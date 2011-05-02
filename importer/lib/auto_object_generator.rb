class AutoObjectGenerator
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv row error)
  PROPERTY_VALUE_CLASSES = PropertyValue.descendants.map { |d| [d] + d.descendants.to_a }.flatten.uniq
  
  def initialize(csv_catalogue, object_catalogue)
    @csvs = csv_catalogue
    @objects = object_catalogue
    
    @errors = []
    
    @agd_property, @at_property = %w(auto:group_diff auto:title).map do |name|
      ref = ObjectRef.for(PropertyDefinition, [name])
      @errors << "#{name} property not found - cannot generate values without it" unless @objects.has_ref?(ref)
      ref
    end
  end
  
  def error_no_strategy(type, for_class, row_md5)
    type = {:ph => "property hierarchy", :ts => "title strategy"}[type]
    error_for_row("no #{type} for reference:class #{for_class.inspect}", row_md5)
  end
  
  def generate
    return unless @errors.empty?
    
    product_row_md5s, *auto_row_md5s = [/^products\//, /^property_hierarchies/, /^title_strategies/].map do |matcher|
      @csvs.infos_for_name(matcher).map { |info| info[:row_md5s] }.flatten.to_set
    end
    
    refs_by_product_row_md5 = {}
    row_md5s_by_product_row_md5 = {}
    
    @objects.rows_by_ref.each do |ref, object_row_md5s|
      primary_row_md5 = object_row_md5s.first
      next unless product_row_md5s.include?(primary_row_md5)
      
      (refs_by_product_row_md5[primary_row_md5] ||= []) << ref
      (row_md5s_by_product_row_md5[primary_row_md5] ||= []).concat(object_row_md5s)
    end
    
    row_md5s_by_product_row_md5_by_csv_name =
      row_md5s_by_product_row_md5.group_by { |row_md5, object_row_md5s| @csvs.row_csv_name(row_md5) }
    
    %w(PH TS).zip(auto_row_md5s).each do |domain, row_md5s|
      m = method("generate_#{domain.downcase}_values")
      
      row_md5s_by_product_row_md5_by_csv_name.each do |csv_name, row_md5s_by_product_row_md5|
        row_count, generated_count, error_count = 0, 0, 0
        
        row_md5s_by_product_row_md5.each do |row_md5, object_row_md5s|
          next unless (row_md5s & object_row_md5s).empty?
          
          refs_by_class = refs_by_product_row_md5[row_md5].group_by { |ref| ref[:class] }
          
          product = refs_by_class[Product].first
          next if domain == "PH" and product[:reference_group].nil?
          
          value_refs = refs_by_class.values_at(*PROPERTY_VALUE_CLASSES).flatten.compact
          value_refs_by_property_name = value_refs.group_by { |v| v[:definition][:name] }
          
          klass = value_refs_by_property_name["reference:class"].first[:text_value]
          
          auto_objects, errors = m.call(product, klass, value_refs_by_property_name, row_md5)
          errors += @objects.add(auto_objects, row_md5).map { |e| error_for_row(e, row_md5) }
          @errors += errors
          
          row_count += 1
          generated_count += auto_objects.size
          error_count += errors.size
        end
        
        puts " - generated #{generated_count} #{domain} objects from #{row_count} rows of #{csv_name}" if generated_count > 0
        puts " ! #{error_count} errors reported from #{csv_name} while generating #{domain} objects" if error_count > 0
      end
      
      # TODO: verifications before commit
      
      @objects.commit("auto_#{domain}")
    end
  end
  
  def generate_auto_part(value_refs, capitalize, superscript_units)
    klass = value_refs.first[:class]
    value_refs = value_refs.sort_by { |v| v[:sequence_number] }
    
    if klass == TextPropertyValue
      part = value_refs.map { |v| v[:text_value] }.join(", ")
      capitalize ? part.gsub!(/(^|\s)\S/) { $&.upcase } : part
    else
      min_seq_num = value_refs.first[:sequence_number]
      value_refs = value_refs.select { |v| v[:sequence_number] == min_seq_num }
      value_refs = value_refs.sort_by { |v| v[:unit].to_s }
      formatted_values = value_refs.map do |v|
        value = klass.format(v[:min_value], v[:max_value], "-", v[:unit])
        superscript_units ? value.superscript_numeric : value
      end
      formatted_values.join(" / ")
    end
  end
  
  def generate_ph_values(product, klass, value_refs_by_property_name, row_md5)
    diff_objects = []
    
    seq_num = 0
    while seq_num += 1 do
      hierarchy = ObjectRef.for(PropertyHierarchy, [klass, seq_num])
      unless @objects.has_ref?(hierarchy)
        return [[], [error_no_strategy(:ph, klass, row_md5)]] if seq_num == 1
        break
      end
      
      rendered_parts = []
      hierarchy[:property_names].map do |name|
        value_refs = value_refs_by_property_name[name]
        rendered_parts << generate_auto_part(value_refs, false, false) unless value_refs.nil?
      end
      
      diff_objects << {
        :class => TextPropertyValue,
        :definition => @agd_property,
        :product => product,
        :auto_generated => true,
        :sequence_number => seq_num,
        :language_code => "ENG",
        :text_value => rendered_parts.join(" - "),
        :property_hierarchy => hierarchy
      }
    end
    
    [diff_objects, []]
  end
  
  def generate_ts_values(product, klass, value_refs_by_property_name, row_md5)
    diff_objects, errors = [], []
    
    strategy = ObjectRef.for(TitleStrategy, [klass])
    return [[], [error_no_strategy(:ts, klass, row_md5)]] unless @objects.has_ref?(strategy)
    
    TitleStrategy::TITLE_PROPERTIES.each_with_index.map do |title, i|
      rendered_parts = []
      strategy[title].each do |part|
        if part == "-"
          rendered_parts << "-" unless rendered_parts.empty? or rendered_parts.last == "-"
        elsif part == "product.reference"
          rendered_parts << product[:reference]
        else
          value_refs = value_refs_by_property_name[part]
          notDescription = (title != :description)
          rendered_parts << generate_auto_part(value_refs, notDescription, notDescription) unless value_refs.nil?
        end
      end
      rendered_parts.pop while rendered_parts.last == "-"
      
      if rendered_parts.empty? then errors << error_for_row("empty #{title} title", row_md5)
      else diff_objects << {
          :class => TextPropertyValue,
          :definition => @at_property,
          :product => product,
          :auto_generated => true,
          :sequence_number => i + 1,
          :language_code => "ENG",
          :text_value => rendered_parts.join(" "),
          :title_strategy => strategy
        }
      end
    end
    
    [diff_objects, errors]
  end
end

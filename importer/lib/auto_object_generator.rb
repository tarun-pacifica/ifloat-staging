class AutoObjectGenerator
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv row error)
  VALUE_CLASSES = PropertyValue.descendants.map { |d| [d] + d.descendants.to_a }.flatten.to_set
  
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
    
    product_data_by_ref = {}
    product_refs_by_class = {Product => [], PropertyHierarchy => [], TitleStrategy => []}
    value_refs_by_product_ref = {}
    @objects.each do |ref, data|
      klass = data[:class]
      if klass == Product
        product_data_by_ref[ref] = data
        product_refs_by_class[Product] << ref
      elsif VALUE_CLASSES.include?(klass)
        product_ref = data[:product]
        auto_class =
          if data[:property_hierarchy] then PropertyHierarchy
          elsif data[:title_strategy]  then TitleStrategy
          else nil
          end
        product_refs_by_class[auto_class] << product_ref unless auto_class.nil?
        (value_refs_by_product_ref[product_ref] ||= []) << ref
      end
    end
    
    all_product_refs = product_refs_by_class.delete(Product).to_set
    product_refs_by_class.each do |klass, refs|
      error_count, product_count = 0, 0
      refs_to_generate = all_product_refs - refs
      refs_to_generate.delete_if { |ref| product_data_by_ref[ref][:reference_group].nil? } if klass == PropertyHierarchy
      m = method("generate_#{klass.to_s.gsub(/[^A-Z]/, '').downcase}_values")
      
      refs_to_generate.each_slice(500).each do |refs|
        refs.each do |ref|
          values_by_property_name = (value_refs_by_product_ref[ref] || []).group_by { |v| v[:definition][:name] }
          product_class = values_by_property_name["reference:class"].first[:text_value]
          row_md5 = @objects.rows_by_ref[ref].first
          
          auto_objects, errors = m.call(ref, product_data_by_ref[ref], product_class, values_by_property_name, row_md5)
          errors += @objects.add(auto_objects, row_md5).map { |e| error_for_row(e, row_md5) }
          @errors += errors
          
          product_count += 1 unless auto_objects.empty?
          error_count += errors.size
        end
        
        puts " - generated #{klass} objects for #{product_count}/#{refs_to_generate.size} products" if product_count > 0
      end
      
      puts " ! #{error_count} errors reported while generating #{klass} objects" if error_count > 0
      @objects.commit("auto_#{klass}")
    end
  end
  
  def generate_auto_part(values, capitalize, superscript_units)
    klass = values.first[:class]
    values = values.sort_by { |v| v[:sequence_number] }
    
    if klass == TextPropertyValue
      part = values.map { |v| v[:text_value] }.join(", ")
      capitalize ? part.gsub!(/(^|\s)\S/) { $&.upcase } : part
    else
      min_seq_num = values.first[:sequence_number]
      values = values.select { |v| v[:sequence_number] == min_seq_num }
      values = values.sort_by { |v| v[:unit].to_s }
      formatted_values = values.map do |v|
        value = klass.format(v[:min_value], v[:max_value], "-", v[:unit])
        superscript_units ? value.superscript_numeric : value
      end
      formatted_values.join(" / ")
    end
  end
  
  def generate_ph_values(product_ref, product, klass, values_by_property_name, row_md5)
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
        values = values_by_property_name[name]
        rendered_parts << generate_auto_part(values, false, false) unless values.nil?
      end
      
      diff_objects << {
        :class => TextPropertyValue,
        :definition => @agd_property,
        :product => product_ref,
        :auto_generated => true,
        :sequence_number => seq_num,
        :language_code => "ENG",
        :text_value => rendered_parts.join(" - "),
        :property_hierarchy => hierarchy
      }
    end
    
    [diff_objects, []]
  end
  
  def generate_ts_values(product_ref, product, klass, values_by_property_name, row_md5)
    title_objects, errors = [], []
    
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
          values = values_by_property_name[part]
          notDescription = (title != :description)
          rendered_parts << generate_auto_part(values, notDescription, notDescription) unless values.nil?
        end
      end
      rendered_parts.pop while rendered_parts.last == "-"
      
      if rendered_parts.empty? then errors << error_for_row("empty #{title} title", row_md5)
      else title_objects << {
          :class => TextPropertyValue,
          :definition => @at_property,
          :product => product_ref,
          :auto_generated => true,
          :sequence_number => i + 1,
          :language_code => "ENG",
          :text_value => rendered_parts.join(" "),
          :title_strategy => strategy
        }
      end
    end
    
    errors.empty? ? [title_objects, []] : [[], errors]
  end
end

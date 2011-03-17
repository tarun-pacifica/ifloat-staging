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
    csv_name = @csvs.row_csv_name(row_md5)
    row_index = @csvs.row_index(row_md5)
    type = {:ph => "property hierarchy", :ts => "title strategy"}[type]
    @errors << [csv_name, row_index, "no #{type} for reference:class #{for_class.inspect}"]
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
        
    [:generate_ph_values, :generate_ts_values].zip(auto_row_md5s).each do |method_sym, row_md5s|
      m = method(method_sym)
      
      row_md5s_by_product_row_md5.each do |row_md5, object_row_md5s|
        next if row_md5s.include?(object_row_md5s[1])
        
        objects = refs_by_product_row_md5[row_md5].map { |ref| ref.attributes }
        objects_by_class = objects.group_by { |o| o[:class] }
        
        product = objects_by_class[Product].first
        next if product[:reference_group].nil?
        
        value_objects = objects_by_class.values_at(*PROPERTY_VALUE_CLASSES).flatten.compact
        value_objects_by_property_name = value_objects.group_by { |v| v[:definition][:name] }
        
        klass = value_objects_by_property_name["reference:class"].first[:text_value]
        
        objects = m.call(product, klass, value_objects_by_property_name, row_md5)
        p objects
        # TODO: do something with objects
        # add objects to the catalogue with row_md5 + property_hierarchy row md5
        # use a PH / TS only group to make system-wide comparison memory efficient
      end
    end
  end
  
  def generate_auto_part(value_objects, capitalize, superscript_units)
    klass = value_objects.first[:class]
    value_objects = value_objects.sort_by { |v| v[:sequence_number] }
    
    if klass == TextPropertyValue
      part = value_objects.map { |v| v[:text_value] }.join(", ")
      capitalize ? part.gsub!(/(^|\s)\S/) { $&.upcase } : part
    else
      min_seq_num = value_objects.first[:sequence_number]
      value_objects = value_objects.select { |v| v[:sequence_number] == min_seq_num }
      value_objects = value_objects.sort_by { |v| v[:unit].to_s }
      formatted_values = value_objects.map do |v|
        value = klass.format(v[:min_value], v[:max_value], "-", v[:unit])
        superscript_units ? value.superscript_numeric : value
      end
      formatted_values.join(" / ")
    end
  end
  
  def generate_ph_values(product, klass, value_objects_by_property_name, row_md5)
    diff_objects = []
    
    seq_num = 0
    while seq_num += 1 do
      hierarchy = ObjectRef.for(PropertyHierarchy, [klass, seq_num])
      unless @objects.has_ref?(hierarchy)
        error_no_strategy(:ph, klass, row_md5) if seq_num == 1
        break
      end
      
      rendered_parts = []
      hierarchy[:property_names].map do |name|
        value_objects = value_objects_by_property_name[name]
        rendered_parts << generate_auto_part(value_objects, false, false) unless value_objects.nil?
      end
      
      diff_objects << {
        :class => TextPropertyValue,
        :definition => @agd_property,
        :product => product,
        :auto_generated => true,
        :sequence_number => seq_num,
        :language_code => "ENG",
        :text_value => rendered_parts.join(" - ")
      }
    end
    
    diff_objects
  end
  
  def generate_ts_values(row_md5, refs)
    # p ["TS", row_md5, pk_md5s]
  end
end

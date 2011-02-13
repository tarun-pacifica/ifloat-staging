class ProductParser < AbstractParser
  HEADERS = %w(company.reference product.reference IMPORT)
  
  SPECIAL_VALUE_VALIDITIES = {
    "AUTO" => [:values].to_set,
    "N/A"  => [:reference_group, :attachments, :mappings, :relationships, :values].to_set,
    "NIL"  => [:reference_group, :attachments, :mappings, :relationships, :values].to_set
  }
  
  def initialize(*args)
    super
    
    @auto_group_diff_property = @import_set.get(PropertyDefinition, "auto:group_diff")
    @auto_title_property = @import_set.get(PropertyDefinition, "auto:title")
    
    @title_strategies_by_class = {}
    @import_set.get(TitleStrategy).each do |name, strategy|
      attributes = strategy.attributes
      attributes[:class_names].each do |klass|
        @title_strategies_by_class[klass] = attributes
      end
    end
    @title_strategies_by_class.default = @title_strategies_by_class["ANY_CLASS"]
  end
  
  
  private
  
  def generate_auto_part(value_objects, capitalize, superscript_units)
    klass = value_objects.first.klass
    value_attributes = value_objects.map { |o| o.attributes }.sort_by { |attribs| attribs[:sequence_number] }
    
    if klass == TextPropertyValue
      part = value_attributes.map { |attribs| attribs[:text_value] }.join(", ")
      capitalize ? part.gsub!(/(^|\s)\S/) { $&.upcase } : part
    else
      min_seq_num = value_attributes.first[:sequence_number]
      value_attributes = value_attributes.select { |attribs| attribs[:sequence_number] == min_seq_num }
      value_attributes = value_attributes.sort_by { |attribs| attribs[:unit].to_s }
      formatted_values = value_attributes.map do |attribs|
        value = klass.format(attribs[:min_value], attribs[:max_value], "-", attribs[:unit])
        superscript_units ? value.superscript_numeric : value
      end
      formatted_values.join(" / ")
    end
  end
  
  def generate_auto_group_diffs(value_objects_by_property_name, product)
    return [] if product.attributes[:reference_group].nil?
    
    diff_objects = []
    klass = (value_objects_by_property_name["reference:class"].first.attributes[:text_value] rescue nil)
    
    seq_num = 0
    while seq_num += 1 do
      hierarchy = @import_set.get(PropertyHierarchy, klass, seq_num)
      break if hierarchy.nil?
      
      rendered_parts = []
      hierarchy.attributes[:property_names].map do |name|
        value_objects = value_objects_by_property_name[name]
        rendered_parts << generate_auto_part(value_objects, false, false) unless value_objects.nil?
      end
      next if rendered_parts.empty?
      
      attributes = {
        :definition => @auto_group_diff_property,
        :product => product,
        :auto_generated => true,
        :sequence_number => seq_num,
        :language_code => "ENG",
        :text_value => rendered_parts.join(" - ")
      }
      diff_objects << ImportObject.new(TextPropertyValue, attributes)
    end
    
    diff_objects
  end
  
  def generate_auto_titles(value_objects_by_property_name, product)
    klass = (value_objects_by_property_name["reference:class"].first.attributes[:text_value] rescue nil)
    strategy = @title_strategies_by_class[klass]
    return [] if strategy.nil?
    
    TitleStrategy::TITLE_PROPERTIES.each_with_index.map do |title, i|
      rendered_parts = []
      strategy[title].each do |part|
        if part == "-"
          rendered_parts << "-" unless rendered_parts.empty? or rendered_parts.last == "-"
        elsif part == "product.reference"
          rendered_parts << product.attributes[:reference]
        else
          value_objects = value_objects_by_property_name[part]
          notDescription = (title != :description)
          rendered_parts << generate_auto_part(value_objects, notDescription, notDescription) unless value_objects.nil?
        end
      end
      rendered_parts.pop while rendered_parts.last == "-"
      
      attributes = {
        :definition => @auto_title_property,
        :product => product,
        :auto_generated => true,
        :sequence_number => i + 1,
        :language_code => "ENG",
        :text_value => rendered_parts.join(" ")
      }
      ImportObject.new(TextPropertyValue, attributes)
    end
  end
  
  def generate_objects(parsed_fields)
    return [] unless parsed_fields.delete([:import]) == "Y"
    
    attributes = {}
    [:company, :reference, :reference_group].each do |attribute|
      attributes[attribute] = parsed_fields.delete([attribute])
    end
    
    product = ImportObject.new(Product, attributes)
    objects = [product]
    
    value_objects_by_property_name = {}
    
    domains = [:attachments, :mappings, :relationships, :values].to_set
    parsed_fields.each do |head, object|
      next if object.nil?
      
      domain = head.first
      next unless domains.include?(domain)
      
      if domain == :values
        property_name = object.attributes[:definition].attributes[:name]
        (value_objects_by_property_name[property_name] ||= []) << object
      end
        
      values = (object.is_a?(Array) ? object : [object])
      values.each { |o| o.attributes[:product] = product }
      objects.push(*values)
    end
    
    objects +
      generate_auto_group_diffs(value_objects_by_property_name, product) +
      generate_auto_titles(value_objects_by_property_name, product)
  end
  
  def parse_field(head, value, fields)
    domain, domain_info = head.first, head[1..-1]
    
    validity = SPECIAL_VALUE_VALIDITIES[value]
    unless validity.nil?
      raise "invalid #{domain}: #{value.inspect}" unless validity.include?(domain)
      return nil if value == "N/A" or value == "NIL"
    end
    
    case domain
      
    when :attachments
      raise "invalid attachment: #{value.inspect}" unless value =~ /^(\[(.+?)\])?([^\[\]]+)$/     
      company_ref, name = $2, $3
      company = (company_ref.nil? ? fields[[:company]] : @import_set.get!(Company, company_ref))
      return :deferred if company.nil?
      asset = @import_set.get!(Asset, "products", company, name)
      ImportObject.new(Attachment, :asset => asset, :role => domain_info[0], :sequence_number => domain_info[1])
      
    when :company
      @import_set.get!(Company, value)
      
    when :import
      raise "invalid import value (not Y/N): #{value.inspect}" unless value == "Y" or value == "N"
      value
      
    when :mappings
      raise "invalid mapping: #{value.inspect}" unless value =~ ProductMapping::REFERENCE_FORMAT
      ImportObject.new(ProductMapping, :company => domain_info[0], :reference => value)
      
    when :reference, :reference_group
      raise "invalid reference: #{value.inspect}" unless value =~ Product::REFERENCE_FORMAT
      value
      
    when :relationships
      name, company, property, bidirectional = domain_info
      attributes = {:company => company, :property_definition => property, :name => name, :bidirectional => bidirectional}
      fields = Set.new
      value.split(",").map do |field|
        raise "empty relationship (possible double comma): #{value.inspect}" if field.blank?
        f = field.strip
        raise "repeated relationship (#{f.inspect}): #{value.inspect}" if fields.include?(f)
        fields << f
        ImportObject.new(ProductRelationship, attributes.merge(:value => f))
      end
      
    when :values
      parse_value(value, fields, *domain_info)
      
    else raise "unknown domain: #{domain}"
    end
  end
  
  def parse_header(header)
    case header
      
    when "IMPORT"
      [:import]
      
    when "company.reference"
      [:company]
      
    when /^product\.(reference(_group)?)$/
      [$1.to_sym]
      
    when /^mapping\.reference\.(.+?)$/
      company_ref = $1
      company = @import_set.get!(Company, company_ref)
      [:mappings, company]
      
    when /^(.+?:.+?):(.*?):(\d+)(:(tolerance))?$/
      property_name, unit, seq_num, component = $1, $2, $3, $5
      property = @import_set.get!(PropertyDefinition, property_name)
      property_type = property.attributes[:property_type]
      unit = nil if unit.blank?
      valid, error = PropertyType.validate_unit(unit, *property_type.attributes.values_at(:name, :core_type, :units))
      raise "invalid unit (#{error}): #{unit.inspect}" unless valid
      klass = PropertyType.value_class(property_type.attributes[:core_type])
      [:values, klass, property, seq_num.to_i, unit, (component || :value).to_sym]
      
    when /^(uni-)?relationship\.([a-z_]+)\.(.+?)(\.(.+?))?$/
      relationship_name, company_ref, property_name, bidirectional = $2, $3, $5, $1.nil?
      raise "unknown relationship: #{relationship_name}" unless ProductRelationship::NAMES.has_key?(relationship_name)
      company = ((company_ref == "*") ? nil : @import_set.get!(Company, company_ref))
      property = (property_name.blank? ? nil : @import_set.get!(PropertyDefinition, property_name))
      raise "non-text property: #{property_name}" unless property.nil? or property.attributes[:property_type].attributes[:core_type] == "text"
      [:relationships, relationship_name, company, property, bidirectional]
      
    when /^attachment\.([a-z_]+)\.(\d+)$/
      role, seq_num = $1, $2
      raise "unknown role: #{role}" unless Attachment::ROLES.has_key?(role)
      [:attachments, role, seq_num.to_i]
      
    else raise "unknown/invalid header: #{header}"
    end
  end
  
  def parse_value(value, fields, klass, property, seq_num, unit, component)
    return parse_value_auto(fields, klass, property, seq_num, unit, component) if value == "AUTO"
    
    case component
      
    when :tolerance
      raise "invalid property value tolerance (expected a number): #{value.inspect}" unless value =~ /^\d+(\.\d+)?$/
      property_value = fields[[:values, klass, property, seq_num, unit, :value]]
      return :deferred unless property_value.is_a?(PropertyValue)
      property_value.tolerance = value.to_f
      
    when :value
      attributes = {:definition => property, :auto_generated => false, :sequence_number => seq_num}
      attributes.update(klass.parse_or_error(value))
      attributes[:unit] = unit unless unit.nil?
      attributes[:language_code] = "ENG" if klass == TextPropertyValue
      ImportObject.new(klass, attributes)
      
    else "unknown component: #{component}"
    end
  end
  
  def parse_value_auto(fields, klass, property, seq_num, unit, component)
    return nil unless component == :value
    
    @all_units_by_property[property].each do |search_unit|
      next if search_unit == unit
      
      object = fields[[:values, klass, property, seq_num, search_unit, component]]
      next if object.nil?

      tolerance_key = [:values, klass, property, seq_num, search_unit, :tolerance]
      return :deferred if @header_values.include?(tolerance_key) and not fields.has_key?(tolerance_key)
      
      attributes = {:definition => property, :auto_generated => true, :sequence_number => seq_num}
      attributes.update(klass.convert(object.attributes, unit))
      return ImportObject.new(klass, attributes)
    end
    
    :deferred
  end
  
  def preflight_check
    errors = []
    errors << 'missing PropertyDefinition "auto:title"' if @auto_title_property.nil?
    errors
  end
  
  def validate_headers(headers)
    errors = super
    
    @header_values = headers.values.to_set
    properties = []
    units_by_seq_nums_by_property = {}
    @header_values.each do |head|
      next unless head.first == :values
      
      property, seq_num, unit, component = head[2..-1]
      properties << property
      next unless component == :value
      
      units_by_seq_nums = (units_by_seq_nums_by_property[property] ||= {})
      units = (units_by_seq_nums[seq_num] ||= [])
      units << unit
    end
    
    all_property_names = []
    @all_units_by_property = {}
    properties.uniq.each do |property|
      all_property_names << property.attributes[:name]
      property_type = property.attributes[:property_type]
      @all_units_by_property[property] = property_type.attributes[:units]
    end
    
    units_by_seq_nums_by_property.each do |property, units_by_seq_nums|
      all_units = (@all_units_by_property[property] || [])
      units_by_seq_nums.each do |seq_num, units|
        (all_units - units).each do |unit|
          errors << "required property unit missing: #{property.attributes[:name]}:#{unit}:#{seq_num}"
        end
      end
    end
    
    errors
  end
end

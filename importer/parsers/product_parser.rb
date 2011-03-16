class ProductParser < AbstractParser
  REQUIRED_HEADERS = REQUIRED_VALUE_HEADERS = %w(company.reference product.reference reference:class::1 marketing:brand::1)
  
  SPECIAL_VALUE_VALIDITIES = {
    "AUTO" => [:values].to_set,
    "N/A"  => [:reference_group, :attachments, :mappings, :relationships, :values].to_set,
    "NIL"  => [:reference_group, :attachments, :mappings, :relationships, :values].to_set
  }
  
  
  def generate_objects(parsed_fields)
    attributes = Hash[[:company, :reference, :reference_group].map { |key| [key, parsed_fields.delete([key])] }]
    product = attributes.update(:class => Product)
    
    product_lookup = lookup(Product, *attributes.values_at(:company, :reference))
    [product] + parsed_fields.map do |head, object|
      next if object.nil?
      values = (object.is_a?(Array) ? object : [object])
      values.map! { |o| o.update(:product => product_lookup) }
    end.compact.flatten
  end
  
  def parse_field(head, value, fields)
    return nil if value.blank?
    
    domain, domain_info = head.first, head[1..-1]
    
    case domain
    
    when :attachments
      raise "invalid attachment: #{value.inspect}" unless value =~ /^(\[(.+?)\])?([^\[\]]+)$/
      company_ref, name = $2, $3
      company = (company_ref.nil? ? fields[[:company]] : lookup!(Company, company_ref))
      raise "company cannot be determined" if company.nil?
      asset = lookup!(Asset, "products", company, name)
      {:class => Attachment, :asset => asset, :role => domain_info[0], :sequence_number => domain_info[1]}
      
    when :company
      lookup!(Company, value)
      
    when :mappings
      raise "invalid mapping: #{value.inspect}" unless value =~ ProductMapping::REFERENCE_FORMAT
      {:class => ProductMapping, :company => domain_info[0], :reference => value}
      
    when :reference, :reference_group
      raise "invalid reference: #{value.inspect}" unless value =~ Product::REFERENCE_FORMAT
      value
      
    when :relationships
      attributes = Hash[[:name, :company, :property_definition, :bidirectional].zip(domain_info)]
      attributes[:class] = ProductRelationship
      fields = Set.new
      value.split(",").map do |field|
        raise "empty relationship (possible double comma): #{value.inspect}" if field.blank?
        f = field.strip
        raise "repeated relationship (#{f.inspect}): #{value.inspect}" if fields.include?(f)
        fields << f
        attributes.merge(:value => f)
      end
      
    when :values
      parse_value(value, fields, *domain_info)
      
    else raise "unknown domain: #{domain}"
    end
  end
  
  def parse_header(header)
    case header
      
    when "company.reference"
      [:company]
      
    when /^product\.(reference(_group)?)$/
      [$1.to_sym]
      
    when /^mapping\.reference\.(.+?)$/
      [:mappings, lookup!(Company, $1)]
      
    when /^(.+?:.+?):(.*?):(\d+)$/
      property_name, unit, seq_num = $1, $2, $3
      property = lookup!(PropertyDefinition, property_name)
      property_type = property[:property_type]
      unit = nil if unit.blank?
      valid, error = PropertyType.validate_unit(unit, *property_type.attributes.values_at(:name, :core_type, :units))
      raise "invalid unit (#{error}): #{unit.inspect}" unless valid
      klass = PropertyType.value_class(property_type[:core_type])
      [:values, klass, property, seq_num.to_i, unit]
      
    when /^(uni-)?relationship\.([a-z_]+)\.(.+?)(\.(.+?))?$/
      relationship_name, company_ref, property_name, bidirectional = $2, $3, $5, $1.nil?
      raise "unknown relationship: #{relationship_name}" unless ProductRelationship::NAMES.has_key?(relationship_name)
      company = ((company_ref == "*") ? nil : lookup!(Company, company_ref))
      property = (property_name.blank? ? nil : lookup!(PropertyDefinition, property_name))
      raise "non-text property: #{property_name}" unless property.nil? or property[:property_type][:core_type] == "text"
      [:relationships, relationship_name, company, property, bidirectional]
      
    when /^attachment\.([a-z_]+)\.(\d+)$/
      role, seq_num = $1, $2
      raise "unknown role: #{role}" unless Attachment::ROLES.has_key?(role)
      [:attachments, role, seq_num.to_i]
      
    else raise "unknown/invalid header: #{header}"
    end
  end
  
  def parse_value(value, fields, klass, property, seq_num, unit)
    return parse_value_auto(fields, klass, property, seq_num, unit) if value == "AUTO"
    
    attributes = {:class => klass, :definition => property, :auto_generated => false, :sequence_number => seq_num}
    attributes.update(klass.parse_or_error(value))
    attributes[:unit] = unit unless unit.nil?
    attributes[:language_code] = "ENG" if klass == TextPropertyValue
    attributes
  end
  
  def parse_value_auto(fields, klass, property, seq_num, unit)
    @all_units_by_property[property].each do |search_unit|
      next if search_unit == unit
      
      object = fields[[:values, klass, property, seq_num, search_unit]]
      next if object.nil?
      
      attributes = {:class => klass, :definition => property, :auto_generated => true, :sequence_number => seq_num}
      return attributes.update(klass.convert(object, unit))
    end
    
    raise "AUTO value with no concrete value from which to convert"
  end
  
  def parse_headers(*args)
    headers, errors = super
    return [headers, errors] unless errors.empty?
    
    properties = []
    units_by_seq_nums_by_property = {}
    headers.each do |header|
      next unless header.first == :values
      
      property, seq_num, unit = header[2..-1]
      properties << property
      
      units_by_seq_nums = (units_by_seq_nums_by_property[property] ||= {})
      units = (units_by_seq_nums[seq_num] ||= [])
      units << unit
    end
    
    all_property_names = []
    @all_units_by_property = {}
    properties.uniq.each do |property|
      all_property_names << property[:name]
      property_type = property[:property_type]
      @all_units_by_property[property] = property_type[:units]
    end
    
    units_by_seq_nums_by_property.each do |property, units_by_seq_nums|
      all_units = (@all_units_by_property[property] || [])
      units_by_seq_nums.each do |seq_num, units|
        (all_units - units).each do |unit|
          errors << "required property unit missing: #{property[:name]}:#{unit}:#{seq_num}"
        end
      end
    end
    
    [headers, errors]
  end
  
  def partition_fields(values_by_header)
    values_by_header.group_by do |header, value|
      if header == [:company] then 0
      elsif value == "AUTO" then 2
      else 1
      end
    end.sort.map { |index, headed_values| headed_values }
  end
end

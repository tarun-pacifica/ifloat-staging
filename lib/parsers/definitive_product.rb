class DefinitiveProductParser < AbstractParser
  ESSENTIAL_HEADERS = ["company.reference", "product.review_stage", "product.reference"]
  
  REQUIRED_PROPERTY_NAMES = ["reference:class"]
  
  SPECIAL_VALUE_VALIDITIES = {
    "AUTO" => [:values],
    "N/A"  => [:attachments, :mappings, :relationships, :values],
    "NIL"  => [:attachments, :mappings, :relationships, :values]
  }
  
  
  private
  
  def generate_objects(parsed_fields)
    attributes = {}
    [:company, :reference, :review_stage].each do |attribute|
      attributes[attribute] = parsed_fields.delete([attribute])
    end
    objects = [ImportObject.new(DefinitiveProduct, attributes)]
    
    parsed_fields.each do |head, value|
      next if value.nil?
      domain = head.first
      next unless [:attachments, :mappings, :relationships, :values].include?(domain)
      
      values = (value.is_a?(Array) ? value : [value])
      values.each { |o| o.attributes[:product] = objects[0] }
      objects.push(*values)
    end
    
    objects
  end
  
  def parse_field(head, value, fields)
    domain, domain_info = head.first, head[1..-1]
    
    validity = SPECIAL_VALUE_VALIDITIES[value]
    unless validity.nil?
      raise "invalid #{domain}: #{value}" unless validity.include?(domain)
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
      
    when :id, :review_stage
      raise "invalid #{domain} (expected an integer): #{value.inspect}" unless value =~ /^(\d+)$/
      value.to_i
      
    when :mappings
      raise "invalid mapping: #{value.inspect}" unless value =~ Product::REFERENCE_FORMAT
      ImportObject.new(ProductMapping, :company => domain_info[0], :reference => value)
      
    when :reference
      raise "invalid reference: #{value.inspect}" unless value =~ Product::REFERENCE_FORMAT
      value
      
    when :relationships
      name, company, property = domain_info
      attributes = {:company => company, :property_definition => property, :name => name}
      value.split(",").map do |field|
        ImportObject.new(Relationship, attributes.merge(:value => field.strip))
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
      
    when /^product\.(.+?)$/
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
      [:values, property, seq_num.to_i, unit, (component || :value).to_sym]

    when /^relationship\.([a-z_]+)\.(.+?)(\.(.+?))?$/
      relationship_name, company_ref, property_name = $1, $2, $4
      raise "unknown relationship: #{relationship_name}" unless Relationship::NAMES.has_key?(relationship_name)
      company = @import_set.get!(Company, company_ref)
      property = (property_name.blank? ? nil : @import_set.get!(PropertyDefinition, property_name))
      [:relationships, relationship_name, company, property]

    when /^attachment\.([a-z_]+)\.(\d+)$/
      role, seq_num = $1, $2
      raise "unknown role: #{role}" unless Attachment::ROLES.include?(role)
      [:attachments, role, seq_num.to_i]

    else raise "unknown/invalid header: #{header}"
    end
  end
  
  def parse_value(value, fields, property, seq_num, unit, component)
    return parse_value_auto(fields, property, seq_num, unit, component) if value == "AUTO"
    
    case component
      
    when :tolerance
      raise "invalid property value tolerance (expected a number): #{value.inspect}" unless value =~ /^\d+(\.\d+)?$/
      property_value = fields[[:values, property, seq_num, unit, :value]]
      return :deferred unless property_value.is_a?(PropertyValue)
      property_value.tolerance = value.to_f
      
    when :value
      klass = PropertyType.value_class(property.attributes[:property_type].attributes[:core_type])
      attributes = {:definition => property, :auto_generated => false, :sequence_number => seq_num}
      attributes.update(klass.parse_or_error(value))
      attributes[:unit] = unit unless unit.nil?
      attributes[:language_code] = "ENG" if klass.text?
      ImportObject.new(klass, attributes)
      
    else "unknown component: #{component}"
    end
  end
  
  def parse_value_auto(fields, property, seq_num, unit, component)
    return nil unless component == :value
    
    @all_units_by_property[property].each do |search_unit|
      next if search_unit == unit
      
      object = fields[[:values, property, seq_num, search_unit, component]]
      next if object.nil?

      tolerance_key = [:values, property, seq_num, search_unit, :tolerance]
      return :deferred if @headers.values.include?(tolerance_key) and not fields.has_key?(tolerance_key)
      
      attributes = {:definition => property, :auto_generated => true, :sequence_number => seq_num}
      attributes.update(object.klass.convert(object.attributes, unit))
      return ImportObject.new(object.klass, attributes)
    end
    
    :deferred
  end
  
  def validate_headers(headers)
    errors = super
    
    properties = []
    units_by_seq_nums_by_property = {}
    headers.values.each do |head|
      next unless head.first == :values
      
      property, seq_num, unit, component = head[1..-1]
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
    
    (REQUIRED_PROPERTY_NAMES - all_property_names).each do |name|
      errors << "required property missing: #{name}"
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

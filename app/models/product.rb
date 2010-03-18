# = Summary
#
# The backbone of the schema, a Product models the available pickable/purchasable items. Its data is based as far as possible on the original manufacturer's specifications and is tracked using PropertyValue objects (for schema-free flexibility). Products may also have arbitrary attachments for tracking images, data sheets and so on.
#
# Each Product belongs to a specific Company and may be related to other Products by means of ProductRelationship objects. FacilityProducts may be associated with Products by means of ProductMapping objects.
#
class Product
  include DataMapper::Resource
  
  REFERENCE_FORMAT = /^[A-Z_\d\-\.\/]+$/
  
  property :id,           Serial
  property :reference,    String,  :required => true, :format => REFERENCE_FORMAT, :unique_index => :ref_per_company
  
  belongs_to :company
    property :company_id, Integer, :unique_index => :ref_per_company
  
  has n, :attachments
  has n, :mappings, :model => "ProductMapping"
  has n, :product_relationships
  has n, :values, :model => "PropertyValue"
  
  # TODO: spec
  def self.marshal_values(product_ids, language_code, range_sep)  
    attributes = {:product_id => product_ids}
    db_values = NumericPropertyValue.all(attributes).map
    db_values += TextPropertyValue.all(attributes.merge(:language_code => language_code))
    
    product_ids = db_values.map { |value| value.product_id }.uniq
    property_ids = db_values.map { |value| value.property_definition_id }.uniq
    
    definitions_by_property_id = PropertyValueDefinition.by_property_id(property_ids, language_code)
    
    comp_keys_by_value = {}
    db_values.each do |value|
      comp_keys_by_value[value] = value.comparison_key
    end
    
    common_values, diff_values = [], []
    
    db_values.group_by { |value| value.property_definition_id }.each do |property_id, values|
      values_by_product_id = values.group_by { |value| value.product_id }
      
      comp_keys = values_by_product_id.map { |product_id, values| comp_keys_by_value.values_at(*values).sort }
      common = (comp_keys.size == product_ids.size and comp_keys.uniq.size == 1)
      
      definitions = definitions_by_property_id[property_id]
      prop_info = Indexer.property_display_cache[property_id]
      
      values_by_product_id.each do |product_id, values|
        value_info = prop_info.merge(:product_id => product_id)
        value_info[:comp_key] = comp_keys_by_value.values_at(*values).min
        value_info[:values] = values.sort_by { |value| value.sequence_number }.map { |value| value.to_s(range_sep) }
        value_info[:definitions] = value_info[:values].map { |v| definitions[v] } unless definitions.nil?
        
        (common ? common_values : diff_values) << value_info
        break if common
      end
    end
    
    [common_values, diff_values]
  end
  
  # TODO: spec, implement supply country filtering support when required (retail:country)
  # TODO: may be able to factor out the mapping bit to ProductMapping
  def self.prices_by_url_by_product_id(product_ids, currency)
    query =<<-EOS
      SELECT DISTINCT pm.product_id, f.primary_url, fp.price
      FROM product_mappings pm
        INNER JOIN companies c ON pm.company_id = c.id
        INNER JOIN facilities f ON c.id = f.company_id
        INNER JOIN facility_products fp ON f.id = fp.facility_id AND pm.reference = fp.reference
      WHERE pm.product_id IN ?
    EOS
    
    prices_by_url_by_prod_id = {}
    repository(:default).adapter.select(query, product_ids).each do |record|
      prices_by_url = (prices_by_url_by_prod_id[record.product_id] ||= {})
      prices_by_url[record.primary_url] = record.price
    end
    prices_by_url_by_prod_id
  end
  
  # TODO: spec
  def self.primary_images_by_product_id(product_ids)
    checksums_by_product_id = {}
    Indexer.image_checksums_for_product_ids(product_ids).each do |checksum, prod_ids|
      prod_ids.each do |prod_id|
        checksums_by_product_id[prod_id] = checksum
      end
    end
    
    assets_by_checksum = Asset.all(:checksum => checksums_by_product_id.values).hash_by(:checksum)
    
    assets_by_prod_id = {}
    checksums_by_product_id.each do |prod_id, checksum|
      assets_by_prod_id[prod_id] = assets_by_checksum[checksum]
    end
    assets_by_prod_id
  end
  
  # TODO: spec
  def self.values_by_property_name_by_product_id(product_ids, language_code, names)
    names_by_property_id = {}
    Indexer.property_display_cache.each do |property_id, info|
      name = info[:raw_name]
      names_by_property_id[property_id] = name if names.include?(name)
    end
    
    attributes = {:product_id => product_ids, :property_definition_id => names_by_property_id.keys }
    db_values = NumericPropertyValue.all(attributes).map
    db_values += TextPropertyValue.all(attributes.merge(:language_code => language_code))
    
    values_by_prop_name_by_prod_id = {}
    db_values.group_by { |value| value.product.id }.each do |product_id, values|
      values_by_prop_name_by_prod_id[product_id] =
        values.group_by { |value| names_by_property_id[value.property_definition_id] }
    end
    values_by_prop_name_by_prod_id
  end
  
  # TODO: spec
  def assets_by_role 
    Attachment.product_role_assets([id])[id] || {}
  end
  
  # TODO: spec
  def marshal_values(language_code)
    Product.marshal_values([id], language_code)[id] || {}
  end
  
  # TODO: spec
  def prices_by_url(currency)
    Product.prices_by_url_by_product_id([id], currency)[id] || {}
  end
  
  # TODO: spec
  def values_by_property_name(language_code, names)
    Product.values_by_property_name_by_product_id([id], language_code, property_names)[id] || {}
  end
end

# = Summary
#
# The backbone of the schema, a Product models the available pickable/purchasable items. Its data is based as far as possible on the original manufacturer's specifications and is tracked using PropertyValue objects (for schema-free flexibility). Products may also have arbitrary attachments for tracking images, data sheets and so on.
#
# Each Product belongs to a specific Company and may be related to other Products by means of ProductRelationship objects. FacilityProducts may be associated with Products by means of ProductMapping objects.
#
# In order to aid with quality control (particularly in the case where a Product is mostly / entirely inferred from retailer information), Products carry a 'review_stage' flag which helps with data preparation in grouping products together that have had the same level of editorial attention. <em>Note that this simple revision number could become a foreign key out to a revisions schema to power more complex workflows.</em>
#
class Product
  include DataMapper::Resource
  
  REFERENCE_FORMAT = /^[A-Z_\d\-\.\/]+$/
  
  property :id,           Serial
  property :reference,    String,  :required => true, :format => REFERENCE_FORMAT
  property :review_stage, Integer, :required => true, :default => 0
  
  belongs_to :company
  
  has n, :attachments
  has n, :mappings, :model => "ProductMapping"
  has n, :product_relationships
  has n, :values, :model => "PropertyValue"
  
  validates_is_unique :reference, :scope => [:company_id]
  
  # TODO: spec
  def self.display_values(product_ids, language_code, property_names = nil)
    attributes = {:product_id => product_ids}
    attributes[:property_definition_id] = PropertyDefinition.all(:name => property_names).map { |pd| pd.id } unless property_names.nil?
    
    db_values = NumericPropertyValue.all(attributes).map
    db_values += TextPropertyValue.all(attributes.merge(:language_code => language_code))
    
    if property_names.nil?
      property_ids = db_values.map { |value| value.property_definition_id }
      PropertyDefinition.all(:id => property_ids.uniq).map
    end
    
    values_by_property_by_product_id = {}
    db_values.sort_by { |value| value.sequence_number }.each do |value|
      values_by_property = (values_by_property_by_product_id[value.product_id] ||= {})
      # TODO: swap simpler code back in when SEL is working in DM again ()
      # http://datamapper.lighthouseapp.com/projects/20609-datamapper/tickets/965
      # values = (values_by_property[value.definition] ||= [])
      values = (values_by_property[PropertyDefinition.get(value.property_definition_id)] ||= [])
      values << value
    end
    values_by_property_by_product_id
  end
  
  # TODO: spec
  def self.partition_data_properties(values_by_property_by_product_id)
    value_identities_by_property = {}
    values_by_property_by_product_id.each do |product_id, values_by_property|
      values_by_property.each do |property, values|
        next unless property.display_as_data?
        value_identity = values.map { |v| v.comparison_key }.sort
        (value_identities_by_property[property] ||= []).push(value_identity)
      end
    end
    
    product_count = values_by_property_by_product_id.size
    value_identities_by_property.keys.partition do |property|
      identities = value_identities_by_property[property]
      identities.size == product_count and identities.uniq.size == 1
    end.map do |prop_segment|
      prop_segment.sort_by { |p| p.sequence_number }
    end
  end
  
  # TODO: spec, implement supply country filtering support when required (retail:country)
  # TODO: may be able to factor out the mapping bit to ProductMapping
  def self.prices(product_ids, currency)
    query =<<-EOS
      SELECT DISTINCT pm.product_id, f.primary_url, fp.price
      FROM product_mappings pm
        INNER JOIN companies c ON pm.company_id = c.id
        INNER JOIN facilities f ON c.id = f.company_id
        INNER JOIN facility_products fp ON f.id = fp.facility_id AND pm.reference = fp.reference
      WHERE pm.product_id IN ?
    EOS
    
    prices_by_url_by_product_id = {}
    repository(:default).adapter.select(query, product_ids).each do |record|
      prices_by_url = (prices_by_url_by_product_id[record.product_id] ||= {})
      prices_by_url[record.primary_url] = record.price
    end
    prices_by_url_by_product_id
  end
  
  # TODO: spec
  def display_values(language_code, property_names = nil)
    Product.display_values([id], language_code, property_names)[id]
  end
  
  # TODO: spec
  def prices(currency)
    Product.prices([id], currency)[id] || {}
  end
  
  # TODO: spec
  def role_assets
    Attachment.product_role_assets([id])[id]
  end
end

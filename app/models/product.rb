# = Summary
#
# Anything that can be found, organised and purchased is a Product (note that this includes services). <b>Note that Product itself is an abstract superclass and should never be created directly.</b>
#
# The subclasses are...
#
# DefinitiveProduct:: The 'ideal' definition of a Product based as far as possible on the original manufacturer's specifications and belonging to a specific Company. It may be related to other DefinitiveProducts by means of Relationship objects.
# FacilityProduct:: A record of the data associated with a particular product at a partner's Facility. ProductMapping objects can map one FacilityProduct to many DefinitiveProducts to allow association for pricing and availability purposes. <em>Has exclusive use of propeties in the 'retail' first-level name-space.</em>
# UserProduct:: An instance of a DefinitiveProduct that the user has 'purchased' (or otherwise acquired) that may be associated with a specific Purchase and can form a tree to group the User's products into name assemblies (such as a boat). <em>Has exclusive use of properties in the 'purchase' first-level name-space.</em>
#
# Each individual piece of information associated with a Product is recorded as a PropertyValue and Products may have arbtitrary Attachments for managing images, data sheets and so on.
#
class Product
  include DataMapper::Resource
  
  REFERENCE_FORMAT = /^[A-Z_\d\-\.\/]+$/
  
  property :id, Serial
  property :type, Discriminator
  property :reference, String, :format => REFERENCE_FORMAT, :nullable => false
  
  has n, :attachments
  has n, :values, :class_name => "PropertyValue"
  
  validates_with_block :type do
    (self.class != Product and self.kind_of?(Product)) || [false, "must be a sub-class of Product"]
  end
  
  # TODO: spec
  def self.display_values(product_ids, languages)
    values_by_property_by_product_id = {}  
    
    TextPropertyValue.translated_values(product_ids, languages).each do |product_id, text_values_by_property|
      values_by_property = (values_by_property_by_product_id[product_id] ||= {})
      values_by_property.update(text_values_by_property)
    end
    
    NumericPropertyValue.all(:product_id => product_ids).each do |value|
      values_by_property = (values_by_property_by_product_id[value.product_id] ||= {})
      values = (values_by_property[value.definition] ||= [])
      values << value
    end
    
    auto_titles_by_product_id = {}
    values_by_property_by_product_id.each do |product_id, values_by_property|
      auto_titles_by_product_id[product_id] = TitleStrategy.generate_titles(values_by_property)
    end
    
    [values_by_property_by_product_id, auto_titles_by_product_id]
  end
  
  # TODO: spec, implement supply country filtering support when required (retail:country)
  # TODO: may be able to factor out the mapping bit to ProductMapping
  def self.prices(product_ids, currency)
    query =<<-EOS
      SELECT DISTINCT pv.min_value, dp.id, f.primary_url
      FROM property_values pv
        INNER JOIN property_definitions pd ON pv.property_definition_id = pd.id
        INNER JOIN products fp ON pv.product_id = fp.id
        INNER JOIN facilities f ON fp.facility_id = f.id
        INNER JOIN product_mappings pm ON fp.company_id = pm.company_id AND fp.reference = pm.reference
        INNER JOIN products dp ON pm.definitive_product_id = dp.id
      WHERE pv.type = 'CurrencyPropertyValue'
        AND pv.unit = ?
        AND pd.name = 'retail:price'
        AND dp.id IN ?
    EOS
    
    prices_by_url_by_product_id = {}
    repository(:default).adapter.query(query, currency, product_ids).each do |record|
      prices_by_url = (prices_by_url_by_product_id[record.definitive_product_id] ||= {})
      prices_by_url[record.primary_url] = record.min_value
    end
    prices_by_url_by_product_id
  end
  
  # TODO: spec
  def display_values(languages)
    values_by_property_by_product_id, auto_titles_by_product_id = Product.display_values([id], languages)
    [values_by_property_by_product_id[id], auto_titles_by_product_id[id]]
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

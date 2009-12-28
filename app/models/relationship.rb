# = Summary
#
# In order to support both auto-assemblies (hiearchies of products) and other less concrete groupings (like marketing categories), DefinitiveProducts may have many Relationships. Each Relationship links a DefinitiveProduct to any other that has a matching TextPropertyValue for a given PropertyDefinition.
#
# The TextPropertyValue match may be limited to a specific Company. This copes with instances where, for example, one DefinitiveProduct is 'used_on' another whose reference:manufacturer is only meaningful in the context of a specific Company. Put another way, specifying a Company as part of the relationship will limit the returned, related DefinitiveProducts to only those from that Company.
#
# See NAMES (the keys) for a list of relationships that can be specified. Note that the values include any 'implied' relationship names that correspond to a given relationship but in the opposite direction and that are generated exclusively by the system. All relationship names form the middle part of the sentence 'product 1 ... product 2' and so necessarily start with a verb.
#
# === Sample Data
#
# name:: 'used_on'
# value:: 'PF223423G'
#
class Relationship
  include DataMapper::Resource
  
  # parent *includes* child:: child _is_included_in_ parent
  # generic *is_alternative_to* oem:: oem _is_originator_of_ generic
  # sibling *goes_well_with* sibling:: [bidirectional]
  # child *used_on* parent:: parent _uses_ child
  # sibling *works_with* sibling:: [bidirectional]
  NAMES = {
    "includes"          => "is_included_in",
    "is_alternative_to" => "is_originator_of",
    "goes_well_with"    => "goes_well_with",
    "used_on"           => "uses",
    "works_with"        => "works_with"
  }
  
  property :id, Serial
  property :name, String
  property :value, String, :required => true

  belongs_to :company
  belongs_to :product, :model => "DefinitiveProduct", :child_key =>[:definitive_product_id]
  belongs_to :property_definition
  
  validates_present :definitive_product_id
  validates_within :name, :set => NAMES.keys
  validates_is_unique :value, :scope => [:company_id, :definitive_product_id, :property_definition_id, :name]
  
  validates_with_block :property_definition, :if => :property_definition do
    property_definition.text? || [false, "should be a text property"]
  end
  
  def self.related_products(product)
    product_ids_by_relationship = {}
    
    # forward reference relationships
    query =<<-EOS
      SELECT r.name, p.id
      FROM relationships r
        INNER JOIN products p
          ON r.value = p.reference
          AND IF(r.company_id IS NULL, TRUE, r.company_id = p.company_id)
      WHERE r.definitive_product_id = ?
        AND r.property_definition_id IS NULL
        AND p.id != ?
        AND p.type = 'DefinitiveProduct'
    EOS
    repository.adapter.select(query, product.id, product.id).each do |record|
      product_ids = (product_ids_by_relationship[record.name] ||= [])
      product_ids << record.id
    end
    
    # forward property relationships
    query =<<-EOS
      SELECT r.name, p.id
      FROM relationships r
        INNER JOIN products p
          ON IF(r.company_id IS NULL, TRUE, r.company_id = p.company_id)
        INNER JOIN property_values pv
          ON r.property_definition_id = pv.property_definition_id
          AND r.value = pv.text_value
          AND p.id = pv.product_id
      WHERE r.definitive_product_id = ?
        AND r.property_definition_id IS NOT NULL
        AND p.id != ?
        AND p.type = 'DefinitiveProduct'
        AND pv.text_value IS NOT NULL
    EOS
    repository.adapter.select(query, product.id, product.id).each do |record|
      product_ids = (product_ids_by_relationship[record.name] ||= [])
      product_ids << record.id
    end
    
    # backward reference relationships
    query =<<-EOS
      SELECT r.name, r.definitive_product_id
      FROM relationships r
      WHERE (r.company_id IS NULL OR r.company_id = ?)
        AND r.definitive_product_id != ?
        AND r.property_definition_id IS NULL
        AND r.value = ?
    EOS
    repository.adapter.select(query, product.company_id, product.id, product.reference).each do |record|
      implied_name = (NAMES[record.name] || record.name)
      product_ids = (product_ids_by_relationship[implied_name] ||= [])
      product_ids << record.definitive_product_id
    end

    # backward property relationships
    query =<<-EOS
      SELECT r.name, r.definitive_product_id
      FROM relationships r
        INNER JOIN property_values pv
          ON r.property_definition_id = pv.property_definition_id
          AND r.value = pv.text_value
      WHERE (r.company_id IS NULL OR r.company_id = ?)
        AND r.definitive_product_id != ?
        AND r.property_definition_id IS NOT NULL
        AND pv.product_id = ?
    EOS
    repository.adapter.select(query, product.company_id, product.id, product.id).each do |record|
      implied_name = (NAMES[record.name] || record.name)
      product_ids = (product_ids_by_relationship[implied_name] ||= [])
      product_ids << record.definitive_product_id
    end
    
    products_by_id = {}
    DefinitiveProduct.all(:id => product_ids_by_relationship.values.flatten).each do |product|
      products_by_id[product.id] = product
    end
    
    products_by_relationship = {}
    product_ids_by_relationship.each do |name, product_ids|
      products_by_relationship[name] = product_ids.uniq.map { |product_id| products_by_id[product_id] }
    end
    products_by_relationship
  end
end

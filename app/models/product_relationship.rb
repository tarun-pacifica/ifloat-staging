# = Summary
#
# In order to support both auto-assemblies (hiearchies of products) and other less concrete groupings (like marketing categories), Products may have many ProductRelationships. Each ProductRelationship links a Product to any other that has a matching TextPropertyValue for a given PropertyDefinition.
#
# The TextPropertyValue match may be limited to a specific Company. This copes with instances where, for example, one Product is 'used_on' another whose reference:manufacturer is only meaningful in the context of a specific Company. Put another way, specifying a Company as part of the relationship will limit the returned, related Products to only those from that Company.
#
# See NAMES (the keys) for a list of relationships that can be specified. Note that the values include any 'implied' relationship names that correspond to a given relationship but in the opposite direction and that are generated exclusively by the system. All relationship names form the middle part of the sentence 'product 1 ... product 2' and so necessarily start with a verb.
#
# === Sample Data
#
# name:: 'used_on'
# value:: 'PF223423G'
#
class ProductRelationship
  include DataMapper::Resource
  
  # parent *includes* child:: child _is_included_in_ parent
  # generic *is_alternative_to* oem:: oem _is_originator_of_ generic
  # sibling *goes_well_with* sibling:: [bidirectional]
  # child *used_on* parent:: parent _uses_ child
  # sibling *works_with* sibling:: [bidirectional]
  NAMES = {
    "includes"          => "is_included_in",
    "is_alternative_to" => "is_alternative_to",
    "goes_well_with"    => "goes_well_with",
    "used_on"           => "uses",
    "uses"              => "used_on",
    "works_with"        => "works_with"
  }
  
  property :id, Serial
  property :name, String, :unique_index => :val_per_company_per_prod_per_prop_per_name
  property :value, String, :required => true, :unique_index => :val_per_company_per_prod_per_prop_per_name, :index => true
  property :bidirectional, Boolean, :required => true # TODO: spec

  belongs_to :company, :required => false
    property :company_id, Integer, :unique_index => :val_per_company_per_prod_per_prop_per_name
  belongs_to :product
    property :product_id, Integer, :unique_index => :val_per_company_per_prod_per_prop_per_name
  belongs_to :property_definition, :required => false
    property :property_definition_id, Integer, :unique_index => :val_per_company_per_prod_per_prop_per_name
  
  validates_within :name, :set => NAMES.keys.to_set
  
  # TODO: spec
  def self.compile_index
    queries = []
    
    # reference relationships
    queries << <<-SQL
      SELECT r.product_id AS source_id, r.name, r.bidirectional, p.id AS target_id
      FROM product_relationships r
        INNER JOIN products p
          ON r.value = p.reference
          AND IF(r.company_id IS NULL, TRUE, r.company_id = p.company_id)
      WHERE r.product_id != p.id
        AND r.property_definition_id IS NULL
    SQL
    
    # property relationships
    queries << <<-SQL
      SELECT r.product_id AS source_id, r.name, r.bidirectional, p.id AS target_id
      FROM product_relationships r
        INNER JOIN products p
          ON IF(r.company_id IS NULL, TRUE, r.company_id = p.company_id)
        INNER JOIN property_values pv
          ON r.property_definition_id = pv.property_definition_id
          AND r.value = pv.text_value
          AND p.id = pv.product_id
      WHERE r.product_id != p.id
        AND r.property_definition_id IS NOT NULL
        AND pv.text_value IS NOT NULL
    SQL
    
    target_ids_by_name_by_source_id = {}
    
    queries.each do |query|
      repository.adapter.select(query).each do |record|
        relationships = [[record.source_id, record.name, record.target_id]]
        relationships << [record.target_id, NAMES[record.name], record.source_id] if record.bidirectional
        
        relationships.each do |source_id, name, target_id|
          target_ids_by_name = (target_ids_by_name_by_source_id[source_id] ||= {})
          target_ids = (target_ids_by_name[name] ||= [])
          target_ids << target_id
        end
      end
    end
    
    target_ids_by_name_by_source_id.each do |source_id, target_ids_by_name|
      target_ids_by_name.each { |name, target_ids| target_ids.uniq! }
    end
  end
  
  def self.related_products(product)
    product_ids_by_relationship = {}
    
    # forward reference relationships
    query =<<-EOS
      SELECT r.name, p.id
      FROM product_relationships r
        INNER JOIN products p
          ON r.value = p.reference
          AND IF(r.company_id IS NULL, TRUE, r.company_id = p.company_id)
      WHERE r.product_id = ?
        AND r.property_definition_id IS NULL
        AND p.id != ?
    EOS
    repository.adapter.select(query, product.id, product.id).each do |record|
      product_ids = (product_ids_by_relationship[record.name] ||= [])
      product_ids << record.id
    end
    
    # forward property relationships
    query =<<-EOS
      SELECT r.name, p.id
      FROM product_relationships r
        INNER JOIN products p
          ON IF(r.company_id IS NULL, TRUE, r.company_id = p.company_id)
        INNER JOIN property_values pv
          ON r.property_definition_id = pv.property_definition_id
          AND r.value = pv.text_value
          AND p.id = pv.product_id
      WHERE r.product_id = ?
        AND r.property_definition_id IS NOT NULL
        AND p.id != ?
        AND pv.text_value IS NOT NULL
    EOS
    repository.adapter.select(query, product.id, product.id).each do |record|
      product_ids = (product_ids_by_relationship[record.name] ||= [])
      product_ids << record.id
    end
    
    # backward reference relationships
    query =<<-EOS
      SELECT r.name, r.product_id
      FROM product_relationships r
      WHERE (r.company_id IS NULL OR r.company_id = ?)
        AND r.product_id != ?
        AND r.property_definition_id IS NULL
        AND r.bidirectional = ?
        AND r.value = ?
    EOS
    repository.adapter.select(query, product.company_id, product.id, true, product.reference).each do |record|
      implied_name = (NAMES[record.name] || record.name)
      product_ids = (product_ids_by_relationship[implied_name] ||= [])
      product_ids << record.product_id
    end
  
    # backward property relationships
    query =<<-EOS
      SELECT r.name, r.product_id
      FROM product_relationships r
        INNER JOIN property_values pv
          ON r.property_definition_id = pv.property_definition_id
          AND r.value = pv.text_value
      WHERE (r.company_id IS NULL OR r.company_id = ?)
        AND r.product_id != ?
        AND r.property_definition_id IS NOT NULL
        AND r.bidirectional = ?
        AND pv.product_id = ?
    EOS
    repository.adapter.select(query, product.company_id, product.id, true, product.id).each do |record|
      implied_name = (NAMES[record.name] || record.name)
      product_ids = (product_ids_by_relationship[implied_name] ||= [])
      product_ids << record.product_id
    end
    
    products_by_id = Product.all(:id => product_ids_by_relationship.values.flatten).hash_by(:id)
    
    products_by_relationship = {}
    product_ids_by_relationship.each do |name, product_ids|
      products_by_relationship[name] = product_ids.uniq.map { |product_id| products_by_id[product_id] }
    end
    products_by_relationship
  end
end

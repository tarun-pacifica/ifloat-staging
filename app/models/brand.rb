# = Summary
#
# Brands are uniquely named per company and may carry a logo, a description and a primary URL.
#
# === Sample Data
#
# name:: 'Nauticalia'
# primary_url:: 'www.mybrand.com'
# description:: 'A fine seafaring brand.'
#
class Brand
  include DataMapper::Resource
  
  property :id, Serial
  property :name, String, :required => true, :length => 255, :unique_index => :name_per_company
  property :primary_url, String, :length => 255
  property :description, Text, :lazy => false
  
  belongs_to :asset
  belongs_to :company
    property :company_id, Integer, :required => true, :unique_index => :name_per_company
  
  before :destroy do
    asset.destroy unless asset.nil?
  end
  
  # TODO: if needed, augment to take a list of names_by_company_id to support brand namespace clashes
  def self.logos(names)
    Asset.all("brands.name" => names)
  end
  
  def indexer
    Indexer
  end
  
  def product_ids_by_category_node(node_matcher)
    query =<<-SQL
      SELECT DISTINCT(product_id)
      FROM property_values
      WHERE property_definition_id = ?
        AND text_value = ?
    SQL
    
    product_ids = repository.adapter.select(query, indexer.brand_property_id, name).to_set
    product_ids_by_node = {}
    walk_category_tree_for_product_ids(product_ids) do |node, node_product_ids|
      product_ids_by_node[node] = node_product_ids.to_a if node_matcher.zip(node).all? { |m, n| m == n }
    end
    product_ids_by_node
  end
  
  
  private
  
  def walk_category_tree_for_product_ids(product_ids, node = [], &block)
    children = indexer.category_children_for_node(node)
    if children.first.is_a?(Integer)
      node_product_ids = (product_ids & children)
      block.call(node, node_product_ids) unless node_product_ids.empty?
    else
      children.each { |c| walk_category_tree_for_product_ids(product_ids, node + [c], &block) }
    end
  end
end

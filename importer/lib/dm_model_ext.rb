require "tsort"

module DataMapper::Model
  def property_names_by_child_key
    Hash[relationships.map { |rel| [rel.child_key.first.name, rel.name.to_sym] }]
  end
  
  def self.sorted_descendants(extra_rules = {})
    models = (descendants.to_a + descendants.map { |d| d.descendants.to_a }).flatten.uniq.extend(TSort)
    models.instance_variable_set("@extra_rules", extra_rules)
    
    def models.tsort_each_node(&block); each(&block); end
    
    def models.tsort_each_child(node, &block)
      children = select { |m| m.relationships.any? { |rel| rel.parent_model == node } }
      (children + (@extra_rules[node] || [])).each(&block)
    end
    
    models.tsort.reverse
  end
end

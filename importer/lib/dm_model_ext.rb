require "tsort"

module DataMapper::Model
  def self.sorted_descendants(extra_rules = {})
    models = (descendants.to_a | descendants.map { |d| d.descendants.to_a }).extend(TSort)
    models.instance_variable_set("@extra_rules", extra_rules)
    
    def models.tsort_each_node(&block); each(&block); end
    
    def models.tsort_each_child(node, &block)
      children = select { |m| m.relationships.any? { |name, rel| rel.parent_model == node } }
      (children + (@extra_rules[node] || [])).each(&block)
    end
    
    models.tsort.reverse
  end
end

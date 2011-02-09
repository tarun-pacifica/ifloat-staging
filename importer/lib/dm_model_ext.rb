require "tsort"

module DataMapper::Model
  def self.sorted_descendants(extra_rules = {})
    models = descendants.dup.extend(TSort)
    models.instance_variable_set("@extra_rules", extra_rules)
    
    def models.tsort_each_node(&block); each(&block); end
    
    # TODO: still not sorting right - UOM should come after PD, for example
    def models.tsort_each_child(node, &block)
      node.relationships.each do |name, relation|
        next unless relation.parent_model == node
        model = relation.child_model
        (model.descendants.to_a + (@extra_rules[node] || []) << model).each(&block)
      end
    end
    
    models.tsort.reverse
  end
end

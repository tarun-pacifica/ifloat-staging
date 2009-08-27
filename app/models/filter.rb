# = Summary
#
# A Filter keeps track of the filtering process of a CachedFind for a given PropertyDefinition and assists in deriving excluded products. <b>There should be no reason to create a Filter directly.</b>
#
# The subclasses are...
#
# NumericFilter:: keeps track of the min/max values per unit for a given numeric property
# TextFilter:: keeps track of the preferred language code for a given text property (and tracks exclusions through TextFilterExclusion objects)
#
# The only reason that Filter objects are persisted to the database is to allow a user to pick up where they left off. The advantage of breaking up a CachedFind by PropertyDefinition is that dependencies on specific definitions are immediately clear should the need arise to edit / delete them.
#
# = Processes
#
# === 1. Destroy Filters Belonging To Archived CachedFinds
#
# Run Filter.archived.each { |f| f.destroy } periodically. This will destroy all filters belonging to an archived CachedFind and any child TextFilterExclusions.
#
class Filter
  include DataMapper::Resource
  
  property :id, Serial
  property :type, Discriminator
  property :fresh, Boolean, :nullable => false, :default => true
  
  belongs_to :cached_find
	belongs_to :property_definition
	
	validates_present :cached_find_id, :property_definition_id
	validates_is_unique :property_definition_id, :scope => [:cached_find_id]
	
	validates_with_block :type do
    (self.class != Filter and self.kind_of?(Filter)) || [false, "must be a sub-class of Filter"]
  end
  
  def self.archived
    all(:cached_find_id => CachedFind.archived.map { |find| find.id })
  end
  
  # TODO: review whether this belongs in Product
  def self.product_ids_by_property_id(product_ids)
    return {} if product_ids.empty?
    
    query =<<-EOS
      SELECT DISTINCT property_definition_id, product_id
      FROM property_values
      WHERE product_id IN ?
    EOS
    
    product_ids_by_pid = {}
    repository.adapter.query(query, product_ids).each do |record|
      (product_ids_by_pid[record.property_definition_id] ||= []) << record.product_id
    end
    product_ids_by_pid
  end
end

# = Summary
#
# A UnitOfMeasure relates a given unit to a class and property so that pricing can be interpreted per UOM as appropriate.
#
# === Sample Data
#
# class_name:: 'Paint'
# unit:: 'l'
#
class UnitOfMeasure
  include DataMapper::Resource
  
  property :id, Serial
  property :class_name, String, :required => true, :unique_index => true
  property :unit, String, :required => true
  
  belongs_to :property_definition
  
  # TODO: spec
  def self.unit_and_divisor_by_product_id(product_ids)
    # TODO: cache this in the Indexer
    uoms = UnitOfMeasure.all
    uoms_by_class = uoms.hash_by(:class_name)
    
    property_ids = uoms.map { |uom| uom.property_definition_id }.to_set
    property_ids << Indexer.class_property_id
    
    pdc = Indexer.property_display_cache
    
    ud_by_product_id = {}
    Product.values_by_property_name_by_product_id(product_ids, "ENG", property_ids).each do |product_id, values_bpn|
      class_name = (values_bpn["reference:class"].first.to_s rescue nil)
      uom = uoms_by_class[class_name]
      next if uom.nil?
      
      property_name = Indexer.property_display_cache[uom.property_definition_id][:raw_name]
      uom_value = (values_bpn[property_name].find { |v| v.unit == uom.unit } rescue nil)
      ud_by_product_id[product_id] = [uom.unit, uom_value.nil? ? nil : uom_value.min_value]
    end
    ud_by_product_id
  end
end

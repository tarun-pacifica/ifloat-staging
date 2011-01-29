# = Summary
#
# Title auto-construction in the system is handled by means of TitleStrategy objects. These strategies take the forms of very simple build instructions per auto-constructed title (of which there are four per product). The strategy employed for a given product is entirely dependent on it's class. One TitleStrategy may apply to many classes but each class has either no or one TitleStrategy.
#
# For performance reasons, the entire suite of strategies is applied to every product at import time so that these objects are never referenced directly during the normal operation of the application.
#
# === Sample Data
#
# class_name:: 'block'
# sequence_number:: 1
# property_names:: ['appearance:colour_primary', 'appearance:colour_secondary']
#
class PropertyHierarchy
  include DataMapper::Resource
  
  property :id,              Serial
  property :class_name,      String,  :required => true, :unique_index => :seq_num_per_class
  property :sequence_number, Integer, :required => true, :unique_index => :seq_num_per_class
  property :property_names,  Object,  :required => true, :lazy => false
  
  validates_with_block :property_names do
    property_names.is_a?(Array) and property_names.all? { |name| name =~ PropertyDefinition::NAME_FORMAT } ||
      [false, "Value should be an array containing property names"]
  end
end

# = Summary
#
# All data associated with a Product is managed as a PropertyValue subclass. <b>PropertyValue itself is abstract and should never be created directly.</b> PropertyValues track primary data as well as pertinent meta-information that depends upon the exact subclass employed...
#
# TextPropertyValue:: All textual (free form) data is stored using this class. It carries a language code which should be set to ENG in any ambiguous cases as per the default values discussion in CachedFind.
# NumericPropertyValue:: It holds any scalar or range value that can be expressed as a decimal. It carries a unit (which must be found in the valid_units list of the ultimate PropertyType the value belongs to). It also carries a tolerance (+/-) which, when not nil, indicates the variation in the measurement provided and is deemed to be in the same unit as the primary value. Note that currency values should be stored using this class (the currencies themeselves being regarded as units).
# DatePropertyValue:: A specific subclass of NumericPropertyValue that returns a structured [year, month, day] as its value and stores the date in the database in a manner that supports direct comparison operations. It should never have a tolerance. It allows for the specification of year-only (YYYY0000), year-month (YYYYMM00) and year-month-day (YYYYMMDD) values.
#
# One Product may have many PropertyValues of the same PropertyDefinition. Take the example of a shoe which has only one Product (with one reference) but comes in many sizes. In this case, multiple NumericPropertyValues would exist with differing values but all belonging to the same shoe-size PropertyDefinition. It is not permitted to create multiple numeric / text PropertyValues for a single Product and PropertyDefinition where the primary value of those objects is the same. In other words, a car cannot be tagged as being available in 'red' more than once.
#
# In order to support the import / export process (particularly for Products), the import 'sequence number' can optionally be recorded in the PropertyValue. The sense of this data is that a group of values with the same sequence number, PropertyDefinition and Product form a cluster of differing views of one unique value. Because sequence numbers are an optional artefact of the import process, the are no in-model data integrity rules surrounding them.
#
# Even though ranges are supported directly, discrete numeric sequences such as shoe sizes should be stored as sets of individual NumericPropertyValues. Whilst less space efficient, this approach makes PropertyValue lookup / search refinement vastly easier to program. It also copes with arbitrary divisions, sequence gaps and other practical annoyances found in real-world ranges.
#
# Where values need to be rationalised to make items more findable for the consumer, the bias should be towards preserving the manufacturers original data but recording the simplified values in their own companion property...
#
# aesthetic:colour:: 'Parisian Moulet'
# aesthetic:simplified_colour:: 'White'
#
# This approach has the advantage that it allows for unambiguous translation into other languages (so that those responsible for data entry are not tasked with having to derive the German equivalent of 'Parisian Moulet').
#
# In terms of rationalisation, it has been agreed that common synonyms will be rationalised at data-entry time. Thus instead of having to build a complex, multi-dimensional synonym model, data will standardised (i.e. descriptions will always refer to 'left' rather than 'port').
#
# === Sample Data
#
# *TextPropertyValue*
#
# language_code:: 'ENG'
# value:: 'red'
#
# *NumericPropertyValue*
#
# unit:: 'kg'
# value:: 12.2..15.6
# tolerance:: 0.05
# sequence_number:: 1
# 
class PropertyValue
  include DataMapper::Resource
  
  property :id, Serial
  property :type, Discriminator
  property :auto_generated, Boolean, :required => true
  property :sequence_number, Integer, :required => true
  
  belongs_to :product
    property :product_id, Integer, :required => true # TODO: investigate why inherited models require this
  belongs_to :definition, :model => "PropertyDefinition", :child_key => [:property_definition_id]
    property :property_definition_id, Integer, :required => true # TODO: ditto
  
  validates_with_block :type do
    (self.class != PropertyValue and self.kind_of?(PropertyValue)) || [false, "Type must be a sub-class of PropertyValue"]
  end
end

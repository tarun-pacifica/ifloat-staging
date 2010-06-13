# = Summary
#
# Title auto-construction in the system is handled by means of TitleStrategy objects. These strategies take the forms of very simple build instructions per auto-constructed title (of which there are four per product). The strategy employed for a given product is entirely dependent on it's class. One TitleStrategy may apply to many classes but each class has either no or one TitleStrategy.
#
# For performance reasons, the entire suite of strategies is applied to every product at import time so that these objects are never referenced directly during the normal operation of the application.
#
# === Sample Data
#
# name:: 'Deckgear-01'
# class_names:: ['block', 'fiddle block', ...]
# title_1:: ['reference:class']
# title_2:: [...]
# title_3:: [...]
# title_4:: ['marketing:brand', 'marketing:range', 'marketing:model', 'marketing:edition']
#
class TitleStrategy
  include DataMapper::Resource
  
  property :id, Serial
  property :name, String, :required => true, :unique_index => true
  property :class_names, Object, :lazy => false, :required => true, :default => []
  
  TITLE_PROPERTIES = (1..6).to_a.map { |i| "title_#{i}".to_sym }
  TITLE_PROPERTIES.each do |title|
    property title, Object, :lazy => false, :default => []
  end
  
  validates_with_block :class_names, :if => :class_names do
    class_names.is_a?(Array) and class_names.all? { |name| name.is_a?(String) and name.size > 0 } ||
      [false, "Class names should be an array of class names"]
  end
  
  TITLE_PROPERTIES.each do |title|
    validates_with_block title do
      validate_title(attribute_get(title))
    end
  end
  
  # TODO: spec
  def validate_title(title)
    title.is_a?(Array) and title.all? { |part| name.is_a?(Integer) or name = "-" } ||
      [false, "Title should be an array containing PropertyDefinition IDs and (optionally) '-'s"]
  end
end

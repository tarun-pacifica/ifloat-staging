# = Summary
#
# Title auto-construction in the system is handled by means of TitleStrategy objects. These strategies take the forms of very simple build instructions per auto-constructed title (of which there are four per product). The strategy employed for a given product is entirely dependent on it's class. One TitleStrategy may apply to many classes but each class has either no or one TitleStrategy.
#
# For performance reasons, the entire suite of strategies is cached inside the class and only updated every EXPIRY_TIME seconds.
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
  
  EXPIRY_TIME = 5.minutes
  
  @@cache = {}
  @@cache_time = nil
  
  property :id, Serial
  property :name, String, :nullable => false, :unique => true
  property :class_names, Yaml, :lazy => false, :nullable => false, :default => []
  
  TITLE_PROPERTIES = (1..4).to_a.map { |i| "title_#{i}".to_sym }
  TITLE_PROPERTIES.each do |title|
    property title, Yaml, :lazy => false, :default => []
  end
  
  validates_with_block :class_names, :if => :class_names do
    class_names.is_a?(Array) and class_names.all? { |name| name.is_a?(String) and name.size > 0 } ||
      [false, "should be an array of class names"]
  end
  
  TITLE_PROPERTIES.each do |title|
    validates_with_block title do
      validate_title(attribute_get(title))
    end
  end
  
  # TODO: spec
  def self.generate_titles(values_by_property)
    ensure_cache
    
    properties_by_name = {}
    klass = nil
    values_by_property.each do |property, values|
      properties_by_name[property.name] = property
      klass = values.first if property.name == "reference:class"
    end
    
    strategy = @@cache[klass]
    strategy ||= @@cache["ANY_CLASS"]
    return {} if strategy.nil?
    
    titles = {}
    TITLE_PROPERTIES.each do |title|
      rendered_parts = []
      
      strategy.attribute_get(title).each do |part|
        if part == "SEP"
          rendered_parts << "SEP" unless rendered_parts.empty? or rendered_parts.last == "SEP"
        else
          property = properties_by_name[part]
          values = (values_by_property[property] || [])
          next if values.empty?
          
          if property.text? then rendered_parts << values.join(", ")
          else rendered_parts += values
          end
        end
      end
      
      rendered_parts.pop while rendered_parts.last == "SEP"
      
      titles[title] = rendered_parts
    end
    titles
  end
  
  # TODO: spec
  def add_class(class_name)
    ensure_cache
    
    return false if @@cache.has_key?(class_name)
    self.class_names = class_names << class_name
    true
  end
  
  # TODO: spec
  def validate_title(title)
    title.is_a?(Array) and title.all? { |part| name.is_a?(Integer) or name = "-" } ||
      [false, "should be an array containing PropertyDefinition IDs and (optionally) '-'s"]
  end
  
  
  private
  
  def self.ensure_cache
    return unless @@cache_time.nil? or @@cache_time < EXPIRY_TIME.ago
    
    @@cache.clear
    @@cache_time = Time.now
    
    TitleStrategy.all.each do |strategy|
      strategy.class_names.each do |class_name|
        @@cache[class_name] = strategy
      end
    end
  end
end

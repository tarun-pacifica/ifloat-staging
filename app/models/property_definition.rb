# = Summary
#
# A PropertyDefinition defines one attribute that any Product may have. Fundamentally it is a named entity in a two-level namespace of the form 'domain:key'. It also carries some associated behavioural information (which describes its participation in the finding and filtering processes as well as whether it should form part of a product's displayed data). It belongs to a PropertyType which governs the associated PropertyValues' storage and unit semantics.
#
# Names shoud be allocated with deference to the following guidelines...
#
# 1. The first-level name should be applicable as a section heading when presenting data ('physical', 'environmental', 'electrical', 'aesthetic').
# 2. The second-level name should lend itself to labelling values and filtering controls ('weight_max', 'size', 'colour_simplified').
# 3. PropertyDefinitions should be allocated conservatively and opportunities for re-use should be agressively pursued.
#
# Presentation versions of the names of PropertyDefinitions are stored as Translation objects (including an English version). If no such translation exists, the presentation system falls back to splitting up the internal PropertyDefinition name and using the resulting values.
#
# === FAQs
#
# <b>1. Can different PropertyValues (particularly those from different PropertyDefinitions) be associated?</b>
#
# Not directly, no. So far, situations involving related values (such as gold : 50%) have been coped with through the careful sequencing of PropertyDefinitions (so that one appear after the other). This approach is 'good enough' as long as a single product does not carry multiple values against such PropertyDefinitions (such as gold, lead, arsenic : 10%, 15%, 25%).
#
# === Sample Data
#
# name:: 'marketing:range'
# findable:: true
# filterable:: true
# display_as_data:: true
#
class PropertyDefinition
  include DataMapper::Resource
  
  NAME_FORMAT = /^[a-z]{3,}:[a-z_]{3,}$/
  
  property :id, Serial
  property :name, String, :required => true, :format => NAME_FORMAT, :unique => true
  property :findable, Boolean, :default => false
  property :filterable, Boolean, :default => false
  property :display_as_data, Boolean, :default => false
  property :sequence_number, Integer, :required => true
  
  belongs_to :property_type
  has n, :values, :model => "PropertyValue"
  has n, :translations
  
  # TODO: spec
  def self.definitions_by_property_id(properties, language_code)
    return {} if properties.empty?
    
    query =<<-EOS
      SELECT pd.id, pvd.value, pvd.definition
      FROM property_value_definitions pvd
        INNER JOIN property_types pt ON pvd.property_type_id = pt.id
        INNER JOIN property_definitions pd ON pt.id = pd.property_type_id
      WHERE pvd.language_code = ?
        AND pd.id IN ?
    EOS
    
    dbpi = {}
    repository.adapter.select(query, language_code, properties.map { |p| p.id }).each do |record|
      (dbpi[record.id] ||= {})[record.value] = record.definition
    end
    dbpi
  end
  
  def self.friendly_name_sections(properties, language_code)
    property_ids = properties.map { |property| property.id }
    
    translated_names = {}
    Translation.all(:property_definition_id => property_ids, :language_code => language_code).each do |translation|
      translated_names[translation.property_definition_id] = translation.value
    end
    
    friendly_names = {}
    properties.each do |property|
      translation = translated_names[property.id]
      friendly_names[property.id] = (translation || property.name).split(":")
    end
    friendly_names
  end
  
  # TODO: spec
  def self.icon_urls_by_property_id(properties)
    properties_by_asset_name = {}
    properties.each do |property|
      properties_by_asset_name[property.name.tr(":", "_") + ".png"] = property
    end
    
    urls = {}
    Asset.all(:bucket => "property_icons", :name => (properties_by_asset_name.keys + ["blank.png"])).each do |asset|
      if asset.name == "blank.png" then urls.default = asset.url
      else urls[properties_by_asset_name[asset.name].id] = asset.url
      end
    end
    urls
  end
  
  def date?
    property_type.value_class.date?
  end
  
  def text?
    property_type.value_class.text?
  end
end

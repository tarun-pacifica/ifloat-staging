# = Summary
#
# Facility objects track the various outlets and places of business a Company may have. They model real premises as well as virtual outlets like e-stores. Note that an Employee who frequents multiple facilities on behalf of their Company would best be allocated to the 'HQ' facility (or similar).
#
# Primary URLs act as a unique identifier for tracking purchases (and jumpout behaviour) with e-stores. They must be set to the actual URL location of an e-store minus any session specific data. In addition, a purchase TTL (in days) is set to control how long after the last interaction with the site a claim should be made on a pure trackback purchase.
#
# Facilities act as co-ordinating objects for a Company's inventory of FacilityProducts, any tracked Purchase and the Employees of a Company. They may have a Location.
#
# === Sample Data
#
# name:: 'The Big Boats On-line Store'
# primary_url:: 'store.bigboats.co.uk'
# description:: 'A marvelous array of fishy things.'
# purchase_ttl:: 60
#
class Facility
  include DataMapper::Resource
  
  property :id,           Serial
  property :name,         String,  :required => true, :unique_index => :name_per_company
  property :primary_url,  String,  :length => 255, :unique_index => true
  property :description,  Text,    :lazy => false
  property :purchase_ttl, Integer, :required => true
  
  belongs_to :company
    property :company_id, Integer, :required => true, :unique_index => :name_per_company
  belongs_to :location, :required => false
  has n, :employees
  has n, :products, :model => "FacilityProduct"
  has n, :purchases
  
  def product_ids_for_refs(references)
    return [] if references.empty?
    
    query =<<-SQL
      SELECT product_id
      FROM product_mappings
      WHERE company_id = ?
        AND (reference IN ? OR SUBSTRING_INDEX(reference, ';', 1) IN ?)
    SQL
    repository.adapter.select(query, company_id, references, references)
  end
  
  def product_mappings(product_ids)
    mappings = ProductMapping.all(:company_id => company_id, :product_id => product_ids)
    return [] if mappings.empty? # TODO: spec - was returning a hash previously
    
    query = "SELECT reference FROM facility_products WHERE facility_id = ? AND reference IN ?"
    all_refs = mappings.map { |m| m.reference_parts.first }
    available_refs = repository.adapter.select(query, id, all_refs).map { |r| r.upcase }.to_set
    mappings.select { |m| available_refs.include?(m.reference_parts.first.upcase) }
  end
  
  def product_url(mapping)
    case primary_url
    when "marinestore.co.uk"
      query_url("Screen" => "PROD", "Store_Code" => "mrst", "Product_Code" => mapping.reference_parts.first)
    end
  end
  
  def product_urls_by_id(mappings)
    Hash[mappings.map { |m| [m.product_id, product_url(m)] }]
  end
  
  # TODO: respec now this takes mappings_with_quantites rather than just mappings
  def purchase_urls(mappings_with_quantites)
    return [] if mappings_with_quantites.empty?
    
    case primary_url
    when "marinestore.co.uk"
      endpoint = "http://marinestore.co.uk/Merchant2/merchant.mvc"
      mappings_with_quantites.map do |mapping, quantity|
        query = {"Action" => "ADPR", "Screen" => "BASK", "Store_Code" => "mrst", "Quantity" => quantity.to_s}
        query["Product_Code"], variations = mapping.reference_parts
        variations.each_with_index do |kv, i|
          query["Product_Attributes[#{i}]:code"] = kv[0]
          query["Product_Attributes[#{i}]:value"] = kv[1]
        end
        query_url(query)
      end << query_url("Screen" => "CHECKOUT", "Store_Code" => "mrst")
    else []
    end
  end
  
  def query_url(params)
    uri_params =
      case primary_url
      when "marinestore.co.uk"
        {:scheme => "http", :host => "marinestore.co.uk", :path => "/Merchant2/merchant.mvc"}
      end
    uri = Addressable::URI.new(uri_params || {})
    uri.query_values = params unless uri_params.nil?
    uri
  end
  
  def update_products(product_info_by_ref)
    reports = []
    
    adapter = repository.adapter
    transaction = DataMapper::Transaction.new(adapter)
    transaction.begin
    adapter.push_transaction(transaction)
    
    existing_products_by_ref = products.all.hash_by { |product| product.reference }
    new_refs = product_info_by_ref.keys.to_set
    products.all(:reference => existing_products_by_ref.keys.to_set - new_refs).destroy!
    
    product_info_by_ref.each do |ref, info|
      product = existing_products_by_ref[ref] || products.new(:reference => ref)
      product.price = BigDecimal.new(info[:price]) # explicit conversion required to avoid triggering dirty-detection
      product.currency = "GBP"
      
      [:title, :image_url, :description].each do |a|
        new_val, old_val = info[a].unpack("C*").pack("U*"), product.attribute_get(a)
        next if new_val == old_val
        product.attribute_set(a, new_val)
        reports << [ref, "updated: #{a}", "from #{old_val.inspect}", "to #{new_val.inspect}"]
      end
      
      product.save
    end
    
    adapter.pop_transaction
    transaction.commit
    
    mappings_by_fp_ref = ProductMapping.all(:company_id => company_id).group_by { |pm| pm.reference_parts.first.upcase }
    product_ids = mappings_by_fp_ref.values.flatten.map { |mapping| mapping.product_id }
    classes_by_product_id = {}
    Product.values_by_property_name_by_product_id(product_ids, "ENG", "reference:class").each do |product_id, vbpn|
      classes_by_product_id[product_id] = vbpn["reference:class"].first.to_s
    end
    
    mapped_refs = mappings_by_fp_ref.keys.to_set
    (new_refs - mapped_refs).each do |ref|
      fields = product_info_by_ref[ref].values_at(:classification, :title, :description, :image_url)
      reports << fields.unshift(ref, "unmapped reference")
    end
    (mapped_refs - new_refs).each do |ref|
      classes = mappings_by_fp_ref[ref].map { |mapping| classes_by_product_id[mapping.product_id] }.uniq.sort.join(", ")
      reports << [ref, "obsolete mapped reference", "classes: #{classes}"]
    end
    
    reports
  end
end

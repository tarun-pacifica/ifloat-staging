# = Summary
#
# Facility objects track the various outlets and places of business a Company may have. They model real premises as well as virtual outlets like e-stores. Note that an Employee who frequents multiple facilities on behalf of their Company would best be allocated to the 'HQ' facility (or similar).
#
# Primary URLs act as a unique identifier for tracking purchases (and jumpout behaviour) with e-stores. They must be set to the actual URL location of an e-store minus any session specific data.
#
# Facilities act as co-ordinating objects for a Company's inventory of FacilityProducts, any tracked Purchase and the Employees of a Company. They may have a Location.
#
# === Sample Data
#
# name:: 'The Big Boats On-line Store'
# primary_url:: 'store.bigboats.co.uk'
#
class Facility
  include DataMapper::Resource
  
  property :id, Serial
  property :name, String, :required => true, :unique_index => :name_per_company
  property :primary_url, String, :length => 255, :unique_index => true
  
  belongs_to :company
    property :company_id, Integer, :unique_index => :name_per_company
  belongs_to :location, :required => false
  has n, :employees
  has n, :products, :model => "FacilityProduct"
  has n, :purchases
  
  # TODO: spec
  def map_products(product_ids)
    pids_by_fp_ref = {}
    ProductMapping.all(:company_id => company_id, :product_id => product_ids).each do |mapping|
      (pids_by_fp_ref[mapping.reference] ||= []).push(mapping.product_id)
    end
    
    fps_by_pid = {}
    products.all(:reference => pids_by_fp_ref.keys).each do |product|
      pids_by_fp_ref[product.reference].each do |product_id|
        fps_by_pid[product_id] = product
      end
    end
    fps_by_pid
  end
  
  # TODO: spec
  def map_references(references)
    pids_by_fp_ref = {}
    ProductMapping.all(:company_id => company_id, :reference => references).each do |mapping|
      (pids_by_fp_ref[mapping.reference] ||= []).push(mapping.product_id)
    end
    pids_by_fp_ref
  end
  
  # TODO: spec
  def update_products(product_info_by_ref)
    reports = []
    
    adapter = repository.adapter
    transaction = DataMapper::Transaction.new(adapter)
    transaction.begin
    adapter.push_transaction(transaction)
  
    # TODO: switch to the simpler form when the call to save below stops triggering the facility's validations
    # http://datamapper.lighthouseapp.com/projects/20609-datamapper/tickets/1154
    # existing_products_by_ref = products.all.hash_by { |product| product.reference }
    existing_products_by_ref = FacilityProduct.all(:facility_id => id).hash_by { |product| product.reference }

    new_refs = product_info_by_ref.keys.to_set
    products.all(:reference => existing_products_by_ref.keys.to_set - new_refs).destroy!
  
    product_info_by_ref.each do |ref, info|
      # TODO: see above
      # product = existing_products_by_ref[ref] || products.new(:reference => ref)
      product = existing_products_by_ref[ref] || FacilityProduct.new(:facility_id => id, :reference => ref)
      product.price = info[:price]
      product.currency = "GBP"
      
      [:title, :image_url, :description].each do |a|
        old_val, new_val = product.attribute_get(a), info[a].unpack("C*").pack("U*")
        product.attribute_set(a, new_val)
        reports << [ref, "updated: #{a}", "from #{old_val.inspect}", "to #{new_val.inspect}"] unless old_val == new_val
      end
      
      product.save if product.new? or product.dirty? # TODO: remove when DM comes to its senses
    end

    adapter.pop_transaction
    transaction.commit
    
    mappings_by_fp_ref = ProductMapping.all(:company_id => company_id).group_by { |mapping| mapping.reference }
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

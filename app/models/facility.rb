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
  property :name, String, :required => true
  property :primary_url, String, :length => 255
  
  belongs_to :company
  belongs_to :location, :required => false
  has n, :employees
  has n, :products, :model => "FacilityProduct"
  has n, :purchases
  
  validates_is_unique :name, :scope => :company_id
  validates_is_unique :primary_url, :unless => proc { |f| f.primary_url.nil? }
    
  # TODO: add country support when needed (will need to relax the has 1 to a has n above)
  def map_products(definitive_product_ids)
    dpids_by_fp_ref = {}
    ProductMapping.all(:company_id => company_id, :definitive_product_id => definitive_product_ids).each do |mapping|
      dpids_by_fp_ref[mapping.reference] = mapping.definitive_product_id
    end
    
    fps_by_dpid = {}
    products.all(:reference => dpids_by_fp_ref.keys).each do |product|
      dpid = dpids_by_fp_ref[product.reference]
      fps_by_dpid[dpid] = product
    end
    fps_by_dpid
  end
  
  # TODO: spec
  def retrieve_products(data = nil)
    raise "logger block required" unless block_given?
    
    product_info_by_ref = {}
    
    case primary_url
    when "marinestore.co.uk"
      if data.nil?
        host, path = "marinestore.co.uk", "/marinestorechandlers.txt"
        yield [:info, "downloading manifest from #{host}#{path}"]
        begin
          response = Net::HTTP.get_response(host, path)
          raise "expected an HTTPSuccess but recieved an #{response.class}" unless response.kind_of?(Net::HTTPSuccess)
          data = response.body
        rescue Exception => e
          yield [:error, e.message]
          return nil
        end
      end
      
      lines = data.split("\n")
      yield [:info, "parsing #{lines.size} lines (#{data.size} bytes)"]
      
      header = lines.shift
      expected_header = "link\ttitle\tdescription\timage_link\tprice\tid\texpiration_date\tbrand\tcondition\tproduct_type"
      unless header == expected_header
        yield [:error, "expected header to be #{expected_header.inspect} but received #{header.inspect}"]
        return nil
      end
      
      expected_count = expected_header.split("\t").size
      lines.each do |line|
        fields = line.split("\t", -1)
        unless expected_count == fields.size
          yield [:error, "expected #{expected_count} fields but encountered #{fields.size} in #{line.inspect}"]
          next
        end
        product_info_by_ref[fields[5]] = {:price => fields[4]}
      end
      
    else raise "no import routine for #{primary_url} (#{name})"
    end
  
    product_info_by_ref
  end
  
  # TODO: spec
  def update_products(product_info_by_ref)
    adapter = repository.adapter
    transaction = DataMapper::Transaction.new(adapter)
    transaction.begin
    adapter.push_transaction(transaction)
  
    products.all(:reference.not => product_info_by_ref.keys).destroy!
    existing_products_by_ref = products.all.hash_by { |product| product.reference }
  
    product_info_by_ref.each do |ref, info|
      product = existing_products_by_ref[ref] || products.new(:reference => ref)
      product.price = info[:price]
      product.currency = "GBP"
      product.save
    end

    adapter.pop_transaction
    transaction.commit
  end
end

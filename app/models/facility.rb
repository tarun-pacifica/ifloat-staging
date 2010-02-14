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
      pids_by_fp_ref[mapping.reference] = mapping.product_id
    end
    
    fps_by_pid = {}
    products.all(:reference => pids_by_fp_ref.keys).each do |product|
      pid = pids_by_fp_ref[product.reference]
      fps_by_pid[pid] = product
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
  def parse_products(data)
    raise "logger block required" unless block_given?
    
    product_info_by_ref = {}
    
    case primary_url
    when "marinestore.co.uk"
      lines = data.split("\n")
      yield [:info, "parsing #{lines.size} lines (#{data.size} bytes)"]
      
      header = lines.shift
      expected_header = "link\ttitle\tdescription\timage_link\tprice\tid\texpiration_date\tbrand\tcondition\tproduct_type"
      unless header == expected_header
        yield [:error, "expected header to be #{expected_header.inspect} but received #{header.inspect}"]
        return nil
      end
      
      expected_count = expected_header.split("\t").size
      line_nums_by_ref = {}
      lines.each_with_index do |line, i|
        fields = line.split("\t", -1)
        unless expected_count == fields.size
          yield [:error, "expected #{expected_count} fields but encountered #{fields.size} in #{line.inspect}"]
          next
        end
        
        ref = fields[5].upcase
        unless ref =~ FacilityProduct::REFERENCE_FORMAT
          yield [:warn, "skipped line #{i} as reference #{ref.inspect} contains invalid characters"]
          next
        end
        
        line_num = line_nums_by_ref[ref]
        if line_num.nil?
          line_nums_by_ref[ref] = i
          product_info_by_ref[ref] = {:price => fields[4]}
        else
          yield [:warn, "skipped line #{i} as reference #{ref.inspect} already encountered on line #{line_num}"]
        end
      end
      
    else raise "no import routine for #{primary_url} (#{name})"
    end
  
    product_info_by_ref
  end
  
  # TODO: spec
  def retrieve_products
    raise "logger block required" unless block_given?
    
    case primary_url
      
    when "marinestore.co.uk"
      host, path = "marinestore.co.uk", "/marinestorechandlers.txt"
      yield [:info, "downloading manifest from #{host}#{path}"]
      begin
        response = Net::HTTP.get_response(host, path)
        raise "expected an HTTPSuccess but recieved an #{response.class}" unless response.kind_of?(Net::HTTPSuccess)
        response.body
      rescue Exception => e
        yield [:error, e.message]
        nil
      end
      
    end
  end
  
  # TODO: spec
  def update_products(product_info_by_ref)
    adapter = repository.adapter
    transaction = DataMapper::Transaction.new(adapter)
    transaction.begin
    adapter.push_transaction(transaction)
  
    products.all(:reference.not => product_info_by_ref.keys).destroy!
    # TODO: switch to the simpler form when the call to save below stops triggering the facility's validations
    # http://datamapper.lighthouseapp.com/projects/20609-datamapper/tickets/1154
    # existing_products_by_ref = products.all.hash_by { |product| product.reference }
    existing_products_by_ref = FacilityProduct.all(:facility_id => id).hash_by { |product| product.reference }
  
    product_info_by_ref.each do |ref, info|
      # TODO: see above
      # product = existing_products_by_ref[ref] || products.new(:reference => ref)
      product = existing_products_by_ref[ref] || FacilityProduct.new(:facility_id => id, :reference => ref)
      old_price = product.price
      product.price = info[:price]
      product.currency = "GBP"
      product.save if product.new? or product.dirty? # TODO: remove when DM comes to its senses
    end

    adapter.pop_transaction
    transaction.commit
  end
end

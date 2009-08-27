# = Summary
#
# Facility objects track the various outlets and places of business a Company may have. They model real premises as well as virtual outlets like e-stores. Note that an Employee who frequents multiple facilities on behalf of their Company would best be allocated to the 'HQ' facility (or similar).
#
# Primary URLs act as a unique identifier for tracking purchases (and jumpout behaviour) with e-stores. It must be set to the actual URL location of an e-store minus any session specific data.
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
  property :name, String, :nullable => false
  property :primary_url, String, :size => 255
  
  belongs_to :company
  belongs_to :location
  has n, :employees
  has n, :products, :class_name => "FacilityProduct"
  has n, :purchases
  
  validates_present :company_id
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
  
  def retrieve_products()
    raise "logger block required" unless block_given?
    
    products = {}
    
    case primary_url
    when "marinestore.co.uk"
      host, path = "marinestore.co.uk", "/marinestorechandlery-google.txt"
      
      yield "downloading manifest from #{host}#{path}"
      data = nil
      begin
        response = Net::HTTP.get_response(host, path)
        raise "expected an HTTPSuccess but recieved an #{response.class}" unless response.kind_of?(Net::HTTPSuccess)
        data = response.body
      rescue Exception => e
        yield e.message
        return nil
      end
      
      lines = data.split("\n")
      yield "parsing #{lines.size} lines (#{data.size} bytes)"
      
      header = lines.shift
      expected_header = "link\ttitle\tdescription\timage_link\tprice\tid\texpiration_date\tproduct_type\tcondition"
      unless header == expected_header
        yield "expected header to be #{expected_header.inspect} but received #{header.inspect}"
        return nil
      end
      
      expected_count = expected_header.split("\t").size
      lines.each do |line|
        fields = line.split("\t", -1)
        unless expected_count == fields.size
          yield "expected #{expected_count} fields but encountered #{fields.size} in #{line.inspect}"
          return nil
        end
        products[fields[5]] = {"sale:price:GBP" => [fields[4]]}
      end
      
    else raise "no import routine for #{primary_url} (#{name})"
    end
  
    products
  end
  
  def update_products(products_by_ref)
    raise "method needs complete overhaul and is currently incorrect and incomplete"
    
    existing_products = products.all.group_by { |product| product.reference }
        
    mapped_product_ids = {}
    ProductMapping.all(:reference => all_refs).each do |mapping|
      (mapped_products[mapping.reference] ||= Array.new) << mapping.definitive_product_id
    end
    
    actions = {}
    checksums = {}
    
    (existing_products.keys - products_by_ref.keys).each do |reference|
      actions[reference] = [:destroy]
    end
    
    products_by_ref.each do |reference, property_values|
      checksum = checksums[reference] = Digest::SHA1.hexdigest(property_values.sort.inspect)
      existing_product = existing_products[reference]
      def_product_ids = mapped_product_ids[reference]
      
      actions = (actions[reference] ||= [])
      
      if existing_product.nil?
        actions << (mapped_product_ids.nil? ? :add_fail_no_mapping : :add)
      else
        if def_product_ids.nil?
          actions << :destroy_no_mapping
        else
          actions << :reassign unless def_product_ids.include?(existing_product.definitive_product_id) # see note below
          actions << :update unless checksum == existing_product.import_checksum          
        end
      end
    end
      
    # TODO: do something with actions (wrap this in a transaction)
    actions.each do |reference, operations|
      operations.each do |operation|
        case operation
          
        when :add
          checksum = checksums[reference]
          mapped_product_ids.each do |def_product_id|
            ip = InventoryProduct.new(:definitive_product_id => def_product_id, :inventory => self, :reference => reference, :import_checksum => checksum)
            ip.save or (raise "failed to save #{reference.inspect}: #{ip.errors.full_messages.inspect}")
            # TODO: set values
          end
          
        when :destroy
          products.all(:reference => reference).destroy!
          
        when :reassign
          raise "not implemented"
          # the problem here is that we need to make sure that there is an identical inventory product for each mapping (where there are multiple mappings to different DefinitiveProducts) - :add takes care of this but we don't know at this stage whether we just need to re-assign n IPs to a new DP or... - we may need to make IP -> DP a many-to-many??? so that we only ever need one inventory product??? - allow IPs themselves to associate with region availability then get rid of facility inventories entirely - then retail products are IPs with properties retail:price = [5 GBP, 6 USD], and retail:countries = [GBR, DEU, FRA]
          
        when :update
          existing_products[reference]
        
        end
      end
    end
  end
end

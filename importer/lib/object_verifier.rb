class ObjectVerifier
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv row error)
  TEXT_PROP_NAMES = %w(auto:group_diff auto:title reference:category reference:class).to_set
  
  def initialize(csv_catalogue, object_catalogue)
    @csvs = csv_catalogue
    @objects = object_catalogue
    @errors = []
    
    @asset_checksums_by_ref          = {}
    @category_images                 = []
    @companies_by_ref                = {}
    @facilities_by_ref               = {}
    @primary_images_by_ref           = {}
    @products_by_ref                 = {}
    @text_values_by_prop_name_by_ref = {}
    @objects.each(&method(:add))
  end
  
  def add(ref, data)
    case data[:class].to_s
    
    when "Asset"
      @asset_checksums_by_ref[ref] = data[:checksum]
      @category_images << data if data[:bucket] == "category_images"
      
    when "Attachment"
      return unless data[:role] == "image" and data[:sequence_number] == 1
      @primary_images_by_ref[data[:product]] = data[:asset]
      
    when "Company"
      @companies_by_ref[ref] = data
      
    when "Facility"
      @facilities_by_ref[ref] = data
      
    when "Product"
      @products_by_ref[ref] = data
      
    when "TextPropertyValue"
      prop_name = data[:definition][:name] # OK that this triggers a data_for
      return unless TEXT_PROP_NAMES.include?(prop_name)
      text_values_by_prop_name = (@text_values_by_prop_name_by_ref[data[:product]] ||= {})
      (text_values_by_prop_name[prop_name] ||= []) << data
      
    end
  end
  
  def verify
    steps = %w(all_categories_have_images no_orphaned_purchases product_count_is_safe same_image_means_same_group unique_titles well_differentiated_siblings no_orphaned_picks)
    
    steps.each do |step|
      puts " - #{step.tr('_', ' ')}"
      send("verify_#{step}")
    end
  end
  
  def verify_all_categories_have_images
    cat_image_names = @category_images.map do |image|
      image[:name] =~ Asset::NAME_FORMAT ? $1 : raise("unable to parse #{o.attributes[:name]}")
    end.to_set
    
    prop_names = %w(reference:category reference:class)
    cat_names = @text_values_by_prop_name_by_ref.map do |ref, tvs_by_pn|
      tvs_by_pn.values_at(*prop_names).compact.flatten.map { |tv| tv[:text_value].downcase.tr(" ", "_") }
    end.flatten.to_set
    
    @errors += (cat_names - cat_image_names).sort.map { |n| [nil, nil, "no image provided for category #{n.inspect}"] }
  end
  
  def verify_no_orphaned_picks
    db_companies = Company.all.hash_by(:reference)
    orphaned_product_ids = []
    
    companies_by_ref = @companies_by_ref.values.hash_by { |c| c[:reference] }
    products_by_ref = @products_by_ref.values.hash_by { |p| p[:reference] }
    
    PickedProduct.all_primary_keys.each do |company_ref, product_ref|
      next if companies_by_ref.has_key?(company_ref)
      @errors << [nil, nil,"unable to delete company with user-referenced product: #{company_ref} / #{product_ref}"]
    end
  end
  
  def verify_no_orphaned_purchases
    companies_by_ref = @companies_by_ref.values.hash_by { |c| c[:reference] }
    facilities_by_name = @facilities_by_ref.values.hash_by { |f| f[:name] }
    
    Purchase.all_facility_primary_keys.each do |company_ref, facility_name|
      if (not companies_by_ref.has_key?(company_ref))
        @errors << [nil, nil, "unable to delete company with facility with user-referenced purchases: #{company_ref} / #{facility_url}"]
      elsif (not facilities_by_name.has_key?(facility_name))
        @errors << [nil, nil, "unable to delete facility with user-referenced purchases: #{company_ref} / #{facility_url}"]
      end
    end
  end
  
  def verify_product_count_is_safe
    @errors << [nil, nil, "> 50,000 products (sitemap would be invalid)"] if @products_by_ref.size > 50000
  end
  
  def verify_same_image_means_same_group
    first_refs_by_checksum = {}
    
    @primary_images_by_ref.each do |product_ref, asset_ref|
      checksum = @asset_checksums_by_ref[asset_ref]
      first_ref = first_refs_by_checksum[checksum]
      (first_refs_by_checksum[checksum] = product_ref and next) if first_ref.nil?
      
      fr_group, r_group = [first_ref, product_ref].map { |r| @products_by_ref[r][:reference_group] }
      next unless fr_group.nil? or fr_group != r_group
      
      problem = "their reference_group values differ (#{r_group.inspect} vs #{fr_group.inspect})"
      problem = "neither have a reference_group value set" if fr_group == r_group
      
      colliding_row_md5 = @objects.row_md5s_by_ref[ref].first
      @errors << error_for_row("has the same primary image as #{ident(first_ref)} but #{problem}", colliding_row_md5)
    end
  end
  
  def verify_unique_titles
    first_refs_by_value_by_heading = {}
    @text_values_by_prop_name_by_ref.each do |ref, tvs_by_pn|
      (tvs_by_pn["auto:title"] || []).each do |tv|
        heading = TitleStrategy::TITLE_PROPERTIES[tv[:sequence_number] - 1]
        next if heading == :image
        first_refs_by_value = (first_refs_by_value_by_heading[heading] ||= {})
        
        value = tv[:text_value]
        existing_ref = first_refs_by_value[value]
        if existing_ref.nil?
          first_refs_by_value[value] = ref
        else
          colliding_row_md5 = @objects.row_md5s_by_ref[ref].first
          @errors << error_for_row("has the same #{heading} title as #{ident(existing_ref)}: #{value}", colliding_row_md5)
        end
      end
    end
  end
  
  def verify_well_differentiated_siblings
    values_by_ref_by_group = {}
    
    @text_values_by_prop_name_by_ref.each do |ref, tvs_by_pn|
      group = @products_by_ref[ref].values_at(:company, :reference_group)
      values_by_ref = (values_by_ref_by_group[group] ||= {})
      text_values = tvs_by_pn["auto:group_diff"]
      next if text_values.nil?
      values_by_ref[ref] = text_values.sort_by { |tv| tv[:sequence_number] }.map { |tv| tv[:text_value] }
    end
    
    values_by_ref_by_group.each do |group, values_by_ref|
      next if values_by_ref.size == 1
      friendly_group = "#{@companies_by_ref[group[0]][:reference]} / #{group[1]}"
      
      values_by_ref.values.transpose.each_with_index do |diff_column, i|
        blank_count = diff_column.count { |v| v.blank? }
        next if blank_count == 0 or blank_count == diff_column.size
        colliding_row_md5 = @objects.row_md5s_by_ref[values_by_ref.keys.first].first
        @errors << error_for_row("differentiating values from property set #{i + 1} are a mixture of values and blanks: #{diff_column.inspect} (group: #{friendly_group})", colliding_row_md5)
      end
      
      values_by_ref.to_a.combination(2) do |a, b|
        ref1, values1 = a
        ref2, values2 = b
        next unless values1 == values2
        colliding_row_md5 = @objects.row_md5s_by_ref[ref2].first
        @errors << error_for_row("has the same differentiating values #{values1.inspect} as #{ident(ref1)} (group: #{friendly_group})", colliding_row_md5)
      end
    end
  end
  
  
  private
  
  def ident(prod_ref)
    product = @products_by_ref[prod_ref]
    company = @companies_by_ref[product[:company]]
    row_md5 = @objects.row_md5s_by_ref[prod_ref].first
    "#{company[:reference]} / #{product[:reference]} (#{@csvs.location(row_md5)})"
  end
end

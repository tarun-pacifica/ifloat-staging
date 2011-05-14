class ObjectCatalogueVerifier
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv row error)
  TEXT_PROP_NAMES = %w(auto:group_diff auto:title reference:category reference:class).to_set
  
  def initialize(dir, csv_catalogue)
    @csvs = csv_catalogue
    @errors = []
    
    @category_images_by_ref          = {}
    @companies_by_ref                = {}
    @primary_images_by_ref           = {}
    @products_by_ref                 = {}
    @text_values_by_prop_name_by_ref = {}
  end
  
  def added(ref, data)
    case data[:class]
    
    when Asset
      @category_images_by_ref[ref] = data if data[:bucket] == "category_images"
      
    when Attachment
      asset = data[:asset]
      return unless data[:role] == "image" and asset[:sequence_number] = 1
      @primary_images_by_ref[data[:product]] = data
      
    when Company
      @companies_by_ref[ref] = data
      
    when Product
      @products_by_ref[ref] = data
      
    when TextPropertyValue
      prop_name = data[:definition][:name]
      return unless TEXT_PROP_NAMES.include?(prop_name)
      text_values_by_prop_name = (@text_values_by_prop_name_by_ref[data[:product]] ||= {})
      text_values_by_prop_name[prop_name] = data
      
    end
  end
  
  def deleted(ref)
    @category_images_by_ref.delete(ref)
    @companies_by_ref.delete(ref)
    @primary_images_by_ref.delete(ref)
    @products_by_ref.delete(ref)
    @text_values_by_prop_name_by_ref.delete(ref)
  end
  
  # TODO: double check that no data loading from disk occurs during verification
  def verify
    steps = %w(all_categories_have_images no_orphaned_purchases product_count_is_safe same_image_means_same_group unique_titles well_differentiated_siblings)
    
    steps.each do |step|
      puts " - #{step.tr('-', ' ')}"
      send("verify_#{step}")
    end
  end
  
  def verify_all_categories_have_images
    cat_image_names = @category_images.map do |image|
      image[:name] =~ Asset::NAME_FORMAT ? $1 : raise("unable to parse #{o.attributes[:name]}")
    end.to_set
    
    prop_names = %w(reference:category reference:class)
    cat_names = @text_values_by_prop_name_by_ref.map do |ref, tvs_by_pn|
      tvs_by_pn.values_at(*prop_names).compact.flatten.map { |tv| tv[:text_value] }
    end.flatten.to_set
    
    @errors += (cat_names - cat_image_names).sort.map { |n| [nil, nil, "no image provided for category #{n.inspect}"] }
  end
  
  def no_orphaned_purchases
    Purchase.all_facility_primary_keys.each do |actual_company_ref, facility_url|
      if @companies_by_ref.values.find { |c| c[:reference] == actual_company_ref }.nil?
        @errors << [nil, nil, "unable to delete company with facility with user-referenced purchases: #{actual_company_ref} / #{facility_url}"]
      elsif @facilities_by_ref.values.find { |f| f[:primary_url] == facility_url }.nil?
         @errors << [nil, nil, "unable to delete facility with user-referenced purchases: #{actual_company_ref} / #{facility_url}"]
      end
    end
  end
  
  def verify_product_count_is_safe
    @errors << [nil, nil, "> 50,000 products (sitemap would be invalid)"] if @products_by_ref.size > 50000
  end
  
  def verify_same_image_means_same_group
    first_refs_by_checksum = {}
    
    @primary_images_by_ref.each do |ref, image|
      checksum = image[:checksum]
      first_ref = first_refs_by_checksum[checksum]
      first_refs_by_checksum[checksum] = ref and next if first_ref.nil?
      
      fr_group, r_group = [first_ref, ref].map { |r| @products_by_ref[r][:reference_group] }
      next unless fr_group.nil? or fr_group != r_group
      
      problem = "their reference_group values differ (#{r_group.inspect} vs #{fr_group.inspect})"
      problem = "neither have a reference_group value set" if fr_group == r_group
      
      colliding_row = @objects.rows_by_ref(ref).first
      @errors << error_for_row(colliding_row, "has the same primary image as #{ident(first_ref)} but #{problem}")
    end
  end
  
  # TODO: generalize to non-English titles when ready
  def verify_unique_titles
    first_refs_by_value_by_heading = {}
    text_values_by_prop_name_by_ref.each do |ref, tvs_by_pn|
      (tvs_by_pn["auto:title"] || []).each do |tv|
        heading = TitleStrategy::TITLE_PROPERTIES[tv[:sequence_number] - 1]
        refs_by_value = (first_refs_by_value_by_heading[heading] ||= {})
        
        value = tv[:text_value]
        existing_ref = first_ref_by_value[value]
        if existing_ref.nil?
          first_refs_by_value[value] = ref
        else
          colliding_row = @objects.rows_by_ref(ref).first
          @errors << error_for_row(colliding_row, "has the same #{heading} title as #{ident(existing_ref)}: #{value}")
        end
      end
    end
  end
  
  def verify_well_differentiated_siblings
    values_by_ref_by_group = {}
    
    text_values_by_prop_name_by_ref.each do |ref, tvs_by_pn|
      (tvs_by_pn["auto:group_diff"] || []).each do |tv|
        group = @products_by_ref[ref].attributes.values_at(:company, :reference_group)
        values_by_ref = (values_by_ref_by_group[group] ||= {})
        (values_by_product[ref] ||= []) << tv[:text_value]
      end
    end
    
    values_by_ref_by_group.each do |group, values_by_ref|
      next if values_by_ref.size == 1
      friendly_group = "#{@companies_by_ref[group[0]][:reference]} / #{group[1]}"
      
      values_by_ref.values.transpose.each_with_index do |diff_column, i|
        blank_count = diff_column.count { |v| v.blank? }
        next if blank_count == 0 or blank_count == diff_column.size
        colliding_row = @objects.rows_by_ref(values_by_ref.keys.first).first
        @errors << error_for_row(colliding_row, "differentiating values from property set #{i + 1} are a mixture of values and blanks: #{diff_column.inspect} (group: #{friendly_group})")
      end
      
      values_by_ref.to_a.combination(2) do |a, b|
        ref1, values1 = a
        ref2, values2 = b
        colliding_row = @objects.rows_by_ref(ref2).first
        @errors << error_for_row(colliding_row, "has the same differentiating values #{values1.inspect} as #{ident(ref1)} (group: #{friendly_group})") if values1 == values2
      end
    end
  end
  
  
  private
  
  def ident(prod_ref)
    product = @products_by_ref[prod_ref]
    company = @companies_by_ref[product[:company]]
    location = @csvs.row_info(@objects.rows_by_ref(prod_ref)).first.values_at(:name, :index).join(":")
    "#{company[:reference]} / #{product[:reference]} (#{location})"
  end
end

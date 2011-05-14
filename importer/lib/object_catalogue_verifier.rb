class ObjectCatalogueVerifier
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv row error)
  TEXT_PROP_NAMES = %w(auto:title reference:category reference:class).to_set
  
  def initialize(dir, csv_catalogue)
    @csvs = csv_catalogue
    @errors = []
    
    @category_images_by_ref          = {}
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
    @primary_images_by_ref.delete(ref)
    @products_by_ref.delete(ref)
    @text_values_by_prop_name_by_ref.delete(ref)
  end
  
  def verify
    steps = %w(all_categories_have_images product_count_is_safe same_image_means_same_group unique_titles)
    
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
  
  def verify_product_count_is_safe
    @errors << [nil, nil, "> 50,000 products (sitemap would be invalid)"] if @products_by_ref.size > 50000
  end
  
  def verify_same_image_means_same_group
    first_refs_by_checksum = {}
    
    @primary_images_by_ref.each do |ref, image|
      checksum = image[:checksum]
      first_ref = first_refs_by_checksum[checksum]
      first_refs_by_checksum[checksum] = ref and next if first_ref.nil?
      
      fr_group, r_group = [first_ref, ref].map { |r| r[:reference_group] }
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
  
  
  private
  
  def ident(product)
    location = @csvs.row_info(@objects.rows_by_ref(product)).first.values_at(:name, :index).join(":")
    "#{product[:company][:reference]} / #{product[:reference]} (#{location})"
  end
  
  # AFTER AUTO
  # 
  # need the agd values by product
  #  - ""ensured all grouped products are adequately differentiated"
  # 
  # handling orphaned pick_products / purchases should be handled JIT when they are marked as potentially invalid
  # - user driven data not part of core
end

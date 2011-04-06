class ObjectCatalogueVerifier
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv row error)
  TEXT_PROP_NAMES = %w(reference:category reference:class).to_set
  
  def initialize(dir, csv_catalogue, object_catalogue, index_newer_than)
    @csvs = csv_catalogue
    
    FileUtils.mkpath(dir)
    @index_path = dir / "verifier_index"
    
    if File.exist?(@index_path) and File.mtime(@index_path) > index_newer_than
      @data = File.open(@index_path) { |f| Marshal.load(f) }
    else
      puts " ! (re)building verifier index"
      @data = {:cibr => {}, :pibr => {}, :pbr => {}, :tvbpnbr => {}}
      object_catalogue.each(&method(:added))
      committed
    end
    
    @category_images_by_ref          = @data[:cibr]
    @primary_images_by_ref           = @data[:pibr]
    @products_by_ref                 = @data[:pbr]
    @text_values_by_prop_name_by_ref = @data[:tvbpnbr]
    
    @errors = []
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
  
  def committed
    File.open(@index_path, "w") { |f| Marshal.dump(@data, f) }
  end
  
  def deleted(ref)
    @category_images_by_ref.delete(ref)
    @primary_images_by_ref.delete(ref)
    @products_by_ref.delete(ref)
    @text_values_by_prop_name_by_ref.delete(ref)
  end
  
  def verify
    steps = %w(all_categories_have_images product_count_is_safe same_image_means_same_group)
    
    steps.each do |step|
      puts " - #{step.tr('-', ' ')}"
      send("verify_#{step}")
    end
  end
  
  def verify_all_categories_have_images
    raise "to implement" # TODO
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
      
      fr_company, fr_prod_ref = first_ref.attributes.values_at(:company, :reference)
      fr_company_ref = fr_company[:reference]
      
      fr_row, r_row = [first_ref, ref].map { |r| @objects.rows_by_ref(r).first }
      fr_location = @csvs.row_info(fr_row).values_at(:name, :index).join(":")
      fr_ident = "#{fr_company_ref} / #{fr_prod_ref} (#{fr_location})"
      
      problem = "their reference_group values differ (#{r_group.inspect} vs #{fr_group.inspect})"
      problem = "neither have a reference_group value set" if fr_group == r_group
      
      @errors << error_for_row(r_row, "has the same primary image as #{fr_ident} but #{problem}")
    end
  end
  
  # AFTER AUTO
  # 
  # need the title values by product
  #  - "ensured no blank / duplicated titles"
  # 
  # need the agd values by product
  #  - ""ensured all grouped products are adequately differentiated"
  # 
  # handling orphaned pick_products / purchases should be handled JIT when they are marked as potentially invalid
  # - user driven data not part of core
end

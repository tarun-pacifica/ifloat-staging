class ObjectCatalogueVerifier
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv row error)
  TEXT_PROP_NAMES = %w(reference:category reference:class).to_set
  
  def initialize(dir, csv_catalogue, object_catalogue)
    @csvs = csv_catalogue
    
    FileUtils.mkpath(dir)
    @index_path = dir / "verifier_index"
    
    if File.exist?(@index_path) # TODO: should also be newer than any object index
      @data = File.open(@index_path) { |f| Marshal.load(f) }
    else
      puts " ! (re)building verifier index"
      @data = {:pias => {}, :prods => {}, :tvs => {}}
      object_catalogue.each(&method(:added))
      committed
    end
    
    @primary_images_by_ref            = @data[:pias]
    @products_by_ref                  = @data[:prods]
    @text_values_by_prop_name_by_ref  = @data[:tvs]
    
    @errors = []
  end
  
  def added(ref, data)
    case data[:class]
      
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
    @primary_images_by_ref.delete(ref)
    @products_by_ref.delete(ref)
    @text_values_by_prop_name_by_ref.delete(ref)
  end
  
  def verify
    steps = %w(product_count same_image_means_same_group)
    
    @errors = steps.inject([]) do |errors, step|
      puts " - #{step.tr('-', ' ')}"
      errors + send("verify_#{step}")
    end
  end
  
  def verify_product_count
    @products_by_ref.size > 50000 ? [[nil, nil, "> 50,000 products (sitemap would be invalid)"]] : []
  end
  
  def verify_same_image_means_same_group
    first_refs_by_checksum = {}
    
    @primary_images_by_ref.each do |ref, image|
      checksum = image[:checksum]
      first_ref = first_refs_by_checksum[checksum]
      first_refs_by_checksum[checksum] = ref and next if first_ref.nil?
      
      fr_group, r_group = [first_ref, ref].map { |r| r[:reference_group] }
      next unless fr_group.nil? or fr_group != r_group
      
      fr_company, fr_ref = first_ref.attributes.values_at(:company, :reference)
      fr_company_ref = fr_company[:reference]
      # TODO: complete
      fr_ident = "#{first_product.path} row #{first_product.row} (#{fr_company_ref} / #{fr_ref})"
      problem = "their reference_group values differ (#{r_group.inspect} vs #{fr_group.inspect})"
      problem = "neither have a reference_group value set" if fr_group == r_group
      # TODO: complete
      error(Product, product.path, product.row, nil, "has the same primary image as #{fr_ident} but #{problem}")
    end
  end
end

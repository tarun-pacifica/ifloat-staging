class ObjectVerifier
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv row error)
  TEXT_PROP_NAMES = %w(auto:group_diff auto:title reference:category reference:class).to_set
  
  def initialize(csv_catalogue, object_catalogue, dir)
    @csvs = csv_catalogue
    @objects = object_catalogue
    @errors = []
    
    @stores = [
      @asset_checksums_by_asset_ref      = OklahomaMixer.open(dir / "asset_checksums_by_asset_ref.tch", "wcs"),
      @category_image_names_by_asset_ref = OklahomaMixer.open(dir / "category_image_names_by_asset_ref.tch", "wcs"),
      @category_names_by_tpv_ref         = OklahomaMixer.open(dir / "category_names_by_tpv_ref.tch", "wcs"),
      @company_refs_by_product_ref       = OklahomaMixer.open(dir / "company_refs_by_product_ref.tch", "wcs"),
      @company_refnames_by_company_ref   = OklahomaMixer.open(dir / "company_refnames_by_company_ref.tch", "wcs"),
      @facility_names_by_facility_ref    = OklahomaMixer.open(dir / "facility_names_by_facility_ref.tch", "wcs"),
      @primary_image_refs_by_product_ref = OklahomaMixer.open(dir / "primary_image_refs_by_product_ref.tch", "wcs"),
      @product_group_refs_by_product_ref = OklahomaMixer.open(dir / "product_group_refs_by_product_ref.tch", "wcs"),
      @product_refnames_by_product_ref   = OklahomaMixer.open(dir / "product_refnames_by_product_ref.tch", "wcs"),
      @property_names_by_property_ref    = OklahomaMixer.open(dir / "property_names_by_property_ref.tch", "wcs"),
      @sibling_product_refs_by_tpv_ref   = OklahomaMixer.open(dir / "sibling_product_refs_by_tpv_ref.tch", "wcs"),
      @sibling_seq_nums_by_tpv_ref       = OklahomaMixer.open(dir / "sibling_seq_nums_by_tpv_ref.tch", "wcs"),
      @sibling_values_by_tpv_ref         = OklahomaMixer.open(dir / "sibling_values_by_tpv_ref.tch", "wcs"),
      @title_seq_nums_by_tpv_ref         = OklahomaMixer.open(dir / "title_seq_nums_by_tpv_ref.tch", "wcs"),
      @title_values_by_tpv_ref           = OklahomaMixer.open(dir / "title_values_by_tpv_ref.tch", "wcs")
    ]
    
    delete_obsolete
  end
  
  def added(ref, data)
    case data[:class].to_s
      
    when "Asset"
      @asset_checksums_by_asset_ref[ref] = data[:checksum]
      if data[:bucket] == "category_images"
        raise "unable to parse #{data[:name]}" unless data[:name] =~ Asset::NAME_FORMAT
        @category_image_names_by_asset_ref[ref] = $1
      end
      
    when "Attachment"
      return unless data[:role] == "image" and data[:sequence_number] == 1
      @primary_image_refs_by_product_ref[data[:product]] = data[:asset]
      
    when "Company"
      @company_refnames_by_company_ref[ref] = data[:reference]
      
    when "Facility"
      @facility_names_by_facility_ref[ref] = data[:name]
      
    when "Product"
      @company_refs_by_product_ref[ref] = data[:company]
      @product_group_refs_by_product_ref[ref] = data[:reference_group]
      @product_refnames_by_product_ref[ref] = data[:reference]
      
    when "PropertyDefinition"
      @property_names_by_property_ref[ref] = data[:name]
      
    when "TextPropertyValue"
      case @property_names_by_property_ref[data[:definition]]
      when "auto:group_diff"
        @sibling_product_refs_by_tpv_ref[ref] = data[:product]
        @sibling_seq_nums_by_tpv_ref[ref] = data[:sequence_number]
        @sibling_values_by_tpv_ref[ref] = data[:text_value]
      when "auto:title"
        @title_seq_nums_by_tpv_ref[ref] = data[:sequence_number]
        @title_values_by_tpv_ref[ref] = data[:text_value]
      when "reference:category", "reference:class"
        @category_names_by_tpv_ref[ref] = data[:text_value].downcase.tr(" ", "_")
      end
      
    end
  end
  
  def delete_obsolete
    @stores.map(&:keys).flatten.uniq.each do |ref|
      @stores.each { |db| db.delete(ref) } unless @objects.has_ref?(ref)
    end
  end
  
  def verify
    steps = %w(all_categories_have_images no_orphaned_picks no_orphaned_purchases product_count_is_safe same_image_means_same_group unique_titles well_differentiated_siblings)
    
    steps.each do |step|
      puts " - #{step.tr('_', ' ')}"
      send("verify_#{step}")
    end
  end
  
  def verify_all_categories_have_images
    cat_names = @category_names_by_tpv_ref.values.to_set
    cat_image_names = @category_image_names_by_asset_ref.values.to_set
    @errors += (cat_names - cat_image_names).sort.map { |n| [nil, nil, "no image provided for category #{n.inspect}"] }
  end
  
  def verify_no_orphaned_picks
    company_refnames = @company_refnames_by_company_ref.values.to_set
    PickedProduct.all_primary_keys.each do |company_refname, product_refname|
      next if company_refnames.include?(company_refname)
      @errors << [nil, nil,"unable to delete company with user-referenced product: #{company_refname} / #{product_refname}"]
    end
  end
  
  def verify_no_orphaned_purchases
    company_refnames = @company_refnames_by_company_ref.values.to_set
    facility_names = @facility_names_by_facility_ref.values.to_set
    
    Purchase.all_facility_primary_keys.each do |company_refname, facility_name|
      purchase_name = [company_refname, facility_name].join(" / ")
      if (not company_refnames.include?(company_refname))
        @errors << [nil, nil, "unable to delete company with facility with user-referenced purchases: #{purchase_name}"]
      elsif (not facility_names.include?(facility_name))
        @errors << [nil, nil, "unable to delete facility with user-referenced purchases: #{purchase_name}"]
      end
    end
  end
  
  def verify_product_count_is_safe
    @errors << [nil, nil, "> 50,000 products (sitemap would be invalid)"] if @product_refnames_by_product_ref.size > 50000
  end
  
  def verify_same_image_means_same_group
    first_product_refs_by_checksum = {}
    
    @primary_image_refs_by_product_ref.each do |product_ref, image_ref|
      checksum = @asset_checksums_by_asset_ref[image_ref]
      first_product_ref = first_product_refs_by_checksum[checksum]
      (first_product_refs_by_checksum[checksum] = product_ref and next) if first_product_ref.nil?
      
      fp_group, p_group = [first_product_ref, product_ref].map(&@product_group_refs_by_product_ref.method(:fetch))
      next unless fp_group.nil? or fp_group != p_group
      
      problem = "their reference_group values differ (#{p_group.inspect} vs #{fp_group.inspect})"
      problem = "neither have a reference_group value set" if fp_group == p_group
      error = "has the same primary image as #{ident(first_product_ref)} but #{problem}"
      @errors << error_for_row(error, @objects.row_md5s_for(product_ref).first)
    end
  end
  
  def verify_unique_titles
    first_tpv_refs_by_value_by_heading = {}
    
    @title_seq_nums_by_tpv_ref.each do |tpv_ref, seq_num|
      raise seq_num.inspect unless seq_num =~ /^\d+$/
      heading = TitleStrategy::TITLE_PROPERTIES[seq_num.to_i - 1]
      next if heading == :image
      first_tpv_refs_by_value = (first_tpv_refs_by_value_by_heading[heading] ||= {})
      
      value = @title_values_by_tpv_ref[tpv_ref]
      existing_ref = first_tpv_refs_by_value[value]
      
      if existing_ref.nil?
        first_tpv_refs_by_value[value] = tpv_ref
      else
        error = "has the same #{heading} title as #{ident(@objects.data_for(existing_ref)[:product])}: #{value}"
        @errors << error_for_row(error, @objects.row_md5s_for(tpv_ref).first)
      end
    end
  end
  
  def verify_well_differentiated_siblings
    tpv_refs_by_product_ref_by_group = {}
    
    @sibling_product_refs_by_tpv_ref.each do |tpv_ref, product_ref|
      group = [company_refname_for(product_ref), @product_group_refs_by_product_ref[product_ref]]
      tpv_refs_by_product_ref = (tpv_refs_by_product_ref_by_group[group] ||= {})
      (tpv_refs_by_product_ref[product_ref] ||= []) << tpv_ref
    end
    
    tpv_refs_by_product_ref_by_group.each do |group, tpv_refs_by_product_ref|
      next if tpv_refs_by_product_ref.size == 1
      friendly_group = group.join(" / ")
      
      sorter = @sibling_seq_nums_by_tpv_ref.method(:fetch)
      valuer = @sibling_values_by_tpv_ref.method(:fetch)
      ordered_values_by_product_ref = Hash[
        tpv_refs_by_product_ref.map { |product_ref, tpv_refs| [product_ref, tpv_refs.sort_by(&sorter).map(&valuer)] }
      ]
      
      diff_columns = nil
      begin
        diff_columns = ordered_values_by_product_ref.values.transpose
      rescue
        error_row_md5 = @objects.row_md5s_for(ordered_values_by_product_ref.keys.first).first
        @errors << error_for_row("mixed number of property hierarchy values per product in the product group #{group.inspect} - probably a mix of classes with differently shaped property hierarchy configurations", error_row_md5)
        next
      end
      
      diff_columns.each_with_index do |diff_column, i|
        blank_count = diff_column.count(&:blank?)
        next if blank_count == 0 or blank_count == diff_column.size
        error_row_md5 = @objects.row_md5s_for(ordered_values_by_product_ref.keys.first).first
        @errors << error_for_row("differentiating values from property set #{i + 1} are a mixture of values and blanks: #{diff_column.inspect} (group: #{friendly_group})", error_row_md5)
      end
      
      ordered_values_by_product_ref.to_a.combination(2) do |a, b|
        ref1, values1 = a
        ref2, values2 = b
        next unless values1 == values2
        @errors << error_for_row("has the same differentiating values #{values1.inspect} as #{ident(ref1)} (group: #{friendly_group})", @objects.row_md5s_for(ref2).first)
      end
    end
  end
  
  
  private
  
  def company_refname_for(product_ref)
    company_ref = @company_refs_by_product_ref[product_ref]
    @company_refnames_by_company_ref[company_ref]
  end
  
  def ident(product_ref)
    company_refname = company_refname_for(product_ref)
    product_refname = @product_refnames_by_product_ref[product_ref]
    location = @csvs.location(@objects.row_md5s_for(product_ref).first)
    "#{company_refname} / #{product_refname} (#{location})"
  end
end

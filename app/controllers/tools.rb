class Tools < Application
  CSV_REPO = "../ifloat_csvs"
  
  before :ensure_authenticated
  
  def ensure_authenticated
    redirect "/" unless Merb.environment == "development" or session.admin?
  end
  
  def icons
    @properties = PropertyDefinition.all.sort_by { |property| property.sequence_number }
    @icon_urls_by_property_id = PropertyDefinition.icon_urls_by_property_id(@properties)
    
    used_names = @icon_urls_by_property_id.values.map { |url| url.split("/").last }
    @unused_property_icons = Asset.all(:bucket => "property_icons", :name.not => used_names).sort_by { |a| a.name }
    
    @skip_javascript = true
    render
  end
  
  def pivoter
    properties_by_name = PropertyDefinition.all.hash_by { |property| property.name }
    
    universal_columns = {}
    universal_r = 0
    
    Dir[CSV_REPO / "products" / "*.csv"].each do |path|
      FasterCSV.foreach(path, :headers => :first_row, :return_headers => false) do |row|
        row.each do |header, value|
          universal_column = (universal_columns[header] ||= [])
          universal_column[universal_r] = value
        end
        universal_r += 1
      end
    end
    
    universal_columns.each do |column_name, values|
      values[universal_r - 1] ||= nil
    end
    
    sorted_column_names = universal_columns.keys.sort_by do |col_name|
      case col_name
      when "company.reference" then [0]
      when "product.review_stage" then [1]
      when "product.reference" then [2]
      when /^mapping\.(.+?)$/ then [3, $1]
      when /^raw:.*?(\d+)$/ then [7, $1.to_i]
      when /^(.+?:.+?):(.*?):(\d+)(:tolerance)?$/ then [4, (properties_by_name[$1].sequence_number rescue 0).to_i, $3.to_i, $2, ($4.nil? ? 0 : 1)]
      when /^relationship\.(.+?)$/ then [5, $1]
      when /^attachment.(.+?).(\d+)$/ then [6, $1, $2.to_i]
      else [8]
      end
    end
    
    csv_data = FasterCSV.generate do |csv|
      csv << sorted_column_names
      universal_columns.values_at(*sorted_column_names).transpose.each { |row| csv << row }
    end
    
    headers["Content-Disposition"] = "attachment; filename=all_products.csv"
    headers["Content-Type"] = "text/csv"
    csv_data
  end
end

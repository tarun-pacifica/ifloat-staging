class AutoObjectGenerator
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv row column error)
  
  def initialize(csv_catalogue, object_catalogue)
    @csvs = csv_catalogue
    @objects = object_catalogue
    
    @errors = []
  end
  
  def generate
    product_row_md5s, *auto_row_md5s = [/^products\//, /^property_hierarchies/, /^title_strategies/].map do |matcher|
      @csvs.infos_for_name(matcher).map { |info| info[:row_md5s] }.flatten.to_set
    end
    
    product_row_md5s_satisfied = Array.new(auto_row_md5s.size) { [] }
    
    @objects.rows_by_pk_md5 do |pk_md5, object_row_md5s|
      object_product_row_md5s = (product_row_md5s & object_row_md5s)
      next if object_product_row_md5s.empty?
      auto_row_md5s.each_with_index do |row_md5s, i|
        product_row_md5s_satisfied[i] += object_product_row_md5s unless (row_md5s & object_row_md5s).empty?
      end
    end
    
    (product_row_md5s - product_row_md5s_satisfied[0]).each { |row_md5| generate_ph_values(row_md5) }
    (product_row_md5s - product_row_md5s_satisfied[1]).each { |row_md5| generate_ts_values(row_md5) }
  end
  
  def generate_ph_values(row_md5)
    p ["PH", row_md5]
  end
  
  def generate_ts_values(row_md5)
    p ["TS", row_md5]
  end
end

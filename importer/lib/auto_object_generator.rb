class AutoObjectGenerator
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv row column error)
  
  def initialize(csv_catalogue, object_catalogue)
    @csvs = csv_catalogue
    @objects = object_catalogue
    
    @errors = []
    
    @agd_property, @at_property = %w(auto:group_diff auto:title).map do |name|
      ref = ObjectRef.for(PropertyDefinition, [name])
      @errors << "#{name} property not found - cannot generate values without it" unless @objects.has_ref?(ref)
      ref
    end
  end
  
  def generate
    return unless @errors.empty?
    
    product_row_md5s, *auto_row_md5s = [/^products\//, /^property_hierarchies/, /^title_strategies/].map do |matcher|
      @csvs.infos_for_name(matcher).map { |info| info[:row_md5s] }.flatten.to_set
    end
    
    refs_by_product_row_md5 = {}
    row_md5s_by_product_row_md5 = {}
    
    @objects.rows_by_ref do |ref, object_row_md5s|
      primary_row_md5 = object_row_md5s.first
      next unless product_row_md5s.include?(primary_row_md5)
      
      (refs_by_product_row_md5[primary_row_md5] ||= []) << ref
      (row_md5s_by_product_row_md5[primary_row_md5] ||= []).concat(object_row_md5s)
    end
    
    [:generate_ph_values, :generate_ts_values].zip(auto_row_md5s).each do |method_sym, row_md5s|
      row_md5s_by_product_row_md5.each do |row_md5, object_row_md5s|
        next unless (row_md5s & object_row_md5s).empty?
        send(method_sym, row_md5, refs_by_product_row_md5[row_md5])
      end
    end
  end
  
  def generate_ph_values(row_md5, pk_md5s)
    p ["PH", row_md5]
    pk_md5s.each do |pk_md5|
      p @objects.lookup_data(pk_md5)
    end
  end
  
  def generate_ts_values(row_md5, pk_md5s)
    p ["TS", row_md5, pk_md5s]
  end
end

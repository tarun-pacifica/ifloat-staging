class ObjectCatalogue
  def self.default
    @@default
  end
  
  def initialize(dir)
    @@default = self
    
    @data_dir, @refs_dir, @rows_dir = %w(data refs rows).map { |d| dir / d }
    group_names_by_dir = Hash[ [@data_dir, @refs_dir, @rows_dir].map do |d|
      FileUtils.mkpath(d)
      [d, Dir[d / "*"].map { |path| File.basename(path) }]
    end ]
    
    common_group_names = group_names_by_dir.values.inject(:&)
    group_names_by_dir.each do |dir, names|
      (names - common_group_names).map { |name| dir / name }.delete_and_log("orphaned #{File.basename(dir)}")
    end
    
    @group_names_by_pk_md5 = {}
    @refs_by_pk_md5 = {}
    common_group_names.each do |name|
      File.open(@refs_dir / name) { |f| Marshal.load(f) }.each do |pk_md5, value_md5|
        @group_names_by_pk_md5[pk_md5] = name
        @refs_by_pk_md5[pk_md5] = ObjectReference.new(pk_md5, value_md5)
      end
    end
    
    @rows_by_pk_md5 = {}
    common_group_names.each do |name|
      @rows_by_pk_md5.update(File.open(@rows_dir / name) { |f| Marshal.load(f) })
    end
    
    @data_by_pk_md5 = {}
    @refs_to_write = []
  end
  
  def add(csv_catalogue, objects, *row_md5s)
    objects.each do |object|
      
      # row_md5s = (row_md5s + row_md5_chain(object, catalogue)).flatten.uniq
      
      ref = ObjectReference.new(self, row_md5s, object)
      uid = ref.unique_id
      
      existing_ref = @refs_by_unique_id[uid]
      unless existing_ref.nil?
        existing_rows = existing_ref.row_md5s.map do |row_md5|
          csv_catalogue.row_info(row_md5).values_at(:name, :index).join(":")
        end.join(", ")
        existing_rows = "unknown csvs / rows" if existing_rows.blank?
        return ["duplicate of #{existing_ref.klass} from #{existing_rows}"]
      end
      
      @data_by_unique_id[uid] = object
      @refs_by_unique_id[uid] = ref
      @refs_to_write << ref
    end
    
    []
  end
  
  def commit(group_name)
    return if @refs_to_write.empty?
    
    data_by_unique_id = {}
    refs_by_unique_id = {}
    @refs_to_write.each do |ref|
      uid = ref.unique_id
      data_by_unique_id[uid] = flatten_object(@data_by_unique_id.delete(uid))
      refs_by_unique_id[uid] = ref
      @group_names_by_unique_id[uid] = group_name
    end
    @refs_to_write.clear
    
    {@data_dir => data_by_unique_id, @refs_dir => refs_by_unique_id}.each do |dir, set|
      path = dir / group_name
      data = (File.open(path) { |f| Marshal.load(f) } rescue {})
      data.update(set)
      File.open(path, "w") { |f| Marshal.dump(data, f) }
    end
  end
  
  def delete_obsolete(row_md5s)
    refs_by_row_md5 = {}
    @refs_by_unique_id.values.each do |ref|
      ref.row_md5s.each { |row_md5| (refs_by_row_md5[row_md5] ||= []) << ref }
    end
    
    obsolete_row_md5s = (refs_by_row_md5.keys - row_md5s)
    obsolete_refs = refs_by_row_md5.values_at(*obsolete_row_md5s).flatten
    
    obsolete_refs.group_by { |ref| @group_names_by_unique_id.delete(ref.unique_id) }.each do |name, refs|
      [@data_dir, @refs_dir].each do |dir|
        path = dir / name
        data = File.open(path) { |f| Marshal.load(f) } rescue {}
        refs.each { |ref| data.delete(ref.unique_id) }
        File.open(path, "w") { |f| Marshal.dump(data, f) }
      end
    end
    
    obsolete_refs.each do |ref|
      @data_by_unique_id.delete(ref.unique_id)
      @refs_by_unique_id.delete(ref.unique_id)
    end
    
    puts " - deleted #{obsolete_refs.size} objects in #{obsolete_group_names.size} groups" unless obsolete_refs.empty?
  end
  
  def flatten_object(object)
    flattened = object.map do |key, value|
      value = value.unique_id if value.is_a?(ObjectReference)
      [key, value]
    end
    Hash[flattened]
  end
  
  def lookup_data(unique_id)
    data = @data_by_unique_id[unique_id]
    return data unless data.nil?
    
    path = @data_dir / @group_names_by_unique_id[unique_id]
    return nil unless File.exist?(path)
    @data_by_unique_id[unique_id] = File.open(path) { |f| unflatten_object(Marshal.load(f)[unique_id]) }
  end
  
  def lookup_ref(unique_id)
    @refs_by_unique_id[unique_id]
  end
  
  # TODO: reimplement
  def missing_auto_row_md5s(auto_row_md5s, product_row_md5s)
    raise "to reimplement"
    
    missing_auto_row_md5s = []
    seen_row_md5s = []
    
    auto_row_md5s.each do |md5|
      object_refs = @object_refs_by_row_md5[md5]
      if object_refs.nil? then missing_auto_row_md5s << md5
      else object_refs.each { |o| seen_row_md5s += (@row_md5s_by_unique_id[o.unique_id] || []) }
      end
    end
    
    [missing_auto_row_md5s, product_row_md5s - seen_row_md5s]
  end
  
  def missing_row_md5s(row_md5s)
    row_md5s - @refs_by_unique_id.values.map { |ref| ref.row_md5s }.flatten
  end
  
  def unflatten_object(object)
    unflattened = object.map do |key, value|
      value = lookup_ref(value) if value.is_a?(ObjectUniqueID)
      [key, value]
    end
    Hash[unflattened]
  end
end

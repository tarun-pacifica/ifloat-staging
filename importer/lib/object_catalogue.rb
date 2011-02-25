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
      ref = ObjectReference.from_object(object)
      
      existing_ref = @refs_by_pk_md5[ref.pk_md5]
      unless existing_ref.nil?
        existing_rows = existing_ref.row_md5s.map do |row_md5|
          csv_catalogue.row_info(row_md5).values_at(:name, :index).join(":")
        end.join(", ")
        existing_rows = "unknown csvs / rows" if existing_rows.blank?
        return ["duplicate of #{existing_ref.klass} from #{existing_rows}"]
      end
      
      @data_by_pk_md5[ref.pk_md5] = object
      @refs_by_pk_md5[ref.pk_md5] = ref
      @rows_by_pk_md5[ref.pk_md5] = (row_md5s + row_md5_chain(object)).flatten.uniq
      
      @refs_to_write << ref
    end
    
    []
  end
  
  def commit(group_name)
    return if @refs_to_write.empty?
    
    data_by_pk_md5 = {}
    rows_by_pk_md5 = {}
    vals_by_pk_md5 = {}
    @refs_to_write.each do |ref|
      data_by_pk_md5[ref.pk_md5] = @data_by_pk_md5.delete(ref.pk_md5)
      rows_by_pk_md5[ref.pk_md5] = @rows_by_pk_md5[ref.pk_md5]
      vals_by_pk_md5[ref.pk_md5] = ref.value_md5
      @group_names_by_pk_md5[ref.pk_md5] = group_name
    end
    @refs_to_write.clear
    
    {@data_dir => data_by_pk_md5, @refs_dir => vals_by_pk_md5, @rows_dir => rows_by_pk_md5}.each do |dir, set|
      path = dir / group_name
      data = (File.open(path) { |f| Marshal.load(f) } rescue {})
      data.update(set)
      File.open(path, "w") { |f| Marshal.dump(data, f) }
    end
  end
  
  def delete_obsolete(row_md5s)
    row_md5s = row_md5s.to_set
    
    obsolete_pk_md5s = @rows_by_pk_md5.map do |pk_md5, rows|
      next if (row_md5s & rows).size == rows.size
      pk_md5
    end.compact
    
    obsolete_group_names = []
    obsolete_pk_md5s.group_by { |pk_md5| @group_names_by_pk_md5.delete(pk_md5) }.each do |name, pk_md5s|
      obsolete_group_names << name
      
      [@data_dir, @refs_dir, @rows_dir].each do |dir|
        path = dir / name
        data = File.open(path) { |f| Marshal.load(f) } rescue {}
        pk_md5s.each { |pk_md5| data.delete(pk_md5) }
        if data.empty? then File.delete(path)
        else File.open(path, "w") { |f| Marshal.dump(data, f) }
        end
      end
    end
    
    obsolete_pk_md5s.each do |pk_md5|
      @data_by_pk_md5.delete(pk_md5)
      @refs_by_pk_md5.delete(pk_md5)
      @rows_by_pk_md5.delete(pk_md5)
    end
    
    puts " - deleted #{obsolete_pk_md5s.size} objects in #{obsolete_group_names.size} groups" unless obsolete_pk_md5s.empty?
  end
  
  def lookup_data(pk_md5)
    data = @data_by_pk_md5[pk_md5]
    return data unless data.nil?
    
    path = @data_dir / @group_names_by_pk_md5[pk_md5]
    return nil unless File.exist?(path)
    @data_by_pk_md5[pk_md5] = File.open(path) { |f| Marshal.load(f)[pk_md5] }
  end
  
  def lookup_ref(pk_md5)
    @refs_by_pk_md5[pk_md5]
  end
  
  # TODO: reimplement
  def missing_auto_row_md5s(auto_row_md5s, product_row_md5s)
    raise "to reimplement"
    
    missing_auto_row_md5s = []
    seen_row_md5s = []
    
    auto_row_md5s.each do |md5|
      object_refs = @object_refs_by_row_md5[md5]
      if object_refs.nil? then missing_auto_row_md5s << md5
      else object_refs.each { |o| seen_row_md5s += (@row_md5s_by_pk_md5[o.pk_md5] || []) }
      end
    end
    
    [missing_auto_row_md5s, product_row_md5s - seen_row_md5s]
  end
  
  def missing_row_md5s(row_md5s)
    row_md5s - @rows_by_pk_md5.values.flatten.uniq
  end
  
  def row_md5_chain(object)
    case object
    when Array                then object.map { |v| row_md5_chain(v) }
    when Hash                 then object.values.map { |v| row_md5_chain(v) }
    when ObjectReference::MD5 then @rows_by_pk_md5[object]
    else []
    end
  end
end

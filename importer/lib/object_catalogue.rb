class ObjectCatalogue
  def self.default
    @@default
  end
  
  attr_reader :rows_by_ref
  
  def initialize(csv_catalogue, dir)
    @@default = self
    
    @csvs = csv_catalogue
    
    @data_dir, @refs_dir, @rows_dir = %w(data refs rows).map { |d| dir / d }
    dirs_with_groups = [@data_dir, @refs_dir, @rows_dir].map do |d|
      FileUtils.mkpath(d)
      [d, Dir[d / "*"].map { |path| File.basename(path) }]
    end
    groups_by_dir = Hash[dirs_with_groups]
    
    common_groups = groups_by_dir.values.inject(:&)
    groups_by_dir.each do |d, names|
      (names - common_groups).map { |name| d / name }.delete_and_log("orphaned #{File.basename(d)}")
    end
    
    @groups_by_ref = {}
    @vals_by_ref = {}
    common_groups.each do |name|
      # TODO: remove once marshal stops blowing up in ruby 1.8
      GC.disable
      value_md5s_by_ref = File.open(@refs_dir / name) { |f| Marshal.load(f) }
      GC.enable
      
      value_md5s_by_ref.each do |ref, value_md5|
        @groups_by_ref[ref] = name
        @vals_by_ref[ref] = value_md5
      end
    end
    
    most_recent_commit = nil
    @rows_by_ref = {}
    common_groups.each do |name|
      path = @rows_dir / name
      most_recent_commit = [most_recent_commit, File.mtime(path)].compact.max
      @rows_by_ref.update(File.open(path) { |f| Marshal.load(f) })
    end
    
    @data_by_ref = {}
    @refs_to_write = []
  end
  
  def add(objects, *row_md5s)
    objects.each do |object|
      ref, value_md5 = ObjectRef.from_object(object)
      
      if has_ref?(ref)
        existing_rows = @rows_by_ref[ref].map(&@csvs.method(:location)).join(", ")
        existing_rows = "unknown csvs / rows" if existing_rows.blank?
        return ["duplicate of #{object[:class]} from #{existing_rows}"]
      end
      
      @data_by_ref[ref] = object
      @rows_by_ref[ref] = (row_md5s + row_md5_chain(object)).flatten.uniq
      @vals_by_ref[ref] = value_md5
      
      @refs_to_write << ref
    end
    
    []
  end
  
  def commit(group)
    return if @refs_to_write.empty?
    
    data_by_ref = {}
    rows_by_ref = {}
    vals_by_ref = {}
    @refs_to_write.each do |ref|
      data_by_ref[ref] = @data_by_ref.delete(ref)
      rows_by_ref[ref] = @rows_by_ref[ref]
      vals_by_ref[ref] = @vals_by_ref[ref]
      @groups_by_ref[ref] = group
    end
    @refs_to_write.clear
    
    {@data_dir => data_by_ref, @refs_dir => vals_by_ref, @rows_dir => rows_by_ref}.each do |dir, set|
      path = dir / group
      data = (File.open(path) { |f| Marshal.load(f) } rescue {})
      data.update(set)
      File.open(path, "w") { |f| Marshal.dump(data, f) }
    end
  end
  
  def data_for(ref)
    data = @data_by_ref[ref]
    return data unless data.nil?
    
    path = @data_dir / @groups_by_ref[ref]
    return nil unless File.exist?(path)
    
    # TODO: remove once marshal stops blowing up in ruby 1.8
    GC.disable
    data_by_ref = File.open(path) { |f| Marshal.load(f) }
    GC.enable
    @data_by_ref.update(data_by_ref)[ref]
  end
  
  def delete_obsolete
    row_md5s = @csvs.row_md5s.to_set
    
    obsolete_groups = []
    refs_by_row = {}
    @rows_by_ref.each do |ref, rows|
      rows.each { |row| (refs_by_row[row] ||= []) << ref }
    end
    obsolete_refs = refs_by_row.values_at(*(refs_by_row.keys.to_set - row_md5s)).flatten.uniq
    
    # any object with parents (A and B) in two different rows might be deleted because A is removed
    # unfortunately, because other items produced from B might still exist, the importer wouldn't know that
    # it needed to completely refresh B - thus we allow row obsolescence to propagate up to a child object's
    # primary parent row (which will be the row already marked obsolete in all other cases)
    implictly_obsolete_rows = @rows_by_ref.values_at(*obsolete_refs).map(&:first)
    obsolete_refs = (obsolete_refs + refs_by_row.values_at(*implictly_obsolete_rows).flatten).uniq
    
    obsolete_refs.group_by { |ref| @groups_by_ref.delete(ref) }.each do |name, refs|
      obsolete_groups << name
      
      [@data_dir, @refs_dir, @rows_dir].each do |dir|
        path = dir / name
        data = File.open(path) { |f| Marshal.load(f) } rescue {}
        refs.each { |ref| data.delete(ref) }
        if data.empty? then File.delete(path)
        else File.open(path, "w") { |f| Marshal.dump(data, f) }
        end
      end
    end
    
    obsolete_refs.each do |ref|
      @data_by_ref.delete(ref)
      @rows_by_ref.delete(ref)
      @vals_by_ref.delete(ref)
    end
    
    puts " - deleted #{obsolete_refs.size} objects in #{obsolete_groups.size} groups" unless obsolete_refs.empty?
  end
  
  def each(&block)
    Dir[@data_dir / "*"].each do |path|
      # TODO: remove once marshal stops blowing up in ruby 1.8
      GC.disable
      File.open(path) { |f| Marshal.load(f) }.each(&block)
      GC.enable
    end
  end
  
  def has_ref?(ref)
    @vals_by_ref.has_key?(ref)
  end
  
  def row_md5_chain(object)
    case object
    when Array     then object.map { |v| row_md5_chain(v) }
    when Hash      then object.values.map { |v| row_md5_chain(v) }
    when ObjectRef then @rows_by_ref[object]
    else []
    end
  end
  
  def summarize
    puts " > managing #{@groups_by_ref.size} objects in #{@groups_by_ref.values.uniq.size} groups"
  end
end

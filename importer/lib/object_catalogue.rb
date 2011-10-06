class ObjectCatalogue
  def self.default
    @@default
  end
  
  attr_reader :verifier
  
  def initialize(csv_catalogue, dir, verifier_dir)
    @@default = self
    
    @csvs = csv_catalogue
    @dir = dir
    
    @data_by_ref = OklahomaMixer.open(dir / "data.tch")
    @refs_by_row_md5 = OklahomaMixer.open(dir / "refs_by_row.tcb")
    @row_md5s_by_ref = OklahomaMixer.open(dir / "rows_by_ref.tcb")
    @value_md5s_by_ref = OklahomaMixer.open(dir / "value_md5s.tch")
    @queues_by_name = {}
    
    delete_inconsistent
    delete_obsolete
    
    @verifier = ObjectVerifier.new(csv_catalogue, self, verifier_dir)
  end
  
  def add(objects, *row_md5s)
    flush_pending(true)
    
    orvs = objects.map do |object|
      ref, value_md5 = ObjectRef.from_object(object)
      if has_ref?(ref)
        existing_rows = row_md5s_for(ref).map(&@csvs.method(:location)).join(", ")
        existing_rows = "unknown csvs / rows" if existing_rows.blank?
        return ["duplicate of #{object[:class]} from #{existing_rows}: #{object.inspect}"]
      end
      [object, ref, value_md5]
    end
    
    orvs.each do |object, ref, value_md5|
      @data_by_ref[ref] = Marshal.dump(object)
      @value_md5s_by_ref[ref] = value_md5
      
      (row_md5s + row_md5_chain(object)).flatten.uniq.each do |row_md5|
        @refs_by_row_md5.store(row_md5, ref, :dup)
        @row_md5s_by_ref.store(ref, row_md5, :dup)
      end
      
      @queues_by_name.each_value do |db, block|
        key, value = block.call(ref, object)
        db.store(key, value, :dup) unless key.nil?
      end
      
      @verifier.added(ref, object)
    end
    
    []
  end
  
  def add_queue(name, &block)
    @queues_by_name[name] = [OklahomaMixer.open(@dir / "queue_#{name}.tcb", "wcs"), block]
  end
  
  def all_row_md5s
    @refs_by_row_md5.keys
  end
  
  def data_for(ref)
    data = @data_by_ref[ref]
    data.nil? ? nil : Marshal.load(data)
  end
  
  def delete_inconsistent
    return unless flush_pending?
    puts " ! possible inconsistent state detected - running consistency scan"
    
    # this is slower than keyset operations in memory but far more memory efficient for large object sets
    bad_refs = []
    by_ref_stores = [@data_by_ref, @row_md5s_by_ref, @value_md5s_by_ref]
    refs_checked = []
    
    by_ref_stores.each_with_index do |master, i|
      slaves = by_ref_stores[0...i] + by_ref_stores[(i + 1)..-1]
      master.each_key do |ref|
        next if i > 0 and refs_checked.include?(ref)
        bad_refs << ref unless slaves.all? { |db| db.has_key?(ref) }
        refs_checked << ref
      end
      refs_checked = refs_checked.to_set if i == 0
    end
    
    by_ref_stores.each do |db|
      if db.is_a?(OklahomaMixer::BTreeDatabase) then bad_refs.each { |ref| db.delete(ref, :dup) }
      else bad_refs.each(&db.method(:delete))
      end
    end
    flush
    
    puts(bad_refs.empty? ? " - all objects consistent" : " ! #{bad_refs.size} inconsistent objects deleted")
  end
  
  def delete_obsolete
    bad_row_md5s = all_row_md5s - @csvs.row_md5s
    puts " - #{bad_row_md5s.size} obsolete rows" unless bad_row_md5s.empty?
    bad_refs = refs_for(bad_row_md5s)
    puts " - #{bad_refs.size} obsolete objects" unless bad_refs.empty?
    
    # any object with parents (A and B) in two different rows might be deleted because A is removed
    # unfortunately, because other items produced from B might still exist, the importer wouldn't know that
    # it needed to completely refresh B - thus we allow row obsolescence to propagate up to a child object's
    # primary parent row (which will be the row already marked obsolete in all other cases)
    implicit_bad_row_md5s = (@row_md5s_by_ref.values_at(*bad_refs) - bad_row_md5s).uniq.compact
    puts " - #{implicit_bad_row_md5s.size} implicitly obsolete rows" unless implicit_bad_row_md5s.empty?
    implicit_bad_refs = (refs_for(implicit_bad_row_md5s) - bad_refs)
    puts " - #{implicit_bad_refs.size} implicitly obsolete objects" unless implicit_bad_refs.empty?
    
    flush_pending(true)
    (bad_refs + implicit_bad_refs).each do |ref|
      @data_by_ref.delete(ref)
      @row_md5s_by_ref.delete(ref, :dup)
      @value_md5s_by_ref.delete(ref)
    end
    (bad_row_md5s + implicit_bad_row_md5s).each { |md5| @refs_by_row_md5.delete(md5, :dup) }
    flush
    
    stores.each(&:defrag)
  end
  
  def each_ref(&block)
    @data_by_ref.each_key(&block)
  end
  
  def flush
    stores.each(&:flush)
    flush_pending(false)
  end
  
  def flush_pending(pending)
    if pending then FileUtils.touch(@dir / "_flush_pending")
    elsif flush_pending? then File.delete(@dir / "_flush_pending")
    end
  end
  
  def flush_pending?
    File.exist?(@dir / "_flush_pending")
  end
  
  def has_ref?(ref)
    @data_by_ref.has_key?(ref)
  end
  
  def queue_each(name, keys = nil)
    db = (@queues_by_name[name].first rescue nil)
    return if db.nil?
    
    keys_to_delete = []
    key_vals_to_delete = []
    (keys || db.keys).each do |key|
      values = db.values(key)
      val_set = values.to_set
      if val_set.size < values.size
        db.delete(key, :dup)
        val_set.each { |val| db.store(key, val, :dup) }
      end
      
      vals_to_delete = yield(key, val_set)
      if vals_to_delete.to_set == val_set then keys_to_delete << key
      else key_vals_to_delete += vals_to_delete.map { |val| [key, val] }
      end
    end
    
    keys_to_delete.each { |key| db.delete(key, :dup) }
    
    key_vals_to_delete = key_vals_to_delete.to_set
    db.delete_if { |key, value| key_vals_to_delete.include?([key, value]) } unless key_vals_to_delete.empty?
    
    db.flush
    db.defrag
  end
  
  def queue_get(name, key, &block)
    queue_each(name, [key], &block)
  end
  
  def queue_size(name, keys_only = false)
    db = (@queues_by_name[name].first rescue nil)
    (keys_only ? db.keys.size : db.size) unless db.nil?
  end
  
  def refs_for(row_md5s)
    row_md5s.map { |md5| @refs_by_row_md5.values(md5) }.flatten.uniq
  end
  
  def row_md5s_for(ref)
    @row_md5s_by_ref.values(ref)
  end
  
  def row_md5_chain(object)
    case object
    when Array     then object.map { |v| row_md5_chain(v) }
    when Hash      then object.values.map { |v| row_md5_chain(v) }
    when ObjectRef then row_md5s_for(object)
    else []
    end
  end
  
  def stores
    [@data_by_ref, @refs_by_row_md5, @row_md5s_by_ref, @value_md5s_by_ref] + @queues_by_name.values.map(&:first)
  end
  
  def summarize
    puts " > managing #{@data_by_ref.size} objects"
  end
  
  def value_md5_for(ref)
    @value_md5s_by_ref[ref]
  end
end

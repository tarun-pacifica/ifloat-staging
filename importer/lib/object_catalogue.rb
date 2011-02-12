class ObjectCatalogue
  def initialize(dir)
    @dir = dir
    build_catalogue
  end
  
  def build_catalogue
    @objects_by_pk_md5 = {}  # not used at all yet
    @objects_by_row_md5 = {}
    
    @objects = Dir[@dir / "*"].map do |path|
      klass, pk_md5, val_md5, *row_md5s = File.basename(path).split("_")
      object = [klass, pk_md5, val_md5, row_md5s]
      @objects_by_pk_md5[pk_md5] = object
      row_md5s.each { |row_md5| (@objects_by_row_md5[row_md5] ||= []) << object }
      object
    end
  end
  
  def delete_obsolete_objects(row_md5s)
    obsolete_row_md5s = (@objects_by_row_md5.keys.to_set - row_md5s)
    obsolete_objects = @objects_by_row_md5.values_at(*obsolete_row_md5s)    
    obsolete_objects.map { |o| @dir / o[0] }.delete_and_log("obsolete objects")
    build_catalogue unless obsolete_objects.empty?
  end
  
  def missing_auto_objects_row_md5s(auto_row_md5s, product_row_md5s)
    missing_auto_row_md5s = []
    seen_row_md5s = []
    
    auto_row_md5s.each do |md5|
      objects = @objects_by_row_md5[md5]
      if objects.nil? then missing_auto_row_md5s << md5
      else seen_row_md5s += objects.map { |o| objects[3] }
      end
    end
    
    [missing_auto_row_md5s, product_row_md5s - seen_row_md5s]
  end
  
  def missing_object_row_md5s(row_md5s)
    row_md5s - @objects_by_row_md5.keys.to_set
  end
end

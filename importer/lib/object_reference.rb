class ObjectReference
  attr_reader :path, :klass, :pk_md5, :val_md5, :row_md5s
  
  def self.from_memory(dir, klass, pk_md5, val_md5, row_md5s)
    name = ([klass, pk_md5, val_md5] + row_md5s).join("_")
    new(dir / name, klass, pk_md5, val_md5, row_md5s)
  end
  
  def self.from_path(path)
    klass, pk_md5, val_md5, *row_md5s = File.basename(path).split("_")
    new(path, klass, pk_md5, val_md5, row_md5s)
  end
  
  def initialize(path, klass, pk_md5, val_md5, row_md5s)
    @path = path
    @klass = klass
    @pk_md5 = pk_md5
    @val_md5 = val_md5
    @row_md5s = row_md5s
  end
  
  def[](key)
    @attributes[key]
  end
  
  def attributes
    @attributes ||= Marshal.load(File.open(@path))
  end
  
  def class_pk_md5
    [@klass, @pk_md5]
  end
  
  def write(object)
    Marshal.dump(object, File.open(@path, "w"))
  end
end

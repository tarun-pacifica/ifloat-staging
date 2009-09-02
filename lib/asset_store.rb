module AssetStore
  # TODO: period compare and delete from the store (for all obsolete storage names)
  @@engine = nil
  
  def self.config(engine, config = {})
    engine_class = const_get(engine.to_s.split("_").map { |word| word.capitalize }.join) rescue nil
    raise "unknown asset store engine #{engine.inspect}" if engine_class.nil?
    @@engine = engine_class.new(config)    
  end
  
  def self.method_missing(method, *args)
    raise "asset store engine not configured" if @@engine.nil?
    super unless [:delete_obsolete, :url, :write].include?(method)
    @@engine.send(method, *args)
  end
  
  
  class Abstract
    def initialize(config)
      @required_keys ||= []
      @required_keys << :url_stem
      @required_keys.each { |key| raise "#{self.class} must be configured with a #{key}" unless config.has_key?(key) }
      config.each { |key, value| instance_variable_set("@#{key}", value) }
    end
    
    def delete_obsolete
      list_by_bucket.each do |bucket, names|
        current_names = Asset.all(:bucket => bucket).map { |asset| asset.store_name }
        (names - current_names).each { |name| delete(bucket, name) }
      end
    end
    
    def url(asset)
      url_direct(asset.bucket, asset.store_name)
    end
    
    def url_direct(bucket, name)
      "#{@url_stem}/#{bucket}/#{name}"
    end
  end
    
  
  class Local < Abstract
    def initialize(config)
      @required_keys = [:local_root]
      super
    end
    
    def delete(bucket, name)
      begin
        File.delete(local_dir(bucket) / name)
      rescue
        false
      end
    end
    
    def list_by_bucket
      names_by_bucket = {}
      Dir[@local_root / "*"].each do |bucket_path|
        next unless File.directory?(bucket_path)
        names_by_bucket[File.basename(bucket_path)] = Dir[bucket_path / "*"].map { |path| File.basename(path) }
      end
      names_by_bucket
    end
    
    def local_dir(bucket)
      @local_root / bucket
    end
    
    def local_path(asset)
      begin
        dir = local_dir(asset.bucket)
        FileUtils.mkpath(dir)
        yield dir, asset.store_name
      rescue
        nil
      end
    end
    
    def write(asset)
      local_path(asset) { |dir, name| File.link(asset.file_path, dir / name) }
    end
  end
  
  
  class Mosso < Abstract
    def initialize(config)
      @required_keys = [:user, :key, :container]
      super
    end
    
    def container
      @connection ||= (CloudFiles::Connection.new(@user, @key) rescue nil)
      return nil if @connection.nil?
      
      begin
        @cont ||= @connection.container(@container)
      rescue
      end      
      return nil if @cont.nil?
      
      yield @cont rescue nil
    end
    
    def delete(bucket, name)
      container { |c| c.delete_object("#{bucket}/#{name}") }
    end
    
    def list_by_bucket
      names_by_bucket = {}
      container do |c|
        c.objects.each do |path|
          dir, name = path.split("/")
          names_by_bucket[dir] = name
        end
      end
      names_by_bucket
    end
    
    def write(asset)
      container do |c|
        object = c.create_object("#{asset.bucket}/#{asset.store_name}")
        object.load_from_filename(asset.file_path) if object.bytes.to_i != File.size(asset.file_path)
      end
    end    
  end
end
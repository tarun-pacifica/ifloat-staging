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
    super unless [:delete_obsolete, :url, :url_direct, :write].include?(method)
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
        db_names = Asset.all(:bucket => bucket).map { |asset| asset.store_names }.flatten
        (names - db_names).each { |name| delete(bucket, name) }
      end
    end
    
    def url(asset, variant = nil)
      url_direct(asset.bucket, asset.store_name(variant))
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
    
    def local_path(asset, variant = nil)
      begin
        dir = local_dir(asset.bucket)
        FileUtils.mkpath(dir)
        yield dir, asset.store_name(variant)
      rescue
        nil
      end
    end
    
    def write(asset, variant = nil)
      source_path = asset.file_path(variant)
      local_path(asset, variant) do |dir, name|
        target_path = dir / name
        File.link(source_path, target_path) unless File.exist?(target_path)
      end unless source_path.nil?
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
    
    def write(asset, variant = nil)
      source_path = asset.file_path(variant)
      container do |c|
        object = c.create_object("#{asset.bucket}/#{asset.store_name(variant)}")
        object.load_from_filename(source_path) if object.bytes.to_i != File.size(source_path)
      end unless source_path.nil?
    end
  end
end
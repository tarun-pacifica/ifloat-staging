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
      @user = config.delete(:user) || (raise "specify a user")
      @key = config.delete(:key) || (raise "specify a key")
      super
    end
    
    def container(bucket, auto_create = false)
      @connection = @connection.nil? ? (CloudFiles::Connection.new(@user, @key) rescue nil) : @connection
      return nil if @connection.nil?
      
      cont = nil
      begin
        cont = @connection.container(bucket)
      rescue CloudFiles::NoSuchContainerException
        cont = (create_container(bucket) rescue nil) if auto_create
      end      
      return nil if cont.nil?
      
      yield cont rescue nil
    end
    
    def delete(bucket, name)
      container(bucket) do |c|
        c.delete_object(name)
      end
    end
          
    def write(bucket, name, data)
      container(bucket, true) do |c|
        storage_object = c.create_object(name)
        storage_object.write(data)
        storage_object.public_url
      end
    end    
  end
end
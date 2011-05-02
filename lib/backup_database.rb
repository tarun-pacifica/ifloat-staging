AssetStore.config(:mosso, :user => "pristine", :key => "b7db73b0bd047f7292574d7c9f0d16de", :container => "ifloat-backups", :url_stem => "")
BACKUP_DIR = "/tmp/ifloat_backups"

class BackupAsset
  def initialize(path)
    @path = path
  end
  
  def bucket
    "#{Merb.environment}_database"
  end
  
  def file_path(*args)
    @path
  end
  
  def store_name(*args)
    File.basename(@path)
  end
end

begin
  config = Merb::Orms::DataMapper.config
  raise "script requires a local connection to a mysql database" unless config[:adapter] == "mysql" and config[:host] == "localhost"
  
  FileUtils.mkpath(BACKUP_DIR, :mode => 0700)
  
  cnf_path = BACKUP_DIR / "mysql_defaults.cnf"
  File.open(cnf_path, "w") do |f|
    f.puts "[client]"
    f.puts "user=#{config[:username]}"
    f.puts "password=#{config[:password]}"
  end
    
  bak_path = BACKUP_DIR / Time.now.strftime("%Y%m%dT%H%M%S.sql.bz")
  system "mysqldump --defaults-file=#{cnf_path.inspect} #{config[:database]} | bzip2 > #{bak_path.inspect}"    
  AssetStore.write(BackupAsset.new(bak_path))
    
rescue Exception => e
  Mailer.deliver(:exception, :exception => e, :whilst => "backing up database")
  
end

# merb -i -r lib/import_prices.rb

extend Merb::MailerMixin

PRICES_REPO = "../ifloat_prices"

facilities_by_url = Facility.all.hash_by(:primary_url)

Dir[PRICES_REPO / "*"].each do |path|
  next unless File.directory?(path)
  
  url = File.basename(path)
  facility = facilities_by_url[url]
  next if facility.nil?
  
  begin
    product_info_by_ref = YAML.load(File.open(path / "prices.yaml"))
    facility.update_products(product_info_by_ref)
  rescue Exception => e
    mail_attributes = {
      :from    => "admin@ifloat.biz",
      :to      => "andre@bluetheta.com",
      :subject => "Price import failure on #{`hostname`.chomp} (#{Merb.environment} environment)"
    }
        
    send_mail(MainMailer, :exception, mail_attributes, {:context => url, :exception => e})
  end
end

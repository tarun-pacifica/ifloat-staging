# dependencies are generated using a strict version, don't forget to edit the dependency versions when upgrading.
merb_gems_version = "1.0.12"
dm_gems_version   = "0.9.11"
do_gems_version   = "0.9.12"

# For more information about each component, please read http://wiki.merbivore.com/faqs/merb_components
dependency "merb-core", merb_gems_version 
dependency "merb-action-args", merb_gems_version
dependency "merb-assets", merb_gems_version  
dependency("merb-cache", merb_gems_version) do
  Merb::Cache.setup do
    register(Merb::Cache::FileStore) unless Merb.cache
  end
end
dependency "merb-helpers", merb_gems_version 
dependency "merb-mailer", merb_gems_version  
dependency "merb-exceptions", merb_gems_version

dependency "data_objects", do_gems_version
dependency "do_mysql", do_gems_version
dependency "dm-core", dm_gems_version         
dependency "dm-aggregates", dm_gems_version   
dependency "dm-migrations", dm_gems_version   
dependency "dm-timestamps", dm_gems_version   
dependency "dm-types", dm_gems_version        
dependency "dm-validations", dm_gems_version  
dependency "dm-serializer", dm_gems_version   

dependency "merb_datamapper", merb_gems_version

# Standard library
require "fileutils"

# Non-merb gems
dependency "fastercsv"
dependency "rackspace-cloudfiles", :require_as => "cloudfiles"

# Internal libraries
require "lib" / "asset_store"
require "lib" / "conversion"
require "lib" / "indexer"
require "lib" / "password"

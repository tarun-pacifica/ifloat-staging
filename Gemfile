bundle_path "gems"

clear_sources
source "http://gemcutter.org"

def gems(names, version)
  names.each { |n| gem(n, version) }
end

# DataObjects, DataMapper and Merb
gems %w(data_objects do_mysql), "0.10.0"
gems %w(dm-core dm-aggregates dm-migrations dm-types dm-validations), "0.10.2"
gems %w(merb-core merb-action-args merb-helpers merb-mailer merb_datamapper), "1.1.0.pre"
# merb-assets merb-exceptions ?

# Others
gem "cloudfiles", "1.4.4"
gem "fastercsv", "1.5.0"
gem "image_science", "1.2.0"
gem "thin", "1.2.5"

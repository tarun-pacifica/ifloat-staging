source :gemcutter

# http://github.com/carlhuda/bundler/issues/#issue/107
gem "bundler", "0.9.10"

def gems(names, version)
  names.each { |n| gem(n, version) }
end

# DataObjects, DataMapper and Merb
gems %w(data_objects do_mysql), "0.10.1"
gems %w(dm-core dm-aggregates dm-migrations dm-types dm-validations), "0.10.2"
gems %w(merb-core merb-action-args merb-helpers merb_datamapper), "1.1.0.pre"

# Others
gem "cloudfiles", "1.4.6"
gem "fastercsv",  "1.5.1" unless RUBY_VERSION =~ /^1\.9\./
gem "json",       "1.2.2"
gem "mail",       "2.1.5.3"
gem "rspec",      "1.3.0"
gem "thin",       "1.2.7"

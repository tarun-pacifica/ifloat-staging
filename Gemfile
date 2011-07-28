source :gemcutter

def gems(names, version)
  names.each { |n| gem(n, version) }
end

# DataMapper and Merb
gems %w(dm-core dm-aggregates dm-migrations dm-mysql-adapter dm-transactions dm-types dm-validations), "1.1.0"
gems %w(merb-core merb-action-args merb-helpers merb_datamapper), "1.1.3"

# Others
gem "bluecloth",      "2.0.9"
gem "cloudfiles",     "1.4.10"
gem "fastercsv",      "1.5.4" unless RUBY_VERSION =~ /^1\.9\./
gem "i18n",           "0.5.0"
gem "json",           "1.4.6"
gem "mail",           "2.2.12"
gem "nokogiri",       "1.4.4"
gem "oklahoma_mixer", "0.4.0"
gem "rspec",          "2.3.0"
gem "thin",           "1.2.7"
gem "zip",            "2.0.2"

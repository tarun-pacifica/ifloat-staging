# = Summary
#
# ImportEvents track successful runs of lib/import_core_data (both as an audit record and to support CacheFind auto-re-execution). 
#
# === Sample Data
#
# completed_at:: 1981/09/05 12:34:56
# succeeded:: true
# report:: 'Asset repo version: ...'
#
class ImportEvent # TODO: spec
  include DataMapper::Resource
  
  property :id, Serial
  property :completed_at, DateTime, :required => true, :default => proc { DateTime.now }
  property :succeeded, Boolean, :required => true
  property :report, Text, :required => true
end

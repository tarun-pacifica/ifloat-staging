# = Summary
#
# ImportEvents track successful runs of lib/import_core_data (both as an audit record and to support CacheFind auto-re-execution). 
#
# === Sample Data
#
# ran_at:: 1981/09/05 12:34:56
# succeeded:: true
# report:: 'Asset repo version: ...'
#
class ImportEvent
  include DataMapper::Resource
  
  property :id, Serial
  property :ran_at, DateTime, :nullable => false
  property :succeeded, Boolean, :nullable => false
  property :report, String, :nullable => false
end

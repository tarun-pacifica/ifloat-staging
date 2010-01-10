# = Summary
#
# ImportEvents track runs of lib/import_core_data (to provide an audit record). They are currently only used to track successful runs.
#
# === Sample Data
#
# completed_at:: 1981/09/05 12:34:56
# succeeded:: true
# report:: 'Asset repo version: ...'
#
class ImportEvent
  include DataMapper::Resource
  
  property :id, Serial
  property :completed_at, DateTime, :required => true, :default => proc { DateTime.now }
  property :succeeded, Boolean, :required => true
  property :report, Text, :required => true
end

module HouseKeeping
  def self.run
    begin
      # TODO: exception if already running
      expire_old_sessions
      # TODO: cached_find anonimization (may not need to delete filters if they are subsumed into cached finds)
      # TODO: tidy up obsolete assets
      # TODO: tidy up obsolete controller errors
      # TODO: Purchase.abandon_obsolete
    rescue Exception => e
      p e
      # TODO: send mail
    end
  end
  
  
  private
  
  def self.expire_old_sessions
    ttl = Merb::Config[:session_ttl]
    Merb::DataMapperSession.store.all(:created_at.lt => ttl.ago).destroy!
  end
end
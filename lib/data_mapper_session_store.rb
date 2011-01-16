class Merb::DataMapperSessionStore
  EXPIRY_DAYS = 180
  
  has n, :events,    :child_key => [:session_id], :model => "SessionEvent"
  has n, :purchases, :child_key => [:session_id]
  
  before(:destroy) do
    events.destroy!
  end
  
  def self.expired
    query =<<-SQL
      SELECT session_id
      FROM sessions
      WHERE session_id NOT IN (SELECT session_id FROM purchases)
        AND session_id NOT IN (SELECT session_id FROM session_events WHERE created_at > ?)
    SQL
    
    session_ids = repository(:default).adapter.select(query, DateTime.now - EXPIRY_DAYS)
    all(:created_at.lt => DateTime.now - 1, :session_id => session_ids)
  end
end

class Purchases < Application
  def track(facility)
    purchases = session.purchases
    return "" if purchases.empty?
    
    facility = Facility.first(:primary_url => facility)
    raise NotFound unless facility
    
    purchase = purchases.find { |purc| purc.facility_id == facility.id }
    raise NotFound unless purchase
    
    purchase.complete!(params)
    session.remove_purchase(purchase)
    ""
  end
end

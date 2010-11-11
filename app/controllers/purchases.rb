class Purchases < Application
  def track(facility)
    purchases = session.purchases
    return "" if purchases.empty?
    
    facility = Facility.first(:primary_url => facility)
    raise NotFound if facility.nil?
    
    purchase = purchases.find { |purc| purc.facility_id == facility.id }
    raise NotFound if purchase.nil?
    
    references = purchase.complete!(params, request.remote_ip)
    Mailer.deliver(:purchase_completed, :purchase => purchase)
    session.remove_purchase(purchase)
    
    prod_ids_by_ref = facility.map_references(references)
    product_ids = prod_ids_by_ref.values.flatten.to_set
    
    picks = session.picked_products.select { |pick| product_ids.include?(pick.product_id) }
    session.remove_picked_products(picks)
    
    ""
  end
end

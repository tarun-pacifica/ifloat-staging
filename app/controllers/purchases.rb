class Purchases < Application
  def track(facility)
    purchases = session.purchases
    return "" if purchases.empty?
    
    facility = Facility.first(:primary_url => facility)
    raise NotFound unless facility
    
    purchase = purchases.find { |purc| purc.facility_id == facility.id }
    raise NotFound unless purchase
    
    references = purchase.complete!(params, request.remote_ip)
    session.remove_purchase(purchase)
    
    prod_ids_by_ref = facility.map_references(references)
    product_ids = prod_ids_by_ref.values.flatten.to_set
    
    picks = session.picked_products.select { |pick| pick.group == "buy_now" && product_ids.include?(pick.product_id) }
    session.remove_picked_products(picks)
    
    ""
  end
end

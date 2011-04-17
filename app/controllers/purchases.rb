class Purchases < Application
  def track(facility)
    return "" if request.session_cookie_value.nil? # NOTE: private / unstable API
    
    last_event = session.last_event
    return "" if last_event.nil?
    
    raise NotFound unless Indexer.facilities.has_key?(facility)
    facility = Facility.first(:primary_url => facility)
    return "" if last_event.created_at + facility.purchase_ttl < DateTime.now
    
    response = Purchase.parse_response(params)
    purchase = facility.purchases.new(:ip_address => request.remote_ip, :response => response)
    session.add_purchase(purchase)
    Mailer.deliver(:purchase_completed, :purchase => purchase, :userish => session.userish(request))
    
    references = response[:items].map { |item| item["reference"] }.compact.uniq
    implied_product_ids = facility.product_ids_for_refs(references).to_set
    picks = session.picked_products.select { |pick| implied_product_ids.include?(pick.product_id) }
    session.remove_picked_products(picks)
    
    ""
  end
end

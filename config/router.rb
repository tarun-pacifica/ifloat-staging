Merb.logger.info("Compiling routes...")

Merb::Router.prepare do
  # TODO: remove for launch
  match('/prelaunch/:action').to(:controller => 'prelaunch')
  
  match('/tools/:action').to(:controller => 'tools')
  
  resources :articles
  
  match('/blogs/:name').to(:controller => 'blogs', :action => 'show').name(:blogs)
  
  match('/cached_finds/conversions.js').to(:controller => 'cached_finds', :action => 'conversions', :format => 'js')
  match('/cached_finds/:id/reset').to(:controller => 'cached_finds', :action => 'reset')
  resources :cached_finds
  match('/cached_finds/:id/found_product_ids/:limit').to(:controller => 'cached_finds', :action => 'found_product_ids', :format => 'js')
  match('/cached_finds/:find_id/filters/:filter_id/:action').to(:controller => 'filters')
  match('/cached_finds/:find_id/relevant_filter_ids').to(:controller => 'filters', :action => 'relevant_filter_ids')
  
  match('/future_purchases/buy/:facility_id').to(:controller => 'future_purchases', :action => 'buy')
  match('/future_purchases/buy_options').to(:controller => 'future_purchases', :action => 'buy_options')
  resources :future_purchases
  
  resources :products
  match('/products/batch/:ids').to(:controller => 'products', :action => 'batch')
  match('/products/:id/purchase_buttons').to(:controller => 'products', :action => 'purchase_buttons')
  
  match('/purchases/track').to(:controller => 'purchases', :action => 'track')
  
  match('/users/login').to(:controller => 'users', :action => 'login')
  match('/users/logout').to(:controller => 'users', :action => 'logout')
  resources :users
  
  match('/').to(:controller => 'cached_finds', :action =>'new')
end
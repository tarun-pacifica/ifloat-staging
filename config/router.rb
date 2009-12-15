Merb.logger.info("Compiling routes...")

Merb::Router.prepare do
  # TODO: remove for launch
  match('/prelaunch/:action').to(:controller => 'prelaunch')
  
  match('/tools/caches/:basename.:ext').to(:controller => 'tools', :action => 'caches]')
  match('/tools/:action').to(:controller => 'tools')
  
  resources :articles
  
  match('/blogs/:name').to(:controller => 'blogs', :action => 'show').name(:blogs)
  
  match('/cached_finds/conversions.js').to(:controller => 'cached_finds', :action => 'conversions', :format => 'js')
  match('/cached_finds/:id/filter/:property_id').to(:controller => 'cached_finds', :action => 'filter')
  match('/cached_finds/:id/found_images/:limit').to(:controller => 'cached_finds', :action => 'found_images', :format => 'js')
  match('/cached_finds/:id/found_products/:image_checksum').to(:controller => 'cached_finds', :action => 'found_products')
  match('/cached_finds/:id/reset').to(:controller => 'cached_finds', :action => 'reset')
  resources :cached_finds
  
  match('/future_purchases/buy/:facility_id').to(:controller => 'future_purchases', :action => 'buy')
  match('/future_purchases/buy_options').to(:controller => 'future_purchases', :action => 'buy_options')
  resources :future_purchases
  
  match('/products/batch/:ids').to(:controller => 'products', :action => 'batch')
  match('/products/:id/purchase_buttons').to(:controller => 'products', :action => 'purchase_buttons')
  resources :products
  
  match('/purchases/track').to(:controller => 'purchases', :action => 'track')
  
  match('/users/login').to(:controller => 'users', :action => 'login')
  match('/users/logout').to(:controller => 'users', :action => 'logout')
  resources :users
  
  match('/').to(:controller => 'cached_finds', :action =>'new')
end
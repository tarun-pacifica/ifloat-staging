Merb.logger.info("Compiling routes...")

Merb::Router.prepare do
  # TODO: remove for launch
  match('/prelaunch/:action').to(:controller => 'prelaunch')
  
  match('/tools/caches/:basename.:ext').to(:controller => 'tools', :action => 'caches]')
  match('/tools/:action').to(:controller => 'tools')
  
  resources :articles
  
  match('/blogs/:name').to(:controller => 'blogs', :action => 'show').name(:blogs)
  
  match('/cached_finds/:id/filter/:property_id').to(:controller => 'cached_finds', :action => 'filter')
  match('/cached_finds/:id/filters').to(:controller => 'cached_finds', :action => 'filters', :format => 'js')
  match('/cached_finds/:id/found_images/:limit').to(:controller => 'cached_finds', :action => 'found_images', :format => 'js')
  match('/cached_finds/:id/found_products_for_checksum/:image_checksum').to(:controller => 'cached_finds', :action => 'found_products_for_checksum')
  match('/cached_finds/:id/reset').to(:controller => 'cached_finds', :action => 'reset')
  resources :cached_finds
  
  match('/picked_products/buy/:facility_id').to(:controller => 'picked_products', :action => 'buy')
  match('/picked_products/compare/:klass').to(:controller => 'picked_products', :action => 'compare')
  match('/picked_products/options').to(:controller => 'picked_products', :action => 'options')
  resources :picked_products
  
  match('/products/batch/:ids').to(:controller => 'products', :action => 'batch')
  match('/products/:id/picked_group').to(:controller => 'products', :action => 'picked_group')
  resources :products
  
  match('/purchases/track').to(:controller => 'purchases', :action => 'track')
  
  match('/users/login').to(:controller => 'users', :action => 'login')
  match('/users/logout').to(:controller => 'users', :action => 'logout')
  resources :users
  
  match('/').to(:controller => 'cached_finds', :action =>'new')
end
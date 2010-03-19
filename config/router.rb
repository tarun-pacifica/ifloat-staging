Merb.logger.info("Compiling routes...")

Merb::Router.prepare do
  # TODO: remove for launch
  match('/prelaunch/:action').to(:controller => 'prelaunch')
  
  match('/tools/:action').to(:controller => 'tools')
  
  resources :articles
  
  match('/blogs/:name').to(:controller => 'blogs', :action => 'show').name(:blogs)
  
  match('/cached_finds/:id/filter/:property_id', :method => 'get').to(:controller => 'cached_finds', :action => 'filter_get')
  match('/cached_finds/:id/filter/:property_id', :method => 'post').to(:controller => 'cached_finds', :action => 'filter_set')
  match('/cached_finds/:id/filters/:list').to(:controller => 'cached_finds', :action => 'filters', :format => 'js')
  match('/cached_finds/:id/found_images/:limit').to(:controller => 'cached_finds', :action => 'found_images', :format => 'js')
  match('/cached_finds/:id/compare_by_image/:image_checksum').to(:controller => 'cached_finds', :action => 'compare_by_image')
  match('/cached_finds/:id/reset').to(:controller => 'cached_finds', :action => 'reset')
  resources :cached_finds
  
  match('/picked_products/buy/:facility_id').to(:controller => 'picked_products', :action => 'buy')
  match('/picked_products/compare/:klass').to(:controller => 'picked_products', :action => 'compare')
  match('/picked_products/options').to(:controller => 'picked_products', :action => 'options')
  resources :picked_products
  
  match('/products/batch/:ids').to(:controller => 'products', :action => 'batch')
  resources :products
  
  match('/purchases/track').to(:controller => 'purchases', :action => 'track')
  
  match('/users/login').to(:controller => 'users', :action => 'login')
  match('/users/logout').to(:controller => 'users', :action => 'logout')
  resources :users
  
  match('/').to(:controller => 'cached_finds', :action =>'new')
  
  match(/.*/).redirect("/")
end
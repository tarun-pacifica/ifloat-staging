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
  match('/cached_finds/:id/images').to(:controller => 'cached_finds', :action => 'images', :format => 'js')
  match('/cached_finds/:id/products_for/:image_checksum').to(:controller => 'cached_finds', :action => 'compare_by_image')
  match('/cached_finds/:id/reset').to(:controller => 'cached_finds', :action => 'reset')
  match('/cached_finds/create', :method => 'get').to(:controller => 'cached_finds', :action => 'create')
  resources :cached_finds
  
  match('/categories').to(:controller => 'categories', :action => 'show').name(:categories)
  match('/categories/:root').to(:controller => 'categories', :action => 'show').name(:categories)
  match('/categories/:root/:suba').to(:controller => 'categories', :action => 'show').name(:categories)
  match('/categories/:root/:suba/:subb').to(:controller => 'categories', :action => 'show').name(:categories)
  
  match('/picked_products/buy/:facility_id').to(:controller => 'picked_products', :action => 'buy')
  match('/picked_products/products_for/:klass').to(:controller => 'picked_products', :action => 'compare_by_class')
  match('/picked_products/options').to(:controller => 'picked_products', :action => 'options')
  resources :picked_products
  
  match('/products/batch/:ids').to(:controller => 'products', :action => 'batch')
  match('/products/:id/buy_now/:facility_id').to(:controller => 'products', :action => 'buy_now')
  match('/products/:junk-:id').to(:controller => 'products', :action => 'show')
  resources :products
  
  match('/purchases/track').to(:controller => 'purchases', :action => 'track')
  
  match('/users/:id/confirm/:confirm_key').to(:controller => 'users', :action => 'confirm').name(:user_confirm)
  match('/users/login').to(:controller => 'users', :action => 'login')
  match('/users/logout').to(:controller => 'users', :action => 'logout')
  resources :users
  
  match('/').to(:controller => 'cached_finds', :action =>'new')
  
  match(/.*/).redirect("/")
end
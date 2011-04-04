Merb.logger.info("Compiling routes...")

Merb::Router.prepare do
  match('/prelaunch/:action').to(:controller => 'prelaunch')
  
  match('/tools/:action(.:ext)').to(:controller => 'tools')
  
  match('/brands/:name').to(:controller => 'brands', :action => 'show')
  
  match('/categories').to(:controller => 'categories', :action => 'show').name(:categories)
  match('/categories/:root').to(:controller => 'categories', :action => 'show').name(:categories)
  match('/categories/:root/:sub').to(:controller => 'categories', :action => 'show').name(:categories)
  match('/categories/:root/:sub/filter/:id').to(:controller => 'categories', :action => 'filter').name(:categories)
  match('/categories/:root/:sub/filters').to(:controller => 'categories', :action => 'filters').name(:categories)
  
  match('/picked_products/buy/:facility_id').to(:controller => 'picked_products', :action => 'buy')
  match('/picked_products/products_for/:klass').to(:controller => 'picked_products', :action => 'compare_by_class')
  resources :picked_products
  
  match('/products/autocomplete').to(:controller => 'products', :action => 'autocomplete')
  match('/products/batch/:ids').to(:controller => 'products', :action => 'batch')
  match('/products/:junk-:id', :junk => /[\w\-.]+/).to(:controller => 'products', :action => 'show')
  resources :products
  
  match('/purchases/track').to(:controller => 'purchases', :action => 'track')
  
  match('/users/:id/confirm/:confirm_key').to(:controller => 'users', :action => 'confirm').name(:user_confirm)
  match('/users/login').to(:controller => 'users', :action => 'login')
  match('/users/logout').to(:controller => 'users', :action => 'logout')
  match('/users/me').to(:controller => 'users', :action => 'me')
  match('/users/track').to(:controller => 'users', :action => 'track')
  resources :users
  
  match('/').to(:controller => 'categories', :action =>'show')
  
  match("/sitemap.txt").defer_to { [404, {}, ""] }
  match(/.*/).redirect("/")
end
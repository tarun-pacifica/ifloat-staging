module Merb
  module ControllerExceptions
    class Unauthenticated < Unauthorized ; end
  end
  
  module Session
    include Merb::ControllerExceptions
    
    def add_cached_find(cached_find)
      existing_find = cached_finds.find { |cf| cf.specification == cached_find.specification }
      return existing_find unless existing_find.nil?
      
      cached_find.user = user
      self[:cached_find_ids] = (cached_find_ids << cached_find.id) if cached_find.save
      cached_find
    end
    
    def add_picked_product(pick)
      existing = picked_products.find { |p| p.product_id == pick.product_id }
      unless existing.nil?
        existing.group = pick.group
        existing.quantity = pick.quantity
        existing.save
        return
      end
      
      pick.user = user
      update_picked_product_title_values([pick])
      self[:picked_product_ids] = (picked_product_ids << pick.id) if pick.save
    end
    
    def add_purchase(purchase)
      purchase.session_id = session_id
      purchase.user_id = self[:user_id]
      purchase.save
    end
    
    def admin?
      authenticated? and user.admin?
    end
    
    def authenticated?
      not self[:user_id].nil?
    end
    
    def cached_finds
      return [] if cached_find_ids.empty?
      CachedFind.all(:id => cached_find_ids)
    end
    
    def currency
      self[:currency] || "GBP"
    end
    
    def currency=(code)
      self[:currency] = code if code =~ /^[A-Z]{3}$/
    end
    
    def ensure_cached_find(find_id, retrieve = true) # TODO: review all uses to prevent retrieval where unnecessary
      raise NotFound unless cached_find_ids.include?(find_id)
      retrieve ? (CachedFind.get(find_id) or raise NotFound) : nil
    end
    
    def ensure_picked_product(pick_id) # TODO: review all uses to prevent retrieval where unnecessary
      raise NotFound unless picked_product_ids.include?(pick_id)
      PickedProduct.get(pick_id) or raise NotFound
    end
    
    def language
      self[:language] || "ENG"
    end
    
    def language=(code)
      self[:language] = code if code =~ /^[A-Z]{3}$/
    end
    
    def languages
      [language, "ENG"].uniq
    end
    
    def last_event
      SessionEvent.last(:session_id => session_id, :order => [:created_at])
    end
    
    def log!(type, value, ip_address)
      SessionEvent.create(:session_id => session_id, :type => type, :value => value, :ip_address => ip_address)
    end
    
    def login!(login, pass)
      user = User.authenticate(login, pass)
      raise Unauthenticated, "Unknown account / password" if user.nil?
      raise Unauthenticated, "Disabled account" unless user.enabled?
      self[:user_id] = user.id
      
      [[:cached_finds, :specification], [:picked_products, :product_id]].each do |set, discriminator|
        session_set = send(set)
        user_set = user.send(set)
        
        unless session_set.empty?
          user_discriminators = user_set.map { |item| item.send(discriminator) }
          session_set.all(discriminator => user_discriminators).destroy!
          session_set.reload
          session_set.update!(:user_id => user.id)
          user_set.reload
        end
        
        self["#{set.to_s[0..-2]}_ids"] = user_set.map { |item| item.id }
      end
      
      Purchase.all(:session_id => session_id, :user_id => nil).update!(:user_id => self[:user_id]) if authenticated?
      
      self[:messages] = nil
    end
    
    def logout
      self[:user_id] = nil
      self[:cached_find_ids] = self[:picked_product_ids] = []
    end
    
    def most_recent_cached_find
      CachedFind.get(self[:most_recent_find_id])
    end
    
    def most_recent_cached_find=(cached_find)
      self[:most_recent_find_id] = cached_find.id
    end
    
    def picked_products
      return [] if picked_product_ids.empty?
      picks = PickedProduct.all(:id => picked_product_ids, :order => [:cached_class, :cached_brand, :created_at])
      update_picked_product_title_values(picks.select { |pick| pick.invalidated? }, true)
      picks
    end
    
    def queue_message(value)
      (self[:messages] ||= []) << value
    end
    
    def remove_picked_products(picks)
      ids = picked_product_ids
      pick_ids = picks.map { |pick| pick.id }
      PickedProduct.all(:id => pick_ids).destroy!      
      self[:picked_product_ids] = (ids - pick_ids)
    end
    
    def unqueue_messages
      if authenticated?
        messages = Message.all(:user_id => self[:user_id])
        values = messages.map { |m| m.value }
        messages.destroy! unless values.empty?
        values
      else
        self.delete(:messages) || []
      end
    end
    
    def user
      user_id = self[:user_id]
      return nil if user_id.nil?
      User.get(user_id)
    end
    
    def userish
      u = user
      u.nil? ? "session #{session_id}" : "user #{u.id} (#{u.name} / #{u.login})"
    end
    
    
    private
    
    def cached_find_ids
      self[:cached_find_ids] || []
    end
    
    def picked_product_ids
      self[:picked_product_ids] || []
    end
    
    def update_picked_product_title_values(picks, commit = false)
      picks_by_product_id = picks.hash_by(:product_id)
      property_names = %w(marketing:brand reference:class)
      
      Product.values_by_property_name_by_product_id(picks_by_product_id.keys, language, property_names).each do |product_id, values_by_name|
        pick = picks_by_product_id[product_id]
        old_title = pick.title_parts
        
        values_by_name.each do |name, values|
          attribute = "cached_#{name.split(':').last}"
          pick.attribute_set(attribute, values.first.to_s)
        end
        pick.cached_brand ||= "Miscellaneous"
        pick.invalidated = false
        pick.save if commit
      end
    end
  end
end
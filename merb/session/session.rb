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
      return if picked_products.any? { |p| p.product_id == pick.product_id }
      
      pick.user = user
      self[:picked_product_ids] = (picked_product_ids << pick.id) if pick.save
    end
    
    def add_purchase(purchase)
      purchase.user = user
      if purchase.save
        previous_purchase_ids = purchases.map { |p| (p.facility_id == purchase.facility_id) ? p.id : nil }.compact
        self[:purchase_ids] = ((purchase_ids - previous_purchase_ids) << purchase.id)
      end
    end
    
    def admin?
      authenticated? and user.admin?
    end
    
    def authenticated?
      not user.nil?
    end
    
    def cached_finds
      return [] if cached_find_ids.empty?
      CachedFind.all(:id => cached_find_ids, :order => [:specification])
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
    
    def login!(login, pass, challenge)
      user = nil
      begin
        raise Unauthenticated unless login_challenge == challenge 
        user = User.authenticate(login, pass)
        raise Unauthenticated, "Unknown account / password" if user.nil?
        raise Unauthenticated, "Disabled account" unless user.enabled?
      rescue Exception => e
        raise e
      end
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
    end
    
    def login_challenge
      self[:login_challenge] ||= Password.gen_string(32)
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
      PickedProduct.all(:id => picked_product_ids, :order => [:created_at])
    end
    
    def purchases
      return [] if purchase_ids.empty?
      Purchase.all(:id => purchase_ids)
    end
    
    def remove_picked_products(picks)
      ids = picked_product_ids
      pick_ids = picks.map { |pick| pick.id }
      
      PickedProduct.all(:id => pick_ids).destroy!
      
      ids.delete(pick_ids)
      self[:picked_product_ids] = ids
    end
    
    def remove_purchase(purchase)
      ids = purchase_ids
      ids.delete(purchase.id)
      self[:purchase_ids] = ids
    end
    
    def user
      user_id = self[:user_id]
      return nil if user_id.nil?
      User.get(user_id)
    end
    
    
    private
    
    def cached_find_ids
      self[:cached_find_ids] || []
    end
    
    def picked_product_ids
      self[:picked_product_ids] || []
    end
    
    def purchase_ids
      self[:purchase_ids] || []
    end
  end
end
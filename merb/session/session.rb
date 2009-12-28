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
    
    def add_future_purchase(purchase)
      return if future_purchases.any? { |fp| fp.definitive_product_id == purchase.definitive_product_id }
      
      purchase.user = user
      self[:future_purchase_ids] = (future_purchase_ids << purchase.id) if purchase.save
    end
    
    def add_purchase(purchase)
      purchase.user = user
      self[:purchase_ids] = (purchase_ids << purchase.id) if purchase.save
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
    
    def ensure_future_purchase(purchase_id) # TODO: review all uses to prevent retrieval where unnecessary
      raise NotFound unless future_purchase_ids.include?(purchase_id)
      FuturePurchase.get(purchase_id) or raise NotFound
    end
    
    def future_purchases
      return [] if future_purchase_ids.empty?
      FuturePurchase.all(:id => future_purchase_ids, :order => [:created_at])
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
      
      [[:cached_finds, :specification], [:future_purchases, :definitive_product_id]].each do |set, discriminator|
        session_set = send(set)
        user_set = user.send(set)
        
        unless session_set.empty?
          user_discriminators = user_set.map { |item| item.send(discriminator) }
          session_set.all(discriminator => user_discriminators).destroy!
          session_set.update!({:user_id => user.id}, true)
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
      self[:cached_find_ids] = self[:future_purchase_ids] = []
    end
    
    def purchases
      return [] if purchase_ids.empty?
      Purchase.all(:id => purchase_ids)
    end
    
    def remove_future_purchase(purchase)
      ids = future_purchase_ids
      ids.delete(purchase.id)
      self[:future_purchase_ids] = ids
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
    
    def future_purchase_ids
      self[:future_purchase_ids] || []
    end
    
    def purchase_ids
      self[:purchase_ids] || []
    end
  end
end
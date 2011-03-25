class Application < Merb::Controller
  RANGE_SEPARATOR = " <em>to</em> "
  
  before :ensure_authenticated, :exclude => [:login, :track]
  
  def self._filter_params(params)
    redacted = params.dup
    (@redacted_params || []).each { |key| redacted[key] = "[REDACTED]" if params.has_key?(key) }
    redacted
  end
  
  def self.redact_params(*params)
    @redacted_params = params
  end
  
  def categories_404(status = 404)
    params["filters"] = params["find"] = nil
    @path_names = []
    @child_links = Indexer.category_children_for_node([]).map { |child| category_link(@path_names + [child]) }.sort
    @canonical_path = "/categories"
    render("../categories/show".to_sym, :status => status)
  end
  
  def ensure_authenticated
    raise Unauthenticated if Merb.environment == "staging" and not session.authenticated?
  end
end

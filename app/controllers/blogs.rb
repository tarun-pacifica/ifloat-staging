class Blogs < Application
  def show(name)
    @blog = Blog.first(:name => name)
    return redirect("/") if @blog.nil?
    
    @admin = (session.admin? or session.user == @blog.user)
    @articles = @blog.articles
    @blog_image_src = image_src(name)
    @images = Article.images(@articles)
    
    render
  end
  
  
  private
  
  def image_src(name)
    image = Asset.first(:bucket => "blogs", :name.like => "#{name}%")
    image.nil? ? nil : image.url
  end
end
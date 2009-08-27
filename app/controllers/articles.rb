class Articles < Application
  def create(blog_id, title, body, image)
    blog = Blog.get(blog_id)
    return redirect("/") if blog.nil? or not (session.admin? or session.user == blog.user)
    
    article = blog.articles.create(:user => blog.user, :title => title, :body => body)
    article.save_image(image["tempfile"].path, image["filename"]) unless image.blank? or not article.valid?
    
    redirect(url(:blogs, :name => blog.name))
  end
  
  def update(id, title, body, image)
    article = Article.get(id)
    return redirect("/") if article.nil? or not (session.admin? or session.user == article.user)
    
    article.title = title
    article.body = body
    article.save
    article.save_image(image["tempfile"].path, image["filename"]) unless image.blank?
    
    redirect(url(:blogs, :name => article.blog.name))
  end
end
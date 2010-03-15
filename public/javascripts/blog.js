function blog_article_edit(a) {
	var article = $(a).parents('.article');
	article.children().hide();
	
	var form = article.children('form');
	form.show();
	form.animate({backgroundColor: '#FCBB1A'}).animate({backgroundColor: '#F3F3F3'});
	form.animate({backgroundColor: '#FCBB1A'}).animate({backgroundColor: '#F3F3F3'});
	
	$(document).scrollTop(form.offset().top);
}

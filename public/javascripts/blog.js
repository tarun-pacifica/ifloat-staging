function blog_article_edit(event) {
	var article = $(event.target).parents('.article');
	article.children().hide();
	
	var form = article.children('form');
	form.show();
	form.animate({backgroundColor: 'yellow'}).animate({backgroundColor: '#F3F3F3'});
	
	$(document).scrollTop(form.offset().top);
}

function blog_article_validate(event) {
	var form = $(event.target);
	
	var errors = [];
	if(form.find('input:text').val() == '') errors.push("Articles must have a title.");
	if(form.find('textarea').val() == '') errors.push("Articles must have a body.");
	
	if(errors.length == 0) return true;
	
	alert(errors.join('\n'));
	return false;
}

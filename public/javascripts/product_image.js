function product_image_make(url, popup_url) {
	if(popup_url) return '<img class="product" src="' + url + '" onmouseover="product_image_popup(event, \'' + popup_url + '\')" onmouseout="prod_image_unpopup(this)" />';
	return '<img class="product" src="' + url + '" />';
}

function product_image_popup(event, image_url) {
	var zoom = $("#image_popup");
	zoom.attr('src', image_url);
	
	var image = $(event.target)
	var position = image.offset();
	image.css('border-color', 'black');
	zoom.css('left', position.left - 10 - zoom.width() + 'px');
	zoom.css('top', position.top + (image.height() - zoom.height()) / 2 + 'px');
	zoom.css('display', 'block');
}

function prod_image_unpopup(i) {
	$(i).css('border-color', 'gray');
	$('#image_popup').css('display', 'none');
}

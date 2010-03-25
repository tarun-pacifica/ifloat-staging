function product_image_make(url, popup_url, relative_position) {
	if(relative_position == undefined) relative_position = 'left';
	
	if(popup_url) return '<img class="product" src="' + url + '" onmouseover="product_image_popup(event, \'' + popup_url + '\', \'' + relative_position + '\')" onmouseout="product_image_unpopup(event)" />';
	return '<img class="product" src="' + url + '" />';
}

function product_image_popup(event, image_url, relative_position) {
	var zoom = $("#image_popup");
	zoom.attr('src', image_url);
	
	var image = $(event.target);
	image.css('border-color', 'black');
	
	var position = image.offset();
	var left = position.left + (relative_position == 'right' ? (image.width() + 10) : (-10 - zoom.width())) + 'px';
	zoom.css('left', left);
	zoom.css('top', position.top + (image.height() - zoom.height()) / 2 + 'px');
	zoom.css('display', 'block');
}

function product_image_unpopup(event) {
	$(event.target).css('border-color', 'gray');
	$('#image_popup').css('display', 'none');
}

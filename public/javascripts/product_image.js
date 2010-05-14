function product_image_make(url, popup_url, relative_position) {
	if(relative_position == undefined) relative_position = 'left';
	
	if(popup_url) return '<img class="product" src="' + url + '" onmouseover="product_image_popup(event, \'' + popup_url + '\', \'' + relative_position + '\')" onmouseout="product_image_unpopup(event)" />';
	return '<img class="product" src="' + url + '" />';
}

function product_image_popup(event, image_url, relative_position) {
	$('body').append('<img id="image_popup" src="' + image_url + '" />');
	var popup = $('#image_popup');
	
	var image = util_target(event);
	image.css('border-color', 'black');
	
	var position = image.offset();
	var popup_height = popup.outerHeight();
	
	var left = position.left + (relative_position == 'right' ? (image.outerWidth() + 10) : (-10 - popup.outerWidth()));
	var top = position.top + (image.outerHeight() - popup_height) / 2;
	
	var document_overhang = top + popup_height - $(document).height();
	if(document_overhang > 0) top -= document_overhang;
	
	popup.css('left', left + 'px').css('top', top + 'px').fadeIn('fast');
}

function product_image_unpopup(event) {
	util_target(event).css('border-color', 'gray');
	$('#image_popup').remove();
}

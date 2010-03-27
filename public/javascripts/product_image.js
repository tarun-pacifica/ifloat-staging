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
	var zoom_height = zoom.outerHeight();
	
	var left = position.left + (relative_position == 'right' ? (image.outerWidth() + 10) : (-10 - zoom.outerWidth()));
	var top = position.top + (image.outerHeight() - zoom_height) / 2;
	
	var document_overhang = top + zoom_height - $(document).height();
	if(document_overhang > 0) top -= document_overhang;
	
	zoom.css('left', left + 'px').css('top', top + 'px').fadeIn('fast');
}

function product_image_unpopup(event) {
	$(event.target).css('border-color', 'gray');
	$('#image_popup').stop(true, true).hide();
}

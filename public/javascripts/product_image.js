function product_image_caption(titles) {
	return titles ? util_superscript('text', util_escape_attr_js(titles.join('<br/>'))) : 'null';
}

function product_image_make(url, popup_url, relative_position, titles) {
	if(relative_position == undefined) relative_position = 'left';
	
	if(popup_url) {
		return '<img class="product" src="' + url + '" alt="product" onmouseover="product_image_popup(event, \'' + popup_url + '\', \'' + relative_position + '\', ' + product_image_caption(titles) + ')" onmouseout="product_image_unpopup(event)" />';
	}
	
	return '<img class="product" src="' + url + '" alt="product" />';
}

function product_image_popup(event, image_url, relative_position, caption) {
	caption = (caption ? '<p>' + caption + '</p>' : '');
	$('body').append('<div id="image_popup"> <img alt="closeup" src="' + image_url + '" /> ' + caption + ' </div>');
	var popup = $('#image_popup');
	
	var image = util_target(event);
	image.css('border-color', '#404040');
	
	var position = image.offset();
	var popup_height = popup.outerHeight();
	
	var left_end = position.left, left_start;
	if(relative_position == 'right') {
		left_end += image.outerWidth() + 10;
		left_start = left_end + 10;
	} else {
		left_end -= popup.outerWidth() + 10;
		left_start = left_end - 10;
	}

	var top = position.top + (image.outerHeight() - popup_height) / 2;
	
	var document_overhang = top + popup_height - $(document).height();
	if(document_overhang > 0) top -= document_overhang;
	
	popup.css('left', left_start + 'px').css('top', top + 'px').css('opacity', 0).show();
	popup.animate({left: left_end + 'px', opacity: 1}, 'fast');
}

function product_image_unpopup(event) {
	util_target(event).css('border-color', '#D0D0D0');
	$('#image_popup').remove();
}

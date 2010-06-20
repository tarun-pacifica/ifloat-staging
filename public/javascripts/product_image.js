function product_image_caption(titles) {
	return titles ? util_superscript('text', util_escape(titles.join('<br/>'), '"\'')) : '';
}

function product_image_make(url, popup_url, relative_position, titles) {
	if(relative_position == undefined) relative_position = 'left';
	
	if(popup_url) {
		return '<img class="product" src="' + url + '" onmouseover="product_image_popup(event, \'' + popup_url + '\', \'' + relative_position + '\', \'' + product_image_caption(titles) + '\')" onmouseout="product_image_unpopup(event)" />';
	}
	
	return '<img class="product" src="' + url + '" />';
}

function product_image_popup(event, image_url, relative_position, caption) {
	if(caption == undefined) caption = '';
	$('body').append('<div id="image_popup"> <img src="' + image_url + '" /> <p>' + caption + '</p> </div>');
	var popup = $('#image_popup');
	
	var image = util_target(event);
	image.css('border-color', '#404040');
	
	var position = image.offset();
	var popup_height = popup.outerHeight();
	
	var left = position.left + (relative_position == 'right' ? (image.outerWidth() + 10) : (-10 - popup.outerWidth()));
	var top = position.top + (image.outerHeight() - popup_height) / 2;
	
	var document_overhang = top + popup_height - $(document).height();
	if(document_overhang > 0) top -= document_overhang;
	
	popup.css('left', left + 'px').css('top', top + 'px').fadeIn('fast');
}

function product_image_unpopup(event) {
	util_target(event).css('border-color', '#D0D0D0');
	$('#image_popup').remove();
}

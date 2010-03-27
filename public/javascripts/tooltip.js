function tooltip_hide() {
	$('#tooltip').stop(true, true).hide();;
}

function tooltip_show(event, text, relative_position) {
	var tooltip = $('#tooltip');
	tooltip.html(text);
	
	var target = $(event.target);
	var position = target.offset();
	var tooltip_height = tooltip.outerHeight();
	
	var left, top;
	if(relative_position == 'above') {
		left = position.left + ((target.outerWidth() - tooltip.outerWidth()) / 2);
		top = position.top - tooltip.outerHeight() - 3;
	} else if(relative_position == 'below') {
		left = position.left + ((target.outerWidth() - tooltip.outerWidth()) / 2);
		top = position.bottom + 3;
	} else if(relative_position == 'left') {
		left = position.left - tooltip.outerWidth() - 3;
		top = position.top + ((target.outerHeight() - tooltip_height) / 2) + 2;
	} else { // right
		left = position.left + target.outerWidth() + 3;
		top = position.top + ((target.outerHeight() - tooltip_height) / 2) + 2;
	}
	
	var document_overhang = top + tooltip_height - $(document).height();
	if(document_overhang > 0) top -= document_overhang;
	
	tooltip.css('left', left + 'px').css('top', top + 'px').fadeIn('fast');
}

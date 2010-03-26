function tooltip_hide() {
	$('#tooltip').css('display', 'none');
}

function tooltip_show(event, text, relative_position) {
	var tooltip = $('#tooltip');
	tooltip.html(text);
	
	var target = $(event.target);
	var position = target.offset();
	var left, top;
	
	if(relative_position == 'above') {
		left = position.left + ((target.width() - tooltip.outerWidth()) / 2);
		top = position.top - tooltip.outerHeight() - 3;
	} else if(relative_position == 'bottom') {
		left = position.left + ((target.width() - tooltip.outerWidth()) / 2);
		top = position.bottom + 3;
	} else if(relative_position == 'left') {
		left = position.left - tooltip.outerWidth() - 3;
		top = position.top + ((target.height() - tooltip.outerHeight()) / 2) + 2;
	} else { // right
		left = position.left + target.width() + 3;
		top = position.top + ((target.height() - tooltip.outerHeight()) / 2) + 2;
	}
	
	tooltip.css('left', left + 'px');
	tooltip.css('top', top + 'px');
	tooltip.fadeIn('fast');
}

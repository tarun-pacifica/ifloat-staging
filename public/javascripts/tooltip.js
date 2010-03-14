function tooltip_show(event, text, relative_position) {
	var bubble = $("#tooltip");
	bubble.find("p").text(text);
	
	var target = $(event.target);
	var position = target.offset();
	var left, top;
	
	if(relative_position == "above") {
		left = position.left + ((target.width() - bubble.width()) / 2);
		top = position.top - bubble.height() - 3;
	} else if (relative_position == "bottom") {
		left = position.left + ((target.width() - bubble.width()) / 2);
		top = position.bottom + 3;
	} else if (relative_position == "left") {
		left = position.left - bubble.width() - 3;
		top = position.top + ((target.height() - bubble.height()) / 2) + 2;
	} else { // right
		left = position.left + target.width() + 3;
		top = position.top + ((target.height() - bubble.height()) / 2) + 2;
	}
	
	bubble.css("left", left + "px");
	bubble.css("top", top + "px");
	bubble.css("display", "block");
}	

function tooltip_hide() {
	$("#tooltip").css("display", "none");
}

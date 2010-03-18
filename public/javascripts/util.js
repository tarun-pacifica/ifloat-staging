function util_defined(value, definition, position) {
	if(definition == undefined) return value;
	if(position == undefined) position = 'right';
	
	return '<span class="defined" onmouseover="tooltip_show(event, \'' + util_escape(definition, ['"', "'"]) + '\', \'' + position + '\')" onmouseout="tooltip_hide()">' + value + '</span>';
}

function util_escape(string, characters) {
	var s = string;
	for(i in characters) {
		var c = characters[i];
		s = s.replace(c, '\\' + c);
	}
	return s;
}

function util_group_by(array, property) {
	var grouped = {};
	for(i in array) {
		var a = array[i];
		var key = a[property];
		if(grouped[key] == undefined) grouped[key] = [];
		grouped[key].push(a);
	}
	return grouped;
}

function util_hash_from_array(keys, value) {
	var hash = {};
	for(i in keys) hash[keys[i]] = value;
	return hash;
}

function util_highlight_row(action) {
	var row = $(event.target).parent();
	var cells = row.children();
		
	if(action == 'on') {
		row.data('original_bg_colour', cells.css('background-color'));
		cells.css('background-color', 'yellow');
	} else {
		cells.css('background-color', row.data('original_bg_colour'));
	}
}

function util_preload_image(url) {
	(new Image()).src = url;
}

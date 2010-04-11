function util_carousel_table(selector, label_cols, data_cols, slim) {
	var shown_cols = label_cols.concat(data_cols);
	var table = $(selector);
	
  var column_count = table.find('tr:first td').length;
	if(column_count <= shown_cols.length) return;
	
	var nav_row = table.find('tr.nav');
	if(nav_row.length == 0) {
		table.prepend('<tr class="nav"> </tr>');
		nav_row = table.find('tr.nav');
	}
	nav_row.empty();
	
	var min_data_col = data_cols[0];
	var max_data_col = data_cols[data_cols.length - 1];
	var max_label_col = label_cols[label_cols.length - 1];
	
	if(min_data_col == max_label_col + 1) min_data_col = undefined;
	if(max_data_col == column_count - 1) max_data_col = undefined;
	
	var sel = "'" + selector + "'";
	var lcols = '[' + label_cols.join(', ') + ']';

	for(var i = 0; i < column_count; i += 1) {
		if(i != min_data_col && i != max_data_col) {
			nav_row.append('<td> </td>');
			continue;
		}
		
		var dcols = [];
		for(var j in data_cols) dcols.push(data_cols[j] + (i == min_data_col ? -1 : 1));
		
		var klass = (i == min_data_col ? 'minimize' : 'maximize');
		var message = (slim ? 'more' : ('show <strong>' + dcols.join(', ') + '</strong> of ' + (column_count - label_cols.length)));
		message = (i == min_data_col ? '&lt;&lt;&lt; ' + message : message + ' &gt;&gt;&gt;');
		nav_row.append('<td class="' + klass + '" onclick="util_carousel_table(\'' + selector + '\', [' + label_cols.join(', ') + '], [' + dcols + '], ' + slim + ')">' + message + '</td>');
	}
	
	var rows = table.find('tr');
	rows.find('td').hide();
	for(var i in shown_cols) rows.find('td:eq(' + shown_cols[i] + ')').show();
}

function util_defined(value, definition, position) {
	if(definition == undefined) return value;
	if(position == undefined) position = 'right';
	
	return '<span class="defined" onmouseover="tooltip_show(event, \'' + util_escape(definition, '"\'') + '\', \'' + position + '\')" onmouseout="tooltip_hide()">' + value + '</span>';
}

function util_escape(string, characters) {
	return string.replace(RegExp("([" + characters + "])", "g"), '\\$1');
}

function util_group_by(array, property) {
	var grouped = {};
	for(var i in array) {
		var a = array[i];
		var key = a[property];
		if(grouped[key] == undefined) grouped[key] = [];
		grouped[key].push(a);
	}
	return grouped;
}

function util_hash_from_array(keys, value) {
	var hash = {};
	for(var i in keys) hash[keys[i]] = value;
	return hash;
}

function util_highlight_column(event, action, col_num) {
	var table = $(event.target).parents("table");
	
	table.find('.hover').removeClass('hover');
	if(action == 'on') table.find('td:nth-child(' + col_num + ')').addClass('hover');
}

function util_highlight_row(event, action) {
	var row = $(event.target).parent();

	if(action == 'on') row.addClass('hover');
	else row.removeClass('hover');
}

function util_pluralize(count, singular) {
	return count + ' ' + (count == 1 ? singular : singular + 's');
}

function util_preload_image(url) {
	(new Image()).src = url;
}

function util_superscript(type, value) {
	if(type == 'text') return value.replace(/([®™])/g, '<sup>$1</sup>');
	
	if(type == 'numeric') {
		var parts = value.split(' ');
		var last_part = parts.pop();
		
		if(!last_part.match(/[a-z]/)) return value;
		parts.push(last_part.replace(/(\d)/g, '<sup>$1</sup>'))
		return parts.join(' ');
	}
	
	return value;
}

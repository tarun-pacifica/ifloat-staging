function filter_configure(filter_id) {
	$.getJSON('/cached_finds/' + $ifloat_body.find_id + '/filter/' + filter_id, filter_configure_handle);
	// TODO: spinner
}

function filter_configure_apply() {
	
}

function filter_configure_back() {
	$('#filter_configure').dialog('close');
	filter_choose_open();
}

function filter_configure_handle(filter) {
	if(filter == null) {
		alert('The product catalogue has been updated, making the selected filter obsolete. Please click OK to refresh the page.');
		window.location.reload();
		return;
	}
	
	var from_filter_choose = filter_choose_close();
	
	var filter_configure = $('#filter_configure');
	if(filter_configure.length == 0) {
		$('body').append('<div id="filter_configure" title="Configure the filter..."> </div>');
		filter_configure = $('#filter_configure');
		filter_configure.dialog({autoOpen: false, modal: true, resizable: false, buttons: {Apply: filter_configure_apply}});
		filter_configure.data('width.dialog', 700);
	}
	
	var html = [];
	
	html.push('<div class="location">');
	if(from_filter_choose) {
		html.push('<h3 class="back" onclick="filter_configure_back()">Back to all filters</h3>');
		html.push('<img src="/images/filter_configure/backgrounds/location_sep_button.png" />');
	}
	html.push('<h3>' + filter.section + '</h3>');
	html.push('<img src="/images/filter_configure/backgrounds/location_sep.png" />');
	html.push('<p> <img class="property_icon" src="' + filter.icon_url + '" /> ' + filter.name + '</p>');
	html.push('</div>');
	
	html.push('<table summary="values">');
	if(filter.include_unknown != null) {
		var checked = (filter.include_unknown ? 'checked="checked"' : '');
		var checkbox = '<input class="include_unkown" type="checkbox" ' + checked + ' /> Show products with no "' + filter.name + '" value';
		html.push('<tr class="include_unknown"> <td colspan="3"> ' + checkbox + ' </td> </tr>');
	}
	if(filter.type == "text") filter_configure_values_text(filter.values_by_unit, html);
	else filter_configure_values_numeric(filter.values_by_unit, html);
	html.push('</table>');
	
	filter_configure.html(html.join(' '));
	filter_configure.dialog('open');	
}

function filter_configure_values_numeric(values_by_unit, html) {
	
}

function filter_configure_values_text(values_by_unit, html) {
	var values = values_by_unit[$ifloat_body.language];
	
	var column_count = 0;
	var column_length = 11;
	while(column_count < 4 && column_length > 10) {
		column_count += 1;
		column_length = Math.floor(values.length / column_count);
	}
	var column_remainder = values.length % column_count;
	
	var columns = [];
	while(columns.length < column_count) columns.push([]);
	for(c in columns) {
		var length = column_length + (column_remainder > c ? 1 : 0);
		var column = columns[c];
		while(column.length < length) column.push(values.shift());
	}
	
	for (i in columns[0]) {
		html.push('<tr>');
		
		for (c in columns) {
			var v = columns[c][i];
			if(v == undefined) continue;
			var checked = (v[1] ? 'checked="checked"' : '');
			var klass = (v[2] ? '' : 'class="irrelevant"');
			html.push('<td> <input ' + klass +  ' type="checkbox" ' + checked + ' /> ' + v[0] + '</td>');
		}
		
		html.push('</tr>');
	}
}

function filter_configure(filter_id) {
	$.getJSON(filter_configure_url(filter_id), filter_configure_handle);
}

function filter_configure_apply() {
	var filter_configure = $('#filter_configure');
	
	var data = {include_unknown: filter_configure.find('.include_unknown input:checked').length == 1}
	
	if(filter_configure.data('type') == 'text') {
		data['unit'] = $ifloat_body.language;
		data['value'] = filter_configure.find("table input:checked").map(function() {return $(this).val();}).toArray().join("::");
	} else {
		data['unit'] = filter_configure.data('unit');
		var slider_set = filter_configure.find('.slider_set[title=' + data['unit'] + ']');
		data['value'] = slider_set.data('min') + '::' + slider_set.data('max');
	}
		
	$.post(filter_configure_url(filter_configure.data('id')), data, filter_configure_apply_handle, 'json');
}

function filter_configure_apply_handle(data) {
	var filter_configure = $('#filter_configure');
	var filter_dom_id = '#filter_' + filter_configure.data('id');
	var update = $(filter_dom_id).length > 0;
	
	filter_panel_reload(data);
	filter_configure.dialog('close');
	
	if(update) $(filter_dom_id).animate({color: 'yellow'}).animate({color: 'black'});
	else $(filter_dom_id).hide().fadeIn('slow');
}

function filter_configure_back() {
	$('#filter_configure').dialog('close');
	filter_choose_open();
}

function filter_configure_handle(filter) {
	if(filter == null) {
		alert('The product catalogue has been updated so we need to refresh the page.');
		window.location.reload();
		return;
	}
	
	var from_filter_choose = filter_choose_close();
	
	var filter_configure = $('#filter_configure');
	if(filter_configure.length == 0) {
		$('body').append('<div id="filter_configure"> </div>');
		filter_configure = $('#filter_configure');
		filter_configure.dialog({autoOpen: false, modal: true, resizable: false, title: filter_choose_title()});
		filter_configure.dialog('option', 'buttons', {Apply: filter_configure_apply});
		filter_configure.data('width.dialog', 700 + 'px');
	}
	
	var html = [];
	
	html.push('<div class="location">');
	if(from_filter_choose) {
		html.push('<h3 class="back" onclick="filter_configure_back()">Back to all filters</h3>');
		html.push('<img src="/images/filter_configure/backgrounds/location_button_sep.png" />');
	}
	html.push('<h3>' + filter.section + '</h3>');
	html.push('<img src="/images/filter_configure/backgrounds/location_sep.png" />');
	html.push('<p> <img class="property_icon" src="' + filter.icon_url + '" /> <strong>' + filter.name + '</strong> values </p>');
	html.push('</div>');
	
	if(filter.include_unknown != null) {
		var checked = (filter.include_unknown ? 'checked="checked"' : '');
		html.push('<p class="include_unknown"> <input type="checkbox" ' + checked + ' /> Show products with no <strong>' + filter.name + '</strong> value </p>');
	}
	if(filter.type == 'text') filter_configure_values_text(filter.values_by_unit, html);
	else filter_configure_values_numeric(filter.type, filter.values_by_unit, html);
	
	filter_configure.html(html.join(' '));
	if(filter.type != 'text') filter_configure_values_numeric_build_sliders(filter_configure, filter.values_by_unit);
	
	filter_configure.data('id', filter.id);
	filter_configure.data('type', filter.type);
	filter_configure.dialog('open');
}

function filter_configure_url(filter_id) {
	return '/cached_finds/' + $ifloat_body.find_id + '/filter/' + filter_id;
}

function filter_configure_values_numeric(variant, values_by_unit, html) {
	var selected_unit;
	var unit_count = 0;
	for(unit in values_by_unit) {
		if(selected_unit == undefined) selected_unit = unit;
		unit_count += 1;
	}
	
	if(unit_count > 1) {
		html.push('<p class="units">Measurements in ');
		html.push('<select class="unit" onchange="filter_configure_values_numeric_handle_select()">');
		for(unit in values_by_unit) {
			var selected = (unit == selected_unit ? 'selected="selected"' : '');
			html.push('<option ' + selected + '>' + unit + '</option>');
		}
		html.push('</select>');
		html.push('</p>');
	}
	
	for(unit in values_by_unit) {
		html.push('<div class="slider_set" title="' + unit + '">');
		html.push('<p class="min">min:</p> <div class="min"> </div>');
		html.push('<p class="max">max:</p> <div class="max"> </div>');
		html.push('</div>');
	}
}

function filter_configure_values_numeric_build_sliders(filter_configure, values_by_unit) {
	var selected_unit;
	for(unit in values_by_unit) { selected_unit = unit; break; }
	filter_configure.data('unit', selected_unit);
	filter_configure.data('values_by_unit', values_by_unit);
	
	for(unit in values_by_unit) {
		var extremes = {};
		var values = values_by_unit[unit];
		for(i in values) {
			var v = values[i];
			if(extremes['min'] == undefined) { if(v[1]) extremes['min'] = extremes['max'] = i; }
			else if(! v[1]) break;
			else extremes['max'] = i;
		}
		
		var slider_set = filter_configure.find('.slider_set[title=' + unit + ']');
		var options = {  max: values.length - 1,
			             slide: filter_configure_values_numeric_handle_slide,
			              stop: filter_configure_values_numeric_handle_slide };
		for(extreme in extremes) {
			var i = extremes[extreme]
			options['range'] = extreme;
			options['value'] = i;
			slider_set.data(extreme, values[i][0]);
			slider_set.find('div.' + extreme).slider(options);
		}
				
		if(unit != selected_unit) slider_set.hide();
		filter_configure_values_numeric_update_minmax(unit);
	}
}

function filter_configure_values_numeric_handle_select() {
	var filter_configure = $('#filter_configure');
	var unit = $(event.target).val();
	
	filter_configure.find('.slider_set[title=' + filter_configure.data('unit') + ']').hide();
	filter_configure.find('.slider_set[title=' + unit + ']').show();
	
	filter_configure.data('unit', unit);
}

function filter_configure_values_numeric_handle_slide() {
	var slider = $(this);
	var my_value = slider.slider('value');
	var other = slider.siblings('div');
	var other_value = other.slider('value');
	
	if((slider.hasClass('min') && my_value > other_value) ||
	   (slider.hasClass('max') && my_value < other_value)) other.slider('value', my_value);
	
	filter_configure_values_numeric_update_minmax();
}

function filter_configure_values_numeric_update_minmax(unit) {
	var filter_configure = $('#filter_configure');
	if(unit == undefined) unit = filter_configure.data('unit');
	var slider_set = filter_configure.find('.slider_set[title=' + unit + ']');
	var values = filter_configure.data('values_by_unit')[unit];
	
	var extremes = {min: null, max: null};
	for(extreme in extremes) {
		var i = slider_set.find('div.' + extreme).slider('value');
		var value = values[i];
		slider_set.data(extreme, value[0]);
		slider_set.find('p.' + extreme).text(extreme + ': ' + value[3]);
	}
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
	
	html.push('<table summary="values">');
	for(var i in columns[0]) {
		html.push('<tr>');
		
		for(c in columns) {
			var v = columns[c][i];
			if(v == undefined) continue;
			
			var value = v[0];
			var checked = (v[1] ? 'checked="checked"' : '');
			var escaped_value = util_escape(v[0], ['"']);
			html.push('<td class="check"> <input value="' + escaped_value + '" type="checkbox" ' + checked + ' /> </td>');
			
			var klass = ((v[1] && !v[2]) ? 'class="value irrelevant"' : 'class="value"');
			var definition = v[3];
			value = util_defined(value, definition, c >= columns.length / 2 ? 'left' : 'right');
			escaped_value = "'" + util_escape(v[0], ['"', "'"]) + "'";
			html.push('<td ' + klass + ' onclick="filter_configure_values_text_handle_click(' + escaped_value + ')"> ' + value + ' </td>');
		}
		
		html.push('</tr>');
	}
	html.push('</table>');
}

function filter_configure_values_text_handle_click(value) {
	var filter_configure = $('#filter_configure');
	filter_configure.find('table input').each(function() {
		var checkbox = $(this);
		checkbox.attr('checked', checkbox.val() == value);
	});
}

function filter_configure(filter_id) {
	$.getJSON(filter_configure_url(filter_id), filter_configure_handle);
	spinner_show('Loading filter...');
}

function filter_configure_apply() {
	var filter_configure = $('#filter_configure');
	
	var data = {include_unknown: filter_configure.find('.include_unknown input:checked').length == 1}
	
	data.apply_exclusively = !$ifloat_body.find_home;
	data.inline_response = $ifloat_body.find_home;
	
	if(filter_configure.data('type') == 'text') {
		data['unit'] = $ifloat_body.language;
		data['value'] = filter_configure.find("table input:checked").map(function() {return $(this).val();}).toArray().concat(filter_configure.data('hidden_values')).join("::");
	} else {
		data['unit'] = filter_configure.data('unit');
		var slider_set = filter_configure.find('.slider_set[title=' + data['unit'] + ']');
		data['value'] = slider_set.data('min') + '::' + slider_set.data('max');
	}
		
	$.post(filter_configure_url(filter_configure.data('id')), data, filter_configure_apply_handle, 'json');
	spinner_show('Applying filter...');
}

function filter_configure_apply_handle(data) {
	if(!$ifloat_body.find_home) {
		window.location = '/cached_finds/' + $ifloat_body.find_id;
		return;
	}
	
	var filter_configure = $('#filter_configure');
	var filter_dom_id = '#filter_' + filter_configure.data('id');
	var update = $(filter_dom_id).length > 0;
	
	filter_panel_reload(data);
	filter_configure.dialog('close');
	spinner_hide();
	
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
	
	var no_values = true;
	for(var unit in filter.values_by_unit) no_values = false;
	if(no_values) {
		spinner_hide();
		alert('Your "' + $ifloat_body.find_spec + '" results cannot be filtered by ' + filter.name + '.');
		return;
	}
	
	var from_filter_choose = filter_choose_close();
	
	var filter_configure = $('#filter_configure');
	if(filter_configure.length == 0) {
		$('body').append('<div id="filter_configure"> </div>');
		filter_configure = $('#filter_configure');
		filter_configure.dialog({autoOpen: false, modal: true, resizable: false});
		filter_configure.dialog('option', 'title', 'Filter your "' + $ifloat_body.find_spec + '" results by...');
		
		var apply = {};
		apply['Apply' + ($ifloat_body.find_home ? '' : ' Exclusively')] = filter_configure_apply;
		filter_configure.dialog('option', 'buttons', apply);
		
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
	if(filter.type == 'text') filter_configure_values_text_update_select_all();
	else filter_configure_values_numeric_build_sliders(filter_configure, filter.values_by_unit);
	
	filter_configure.data('id', filter.id);
	filter_configure.data('type', filter.type);
	filter_configure.dialog('open');
	spinner_hide();
}

function filter_configure_url(filter_id) {
	return '/cached_finds/' + $ifloat_body.find_id + '/filter/' + filter_id;
}

function filter_configure_values_numeric(variant, values_by_unit, html) {
	var selected_unit;
	var unit_count = 0;
	for(var unit in values_by_unit) {
		if(selected_unit == undefined) selected_unit = unit;
		unit_count += 1;
	}
	
	if(unit_count > 1) {
		html.push('<p class="units">Measurements in ');
		html.push('<select class="unit" onchange="filter_configure_values_numeric_handle_select(event)">');
		for(var unit in values_by_unit) {
			var selected = (unit == selected_unit ? 'selected="selected"' : '');
			html.push('<option ' + selected + '>' + unit + '</option>');
		}
		html.push('</select>');
		html.push('</p>');
	}
	
	for(var unit in values_by_unit) {
		html.push('<div class="slider_set" title="' + unit + '">');
		html.push('<p class="min">min:</p> <div class="min"> </div>');
		html.push('<p class="max">max:</p> <div class="max"> </div>');
		html.push('</div>');
	}
}

function filter_configure_values_numeric_build_sliders(filter_configure, values_by_unit) {
	var selected_unit;
	for(var unit in values_by_unit) { selected_unit = unit; break; }
	filter_configure.data('unit', selected_unit);
	filter_configure.data('values_by_unit', values_by_unit);
	
	for(var unit in values_by_unit) {
		var raw_values = values_by_unit[unit];
		var values = []
		for(var i in raw_values) {
			var v = raw_values[i];
			if(v[2]) values.push(v);
		}
		values_by_unit[unit] = values;
		
		var extremes = {};
		for(var i in values) {
			var v = values[i];
			if(extremes['min'] == undefined) { if(v[1]) extremes['min'] = extremes['max'] = i; }
			else if(!v[1]) break;
			else extremes['max'] = i;
		}
		
		var slider_set = filter_configure.find('.slider_set[title=' + unit + ']');
		var options = {  max: values.length - 1,
			             slide: filter_configure_values_numeric_handle_slide,
			              stop: filter_configure_values_numeric_handle_slide };
		for(var extreme in extremes) {
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

function filter_configure_values_numeric_handle_select(event) {
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
	for(var extreme in extremes) {
		var i = slider_set.find('div.' + extreme).slider('value');
		var value = values[i];
		slider_set.data(extreme, value[0]);
		slider_set.find('p.' + extreme).html(extreme + ': ' + util_superscript('numeric', value[3]));
	}
}

function filter_configure_values_text(values_by_unit, html) {
	var raw_values = values_by_unit[$ifloat_body.language];
	
	var hidden_values = [];
	var values = [];
	for(var i in raw_values) {
		var v = raw_values[i];
		if(!v[1] || v[2]) values.push(v);
		else hidden_values.push(v[0]);
	}
	$('#filter_configure').data('hidden_values', hidden_values);
	
	if(values.length > 1) html.push('<p class="select_all"> <input type="checkbox" onclick="filter_configure_values_text_select_all()"> Select <strong>all</strong> values </p>');

	var column_count = 0;
	var column_length = 11;
	while(column_count < 4 && column_length > 10) {
		column_count += 1;
		column_length = Math.floor(values.length / column_count);
	}
	var column_remainder = values.length % column_count;
	
	var columns = [];
	while(columns.length < column_count) columns.push([]);
	for(var c in columns) {
		var length = column_length + (column_remainder > c ? 1 : 0);
		var column = columns[c];
		while(column.length < length) column.push(values.shift());
	}
	
	html.push('<table summary="values">');
	for(var i in columns[0]) {
		html.push('<tr>');
		
		for(var c in columns) {
			var v = columns[c][i];
			if(v == undefined) continue;
			
			var value = v[0];
			var checked = (v[1] ? 'checked="checked"' : '');
			var escaped_value = util_escape(v[0], '"');
			html.push('<td class="check"> <input value="' + escaped_value + '" type="checkbox" ' + checked + ' onclick="filter_configure_values_text_update_select_all()"/> </td>');
			
			var klass = (!v[2] ? 'class="value irrelevant"' : 'class="value"');
			var definition = v[3];
			value = util_defined(value, definition, c >= columns.length / 2 ? 'left' : 'right');
			escaped_value = "'" + util_escape(v[0], '"\'') + "'";
			html.push('<td ' + klass + ' onclick="filter_configure_values_text_select_one(' + escaped_value + ')"> ' + util_superscript('text', value) + ' </td>');
		}
		
		html.push('</tr>');
	}
	html.push('</table>');
}

function filter_configure_values_text_select_all() {
	var filter_configure = $('#filter_configure');
	filter_configure.find('table input').attr('checked', true);
	filter_configure.find('p.select_all input').attr('checked', true);
}

function filter_configure_values_text_select_one(value) {
	var filter_configure = $('#filter_configure');
	filter_configure.find('table input').each(function() {
		var checkbox = $(this);
		checkbox.attr('checked', checkbox.val() == value);
	});
	filter_configure_values_text_update_select_all();
}

function filter_configure_values_text_update_select_all() {
	var filter_configure = $('#filter_configure');
	var checked_count = filter_configure.find('table input:checked').length;
	var total_count = filter_configure.find('table input').length;
	filter_configure.find('p.select_all input').attr('checked', checked_count == total_count);
}

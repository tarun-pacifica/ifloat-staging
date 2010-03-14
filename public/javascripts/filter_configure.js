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
	
	if(filter.include_unknown != null) {
		var checked = (filter.include_unknown ? 'checked="checked"' : '');
		html.push('<p class="include_unknown"> <input type="checkbox" ' + checked + ' /> Show products with no "' + filter.name + '" value </p>');
	}
	if(filter.type == 'text') filter_configure_values_text(filter.values_by_unit, html);
	else filter_configure_values_numeric(filter.type, filter.values_by_unit, html);
	
	
	filter_configure.html(html.join(' '));
	if(filter.type != 'text') filter_configure_values_numeric_build_sliders(filter_configure);
	filter_configure.dialog('open');	
}

function filter_configure_values_numeric(variant, values_by_unit, html) {
	blank_unit = false;
	units = [];
	for(unit in values_by_unit) {
		if(unit == '') blank_unit = true;
		units.push(unit);
	}
	
	if(! blank_unit) {
		html.push('<p class="units">Measurements in ');
		html.push('<select class="unit" onchange="filter_configure_values_numeric_handle_select(event)">');
		for(unit in values_by_unit) {
			var selected = (unit == units[0] ? 'selected="selected"' : '');
			html.push('<option ' + selected + '>' + unit + '</option>');
		}
		html.push('</select>');
		html.push('</p>');
	}
	
	if(blank_unit) {
		var vbu = {};
		vbu[''] = values_by_unit[''];
		values_by_unit = vbu;
	}
	
	for(unit in values_by_unit) {
		html.push('<div class="slider_set" title="' + unit + '">');
		html.push('<p class="min">min:</p> <div class="min"> </div>');
		html.push('<p class="max">max:</p> <div class="max"> </div>');
		html.push('</div>');
	}
	
	$ifloat_body.filter_unit = units[0];
	$ifloat_body.filter_values_by_unit = values_by_unit;
}

function filter_configure_values_numeric_build_sliders(filter_configure) {
	values_by_unit = $ifloat_body.filter_values_by_unit;
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
			options['range'] = extreme;
			options['value'] = extremes[extreme];
			slider_set.find('div.' + extreme).slider(options);
		}
		
		if(unit != $ifloat_body.filter_unit) slider_set.hide();
		filter_configure_values_numeric_update_minmax(unit);
	}
}

function filter_configure_values_numeric_handle_select(event) {
	var filter_configure = $('#filter_configure');
	var unit = $(event.target).val();
	
	filter_configure.find('.slider_set[title=' + $ifloat_body.filter_unit + ']').hide();
	filter_configure.find('.slider_set[title=' + unit + ']').show();
	
	$ifloat_body.filter_unit = unit;
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
	if(unit == undefined) unit = $ifloat_body.filter_unit;
	var values = $ifloat_body.filter_values_by_unit[unit];
	
	var slider_set = $('#filter_configure').find('.slider_set[title=' + unit + ']');
	
	var extremes = {min: null, max: null};
	for (extreme in extremes) {
		var i = slider_set.find('div.' + extreme).slider('value');
		slider_set.find('p.' + extreme).text(extreme + ': ' + values[i][3]);
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
	for (i in columns[0]) {
		html.push('<tr>');
		
		for (c in columns) {
			var v = columns[c][i];
			if(v == undefined) continue;
			
			var value = v[0];
			var checked = (v[1] ? 'checked="checked"' : '');
			var klass = (v[2] ? '' : 'class="irrelevant"');			
			var definition = v[3];
			
			if(definition) {
				definition = "'" + definition.replace("'", "\\'").replace('"', '\\"') + "'";
				var position = (c >= columns.length / 2 ? "'left'" : "'right'");
				value = '<span class="defined" onmouseover="tooltip_show(event, ' + definition + ', ' + position + ')" onmouseout="tooltip_hide()">' + value + '</span>';
			}
			
			html.push('<td> <input ' + klass + ' type="checkbox" ' + checked + ' /> ' + value + '</td>');
		}
		
		html.push('</tr>');
	}
	html.push('</table>');
}

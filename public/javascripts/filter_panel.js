function filter_panel_add() {
	filter_choose_open();
}

function filter_panel_edit(filter_id) {
	filter_configure(filter_id);
}

function filter_panel_load() {
	$.getJSON('/cached_finds/' + $ifloat_body.find_id + '/filters/used', filter_panel_load_handle);
	filter_choose_load();
}

function filter_panel_load_handle(filters) {
	var html = [];
	var section = '';
	
	for(i in filters) {
		var filter = filters[i];
		
		if(section != filter.section) {
			if(i > 0) html.push('<hr class="terminator" />');
			html.push('<h3>' + filter.section + '</h3>');
			section = filter.section;
		}
		
		html.push('<table class="filter" id="filter_' + filter.id + '">');
		html.push('<tr>');
		html.push('<td class="icon">');
		html.push(filter_panel_property_icon(filter, 'filter_panel_edit'));
		html.push('</td>');
		html.push('<td class="summary">' + filter.summary + '</td>');
		html.push('<td><div class="remove" onclick="filter_panel_remove(' + filter.id + ')"></div></td>');
		html.push('</tr>');
		html.push('</table>');
	}
	
	if(html.length > 0) html.push('<hr class="terminator" />');
	
	$('#filter_panel .sections').html(html.join(' '));
}

function filter_panel_property_icon(filter, onclick, tooltip_position) {
	return '<img class="property_icon" src="' + filter.icon_url + '" onclick="' + onclick + '(' + filter.id + ')" onmouseover="tooltip_show(\'' + filter.name + '\', \'' + tooltip_position + '\')" onmouseout="tooltip_hide()" />';
}

function filter_panel_reload(data) {
	if(data == null) {
		alert('The product catalogue has been updated so we need to refresh the page.');
		window.location.reload();
		return;
	}
	
	filter_panel_load_handle(data[0]);
	filter_choose_load_handle(data[1]);
	find_results_update_handle(data[2]);
}

function filter_panel_remove(filter_id) {
	$('#filter_' + filter_id).fadeOut('fast');
	$.post(filter_configure_url(filter_id), {method: 'delete'}, filter_panel_reload, 'json');
}

function filter_panel_remove_all() {
	$('#filter_panel').find('h3,.filter,hr').fadeOut('fast');
	$.getJSON('/cached_finds/' + $ifloat_body.find_id + '/reset/', filter_panel_reload);
}

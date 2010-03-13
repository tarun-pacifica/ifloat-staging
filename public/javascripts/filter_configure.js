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
		$("body").append('<div id="filter_configure" title="Configure the filter..."> </div>');
		filter_configure = $('#filter_configure');
		filter_configure.dialog({autoOpen: false, modal: true, buttons: {Apply: filter_configure_apply}});
		filter_configure.data('width.dialog', 800);
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
	
	filter_configure.html(html.join(' '));
	
	filter_configure.dialog('open');	
}

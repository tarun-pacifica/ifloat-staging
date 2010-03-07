function filter_configure(filter_id) {
	$.getJSON('/cached_finds/' + $ifloat_body.find_id + '/filter/' + filter_id, filter_configure_handle);
	// TODO: spinner
}

function filter_configure_handle(filter) {
	console.log(filter);
	
	filter_choose_close();
	$('#filter_configure').dialog('open');
}

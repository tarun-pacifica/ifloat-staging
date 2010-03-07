function filter_configure(filter_id) {
	$.getJSON('/cached_finds/' + $ifloat_body.find_id + '/filter/' + filter_id, filter_configure_handle);
	// TODO: spinner
}

function filter_configure_handle(filter) {
	if(filter == null) {
		alert("The product catalogue has been updated, making the selected filter obsolete. Please click OK to refresh the page.");
		window.location.reload();
		return;
	}
	
	console.log(filter);
	
	filter_choose_close();
	
	var filter_configure = $('#filter_configure');
	if(! $ifloat_body.filter_configure_created) {
		filter_configure.dialog({autoOpen: false, modal: true});
		$ifloat_body.filter_configure_created = true
	}
	filter_configure.dialog('open');
}

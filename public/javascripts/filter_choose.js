function filter_choose_close() {
	var filter_choose = $('#filter_choose');
	var isOpen = filter_choose.dialog('isOpen');
	if(isOpen) $('#filter_choose').dialog('close');
	return isOpen;
}

function filter_choose_load() {
	$.getJSON('/cached_finds/' + $ifloat_body.find_id + '/filters/unused', filter_choose_load_handle);
}

function filter_choose_load_handle(filters) {
	if(filters == null) {
		alert('The product catalogue has been updated so we need to refresh the page. Please click OK to proceed.');
		window.location.reload();
		return;
	}
	
	$ifloat_body.filter_unused_count = filters.length;
	
	var filters_by_section = util_group_by(filters, 'section');
	
	var section_count_max = 2;
	for(section in filters_by_section) {
		var count = filters_by_section[section].length;
		if(count > section_count_max) section_count_max = count;
	}
	if(section_count_max > 9) section_count_max = 9;
	
	var sections = [];
	for(i in filters) {
		var section = filters[i].section;
		if(sections.length == 0 || (sections[sections.length -1] != section)) sections.push(section);
	}
	
	var row_count = 0;
	var rows = [[]];
	for(i in sections) {
		var section = sections[i];
		var section_count = filters_by_section[section].length;
		if(row_count + section_count < section_count_max) {
			rows[rows.length - 1].push(section);
			row_count += section_count;
		} else {
			rows.push([section]);
			row_count = section_count;
		}
	}
		
	var html = [];	
	for(i in rows) {
		var row = rows[i];
		html.push('<div class="row ' + (i % 2 ? "even" : "odd") + '">');
		
		for(j in row) {
			var section = row[j];
			html.push('<div class="section">');
			html.push('<h3>' + section + '</h3>');
			
			var filters = filters_by_section[section];
			for(k in filters) {
				var filter = filters[k];
				html.push('<div class="filter">');
				html.push(filter_panel_property_icon(filter, 'filter_configure', 'above'));
				html.push('</div>');
			}
			
			html.push('</div>');
		}
		
		html.push('<hr class="terminator" />');
		html.push('</div>');
	}
	
	var filter_choose = $('#filter_choose');
	if(filter_choose.length == 0) {
		$('body').append('<div id="filter_choose" title="Choose a filter..."> </div>');
		filter_choose = $('#filter_choose');
		filter_choose.dialog({autoOpen: false, modal: true, resizable: false});
	}
	filter_choose.data('width.dialog', section_count_max * 78);
	filter_choose.html(html.join(' '));
	filter_choose.find('.row:last').css("border-bottom", "none");
}

function filter_choose_open() {
	if($ifloat_body.filter_unused_count > 0) $('#filter_choose').dialog('open');
}

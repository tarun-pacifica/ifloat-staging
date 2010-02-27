function find_results_make(checksum, count, image_url, popup_image_url) {
	var url = '/cached_finds/' + body_state.find_id + '/found_products_for_checksum/' + checksum;
	var tally = '<div class="tally">' + count + ' item' + (count > 1 ? 's' : '') + '</div>';
	return '<a class="product" href="' + url + '"> ' + tally + product_image_make(image_url, popup_image_url) + ' </a>';
}

function find_results_update() {
	var url = '/cached_finds/' + body_state.find_id + '/found_images/36'
	$.getJSON(url, find_results_update_handle);
}

function find_results_update_handle(data) {
	var image_prod_count = 0;
	var total_prod_count = data.shift();
	var image_count = data.length;
	
	var frps = $('#find_results_products');
	var insertion_point = frps.find('.terminator');
	frps.find('.product').remove();
	
	var products = [];
	for(i in data) {
		var d = data[i];
		image_prod_count += d[1];
		products.push(find_results_make(d[0], d[1], d[2], d[3]));
	}
	
	frps.find('.product').remove();
	frps.find('.terminator').before(products.join(' '));
		
	$('#find_results_count').text(image_prod_count + ' / ' + total_prod_count);
	
	body_state.filter_queue_active = -1;
	// filter_queue_execute();
}

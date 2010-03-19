function find_results_make(checksum, count, image_url, popup_image_url) {
	var url = '/cached_finds/' + $ifloat_body.find_id + '/compare_by_image/' + checksum;
	var tally = '<div class="tally">' + count + ' item' + (count > 1 ? 's' : '') + '</div>';
	return '<a class="product" href="' + url + '"> ' + tally + product_image_make(image_url, popup_image_url) + ' </a>';
}

function find_results_update() {
	var url = '/cached_finds/' + $ifloat_body.find_id + '/images/36'
	$.getJSON(url, find_results_update_handle);
}

function find_results_update_handle(data) {
	if(data == null) {
		alert('The product catalogue has been updated so we need to refresh the page.');
		window.location.reload();
		return;
	}
	
	var image_prod_count = 0;
	var total_prod_count = data.shift();
	var image_count = data.length;
	
	var frps = $('#find_results_products');
	var insertion_point = frps.find('.terminator');
	
	var products = [];
	for(i in data) {
		var d = data[i];
		image_prod_count += d[1];
		products.push(find_results_make(d[0], d[1], d[2], d[3]));
	}
	
	frps.find('p').remove();
	frps.find('.product').remove();
	frps.find('.terminator').before(products.join(' '));
		
	$('#find_results_count').text(image_prod_count + ' / ' + total_prod_count);
	
	if(data.length == 0) {
		frps.find('.terminator').before('<p>You have filtered out all possible products. To fix this, <strong>relax or remove some of your filters</strong>.</p>');
	}
}

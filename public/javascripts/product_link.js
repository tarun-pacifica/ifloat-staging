function product_link(product) {
	var image_urls = product.image_urls;
	var titles = product.titles;
	
	title_lines = [];
	for(i in titles) title_lines.push('<h2>' + titles[i] + '</h2>');
	
	return '<a class="product" href="/products/' + product.id + '">' + product_image_make(image_urls[0], image_urls[1]) + title_lines.join(" ") + '<p>' + product.summary + '</p> <hr class="terminator" /> </a>';
}

var $ifloat_product_links_cache = {};

function product_links_load(product_ids) {
	$ifloat_product_links_requested = product_ids;
	
	var missing = [];
	for(i in product_ids) {
		var id = product_ids[i];
		if($ifloat_product_links_cache[id] == undefined) missing.push(id);
	}
	
	if(missing.length == 0) product_links_load_handle([]);
	else $.getJSON('/products/batch/' + missing.join('_'), product_links_load_handle);	
}

function product_links_load_handle(products) {
	for(i in products) {
		var product = products[i];
		$ifloat_product_links_cache[product.id] = product;
	}
	
	for(i in $ifloat_product_links_requested) {
		var id = $ifloat_product_links_requested[i];
		$('#prod_' + id).html(product_link($ifloat_product_links_cache[id]));
	}
}

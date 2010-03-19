function product_link(product) {
	var image_urls = product.image_urls;
	var titles = product.titles;
	
	title_lines = [];
	for(i in titles) title_lines.push('<h2>' + titles[i] + '</h2>');
	
	return '<a class="product" href="/products/' + product.id + '">' + product_image_make(image_urls[0], image_urls[1]) + title_lines.join(" ") + '<p>' + product.summary + '</p> <hr class="terminator" /> </a>';
}

function product_links_load(product_ids) {
	var url = '/products/batch/' + product_ids.join('_');
	$.getJSON(url, product_links_load_handle);	
}

function product_links_load_handle(products) {
	for(i in products) {
		var product = products[i];
		$('#prod_' + product.id).html(product_link(product));
	}
}

// TODO: revise
// Product Links

function prod_link_detailed(product) {
	var image_urls = product.image_urls;
	var titles = product.titles;
	var summary = product.summary;
	
	title_lines = [];
	for(i in titles) {
		var tag = (i == 4 ? "h2" : "h1");
		title_lines.push("<" + tag + ">" + titles[i] + "</" + tag + ">");
	}
	
	return '<a class="product" href="/products/' + product.id + '">' + prod_image(image_urls[0], image_urls[1]) + title_lines.join(" ") + '<p>' + summary + '</p> <hr /> </a>';
}

function prod_links_load(product_ids) {
	var url = "/products/batch/" + product_ids.join("_");
	$.getJSON(url, prod_links_load_handle);	
}

function prod_links_load_handle(products) {
	for(i in products) {
		var product = products[i];
		$("#prod_" + product.id).html(prod_link_detailed(product));
	}
}

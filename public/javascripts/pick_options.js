function pick_options_update(data) {
	var buy_later = $('#po_buy_later');
	if(buy_later.length == 0) return;
	var buy_now = $('#po_buy_now');
	
	var buy_later_items = (data.buy_later ? data.buy_later : []);
	var buy_now_items = (data.buy_now ? data.buy_now : []);
	
	var html = [];
	for(i in buy_later_items) {
		var info = buy_later_items[i];
		var image = product_image_make(info.image_urls[0], info.image_urls[1], 'right');
		html.push('<div>' + image + info.title_parts.join('<br/>') + '</div>');
		html.push('<div class="button move" onclick="pick_list_move(\'buy_later\', \'buy_now\', ' + info.id + ')"> Shopping List </div>');
	}
	if(html.length == 0) html.push('<p>Your wish list is <strong>empty</strong>.</p>');
	buy_later.find('.sections').html(html.join(' '));
	
	var counts_by_url = {};
	var facility_urls = $ifloat_body.facility_urls;
	for(i in facility_urls) counts_by_url[facility_urls[i]] = 0;
	
	var parity = 'odd';
	var product_ids = []
	html = [];
	for(i in buy_now_items) {
		var info = buy_now_items[i];
		product_ids.push(info.product_id);
		
		parity = (parity == 'even' ? 'odd' : 'even');
		html.push('<tr class="' + parity + '">');
		
		html.push('<td> <div class="button move" onclick="pick_list_move(\'buy_now\', \'buy_later\', ' + info.id + ')"> Wish List </div> </td>');
		html.push('<td> <div id="prod_' + info.product_id + '" class="product"></div> </td>');
		
		var prices_by_url = $ifloat_body.prices_by_url_by_product_id[info.product_id];
		if(prices_by_url) {
			for(j in facility_urls) {
				var url = facility_urls[j];
				var price = prices_by_url[url];
				if(price) {
					html.push('<td>' + util_money(price, $ifloat_body.currency) + '</td>');
					counts_by_url[url] += 1;
				} else {
					html.push('<td>Not in stock</td>');
				}
			}
		}
		
		html.push('</tr>');
	}
	
	// TODO: summary row
	
	var facilities_row = buy_now.find('tr.facilities');
	if(html.length == 0) facilities_row.hide();
	else facilities_row.show();
	
	facilities_row.nextAll().remove();
	facilities_row.after(html.join(' '));
	
	// TODO: introduce caching and load all products first time
	// TODO: should then be able to insert / remove rows without jumping about
	// TODO: can then fade in (and maybe even fade out rows)
	product_links_load(product_ids);
}

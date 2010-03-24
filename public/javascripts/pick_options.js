function pick_options_to_shop(pick_id) {
	var button = $(event.target);
	button.fadeOut('fast');
	button.prev().fadeOut('fast');
	pick_list_move('buy_later', 'buy_now', pick_id);
}

function pick_options_to_wish(pick_id) {
	if(pick_list_move('buy_now', 'buy_later', pick_id)) $(event.target).parents('tr').fadeOut('fast');
}

function pick_options_update(data) {
	var buy_later = $('#po_buy_later');
	if(buy_later.length == 0) return;
	var buy_now = $('#po_buy_now');
	
	var buy_later_items = (data.buy_later ? data.buy_later : []);
	var buy_now_items = (data.buy_now ? data.buy_now : []);
	var product_ids = [];
	
	var html = [];
	for(var i in buy_later_items) {
		var info = buy_later_items[i];
		product_ids.push(info.product_id);
		
		var image = product_image_make(info.image_urls[0], info.image_urls[1], 'right');
		html.push('<div class="product">' + image + info.title_parts.join('<br/>') + '</div>');
		html.push('<div class="button move" onclick="pick_options_to_shop(' + info.id + ')"> Shopping List </div>');
	}
	if(html.length == 0) html.push('<p class="empty">Your wish list is <strong>empty</strong>.</p>');
	else html.push('<hr class="terminator" />');
	buy_later.find('.sections').html(html.join(' '));
	
	var counts_by_url = {};
	var fac_ids_by_url = $ifloat_body.facility_ids_by_url;
	var fac_urls = $ifloat_body.facility_urls;
	for(var url in fac_ids_by_url) counts_by_url[url] = 0;
	
	var parity = 'odd';
	html = [];
	for(var i in buy_now_items) {
		var info = buy_now_items[i];
		product_ids.push(info.product_id);
		
		parity = (parity == 'even' ? 'odd' : 'even');
		html.push('<tr class="' + parity + '">');
		
		html.push('<td class="product">');
		html.push('<div id="prod_' + info.product_id + '" class="product"></div>');
		html.push('</td>');
		
		html.push('<td class="move">');
		html.push('<div class="button move" onclick="pick_options_to_wish(' + info.id + ')"> Wish List </div>');
		html.push('</td>');
		
		var prices_by_url = $ifloat_body.prices_by_url_by_product_id[info.product_id];
		if(prices_by_url == undefined) prices_by_url = {}
		for(var j in fac_urls) {
			var url = fac_urls[j];
			var price = prices_by_url[url];
			if(price) {
				html.push('<td class="price">' + price + '</td>');
				counts_by_url[url] += 1;
			} else {
				html.push('<td class="price">Not in stock</td>');
			}
		}
		
		html.push('</tr>');
	}
	
	var empty_warning = buy_now.find('p.empty');
	var facilities_row = buy_now.find('tr.facilities');
	facilities_row.nextAll().remove();
	
	if(html.length == 0) {
		empty_warning.show();
		facilities_row.hide();
	} else {
		html.push('<tr class="counts">');
		html.push('<td colspan="2"> </td>');
		
		for(var i in fac_urls) {
			html.push('<td class="count">');
			var url = fac_urls[i];
			var count = counts_by_url[url];
			if(count == 0) html.push('No items in stock');
			else html.push('<a href="/picked_products/buy/' + fac_ids_by_url[url] + '">Buy ' + util_pluralize(count, 'item') + '</a>');
			html.push('</td>');
		}
		
		html.push('</tr>');
		
		empty_warning.hide();
		facilities_row.show();
		facilities_row.after(html.join(' '));
	}
	
	product_links_load(product_ids);
}
function pick_list_add(group, product_id) {
	if(pick_list_add_move(group, product_id)) pick_list_blink(group);
}

function pick_list_add_move(group, product_id, pick_id) {
	if(group == "buy_later" && ! $ifloat_header.authenticated) {
		login_open('Please login / register to add items to your wish list...');
		return false;
	}
	
	var data = {group: group};
	var url = "/picked_products";
	
	if(pick_id) {
		url += '/' + pick_id;
		data._method = 'PUT';
	} else {
		data.product_id = product_id;
	}
	
	$.post(url, data, pick_lists_update_handle, 'json');
	return true;
}

function pick_list_blink(group) {
	$('#pl_' + group + ' .menu').animate({color: 'yellow'}).animate({color: 'black'});
}

function pick_list_enable(pick_list) {
	pick_list.click(pick_list_show);
	pick_list.mouseenter(pick_list_show);
	pick_list.mouseleave(pick_list_hide);
}

function pick_list_hide() {
	var list = $(this);
	list.find('a').hide();
	list.children('.menu').css('background-position', '0 0');
	list.children('.items').css('border-bottom', 'none');
}

function pick_list_make_link(info, partner_urls) {
	var partner = (partner_urls != undefined);
	
	var link_url = (partner ? partner_urls[info.product_id] : info.url);
	var klass = (link_url ? 'available' : 'unavailable');
	var target = '';
	if(link_url && partner) target = 'partner_store';
	if(!link_url) link_url = '#';
	
	var image = product_image_make(info.image_urls[0], partner ? undefined : info.image_urls[1]);
	
	return '<a class="' + klass + '" target="' + target + '" href="' + link_url + '">' + image + info.title_parts.join('<br/>') + '</a>';
}

function pick_list_move(from_group, to_group, pick_id) {
	var success = pick_list_add_move(to_group, undefined, pick_id);
	
	if(success) {
		pick_list_blink(from_group);
		pick_list_blink(to_group);
	}
	
	return success;
}

function pick_list_remove(group, pick_id) {
	$.get('/picked_products/' + pick_id + '/delete', pick_lists_update);
	pick_list_blink(group);
}

function pick_list_show() {
	var list = $(this);
	if(list.find('.total').text() == '') return;
	list.find('a').show();
	list.children('.menu').css('background-position', '0 -21px');
	list.children('.items').css('border-bottom', '1px solid #404040');
}

function pick_lists_bind_unavailable(partner_panel) {
	function hide_unavailable() {
		var item = $(this);
		item.html(this.original_html);
		item.css('color', 'gray');
	}

	function show_unavailable() {
		var item = $(this);
		this.original_html = item.html();
		item.html('<p>Not in stock</p>');
		item.css('color', 'red');
	}

	unavailable_items = partner_panel.find('a.unavailable');
	unavailable_items.mouseenter(show_unavailable);
	unavailable_items.mouseleave(hide_unavailable);
}

function pick_lists_clear(pick_lists) {
	pick_lists.unbind();
	pick_lists.children('.items').empty();
	pick_lists.find('.total').empty();
	pick_lists.css('background-position', '0 0');
}

function pick_lists_update() {
	$.getJSON('/picked_products', pick_lists_update_handle);
}

function pick_lists_update_handle(data) {
	var partner_panel = $('#partner_panel');
	var partner = (partner_panel.length > 0);
	var partner_urls = partner_panel.data('partner_urls');
	
	var pick_lists = $('.pick_list');
	if(!partner) pick_lists_clear(pick_lists);
	
	var product_id = $ifloat_body.product_id;
	var product_group, product_pick_id;
	
	for(var group in data) {
		var links = [];
		
		var list = data[group];
		var total_products = (group == 'compare' ? 0 : list.length);
		for(var i in list) {
			var info = list[i];
			links.push(pick_list_make_link(info, partner_urls));
			
			if(group == 'compare') {
				total_products += info.title_parts[1];
				
				var product_ids = info.product_ids;
				for(var i in product_ids) {
					if(product_ids[i] == product_id) {
						product_group = group;
						product_pick_id = info.ids[i];
					}
				}
			} else if(info.product_id == product_id) {
				product_group = group;
				product_pick_id = info.id;
			}
		}
		
		if(!partner && group == 'buy_now') links.push('<a class="buy" href="/picked_products/options">Buy from...</a>');
		
		var pick_list = $('#pl_' + group);
		pick_list.children('.items').html(links.join(' '));
		pick_list.find('.total').text(total_products);
		
		if(!partner) {
			pick_list_enable(pick_list);
			pick_list.css('background-position', '0 -21px');
		}
	}
	
	if(partner) {
		pick_lists_bind_unavailable(partner_panel);
	} else {
		pick_lists.mouseleave();
		product_detail_pick_buttons_update(product_group, product_pick_id);
	}
	
	pick_options_update(data);
}

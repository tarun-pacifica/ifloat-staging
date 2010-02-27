// TODO: revise
// Pick Lists

function pick_list_add(group, product_id) {
	pick_list_add_move(group, product_id);
	pick_list_blink(group);
}

function pick_list_add_move(group, product_id, pick_id) {
	var options = {type: "POST", success: pick_lists_update, error: pick_list_add_move_error};
	if($("#picked_product_options").length > 0) options.success = function() { window.location.reload(); };
	
	options.data = {group: group}
	if(pick_id) {
		options.url = "/picked_products/" + pick_id;
		options.data._method = "PUT";
	} else {
		options.url = "/picked_products"
		options.data.product_id = product_id;
	}
	
	$.ajax(options);
}

function pick_list_add_move_error(request) {
	if(request.status == 401) login_open("Please login / register to add items to that list...");
}

// TODO: revise to flash companion icon instead of text
function pick_list_blink(group) {
	var total = $("#pl_" + group).children(".name,.total");
	total.animate({color:"#FCBB1A"}).animate({color:"white"});
	total.animate({color:"#FCBB1A"}).animate({color:"white"});
}

function pick_list_hide() {
	var list = $(this);
	list.css("background-image", "url(/images/pick_lists/backgrounds/enabled.png)");
	list.find("a").hide();
}

function pick_list_move(from_group, to_group, pick_id) {
	pick_list_add_move(to_group, undefined, pick_id);
	pick_list_blink(from_group);
	pick_list_blink(to_group);
}

function pick_list_remove(group, pick_id) {
	$.get("/picked_products/" + pick_id + "/delete", pick_lists_update);
	pick_list_blink(group);
}

function pick_list_show() {
	var list = $(this);
	if(list.find(".total").text() == "") return;
	list.css("background-image", "url(/images/pick_lists/backgrounds/active.png)");
	list.find("a").show();
}

function pick_lists_update() {
	$.getJSON("/picked_products", pick_lists_update_handle);
}

function pick_lists_update_handle(data) {
	var partner_panel = $("#partner_panel");
	var partner = (partner_panel.length > 0);
	var urls_by_product_id = (partner ? partner_panel[0].urls_by_product_id : {}) 
	
	var pick_lists = $(".pick_list");
	if (!partner) {
		pick_lists.unbind();
		pick_lists.css("background", "black");
		pick_lists.children(".items").empty();
		pick_lists.children(".total").empty();
	}
	
	for(group in data) {
		var links = [];
		
		if(!partner && group == "buy_now") links.push('<a class="buy" href="/picked_products/options">Buy from...</a>');
		
		var list = data[group];
		var total_products = (group == "compare" ? 0 : list.length);
		for(i in list) {
			var info = list[i];
			var product_id = info[0]
			var image_urls = info[1];
			var image = prod_image(image_urls[0], partner ? undefined : image_urls[1]);
			var title_parts = info[2];
			var target = (partner ? "partner_store" : "")
			var link_url = (partner ? urls_by_product_id[product_id] : info[3]);
			var klass = (link_url ? "available" : "unavailable");
			if(!link_url) link_url = "#";
			links.push('<a class="' + klass + '" target="' + target + '" href="' + link_url + '">' + image + title_parts.join("<br/>") + '</a>');
			if(group == "compare") total_products += title_parts[1];
		}
		
		var pick_list = $("#pl_" + group);
		pick_list.children(".items").html(links.join(" "));
		pick_list.children(".total").html(total_products);
		if(!partner) {
			pick_list.click(pick_list_show);
			pick_list.mouseenter(pick_list_show);
			pick_list.mouseleave(pick_list_hide);
			pick_list.css("background", "url(/images/pick_lists/backgrounds/enabled.png) repeat-x;");
		}
	}
	
	if (partner) {
		function hide_unavailable() {
			var item = $(this);
			item.html(this.original_html);
			item.css("color", "gray");
		}

		function show_unavailable() {
			var item = $(this);
			this.original_html = item.html();
			item.html("<p>UNAVAILABLE</p>");
			item.css("color", "red");
		}

		unavailable_items = partner_panel.find("a.unavailable");
		unavailable_items.mouseover(show_unavailable);
		unavailable_items.mouseout(hide_unavailable);
	} else {
		pick_lists.mouseleave();
		var pb = $("#pick_buttons")[0];
		if(pb) prod_detail_update_pick_buttons(pb.product_id);
	}
}

// TODO: revise
// Product Detail

function prod_detail_click_pick_button(b) {
	if(b.klass == "add") pick_list_add(b.to_group, b.product_id);
	else if(b.klass == "move") pick_list_move(b.from_group, b.to_group, b.pick_id);
	else pick_list_remove(b.to_group, b.pick_id);
}

function prod_detail_more_relations(d) {
	var more_bar = $(d).parent();
	more_bar.prevAll().show();
	more_bar.hide();
}

function prod_detail_select_image(event) {
	$("#product_detail_assets").find("img.main")[0].src = event.target.src;
}

function prod_detail_update_pick_buttons() {
	$.getJSON("/products/" + $ifloat_body.product_id + "/picked_group", prod_detail_update_pick_buttons_handle);
}

function prod_detail_update_pick_buttons_handle(data) {
	var pick_id = data[0];
	var group = data[1];
	var product_id = data[2];
	
	var actions = {add: "Add to", move: "Move to", remove: "Remove from"};
	var groups = ["compare", "buy_later", "buy_now"];
	var lists = {compare: "Compare List", buy_later: "Wish List", buy_now: "Shopping List"};
	
	var button_set = $("#pick_buttons");
	button_set.empty();
	
	for(i in groups) {
		var g = groups[i];
		var klass = (group ? (group == g ? "remove" : "move") : "add");
		
		button_set.append('<div class="' + [klass, g].join(" ") + '" onclick="prod_detail_click_pick_button(this)">' + actions[klass] + ' ' + lists[g] + '</div>');
		
		var b = button_set.children("." + g)[0];
		b.klass = klass;
		b.from_group = group;
		b.to_group = g;
		b.pick_id = pick_id;
		b.product_id = product_id;
	}
}

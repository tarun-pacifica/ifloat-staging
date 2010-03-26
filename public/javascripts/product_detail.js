function product_detail_more_relations(event) {
	var more = $(event.target);
	more.prevAll().show();
	more.hide();
}

function product_detail_pick_button_click(action, from_group, to_group, pick_id) {
	if(action == 'add') pick_list_add(to_group, $ifloat_body.product_id);
	else if(action == 'move') pick_list_move(from_group, to_group, pick_id);
	else pick_list_remove(to_group, pick_id);
}

function product_detail_pick_buttons_update(group, pick_id) {
	var pick_buttons = $('#pick_buttons');
	
	if(pick_buttons.length == 0) return;
	
	var groups = ['compare', 'buy_later', 'buy_now'];
	var lists = {compare: 'Compare', buy_later: 'Future Buys', buy_now: 'Buy Now'};
	
	pick_buttons.empty();
	
	for(var i in groups) {
		var g = groups[i];
		var action = (group ? (group == g ? 'remove' : 'move') : 'add');
		var click = "product_detail_pick_button_click('" + action + "', '" + group + "', '" + g + "', " + pick_id + ")";
		pick_buttons.append('<div class="button ' + action + '" onclick="' + click + '">' + lists[g] + '</div>');
	}
}

function product_detail_select_image(event) {
	$('#product_detail').find('img.main').attr('src', event.target.src);
}

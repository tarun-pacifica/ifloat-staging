function prod_detail_more_relations(d) {
	var more_bar = $(d).parent();
	more_bar.prevAll().show();
	more_bar.hide();
}

function prod_detail_pick_button_click(action, from_group, to_group, pick_id) {
	if(action == 'add') pick_list_add(to_group, $ifloat_body.product_id);
	else if(action == 'move') pick_list_move(from_group, to_group, pick_id);
	else pick_list_remove(to_group, pick_id);
}

function prod_detail_pick_buttons_update(group, pick_id) {
	var pick_buttons = $('#pick_buttons');
	
	if(pick_buttons.length == 0) return;
	
	var actions = {add: 'Add to', move: 'Move to', remove: 'Remove from'};
	var groups = ['compare', 'buy_later', 'buy_now'];
	var lists = {compare: 'Compare List', buy_later: 'Wish List', buy_now: 'Shopping List'};
	
	pick_buttons.empty();
	
	for(i in groups) {
		var g = groups[i];
		var action = (group ? (group == g ? 'remove' : 'move') : 'add');
		
		var click = "prod_detail_pick_button_click('" + action + "', '" + group + "', '" + g + "', " + pick_id + ")";
		
		pick_buttons.append('<div class="' + [action, g].join(' ') + '" onclick="' + click + '">' + actions[action] + ' ' + lists[g] + '</div>');
	}
}

function prod_detail_select_image(event) {
	$('#product_detail_assets').find('img.main').attr('src', event.target.src);
}

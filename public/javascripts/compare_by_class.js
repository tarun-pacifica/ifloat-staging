function compare_by_class_pick(to_group, pick_id, col_class) {
	if(to_group) pick_list_move('compare', to_group, pick_id);
	else pick_list_remove('compare', pick_id);
	
	$('#compare_by_class table td.' + col_class).addClass('defunct').fadeOut('fast', compare_by_class_remove);
}

var compare_by_class_remove_count = 0;
function compare_by_class_remove() {
	var table = $('#compare_by_class table');
	
	compare_by_class_remove_count += 1;
	var defunct = table.find('td.defunct');
	if(compare_by_class_remove_count < defunct.length) return;
	
	defunct.remove();
	if(table.find('td.image').length < 2) window.location.reload();
	else util_carousel_table('#compare_by_class table', [0], [1, 2, 3]);
}
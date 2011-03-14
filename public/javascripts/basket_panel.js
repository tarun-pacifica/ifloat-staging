function basket_panel_load() {
  
}

// function product_detail_pick_button_click(event) {
//   var button = util_target(event);
//   var to_group = null;
//   var groups = ['buy_later', 'buy_now', 'compare'];
//   for(var i in groups) {
//     var g = groups[i];
//     if(button.hasClass(g)) {
//       to_group = g;
//       break;
//     }
//   }
//   
//   var data = button.parent().data();
//   var from_group = data.group;
//   var pick_id = data.pick_id;
//   
//   if(to_group == null) {
//     if(from_group) pick_list_remove(from_group, pick_id);
//   }
//   else if(from_group) pick_list_move(from_group, to_group, pick_id);
//   else pick_list_add(to_group, $ifloat_body.product_id);
// }
// 
// function product_detail_pick_buttons_update(group, pick_id) {
//   var pick_buttons = $('#pick_buttons');
//   if(pick_buttons.length == 0) return;
//   
//   pick_buttons.removeData();
//   if(group) pick_buttons.data('group', group)
//   if(pick_id) pick_buttons.data('pick_id', pick_id);
//   
//   pick_buttons.find('div').removeClass('selected').unbind('click').click(product_detail_pick_button_click);
//   if(group) pick_buttons.find('.' + group).addClass('selected').unbind('click');
// }

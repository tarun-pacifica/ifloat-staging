function product_detail_buy_now(product_id, facility_id) {
  window.location = '/products/' + product_id + '/buy_now/' + facility_id;
}

function product_detail_flash_related() {
  $('.relations').animate({backgroundColor: 'yellow'}).animate({backgroundColor: '#F3F3F3'});
}

function product_detail_load_related(related_by_name) {
  for(var name in related_by_name) {
    var related = related_by_name[name];
    var section = $('#rel_' + name);
    
    for(i in related) {
      var info = related[i];
      section.append(find_results_make(info[0], info[1], info[2], info[3], info[4], $ifloat_body.product_id));
    }
    
    section.append('<hr class="terminator" />');
  }
}

function product_detail_pick_button_click(event) {
  var button = util_target(event);
  var to_group = null;
  var groups = ['buy_later', 'buy_now', 'compare'];
  for(var i in groups) {
    var g = groups[i];
    if(button.hasClass(g)) {
      to_group = g;
      break;
    }
  }
  
  var data = button.parent().data();
  var from_group = data.group;
  var pick_id = data.pick_id;
  
  if(to_group == null) {
    if(from_group) pick_list_remove(from_group, pick_id);
  }
  else if(from_group) pick_list_move(from_group, to_group, pick_id);
  else pick_list_add(to_group, $ifloat_body.product_id);
}

function product_detail_pick_buttons_update(group, pick_id) {
  var pick_buttons = $('#pick_buttons');
  if(pick_buttons.length == 0) return;
  
  pick_buttons.removeData();
  if(group) pick_buttons.data('group', group)
  if(pick_id) pick_buttons.data('pick_id', pick_id);
  
  pick_buttons.find('div').removeClass('selected').unbind('click').click(product_detail_pick_button_click);
  if(group) pick_buttons.find('.' + group).addClass('selected').unbind('click');
}

function product_detail_select_image(event) {
  $('#product_detail').find('img.main').attr('src', util_target(event).attr('src'));
}

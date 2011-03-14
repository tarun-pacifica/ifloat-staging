function basket_panel_load() {
  $.getJSON('/picked_products', basket_panel_load_handle);
}

function basket_panel_load_handle(picks_by_group) {
  var html = [].concat(
    basket_panel_load_handle_buy_now(picks_by_group.buy_now),
    basket_panel_load_handle_buy_later(picks_by_group.buy_later),
    basket_panel_load_handle_compare(picks_by_group.compare)
  );
  
  $('#basket_panel').append(html.join(' '));
}

function basket_panel_load_handle_buy_now(picks) {
  if (!picks) return [];
  
  var html = [];
  return html
}

function basket_panel_load_handle_buy_later(picks) {
  if (!picks) return [];
  
  var html = [];
  return html
}

function basket_panel_load_handle_compare(picks) {
  if (!picks) return [];
  
  var html = [];
  return html
}

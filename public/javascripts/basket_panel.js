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

function basket_panel_load_handle_buy_now(picks_and_subtotal) {
  if (!picks_and_subtotal) return [];
  
  var subtotal = picks_and_subtotal.pop();
  
  var html = [];
  for(var i in picks_and_subtotal) html.push(basket_panel_markup_item(picks_and_subtotal[i], true));
  html.push('<div class="subtotal"> <span class="label">Sub-total</span> <span class="money">' + subtotal + ' </span></div>');
  return html;
}

function basket_panel_load_handle_buy_later(picks) {
  if (!picks) return [];
  
  var html = [basket_panel_markup_header('Future Buys', '/images/basket/buy_later.png')];
  for(var i in picks) html.push(basket_panel_markup_item(picks[i], false));
  return html;
}

function basket_panel_load_handle_compare(picks) {
  if (!picks) return [];
  
  var html = [basket_panel_markup_header('Compare List', '/images/basket/compare.png')];
  
  var section = undefined, section_count = 0;
  for(var i in picks) {
    var pick = picks[i];
    
    var klass = pick.title_parts[1];
    if(section != klass) {
      html.push('<h3>' + klass + '</h3>');
      if(section_count > 1) {
        html.push('<a href="/picked_products/products_for/' + klass + '"> Differentiate ' + klass + ' Products </a>');
      }
      section = klass;
      section_count = 0;
    }
    
    html.push(basket_panel_markup_item(pick, false));
    section_count += 1;
  }
  
  return html;
}

function basket_panel_markup_item(pick, show_quantity) {
  var html = ['<div class="item">'];
  
  html.push('<a href="/picked_products/' + pick.id + '/delete">X</a>');
  html.push('<p>' + pick.title_parts.join(' - ') + '</p>');
  
  var quantity = '';
  if(show_quantity) quantity = '<span class="quantity">' + (pick.unit ? pick.quantity + pick.unit : 'x' + pick.quantity) + '</span> <span class="change_quantity">change quantity</span>';
  html.push('<p> ' + quantity + ' <span class="money">' + pick.subtotal + '</span> </p>');
  
  html.push('</div>');
  return html.join(' ');
}

function basket_panel_markup_header(text, img_src) {
  return '<h2> <img src="' + img_src + '" /> ' + text + ' </h2>';
}

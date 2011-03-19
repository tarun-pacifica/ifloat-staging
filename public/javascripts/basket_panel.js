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
  
  // TODO: cope with 0-valued subtotal by hiding checkout button and ?
  
  var html = [];
  for(var i in picks_and_subtotal) html.push(basket_panel_markup_item(picks_and_subtotal[i], true));
  html.push('<div class="subtotal"> <p><span class="label">Sub-total</span> <span class="money">' + subtotal + ' </span></p> <div class="checkout">GO TO CHECKOUT</div> </div>');
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

function basket_panel_markup_item(pick, buy_now) {
  var html = ['<div class="item ' + (buy_now ? 'buy_now' : '') + '">'];
  
  html.push('<span class="delete" onclick="basket_panel_delete(' + pick.id + ')">X</span>');
  html.push('<p> <a href="' + pick.url + '">'+ pick.title_parts.join(' - ') + '</a> </p>');
  
  if(buy_now) html.push('<p class="quantity"> ' + (pick.unit ? pick.quantity + pick.unit : 'x' + pick.quantity) + '<span class="change_quantity" onclick="basket_panel_change_quantity(' + [pick.id, pick.quantity, pick.unit ? util_escape_attr_js(pick.unit) : ''].join(', ') + ')">change quantity</span> </p>');
  
  html.push('<p class="money">' + pick.subtotal + '</p>');
  
  html.push('</div>');
  return html.join(' ');
}

function basket_panel_markup_header(text, img_src) {
  return '<h2> <img src="' + img_src + '" /> ' + text + ' </h2>';
}

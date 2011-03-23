var basket_panel_product_info = null;
function basket_panel_add(group) {
  if(group == 'buy_later' && ! $ifloat_header.authenticated) {
    login_open('Please login / register to add items to your future buys...');
    return;
  }
  
  var adder =  $('#basket_panel_adder');
  adder.fadeOut('fast');
  
  var data = {
    group: group,
    product_id: basket_panel_product_info.product_id,
    quantity: adder.find('input').val()
  };
  
  $.post('/picked_products', data, basket_panel_load_handle, 'json');
}

function basket_panel_change_quantity(event, pick_id, quantity, unit) {
  var para = util_target(event).parent();
  para.html('<form onsubmit="$(this).find(\'.change_quantity\').click(); return false"> <input name="quantity" type="text" value="' + quantity + '" size="4" />' + (unit ? unit : '') + ' <span class="change_quantity" onclick="basket_panel_change_quantity_apply(event, ' + pick_id + ')">apply</span></form>');
  para.find('input').focus();
}

function basket_panel_change_quantity_apply(event, pick_id) {
  var quantity = util_target(event).parent().find('input').val();
  $.post('/picked_products/' + pick_id, {_method: 'PUT', quantity: quantity}, basket_panel_load_handle, 'json');
}

function basket_panel_delete(event, pick_id) {
  util_target(event).parent().fadeOut('fast');
  $.getJSON('/picked_products/' + pick_id + '/delete', basket_panel_load_handle);
}


function basket_panel_load(product_id, price, unit_of_measure) {
  if(product_id) basket_panel_product_info = {product_id: product_id, price: price, uom: unit_of_measure};
  $.getJSON('/picked_products', basket_panel_load_handle);
}

function basket_panel_load_handle(picks_by_group) {
  var html = [];
  
  var info = basket_panel_product_info;
  if(info) {
    picks_contain_product_id = false;
    for(group in picks_by_group) {
      var picks = picks_by_group[group];
      for(i in picks) picks_contain_product_id = picks_contain_product_id || (info.product_id == picks[i].product_id);
    }
    
    if(!picks_contain_product_id) {
      if(info.price) {
        html.push('<div id="basket_panel_adder">');
        html.push('<p class="price">' + info.price + '</p>');
        html.push('<p class="price_note">(Best partner price)</p>');
        html.push('<form onsubmit="$(\'#basket_panel_adder .add_basket\').click(); return false"> <label for="quantity">Quantity</label> <input name="quantity" type="text" value="1" size="4" />' + (info.uom ? info.uom : '') + '</form>');
        html.push('<div class="add_basket" onclick="basket_panel_add(\'buy_now\')">ADD TO BASKET</div>');
        html.push('<p class="add_other" onclick="basket_panel_add(\'buy_later\')">Add to Future Buys</p>');
        html.push('<p class="add_other" onclick="basket_panel_add(\'compare\')">Add to Compare List</p>');
        html.push('</div>');
      } else {
        html.push('<div id="basket_panel_adder"> <p class="no_price">None of our partners have this item in stock at the moment</p> </div>');
      }
    }
  }
  
  if(html.length == 0 && !picks_by_group.buy_now) {
    html.push('<div class="item"> <p class="no_items">Your basket is empty</p> </div>');
  }
  
  html = html.concat(
    basket_panel_load_handle_buy_now(picks_by_group.buy_now),
    basket_panel_load_handle_buy_later(picks_by_group.buy_later),
    basket_panel_load_handle_compare(picks_by_group.compare)
  );
  
  $('#basket_panel').html(html.join(' '));
}

function basket_panel_load_handle_buy_now(picks_and_subtotal) {
  if (!picks_and_subtotal) return [];
  
  var subtotal = picks_and_subtotal.pop();
  
  var html = [];
  for(var i in picks_and_subtotal) html.push(basket_panel_markup_item(picks_and_subtotal[i], true));
  html.push('<div class="subtotal"> <p><span class="label">Sub-total</span> <span class="money">' + subtotal + ' </span></p> <div class="checkout">GO TO CHECKOUT</div> </div>');
  return html;
}

function basket_panel_load_handle_buy_later(picks) {
  if (!picks) return [];
  
  var html = [basket_panel_markup_header('Future Buys', '/images/basket_panel/buy_later_blue.png')];
  for(var i in picks) html.push(basket_panel_markup_item(picks[i], false));
  return html;
}

function basket_panel_load_handle_compare(picks) {
  if (!picks) return [];
  
  var html = [basket_panel_markup_header('Compare List', '/images/basket_panel/compare_blue.png')];
  
  var section = undefined, section_count = 0;
  for(var i in picks) {
    var pick = picks[i];
    
    var klass = pick.title_parts[1];
    if(section != klass) {
      html.push(basket_panel_markup_differentiate(section_count, section));
      html.push('<h3>' + klass + '</h3>');
      section = klass;
      section_count = 0;
    }
    
    html.push(basket_panel_markup_item(pick, false));
    section_count += 1;
  }
  
  html.push(basket_panel_markup_differentiate(section_count, picks[picks.length - 1].title_parts[1]));
  
  return html;
}

function basket_panel_markup_differentiate(section_count, klass) {
  if(section_count < 2) return '';
  return '<div class="item compare"> <a class="compare" href="/picked_products/products_for/' + klass + '"> Compare ' + klass + ' </a> </div>';
}

function basket_panel_markup_item(pick, buy_now) {
  var html = ['<div class="item ' + (buy_now ? 'buy_now' : '') + '">'];
  
  html.push('<span class="delete" onclick="basket_panel_delete(event, ' + pick.id + ')">X</span>');
  html.push('<p> <a href="' + pick.url + '">'+ util_superscript('text', pick.title_parts.join(' - ')) + '</a> </p>');
  
  if(buy_now) html.push('<p class="quantity"> ' + (pick.unit ? pick.quantity + pick.unit : 'x' + pick.quantity) + '<span class="change_quantity" onclick="basket_panel_change_quantity(event, ' + [pick.id, pick.quantity, util_escape_attr_js(pick.unit ? pick.unit : '')].join(', ') + ')">change quantity</span> </p>');
  
  html.push('<p class="money">' + pick.subtotal + '</p>');
  
  html.push('</div>');
  return html.join(' ');
}

// TODO: simplify if images no longer needed
function basket_panel_markup_header(text, img_src) {
  return '<h2>' + text + ' </h2>';
  // return '<h2> <img src="' + img_src + '" /> ' + text + ' </h2>';
}

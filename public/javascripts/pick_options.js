function pick_options_buy_later(event, pick_id) {
  if(pick_list_move('buy_now', 'buy_later', pick_id)) pick_options_fadeout('buy_now', event);
}

function pick_options_buy_now(event, pick_id) {
  pick_list_move('buy_later', 'buy_now', pick_id);
  pick_options_fadeout('buy_later', event);
}

function pick_options_fadeout(group, event) {
  if(group == 'buy_later') {
    var buttons = util_target(event).parent();
    buttons.fadeOut('fast');
    buttons.prev().fadeOut('fast');
  } else {
    util_target(event).parents('tr').fadeOut('fast');
  }
}

function pick_options_reset(event, from_group, pick_id) {
  pick_options_fadeout(from_group, event);
  pick_list_remove(from_group, pick_id);
}

function pick_options_update(data) {
  var buy_later = $('#po_buy_later');
  if(buy_later.length == 0) return;
  var buy_now = $('#po_buy_now');
  
  var buy_later_items = (data.buy_later ? data.buy_later : []);
  var buy_now_items = (data.buy_now ? data.buy_now : []);
  var product_ids = [];
  
  
  // BUY LATER
  
  var html = [];
  for(var i in buy_later_items) {
    var info = buy_later_items[i];
    product_ids.push(info.product_id);
    
    html.push('<div class="product">');
    html.push(product_image_make(info.image_urls[0], info.image_urls[1], 'right'));
    html.push('<a href="' + info.url + '">' + info.title_parts.join('<br/>') + '</a>');
    html.push('</div>');
    html.push('<div class="pick_buttons">');
    html.push('<div class="buy_now" onclick="pick_options_buy_now(event, ' + info.id + ')"> </div>');
    html.push('<div class="reset" onclick="pick_options_reset(event, \'buy_later\', ' + info.id + ')"> </div>');
    html.push('</div>');
    html.push('<hr class="terminator" />');
  }
  if(html.length == 0) html.push('<p class="empty">You have no future buys</p>');
  else html.push('<hr class="terminator final" />');
  buy_later.find('.sections').html(html.join(' '));
  
  
  // BUY NOW
  
  var empty_warning = buy_now.find('p.empty');
  var facilities_row = buy_now.find('tr.facilities');
  facilities_row.nextAll().remove();
  
  if(buy_now_items.length == 0) {
    empty_warning.show();
    facilities_row.hide();
    return;
  }
  
  empty_warning.hide();
  facilities_row.show();
  
  var fac_desc_by_url = $ifloat_body.facility_descriptions_by_url;
  var fac_ids_by_url = $ifloat_body.facility_ids_by_url;
  var fac_urls = $ifloat_body.facility_urls;
  var prices_by_url_by_product_id = $ifloat_body.prices_by_url_by_product_id;
  
  // Buy Buttons
  
  var counts_by_url = {};
  for(var url in fac_ids_by_url) {
    counts_by_url[url] = 0;
    
    for(var i in buy_now_items) {
      var info = buy_now_items[i];
      var prices_by_url = prices_by_url_by_product_id[info.product_id];
      if(prices_by_url == undefined) continue;
      for(var url in prices_by_url) counts_by_url[url] += 1
    }
  }
  
  for(var i in fac_urls) {
    var html = '<p>No items in stock</p>';
    var url = fac_urls[i];
    if(counts_by_url[url] > 0) {
      var desc = fac_desc_by_url[url], id = fac_ids_by_url[url];
      html = '<a href="/picked_products/buy/' + id + '" onmouseover="tooltip_show(event, \'' + desc + '\', \'left\')" onmouseout="tooltip_hide()">Buy All Now</a>';
    }
    var image = facilities_row.find('img[alt=' + url + ']');
    image.siblings().remove();
    image.after(html);
  }
  
  // Products
  
  var html = [];
  var parity = 'odd';
  for(var i in buy_now_items) {
    var info = buy_now_items[i];
    product_ids.push(info.product_id);
    
    parity = (parity == 'even' ? 'odd' : 'even');
    html.push('<tr class="' + parity + '">');
    
    html.push('<td class="product">');
    html.push('<div id="prod_' + info.product_id + '" class="product"></div>');
    html.push('</td>');
    
    html.push('<td class="buttons">');
    html.push('<div class="buttons">');
    html.push('<div class="buy_later" onclick="pick_options_buy_later(event, ' + info.id + ')"> </div>');
    html.push('<div class="reset" onclick="pick_options_reset(event, \'buy_now\', ' + info.id + ')"> </div>');
    html.push('</div');
    html.push('</td>');
    
    var prices_by_url = prices_by_url_by_product_id[info.product_id];
    if(prices_by_url == undefined) prices_by_url = {}
    for(var j in fac_urls) {
      var url = fac_urls[j];
      var desc = fac_desc_by_url[url], id = fac_ids_by_url[url], price = prices_by_url[url];
      if(price == undefined) html.push('<td class="price">Not in stock</td>');
      else html.push('<td class="price"> ' + price + ' <a href="/picked_products/buy/' + id + '?product_id=' + info.product_id + '" onmouseover="tooltip_show(event, \'' + desc + '\', \'left\')" onmouseout="tooltip_hide()">Buy Now</a> </td>');
    }
    
    html.push('</tr>');
  }
  
  facilities_row.after(html.join(' '));
  
  product_links_load(product_ids);
}

function product_related_media_show(event) {
  util_target(event).hide();
  $('#product .related_media').fadeIn('fast');
}

var product_sibling_prod_ids_by_value_by_prop_ids = {};
function product_sibling_prod_ids(sibling) {
  var prop_id = sibling.attr('id').split('_')[2];
  var value = product_sibling_value(sibling);
  return product_sibling_prod_ids_by_value_by_prop_ids[prop_id][value];
}

function product_sibling_reset(sibling, acceptable_prod_ids) {
  var prop_id = sibling.attr('id').split('_')[2];
  var product_sibling_prod_ids_by_value = product_sibling_prod_ids_by_value_by_prop_ids[prop_id];
  
  for(var value in product_sibling_prod_ids_by_value) {
    var prod_ids = product_sibling_prod_ids_by_value[value];
    if(util_intersection(acceptable_prod_ids, prod_ids).length == 0) continue;
    product_sibling_value(sibling, value);
    break;
  }
}

function product_sibling_select(event, repeat) {
  var target = util_target(event);
  
  if(!repeat && target.is('span')) {
    if(target.hasClass('selected')) return;
    target.addClass('selected');
    target.siblings().removeClass('selected');
  }
  
  var chosen_sibling = target.parent().parent();
  var chosen_prod_ids = product_sibling_prod_ids(chosen_sibling);
  var global_intersection = chosen_prod_ids.slice(0);
  
  $('#pick_sibling .sibling').not(chosen_sibling).each(function () {
    var prod_ids = product_sibling_prod_ids($(this));
    if(!prod_ids) {
      product_sibling_reset($(this), chosen_prod_ids);
      return;
    }
    
    var local_intersection = util_intersection(chosen_prod_ids, prod_ids);
    if(local_intersection.length == 0) product_sibling_reset($(this), chosen_prod_ids);
    else global_intersection = util_intersection(global_intersection, local_intersection);
  });
  
  if(global_intersection.length == 1) window.location = '/products/sibling-' + global_intersection[0];
  else if(repeat) console.log('avoiding infinite loop in product_sibling_select');
  else product_sibling_select(event, true);
}

function product_sibling_value(sibling, new_value) {
  var v = sibling.find('.value');
  
  if(new_value == undefined) return (v.length > 1 ? v.filter('.selected').text() : v.val());
  
  if(v.length > 1) {
    v.removeClass('selected').each(function() { if($(this).text() == new_value) $(this).addClass('selected') });
  } else {
    v.val(new_value);
  }
}

function product_siblings_wire_up(prod_ids_by_value_by_prop_ids) {
  product_sibling_prod_ids_by_value_by_prop_ids = prod_ids_by_value_by_prop_ids;
}

function product_thumb_hover(event) {
  var thumb = util_target(event);
  $('#product img.main').attr('src', thumb.attr('src'));
  $('#product img.thumb').css('opacity', '0.5').css('border-style', 'dotted');
  thumb.css('opacity', '1').css('border-style', 'solid');
}

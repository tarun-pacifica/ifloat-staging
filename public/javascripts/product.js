var product_property_ids_by_section = {};
function product_property_sections_init(property_ids_by_section) {
  product_property_ids_by_section = property_ids_by_section;
  
  var sections = $('#product .properties .sections div');
  sections.click(product_property_section_select);
  $(sections[1]).click();
}

function product_property_section_select(event) {
  var properties = $('#product .properties');
  properties.find('.sections div').removeClass('selected');
  
  var section = $(this);
  section.addClass('selected');
  
  var all_values = properties.find('.values table tr');
  all_values.hide();
  
  var property_ids = product_property_ids_by_section[section.text()]
  for(var i in property_ids) $('#property_' + property_ids[i]).show();
}

function product_related_media_show(event) {
  util_target(event).hide();
  $('#product .related_media').fadeIn('fast');
}

var product_sibling_prod_ids_by_value_by_prop_ids = {};
function product_sibling_select() {
  var siblings = $('#pick_sibling .sibling');
  
  var prod_id_intersection = null;
  siblings.each(function () {
    var prop_id = $(this).attr('id').split('_')[2];
    var value = $(this).find('select').val();
    
    var prod_ids = product_sibling_prod_ids_by_value_by_prop_ids[prop_id][value];
    if(prod_ids) {
      if(prod_id_intersection) {
        var old_intersection = prod_id_intersection;
        prod_id_intersection = {};
        for(var i in prod_ids) {
          var prod_id = prod_ids[i];
          if(old_intersection[prod_id]) prod_id_intersection[prod_id] = true
        }
      } else {
        prod_id_intersection = util_hash_from_array(prod_ids, true);
      }
    }
  });
  
  var prod_ids = [];
  for(prod_id in prod_id_intersection) prod_ids.push(prod_id);
  
  var selects = siblings.find('select')
  selects.removeAttr('disabled');
  selects.find('option').removeAttr('disabled');
  
  if(prod_ids.length == 0) return;

  if(prod_ids.length == 1) {
    window.location = '/products/sibling-' + prod_ids[0];
    return;
  }
  
  for(var prop_id in product_sibling_prod_ids_by_value_by_prop_ids) {
    var prod_ids_by_value = product_sibling_prod_ids_by_value_by_prop_ids[prop_id];
    var disabled_values_exist = false, enabled_values = [];
    
    for(var value in prod_ids_by_value) {
      var enabled = false;
      var prod_ids = prod_ids_by_value[value];
      for(var i in prod_ids) enabled = (enabled || prod_id_intersection[prod_ids[i]]);
      if(enabled) enabled_values.push(value);
      else disabled_values_exist = true;
    }
    
    if(!disabled_values_exist) continue;
        
    var select = $('#sibling_property_' + prop_id + ' select');
    var options = select.find('option');
    
    if(enabled_values.length == 0) {
      select.attr('disabled', 'disabled');
      continue;
    }
    
    var enabled_values = util_hash_from_array(enabled_values, true);
    
    options.each(function(index) {
      var option = $(this);
      if(index > 0 && !enabled_values[option.val()]) option.attr('disabled', 'disabled');
    });
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

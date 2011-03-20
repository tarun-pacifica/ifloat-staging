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

var product_sibling_prod_ids_by_value_by_prop_ids = {};
function product_sibling_select() {
  var prod_id_intersection = null;
  
  $('#pick_sibling .sibling').each(function () {
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
  
  if(prod_ids.length == 1) window.location = '/products/sibling-' + prod_ids[0];
  // TODO: hide obsolete selects
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

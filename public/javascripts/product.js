var product_property_ids_by_section = {}
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

function product_thumb_hover(event) {
  var thumb = util_target(event);
  $('#product img.main').attr('src', thumb.attr('src'));
  $('#product img.thumb').css('opacity', '0.5').css('border-style', 'dotted');
  thumb.css('opacity', '1').css('border-style', 'solid');
}

// function product_detail_buy_now(product_id, facility_id) {
//   window.location = '/products/' + product_id + '/buy_now/' + facility_id;
// }

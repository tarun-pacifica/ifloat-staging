var common_values_property_ids_by_section = {};
function common_values_init(property_ids_by_section) {
  common_values_property_ids_by_section = property_ids_by_section;
  
  var sections = $('#common_values .sections div');
  sections.click(common_values_select);
  $(sections[1]).click();
}

function common_values_select(event) {
  var properties = $('#common_values');
  properties.find('.sections div').removeClass('selected');
  
  var section = $(this);
  section.addClass('selected');
  
  var all_values = properties.find('.values table tr');
  all_values.hide();
  
  var property_ids = common_values_property_ids_by_section[section.text()]
  for(var i in property_ids) $('#property_' + property_ids[i]).show();
}

var category_filters_back_buffer = null;
function category_filters_back() {
  $('#categories .filters').html(category_filters_back_buffer);
}

var category_filters_choose_values = null;
function category_filters_choose(index) {
  window.location = category_filters_url(null, category_filters_choose_values[index]);
}

function category_filters_configure(filter_id) {
  $.getJSON(category_filters_url('filter/' + filter_id), category_filters_configure_handle);
  spinner_show('Retrieving filter values...');
  tooltip_hide(); // needed by Firefox
}

function category_filters_configure_handle(filter) {
  category_filters_choose_values = [];
  
  var all_values = [], vbu = filter.values_by_unit;
  for(var unit in vbu) {
    var values = vbu[unit];
    for(var i in values) {
      var v = values[i];
      var formatted = (filter.type == 'text' ? util_defined(v[0], v[1]) : v[1]);
      all_values[i] = (all_values[i] ? all_values[i] + ' / ' + formatted : formatted);
      category_filters_choose_values[i] = [filter.id, unit, v[0], filter.type == 'text' ? null : all_values[i]];
    }
  }
  
  if(all_values.length == 0) {
    alert('The product catalogue has been updated so we need to refresh the page.');
    window.location.reload();
    return;
  }
  
  var html = ['<h2>Choose a ' + filter.name + ' value... <span onclick="category_filters_back()">« back to all filters</span></h2>'];
  
  html.push('<ul>');
  for(var i in all_values) html.push('<li onclick="category_filters_choose(' + i + ')">' + util_superscript('text', all_values[i]) + '</li>');
  html.push('</ul>');
  
  var filter_panel = $('#categories .filters');
  category_filters_back_buffer = filter_panel.html();
  filter_panel.html(html.join(' '));
  spinner_hide();
}

function category_filters_icon(filter) {
  return '<img class="property_icon" src="' + filter.icon_url + '" alt="' + filter.name + '" onclick="category_filters_configure(' + filter.id + ')" onmouseover="tooltip_show(event, ' + util_escape_attr_js(filter.name) + ')" onmouseout="tooltip_hide()" />';
}

function category_filters_show() {
  var filter_panel = $('#categories .filters');
  $.getJSON(category_filters_url('filters'), category_filters_show_handle);
  // spinner_show('Retrieving filters...'); // TODO: remove if we settle on always showing filters
}

function category_filters_show_handle(filters) {
  var filter_panel = $('#categories .filters');
  // spinner_hide(); // TODO: remove if we settle on always showing filters
  
  if(filters.length == 0) return;
  
  var filters_by_section = util_group_by(filters, 'section');
  
  var sections = [];
  for(var i in filters) {
    var section = filters[i].section;
    if(sections.length == 0 || (sections[sections.length - 1] != section)) sections.push(section);
  }
  
  var html = [];
  
  for(var i in sections) {
    var section = sections[i];
    html.push('<div class="section ' + (i % 2 ? 'even' : 'odd') + '">');
    html.push('<h3>' + section + '</h3>');
    
    var filters = filters_by_section[section];
    for(var j in filters) {
      var filter = filters[j];
      html.push('<div class="filter">');
      html.push(category_filters_icon(filter));
      html.push('</div>');
    }
    
    html.push('</div>')
  }
  
  html.push('<hr class="terminator" />');
  
  filter_panel.append(html.join(' '));
  filter_panel.fadeIn('fast');
}

function category_filters_url(intermediate_path, new_filter) {
  var loc = util_location_parts();
  
  var path = loc.path;
  if(intermediate_path) path += '/' + intermediate_path;
  
  var params = loc.params;
  if(new_filter) {
    var filtersJSON = params.filters;
    var filters = (filtersJSON ? JSON.parse(filtersJSON) : []);
    filters.push(new_filter);
    params.filters = JSON.stringify(filters);
  }
  
  var queryParts = [];
  for(var key in params) queryParts.push(encodeURIComponent(key) + '=' + encodeURIComponent(params[key]));
  if(queryParts.length > 0) path += '?' + queryParts.join('&');
  
  return path;
}

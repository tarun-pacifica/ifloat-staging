var category_filters_back_buffer = null;
function category_filters_back() {
  $('#categories .filters').html(category_filters_back_buffer);
}

var category_filters_choose_filter = null;
function category_filters_choose(index) {
  var filter = category_filters_choose_filter;
  var new_filter = [filter.id];
  
  if(filter.bucketed) {
    var values = filter.bucketed_values[index];
    new_filter.push(values[0][0], values[values.length - 1][0]);
  } else if(filter.type != 'text') {
    var value = filter.values[index][0];
    new_filter.push(value, value);
  } else {
    new_filter.push(filter.values[index][0]);
  }
  
  window.location = category_filters_url(null, new_filter);
}

function category_filters_configure(filter_id) {
  $.getJSON(category_filters_url('filter/' + filter_id), category_filters_configure_handle);
  spinner_show('Retrieving filter values...');
  tooltip_hide(); // needed by Firefox
}

function category_filters_configure_handle(filter) {
  spinner_hide();
  
  var values = filter.values;
  if(values.length == 0) {
    alert('The product catalogue has been updated so we need to refresh the page.');
    window.location.reload();
    return;
  }
  
  category_filters_choose_filter = filter;
  
  var max_choices = 6;
  if(filter.type != 'text' && values.length > max_choices) {
    var bucket_size = Math.ceil(values.length / max_choices);
    filter.bucketed = true;
    filter.bucketed_values = [];
    var b = 0, bucket = null;
    for(var i in values) {
      if(b == 0) filter.bucketed_values.push(bucket = []);
      bucket.push(values[i]);
      b = (b + 1) % bucket_size;
    }
  }
  
  var choice = (filter.bucketed ? 'range' : 'value');
  var html = ['<h2>Choose a ' + filter.name + ' ' + choice + '... <span onclick="category_filters_back()">« back to all filters</span></h2>'];
  
  category_filters_configure_handle_list(filter, html);
  html.push('<hr class="terminator" />');
  
  var filter_panel = $('#categories .filters');
  category_filters_back_buffer = filter_panel.html();
  filter_panel.html(html.join(' '));
}

function category_filters_configure_handle_list(filter, html) {
  var values = (filter.bucketed ? filter.bucketed_values : filter.values);
  
  html.push('<div class="choices">');
  
  html.push('<ul>');
  for(var i in values) {
    var v = values[i];
    
    var formatted = v[1];
    if(filter.bucketed) { formatted = v[0][1] + ' &mdash; ' + v[v.length - 1][1]; }
    else if(typeof(v[0]) == 'string') { formatted = util_superscript('text', util_defined(v[0], v[1])); }
    
    html.push('<li onclick="category_filters_choose(' + i + ')">' + formatted + '</li>');
  }
  html.push('</ul>');
  
  html.push('</div>');
}

function category_filters_icon(filter) {
  return '<img class="property_icon" src="' + filter.icon_url + '" alt="' + filter.name + '" onclick="category_filters_configure(' + filter.id + ')" onmouseover="tooltip_show(event, ' + util_escape_attr_js(filter.name) + ')" onmouseout="tooltip_hide()" />';
}

function category_filters_show() {
  var filter_panel = $('#categories .filters');
  $.getJSON(category_filters_url('filters'), category_filters_show_handle);
}

function category_filters_show_handle(filters) {
  if(filters.length == 0) return;
  
  var sections = [];
  for(var i in filters) {
    var section = filters[i].section;
    if(sections.length == 0 || (sections[sections.length - 1] != section)) sections.push(section);
  }
  
  var filters_by_section = util_group_by(filters, 'section');
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
  
  var filter_panel = $('#categories .filters');
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

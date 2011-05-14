var category_filters_back_buffer = null;
function category_filters_back() {
  $('#categories .filters').html(category_filters_back_buffer);
}

var category_filters_chosen = null;
var category_filters_choose_filter = null;
function category_filters_choose(step, index) {
  var filter = category_filters_choose_filter;
  var values = filter.values;
  
  if(filter.type == 'text') {
    window.location = category_filters_url(null, [filter.id, values[index][0]]);
    return;
  }
  
  var other_step = (step == 'from' ? 'to' : 'from');
  var other_index = category_filters_chosen[other_step];
  if(other_index && (step == 'from' ? other_index < index : other_index > index)) return;
  
  category_filters_chosen[step] = index;
  if(other_index == undefined && (step == 'from' ? index == values.length - 1 : index == 0)) category_filters_chosen[other_step] = index;
  
  var from = category_filters_chosen.from, to = category_filters_chosen.to;
  if(from != undefined && to != undefined) {
    window.location = category_filters_url(null, [filter.id, values[from][0], values[to][0]]);
    return;
  }
  
  var filters = $('#categories .filters');
  var choice_list_items = filters.find('.step_' + step + ' li');
  var other_list_items = filters.find('.step_' + other_step + ' li');
  
  choice_list_items.css('font-weight', 'normal');
  choice_list_items.eq(index).css('font-weight', 'bold');
  
  var item_lists = [choice_list_items, other_list_items];
  for(var i in item_lists) {
    var list = item_lists[i];
    list.css('opacity', '1.0');
    var strike_selector = (step == 'from' ? 'lt' : 'gt');
    list.filter(':' + strike_selector + '(' + index + ')').css('opacity', '0.5');
  }
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
  
  category_filters_chosen = {};
  category_filters_choose_filter = filter;
  
  var choice = (filter.type == 'text' ? 'value' : 'range');
  var html = ['<h2>Choose a ' + filter.name + ' ' + choice + '... <span onclick="category_filters_back()">« back to all filters</span></h2>'];
  
  var steps = (filter.type == 'text' ? [null] : ['from', 'to']);
  for(var i in steps) category_filters_configure_handle_list(values, steps[i], html);
  html.push('<hr class="terminator" />');
  
  var filter_panel = $('#categories .filters');
  category_filters_back_buffer = filter_panel.html();
  filter_panel.html(html.join(' '));
}

function category_filters_configure_handle_list(values, step, html) {
  html.push('<div class="choices step_' + step + '">');
  
  if(step) {
    html.push('<h3>' + step + '</h3>');
    step = util_escape_attr_js(step);
  }
  
  html.push('<ul>');
  for(var i in values) {
    var v = values[i];
    var formatted = util_superscript('text', (typeof(v[0]) == 'string' ? util_defined(v[0], v[1]) : v[1]));
    html.push('<li onclick="category_filters_choose(' + step + ', ' + i + ')">' + formatted + '</li>');
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

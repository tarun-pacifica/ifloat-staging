var category_filters_choose_values = null;
function category_filters_choose(index) {
  console.log(index, category_filters_choose_values[index]);
}

function category_filters_configure(filter_id) {
  console.log(window.location + '/filter/' + filter_id)
  $.getJSON(window.location + '/filter/' + filter_id + '?filters=', category_filters_configure_handle);
  spinner_show('Retrieving filter values...');
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
      category_filters_choose_values[i] = [v[0], unit, all_values[i]];
    }
  }
  
  if(all_values.length == 0) {
    alert('The product catalogue has been updated so we need to refresh the page.');
    window.location.reload();
    return;
  }
  
  var html = ['<h2>Choose a ' + filter.name + ' value...</h2>'];
  
  html.push('<ul>');
  for(var i in all_values) html.push('<li onclick="category_filters_choose(' + i + ')">' + util_superscript('text', all_values[i]) + '</li>');
  html.push('</ul>');
  
  var filter_panel = $('#categories .filters');
  filter_panel.html(html.join(' '));  
  spinner_hide();
}

function category_filters_icon(filter) {
  return '<img class="property_icon" src="' + filter.icon_url + '" alt="' + filter.name + '" onclick="category_filters_configure(' + filter.id + ')" onmouseover="tooltip_show(event, ' + util_escape_attr_js(filter.name) + ', \'above\')" onmouseout="tooltip_hide()" />';
}

function category_filters_show() {
  var filter_panel = $('#categories .filters');
  $.getJSON(window.location + '/filters?filters=', category_filters_show_handle);
  spinner_show('Retrieving filters...');
}

function category_filters_show_handle(filters) {
  var filter_panel = $('#categories .filters');
  
  if(filters.length == 0) {
    filter_panel.hide();
    return;
  }
  
  var filters_by_section = util_group_by(filters, 'section');
  
  var sections = [];
  for(var i in filters) {
    var section = filters[i].section;
    if(sections.length == 0 || (sections[sections.length - 1] != section)) sections.push(section);
  }
  
  var row_count = 0;
  var rows = [[]];
  for(var i in sections) {
    var section = sections[i];
    var section_count = Math.max(filters_by_section[section].length, 2);
    if(row_count + section_count <= 9) {
      rows[rows.length - 1].push(section);
      row_count += section_count;
    } else {
      rows.push([section]);
      row_count = section_count;
    }
  }
  
  var html = ['<h2>Choose a filter...</h2>'];
  for(var i in rows) {
    var row = rows[i];
    html.push('<div class="row ' + (i % 2 ? 'even' : 'odd') + '">');
    
    for(var j in row) {
      var section = row[j];
      html.push('<div class="section">');
      html.push('<h3>' + section + '</h3>');
      
      var filters = filters_by_section[section];
      for(var k in filters) {
        var filter = filters[k];
        html.push('<div class="filter">');
        html.push(category_filters_icon(filter));
        html.push('</div>');
      }
      
      html.push('</div>');
    }
    
    html.push('<hr class="terminator" />');
    html.push('</div>');
  }
  
  filter_panel.html(html.join(' '));
  filter_panel.fadeIn('fast');
  spinner_hide();
}

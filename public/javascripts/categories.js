function category_filters_show() {
  var filter_panel = $('#categories .filters');
  filter_panel.html('<img src="/images/common/spinner.gif" alt="spinner" />');
  filter_panel.fadeIn('fast');
  $.getJSON(window.location + '/filters?filters=', category_filters_show_handle);
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
        html.push(filter_panel_property_icon(filter, 'above'));
        html.push('</div>');
      }
      
      html.push('</div>');
    }
    
    html.push('<hr class="terminator" />');
    html.push('</div>');
  }
  
  filter_panel.html(html.join(' '));
}

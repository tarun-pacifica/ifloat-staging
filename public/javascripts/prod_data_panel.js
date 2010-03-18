function prod_data_panel_load(properties) {
	var html = [];
	var section = '';
	
	for(i in properties) {
		var property = properties[i];
		
		if(section != property.section) {
			if(i > 0) html.push('<hr class="terminator" />');
			html.push('<h3>' + property.section + '</h3>');
			section = property.section;
		}
		
		html.push('<table class="property">');
		html.push('<tr>');
		html.push('<td class="icon">');
		html.push(filter_panel_property_icon(property, '#'));
		html.push('</td>');
		
		var definitions = (property.definitions ? property.definitions : []);
		var values = property.values;
		var values_defined = [];
		for(i in values) values_defined.push(util_defined(values[i], definitions[i]));
		html.push('<td class="summary">' + values_defined.join('<br />') + '</td>');

		html.push('</tr>');
		html.push('</table>');
	}
	
	if(html.length > 0) html.push('<hr class="terminator" />');
	
	$('#prod_data_panel .sections').html(html.join(' '));
}

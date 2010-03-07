function filter_panel_add() {
	if($ifloat_body.filter_unused_count > 0) $('#filter_choose').dialog('open');
}

function filter_panel_choose_load_handle(filters) {
	$ifloat_body.filter_unused_count = filters.length;
	
	var filters_by_section = util_group_by(filters, 'section');
	
	var section_count_max = 2;
	for(section in filters_by_section) {
		var count = filters_by_section[section].length;
		if(count > section_count_max) section_count_max = count;
	}
	
	var sections = [];
	for(i in filters) {
		var section = filters[i].section;
		if(sections.length == 0 || (sections[sections.length -1] != section)) sections.push(section);
	}
	
	var row_count = 0;
	var rows = [[]];
	for(i in sections) {
		var section = sections[i];
		var section_count = filters_by_section[section].length;
		if(row_count + section_count < section_count_max) {
			rows[rows.length - 1].push(section);
			row_count += section_count;
		} else {
			rows.push([section]);
			row_count = section_count;
		}
	}
		
	var html = [];	
	for(i in rows) {
		var row = rows[i];
		html.push('<div class="row ' + (i % 2 ? "even" : "odd") + '">');
		
		for(j in row) {
			var section = row[j];
			html.push('<div class="section">');
			html.push('<h3>' + section + '</h3>');
			
			var filters = filters_by_section[section];
			for(k in filters) {
				var filter = filters[k];
				html.push('<div class="filter">');
				html.push(filter_panel_property_icon(filter, 'filter_panel_choose', 'above'));
				// html.push('<p>' + filter.name + '</p>');
				html.push('</div>');
			}
			
			html.push('</div>');
		}
		
		html.push('<hr class="terminator" />');
		html.push('</div>');
	}
	
	var filter_choose = $('#filter_choose');
	if(! $ifloat_body.filter_choose_created) {
		filter_choose.dialog({autoOpen: false, modal: true});
		$ifloat_body.filter_choose_created = true
	}
	filter_choose.data('width.dialog', section_count_max * 78);
	filter_choose.html(html.join(' '));
}

function filter_panel_choose_section_focus(event) {
	$(event.target).find('.filter').show();
}

function filter_panel_choose_section_unfocus(event) {
	$(event.target).find('.filter').hide();
}

function filter_panel_load() {
	$.getJSON('/cached_finds/' + $ifloat_body.find_id + '/filters/used', filter_panel_load_handle);
	$.getJSON('/cached_finds/' + $ifloat_body.find_id + '/filters/unused', filter_panel_choose_load_handle);
}

function filter_panel_load_handle(filters) {
	var html = [];
	var section = '';
	
	for(i in filters) {
		var filter = filters[i];
		
		if(section != filter.section) {
			html.push('<h3>' + filter.section + '</h3>');
			section = filter.section;
		}
		
		html.push('<table class="filter">');
		html.push('<tr>');
		html.push('<td class="icon">');
		html.push(filter_panel_property_icon(filter, 'filter_panel_edit'));
		html.push('</td>');
		html.push('<td class="summary">' + filter.summary + '</td>');
		html.push('<td><div class="remove" onclick="filter_panel_remove(' + filter.id + ')"></div></td>');
		html.push('</tr>');
		html.push('</table>');
	}
	
	$('#filter_panel .sections').html(html.length == 0 ? '&nbsp;' : html.join(' '));
}

function filter_panel_property_icon(filter, onclick, tooltip_position) {
	if(tooltip_position == undefined) tooltip_position = 'above';
	return '<img class="property_icon" src="' + filter.icon_url + '" onclick="' + onclick + '(' + filter.id + ')" onmouseover="tooltip_show(event, \'' + filter.name + '\', \'' + tooltip_position + '\')" onmouseout="tooltip_hide()" />';
}

// vvv LEGACY CODE vvv

// Date Filter

function date_filter_create(data, html) {
	html.push('<table>');
	num_filter_create_min_max("min", "from", false, html);
	num_filter_create_min_max("max", "to", false, html);
	html.push('</table>');
}

// Filter (Common)

function filter_create(info) {
	var html = [];
	var dom_id = "filter_" + info.prop_id;
	
	filter_create_summary(dom_id, info.icon_url, info.domain_class, info.prop_friendly_name[1], html);
	
	var subclass = info.prop_type + "_filter";
	html.push('<tr id="' + dom_id + '" class="filter ' + info.prop_type + '_filter">');
	
	filter_create_unknown_checkbox(info.include_unknown, html);
	
	var data = info.data;
	if (info.prop_type == "text") text_filter_create(data, html);
	else if(info.prop_type == "numeric") num_filter_create(data, html);
	else if(info.prop_type == "date") date_filter_create(data, html);
	else if(info.prop_type == "currency") num_filter_create(data, html);
	
	html.push('</tr>');
	
	var attributes = {};
	
	if (info.prop_type != "text") {
		attributes.limit_count = 0;
		attributes.limits = data.limits;
		attributes.unit = data.chosen[2];
		attributes.values = {};
		
		for(unit in data.limits) {
			var min = data.chosen[0];
			var max = data.chosen[1];
			
			if (unit != attributes.unit) {
				min = util_convert(min, attributes.unit, unit);
				max = util_convert(max, attributes.unit, unit);
			}
			
			attributes.values[unit] = [min, max];
			attributes.limit_count += 1;
		}		
	}
	
	return [html.join(" "), attributes];
}

function filter_create_summary(dom_id, icon_url, domain_class, name, html) {
	html.push('<tr id="' + dom_id + '_summary" class="filter_summary ' + domain_class + '">');
	
	html.push('<td>');
	html.push('<img class="icon" src="' + icon_url + '" onclick="$(\'#' + dom_id + '\').toggle()" onmouseover="tooltip_show(event, \'' + name + '\')" onmouseout="tooltip_hide()"/>');
	html.push('</td>');
	
	html.push('<td>');
	html.push('<div class="summary" onclick="$(\'#' + dom_id + '\').toggle()"> </div>');
	html.push('</td>');
	
	html.push('</tr>');
}

function filter_create_unknown_checkbox(include_unknown, html) {
	html.push('<td colspan="2">');
	html.push('<div class="unknown_item">');
	var checked = (include_unknown ? 'checked="checked"' : '');
	html.push('<input type="checkbox" ' + checked + ' onclick="filter_handle_check(this)" />');
	html.push('Show products with no value');
	html.push('</div>');
}

function filter_load_all(find_id) {
	$.getJSON("/cached_finds/" + find_id + "/filters", filter_load_all_handle);
}

function filter_load_all_handle(filters) {
	if(filters == "reset") {
		window.location.reload();
		return;
	}

	var filter_table = $("#cached_find_filters table");
	var domains = [];
	var relevant_ids = [];
	
	for(i in filters) {
		var info = filters[i];
		if(info.relevant) relevant_ids.push(info.prop_id);
		
		var domain = info.prop_friendly_name[0];
		if(domains[domains.length - 1] != domain) {
			domains.push(domain);
			filter_table.append('<tr id="' + domains.length + '" class="filter_section"> <th colspan="3">' + domain + '</th> </tr>');
		}
		info.domain_class = "domain_" + domains.length;
		
		var html_attribs = filter_create(info);
		filter_table.append(html_attribs[0]);
		
		var filter = $("#cached_find_filters .filter:last");
		var f = filter[0];
		
		var attributes = html_attribs[1];
		for(key in attributes) f[key] = attributes[key];
		
		if(info.prop_type == "text") {
			text_filter_update_summary(filter);
		} else {
			num_filter_update_context_and_summary(filter);
			num_filter_update_min_max(filter);
		}
	}
	
	filter_show_only(relevant_ids);	
}

// Filter Queue - TODO this queue can now be essentially blocking ('apply' should block until an update is received - we now have a predictable state machine)

function filter_handle_check(checkbox) {
	var property_id = $(checkbox).parents(".filter")[0].id.match(/^filter_(\d+)$/)[1];
	var url = "/cached_finds/" + $("#cached_find_results")[0].find_id + "/filter/" + property_id;
	filter_queue_add(url, {operation: "include_unknown", value: checkbox.checked});
}

function filter_queue_add(url, data) {
	var results = $("#cached_find_results");
	var r = results[0];
	r.filter_queue.push({url: url, data: data})
	filter_queue_execute(results);
}

function filter_queue_execute(results) {
	var r = results[0];
	if(r.filter_queue_active > -1) return;
	
	var queue = r.filter_queue;
	if(queue.length == 0) return;
	r.filter_queue_active = queue.length;
	
	for(i in queue) {
		var q = queue[i];
		$.post(q.url, q.data, filter_queue_execute_handle, "json");
	}
	r.filter_queue = []
}

function filter_queue_execute_handle(text_values_by_relevant_filter_ids) {
	if(text_values_by_relevant_filter_ids == "reset") {
		window.location.reload();
		return;
	}
	
	var results = $("#cached_find_results");
	var r = results[0];
	r.filter_queue_active -= 1;
	if(r.filter_queue_active == 0) prod_grid_update(results);
	
	var relevant_filter_ids = [];
	for(filter_id in text_values_by_relevant_filter_ids) relevant_filter_ids.push(filter_id);
	filter_show_only(relevant_filter_ids);
	text_filter_mark_relevant(text_values_by_relevant_filter_ids);
}

function filter_show_only(filter_ids) {
	var filters_to_hide = $(".filter");
	var summaries_to_hide = $(".filter_summary");
	
	for(i in filter_ids) {
		var filter_id = "#filter_" + filter_ids[i];
		var summary_id = filter_id + "_summary";
		filters_to_hide = filters_to_hide.not(filter_id);
		summaries_to_hide = summaries_to_hide.not(summary_id);
		$(summary_id).show();
	}
	
	filters_to_hide.hide();
	summaries_to_hide.hide();
	
	$(".filter_section").each(function (i) {
		var section = $(this);
		var all_hidden = ($(".domain_" + this.id + ":visible").length == 0);
		if(all_hidden) section.hide();
		else section.show();
	});
}

// Numeric Filters

function num_filter_choose(filter) {
	var f = filter[0];
	var property_id = f.id.match(/^filter_(\d+)$/)[1];
	var url = "/cached_finds/" + $("#cached_find_results")[0].find_id + "/filter/" + property_id;
	var values = f.values[f.unit];
	filter_queue_add(url, {operation: "choose", min: values[0], max: values[1], unit: f.unit});
}

function num_filter_create(data, html) {
	html.push('<table>');
	
	num_filter_create_min_max("min", "min", true, html);
	num_filter_create_min_max("max", "max", true, html);
	
	var chosen_unit = data.chosen[2];
	var limits = data.limits;
	
	if(limits[""] == undefined) {
		html.push('<tr>');
		html.push('<td class="label">unit</td>');
		html.push('<td>');
		html.push('<select class="unit" onchange="num_filter_handle_select(this)">');
		for(unit in limits) {
			var selected = (unit == chosen_unit ? 'selected="selected"' : '');
			html.push('<option ' + selected + '>' + unit + '</option>');
		}
		html.push('</select>');
		html.push('</td>');
		html.push('</tr>');
	}

	html.push('</table>');
}

function num_filter_create_min_max(min_max, label, fraction_helper, html) {
	html.push('<tr>');
	html.push('<td class="label">' + label + '</td>');
	html.push('<td>');
	if(fraction_helper) html.push('<img class="fraction_helper" src="/images/filters/buttons/fraction_helper.png" onclick="fraction_helper_open(this)" />');
	html.push('<input class="' + min_max + '" type="text" onkeyup="num_filter_handle_input(this)" />');
	html.push('(' + (min_max == "min" ? "&ge;" : "&le;") + ' <span class="' + min_max + '_all"> </span>)');
	html.push('</td>');
	html.push('</tr>');
}

function num_filter_handle_input(i) {
	var input = $(i);
	var filter = input.parents(".filter");
	var f = filter[0];
	
	var value = input.val();
	var values = f.values[f.unit];
	var i = (input.hasClass("min") ? 0 : 1);
	var updated = false;
	
	if(filter.hasClass("date_filter")) {
		if(value.length >= 4) {
			value = value.substr(0, 4);
			input.val(value);
		}		
		var year = parseInt(value);
		if(!isNaN(year) && year >= 1000 && year <= 2500 && values[i] != year * 10000) {
			values[i] = year * 10000;
			updated = true;
		}
	} else {
		if(value == "" || value == ".") {
			values[i] = 0;
			updated = true;
		} else if(value.match(/^\d*(\.\d*)?$/)) {
			values[i] = parseFloat(value);
			updated = true;
		} else {
			input.val(values[i]);
		}
	}
	
	if(updated) {
		for(unit in f.values) {
			if(unit == f.unit) continue;
			var unit_values = f.values[unit];

			for(i in values) {
				var v = values[i];
				unit_values[i] = util_convert(v, f.unit, unit);
			}
		}
		
		num_filter_choose(filter);
	}
	
	num_filter_update_context_and_summary(filter);
}

function num_filter_handle_select(s) {
	var select = $(s);
	var filter = select.parents(".filter");

	filter[0].unit = select.val();
		
	num_filter_choose(filter);
	num_filter_update_context_and_summary(filter);
	num_filter_update_min_max(filter);
}

function num_filter_update_context_and_summary(filter) {
	var f = filter[0];
	var date_filter = filter.hasClass("date_filter");
	var summaries = [];
	
	for(unit in f.values) {
		var summary = util_format_number(f.values[unit], unit, date_filter);
		if (f.limit_count > 1 && unit == f.unit) summary = "<strong>" + summary + "</strong>";		
		summaries.push(summary);
	}
	
	filter.prev().find(".summary").html(summaries.join(" <br /> "));
	
	var limits = f.limits[f.unit];
	filter.find(".min_all").text(util_format_number([limits[0]], "", date_filter));
	filter.find(".max_all").text(util_format_number([limits[1]], "", date_filter));
}

function num_filter_update_min_max(filter) {
	var f = filter[0];
	var values = f.values[f.unit];
	if(filter.hasClass("date_filter")) values = [values[0] / 10000, values[1] / 10000];
	filter.find("input.min").val(values[0]);
	filter.find("input.max").val(values[1]);
}

// Text Filters

function text_filter_create(data, html) {
	var all = data.all;
	var definitions = data.definitions;
	var excluded = util_hash_from_array(data.excluded, true);
	var relevant = util_hash_from_array(data.relevant == "all" ? all : data.relevant, true);
	
	for(i in all) {
		var value = all[i];
		
		var style = (relevant[value] ? '' : 'style="text-decoration:line-through;color:gray"');
		html.push('<div class="list_item" ' + style + '>');
		
		html.push('<img class="select_one" src="/images/filters/buttons/select_one.png" onclick="text_filter_select_one(this)"/>');
		
		var checked = (excluded[value] ? '' : 'checked="checked"');
		html.push('<input type="checkbox" ' + checked + ' value="' + value + '" onclick="text_filter_handle_check(this)" />');
		
		var definition = definitions[value];
		if(definition == null) {
			html.push(value);
		} else {
			definition = definition.replace("'", "\\'").replace('"', '\\"');
			html.push('<span class="defined" onmouseover="tooltip_show(event, \'' + definition + '\', \'right\')" onmouseout="tooltip_hide()">' + value + '</span>');
		}
		
		html.push('</div>');
	}
}

function text_filter_handle_check(checkbox, select_one) {
	var filter = $(checkbox).parents(".filter");
	var property_id = filter[0].id.match(/^filter_(\d+)$/)[1];
	
	var url = "/cached_finds/" + $("#cached_find_results")[0].find_id + "/filter/" + property_id;
	var operation = (select_one ? "include_only" : (checkbox.checked ? "include" : "exclude"));
	
	filter_queue_add(url, {operation: operation, value: checkbox.value});
	text_filter_update_summary(filter);
}

function text_filter_mark_relevant(text_values_by_relevant_filter_ids) {
	for(filter_id in text_values_by_relevant_filter_ids) {
		var values = text_values_by_relevant_filter_ids[filter_id];
		if(values == null) continue;
		
		var value_lookup = util_hash_from_array(values, true);
		
		var filter = $("#filter_" + filter_id);
		filter.find(".list_item input:checkbox").each(function (i) {
			var list_item = $(this).parent();
			if(value_lookup[this.value]) list_item.css("text-decoration", "none").css("color", "black");
			else list_item.css("text-decoration", "line-through").css("color", "gray");
		});
		
		text_filter_update_summary(filter);
	}
}

function text_filter_select_one(image) {	
	var checkbox = $(image).next("input:checkbox");
	checkbox.parents(".filter").find(".list_item input:checkbox:checked").not(checkbox).attr("checked", false);
	checkbox.not(":checked").attr("checked", true);
	text_filter_handle_check(checkbox[0], true);
}

// function text_filter_update_summary(filter) {
// 	var list = filter.find(".list_item input:checkbox").map(function() {
// 		var relevant = ($(this).parent().css("text-decoration") == "none");
// 		if(this.checked && relevant) return this.value;
// 		else return undefined;
// 	});
// 	if(list.length == 0) list.push("[none]");
// 	var summary = list.get().join(", ");
// 	if(summary.length > 50) summary = summary.substr(0, 46) + "...";
// 	filter.prev().find(".summary").text(summary);
// }

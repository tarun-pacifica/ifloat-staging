// Articles

function article_edit(a) {
	var article = $(a).parents(".article");
	article.children().hide();
	
	var form = article.children("form");
	form.show();
	form.animate({backgroundColor: "#FCBB1A"}).animate({backgroundColor: "#F3F3F3"});
	form.animate({backgroundColor: "#FCBB1A"}).animate({backgroundColor: "#F3F3F3"});
	
	$(document).scrollTop(form.offset().top);
}

// Bubble Tooltip

function bubble_tooltip_show(event, text) {
	var bubble = $("#bubble_tooltip");
	bubble.find("p").text(text);
	
	var target = $(event.target);
	var position = target.position();
	bubble.css("left", position.left + target.width() + 3 + "px");
	bubble.css("top", position.top + ((target.height() - bubble.height()) / 2) + 2 + "px");
	bubble.css("display", "block");
}	

function bubble_tooltip_hide() {
	$("#bubble_tooltip").css("display", "none");
}

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
	
	if (info.prop_type == "text") text_filter_create(info.data, html);
	else if(info.prop_type == "numeric") num_filter_create(info.data, html);
	else if(info.prop_type == "date") date_filter_create(info.data, html);
	else if(info.prop_type == "currency") num_filter_create(info.data, html);
	
	html.push('</tr>');
	
	// TODO: implement for all numeric/currency filters
	// f.unit = <%= @unit.to_s.inspect %>;
	// 
	// f.limits = {};
	// f.values = {};
	// <% @limits.each do |unit, min_max| %>
	// <% cmin, cmax = @min.to_f, @max.to_f %>
	// <% cmin, cmax = [cmin, cmax].map { |v| Conversion.convert(v, @unit, unit) } unless unit == @unit %>
	// <% unit = unit.to_s.inspect %>
	// f.limits[<%= unit %>] = <%= [min_max.first.to_f, min_max.last.to_f].inspect %>;
	// f.values[<%= unit %>] = <%= [cmin, cmax].inspect %>;
	// <% end %>
	// f.unit_count = <%= @limits.size %>;	
	// 
	// num_filter_update_context_and_summary(filter);
	// num_filter_update_min_max(filter);
	// 
	// <% unless @unit.nil? %>
	// filter.find("select.unit").val(f.unit);
	// <% end %>
	
	return html.join(" ");
}

function filter_create_summary(dom_id, icon_url, domain_class, name, html) {
	html.push('<tr id="' + dom_id + '_summary" class="filter_summary ' + domain_class + '">');
	
	html.push('<td>');
	html.push('<img class="icon" src="' + icon_url + '" onclick="$(\'#' + dom_id + '\').toggle()" onmouseover="bubble_tooltip_show(event, \'' + name + '\')" onmouseout="bubble_tooltip_hide()"/>');
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
	
	for(i in filters) {
		var filter = filters[i];
		
		var domain = filter.prop_friendly_name[0];
		if(domains[domains.length - 1] != domain) {
			domains.push(domain);
			filter_table.append('<tr id="' + domains.length + '" class="filter_section"> <th colspan="3">' + domain + '</th> </tr>');
		}
		filter.domain_class = "domain_" + domains.length;
				
		filter_table.append(filter_create(filter));
	}
	
	$("#cached_find_filters .text_filter").each(function(i) { text_filter_update_summary($(this)); });
	$("#cached_find_filters .filter").not(".text_filter").each(function(i) {
		// TODO: check whether this is the most efficient way to go about this
		var filter = $(this);
		num_filter_update_context_and_summary(filter);
		num_filter_update_min_max(filter);
	});
	
	// TODO: re-activate / replace
	// filter_show_only(<%= @relevant_filters.keys.inspect %>);
	// text_filter_mark_relevant(<%= @relevant_filters.to_json %>);
}

// Filter Queue

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

// Finder

function finder_recall(s) {
	var specification = $("#cached_find_specification");
	specification.val(s.value);
	specification.siblings("#submit").click();
}

function finder_validate() {
	var specification = $("#cached_find_specification").val();

	if(specification == "") {
		alert("Please supply one or more words to find.")
		return false;
	}

	var atoms = specification.split(" ");

	for(i in atoms) {
		var atom = atoms[i];
		if(atom == "" || atom.length >= 3) continue;
		alert("Please make sure that all the words you've supplied are at least 3 characters long.");
		return false;
	}

	return true;
}

// Fraction Helper

function fraction_helper_detect_nearest_po2_fraction(value) {
	var nearest_64th = Math.round(value * 64) / 64;
	
	var remainder = nearest_64th % 1;
	if(remainder == 0) return {integer: parseInt(value), numerator: 0, denominator: 2, value: nearest_64th};
	
	for(i = 1; i <= 6; i ++) {
		var d = Math.pow(2, i);
		var n = remainder * d;
		if(n % 1 == 0) return {integer: parseInt(value), numerator: n, denominator: d, value: nearest_64th};
	}
	
	// We should _never_ get here
	alert("unable to detect nearest po2 fraction for " + value + " (nearest_64th: " + nearest_64th + ")");
	return {integer: undefined, numerator: undefined, denominator: undefined, value: nearest_64th};
}

function fraction_helper_format(value) {
	var fraction = fraction_helper_detect_nearest_po2_fraction(value);
	var result = value;
	
	if(value == fraction.value) {
		var parts = [];
		if(fraction.integer > 0) parts.push(fraction.integer);
		if(fraction.numerator > 0) parts.push(fraction.numerator + "/" + fraction.denominator);
		result = (parts.length > 0 ? parts.join(" ") : 0);
	} else {
		result = Math.round(value * 1000) / 1000;
	}
	
	return result;
}

function fraction_helper_handle_input(i) {
	var input = $(i);
 	var value = parseInt(input.val());
	input.val(isNaN(value) ? "" : value);
	fraction_helper_update_preview();
}

function fraction_helper_handle_select(s, num_value) {
	var select = $(s);
	
	if(select.hasClass("denominator")) {	
		var numerator = select.siblings(".numerator");
		var denominator = parseInt(select.val());
		
		if(num_value == undefined) num_value = Math.min(numerator.val(), denominator - 1);
		
		var options = [];
		for(n = 0; n < denominator; n++) {
			if(n == num_value) options.push('<option selected="selected">' + n + "</option>");
			else options.push("<option>" + n + "</option>");
		}
		numerator.html(options.join(" "));
	}
	
	fraction_helper_update_preview();
}

function fraction_helper_open(i) {
	var image = $(i);
	
	var fraction_helper = $("#fraction_helper");
	fraction_helper.dialog("open");
	
	var f = fraction_helper[0];
	f.input = image.next("input");
	f.input.css("background", "yellow");
	
	var filter = f.input.parents(".filter")[0];
	var values = filter.values[filter.unit];
	var value = values[(f.input.hasClass("min") ? 0 : 1)]
	value = fraction_helper_detect_nearest_po2_fraction(value);
	fraction_helper.find(".integer").val(value.integer);
	
	var denominator = fraction_helper.find(".denominator");
	denominator.val(value.denominator);
	fraction_helper_handle_select(denominator[0], value.numerator);
}

function fraction_helper_paste_value() {
	var fraction_helper = $(this);
	var value = parseFloat(fraction_helper.find("p.preview").text());
	fraction_helper.dialog("close");
	
	var input = fraction_helper[0].input;
	input.val(value);
	num_filter_handle_input(input[0]);
}

function fraction_helper_update_preview() {
	var fraction_helper = $("#fraction_helper");
	var i = parseFloat(fraction_helper.find(".integer").val());
	var n = parseFloat(fraction_helper.find(".numerator").val());
	var d = parseFloat(fraction_helper.find(".denominator").val());
	fraction_helper.find("p.preview").text((isNaN(i) ? 0 : i) + n / d);
}

// Future Purchase Options

function future_purchase_opts_load(product_ids) {
	var url = "/products/batch/" + product_ids.join("_");
	$.get(url, future_purchase_opts_load_handle, "html");	
}

function future_purchase_opts_load_handle(data) {
	var fp_opts = $("#future_purchase_options");
	var fp_opts_tmp = $("#future_purchase_options_tmp");
	fp_opts_tmp.html(data);
	
	fp_opts_tmp.children("a").each(
		function (i, a) { fp_opts.find("#" + a.id).append(a); }
	);
	
	fp_opts_tmp.empty();	
}

function future_purchase_opts_move(purchase_id) {
	var options = {type: "POST", url: "/future_purchases/" + purchase_id};
	options.data = {_method: "PUT"};
	options.success = function() { window.location.reload(); };
	options.error = purchase_list_add_move_error;
	$.ajax(options);
}

// Images

function image_preload(url) {
	(new Image()).src = url;
}

// Login / Logout

function login_error(request) {
	var login_register = $("#login_register");
	login_register.find("form .errors").remove();
	
	var operation = login_register[0].operation;
	var form = login_register.find(operation == "register" ? "form.register" : "form.login");
	form.append(request.responseText);
}

function login_open(message) {
	var login_register = $("#login_register");
	message = (message ? message : "");
	login_register.find(".message").text(message);
	login_register.dialog("open");
}

function login_operation(operation) {
	$("#login_register")[0].operation = operation;
}

function login_reset() {
	var forms = $("#login_register").find("form");
	forms.each( function() { this.reset(); } );
	forms.find(".errors").remove();
}

function login_submit(f) {
	var options = {type: "POST", url: f.action, success: login_success, error: login_error, data: {}};
	
	var inputs = $(f).find("input:not(:submit)");
	for(i in inputs) {
		var input = inputs[i];
		options.data[input.name] = input.value;
	}
	options.data.submit = ($("#login_register")[0].operation == "reset" ? "Reset Password" : "");
	
	$.ajax(options);
	
	return false;
}

function login_success(data) {
	var login_register = $("#login_register");
	login_register.html(data);
	window.location.reload();
}

function logout() {
	$.get("/users/logout", logout_success);
}

function logout_success(data) {
	window.location = "/";
}

// Number formatters

// TODO: review as possibly redundant (if the filtering controls for dates end up not using input boxes)
function date_format(value) {
	var yyyy_mm_dd = String(value).match(/^(\d{4})(\d\d)(\d\d)$/);
	if(yyyy_mm_dd == null) return value;
	
	var parts = [];
	for(i in yyyy_mm_dd) {
		var v = yyyy_mm_dd[i];
		if(i > 0 && v > 0) parts.push(v);
	}
	return parts.join("-");
}

function number_format(values, unit, date) {
	if(values.length == 0) return "";
	
	var formatted_values = [];
	for(i in values) {
		var v = values[i];
		if(v) formatted_values.push(date ? date_format(v) : fraction_helper_format(v));
	}
	
	var result = formatted_values.join("&ndash;");
	if(unit) result += " " + unit;
	return result;
}

// Numeric Filters

function num_filter_choose(filter) {
	var f = filter[0];
	var url = "/cached_finds/" + f.find_id + "/filter/" + f.property_id;
	var values = f.values[f.unit];
	filter_queue_add(url, {operation: "choose", min: values[0], max: values[1], unit: f.unit});
}

function num_filter_create(data, html) {
	html.push('<table>');
	
	num_filter_create_min_max("min", "min", true, html);
	num_filter_create_min_max("max", "max", true, html);
	
	if(data[null] == undefined) {
		html.push('<tr>');
		html.push('<td class="label">unit</td>');
		html.push('<td>');
		html.push('<select class="unit" onchange="num_filter_handle_select(this)">');
		for(unit in data) html.push('<option>' + unit + '</option>');
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
	if(fraction_helper) html.push('<img class="fraction_helper" src="/images/buttons/fraction_helper.png" onclick="fraction_helper_open(this)" />');
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
				unit_values[i] = num_filter_convert(v, f.unit, unit);
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
		var summary = number_format(f.values[unit], unit, date_filter);
		if (f.unit_count > 1 && unit == f.unit) summary = "<strong>" + summary + "</strong>";		
		summaries.push(summary);
	}
	
	filter.prev().find(".summary").html(summaries.join(" <br /> "));
	
	var limits = f.limits[f.unit];
	filter.find(".min_all").text(number_format([limits[0]], "", date_filter));
	filter.find(".max_all").text(number_format([limits[1]], "", date_filter));
}

function num_filter_update_min_max(filter) {
	var f = filter[0];
	var values = f.values[f.unit];
	if(filter.hasClass("date_filter")) values = [values[0] / 10000, values[1] / 10000];
	filter.find("input.min").val(values[0]);
	filter.find("input.max").val(values[1]);
}

// Product Detail

function prod_detail_select_image(event) {	
	$("#product_detail_assets").find("img.main")[0].src = event.target.src;
}

function prod_detail_update_purchase_buttons(product_id) {
	$.get("/products/" + product_id + "/purchase_buttons", prod_detail_update_purchase_buttons_handle, "html");
}

function prod_detail_update_purchase_buttons_handle(data) {
	var assets = $("#product_detail_assets .asset_links");
	assets.find(".add").remove();
	assets.append(data);
}

// Product Grid

function prod_grid_update(results) {
	var url = "/cached_finds/" + results[0].find_id + "/found_images/36"
	$.getJSON(url, prod_grid_update_handle);
}

function prod_grid_update_handle(images) {
	var image_prod_count = 0;
	var total_prod_count = images.shift();
	var image_count = images.length;
	
	var results = $("#cached_find_results");
	var r = results[0];
	
	results.find(".product").remove();
	var insertion_point = results.find("hr.result_terminator");
	
	var small_urls = [];
	for(i in images) {
		var image_data = images[i];
		
		var checksum = image_data[0];
		var count = image_data[1];
		var small_url = image_data[2];
		var tiny_url = image_data[3];
		
		image_prod_count += count;
		small_urls.push(small_url);
		
		var link_url = "/cached_finds/" + r.find_id + '/found_products_for_checksum/' + checksum;
		var count_overlay = '<div class="count">' + count + ' item' + (count > 1 ? "s" : "") + '</div>';
		
		var prod_html = '<a class="product" href="' + link_url + '"> ' + count_overlay + '<img src="' + tiny_url + '" onmouseover="prod_image_zoom(event, \'' + small_url + '\')" onmouseout="prod_image_unzoom(this)" /> </a>';
		insertion_point.before(prod_html);
	}
	
	for(i in small_urls) image_preload(small_urls[i]);
	
	$("#cached_find_report .displayed_count").text(image_prod_count);
	$("#cached_find_report .filtered_count").text(total_prod_count);
	
	r.filter_queue_active = -1;
	filter_queue_execute(results);
}

// Product Images

function prod_image_zoom(event, image_url) {
	var zoom = $("#image_zoom");
	zoom[0].src = image_url ? image_url : event.target.src;
	
	var image = $(event.target)
	var position = image.offset();
	image.css("border-color", "black");
	zoom.css("left", position.left - 10 - zoom.width() + "px");
	zoom.css("top", position.top + (image.height() - zoom.height()) / 2 + "px");
	zoom.css("display", "block");
}

function prod_image_unzoom(i) {
	$(i).css("border-color", "gray");
	$("#image_zoom").css("display", "none");
}

// Purchase Lists

function purchase_list_add(future, product_id) {
	purchase_list_add_move(future, product_id);
	purchase_list_blink(future);
}

function purchase_list_add_move(future, product_id, purchase_id) {
	var options = {type: "POST", success: purchase_list_update, error: purchase_list_add_move_error};
	
	if(purchase_id) {
		options.url = "/future_purchases/" + purchase_id;
		options.data = {_method: "PUT"};
	} else {
		options.url = "/future_purchases"
		options.data = {product_id: product_id, deferred: future};
	}
	
	$.ajax(options);
}

function purchase_list_add_move_error(request) {
	if(request.status == 401) login_open("Please login / register to use the future buys list...");
}

function purchase_list_blink(future) {
	var spans = $(future ? "#future_purchases" : "#shopping_list").find("span");
	spans.animate({color:"#FCBB1A"}).animate({color:"white"});
	spans.animate({color:"#FCBB1A"}).animate({color:"white"});
}

function purchase_list_hover(p) {
	var list = $(p);
	if(list.find(".total").text() == "") return;
	list.css("background-image", "url(/images/buttons/hover.png)");
	list.find("a").show();
}

function purchase_list_move(purchase_id) {
	purchase_list_add_move(undefined, undefined, purchase_id);
	purchase_list_blink(false);
	purchase_list_blink(true);
}

function purchase_list_remove(future, purchase_id) {
	$.get("/future_purchases/" + purchase_id + "/delete", purchase_list_update);
	purchase_list_blink(future);
}

function purchase_list_unhover(p) {
	var list = $(p);
	list.css("background-image", "url(/images/buttons/enabled.png)");
	list.find("a").hide();
}

function purchase_list_update() {
	$.get("/future_purchases", purchase_list_update_handle, "html");
}

function purchase_list_update_handle(data) {
	var shopping_list = $("#shopping_list");
	var future_purchases = $("#future_purchases");
	shopping_list.find("a").remove();
	future_purchases.find("a").remove();
	
	var purchases_tmp = $("#future_purchases_tmp");
	purchases_tmp.html(data);
	
	purchases_tmp.find("a.now").appendTo(shopping_list);
	shopping_list.append('<a class="buy" href="/future_purchases/buy_options">Buy from...</a>');
	purchases_tmp.find("a.future").appendTo(future_purchases);
	
	var list_length = shopping_list.find("a").hide().length - 1;
	shopping_list.find(".total").text(list_length == 0 ? "" : list_length);
	list_length = future_purchases.find("a").hide().length;
	future_purchases.find(".total").text(list_length == 0 ? "" : list_length);
	
	purchases_tmp.empty();
	
	var product_detail = $("#product_detail");
	if(product_detail.length > 0) {
		prod_detail_update_purchase_buttons(product_detail[0].product_id);
	}
}

// Relationship Product Listings (Product Detail View)

function relationship_list_build(product_ids_by_section) {
	var product_ids = [];
	for(var section in product_ids_by_section) {
		product_ids = product_ids.concat(product_ids_by_section[section]);
	}
	
	var url = "/products/batch/" + product_ids.join("_");
	$.get(url, relationship_list_handle_batch, "html");
}

function relationship_list_handle_batch(data) {
	var relations_tmp = $("#product_detail_relations_tmp");
	relations_tmp.html(data);
	
	var relations = $("#product_detail_relations");
	var r = relations[0];
	var pibs = r.product_ids_by_section;
	var shown = r.initially_shown_per_section;
	
	for(var section in pibs) {
		var section_id = "section_" + section.replace(/ /g, "_");
		relations.append('<div id="' + section_id + '"> </div>');
		var section_div = relations.find("#" + section_id);
		
		section_div.append("<h2>" + section + "...</h2>");
		
		var product_ids = pibs[section];
		for(var i in product_ids) {
			var cloned_list_item = relations_tmp.find("#prod_" + product_ids[i]).clone();
			cloned_list_item.appendTo(section_div);
			if(i >= shown) cloned_list_item.hide();
		}
		
		var hidden = (product_ids.length - shown);
		if(hidden > 0) section_div.append('<div class="more"> <div onclick="relationship_list_more(this)">' + hidden + ' More Results</div> </div>');
	}
	
	relations_tmp.empty();
}

function relationship_list_more(d) {
	var more_bar = $(d).parent();
	more_bar.prevAll().show();
	more_bar.hide();
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
		
		html.push('<img class="select_one" src="/images/buttons/select_one.png" onclick="text_filter_select_one(this)"/>');
		
		var checked = (excluded[value] ? '' : 'checked="checked"');
		html.push('<input type="checkbox" ' + checked + ' value="' + value + '" onclick="text_filter_handle_check(this)" />');
		
		var definition = data[value];
		if(definition == null) html.push(value);
		else html.push('<span class="defined" onmouseover="bubble_tooltip_show(event, \'' + definition + '\')" onmouseout="bubble_tooltip_hide()">' + value + '</span>');
		
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

function text_filter_update_summary(filter) {
	var list = filter.find(".list_item input:checkbox").map(function() {
		var relevant = ($(this).parent().css("text-decoration") == "none");
		if(this.checked && relevant) return this.value;
		else return undefined;
	});
	if(list.length == 0) list.push("[none]");
	var summary = list.get().join(", ");
	if(summary.length > 50) summary = summary.substr(0, 46) + "...";
	filter.prev().find(".summary").text(summary);
}

// Util

function util_hash_from_array(keys, value) {
	var hash = {};
	for(i in keys) hash[keys[i]] = value;
	return hash;
}

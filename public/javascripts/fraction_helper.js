// TODO: revise and refactor when ready

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

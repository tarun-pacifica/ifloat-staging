function utiL_preload_image(url) {
	(new Image()).src = url;
}

// Number formatters

// TODO: review as possibly redundant (if the filtering controls for dates end up not using input boxes)
function util_format_date(value) {
	var yyyy_mm_dd = String(value).match(/^(\d{4})(\d\d)(\d\d)$/);
	if(yyyy_mm_dd == null) return value;
	
	var parts = [];
	for(i in yyyy_mm_dd) {
		var v = yyyy_mm_dd[i];
		if(i > 0 && v > 0) parts.push(v);
	}
	return parts.join("-");
}

function util_format_number(values, unit, date) {
	if(values.length == 0) return "";
	
	var formatted_values = [];
	for(i in values) {
		var v = values[i];
		if(v) formatted_values.push(date ? util_format_date(v) : fraction_helper_format(v));
	}
	
	var result = formatted_values.join("&ndash;");
	if(unit) result += " " + unit;
	return result;
}


// Util

function util_hash_from_array(keys, value) {
	var hash = {};
	for(i in keys) hash[keys[i]] = value;
	return hash;
}

function util_group_by(array, property) {
	var grouped = {};
	for(i in array) {
		var a = array[i];
		var key = a[property];
		if(grouped[key] == undefined) grouped[key] = [];
		grouped[key].push(a);
	}
	return grouped;
}

function util_hash_from_array(keys, value) {
	var hash = {};
	for(i in keys) hash[keys[i]] = value;
	return hash;
}

function util_preload_image(url) {
	(new Image()).src = url;
}

function util_escape(string, characters) {
	var s = string;
	for(i in characters) {
		var c = characters[i];
		s = s.replace(c, '\\' + c);
	}
	return s;
}

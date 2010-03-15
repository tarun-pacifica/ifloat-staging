function finder_recall(s) {
	var specification = $("#finder_specification");
	specification.val(s.value);
	specification.siblings("#submit").click();
}

function finder_validate() {
	var specification = $("#finder_specification").val();

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

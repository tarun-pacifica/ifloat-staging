function finder_recall() {
	var specification = $('#finder_specification');
	specification.val(event.target.value);
	specification.siblings('#submit').click();
}

function finder_validate() {
	var specification = $('#finder_specification').val();

	if(specification == '' || specification == 'What can we find for you?') {
		alert('Please supply one or more words to find.')
		return false;
	}

	return true;
}

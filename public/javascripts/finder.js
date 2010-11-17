function finder_do(phrase) {
  $('#finder_specification').val(phrase);
  $('#finder_submit').click();
}

function finder_validate() {
  var specification = $('#finder_specification').val();

  if(specification == '' || specification == 'What can we find for you?') {
    alert('Please supply one or more words to find.')
    return false;
  }

  return true;
}

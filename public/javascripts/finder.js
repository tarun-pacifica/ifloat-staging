function finder_do(phrase) {
  $('#finder_specification').val(phrase);
  $('#finder_submit').click();
}

function finder_validate() {
  var spec = $('#finder_specification').val();
  if(spec == '' || spec == 'What can we find for you?') alert('Please supply one or more words to find.');
  else window.location = '/categories?find=' + escape(spec);
}

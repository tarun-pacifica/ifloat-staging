function login_error(request) {
  var login_register = $('#login_register');
  login_register.find('form .errors').remove();
  
  var operation = login_register.data('operation');
  var form = login_register.find(operation == 'register' ? 'form.register' : 'form.login');
  form.append(request.responseText);
}

function login_logout() {
  $.get('/users/logout', function(){ window.location = '/'; });
}

function login_open(message) {
  var login_register = $('#login_register');
  message = (message ? message : '');
  login_register.find('.message').text(message);
  login_register.dialog('open');
}

function login_operation(operation) {
  $('#login_register').data('operation', operation);
}

function login_reset() {
  var forms = $('#login_register').find('form');
  forms.each( function() { this.reset(); } );
  forms.find('.errors').remove();
}

function login_submit(event) {
  var form = util_target(event);
  var options = {type: 'POST', url: form.attr('action'), success: login_success, error: login_error, data: {}};
  
  var inputs = form.find('input:not(:submit)');
  for(var i in inputs) {
    var input = inputs[i];
    options.data[input.name] = input.value;
  }
  options.data.submit = ($('#login_register').data('operation') == 'reset' ? 'Reset Password' : '');
  
  $.ajax(options);
  
  return false;
}

function login_success(data) {
  var login_register = $('#login_register');
  login_register.html(data);
  window.location.reload();
}

function login_update() {
  $.getJSON("/users/me", login_update_handle);
}

function login_update_handle(data) {
  var name = data.nickname;
  if(name == undefined) name = data.name;
  
  $ifloat_header.authenticated = (name != undefined);
  
  var link = $("#header_body .login");
  if(name == undefined) link.click(login_open).text("Log In");
  else link.click(login_logout).text("Log Out (" + name + ")");
  
  show_messages(data.messages);
}

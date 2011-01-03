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
  
  if(login_register.length == 0) {
    var html = ['<div id="login_register" title="Login / Register">'];
    html.push('<p class="message"> </p>');
    
    html.push('<form class="login" action="/users/login" method="post" onsubmit="return login_submit(event)">');
    html.push('<h3>Login</h3>');
    html.push('<p> <label>E-mail: <input type="text" name="login" /></label> </p>');
    html.push('<p> <label>Password: <input type="password" name="password" /></label> </p>');
    html.push('<p class="submit">');
    html.push('<input type="submit" value="Login" onclick="login_operation(\'login\')" name="form_submit" id="login_submit_button" />');
    html.push('<input type="submit" value="Reset Password" onclick="login_operation(\'reset\')" name="form_submit" id="reset_password_submit" />');
    html.push('</p>');
    html.push('</form>');
    
    html.push('<form class="register" action="/users" method="post" onsubmit="return login_submit(event)">');
    html.push('<h3>Register</h3>');
    html.push('<p> <label>Name: <input type="text" name="name" /></label> </p>');
    html.push('<p> <label>Nickname: <input type="text" name="nickname" /></label> </p>');
    html.push('<p> <label>E-mail: <input type="text" name="login" /></label> </p>');
    html.push('<p> <label>Password: <input type="password" name="password" /></label> </p>');
    html.push('<p> <label>Confirmation: <input type="password" name="confirmation" /></label> </p>');
    html.push('<p class="marketing">From time to time, we like to involve our users in marketing activities that make suppliers and retailers more effective for their customers. Please tick here <input type="checkbox" name="send_marketing" /> if you would like to participate in these activities.</p>');
    html.push('<p class="submit">');
    html.push('<input type="submit" value="Register" onclick="login_operation(\'register\')" name="form_submit" id="register_submit" />');
    html.push('</p>');
    html.push('</form>');
    
    html.push('</div>');
    
    $('body').append(html.join(' '));
    
    login_register = $('#login_register');
    login_register.dialog({autoOpen: false, close: login_reset, resizable: false, width: '700px'});
  }
  
  login_register.find('.message').text(message ? message : '');
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

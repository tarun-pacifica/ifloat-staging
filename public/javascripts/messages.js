function show_messages(messages) {
	if(messages.length == 0) return;
	
	$('body').append('<div id="messages"> </div>');
	message_dialog = $('#messages');
	for(var i in messages) message_dialog.append('<p>' + messages[i] + '</p>');
	
	message_dialog.dialog({autoOpen: true, resizable: false});
	message_dialog.dialog('option', 'title', 'Messages for you...');
	message_dialog.dialog('option', 'buttons', {OK: unshow_messages});
}

function unshow_messages() {
	$('#messages').remove();
}

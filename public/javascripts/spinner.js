util_preload_image('/images/common/spinner.gif');

function spinner_hide() {
	$('#spinner').fadeOut('fast');
}

function spinner_show(message) {
	var spinner = $('#spinner');
	if(spinner.length == 0) {
		$('body').append('<div id="spinner"> <img alt="spinner" src="/images/common/spinner.gif" /> <p> </p> </div>');
		spinner = $('#spinner');
		spinner.hide();
	}
	
	if(message) spinner.find('p').text(message);
	
	var win = $(window);
	spinner.css('left', (win.width() - spinner.width()) / 2 + 'px');
	spinner.css('top', (win.height() - spinner.height()) / 2 + 'px');
	
	spinner.fadeIn('fast');
}

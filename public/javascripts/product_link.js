function product_link_popup(event) {
  var link = $(this);
  
  var product = link.data('product');
  var caption = util_superscript('text', '<p>' + product.titles.image + '<br />' + product.titles.summary + '</p>');
  $('body').append('<div id="link_popup"> <img alt="product" src="' + product.image_urls.small + '" /> ' + caption + ' </div>');
  
  var image = link.children('img');
  var image_height = image.outerHeight();
  var image_position = image.offset();
  var image_left = image_position.left;
  var image_top = image_position.top;
  var image_width = image.outerWidth();
  
  var popup = $('#link_popup');
  var popup_height = popup.outerHeight();
  var popup_width = popup.outerWidth();
  
  var doc = $(document);
  var position_on = (image_left + image_width + 10 + popup_width < doc.width()) ? 'right' : 'left'
  
  var left_end = image_left, left_start;
  if(position_on == 'right') {
    left_end += image_width + 10;
    left_start = left_end + 10;
  } else {
    left_end -= popup_width + 10;
    left_start = left_end - 10;
  }
  
  var top = image_top + (image_height - popup_height) / 2;
  var document_overhang = top + popup_height - doc.height();
  if(document_overhang > 0) top -= document_overhang;
  
  image.css('opacity', '0.5');
  popup.css('left', left_start + 'px').css('top', top + 'px').css('opacity', 0).show();
  popup.animate({left: left_end + 'px', opacity: 1}, 'fast');
  }

function product_link_unpopup(event) {
  $(this).children('img').css('opacity', '1');
  $('#link_popup').remove();
}

function product_links_wire_up(product_ids) {
  var slices = Math.ceil(product_ids.length / 100);
  for(var i = 0; i < slices; i++) {
    var j = i * 100;
    $.getJSON('/products/batch/' + product_ids.slice(j, j + 100).join('_'), product_links_wire_up_handle);
  }
}

function product_links_wire_up_handle(products) {
  for(var i in products) {
    var product = products[i];
    var link = $('a#product_' + product.id);
    link.data('product', product);
    link.hover(product_link_popup, product_link_unpopup);
  }
}

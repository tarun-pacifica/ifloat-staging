function product_thumb_hover(event) {
  var thumb = util_target(event);
  $('#product img.main').attr('src', thumb.attr('src'));
  $('#product img.thumb').css('opacity', '0.5').css('border-style', 'dotted');
  thumb.css('opacity', '1').css('border-style', 'solid');
}

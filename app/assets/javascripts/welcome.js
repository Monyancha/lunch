$(function() {
  var $welcomeForm = $('.welcome-member-select');
  if ($welcomeForm.length) {
    var $memberProfileButton = $welcomeForm.find('.welcome-profile');
    var $visitProfileField = $welcomeForm.find('input[name=visit_profile]');
    $('.welcome form select').change(function() {
      $welcomeForm.find('input[type=submit]').removeAttr('disabled');
      $memberProfileButton.removeAttr('disabled');
    });
    $memberProfileButton.click(function(e) {
      $visitProfileField.removeAttr('disabled');
      $welcomeForm.attr('target', '_blank');
    });
    $welcomeForm.submit(function(e) {
      setTimeout(function() {
        $welcomeForm.removeAttr('target');
        $visitProfileField.attr('disabled', 'disabled');
        $welcomeForm.get(0).submit();
      }, 1);
    });
  };
});
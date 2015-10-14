When(/^I follow the forgot password link$/) do
  click_link(I18n.t('welcome.forgot_password'))
end

Then(/^I should see the forgot password page$/) do
  page.assert_selector('form legend', exact: true, visible: true, text: I18n.t('welcome.forgot_password'))
  page.assert_selector('form p', exact: true, visible: true, text: I18n.t('forgot_password.instructions'))
end

When(/^I enter my username$/) do
  fill_in('user_username', with: primary_user['username'])
end

When(/^I submit the form$/) do
  page.find('form input[type=submit]').click
end

Then(/^I should see the forgot password confirmation page$/) do
    page.assert_selector('form legend', exact: true, visible: true, text: I18n.t('forgot_password.confirmation.title'))
end

When(/^I enter an invalid username$/) do
  fill_in('user_username', with: 'abcd123')
end

Then(/^I should see an unknown user error flash$/) do
  page.assert_selector('form .form-flash-message', exact: true, visible: true, text: I18n.t('devise.passwords.username_not_found'))
end

When(/^I follow an invalid password link$/) do
  visit("/member/password/reset?reset_password_token=#{SecureRandom.hex}")
end

Then(/^I should see the forgot password request expired page$/) do
  page.assert_selector('form legend', exact: true, visible: true, text: I18n.t('forgot_password.timeout.title'))
end

Given(/^I visit a valid reset password link$/) do
  token = User.find_or_create_if_valid_login(username: resetable_user['username']).send_reset_password_instructions
  visit("/member/password/reset?reset_password_token=#{token}")
end

When(/^I enter a (password(?: confirmation)?) of "([^"]*)"$/) do |field, password|
  fill_in("user_#{field.parameterize('_')}", with: password)
  page.find('body').click
end

Then(/^I should see a (capital letter|lowercase|number|symbol|confirmation|minimum length) required password error$/) do |error_type|
  error = case error_type
  when 'capital letter'
    I18n.t('activerecord.errors.models.user.attributes.password.capital_letter_needed')
  when 'lowercase'
    I18n.t('activerecord.errors.models.user.attributes.password.lowercase_letter_needed')
  when 'number'
    I18n.t('activerecord.errors.models.user.attributes.password.number_needed')
  when 'symbol'
    I18n.t('activerecord.errors.models.user.attributes.password.symbol_needed')
  when 'confirmation'
    I18n.t('activerecord.errors.models.user.attributes.password.confirmation')
  when 'minimum length'
    I18n.t('activerecord.errors.models.user.attributes.password.too_short', count: 8)
  else
    raise 'unknown error'
  end
  page.assert_selector('label.label-error', exact: true, visible: true, text: error)
end

Then(/^I should see no password errors$/) do
  page.assert_no_selector('label.label-error', wait: 1)
end

Then(/^I should see a password change success flash$/) do
  page.assert_selector('.form-flash-message[data-type=success]', exact: true, visible: true, text: I18n.t('devise.passwords.updated_not_active'))
end

When(/^I fill in and submit the login form with reset username and password "([^"]*)"$/) do |password|
  step %{I fill in and submit the login form with username "#{resetable_user['username']}" and password "#{password}"}
end
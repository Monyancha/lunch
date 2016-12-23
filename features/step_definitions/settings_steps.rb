When(/^I click on the settings link in the header$/) do
  page.find('.nav-settings a').click
end

Then(/^I should see "(.*?)" as the sidebar title$/) do |title|
  page.assert_selector('.sidebar-label', :text => title)
end

When(/^I click on "(.*?)" in the sidebar nav$/) do |link|
  page.find('.sidebar a', text: link).click
end

Then(/^I should be on the email settings page$/) do
  page.assert_selector('section.settings-email', :visible => true)
end

Then(/^I should be on the two factor settings page$/) do
  page.assert_selector('section.settings-two-factor',  visible: true)
  text = I18n.t('settings.two_factor.title')
  page.assert_selector('h1', visible: true, text: /\A#{Regexp.quote(text)}\z/)
  page.assert_selector('.settings-group', visible: true, count: 3)
end

When(/^I am on the email settings page$/) do
  visit "/settings"
  step "I click on \"Emails\" in the sidebar nav"
  step "I should be on the email settings page"
end

Given(/^I am on the change password page$/) do
  page.find( '.page-header .nav-settings a' ).click
  step %{I should see the change password page}
end

Then(/^I should see a message letting me know I cannot change my password$/) do
  page.assert_selector('p', text: I18n.t('settings.password.intranet'), exact: true)
end

Then(/^I should not see the change password form/) do
  page.assert_no_selector('.settings-password form')
end

Then(/^I should see the change password page$/) do
  page.assert_selector('.settings-password form', visible: true)
end

Given(/^I fill in the current password field with the (password change user)'s password$/) do |user_type|
  fill_in(:user_current_password, with: user_for_type(user_type)['password'])
end

Given(/^I see the unselected state for the "(.*?)" option$/) do |option|
  page.assert_selector(".settings-email-#{option}-row td:nth-child(3) .settings-selected-item-message", :visible => :hidden)
end

When(/^I check the box for the "(.*?)" option$/) do |option|
  page.find(".settings-email-#{option}-row label").click
end

Then(/^I should see the selected state for the "(.*?)" option$/) do |option|
  page.assert_selector(".settings-email-#{option}-row td:nth-child(3) .settings-selected-item-message", :visible => true)
end

Then(/^I should see the auto\-save message for the email settings page$/) do
  page.assert_selector(".settings-save-message")
end

Given(/^I am on the two factor authentication settings page$/) do
  visit '/settings/two-factor'
end

Then(/^I should see the (reset|new) PIN form$/) do |form_name|
  page.assert_selector(".settings-#{form_name}-pin form", visible: true)
end

When(/^I click on the (reset|new) token PIN CTA$/) do |cta_name|
  click_link I18n.t("settings.two_factor.#{cta_name}_pin.cta")
end

When(/^I cancel (?:re)?setting the PIN$/) do
  click_button I18n.t('global.cancel')
end

Then(/^I should not see the (reset|new) PIN form$/) do |form_name|
  page.assert_selector(".settings-#{form_name}-pin form", visible: false)
end

Given(/^I am on the (reset|new) PIN page$/) do |page_name|
  step %{I am on the two factor authentication settings page}
  step %{I click on the #{page_name} token PIN CTA}
end

When(/^I enter a bad current PIN$/) do
  page.find('input[name=securid_pin').set('abc1')
end

When(/^I submit the (reset|new) PIN form$/) do |form_name|
  click_button I18n.t("settings.two_factor.#{form_name}_pin.save")
end

Then(/^I should see the invalid PIN message$/) do
  page.assert_selector('.form-error', text: /\A#{Regexp.quote(I18n.t('dashboard.quick_advance.securid.errors.invalid_pin'))}\z/, visible: true)
end

When(/^I enter a good current PIN$/) do
  step %{I enter my SecurID pin}
end

When(/^I enter a bad token$/) do
  page.find('input[name=securid_token').set('abc1dc')
end

Then(/^I should see the invalid token message$/) do
  page.assert_selector('.form-error', text: /\A#{Regexp.quote(I18n.t('dashboard.quick_advance.securid.errors.invalid_token'))}\z/, visible: true)
end

When(/^I enter a good token$/) do
  step %{I enter my SecurID token}
end

When(/^I enter a bad new PIN$/) do
  page.find('input[name=securid_new_pin').set('12ad')
end

When(/^I enter a good new PIN$/) do
  page.find('input[name=securid_new_pin').set(Random.rand(9999).to_s.rjust(4, '0'))
end

When(/^I enter a bad confirm PIN$/) do
  page.find('input[name=securid_confirm_pin').set('12ad')
end

When(/^I enter two different values for the new PIN$/) do
  pin = Random.rand(9999).to_s.rjust(4, '0')
  page.find('input[name=securid_new_pin').set(pin)
  page.find('input[name=securid_confirm_pin').set(pin)
end

Then(/^I should see the failed to reset PIN message$/) do
  page.assert_selector('.form-flash-message', text: /\A#{Regexp.quote(strip_links(I18n.t('settings.two_factor.reset_pin.error_html', phone_number: web_support_phone_number, url: web_support_email)))}\z/, visible: true)
end

Then(/^I should see the failed to set PIN message$/) do
  page.assert_selector('.form-flash-message', text: /\A#{Regexp.quote(strip_links(I18n.t('settings.two_factor.new_pin.error_html', phone_number: web_support_phone_number, url: web_support_email)))}\z/, visible: true)
end

When(/^I click on the resynchronize token CTA$/) do
  click_link I18n.t('settings.two_factor.resynchronize.cta')
end

Then(/^I should see the resynchronize token form$/) do
  page.assert_selector('.settings-resynchronize-token form', visible: true)
end

When(/^I cancel resynchronizing the token$/) do
  click_button I18n.t('global.cancel')
end

Then(/^I should not see the resynchronize token form$/) do
  page.assert_selector('.settings-resynchronize-token form', visible: false)
end

Given(/^I am on the resynchronize token page$/) do
  step %{I am on the two factor authentication settings page}
  step %{I click on the resynchronize token CTA}
end

When(/^I submit the resynchronize token form$/) do
  click_button I18n.t('settings.two_factor.resynchronize.save')
end

When(/^I enter a bad next token$/) do
  page.find('input[name=securid_next_token').set('abc1dc')
end

When(/^I enter a good next token$/) do
  page.find('input[name=securid_next_token').set(Random.rand(999999).to_s.rjust(6, '0'))
end

Then(/^I should see the failed to resynchronize token message$/) do
    page.assert_selector('.form-flash-message', text: /\A#{Regexp.quote(strip_links(I18n.t('settings.two_factor.resynchronize.error_html', phone_number: web_support_phone_number, url: web_support_email)))}\z/, visible: true)
end

Then(/^I should see current password validations$/) do
  step %{I enter a current password of ""}
  step %{I should see a current password required error}
end

When(/^I enter a current password of "([^"]*)"$/) do |password|
  fill_in(:user_current_password, with: password)
  page.find('body').click
end

When(/^I enter a bad current password$/) do
  step %{I enter a current password of "#{SecureRandom.hex}"}
end

Then(/^I should see a current password required error$/) do
  page.assert_selector('label.label-error', exact: true, visible: true, text: I18n.t('activerecord.errors.models.user.attributes.current_password.blank'))
end

Then(/^I should see the "(.*?)" product page$/) do |product|
  text = case product
    when 'products summary'
      I18n.t('products.products_summary.title')
    when 'standby letters of credit'
      I18n.t('products.standby_loc.title')
    when 'arc embedded'
      I18n.t('products.advances.arc_embedded.title')
    when 'amortizing'
      I18n.t('products.advances.amortizing.title')
    when 'frc'
      I18n.t('products.advances.frc.title')
    when 'frc embedded'
      I18n.t('products.advances.frc_embedded.title')
    when 'arc'
      I18n.t('products.advances.arc.title')
    when 'choice libor'
      I18n.t('products.advances.choice_libor.title')
    when 'knockout'
      I18n.t('products.advances.knockout.title')
    when 'other cash needs'
      I18n.t('products.advances.ocn.title')
    when 'putable'
      I18n.t('products.advances.putable.title')
    when 'callable'
      I18n.t('products.advances.callable.title')
    when 'variable rate credit'
      I18n.t('products.advances.vrc.title')
    when 'securities backed credit'
      I18n.t('products.advances.sbc.title')
    when 'mortgage partnership finance'
      I18n.t('products.advances.mpf.title')
    when 'convertible'
      I18n.t('products.advances.convertible.title')
    when 'variable balance letter of credit'
      I18n.t('products.variable_balance_loc.title')
    else
      raise 'unknown product page'
  end
  page.assert_selector('.product-page h1', text: text)
end

Then(/^I should see the pfi page$/) do
  page.assert_selector('.product-page-mpf h1 span', text: I18n.t('products.advances.pfi.title'))
end

When(/^I click on the (arc embedded|frc|frc embedded|arc|amortizing|choice libor|knockout|putable|other cash needs|mortgage partnership finance|standby letters of credit) link in the products advances dropdown$/) do |link|
  page.find('.page-header .products-dropdown a', text: dropdown_title_regex(link), exact: true).click
end

When(/^I click on the pfi link$/) do
  click_link('PFI Application')
end

Then(/^I should see at least one pfi form to download$/) do
  page.assert_selector('.product-mpf-table a', text: /\A#{Regexp.quote(I18n.t('global.view_pdf'))}\z/i, minimum: 1)
end

Given(/^I am on the pfi page$/) do
  visit '/products/advances/pfi'
end

When(/^I click on the variable balance letter of credit link$/) do
  click_link('Variable Balance Letter of Credit')
end

Then(/^I should see the variable letter of credit page$/) do
  page.assert_selector('.products-page-vbloc h1', text: I18n.t('products.variable_balance_loc.title'))
end
When(/^I click on the Securities link in the header$/) do
  page.find('.secondary-nav a', text: I18n.t('securities.title'), exact: true).click
end

Then(/^I should be on the (Manage Securities|Securities Requests|Securities Release|Safekeep Securities|Pledge Securities|Transfer to Pledged|Transfer to Safekept|Transfer Securities|Manage Letters of Credit|New Letter of Credit Request|Preview Letter of Credit Request|Letter of Credit Request Success|Add Beneficiary Request) page$/i) do |page_type|
  text = case page_type
  when /\AManage Securities\z/i
    step 'I should see a report table with multiple data rows'
    I18n.t('securities.manage.title')
  when /\ASecurities Requests\z/i
    step 'I should see a report table with multiple data rows'
    I18n.t('securities.requests.title')
  when /\ASecurities Release\z/i
    step 'I should see a report table with multiple data rows'
    I18n.t('securities.release.title')
  when /\ASafekeep Securities\z/i
    I18n.t('securities.safekeep.title')
  when /\APledge Securities\z/i
    I18n.t('securities.pledge.title')
  when /\ATransfer to Pledged\z/i
    I18n.t('securities.transfer.pledge.title')
  when /\ATransfer to Safekept\z/i
    I18n.t('securities.transfer.safekeep.title')
  when /\ATransfer Securities\z/i
    /\ATransfer Securities/
  when /\AManage Letters of Credit\z/i
    step 'I should see a report table with multiple data rows'
    I18n.t('letters_of_credit.manage.title')
  when /\ANew Letter of Credit Request\z/i
    I18n.t('letters_of_credit.request.title')
  when /\APreview Letter of Credit Request\z/i
    I18n.t('letters_of_credit.request.title')
  when /\ALetter of Credit Request Success\z/i
    I18n.t('letters_of_credit.success.title')
  when /\ALetter of Credit Request Success\z/i
    I18n.t('letters_of_credit.beneficiary.add')
  end
  page.assert_selector('h1', text: text, exact: true)
end

Then(/^I should see two securities requests tables with data rows$/) do
  page.assert_selector('.securities-request-table', count: 2)
  page.all('.securities-request-table').each do |table|
    table.assert_selector('tbody tr')
  end
end

When(/^I am on the (manage|release|pledge release|safekeep release|pledge release success|safekeep release success|safekeep success|pledge success|safekeep|pledge|pledge transfer success|safekeep transfer success|transfer to pledged account|transfer to safekept account) securities page$/) do |page|
  case page
  when 'manage'
    visit '/securities/manage'
  when 'pledge release success'
    visit '/securities/release/pledge_success'
  when 'safekeep release success'
    visit '/securities/release/safekeep_success'
  when 'pledge success'
    visit '/securities/pledge/success'
  when 'safekeep success'
    visit '/securities/safekeep/success'
  when 'pledge transfer success'
    visit '/securities/transfer/pledge_success'
  when 'safekeep transfer success'
    visit '/securities/transfer/safekeep_success'
  when 'release'
    step 'I am on the manage securities page'
    step 'I check the 1st Pledged security'
    step 'I click the button to release the securities'
  when 'pledge release'
    step 'I am on the manage securities page'
    step 'I check the 1st Pledged security'
    step 'I click the button to release the securities'
  when 'safekeep release'
    step 'I am on the manage securities page'
    step 'I check the 1st Safekept security'
    step 'I click the button to release the securities'
  when 'transfer to pledged account'
    step 'I am on the manage securities page'
    step 'I check the 1st Safekept security'
    step 'I click the button to transfer the securities'
  when 'transfer to safekept account'
    step 'I am on the manage securities page'
    step 'I check the 1st Pledged security'
    step 'I click the button to transfer the securities'
  when 'safekeep'
    visit '/securities/safekeep/edit'
  when 'pledge'
    visit '/securities/pledge/edit'
  end
end

Given(/^I am on the securities request page$/) do
  visit '/securities/requests'
end

When(/^I filter the securities by (Safekept|Pledged|All)$/) do |filter|
  page.find('.securities-status-filter span', text: filter, exact: true).click
end

Then(/^I should only see (Safekept|Pledged|All) rows in the securities table$/) do |filter|
  column_index = jquery_evaluate("$('.report-table thead th:contains(#{I18n.t('common_table_headings.status')})').index()") + 1
  if table_not_empty
    page.all(".manage-securities-table td:nth-child(#{column_index})").each_with_index do |element, index|
      expect(element.text).to eq(filter)
    end
  end
end

When(/^I (check|uncheck) the (\d+)(?:st|nd|rd|th) (Pledged|Safekept) security$/) do |checked, i, status|
  if table_not_empty
    index = i.to_i - 1
    checkbox = page.all(".manage-securities-form input[type=checkbox][data-status='#{status}']")[index]
    checkbox.click
    expect(checkbox.checked?).to eq(checked == 'check')
  end
end

When(/^I remember the cusip value of the (\d+)(?:st|nd|rd|th) (Pledged|Safekept) security$/) do |i, status|
  checkbox_name = :"@#{status.downcase}#{i}"
  index = i.to_i - 1
  cusip = page.all(".manage-securities-form input[type=checkbox][data-status='#{status}']")[index].first(:xpath,".//..//..").find('td:nth-child(2)').text
  instance_variable_set(checkbox_name, cusip)
end

Then(/^I should see the cusip value from the (\d+)(?:st|nd|rd|th) (Pledged|Safekept) security in the (\d+)(?:st|nd|rd|th) row of the securities table$/) do |i, status, row|
  remembered_cusip = instance_variable_get(:"@#{status.downcase}#{i}")
  cusip = page.find(".securities-release-table tbody tr:nth-child(#{row}) td:first-child").text
  expect(remembered_cusip).to eq(cusip)
end

Then(/^the (release|transfer) securities button should be (active|inactive)$/) do |action, active|
  if table_not_empty
    text = action == 'release' ? I18n.t('securities.manage.release') : I18n.t('securities.manage.transfer')
    if active == 'active'
      page.assert_selector('.manage-securities-form a[data-manage-securities-form-submit]', text: text.upcase, exact: true)
      page.assert_no_selector('.manage-securities-form a[data-manage-securities-form-submit][disabled]', text: text.upcase, exact: true)
    else
      page.assert_selector('.manage-securities-form a[data-manage-securities-form-submit][disabled]', text: text.upcase, exact: true)
    end
  end
end

When(/^I click the button to (release|transfer) the securities$/) do |action|
  text = action == 'release' ? I18n.t('securities.manage.release') : I18n.t('securities.manage.transfer')
  page.find('.manage-securities-form a[data-manage-securities-form-submit]', text: text.upcase, exact: true).click
end

When(/^I click the button to create a new (safekeep|pledge) request$/) do |type|
  page.find(".manage-securities-table-actions a.#{type}").click
end

Then(/^I should see "(.*?)" as the selected release delivery instructions$/) do |instructions|
  text = delivery_instructions(instructions)
  page.assert_selector('.securities-delivery-instructions .dropdown-selection', text: text, exact: true)
end

Then(/^I should see the "(.*?)" release instructions fields$/) do |instructions|
  selector = case instructions
    when 'DTC'
      'dtc'
    when 'Fed'
      'fed'
    when 'Mutual Fund'
      'mutual-fund'
    when 'Physical'
      'physical-securities'
  end
  page.assert_selector(".securities-delivery-instructions-field-#{selector}", visible: :visible)
end

When(/^I select "(.*?)" as the release delivery instructions$/) do |instructions|
  text = delivery_instructions(instructions)
  page.find('.securities-delivery-instructions .dropdown').click
  page.find('.securities-delivery-instructions .dropdown li', text: text, exact: true).click
end

When(/^I click the button to delete the request/) do
  page.find('.delete-request-trigger').click
end

Then(/^I should see the delete (?:release|request) flyout dialogue$/) do
  page.assert_selector('.flyout-confirmation-dialogue', visible: 'visible')
end

Then(/^I should see (safekeep|pledge|transfer|release) copy for the delete flyout$/) do |type|
  page.assert_selector('.delete-request-flyout h2', text: I18n.t("securities.delete_request.titles.#{type}"), visible: 'visible', exact: true)
end

Then(/^I should not see the delete (?:release|request) flyout dialogue$/) do
  page.assert_no_selector('.flyout-confirmation-dialogue', visible: 'visible')
end

When(/^I click on the button to continue with the release$/) do
  page.find('.delete-request-flyout button', text: I18n.t('global.cancel').upcase).click
end

When(/^I confirm that I want to delete the request$/) do
  page.find('.delete-request-flyout a', text: I18n.t('securities.delete_request.delete').upcase).click
end

When(/^I click on the Edit Securities link$/) do
  page.find('.securities-download').click
end

When(/^I click on the Learn How link$/) do
  page.find('.securities-download-safekeep-pledge').click
end

Then(/^I should see instructions on how to (edit|upload) securities$/) do |action|
  page.assert_selector(".securities-#{action == 'edit' ? 'download' : 'upload'}-instructions", visible: :visible)
end

Then(/^I should not see instructions on how to (edit|upload) securities$/) do |action|
  page.assert_selector(".securities-#{action == 'edit' ? 'download' : 'upload'}-instructions", visible: :hidden)
end

When(/^the edit securities section is open$/) do
  step 'I click on the Edit Securities link'
  step 'I should see instructions on how to edit securities'
end

When(/^I drag and drop the "(.*?)" file into the (edit|upload) securities dropzone$/) do |filename, type|
  # Simulate drag and drop of given file
  dropzone = type == 'edit' ? '.securities-download-instructions' : '.safekeep-pledge-download-area'
  page.execute_script("seleniumUpload = window.$('<input/>').attr({id: 'seleniumUpload', type:'file'}).appendTo('body');")
  attach_file('seleniumUpload', Rails.root + "spec/fixtures/#{filename}")
  page.execute_script("e = $.Event('drop'); e.originalEvent = {dataTransfer : { files : seleniumUpload.get(0).files } }; $('#{dropzone}').trigger(e);")
end

When(/^I should see an? (security required|original par numericality|no securities|original par blank) field error$/) do |error_type|
  text = case error_type
           when 'security required'
             I18n.t('activemodel.errors.models.security.blank').gsub("\n",' ')
           when 'original par blank'
             I18n.t('activemodel.errors.models.security.attributes.original_par.blank')
           when 'original par numericality'
             I18n.t('activemodel.errors.models.security.not_a_number', attribute: 'Original par')
           when 'no securities'
             I18n.t('securities.upload_errors.no_rows')
         end
  page.assert_selector('.securities-request-upload-error p', text: text, exact: true)
end

Then(/^I should( not)? see the securities upload success message$/) do |should_not_see|
  selector = ['.securities-request-upload-success', text: I18n.t('securities.upload_success'), exact: true, visible: true]
  should_not_see ? page.assert_no_selector(*selector) : page.assert_selector(*selector)
end

Then(/^I should see an upload progress bar$/) do
  page.assert_selector('.file-upload-progress .gauge-section', visible: :visible)
end

When(/^I click to cancel the securities release file upload$/) do
  page.find('.file-upload-progress p', text: I18n.t('global.cancel_upload').upcase, exact: true).click
end

Then(/^I should not see an upload progress bar$/) do
  page.assert_selector('.file-upload-progress .gauge-section', visible: :hidden)
end

When(/^I click the (trade|settlement|issue|expiration) date datepicker$/) do |field|
  text = case field
  when 'trade'
    I18n.t('common_table_headings.trade_date')
  when 'settlement'
    I18n.t('common_table_headings.settlement_date')
  else
    raise ArgumentError.new("Unknown datepicker field: #{field}")
  end
  field_container = page.find('.securities-broker-instructions .input-field-container-horizontal', text: text, exact: true, visible: :visible)
  field_container.find('.datepicker-trigger').click
end

Then(/^I should see a list of securities authorized users$/) do
  page.assert_selector('h2', text: /\A#{Regexp.quote(I18n.t('securities.success.authorizers'))}\z/, visible: true)
  page.assert_selector('.securities-success-table', visible: true)
end

Then(/^I should see the title for the "(.*?)" success page$/) do |success_page|
  translation = case success_page
  when 'pledge release'
    'securities.success.titles.pledge_release'
  when 'safekept release'
    'securities.success.titles.safekept_release'
  when 'pledge intake'
    'securities.success.titles.pledge_intake'
  when 'safekept intake'
    'securities.success.titles.safekept_intake'
  when 'transfer'
    'securities.success.titles.transfer'
  end
  page.assert_selector('.securities-header h1', text: I18n.t(translation), exact: true)
end

When(/^I fill in the "(.*?)" securities field with "(.*?)"$/) do |field_name, value|
  begin
    page.fill_in("securities_request[#{field_name}]", with: value)
  rescue Capybara::ElementNotFound
    #ignore
  end
end

When(/^I submit the securities(?: release)? request for authorization$/) do
  page.find('.securities-submit-request-form input[type=submit]').click
end

Then(/^I should see the generic error message for the securities release request$/) do
  page.assert_selector('.securities .form-error-section p', text: I18n.t('securities.release.edit.generic_error', phone_number: securities_services_phone_number, email: securities_services_email_text), exact: true)
end

Then(/^I should see the error message for missing securities request information$/) do
  page.assert_selector('.securities .form-error-section p', text: /^Missing a required field: /)
end

Then(/^the (Pledge|Safekeep) Account Number should be disabled$/) do |action|
  if action == 'Pledge'
    page.assert_selector('#securities_request_pledged_account[disabled]')
  else
    page.assert_selector('#securities_request_safekept_account[disabled]')
  end
end

Then(/^I should see a disabled state for the Authorize action$/) do
  page.assert_selector('.securities-request-table .report-cell-actions', text: I18n.t('securities.requests.actions.authorize').upcase, exact: true)
  page.assert_no_selector('.securities-request-table .report-cell-actions a', text: I18n.t('securities.requests.actions.authorize').upcase, exact: true)
end

Then(/^I should see the active state for the Authorize action$/) do
  page.assert_selector('.securities-request-table .report-cell-actions a', text: I18n.t('securities.requests.actions.authorize').upcase, exact: true)
end

Then(/^I should see the (active|disabled) state for the Authorize action for (pledge intake|safekept intake|pledge release|safekept release|safekept transfer|pledge transfer)$/) do |state, type|
  description = case type
  when 'pledge intake'
    I18n.t('securities.requests.form_descriptions.pledge')
  when 'pledge release'
    I18n.t('securities.requests.form_descriptions.release_pledged')
  when 'safekept release'
    I18n.t('securities.requests.form_descriptions.release_safekept')
  when 'safekept intake'
    I18n.t('securities.requests.form_descriptions.safekept')
  when 'safekept transfer'
    I18n.t('securities.requests.form_descriptions.transfer_safekept')
  when 'pledge transfer'
    I18n.t('securities.requests.form_descriptions.transfer_pledged')
  else
    raise ArgumentError, "unknown form type: #{type}"
  end
  row = page.all('.securities-request-table td', text: description, exact: true).first.find(:xpath, '..')
  if state == 'active'
    row.assert_selector('.report-cell-actions a', text: I18n.t('securities.requests.actions.authorize').upcase, exact: true)
  else
    row.assert_no_selector('.report-cell-actions a', text: I18n.t('securities.requests.actions.authorize').upcase, exact: true)
  end
end

When(/^I click to Authorize the first (pledge intake|pledge release|safekept release|safekept intake|safekept transfer|pledge transfer)(?: request)?$/) do |type|
  description = case type
  when 'pledge intake'
    I18n.t('securities.requests.form_descriptions.pledge')
  when 'pledge release'
    I18n.t('securities.requests.form_descriptions.release_pledged')
  when 'safekept release'
    I18n.t('securities.requests.form_descriptions.release_safekept')
  when 'safekept intake'
    I18n.t('securities.requests.form_descriptions.safekept')
  when 'safekept transfer'
    I18n.t('securities.requests.form_descriptions.transfer_safekept')
  when 'pledge transfer'
    I18n.t('securities.requests.form_descriptions.transfer_pledged')
  else
    raise ArgumentError, "unknown form type: #{type}"
  end
  row = page.all('.securities-request-table td', text: description, exact: true).first.find(:xpath, '..')
  @request_id = row.find('td:first-child').text
  row.find('.report-cell-actions a', text: I18n.t('securities.requests.actions.authorize').upcase, exact: true).click
end

Then(/^I should not see the request ID that I deleted$/) do
  page.assert_no_selector('.securities-request-table td', text: @request_id, exact: true)
end

Then(/^I should see "(.*?)" as the selected pledge type$/) do |type|
  page.assert_selector('.securities-broker-instructions .pledge_type .dropdown-selection', text: pledge_types(type), exact: true)
end

When(/^I authorize the request$/) do
  step %{I enter my SecurID pin and token}
  step %{I click to authorize the request}
end

When(/^I click to (authorize|submit) the request$/) do |action|
  text = action == 'authorize' ? I18n.t('securities.release.authorize') : I18n.t('securities.release.submit_authorization')
  page.find(".securities-actions .primary-button[value='#{text}']").click
end

Then(/^I should see the authorize request success page$/) do
  page.assert_selector('.securities-authorize-success')
end

Then(/^the (Authorize|Submit) action is (disabled|enabled)$/) do |action, state|
  text = action == 'Authorize' ? I18n.t('securities.release.authorize') : I18n.t('securities.release.submit_authorization')
  base = ".securities-actions .primary-button[value='#{text}']"
  if state == 'disabled'
    page.assert_selector(base + '[disabled]')
  else
    page.assert_selector(base + ':not([disabled])')
  end
end

When(/^I choose the (first|last) available date for (trade|settlement) date$/) do |position, attr|
  step "I click the #{attr} date datepicker"
  step "I choose the #{position} available date"
end

Given(/^I upload a securities (release|intake|transfer) file(?: with "(.*?)")?$/) do |action, file_type|
  filename = if action && file_type
    if action == 'release' && file_type == 'settlement amounts'
      'sample-securities-release-upload-with-settlement-amount.xlsx'
    elsif action == 'release' && file_type == 'no settlement amounts'
      'sample-securities-release-upload-no-settlement-amount.xlsx'
    elsif action == 'release' && file_type == 'an original par over the federal limit'
      'sample-securities-release-upload-over-fed-limit.xlsx'
    elsif action == 'release' && file_type == 'an original par that is not a whole number'
      'sample-securities-release-upload-decimal-original-par.xlsx'
    elsif action == 'intake' && file_type == 'settlement amounts'
      'sample-securities-intake-upload-with-settlement-amount.xlsx'
    elsif action == 'intake' && file_type == 'no settlement amounts'
      'sample-securities-intake-upload-no-settlement-amount.xlsx'
    elsif action == 'intake' && file_type == 'an original par over the federal limit'
      'sample-securities-intake-upload-over-fed-limit.xlsx'
    elsif action == 'intake' && file_type == 'an original par that is not a whole number'
      'sample-securities-intake-upload-decimal-original-par.xlsx'
    end
  else
    case action
    when 'release'
      'sample-securities-release-upload-no-settlement-amount.xlsx'
    when 'intake'
      'sample-securities-intake-upload-no-settlement-amount.xlsx'
    when 'transfer'
      'sample-securities-transfer-upload.xlsx'
    end
  end
  file_field = page.find('[type=file]', visible: false)
  file_field.set(File.absolute_path(File.join(__dir__, '..', '..', 'spec', 'fixtures', filename)))
end

When(/^I wait for the securities file to upload$/) do
  step 'I should not see instructions on how to edit securities'
  page.assert_no_selector('.file-upload-progress .gauge-section', visible: :visible)
end

Then(/^I should see an uploaded transfer security with an? (description|original par) of "(.*?)"$/) do |field, value|
  index = field == 'description' ? 1 : 2
  expect(page.all('.securities-display table tbody tr:first-child td')[index].text).to eq(value)
end

Then(/^I should (see|not see) the securities legal copy$/) do |should_see|
  if should_see == 'see'
    page.assert_selector('.securities-request-legal')
  else
    page.assert_no_selector('.securities-request-legal')
  end
end

Then(/^I should see the "(.*?)" error$/) do |error|
  text = case error
  when 'settlement date before trade date'
    I18n.t('activemodel.errors.models.securities_request.attributes.settlement_date.before_trade_date')
  when 'settlement amount required'
    I18n.t('activemodel.errors.models.securities_request.attributes.securities.payment_amount_missing')
  when 'over federal limit'
    I18n.t('activemodel.errors.models.securities_request.attributes.securities.original_par')
  when 'settlement amount present'
    I18n.t('activemodel.errors.models.securities_request.attributes.securities.payment_amount_present')
  when 'generic catchall'
    I18n.t('securities.release.edit.generic_error_html', phone_number: securities_services_phone_number, email: securities_services_email)
  when 'intranet user'
    I18n.t('securities.internal_user_error')
  when 'original par whole number'
    I18n.t('activemodel.errors.models.securities_request.attributes.securities.original_par_whole_number')
  end
  page.assert_selector('.securities-header h1', visible: true)
  page.assert_selector('.securities .form-error-section p', text: strip_links(text), exact: true)
end

When(/^the settlement type is set to (Vs Payment|Free)$/) do |payment_type|
  text = payment_type == 'Vs Payment' ? I18n.t('securities.release.settlement_type.vs_payment') : I18n.t('securities.release.settlement_type.free')
  page.find('label[for=release_settlement_type] + .dropdown').click
  page.find('label[for=release_settlement_type] + .dropdown li', text: text, exact: true).click
end

When(/^I submit the request and the API returns a (\d+)$/) do |http_code|
  allow_any_instance_of(SecuritiesRequestService).to receive(:post_hash).with(:submit_request_for_authorization, anything, anything).and_return(RestClient::Exception.new(nil, http_code.to_i))
  step 'I submit the securities release request for authorization'
end

When(/^I check the box to select all displayed securities$/) do
  page.find('.manage-securities-table input[name="check_all"]').click
end

When(/^I request a PDF of an authorized (pledge intake|pledge release|safekept release|safekept intake|safekept transfer|pledge transfer) securities request$/) do |type|
  description = case type
    when 'pledge intake'
      I18n.t('securities.requests.form_descriptions.pledge')
    when 'pledge release'
      I18n.t('securities.requests.form_descriptions.release_pledged')
    when 'safekept release'
      I18n.t('securities.requests.form_descriptions.release_safekept')
    when 'safekept intake'
      I18n.t('securities.requests.form_descriptions.safekept')
    when 'safekept transfer'
      I18n.t('securities.requests.form_descriptions.transfer_safekept')
    when 'pledge transfer'
      I18n.t('securities.requests.form_descriptions.transfer_pledged')
    else
      raise ArgumentError, "unknown form type: #{type}"
    end
  row = page.all('.authorized-requests td', text: description, exact: true).first.find(:xpath, '..')
  jquery_execute("$('body').on('downloadStarted', function(){$('body').addClass('download-started')})")
  row.find('td:last-child a', text: /\A#{I18n.t('global.view').upcase}\z/, match: :first).click
end

When(/^I discard the uploaded securities$/) do
  page.find('.safekeep-pledge-upload-again').click
end

Then(/^I should see the contact information for (Securities Services|Collateral Operations)$/) do |contact|
  if contact == 'Securities Services'
    email_address = securities_services_email
    mailto_text = I18n.t('contact.collateral_departments.securities_services.title')
    phone_number = securities_services_phone_number
  else
    email_address = collateral_operations_email
    mailto_text = I18n.t('contact.collateral_departments.collateral_operations.title')
    phone_number = collateral_operations_phone_number
  end
  text = strip_links(I18n.t('securities.release.edit.step_2.description_html', mailto_url: email_address, mailto_text: mailto_text, phone_number: phone_number))
  page.assert_selector('.securities-download-instructions-description:last-of-type', text: text, exact: true, visible: true)
end

Then(/^I (should|should not) see the field for further credit account number in the "(.*?)" fieldset$/) do |assertion, delivery_instruction|
  attribute = case delivery_instruction
    when 'DTC'
      'dtc_credit_account_number'
    when 'Fed'
      'fed_credit_account_number'
    when 'Physical'
      'physical_securities_credit_account_number'
              end
  selector = "input[name='securities_request[#{attribute}]'"
  if assertion == 'should'
    page.assert_selector(selector, visible: true)
  else
    page.assert_no_selector(selector)
  end
end

def delivery_instructions(text)
  case text
  when 'DTC'
    I18n.t('securities.release.delivery_instructions.dtc')
  when 'Fed'
    I18n.t('securities.release.delivery_instructions.fed')
  when 'Mutual Fund'
    I18n.t('securities.release.delivery_instructions.mutual_fund')
  when 'Physical'
    I18n.t('securities.release.delivery_instructions.physical_securities')
  end
end

def pledge_types(text)
  case text
  when 'SBC'
    I18n.t('securities.release.pledge_type.sbc')
  when 'Standard'
    I18n.t('securities.release.pledge_type.standard')
  end
end

def table_not_empty
  !page.find(".report-table tbody tr:first-child td:first-child")['class'].split(' ').include?('dataTables_empty')
end
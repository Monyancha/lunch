require 'rails_helper'
include CustomFormattingHelper
include ContactInformationHelper

RSpec.describe SecuritiesController, type: :controller do
  login_user

  describe 'requests hitting MemberBalanceService' do
    let(:member_balance_service_instance) { double('MemberBalanceServiceInstance') }

    before do
      allow(MemberBalanceService).to receive(:new).and_return(member_balance_service_instance)
    end

    describe 'GET manage' do
      let(:security) do
        security = {}
        [:cusip, :description, :custody_account_type, :eligibility, :maturity_date, :authorized_by, :current_par, :borrowing_capacity].each do |attr|
          security[attr] = double(attr.to_s, upcase: nil)
        end
        security
      end
      let(:call_action) { get :manage }
      let(:securities) { [security] }
      let(:status) { double('status') }
      before do
        allow(member_balance_service_instance).to receive(:managed_securities).and_return(securities)
        allow(security[:cusip]).to receive(:upcase).and_return(security[:cusip])
      end
      it_behaves_like 'a user required action', :get, :manage
      it_behaves_like 'a controller action with an active nav setting', :manage, :securities
      it 'renders the `manage` view' do
        call_action
        expect(response.body).to render_template('manage')
      end
      it 'raises an error if the managed_securities endpoint returns nil' do
        allow(member_balance_service_instance).to receive(:managed_securities).and_return(nil)
        expect{call_action}.to raise_error(StandardError)
      end
      it 'sets `@title`' do
        call_action
        expect(assigns[:title]).to eq(I18n.t('securities.manage.title'))
      end
      it 'assigns @securities_table_data the correct column_headings' do
        call_action
        expect(assigns[:securities_table_data][:column_headings]).to eq([{value: 'check_all', type: :checkbox, name: 'check_all'}, I18n.t('common_table_headings.cusip'), I18n.t('common_table_headings.description'), I18n.t('common_table_headings.status'), I18n.t('securities.manage.eligibility'), I18n.t('common_table_headings.maturity_date'), I18n.t('common_table_headings.authorized_by'), fhlb_add_unit_to_table_header(I18n.t('common_table_headings.current_par'), '$'), fhlb_add_unit_to_table_header(I18n.t('global.borrowing_capacity'), '$')])
      end
      describe 'the `columns` array in each row of @securities_table_data[:rows]' do
        describe 'the checkbox object at the first index' do
          it 'has a `type` of `checkbox`' do
            call_action
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][0][:type]).to eq(:checkbox)
            end
          end
          it 'has a `name` of `securities[]`' do
            call_action
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][0][:name]).to eq('securities[]')
            end
          end
          it 'has a `value` that is a JSON\'d string of the security' do
            call_action
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][0][:value]).to eq(security.to_json)
            end
          end
          it 'has `disabled` set to `false` if there is a cusip value' do
            call_action
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][0][:disabled]).to eq(false)
            end
          end
          it 'has `disabled` set to `true` if there is no cusip value' do
            security[:cusip] = nil
            allow(member_balance_service_instance).to receive(:managed_securities).and_return([security])
            call_action
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][0][:disabled]).to eq(true)
            end
          end
          it 'has a `data` field that includes its status' do
            allow(Security).to receive(:human_custody_account_type_to_status).with(security[:custody_account_type]).and_return(status)
            call_action
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][0][:data]).to eq({status: status})
            end
          end
        end
        [[:cusip, 1], [:description, 2], [:eligibility, 4], [:authorized_by, 6]].each do |attr_with_index|
          it "contains an object at the #{attr_with_index.last} index with the correct value for #{attr_with_index.first}" do
            call_action
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][attr_with_index.last][:value]).to eq(security[attr_with_index.first])
            end
          end
          it "contains an object at the #{attr_with_index.last} index with a value of '#{I18n.t('global.missing_value')}' when the given security has no value for #{attr_with_index.first}" do
            security[attr_with_index.first] = nil
            allow(member_balance_service_instance).to receive(:managed_securities).and_return([security])
            call_action
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][attr_with_index.last][:value]).to eq(I18n.t('global.missing_value'))
            end
          end
        end
        it 'contains an object at the 3 index with a value of the response from the `Security#human_custody_account_type_to_status` class method' do
          allow(Security).to receive(:human_custody_account_type_to_status).with(security[:custody_account_type]).and_return(status)
          call_action
          assigns[:securities_table_data][:rows].each do |row|
            expect(row[:columns][3][:value]).to eq(status)
          end
        end
        it 'contains an object at the 5 index with the correct value for :maturity_date and a type of `:date`' do
          call_action
          assigns[:securities_table_data][:rows].each do |row|
            expect(row[:columns][5][:value]).to eq(security[:maturity_date])
            expect(row[:columns][5][:type]).to eq(:date)
          end
        end
        [[:current_par, 7], [:borrowing_capacity, 8]].each do |attr_with_index|
          it "contains an object at the #{attr_with_index.last} index with the correct value for #{attr_with_index.first} and a type of `:number`" do
            call_action
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][attr_with_index.last][:value]).to eq(security[attr_with_index.first])
              expect(row[:columns][attr_with_index.last][:type]).to eq(:number)
            end
          end
        end
      end
      it 'sets @securities_table_data[:filter]' do
        filter = {
          name: 'securities-status-filter',
          data: [
            {
              text: I18n.t('securities.manage.safekept'),
              value: 'Safekept'
            },
            {
              text: I18n.t('securities.manage.pledged'),
              value: 'Pledged'
            },
            {
              text: I18n.t('securities.manage.all'),
              value: 'all',
              active: true
            }
          ]
        }
        call_action
        expect(assigns[:securities_table_data][:filter]).to eq(filter)
      end
    end
  end

  describe 'GET `requests`' do
    let(:authorized_requests) { [] }
    let(:awaiting_authorization_requests) { [] }
    let(:securities_requests_service) { double(SecuritiesRequestService, authorized: authorized_requests, awaiting_authorization: awaiting_authorization_requests) }
    let(:call_action) { get :requests }
    before do
      allow(SecuritiesRequestService).to receive(:new).and_return(securities_requests_service)
    end

    it_behaves_like 'a user required action', :get, :requests
    it_behaves_like 'a controller action with an active nav setting', :requests, :securities

    it 'renders the `requests` view' do
      call_action
      expect(response.body).to render_template('requests')
    end
    it 'sets `@title`' do
      call_action
      expect(assigns[:title]).to eq(I18n.t('securities.requests.title'))
    end
    it 'raises an error if the `authorized` securities request endpoint returns nil' do
      allow(securities_requests_service).to receive(:authorized).and_return(nil)
      expect{call_action}.to raise_error(/SecuritiesController#requests has encountered nil/i)
    end
    it 'raises an error if the `awaiting_authorization` securities request endpoint returns nil' do
      allow(securities_requests_service).to receive(:awaiting_authorization).and_return(nil)
      expect{call_action}.to raise_error(/SecuritiesController#requests has encountered nil/i)
    end
    it 'fetches the list of authorized securities requests from the service' do
      expect(securities_requests_service).to receive(:authorized)
      call_action
    end
    it 'fetches the list of securities requests awaiting authorization from the service' do
      expect(securities_requests_service).to receive(:awaiting_authorization)
      call_action
    end
    describe '`@authorized_requests_table`' do
      it 'builds the column headers' do
        call_action
        expect(assigns[:authorized_requests_table][:column_headings]).to eq([
          I18n.t('securities.requests.columns.request_id'),
          I18n.t('common_table_headings.description'),
          I18n.t('common_table_headings.authorized_by'),
          I18n.t('securities.requests.columns.authorization_date'),
          I18n.t('common_table_headings.settlement_date'),
          I18n.t('global.actions')
        ])
      end
      it 'builds a row for each entry in the `authorized` requests' do
        3.times do
          authorized_requests << {
            request_id: double('Request ID'),
            authorized_by: double('Authorized By'),
            authorized_date: double('Authorized Date'),
            settle_date: double('Settlement Date'),
            form_type: double('Form Type')
          }
        end
        rows = authorized_requests.collect do |request|
          description = double('A Description')
          allow(subject).to receive(:form_type_to_description).with(request[:form_type]).and_return(description)
          {
            columns: [
              {value: request[:request_id]},
              {value: description},
              {value: request[:authorized_by]},
              {value: request[:authorized_date], type: :date},
              {value: request[:settle_date], type: :date},
              {value: [[I18n.t('global.view'), '#']], type: :actions}
            ]
          }
        end
        call_action
        expect(assigns[:authorized_requests_table][:rows]).to eq(rows)
      end
    end
    describe '`@awaiting_authorization_requests_table`' do
      it 'builds the column headers' do
        call_action
        expect(assigns[:awaiting_authorization_requests_table][:column_headings]).to eq([
          I18n.t('securities.requests.columns.request_id'),
          I18n.t('common_table_headings.description'),
          I18n.t('securities.requests.columns.submitted_by'),
          I18n.t('securities.requests.columns.submitted_date'),
          I18n.t('common_table_headings.settlement_date'),
          I18n.t('global.actions')
        ])
      end
      it 'builds a row for each entry in the `awaiting_authorization` requests' do
        3.times do
          awaiting_authorization_requests << {
            request_id: double('Request ID'),
            submitted_by: double('Submitted By'),
            submitted_date: double('Submitted Date'),
            settle_date: double('Settlement Date'),
            form_type: double('Form Type')
          }
        end
        rows = awaiting_authorization_requests.collect do |request|
          description = double('A Description')
          allow(subject).to receive(:form_type_to_description).with(request[:form_type]).and_return(description)
          {
            columns: [
              {value: request[:request_id]},
              {value: description},
              {value: request[:submitted_by]},
              {value: request[:submitted_date], type: :date},
              {value: request[:settle_date], type: :date},
              {value: [[I18n.t('securities.requests.actions.authorize'), '#']], type: :actions}
            ]
          }
        end
        call_action
        expect(assigns[:awaiting_authorization_requests_table][:rows]).to eq(rows)
      end
    end
  end

  describe 'POST edit_release' do
    let(:call_action) { post :edit_release }

    it_behaves_like 'a user required action', :post, :edit_release
    it_behaves_like 'a controller action with an active nav setting', :edit_release, :securities
    it 'sets `@title`' do
      call_action
      expect(assigns[:title]).to eq(I18n.t('securities.release.title'))
    end
    it 'renders its view' do
      call_action
      expect(response.body).to render_template('edit_release')
    end
    it 'calls `populate_view_variables`' do
      expect(controller).to receive(:populate_view_variables)
      call_action
    end
  end

  describe 'GET edit_safekeep' do
    let(:securities_release_request) { double(SecuritiesReleaseRequest,
                                              :settlement_date => Time.zone.now,
                                              :trade_date => Time.zone.now,
                                              :securities => {} ) }
    let(:unpledged_account_number) { rand(999..9999) }
    let(:member_service_instance) { double('MembersService') }
    let(:member_details) { { 'unpledged_account_number' => rand(999..9999) } }
    let(:call_action) { get :edit_safekeep }

    it_behaves_like 'a user required action', :get, :edit_safekeep
    it_behaves_like 'a controller action with an active nav setting', :edit_safekeep, :securities

    before do
      allow(MembersService).to receive(:new).with(request).and_return(member_service_instance)
      allow(member_service_instance).to receive(:member).with(anything).and_return(member_details)
    end

    it 'sets `@title`' do
      call_action
      expect(assigns[:title]).to eq(I18n.t('securities.release.safekeep.title'))
    end
    it 'gets the `unpledged_account_number` from the `MembersService` and assigns to `@securities_release_request.account_number`' do
      controller.instance_variable_set(:@securities_release_request, securities_release_request)
      expect(securities_release_request).to receive(:account_number=).with(member_details['unpledged_account_number'])
      call_action
    end
    it 'renders its view' do
      call_action
      expect(response.body).to render_template('edit_safekeep')
    end
  end

  describe 'POST download_release' do
    let(:security) { instance_double(Security) }
    let(:security_1) {{
      "cusip" => SecureRandom.hex,
      "description" => SecureRandom.hex
    }}
    let(:security_2) {{
      "cusip" => SecureRandom.hex,
      "description" => SecureRandom.hex
    }}
    let(:securities) { [security_1, security_2] }
    let(:call_action) { post :download_release, securities: securities.to_json }

    before do
      allow(controller).to receive(:populate_securities_table_data_view_variable)
    end

    it_behaves_like 'a user required action', :post, :download_release
    it 'builds `Security` instances from the POSTed array of json objects' do
      expect(Security).to receive(:from_hash).with(securities[0]).ordered
      expect(Security).to receive(:from_hash).with(securities[1]).ordered
      call_action
    end
    it 'calls `populate_securities_table_data_view_variable` with the securities' do
      allow(Security).to receive(:from_hash).and_return(security)
      expect(controller).to receive(:populate_securities_table_data_view_variable).with([security, security])
      call_action
    end
    it 'responds with an xlsx file' do
      call_action
      expect(response.headers['Content-Disposition']).to eq('attachment; filename="securities.xlsx"')
    end
  end

  describe 'POST upload_release' do
    uploaded_file = excel_fixture_file_upload('sample-securities-upload.xlsx')
    headerless_file = excel_fixture_file_upload('sample-securities-upload-headerless.xlsx')
    let(:security) { instance_double(Security) }
    let(:sample_securities_upload_array) { [security,security,security,security,security] }
    let(:html_response_string) { SecureRandom.hex }
    let(:form_fields_html_response_string) { SecureRandom.hex }
    let(:call_action) { post :upload_release, file: uploaded_file }
    let(:parsed_response_body) { call_action; JSON.parse(response.body).with_indifferent_access }
    let(:cusip) { SecureRandom.hex }
    let(:description) { SecureRandom.hex }
    let(:original_par) { rand(1000..1000000) }
    let(:payment_amount) { rand(1000..1000000) }
    let(:securities_rows) {[
      ['cusip', 'description', 'original par', 'settlement amount'],
      [cusip, description, original_par, payment_amount]
    ]}
    let(:securities_rows_padding) {[
      [],
      [],
      [nil, nil, 'cusip', 'description', 'original par', 'settlement amount'],
      [nil, nil, cusip, description, original_par, payment_amount]
    ]}

    before do
      allow(controller).to receive(:populate_securities_table_data_view_variable)
      allow(controller).to receive(:render_to_string)
      allow(Security).to receive(:from_hash).and_return(security)
    end

    it_behaves_like 'a user required action', :post, :upload_release
    it 'succeeds' do
      call_action
      expect(response.status).to eq(200)
    end
    it 'renders the view to a string with `layout` set to false' do
      expect(controller).to receive(:render_to_string).with(layout: false)
      call_action
    end
    it 'calls `populate_securities_table_data_view_variable` with the securities' do
      expect(controller).to receive(:populate_securities_table_data_view_variable).with(sample_securities_upload_array)
      call_action
    end
    it 'begins parsing data in the row and cell underneath the `cusip` header cell' do
      allow(Roo::Spreadsheet).to receive(:open).and_return(securities_rows_padding)
      expect(Security).to receive(:from_hash).with({
        cusip: cusip,
        description: description,
        original_par: original_par,
        payment_amount: payment_amount
      }).and_return(security)
      call_action
    end
    it 'returns a json object with `html`' do
      allow(controller).to receive(:render_to_string).with(layout: false).and_return(html_response_string)
      call_action
      expect(parsed_response_body[:html]).to eq(html_response_string)
    end
    it 'returns a json object with `form_data` equal to the JSONed securities' do
      call_action
      expect(parsed_response_body[:form_data]).to eq(sample_securities_upload_array.to_json)
    end
    it 'returns a json object with a nil value for `error`' do
      call_action
      expect(parsed_response_body[:error]).to be_nil
    end
    describe 'when the uploaded file does not contain a header row with `CUSIP` as a value' do
      let(:call_action) { post :upload_release, file: headerless_file }
      it 'returns a 400' do
        call_action
        expect(response.status).to eq(400)
      end
      it 'renders a json object with a nil value for `html`' do
        call_action
        expect(parsed_response_body[:html]).to be_nil
      end
      it 'renders a json object with an error message' do
        call_action
        expect(parsed_response_body[:error]).to eq('No header row found')
      end
    end
    describe 'when the MIME type of the uploaded file is not in the list of accepted types' do
      let(:incorrect_mime_type) { fixture_file_upload('sample-securities-upload.xlsx', 'text/html') }
      let(:call_action) { post :upload_release, file: incorrect_mime_type }
      let(:parsed_response_body) { call_action; JSON.parse(response.body).with_indifferent_access }
      it 'returns a 415' do
        call_action
        expect(response.status).to eq(415)
      end
      it 'renders a json object with an error message' do
        call_action
        expect(parsed_response_body[:error]).to eq('Uploaded file has unsupported MIME type: text/html')
      end
      it 'renders a json object with a nil value for `html`' do
        call_action
        expect(parsed_response_body[:html]).to be_nil
      end
      it 'renders a json object with a nil value for `form_data`' do
        call_action
        expect(parsed_response_body[:form_data]).to be_nil
      end
    end
  end

  describe 'POST submit_release' do
    let(:member_id) { rand(1000..99999) }
    let(:securities_release_request_param) { {'transaction_code' => "#{instance_double(String)}"} }
    let(:securities_request_service) { instance_double(SecuritiesRequestService, submit_release_for_authorization: true) }
    let(:securities_release_request) { instance_double(SecuritiesReleaseRequest, :valid? => true) }
    let(:call_action) { post :submit_release, securities_release_request: securities_release_request_param }

    before do
      allow(controller).to receive(:current_member_id).and_return(member_id)
      allow(controller).to receive(:populate_view_variables)
      allow(SecuritiesRequestService).to receive(:new).and_return(securities_request_service)
      allow(SecuritiesReleaseRequest).to receive(:from_hash).and_return(securities_release_request)
    end
    it 'builds a SecuritiesReleaseRequest instance with the `securities_release_request` params' do
      expect(SecuritiesReleaseRequest).to receive(:from_hash).with(securities_release_request_param)
      call_action
    end
    it 'sets @securities_release_request' do
      call_action
      expect(assigns[:securities_release_request]).to eq(securities_release_request)
    end
    describe 'when the securities_release_request is valid' do
      it 'creates a new instance of SecuritiesRequestService with the `current_member_id`' do
        expect(SecuritiesRequestService).to receive(:new).with(member_id, anything).and_return(securities_request_service)
        call_action
      end
      it 'creates a new instance of SecuritiesRequestService with the current request' do
        expect(SecuritiesRequestService).to receive(:new).with(anything, request).and_return(securities_request_service)
        call_action
      end
      it 'calls `submit_release_for_authorization` on the SecuritiesRequestService instance with the `securities_release_request`' do
        expect(securities_request_service).to receive(:submit_release_for_authorization).with(securities_release_request, anything).and_return(true)
        call_action
      end
      it 'calls `submit_release_for_authorization` on the SecuritiesRequestService instance with the current_user' do
        expect(securities_request_service).to receive(:submit_release_for_authorization).with(anything, controller.current_user).and_return(true)
        call_action
      end
      describe 'when the service object returns true' do
        it 'redirects to the `securities_success_url`' do
          expect(call_action).to redirect_to(securities_success_url)
        end
      end
      describe 'when the service object returns nil' do
        let(:error_message) { SecureRandom.hex }
        let(:error) { instance_double(RestClient::Exception, http_body: error_message) }

        before do
          allow(securities_request_service).to receive(:submit_release_for_authorization).and_return(nil)
        end
        it 'calls `populate_view_variables` with a specific `mapi_endpoint` error when the error handler is invoked' do
          allow(securities_request_service).to receive(:submit_release_for_authorization).and_yield(error)
          expect(controller).to receive(:populate_view_variables).with({mapi_endpoint: [error_message]})
          call_action
        end
        it 'calls `populate_view_variables` with an `mapi_endpoint` error' do
          expect(controller).to receive(:populate_view_variables).with({mapi_endpoint: ['SecuritiesRequestService#submit_release_for_authorization has returned nil']})
          call_action
        end
        it 'renders the `edit_release` view' do
          call_action
          expect(response.body).to render_template(:edit_release)
        end
      end
    end
    describe 'when the securities_release_request is invalid' do
      let(:error_messages) { instance_double(Hash) }
      let(:errors) { instance_double(ActiveModel::Errors, messages: error_messages) }
      before do
        allow(securities_release_request).to receive(:valid?).and_return(false)
        allow(securities_release_request).to receive(:errors).and_return(errors)
      end

      it 'calls `populate_view_variables` with the securities_release_request validation errors' do
        expect(controller).to receive(:populate_view_variables).with(error_messages)
        call_action
      end
      it 'renders the `edit_release` view' do
        call_action
        expect(response.body).to render_template(:edit_release)
      end
    end
  end

  describe 'GET `submit_release_success`' do
    let(:member_service_instance) {double('MembersService')}
    let(:user_no_roles) {{display_name: 'User With No Roles', roles: [], surname: 'With No Roles', given_name: 'User'}}
    let(:user_etransact) {{display_name: 'Etransact User', roles: [User::Roles::ETRANSACT_SIGNER], surname: 'User', given_name: 'Etransact'}}
    let(:user_a) { {display_name: 'R&A User', roles: [User::Roles::SIGNER_MANAGER], given_name: 'R&A', surname: 'User'} }
    let(:user_b) { {display_name: 'Collateral User', roles: [User::Roles::COLLATERAL_SIGNER], given_name: 'Collateral', surname: 'User'} }
    let(:user_c) { {display_name: 'Securities User', roles: [User::Roles::SECURITIES_SIGNER], given_name: 'Securities', surname: 'User'} }
    let(:user_d) { {display_name: 'No Surname', roles: [User::Roles::WIRE_SIGNER], given_name: 'No', surname: nil} }
    let(:user_e) { {display_name: 'No Given Name', roles: [User::Roles::WIRE_SIGNER], given_name: nil, surname: 'Given'} }
    let(:user_f) { {display_name: 'Entire Authority User', roles: [User::Roles::SIGNER_ENTIRE_AUTHORITY], given_name: 'Entire Authority', surname: 'User'} }
    let(:signers_and_users) {[user_no_roles, user_etransact, user_a, user_b, user_c, user_d, user_e, user_f]}
    let(:call_action) { get :submit_release_success }
    before do
      allow(MembersService).to receive(:new).and_return(member_service_instance)
      allow(member_service_instance).to receive(:signers_and_users).and_return(signers_and_users)
    end

    it_behaves_like 'a user required action', :get, :submit_release_success

    it 'renders the `submit_release_success` view' do
      call_action
      expect(response.body).to render_template('submit_release_success')
    end
    it 'sets `@title`' do
      call_action
      expect(assigns[:title]).to eq(I18n.t('securities.success.title'))
    end
    it 'sets `@authorized_user_data` to a list of users with securities authority' do
      call_action
      expect(assigns[:authorized_user_data]).to eq([user_c])
    end
    it 'sets `@authorized_user_data` to [] if no users are found' do
      allow(member_service_instance).to receive(:signers_and_users).and_return([])
      call_action
      expect(assigns[:authorized_user_data]).to eq([])
    end

  end

  describe 'private methods' do
    describe '`form_type_to_description`' do
      {
        'pledge_release' => 'securities.requests.form_descriptions.release',
        'safekept_release' => 'securities.requests.form_descriptions.release',
        'pledge_intake' => 'securities.requests.form_descriptions.pledge',
        'safekept_intake' => 'securities.requests.form_descriptions.safekept'
      }.each do |form_type, description_key|
        it "returns the localization value for `#{description_key}` when passed `#{form_type}`" do
          expect(controller.send(:form_type_to_description, form_type)).to eq(I18n.t(description_key))
        end
      end
      it 'returns the localization value for `global.missing_value` when passed an unknown form type' do
        expect(controller.send(:form_type_to_description, double(String))).to eq(I18n.t('global.missing_value'))
      end
    end

    describe '`populate_view_variables`' do
      let(:member_id) { rand(1000..99999) }
      let(:security) { {
        cusip: SecureRandom.hex,
        description: SecureRandom.hex,
        original_par: SecureRandom.hex
      } }
      let(:securities) { [instance_double(Security)] }
      let(:securities_release_request) { instance_double(SecuritiesReleaseRequest, securities: securities, :securities= => nil, trade_date: nil, :trade_date= => nil, settlement_date: nil, :settlement_date= => nil) }
      let(:call_action) { controller.send(:populate_view_variables) }
      let(:errors) { instance_double(Hash) }

      before do
        allow(controller).to receive(:current_member_id).and_return(member_id)
        allow(SecuritiesReleaseRequest).to receive(:new).and_return(securities_release_request)
        allow(controller).to receive(:populate_securities_table_data_view_variable)
      end

      it 'calls `human_submit_release_error_messages` if errors are present' do
        expect(controller).to receive(:human_submit_release_error_messages).with(errors).and_return(errors)
        controller.send(:populate_view_variables, errors)
      end
      it 'sets `@errors` if errors are passed' do
        allow(controller).to receive(:human_submit_release_error_messages).and_return(errors)
        controller.send(:populate_view_variables, errors)
        expect(assigns[:errors]).to eq(errors)
      end
      it 'sets `@transaction_code_dropdown`' do
        transaction_code_dropdown = [
          [I18n.t('securities.release.transaction_code.standard'), SecuritiesReleaseRequest::TRANSACTION_CODES[:standard]],
          [I18n.t('securities.release.transaction_code.repo'), SecuritiesReleaseRequest::TRANSACTION_CODES[:repo]]
        ]
        call_action
        expect(assigns[:transaction_code_dropdown]).to eq(transaction_code_dropdown)
      end
      it 'sets `@settlement_type_dropdown`' do
        settlement_type_dropdown = [
          [I18n.t('securities.release.settlement_type.free'), SecuritiesReleaseRequest::SETTLEMENT_TYPES[:free]],
          [I18n.t('securities.release.settlement_type.vs_payment'), SecuritiesReleaseRequest::SETTLEMENT_TYPES[:payment]]
        ]
        call_action
        expect(assigns[:settlement_type_dropdown]).to eq(settlement_type_dropdown)
      end
      it 'sets `@delivery_instructions_dropdown`' do
        delivery_instructions_dropdown = [
          [I18n.t('securities.release.delivery_instructions.dtc'), SecuritiesReleaseRequest::DELIVERY_TYPES[:dtc]],
          [I18n.t('securities.release.delivery_instructions.fed'), SecuritiesReleaseRequest::DELIVERY_TYPES[:fed]],
          [I18n.t('securities.release.delivery_instructions.mutual_fund'), SecuritiesReleaseRequest::DELIVERY_TYPES[:mutual_fund]],
          [I18n.t('securities.release.delivery_instructions.physical_securities'), SecuritiesReleaseRequest::DELIVERY_TYPES[:physical_securities]]
        ]
        call_action
        expect(assigns[:delivery_instructions_dropdown]).to eq(delivery_instructions_dropdown)
      end
      it 'sets `@securities_release_request`' do
        call_action
        expect(assigns[:securities_release_request]).to eq(securities_release_request)
      end
      it 'creates a new instance of SecuritiesReleaseRequest if `@securities_release_request` not already set' do
        expect(SecuritiesReleaseRequest).to receive(:new).and_return(securities_release_request)
        call_action
      end
      it 'does not create a new instance of SecuritiesReleaseRequest if `securities_release_request` is already set' do
        controller.instance_variable_set(:@securities_release_request, securities_release_request)
        expect(SecuritiesReleaseRequest).not_to receive(:new)
        call_action
      end
      it 'sets `securities_release_request.securities` to the `securities` param if it is present' do
        controller.params = ActionController::Parameters.new({securities: securities})
        expect(securities_release_request).to receive(:securities=).with(securities)
        call_action
      end
      it 'does not set `securities_release_request.securities` if the `securities` param is not present' do
        expect(securities_release_request).not_to receive(:securities=)
        call_action
      end
      it 'sets `securities_release_request.trade_date` to today if there is not already a trade date' do
        expect(securities_release_request).to receive(:trade_date=).with(Time.zone.today)
        call_action
      end
      it 'does not set `securities_release_request.trade_date` if there is already a trade date' do
        allow(securities_release_request).to receive(:trade_date).and_return(instance_double(Date))
        expect(securities_release_request).not_to receive(:trade_date=)
        call_action
      end
      it 'sets `securities_release_request.settlement_date` to today if there is not already a settlment date' do
        expect(securities_release_request).to receive(:settlement_date=).with(Time.zone.today)
        call_action
      end
      it 'does not set `securities_release_request.settlement_date` if there is already a settlment date' do
        allow(securities_release_request).to receive(:settlement_date).and_return(instance_double(Date))
        expect(securities_release_request).not_to receive(:settlement_date=)
        call_action
      end
      it 'calls `populate_securities_table_data_view_variable` with the securities' do
        expect(controller).to receive(:populate_securities_table_data_view_variable).with(securities)
        call_action
      end
    end

    describe '`populate_securities_table_data_view_variable`' do
      headings = [
        I18n.t('common_table_headings.cusip'),
        I18n.t('common_table_headings.description'),
        fhlb_add_unit_to_table_header(I18n.t('common_table_headings.original_par'), '$'),
        I18n.t('securities.release.settlement_amount', unit: fhlb_add_unit_to_table_header('', '$'), footnote_marker: fhlb_footnote_marker)
      ]
      let(:securities) { [FactoryGirl.build(:security)] }
      let(:call_method) { controller.send(:populate_securities_table_data_view_variable, securities) }

      it 'sets `column_headings`' do
        call_method
        expect(assigns[:securities_table_data][:column_headings]).to eq(headings)
      end
      it 'contains rows of columns that have a `cusip` value' do
        call_method
        expect(assigns[:securities_table_data][:rows].length).to be > 0
        assigns[:securities_table_data][:rows].each do |row|
          expect(row[:columns].first[:value]).to eq(securities.first.cusip)
        end
      end
      it "contains rows of columns that have a `cusip` value equal to `#{I18n.t('global.missing_value')}` if the security has no cusip value" do
        securities = [FactoryGirl.build(:security, cusip: nil)]
        controller.send(:populate_securities_table_data_view_variable, securities)
        expect(assigns[:securities_table_data][:rows].length).to be > 0
        assigns[:securities_table_data][:rows].each do |row|
          expect(row[:columns].first[:value]).to eq(I18n.t('global.missing_value'))
        end
      end
      it 'contains rows of columns that have a `description` value' do
        call_method
        expect(assigns[:securities_table_data][:rows].length).to be > 0
        assigns[:securities_table_data][:rows].each do |row|
          expect(row[:columns][1][:value]).to eq(securities.first.description)
        end
      end
      it "contains rows of columns that have a `description` value equal to `#{I18n.t('global.missing_value')}` if the security has no description value" do
        securities = [FactoryGirl.build(:security, description: nil)]
        controller.send(:populate_securities_table_data_view_variable, securities)
        expect(assigns[:securities_table_data][:rows].length).to be > 0
        assigns[:securities_table_data][:rows].each do |row|
          expect(row[:columns][1][:value]).to eq(I18n.t('global.missing_value'))
        end
      end
      it 'contains rows of columns that have an `original_par` value' do
        call_method
        expect(assigns[:securities_table_data][:rows].length).to be > 0
        assigns[:securities_table_data][:rows].each do |row|
          expect(row[:columns][2][:value]).to eq(securities.first.original_par)
        end
      end
      it 'contains rows of columns whose `original_par` value has a type of `number`' do
        call_method
        expect(assigns[:securities_table_data][:rows].length).to be > 0
        assigns[:securities_table_data][:rows].each do |row|
          expect(row[:columns][2][:type]).to eq(:number)
        end
      end
      it 'contains rows of columns whose last member has a `payment_amount` value' do
        call_method
        expect(assigns[:securities_table_data][:rows].length).to be > 0
        assigns[:securities_table_data][:rows].each do |row|
          expect(row[:columns].last[:value]).to eq(securities.first.payment_amount)
        end
      end
      it 'contains rows of columns whose last member has a type of `:number`' do
        call_method
        expect(assigns[:securities_table_data][:rows].length).to be > 0
        assigns[:securities_table_data][:rows].each do |row|
          expect(row[:columns].last[:type]).to eq(:number)
        end
      end
      it 'contains an empty array for rows if no securities are passed in' do
        controller.send(:populate_securities_table_data_view_variable, nil)
        expect(assigns[:securities_table_data][:rows]).to eq([])
      end
    end

    describe '`human_submit_release_error_messages`' do
      it 'returns a generic message for errors it is provided with' do
        errors = {
          foo: ['some error message']
        }
        human_errors = subject.send(:human_submit_release_error_messages, errors)
        expect(human_errors[:foo]).to eq(I18n.t('securities.release.edit.generic_error', phone_number: securities_services_phone_number))
      end
    end
  end
end
require 'rails_helper'
include CustomFormattingHelper
include ContactInformationHelper
include ActionView::Helpers::TextHelper

RSpec.describe SecuritiesController, type: :controller do
  login_user
  let(:member_id) { rand(1000..99999) }
  before { allow(controller).to receive(:current_member_id).and_return(member_id) }

  shared_examples 'an action that sets its contact info by kind' do |kind|
    it "calls `populate_contact_info_by_kind` with `#{kind}`" do
      expect(controller).to receive(:populate_contact_info_by_kind).with(kind)
      call_action
    end
  end
  shared_examples 'an action that sets its title by kind' do |kind|
    it "calls `set_edit_title_by_kind` with `#{kind}`" do
      expect(controller).to receive(:set_edit_title_by_kind).with(kind)
      call_action
    end
  end

  describe 'requests hitting MemberBalanceService' do
    let(:member_balance_service_instance) { double('MemberBalanceServiceInstance') }

    before do
      allow(MemberBalanceService).to receive(:new).and_return(member_balance_service_instance)
    end

    describe 'GET manage' do
      let(:members_service_instance) { double("A Member Service") }
      before do
        allow(MembersService).to receive(:new).and_return(members_service_instance)
        allow(members_service_instance).to receive(:report_disabled?).and_return(false)
      end

      let(:security) do
        security = {}
        [:cusip, :description, :custody_account_type, :maturity_date, :current_par].each do |attr|
          security[attr] = double(attr.to_s, upcase: nil)
        end
        security[:reg_id] = reg_id
        security
      end
      let(:call_action) { get :manage }
      let(:securities) { [security] }
      let(:status) { double('status') }
      let(:reg_id) { double('reg_id') }
      let(:deliver_to) { double('deliver_to') }
      let(:column_headings) { [
        { value: 'check_all', type: :checkbox, name: 'check_all', :sortable=>false},
        { title: I18n.t('common_table_headings.cusip'), :sortable=>true},
        { title: I18n.t('common_table_headings.description'), :sortable=>true},
        { title: I18n.t('common_table_headings.status'), :sortable=>true},
        { title: I18n.t('common_table_headings.maturity_date'), :sortable=>true},
        { title: fhlb_add_unit_to_table_header(I18n.t('common_table_headings.current_par'), '$'), :sortable=>true}
      ]}
      let(:column_headings_delivery_method_enabled) { [
        { value: 'check_all', type: :checkbox, name: 'check_all', :sortable=>false},
        { title: I18n.t('common_table_headings.cusip'), :sortable=>true},
        { title: I18n.t('common_table_headings.description'), :sortable=>true},
        { title: I18n.t('common_table_headings.status'), :sortable=>true},
        { title: I18n.t('securities.manage.delivery'), :sortable=>true},
        { title: I18n.t('common_table_headings.maturity_date'), :sortable=>true},
        { title: fhlb_add_unit_to_table_header(I18n.t('common_table_headings.current_par'), '$'), :sortable=>true}
      ]}
      before do
        allow(member_balance_service_instance).to receive(:managed_securities).and_return(securities)
        allow(security[:cusip]).to receive(:upcase).and_return(security[:cusip])
        allow(security[:description]).to receive(:gsub!).and_return(security[:description])
        allow(security[:description]).to receive(:truncate).and_return(security[:description])
        allow(controller).to receive(:feature_enabled?).and_call_original
        allow(controller).to receive(:feature_enabled?).with('securities-delivery-method').and_return(false)
        stub_const('SecuritiesController::DELIVER_TO_MAPPING', { reg_id => deliver_to })
      end
      it_behaves_like 'a user required action', :get, :manage
      it_behaves_like 'a controller action with an active nav setting', :manage, :securities
      it 'renders the `manage` view' do
        call_action
        expect(response.body).to render_template('manage')
      end
      describe 'sorted securities' do
        let(:security1) { { cusip: 'B',   custody_account_type: 'P' } }
        let(:security2) { { cusip: 'C',   custody_account_type: 'U' } }
        let(:security3) { { cusip: 'A',   custody_account_type: 'P' } }
        let(:securities_array) { [ security1, security2, security3 ] }
        let(:sorted_securities) { [ security3, security1, security2 ] }
        before do
          allow(member_balance_service_instance).to receive(:managed_securities).and_return(securities_array)
        end
        it 'sorts the securities first by `custody_account_type`, then by `cusip`' do
          call_action
          expect(securities_array.map { |s| { cusip: s.cusip, custody_account_type: s.custody_account_type } }).to eq(sorted_securities)
        end
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
        expect(assigns[:securities_table_data][:column_headings]).to eq(column_headings)
      end
      describe 'the `columns` array in each row of @securities_table_data[:rows]' do
        it 'should contain a `column_headings` array containing hashes with a `sortable` key' do
          call_action
          assigns[:securities_table_data][:column_headings].each {|heading| expect(heading[:sortable]).to eq(true) unless heading[:name].eql?('check_all')}
        end
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
              expect(JSON.parse(row[:columns][0][:value])).to eq(JSON.parse(security.to_json))
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
        [[:cusip, 1], [:description, 2]].each do |attr_with_index|
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
        it 'contains an object at the 4 index with the correct value for :maturity_date and a type of `:date`' do
          call_action
          assigns[:securities_table_data][:rows].each do |row|
            expect(row[:columns][4][:value]).to eq(security[:maturity_date])
            expect(row[:columns][4][:type]).to eq(:date)
          end
        end
        [[:current_par, 5]].each do |attr_with_index|
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
      describe 'when the `securities-delivery-method` feature is enabled' do
        before do
          allow(controller).to receive(:feature_enabled?).and_call_original
          allow(controller).to receive(:feature_enabled?).with('securities-delivery-method').and_return(true)
        end
        it 'assigns @securities_table_data the correct column_headings' do
          call_action
          expect(assigns[:securities_table_data][:column_headings]).to eq(column_headings_delivery_method_enabled)
        end
        it 'contains an object at the 4 index with the correct value for delivery method' do
          call_action
          assigns[:securities_table_data][:rows].each do |row|
            expect(row[:columns][4][:value]).to eq(deliver_to)
          end
        end
        it "contains an object at the 4 index with a value of '#{I18n.t('global.missing_value')}' when the given security has no value for delivery method" do
          security[:reg_id] = nil
          allow(member_balance_service_instance).to receive(:managed_securities).and_return([security])
          call_action
          assigns[:securities_table_data][:rows].each do |row|
            expect(row[:columns][4][:value]).to eq(I18n.t('global.missing_value'))
          end
        end
      end

      describe 'when the `Manage Securities` user interface element has been disabled' do
        before do
          allow(MembersService).to receive(:new).and_return(members_service_instance)
          allow(members_service_instance).to receive(:report_disabled?).and_return(true)
        end
        it 'sets the `@manage_securities_disabled` instance variable to true' do
          call_action
          expect(assigns[:manage_securities_disabled]).to eq(true)
        end
      end
    end
  end

  describe 'GET `requests`' do
    let(:authorized_requests) { instance_double(Array, :sort! => nil, :collect => nil, :<< => nil) }
    let(:awaiting_authorization_requests) { [] }
    let(:securities_requests_service) { double(SecuritiesRequestService, authorized: authorized_requests, awaiting_authorization: awaiting_authorization_requests) }
    let(:call_action) { get :requests }
    before do
      allow(SecuritiesRequestService).to receive(:new).and_return(securities_requests_service)
    end

    allow_policy :security, :authorize_collateral?

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
            request_id: double('Request ID', to_s: SecureRandom.hex),
            authorized_by: double('Authorized By'),
            authorized_date: double('Authorized Date'),
            settle_date: double('Settlement Date'),
            kind: double('Kind')
          }
        end
        rows = authorized_requests.collect do |request|
          description = double('A Description')
          allow(subject).to receive(:kind_to_description).with(request[:kind]).and_return(description)
          {
            columns: [
              {value: request[:request_id]},
              {value: description},
              {value: request[:authorized_by]},
              {value: request[:authorized_date], type: :date},
              {value: request[:settle_date], type: :date},
              {value: [[I18n.t('global.view'),
                securities_release_generate_authorized_request_path(request_id: request[:request_id],
                  kind: request[:kind])]],
                  type: :actions}
            ]
          }
        end
        call_action
        expect(assigns[:authorized_requests_table][:rows]).to eq(rows)
      end
    end
    describe 'sorted securities' do
      let(:request1) { {request_id: 22222} }
      let(:request2) { {request_id: 44444} }
      let(:request3) { {request_id: 33333} }
      let(:requests_array) { [ request1, request2, request3 ] }
      let(:sorted_requests) { [ request2, request3, request1 ] }
      before do
        allow(securities_requests_service).to receive(:authorized).and_return(requests_array)
      end
      it 'sorts the authorized requests by request_id' do
        call_action
        expect(requests_array).to eq(sorted_requests)
      end
    end
    describe '`@awaiting_authorization_requests_table`' do
      deny_policy :security, :authorize_collateral?
      deny_policy :security, :authorize_securities?
      before do
        allow(subject).to receive(:is_request_collateral?).and_return(true)
      end
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
            kind: double('Kind')
          }
        end
        rows = awaiting_authorization_requests.collect do |request|
          description = double('A Description')
          allow(subject).to receive(:kind_to_description).with(request[:kind]).and_return(description)
          {
            columns: [
              {value: request[:request_id]},
              {value: description},
              {value: request[:submitted_by]},
              {value: request[:submitted_date], type: :date},
              {value: request[:settle_date], type: :date},
              {value: [I18n.t('securities.requests.actions.authorize')], type: :actions}
            ]
          }
        end
        call_action
        expect(assigns[:awaiting_authorization_requests_table][:rows]).to eq(rows)
      end
      describe 'when the `current_user` can authorize securities' do
        let(:request_id) { SecureRandom.hex }
        before do
          allow(subject).to receive(:kind_to_description)
        end
        {
          'pledge_release' => :securities_release_view_path,
          'safekept_release' => :securities_release_view_path,
          'pledge_intake' => :securities_pledge_view_path,
          'safekept_intake' => :securities_safekeep_view_path,
          'safekept_transfer' => :securities_transfer_view_path,
          'pledge_transfer' => :securities_transfer_view_path
        }.each do |kind, path_helper|
          if kind == 'safekept_intake' || kind == 'safekept_release'
            allow_policy :security, :authorize_securities?
          else
            allow_policy :security, :authorize_collateral?
          end
          it "sets the authorize action URL to `#{path_helper}` when the `kind` is `#{kind}`" do
            awaiting_authorization_requests << {
              request_id: request_id,
              kind: kind
            }
            call_action
            expect(assigns[:awaiting_authorization_requests_table][:rows].length).to be > 0
            assigns[:awaiting_authorization_requests_table][:rows].each do |row|
              expect(row[:columns].last).to eq({value: [[I18n.t('securities.requests.actions.authorize'), send(path_helper, request_id) ]], type: :actions})
            end
          end
        end
        it "sets the authorize action URL to nil when the `kind` is unknown" do
          awaiting_authorization_requests << {
            request_id: request_id,
            kind: SecureRandom.hex
          }
          call_action
          expect(assigns[:awaiting_authorization_requests_table][:rows].length).to be > 0
          assigns[:awaiting_authorization_requests_table][:rows].each do |row|
            expect(row[:columns].last).to eq({value: [[I18n.t('securities.requests.actions.authorize'), nil ]], type: :actions})
          end
        end
        it "sets the authorize action URL to nil when the `kind` is nil" do
          awaiting_authorization_requests << {
            request_id: request_id,
            kind: nil
          }
          call_action
          expect(assigns[:awaiting_authorization_requests_table][:rows].length).to be > 0
          assigns[:awaiting_authorization_requests_table][:rows].each do |row|
            expect(row[:columns].last).to eq({value: [I18n.t('securities.requests.actions.authorize')], type: :actions})
          end
        end
      end
    end
  end

  describe 'GET view_request' do
    let(:type) { SecureRandom.hex }
    let(:request_id) { SecureRandom.hex }
    let(:kind) { instance_double(Symbol) }
    let(:securities_request) { instance_double(SecuritiesRequest, kind: kind, is_collateral?: true) }
    let(:service) { instance_double(SecuritiesRequestService, submitted_request: securities_request) }
    let(:call_action) { get :view_request, request_id: request_id, type: type }

    allow_policy :security, :authorize_collateral?
    allow_policy :security, :authorize_securities?

    before do
      allow(SecuritiesRequestService).to receive(:new).and_return(service)
      allow(controller).to receive(:populate_view_variables)
      allow(controller).to receive(:type_matches_kind).and_return(true)
      allow(controller).to receive(:populate_contact_info_by_kind)
      allow(controller).to receive(:populate_form_data_by_kind)
      allow(controller).to receive(:set_edit_title_by_kind)
    end

    it_behaves_like 'a user required action', :get, :view_request, request_id: SecureRandom.hex, type: :release
    it_behaves_like 'a controller action with an active nav setting', :view_request, :securities, request_id: SecureRandom.hex, type: :release
    it_behaves_like 'an authorization required method', :get, :view_request, :security, :authorize_collateral?, request_id: SecureRandom.hex, type: :pledge

    it 'raises an exception if passed an unknown type' do
      expect{call_action}.to raise_error(ArgumentError, "Unknown request type: #{type}")
    end

    {
      release: :edit_release,
      pledge: :edit_pledge,
      safekeep: :edit_safekeep,
      transfer: :edit_transfer
    }.each do |type, view|
      describe "when the `type` is `#{type}`" do
        before do
          allow(service).to receive(:submitted_request).and_return(securities_request)
        end
        let(:call_action) { get :view_request, request_id: request_id, type: type }
        it 'raises an ActionController::RoutingError if the service object returns nil' do
          allow(service).to receive(:submitted_request).and_return(nil)
          expect{call_action}.to raise_error(ActionController::RoutingError, 'There has been an error retrieving the securities request. Check error logs.')
        end
        it 'raises an ActionController::RoutingError if the securities request kind does not match the request type param' do
          allow(controller).to receive(:type_matches_kind).and_return(false)
          expect{call_action}.to raise_error(ActionController::RoutingError, "The type specified by the `/securities/view` route does not match the @securities_request.kind. \nType: `#{type}`\nKind: `#{securities_request.kind}`")
        end
        it 'creates a new `SecuritiesRequestService` with the `current_member_id`' do
          expect(SecuritiesRequestService).to receive(:new).with(member_id, any_args).and_return(service)
          call_action
        end
        it 'creates a new `SecuritiesRequestService` with the `request`' do
          expect(SecuritiesRequestService).to receive(:new).with(anything, request).and_return(service)
          call_action
        end
        it 'calls `submitted_request` on the `SecuritiesRequestService` instance with the `request_id`' do
          expect(service).to receive(:submitted_request).with(request_id)
          call_action
        end
        it 'sets `@securities_request` to the result of `SecuritiesRequestService#request_id`' do
          call_action
          expect(assigns[:securities_request]).to eq(securities_request)
        end
        it 'calls `populate_view_variables`' do
          expect(controller).to receive(:populate_view_variables)
          call_action
        end
        it 'calls `populate_contact_info_by_kind` with its `kind`' do
          expect(controller).to receive(:populate_contact_info_by_kind).with(kind)
          call_action
        end
        it 'calls `set_edit_title_by_kind` with its `kind`' do
          expect(controller).to receive(:set_edit_title_by_kind).with(kind)
          call_action
        end
        it "renders the `#{view}` view" do
          call_action
          expect(response.body).to render_template(view)
        end
        it 'calls `populate_view_variables`' do
          expect(controller).to receive(:populate_view_variables).with(type)
          call_action
        end
      end
    end
    describe 'when the authorization policies get applied' do
      let(:call_action) { get :view_request, request_id: SecureRandom.hex, type: :pledge }

      context 'when `is_collateral?` returns `true`' do
        before do
          allow(securities_request).to receive(:is_collateral?).and_return(true)
        end

        it 'checks that the user can authorize collateral' do
          expect(subject).to receive(:authorize).with(:security, :authorize_collateral?)
          call_action
        end

        it 'does not check that the user can authorize securities' do
          expect(subject).not_to receive(:authorize).with(:security, :authorize_securities?)
          call_action
        end
      end
      context 'when `is_collateral?` returns `false`' do
        before do
          allow(securities_request).to receive(:is_collateral?).and_return(false)
        end

        it 'does not check that the user can authorize collateral' do
          expect(subject).not_to receive(:authorize).with(:security, :authorize_collateral?)
          call_action
        end

        it 'checks that the user can authorize securities' do
          expect(subject).to receive(:authorize).with(:security, :authorize_securities?)
          call_action
        end
      end
    end
  end

  context 'edit securities requests (pledged, safekept, release, transfer)' do
    let(:securities_request) { double(SecuritiesRequest,
                                              :settlement_date => Time.zone.now,
                                              :trade_date => Time.zone.now,
                                              :transaction_code => SecuritiesRequest::TRANSACTION_CODES.values[rand(0..1)],
                                              :settlement_type => SecuritiesRequest::SETTLEMENT_TYPES.values[rand(0..1)],
                                              :delivery_type => SecuritiesRequest::DELIVERY_TYPES.values[rand(0..3)],
                                              :securities => {},
                                              :pledged_account= => nil,
                                              :safekept_account= => nil,
                                              :kind= => nil) }
    let(:member_service_instance) { double('MembersService') }
    let(:member_details) {{
      'pledged_account_number' => rand(999..9999),
      'unpledged_account_number' => rand(999..9999)
    }}
    before do
      allow(MembersService).to receive(:new).with(request).and_return(member_service_instance)
      allow(SecuritiesRequest).to receive(:new).and_return(securities_request)
      allow(member_service_instance).to receive(:member).with(anything).and_return(member_details)
      allow(controller).to receive(:populate_view_variables) do
        controller.instance_variable_set(:@securities_request, securities_request)
      end
    end

    shared_examples 'an action with allowed mimetypes' do
      it 'sets `@accepted_upload_mimetypes` appropriately' do
        call_action
        expect(assigns[:accepted_upload_mimetypes]).to eq(described_class::ACCEPTED_UPLOAD_MIMETYPES.join(', '))
      end
    end

    describe 'GET edit_pledge' do
      let(:call_action) { get :edit_pledge }

      it_behaves_like 'a user required action', :get, :edit_pledge
      it_behaves_like 'a controller action with an active nav setting', :edit_pledge, :securities
      it_behaves_like 'an action that sets its contact info by kind', :pledge_intake
      it_behaves_like 'an action that sets its title by kind', :pledge_intake
      it_behaves_like 'an action with allowed mimetypes'

      it 'calls `populate_view_variables`' do
        expect(subject).to receive(:populate_view_variables).with(:pledge)
        call_action
      end
      it 'gets the `pledged_account_number` from the `MembersService` and assigns to `@securities_request.pledged_account`' do
        expect(securities_request).to receive(:pledged_account=).with(member_details['pledged_account_number'])
        call_action
      end
      it 'assigns `@securities_request.kind` a value of `:pledge_intake`' do
        expect(securities_request).to receive(:kind=).with(:pledge_intake)
        call_action
      end
      it 'renders its view' do
        call_action
        expect(response.body).to render_template('edit_pledge')
      end
    end

    describe 'GET edit_safekeep' do
      let(:call_action) { get :edit_safekeep }

      it_behaves_like 'a user required action', :get, :edit_safekeep
      it_behaves_like 'a controller action with an active nav setting', :edit_safekeep, :securities
      it_behaves_like 'an action that sets its contact info by kind', :safekept_intake
      it_behaves_like 'an action that sets its title by kind', :safekept_intake
      it_behaves_like 'an action with allowed mimetypes'

      it 'calls `populate_view_variables`' do
        expect(subject).to receive(:populate_view_variables).with(:safekeep)
        call_action
      end
      it 'gets the `unpledged_account_number` from the `MembersService` and assigns to `@securities_request.safekept_account`' do
        expect(securities_request).to receive(:safekept_account=).with(member_details['unpledged_account_number'])
        call_action
      end
      it 'assigns `@securities_request.kind` a value of `:safekept_intake`' do
        expect(securities_request).to receive(:kind=).with(:safekept_intake)
        call_action
      end
      it 'renders its view' do
        call_action
        expect(response.body).to render_template('edit_safekeep')
      end
    end

    describe 'POST edit_release' do
      let(:security) { instance_double(Security, custody_account_type: ['U', 'P'].sample) }
      let(:call_action) { post :edit_release }
      before { allow(securities_request).to receive(:securities).and_return([security]) }

      it_behaves_like 'a user required action', :post, :edit_release
      it_behaves_like 'a controller action with an active nav setting', :edit_release, :securities
      it_behaves_like 'an action with allowed mimetypes'

      it 'renders its view' do
        call_action
        expect(response.body).to render_template('edit_release')
      end
      it 'calls `populate_view_variables`' do
        expect(controller).to receive(:populate_view_variables)
        call_action
      end
      it 'raises an exception if there are no `securities` for the @security_request' do
        allow(securities_request).to receive(:securities).and_return(nil)
        expect{post :edit_release}.to raise_exception(ArgumentError, 'Securities cannot be nil')
      end
      describe 'when the `securities` have a `custody_account_type` of `U`' do
        before { allow(security).to receive(:custody_account_type).and_return('U') }
        it_behaves_like 'an action that sets its contact info by kind', :safekept_release
        it_behaves_like 'an action that sets its title by kind', :safekept_release

        it 'assigns the `@securities_request.kind` a value of `:safekept_release`' do
          expect(securities_request).to receive(:kind=).with(:safekept_release)
          call_action
        end
      end
      describe 'when the `securities` have a `custody_account_type` of `P`' do
        before { allow(security).to receive(:custody_account_type).and_return('P') }
        it_behaves_like 'an action that sets its contact info by kind', :pledge_release
        it_behaves_like 'an action that sets its title by kind', :pledge_release

        it 'assigns the `@securities_request.kind` a value of `:pledge_release`' do
          expect(securities_request).to receive(:kind=).with(:pledge_release)
          call_action
        end
      end
      describe 'when the `securities` have a `custody_account_type` that is neither `P` nor `U`' do
        before { allow(security).to receive(:custody_account_type).and_return(SecureRandom.hex) }
        it 'raises an exception' do
          expect{call_action}.to raise_error(ArgumentError, 'Unrecognized `custody_account_type` for passed security.')
        end
      end
    end

    describe 'POST edit_transfer' do
      let(:security) { instance_double(Security, custody_account_type: ['U', 'P'].sample) }
      let(:call_action) { post :edit_transfer }
      before { allow(securities_request).to receive(:securities).and_return([security]) }

      it_behaves_like 'a user required action', :post, :edit_transfer
      it_behaves_like 'a controller action with an active nav setting', :edit_transfer, :securities
      it_behaves_like 'an action with allowed mimetypes'

      it 'renders its view' do
        call_action
        expect(response.body).to render_template('edit_transfer')
      end
      it 'calls `populate_view_variables`' do
        expect(controller).to receive(:populate_view_variables)
        call_action
      end
      it 'gets the `pledged_account_number` from the `MembersService` and assigns to `@securities_request.pledged_account`' do
        expect(securities_request).to receive(:pledged_account=).with(member_details['pledged_account_number'])
        call_action
      end
      it 'gets the `unpledged_account_number` from the `MembersService` and assigns to `@securities_request.safekept_account`' do
        expect(securities_request).to receive(:safekept_account=).with(member_details['unpledged_account_number'])
        call_action
      end
      it 'raises an exception if there are no `securities` for the @security_request' do
        allow(securities_request).to receive(:securities).and_return(nil)
        expect{post :edit_transfer}.to raise_error(NoMethodError)
      end
      describe 'when the `securities` have a `custody_account_type` of `U`' do
        before { allow(security).to receive(:custody_account_type).and_return('U') }
        it_behaves_like 'an action that sets its contact info by kind', :pledge_transfer
        it_behaves_like 'an action that sets its title by kind', :pledge_transfer

        it 'assigns the `@securities_request.kind` a value of `:pledge_transfer`' do
          expect(securities_request).to receive(:kind=).with(:pledge_transfer)
          call_action
        end
      end
      describe 'when the `securities` have a `custody_account_type` of `P`' do
        before { allow(security).to receive(:custody_account_type).and_return('P') }
        it_behaves_like 'an action that sets its contact info by kind', :safekept_transfer
        it_behaves_like 'an action that sets its title by kind', :safekept_transfer

        it 'assigns the `@securities_request.kind` a value of `:safekept_transfer`' do
          expect(securities_request).to receive(:kind=).with(:safekept_transfer)
          call_action
        end
      end
      describe 'when the `securities` have a `custody_account_type` that is neither `P` nor `U`' do
        before { allow(security).to receive(:custody_account_type).and_return(SecureRandom.hex) }
        it 'raises an exception' do
          expect{call_action}.to raise_error(ArgumentError, 'Unrecognized `custody_account_type` for passed security.')
        end
      end
    end
  end

  { release: 'securities-release.xlsx',
    transfer: 'securities-transfer.xlsx',
    safekeep: 'securities-safekeeping.xlsx',
    pledge: 'securities-pledge.xlsx' }.each do |type, xls_file_name|
    action = :"download_#{type}"
    describe "POST download_#{action}" do
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
      let(:call_action) { post action, securities: securities.to_json }

      before do
        allow(controller).to receive(:populate_securities_table_data_view_variable)
        allow(controller).to receive(:render).and_call_original
      end

      it_behaves_like 'a user required action', :post, action
      it 'builds `Security` instances from the POSTed array of json objects' do
        expect(Security).to receive(:from_hash).with(securities[0]).ordered
        expect(Security).to receive(:from_hash).with(securities[1]).ordered
        call_action
      end
      it "calls `populate_securities_table_data_view_variable` with `#{type}` and the securities array" do
        allow(Security).to receive(:from_hash).and_return(security)
        expect(controller).to receive(:populate_securities_table_data_view_variable).with(type, [security, security])
        call_action
      end
      it "renders with a `type` of `#{type}` and the correct `title`" do
        expect(controller).to receive(:render).with(hash_including(locals: { type: type, title: I18n.t("securities.download.titles.#{type}") }))
        call_action
      end
      it 'responds with an xlsx file' do
        call_action
        expect(response.headers['Content-Disposition']).to eq('attachment; filename="' + xls_file_name + '"')
      end
    end
  end

  describe 'POST upload_securities' do
    shared_examples 'an upload_securities action with a type' do |type, floating_point_error_filename: nil, **files|
      uploaded_file = excel_fixture_file_upload('sample-securities-upload.xlsx')
      headerless_file = excel_fixture_file_upload('sample-securities-upload-headerless.xlsx')
      uploaded_with_blanks_file = excel_fixture_file_upload('sample-securities-upload-blanks.xlsx')
      uploaded_with_whitespace_file = excel_fixture_file_upload('sample-securities-upload-whitespace.xlsx')
      uploaded_with_floating_point_approximation = excel_fixture_file_upload(floating_point_error_filename)
      let(:security) { instance_double(Security, :valid? => true) }
      let(:invalid_security) { instance_double(Security, :valid? => false, errors: {}) }
      let(:sample_securities_upload_array) { [security,security,security,security,security] }
      let(:html_response_string) { SecureRandom.hex }
      let(:form_fields_html_response_string) { SecureRandom.hex }
      let(:parsed_response_body) { call_action; JSON.parse(response.body).with_indifferent_access }
      let(:cusip) { SecureRandom.hex }
      let(:description) { SecureRandom.hex }
      let(:original_par) { rand(1000..1000000) }
      let(:payment_amount) { rand(1000..1000000) }
      let(:custodian_name) { SecureRandom.hex }
      let(:error) { instance_double(MAPIService::Error) }
      let(:error_message) { SecureRandom.hex }
      let(:call_action) { post :upload_securities, file: uploaded_file, type: type }

      before do
        allow(controller).to receive(:populate_securities_table_data_view_variable)
        allow(controller).to receive(:render_to_string)
        allow(Security).to receive(:from_hash).and_return(security)
        allow(controller).to receive(:prioritized_security_error)
      end

      it_behaves_like 'a user required action', :post, :upload_securities, type: type
      it 'succeeds' do
        call_action
        expect(response.status).to eq(200)
      end
      it 'renders the view to a string with `layout` set to false' do
        expect(controller).to receive(:render_to_string).with(:upload_table, layout: false, locals: { type: type})
        call_action
      end
      it 'calls `populate_securities_table_data_view_variable` with the securities' do
        expect(controller).to receive(:populate_securities_table_data_view_variable).with(type, sample_securities_upload_array)
        call_action
      end
      it 'begins parsing data in the row and cell underneath the `cusip` header cell' do
        allow(Roo::Spreadsheet).to receive(:open).and_return(securities_rows_padding)
        expect(Security).to receive(:from_hash).with(security_hash).and_return(security)
        call_action
      end
      it 'returns a json object with `html`' do
        allow(controller).to receive(:render_to_string).with(:upload_table, layout: false, locals: { type: type}).and_return(html_response_string)
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
      it 'does not add invalid securities to its `form_data` response' do
        allow(Security).to receive(:from_hash).and_return(security, invalid_security)
        expect(parsed_response_body[:form_data]).to eq([security].to_json)
      end
      describe 'security validations' do
        describe 'when a security is invalid' do
          before do
            allow(Security).to receive(:from_hash).and_return(security, invalid_security, invalid_security, security, security)
          end
          describe 'when there is not an invalid CUSIP present' do
            before { allow(invalid_security).to receive(:errors).and_return({foo: ['some message']}) }
            it 'calls `prioritized_security_error` with the first invalid security it encounters' do
              expect(controller).to receive(:prioritized_security_error).with(invalid_security).exactly(:once)
              call_action
            end
            it 'returns a json object with an error message that is the result of calling `prioritized_security_error`' do
              allow(controller).to receive(:prioritized_security_error).and_return(error_message)
              expect(parsed_response_body[:error]).to eq(simple_format(error_message))
            end
          end
          describe 'when there is an invalid CUSIP present' do
            let(:invalid_cusip_1) { SecureRandom.hex }
            let(:invalid_cusip_2) { SecureRandom.hex }

            before do
              allow(invalid_security).to receive(:errors).and_return({cusip: ['some message']})
              allow(invalid_security).to receive(:cusip).and_return(invalid_cusip_1, invalid_cusip_2)
            end

            it 'returns a json object with an error message that enumerates the invalid cusips if they are present' do
              call_action
              expect(parsed_response_body[:error]).to eq(simple_format(I18n.t('securities.upload_errors.invalid_cusips', cusips: [invalid_cusip_1, invalid_cusip_2].join(', '))))
            end
            it 'prioritizes blank CUSIP errors over invalid CUSIP errors' do
              allow(invalid_security).to receive(:cusip).and_return('', invalid_cusip_2)
              expect(parsed_response_body[:error]).to eq(simple_format(I18n.t('activemodel.errors.models.security.blank')))
            end
          end
          describe 'when there is valid floating point approximation par amount present' do
            let(:call_action) { post :upload_securities, file: uploaded_with_floating_point_approximation, type: type }
            before do
              allow(Security).to receive(:from_hash).and_call_original
            end
            it 'does not return an error' do
              expect(parsed_response_body[:error]).to be_nil
            end
            it 'correctly parses the par amount' do
              expect(JSON.parse(parsed_response_body[:form_data]).first['original_par']).to be(10000000.0)
            end
            it 'does not round values that are within the float precision' do
              expect(JSON.parse(parsed_response_body[:form_data])[1]['original_par']).to be(5000000.003)
            end
          end
        end
      end
      describe 'when the uploaded file does not contain a header row with `CUSIP` as a value' do
        let(:call_action) { post :upload_securities, file: headerless_file, type: type }
        it 'renders a json object with a nil value for `html`' do
          expect(parsed_response_body[:html]).to be_nil
        end
        it 'renders a json object with a generic error messages' do
          expect(parsed_response_body[:error]).to eq(simple_format(I18n.t('securities.upload_errors.generic')))
        end
      end
      describe 'when the uploaded file contains blanks' do
        let(:call_action) { post :upload_securities, file: uploaded_with_blanks_file, type: type }
        it 'does not return an error' do
          expect(parsed_response_body[:error]).to be_nil
        end
        it 'calls `populate_securities_table_data_view_variable` with the securities, skipping blank lines' do
          expect(controller).to receive(:populate_securities_table_data_view_variable).with(type, sample_securities_upload_array)
          call_action
        end
      end
      describe 'when the uploaded file contains lines of pure whitespace' do
        let(:call_action) { post :upload_securities, file: uploaded_with_whitespace_file, type: type }
        it 'does not return an error' do
          expect(parsed_response_body[:error]).to be_nil
        end
        it 'calls `populate_securities_table_data_view_variable` with the securities, skipping empty lines' do
          expect(controller).to receive(:populate_securities_table_data_view_variable).with(type, sample_securities_upload_array)
          call_action
        end
      end
      describe 'when the MIME type of the uploaded file is not in the list of accepted types' do
        let(:incorrect_mime_type) { fixture_file_upload('sample-securities-upload.xlsx', 'text/html') }
        let(:call_action) { post :upload_securities, file: incorrect_mime_type, type: type }
        let(:parsed_response_body) { call_action; JSON.parse(response.body).with_indifferent_access }
        it 'renders a json object with a specific error messages' do
          call_action
          expect(parsed_response_body[:error]).to eq(simple_format(I18n.t('securities.upload_errors.unsupported_mime_type')))
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
      describe 'when the XLS file does not contain any rows of securities' do
        no_securities = excel_fixture_file_upload('sample-empty-securities-upload.xlsx')
        let(:call_action) { post :upload_securities, file: no_securities, type: type }
        let(:parsed_response_body) { call_action; JSON.parse(response.body).with_indifferent_access }
        it 'renders a json object with a specific error messages' do
          call_action
          expect(parsed_response_body[:error]).to eq(simple_format(I18n.t('securities.upload_errors.no_rows')))
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
      [ArgumentError, IOError, Zip::ZipError].each do |error_klass|
        describe "when opening the file raises a `#{error_klass}`" do
          before { allow(Roo::Spreadsheet).to receive(:open).and_raise(error_klass) }

          it 'renders a json object with a specific error messages' do
            call_action
            expect(parsed_response_body[:error]).to eq(simple_format(I18n.t('securities.upload_errors.cannot_open')))
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
    end

    describe 'when the type param is `release`' do
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
      let(:security_hash) {{
        cusip: cusip,
        description: description,
        original_par: original_par,
        payment_amount: payment_amount
      }}
      it_behaves_like 'an upload_securities action with a type', :release, floating_point_error_filename: 'securities-release-cents-floating-point-error.xlsx'
    end

    describe 'when the type param is `transfer`' do
      let(:securities_rows) {[
        ['cusip', 'description', 'original par'],
        [cusip, description, original_par]
      ]}
      let(:securities_rows_padding) {[
        [],
        [],
        [nil, nil, 'cusip', 'description', 'original par'],
        [nil, nil, cusip, description, original_par]
      ]}
      let(:security_hash) {{
        cusip: cusip,
        description: description,
        original_par: original_par
      }}
      it_behaves_like 'an upload_securities action with a type', :transfer, floating_point_error_filename: 'securities-release-cents-floating-point-error.xlsx'
    end

    [:release, :transfer].each do |type|
      describe "when a security in the uploaded file for a `#{type}` contains a description with > 34 characters" do
        uploaded_with_long_description = excel_fixture_file_upload('sample-securities-upload-long-description.xlsx')
        let(:call_action) { post :upload_securities, file: uploaded_with_long_description, type: type}
        let(:parsed_response_body) { call_action; JSON.parse(response.body).with_indifferent_access }
        before do
          allow(Security).to receive(:from_hash).and_call_original
        end
        it 'truncates the overlengthy description to 34 characters' do
          expect(JSON.parse(parsed_response_body[:form_data]).first['description'].size).to be <= 34
        end
      end
      describe "when a security in the uploaded file for a `#{type}` contains a description with % character" do
        uploaded_with_percent_sign_description = excel_fixture_file_upload('sample-securities-upload-with-percent-sign-in-description.xlsx')
        let(:call_action) { post :upload_securities, file: uploaded_with_percent_sign_description, type: type}
        let(:parsed_response_body) { call_action; JSON.parse(response.body).with_indifferent_access }
        before do
          allow(Security).to receive(:from_hash).and_call_original
        end
        it 'removes `%` from description' do
          expect(JSON.parse(parsed_response_body[:form_data]).first['description']).not_to include('%')
        end
      end
    end

    [:pledge, :safekeep].each do |type|
      describe "when the type param is `#{type}`" do
        let(:securities_rows) {[
          ['cusip', 'original par', 'payment_amount', 'custodian name'],
          [cusip, original_par, payment_amount, custodian_name]
        ]}
        let(:securities_rows_padding) {[
          [],
          [],
          [nil, nil, 'cusip', 'original par', 'payment_amount', 'custodian name'],
          [nil, nil, cusip, original_par, payment_amount, custodian_name]
        ]}
        let(:security_hash) {{
          cusip: cusip,
          original_par: original_par,
          payment_amount: payment_amount,
          custodian_name: custodian_name
        }}
        it_behaves_like 'an upload_securities action with a type', type, floating_point_error_filename: 'securities-pledge-cents-floating-point-error.xlsx'
      end
    end
  end

  describe "POST submit_request for unknown types" do
    let(:securities_request_param) { {'transaction_code' => "#{instance_double(String)}"} }
    let(:type) { SecureRandom.hex }
    let(:call_action) { post :submit_request, securities_request: securities_request_param, type: type }

    it 'raises an exception' do
      expect{call_action}.to raise_error(ArgumentError, "Unknown request type: #{type}")
    end
  end

  {
    pledge_release: [:edit_release, I18n.t('securities.authorize.release.title'), :securities_release_pledge_success_url, :release],
    safekept_release: [:edit_release, I18n.t('securities.authorize.release.title'), :securities_release_safekeep_success_url, :release],
    pledge_intake: [:edit_pledge, I18n.t('securities.authorize.pledge.title'), :securities_pledge_success_url, :pledge],
    safekept_intake: [:edit_safekeep, I18n.t('securities.authorize.safekeep.title'), :securities_safekeep_success_url, :safekeep],
    pledge_transfer: [:edit_transfer, I18n.t('securities.authorize.transfer.title'), :securities_transfer_pledge_success_url, :transfer],
    safekept_transfer: [:edit_transfer, I18n.t('securities.authorize.transfer.title'), :securities_transfer_safekeep_success_url, :transfer]
  }.each do |kind, details|
    template, title, success_path, type = details
    describe "POST submit_request for type `#{type}` and kind `#{kind}`" do
      allow_policy :security, :submit?
      let(:securities_request_param) { {'transaction_code' => "#{instance_double(String)}"} }
      let(:securities_request_service) { instance_double(SecuritiesRequestService, submit_request_for_authorization: true, authorize_request: true) }
      let(:active_model_errors) { instance_double(ActiveModel::Errors, add: nil) }
      let(:securities_request) { instance_double(SecuritiesRequest, :valid? => true, errors: active_model_errors, kind: kind, is_collateral?: nil, :'member_id=' => nil) }
      let(:error_message) { instance_double(String) }
      let(:call_action) { post :submit_request, securities_request: securities_request_param, type: type }

      before do
        allow(controller).to receive(:current_member_id).and_return(member_id)
        allow(controller).to receive(:populate_view_variables)
        allow(controller).to receive(:prioritized_securities_request_error)
        allow(SecuritiesRequestService).to receive(:new).and_return(securities_request_service)
        allow(SecuritiesRequest).to receive(:from_hash).and_return(securities_request)
        allow(controller).to receive(:type_matches_kind).and_return(true)
        allow(controller).to receive(:populate_authorize_request_view_variables)
        allow(controller).to receive(:set_edit_title_by_kind)
      end

      it_behaves_like 'an action that sets its contact info by kind', kind
      it_behaves_like 'an action that sets its title by kind', kind

      it 'raises an ActionController::RoutingError if the securities request kind does not match the request type param' do
        allow(controller).to receive(:type_matches_kind).and_return(false)
        expect{call_action}.to raise_error(ActionController::RoutingError, "The type specified by the `/securities/submit` route does not match the @securities_request.kind. \nType: `#{type}`\nKind: `#{securities_request.kind}`")
      end
      it 'builds a SecuritiesRequest instance with the `securities_request` params' do
        expect(SecuritiesRequest).to receive(:from_hash).with(securities_request_param)
        call_action
      end
      it 'populates the SecuritiesRequest `member_id` with the `current_member_id`' do
        expect(securities_request).to receive(:member_id=).with(member_id)
        call_action
      end
      it 'sets @securities_request' do
        call_action
        expect(assigns[:securities_request]).to eq(securities_request)
      end
      describe 'when the securities_request is valid' do
        it 'creates a new instance of SecuritiesRequestService with the `current_member_id`' do
          expect(SecuritiesRequestService).to receive(:new).with(member_id, anything).and_return(securities_request_service)
          call_action
        end
        it 'creates a new instance of SecuritiesRequestService with the current request' do
          expect(SecuritiesRequestService).to receive(:new).with(anything, request).and_return(securities_request_service)
          call_action
        end
        it 'calls `submit_request_for_authorization` on the SecuritiesRequestService instance with the `securities_request`' do
          expect(securities_request_service).to receive(:submit_request_for_authorization).with(securities_request, anything, type).and_return(true)
          call_action
        end
        describe 'when the service object returns true' do
          it 'redirects to the `securities_release_success_url` if there are no errors' do
            allow(active_model_errors).to receive(:present?).and_return(false)
            expect(call_action).to redirect_to(send(success_path))
          end
        end
        describe 'when the service object returns nil' do
          let(:error_body) {{
            'error' => {
              'code' => SecureRandom.hex,
              'type' => SecureRandom.hex
            }
          }}
          let(:error) { instance_double(RestClient::Exception, http_body: error_body.to_json) }

          before do
            allow(securities_request_service).to receive(:submit_request_for_authorization).and_return(nil)
            allow(JSON).to receive(:parse).and_return(error_body)
          end
          describe 'when the error handler is invoked' do
            before { allow(securities_request_service).to receive(:submit_request_for_authorization).and_yield(error) }

            it 'adds an error to the securities_request instance with the given code and type' do
              expect(active_model_errors).to receive(:add).with(error_body['error']['code'].to_sym, error_body['error']['type'].to_sym)
              call_action
            end
            it 'adds an error to the securities_request instance with an attribute of `:base` when the given code is `unkown`' do
              error_body['error']['code'] = 'unknown'
              expect(active_model_errors).to receive(:add).with(:base, error_body['error']['type'].to_sym)
              call_action
            end
            it 'does not add a `:base`, `:submission` error' do
              expect(active_model_errors).not_to receive(:add).with(:base, :submission)
              call_action
            end
          end
          it 'adds a `:base`, `:submission` error if there are not yet any errors' do
            allow(active_model_errors).to receive(:present?).and_return(false)
            expect(active_model_errors).to receive(:add).with(:base, :submission)
            call_action
          end
          it "calls `populate_view_variables` with `#{type}`" do
            expect(controller).to receive(:populate_view_variables).with(type)
            call_action
          end
          it 'calls `prioritized_securities_request_error` with the securities_request instance' do
            expect(controller).to receive(:prioritized_securities_request_error).with(securities_request)
            call_action
          end
          it 'sets `@error_message` to the result of `prioritized_securities_request_error`' do
            allow(controller).to receive(:prioritized_securities_request_error).and_return(error_message)
            call_action
            expect(assigns[:error_message]).to eq(error_message)
          end
          it "renders the `#{template}` view" do
            call_action
            expect(response.body).to render_template(template)
          end

          describe 'when the user is an collateral signer' do
            allow_policy :security, :authorize_collateral?
            it 'does not check the SecurID details' do
              expect(subject).to_not receive(:securid_perform_check)
              call_action
            end
          end

          describe 'when the user is an securities signer' do
            allow_policy :security, :authorize_securities?
            it 'does not check the SecurID details' do
              expect(subject).to_not receive(:securid_perform_check)
              call_action
            end
          end
        end
      end
      describe 'when the securities_request is invalid' do
        before { allow(securities_request).to receive(:valid?).and_return(false) }

        it 'calls `prioritized_securities_request_error` with the securities_request instance' do
          expect(controller).to receive(:prioritized_securities_request_error).with(securities_request)
          call_action
        end
        it 'sets `@error_message` to the result of `prioritized_securities_request_error`' do
          allow(controller).to receive(:prioritized_securities_request_error).and_return(error_message)
          call_action
          expect(assigns[:error_message]).to eq(error_message)
        end
        it "renders the `#{template}` view" do
          call_action
          expect(response.body).to render_template(template)
        end
        describe 'when the user is an collateral signer' do
          allow_policy :security, :authorize_collateral?
          it 'does not check the SecurID details' do
            expect(subject).to_not receive(:securid_perform_check)
            call_action
          end
        end
        describe 'when the user is an securities signer' do
          allow_policy :security, :authorize_securities?
          it 'does not check the SecurID details' do
            expect(subject).to_not receive(:securid_perform_check)
            call_action
          end
        end
      end

      describe 'when the user is an authorizer' do
        let(:request_id) { double('A Request ID') }
        allow_policy :security, :authorize_securities?
        before do
          allow(securities_request).to receive(:request_id).and_return(request_id)
        end
        it 'checks the SecurID details if no errors are found in the data' do
          allow(active_model_errors).to receive(:blank?).and_return(true)
          expect(subject).to receive(:securid_perform_check).and_return(:authenticated)
          call_action
        end
        describe 'when SecurID passes and there are not yet any errors' do
          let(:message) { instance_double(ActionMailer::MessageDelivery) }
          before do
            allow(subject).to receive(:session_elevated?).and_return(true)
            allow(active_model_errors).to receive(:blank?).and_return(true)
            allow(InternalMailer).to receive(:securities_request_authorized).with(securities_request).and_return(message)
            allow(message).to receive(:deliver_now)
          end
          it 'authorizes the request' do
            expect(securities_request_service).to receive(:authorize_request).with(request_id, controller.current_user)
            call_action
          end
          it 'builds the SecuritiesRequest before it emails the distribution list' do
            expect(SecuritiesRequest).to receive(:from_hash).with(securities_request_param).ordered
            expect(securities_request).to receive(:member_id=).with(member_id).ordered
            expect(InternalMailer).to receive(:securities_request_authorized).with(securities_request).ordered
            call_action
          end
          it 'constructs an email to the internal distribution list' do
            expect(InternalMailer).to receive(:securities_request_authorized).with(securities_request)
            call_action
          end
          it 'delivers an email to the internal distribution list' do
            expect(message).to receive(:deliver_now)
            call_action
          end
          it 'renders the `authorize_request` view' do
            call_action
            expect(response.body).to render_template(:authorize_request)
          end
          it 'calls `populate_authorize_request_view_variables` with the securities request `kind`' do
            expect(controller).to receive(:populate_authorize_request_view_variables).with(kind)
            call_action
          end
          describe 'when the authorization fails' do
            before do
              allow(securities_request_service).to receive(:authorize_request).and_return(false)
              allow(active_model_errors).to receive(:present?).and_return(false, false, true)
            end

            it 'adds an `:base`, `:authorization` error to the securities_request instance' do
              expect(active_model_errors).to receive(:add).with(:base, :authorization)
              call_action
            end
            it 'calls `prioritized_securities_request_error` with the securities_request instance' do
              expect(controller).to receive(:prioritized_securities_request_error).with(securities_request)
              call_action
            end
            it 'sets `@error_message` to the result of `prioritized_securities_request_error`' do
              allow(controller).to receive(:prioritized_securities_request_error).and_return(error_message)
              call_action
              expect(assigns[:error_message]).to eq(error_message)
            end
            it "renders the `#{template}` view" do
              call_action
              expect(response.body).to render_template(template)
            end
          end
        end
        describe 'when SecurID fails' do
          let(:securid_error) { double('A SecurID error') }
          before do
            allow(active_model_errors).to receive(:blank?).and_return(true)
            allow(subject).to receive(:securid_perform_check).and_return(securid_error)
          end
          it 'does not authorize the request' do
            expect(securities_request_service).to_not receive(:authorize_request)
            call_action
          end
          it "renders the `#{template}` view" do
            call_action
            expect(response.body).to render_template(template)
          end
          it "calls `populate_view_variables` with `#{type}`" do
            expect(controller).to receive(:populate_view_variables).with(type)
            call_action
          end
          it 'does not call `prioritized_securities_request_error`' do
            expect(controller).to_not receive(:prioritized_securities_request_error)
            call_action
          end
          it 'does not set `@error_message`' do
            call_action
            expect(assigns[:error_message]).to be_nil
          end
        end
      end
      describe 'when the user is not a submitter' do
        deny_policy :security, :submit?
        it 'still validates the securities request' do
          expect(securities_request).to receive(:valid?)
          call_action
        end
        it 'calls `prioritized_securities_request_error` with the securities request' do
          expect(controller).to receive(:prioritized_securities_request_error).with(securities_request)
          call_action
        end
        it 'sets `@error_message` to the result of `prioritized_securities_request_error` if it exists' do
          error_message = instance_double(String)
          allow(controller).to receive(:prioritized_securities_request_error).and_return(error_message)
          call_action
          expect(assigns[:error_message]).to eq(error_message)
        end
        it 'sets `@error_message` to the internal user error if `prioritized_securities_request_error` returns nil' do
          allow(controller).to receive(:prioritized_securities_request_error).and_return(nil)
          call_action
          expect(assigns[:error_message]).to eq(I18n.t('securities.internal_user_error'))
        end
      end
    end
  end

  describe 'GET `submit_request_success`' do
    request_kind_translations = {
      pledge_release: [I18n.t('securities.success.titles.pledge_release'), I18n.t('securities.success.email.subjects.pledge_release')],
      safekept_release: [I18n.t('securities.success.titles.safekept_release'), I18n.t('securities.success.email.subjects.safekept_release')],
      pledge_intake: [I18n.t('securities.success.titles.pledge_intake'), I18n.t('securities.success.email.subjects.pledge_intake')],
      safekept_intake: [I18n.t('securities.success.titles.safekept_intake'), I18n.t('securities.success.email.subjects.safekept_intake')],
      pledge_transfer: [I18n.t('securities.success.titles.transfer'), I18n.t('securities.success.email.subjects.transfer')],
      safekept_transfer: [I18n.t('securities.success.titles.transfer'), I18n.t('securities.success.email.subjects.transfer')]
    }
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

    before do
      allow(MembersService).to receive(:new).and_return(member_service_instance)
      allow(member_service_instance).to receive(:signers_and_users).and_return(signers_and_users)
    end

    it_behaves_like 'a user required action', :get, :submit_request_success

    request_kind_translations.each do |kind, translations|
      title, email_subject = translations
      let(:call_action) { get :submit_request_success, kind: kind }
      it_behaves_like 'a controller action with an active nav setting', :submit_request_success, :securities, kind: kind
      it "sets `@title` to `#{title}` when the `kind` param is `#{kind}`" do
        get :submit_request_success, kind: kind
        expect(assigns[:title]).to eq(title)
      end
      it "sets `@email_subject` to `#{email_subject}` when the `kind` param is `#{kind}`" do
        get :submit_request_success, kind: kind
        expect(assigns[:email_subject]).to eq(email_subject)
      end
      it "sets `@title` to `#{title}` when the `type` param is `#{kind}`" do
        get :submit_request_success, kind: kind
        expect(assigns[:title]).to eq(title)
      end
      it 'renders the `submit_request_success` view' do
        call_action
        expect(response.body).to render_template('submit_request_success')
      end
      it 'renders the `submit_request_success` view' do
        call_action
        expect(response.body).to render_template('submit_request_success')
      end
      it 'sets `@authorized_user_data` to [] if no users are found' do
        allow(member_service_instance).to receive(:signers_and_users).and_return([])
        call_action
        expect(assigns[:authorized_user_data]).to eq([])
      end
    end

    SecuritiesRequest::COLLATERAL_KINDS.each do |kind|
      it 'sets `@authorized_user_data` to a list of users with collateral authority' do
        get :submit_request_success, kind: kind
        expect(assigns[:authorized_user_data]).to eq([user_b])
      end
    end

    SecuritiesRequest::SECURITIES_KINDS.each do |kind|
      it 'sets `@authorized_user_data` to a list of users with collateral authority' do
        get :submit_request_success, kind: kind
        expect(assigns[:authorized_user_data]).to eq([user_c])
      end
    end
  end

  describe 'DELETE delete_request' do
    allow_policy :security, :delete?
    let(:request_id) { SecureRandom.hex }
    let(:securities_request_service) { instance_double(SecuritiesRequestService, delete_request: true) }
    let(:call_action) { delete :delete_request, request_id: request_id }
    before { allow(SecuritiesRequestService).to receive(:new).and_return(securities_request_service) }

    it_behaves_like 'a user required action', :delete, :delete_request, request_id: SecureRandom.hex
    it_behaves_like 'an authorization required method', :delete, :delete_request, :security, :delete?, request_id: SecureRandom.hex
    it 'creates a new `SecuritiesRequestService` with the `current_member_id`' do
      expect(SecuritiesRequestService).to receive(:new).with(member_id, any_args).and_return(securities_request_service)
      call_action
    end
    it 'creates a new `SecuritiesRequestService` with the `request`' do
      expect(SecuritiesRequestService).to receive(:new).with(anything, request).and_return(securities_request_service)
      call_action
    end
    it 'calls `delete_request` on the `SecuritiesRequestService` instance with the `request_id`' do
      expect(securities_request_service).to receive(:delete_request).with(request_id)
      call_action
    end
    it 'renders JSON hash with a `url` body value `securities_requests_url`' do
      call_action
      expect(JSON.parse(response.body)['url']).to eq(securities_requests_url)
    end
    it "renders JSON hash with an `error_message` body value `#{I18n.t('securities.release.delete_request.error_message')}`" do
      call_action
      expect(JSON.parse(response.body)['error_message']).to eq(I18n.t('securities.release.delete_request.error_message'))
    end
    it 'returns a 200 if the SecuritiesRequestService returns true' do
      call_action
      expect(response.status).to eq(200)
    end
    it 'returns a 404 if the SecuritiesRequestService returns false' do
      allow(securities_request_service).to receive(:delete_request).and_return(false)
      call_action
      expect(response.status).to eq(404)
    end
    it 'returns a 404 if the SecuritiesRequestService returns nil' do
      allow(securities_request_service).to receive(:delete_request).and_return(nil)
      call_action
      expect(response.status).to eq(404)
    end
  end

  describe 'GET `generate_authorized_request`' do
    let(:job_status) { double('JobStatus', update_attributes!: nil, id: nil, destroy: nil, result_as_string: nil ) }
    let(:request_id) { rand(0..99999) }
    let(:user_id) { rand(1000) }
    let(:kind) { SecureRandom.hex }
    let(:active_job) { double('Active Job Instance', job_status: job_status) }
    let(:call_action) { get :generate_authorized_request, request_id: request_id, kind: kind }
    let(:current_user) { double('User', id: user_id, :accepted_terms? => true)}
    let(:member_id) { rand(1000) }

    before do
      allow(RenderSecuritiesRequestsPDFJob).to receive(:perform_later).and_return(active_job)
      allow(controller).to receive(:current_user).and_return(current_user)
      allow(subject).to receive(:current_member_id).and_return(member_id)
    end

    it "calls `perform_later` on `RenderSecuritiesRequestsPDFJob` with the current_member_id" do
      expect(RenderSecuritiesRequestsPDFJob).to receive(:perform_later).with(member_id, any_args).and_return(active_job)
      call_action
    end
    it "calls `perform_later` on `RenderSecuritiesRequestsPDFJob` with the `view_authorized_request` as the action name" do
      expect(RenderSecuritiesRequestsPDFJob).to receive(:perform_later).with(anything, 'view_authorized_request', any_args).and_return(active_job)
      call_action
    end
    it "calls `perform_later` on `RenderSecuritiesRequestsPDFJob` with the a download name including the request_id" do
      expect(RenderSecuritiesRequestsPDFJob).to receive(:perform_later).with(anything, anything, "authorized_request_#{request_id}.pdf", any_args).and_return(active_job)
      call_action
    end
    it "calls `perform_later` on `RenderSecuritiesRequestsPDFJob` with the request_id and kind params" do
      expect(RenderSecuritiesRequestsPDFJob).to receive(:perform_later).with(anything, anything, anything, { request_id: request_id.to_s, kind: kind }).and_return(active_job)
      call_action
    end
    it 'updates the job_status instance with the user_id of the current user' do
      expect(job_status).to receive(:update_attributes!).with({user_id: user_id})
      call_action
    end
    it 'returns a json response with a `job_status_url`' do
      call_action
      expect(JSON.parse(response.body).with_indifferent_access[:job_status_url]).to eq(job_status_url(job_status))
    end
    it 'returns a json response with a `job_cancel_url`' do
      call_action
      expect(JSON.parse(response.body).with_indifferent_access[:job_cancel_url]).to eq(job_cancel_url(job_status))
    end
  end

  describe '`view_authorized_request`' do
    let(:member_id) { rand(0..9999) }
    let(:request_id) { rand(0..99999) }
    let(:controller) { SecuritiesController.new }
    let(:profile) { double('Member Profile') }
    let(:member) { instance_double(Member) }
    let(:authorized_by) { SecureRandom.hex }
    let(:authorized_date) { Time.zone.today }
    let(:transaction_code) { double('Transaction Code') }
    let(:members_service_instance) { instance_double(MembersService, member: member ) }
    let(:member_balance_service_instance) { instance_double(MemberBalanceService, profile: profile) }
    let(:settlement_type) {  SecureRandom.hex }
    let(:trade_date) { Time.zone.today }
    let(:settlement_date) { Time.zone.today }
    let(:clearing_agent_participant_number) { rand(0..9999) }
    let(:account_number) { rand(0..9999) }
    let(:cusip) { SecureRandom.hex }
    let(:description) { SecureRandom.hex }
    let(:original_par) { rand(0..9999) }
    let(:payment_amount) { rand(0..9999) }
    let(:delivery_instruction_rows) { double('Delivery Instruction Rows') }
    let(:pledge_type) { double('Pledge Type') }
    let(:security) { instance_double(Security, cusip: cusip,
                                        description: description,
                                        original_par: original_par,
                                        payment_amount: payment_amount,
                                        custodian_name: SecureRandom.hex) }
    let(:pledged_account) { rand(9999..99999) }
    let(:safekept_account) { rand(9999..99999) }
    let(:securities_request) { instance_double(SecuritiesRequest, request_id: request_id,
                                                            authorized_by: authorized_by,
                                                            authorized_date: authorized_date,
                                                            transaction_code: transaction_code,
                                                            settlement_type: settlement_type,
                                                            trade_date: trade_date,
                                                            delivery_type: SecureRandom.hex,
                                                            settlement_date: settlement_date,
                                                            securities: [ security ],
                                                            clearing_agent_participant_number: clearing_agent_participant_number,
                                                            kind: nil,
                                                            pledge_to: pledge_type,
                                                            pledged_account: pledged_account,
                                                            safekept_account: safekept_account,
                                                            is_collateral?: double('Is Collateral?')) }
    let(:securities_request_service_instance) { instance_double(SecuritiesRequestService, submitted_request: securities_request )}
    let(:user) { instance_double(User,
                        display_name: 'A User',
                        roles: [User::Roles::COLLATERAL_SIGNER],
                        surname: 'User',
                        given_name: 'A',
                        'cache_key=': nil,
                        cache_key: SecureRandom.hex,
                        intranet_user?: false ) }
    let(:call_action) { subject.public_send(:view_authorized_request) }

    before do
      subject.params = { request_id: request_id }
      subject.class_eval { layout 'print' }
      allow(MembersService).to receive(:new).with(anything).and_return(members_service_instance)
      allow(members_service_instance).to receive(:member).and_return(member)
      allow(MemberBalanceService).to receive(:new).and_return(member_balance_service_instance)
      allow(SecuritiesRequestService).to receive(:new).and_return(securities_request_service_instance)
      allow(subject).to receive(:get_delivery_instruction_rows).with(securities_request).and_return(delivery_instruction_rows)
      subject.instance_variable_set(:@securities_request, securities_request)
    end

    shared_examples 'setting the preconditions for generating a PDF for each `kind` of securities request' do |kind, title|
      before do
        allow(securities_request).to receive(:kind).and_return(kind)
      end

      it 'sets the report name' do
        call_action
        expect(subject.instance_variable_get(:@title)).to eq(title)
      end
      it 'sets the member' do
        call_action
        expect(subject.instance_variable_get(:@member)).to eq(member)
      end
      it 'raises an error if the `member` is nil' do
        allow(members_service_instance).to receive(:member).and_return(nil)
        expect { call_action }.to raise_error(ActionController::RoutingError)
      end
      it 'sets the member profile' do
        call_action
        expect(subject.instance_variable_get(:@member_profile)).to eq(profile)
      end
      it 'raises an error if the `member_profile` is nil' do
        allow(member_balance_service_instance).to receive(:profile).and_return(nil)
        expect { call_action }.to raise_error(ActionController::RoutingError)
      end
      it 'sets the securities request' do
        call_action
        expect(subject.instance_variable_get(:@securities_request)).to eq(securities_request)
      end
      it 'raises an error if the `securities_request` is nil' do
        allow(securities_request_service_instance).to receive(:submitted_request).and_return(nil)
        expect { call_action }.to raise_error(ActionController::RoutingError)
      end
    end

    shared_examples 'an action that generates a PDF for securities intake' do |kind|
      before do
        allow(securities_request).to receive(:kind).and_return(kind)
      end
      it 'sets broker instructions table data' do
        call_action
        expect(subject.instance_variable_get(:@broker_instructions_table_data)).to eq( {
          rows: [ { columns: [ { value: I18n.t('securities.requests.view.broker_instructions.transaction_code') },
                               { value: securities_request.transaction_code.to_s.titleize } ] },
                  { columns: [ { value: I18n.t('securities.requests.view.broker_instructions.settlement_type') },
                               { value: securities_request.settlement_type.to_s.titleize } ] },
                  { columns: [ { value: I18n.t('securities.requests.view.broker_instructions.trade_date') },
                               { value: CustomFormattingHelper::fhlb_date_standard_numeric(securities_request.trade_date) } ] },
                  { columns: [ { value: I18n.t('securities.requests.view.broker_instructions.settlement_date') },
                               { value: CustomFormattingHelper::fhlb_date_standard_numeric(securities_request.settlement_date) } ] } ] } )
      end
      it 'sets delivery instructions table data' do
        call_action
        expect(subject.instance_variable_get(:@delivery_instructions_table_data)).to eq(rows: delivery_instruction_rows)
      end
      it 'sets securities table data' do
        table_data = {  column_headings: [
          I18n.t('common_table_headings.cusip'),
          I18n.t('common_table_headings.description'),
          fhlb_add_unit_to_table_header(I18n.t('common_table_headings.original_par'), '$'),
          I18n.t('securities.requests.view.securities.settlement_amount', footnote_marker: fhlb_footnote_marker),
          I18n.t('common_table_headings.custodian_name', footnote_marker: fhlb_footnote_marker(1))],
          rows: [ { columns: [ { value: security.cusip },
                               { value: security.description },
                               { value: security.original_par, type: :currency, options: { unit: '' } },
                               { value: security.payment_amount, type: :currency, options: { unit: '' } },
                               { value: security.custodian_name } ] } ],
          footer: [ { value: I18n.t('securities.requests.view.securities.securities_in_request', count: 1) },
                    { value: I18n.t('global.total_with_colon'), classes: ['report-cell-right'] },
                    { value: security.original_par, type: :currency },
                    { value: security.payment_amount, type: :currency }]}                  
        call_action
        expect(subject.instance_variable_get(:@securities_table_data)).to eq(table_data)
      end
    end

    shared_examples 'an action that generates a PDF for securities release' do |kind|
      before do
        allow(securities_request).to receive(:kind).and_return(kind)
      end
      it 'sets the request details table data' do
        call_action
        request_details = {
          rows: [ { columns: [ { value: I18n.t('securities.requests.view.request_details.request_id') },
                             { value: securities_request.request_id } ] },
                { columns: [ { value: I18n.t('securities.requests.view.request_details.authorized_by') },
                             { value: securities_request.authorized_by } ] },
                { columns: [ { value: I18n.t('securities.requests.view.request_details.authorization_date') },
                             { value: CustomFormattingHelper::fhlb_date_standard_numeric(securities_request.authorized_date) } ] } ] }
        expect(subject.instance_variable_get(:@request_details_table_data)).to eq(request_details)
      end
      it 'sets broker instructions table data' do
        call_action
        expect(subject.instance_variable_get(:@broker_instructions_table_data)).to eq( {
          rows: [ { columns: [ { value: I18n.t('securities.requests.view.broker_instructions.transaction_code') },
                               { value: securities_request.transaction_code.to_s.titleize } ] },
                  { columns: [ { value: I18n.t('securities.requests.view.broker_instructions.settlement_type') },
                               { value: securities_request.settlement_type.to_s.titleize } ] },
                  { columns: [ { value: I18n.t('securities.requests.view.broker_instructions.trade_date') },
                               { value: CustomFormattingHelper::fhlb_date_standard_numeric(securities_request.trade_date) } ] },
                  { columns: [ { value: I18n.t('securities.requests.view.broker_instructions.settlement_date') },
                               { value: CustomFormattingHelper::fhlb_date_standard_numeric(securities_request.settlement_date) } ] } ] } )
      end
      it 'sets delivery instructions table data' do
        call_action
        expect(subject.instance_variable_get(:@delivery_instructions_table_data)).to eq(rows: delivery_instruction_rows)
      end
      it 'sets securities table data' do
        table_data = {  column_headings: [ I18n.t('common_table_headings.cusip'),
                             I18n.t('common_table_headings.description'),
                             fhlb_add_unit_to_table_header(I18n.t('common_table_headings.original_par'), '$'),
                              I18n.t('securities.requests.view.securities.settlement_amount', footnote_marker: fhlb_footnote_marker) ],
                        rows: [ { columns: [ { value: security.cusip },
                                             { value: security.description },
                                             { value: security.original_par, type: :currency, options: { unit: '' } },
                                             { value: security.payment_amount, type: :currency, options: { unit: '' } } ] } ],
                        footer: [ { value: I18n.t('securities.requests.view.securities.securities_in_request', count: 1) },
                                  { value: I18n.t('global.total_with_colon'), classes: ['report-cell-right'] },
                                  { value: security.original_par, type: :currency },
                                  { value: security.payment_amount, type: :currency } ] }        
        call_action
        expect(subject.instance_variable_get(:@securities_table_data)).to eq(table_data)
      end
    end

    {safekept_intake: I18n.t('securities.requests.view.safekept_intake.title'),
     pledge_intake: I18n.t('securities.requests.view.pledge_intake.title'),
     safekept_release: I18n.t('securities.requests.view.safekept_release.title'),
     pledge_release: I18n.t('securities.requests.view.pledge_release.title'),
     safekept_transfer: I18n.t('securities.requests.view.safekept_transfer.title'),
     pledge_transfer: I18n.t('securities.requests.view.pledge_transfer.title')}.each do |kind, title|
      describe "when `kind` is `#{kind}`" do
        it_behaves_like 'setting the preconditions for generating a PDF for each `kind` of securities request', kind, title
      end
    end

    [:safekept_intake, :pledge_intake ].each do |kind|
      describe "when `kind` is `#{kind}`" do
        it_behaves_like 'an action that generates a PDF for securities intake', kind
      end
    end

    [:safekept_release, :pledge_release].each do |kind|
      describe "when `kind` is `#{kind}`" do
        it_behaves_like 'an action that generates a PDF for securities release', kind
      end
    end

    context do
      [:safekept_transfer, :safekept_intake].each do |kind|
        before do
          allow(securities_request).to receive(:kind).and_return(kind)
        end
        it "sets the request details table data for `#{kind}`" do
          call_action
          expect(subject.instance_variable_get(:@request_details_table_data)).to eq({ rows: [
            { columns: [ { value: I18n.t('securities.requests.view.request_details.request_id') },
                         { value: securities_request.request_id } ] },
            { columns: [ { value: I18n.t('securities.requests.view.request_details.authorized_by') },
                         { value: securities_request.authorized_by } ] },
            { columns: [ { value: I18n.t('securities.requests.view.request_details.authorization_date') },
                         { value: CustomFormattingHelper::fhlb_date_standard_numeric(securities_request.authorized_date) } ] },
          ] })
        end
      end
    end
    context do
      [:pledge_transfer, :pledge_intake].each do |kind|
        before do
          allow(securities_request).to receive(:kind).and_return(kind)
        end
        it "sets the request details table data for `#{kind}`" do
          call_action
          expect(subject.instance_variable_get(:@request_details_table_data)).to eq({ rows: [
            { columns: [ { value: I18n.t('securities.requests.view.request_details.request_id') },
                         { value: securities_request.request_id } ] },
            { columns: [ { value: I18n.t('securities.requests.view.request_details.authorized_by') },
                         { value: securities_request.authorized_by } ] },
            { columns: [ { value: I18n.t('securities.requests.view.request_details.authorization_date') },
                         { value: CustomFormattingHelper::fhlb_date_standard_numeric(securities_request.authorized_date) } ] },
            { columns: [ { value: I18n.t('securities.requests.view.request_details.pledge_to.pledge_type') },
                         { value: SecuritiesController::PLEDGE_TO_MAPPING[securities_request.pledge_to] } ] }
          ] })
        end
      end
    end
  end
  describe 'private methods' do
    describe '`kind_to_description`' do
      {
        'pledge_release' => 'securities.requests.form_descriptions.release_pledged',
        'safekept_release' => 'securities.requests.form_descriptions.release_safekept',
        'pledge_intake' => 'securities.requests.form_descriptions.pledge',
        'safekept_intake' => 'securities.requests.form_descriptions.safekept',
        'pledge_transfer' => 'securities.requests.form_descriptions.transfer_pledged',
        'safekept_transfer' => 'securities.requests.form_descriptions.transfer_safekept'
      }.each do |form_type, description_key|
        it "returns the localization value for `#{description_key}` when passed `#{form_type}`" do
          expect(controller.send(:kind_to_description, form_type)).to eq(I18n.t(description_key))
        end
      end
      it 'returns the localization value for `global.missing_value` when passed an unknown form type' do
        expect(controller.send(:kind_to_description, double(String))).to eq(I18n.t('global.missing_value'))
      end
    end

    describe '`populate_transaction_code_dropdown_variables`' do
      transaction_code_dropdown = [
        [I18n.t('securities.release.transaction_code.standard'), SecuritiesRequest::TRANSACTION_CODES[:standard]],
        [I18n.t('securities.release.transaction_code.repo'), SecuritiesRequest::TRANSACTION_CODES[:repo]]
      ]
      let(:securities_request) { instance_double(SecuritiesRequest, transaction_code: nil) }
      let(:call_method) { controller.send(:populate_transaction_code_dropdown_variables, securities_request) }
      it 'sets `@transaction_code_dropdown`' do
        call_method
        expect(assigns[:transaction_code_dropdown]).to eq(transaction_code_dropdown)
      end
      describe 'setting `@transaction_code_defaults`' do
        describe 'when the `transaction_code` is `:standard`' do
          before { allow(securities_request).to receive(:transaction_code).and_return(:standard) }
          it "has a `text` string of `#{transaction_code_dropdown.first.first}`" do
            call_method
            expect(assigns[:transaction_code_defaults][:text]).to eq(transaction_code_dropdown.first.first)
          end
          it "has a `value` of `#{transaction_code_dropdown.first.last}`" do
            call_method
            expect(assigns[:transaction_code_defaults][:value]).to eq(transaction_code_dropdown.first.last)
          end
        end
        describe 'when the `transaction_code` is `:repo`' do
          before { allow(securities_request).to receive(:transaction_code).and_return(:repo) }
          it "has a `text` string of `#{transaction_code_dropdown.last.first}`" do
            call_method
            expect(assigns[:transaction_code_defaults][:text]).to eq(transaction_code_dropdown.last.first)
          end
          it "has a `value` of `#{transaction_code_dropdown.last.last}`" do
            call_method
            expect(assigns[:transaction_code_defaults][:value]).to eq(transaction_code_dropdown.last.last)
          end
        end
        describe 'when the `transaction_code` is neither `:standard` nor `:repo`' do
          it "has a `text` string of `#{transaction_code_dropdown.first.first}`" do
            call_method
            expect(assigns[:transaction_code_defaults][:text]).to eq(transaction_code_dropdown.first.first)
          end
          it "has a `value` of `#{transaction_code_dropdown.first.last}`" do
            call_method
            expect(assigns[:transaction_code_defaults][:value]).to eq(transaction_code_dropdown.first.last)
          end
        end
      end
    end

    describe '`populate_settlement_type_dropdown_variables`' do
      settlement_type_dropdown = [
        [I18n.t('securities.release.settlement_type.free'), SecuritiesRequest::SETTLEMENT_TYPES[:free]],
        [I18n.t('securities.release.settlement_type.vs_payment'), SecuritiesRequest::SETTLEMENT_TYPES[:vs_payment]]
      ]
      let(:securities_request) { instance_double(SecuritiesRequest, settlement_type: nil) }
      let(:call_method) { controller.send(:populate_settlement_type_dropdown_variables, securities_request) }
      it 'sets `@settlement_type_dropdown`' do
        call_method
        expect(assigns[:settlement_type_dropdown]).to eq(settlement_type_dropdown)
      end
      describe 'setting `@settlement_type_defaults`' do
        describe 'when the `settlement_type` is `:free`' do
          before { allow(securities_request).to receive(:settlement_type).and_return(:free) }
          it "has a `text` string of `#{settlement_type_dropdown.first.first}`" do
            call_method
            expect(assigns[:settlement_type_defaults][:text]).to eq(settlement_type_dropdown.first.first)
          end
          it "has a `value` of `#{settlement_type_dropdown.first.last}`" do
            call_method
            expect(assigns[:settlement_type_defaults][:value]).to eq(settlement_type_dropdown.first.last)
          end
        end
        describe 'when the `settlement_type` is `:vs_payment`' do
          before { allow(securities_request).to receive(:settlement_type).and_return(:vs_payment) }
          it "has a `text` string of `#{settlement_type_dropdown.last.first}`" do
            call_method
            expect(assigns[:settlement_type_defaults][:text]).to eq(settlement_type_dropdown.last.first)
          end
          it "has a `value` of `#{settlement_type_dropdown.last.last}`" do
            call_method
            expect(assigns[:settlement_type_defaults][:value]).to eq(settlement_type_dropdown.last.last)
          end
        end
        describe 'when the `settlement_type` is neither `:free` nor `:vs_payment`' do
          before { allow(securities_request).to receive(:settlement_type).and_return(:free) }
          it "has a `text` string of `#{settlement_type_dropdown.first.first}`" do
            call_method
            expect(assigns[:settlement_type_defaults][:text]).to eq(settlement_type_dropdown.first.first)
          end
          it "has a `value` of `#{settlement_type_dropdown.first.last}`" do
            call_method
            expect(assigns[:settlement_type_defaults][:value]).to eq(settlement_type_dropdown.first.last)
          end
        end
      end
    end

    describe '`populate_delivery_instructions_dropdown_variables`' do
      delivery_instructions_dropdown = [
        [I18n.t('securities.release.delivery_instructions.dtc'), SecuritiesRequest::DELIVERY_TYPES[:dtc]],
        [I18n.t('securities.release.delivery_instructions.fed'), SecuritiesRequest::DELIVERY_TYPES[:fed]],
        [I18n.t('securities.release.delivery_instructions.mutual_fund'), SecuritiesRequest::DELIVERY_TYPES[:mutual_fund]],
        [I18n.t('securities.release.delivery_instructions.physical_securities'), SecuritiesRequest::DELIVERY_TYPES[:physical_securities]]
      ]
      let(:securities_request) { instance_double(SecuritiesRequest, delivery_type: nil, is_collateral?: true) }
      let(:call_method) { controller.send(:populate_delivery_instructions_dropdown_variables, securities_request) }
      it 'sets `@delivery_instructions_dropdown`' do
        call_method
        expect(assigns[:delivery_instructions_dropdown]).to eq(delivery_instructions_dropdown)
      end
      describe 'setting `@delivery_instructions_defaults`' do
        [:dtc, :fed, :mutual_fund, :physical_securities].each_with_index do |delivery_type, i|
          describe "when the `delivery_type` is `#{delivery_type}`" do
            before { allow(securities_request).to receive(:delivery_type).and_return(delivery_type) }
            it "has a `text` string of `#{delivery_instructions_dropdown[i].first}`" do
              call_method
              expect(assigns[:delivery_instructions_defaults][:text]).to eq(delivery_instructions_dropdown[i].first)
            end
            it "has a `value` of `#{delivery_instructions_dropdown[i].last}`" do
              call_method
              expect(assigns[:delivery_instructions_defaults][:value]).to eq(delivery_instructions_dropdown[i].last)
            end
          end
        end
        describe "when the `delivery_type` is not one of: `#{SecuritiesRequest::DELIVERY_TYPES.keys}`" do
          it "has a `text` string of `#{delivery_instructions_dropdown.first.first}`" do
            call_method
            expect(assigns[:delivery_instructions_defaults][:text]).to eq(delivery_instructions_dropdown.first.first)
          end
          it "has a `value` of `#{delivery_instructions_dropdown.first.last}`" do
            call_method
            expect(assigns[:delivery_instructions_defaults][:value]).to eq(delivery_instructions_dropdown.first.last)
          end
        end
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
      let(:securities_request) { instance_double(SecuritiesRequest, securities: securities, :securities= => nil, trade_date: nil, :trade_date= => nil, settlement_date: nil, :settlement_date= => nil, is_collateral?: true) }
      let(:call_action) { controller.send(:populate_view_variables, :release) }
      let(:date_restrictions) { instance_double(Hash) }
      let(:next_business_day) { instance_double(Date) }

      before do
        allow(SecuritiesRequest).to receive(:new).and_return(securities_request)
        allow(controller).to receive(:populate_transaction_code_dropdown_variables)
        allow(controller).to receive(:populate_settlement_type_dropdown_variables)
        allow(controller).to receive(:populate_delivery_instructions_dropdown_variables)
        allow(controller).to receive(:populate_securities_table_data_view_variable)
        allow(controller).to receive(:date_restrictions)
        allow_any_instance_of(CalendarService).to receive(:find_next_business_day).and_return(next_business_day)
      end

      it 'sets `@pledge_type_dropdown`' do
        pledge_type_dropdown = [
          [I18n.t('securities.release.pledge_type.sbc'), SecuritiesRequest::PLEDGE_TO_VALUES[:sbc]],
          [I18n.t('securities.release.pledge_type.standard'), SecuritiesRequest::PLEDGE_TO_VALUES[:standard]]
        ]
        call_action
        expect(assigns[:pledge_type_dropdown]).to eq(pledge_type_dropdown)
      end
      {
        release: {
          upload_path: :securities_release_upload_path,
          download_path: :securities_release_download_path
        },
        pledge: {
          upload_path: :securities_pledge_upload_path,
          download_path: :securities_pledge_download_path
        }, safekeep: {
          upload_path: :securities_safekeep_upload_path,
          download_path: :securities_safekeep_download_path
        },
        transfer: {
          upload_path: :securities_transfer_upload_path,
          download_path: :securities_transfer_download_path
        }
      }.each do |type, details|
        it 'sets `@confirm_delete_text` appropriately' do
          controller.send(:populate_view_variables, type)
          expect(assigns[:confirm_delete_text]).to eq(I18n.t("securities.delete_request.titles.#{type}"))
        end
        it "sets `@download_path` to `#{details[:download_path]}`" do
          controller.send(:populate_view_variables, type)
          expect(assigns[:download_path]).to eq(controller.send(details[:download_path]))
        end
        it "sets `@upload_path` to `#{details[:upload_path]}`" do
          controller.send(:populate_view_variables, type)
          expect(assigns[:upload_path]).to eq(controller.send(details[:upload_path]))
        end
      end
      it 'calls `populate_transaction_code_dropdown_variables` with the @securities_request' do
        expect(controller).to receive(:populate_transaction_code_dropdown_variables).with(securities_request)
        call_action
      end
      it 'calls `populate_settlement_type_dropdown_variables` with the @securities_request' do
        expect(controller).to receive(:populate_settlement_type_dropdown_variables).with(securities_request)
        call_action
      end
      it 'calls `populate_delivery_instructions_dropdown_variables` with the @securities_request' do
        expect(controller).to receive(:populate_delivery_instructions_dropdown_variables).with(securities_request)
        call_action
      end
      it 'sets `@securities_request`' do
        call_action
        expect(assigns[:securities_request]).to eq(securities_request)
      end
      it 'creates a new instance of SecuritiesRequest if `@securities_request` not already set' do
        expect(SecuritiesRequest).to receive(:new).and_return(securities_request)
        call_action
      end
      it 'does not create a new instance of SecuritiesRequest if `securities_request` is already set' do
        controller.instance_variable_set(:@securities_request, securities_request)
        expect(SecuritiesRequest).not_to receive(:new)
        call_action
      end
      it 'sets `securities_request.securities` to the `securities` param if it is present' do
        controller.params = ActionController::Parameters.new({securities: securities})
        expect(securities_request).to receive(:securities=).with(securities)
        call_action
      end
      it 'does not set `securities_request.securities` if the `securities` param is not present' do
        expect(securities_request).not_to receive(:securities=)
        call_action
      end
      it 'uses the calendar service to find the next business day' do
        expect_any_instance_of(CalendarService).to receive(:find_next_business_day).with(Time.zone.today, 1.day)
        call_action
      end
      it 'sets `securities_request.trade_date` to the next available business day if there is not already a trade date' do
        expect(securities_request).to receive(:trade_date=).with(next_business_day)
        call_action
      end
      it 'does not set `securities_request.trade_date` if there is already a trade date' do
        allow(securities_request).to receive(:trade_date).and_return(instance_double(Date))
        expect(securities_request).not_to receive(:trade_date=)
        call_action
      end
      it 'sets `securities_request.settlement_date` to the next available business day if there is not already a settlement date' do
        expect(securities_request).to receive(:settlement_date=).with(next_business_day)
        call_action
      end
      it 'does not set `securities_request.settlement_date` if there is already a settlment date' do
        allow(securities_request).to receive(:settlement_date).and_return(instance_double(Date))
        expect(securities_request).not_to receive(:settlement_date=)
        call_action
      end
      it 'calls `populate_securities_table_data_view_variable` with the securities' do
        expect(controller).to receive(:populate_securities_table_data_view_variable).with(:release, securities)
        call_action
      end
      it 'sets the proper @form_data for a user to submit a request for authorization' do
        form_data = {
          url: securities_release_submit_path,
          submit_text: I18n.t('securities.release.submit_authorization')
        }
      end
      it 'sets `@date_restrictions` to the result of calling the `date_restrictions` method' do
        allow(controller).to receive(:date_restrictions).and_return(date_restrictions)
        call_action
        expect(assigns[:date_restrictions]).to eq(date_restrictions)
      end
    end

    describe '`populate_securities_table_data_view_variable`' do
      release_headings = [
        I18n.t('common_table_headings.cusip'),
        I18n.t('common_table_headings.description'),
        fhlb_add_unit_to_table_header(I18n.t('common_table_headings.original_par'), '$'),
        I18n.t('securities.release.settlement_amount', unit: fhlb_add_unit_to_table_header('', '$'), footnote_marker: fhlb_footnote_marker)
      ]
      transfer_headings = [
        I18n.t('common_table_headings.cusip'),
        I18n.t('common_table_headings.description'),
        fhlb_add_unit_to_table_header(I18n.t('common_table_headings.original_par'), '$')
      ]
      safekeep_and_pledge_headings = [
        I18n.t('common_table_headings.cusip'),
        fhlb_add_unit_to_table_header(I18n.t('common_table_headings.original_par'), '$'),
        I18n.t('securities.release.settlement_amount', unit: fhlb_add_unit_to_table_header('', '$'), footnote_marker: fhlb_footnote_marker),
        I18n.t('securities.safekeep.custodian_name', footnote_marker: fhlb_footnote_marker(1))
      ]
      let(:securities) { [FactoryGirl.build(:security)] }
      let(:call_method) { controller.send(:populate_securities_table_data_view_variable, :release, securities) }

      it 'sets `column_headings` for release' do
        call_method
        expect(assigns[:securities_table_data][:column_headings]).to eq(release_headings)
      end

      it 'sets `column_headings` for transfer' do
        controller.send(:populate_securities_table_data_view_variable, :transfer, securities)
        expect(assigns[:securities_table_data][:column_headings]).to eq(transfer_headings)
      end

      it 'sets `column_headings` for pledge' do
        controller.send(:populate_securities_table_data_view_variable, :pledge, securities)
        expect(assigns[:securities_table_data][:column_headings]).to eq(safekeep_and_pledge_headings)
      end

      it 'sets `column_headings` for safekeep' do
        controller.send(:populate_securities_table_data_view_variable, :safekeep, securities)
        expect(assigns[:securities_table_data][:column_headings]).to eq(safekeep_and_pledge_headings)
      end

      [:transfer, :release].each do |action|
        describe "when `#{action}` is passed in as the type" do
          let(:call_method) { controller.send(:populate_securities_table_data_view_variable, action, securities) }
          it 'contains rows of columns that have a `cusip` value' do
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns].first[:value]).to eq(securities.first.cusip)
            end
          end
          it "contains rows of columns that have a `cusip` value equal to `#{I18n.t('global.missing_value')}` if the security has no cusip value" do
            securities = [FactoryGirl.build(:security, cusip: nil)]
            controller.send(:populate_securities_table_data_view_variable, action, securities)
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
            controller.send(:populate_securities_table_data_view_variable, action, securities)
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][1][:value]).to eq(I18n.t('global.missing_value'))
            end
          end
          it 'converts nil `original_par` values into 0' do
            securities.first.original_par = nil
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][2][:value]).to eq(0.0)
            end
          end
          it 'contains rows of columns that have an `original_par` value' do
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][2][:value]).to eq(securities.first.original_par)
            end
          end
          it 'contains rows of columns whose `original_par` value has a type of `currency`' do
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][2][:type]).to eq(:currency)
            end
          end
          it 'contains rows of columns whose `original_par` value have a blank unit in its cell options' do
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][2][:options]).to include(unit: '')
            end
          end
          if action == :release
            it 'converts nil `payment_amount` values into 0' do
              securities.first.payment_amount = nil
              call_method
              expect(assigns[:securities_table_data][:rows].length).to be > 0
              assigns[:securities_table_data][:rows].each do |row|
                expect(row[:columns].last[:value]).to eq(0.0)
              end
            end
            it 'contains rows of columns whose last member has a `payment_amount` value' do
              call_method
              expect(assigns[:securities_table_data][:rows].length).to be > 0
              assigns[:securities_table_data][:rows].each do |row|
                expect(row[:columns].last[:value]).to eq(securities.first.payment_amount)
              end
            end
            it 'contains rows of columns whose last member has a type of `currency`' do
              call_method
              expect(assigns[:securities_table_data][:rows].length).to be > 0
              assigns[:securities_table_data][:rows].each do |row|
                expect(row[:columns].last[:type]).to eq(:currency)
              end
            end
          end
          it 'contains rows of columns whose last member have a blank unit in its cell options' do
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns].last[:options]).to include(unit: '')
            end
          end
          it 'contains an empty array for rows if no securities are passed in' do
            controller.send(:populate_securities_table_data_view_variable, action)
            expect(assigns[:securities_table_data][:rows]).to eq([])
          end
        end
      end

      [:pledge, :safekeep].each do |action|
        describe "when `#{action}` is passed in as the type" do
          let(:call_method) { controller.send(:populate_securities_table_data_view_variable, action, securities) }
          it 'contains rows of columns that have a `cusip` value' do
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns].first[:value]).to eq(securities.first.cusip)
            end
          end
          it "contains rows of columns that have a `cusip` value equal to `#{I18n.t('global.missing_value')}` if the security has no cusip value" do
            securities = [FactoryGirl.build(:security, cusip: nil)]
            controller.send(:populate_securities_table_data_view_variable, action, securities)
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns].first[:value]).to eq(I18n.t('global.missing_value'))
            end
          end
          it 'converts nil `original_par` values into 0' do
            securities.first.original_par = nil
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][1][:value]).to eq(0.0)
            end
          end
          it 'contains rows of columns that have an `original_par` value' do
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][1][:value]).to eq(securities.first.original_par)
            end
          end
          it 'contains rows of columns whose `original_par` value has a type of `currency`' do
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][1][:type]).to eq(:currency)
            end
          end
          it 'contains rows of columns whose `original_par` value have a blank unit in its cell options' do
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][1][:options]).to include(unit: '')
            end
          end
          it 'converts nil `payment_amount` values into 0' do
            securities.first.payment_amount = nil
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][2][:value]).to eq(0.0)
            end
          end
          it 'contains rows of columns that have a `payment_amount` value' do
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][2][:value]).to eq(securities.first.payment_amount)
            end
          end
          it 'contains rows of columns whose `payment_amount` value has a type of `currency`' do
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][2][:type]).to eq(:currency)
            end
          end
          it 'contains rows of columns whose `payment_amount` value have a blank unit in its cell options' do
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][2][:options]).to include(unit: '')
            end
          end
          it 'contains rows of columns that have a `custodian_name` value' do
            call_method
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][3][:value]).to eq(securities.first.custodian_name)
            end
          end
          it "contains rows of columns that have a `custodian_name` value equal to `#{I18n.t('global.missing_value')}` if the security has no custodian_name value" do
            securities = [FactoryGirl.build(:security, custodian_name: nil)]
            controller.send(:populate_securities_table_data_view_variable, action, securities)
            expect(assigns[:securities_table_data][:rows].length).to be > 0
            assigns[:securities_table_data][:rows].each do |row|
              expect(row[:columns][3][:value]).to eq(I18n.t('global.missing_value'))
            end
          end
          it 'contains an empty array for rows if no securities are passed in' do
            controller.send(:populate_securities_table_data_view_variable, action)
            expect(assigns[:securities_table_data][:rows]).to eq([])
          end
        end
      end
    end

    describe '`translated_dropdown_mapping`' do
      let(:translated_string_1) { instance_double(String) }
      let(:translated_string_2) { instance_double(String) }
      let(:dropdown_hash) {{
        foo: {
          whiz: instance_double(String),
          text: instance_double(String)
        },
        bar: {
          bang: instance_double(String),
          text: instance_double(String)
        }
      }}
      let(:translated_hash) {{
        foo: {
          whiz: dropdown_hash[:foo][:whiz],
          text: translated_string_1
        },
        bar: {
          bang: dropdown_hash[:bar][:bang],
          text: translated_string_2
        }
      }}
      let(:call_method) { subject.send(:translated_dropdown_mapping, dropdown_hash) }
      before do
        allow(I18n).to receive(:t).with(dropdown_hash[:foo][:text]).and_return(translated_string_1)
        allow(I18n).to receive(:t).with(dropdown_hash[:bar][:text]).and_return(translated_string_2)
      end
      it 'returns a hash with I18n translated `text` values' do
        expect(call_method).to eq(translated_hash)
      end
    end

    describe '`date_restrictions`' do
      let(:today) { Time.zone.today }
      let(:max_date) { today + SecuritiesRequest::MAX_DATE_RESTRICTION }
      let(:min_dates) { { trade_date: today - SecuritiesRequest::MIN_TRADE_DATE_RESTRICTION,
                          settlement_date: today - (SecuritiesRequest::MIN_SETTLEMENT_DATE_RESTRICTION - 4.days) } }
      let(:holidays) do
        holidays = []
        rand(2..4).times do
          holidays << (today + rand(1..70).days)
        end
        holidays
      end
      let(:weekends) do
        weekends = []
        date_iterator = today.clone
        while date_iterator <= max_date do
          weekends << date_iterator.iso8601 if (date_iterator.sunday? || date_iterator.saturday?)
          date_iterator += 1.day
        end
      end
      let(:calendar_service) { instance_double(CalendarService, holidays: holidays) }
      let(:call_method) { subject.send(:date_restrictions) }

      before { allow(CalendarService).to receive(:new).and_return(calendar_service) }

      it 'creates a new instance of the CalendarService with the request as an arg' do
        expect(CalendarService).to receive(:new).with(request).and_return(calendar_service)
        call_method
      end
      it 'calls `holidays` on the service instance with today as an arg' do
        expect(calendar_service).to receive(:holidays).with(today, any_args).and_return(holidays)
        call_method
      end
      it 'calls `holidays` on the service instance with a date three months from today as an arg' do
        expect(calendar_service).to receive(:holidays).with(anything, max_date).and_return(holidays)
        call_method
      end
      describe 'the returned hash' do
        [:trade_date, :settlement_date].each do |date_type|
          it "`#{date_type}` has a `max_date` of `today` plus the `SecuritiesRequest::MAX_DATE_RESTRICTION`" do
            expect(call_method[date_type][:max_date]).to eq(max_date)
          end
          it 'has the correct `min_date`' do
            expect(call_method[date_type][:min_date]).to eq(min_dates[date_type])
          end
          describe 'the `invalid_dates` array' do
            it 'includes all dates returned from the CalendarService as iso8601 strings' do
              holidays_strings = holidays.map{|holiday| holiday.iso8601}
              expect(call_method[date_type][:invalid_dates]).to include(*holidays_strings)
            end
            it 'includes all weekends between the today and the max date' do
              expect(call_method[date_type][:invalid_dates]).to include(*weekends)
            end
          end
        end
      end
    end

    describe '`prioritized_securities_request_error`' do
      generic_error_message = I18n.t('securities.release.edit.generic_error_html', phone_number: securities_services_phone_number, email: securities_services_email)
      member_not_set_up_error_message = I18n.t('securities.release.edit.member_not_set_up_html', email: securities_services_email, phone: securities_services_phone_number)

      let(:errors) {{
        foo: [SecureRandom.hex],
        bar: [SecureRandom.hex],
        settlement_date: [SecureRandom.hex],
        securities: [SecureRandom.hex],
        base: [SecureRandom.hex]
      }}
      let(:securities_request) { instance_double(SecuritiesRequest, errors: errors) }
      let(:call_method) { subject.send(:prioritized_securities_request_error, securities_request) }

      it 'returns nil if no errors are present on the securities_request' do
        allow(securities_request).to receive(:errors).and_return({})
        expect(call_method).to be_nil
      end
      describe 'when the error object contains a `member` error' do
        let(:errors) {{ member: [SecureRandom.hex],
                        settlement_date: [SecureRandom.hex],
                        securities: [SecureRandom.hex],
                        base: [SecureRandom.hex] }}
        it 'returns the member not set up message' do
          expect(call_method).to eq(member_not_set_up_error_message)
        end
      end
      describe 'when the error object contains standard error keys' do
        it 'returns the standard message for the first key it finds' do
          expect(call_method).to eq(errors[:foo].first)
        end
      end
      describe 'when the error object does not contain standard error keys' do
        let(:errors) {{
          settlement_date: [SecureRandom.hex],
          securities: [SecureRandom.hex],
          base: [SecureRandom.hex]
        }}

        it 'returns the standard message for the `settlement_date` error' do
          expect(call_method).to eq(errors[:settlement_date].first)
        end

        describe 'when there is a `securities` error but no `settlement_date` error' do
          let(:errors) {{
            securities: [SecureRandom.hex],
            base: [SecureRandom.hex]
          }}

          it 'returns the standard message for the `securities` error' do
            expect(call_method).to eq(errors[:securities].first)
          end
        end

        describe 'when there is a `base` error but no other specific error' do
          let(:errors) {{
            base: [SecureRandom.hex]
          }}

          it 'returns a generic error message' do
            expect(call_method).to eq(generic_error_message)
          end
        end
      end
    end
    describe '`prioritized_security_error`' do
      let(:security) { instance_double(Security, errors: nil) }
      let(:error_message) { instance_double(String) }
      let(:other_error_message) { instance_double(String) }
      let(:errors) {{
        foo: [error_message, other_error_message],
        bar: [other_error_message]
      }}
      let(:call_method) { subject.send(:prioritized_security_error, security) }

      it 'returns nil if the passed security contains no errors' do
        expect(call_method).to be nil
      end
      it 'returns the first error message from the security object it is passed' do
        allow(security).to receive(:errors).and_return(errors)
        expect(call_method).to eq(error_message)
      end
      describe 'when the error hash contains Security::CURRENCY_ATTRIBUTES' do
        let(:currency_attr_error) { instance_double(String) }

        before do
          errors[Security::CURRENCY_ATTRIBUTES.sample] = [currency_attr_error]
          allow(security).to receive(:errors).and_return(errors)
        end

        it 'prioritizes other errors above the Security::CURRENCY_ATTRIBUTES errors' do
          expect(call_method).to eq(error_message)
        end
        it 'returns the first error message of the first Security::CURRENCY_ATTRIBUTES error if no other errors are present' do
          [:foo, :bar].each {|error| security.errors.delete(error) }
          expect(call_method).to eq(currency_attr_error)
        end
      end
    end

    describe '`type_matches_kind`' do
      {
        release: [:pledge_release, :safekept_release],
        transfer: [:pledge_transfer, :safekept_transfer],
        safekeep: [:safekept_intake],
        pledge: [:pledge_intake]
      }.each do |type, valid_kinds|
        invalid_kinds = SecuritiesRequest::KINDS - valid_kinds
        valid_kinds.each do |kind|
          it "returns true when `kind` is `#{kind}`" do
            expect(subject.send(:type_matches_kind, type, kind)).to be true
          end
        end
        invalid_kinds.each do |kind|
          it "returns false when `kind` is `#{kind}`" do
            expect(subject.send(:type_matches_kind, type, kind)).to be false
          end
        end
      end
      describe 'when `type` is anything other than :release, :transfer :safekeep or :pledge' do
        it 'returns nil' do
          expect(subject.send(:type_matches_kind, SecureRandom.hex, SecureRandom.hex)).to be nil
        end
      end
    end
    describe '`populate_authorize_request_view_variables`' do
      describe 'when passed a kind that is not a valid SecuritiesRequest `kind`' do
        let(:call_method) { controller.send(:populate_authorize_request_view_variables, SecureRandom.hex) }
        it 'does not set `@title`' do
          call_method
          expect(assigns[:title]).to be_nil
        end
        it 'does not set `@contact`' do
          call_method
          expect(assigns[:contact]).to be_nil
        end
      end
      {
        safekept_release: I18n.t('securities.authorize.titles.safekept_release'),
        safekept_intake: I18n.t('securities.authorize.titles.safekept_intake'),
        safekept_transfer: I18n.t('securities.authorize.titles.transfer'),
        pledge_release: I18n.t('securities.authorize.titles.pledge_release'),
        pledge_intake: I18n.t('securities.authorize.titles.pledge_intake'),
        pledge_transfer: I18n.t('securities.authorize.titles.transfer')
      }.each do |kind, title|
        describe "when the passed `kind` is `#{kind}`" do
          let(:title) { title }
          let(:call_method) { controller.send(:populate_authorize_request_view_variables, kind) }

          it "sets `@title` appropriately" do
            call_method
            expect(assigns[:title]).to eq(title)
          end
          it "calls `populate_contact_info_by_kind` with `#{kind}`" do
            expect(controller).to receive(:populate_contact_info_by_kind).with(kind)
            call_method
          end
        end
      end
    end
    describe '`populate_contact_info_by_kind`' do
      let(:sentinel) { instance_double(String) }

      it 'does not set @contact when passed an unknown kind' do
        controller.send(:populate_contact_info_by_kind, SecureRandom.hex)
        expect(assigns[:contact]).to be_nil
      end
      SecuritiesRequest::SECURITIES_KINDS.each do |kind|
        describe "when passed `#{kind}`" do
          let(:call_method) { controller.send(:populate_contact_info_by_kind, kind) }

          it 'sets the `@contact[:email_address]` value to the result of the `securities_services_email` helper method' do
            allow(controller).to receive(:securities_services_email).and_return(sentinel)
            call_method
            expect(assigns[:contact][:email_address]).to eq(sentinel)
          end
          it 'sets the `@contact[:phone_number]` value to the result of the `securities_services_phone_number` helper method' do
            allow(controller).to receive(:securities_services_phone_number).and_return(sentinel)
            call_method
            expect(assigns[:contact][:phone_number]).to eq(sentinel)
          end
          it 'sets the `@contact[:mailto_text]` value to the appropriate string' do
            call_method
            expect(assigns[:contact][:mailto_text]).to eq(I18n.t('contact.collateral_departments.securities_services.title'))
          end
        end
      end
      SecuritiesRequest::COLLATERAL_KINDS.each do |kind|
        let(:call_method) { controller.send(:populate_contact_info_by_kind, kind) }

        it 'sets the `@contact[:email_address]` value to the result of the `collateral_operations_email` helper method' do
          allow(controller).to receive(:collateral_operations_email).and_return(sentinel)
          call_method
          expect(assigns[:contact][:email_address]).to eq(sentinel)
        end
        it 'sets the `@contact[:phone_number]` value to the result of the `collateral_operations_phone_number` helper method' do
          allow(controller).to receive(:collateral_operations_phone_number).and_return(sentinel)
          call_method
          expect(assigns[:contact][:phone_number]).to eq(sentinel)
        end
        it 'sets the `@contact[:mailto_text]` value to the appropriate string' do
          call_method
          expect(assigns[:contact][:mailto_text]).to eq(I18n.t('contact.collateral_departments.collateral_operations.title'))
        end
      end
    end
    describe '`get_delivery_instructions`' do
      (SecuritiesRequest::DELIVERY_TYPES.keys - [:transfer]).each do |delivery_type|
        it 'returns the correct string for `delivery_type` `#{delivery_type}`' do
          expect(subject.send(:get_delivery_instructions, delivery_type)).to eq(I18n.t(SecuritiesController::DELIVERY_INSTRUCTIONS_DROPDOWN_MAPPING[delivery_type.to_sym][:text]))
        end
      end
    end
    describe '`set_edit_title_by_kind`' do
      {
        pledge_release: I18n.t('securities.release.title'),
        safekept_release: I18n.t('securities.release.title'),
        pledge_intake: I18n.t('securities.pledge.title'),
        safekept_intake: I18n.t('securities.safekeep.title'),
        pledge_transfer: I18n.t('securities.transfer.pledge.title'),
        safekept_transfer: I18n.t('securities.transfer.safekeep.title')
      }.each do |kind, title|
        describe "when the passed kind is `#{kind}`" do
          let(:call_method) { subject.send(:set_edit_title_by_kind, kind) }
          it "sets `@title` to `#{title}`" do
            call_method
            expect(assigns[:title]).to eq(title)
          end
        end
      end
      it 'does not assign `@title` if it does not recognize the kind' do
        subject.send(:set_edit_title_by_kind, SecureRandom.hex)
        expect(assigns[:title]).to be_nil
      end
    end
    describe '`is_request_collateral?`' do
      SecuritiesRequest::COLLATERAL_KINDS.each do |kind|
        it "returns `true` for `#{kind}`" do
          expect(subject.send(:is_request_collateral?, kind)).to eq(true)
        end
      end

      SecuritiesRequest::SECURITIES_KINDS.each do |kind|
        it "returns `false` for `#{kind}`" do
          expect(subject.send(:is_request_collateral?, kind)).to eq(false)
        end
      end

      it 'raises an error for an unsupported `kind`' do
        expect { subject.send(:is_request_collateral?, :unsupported_kind) }.to raise_error(ArgumentError)
      end
    end
    describe '`populate_form_data_by_kind`' do
      let(:securities_request) { instance_double(SecuritiesRequest) }
      describe 'when the current user is a collateral signer' do
        before do
          allow(securities_request).to receive(:is_collateral?).and_return(true)
        end
        allow_policy :security, :authorize_collateral?
        it 'sets the proper @form_data for an authorized collateral signer' do
          form_data = {
            url: securities_release_submit_path,
            submit_text: I18n.t('securities.release.authorize')
          }
          subject.send(:populate_form_data_by_kind, :pledge_intake)
          expect(assigns[:form_data]).to eq(form_data)
        end
      end
      describe 'when the current user is a securities signer' do
        before do
          allow(securities_request).to receive(:is_collateral?).and_return(false)
        end
        allow_policy :security, :authorize_securities?
        it 'sets the proper `@form_data` for an authorized securities signer' do
          form_data = {
            url: securities_release_submit_path,
            submit_text: I18n.t('securities.release.authorize')
          }
          subject.send(:populate_form_data_by_kind, :safekept_intake)
          expect(assigns[:form_data]).to eq(form_data)
        end
      end
    end
    describe '`get_delivery_instruction_rows`' do
      let(:delivery_type) { double('A Delivery Type') }
      let(:delivery_instruction_keys) {[]}
      let(:delivery_instructions) { double('Some Delivery Instructions') }
      let(:securities_request) { instance_double(SecuritiesRequest, delivery_type: delivery_type) }
      let(:call_method) { subject.send(:get_delivery_instruction_rows, securities_request) }

      before do
        allow(subject).to receive(:get_delivery_instructions).with(delivery_type).and_return(delivery_instructions)
        stub_const('SecuritiesRequest::DELIVERY_INSTRUCTION_KEYS', {delivery_type => delivery_instruction_keys})
      end

      it 'calls `get_delivery_instructions` with the delivery_type from the SecuritiesRequest' do
        expect(subject).to receive(:get_delivery_instructions).with(delivery_type)
        call_method
      end
      it 'builds a row for the result of `get_delivery_instructions`' do
        expect(call_method).to start_with(
        {
          columns: [
            { value: I18n.t('securities.requests.view.delivery_instructions.delivery_method') },
            { value: delivery_instructions }
          ]
        })
      end
      describe 'for each attribute in SecuritiesRequest::DELIVERY_INSTRUCTION_KEYS for the `delivery_type` of the SecuritiesRequest' do
        let(:delivery_instruction_keys) { [:aba_number, :mutual_fund_account_number] }
        let(:attribute_human_names) { [double('A Human Name for `aba_number`'), double('A Human Name for `mutual_fund_account_number`')] }
        let(:attribute_values) { [double('A Value for `aba_number`'), double('A Value for `mutual_fund_account_number`')] }
        before do
          delivery_instruction_keys.zip(attribute_human_names).each do |pair|
            allow(SecuritiesRequest).to receive(:human_attribute_name).with(pair.first).and_return(pair.last)
          end
          allow(securities_request).to receive_messages(Hash[delivery_instruction_keys.zip(attribute_values)])
        end
        it 'builds a row with the first column being the human name of the attribute' do
          expect(call_method).to include({
            columns: start_with({value: attribute_human_names.first})
          },
          {
            columns: start_with({value: attribute_human_names.last})
          })
        end
        it 'builds a row with the second column being the value of the attribute' do
          expect(call_method).to include({
            columns: end_with({value: attribute_values.first})
          },
          {
            columns: end_with({value: attribute_values.last})
          })
        end
        it 'builds one row per key' do
          expect(call_method.length).to be(delivery_instruction_keys.length + 1)
        end
      end
    end
  end
end
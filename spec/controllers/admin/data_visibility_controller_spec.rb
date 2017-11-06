require 'rails_helper'
require 'rspec/support/spec/string_matcher'

RSpec.describe Admin::DataVisibilityController, :type => :controller do
  login_user(admin: true)

  # Reports
  account_reports = [:account_summary, :authorizations, :settlement_transaction_account, :investments]
  capital_stock_reports = [:cap_stock_activity, :cap_stock_trial_balance, :cap_stock_leverage, :dividend_statement]
  price_indications_reports = [:current_price_indications, :historical_price_indications]
  collateral_reports = [:borrowing_capacity, :mortgage_collateral_update]
  credit_reports = [:todays_credit, :advances, :interest_rate, :letters_of_credit, :forward_commitments, :parallel_shift]
  securities_reports = [:securities_transactions, :cash_projections, :current_securities_position, :monthly_securities_position, :securities_services]

  all_report_names = [securities_reports, credit_reports, collateral_reports, price_indications_reports, capital_stock_reports, account_reports].flatten

  # User Interface Elements
  borrowing_capacity_elements = [:acct_summary_and_borrowing_cap_sidebar, :table_in_acct_summary_report]
  site_page_names = [:manage_advances, :manage_letters_of_credit, :manage_securities]

  it_behaves_like 'an admin controller'

  shared_examples 'a DataVisibilityController action with before_action methods' do
    it 'sets the active nav to :data_visibility' do
      expect(controller).to receive(:set_active_nav).with(:data_visibility)
      call_action
    end
    context 'when the current user can edit data visibility' do
      allow_policy :web_admin, :edit_data_visibility?
      it 'sets `@can_edit_data_visibility` to true' do
        call_action
        expect(assigns[:can_edit_data_visibility]).to be true
      end
    end
    context 'when the current user cannot edit data visbility' do
      deny_policy :web_admin, :edit_data_visibility?
      it 'sets `@can_edit_data_visibility` to false' do
        begin
          call_action
        rescue Pundit::NotAuthorizedError
        end
        expect(assigns[:can_edit_data_visibility]).to be false
      end
    end
  end

  RSpec.shared_examples 'it checks the edit_data_visibility? web_admin policy' do
    before { allow(subject).to receive(:authorize).and_call_original }
    it 'checks if the current user is allowed to edit data visibility' do
      expect(subject).to receive(:authorize).with(:web_admin, :edit_data_visibility?)
      call_action
    end
    it 'raises any errors raised by checking to see if the user is authorized to edit data visibility' do
      error = Pundit::NotAuthorizedError
      allow(subject).to receive(:authorize).with(:web_admin, :edit_data_visibility?).and_raise(error)
      expect{call_action}.to raise_error(error)
    end
  end

  describe 'GET view_flags' do
    let(:members_service) { instance_double(MembersService, global_disabled_reports: [], disabled_reports_for_member: [], all_members: []) }
    let(:call_action) { get :view_flags }

    before do
      allow(MembersService).to receive(:new).and_return(members_service)
    end

    it_behaves_like 'a DataVisibilityController action with before_action methods'
    it 'creates a new instance of the MembersService with the request' do
      expect(MembersService).to receive(:new).and_return(members_service)
      call_action
    end
    it 'calls `all_members` on the instance of MembersService' do
      expect(members_service).to receive(:all_members).and_return([])
      call_action
    end
    it 'raises an error if `all_members` returns nil' do
      allow(members_service).to receive(:all_members).and_return(nil)
      expect{call_action}.to raise_error('There has been an error and Admin::DataVisibilityController#view_flags has encountered nil. Check error logs.')
    end
    context 'when a member_id param is not present' do
      it 'calls `global_disabled_reports` on the instance of MembersService' do
        expect(members_service).to receive(:global_disabled_reports).and_return([])
        call_action
      end
      it 'raises an error if `global_disabled_reports` returns nil' do
        allow(members_service).to receive(:global_disabled_reports).and_return(nil)
        expect{call_action}.to raise_error('There has been an error and Admin::DataVisibilityController#view_flags has encountered nil. Check error logs.')
      end
      it 'sets a `@member_dropdown` instance variable with a `default_value` of `all`' do
        call_action
        expect(assigns[:member_dropdown][:default_value]).to eq('all')
      end
    end
    context 'when a member_id param is present' do
      let(:member_id) { SecureRandom.hex }
      let(:call_action) { get :view_flags, member_id: member_id}
      it 'calls `disabled_reports_for_member` with the member_id on the instance of MembersService' do
        expect(members_service).to receive(:disabled_reports_for_member).with(member_id).and_return([])
        call_action
      end
      it 'raises an error if `disabled_reports_for_member` returns nil' do
        allow(members_service).to receive(:disabled_reports_for_member).and_return(nil)
        expect{call_action}.to raise_error('There has been an error and Admin::DataVisibilityController#view_flags has encountered nil. Check error logs.')
      end
      it 'sets a `@member_dropdown` instance variable with a `default_value` that is the member_id' do
        call_action
        expect(assigns[:member_dropdown][:default_value]).to eq(member_id)
      end
    end
    describe 'setting the view instance variables for the tables' do
      let(:disabled_web_flags) { double('disabled web flags') }
      let(:table_sentinel) { double('table instance variable') }
      before do
        allow(controller).to receive(:data_visibility_table)
        allow(members_service).to receive(:global_disabled_reports).and_return(disabled_web_flags)
      end
      {
        account_table: account_reports,
        capital_stock_table: capital_stock_reports,
        price_indications_table: price_indications_reports,
        collateral_table: collateral_reports,
        credit_table: credit_reports,
        securities_table: securities_reports,
        borrowing_cap_elements_table: borrowing_capacity_elements,
        page_names_table: site_page_names
      }.each do |instance_var, web_flag_keys|
        describe "setting the `@#{instance_var}`" do
          it 'calls `data_visibility_table` with the disabled web flags' do
            expect(controller).to receive(:data_visibility_table).with(disabled_web_flags, anything)
            call_action
          end
          it 'calls `data_visibility_table` with an array of web flag names associated with the table' do
            expect(controller).to receive(:data_visibility_table).with(anything, web_flag_keys)
            call_action
          end
          it "sets `@#{instance_var}` to result of calling `data_visibility_table`" do
            allow(controller).to receive(:data_visibility_table).with(anything, web_flag_keys).and_return(table_sentinel)
            call_action
            expect(assigns[instance_var]).to eq(table_sentinel)
          end
        end
      end
    end
    describe 'setting the `@member_dropdown` view variable' do
      describe 'the `options` value' do
        let(:member) {{
          name: instance_double(String),
          id: instance_double(Integer)
        }}
        it "has a first member whose text is #{I18n.t('admin.data_visibility.manage_data_visibility.all_members')}" do
          call_action
          expect(assigns[:member_dropdown][:options].first.first).to eq(I18n.t('admin.data_visibility.manage_data_visibility.all_members'))
        end
        it "has a first member whose value is `all`" do
          call_action
          expect(assigns[:member_dropdown][:options].first.last).to eq('all')
        end
        it 'contains an array for each member' do
          members = Array.new(rand(2..5)) {instance_double(Hash, :[] => nil)}
          allow(members_service).to receive(:all_members).and_return(members)
          call_action
          expect(assigns[:member_dropdown][:options].length).to eq(members.length + 1)
        end
        it 'sets the text of the member entry to the name of the member' do
          allow(members_service).to receive(:all_members).and_return([member])
          call_action
          expect(assigns[:member_dropdown][:options].last.first).to eq(member[:name])
        end
        it 'sets the value of the member entry to the id of the member' do
          allow(members_service).to receive(:all_members).and_return([member])
          call_action
          expect(assigns[:member_dropdown][:options].last.last).to eq(member[:id])
        end
      end
    end
  end

  describe 'PUT `update_flags`' do
    allow_policy :web_admin, :edit_data_visibility?
    let(:member_id) { rand(1000..9999) }
    let(:members_service) { instance_double(MembersService, update_global_data_visibility: nil, update_data_visibility_for_member: nil) }
    let(:flag_name) { described_class::DATA_VISIBILITY_MAPPING.keys.sample }
    let(:results) { double('some results') }
    let(:flags) {{
        flag_name => SecureRandom.hex
    }}
    let(:call_action) { put :update_flags, data_visibility_flags: flags }
    before do
      allow(MembersService).to receive(:new).and_return(members_service)
    end

    it_behaves_like 'a DataVisibilityController action with before_action methods'
    it_behaves_like 'it checks the edit_data_visibility? web_admin policy'

    it 'creates a new instance of `MembersService` with the request' do
      expect(MembersService).to receive(:new).and_return(members_service).with(request)
      call_action
    end
    shared_examples 'it updates the data visibility flags globally' do
      describe 'processing the `data_visibility_flags` params' do
        it 'sets the `web_flag_id` to the `flag` value of the corresponding data source in `DATA_VISIBILITY_MAPPING`' do
          expect(members_service).to receive(:update_global_data_visibility).with([hash_including(web_flag_id: described_class::DATA_VISIBILITY_MAPPING[flag_name][:flags].first)])
          call_action
        end
        it 'sets the `visible` attribute to `true` if the value of the param is `on`' do
          flags[flag_name] = 'on'
          expect(members_service).to receive(:update_global_data_visibility).with([hash_including(visible: true)])
          call_action
        end
        it 'sets the `visible` attribute to `true` if the value of the param is `off`' do
          flags[flag_name] = 'off'
          expect(members_service).to receive(:update_global_data_visibility).with([hash_including(visible: false)])
          call_action
        end
      end
      it 'calls `set_flash_message` with the results of `update_global_data_visibility`' do
        allow(members_service).to receive(:update_global_data_visibility).and_return(results)
        expect(controller).to receive(:set_flash_message).with(results)
        call_action
      end
      it 'calls `set_flash_message` with a hash containing an error if `update_global_data_visibility` returns nil' do
        allow(members_service).to receive(:update_global_data_visibility).and_return(nil)
        expect(controller).to receive(:set_flash_message).with({error: 'There has been an error and Admin::DataVisibilityController#update_flags has encountered nil'})
        call_action
      end
    end
    context 'when no member_id param is passed' do
      it_behaves_like 'it updates the data visibility flags globally'
    end
    context 'when `all` is passed as the member_id param' do
      let(:call_action) { put :update_flags, member_id: 'all', data_visibility_flags: flags }
      it_behaves_like 'it updates the data visibility flags globally'
    end
    context 'when a member_id param is passed' do
      let(:call_action) { put :update_flags, member_id: member_id, data_visibility_flags: flags }

      it 'calls `update_data_visibility_for_member` with the member_id string' do
        expect(members_service).to receive(:update_data_visibility_for_member).with(member_id.to_s, anything)
        call_action
      end
      describe 'processing the `data_visibility_flags` params' do
        it 'sets the `web_flag_id` to the `flag` value of the corresponding data source in `DATA_VISIBILITY_MAPPING`' do
          expect(members_service).to receive(:update_data_visibility_for_member).with(anything, [hash_including(web_flag_id: described_class::DATA_VISIBILITY_MAPPING[flag_name][:flags].first)])
          call_action
        end
        it 'sets the `visible` attribute to `true` if the value of the param is `on`' do
          flags[flag_name] = 'on'
          expect(members_service).to receive(:update_data_visibility_for_member).with(anything, [hash_including(visible: true)])
          call_action
        end
        it 'sets the `visible` attribute to `true` if the value of the param is `off`' do
          flags[flag_name] = 'off'
          expect(members_service).to receive(:update_data_visibility_for_member).with(anything, [hash_including(visible: false)])
          call_action
        end
      end
      it 'calls `set_flash_message` with the results of `update_data_visibility_for_member`' do
        allow(members_service).to receive(:update_data_visibility_for_member).and_return(results)
        expect(controller).to receive(:set_flash_message).with(results)
        call_action
      end
      it 'calls `set_flash_message` with a hash containing an error if `update_data_visibility_for_member` returns nil' do
        allow(members_service).to receive(:update_data_visibility_for_member).and_return(nil)
        expect(controller).to receive(:set_flash_message).with({error: 'There has been an error and Admin::DataVisibilityController#update_flags has encountered nil'})
        call_action
      end
    end
    it 'redirects to the `view_flags` action with the member_id param' do
      put :update_flags, member_id: member_id, data_visibility_flags: flags
      expect(response).to redirect_to(data_visibility_flags_url(member_id: member_id))
    end
  end

  describe 'GET view_status' do
    let(:members_service) { instance_double(MembersService, global_disabled_reports: [], members_with_disabled_reports: [] ) }
    let(:call_action) { get :view_status }

    before do
      allow(MembersService).to receive(:new).and_return(members_service)
    end

    it_behaves_like 'a DataVisibilityController action with before_action methods'
    it 'creates a new instance of the MembersService with the request' do
      expect(MembersService).to receive(:new).and_return(members_service)
      call_action
    end
    it 'raises an error if `global_disabled_reports` returns nil' do
      allow(members_service).to receive(:global_disabled_reports).and_return(nil)
      expect{call_action}.to raise_error('There has been an error and Admin::DataVisibilityController#view_status has encountered nil. Check error logs.')
    end

    it 'raises an error if `@institutions_with_disabled_items` returns nil' do
      allow(members_service).to receive(:global_disabled_reports).and_return(nil)
      expect{call_action}.to raise_error('There has been an error and Admin::DataVisibilityController#view_status has encountered nil. Check error logs.')
    end

    describe 'setting the `@globally_disabled_reports` view instance variable' do
      let(:disabled_web_flags) { double('disabled web flags') }
      let(:table_sentinel) { double('table instance variable') }

      { globally_disabled_reports: [:letters_of_credit, :borrowing_capacity, :authorizations ] }
      before do
        allow(controller).to receive(:data_visibility_table)
        allow(members_service).to receive(:global_disabled_reports).and_return(disabled_web_flags)
      end

      it 'calls `data_visibility_table` with the disabled web flags' do
        expect(controller).to receive(:data_visibility_table).with(disabled_web_flags, anything, anything)
        call_action
      end
      it 'calls `data_visibility_table` with an array of all report names' do
        expect(controller).to receive(:data_visibility_table).with(anything, all_report_names, anything)
        call_action
      end
      it 'calls `data_visibility_table` with the `disabled_only` parameter set to `true` ' do
        expect(controller).to receive(:data_visibility_table).with(anything, anything, true)
        call_action
      end
      it 'sets `@globally_disabled_reports` to result of calling `data_visibility_table`' do
        allow(controller).to receive(:data_visibility_table).with(anything, anything, anything).and_return(table_sentinel)
        call_action
        expect(assigns[:globally_disabled_reports]).to eq(table_sentinel)
      end
    end

    describe 'setting the `@institutions_with_disabled_items` view instance variable' do
      let(:member_list) { double('list of members with disabled reports') }
      let(:table_sentinel) { double('table instance variable') }

      before do
        allow(controller).to receive(:institutions_disabled_data_table)
        allow(members_service).to receive(:members_with_disabled_reports).and_return(member_list)
      end

      it 'calls `institutions_disabled_data_table` with the list of members' do
        expect(controller).to receive(:institutions_disabled_data_table).with(member_list)
        call_action
      end
      it 'sets `@institutions_with_disabled_items` to the result of calling `institutions_disabled_data_table`' do
        allow(controller).to receive(:institutions_disabled_data_table).with(anything).and_return(table_sentinel)
        call_action
        expect(assigns[:institutions_with_disabled_items]).to eq(table_sentinel)
      end
    end
  end

  describe 'private methods' do
    describe '`data_visibility_table`' do
      visibility_mapping = described_class::DATA_VISIBILITY_MAPPING
      it 'returns a hash with a row for for each `report_name` it is passed' do
        report_names = Array.new(rand(2..5)){visibility_mapping.keys.sample}
        result = subject.send(:data_visibility_table, [], report_names)
        expect(result[:rows].length).to eq(report_names.length)
      end
      describe 'a row column' do
        let(:report_name) { visibility_mapping.keys.sample }
        let(:row) { subject.send(:data_visibility_table, [], [report_name])[:rows].first }
        context 'when the web flags associated with the passed report names overlaps with the passed flags' do
          let(:flags) { visibility_mapping[report_name][:flags] }
          let(:row) { subject.send(:data_visibility_table, flags, [report_name])[:rows].first }

          it 'has a `row_class` of `data-source-disabled`' do
            expect(row[:row_class]).to eq('data-source-disabled')
          end
          it 'has a first row with a `checked` attribute that is false' do
            expect(row[:columns].first[:checked]).to be false
          end
        end
        context 'when the web flags associated with the passed report names do not overlap with the passed flags' do
          it 'does not have a `row_class`' do
            expect(row[:row_class]).to be nil
          end
          it 'has a first row with a `checked` attribute that is true' do
            expect(row[:columns].first[:checked]).to be true
          end
        end
        describe 'the first column in the row' do
          let(:column) { row[:columns].first }

          it 'has a `name` that contains the passed report name' do
            expect(column[:name]).to eq("data_visibility_flags[#{report_name}]")
          end
          it 'has a `type` that is `checkbox`' do
            expect(column[:type]).to eq(:checkbox)
          end
          it 'has a `label` attribute set to true' do
            expect(column[:label]).to be true
          end
          it 'has a `submit_unchecked_boxes` attribute set to true' do
            expect(column[:submit_unchecked_boxes]).to be true
          end
          context 'when the given user can edit data visibility' do
            before { controller.instance_variable_set(:@can_edit_data_visibility, true) }

            it 'has a `disabled` attribute set to false' do
              expect(column[:disabled]).to be false
            end
          end
          context 'when the given user cannot edit data visibility' do
            before { controller.instance_variable_set(:@can_edit_data_visibility, false) }

            it 'has a `disabled` attribute set to true' do
              expect(column[:disabled]).to be true
            end
          end
        end
        describe 'the second column in the row' do
          let(:column) { row[:columns].last }
          it 'has a value that is equal to the title associated with the report_name in the DATA_VISIBILITY_MAPPING' do
            expect(column[:value]).to eq(visibility_mapping[report_name][:title])
          end
        end
      end

      context '`data_visibility_table` called with the `disabled_only` flag set to `true`' do
        describe 'when there are globally disabled reports' do
          disabled_ids = [ 17, 35, 39 ]
          it 'returns a hash of disabled report names' do
            result = subject.send(:data_visibility_table, disabled_ids, all_report_names, true)
            expect(result[:rows].length).to eq(disabled_ids.length)
          end
          it 'return a hash with a single column' do
            result = subject.send(:data_visibility_table, disabled_ids, all_report_names, true)
            expect(result[:rows][0][:columns].length).to eq(1)
          end
        end
        describe 'when there are no globally disabled reports' do
          disabled_ids = []
          it 'returns an empty hash' do
            result = subject.send(:data_visibility_table, disabled_ids, all_report_names, true)
            expect(result[:rows].length).to eq(0)
          end
        end
      end
    end

    describe '`institutions_disabled_data_table`' do
      member_list = [ {"FHLB_ID"=> 1, "MEMBER_NAME"=> "Old McDonald's Leanding Window"},
                      {"FHLB_ID"=> 3, "MEMBER_NAME"=> "Irish Bank"},
                      {"FHLB_ID"=> 4, "MEMBER_NAME"=> "S'more Bank"} ]
      let(:result) {subject.send(:institutions_disabled_data_table, member_list)}
      let(:row) { subject.send(:institutions_disabled_data_table, member_list)[:rows].first}

      it 'returns a hash with a row for for each item in the `member_list` array it is passed' do
        expect(result[:rows].length).to eq(member_list.length)
      end

      describe 'the first column in the table' do
         it 'has a value that contains the member name' do
           expect(row[:columns].first[:value]).to eq(member_list[0]['MEMBER_NAME'].to_s)
         end
      end

      describe 'the second column in the table' do
        it 'is populated with a string value' do
          expect(row[:columns].second[:value].to_s).to include('member_id=' + member_list[0]['FHLB_ID'].to_s)
        end
      end
    end

    describe '`set_flash_message`' do
      let(:result) { {} }
      let(:error_message) { double('some error message') }
      let(:result_with_errors) {{error: error_message}}
      context 'when a single result set is passed' do
        it 'sets the `flash[:error]` message if the result set contains an error message' do
          subject.send(:set_flash_message, result_with_errors)
          expect(flash[:error]).to eq(I18n.t('admin.term_rules.messages.error'))
        end
        it 'logs the error' do
          expect(Rails.logger).to receive(:error).with(error_message)
          subject.send(:set_flash_message, result_with_errors)
        end
        it 'sets the `flash[:notice] message` if the result set does not contain an error message' do
          subject.send(:set_flash_message, result)
          expect(flash[:notice]).to eq(I18n.t('admin.term_rules.messages.success'))
        end
      end
      context 'when multiple result sets are passed' do
        it 'sets the `flash[:error]` message if any of the passed result sets contains an error message' do
          subject.send(:set_flash_message, [result, result_with_errors, result])
          expect(flash[:error]).to eq(I18n.t('admin.term_rules.messages.error'))
        end
        it 'logs all of the errors' do
          expect(Rails.logger).to receive(:error).exactly(2).times.with(error_message)
          subject.send(:set_flash_message, [result, result_with_errors, result_with_errors])
        end
        it 'sets the `flash[:notice] message` if none of the result sets contain an error message' do
          subject.send(:set_flash_message, [result, result, result])
          expect(flash[:notice]).to eq(I18n.t('admin.term_rules.messages.success'))
        end
      end
    end
  end
end
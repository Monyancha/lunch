require 'rails_helper'

RSpec.describe MortgagesController, :type => :controller do
  login_user

  let(:member_id) { double('A Member ID') }

  before { allow(controller).to receive(:current_member_id).and_return(member_id) }

  shared_examples 'a MortgagesController action that sets page-specific instance variables with a before filter' do
    it 'sets the active nav to `:mortgages`' do
      expect(controller).to receive(:set_active_nav).with(:mortgages)
      call_action
    end
    it 'sets the `@html_class` to `white-background` if no class has been set' do
      call_action
      expect(assigns[:html_class]).to eq('white-background')
    end
    it 'does not set `@html_class` if it has already been set' do
      html_class = instance_double(String)
      controller.instance_variable_set(:@html_class, html_class)
      call_action
      expect(assigns[:html_class]).to eq(html_class)
    end
  end

  RSpec.shared_examples 'it checks the `request?` `mortgage` policy' do
    before { allow(subject).to receive(:authorize).and_call_original }
    it 'checks if the current user is allowed to edit trade rules' do
      expect(subject).to receive(:authorize).with(:mortgage, :request?)
      call_action
    end
    it 'raises any errors raised by checking to see if the user is authorized to modify the advance' do
      error = Pundit::NotAuthorizedError
      allow(subject).to receive(:authorize).and_raise(error)
      expect{call_action}.to raise_error(error)
    end
  end

  describe 'get `new`' do
    allow_policy :mortgage, :request?

    let(:today) { Time.zone.today }
    let(:call_action) { get :new }
    before { allow(Time.zone).to receive(:today).and_return(today) }

    it_behaves_like 'a MortgagesController action that sets page-specific instance variables with a before filter'
    it_behaves_like 'it checks the `request?` `mortgage` policy'
    it 'sets the `@title`' do
      call_action
      expect(assigns[:title]).to eq(I18n.t('mortgages.new.title'))
    end
    it 'sets `@due_datetime` to a day one week from today, at 5pm' do
      call_action
      expect(assigns[:due_datetime]).to eq(Time.zone.parse("#{(today + 7.days).iso8601} 17:00:00"))
    end
    it 'sets `@extension_datetime` to a day two weeks from today, at 5pm' do
      call_action
      expect(assigns[:extension_datetime]).to eq(Time.zone.parse("#{(today + 14.days).iso8601} 17:00:00"))
    end
    it 'sets `@pledge_type_dropdown_options` to an array with each member array containing a `PLEDGE_TYPE_MAPPING` value-key pair' do
      call_action
      expect(assigns[:pledge_type_dropdown_options]).to eq(described_class::PLEDGE_TYPE_MAPPING.map{ |k,v| [v, k] })
    end
    it 'sets `@mcu_type_dropdown_options` to an array with each member array containing a `MCU_TYPE_MAPPING` value-key pair' do
      call_action
      expect(assigns[:mcu_type_dropdown_options]).to eq(described_class::MCU_TYPE_MAPPING.map{ |k,v| [v, k] })
    end
    it 'sets `@program_type_dropdown_options` to an array with each member array containing a `PROGRAM_TYPE_MAPPING` value-key pair' do
      call_action
      expect(assigns[:program_type_dropdown_options]).to eq(described_class::PROGRAM_TYPE_MAPPING.map{ |k,v| [v, k] })
    end
    it 'sets `@accepted_upload_mimetypes` to the joined `ACCEPTED_UPLOAD_MIMETYPES` constant' do
      call_action
      expect(assigns[:accepted_upload_mimetypes]).to eq(described_class::ACCEPTED_UPLOAD_MIMETYPES.join(', '))
    end
    it 'sets `@session_elevated` to the result of `session_elevated?`' do
      session_elevated = double('session info')
      allow(controller).to receive(:session_elevated?).and_return(session_elevated)
      call_action
      expect(assigns[:session_elevated]).to eq(session_elevated)
    end
  end

  describe 'get `manage`' do
    let(:today) { Time.zone.today }
    let(:call_action) { get :manage }
    let(:member_balance_service) { instance_double(MemberBalanceService, mcu_member_status: []) }
    before {
      allow(Time.zone).to receive(:today).and_return(today)
      allow(MemberBalanceService).to receive(:new).and_return(member_balance_service)
    }

    it_behaves_like 'a MortgagesController action that sets page-specific instance variables with a before filter'
    it 'sets the `@title`' do
      call_action
      expect(assigns[:title]).to eq(I18n.t('mortgages.manage.title'))
    end
    it 'sets `@due_datetime` to a day one week from today, at 5pm' do
      call_action
      expect(assigns[:due_datetime]).to eq(Time.zone.parse("#{(today + 7.days).iso8601} 17:00:00"))
    end
    it 'sets `@extension_datetime` to a day two weeks from today, at 5pm' do
      call_action
      expect(assigns[:extension_datetime]).to eq(Time.zone.parse("#{(today + 14.days).iso8601} 17:00:00"))
    end
    describe '`@table_data`' do
      it 'has the proper `column_headings`' do
        column_headings = [I18n.t('mortgages.manage.transaction_number'),
                           I18n.t('mortgages.manage.upload_type'),
                           I18n.t('mortgages.manage.authorized_by'),
                           I18n.t('mortgages.manage.authorized_on'),
                           I18n.t('mortgages.manage.status'),
                           I18n.t('mortgages.manage.number_of_loans'),
                           I18n.t('mortgages.manage.number_of_errors'),
                           I18n.t('mortgages.manage.action')]
        call_action
        expect(assigns[:table_data][:column_headings]).to eq(column_headings)
      end
      describe 'table `rows`' do
        it 'is an empty array if there are no mcus' do
          allow(member_balance_service).to receive(:mcu_member_status).and_return([])
          call_action
          expect(assigns[:table_data][:rows]).to eq([])
        end
        it 'builds a row for each letter of credit returned by `dedupe_locs`' do
          n = rand(1..10)
          mcu = []
          n.times { mcu << {transaction_number: SecureRandom.hex} }
          allow(member_balance_service).to receive(:mcu_member_status).and_return(mcu)
          call_action
          expect(assigns[:table_data][:rows].length).to eq(n)
        end
        describe 'populated rows' do
          let(:mcu) { {transaction_number: double('transaction_number'), translated_mcu_type: double('upload_type'), authorized_by: double('authorized_by'), authorized_on: double('authorized_on'), translated_status: double('status'), number_of_loans: double('number_of_loans'), number_of_errors: double('number_of_errors') } }
          before { allow(member_balance_service).to receive(:mcu_member_status).and_return([mcu]) }

          it 'calls `translated_mcu_transaction` with each mcu transaction' do
            expect(controller).to receive(:translated_mcu_transaction).and_return({})
            call_action
          end
          value_types = [[:transaction_number, nil], [:translated_mcu_type, nil], [:authorized_by, nil], [:authorized_on, nil], [:translated_status, nil], [:number_of_loans, :number], [:number_of_errors, :number]]
          value_types.each_with_index do |attr, i|
            attr_name = attr.first
            attr_type = attr.last
            describe "columns with cells based on the MCU attribute `#{attr_name}`" do
              before { allow(controller).to receive(:translated_mcu_transaction).and_return(mcu) }

              it "builds a cell with a `value` of `#{attr_name}`" do
                call_action
                expect(assigns[:table_data][:rows].length).to be > 0
                assigns[:table_data][:rows].each do |row|
                  expect(row[:columns][i][:value]).to eq(mcu[attr_name])
                end
              end
              it "builds a cell with a `type` of `#{attr_type}`" do
                call_action
                expect(assigns[:table_data][:rows].length).to be > 0
                assigns[:table_data][:rows].each do |row|
                  expect(row[:columns][i][:type]).to eq(attr_type)
                end
              end
            end
          end
          describe 'the `view_details` column' do
            let(:view_details_column) { call_action; assigns[:table_data][:rows][0][:columns].last }
            before { allow(controller).to receive(:translated_mcu_transaction).and_return(mcu) }

            it 'builds a cell with a `type` of `:link_list`' do
              expect(view_details_column[:type]).to eq(:link_list)
            end
            describe 'the `value` of the cell' do
              it "is an array in an array whose first member is `#{I18n.t('mortgages.manage.actions.view_details')}`" do
                expect(view_details_column[:value].first.first).to eq(I18n.t('mortgages.manage.actions.view_details'))
              end
              it 'is an array in an array whose second member is the `mcu_view_transaction_path` with the `transaction_number` of the mcu transaction' do
                expect(view_details_column[:value].first.last).to eq(mcu_view_transaction_path(transaction_number: mcu[:transaction_number]))
              end
            end
          end
        end
      end
    end
  end

  describe 'get `view`' do
    let(:transaction_number) { SecureRandom.hex }
    let(:matching_transaction) { {transaction_number: transaction_number} }
    let(:unmatching_transaction) { {transaction_number: SecureRandom.hex} }
    let(:member_balance_service) { instance_double(MemberBalanceService, mcu_member_status: [unmatching_transaction, matching_transaction]) }
    let(:call_action) { get :view, transaction_number: transaction_number }

    before { allow(MemberBalanceService).to receive(:new).and_return(member_balance_service) }

    it_behaves_like 'a MortgagesController action that sets page-specific instance variables with a before filter'
    it 'sets the `@title` appropriately' do
      call_action
      expect(assigns[:title]).to eq(I18n.t('mortgages.view.title'))
    end
    it 'creates a new instance of `MemberBalanceService` with the member_id and request' do
      expect(MemberBalanceService).to receive(:new).with(member_id, request).and_return(member_balance_service)
      call_action
    end
    it 'calls `mcu_member_status` on the instance of `MemberBalanceService`' do
      expect(member_balance_service).to receive(:mcu_member_status).and_return([unmatching_transaction, matching_transaction])
      call_action
    end
    it 'raises an error if `mcu_member_status` returns nil' do
      allow(member_balance_service).to receive(:mcu_member_status).and_return(nil)
      expect{call_action}.to raise_error(StandardError, 'There has been an error and MortgagesController#view has encountered nil. Check error logs.')
    end
    describe 'when no transactions are returned from `mcu_member_status`' do
      before { allow(member_balance_service).to receive(:mcu_member_status).and_return([]) }

      it 'raises an error containing the transaction number' do
        expect{call_action}.to raise_error(ArgumentError, "No matching MCU Status found for MCU with transaction_number: #{transaction_number}")
      end
    end
    describe 'when no matching transactions are returned from `mcu_member_status`' do
      before { allow(member_balance_service).to receive(:mcu_member_status).and_return([unmatching_transaction]) }

      it 'raises an error containing the transaction number' do
        expect{call_action}.to raise_error(ArgumentError, "No matching MCU Status found for MCU with transaction_number: #{transaction_number}")
      end
    end
    describe 'when a matching transaction is included in the set returned by `mcu_member_status`' do
      let(:translated_transaction_details) { instance_double(Hash) }
      it 'calls `translated_mcu_transaction` with the mcu transaction that has the same `transaction_number` as the passed `transaction_number` param' do
        expect(controller).to receive(:translated_mcu_transaction).with(matching_transaction)
        call_action
      end
      it 'does not call `translated_mcu_transaction` with any mcu transactions that have different `transaction_numbers` than the passed `transaction_number` param' do
        expect(controller).not_to receive(:translated_mcu_transaction).with(unmatching_transaction)
        call_action
      end
      it 'sets `@transaction_details` to the result of calling `translated_mcu_transaction`' do
        allow(controller).to receive(:translated_mcu_transaction).and_return(translated_transaction_details)
        call_action
        expect(assigns[:transaction_details]).to eq(translated_transaction_details)
      end
    end
  end

  describe 'private methods' do
    describe '`translated_mcu_transaction`' do
      let(:transaction) {{
        mcu_type: described_class::MCU_TYPE_MAPPING.keys.sample,
        pledge_type: described_class::PLEDGE_TYPE_MAPPING.keys.sample,
        program_type: described_class::PROGRAM_TYPE_MAPPING.keys.sample,
        status: described_class::STATUS_MAPPING.keys.sample
      }}
      let(:call_method) { subject.send(:translated_mcu_transaction, transaction) }
      it 'returns nil if passed nil' do
        expect(subject.send(:translated_mcu_transaction, nil)).to be nil
      end
      [
        {
          attr: :mcu_type,
          const_name: 'MCU_TYPE_MAPPING',
          const: described_class::MCU_TYPE_MAPPING
        },
        {
          attr: :pledge_type,
          const_name: 'PLEDGE_TYPE_MAPPING',
          const: described_class::PLEDGE_TYPE_MAPPING
        },
        {
          attr: :program_type,
          const_name: 'PROGRAM_TYPE_MAPPING',
          const: described_class::PROGRAM_TYPE_MAPPING
        },
        {
          attr: :status,
          const_name: 'STATUS',
          const: described_class::STATUS_MAPPING
        },
      ].each do |translation|
        it "sets `translated_#{translation[:attr]}` to the value of the `#{translation[:attr]}` key found in `#{translation[:const_name]}`" do
          expect(call_method["translated_#{translation[:attr]}"]).to eq(translation[:const][transaction[translation[:attr]]])
        end
        it "does not set `translated_#{translation[:attr]}` if there is no `#{translation[:attr]}` value in the passed transaction" do
          transaction.delete(translation[:attr])
          expect(call_method["translated_#{translation[:attr]}"]).to be nil
        end
      end
      describe 'the `error_percentage` attribute' do
        let(:number_of_loans) { rand(100..999) }
        let(:number_of_errors) { number_of_loans - rand(1..75) }
        let(:error_percentage) { call_method[:error_percentage] }
        it 'is not set if there is no `number_of_loans` value in the passed transaction' do
          expect(error_percentage).to be nil
        end
        context 'when there is a `number_of_loans` value in the passed transaction' do
          before { transaction[:number_of_loans] = number_of_loans }

          it 'is zero if there is no `number_of_errors` value in the passed transaction' do
            expect(error_percentage).to eq(0)
          end

          context 'when there is a `number_of_errors` value in the passed transaction' do
            before { transaction[:number_of_errors] = number_of_errors }

            it 'is the quotient of the `number_of_errors` divided by the `number_of_loans` times 100' do
              expect(error_percentage).to eq((number_of_errors.to_f / number_of_loans.to_f) * 100)
            end
          end
        end
      end
    end
  end
end
require 'spec_helper'

describe MAPI::ServiceApp do
  subject { MAPI::Services::Member::SecuritiesTransactions }

  describe 'Securities Transactions' do
    let(:fhlb_id)              { 750 }
    let(:rundate)              { Time.zone.parse('20 sept 2015').to_date }
    let(:custody_account_no)   { "082011" }
    let(:cusip)                { "31393RVW7" }
    let(:transaction_code)     { "DELD" }
    let(:security_description) { "FEDERAL HOME LN MTG GD REMIC" }
    let(:units)                { 10700000 }
    let(:maturity_date)        { "2016-06-18".to_date }
    let(:payment_or_principal) { 1609041.64 }
    let(:interest)             { 0 }
    let(:total)                { 1609041.64 }
    let(:before_hash) do
      {
          'fhlb_id'                => fhlb_id,
          'cur_btc_account_number' => custody_account_no,
          'cur_new_trans'          => 'Y',
          'cur_cusip'              => cusip,
          'cur_trans_code'         => transaction_code,
          'cur_desc_line_1'        => security_description,
          'cur_units'              => units,
          'cur_maturity_date'      => maturity_date,
          'cur_principal_amount'   => payment_or_principal,
          'cur_interest_amount'    => interest,
          'cur_total_amount'       => total
      }
    end
    let(:custody_account_no2)   { "082011" }
    let(:cusip2)                { "31398J7L1" }
    let(:transaction_code2)     { "DELD" }
    let(:security_description2) { "FEDERAL HOME LN MTG GD REMIC" }
    let(:units2)                { 10000000 }
    let(:maturity_date2)        { "2016-08-19".to_date }
    let(:payment_or_principal2) { 1449488.15 }
    let(:interest2)             { 0 }
    let(:total2)                { 1449488.15 }
    let(:before_hash2) do
      {
          'fhlb_id'                => fhlb_id,
          'cur_btc_account_number' => custody_account_no2,
          'cur_new_trans'          => 'N',
          'cur_cusip'              => cusip2,
          'cur_trans_code'         => transaction_code2,
          'cur_desc_line_1'        => security_description2,
          'cur_units'              => units2,
          'cur_maturity_date'      => maturity_date2,
          'cur_principal_amount'   => payment_or_principal2,
          'cur_interest_amount'    => interest2,
          'cur_total_amount'       => total2
      }
    end
    let(:after_hash) do
      {
          fhlb_id:              fhlb_id,
          custody_account_no:   custody_account_no,
          new_transaction:      true,
          cusip:                cusip,
          transaction_code:     transaction_code,
          security_description: security_description,
          units:                units,
          maturity_date:        maturity_date,
          payment_or_principal: payment_or_principal,
          interest:             interest,
          total:                total
      }.with_indifferent_access
    end
    let(:after_hash2) do
        {
            fhlb_id:              fhlb_id,
            custody_account_no:   custody_account_no2,
            new_transaction:      false,
            cusip:                cusip2,
            transaction_code:     transaction_code2,
            security_description: security_description2,
            units:                units2,
            maturity_date:        maturity_date2,
            payment_or_principal: payment_or_principal2,
            interest:             interest2,
            total:                total2
        }.with_indifferent_access
    end
    let(:final_securities_count_sql) { double('final_securities_count_sql') }
    let(:securities_transactions_sql) { double('securities_transactions_sql') }
    let(:logger) { instance_double(Logger, error: nil)  }
    let(:make_request) { get "/member/#{fhlb_id}/securities_transactions/#{rundate.iso8601}" }

    [:test, :development, :production].each do |environment|
      describe "#{environment}" do
        let(:securities_transactions) { make_request; JSON.parse(last_response.body) }
        before do
          allow(subject).to receive(:final_securities_count_sql).with(fhlb_id, rundate).and_return(final_securities_count_sql)
          allow(subject).to receive(:fetch_hashes).with(anything, final_securities_count_sql).and_return([{'RECORDSCOUNT' => 2}])
          allow(subject).to receive(:securities_transactions_sql).with(fhlb_id, rundate, true).and_return(securities_transactions_sql)
          allow(subject).to receive(:fetch_hashes).with(anything, securities_transactions_sql,{to_date: ['CUR_MATURITY_DATE'], to_i: ["CUR_UNITS"], to_f: %w(CUR_PRINCIPAL_AMOUNT CUR_INTEREST_AMOUNT CUR_TOTAL_AMOUNT)}, true).and_return([before_hash, before_hash2])
          allow(MAPI::ServiceApp).to receive(:environment).and_return(environment)
        end
        it "returns expected advances detail hash where value could not be nil in #{environment}" do
          securities_transactions['transactions'].each do |row|
            expect(row['fhlb_id']).to              be_kind_of(Numeric)
            expect(row['custody_account_no']).to   be_kind_of(String)
            expect(row['new_transaction']).to      be_boolean
            expect(row['cusip']).to                be_kind_of(String)
            expect(row['transaction_code']).to     be_kind_of(String)
            expect(row['security_description']).to be_kind_of(String)
            expect(row['units']).to                be_kind_of(Numeric)
            expect(row['maturity_date']).to        be_kind_of(String)
            expect(row['payment_or_principal']).to be_kind_of(Numeric)
            expect(row['interest']).to             be_kind_of(Numeric)
            expect(row['total']).to                be_kind_of(Numeric)
          end
        end
        describe 'when `MAPI::Services::Member::SecuritiesTransactions.securities_transactions` raises an error' do
          let(:err) { StandardError.new }
          before do
            allow(subject).to receive(:securities_transactions).and_raise(err)
            allow_any_instance_of(described_class).to receive(:logger).and_return(logger)
          end
          it 'returns a 503' do
            make_request
            expect(last_response.status).to be(503)
          end
          it 'logs the error' do
            expect(logger).to receive(:error).with(err)
            make_request
          end
        end
      end
    end

    [:test, :development, :production].each do |environment|
      describe 'securities_transactions' do
        let(:app) { instance_double(MAPI::ServiceApp, settings: double('settings', environment: instance_double(Symbol)), logger: double('logger')) }
        let(:fhlb_id){ double('fhlb_id') }
        let(:rundate){ double('rundate') }
        let(:previous_business_day){ double('previous_business_day')}
        let(:call_method) { subject.securities_transactions(app, fhlb_id, rundate) }

        it 'returns a valid result for final' do
          allow(subject).to receive(:fetch_final_securities_count).with(app.settings.environment, app.logger, fhlb_id, rundate).and_return([{'RECORDSCOUNT' => 2}])
          allow(subject).to receive(:fetch_securities_transactions).with(app.settings.environment, app.logger, fhlb_id, rundate, true).and_return([before_hash, before_hash2])
          expect(call_method).to eq({ final: true, transactions: [after_hash, after_hash2]})
        end

        it 'returns a valid result for non-final' do
          allow(subject).to receive(:fetch_final_securities_count).with(app.settings.environment, app.logger, fhlb_id, rundate).and_return([{'RECORDSCOUNT' => 0}])
          allow(subject).to receive(:fetch_securities_transactions).with(app.settings.environment, app.logger, fhlb_id, rundate, false).and_return([before_hash, before_hash2])
          expect(call_method).to eq({ final: false, transactions: [after_hash, after_hash2]})
        end

        it 'returns populate previous_business_day for empty transactions' do
          allow(subject).to receive(:fetch_final_securities_count).with(app.settings.environment, app.logger, fhlb_id, rundate).and_return([{'RECORDSCOUNT' => 0}])
          allow(subject).to receive(:fetch_securities_transactions).with(app.settings.environment, app.logger, fhlb_id, rundate, false).and_return([])
          allow(subject).to receive(:previous_business_day).with(app, rundate).and_return(previous_business_day)
          expect(call_method).to eq({ final: false, transactions: [], previous_business_day: previous_business_day})
        end
      end
    end

    describe 'fetch_securities_transactions' do
      let(:logger) { double('logger') }
      let(:fhlb_id) { double('fhlb id') }
      let(:date) { double('date') }
      let(:final_report) { double('preliminary or final report') }
      let(:sql) { double('securities_transactions_sql') }
      let(:results_hash) { double('results hash') }
      
      describe 'in the production environment' do
        environment = :production
        let(:call_method) { subject.fetch_securities_transactions(environment, logger, fhlb_id, rundate, final_report) }
        it 'calls `fetch_hashes` with the provided logger' do
          expect(subject).to receive(:fetch_hashes).with(logger, anything, anything, anything)
          call_method
        end
        it 'calls `fetch_hashes` with the appropriate sql' do
          allow(subject).to receive(:securities_transactions_sql).with(fhlb_id, rundate, final_report).and_return(sql)
          expect(subject).to receive(:fetch_hashes).with(anything, sql, anything, anything)
          call_method
        end
        it 'calls `fetch_hashes` with the appropriate field-type matchings' do
          expect(subject).to receive(:fetch_hashes).with(anything, anything, {to_date: ['CUR_MATURITY_DATE'], to_i: ["CUR_UNITS"], to_f: %w(CUR_PRINCIPAL_AMOUNT CUR_INTEREST_AMOUNT CUR_TOTAL_AMOUNT)}, anything)
          call_method
        end
        it 'calls `fetch_hashes` with a downcase argument of true' do
          expect(subject).to receive(:fetch_hashes).with(anything, anything, anything, true)
          call_method
        end
        it 'returns the result of `fetch_hashes`' do
          allow(subject).to receive(:fetch_hashes).and_return(results_hash)
          expect(call_method).to eq(results_hash)
        end
      end
      describe 'in an environment other than production' do
        environment = :development
        christmas_2015 = MAPI::Services::Member::SecuritiesTransactions::XMAS_2015
        it "returns an empty hash if the passed date is #{christmas_2015}" do
          expect(subject.fetch_securities_transactions(environment, logger, fhlb_id, christmas_2015, final_report)).to eq([])
        end
        it "returns fake securities transactions if #{christmas_2015} is not passed as the date" do
          expect(subject).to receive(:fake).with('securities_transactions')
          subject.fetch_securities_transactions(environment, logger, fhlb_id, date, final_report)
        end
      end
    end

    describe 'final_securities_count_sql' do
      let(:id){double('id')}
      let(:date){double('date')}
      let(:today){Date.today}
      
      it 'returns a string' do
        expect(subject.final_securities_count_sql(5, today)).to be_kind_of(String)
      end

      it 'calls quote with id' do
        allow(subject).to receive(:quote).with(date)
        expect(subject).to receive(:quote).with(id)
        subject.final_securities_count_sql(id, date)
      end

      it 'calls quote with date' do
        allow(subject).to receive(:quote).with(id)
        expect(subject).to receive(:quote).with(date)
        subject.final_securities_count_sql(id, date)
      end

      it 'returns a string containing properly converted date' do
        expect(subject.final_securities_count_sql(5, today)).to match(/TO_DATE\('#{today.iso8601}','YYYY-MM-DD HH24:MI:SS'\)/)
      end

      it 'returns a string containing id = 1234567890 for an id of 1234567890' do
        expect(subject.final_securities_count_sql(1234567890, today)).to match(/fhlb_id = 1234567890/i)
      end
    end

    describe 'securities_transactions_sql' do
      let(:id){double('id')}
      let(:date){double('date')}
      let(:today){Date.today}

      it 'returns a string' do
        expect(subject.securities_transactions_sql(5, today, true)).to be_kind_of(String)
      end

      describe 'quote gets called with correct arguments' do
        before do
          allow(subject).to receive(:quote)
        end
        it 'calls quote with id for non-final' do
          expect(subject).to receive(:quote).with(id)
          subject.securities_transactions_sql(id, date, false)
        end

        it 'calls quote with date for non-final' do
          expect(subject).to receive(:quote).with(date)
          subject.securities_transactions_sql(id, date, false)
        end

        it 'calls quote with AM for non-final' do
          expect(subject).to receive(:quote).with('AM')
          subject.securities_transactions_sql(id, date, false)
        end

        it 'calls quote with id for final' do
          expect(subject).to receive(:quote).with(id)
          subject.securities_transactions_sql(id, date, true)
        end

        it 'calls quote with today for final' do
          expect(subject).to receive(:quote).with(date)
          subject.securities_transactions_sql(id, date, true)
        end

        it 'calls quote with PM for final' do
          expect(subject).to receive(:quote).with('PM')
          subject.securities_transactions_sql(id, date, true)
        end
      end

      it 'returns a string containing properly converted date' do
        expect(subject.securities_transactions_sql(5, today, true)).to match(/TO_DATE\('#{today.iso8601}','YYYY-MM-DD HH24:MI:SS'\)/)
      end

      it 'returns a string containing id = 1234567890 for an id of 1234567890' do
        expect(subject.securities_transactions_sql(1234567890, today, true)).to match(/fhlb_id = 1234567890/)
      end

      it 'returns a string containing PM for final' do
        expect(subject.securities_transactions_sql(5, today, true)).to match(/'PM'/)
      end

      it 'returns a string containing AM for non-final' do
        expect(subject.securities_transactions_sql(5, today, false)).to match(/'AM'/)
      end
    end

    describe 'translate_securities_transactions_fields' do
      it 'maps fields appropriately for upper case keys' do
        expect(subject.translate_securities_transactions_fields(before_hash)).to eq(after_hash)
      end
    end

    describe '`previous_business_day` class method' do
      let(:date) { Time.zone.today }
      let(:app) { instance_double(described_class) }
      let(:holidays) { instance_double(Array, 'An Array of Holidays')}
      let(:next_business_day) { instance_double(Date) }
      let(:call_method) { subject.previous_business_day(app, date) }

      before do
        allow(MAPI::Services::Rates::Holidays).to receive(:holidays).and_return(holidays)
        allow(MAPI::Services::Rates).to receive(:find_next_business_day).and_return(next_business_day)
      end

      it 'fetches the holidays for the past week' do
        expect(MAPI::Services::Rates::Holidays).to receive(:holidays).with(app, date - 1.week, date - 1.day)
        call_method
      end

      it 'finds the next business day starting from yesterday' do
        expect(MAPI::Services::Rates).to receive(:find_next_business_day).with(date - 1.day, anything, anything)
        call_method
      end
      it 'finds the next business day using a negative increment' do
        expect(MAPI::Services::Rates).to receive(:find_next_business_day).with(anything, -1.day, anything)
        call_method
      end
      it 'finds the next business day using the holidays for the last week' do
        expect(MAPI::Services::Rates).to receive(:find_next_business_day).with(anything, anything, holidays)
        call_method
      end
      it 'returns the found date' do
        expect(call_method).to be(next_business_day)
      end
    end
  end
end

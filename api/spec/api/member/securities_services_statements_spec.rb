require 'spec_helper'

describe MAPI::ServiceApp do
  subject { MAPI::Services::Member::SecuritiesServicesStatements }

  before do
    header 'Authorization', "Token token=\"#{ENV['MAPI_SECRET_TOKEN']}\""
  end

  describe 'SecuritiesServicesStatements' do
    let(:logger) { double('logger')  }
    let(:fhlb_id){ double('fhlb_id') }
    let(:date){ double('date') }

    describe 'multi_level_merge' do
      it 'should work on the simple case' do
        result = {}
        expect(subject.multi_level_merge(result, [:key], :value)).to eq({key: :value})
        expect(subject.multi_level_merge(result, [:key2], :value2)).to eq({key: :value, key2: :value2})
      end

      it 'should work on the nested case' do
        result = {}
        expect(subject.multi_level_merge(result, %w(key1 key2 key3 key4), :value)).to eq({"key1" => { "key2" => { "key3" => { "key4" => :value }}}})
        expect(subject.multi_level_merge(result, %w(key1 key2 key3 key5), :value2)).to eq({"key1" => { "key2" => { "key3" => { "key4" => :value, "key5" => :value2 }}}})
      end
    end

    describe 'multi_level_transform' do
      let(:real_data){subject.fake('securities_services_statements')}
      let(:real_result) do
        {
            account_maintenance: { total: 100.0 },
            certifications: {total:0.0, cost: 40.0, count: 0},
            contact: {city: "OAKLAND", name: "UNITED BUSINESS BANK, F.S.B.", state: "CA", zip: "94621-1447"},
            debit_date: "30-JAN-15",
            handling: {total: 0.0, count: 0, cost: 40.0},
            income_disbursement: {total: 195.0, cost: 5.0, count: 39},
            member_id: 129,
            month_ending: "31-DEC-14",
            pledge_status_change: {total: 0.0, cost: 10.0, count: 0},
            research: {total: 0.0, count: 0, cost: 40.0},
            securities_fees: {dtc:       {cost: 2.5,  count: 19, total: 47.5},
                              euroclear: {cost: 0.01, count:  0, total:  0.0},
                              fed:       {cost: 1.0,  count: 30, total: 30.0},
                              funds:     {cost: 4.5,  count:  0, total:  0.0}},
            sta_account_number: "12345678",
            total: 372.5,
            transaction_fees: {dtc:       {cost:  15.0, count: 0, total: 0.0},
                               euroclear: {cost:  75.0, count: 0, total: 0.0},
                               fed:       {cost:  10.0, count: 0, total: 0.0},
                               funds:     {cost: 150.0, count: 0, total: 0.0}}
        }.with_indifferent_access
      end

      it 'should work on real data' do
        expect(subject.multi_level_transform(real_data.first.with_indifferent_access, subject::MAP_KEYS)).to eq(real_result)
      end

      it 'should work on the simple cases' do
        expect(subject.multi_level_transform({ key: :value, key2: :value2 }, { key: 'a/b/c', key2: 'a/b/d' }).with_indifferent_access).to eq({ 'a' => { 'b' => { 'c' => :value, 'd' => :value2 }}})
      end
    end

    describe 'production' do
      let(:env){ :production }
      let(:available_statements_sql){ double('available_statements_sql') }
      let(:available_statements_hashes){ double('available_statements_hashes') }
      let(:statement_sql){ double('statement_sql') }
      let(:statement_hash){ double('statement_record', with_indifferent_access: indifferent_statement_hash) }
      let(:indifferent_statement_hash){ double('indifferent_statement_hash') }
      let(:fixed_statement_hash) { double('fixed_statement_hash') }
      let(:transformed_statement_hash){ double('transformed_statement_hash') }

      before do
        allow(subject).to receive(:available_statements_sql).with(fhlb_id).and_return(available_statements_sql)
        allow(subject).to receive(:statement_sql).with(fhlb_id, date).and_return(statement_sql)
        allow(subject).to receive(:fetch_hashes).with(logger, available_statements_sql, {}, true).and_return(available_statements_hashes)
        allow(available_statements_hashes).to receive(:each)
        allow(subject).to receive(:fetch_hashes).with(logger, statement_sql, subject::MAP_VALUES).and_return([statement_hash])
        allow(subject).to receive(:multi_level_transform).with(statement_hash, subject::MAP_KEYS).and_return(transformed_statement_hash)
      end

      describe 'available_statements' do
        it 'should return available_statements_hashes' do
          expect(subject.available_statements(logger, env, fhlb_id)).to eq(available_statements_hashes)
        end
      end

      describe 'statement' do
        it 'should return transformed_statement_hash' do
          expect(subject.statement(logger, env, fhlb_id, date)).to eq(transformed_statement_hash)
        end

        it 'should handle empty results' do
          allow(subject).to receive(:fetch_hashes).with(logger, statement_sql, subject::MAP_VALUES).and_return([])
          expect(subject.statement(logger, env, fhlb_id, date)).to eq({})
        end
      end
    end
    [:test, :development].each do |env|
      describe env do
        describe 'available_statements' do
          let(:available_statements){ double('available_statements') }
          it 'should return available_statements_records' do
            allow(subject).to receive(:fake).with('securities_services_statements_available').and_return(available_statements)
            allow(available_statements).to receive(:each)
            expect(subject.available_statements(logger, env, fhlb_id)).to eq(available_statements)
          end
        end

        describe 'statement' do
          let(:statement_hash){ double('statement_hash', with_indifferent_access: indifferent_hash) }
          let(:indifferent_hash){ double('indifferent_hash') }
          let(:fixup_hash){ double('fixup_hash') }
          let(:transformed_hash){ double('transformed_hash') }
          it 'should return statement_records' do
            allow(subject).to receive(:fake).with('securities_services_statements').and_return([statement_hash])
            allow(subject).to receive(:multi_level_transform).with(statement_hash, subject::MAP_KEYS).and_return(transformed_hash)
            expect(subject.statement(logger, env, fhlb_id, date)).to eq(transformed_hash)
          end
        end
      end
    end
  end
end
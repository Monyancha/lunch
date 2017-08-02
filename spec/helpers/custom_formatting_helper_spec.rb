require 'rails_helper'

describe CustomFormattingHelper do
  describe '`fhlb_formatted_currency` method' do
    it 'converts a number into the approved FHLB currency format' do
      expect(helper.fhlb_formatted_currency(465465465, html: false)).to eq('$465,465,465.00')
    end
    it 'omits the dollar-sign and decimals if it is passed the number 0' do
      expect(helper.fhlb_formatted_currency(0, html: false)).to eq('0')
    end
    it 'shows the dollar-sign if it is passed the number 0 and force_unit is true' do
      expect(helper.fhlb_formatted_currency(0, html: false, force_unit: true)).to eq('$0.00')
    end
    it 'accepts an optional precision value' do
      expect(helper.fhlb_formatted_currency(465465465, precision: 0, html: false)).to eq('$465,465,465')
    end
    it 'wraps negative numbers in paranthesis' do
      expect(helper.fhlb_formatted_currency(-123456789, html: false)).to eq('$(123,456,789.00)')
    end
    it 'wraps the formatted currency in a span with a class indicating the sign if requested' do
      expect(helper.fhlb_formatted_currency(-123456789, html: true)).to eq('<span class="number-negative">$(123,456,789.00)</span>')
      expect(helper.fhlb_formatted_currency(123456789, html: true)).to eq('<span class="number-positive">$123,456,789.00</span>')
    end
    it 'defaults to HTML output' do
      expect(helper.fhlb_formatted_currency(123)).to eq('<span class="number-positive">$123.00</span>')
    end
    it 'returns nil if passed nil and the option `optional_number`' do
      expect(helper.fhlb_formatted_currency(nil, optional_number: true)).to be_nil
    end
    it 'returns the `missing_value` I18n value if passed nil' do
      expect(helper.fhlb_formatted_currency(nil)).to eq(I18n.t('global.missing_value'))
    end
  end

  describe '`fhlb_formatted_currency_whole` method' do
    it 'calls fhlb_formatted_currency with a default precision of 0' do
      number = double('Number')
      expect(helper).to receive(:fhlb_formatted_currency).with(number, {precision: 0})
      helper.fhlb_formatted_currency_whole(number)
    end
    it 'returns the `missing_value` I18n value if passed nil' do
      expect(helper.fhlb_formatted_currency_whole(nil)).to eq(I18n.t('global.missing_value'))
    end
  end

  describe '`fhlb_formatted_number` method' do
    it 'adds delimiters to the number' do
      expect(helper.fhlb_formatted_number(123456789, html: false)).to eq('123,456,789')
    end
    it 'wraps negative numbers in paranthesis' do
      expect(helper.fhlb_formatted_number(-123456789, html: false)).to eq('(123,456,789)')
    end
    it 'wraps the formatted currency in a span with a class indicating the sign if requested' do
      expect(helper.fhlb_formatted_number(-123456789, html: true)).to eq('<span class="number-negative">(123,456,789)</span>')
      expect(helper.fhlb_formatted_number(123456789, html: true)).to eq('<span class="number-positive">123,456,789</span>')
    end
    it 'defaults to HTML output' do
      expect(helper.fhlb_formatted_number(123)).to eq('<span class="number-positive">123</span>')
    end
    it 'returns nil if passed nil and the option `optional_number`' do
      expect(helper.fhlb_formatted_number(nil, optional_number: true)).to be_nil
    end
    it 'returns the `missing_value` I18n value if passed nil' do
      expect(helper.fhlb_formatted_number(nil)).to eq(I18n.t('global.missing_value'))
    end
  end

  describe '`fhlb_date_standard_numeric` method' do
    describe 'converting a date in to a string following the MM/DD/YYYY convention' do
      it 'should handle single digit months and days' do
        expect(helper.fhlb_date_standard_numeric(Date.new(2015,1,2))).to eq('01/02/2015')
      end
      it 'should handle double digit months and days' do
        expect(helper.fhlb_date_standard_numeric(Date.new(2015,11,20))).to eq('11/20/2015')
      end
      it 'returns the I18n value for `missing_value` if passed nil' do
        expect(helper.fhlb_date_standard_numeric(nil)).to eq(I18n.t('global.missing_value'))
      end
    end
  end

  describe '`fhlb_report_date_numeric` method' do
    describe 'converting a date in to a string following the MM-DD-YYYY convention' do
      it 'should remove leading zeros from single digit months and days' do
        expect(helper.fhlb_report_date_numeric(Date.new(2015,1,2))).to eq('1-2-2015')
      end
      it 'should handle double digit months and days' do
        expect(helper.fhlb_report_date_numeric(Date.new(2015,11,20))).to eq('11-20-2015')
      end
      it 'returns the I18n value for `missing_value` if passed nil' do
        expect(helper.fhlb_report_date_numeric(nil)).to eq(I18n.t('global.missing_value'))
      end
    end
  end

  describe '`fhlb_datetime_standard_numeric` method' do
    let(:date) {DateTime.new(2015,1,2, 10, 12, 13)}
    it 'converts a datetime into a string following the `Time MM/DD/YYYY` format' do
      expect(helper.fhlb_datetime_standard_numeric(date)).to eq('10:12 am 01/02/2015')
    end
    it 'returns the I18n value for `missing_value` if passed nil' do
      expect(helper.fhlb_datetime_standard_numeric(nil)).to eq(I18n.t('global.missing_value'))
    end
  end

  describe '`fhlb_datetime_standard_numeric_with_on` method' do
    let(:date) {DateTime.new(2015,1,2, 10, 12, 13)}
    it 'converts a datetime into a string following the `Time on MM/DD/YYYY` format' do
      expect(helper.fhlb_datetime_standard_numeric_with_on(date)).to eq('10:12 am on 01/02/2015')
    end
    it 'returns the I18n value for `missing_value` if passed nil' do
      expect(helper.fhlb_datetime_standard_numeric_with_on(nil)).to eq(I18n.t('global.missing_value'))
    end
  end

  describe '`fhlb_datetime_standard_numeric_with_at` method' do
    let(:date) {DateTime.new(2015,1,2, 10, 12, 13)}
    it 'converts a datetime into a string following the `MM/DD/YYYY at Time` format' do
      expect(helper.fhlb_datetime_standard_numeric_with_at(date)).to eq('01/02/2015 at 10:12 am')
    end
    it 'returns the I18n value for `missing_value` if passed nil' do
      expect(helper.fhlb_datetime_standard_numeric_with_at(nil)).to eq(I18n.t('global.missing_value'))
    end
  end

  describe '`fhlb_datetime_long_alpha_with_on` method' do
    let(:datetime) { instance_double(DateTime, strftime: nil) }
    let(:call_method) { helper.fhlb_datetime_long_alpha_with_on(datetime) }
    let(:sentinel) { instance_double(String) }
    before do
      allow(datetime).to receive(:to_datetime).and_return(datetime)
      allow(helper).to receive(:fhlb_date_long_alpha)
    end
    it 'returns the I18n value for `missing_value` if passed nil' do
      expect(helper.fhlb_datetime_long_alpha_with_on(nil)).to eq(I18n.t('global.missing_value'))
    end
    it 'interpolates a string with a `time` argument that uses the `%l:%M %P` format' do
      allow(datetime).to receive(:strftime).with('%l:%M %P').and_return(sentinel)
      expect(helper).to receive(:t).with(anything, hash_including(time: sentinel))
      call_method
    end
    it 'interpolates a string with a `date` argument that is the result of calling `fhlb_date_long_alpha`' do
      allow(helper).to receive(:fhlb_date_long_alpha).with(datetime).and_return(sentinel)
      expect(helper).to receive(:t).with(anything, hash_including(date: sentinel))
      call_method
    end
    it 'interpolates a string using the `global.time_on_date` value' do
      expect(helper).to receive(:t).with('global.time_on_date', any_args)
      call_method
    end
    it 'returns the interpolated string' do
      allow(helper).to receive(:t).and_return(sentinel)
      expect(call_method).to eq(sentinel)
    end
  end

  describe '`fhlb_date_long_alpha` method' do
    let(:date) {Date.new(2015,1,2)}
    it 'converts a date into an alphanumeric string following the `Month d, YYYY` format' do
      expect(helper.fhlb_date_long_alpha(date)).to eq('January 2, 2015')
    end
    it 'returns the I18n value for `missing_value` if passed nil' do
      expect(helper.fhlb_date_long_alpha(nil)).to eq(I18n.t('global.missing_value'))
    end
  end

  describe '`fhlb_date_short_alpha` method' do
    it 'converts a date into an alphanumeric string following the `Month YYYY` format' do
      [Date.new(2015,1,1), Date.new(2015,1,31), Date.new(2015,1,15)].each do |date|
        expect(helper.fhlb_date_short_alpha(date)).to eq('January 2015')
      end
    end
    it 'returns the I18n value for `missing_value` if passed nil' do
      expect(helper.fhlb_date_short_alpha(nil)).to eq(I18n.t('global.missing_value'))
    end
  end

  describe '`fhlb_formatted_phone_number` method' do
    it 'returns nil if it is not passed a phone number' do
      expect(helper.fhlb_formatted_phone_number(nil)).to be_nil
    end
    it 'converts a 10 digit phone number into the FHLB format' do
      expect(helper.fhlb_formatted_phone_number('1234567890')).to eq('(123) 456-7890')
    end
    it 'converts an 11 digit phone number into the FHLB format' do
      expect(helper.fhlb_formatted_phone_number('11234567890')).to eq('(123) 456-7890')
    end
    it 'approrpiately styles extentions if provided' do
      expect(helper.fhlb_formatted_phone_number('1234567890', '6789')).to eq('(123) 456-7890, ext. 6789')
    end
    it 'raises an exception if fewer than 10 digits are supplied' do
      expect {helper.fhlb_formatted_phone_number('123456789')}.to raise_error(ArgumentError)
    end
    it 'raises an exception if more than 11 digits are supplied' do
      expect {helper.fhlb_formatted_phone_number('123456789012')}.to raise_error(ArgumentError)
    end
    it 'raises an exception if 11 digits are supplied and the first is not a 1' do
      expect {helper.fhlb_formatted_phone_number('21234567890')}.to raise_error(ArgumentError)
    end
    it 'removes non-digit characters from the supplied string' do
      expect(helper.fhlb_formatted_phone_number('123-456 7890', '67a89')).to eq('(123) 456-7890, ext. 6789')
    end
    it 'does not include the ext section if a blank string was passed' do
      expect(helper.fhlb_formatted_phone_number('11234567890', '')).to eq('(123) 456-7890')
    end
    it 'does not include the ext section if a string without digits was passed' do
      expect(helper.fhlb_formatted_phone_number('11234567890', 'abc')).to eq('(123) 456-7890')
    end
  end

  describe '`fhlb_date_quarter` method' do
    [[1..3, 'First Quarter 2015'], [4..6, 'Second Quarter 2015'], [7..9, 'Third Quarter 2015'], [10..12, 'Fourth Quarter 2015']].each do |expectation|
      expectation.first.each do |month|
        it 'converts a date into its quarter representation' do
          expect(helper.fhlb_date_quarter(Date.new(2015, month, 2))).to eq(expectation.last)
        end
      end
    end
    it 'returns the I18n value for `missing_value` if passed nil' do
      expect(helper.fhlb_date_quarter(nil)).to eq(I18n.t('global.missing_value'))
    end
  end

  describe '`fhlb_add_unit_to_table_header` method' do
    it 'adds a (unit) to a string' do
      expect(helper.fhlb_add_unit_to_table_header('my header', '%')).to eq('my header (%)')
    end
  end

  describe '`fhlb_formatted_percentage` method' do
    it 'returns percentage with no precision' do
      expect(helper.fhlb_formatted_percentage(30.23)).to eq('30%')
    end
    it 'returns percentage with 2 precision' do
      expect(helper.fhlb_formatted_percentage(30.23, 2)).to eq('30.23%')
    end
    it 'returns the I18n value for `missing_value` if passed nil' do
      expect(helper.fhlb_formatted_percentage(nil)).to eq(I18n.t('global.missing_value'))
    end
  end

  describe '`fhlb_formated_currency_unit` method' do
    it 'returns two spans nested in a span with `$` as the default currency symbol and a currency with precision of 0' do
      expect(helper.fhlb_formated_currency_unit(30)).to eq("<span class=\"currency-alignment\"><span class=\"alignleft\">$</span><span class=\"alignright\"><span class=\"number-positive\">30</span></span></span>")
    end
    it 'returns two spans nested in a span with any passed in string as the currency symbol' do
      expect(helper.fhlb_formated_currency_unit(30, '£')).to eq("<span class=\"currency-alignment\"><span class=\"alignleft\">£</span><span class=\"alignright\"><span class=\"number-positive\">30</span></span></span>")
    end
    it 'returns currency with 2 precision and left/right align' do
      expect(helper.fhlb_formated_currency_unit(30, '$', 2)).to eq('<span class="currency-alignment"><span class="alignleft">$</span><span class="alignright"><span class="number-positive">30.00</span></span></span>')
    end
    it 'returns no currency span and a span with the I18n value for missing value when passed nil' do
      expect(helper.fhlb_formated_currency_unit(nil)).to eq("<span class=\"currency-alignment\"><span class=\"alignright\">#{I18n.t('global.missing_value')}</span></span>")
    end
  end

  describe '`mask_email`' do
    it 'returns nil if passed nil' do
      expect(helper.mask_email(nil)).to be_nil
    end
    it 'returns nil if passed a malformed email' do
      email = double('An Email')
      matches = double('MatchData', length: 5)
      allow(email).to receive(:match).and_return(matches)
      expect(helper.mask_email(email)).to be_nil
    end
    it 'should mask the email' do
      email = double('An Email')
      masked_email = double('MaskedEmail')
      matches = double('MatchData', length: 6)
      intermediary_1 = double('Masked Email Intermiedary 1')
      intermediary_2 = double('Masked Email Intermiedary 2')
      intermediary_3 = double('Masked Email Intermiedary 3')
      intermediary_4 = double('Masked Email Intermiedary 4')

      allow(matches).to receive(:[]).with(1).and_return(double('MatchData:1'))
      allow(matches).to receive(:[]).with(2).and_return(double('MatchData:2', length: rand(1..5)))
      allow(matches).to receive(:[]).with(3).and_return(double('MatchData:3'))
      allow(matches).to receive(:[]).with(4).and_return(double('MatchData:4', length: rand(1..5)))
      allow(matches).to receive(:[]).with(5).and_return(double('MatchData:5'))
      allow(matches[1]).to receive(:+).with('*' * matches[2].length).and_return(intermediary_1)
      allow(intermediary_1).to receive(:+).with('@').and_return(intermediary_2)
      allow(intermediary_2).to receive(:+).with(matches[3]).and_return(intermediary_3)
      allow(intermediary_3).to receive(:+).with('*' * matches[4].length).and_return(intermediary_4)
      allow(intermediary_4).to receive(:+).with(matches[5]).and_return(masked_email)
      allow(email).to receive(:match).and_return(matches)

      expect(helper.mask_email(email)).to be(masked_email)
    end
    describe 'with fixtures' do
      it 'returns nil if passed a malformed email' do
        ['foo', 'foo@bar', 'foo@bar%', '@foo.com'].each do |email|
          expect(helper.mask_email(email)).to be_nil
        end
      end
    end
    it 'should mask the email' do
      {
        'foo@example.com' => 'f**@e******.com',
        'monkey@example.co.bar' => 'm*****@e*********.bar'
      }.each do |input, output|
        expect(helper.mask_email(input)).to eq(output)
      end
    end
  end

  let(:first_name) { 'Robert' }
  let(:last_name) { 'Johnson' }
  let(:first_initial) { 'R.' }
  let(:properly_formatted_name) { 'R. Johnson' }

  describe '`fhlb_first_intial_last_name` method' do
    it 'returns empty string if first and last names are nil' do
      expect(helper.fhlb_first_intial_last_name(nil, nil)).to eq(nil)
      expect(helper.fhlb_first_intial_last_name(nil)).to eq(nil)
      expect(helper.fhlb_first_intial_last_name).to eq(nil)
    end

    it 'returns just the last name if the first name is missing' do
      expect(helper.fhlb_first_intial_last_name(nil, last_name)).to eq(last_name)
    end

    it 'returns the first initial and last name for a two word name' do
      expect(helper.fhlb_first_intial_last_name(first_name, last_name)).to eq(properly_formatted_name)
    end

    it 'returns just the first initial if the last name is missing' do
      expect(helper.fhlb_first_intial_last_name(first_name)).to eq(first_initial)
    end
  end

  describe '`fhlb_initials_from_full_name` method' do
    it 'returns empty string for nil' do
      expect(helper.fhlb_initials_from_full_name(nil)).to eq('')
    end

    it 'returns proper initials for a variety of names' do
      expect(helper.fhlb_initials_from_full_name('Prince')).to eq('P')
      expect(helper.fhlb_initials_from_full_name('Robert Johnson')).to eq('RJ')
      expect(helper.fhlb_initials_from_full_name('Vince Di Bona')).to eq('VDB')
      expect(helper.fhlb_initials_from_full_name("Martin O'Malley")).to eq('MO')
      expect(helper.fhlb_initials_from_full_name("    Tula does the @#}$%^&*()     Hula from Hawaii  ")).to eq('TDT@HFH')
    end
  end

  describe '`fhlb_formatted_time` method' do
    it 'returns the global missing value for nil' do
      expect(helper.fhlb_formatted_time(nil)).to eq(t('global.missing_value'))
    end

    it 'formats the time' do
      now = Time.zone.now
      { now => now.strftime('%l:%M%p'),
        Time.parse('1:30') => ' 1:30AM',
        Time.parse('12:30') => '12:30PM' }.each do |raw, formatted|
        expect(helper.fhlb_formatted_time(raw)).to eq(formatted)
      end
    end
  end

  describe '`fhlb_formatted_duration` method' do
    let(:duration_under_24_hours) { rand(1..86399).seconds }
    it 'throws an `ArgumentError` for negative values' do
      expect { helper.fhlb_formatted_duration(0 - rand(1..42)) }.to raise_error(ArgumentError)
    end
    it 'returns a valid response for zero' do
      expect(helper.fhlb_formatted_duration(0)).to eq("00:00:00")
    end
    it 'returns the global missing value for nil' do
      expect(helper.fhlb_formatted_duration(nil)).to eq(t('global.missing_value'))
    end
    it 'formats the duration (under 24 hours)' do
      expect(helper.fhlb_formatted_duration(duration_under_24_hours)).to eq(Time.at(duration_under_24_hours).utc.strftime('%H:%M:%S'))
    end
    it 'format the duration (over 24 hours)' do
      expect(helper.fhlb_formatted_duration(271545)).to eq('75:25:45')
    end
  end

  describe '`fhlb_footnote_marker` method' do
    marker = I18n.t('global.footnote_indicator')

    it "returns `#{marker}` if no index is passed" do
      expect(helper.fhlb_footnote_marker). to eq(marker)
    end
    10.times do |i|
      it "returns a string of `#{marker}`'s whose length is equal to the index plus one" do
        expect(helper.fhlb_footnote_marker(i).length).to eq(i + 1)
      end
    end
  end

  describe '`fhlb_date_iso8601`' do
    let(:iso8601_date) { instance_double(String) }
    let(:dateified_date) { instance_double(Date, strftime: iso8601_date)}
    let(:date) { double('date', to_date: dateified_date) }
    let(:call_method) { helper.fhlb_date_iso8601(date) }

    it 'turns the passed argument into a date' do
      expect(date).to receive(:to_date).and_return(dateified_date)
      call_method
    end
    it 'calls `strftime` on the date with the `%Y-%m-%d` format' do
      expect(dateified_date).to receive(:strftime).with('%Y-%m-%d')
      call_method
    end
    it 'returns the iso8601-formatted date' do
      expect(call_method).to eq(iso8601_date)
    end
    [{nil: nil}, {false: false}].each do |name, argument|
      context "when #{name} is passed" do
        context 'when the `allow_nil` argument is true' do
          it 'returns nil' do
            expect(helper.fhlb_date_iso8601(argument, true)).to be nil
          end
        end
        context 'when the `allow_nil` argument is false' do
          it 'returns the I18n value for `missing_value`' do
            expect(helper.fhlb_date_iso8601(argument, false)).to eq(I18n.t('global.missing_value'))
          end
        end
        context 'when the `allow_nil` argument is not set' do
          it 'returns nil' do
            expect(helper.fhlb_date_iso8601(argument)).to be nil
          end
        end
      end
    end
    it 'handles single digit months and days' do
      expect(helper.fhlb_date_iso8601(Date.new(2015,1,2))).to eq('2015-01-02')
    end
    it 'handles double digit months and days' do
      expect(helper.fhlb_date_iso8601(Date.new(2015,11,20))).to eq('2015-11-20')
    end
  end
end
require 'date'
require 'savon'
require 'active_support/core_ext/hash/indifferent_access'

module MAPI
  module Services
    module Rates
      include MAPI::Services::Base
      include MAPI::Shared::Constants
      include MAPI::Shared::Utils

      SOAP_OPEN_TIMEOUT = 0.2 # seconds
      SOAP_READ_TIMEOUT = 45 # seconds

      def self.find_next_business_day(candidate, delta, holidays)
        weekend_or_holiday?(candidate, holidays) ? find_next_business_day(candidate + delta, delta, holidays) : candidate
      end

      def self.get_maturity_date(original, frequency_unit, holidays)
        original_date = original.to_date
        candidate = find_next_business_day(original_date, 1.day, holidays)
        if %w(M Y).include?(frequency_unit) && candidate > original_date.end_of_month
          find_next_business_day(original_date, -1.day, holidays)
        else
          candidate
        end
      end

      def self.disabled?(live, loan_term, blackout_dates)
        blacked_out           = blackout_dates.include?( live['maturity_date'] )
        cant_trade            = !loan_term['trade_status']
        cant_display          = !loan_term['display_status']
        blacked_out || cant_trade || cant_display || live[:rate_band_info][:min_threshold_exceeded] || live[:rate_band_info][:max_threshold_exceeded]
      end

      def self.rate_band_info(live, rate_band)
        live_rate              = live[:rate].to_f
        low_band_off_delta     = rate_band['LOW_BAND_OFF_BP'].to_f/100.0
        high_band_off_delta    = rate_band['HIGH_BAND_OFF_BP'].to_f/100.0
        low_band_warn_delta    = rate_band['LOW_BAND_WARN_BP'].to_f/100.0
        high_band_warn_delta   = rate_band['HIGH_BAND_WARN_BP'].to_f/100.0
        low_band_off_rate      = live[:start_of_day_rate].to_f - low_band_off_delta
        low_band_warn_rate     = live[:start_of_day_rate].to_f - low_band_warn_delta
        high_band_off_rate     = live[:start_of_day_rate].to_f + high_band_off_delta
        high_band_warn_rate    = live[:start_of_day_rate].to_f + high_band_warn_delta
        {
          low_band_warn_delta: low_band_warn_delta,
          low_band_off_delta: low_band_off_delta,
          high_band_warn_delta: high_band_warn_delta,
          high_band_off_delta: high_band_off_delta,
          low_band_off_rate: low_band_off_rate,
          low_band_warn_rate: low_band_warn_rate,
          high_band_warn_rate: high_band_warn_rate,
          high_band_off_rate: high_band_off_rate,
          min_threshold_exceeded: live_rate < low_band_off_rate,
          max_threshold_exceeded: live_rate > high_band_off_rate
        }.with_indifferent_access
      end

      def self.soap_client(endpoint, namespaces)
        client = Savon.client( COMMON.merge( wsdl: ENV[endpoint], namespaces: namespaces ) )
        client.globals[:open_timeout] = SOAP_OPEN_TIMEOUT
        client.globals[:read_timeout] = SOAP_READ_TIMEOUT
        client
      end

      @@mds_connection = nil
      def self.init_mds_connection(environment, cache=true)
        return nil unless environment == :production
        connection = @@mds_connection
        connection = nil unless cache
        connection ||= MAPI::Services::Rates.soap_client( 'MAPI_MDS_ENDPOINT',
                                                                { 'xmlns:v1' => 'http://fhlbsf.com/schema/msg/marketdata/v1',
                                                                  'xmlns:wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd',
                                                                  'xmlns:v11' => 'http://fhlbsf.com/schema/canonical/common/v1',
                                                                  'xmlns:v12' => 'http://fhlbsf.com/schema/canonical/marketdata/v1',
                                                                  'xmlns:v13' => 'http://fhlbsf.com/schema/canonical/shared/v1'} )
        @@mds_connection ||= connection if cache
        connection
      end

      @@cal_connection = nil
      def self.init_cal_connection(environment, cache=true)
        return nil unless environment == :production
        connection = @@cal_connection
        connection = nil unless cache
        connection ||= MAPI::Services::Rates.soap_client( 'MAPI_CALENDAR_ENDPOINT',
                                                                { 'xmlns:v1' => 'http://fhlbsf.com/schema/msg/businessCalendar/v1',
                                                                  'xmlns:wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd',
                                                                  'xmlns:v11' => 'http://fhlbsf.com/schema/canonical/common/v1'} )
        @@cal_connection ||= connection if cache
        connection
      end

      @@pi_connection = nil
      def self.init_pi_connection(environment, cache=true)
        return nil unless environment == :production
        connection = @@pi_connection
        connection = nil unless cache
        connection ||= MAPI::Services::Rates.soap_client( 'MAPI_MDS_ENDPOINT',
                                                               { 'xmlns:v1' => 'http://fhlbsf.com/reports/msg/v1',
                                                                 'xmlns:wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd',
                                                                 'xmlns:v11' => 'http://fhlbsf.com/reports/contract/v1'} )
        @@pi_connection ||= connection if cache
        connection
      end

      def self.market_data_message_for_loan_type(loan_type, live_or_start_of_day, funding_date=nil, maturity_date=nil)
        data = if maturity_date
          frequency = (maturity_date.to_date - (funding_date || Time.zone.today).to_date).to_i.to_s
          [{
            'v12:FhlbsfDataPoint' => [{
              'v12:tenor' => [{
                'v12:interval' => [{
                  'v13:frequency' => frequency,
                  'v13:frequencyUnit' => 'D'
                }]
              }]
            }]
          }]
        else
          ''
        end
        message = {
            'v1:caller' => [{'v11:id' => ENV['MAPI_FHLBSF_ACCOUNT']}],
            'v1:marketData' => [{
                                    'v12:spotDate'     => funding_date.try(:to_date).try(:iso8601),
                                    'v12:name'         => LOAN_MAPPING[loan_type.to_s],
                                    'v12:pricingGroup' => [{'v12:id' => live_or_start_of_day}],
                                    'v12:data'         => data
                                }]
        }
        message['v1:marketData'].first.delete('v12:spotDate') unless funding_date
        message
      end

      def self.get_market_data_from_soap(logger, live_or_start_of_day, funding_date=nil, maturity_date=nil)
        if !@@mds_connection.nil?
          requests = [{'v1:fhlbsfMarketDataRequest' => LOAN_TYPES.map { |lt| market_data_message_for_loan_type(lt, live_or_start_of_day, funding_date) }}]
          if maturity_date
            requests.first['v1:fhlbsfMarketDataRequest'].push(*LOAN_TYPES.map { |lt| market_data_message_for_loan_type(lt, live_or_start_of_day, funding_date, maturity_date) })
          end

          begin
            @@mds_connection.call(:get_market_data,
                                  message_tag: 'marketDataRequest',
                                  message: {
                                      'v11:caller' => [{'v11:id' => ENV['MAPI_COF_ACCOUNT']}],
                                      'v1:requests' => requests
                                  },
                                  soap_header: SOAP_HEADER)
          rescue Savon::Error => error
            logger.error error
            return nil
          end
        end
      end

      PATHS = {
          type_data:       '//Envelope//Body//marketDataResponse//responses//fhlbsfMarketDataResponse',
          term_data:       'marketData FhlbsfMarketData data FhlbsfDataPoint',
          day_count_basis: 'marketData FhlbsfMarketData dayCountBasis',
          type_long:       'marketData FhlbsfMarketData name',
          spot_date:       'marketData FhlbsfMarketData spotDate',
          frequency:       'tenor interval frequency',
          unit:            'tenor interval frequencyUnit',
          maturity_string: 'tenor maturityDate',
          rate:            'value',
      }.with_indifferent_access

      def self.extract_text(xml, field)
        xml.at_css(PATHS[field]).try(:content)
      end

      PERIOD_TO_TERM= {
          '1D' => :overnight,
          '1W' => :'1week',  '2W' => :'2week',  '3W' => :'3week',
          '1M' => :'1month', '2M' => :'2month', '3M' => :'3month', '6M' => :'6month',
          '1Y' => :'1year',  '2Y' => :'2year',  '3Y' => :'3year'
        }

      def self.extract_market_data_from_soap_response(response)
        hash = {}.with_indifferent_access
        response.doc.remove_namespaces!
        response.doc.xpath(PATHS[:type_data]).each do |type_data|
          day_count_basis = extract_text(type_data, :day_count_basis)
          type_long       = extract_text(type_data, :type_long)
          type            = LOAN_MAPPING_INVERTED[type_long]
          is_custom = !!hash[type]
          type_data.css(PATHS[:term_data]).each do |term_data|
            term_data_result = MAPI::Services::Rates.get_term_data(type_data, term_data, is_custom)
            if term_data_result
              hash[type] ||= {}
              term = term_data_result[:term].to_sym
              rate = term_data_result[:rate]
              NewRelic::Agent.notice_error('Blank rate returned', trace_only: true, custom_params: {term: term.to_s, type: type.to_s, data: term_data}) unless rate.present?
              hash[type][term] = {
                rate: rate,
                maturity_date: Time.zone.parse(term_data_result[:maturity_string]).to_date,
                payment_on: 'Maturity',
                interest_day_count: day_count_basis
              }
            end
          end
          hash[type][:open] = hash[type][:overnight].clone if !is_custom && hash[type] && hash[type][:overnight]
        end
        hash
      end

      def self.days_to_maturity(maturity_date, funding_date=nil)
        today = Time.zone.today
        days_to_maturity = (maturity_date.to_date - (funding_date || today).to_date).to_i
        {
          days: days_to_maturity,
          term: days_to_maturity.to_s + 'day'
        }
      end

      def self.get_term_data(type_data, term_data, is_custom)
        rate            = extract_text(term_data, :rate)
        maturity_string = extract_text(term_data, :maturity_string)
        if is_custom
          funding_date    = extract_text(type_data, :spot_date)
          term            = MAPI::Services::Rates.days_to_maturity(maturity_string, funding_date)[:term]
        else
          frequency       = extract_text(term_data, :frequency)
          unit            = extract_text(term_data, :unit)
          period          = "#{frequency}#{unit}"
          term            = PERIOD_TO_TERM[period]
        end
        if term
          {
            rate: rate,
            maturity_string: maturity_string,
            term: term
          }
        end
      end

      def self.is_limited_pricing_day?(app, date)
        date = date.to_date
        cached_dates = request_cache(app.request, ['is_limited_pricing_day', date.to_s]) do
          dates = []
          if connection = self.init_cal_connection(app.settings.environment)
            message = {'v1:endDate' => date.strftime('%F') , 'v1:startDate' => date.strftime('%F') }
            begin
              response = connection.call(:get_holiday, message_tag: 'holidayRequest', message: message, :soap_header => MAPI::Services::Rates::SOAP_HEADER )
            rescue Savon::Error => error
              raise 'Internal Service Error: the holiday calendar service could not be reached'
            end
            response.doc.remove_namespaces!
            holiday_type = response.doc.xpath('//Envelope//Body//holidayResponse//holidays//businessCenters')
            holiday_type.each do |row|
              if row.css('businessCenter').text == 'FHLBSF Special Pricing Day'
                row.css('days day date').map do |holiday|
                  dates.push(holiday.content)
                end
              end
            end
          else
            dates = fake('limited_pricing_days')
          end
          dates.collect(&:to_date)
        end
        cached_dates.include?(date)
      end

      def self.registered(app)
        service_root '/rates', app
        swagger_api_root :rates do
          api do
            key :path, "/price_indications/current/vrc/{collateral}"
            operation do
              key :method, 'GET'
              key :summary, 'Retrieve current price indications for vrc products'
              key :notes, 'Returns current price indications based on vrc and collateral inputs'
              key :type, :CurrentPriceIndicationsVrc
              key :nickname, :CurrentPriceIndicationsVrc
              parameter do
                key :paramType, :path
                key :name, :collateral
                key :required, true
                key :type, :string
                key :enum, COLLATERAL_TYPES
                key :description, 'The type of collateral used.'
              end
              response_message do
                key :code, 200
                key :message, 'OK'
              end
            end
          end

          api do
            key :path, "/price_indications/current/frc/{collateral}"
            operation do
              key :method, 'GET'
              key :summary, 'Retrieve current price indications for frc products'
              key :notes, 'Returns current price indications based on frc and collateral inputs'
              key :type, :CurrentPriceIndicationsFrc
              key :nickname, :CurrentPriceIndicationsFrc
              parameter do
                key :paramType, :path
                key :name, :collateral
                key :required, true
                key :type, :string
                key :enum, COLLATERAL_TYPES
                key :description, 'The type of collateral used.'
              end
              response_message do
                key :code, 200
                key :message, 'OK'
              end
            end
          end

          api do
            key :path, "/price_indications/current/arc/{collateral}"
            operation do
              key :method, 'GET'
              key :summary, 'Retrieve current price indications for arc products'
              key :notes, 'Returns current price indications based on arc and collateral inputs'
              key :type, :CurrentPriceIndicationsArc
              key :nickname, :CurrentPriceIndicationsArc
              parameter do
                key :paramType, :path
                key :name, :collateral
                key :required, true
                key :type, :string
                key :enum, COLLATERAL_TYPES
                key :description, 'The type of collateral used.'
              end
              response_message do
                key :code, 200
                key :message, 'OK'
              end
            end
          end

          api do
            key :path, "/historic/overnight"
            operation do
              key :method, 'GET'
              key :summary, 'Retrieve historic overnight rates'
              key :notes, 'Returns a list of the opening overnight rates'
              key :type, :HistoricRate
              key :nickname, :historicOvernightVRCRate
              parameter do
                key :paramType, :query
                key :name, :limit
                key :required, false
                key :type, :integer
                key :defaultValue, 30
                key :minimum, 0
                key :maximum, 30
                key :description, 'How many rates to return. Default is 30.'
              end
              response_message do
                key :code, 200
                key :message, 'OK'
              end
            end
          end

          api do
            key :path, "/{loan}/{term}"
            operation do
              key :method, 'GET'
              key :summary, 'Retrieve current rates for a given loan type and term.'
              key :notes, 'Returns the current rate and the time at which it was considered current.'
              key :type, :RealtimeRate
              key :nickname, :currentRates
              parameter do
                key :paramType, :path
                key :name, :loan
                key :required, true
                key :type, :string
                key :enum, LOAN_TYPES
                key :description, 'The type of loan. Describes the collateral behind the loan.'
              end
              parameter do
                key :paramType, :path
                key :name, :term
                key :required, true
                key :type, :string
                key :enum, LOAN_TERMS
                key :description, 'The term of the loan.'
              end
              parameter do
                key :paramType, :path
                key :name, :type
                key :required, false
                key :type, :string
                key :description, 'The type of the loan.'
              end
              parameter do
                key :paramType, :query
                key :name, :funding_date
                key :required, false
                key :type, :string
                key :description, 'Funding Date, if in the future, otherwise nil'
              end
              parameter do
                key :paramType, :query
                key :name, :maturity_date
                key :required, false
                key :type, :string
                key :description, 'Maturity Date, if custom, otherwise nil'
              end
              response_message do
                key :code, 200
                key :message, 'OK'
              end
              response_message do
                key :code, 404
                key :message, 'Term Not Found'
              end
              response_message do
                key :code, 404
                key :message, 'Loan Not Found'
              end
            end
          end

          # This is ambiguous right now as we wait to see what we can get back from Calypso in a single request.
          # We'll probably pull all the rates we can get (assuming no performance hit) and handle the logic of which we
          # want to show in app/services/rates_service.rb
          api do
            key :path, "/summary"
            operation do
              key :method, 'GET'
              key :summary, 'Retrieve current rates for standard loan types and terms.'
              key :notes, 'Returns an object containing rate data for each loan term of a given loan type, as well as a timestamp to indicate when the rates were fetched'
              key :type, :SummaryRates
              key :nickname, :SummaryRates
              parameter do
                key :paramType, :query
                key :name, :funding_date
                key :required, false
                key :type, :string
                key :description, 'Funding Date, if in the future, otherwise nil'
              end
              parameter do
                key :paramType, :query
                key :name, :maturity_date
                key :required, false
                key :type, :string
                key :description, 'Maturity Date, if custom, otherwise nil'
              end
              response_message do
                key :code, 200
                key :message, 'OK'
              end
            end
          end

          api do
            key :path, '/price_indication/historical/{start_date}/{end_date}/sta/sta'
            operation do
              key :method, 'GET'
              key :summary, 'Retrieve historical sta rates.'
              key :notes, 'Returns an object containing rate data'
              key :type, :HistoricalSTA
              key :nickname, :HistoricalSTA
              parameter do
                key :paramType, :path
                key :name, :start_date
                key :required, true
                key :type, :string
                key :description, 'Start date yyyy-mm-dd for the STA historical rates.'
              end
              parameter do
                key :paramType, :path
                key :name, :end_date
                key :required, true
                key :type, :string
                key :description, 'End date yyyy-mm-dd for the STA historical rates.'
              end
              response_message do
                key :code, 200
                key :message, 'OK'
              end
              response_message do
                key :code, 400
                key :message, 'Invalid input'
              end
            end
          end

          # Price Indication Historical rates for VRC, FRC, ARC
          api do
            key :path, '/price_indication/historical/{start_date}/{end_date}/{collateral_type}/{credit_type}'
            operation do
              key :method, 'GET'
              key :summary, 'Retrieve historical price indication rates for the selected date range for the specified collateral/credit type.'
              key :notes, 'Returns an object containing rate data for each collateral, credit type by dates and term'
              key :type, :PriceIndicationHistorical
              key :nickname, :PriceIndicationHistorical
              parameter do
                key :paramType, :path
                key :name, :start_date
                key :required, true
                key :type, :string
                key :description, 'Start date yyyy-mm-dd for the Price Indication historical rates.'
              end
              parameter do
                key :paramType, :path
                key :name, :end_date
                key :required, true
                key :type, :string
                key :description, 'End date yyyy-mm-dd for the Price Indication historical rates.'
              end
              parameter do
                key :paramType, :path
                key :name, :collateral_type
                key :required, true
                key :type, :string
                key :description, 'Collateral Type i.e. standard, sbc  Price Indication historical rates.'
              end
              parameter do
                key :paramType, :path
                key :name, :credit_type
                key :required, true
                key :type, :string
                key :description, 'Credit Type for the specified collateral type e.g. vrc, frc, 1m_libor ect.'
              end
              response_message do
                key :code, 200
                key :message, 'OK'
              end
              response_message do
                key :code, 400
                key :message, 'Invalid input'
              end
            end
          end

          # Fetch rate band info
          api do
            key :path, '/rate_bands'
            operation do
              key :method, 'GET'
              key :summary, 'Retrieve rate band info for all terms.'
              key :nickname, :RateBands
              key :type, :RateBands
            end
          end

          # Update rate band info
          api do
            key :path, '/rate_bands'
            operation do
              key :method, 'PUT'
              key :summary, 'Update rate band info for the terms contained in the JSON body'
              key :nickname, :UpdateRateBands
              parameter do
                key :paramType, :body
                key :name, :body
                key :required, true
                key :type, :RateBands
                key :description, "The hash of terms and their associated rate band values."
              end
            end
          end
        end

        relative_get "/historic/overnight" do
          days = (params[:limit] || 30).to_i
          query = <<-SQL
              SELECT * FROM (SELECT TRX_EFFECTIVE_DATE, TRX_VALUE
              FROM IRDB.IRDB_TRANS T
              WHERE TRX_IR_CODE = 'FRADVN'
              AND (TRX_TERM_VALUE || TRX_TERM_UOM  = '1D' )
              ORDER BY TRX_EFFECTIVE_DATE DESC) WHERE ROWNUM <= #{ActiveRecord::Base.connection.quote(days)}
          SQL

          data = if settings.environment == :production
            rows = MAPI::Services::Rates.fetch_rows(logger, query)
            halt 503, 'Internal Service Error' if rows.nil?
            rows
          else
            rows = MAPI::Services::Rates.fake('rates_historic_overnight')[0..(days - 1)]
            rows.collect do |row|
              [Time.zone.parse(row[0]), row[1]]
            end
          end

          data.reverse!.collect! do |row|
            [row[0].to_date, row[1].to_f]
          end

          data.to_json
        end

        relative_get "/price_indications/current/vrc/:collateral" do
          if !COLLATERAL_MAPPING[params[:collateral]]
            halt 404, 'Collateral Not Found'
          end

          data = if MAPI::Services::Rates.init_pi_connection(settings.environment)
            @@pi_connection.operations
            message = {
              'v1:productType' => CURRENT_CREDIT_MAPPING['vrc'],
              'v1:subProductType' => COLLATERAL_MAPPING[params[:collateral]]
            }
            begin
              response = @@pi_connection.call(:get_pricing_indications,
                                              message_tag: 'pricingIndicationsRequest',
                                              message: message,
                                              soap_header: SOAP_HEADER )
            rescue Savon::Error => error
              logger.error error
              halt 503, 'Internal Service Error'
            end
            response.doc.remove_namespaces!
            fhlbsfresponseblock = response.doc.xpath('//Envelope//Body//pricingIndicationsResponse//response//Items//FhlbsfReportDataBlock')
            fhlbsfresponse = response.doc.xpath('//Envelope//Body//pricingIndicationsResponse//response//Items//FhlbsfReportDataBlock//Data//FhlbsfReportData')
            fhlbsfdatapoints = fhlbsfresponse[3].css('Table Rows TableRow Cells TableCell')
            effective_date = fhlbsfresponseblock.at_css('EffectiveDate').content.to_date
            hash = {
              'advance_maturity' => fhlbsfdatapoints[0].at_css('Text').content,
              'advance_rate' => fhlbsfdatapoints[3].at_css('Text').content,
              'effective_date' => effective_date
            }
            hash
          else
            hash = MAPI::Services::Rates.fake('rates_current_price_indications_vrc')
            hash['effective_date'] = Time.zone.today
            hash
          end
          hash = {
            'advance_maturity' => data['advance_maturity'].to_s,
            'advance_rate' => data['advance_rate'].to_f,
            'effective_date' => data['effective_date'].to_date
          }
          hash.to_json
        end

        relative_get "/price_indications/current/frc/:collateral" do
          if !COLLATERAL_MAPPING[params[:collateral]]
            halt 404, 'Collateral Not Found'
          end

          data = if MAPI::Services::Rates.init_pi_connection(settings.environment)
            @@pi_connection.operations
            message = {
              'v1:productType' => CURRENT_CREDIT_MAPPING['frc'],
              'v1:subProductType' => COLLATERAL_MAPPING[params[:collateral]]
            }
            begin
              response = @@pi_connection.call(:get_pricing_indications,
                                              message_tag: 'pricingIndicationsRequest',
                                              message: message,
                                              soap_header: SOAP_HEADER )
            rescue Savon::Error => error
              logger.error error
              halt 503, 'Internal Service Error'
            end
            response.doc.remove_namespaces!
            fhlbsfresponse = response.doc.xpath('//Envelope//Body//pricingIndicationsResponse//response//Items//FhlbsfReportDataBlock//Data//FhlbsfReportData')
            fhlbsfdatapoints = fhlbsfresponse[3].css('Table Rows TableRow Cells')
            fhlbsfresponseblock = response.doc.xpath('//Envelope//Body//pricingIndicationsResponse//response//Items//FhlbsfReportDataBlock')
            effective_date = fhlbsfresponseblock.at_css('EffectiveDate').content.to_date
            hash = fhlbsfdatapoints.collect do |fhlbsfdatapoint|
              result = fhlbsfdatapoint.css('TableCell')
              {
                'advance_maturity' => result[0].at_css('Text').content,
                'advance_rate' => result[4].at_css('Text').content,
                'effective_date' => effective_date
              }
            end
            hash
          else
            rates_file_name = params[:collateral].to_sym == :standard ? 'rates_current_price_indications_standard_frc' : 'rates_current_price_indications_sbc_frc'
            MAPI::Services::Rates.fake(rates_file_name).collect do |rate|
              rate['effective_date'] = Time.zone.today
              rate
            end
          end
          data_formatted = []
          data.each do |row|
            hash = {
              'advance_maturity' => row['advance_maturity'].to_s,
              'advance_rate' => row['advance_rate'].to_f,
              'effective_date' => row['effective_date'].to_date
            }
            limited_pricing = MAPI::Services::Rates.is_limited_pricing_day?(self, hash['effective_date'])
            data_formatted.push(hash) unless limited_pricing
          end
          data_formatted.to_json
        end

        relative_get "/price_indications/current/arc/:collateral" do
          if !COLLATERAL_MAPPING[params[:collateral]]
            halt 404, 'Collateral Not Found'
          end

          data = if MAPI::Services::Rates.init_pi_connection(settings.environment)
            @@pi_connection.operations
            message = {
              'v1:productType' => CURRENT_CREDIT_MAPPING['arc'],
              'v1:subProductType' => COLLATERAL_MAPPING[params[:collateral]]
            }
            begin
              response = @@pi_connection.call(:get_pricing_indications,
                                              message_tag: 'pricingIndicationsRequest',
                                              message: message,
                                              soap_header: SOAP_HEADER )
            rescue Savon::Error => error
              logger.error error
              halt 503, 'Internal Service Error'
            end
            response.doc.remove_namespaces!
            fhlbsfresponse = response.doc.xpath('//Envelope//Body//pricingIndicationsResponse//response//Items//FhlbsfReportDataBlock//Data//FhlbsfReportData')
            fhlbsfdatapoints = fhlbsfresponse[3].css('Table Rows TableRow Cells')
            fhlbsfresponseblock = response.doc.xpath('//Envelope//Body//pricingIndicationsResponse//response//Items//FhlbsfReportDataBlock')
            effective_date = fhlbsfresponseblock.at_css('EffectiveDate').content.to_date
            hash = fhlbsfdatapoints.collect do |fhlbsfdatapoint|
              result = fhlbsfdatapoint.css('TableCell')
              {
                'advance_maturity' =>   result[0].at_css('Text').content,
                '1_month_libor' =>  result[1].at_css('Text').content,
                '3_month_libor' =>  result[2].at_css('Text').content,
                '6_month_libor' =>  result[3].at_css('Text').content,
                'prime' =>  params[:collateral] == 'standard' ? result[4].at_css('Text').content : 0,
                'effective_date' => effective_date
              }
            end
            hash
          else
            MAPI::Services::Rates.fake('rates_current_price_indications_arc').collect do |rate|
              rate['effective_date'] = Time.zone.today
              rate
            end
          end
          data_formatted = []
          data.each do |row|
            hash = {
                'advance_maturity' => row['advance_maturity'].to_s,
                '1_month_libor' => row['1_month_libor'].to_i,
                '3_month_libor' => row['3_month_libor'].to_i,
                '6_month_libor' => row['6_month_libor'].to_i,
                'prime' => row['prime'].to_i,
                'effective_date' => row['effective_date'].to_date
            }
            limited_pricing = MAPI::Services::Rates.is_limited_pricing_day?(self, hash['effective_date'])
            data_formatted.push(hash) unless limited_pricing
          end
          data_formatted.to_json
        end

        relative_get '/:loan/:term/?:type?' do
          halt 404, 'Loan Not Found' unless LOAN_MAPPING[params[:loan]]
          halt 404, 'Term Not Found' unless (TERM_MAPPING[params[:term]] || params[:term]=~CUSTOM_TERM)
          type = params[:type] ? params[:type] : 'Live'
          funding_date = params[:funding_date].try(:to_date)
          data = if MAPI::Services::Rates.init_mds_connection(settings.environment)
            @@mds_connection.operations
            if matched_term = params[:term].match(CUSTOM_TERM)
              lookup_term = {
                frequency: (matched_term[1]).to_i.to_s,
                frequency_unit: 'D'
              }
            else
              lookup_term = TERM_MAPPING[params[:term]]
            end
            message = {
              'v11:caller' => [{ 'v11:id' => ENV['MAPI_COF_ACCOUNT']}],
              'v1:requests' => [{
                'v1:fhlbsfMarketDataRequest' => [{
                  'v1:caller' => [{'v11:id' => ENV['MAPI_FHLBSF_ACCOUNT']}],
                  'v1:marketData' =>  [{
                    'v12:spotDate'     => funding_date.try(:to_date).try(:iso8601),
                    'v12:customRollingDay' => '0',
                    'v12:name' => LOAN_MAPPING[params[:loan]],
                    'v12:pricingGroup' => [{'v12:id' => type}],
                    'v12:data' => [{
                      'v12:FhlbsfDataPoint' => [{
                        'v12:tenor' => [{
                          'v12:interval' => [{
                            'v13:frequency' => lookup_term[:frequency],
                            'v13:frequencyUnit' => lookup_term[:frequency_unit]
                          }]
                        }]
                      }]
                    }]
                  }]
                }]
              }]
            }
            message['v1:requests'].first['v1:fhlbsfMarketDataRequest'].first['v1:marketData'].first.delete('v12:spotDate') unless funding_date
            response = @@mds_connection.call(:get_market_data, message_tag: 'marketDataRequest', message: message, soap_header: SOAP_HEADER )
            namespaces = {'a' => 'http://fhlbsf.com/schema/canonical/marketdata/v1', 'xmlns' => 'http://fhlbsf.com/schema/msg/marketdata/v1'}
            if response.success? && response.doc.search('//xmlns:transactionResult', namespaces).text != 'Error'
              {rate: response.doc.search('//a:value', namespaces).text.to_f, updated_at: DateTime.parse(response.doc.search('//a:snapTime', namespaces).text).to_time}
            else
              halt 503, 'Service Unavailable'
            end
          else
            # We have no real data source yet.
            rows = MAPI::Services::Rates.fake('rates_current_overnight')
            rate = rows.sample
            now = Time.now
            {rate: rate, updated_at: Time.mktime(now.year, now.month, now.day, now.hour, now.min).to_s}
          end
          data.to_json
        end

        relative_get "/summary" do
          funding_date = params[:funding_date].try(:to_date)
          maturity_date = params[:maturity_date].try(:to_date)
          halt 503, 'Internal Service Error' unless holidays       = MAPI::Services::Rates::Holidays.holidays(self)
          halt 503, 'Internal Service Error' unless blackout_dates = MAPI::Services::Rates::BlackoutDates.blackout_dates(logger,settings.environment)
          halt 503, 'Internal Service Error' unless loan_terms     = MAPI::Services::Rates::LoanTerms.loan_terms(logger,settings.environment)
          halt 503, 'Internal Service Error' unless rate_bands     = MAPI::Services::Rates::RateBands.rate_bands(logger,settings.environment)
          if maturity_date
            days_to_maturity = MAPI::Services::Rates.days_to_maturity(maturity_date, funding_date)
            custom_term = days_to_maturity[:term].to_sym
          end
          if MAPI::Services::Rates.init_mds_connection(settings.environment)
            halt 503, 'Internal Service Error' unless live_data_xml    = MAPI::Services::Rates.get_market_data_from_soap(logger, 'Live', funding_date, maturity_date)
            halt 503, 'Internal Service Error' unless start_of_day_xml = MAPI::Services::Rates.get_market_data_from_soap(logger, 'StartOfDay', funding_date, maturity_date)
            live_data    = MAPI::Services::Rates.extract_market_data_from_soap_response(live_data_xml)
            start_of_day = MAPI::Services::Rates.extract_market_data_from_soap_response(start_of_day_xml)
          else
            # We have no real data source yet.
            live_data    = MAPI::Services::Rates.fake_hash('market_data_live_rates')
            start_of_day = MAPI::Services::Rates.fake_hash('market_data_start_of_day_rates')
            holidays.each{ |holiday| holidays.delete(holiday) if MAPI::Services::Rates::BlackoutDates.fake_data_relative_to_today.include?(holiday.to_date) } # Delete holidays that overlap with our self-imposed relative blackout dates of 1 and 3 weeks from today
            LOAN_TYPES.each do |type|
              if maturity_date
                live_data[type][custom_term] = {}
                live_data[type][custom_term][:payment_on] = 'Maturity'
                live_data[type][custom_term][:interest_day_count] = 'ACT/ACT'
                live_data[type][custom_term][:days_to_maturity] = days_to_maturity[:days]
                live_data[type][custom_term][:rate] = rand(0.1..1)
                live_data[type][custom_term][:maturity_date] =  maturity_date
              end
              LOAN_TERMS.each do |term|
                live_data[type][term][:maturity_date] = Time.zone.today + TERM_MAPPING[term][:time]
              end
            end
            if params[:member_id].to_i == 3
              blackout_dates = []
              holidays = []
              end_of_day = Time.zone.now.end_of_day
              LOAN_TYPES.each do |type|
                LOAN_TERMS.each do |term|
                  term_details = loan_terms[term][type]
                  term_details[:trade_status] = true
                  term_details[:display_status] = true
                  term_details[:end_time] = end_of_day
                  term_details[:end_time_reached] = false
                  rate_bands[term]['LOW_BAND_OFF_BP'] = 1000
                  rate_bands[term]['HIGH_BAND_OFF_BP'] = 1000
                end
              end
            end
          end
          LOAN_TYPES.each do |type|
            LOAN_TERMS.each do |term|
              term_details             = loan_terms[term][type]
              live                     = live_data[type][term]
              live[:start_of_day_rate] = start_of_day[type][term][:rate].to_f
              live[:rate_band_info]    = MAPI::Services::Rates.rate_band_info(live, rate_bands[term])
              live[:maturity_date]     = MAPI::Services::Rates.get_maturity_date(live[:maturity_date], TERM_MAPPING[term][:frequency_unit], holidays)
              live[:disabled]          = MAPI::Services::Rates.disabled?(live, term_details, blackout_dates)
              live[:end_of_day]        = !term_details[:trade_status]
              if !live[:end_of_day] && term_details[:display_status] && (live[:rate_band_info][:min_threshold_exceeded] || live[:rate_band_info][:max_threshold_exceeded])
                logger.error("Rate band threshold exceeded: type=#{type}, term=#{term}, details=#{live.to_json}")
                NewRelic::Agent.notice_error('Rate band threshold exceeded', trace_only: true, custom_params: {term: term, type: type, details: live})
                Mailers::InternalMailer.send_rate_band_alert(type, term, live[:rate].to_f, live[:start_of_day_rate], live[:rate_band_info], request_id, request_user_id)
              end
            end
            if maturity_date
              live                     = live_data[type][custom_term]
              live[:start_of_day_rate] = live_data[type][custom_term][:rate].to_f
              live[:maturity_date]     = maturity_date
            end
          end
          live_data.merge( timestamp: Time.zone.now ).to_json
        end

        relative_get "/price_indication/historical/:start_date/:end_date/sta/sta" do
          MAPI::Services::Rates.init_cal_connection(settings.environment)
          start_date      = params[:start_date].to_date
          end_date        = params[:end_date].to_date
          halt 400, 'Invalid date range: start_date must occur earlier than end_date or on the same day' unless start_date <= end_date
          MAPI::Services::Rates::HistoricalSTA.historical_sta(self, start_date, end_date).to_json
        end
                               
        # Price Indication Historical rates for VRC, FRC, ARC
        relative_get "/price_indication/historical/:start_date/:end_date/:collateral_type/:credit_type" do
          MAPI::Services::Rates.init_cal_connection(settings.environment)
          start_date      = params[:start_date].to_date
          end_date        = params[:end_date].to_date
          collateral_type = params[:collateral_type].to_sym
          credit_type     = params[:credit_type].to_sym
          irdb_code       = MAPI::Services::Rates::PriceIndicationHistorical::IRDB_CODE_TERM_MAPPING[collateral_type]
          halt 400, 'Invalid date range: start_date must occur earlier than end_date or on the same day' unless start_date <= end_date
          halt 400, "Invalid Collateral type"                                         unless irdb_code
          halt 400, "Invalid Credit type"                                             unless irdb_code[credit_type]
          MAPI::Services::Rates::PriceIndicationHistorical.price_indication_historical(self, start_date, end_date, collateral_type, credit_type).to_json
        end

        relative_get '/rate_bands' do
          MAPI::Services::Rates.rescued_json_response(self) do
            MAPI::Services::Rates::RateBands.rate_bands(logger, settings.environment)
          end
        end

        relative_put '/rate_bands' do
          MAPI::Services::Rates.rescued_json_response(self) do
            rate_bands = JSON.parse(request.body.read)
            {} if MAPI::Services::Rates::RateBands.update_rate_bands(self, rate_bands)
          end
        end

      end
    end
  end
end
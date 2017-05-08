require 'savon'

module MAPI
  module Services
    module Rates
      module Holidays
        include MAPI::Services::Base
        include MAPI::Shared::Constants
        include MAPI::Shared::Utils

        def self.get_holidays_from_soap(logger, connection, start, finish)
          begin
            connection.call(:get_holiday,
                                  message_tag: 'holidayRequest',
                                  message: {'v1:endDate' => finish, 'v1:startDate' => start},
                                  soap_header: SOAP_HEADER)
          rescue Savon::Error => error
            logger.error error
            nil
          end
        end

        def self.holidays(app, start=Time.zone.today, finish=Time.zone.today + 3.years)
          if should_fake?(app)
            MAPI::Services::Rates.fake('calendar_holidays').map { |holiday| Date.parse(holiday) }
          else
            connection = MAPI::Services::Rates.init_cal_connection(app.settings.environment)
            if response = get_holidays_from_soap(app.logger, connection, start, finish)
              response.doc.remove_namespaces!
              business_centers = response.doc.xpath('//Envelope//Body//holidayResponse//holidays//businessCenters')
              return [] if business_centers.blank?
              business_centers.each do |business_center|
                if business_center.css('businessCenter').text == 'USNY'
                  return business_center.css('days day date').map { |holiday| Date.parse(holiday.content) }
                end
              end
            end
            []
          end
        end
      end
    end
  end
end
class MemberProcessQuickReportsJob < FhlbJob
  queue_as :low_priority
  include DatePickerHelper

  def perform(member_id, period)
    raise '`member_id` must not be nil' unless member_id
    raise '`period` must not be nil' unless period
    member = Member.new(member_id)
    report_set = member.report_set_for_period(period)
    period_date = (period + '-01').to_date
    date_hash = default_dates_hash(period_date)
    missing_reports = report_set.missing_reports(member.quick_report_list)
    if missing_reports.present?      
      member_balance_service = MemberBalanceService.new(member_id, nil)
      unless member_balance_service.borrowing_capacity_data_available?(period_date)
        raise 'halting quick reports because borrowing capacity data is not available for the given period' 
      end
      missing_reports.each do |report_name|
        params = {}
        member.quick_report_params(report_name).each do |key, value|
          params[key] = date_hash[value] || value
        end
        report = RenderReportPDFJob.perform_now(member_id, report_name, nil, params)
        report_set.quick_reports.reports_named(report_name).first_or_create!(report: report)
      end
    end
  end
end
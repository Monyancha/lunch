class DashboardController < ApplicationController
  include CustomFormattingHelper
  include DashboardHelper
  include AssetHelper
  include ReportsHelper
  include ContactInformationHelper

  prepend_around_action :skip_timeout_reset, only: [:current_overnight_vrc]

  # {action_name: [job_klass, path_helper_as_string]}
  DEFERRED_JOBS = {
    recent_activity: {
      job: MemberBalanceRecentCreditActivityJob,
      load_helper: :dashboard_recent_activity_url
    },
    account_overview: {
      job: MemberBalanceProfileJob,
      load_helper: :dashboard_account_overview_url,
      cache_key: ->(controller) { CacheConfiguration.key(:account_overview, controller.session.id, controller.current_member_id) },
      cache_data_handler: :populate_account_overview_view_parameters
    }
  }.freeze

  QUICK_REPORT_MAPPING = {
    account_summary: I18n.t('reports.account.account_summary.title'),
    advances_detail: I18n.t('reports.credit.advances_detail.title'),
    borrowing_capacity: I18n.t('reports.collateral.borrowing_capacity.title'),
    settlement_transaction_account: I18n.t('reports.account.settlement_transaction_account.title'),
    securities_transactions: I18n.t('reports.securities.transactions.title')
  }.with_indifferent_access.freeze

  ACTIVITY_DEFAULT_TRANSACTION_NUMBER = ->(entry, key, controller) { entry[:transaction_number] }
  ACTIVITY_CURRENT_PAR_AMOUNT = ->(entry, key, controller) { entry[:current_par] }

  ACTIVITY_PATTERNS = [
    # LC Amended Today
    {
      returns: {
        description: -> (entry, key, controller) { I18n.t('dashboard.recent_activity.letter_of_credit') },
        amount: ACTIVITY_CURRENT_PAR_AMOUNT,
        transaction_number: ACTIVITY_DEFAULT_TRANSACTION_NUMBER,
        event: -> (entry, key, controller) { I18n.t('dashboard.recent_activity.amended_today') }
      },
      pattern: {
        product: 'LC',
        status: 'VERIFIED',
        trade_date: -> (entry, key, controller) { entry[:trade_date].to_date < Time.zone.today }
      }
    },
    # LC Executed Today
    {
      returns: {
        description: -> (entry, key, controller) { I18n.t('dashboard.recent_activity.letter_of_credit') },
        amount: ACTIVITY_CURRENT_PAR_AMOUNT,
        transaction_number: ACTIVITY_DEFAULT_TRANSACTION_NUMBER,
        event: ->(entry, key, controller) { I18n.t('dashboard.recent_activity.expires_on', date: controller.fhlb_date_standard_numeric(entry[:maturity_date])) }
      },
      pattern: {
        product: 'LC',
        status: 'VERIFIED',
        trade_date: -> (entry, key, controller) { entry[:trade_date].to_date == Time.zone.today }
      }
    },
    # LC Expired Today
    {
      returns: {
        description: -> (entry, key, controller) { I18n.t('dashboard.recent_activity.letter_of_credit') },
        amount: ACTIVITY_CURRENT_PAR_AMOUNT,
        transaction_number: ACTIVITY_DEFAULT_TRANSACTION_NUMBER,
        event: -> (entry, key, controller) { I18n.t('dashboard.recent_activity.expires_today') }
      },
      pattern: {
        product: 'LC',
        status: 'MATURED'
      }
    },
    # LC Terminated Today
    {
      returns: {
        description: -> (entry, key, controller) { I18n.t('dashboard.recent_activity.letter_of_credit') },
        amount: ACTIVITY_CURRENT_PAR_AMOUNT,
        transaction_number: ACTIVITY_DEFAULT_TRANSACTION_NUMBER,
        event: ->(entry, key, controller) { I18n.t('dashboard.recent_activity.terminated_today') },
      },
      pattern: {
        product: 'LC',
        status: 'TERMINATED'
      }
    },
    # Advance Amortized Today
    {
      returns: {
        description: ->(entry, key, controller) { entry[:product_description] },
        amount: ->(entry, key, controller) { entry[:termination_par] },
        transaction_number: ACTIVITY_DEFAULT_TRANSACTION_NUMBER,
        event: ->(entry, key, controller) { entry[:termination_full_partial] }
      },
      pattern: {
        instrument_type: 'ADVANCE',
        status: 'TERMINATED',
        product: 'AMORTIZING'
      }
    },
    # Advance Terminated Today
    {
      returns: {
        description: ->(entry, key, controller) { entry[:product_description] },
        amount: ACTIVITY_CURRENT_PAR_AMOUNT,
        transaction_number: ACTIVITY_DEFAULT_TRANSACTION_NUMBER,
        event: ->(entry, key, controller) { entry[:termination_full_partial] }
      },
      pattern: {
        instrument_type: 'ADVANCE',
        status: 'TERMINATED'
      }
    },
    # Advance/Investment Matured Today
    {
      returns: {
        description: ->(entry, key, controller) { entry[:product_description] },
        amount: ACTIVITY_CURRENT_PAR_AMOUNT,
        transaction_number: ACTIVITY_DEFAULT_TRANSACTION_NUMBER,
        event: ->(entry, key, controller) { I18n.t('dashboard.recent_activity.matures_today') },
      },
      pattern: {
        instrument_type: /\A(ADVANCE|INVESTMENT)\z/,
        status: 'MATURED'
      }
    },
    # Advance Partial Prepayments/Repayments
    {
      returns: {
        description: ->(entry, key, controller) {entry[:product_description]},
        amount: ->(entry, key, controller) { entry[:termination_par] },
        transaction_number: ACTIVITY_DEFAULT_TRANSACTION_NUMBER,
        event: ->(entry, key, controller) {entry[:termination_full_partial]}
      },
      pattern: {
        instrument_type: 'ADVANCE',
        termination_full_partial: /\A(PARTIAL PREPAYMENT|PARTIAL REPAYMENT)\z/,
        status: 'VERIFIED',
      }
    },
    # Advance/Investment Executed Today
    {
      returns: {
        description: ->(entry, key, controller) {entry[:product_description]},
        amount: ACTIVITY_CURRENT_PAR_AMOUNT,
        transaction_number: ACTIVITY_DEFAULT_TRANSACTION_NUMBER,
        event: ->(entry, key, controller) {I18n.t('dashboard.recent_activity.matures_on', date: controller.fhlb_date_standard_numeric(entry[:maturity_date]))}
      },
      pattern: {
        instrument_type: /\A(ADVANCE|INVESTMENT)\z/,
        status: 'VERIFIED',
        product: ->(entry, key, controller) {entry[:product] != 'OPEN VRC'},
        termination_full_partial: nil
      }
    },
    # Open Advances
    {
      returns: {
        description: ->(entry, key, controller) {entry[:product_description]},
        amount: ACTIVITY_CURRENT_PAR_AMOUNT,
        transaction_number: ACTIVITY_DEFAULT_TRANSACTION_NUMBER,
        event: I18n.t('dashboard.open')
      },
      pattern: {
        instrument_type: 'ADVANCE',
        status: /\A(VERIFIED|PEND_TERM)\z/,
        product: 'OPEN VRC',
      }
    },
    # Forward funded advances
    {
      returns: {
        description: ->(entry, key, controller) {entry[:product_description]},
        amount: ACTIVITY_CURRENT_PAR_AMOUNT,
        transaction_number: ACTIVITY_DEFAULT_TRANSACTION_NUMBER,
        event: ->(entry, key, controller) {I18n.t('dashboard.recent_activity.will_be_funded_on', date: controller.fhlb_date_standard_numeric(entry[:funding_date]))}
      },
      pattern: {
        instrument_type: 'ADVANCE',
        status: 'COLLATERAL_AUTH',
      }
    },
    # 'OPS_REVIEW', 'SEC_REVIEWED'
    {
      returns: {
        description: ->(entry, key, controller) {entry[:product_description]},
        amount: ACTIVITY_CURRENT_PAR_AMOUNT,
        transaction_number: ACTIVITY_DEFAULT_TRANSACTION_NUMBER,
        event: I18n.t('dashboard.recent_activity.in_review')
      },
      pattern: {
        status: /\A(OPS_REVIEW|SEC_REVIEWED)\z/
      }
    },
  ].freeze

  CURRENT_ACTIVITY_COUNT = 5

  def index
    rate_service = RatesService.new(request)
    etransact_service = EtransactAdvancesService.new(request)
    member_balances = MemberBalanceService.new(current_member_id, request)
    members_service = MembersService.new(request)
    populate_deferred_jobs_view_parameters(DEFERRED_JOBS)
    profile = sanitized_profile(member_balance_service: member_balances)
    RatesServiceJob.perform_later('quick_advance_rates', request.uuid, current_user.id, current_member_id) if policy(:advance).show?

    market_overview_data = Rails.cache.fetch(CacheConfiguration.key(:market_overview),
                                             expires_in: CacheConfiguration.expiry(:market_overview)) { rate_service.overnight_vrc }
    @market_overview = [{ name: 'Test',
                          data: members_service.report_disabled?(current_member_id, [MembersService::IRDB_RATES_DATA]) ? nil : market_overview_data }]

    @account_summary_disabled = members_service.report_disabled?(current_member_id, [MembersService::ACCT_SUMMARY_AND_BORROWING_CAP_SIDEBARS])
    @financing_availability_gauge = if profile[:total_financing_available]
      calculate_gauge_percentages(
        {
          total: profile[:total_financing_available],
          used: profile[:used_financing_availability],
          unused: profile[:collateral_borrowing_capacity][:remaining],
          uncollateralized: profile[:uncollateralized_financing_availability]
        }, :total)
    else
      calculate_gauge_percentages({total: 0})
    end

    @current_overnight_vrc = Rails.cache.fetch(CacheConfiguration.key(:overnight_vrc)).try(:[], :rate)

    @limited_pricing_message = MessageService.new.todays_quick_advance_message
    @etransact_status = etransact_service.etransact_status(current_member_id)
    @contacts = member_contacts
    default_image_path = 'placeholder-usericon.svg'
    if @contacts[:rm] && @contacts[:rm][:username]
      rm_image_path = "#{@contacts[:rm][:username].downcase}.jpg"
      @contacts[:rm][:image_url] = find_asset(rm_image_path) ? rm_image_path : default_image_path
    end
    if @contacts[:cam] && @contacts[:cam][:username]
      cam_image_path = "#{@contacts[:cam][:username].downcase}.jpg"
      @contacts[:cam][:image_url] = find_asset(cam_image_path) ? cam_image_path : default_image_path
    end
    if feature_enabled?('quick-reports')
      current_report_set = QuickReportSet.for_member(current_member_id).latest_with_reports
      @quick_reports = {}.with_indifferent_access
      if current_report_set.present?
        @quick_reports_period = (current_report_set.period + '-01').to_date # convert period to date
        current_report_set.member.quick_report_list.each do |report_name|
          @quick_reports[report_name] = {
            title: QUICK_REPORT_MAPPING[report_name]
          }
        end
        current_report_set.reports_named(@quick_reports.keys).completed.each do |quick_report|
          @quick_reports[quick_report.report_name][:url] = reports_quick_download_path(quick_report)
        end
      end
    end
  end

  def current_overnight_vrc
    cache_context = :overnight_vrc
    key = CacheConfiguration.key(cache_context)
    expiry = CacheConfiguration.expiry(cache_context)
    response = Rails.cache.fetch(key, expires_in: expiry) do
      etransact_service = EtransactAdvancesService.new(request)
      details = RatesService.new(request).current_overnight_vrc || {}
      details[:etransact_active] = etransact_service.etransact_active?
      details[:rate] = fhlb_formatted_number(details[:rate], precision: 2, html: false) if details[:rate]
      details
    end
    render json: response
  end

  def recent_activity
    activities = deferred_job_data || []
    activities = activities.collect! {|o| o.with_indifferent_access}
    recent_activity_data = process_activity_entries(activities)
    render partial: 'dashboard/dashboard_recent_activity', locals: {table_data: recent_activity_data}, layout: false
  end

  def account_overview
    cache_context = :account_overview
    cached_data = Rails.cache.fetch(CacheConfiguration.key(cache_context, session.id, current_member_id), expires_in: CacheConfiguration.expiry(cache_context)) do
      today = Time.zone.now.to_date
      member_balances = MemberBalanceService.new(current_member_id, request)
      members_service = MembersService.new(request)

      # Borrowing Capacity Gauge
      borrowing_capacity = member_balances.borrowing_capacity_summary(today)
      borrowing_capacity_gauge = calculate_borrowing_capacity_gauge(borrowing_capacity) unless members_service.report_disabled?(current_member_id, [MembersService::COLLATERAL_REPORT_DATA])

      profile = deferred_job_data || {}
      profile = sanitize_profile_if_endpoints_disabled(profile.with_indifferent_access)

      # Account Overview Sub-Tables - format: [title, value, footnote(optional), precision(optional)]
      # STA Balance Sub-Table
      sta_balance = [
        [[t('dashboard.your_account.table.balance'), reports_settlement_transaction_account_path], profile[:sta_balance], t('dashboard.your_account.table.balance_footnote')],
      ]

      # Credit Outstanding Sub-Table
      credit_outstanding = [
        [t('dashboard.your_account.table.credit_outstanding'), (profile[:credit_outstanding] || {})[:total]]
      ]

      # Remaining Borrowing Capacity Sub-Table
      total_standard_bc = borrowing_capacity[:net_plus_securities_capacity].to_i
      total_agency_bc = borrowing_capacity[:sbc][:collateral][:agency][:total_borrowing_capacity].to_i
      total_aaa_bc = borrowing_capacity[:sbc][:collateral][:aaa][:total_borrowing_capacity].to_i
      total_aa_bc = borrowing_capacity[:sbc][:collateral][:aa][:total_borrowing_capacity].to_i
      remaining_standard_bc = borrowing_capacity[:standard_excess_capacity].to_i
      remaining_agency_bc = borrowing_capacity[:sbc][:collateral][:agency][:remaining_borrowing_capacity].to_i
      remaining_aaa_bc = borrowing_capacity[:sbc][:collateral][:aaa][:remaining_borrowing_capacity].to_i
      remaining_aa_bc = borrowing_capacity[:sbc][:collateral][:aa][:remaining_borrowing_capacity].to_i

      remaining_borrowing_capacity = unless borrowing_capacity[:total_borrowing_capacity].to_i == 0
        bc_array = [{title: t('dashboard.your_account.table.remaining_borrowing_capacity')}]
        bc_array << [t('dashboard.your_account.table.remaining.standard'), remaining_standard_bc] unless total_standard_bc == 0
        bc_array << [t('dashboard.your_account.table.remaining.agency'), remaining_agency_bc] unless total_agency_bc == 0
        bc_array << [t('dashboard.your_account.table.remaining.aaa'), remaining_aaa_bc] unless total_aaa_bc == 0
        bc_array << [t('dashboard.your_account.table.remaining.aa'), remaining_aa_bc] unless total_aa_bc == 0
        bc_array
      end

      # Remaining Financing Availability and Stock Leverage Sub-Table
      other_remaining = [ {title: t('dashboard.your_account.table.remaining.title')} ]
      unless members_service.report_disabled?(current_member_id, [MembersService::FINANCING_AVAILABLE_DATA])
        other_remaining << [t('dashboard.your_account.table.remaining.available'), profile[:remaining_financing_available]]
      end
      other_remaining << [[t('dashboard.your_account.table.remaining.leverage'), reports_capital_stock_and_leverage_path], (profile[:capital_stock] || {})[:remaining_leverage]]

      account_overview_table_data = {credit_outstanding: credit_outstanding, sta_balance: sta_balance, remaining_borrowing_capacity: remaining_borrowing_capacity, other_remaining: other_remaining}
      {
        table_data: account_overview_table_data,
        gauge_data: borrowing_capacity_gauge
      }
    end

    populate_account_overview_view_parameters(cached_data)

    render layout: false
  end

  private

  def populate_account_overview_view_parameters(data)
    @account_overview_table_data = data[:table_data]
    @borrowing_capacity_gauge = data[:gauge_data]
  end

  def calculate_gauge_percentages(gauge_hash, excluded_keys=[])
    total = 0
    excluded_keys = Array.wrap(excluded_keys)
    largest_display_percentage_key = nil
    largest_display_percentage = 0
    total_display_percentage = 0
    new_gauge_hash = gauge_hash.deep_dup
    new_gauge_hash.each do |key, value|
      if value.nil? || value < 0
        value = 0
        new_gauge_hash[key] = value
      end
      total += value unless excluded_keys.include?(key)
    end

    new_gauge_hash.each do |key, value|
      percentage = total > 0 ? (value.to_f / total) * 100 : 0

      display_percentage = percentage.ceil
      display_percentage += display_percentage % 2

      new_gauge_hash[key] = {
        amount: value,
        percentage: percentage,
        display_percentage: display_percentage
      }
      unless excluded_keys.include?(key)
        if display_percentage >= largest_display_percentage
          largest_display_percentage = display_percentage
          largest_display_percentage_key = key
        end
        total_display_percentage += display_percentage
      end
    end
    new_gauge_hash[largest_display_percentage_key][:display_percentage] = (100 - (total_display_percentage - largest_display_percentage))
    new_gauge_hash
  end

  def deferred_job_data
    raise "Invalid request: must be XMLHttpRequest (xhr) in order to be valid" unless request.xhr?
    param_name = "#{action_name}_job_id".to_sym
    raise ArgumentError, "No job id given for #{action_name}" unless params[param_name]
    job_status = JobStatus.find_by(id: params[param_name], user_id: current_user.id, status: JobStatus.statuses[:completed] )
    raise ActiveRecord::RecordNotFound unless job_status
    deferred_job_data = JSON.parse(job_status.result_as_string).clone
    job_status.destroy
    deferred_job_data
  end

  def populate_deferred_jobs_view_parameters(jobs_hash)
    jobs_hash.each do |name, args|
      cached_data = nil
      if cache_key = args[:cache_key]
        cache_key = cache_key.call(self) if cache_key.respond_to?(:call)
        cached_data = Rails.cache.fetch(cache_key)
      end
      unless cached_data
        job_klass = args[:job]
        job_status = job_klass.perform_later(current_member_id, (request.uuid if defined?(request))).job_status
        job_status.update_attributes!(user_id: current_user.id)
        instance_variable_set("@#{name}_job_status_url", job_status_url(job_status))
        instance_variable_set("@#{name}_load_url", send(args[:load_helper], :"#{name}_job_id" => job_status.id))
      else
        if args[:cache_data_handler].respond_to?(:call)
          args[:cache_data_handler].call(cached_data)
        else
          send(args[:cache_data_handler], cached_data)
        end
      end
    end
  end

  def calculate_borrowing_capacity_gauge(borrowing_capacity)
    # Nil check sbc collateral types
    borrowing_capacity[:sbc] = {} unless borrowing_capacity[:sbc]
    borrowing_capacity[:sbc][:collateral] = {} unless borrowing_capacity[:sbc][:collateral]
    borrowing_capacity[:sbc][:collateral][:agency] = {} unless borrowing_capacity[:sbc][:collateral][:agency]
    borrowing_capacity[:sbc][:collateral][:aaa] = {} unless borrowing_capacity[:sbc][:collateral][:aaa]
    borrowing_capacity[:sbc][:collateral][:aa] = {} unless borrowing_capacity[:sbc][:collateral][:aa]

    # Totals
    total_borrowing_capacity = borrowing_capacity[:total_borrowing_capacity].to_i

    # Standard
    total_standard_bc = borrowing_capacity[:net_plus_securities_capacity].to_i
    remaining_standard_bc = borrowing_capacity[:standard_excess_capacity].to_i
    used_standard_bc = total_standard_bc - remaining_standard_bc

    # Agency
    total_agency_bc = borrowing_capacity[:sbc][:collateral][:agency][:total_borrowing_capacity].to_i
    remaining_agency_bc = borrowing_capacity[:sbc][:collateral][:agency][:remaining_borrowing_capacity].to_i
    used_agency_bc = total_agency_bc - remaining_agency_bc

    # AAA
    total_aaa_bc = borrowing_capacity[:sbc][:collateral][:aaa][:total_borrowing_capacity].to_i
    remaining_aaa_bc = borrowing_capacity[:sbc][:collateral][:aaa][:remaining_borrowing_capacity].to_i
    used_aaa_bc = total_aaa_bc - remaining_aaa_bc

    # AA
    total_aa_bc = borrowing_capacity[:sbc][:collateral][:aa][:total_borrowing_capacity].to_i
    remaining_aa_bc = borrowing_capacity[:sbc][:collateral][:aa][:remaining_borrowing_capacity].to_i
    used_aa_bc = total_aa_bc - remaining_aa_bc

    if total_borrowing_capacity != 0
      borrowing_capacity_gauge = {
        total: total_borrowing_capacity,
        mortgages: total_standard_bc,
        agency: total_agency_bc,
        aaa: total_aaa_bc,
        aa: total_aa_bc
      }
      borrowing_capacity_gauge = calculate_gauge_percentages(borrowing_capacity_gauge, :total)
      borrowing_capacity_gauge[:mortgages][:breakdown] = {
        total: total_standard_bc,
        remaining: remaining_standard_bc,
        used: used_standard_bc
      }
      borrowing_capacity_gauge[:mortgages][:breakdown] = calculate_gauge_percentages(borrowing_capacity_gauge[:mortgages][:breakdown], :total)

      borrowing_capacity_gauge[:agency][:breakdown] = {
        total: total_agency_bc,
        remaining: remaining_agency_bc,
        used: used_agency_bc
      }
      borrowing_capacity_gauge[:agency][:breakdown] = calculate_gauge_percentages(borrowing_capacity_gauge[:agency][:breakdown], :total)

      borrowing_capacity_gauge[:aaa][:breakdown] = {
        total: total_aaa_bc,
        remaining: remaining_aaa_bc,
        used: used_aaa_bc
      }
      borrowing_capacity_gauge[:aaa][:breakdown] = calculate_gauge_percentages(borrowing_capacity_gauge[:aaa][:breakdown], :total)
      borrowing_capacity_gauge[:aa][:breakdown] = {
        total: total_aa_bc,
        remaining: remaining_aa_bc,
        used: used_aa_bc
      }
      borrowing_capacity_gauge[:aa][:breakdown] = calculate_gauge_percentages(borrowing_capacity_gauge[:aa][:breakdown], :total)
      borrowing_capacity_gauge[:total][:standard_percentage] = borrowing_capacity_gauge[:mortgages][:percentage]
      borrowing_capacity_gauge[:total][:sbc_percentage] = (borrowing_capacity_gauge[:agency][:percentage] + borrowing_capacity_gauge[:aaa][:percentage] + borrowing_capacity_gauge[:aa][:percentage])
    else
      borrowing_capacity_gauge = calculate_gauge_percentages({total: 0})
      borrowing_capacity_gauge[:total][:standard_percentage] = 0
      borrowing_capacity_gauge[:total][:sbc_percentage] = 0
    end
    borrowing_capacity_gauge
  end

  def process_activity_entries(entries)
    activity_data = []
    entries.each do |entry|

      break if activity_data.length == CURRENT_ACTIVITY_COUNT
      result = process_patterns(ACTIVITY_PATTERNS, entry)
      if result
        raise ArgumentError.new('Missing `description`') unless result[:description]
        raise ArgumentError.new('Missing `amount`') unless result[:amount]
        raise ArgumentError.new('Missing `event`') unless result[:event]
        raise ArgumentError.new('Missing `transaction_number`') unless result[:transaction_number]
        activity_data.push(result)
      end
    end
    activity_data.sort_by { |item| item[:transaction_number] }.reverse
  end

  def process_patterns(patterns, entry)
    patterns.each do |pattern_definition|
      if pattern_matches?(pattern_definition[:pattern], entry)
        result = {}
        pattern_definition[:returns].each do |key, value|
          if value.respond_to?(:call)
            result[key] = value.call(entry, key,  self)
          else
            result[key] = value
          end
        end
        return result
      end
    end
    return nil
  end

  def pattern_matches?(pattern, entry)
    matched = true
    pattern.each do |key, matcher|
      if matcher.respond_to?(:call)
        matched = !!matcher.call(entry, key, self)
      elsif matcher.is_a?(Regexp)
        matched = !!matcher.match(entry[key].to_s)
      else
        matched = matcher == entry[key]
      end
      break unless matched
    end
    matched
  end
end
class Admin::RulesController < Admin::BaseController
  include CustomFormattingHelper

  VALID_TERMS = [
    :open, :'1week', :'2week', :'3week', :'1month', :'2month', :'3month', :'6month', :'9month', :'12month', :'1year',
    :'2year', :'3year'
  ].freeze

  LONG_FRC_TERMS = [:'1year', :'2year', :'3year'].freeze

  HOUR_DROPDOWN_OPTIONS = [
    [I18n.t('times.07'), '07'],
    [I18n.t('times.08'), '08'],
    [I18n.t('times.09'), '09'],
    [I18n.t('times.10'), '10'],
    [I18n.t('times.11'), '11'],
    [I18n.t('times.12'), '12'],
    [I18n.t('times.13'), '13'],
    [I18n.t('times.14'), '14'],
    [I18n.t('times.15'), '15'],
    [I18n.t('times.16'), '16'],
    [I18n.t('times.17'), '17'],
    [I18n.t('times.18'), '18']
  ].freeze

  MINUTE_DROPDOWN_OPTIONS = [
    [I18n.t('times.full_hour'), '00'],
    [I18n.t('times.half_hour'), '30']
  ].freeze

  before_action do
    set_active_nav(:rules)
    @can_edit_trade_rules = policy(:web_admin).edit_trade_rules?
  end

  before_action only: [:update_limits, :update_rate_bands, :update_advance_availability_by_term, :update_advance_availability_by_member, :enable_etransact_service, :disable_etransact_service, :view_early_shutoff, :new_early_shutoff, :update_early_shutoff, :remove_early_shutoff, :edit_typical_shutoff] do
    authorize :web_admin, :edit_trade_rules?
  end

  before_action only: [:advance_availability_status, :advance_availability_by_term] do
    @availability_headings = {
      column_headings: ['', t('dashboard.quick_advance.table.axes_labels.standard'), t('dashboard.quick_advance.table.axes_labels.securities_backed'), '', ''],
      rows: [{
        columns: [
          {value: nil},
          {value: t('dashboard.quick_advance.table.whole_loan')},
          {value: t('dashboard.quick_advance.table.agency')},
          {value: t('dashboard.quick_advance.table.aaa')},
          {value: t('dashboard.quick_advance.table.aa')}
        ]
      }]
    }
  end

  before_action :fetch_early_shutoff_request, only: [:view_early_shutoff, :new_early_shutoff, :update_early_shutoff, :remove_early_shutoff]
  after_action :save_early_shutoff_request, only: [:view_early_shutoff, :new_early_shutoff, :update_early_shutoff, :remove_early_shutoff]

  # GET
  def limits
    etransact_service = EtransactAdvancesService.new(request)
    global_limit_data = etransact_service.settings
    term_limit_data = etransact_service.limits
    raise 'There has been an error and Admin::RulesController#limits has encountered nil. Check error logs.' if global_limit_data.nil? || term_limit_data.nil?
    @global_limits = {}
    @global_limits[:rows] = [
      {columns: [
        {value: fhlb_add_unit_to_table_header(t('admin.term_rules.daily_limit.per_member'), '$')},
        {value: global_limit_data[:shareholder_total_daily_limit],
         type: :text_field,
         name: 'global_limits[shareholder_total_daily_limit]',
         value_type: :number,
         disabled: !@can_edit_trade_rules,
         options: {html: false}
        }
      ]},
      {columns: [
        {value: fhlb_add_unit_to_table_header(t('admin.term_rules.daily_limit.all_member'), '$')},
        {value: global_limit_data[:shareholder_web_daily_limit],
         type: :text_field,
         name: 'global_limits[shareholder_web_daily_limit]',
         value_type: :number,
         disabled: !@can_edit_trade_rules,
         options: {html: false}
        }
      ]}
    ]
    @term_limits = {
      column_headings: ['', fhlb_add_unit_to_table_header(t('admin.term_rules.daily_limit.minimum_online'), '$'), fhlb_add_unit_to_table_header(t('admin.term_rules.daily_limit.daily'), '$')]
    }
    @term_limits[:rows] = term_limit_data.collect do |bucket|
      term = bucket[:term]
      raise "There has been an error and Admin::RulesController#limits has encountered an etransact_service.limits bucket with an invalid term: #{term}" unless VALID_TERMS.include?(term.to_sym)
      {columns: [
        {value: t("admin.term_rules.daily_limit.dates.#{term}")},
        {value: bucket[:min_online_advance].to_i,
         type: :text_field,
         name: "term_limits[#{term}][min_online_advance]",
         value_type: :number,
         disabled: !@can_edit_trade_rules,
         options: {html: false}
        },
        {value: bucket[:term_daily_limit].to_i,
         type: :text_field,
         name: "term_limits[#{term}][term_daily_limit]",
         value_type: :number,
         disabled: !@can_edit_trade_rules,
         options: {html: false}
        }
      ]}
    end
  end

  # PUT
  def update_limits
    etransact_service = EtransactAdvancesService.new(request)
    global_limits = params[:global_limits].with_indifferent_access
    term_limits = params[:term_limits].with_indifferent_access
    settings_results = etransact_service.update_settings(global_limits) || {error: 'There has been an error and Admin::RulesController#update_limits has encountered nil'}
    term_limits_results = etransact_service.update_term_limits(term_limits) || {error: 'There has been an error and Admin::RulesController#update_limits has encountered nil'}
    set_flash_message([settings_results, term_limits_results])
    redirect_to action: :limits
  end

  # GET
  def advance_availability_status
    etransact_service = EtransactAdvancesService.new(request)
    term_limit_data = etransact_service.limits
    etransact_status = etransact_service.status
    set_typical_shutoff_table_var(etransact_service)
    raise "There has been an error and Admin::RulesController#advance_availability_status has encountered nil" unless term_limit_data && etransact_status
    @etransact_enabled = etransact_status[:enabled]

    # Determine if any terms are disabled
    disabled_term_rows = []
    term_limit_data.each do |bucket|
      row = availability_row_from_bucket(bucket)
      disabled_row = false
      row[:columns].each_with_index do |column, i|
        next if i == 0
        disabled_row = !column[:checked]
        break if disabled_row
      end
      row[:columns].map { |column| column[:disabled] = true }
      disabled_term_rows << row if disabled_row
    end
    @disabled_terms = { rows: disabled_term_rows } if disabled_term_rows.present?
  end

  # PUT
  def enable_etransact_service
    enable_etransact_results = EtransactAdvancesService.new(request).enable_etransact_service || {error: 'There has been an error and Admin::RulesController#enable_etransact_service has encountered nil'}
    set_flash_message(enable_etransact_results)
    redirect_to action: :advance_availability_status
  end

  # PUT
  def disable_etransact_service
    disable_etransact_results = EtransactAdvancesService.new(request).disable_etransact_service || {error: 'There has been an error and Admin::RulesController#disable_etransact_service has encountered nil'}
    set_flash_message(disable_etransact_results)
    redirect_to action: :advance_availability_status
  end

  # GET
  def advance_availability_by_term
    etransact_service = EtransactAdvancesService.new(request)
    term_limit_data = etransact_service.limits
    raise 'There has been an error and Admin::RulesController#advance_availability_by_term has encountered nil. Check error logs.' if term_limit_data.nil?
    @vrc_availability = {rows: []}
    @frc_availability = {rows: []}
    @long_term_availability = {rows: []}
    term_limit_data.each do |bucket|
      term = bucket[:term].to_sym
      row = availability_row_from_bucket(bucket)
      if term == :open
        @vrc_availability[:rows] << row
      elsif LONG_FRC_TERMS.include?(term)
        @long_term_availability[:rows] << row
      else
        @frc_availability[:rows] << row
      end
    end
  end

  # PUT
  def update_advance_availability_by_term
    etransact_service = EtransactAdvancesService.new(request)
    term_limits = params[:term_limits].with_indifferent_access
    term_limits.each do |term, limit_data|
      limit_data.each do |type, status|
        term_limits[term][type] = status == 'on'
      end
    end
    term_limits_results = etransact_service.update_term_limits(term_limits) || {error: 'There has been an error and Admin::RulesController#update_advance_availability_by_term has encountered nil'}
    set_flash_message(term_limits_results)
    redirect_to action: :advance_availability_by_term
  end

  # GET
  def advance_availability_by_member
    quick_advance_enabled = MembersService.new(request).quick_advance_enabled
    raise "There has been an error and Admin::RulesController#advance_availability_by_member has encountered nil" unless quick_advance_enabled.present?
    quick_advance_enabled.sort_by! { |flag| flag['member_name'] }
    @advance_availability = {
      dropdown: {
        name: 'advance-availability-by-member-dropdown',
        default_text: t('admin.advance_availability.availability_by_member.filter.all'),
        default_value: 'all',
        options: [
          [ t('admin.advance_availability.availability_by_member.filter.all'), 'all' ],
          [ t('admin.advance_availability.availability_by_member.filter.enabled'), 'enabled' ],
          [ t('admin.advance_availability.availability_by_member.filter.disabled'), 'disabled' ] 
        ]
      },
      table: {
        rows: quick_advance_enabled.collect do |flag|
          {
            columns: [
              { value: flag['member_name'] },
              { name: "member_id[#{flag['fhlb_id']}]",
                checked: flag['quick_advance_enabled'],
                type: :checkbox,
                label: true,
                submit_unchecked_boxes: true,
                disabled: !@can_edit_trade_rules
              }
            ]
          }
        end
      }
    }
  end

  # PUT
  def update_advance_availability_by_member
    etransact_members_hash = {}
    members_advance_status = params[:member_id].with_indifferent_access
    members_advance_status.each do |member_id, status|
      etransact_members_hash[member_id] = status == 'on'
    end
    etransact_members_results = MembersService.new(request).update_quick_advance_flags_for_members(etransact_members_hash) || {error: 'There has been an error and Admin::RulesController#update_advance_availability_by_member has encountered nil'}
    set_flash_message(etransact_members_results)
    redirect_to action: :advance_availability_by_member
  end

  # GET
  def rate_bands
    rate_bands = RatesService.new(request).rate_bands
    raise 'There has been an error and Admin::RulesController#rate_bands has encountered nil' unless rate_bands
    @rate_bands = {
      column_headings: ['', t('admin.term_rules.rate_bands.low_shutdown_html').html_safe, t('admin.term_rules.rate_bands.low_warning_html').html_safe,
                        t('admin.term_rules.rate_bands.high_warning_html').html_safe, t('admin.term_rules.rate_bands.high_shutdown_html').html_safe],
      rows: []
    }
    rate_bands.each do |term, rate_band_info|
      next if term == 'overnight'
      raise "There has been an error and Admin::RulesController#rate_bands has encountered a RatesService.rate_bands bucket with an invalid term: #{term}" unless VALID_TERMS.include?(term.to_sym)
      row = {columns: [
        {value: term == 'open' ? t('admin.term_rules.daily_limit.dates.open') : t("dashboard.quick_advance.table.axes_labels.#{term}")},
        {value: rate_band_info['LOW_BAND_OFF_BP'].to_i,
         type: :text_field,
         name: "rate_bands[#{term}][LOW_BAND_OFF_BP]",
         value_type: :number,
         disabled: !@can_edit_trade_rules,
         options: {html: false}
        },
        {value: rate_band_info['LOW_BAND_WARN_BP'].to_i,
         type: :text_field,
         name: "rate_bands[#{term}][LOW_BAND_WARN_BP]",
         value_type: :number,
         disabled: !@can_edit_trade_rules,
         options: {html: false}
        },
        {value: rate_band_info['HIGH_BAND_WARN_BP'].to_i,
         type: :text_field,
         name: "rate_bands[#{term}][HIGH_BAND_WARN_BP]",
         value_type: :number,
         disabled: !@can_edit_trade_rules,
         options: {html: false}
        },
        {value: rate_band_info['HIGH_BAND_OFF_BP'].to_i,
         type: :text_field,
         name: "rate_bands[#{term}][HIGH_BAND_OFF_BP]",
         value_type: :number,
         disabled: !@can_edit_trade_rules,
         options: {html: false}
        }
      ]}
      @rate_bands[:rows] << row
    end
  end

  # PUT
  def update_rate_bands
    rate_bands = params[:rate_bands].with_indifferent_access
    rate_bands_result = RatesService.new(request).update_rate_bands(rate_bands) || {error: 'There has been an error and Admin::RulesController#update_rate_bands has encountered nil'}
    set_flash_message(rate_bands_result)
    redirect_to action: :rate_bands
  end

  # GET
  def rate_report
    rate_summary = RatesService.new(request).quick_advance_rates(:admin)
    raise 'There has been an error and Admin::RulesController#rate_report has encountered nil' unless rate_summary
    rate_summary = process_rate_summary(rate_summary)
    column_headings = ['', '',
      fhlb_add_unit_to_table_header(t('admin.term_rules.rate_report.opening_rate'), '%'),
      fhlb_add_unit_to_table_header(t('admin.term_rules.rate_report.current_rate'), '%'),
      fhlb_add_unit_to_table_header(t('admin.term_rules.rate_report.change'), 'bps'),
      fhlb_add_unit_to_table_header(t('admin.term_rules.rate_report.low_off').html_safe, '%'),
      fhlb_add_unit_to_table_header(t('admin.term_rules.rate_report.low_warn').html_safe, '%'),
      fhlb_add_unit_to_table_header(t('admin.term_rules.rate_report.high_warn').html_safe, '%'),
      fhlb_add_unit_to_table_header(t('admin.term_rules.rate_report.high_off').html_safe, '%')]
    @vrc_rate_report = {
      column_headings: column_headings,
      rows: []
    }
    @frc_rate_report = {
      column_headings: column_headings,
      rows: []
    }
    rate_summary.each do |advance_term, advance_types|
      next if advance_term == 'overnight'
      advance_types.each do |type, rate_info|
        open = advance_term == 'open'
        term_label = open ? t('admin.term_rules.daily_limit.dates.open') : t("dashboard.quick_advance.table.axes_labels.#{advance_term}")
        row = {columns: [
          {value: nil}, #TODO - This will become the column that indicates if a threshold has been breached as part of MEM-2317
          {value:  term_label + ': ' + t("dashboard.quick_advance.table.#{type}")},
          {value: rate_info[:start_of_day_rate].to_f, type: :rate},
          {value: rate_info[:rate].to_f, type: :rate},
          {value: rate_info[:rate_change_bps], type: :basis_point},
          {value: rate_info[:rate_band_info][:low_band_off_rate].to_f, type: :rate},
          {value: rate_info[:rate_band_info][:low_band_warn_rate].to_f, type: :rate},
          {value: rate_info[:rate_band_info][:high_band_warn_rate].to_f, type: :rate},
          {value: rate_info[:rate_band_info][:high_band_off_rate].to_f, type: :rate}
        ]}
        open ? @vrc_rate_report[:rows] << row : @frc_rate_report[:rows] << row
      end
    end
  end

  # GET
  def term_details
    term_details_data = EtransactAdvancesService.new(request).limits
    raise 'There has been an error and EtransactAdvancesService#limits has encountered nil. Check error logs.' if term_details_data.nil?
    @term_details = {
      column_headings: ['', t('admin.term_rules.term_details.low_days_to_maturity'), t('admin.term_rules.term_details.high_days_to_maturity')]
    }
    @term_details[:rows] = term_details_data.collect do |bucket|
      term = bucket[:term]
      raise "There has been an error and Admin::RulesController#term_details has encountered an etransact_service.limits bucket with an invalid term: #{term}" unless VALID_TERMS.include?(term.to_sym)
      {columns: [
        {value: t("admin.term_rules.daily_limit.dates.#{term}")},
        {value: bucket[:low_days_to_maturity].to_i,
         type: :number
        },
        {value: bucket[:high_days_to_maturity].to_i,
         type: :number
        }
      ]}
    end
  end

  # GET
  def early_shutoff
    early_shutoff_data = EtransactAdvancesService.new(request).early_shutoffs
    raise 'There has been an error and EtransactAdvancesService#early_shutoff has encountered nil. Check error logs.' if early_shutoff_data.nil?
    @early_shutoff_data = early_shutoff_data.collect do |early_shutoff|
      shutoff = EarlyShutoffRequest.new(request)
      shutoff.attributes = early_shutoff
      shutoff.original_early_shutoff_date = shutoff.early_shutoff_date
      shutoff.owners.add(current_user.id)
      shutoff.save
      shutoff
    end
    @early_shutoff_data.sort_by! { |shutoff| shutoff.early_shutoff_date}
    @column_headings = [t('admin.shutoff_times.early.date'), t('admin.shutoff_times.early.time'), t('admin.shutoff_times.early.messages')]
    @column_headings << t('global.actions') if @can_edit_trade_rules
  end

  # GET
  def view_early_shutoff
    @hour_dropdown_options = HOUR_DROPDOWN_OPTIONS
    @minute_dropdown_options = MINUTE_DROPDOWN_OPTIONS
    @dropdown_defaults = {
      frc: {
        hour: {
          text: (HOUR_DROPDOWN_OPTIONS.select{ |option| option.last == early_shutoff_request.frc_shutoff_time_hour}.first.first),
          value: early_shutoff_request.frc_shutoff_time_hour
        },
        minute: {
          text: (MINUTE_DROPDOWN_OPTIONS.select{ |option| option.last == early_shutoff_request.frc_shutoff_time_minute}.first.first),
          value: early_shutoff_request.frc_shutoff_time_minute
        }
      },
      vrc: {
        hour: {
          text: (HOUR_DROPDOWN_OPTIONS.select{ |option| option.last == early_shutoff_request.vrc_shutoff_time_hour}.first.first),
          value: early_shutoff_request.vrc_shutoff_time_hour
        },
        minute: {
          text: (MINUTE_DROPDOWN_OPTIONS.select{ |option| option.last == early_shutoff_request.vrc_shutoff_time_minute}.first.first),
          value: early_shutoff_request.vrc_shutoff_time_minute
        }
      }
    }
    @form_data = if params[:edit_request]
      {
        url: rules_advance_update_early_shutoff_url,
        method: :put
      }
    else
      {
        url: rules_advance_new_early_shutoff_url,
        method: :post
      }
    end
  end

  # POST
  def new_early_shutoff
    early_shutoff_request.attributes = params[:early_shutoff_request]
    if EtransactAdvancesService.new(request).schedule_early_shutoff(early_shutoff_request, &early_shutoff_error_handler)
      set_flash_message({}, t('admin.shutoff_times.schedule_early.success'))
      redirect_to action: :early_shutoff
    end
  end

  # PUT
  def update_early_shutoff
    early_shutoff_request.attributes = params[:early_shutoff_request]
    if EtransactAdvancesService.new(request).update_early_shutoff(early_shutoff_request, &early_shutoff_error_handler)
      set_flash_message({}, t('admin.shutoff_times.schedule_early.update_success'))
      redirect_to action: :early_shutoff
    end
  end

  # DELETE
  def remove_early_shutoff
    early_shutoff_request.attributes = params[:early_shutoff_request]
    early_shutoff_result = EtransactAdvancesService.new(request).remove_early_shutoff(early_shutoff_request) || {error: 'There has been an error and Admin::RulesController#remove_early_shutoff has encountered nil'}
    set_flash_message(early_shutoff_result, t('admin.shutoff_times.schedule_early.remove_success'))
    redirect_to action: :early_shutoff
  end

  # GET
  def typical_shutoff
    set_typical_shutoff_table_var
    @hour_dropdown_options = HOUR_DROPDOWN_OPTIONS
    @minute_dropdown_options = MINUTE_DROPDOWN_OPTIONS
    frc_hour = sprintf('%02d', @typical_shutoff_times[:frc].hour) if @typical_shutoff_times[:frc]
    frc_minute = sprintf('%02d', @typical_shutoff_times[:frc].min) if @typical_shutoff_times[:frc]
    vrc_hour = sprintf('%02d', @typical_shutoff_times[:vrc].hour) if @typical_shutoff_times[:vrc]
    vrc_minute = sprintf('%02d', @typical_shutoff_times[:vrc].min) if @typical_shutoff_times[:vrc]
    @dropdown_defaults = {
      frc: {
        hour: {
          text: ((HOUR_DROPDOWN_OPTIONS.select{ |option| option.last == frc_hour}.first || HOUR_DROPDOWN_OPTIONS.last).first),
          value: frc_hour || HOUR_DROPDOWN_OPTIONS.last.last
        },
        minute: {
          text: ((MINUTE_DROPDOWN_OPTIONS.select{ |option| option.last == frc_minute}.first || MINUTE_DROPDOWN_OPTIONS.last).first),
          value: frc_minute || MINUTE_DROPDOWN_OPTIONS.last.last
        }
      },
      vrc: {
        hour: {
          text: ((HOUR_DROPDOWN_OPTIONS.select{ |option| option.last == vrc_hour}.first || HOUR_DROPDOWN_OPTIONS.last).first),
          value: vrc_hour || HOUR_DROPDOWN_OPTIONS.last.last
        },
        minute: {
          text: ((MINUTE_DROPDOWN_OPTIONS.select{ |option| option.last == vrc_minute}.first || MINUTE_DROPDOWN_OPTIONS.last).first),
          value: vrc_minute || MINUTE_DROPDOWN_OPTIONS.last.last
        }
      }
    }
  end

  # PUT
  def edit_typical_shutoff
    shutoff_times = {
      vrc: params[:vrc_shutoff_time_hour] + params[:vrc_shutoff_time_minute],
      frc: params[:frc_shutoff_time_hour] + params[:frc_shutoff_time_minute]
    }
    shutoff_times_result = EtransactAdvancesService.new(request).edit_shutoff_times_by_type(shutoff_times) || {error: 'There has been an error and Admin::RulesController#edit_typical_shutoff has encountered nil'}
    set_flash_message(shutoff_times_result)
    redirect_to action: :typical_shutoff
  end

  private

  def set_flash_message(results, success_message=nil)
    errors = Array.wrap(results).collect{ |result| result[:error] }.compact
    if errors.present?
      errors.each { |error| logger.error(error) }
      error_message = if errors.first.is_a?(Hash) && errors.first[:type].to_sym == :duplicate
        t('admin.shutoff_times.schedule_early.duplicate_error')
      else
        t('admin.term_rules.messages.error')
      end
      flash[:error] = error_message
    else
      flash[:notice] = success_message || t('admin.term_rules.messages.success')
    end
  end

  def process_rate_summary(rate_summary)
    processed_summary = {}
    rate_summary.each do |advance_type, advance_terms|
      next if advance_type == 'timestamp'
      advance_terms.each do |term, rate_info|
        processed_summary[term] ||= {}
        processed_summary[term][advance_type] = rate_info.with_indifferent_access
      end
    end
    processed_summary
  end

  def availability_row_from_bucket(bucket)
    term = bucket[:term].try(:to_sym)
    raise "There has been an error and Admin::RulesController#advance_availability_by_term has encountered an etransact_service.limits bucket with an invalid term: #{term}" unless VALID_TERMS.include?(term)
    term_label = term == :open ? t('admin.advance_availability.availability_by_term.open_label') : t("admin.term_rules.daily_limit.dates.#{term}")
    {columns: [
      {value: term_label},
      {
        name: "term_limits[#{term}][whole_loan_enabled]",
        type: :checkbox,
        submit_unchecked_boxes: true,
        checked: bucket[:whole_loan_enabled],
        label: true,
        disabled: !@can_edit_trade_rules
      },
      {
        name: "term_limits[#{term}][sbc_agency_enabled]",
        type: :checkbox,
        submit_unchecked_boxes: true,
        checked: bucket[:sbc_agency_enabled],
        label: true,
        disabled: !@can_edit_trade_rules
      },
      {
        name: "term_limits[#{term}][sbc_aaa_enabled]",
        type: :checkbox,
        submit_unchecked_boxes: true,
        checked: bucket[:sbc_aaa_enabled],
        label: true,
        disabled: !@can_edit_trade_rules
      },
      {
        name: "term_limits[#{term}][sbc_aa_enabled]",
        type: :checkbox,
        submit_unchecked_boxes: true,
        checked: bucket[:sbc_aa_enabled],
        label: true,
        disabled: !@can_edit_trade_rules
      }
    ]}
  end

  def early_shutoff_request
    @early_shutoff_request ||= EarlyShutoffRequest.new(request)
    @early_shutoff_request.owners.add(current_user.id)
    @early_shutoff_request
  end

  def fetch_early_shutoff_request
    early_shutoff_params = (request.params[:early_shutoff_request] || {}).with_indifferent_access
    id = early_shutoff_params[:id]
    @early_shutoff_request = id ? EarlyShutoffRequest.find(id, request) : early_shutoff_request
    authorize @early_shutoff_request, :modify_early_shutoff_request?
    @early_shutoff_request
  end

  def save_early_shutoff_request
    @early_shutoff_request.save if @early_shutoff_request
  end

  def set_typical_shutoff_table_var(etransact_service=nil)
    etransact_service ||= EtransactAdvancesService.new(request)
    @typical_shutoff_times = etransact_service.shutoff_times_by_type
    raise "There has been an error and Admin::RulesController##{action_name} has encountered nil" unless @typical_shutoff_times
    @typical_shutoff_times_table = {
      rows: [
        {columns: [
          {value: t('admin.shutoff_times.early.vrc_terms')},
          {value: @typical_shutoff_times[:vrc], type: :time}
        ]},
        {columns: [
          {value: t('admin.shutoff_times.early.frc_terms')},
          {value: @typical_shutoff_times[:frc], type: :time}
        ]}
      ]
    }
  end

  def early_shutoff_error_handler
    ->(error) do
      message = if error && error.http_body
        JSON.parse(error.http_body).with_indifferent_access
      else
        {error: "There has been an error and Admin::RulesController##{action_name} has encountered nil"}
      end
      set_flash_message(message)
      redirect_to action: :view_early_shutoff, early_shutoff_request: {id: early_shutoff_request.id}
    end
  end
end
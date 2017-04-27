class SecuritiesController < ApplicationController
  include CustomFormattingHelper
  include ContactInformationHelper
  include ActionView::Helpers::TextHelper
  include DatePickerHelper

  before_action only: [:delete_request] do
    authorize :security, :delete?
  end

  before_action only: [ :edit_safekeep, :edit_pledge, :edit_release, :edit_transfer ] do
    @accepted_upload_mimetypes = ACCEPTED_UPLOAD_MIMETYPES.join(', ')
  end

  ACCEPTED_UPLOAD_MIMETYPES = [
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-excel',
    'text/csv',
    'application/vnd.oasis.opendocument.spreadsheet',
    'application/octet-stream'
  ]

  TRANSACTION_DROPDOWN_MAPPING = {
    standard: {
      text: 'securities.release.transaction_code.standard',
      value: SecuritiesRequest::TRANSACTION_CODES[:standard]
    },
    repo: {
      text: 'securities.release.transaction_code.repo',
      value: SecuritiesRequest::TRANSACTION_CODES[:repo]
    }
  }.freeze

  SETTLEMENT_TYPE_DROPDOWN_MAPPING = {
    free: {
      text: 'securities.release.settlement_type.free',
      value: SecuritiesRequest::SETTLEMENT_TYPES[:free]
    },
    vs_payment: {
      text: 'securities.release.settlement_type.vs_payment',
      value: SecuritiesRequest::SETTLEMENT_TYPES[:vs_payment]
    }
  }.freeze

  DELIVERY_INSTRUCTIONS_DROPDOWN_MAPPING = {
    dtc: {
      text: 'securities.release.delivery_instructions.dtc',
      value: SecuritiesRequest::DELIVERY_TYPES[:dtc]
    },
    fed: {
      text: 'securities.release.delivery_instructions.fed',
      value: SecuritiesRequest::DELIVERY_TYPES[:fed]
    },
    mutual_fund: {
      text: 'securities.release.delivery_instructions.mutual_fund',
      value: SecuritiesRequest::DELIVERY_TYPES[:mutual_fund]
    },
    physical_securities: {
      text: 'securities.release.delivery_instructions.physical_securities',
      value: SecuritiesRequest::DELIVERY_TYPES[:physical_securities]
    }
  }.freeze

  PLEDGE_TO_MAPPING = {
    :sbc => I18n.t('securities.requests.view.request_details.pledge_to.types.sbc'),
    :standard => I18n.t('securities.requests.view.request_details.pledge_to.types.standard_credit')
  }.freeze

  VALID_REQUEST_TYPES = [:release, :pledge, :safekeep, :transfer].freeze

  DELIVER_TO_MAPPING = {
    '88'=> 'FED',
    '89'=> 'DTC'
  }

  before_action do
    set_active_nav(:securities)
    @html_class ||= 'white-background'
  end

  def manage
    @title = t('securities.manage.title')
    member_balances = MemberBalanceService.new(current_member_id, request)
    securities = member_balances.managed_securities
    raise StandardError, "There has been an error and SecuritiesController#manage has encountered nil. Check error logs." if securities.nil?

    securities.collect! { |security| Security.from_hash(security) }
    rows = []
    securities.each do |security|
      cusip = security.cusip
      status = Security.human_custody_account_type_to_status(security.custody_account_type)
      columns = [
        {value: security.to_json, type: :checkbox, name: "securities[]", disabled: cusip.blank?, data: {status: status}},
        {value: cusip || t('global.missing_value')},
        {value: security.description || t('global.missing_value')},
        {value: status},
        {value: security.eligibility || t('global.missing_value')},
        {value: security.maturity_date, type: :date},
        {value: security.authorized_by || t('global.missing_value')},
        {value: security.current_par, type: :number},
        {value: security.borrowing_capacity, type: :number}
      ]
      columns.insert(4, {value: DELIVER_TO_MAPPING[security.reg_id] || t('global.missing_value')}) if feature_enabled?('securities-delivery-method')
      rows << {
        filter_data: status,
        columns: columns
      }
    end
    column_headings = [{value: 'check_all', type: :checkbox, name: 'check_all'}, t('common_table_headings.cusip'), t('common_table_headings.description'), t('common_table_headings.status'), t('securities.manage.eligibility'), t('common_table_headings.maturity_date'), t('common_table_headings.authorized_by'), fhlb_add_unit_to_table_header(t('common_table_headings.current_par'), '$'), fhlb_add_unit_to_table_header(t('global.borrowing_capacity'), '$')]
    column_headings.insert(4, t('securities.manage.delivery')) if feature_enabled?('securities-delivery-method')
    @securities_table_data = {
      filter: {
        name: 'securities-status-filter',
        data: [
          {
            text: t('securities.manage.safekept'),
            value: 'Safekept'
          },
          {
            text: t('securities.manage.pledged'),
            value: 'Pledged'
          },
          {
            text: t('securities.manage.all'),
            value: 'all',
            active: true
          }
        ]
      },
      column_headings: column_headings,
      rows: rows
    }

  end

  def requests
    @title = t('securities.requests.title')
    service = SecuritiesRequestService.new(current_member_id, request)
    authorized_requests = service.authorized
    awaiting_authorization_requests = service.awaiting_authorization
    raise StandardError, "There has been an error and SecuritiesController#requests has encountered nil. Check error logs." if authorized_requests.nil? || awaiting_authorization_requests.nil?

    is_collateral_authorizer = policy(:security).authorize_collateral?
    is_securities_authorizer = policy(:security).authorize_securities?

    @awaiting_authorization_requests_table = {
      column_headings: [
        t('securities.requests.columns.request_id'),
        t('common_table_headings.description'),
        t('securities.requests.columns.submitted_by'),
        t('securities.requests.columns.submitted_date'),
        t('common_table_headings.settlement_date'),
        t('global.actions')
      ],
      rows: awaiting_authorization_requests.collect do |request|
        kind = request[:kind]
        request_id = request[:request_id]
        view_path = case kind
        when 'pledge_release', 'safekept_release'
          securities_release_view_path(request_id)
        when 'pledge_intake'
          securities_pledge_view_path(request_id)
        when 'safekept_intake'
          securities_safekeep_view_path(request_id)
        when 'safekept_transfer', 'pledge_transfer'
          securities_transfer_view_path(request_id)
        end
        authorize = if kind
          is_request_collateral?(kind) ? is_collateral_authorizer : is_securities_authorizer
        else
          false
        end
        action_cell_value = authorize ? [[t('securities.requests.actions.authorize'), view_path ]] : [t('securities.requests.actions.authorize')]
        {
          columns: [
            {value: request_id},
            {value: kind_to_description(kind)},
            {value: request[:submitted_by]},
            {value: request[:submitted_date], type: :date},
            {value: request[:settle_date], type: :date},
            {value: action_cell_value, type: :actions}
          ]
        }
      end
    }

    @authorized_requests_table = {
      column_headings: [
        t('securities.requests.columns.request_id'),
        t('common_table_headings.description'),
        t('common_table_headings.authorized_by'),
        t('securities.requests.columns.authorization_date'),
        t('common_table_headings.settlement_date'),
        t('global.actions')
      ],
      rows: authorized_requests.collect do |request|
        kind = request[:kind]
        {
          columns: [
            {value: request[:request_id]},
            {value: kind_to_description(kind)},
            {value: request[:authorized_by]},
            {value: request[:authorized_date], type: :date},
            {value: request[:settle_date], type: :date},
            {value: [[t('global.view'), securities_release_generate_authorized_request_path(request_id: request[:request_id], kind: kind)]], type: :actions}
          ]
        }
      end
    }
  end

  def generate_authorized_request
    pdf_name = "authorized_request_#{params[:request_id]}.pdf"
    job_status = RenderSecuritiesRequestsPDFJob.perform_later(current_member_id, 'view_authorized_request', pdf_name, { request_id: params[:request_id], kind: params[:kind] }).job_status
    job_status.update_attributes!(user_id: current_user.id)
    render json: {job_status_url: job_status_url(job_status), job_cancel_url: job_cancel_url(job_status)}
  end

  def view_authorized_request
    @member = MembersService.new(request).member(current_member_id)
    raise ActionController::RoutingError.new("There has been an error and SecuritiesController#view_authorized_request has encountered nil calling MembersService. Check error logs.") if @member.nil?
    @member_profile = MemberBalanceService.new(current_member_id, request).profile
    raise ActionController::RoutingError.new("There has been an error and SecuritiesController#view_authorized_request has encountered nil calling MemberBalanceService. Check error logs.") if @member_profile.nil?
    @securities_request = SecuritiesRequestService.new(current_member_id, request).submitted_request(params[:request_id])
    raise ActionController::RoutingError.new("There has been an error retrieving the securities request. Check error logs.") if @securities_request.nil?
    account_number = case @securities_request.kind
    when :pledge_release, :pledge_intake
      @securities_request.pledged_account
    when :safekept_intake, :safekept_release
      @securities_request.safekept_account
    else
      ArgumentError.new("invalid kind: #{@securities_request.kind}")
    end
    @title = case @securities_request.kind
    when :pledge_release
      t('securities.requests.view.pledge_release.title')
    when :safekept_release
      t('securities.requests.view.safekept_release.title')
    when :safekept_intake
      t('securities.requests.view.safekept_intake.title')
    when :pledge_intake
      t('securities.requests.view.pledge_intake.title')
    when :safekept_transfer
      t('securities.requests.view.safekept_transfer.title')
    when :pledge_transfer
      t('securities.requests.view.pledge_transfer.title')
    end
    @request_details_table_data = {
      rows: [ { columns: [ { value: t('securities.requests.view.request_details.request_id') },
                           { value: @securities_request.request_id } ] },
              { columns: [ { value: t('securities.requests.view.request_details.authorized_by') },
                           { value: @securities_request.authorized_by } ] },
              { columns: [ { value: t('securities.requests.view.request_details.authorization_date') },
                           { value: fhlb_date_standard_numeric(@securities_request.authorized_date) } ] } ] }
    @request_details_table_data[:rows] << { columns: [
      { value: t('securities.requests.view.request_details.pledge_to.pledge_type') },
      { value: PLEDGE_TO_MAPPING[@securities_request.pledge_to] } ] } if [:pledge_transfer, :pledge_intake].include?(@securities_request.kind)

    unless SecuritiesRequest::TRANSFER_KINDS.include?(@securities_request.kind)
      @broker_instructions_table_data = {
        rows: [ { columns: [ { value: t('securities.requests.view.broker_instructions.transaction_code') },
                             { value: @securities_request.transaction_code.to_s.titleize } ] },
                { columns: [ { value: t('securities.requests.view.broker_instructions.settlement_type') },
                             { value: @securities_request.settlement_type.to_s.titleize } ] },
                { columns: [ { value: t('securities.requests.view.broker_instructions.trade_date') },
                             { value: fhlb_date_standard_numeric(@securities_request.trade_date) } ] },
                { columns: [ { value: t('securities.requests.view.broker_instructions.settlement_date') },
                             { value: fhlb_date_standard_numeric(@securities_request.settlement_date) } ] } ] }

      @delivery_instructions_table_data = { rows: get_delivery_instruction_rows(@securities_request) }
    end
    rows = []
    @securities_request.securities.each do |security|
      rows << { columns: [ { value: security.cusip },
                           { value: security.description },
                           { value: security.original_par, type: :currency, options: { unit: '' } } ] }
      rows.last[:columns] << { value: security.payment_amount, type: :currency, options: { unit: '' } } unless SecuritiesRequest::TRANSFER_KINDS.include?(@securities_request.kind)
      rows.last[:columns] << { value: security.custodian_name } if SecuritiesRequest::INTAKE_KINDS.include?(@securities_request.kind)
    end

    @securities_table_data = {
      column_headings: [ t('common_table_headings.cusip'),
                         t('common_table_headings.description'),
                         fhlb_add_unit_to_table_header(t('common_table_headings.original_par'), '$') ],
      rows: rows
    }
    @securities_table_data[:column_headings] <<
      t('securities.requests.view.securities.settlement_amount',
        footnote_marker: fhlb_footnote_marker) unless SecuritiesRequest::TRANSFER_KINDS.include?(@securities_request.kind)
    @securities_table_data[:column_headings] <<
      t('common_table_headings.custodian_name',
        footnote_marker: fhlb_footnote_marker(1)) if SecuritiesRequest::INTAKE_KINDS.include?(@securities_request.kind)
  end

  def edit_safekeep
    kind = :safekept_intake
    populate_view_variables(:safekeep)
    @securities_request.safekept_account = MembersService.new(request).member(current_member_id)['unpledged_account_number']
    @securities_request.kind = kind
    populate_form_data_by_kind(kind)
    populate_contact_info_by_kind(kind)
    set_edit_title_by_kind(kind)
  end

  def edit_pledge
    kind = :pledge_intake
    populate_view_variables(:pledge)
    @securities_request.pledged_account = MembersService.new(request).member(current_member_id)['pledged_account_number']
    @securities_request.kind = kind
    populate_form_data_by_kind(kind)
    populate_contact_info_by_kind(kind)
    set_edit_title_by_kind(kind)
  end

  # POST
  def edit_release
    populate_view_variables(:release)
    raise ArgumentError.new('Securities cannot be nil') unless @securities_request.securities.present?
    kind = case @securities_request.securities.first.custody_account_type
    when 'U'
      :safekept_release
    when 'P'
      :pledge_release
    else
      raise ArgumentError, 'Unrecognized `custody_account_type` for passed security.'
    end
    @securities_request.kind = kind
    populate_form_data_by_kind(kind)
    populate_contact_info_by_kind(kind)
    set_edit_title_by_kind(kind)
  end

  # POST
  def edit_transfer
    populate_view_variables(:transfer)
    @securities_request.safekept_account = MembersService.new(request).member(current_member_id)['unpledged_account_number']
    @securities_request.pledged_account = MembersService.new(request).member(current_member_id)['pledged_account_number']
    kind = case @securities_request.securities.first.custody_account_type
    when 'U'
      :pledge_transfer
    when 'P'
      :safekept_transfer
    else
      raise ArgumentError, 'Unrecognized `custody_account_type` for passed security.'
    end
    @securities_request.kind = kind
    populate_form_data_by_kind(kind)
    populate_contact_info_by_kind(kind)
    set_edit_title_by_kind(kind)
  end

  # GET
  def view_request
    request_id = params[:request_id]
    type = params[:type].try(:to_sym)
    raise ArgumentError, "Unknown request type: #{type}" unless VALID_REQUEST_TYPES.include?(type)
    @securities_request = SecuritiesRequestService.new(current_member_id, request).submitted_request(request_id)
    raise ActionController::RoutingError.new("There has been an error retrieving the securities request. Check error logs.") if @securities_request.nil?
    authorize :security, @securities_request.is_collateral? ? :authorize_collateral? : :authorize_securities?
    kind = @securities_request.kind
    raise ActionController::RoutingError.new("The type specified by the `/securities/view` route does not match the @securities_request.kind. \nType: `#{type}`\nKind: `#{kind}`") unless type_matches_kind(type, kind)
    populate_view_variables(type)
    populate_form_data_by_kind(kind)
    populate_contact_info_by_kind(kind)
    set_edit_title_by_kind(kind)
    case type
    when :release
      render :edit_release
    when :pledge
      render :edit_pledge
    when :safekeep
      render :edit_safekeep
    when :transfer
      render :edit_transfer
    end
  end

  def download_release
    securities = JSON.parse(params[:securities]).collect! { |security| Security.from_hash(security) }
    populate_securities_table_data_view_variable(:release, securities)
    render xlsx: 'securities', filename: "securities-release.xlsx", formats: [:xlsx], locals: { type: :release, title: t('securities.download.titles.release') }
  end

  def download_transfer
    securities = JSON.parse(params[:securities]).collect! { |security| Security.from_hash(security) }
    populate_securities_table_data_view_variable(:transfer, securities)
    render xlsx: 'securities', filename: "securities-transfer.xlsx", formats: [:xlsx], locals: { type: :transfer, title: t('securities.download.titles.transfer') }
  end

  def download_safekeep
    securities = JSON.parse(params[:securities]).collect! { |security| Security.from_hash(security) }
    populate_securities_table_data_view_variable(:safekeep, securities)
    render xlsx: 'securities', filename: "securities-safekeeping.xlsx", formats: [:xlsx], locals: { type: :safekeep, title: t('securities.download.titles.safekeep') }
  end

  def download_pledge
    securities = JSON.parse(params[:securities]).collect! { |security| Security.from_hash(security) }
    populate_securities_table_data_view_variable(:pledge, securities)
    render xlsx: 'securities', filename: "securities-pledge.xlsx", formats: [:xlsx], locals: { type: :pledge, title: t('securities.download.titles.pledge') }
  end

  def upload_securities
    uploaded_file = params[:file]
    content_type = uploaded_file.content_type
    type = params[:type].to_sym
    error = nil
    if ACCEPTED_UPLOAD_MIMETYPES.include?(content_type)
      securities = []
      begin
        spreadsheet = Roo::Spreadsheet.open(uploaded_file.path)
      rescue ArgumentError, IOError, Zip::ZipError => e
        error = I18n.t('securities.upload_errors.cannot_open')
      end
      unless error
        data_start_index = nil
        invalid_cusips = []
        spreadsheet.each do |row|
          if data_start_index
            cusip = row[data_start_index]
             security_hash = if type == :release
              {
                cusip: cusip,
                description: row[data_start_index + 1],
                original_par: (row[data_start_index + 2]),
                payment_amount: (row[data_start_index + 3])
              }
            elsif type == :transfer
              {
                cusip: cusip,
                description: row[data_start_index + 1],
                original_par: (row[data_start_index + 2])
              }
            elsif type == :pledge || type == :safekeep
              {
                cusip: cusip,
                original_par: (row[data_start_index + 1]),
                payment_amount: (row[data_start_index + 2]),
                custodian_name: (row[data_start_index + 3])
              }
            end
            next if security_hash.values.reject(&:blank?).empty?
            security_hash[:original_par] = security_hash[:original_par].try(:round, 7)
            security = Security.from_hash(security_hash)
            if security.valid?
              securities << security
            elsif security.errors.keys.include?(:cusip)
              invalid_cusips << security.cusip
            else
              error = prioritized_security_error(security)
              break
            end
          else
            row.each_with_index do |cell, i|
              regex = /\Acusip\z/i
              data_start_index = i if regex.match(cell.to_s)
            end
          end
        end
        if data_start_index && error.blank?
          cusip_error_count = invalid_cusips.length
          invalid_cusips.select!(&:present?)
          if invalid_cusips.present? && cusip_error_count == invalid_cusips.length
            # Invalid cusip error
            error = I18n.t('securities.upload_errors.invalid_cusips', cusips: invalid_cusips.join(', '))
          elsif cusip_error_count > 0
            # Blank cusip error
            error = I18n.t('activemodel.errors.models.security.blank')
          elsif securities.empty?
            error = I18n.t('securities.upload_errors.no_rows')
          else
            populate_securities_table_data_view_variable(type, securities)
            html = render_to_string(:upload_table, layout: false, locals: { type: type })
          end
        elsif error.blank?
          # No header row found (i.e. data_start_index)
          error = I18n.t('securities.upload_errors.generic')
        end
      end
    else
      error = I18n.t('securities.upload_errors.unsupported_mime_type')
    end
    render json: {html: html, form_data: (securities.to_json if securities && securities.present?), error: (simple_format(error) if error)}, content_type: request.format
  end

  # POST
  def submit_request
    type = params[:type].try(:to_sym)
    @securities_request = SecuritiesRequest.from_hash(params[:securities_request])
    @securities_request.member_id = current_member_id
    raise ArgumentError, "Unknown request type: #{type}" unless VALID_REQUEST_TYPES.include?(type)
    kind = @securities_request.kind
    raise ActionController::RoutingError.new("The type specified by the `/securities/submit` route does not match the @securities_request.kind. \nType: `#{type}`\nKind: `#{kind}`") unless type_matches_kind(type, kind)
    authorizer = @securities_request.is_collateral? ? policy(:security).authorize_collateral? : policy(:security).authorize_securities?
    submitter = policy(:security).submit?
    if @securities_request.valid? && submitter
      response = SecuritiesRequestService.new(current_member_id, request).submit_request_for_authorization(@securities_request, current_user, type) do |error|
        error = JSON.parse(error.http_body)['error']
        error['code'] = :base if error['code'] == 'unknown'
        @securities_request.errors.add(error['code'].to_sym, error['type'].to_sym)
      end
      @securities_request.errors.add(:base, :submission) unless response || @securities_request.errors.present?
    end
    has_errors = @securities_request.errors.present? || !submitter
    if authorizer
      @securid_status = securid_perform_check unless has_errors
      unless session_elevated?
        has_errors = true
      end
      unless has_errors
        if SecuritiesRequestService.new(current_member_id, request).authorize_request(@securities_request.request_id, current_user)
          InternalMailer.securities_request_authorized(@securities_request).deliver_now
        else
          @securities_request.errors.add(:base, :authorization)
          has_errors = true
        end
      end
    end
    if has_errors
      unless !@securid_status.nil? && @securid_status != RSA::SecurID::Session::AUTHENTICATED
        @error_message = prioritized_securities_request_error(@securities_request) || I18n.t('securities.internal_user_error')
      end
      populate_view_variables(type)
      populate_form_data_by_kind(kind)
      populate_contact_info_by_kind(kind)
      set_edit_title_by_kind(kind)
      case type
      when :release
        render :edit_release
      when :transfer
        render :edit_transfer
      when :pledge
        render :edit_pledge
      when :safekeep
        render :edit_safekeep
      end
    elsif authorizer
      populate_authorize_request_view_variables(kind)
      render :authorize_request
    else
      url = case kind
      when :pledge_release
        securities_release_pledge_success_url
      when :safekept_release
        securities_release_safekeep_success_url
      when :pledge_transfer
        securities_transfer_pledge_success_url
      when :safekept_transfer
        securities_transfer_safekeep_success_url
      when :pledge_intake
        securities_pledge_success_url
      when :safekept_intake
        securities_safekeep_success_url
      end
      redirect_to url
    end
  end

  def submit_request_success
    kind = params[:kind].to_sym
    case kind
    when :pledge_release
      @title = t('securities.success.titles.pledge_release')
      @email_subject = t('securities.success.email.subjects.pledge_release')
    when :safekept_release
      @title = t('securities.success.titles.safekept_release')
      @email_subject = t('securities.success.email.subjects.safekept_release')
    when :pledge_intake
      @title = t('securities.success.titles.pledge_intake')
      @email_subject = t('securities.success.email.subjects.pledge_intake')
    when :safekept_intake
      @title = t('securities.success.titles.safekept_intake')
      @email_subject = t('securities.success.email.subjects.safekept_intake')
    when :pledge_transfer, :safekept_transfer
      @title = t('securities.success.titles.transfer')
      @email_subject = t('securities.success.email.subjects.transfer')
    end

    role_needed_to_authorize = is_request_collateral?(kind) ? User::Roles::COLLATERAL_SIGNER : User::Roles::SECURITIES_SIGNER
    @authorized_user_data = []
    users = MembersService.new(request).signers_and_users(current_member_id) || []
    users.sort_by! { |user| [user[:surname] || '', user[:given_name] || ''] }
    users.each do |user|
      user[:roles].each do |role|
        if role == role_needed_to_authorize
          @authorized_user_data.push(user)
          break
        end
      end
    end
  end

  # DELETE
  def delete_request
    request_id = params[:request_id]
    response = SecuritiesRequestService.new(current_member_id, request).delete_request(request_id)
    status = response ? 200 : 404
    render json: {url: securities_requests_url, error_message: I18n.t('securities.release.delete_request.error_message')}, status: status
  end

  private

  def kind_to_description(kind)
    case kind
    when 'pledge_intake'
      t('securities.requests.form_descriptions.pledge')
    when 'pledge_release'
      t('securities.requests.form_descriptions.release_pledged')
    when 'safekept_release'
      t('securities.requests.form_descriptions.release_safekept')
    when 'safekept_intake'
      t('securities.requests.form_descriptions.safekept')
    when 'safekept_transfer'
      t('securities.requests.form_descriptions.transfer_safekept')
    when 'pledge_transfer'
      t('securities.requests.form_descriptions.transfer_pledged')
    else
      t('global.missing_value')
    end
  end

  def populate_securities_table_data_view_variable(type, securities=[])
    column_headings = []
    rows = []
    securities ||= []
    case type
    when :release
      column_headings = [ I18n.t('common_table_headings.cusip'),
        I18n.t('common_table_headings.description'),
        fhlb_add_unit_to_table_header(I18n.t('common_table_headings.original_par'), '$'),
        I18n.t('securities.release.settlement_amount', unit: fhlb_add_unit_to_table_header('', '$'), footnote_marker: fhlb_footnote_marker) ]
      rows = securities.collect do |security|
        { columns: [
          {value: security.cusip || t('global.missing_value')},
          {value: security.description || t('global.missing_value')},
          {value: security.original_par.to_f, type: :currency, options: {unit: ""}},
          {value: security.payment_amount.to_f, type: :currency, options: {unit: ""}}
        ] }
      end
      when :transfer
      column_headings = [ I18n.t('common_table_headings.cusip'),
        I18n.t('common_table_headings.description'),
        fhlb_add_unit_to_table_header(I18n.t('common_table_headings.original_par'), '$') ]
      rows = securities.collect do |security|
        { columns: [
          {value: security.cusip || t('global.missing_value')},
          {value: security.description || t('global.missing_value')},
          {value: security.original_par.to_f, type: :currency, options: {unit: ""}}
        ] }
      end
    when :pledge, :safekeep
      column_headings = [ I18n.t('common_table_headings.cusip'),
        fhlb_add_unit_to_table_header(I18n.t('common_table_headings.original_par'), '$'),
        I18n.t('securities.release.settlement_amount', unit: fhlb_add_unit_to_table_header('', '$'), footnote_marker: fhlb_footnote_marker),
        I18n.t('securities.safekeep.custodian_name', footnote_marker: fhlb_footnote_marker(1)) ]
      rows = securities.collect do |security|
        { columns: [
          {value: security.cusip || t('global.missing_value')},
          {value: security.original_par.to_f, type: :currency, options: {unit: ""}},
          {value: security.payment_amount.to_f, type: :currency, options: {unit: ""}},
          {value: security.custodian_name || t('global.missing_value')}
        ] }
      end
    end
    @securities_table_data = {
      column_headings: column_headings,
      rows: rows
    }
  end

  def populate_view_variables(type)
    @pledge_type_dropdown = [
      [t('securities.release.pledge_type.sbc'), SecuritiesRequest::PLEDGE_TO_VALUES[:sbc]],
      [t('securities.release.pledge_type.standard'), SecuritiesRequest::PLEDGE_TO_VALUES[:standard]]
    ]

    case type
    when :release
      @confirm_delete_text = t('securities.delete_request.titles.release')
      @download_path = securities_release_download_path
      @upload_path = securities_release_upload_path
    when :pledge
      @confirm_delete_text = t('securities.delete_request.titles.pledge')
      @download_path = securities_pledge_download_path
      @upload_path = securities_pledge_upload_path
    when :safekeep
      @confirm_delete_text = t('securities.delete_request.titles.safekeep')
      @download_path = securities_safekeep_download_path
      @upload_path = securities_safekeep_upload_path
    when :transfer
      @confirm_delete_text = t('securities.delete_request.titles.transfer')
      @download_path = securities_transfer_download_path
      @upload_path = securities_transfer_upload_path
    end

    @session_elevated = session_elevated?

    @securities_request ||= SecuritiesRequest.new
    @securities_request.securities = params[:securities] if params[:securities]
    next_business_day = CalendarService.new(request).find_next_business_day(Time.zone.today, 1.day)
    @securities_request.trade_date ||= next_business_day
    @securities_request.settlement_date ||= next_business_day

    populate_transaction_code_dropdown_variables(@securities_request)
    populate_settlement_type_dropdown_variables(@securities_request)
    populate_delivery_instructions_dropdown_variables(@securities_request)
    populate_securities_table_data_view_variable(type, @securities_request.securities)
    @date_restrictions = date_restrictions
  end

  def translated_dropdown_mapping(dropdown_hash)
    translated_dropdown_hash = {}
    dropdown_hash.each do |dropdown_key, value_hash|
      translated_value_hash = value_hash.clone
      translated_value_hash[:text] = I18n.t(translated_value_hash[:text])
      translated_dropdown_hash[dropdown_key] = translated_value_hash
    end
    translated_dropdown_hash
  end

  def populate_transaction_code_dropdown_variables(securities_request)
    transaction_dropdown_mapping = translated_dropdown_mapping(TRANSACTION_DROPDOWN_MAPPING)
    @transaction_code_dropdown = transaction_dropdown_mapping.values.collect(&:values)
    transaction_code = securities_request.transaction_code.try(:to_sym) || transaction_dropdown_mapping.keys.first
    @transaction_code_defaults = transaction_dropdown_mapping[transaction_code]
  end

  def populate_settlement_type_dropdown_variables(securities_request)
    settlement_type_dropdown_mapping = translated_dropdown_mapping(SETTLEMENT_TYPE_DROPDOWN_MAPPING)
    @settlement_type_dropdown = settlement_type_dropdown_mapping.values.collect(&:values)
    settlement_type = securities_request.settlement_type.try(:to_sym) || settlement_type_dropdown_mapping.keys.first
    @settlement_type_defaults = settlement_type_dropdown_mapping[settlement_type]
  end

  def populate_delivery_instructions_dropdown_variables(securities_request)
    delivery_instructions_dropdown_mapping = translated_dropdown_mapping(DELIVERY_INSTRUCTIONS_DROPDOWN_MAPPING)
    @delivery_instructions_dropdown = delivery_instructions_dropdown_mapping.values.collect(&:values)
    delivery_type = securities_request.delivery_type.try(:to_sym) || delivery_instructions_dropdown_mapping.keys.first
    @delivery_instructions_defaults = delivery_instructions_dropdown_mapping[delivery_type]
  end

  def date_restrictions
    today = Time.zone.today
    max_date = today + SecuritiesRequest::MAX_DATE_RESTRICTION
    holidays =  CalendarService.new(request).holidays(today, max_date).map{|date| date.iso8601}
    weekends = []
    date_iterator = today.clone
    while date_iterator <= max_date do
      weekends << date_iterator.iso8601 if (date_iterator.sunday? || date_iterator.saturday?)
      date_iterator += 1.day
    end
    {
      settlement_date: {
        min_date: today - (SecuritiesRequest::MIN_SETTLEMENT_DATE_RESTRICTION - 4.days),
        max_date: max_date,
        invalid_dates: holidays + weekends
      },
      trade_date: {
        min_date: today - SecuritiesRequest::MIN_TRADE_DATE_RESTRICTION,
        max_date: max_date,
        invalid_dates: holidays + weekends

      }
    }
  end

  def prioritized_securities_request_error(securities_request)
    securities_request_errors = securities_request.errors
    specific_error_keys = [:settlement_date, :securities, :base]
    if securities_request_errors.present?
      if securities_request_errors.key?(:member)
        return I18n.t('securities.release.edit.member_not_set_up_html', email: securities_services_email, phone: securities_services_phone_number).html_safe
      end
      general_error_keys = (securities_request_errors.keys - specific_error_keys)
      if general_error_keys.present?
        error_key = general_error_keys.first
        securities_request_errors[error_key].first
      elsif securities_request_errors.key?(:settlement_date)
        securities_request_errors[:settlement_date].first
      elsif securities_request_errors.key?(:securities)
        securities_request_errors[:securities].first
      else
        I18n.t('securities.release.edit.generic_error_html', phone_number: securities_services_phone_number, email: securities_services_email).html_safe
      end
    end
  end

  def prioritized_security_error(security)
    security_errors = security.errors
    if security_errors.present?
      error_keys = security_errors.keys
      prioritized_error_keys = error_keys - Security::CURRENCY_ATTRIBUTES
      error_key = prioritized_error_keys.present? ? prioritized_error_keys.first : error_keys.first
      security_errors[error_key].first
    end
  end

  def type_matches_kind(type, kind)
    case type
      when :release
        [:pledge_release, :safekept_release].include?(kind)
      when :transfer
        [:pledge_transfer, :safekept_transfer].include?(kind)
      when :safekeep
        kind == :safekept_intake
      when :pledge
        kind == :pledge_intake
    end
  end

  def populate_contact_info_by_kind(kind)
    @contact = if SecuritiesRequest::COLLATERAL_KINDS.include?(kind)
      {email_address: collateral_operations_email, mailto_text: t('contact.collateral_departments.collateral_operations.title'), phone_number: collateral_operations_phone_number}
    elsif SecuritiesRequest::SECURITIES_KINDS.include?(kind)
      {email_address: securities_services_email, mailto_text: t('contact.collateral_departments.securities_services.title'), phone_number: securities_services_phone_number}
    end
  end

  def populate_authorize_request_view_variables(kind)
    populate_contact_info_by_kind(kind)
    case kind
    when :pledge_release
      @title = t('securities.authorize.titles.pledge_release')
    when :safekept_release
      @title = t('securities.authorize.titles.safekept_release')
    when :pledge_intake
      @title = t('securities.authorize.titles.pledge_intake')
    when :safekept_intake
      @title = t('securities.authorize.titles.safekept_intake')
    when :pledge_transfer
      @title = t('securities.authorize.titles.transfer')
    when :safekept_transfer
      @title = t('securities.authorize.titles.transfer')
    end
  end

  def get_delivery_instructions(delivery_type)
    I18n.t(DELIVERY_INSTRUCTIONS_DROPDOWN_MAPPING[delivery_type.to_sym][:text])
  end

  def get_delivery_instruction_rows(securities_request)
    SecuritiesRequest::DELIVERY_INSTRUCTION_KEYS[securities_request.delivery_type].collect do |key|
      { columns: [ { value: SecuritiesRequest.human_attribute_name(key) },
                   { value: securities_request.public_send(key) } ] }
    end.unshift(
    {
      columns: [
        { value: t('securities.requests.view.delivery_instructions.delivery_method') },
        { value: get_delivery_instructions(securities_request.delivery_type) }
      ]
    })
  end

  def set_edit_title_by_kind(kind)
    @title = case kind.to_sym
    when :pledge_release, :safekept_release
      I18n.t('securities.release.title')
    when :pledge_intake
      I18n.t('securities.pledge.title')
    when :safekept_intake
      I18n.t('securities.safekeep.title')
    when :pledge_transfer
      I18n.t('securities.transfer.pledge.title')
    when :safekept_transfer
      I18n.t('securities.transfer.safekeep.title')
    end
  end

  def is_request_collateral?(kind)
    case kind.to_sym
    when *SecuritiesRequest::COLLATERAL_KINDS
      true
    when *SecuritiesRequest::SECURITIES_KINDS
      false
    else
      raise ArgumentError, "Unsupported securities request kind: #{kind}"
    end
  end

  def populate_form_data_by_kind(kind)
    @authorizer = is_request_collateral?(kind) ? policy(:security).authorize_collateral? : policy(:security).authorize_securities?
    @form_data = {
      url: securities_release_submit_path,
      submit_text: @authorizer ? t('securities.release.authorize') : t('securities.release.submit_authorization')
    }
  end
end
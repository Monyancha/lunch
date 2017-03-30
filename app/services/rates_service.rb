class RatesService < MAPIService
  COLLATERAL_TYPES = %i(standard sbc sta)
  CREDIT_TYPES = %i(frc vrc 1m_libor 3m_libor 6m_libor daily_prime embedded_cap sta)
  ARC_CREDIT_TYPES = %i(1m_libor 3m_libor 6m_libor daily_prime)
  HISTORICAL_FRC_TERM_MAPPINGS = {
    :'1m' => '1_month',
    :'2m' => '2_months',
    :'3m' => '3_months',
    :'6m' => '6_months',
    :'1y' => '1_year',
    :'2y' => '2_years',
    :'3y' => '3_years',
    :'5y' => '5_years',
    :'7y' => '7_years',
    :'10y' => '10_years',
    :'15y' => '15_years',
    :'20y' => '20_years',
    :'30y' => '30_years'
  }
  HISTORICAL_ARC_TERM_MAPPINGS = {
    :'1y' => '1_year',
    :'2y' => '2_years',
    :'3y' => '3_years',
    :'5y' => '5_years'
  }
  HISTORICAL_VRC_TERM_MAPPINGS = {
    :'1d' => '1_day'
  }
  CURRENT_CREDIT_TYPES = %i(vrc frc arc)
  CURRENT_VRC_CREDIT_TYPES = %i(advance_maturity overnight_fed_funds_benchmark basis_point_spread_to_benchmark advance_rate)
  CURRENT_FRC_CREDIT_TYPES = %i(advance_maturity treasury_benchmark_maturity nominal_yield_of_benchmark basis_point_spread_to_benchmark advance_rate)
  CURRENT_ARC_CREDIT_TYPES = %i(advance_maturity 1_month_libor 3_month_libor 6_month_libor prime)

  def overnight_vrc(days=30)
    begin
      response = @connection['rates/historic/overnight'].get params: {limit: days}
    rescue RestClient::Exception => e
      return warn(:overnight_vrc, "RestClient error: #{e.class.name}:#{e.http_code}", e)
    rescue Errno::ECONNREFUSED => e
      return warn(:overnight_vrc, "connection error: #{e.class.name}", e)
    end
    data ||= JSON.parse(response.body)
    data.collect! do |row|
      [Date.parse(row[0]), row[1].to_f]
    end
  end

  def rate(loan, term, type='Live', funding_date=nil) # type=Live|StartOfDay
    if data = get_hash(:rate, "rates/#{loan}/#{term}/#{type}", funding_date: funding_date)
      data[:rate] = data[:rate].to_f if data[:rate]
      data[:updated_at] = DateTime.parse(data[:updated_at]) if data[:updated_at]
      data
    end
  end

  def current_overnight_vrc
    if data = get_json(:current_overnight_vrc, 'rates/whole/overnight')
      {rate: data['rate'], updated_at: DateTime.parse(data['updated_at'])}
    end
  end

  def quick_advance_rates(member_id, funding_date=nil, maturity_date=nil)
    # we're not doing anything with member id right now, but presumably will need to use it at some point to check if
    # certain rates are available (e.g. member has enough collateral)
    raise ArgumentError, 'member_id must not be blank' if member_id.blank?
    iso8601_funding_date = funding_date.try(:to_date).try(:iso8601)
    iso8601_maturity_date = maturity_date.try(:to_date).try(:iso8601)
    Rails.cache.fetch(CacheConfiguration.key(:quick_advance_rates, member_id, iso8601_funding_date, iso8601_maturity_date), expires_in: CacheConfiguration.expiry(:quick_advance_rates)) do
      get_hash(:quick_advance_rates, "rates/summary", funding_date: iso8601_funding_date, maturity_date: iso8601_maturity_date, member_id: member_id)
    end
  end

  def current_price_indications(collateral_type, credit_type)
    collateral_type = collateral_type.to_sym
    credit_type = credit_type.to_sym

    return warn(:current_price_indications, "invalid credit type: #{credit_type}. Credit type must be one of these values: #{CURRENT_CREDIT_TYPES}", nil) unless CURRENT_CREDIT_TYPES.include?(credit_type)
    return warn(:current_price_indications, "invalid collateral type #{collateral_type}. Collateral type must be one of these values: #{COLLATERAL_TYPES}", nil) unless COLLATERAL_TYPES.include?(collateral_type)
    get_json(:current_price_indications, "rates/price_indications/current/#{credit_type}/#{collateral_type}")
  end

  def historical_price_indications(start_date, end_date, collateral_type, credit_type)
    start_date = start_date.to_date
    end_date = end_date.to_date
    collateral_type = collateral_type.to_sym
    credit_type = credit_type.to_sym

    return warn(:historical_price_indications, "invalid credit type: #{credit_type}. Credit type must be one of these values: #{CREDIT_TYPES}", nil) unless CREDIT_TYPES.include?(credit_type)
    return warn(:historical_price_indications, "invalid colateral type #{collateral_type}. Collateral type must be one of these values: #{COLLATERAL_TYPES}", nil) unless COLLATERAL_TYPES.include?(collateral_type)
    return warn(:historical_price_indications, "unsupported credit type: #{credit_type}. Currently, RatesService.historical_price_indications only accepts 'frc', 'vrc', '1m_libor', '3m_libor', '6m_libor' and daily_prime' as the credit_type arg.", nil) if credit_type == :embedded_cap
    # TODO remove the previous line once you support 'embedded_cap'

    fix_date(get_hash(:historical_price_indications, "rates/price_indication/historical/#{start_date}/#{end_date}/#{collateral_type}/#{credit_type}"), :date)
  end

end
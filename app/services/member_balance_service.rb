class MemberBalanceService

  def initialize(member_id)
    @connection = ::RestClient::Resource.new Rails.configuration.mapi.endpoint, headers: {:'Authorization' => "Token token=\"#{ENV['MAPI_SECRET_TOKEN']}\""}
    @db_connection = ActiveRecord::Base.establish_connection('cdb').connection if Rails.env == 'production'
    @member_id = member_id
    raise ArgumentError, 'member_id must not be blank' if member_id.blank?
  end

  def pledged_collateral
    begin
      response = @connection["member/#{@member_id}/balance/pledged_collateral"].get
    rescue RestClient::Exception => e
      Rails.logger.warn("MemberBalanceService.pledged_collateral encountered a RestClient error: #{e.class.name}:#{e.http_code}")
      return nil
    rescue Errno::ECONNREFUSED => e
      Rails.logger.warn("MemberBalanceService.pledged_collateral encountered a connection error: #{e.class.name}")
      return nil
    end
    data = JSON.parse(response.body).with_indifferent_access

    mortgage_mv = data[:mortgages].to_f
    agency_mv = data[:agency].to_f
    aaa_mv = data[:aaa].to_f
    aa_mv = data[:aa].to_f

    total_collateral = mortgage_mv + agency_mv + aaa_mv + aa_mv
    {
      mortgages: {absolute: mortgage_mv, percentage: mortgage_mv.fdiv(total_collateral)*100},
      agency: {absolute: agency_mv, percentage: agency_mv.fdiv(total_collateral)*100},
      aaa: {absolute: aaa_mv, percentage: aaa_mv.fdiv(total_collateral)*100},
      aa: {absolute: aa_mv, percentage: aa_mv.fdiv(total_collateral)*100}
    }.with_indifferent_access
  end

  def total_securities
    begin
      response = @connection["member/#{@member_id}/balance/total_securities"].get
    rescue RestClient::Exception => e
      Rails.logger.warn("MemberBalanceService.total_securities encountered a RestClient error: #{e.class.name}:#{e.http_code}")
      return nil
    rescue Errno::ECONNREFUSED => e
      Rails.logger.warn("MemberBalanceService.total_securities encountered a connection error: #{e.class.name}")
      return nil
    end
    data = JSON.parse(response.body).with_indifferent_access
    pledged_securities = data[:pledged_securities].to_i
    safekept_securities = data[:safekept_securities].to_i
    total_securities = pledged_securities + safekept_securities
    {
      pledged_securities: {absolute: pledged_securities, percentage: pledged_securities.fdiv(total_securities)*100},
      safekept_securities: {absolute: safekept_securities, percentage: safekept_securities.fdiv(total_securities)*100}
    }.with_indifferent_access
  end

  def effective_borrowing_capacity
    begin
      response = @connection["member/#{@member_id}/balance/effective_borrowing_capacity"].get
    rescue RestClient::Exception => e
      Rails.logger.warn("MemberBalanceService.total_securities encountered a RestClient error: #{e.class.name}:#{e.http_code}")
      return nil
    rescue Errno::ECONNREFUSED => e
      Rails.logger.warn("MemberBalanceService.total_securities encountered a connection error: #{e.class.name}")
      return nil
    end
    data = JSON.parse(response.body)

    total_capacity = data['total_capacity']
    unused_capacity= data['unused_capacity']
    used_capacity = total_capacity - unused_capacity
    
    {
        used_capacity: {absolute: used_capacity, percentage: used_capacity.fdiv(total_capacity)*100},
        unused_capacity: {absolute: unused_capacity, percentage: unused_capacity.fdiv(total_capacity)*100}
    }.with_indifferent_access
  end
end

class MAPIService

  def initialize(request)
    @request = request
    @connection = ::RestClient::Resource.new Rails.configuration.mapi.endpoint, headers: {:'Authorization' => "Token token=\"#{ENV['MAPI_SECRET_TOKEN']}\""}
    self.connection_request_uuid = request.try(:uuid)
    self.connection_user_id = request.try(:user_id)
  end

  def request
    @request
  end

  def connection_user_id=(user_id)
    @connection.headers[:'X-User-ID'] = user_id
    @connection_user = nil
  end

  def connection_request_uuid=(uuid)
    @connection.headers[:'X-Request-ID'] = uuid
  end

  def connection_request_uuid
    @connection.headers[:'X-Request-ID']
  end

  def connection_user_id
    @connection.headers[:'X-User-ID']
  end

  def connection_user
    @connection_user ||= User.find(connection_user_id)
  end
  
  def warn(name, msg, error, &error_handler)
    Rails.logger.warn("#{self.class.name}##{name} encountered a #{msg}")
    error_handler.call(name, msg, error) if error_handler
    nil
  end

  def ping
    begin
      response = @connection['healthy'].get
      JSON.parse(response.body)
    rescue Exception => e
      Rails.logger.error("MAPI PING failed: #{e.message}")
      false
    end
  end
  
  def get(name, endpoint, params={}, &error_handler)
    begin
      @connection[endpoint].get params: params
    rescue RestClient::Exception => e
      warn(name, "RestClient error: #{e.class.name}:#{e.http_code}", e, &error_handler)
    rescue Errno::ECONNREFUSED => e
      warn(name, "connection error: #{e.class.name}", e, &error_handler)
    end
  end

  def delete(name, endpoint, params={}, &error_handler)
    begin
      @connection[endpoint].delete params: params
    rescue RestClient::Exception => e
      warn(name, "RestClient error: #{e.class.name}:#{e.http_code}", e, &error_handler)
    rescue Errno::ECONNREFUSED => e
      warn(name, "connection error: #{e.class.name}", e, &error_handler)
    end
  end

  def post(name, endpoint, body, content_type = nil, &error_handler)
    begin
      if content_type
        @connection[endpoint].post body, {:content_type => content_type}
      else
        @connection[endpoint].post body
      end
    rescue RestClient::Exception => e
      warn(name, "RestClient error: #{e.class.name}:#{e.http_code}", e, &error_handler)
    rescue Errno::ECONNREFUSED => e
      warn(name, "connection error: #{e.class.name}", e, &error_handler)
    end
  end

  def put(name, endpoint, body, content_type = nil, &error_handler)
    begin
      if content_type
        @connection[endpoint].put body, {:content_type => content_type}
      else
        @connection[endpoint].put body
      end
    rescue RestClient::Exception => e
      warn(name, "RestClient error: #{e.class.name}:#{e.http_code}", e, &error_handler)
    rescue Errno::ECONNREFUSED => e
      warn(name, "connection error: #{e.class.name}", e, &error_handler)
    end
  end
  
  def parse(name, response, &error_handler)
    begin
      response.nil? ? nil : JSON.parse(response.body)
    rescue JSON::ParserError => e
      warn(name, "JSON parsing error: #{e}", e, &error_handler)
    end
  end
  
  def get_hash(name, endpoint, params={}, &error_handler)
    get_json(name, endpoint, params, &error_handler).try(:with_indifferent_access)
  end

  def get_hashes(name, endpoint, params={}, &error_handler)
    get_json(name, endpoint, params, &error_handler).collect { |result_hash| result_hash.try(:with_indifferent_access) }
  end
  
  def get_json(name, endpoint, params={}, &error_handler)
    parse(name, get(name, endpoint, params, &error_handler), &error_handler)
  end

  def delete_json(name, endpoint, params={}, &error_handler)
    parse(name, delete(name, endpoint, params, &error_handler), &error_handler)
  end

  def delete_hash(name, endpoint, params={}, &error_handler)
    delete_json(name, endpoint, params, &error_handler).try(:with_indifferent_access)
  end

  def post_hash(name, endpoint, body, &error_handler)
    post_json(name, endpoint, body, &error_handler).try(:with_indifferent_access)
  end

  def post_json(name, endpoint, body, &error_handler)
    parse(name, post(name, endpoint, body.to_json, 'application/json', &error_handler), &error_handler)
  end

  def put_hash(name, endpoint, body, &error_handler)
    put_json(name, endpoint, body, &error_handler).try(:with_indifferent_access)
  end

  def put_json(name, endpoint, body, &error_handler)
    parse(name, put(name, endpoint, body.to_json, 'application/json', &error_handler), &error_handler)
  end

  def fix_date(data, field=:as_of_date)
    fields = [field].flatten
    fields.each do |field|
      data[field] = data[field].to_date if data && data[field]
    end
    data
  end

  def parse_24_hour_time(time)
    time = time.to_s
    Time.zone.parse("#{Time.zone.today.to_s} #{time[0..1]}:#{time[2..3]}")
  end

end
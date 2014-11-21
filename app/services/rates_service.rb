class RatesService
  def initialize
    @connection = ActiveRecord::Base.establish_connection('cdb').connection if Rails.env == 'production'
  end

  def overnight_vrc(days=30)
    connection_string = <<SQL
    SELECT * FROM (SELECT TRX_EFFECTIVE_DATE, TRX_VALUE
    FROM IRDB.IRDB_TRANS T
    WHERE TRX_IR_CODE = 'FRADVN'
    AND (TRX_TERM_VALUE || TRX_TERM_UOM  = '1D' )
    ORDER BY TRX_EFFECTIVE_DATE DESC) WHERE ROWNUM <= #{days}
SQL

    data = if @connection
      cursor = @connection.execute(connection_string)
      rows = []
      while row = cursor.fetch()
        rows.push([row[0], row[1]])
      end
      rows
    else
      rows = JSON.parse(File.read(File.join(Rails.root, 'db', 'service_fakes', 'rates_overnight_vrc.json')))[0..(days - 1)]
      rows.collect do |row|
        [Date.parse(row[0]), row[1]]
      end
    end

    data.reverse.collect do |row|
      [row[0].to_date, row[1].to_f]
    end
  end

  def quick_advance_rates(member_id)
    @member_id = member_id
    raise ArgumentError, 'member_id must not be blank' if member_id.blank?

    # TODO: hit the proper MAPI endpoint, once it exists! In the meantime, always return the fake.
    # if @connection
    #   # hit the proper MAPI endpoint
    # else
    #   JSON.parse(File.read(File.join(Rails.root, 'db', 'service_fakes', 'quick_advance_rates.json'))).with_indifferent_access
    # end

    JSON.parse(File.read(File.join(Rails.root, 'db', 'service_fakes', 'quick_advance_rates.json'))).with_indifferent_access
  end

end
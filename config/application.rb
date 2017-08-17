require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module FhlbMember
  class Application < Rails::Application
    attr_accessor :flipper
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    config.time_zone = ENV['TIMEZONE'] || 'America/Los_Angeles'

    config.mapi = ActiveSupport::OrderedOptions.new
    config.mapi.endpoint = ENV['MAPI_ENDPOINT'] || 'http://localhost:3100/mapi'

    config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
    config.log_tags = [
      lambda { |request| "time=#{Time.zone.now.iso8601}" },
      lambda { |request| "request_id=#{request.uuid}" },
      lambda { |request| original_time = Time.zone.now.to_f; lambda { "delta=#{'%10.9f' % (Time.zone.now.to_f - original_time)}" } },
      lambda { |request| "server=#{request.host}" },
      lambda { |request| "session_id=#{request.session.id}" },
      lambda { |request| request.session[ApplicationController::SessionKeys::WARDEN_USER].nil? ? "user_id=NONE" : "user_id=#{request.session[ApplicationController::SessionKeys::WARDEN_USER][0][0]}" },
      lambda { |request| "remote_ip=#{request.remote_ip}" }
    ]

    require Rails.root.join('lib', 'fhlb_member', 'tagged_logging')
    config.logger = FhlbMember::TaggedLogging.new(ActiveSupport::Logger.new(Rails.root.join('log', "#{Rails.env}.log"), 'daily'))
    config.active_job.queue_adapter = :resque

    config.active_record.raise_in_transactional_callbacks = true

    # autoload files in the lib directory
    config.autoload_paths << Rails.root.join('lib') << Rails.root.join('api', 'jobs')

    # hide securid details
    config.filter_parameters << [:securid_pin, :securid_token, :securid_new_pin, :securid_confirm_pin]

    config.action_view.field_error_proc = Proc.new { |html_tag, instance|
      "#{html_tag}".html_safe
    }

    trusted_proxies = (ENV['TRUSTED_PROXIES'] || '').split.collect { |proxy| IPAddr.new(proxy) }
    config.action_dispatch.trusted_proxies = trusted_proxies + ActionDispatch::RemoteIp::TRUSTED_PROXIES

    config.action_dispatch.default_headers = {
      'Pragma' => 'no-cache',
      'Cache-Control' => 'no-store'
    }

    config.x.default_redis_session_store_ttl = 12.hours
    config.x.advance_request.key_expiration = 1.hour
    config.x.letter_of_credit_request.key_expiration = 1.hour
    config.x.early_shutoff_request.key_expiration = 1.hour

    # Configure our cache
    config.before_configuration do
      require Rails.root.join('lib', 'redis_helper')
      require Rails.root.join('app', 'models', 'cache_configuration')


      cache_namespace = ::CacheConfiguration::NAMESPACE + (ENV['DEPLOY_REVISION'].present? ? "-#{ENV['DEPLOY_REVISION']}" : '')
      ENV['CACHE_REDIS_URL'] ||= if ENV['REDIS_URL']
        ::RedisHelper.add_url_namespace(ENV['REDIS_URL'], cache_namespace)
      else
        "redis://localhost:6379/#{cache_namespace}"
      end

      config.cache_store = :redis_store,
                           ENV['CACHE_REDIS_URL'],
                           { namespace: ::RedisHelper.namespace_from_url(ENV['CACHE_REDIS_URL']),
                             expires_in: ::CacheConfiguration.expiry(:default) }
    end
  end
end

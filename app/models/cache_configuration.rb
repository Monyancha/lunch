unless defined?(CacheConfiguration)
  module CacheConfiguration
    NAMESPACE = 'cache'.freeze
    SEPARATOR = ':'.freeze
    CONFIG = {
      member_contacts: {
        key_prefix: 'contacts',
        expiry: 24.hours
      },
      member_data: {
        key_prefix: 'member_data',
        expiry: 24.hours
      },
      members_list: {
        key_prefix: 'members_list',
        expiry: 24.hours
      },
      user_metadata: {
        key_prefix: "users#{SEPARATOR}ldap#{SEPARATOR}metadata",
        expiry: 24.hours
      },
      user_roles: {
        key_prefix: "users#{SEPARATOR}ldap#{SEPARATOR}roles",
        expiry: 24.hours
      },
      user_groups: {
        key_prefix: "users#{SEPARATOR}ldap#{SEPARATOR}groups",
        expiry: 24.hours
      },
      overnight_vrc: {
        key_prefix: "rates#{SEPARATOR}overnight#{SEPARATOR}vrc",
        expiry: 30.seconds
      },
      account_overview: {
        key_prefix: 'account_overview',
        expiry: 20.minutes
      },
      calendar_holidays: {
        key_prefix: 'calendar_holidays',
        expiry: 24.hours
      },
      default: {
        key_prefix: 'default',
        expiry: 24.hours
      },
      quick_advance_rates: {
        key_prefix: "rates#{SEPARATOR}quick_advance",
        expiry: 30.seconds
      }
    }.freeze
    
    def self.key(context, *key_variables)
      [config(context)[:key_prefix], *key_variables].join(SEPARATOR)
    end

    def self.expiry(context)
      config(context)[:expiry]
    end

    def self.config(context)
      CONFIG.has_key?(context) ? CONFIG[context] : CONFIG[:default]
    end
  end
end
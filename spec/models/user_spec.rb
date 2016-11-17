require 'rails_helper'

RSpec.describe User, :type => :model do

  before do
    allow_any_instance_of(User).to receive(:ldap_entry).and_return(nil)
    allow_any_instance_of(User).to receive(:save_ldap_attributes).and_return(true)
  end

  it { is_expected.to callback(:save_ldap_attributes).after(:save) }
  it { is_expected.to callback(:destroy_ldap_entry).after(:destroy) }
  it { is_expected.to callback(:check_password_change).before(:save) }
  it { should validate_confirmation_of(:email).on(:update) }
  it { should validate_presence_of(:email).on(:update) }
  it { subject.email = 'foo' ; should validate_presence_of(:email_confirmation).on(:update) }
  it { should validate_presence_of(:given_name).on(:update) }
  it { should validate_presence_of(:surname).on(:update) }
  it { should validate_presence_of(:username).on(:update) }
  ['foo', 'foo@example', 'foo@example.1'].each do |value|
    it { should_not allow_value(value).for(:email) }
  end
  ['foo@example.com', 'foo@example.co', 'bar@example.org'].each do |value|
    it { should allow_value(value).for(:email) }
  end

  ['foo', 'abcdefghijklmnopqrstuvwxyz', 'fhlbsf1', 'FHLBSF2', '1234', '12345678901234567890'].each do |value|
    it { should_not allow_value(value).for(:username).on(:update) }
  end
  ['user', 'u123', 'u1234567890123456789'].each do |value|
    it { should allow_value(value).for(:username).on(:update) }
  end

  describe 'password changes surpress some validations' do
    before do
      subject.password = 'Fooo123!'
      subject.password_confirmation = subject.password
    end

    [:given_name, :surname, :email].each do |attr|
      it "does not validate the presence of `#{attr}`" do
        subject.send("#{attr}=", nil)
        expect(subject.valid?).to be(true)
      end
    end
  end

  describe 'virtual validators' do
    describe 'are disabled' do
      it 'does not validate `current_password`' do
        expect(subject.valid?).to be(true)
      end
    end
    describe 'are enabled' do
      before do
        subject.enable_virtual_validators!
      end
      it 'validates presence of `current_password`' do
        subject.valid?
        expect(subject.errors[:current_password]).to include(I18n.t('activerecord.errors.models.user.attributes.current_password.blank'))
      end
    end
  end

  describe 'validating passwords' do
    it { should validate_confirmation_of(:password) }
    it { should validate_length_of(:password).is_at_least(8) }
    describe 'acceptance criteria' do
      lower ='asdfsa'
      upper = 'KJSHDF'
      number = '7423894'
      symbol = '#$@!%*'

      [
        [['lowercase letter', 'symbol'], (lower + symbol)],
        [['lowercase letter', 'number'], (lower + number)],
        [['lowercase letter', 'uppercase letter'], (lower + upper)],
        [['uppercase letter', 'lowercase letter'], (upper + lower)],
        [['uppercase letter', 'number'], (upper + number)],
        [['uppercase letter', 'symbol'], (upper + symbol)],
        [['number', 'lowercase number'], (number + lower)],
        [['number', 'uppercase number'], (number + upper)],
        [['number', 'symbol'], (number + symbol)],
        [['symbol', 'lowercase letter'], (symbol + lower)],
        [['symbol', 'uppercase letter'], (symbol + upper)],
        [['symbol', 'number'], (symbol + number)]
      ].each do |criteria, password|
        it "rejects passwords that only include a #{criteria.first} and a #{criteria.last}" do
          should_not allow_value(password).for(:password)
        end
      end

      [
        [['lowercase letter', 'uppercase letter', 'number'], (lower + upper + number)],
        [['lowercase letter', 'uppercase letter', 'symbol'], (lower + upper + symbol)],
        [['lowercase letter', 'symbol', 'number'], (lower + symbol + number)],
        [['lowercase letter', 'symbol', 'uppercase letter'], (lower + symbol + upper)],
        [['lowercase letter', 'number', 'symbol'], (lower + number + symbol)],
        [['lowercase letter', 'number', 'uppercase letter'], (lower + number + upper)],
        [['uppercase letter', 'lowercase letter', 'number'], (upper + lower + number)],
        [['uppercase letter', 'lowercase letter', 'symbol'], (upper + lower + symbol)],
        [['uppercase letter', 'symbol', 'number'], (upper + symbol + number)],
        [['uppercase letter', 'symbol', 'lowercase letter'], (upper + symbol + lower)],
        [['uppercase letter', 'number', 'symbol'], (upper + number + symbol)],
        [['uppercase letter', 'number', 'lowercase letter'], (upper + number + lower)],
        [['number', 'lowercase letter', 'uppercase letter'], (number + lower + upper)],
        [['number', 'lowercase letter', 'symbol'], (number + lower + symbol)],
        [['number', 'symbol', 'uppercase letter'], (number + symbol + upper)],
        [['number', 'symbol', 'lowercase letter'], (number + symbol + lower)],
        [['number', 'uppercase letter', 'symbol'], (number + upper + symbol)],
        [['number', 'uppercase letter', 'lowercase letter'], (number + upper + lower)],
        [['symbol', 'lowercase letter', 'uppercase letter'], (symbol + lower + upper)],
        [['symbol', 'lowercase letter', 'number'], (symbol + lower + number)],
        [['symbol', 'number', 'uppercase letter'], (symbol + number + upper)],
        [['symbol', 'number', 'lowercase letter'], (symbol + number + lower)],
        [['symbol', 'uppercase letter', 'number'], (symbol + upper + number)],
        [['symbol', 'uppercase letter', 'lowercase letter'], (symbol + upper + lower)]
      ].each do |criteria, password|
        it "accepts passwords that include a #{criteria.first}, a #{criteria[1]} and a #{criteria.last}" do
          should allow_value(password).for(:password)
        end
      end
    end
    it { should allow_value(nil).for(:password) }
  end

  describe '`after_ldap_authentication` method' do
    let(:new_ldap_domain) { double('some domain name') }
    it 'updates its `ldap_domain` attribute with the argument provided' do
      expect(subject).to receive(:update_attribute).with(:ldap_domain, new_ldap_domain)
      subject.after_ldap_authentication(new_ldap_domain)
    end
    it 'does not update `ldap_domain` if it already has a value for that attribute' do
      subject.ldap_domain = 'some existing domain name'
      expect(subject).to_not receive(:update_attribute)
      subject.after_ldap_authentication(new_ldap_domain)
    end
  end

  describe '`roles` method' do
    let(:session_roles) { double('roles set from the session') }
    let(:call_method) { subject.roles }
    before do
      allow(subject).to receive(:roles_lookup).and_return(session_roles)
    end
    it 'does not look up the roles if the `roles` attribute already exists' do
      expect(subject).to_not receive(:roles_lookup)
      subject.roles = session_roles
      call_method
    end
    it 'returns its `roles` attribute if it has already been set' do
      subject.roles = session_roles
      expect(call_method).to eq(session_roles)
    end
    it 'passes the supplied request to `roles_lookup`' do
      request = double(ActionDispatch::Request)
      expect(subject).to receive(:roles_lookup).with(request)
      subject.roles(request)
    end
    it 'passes a dummy request to `roles_lookup` if none is provided' do
      expect(subject).to receive(:roles_lookup).with(kind_of(ActionDispatch::TestRequest))
      call_method
    end
    describe 'caching' do
      let(:cache_key) { double('A Cache Key') }
      let(:expiry) { double('An Expiry') }
      it 'returns the result of `roles_lookup` if `prefixed_roles_cache_key` is not present' do
        allow(subject).to receive(:prefixed_roles_cache_key).and_return(nil)
        expect(call_method).to be(session_roles)
      end
      describe 'if `prefixed_roles_cache_key` is present' do
        before do
          allow(subject).to receive(:prefixed_roles_cache_key).and_return(cache_key)
          allow(CacheConfiguration).to receive(:expiry).with(described_class::CACHE_CONTEXT_ROLES).and_return(expiry)
        end
        it 'calls `roles_lookup` if the cache misses' do
          allow(Rails.cache).to receive(:fetch).and_yield
          expect(subject).to receive(:roles_lookup)
          call_method
        end
        it 'looks up the roles in the cache' do
          expect(Rails.cache).to receive(:fetch).with(cache_key, include(expires_in: expiry))
          call_method
        end
        it 'returns the result of the cache lookup' do
          result = double('Some Roles')
          allow(Rails.cache).to receive(:fetch).and_return(result)
          expect(call_method).to be(result)
        end
      end
    end
  end

  {
    display_name: :displayname,
    email: :mail,
    surname: :sn,
    given_name: :givenname,
    deletion_reason: :deletereason
  }.each do |method, attribute|
    describe "`#{method}` method" do
      let(:attribute_value) { double('An LDAP Entry Attribute') }
      let(:ldap_entry) { double('LDAP Entry: User') }
      let(:call_method) { subject.send(method) }
      before do
        allow(subject).to receive(:ldap_entry).and_return(ldap_entry)
        allow(ldap_entry).to receive(:[]).with(attribute).and_return([attribute_value])
      end
      it 'fetches the backing LDAP entry' do
        expect(subject).to receive(:ldap_entry).and_return(ldap_entry)
        call_method
      end
      it "returns the `#{attribute}` of the backing LDAP entry" do
        expect(call_method).to eq(attribute_value)
      end
      it 'returns nil if no entry was found' do
        allow(subject).to receive(:ldap_entry).and_return(nil)
        expect(call_method).to be_nil
      end
      it 'returns the in-memory value if there is one' do
        subject.instance_variable_set(:"@#{method}", attribute_value)
        expect(call_method).to eq(attribute_value)
      end
      it 'returns the in-memory value if there is no ldap_entry' do
        allow(subject).to receive(:ldap_entry).and_return(nil)
        subject.instance_variable_set(:"@#{method}", attribute_value)
        expect(call_method).to eq(attribute_value)
      end
      it "returns nil if the entry had no value for `#{attribute}`" do
        allow(ldap_entry).to receive(:[]).with(attribute)
        expect(call_method).to be_nil
      end
    end
  end

  describe '`locked?` method' do
    let(:uac_attribute_value) { double('An LDAP Entry userAccountControl] Attribute', to_i: 512) }
    let(:lockouttime_attribute_value) { double('An LDAP Entry lockoutTime Attribute', to_i: 0) }
    let(:ldap_entry) { double('LDAP Entry: User') }
    let(:call_method) { subject.locked? }
    before do
      allow(subject).to receive(:ldap_entry).and_return(ldap_entry)
      allow(ldap_entry).to receive(:[]).with(:userAccountControl).and_return([uac_attribute_value])
      allow(ldap_entry).to receive(:[]).with(:lockoutTime).and_return([lockouttime_attribute_value])
    end
    it 'fetches the backing LDAP entry' do
      expect(subject).to receive(:ldap_entry).and_return(ldap_entry)
      call_method
    end
    it 'returns true if the backing LDAP entry has the LDAP_LOCK_BIT set' do
      allow(uac_attribute_value).to receive(:to_i).and_return(User::LDAP_LOCK_BIT)
      expect(call_method).to eq(true)
    end
    it 'returns true if the backing LDAP entry has the `lockoutTime` set to a non-zero value' do
      allow(lockouttime_attribute_value).to receive(:to_i).and_return(123)
      expect(call_method).to eq(true)
    end
    it 'returns false if no entry was found' do
      allow(subject).to receive(:ldap_entry).and_return(nil)
      expect(call_method).to eq(false)
    end
    it 'returns false if the LDAP_LOCK_BIT is not set and the `lockoutTime` is zero' do
      expect(call_method).to eq(false)
    end
  end

  describe '`lock!` method' do
    let(:call_method) { subject.lock! }
    let(:attribute_value) { double('An LDAP Entry Attribute', to_i: 512) }
    let(:ldap_entry) { double('LDAP Entry: User') }
    before do
      allow(subject).to receive(:reload_ldap_entry)
      allow(subject).to receive(:ldap_domain).and_return(double('An LDAP Domain'))
      allow(Devise::LDAP::Adapter).to receive(:set_ldap_param).and_return(false)
      allow(subject).to receive(:ldap_entry).and_return(ldap_entry)
      allow(ldap_entry).to receive(:[]).with(:userAccountControl).and_return([attribute_value])
    end
    it 'calls `reload_ldap_entry` before it reads the entry and after' do
      expect(subject).to receive(:reload_ldap_entry).ordered
      expect(subject).to receive(:ldap_entry).ordered
      expect(subject).to receive(:reload_ldap_entry).ordered
      call_method
    end
    it 'returns false if the LDAP entry could not be found' do
      allow(subject).to receive(:ldap_entry).and_return(nil)
      expect(call_method).to eq(false)
    end
    it 'calls `Devise::LDAP::Adapter.set_ldap_param` with the User::LDAP_LOCK_BIT set' do
      expect(Devise::LDAP::Adapter).to receive(:set_ldap_param).with(subject.username, :userAccountControl, (attribute_value.to_i | User::LDAP_LOCK_BIT).to_s, nil, subject.ldap_domain)
      call_method
    end
    it 'returns false on failure' do
      expect(call_method).to eq(false)
    end
    it 'returns true on success' do
      allow(Devise::LDAP::Adapter).to receive(:set_ldap_param).and_return(true)
      expect(call_method).to eq(true)
    end
  end

  describe '`unlock!` method' do
    let(:call_method) { subject.unlock! }
    let(:attribute_value) { double('An LDAP Entry Attribute', to_i: 514) }
    let(:ldap_entry) { double('LDAP Entry: User') }
    before do
      allow(subject).to receive(:reload_ldap_entry)
      allow(subject).to receive(:ldap_domain).and_return(double('An LDAP Domain'))
      allow(Devise::LDAP::Adapter).to receive(:set_ldap_params).and_return(false)
      allow(subject).to receive(:ldap_entry).and_return(ldap_entry)
      allow(ldap_entry).to receive(:[]).with(:userAccountControl).and_return([attribute_value])
    end
    it 'calls `reload_ldap_entry` before it reads the entry and after' do
      expect(subject).to receive(:reload_ldap_entry).ordered
      expect(subject).to receive(:ldap_entry).ordered
      expect(subject).to receive(:reload_ldap_entry).ordered
      call_method
    end
    it 'returns false if the LDAP entry could not be found' do
      allow(subject).to receive(:ldap_entry).and_return(nil)
      expect(call_method).to eq(false)
    end
    it 'calls `Devise::LDAP::Adapter.set_ldap_param` with the User::LDAP_LOCK_BIT cleared and the `lockoutTime` set to zero' do
      expect(Devise::LDAP::Adapter).to receive(:set_ldap_params).with(subject.username, match(userAccountControl: (attribute_value.to_i & (~User::LDAP_LOCK_BIT)).to_s, lockoutTime: 0.to_s), nil, subject.ldap_domain)
      call_method
    end
    it 'returns false on failure' do
      expect(call_method).to eq(false)
    end
    it 'returns true on success' do
      allow(Devise::LDAP::Adapter).to receive(:set_ldap_params).and_return(true)
      expect(call_method).to eq(true)
    end
  end

  describe '`reload` method' do
    let(:call_method) { subject.reload }
    before do
      allow_any_instance_of(described_class.superclass).to receive(:reload)
    end
    it 'calls `reload_ldap_entry`' do
      expect(subject).to receive(:reload_ldap_entry)
      call_method
    end
    it 'calls `reload_ldap_attributes`' do
      expect(subject).to receive(:reload_ldap_attributes)
      call_method
    end
    it 'calls `super` and returns the result' do
      result = double('A Result')
      allow_any_instance_of(described_class.superclass).to receive(:reload).and_return(result)
      expect(call_method).to be(result)
    end
  end

  describe '`email=` method' do
    let(:value) { 'foo@example.com' }
    let(:call_method) { subject.email = value }
    it 'changes the email attribute on the model' do
      call_method
      expect(subject.email).to eq(value)
    end
    it 'marks the email attribute as dirty if the value changed' do
      expect(subject).to receive(:attribute_will_change!).with('email')
      call_method
    end
    it 'does not mark the email attribute as dirty if the value was the same' do
      allow(subject).to receive(:email).and_return(value)
      expect(subject).to_not receive(:attribute_will_change!).with('email')
      call_method
    end
  end

  describe '`surname=` method' do
    let(:value) { 'Foo' }
    let(:call_method) { subject.surname = value }
    before do
      allow(subject).to receive(:attribute_will_change!)
    end
    it 'changes the surname attribute on the model' do
      call_method
      expect(subject.surname).to eq(value)
    end
    it 'marks the surname attribute as dirty if the value changed' do
      expect(subject).to receive(:attribute_will_change!).with('surname')
      call_method
    end
    it 'does not mark the surname attribute as dirty if the value was the same' do
      allow(subject).to receive(:surname).and_return(value)
      expect(subject).to_not receive(:attribute_will_change!).with('surname')
      call_method
    end
    it 'calls `rebuild_display_name`' do
      expect(subject).to receive(:rebuild_display_name)
      call_method
    end
  end

  describe '`given_name=` method' do
    let(:value) { 'Foo' }
    let(:call_method) { subject.given_name = value }
    before do
      allow(subject).to receive(:attribute_will_change!)
    end
    it 'changes the given_name attribute on the model' do
      call_method
      expect(subject.given_name).to eq(value)
    end
    it 'marks the given_name attribute as dirty if the value changed' do
      expect(subject).to receive(:attribute_will_change!).with('given_name')
      call_method
    end
    it 'does not mark the given_name attribute as dirty if the value was the same' do
      allow(subject).to receive(:given_name).and_return(value)
      expect(subject).to_not receive(:attribute_will_change!).with('given_name')
      call_method
    end
    it 'calls `rebuild_display_name`' do
      expect(subject).to receive(:rebuild_display_name)
      call_method
    end
  end

  describe '`deletion_reason=` method' do
    let(:value) { 'stole my stapler' }
    let(:call_method) { subject.deletion_reason = value }
    it 'changes the deletion_reason attribute on the model' do
      call_method
      expect(subject.deletion_reason).to eq(value)
    end
    it 'marks the deletion_reason attribute as dirty if the value changed' do
      expect(subject).to receive(:attribute_will_change!).with('deletion_reason')
      call_method
    end
    it 'does not mark the deletion_reason attribute as dirty if the value was the same' do
      allow(subject).to receive(:deletion_reason).and_return(value)
      expect(subject).to_not receive(:attribute_will_change!).with('deletion_reason')
      call_method
    end
  end

  describe '`email_changed?` method' do
    let(:call_method) { subject.email_changed? }
    it 'returns true if a new email value has been set' do
      subject.email = 'foo@example.com'
      expect(call_method).to be(true)
    end
    it 'returns false if there are no email changes' do
      expect(call_method).to be(false)
    end
    it 'ignores setting the email to the same value' do
      subject.email = subject.email
      expect(call_method).to be(false)
    end
  end

  describe '`surname_changed?` method' do
    let(:call_method) { subject.surname_changed? }
    it 'returns true if a new surname value has been set' do
      subject.surname = 'foo'
      expect(call_method).to be(true)
    end
    it 'returns false if there are no surname changes' do
      expect(call_method).to be(false)
    end
    it 'ignores setting the surname to the same value' do
      subject.surname = subject.surname
      expect(call_method).to be(false)
    end
  end

  describe '`given_name_changed?` method' do
    let(:call_method) { subject.given_name_changed? }
    it 'returns true if a new given_name value has been set' do
      subject.given_name = 'foo'
      expect(call_method).to be(true)
    end
    it 'returns false if there are no given_name changes' do
      expect(call_method).to be(false)
    end
    it 'ignores setting the given_name to the same value' do
      subject.given_name = subject.given_name
      expect(call_method).to be(false)
    end
  end

  describe '`display_name_changed?` method' do
    let(:call_method) { subject.display_name_changed? }
    it 'returns true if a new surname value has been set' do
      subject.surname = 'foo'
      expect(call_method).to be(true)
    end
    it 'returns true if a new given_name value has been set' do
      subject.given_name = 'foo'
      expect(call_method).to be(true)
    end
    it 'returns false if there are no changes' do
      expect(call_method).to be(false)
    end
    it 'ignores setting the surname to the same value' do
      subject.surname = subject.surname
      expect(call_method).to be(false)
    end
    it 'ignores setting the given_name to the same value' do
      subject.given_name = subject.given_name
      expect(call_method).to be(false)
    end
  end

  describe '`deletion_reason_changed?` method' do
    let(:call_method) { subject.deletion_reason_changed? }
    it 'returns true if a new reason value has been set' do
      subject.deletion_reason = 'they ate my lunch'
      expect(call_method).to be(true)
    end
    it 'returns false if there are no reason changes' do
      expect(call_method).to be(false)
    end
    it 'ignores setting the reason to the same value' do
      subject.deletion_reason = subject.deletion_reason
      expect(call_method).to be(false)
    end
  end

  describe '`cache_key=` method' do
    let(:new_key) { double('New Cache Key') }
    let(:old_key) { double('Old Cache Key') }
    let(:call_method) { subject.cache_key = new_key }
    it 'calls `clear_cache` if the cache key has changed' do
      subject.cache_key = old_key
      expect(subject).to receive(:clear_cache)
      call_method
    end
    it 'does not call `clear_cache` if the cache key is the same as the new key' do
      subject.cache_key = new_key
      expect(subject).to_not receive(:clear_cache)
      call_method
    end
    it 'sets `@cache_key` to the new key' do
      call_method
      expect(subject.cache_key).to be(new_key)
    end
    it 'calls `clear_cache` before setting the new cache key'
  end

  describe '`cache_key` method' do
    it 'returns the value stored for the cache_key' do
      value = double('A Value')
      subject.cache_key = value
      expect(subject.cache_key).to be(value)
    end
  end

  describe '`valid_ldap_authentication?` method' do
    let(:password) { double('A Password') }
    let(:strategy) { double('A Strategy', request: double('A Request')) }
    let(:call_method) { subject.valid_ldap_authentication?(password, strategy) }

    before do
      allow(subject).to receive(:ldap_domain_name)
    end

    it 'returns false if `Devise::LDAP::Adapter.valid_credentials?` returns false' do
      allow(Devise::LDAP::Adapter).to receive(:valid_credentials?).and_return(false)
      expect(call_method).to be(false)
    end
    describe 'if `Devise::LDAP::Adapter.valid_credentials?` returns true' do
      let(:policy) { double(InternalUserPolicy) }
      before do
        allow(Devise::LDAP::Adapter).to receive(:valid_credentials?).and_return(true)
        allow(InternalUserPolicy).to receive(:new).with(subject, strategy.request).and_return(policy)
      end
      it 'returns false if the user is not approved by the `InternalUserPolicy`' do
        allow(policy).to receive(:access?).and_return(false)
        expect(call_method).to be(false)
      end
      it 'returns true if the user is approved by the `InternalUserPolicy`' do
        allow(policy).to receive(:access?).and_return(true)
        expect(call_method).to be(true)
      end
    end
  end

  describe '`flipper_id` method' do
    let(:call_method) { subject.flipper_id }
    it 'returns the username' do
      expect(call_method).to eq(subject.username)
    end
  end

  describe 'add_extranet_user' do
    let(:member_id)    { double('member_id') }
    let(:creator)      { double('creator') }
    let(:username)     { double('username') }
    let(:downcased_username)     { double('downcased username') }
    let(:email)        { double('email') }
    let(:given_name)   { double('given_name') }
    let(:surname)      { double('surname') }
    let(:call_method)  { User.add_extranet_user(member_id, creator, username, email, given_name, surname) }

    before do
      allow(User).to receive(:create_ldap_user).with(member_id, creator, username, email, given_name, surname).and_return(true)
      allow(User).to receive(:find_or_create_by_with_retry)
      allow(username).to receive(:downcase).and_return(downcased_username)
    end

    it 'calls find_or_create_by_with_retry on success' do
      expect(User).to receive(:find_or_create_by_with_retry).with(username: downcased_username, ldap_domain: User::LDAP_EXTRANET_DOMAIN)
      call_method
    end

    it 'calls create_ldap_user on success' do
      expect(User).to receive(:create_ldap_user).with(member_id, creator, username, email, given_name, surname)
      call_method
    end

    it 'returns nil if add_groups fails' do
      allow(User).to receive(:create_ldap_user).with(member_id, creator, username, email, given_name, surname).and_return(false)
      expect(call_method).to be_nil
    end

    it 'downcases the username' do
      expect(username).to receive(:downcase)
      call_method
    end
  end

  describe 'create_ldap_user' do
    let(:member_id)    { rand(9999).to_s }
    let(:creator)      { SecureRandom.hex }
    let(:username)     { SecureRandom.hex }
    let(:email)        { "#{SecureRandom.hex}@#{SecureRandom.hex}.com" }
    let(:given_name)   { SecureRandom.hex }
    let(:surname)      { SecureRandom.hex }
    let(:dn) { "CN=#{username},#{User::LDAP_EXTRANET_EBIZ_USERS_DN}" }
    let(:attributes) do
      {
        CreatedBy: creator,
        description: "Created by #{creator}",
        sAMAccountName: username,
        mail: email,
        User::LDAP_PASSWORD_EXPIRATION_ATTRIBUTE => 'true',
        givenname: given_name,
        sn: surname,
        displayname: "#{given_name} #{surname}",
        objectClass: %w(user top person)
      }
    end
    let(:groups) { [User::AD_GROUP_NAME_PREFIX + member_id, User::ROLES_TO_LDAP_GROUPS[User::Roles::MEMBER_USER]] }
    let(:group1_dn) { double('group1.dn') }
    let(:group2_dn) { double('group2.dn') }
    let(:group1_dn_results){ [double('group1_dn_result', dn: group1_dn)] }
    let(:group2_dn_results){ [double('group2_dn_result', dn: group2_dn)] }
    let(:call_method)  { User::create_ldap_user( member_id, creator, username, email, given_name, surname ) }
    let(:ldap_admin)   { double('ldap_admin') }
    let(:ldap)         { double('ldap') }
    before do
      allow(Devise::LDAP::Connection).to receive(:admin).with(User::LDAP_EXTRANET_DOMAIN).and_return(ldap_admin)
      allow(ldap_admin).to receive(:open).and_yield(ldap)
      allow(ldap).to receive(:search).with(filter: "(&(CN=#{groups[0]})(objectClass=group))").and_return(group1_dn_results)
      allow(ldap).to receive(:search).with(filter: "(&(CN=#{groups[1]})(objectClass=group))").and_return(group2_dn_results)
      allow(ldap).to receive(:add_attribute).with(group1_dn, 'member', dn).and_return(true)
      allow(ldap).to receive(:add_attribute).with(group2_dn, 'member', dn).and_return(true)
      allow(ldap).to receive(:add).with(dn: dn, attributes: attributes).and_return(true)
    end

    it 'searches with group1 filter' do
      expect(ldap).to receive(:search).with(filter: "(&(CN=#{groups[0]})(objectClass=group))")
      call_method
    end

    it 'searches with group2 filter' do
      expect(ldap).to receive(:search).with(filter: "(&(CN=#{groups[1]})(objectClass=group))")
      call_method
    end

    it 'calls add_attribute with group1_dn' do
      expect(ldap).to receive(:add_attribute).with(group1_dn, 'member', dn)
      call_method
    end

    it 'calls add_attribute with group2_dn' do
      expect(ldap).to receive(:add_attribute).with(group2_dn, 'member', dn)
      call_method
    end

    it 'calls add with dn and attributes' do
      expect(ldap).to receive(:add).with(dn: dn, attributes: attributes)
      call_method
    end

    it 'returns true on success' do
      expect(call_method).to be_truthy
    end

    it 'returns false if add fails' do
      allow(ldap).to receive(:add).with(dn: dn, attributes: attributes).and_return(false)
      expect(call_method).to be_falsey
    end

    it 'returns false if search for #{groups[0]} fails' do
      allow(ldap).to receive(:search).with(filter: "(&(CN=#{groups[0]})(objectClass=group))").and_return([])
      expect(call_method).to be_falsey
    end

    it 'returns false if search for #{groups[1]} fails' do
      allow(ldap).to receive(:search).with(filter: "(&(CN=#{groups[1]})(objectClass=group))").and_return([])
      expect(call_method).to be_falsey
    end

    it 'returns false if add_attribute fails for first dn' do
      allow(ldap).to receive(:add_attribute).with(group1_dn, 'member', dn).and_return(false)
      expect(call_method).to be_falsey
    end

    it 'returns false if add_attribute fails for second dn' do
      allow(ldap).to receive(:add_attribute).with(group2_dn, 'member', dn).and_return(false)
      expect(call_method).to be_falsey
    end
  end

  describe '`member` method' do
    let(:call_method) { subject.member }
    let(:member_id) { double('A Member ID') }
    before do
      allow(subject).to receive(:member_id).and_return(member_id)
    end
    it 'returns a Member instance for the users affiliated member' do
      expect(call_method.id).to eq(member_id)
    end
    it 'caches the member instance' do
      member = call_method
      expect(call_method).to be(member)
    end
    it 'returns nil if the user has no member affiliated with it' do
      allow(subject).to receive(:member_id).and_return(nil)
      expect(call_method).to be_nil
    end
  end

  describe '`new_announcements_count`' do
    let(:count) { double('number of CorporateCommunications') }
    let(:now) { DateTime.new(2016,2,10) }
    let(:last_viewed) { DateTime.new(2016,2,8) }
    let(:call_method) { subject.new_announcements_count }
    it 'returns the count of all CorporateCommunications if there is no `last_viewed_announcements_at` for the user' do
      allow(CorporateCommunication).to receive(:count).and_return(count)
      expect(call_method).to eq(count)
    end
    it 'returns the count of all CorporateCommuncations with a `date_sent` value greater than or equal to the user\'s `last_viewed_announcements_at` value' do
      allow(Time.zone).to receive(:now).and_return(now)
      subject.last_viewed_announcements_at = last_viewed
      allow(CorporateCommunication).to receive(:where).with('date_sent >= ?', last_viewed).and_return(double('relational array', count: count))
      expect(call_method).to eq(count)
    end
  end

  describe 'announcements_viewed!' do
    let(:now) { double('now') }
    let(:call_method) { subject.announcements_viewed! }
    it 'sets the user\'s `last_viewed_announcements_at` attribute to now' do
      allow(Time.zone).to receive(:now).and_return(now)
      expect(subject).to receive(:update_attribute).with(:last_viewed_announcements_at, now)
      call_method
    end
  end

  describe '`ldap_entry` method' do
    let(:call_method) { subject.ldap_entry }
    let(:ldif_entry) { double('LDIF Entry Representation') }
    let(:entry) { double(Net::LDAP::Entry, to_ldif: ldif_entry) }

    before do
      allow_any_instance_of(User).to receive(:ldap_entry).and_call_original
      allow(Devise::LDAP::Adapter).to receive(:get_ldap_entry).and_return(nil)
    end

    describe 'when `prefixed_cache_key` is `nil`' do
      it 'returns the previous value if called a second time' do
        value = call_method
        expect(call_method).to be(value)
      end
      it 'returns the results of calling `super`' do
        allow(Devise::LDAP::Adapter).to receive(:get_ldap_entry).and_return(entry)
        expect(call_method).to be(entry)
      end
    end
    describe 'when `prefixed_cache_key` is present' do
      let(:cache_key) { double('A Cache Key') }
      let(:expiry) { double('An Expiry') }
      before do
        allow(subject).to receive(:prefixed_cache_key).and_return(cache_key)
        allow(CacheConfiguration).to receive(:expiry).with(described_class::CACHE_CONTEXT_METADATA).and_return(expiry)
        allow(Rails.cache).to receive(:fetch).and_yield
      end
      it 'returns the previous value if called a second time' do
        value = call_method
        expect(call_method).to be(value)
      end
      it 'tries to fetch a cached entry' do
        expect(Rails.cache).to receive(:fetch).with(cache_key, include(expires_in: expiry))
        call_method
      end
      it 'calls `super` on a cache miss' do
        expect(Devise::LDAP::Adapter).to receive(:get_ldap_entry)
        call_method
      end
      describe 'and `super` returns an entry' do
        before do
          allow(Devise::LDAP::Adapter).to receive(:get_ldap_entry).and_return(entry)
        end
        it 'converts the cache miss entry to LDIF format' do
          expect(entry).to receive(:to_ldif).and_return(nil)
          call_method
        end
        it 'converts the LDIF entry into a `Net::LDAP::Entry`' do
          expect(Net::LDAP::Entry).to receive(:from_single_ldif_string).with(ldif_entry)
          call_method
        end
        it 'returns the `Net::LDAP::Entry` built from the cache' do
          new_entry = double(Net::LDAP::Entry)
          allow(Net::LDAP::Entry).to receive(:from_single_ldif_string).with(ldif_entry).and_return(new_entry)
          expect(call_method).to be(new_entry)
        end
      end
      it 'does not convert the LDIF entry if its nil' do
        expect(Net::LDAP::Entry).to_not receive(:from_single_ldif_string)
        call_method
      end
      it 'does not raise an error if `super` returns nil' do
        expect{call_method}.to_not raise_error
      end
    end
  end

  describe '`clear_cache` method' do
    [:prefixed_cache_key, :prefixed_roles_cache_key, :prefixed_groups_cache_key].each do |key_method|
      let(:call_method) { subject.clear_cache }
      it "deletes the `#{key_method}` cache entry" do
        key = double('Cache Key')
        allow(subject).to receive(key_method).and_return(key)
        expect(Rails.cache).to receive(:delete).with(key)
        call_method
      end
      it "does not delete `#{key_method}` cache entry if `#{key_method}` returns `nil`" do
        allow(subject).to receive(key_method).and_return(nil)
        expect(Rails.cache).to_not receive(:delete)
        call_method
      end
    end
  end

  describe '`timeout_in` method' do
    let(:call_method) { subject.timeout_in }
    let(:policy) { instance_double(InternalUserPolicy, extended_session?: true ) }

    before do
      allow(InternalUserPolicy).to receive(:new).and_return(policy)
    end

    it 'constructs an InternalUserPolicy with this user and no record' do
      expect(InternalUserPolicy).to receive(:new).with(subject, nil)
      call_method
    end
    it 'checks if the user is allowed an extended session using the InternalUserPolicy' do
      expect(policy).to receive(:extended_session?)
      call_method
    end
    it 'returns the `Devise.timeout_in` if the user is not allowed an extended session' do
      allow(policy).to receive(:extended_session?).and_return(false)
      expect(call_method).to be(Devise.timeout_in)
    end
    it 'returns 10 hours if the user is allowed an extended session' do
      allow(policy).to receive(:extended_session?).and_return(true)
      expect(call_method).to eq(10.hours)
    end
  end

  {
    prefixed_cache_key: described_class::CACHE_CONTEXT_METADATA,
    prefixed_roles_cache_key: described_class::CACHE_CONTEXT_ROLES,
    prefixed_groups_cache_key: described_class::CACHE_CONTEXT_GROUPS
  }.each do |method, context|
    let(:call_method) { subject.send(method) }
    describe "`#{method}` protected method" do
      it 'returns the config from `CacheConfiguration`'
      it 'returns `nil` if `cache_key` is `nil`' do
        expect(call_method).to be_nil
      end
    end
  end

  describe '`reload_ldap_entry` protected method' do
    let(:call_method) { subject.send(:reload_ldap_entry) }
    it 'calls `clear_cache`' do
      expect(subject).to receive(:clear_cache)
      call_method
    end
    it 'nils out the `@ldap_entry` instance variable' do
      subject.instance_variable_set(:@ldap_entry, double('LDAP Entry: User'))
      call_method
      expect(subject.instance_variable_get(:@ldap_entry)).to be_nil
    end
  end

  describe '`save_ldap_attributes` protected method' do
    let(:call_method) { subject.send(:save_ldap_attributes) }
    before do
      allow_any_instance_of(User).to receive(:save_ldap_attributes).and_call_original
    end
    it 'does not save if there are no changes' do
      expect(Devise::LDAP::Adapter).to_not receive(:set_ldap_params)
      call_method
    end
    describe 'with LDAP attribute changes' do
      let(:email) { 'foo@example.com' }
      let(:username) { double('Username') }
      let(:ldap_domain) { double('LDAP Domain') }
      before do
        subject.email = email
        allow(subject).to receive(:username).and_return(username)
        allow(subject).to receive(:ldap_domain).and_return(ldap_domain)
        allow(Devise::LDAP::Adapter).to receive(:set_ldap_params).and_return(true)
      end
      it 'saves the changes' do
        expect(Devise::LDAP::Adapter).to receive(:set_ldap_params).with(username, {mail: email}, nil, ldap_domain)
        call_method
      end
      it 'calls `reload_ldap_entry`' do
        expect(subject).to receive(:reload_ldap_entry)
        call_method
      end
      it 'rollbacks if save fails' do
        allow(Devise::LDAP::Adapter).to receive(:set_ldap_params).and_return(false)
        expect{call_method}.to raise_error(ActiveRecord::Rollback)
      end
      it 'calls `reload_ldap_attributes` if the save succeeds' do
        allow(Devise::LDAP::Adapter).to receive(:set_ldap_params).and_return(true)
        expect(subject).to receive(:reload_ldap_attributes)
        call_method
      end
    end
  end

  describe '`rebuild_display_name` protected method' do
    let(:call_method) { subject.send(:rebuild_display_name) }
    let(:given_name) { SecureRandom.hex }
    let(:surname) { SecureRandom.hex }
    before do
      allow(subject).to receive(:given_name).and_return(given_name)
      allow(subject).to receive(:surname).and_return(surname)
    end
    it 'rebuilds the display_name' do
      call_method
      expect(subject.display_name).to eq("#{given_name} #{surname}")
    end
    it 'marks the display_name as changed if it changed' do
      expect(subject).to receive(:attribute_will_change!).with('display_name')
      call_method
    end
    it 'does not mark the display_name as changed if it matches the current display_name' do
      allow(subject).to receive(:display_name).and_return("#{given_name} #{surname}")
      expect(subject).to_not receive(:attribute_will_change!).with('display_name')
      call_method
    end
  end

  describe '`reload_ldap_attributes` protected method' do
    let(:call_method) { subject.send(:reload_ldap_attributes) }
    it 'nils out `@email`' do
      subject.instance_variable_set(:@email, 'foo')
      call_method
      expect(subject.instance_variable_get(:@email)).to be_nil
    end
    it 'nils out `@given_name`' do
      subject.instance_variable_set(:@given_name, 'foo')
      call_method
      expect(subject.instance_variable_get(:@given_name)).to be_nil
    end
    it 'nils out `@surname`' do
      subject.instance_variable_set(:@surname, 'foo')
      call_method
      expect(subject.instance_variable_get(:@surname)).to be_nil
    end
    it 'nils out `@display_name`' do
      subject.instance_variable_set(:@display_name, 'foo')
      call_method
      expect(subject.instance_variable_get(:@display_name)).to be_nil
    end
  end

  describe '`create` class method' do
    it 'calls `super` if not passed a Net::LDAP::Entry' do
      arguments = double('Some Arguments')
      expect(described_class.superclass).to receive(:create).with(arguments)
      described_class.create(arguments)
    end
    describe 'passing a Net::LDAP::Entry' do
      let(:samaccountname) { double('An Account Username') }
      let(:ldap_domain) { double('An LDAP Domain') }
      let(:dn) { double('A DN', end_with?: true) }
      let(:ldap_entry) { double('LDAP Entry: User', is_a?: true, dn: dn) }
      let(:call_method) { described_class.create(ldap_entry) }
      before do
        allow(ldap_entry).to receive(:[]).with(:objectclass).and_return(['user', 'foo'])
        allow(ldap_entry).to receive(:[]).with(:samaccountname).and_return([samaccountname])
        allow(Devise::LDAP::Adapter).to receive(:get_ldap_domain_from_dn).with(dn).and_return(ldap_domain)
      end
      it 'raises an error if the Entry doesn\'t have an `objectclass` of `user`' do
        allow(ldap_entry).to receive(:[]).with(:objectclass).and_return(['foo'])
        expect{call_method}.to raise_error(/Net::LDAP::Entry must have an objectClass of `user`/i)
      end
      it 'calls `super` with a `username` of the Entry\'s `samaccountname`' do
        expect(described_class.superclass).to receive(:create).with(hash_including(username: samaccountname))
        call_method
      end
      it 'calls `super` with an `ldap_domain` of where the Entry was found' do
        expect(described_class.superclass).to receive(:create).with(hash_including(ldap_domain: ldap_domain))
        call_method
      end
      it 'calls `Devise::LDAP::Adapter.get_ldap_domain_from_dn` to find the `ldap_domain`' do
        expect(Devise::LDAP::Adapter).to receive(:get_ldap_domain_from_dn).with(dn).and_return(ldap_domain)
        call_method
      end
      it 'sets the `@ldap_entry` on the new User instance' do
        expect(call_method.instance_variable_get(:@ldap_entry)).to be(ldap_entry)
      end
    end
  end

  describe '`find_or_create_by_ldap_entry` class method' do
    let(:samaccountname) { instance_double(String) }
    let(:downcased_samaccountname) { instance_double(String) }
    let(:ldap_domain) { double('An LDAP Domain') }
    let(:dn) { double('A DN', end_with?: true) }
    let(:ldap_entry) { double('LDAP Entry: User', is_a?: true, dn: dn) }
    let(:call_method) { described_class.find_or_create_by_ldap_entry(ldap_entry) }
    let(:user) { double(described_class) }
    before do
      allow(ldap_entry).to receive(:[]).with(:samaccountname).and_return([samaccountname])
      allow(Devise::LDAP::Adapter).to receive(:get_ldap_domain_from_dn).with(dn).and_return(ldap_domain)
      allow(described_class).to receive(:find_or_create_by).and_return(user)
      allow(samaccountname).to receive(:downcase).and_return(downcased_samaccountname)
    end
    it 'calls `find_or_create_by_with_retry` with a `username` of the entries `samaccountname`' do
      expect(described_class).to receive(:find_or_create_by_with_retry).with(hash_including(username: downcased_samaccountname))
      call_method
    end
    it 'calls `find_or_create_by_with_retry` with a `ldap_domain` of where the Entry was found' do
      expect(described_class).to receive(:find_or_create_by_with_retry).with(hash_including(ldap_domain: ldap_domain))
      call_method
    end
    it 'calls `Devise::LDAP::Adapter.get_ldap_domain_from_dn` to find the `ldap_domain`' do
      expect(Devise::LDAP::Adapter).to receive(:get_ldap_domain_from_dn).with(dn).and_return(ldap_domain)
      call_method
    end
    it 'downcases the accout name' do
      expect(samaccountname).to receive(:downcase)
      call_method
    end
  end

  describe '`find_or_create_if_valid_login` class method' do
    let(:attributes) { double('Some Attributes', :[] => nil) }
    let(:call_method) { described_class.find_or_create_if_valid_login(attributes) }
    let(:user) { double(described_class) }
    let(:username)  { instance_double(String) }
    let(:downcased_username) { instance_double(String) }
    let(:ldap_domain) { double('An LDAP Domain') }

    before do
      allow(Devise::LDAP::Adapter).to receive(:get_ldap_domain)
      allow(described_class).to receive(:find_or_create_by).and_return(user)
      allow(username).to receive(:downcase).and_return(downcased_username)
    end

    it 'calls `find_by` passing in the supplied attributes' do
      expect(described_class).to receive(:find_by).with(attributes)
      call_method
    end
    describe 'if a User is found' do
      before do
        allow(described_class).to receive(:find_by).and_return(user)
      end
      it 'returns the found user' do
        expect(call_method).to be(user)
      end
    end
    describe 'if a User is not found' do
      before do
        allow(described_class).to receive(:find_by).and_return(nil)
        allow(attributes).to receive(:[]).with(:username).and_return(username)
        allow(Devise::LDAP::Adapter).to receive(:get_ldap_domain).and_return(ldap_domain)
      end
      it 'downcases the username' do
        expect(username).to receive(:downcase)
        call_method
      end
      it 'looks up the LDAP domain of the username' do
        expect(Devise::LDAP::Adapter).to receive(:get_ldap_domain).with(downcased_username)
        call_method
      end
      it 'returns nil if no LDAP domain was found for the username' do
        allow(Devise::LDAP::Adapter).to receive(:get_ldap_domain).and_return(nil)
        expect(call_method).to be_nil
      end
      describe 'if an LDAP domain is found for the username' do
        it 'calls `find_or_create_by_with_retry` with the username and LDAP domain' do
          expect(described_class).to receive(:find_or_create_by_with_retry).with({username: downcased_username, ldap_domain: ldap_domain})
          call_method
        end
        it 'returns the result of the `find_or_create_by_with_retry` call' do
          allow(described_class).to receive(:find_or_create_by_with_retry).and_return(user)
          expect(call_method).to be(user)
        end
      end
    end
  end

  describe '`find_or_create_by_with_retry` class method' do
    let(:arguments) { [double(Object), double(Object), double(Object)] }
    let(:call_method) { described_class.find_or_create_by_with_retry(*arguments) }
    let(:user) { double(described_class) }

    before do
      allow(described_class).to receive(:find_or_create_by) do |*args, &block|
        block.call if block
      end
    end

    it 'calls `find_or_create_by` with the supplied arguments' do
      expect(described_class).to receive(:find_or_create_by).with(*arguments)
      call_method
    end
    it 'calls `find_or_create_by` with the supplied block' do
      expect{ |b| described_class.find_or_create_by_with_retry(*arguments, &b) }.to yield_control
    end
    it 'returns the result of `find_or_create_by`' do
      allow(described_class).to receive(:find_or_create_by).and_return(user)
      expect(call_method).to be(user)
    end
    context 'retrying on ActiveRecord::RecordNotUnique' do
      before do
        allow(described_class).to receive(:find_or_create_by).and_raise(ActiveRecord::RecordNotUnique.new('error'))
      end
      it 'retries the `find_or_create_by` twice on `ActiveRecord::RecordNotUnique`' do
        expect(described_class).to receive(:find_or_create_by).twice
        call_method rescue ActiveRecord::RecordNotUnique
      end
      it 'raises `ActiveRecord::RecordNotUnique` if all retries fail' do
        expect{call_method}.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe '`extranet_logins` class method' do
    let!(:user_intranet_nosignin) { FactoryGirl.create(:user, username: 'user_in_nosignin', ldap_domain: 'intranet') }
    let!(:user_intranet_signin) { FactoryGirl.create(:user, username: 'user_in_signin', ldap_domain: 'intranet', sign_in_count: rand(1..10)) }
    let!(:user_extranet_nosignin) { FactoryGirl.create(:user, username: 'user_ex_nosignin', ldap_domain: 'extranet') }
    let!(:user_extranet_signin) { FactoryGirl.create(:user, username: 'user_ex_signin', ldap_domain: 'extranet', sign_in_count: rand(1..10)) }
    let(:call_method) { described_class.extranet_logins }

    it 'returns extranet users who have at least one login' do
      expect(call_method).to include(user_extranet_signin)
    end
    it 'does not return users who are not in the extranet domain' do
      expect(call_method).to_not include(user_intranet_nosignin, user_intranet_signin)
    end
    it 'does not return users who are in the extranet domain but have never signed in' do
      expect(call_method).to_not include(user_extranet_nosignin)
    end

  end

  describe '`member_id` method' do
    let(:call_method) { subject.member_id }
    let(:member_id_instance_variable) { double('@member_id') }
    let(:bank_id) { rand(9999).to_s }
    let(:ldap_bank) { double('LDAP entry for bank', cn: ["FHLB#{bank_id}"], objectClass: ['group'])}
    let(:ldap_group_object) { double('Some LDAP entry for a non-bank group', cn: ["FOO#{bank_id}"], objectClass: ['group'])}
    let(:ldap_other_object) { double('LDAP entry for a non-group object with a valid bank CN', cn: ["FHLB#{bank_id}"], objectClass: ['top'])}
    let(:ldap_groups_array) { [ldap_group_object, ldap_other_object, ldap_bank] }
    before do
      allow(subject).to receive(:ldap_groups).and_return(ldap_groups_array)
    end
    it 'returns the @member_id attribute if it exists' do
      subject.instance_variable_set(:@member_id, member_id_instance_variable)
      expect(call_method).to eq(member_id_instance_variable)
    end
    it 'ignores groups that do not have an object class of `group`' do
      expect(ldap_other_object).to_not receive(:remove)
      call_method
    end
    it 'ignores groups that do not a CN that begins with `FHLB` and is followed by any number of digits' do
      expect(ldap_other_object.cn.first).to_not receive(:remove)
      call_method
    end
    it 'returns the formatted member_id of a group with an objectClass that includes `group` and a CN that begins with `FHLB` followed by any number of digits' do
      expect(ldap_bank.cn.first).to receive(:remove).and_call_original
      expect(call_method).to eq(bank_id)
    end
    it 'sets the @member_id attribute to the returned bank id' do
      call_method
      expect(subject.instance_variable_get(:@member_id)).to eq(bank_id)
    end
  end

  describe '`ldap_groups` method' do
    let(:ldap_groups_result){ double('ldap groups result') }
    let(:call_method) { subject.ldap_groups }
    before do
      allow(Devise::LDAP::Adapter).to receive(:get_groups).with(subject.login_with, subject.ldap_domain).and_return(ldap_groups_result)
    end
    it 'skips the lookup if called twice' do
      expect(Devise::LDAP::Adapter).to receive(:get_groups).and_return(ldap_groups_result).exactly(:once)
      call_method
      call_method
    end
    describe 'when `prefixed_groups_cache_key` is not present' do
      before do
        allow(subject).to receive(:prefixed_groups_cache_key).and_return(nil)
      end
      it 'returns the result of calling `Devise::LDAP::Adapter.get_groups`' do
        expect(call_method).to eq(ldap_groups_result)
      end
    end
    describe 'when `prefixed_groups_cache_key` is present' do
      let(:cache_key) { double('A Cache Key') }
      let(:expiry) { double('An Expiry') }
      before do
        allow(CacheConfiguration).to receive(:expiry).with(described_class::CACHE_CONTEXT_GROUPS).and_return(expiry)
        allow(subject).to receive(:prefixed_groups_cache_key).and_return(cache_key)
      end
      it 'checks for cached groups' do
        expect(Rails.cache).to receive(:fetch).with(cache_key, include(expires_in: expiry))
        call_method
      end
      it 'calls `Devise::LDAP::Adapter.get_groups` on a cache miss' do
        allow(Rails.cache).to receive(:fetch).and_yield
        expect(Devise::LDAP::Adapter).to receive(:get_groups).with(subject.login_with, subject.ldap_domain)
        call_method
      end
      it 'returns the result of the cache check' do
        result = double('A Result')
        allow(Rails.cache).to receive(:fetch).and_return(result)
        expect(call_method).to be(result)
      end
    end
  end

  describe '`destroy_ldap_entry` method' do
    let(:call_method) {subject.send(:destroy_ldap_entry)}
    let(:username) { double('username') }
    let(:ldap_domain) { double('ldap_domain') }
    before do
      allow(subject).to receive(:username).and_return(username)
      allow(subject).to receive(:ldap_domain).and_return(ldap_domain)
    end
    it 'calls `Devise::LDAP::Adapter.delete_ldap_entry`' do
      expect(Devise::LDAP::Adapter).to receive(:delete_ldap_entry).with(username, nil, ldap_domain).and_return(true)
      call_method
    end
    it 'raises an `ActiveRecord::Rollback` if the delete fails' do
      allow(Devise::LDAP::Adapter).to receive(:delete_ldap_entry).and_return(false)
      expect{call_method}.to raise_error(ActiveRecord::Rollback)
    end
  end

  describe '`accepted_terms?` method' do
    let(:stored_value) { double('a stored value') }
    let(:date_time) { DateTime.new(2015,1,1) }
    it 'returns true if there is a value for the `terms_accepted_at` attr' do
      allow(subject).to receive(:terms_accepted_at).and_return(date_time)
      expect(subject.accepted_terms?).to eq(true)
    end
    it 'returns false if there is a value for the `terms_accepted_at` attr' do
      expect(subject.accepted_terms?).to eq(false)
    end
  end

  describe '`virtual_validators?` method' do
    let(:call_method) { subject.virtual_validators? }
    it 'returns false by default' do
      expect(call_method).to be(false)
    end
    it 'returns true after `enable_virtual_validators!` is called' do
      subject.enable_virtual_validators!
      expect(call_method).to be(true)
    end
  end

  describe '`intranet_user?` method' do
    let(:call_method) { subject.intranet_user? }
    it 'returns true if the user has an ldap_domain of `intranet`' do
      subject.ldap_domain = 'intranet'
      expect(subject.intranet_user?).to eq(true)
    end
    it 'returns false if the user has any ldap_domain besides `intranet`' do
      ['foo', 'extranet', nil].each do |domain|
        subject.ldap_domain = domain
        expect(subject.intranet_user?).to eq(false)
      end
    end
  end

  describe '`check_password_change` protected method' do
    let(:call_method) { subject.send(:check_password_change) }
    it 'checks if the password has changed' do
      expect(subject).to receive(:password_changed?).at_least(1)
      call_method
    end
    it 'checks if any LDAP backed attributes have changed' do
      attribute = SecureRandom.hex
      ldap_attributes = double('Some LDAP Attributes')
      stub_const("#{described_class.name}::LDAP_ATTRIBUTES_MAPPING", ldap_attributes)
      allow(subject).to receive(:password_changed?).and_return(true)
      allow(subject).to receive(:changed).and_return([attribute])
      expect(ldap_attributes).to receive(:include?).with(attribute)
      call_method
    end
    describe 'if both a password and an LDAP attribute have changed' do
      before do
        allow(subject).to receive(:password_changed?).and_return(true)
        allow(subject).to receive(:changed).and_return([described_class::LDAP_ATTRIBUTES_MAPPING.keys.sample])
      end

      it 'raises an ActiveRecord::Rollback' do
        expect{call_method}.to raise_error(ActiveRecord::Rollback)
      end
      it 'adds an error to the password field if a rollback is raised' do
        expect(subject.errors).to receive(:add).with(:password, :non_atomic)
        call_method rescue ActiveRecord::Rollback
      end
    end
    describe 'when the password has changed and the user is an intranet user' do
      before do
        allow(subject).to receive(:password_changed?).and_return(true)
        allow(subject).to receive(:intranet_user?).and_return(true)
      end
      it 'raises an ActiveRecord::Rollback' do
        expect{call_method}.to raise_error(ActiveRecord::Rollback)
      end
      it 'adds an error to the password field if a rollback is raised' do
        expect(subject.errors).to receive(:add).with(:password, :intranet)
        call_method rescue ActiveRecord::Rollback
      end
    end
  end

  describe '`clear_password_expiration` protected method' do
    let(:call_method) { subject.send(:clear_password_expiration) }
    it 'calls `Devise::LDAP::Adapter.set_ldap_param` with the `LDAP_PASSWORD_EXPIRATION_ATTRIBUTE` set to `false`' do
      expect(Devise::LDAP::Adapter).to receive(:set_ldap_params).with(subject.username, {described_class::LDAP_PASSWORD_EXPIRATION_ATTRIBUTE => 'false'}, nil, subject.ldap_domain).and_return(true)
      call_method
    end
    it 'calls `reload_ldap_entry` if the update succeeds' do
      allow(Devise::LDAP::Adapter).to receive(:set_ldap_params).and_return(true)
      expect(subject).to receive(:reload_ldap_entry)
      call_method
    end
    it 'raises `ActiveRecord::rollback` if the LDAP update fails' do
      allow(Devise::LDAP::Adapter).to receive(:set_ldap_params).and_return(false)
      expect{call_method}.to raise_error(ActiveRecord::Rollback)
    end
    it 'is called after `ldap_password_save`' do
      callbacks = described_class.send(:get_callbacks, :ldap_password_save).select do |callback|
        callback.kind == :after && callback.filter == :clear_password_expiration
      end
      expect(callbacks.length).to eq(1)
    end
  end

  describe '`encrypted_password_changed?` protected method' do
    it 'returns false' do
      expect(subject.send(:encrypted_password_changed?)).to be(false)
    end
  end

  describe '`roles_lookup` method' do
    let(:user_service) { double('user service instance') }
    let(:ldap_role_cn) { 'FCN-MemberSite-Users' }
    let(:ldap_role) { double('some ldap role', cn: ldap_role_cn) }
    let(:ldap_roles) { [ldap_role] }
    let(:signer_role) { 'signer-advances' }
    let(:mapi_roles) { [signer_role] }
    let(:request) { double('some request object') }
    let(:session_roles) { double('roles set from the session') }
    let(:call_method) { subject.send(:roles_lookup, request) }
    before do
      allow(subject).to receive(:ldap_groups).and_return(ldap_roles)
      allow(UsersService).to receive(:new).and_return(user_service)
      allow(user_service).to receive(:user_roles).and_return(mapi_roles)
    end
    it 'will create an instance of UsersService with a request argument if one is provided' do
      expect(UsersService).to receive(:new).with(request).and_return(user_service)
      call_method
    end
    it 'will create an instance of UsersService with a test request if no request argument is provided' do
      expect(UsersService).to receive(:new).with(an_instance_of(ActionDispatch::TestRequest))
      subject.send(:roles_lookup)
    end
    it 'returns an array containing roles based on the CNs it receives from LDAP' do
      expect(call_method).to include(User::LDAP_GROUPS_TO_ROLES[ldap_role_cn])
    end
    it 'returns an array containing roles based on the values it receives from the MAPI endpoint' do
      expect(call_method).to include(User::LDAP_GROUPS_TO_ROLES[signer_role])
    end
    it 'ignores any roles it receives if they do not correspond to ROLE_MAPPING' do
      allow(subject).to receive(:ldap_groups).and_return([ldap_role, double('another ldap role', cn: 'some role we do not care about')])
      expect(call_method.length).to eq(2)
    end
  end

end

Rails.application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"

  get '/details' => 'welcome#details'
  get '/healthy' => 'welcome#healthy'
  get '/session_status' => 'welcome#session_status'
  get '/grid_demo' => 'welcome#grid_demo'

  get '/dashboard' => 'dashboard#index'

  get '/dashboard/current_overnight_vrc' => 'dashboard#current_overnight_vrc'

  constraints Constraints::FeatureEnabled.new('recent-credit-activity') do
    get '/dashboard/recent_activity' => 'dashboard#recent_activity'
  end

  get '/dashboard/account_overview' => 'dashboard#account_overview'

  get '/attachments/download/:id/:filename' => 'attachments#download', as: :attachment_download, filename: /[^\/]+/

  scope 'reports', as: :reports do
    get '/' => 'reports#index'
    get '/account-summary' => 'reports#account_summary'
    get '/advances' => 'reports#advances_detail'
    get '/authorizations' => 'reports#authorizations'
    get '/borrowing-capacity' => 'reports#borrowing_capacity'
    get '/capital-stock-activity' => 'reports#capital_stock_activity'
    get '/capital-stock-and-leverage' => 'reports#capital_stock_and_leverage'
    get '/capital-stock-trial-balance' => 'reports#capital_stock_trial_balance'
    get '/cash-projections' => 'reports#cash_projections'
    get '/current-securities-position' => 'reports#current_securities_position'
    get '/current-price-indications' => 'reports#current_price_indications'
    get '/dividend-statement' => 'reports#dividend_statement'
    get '/forward-commitments' => 'reports#forward_commitments'
    get '/historical-price-indications' => 'reports#historical_price_indications'
    get '/interest-rate-resets' => 'reports#interest_rate_resets'
    get '/letters-of-credit' => 'reports#letters_of_credit'
    get '/monthly-securities-position' => 'reports#monthly_securities_position'
    get '/mortgage-collateral-update' => 'reports#mortgage_collateral_update'
    get '/putable-advance-parallel-shift-sensitivity' => 'reports#parallel_shift', as: :parallel_shift
    get '/securities-services-statement' => 'reports#securities_services_statement', as: :securities_services_statement
    get '/securities-transactions' => 'reports#securities_transactions'
    get '/settlement-transaction-account' => 'reports#settlement_transaction_account'
    get '/todays-credit' => 'reports#todays_credit'
    constraints Constraints::FeatureEnabled.new('quick-reports') do
      get '/quick/download/:id' => 'quick_reports#download', as: :quick_download
    end
      get '/profile' => 'reports#profile'
  end

  scope 'advances', as: 'advances' do
    get '/manage' => 'advances#manage'
    get '/select-rate' => 'advances#select_rate'
    get '/fetch-rates' => 'advances#fetch_rates'
    get '/fetch-custom-rates' => 'advances#fetch_custom_rates'
    post  '/preview' => 'advances#preview'
    post '/perform' => 'advances#perform'
    constraints Constraints::FeatureEnabled.new('advance-confirmation') do
      get '/confirmation' => 'advances#confirmation'
    end
  end


  scope 'settings', as: :settings do
    get    '/'                         => 'error#not_found'
    get    '/password'                 => 'settings#change_password'
    put    '/password'                 => 'settings#update_password'
    get    '/two-factor'               => 'settings#two_factor'
    put    '/two-factor/pin'           => 'settings#reset_pin'
    post   '/two-factor/pin'           => 'settings#new_pin'
    post   '/two-factor/resynchronize' => 'settings#resynchronize'
    get    '/users'                    => 'settings#users'
    patch  '/users/:id'                => 'settings#update_user'
    delete '/users/:id'                => 'settings#delete_user'
  end

  scope 'settings' do
    get    '/users/new'                => 'settings#new_user', as: 'new_user'
    post   '/users'                    => 'settings#create_user', as: 'users'
    get    '/users/:id'                => 'settings#edit_user', as: 'user'
    get    '/users/:id/confirm_delete' => 'settings#confirm_delete', as: 'user_confirm_delete'
    post   '/users/:id/lock'           => 'settings#lock', as: 'user_lock'
    post   '/users/:id/unlock'         => 'settings#unlock', as: 'user_unlock'
    post   '/users/:id/reset_password' => 'settings#reset_password', as: 'user_reset_password'
    get    '/expired-password'         => 'settings#expired_password', as: :user_expired_password
    put    '/expired-password'         => 'settings#update_expired_password'
  end

  get '/jobs/:job_status_id' => 'jobs#status', as: 'job_status'
  get '/jobs/:job_status_id/download' => 'jobs#download', as: 'job_download'
  get '/jobs/:job_status_id/cancel' => 'jobs#cancel', as: 'job_cancel'

  constraints Constraints::FeatureEnabled.new('announcements') do
    scope 'corporate_communications/:category' do
      resources :corporate_communications, only: :show, as: :corporate_communication
      get '/' => 'corporate_communications#category', as: :corporate_communications
    end
  end

  scope 'resources' do
    get '/business-continuity' => 'resources#business_continuity'
    get '/forms' => 'resources#forms'
    get '/guides' => 'resources#guides'
    get '/capital-plan' => 'resources#capital_plan'
    get '/download/:file' => 'resources#download', as: :resources_download
    get 'fee_schedules' => 'resources#fee_schedules'
    scope 'membership' do
      get 'overview' => 'resources#membership_overview', as: :membership_overview
      get 'application' => 'resources#membership_application', as: :membership_application
      scope 'application' do
        get 'commercial-savings-and-industrial' => 'resources#commercial_application', as: :commercial_application
        get 'community-development' => 'resources#community_development_application', as: :community_development_application
        get 'credit-union' => 'resources#credit_union_application', as: :credit_union_application
        get 'insurance-company' => 'resources#insurance_company_application', as: :insurance_company_application
      end
    end
    constraints Constraints::FeatureEnabled.new('resources-token') do
      get '/token' => 'resources#token'
    end
  end

  scope 'products' do
    get '/authorizations' => 'products#authorizations', as: :products_authorizations
    get '/summary' => 'products#index', as: :product_summary
    get '/letters-of-credit' => 'products#loc', as: :products_loc
    get '/community_programs' => 'error#not_found'
    get '/interest-rate-swaps-caps-floors' => 'products#swaps', as: :product_swaps
    get '/variable-balance-letters-of-credit' => 'products#vbloc', as: :products_vbloc
    scope 'advances' do
      get 'adjustable-rate-credit' => 'products#arc', as: :arc
      get 'advances-for-community-enterprise' => 'error#not_found', as: :ace
      get 'amortizing' => 'products#amortizing', as: :amortizing
      get 'arc-embedded' => 'products#arc_embedded', as: :arc_embedded
      get 'callable' => 'products#callable', as: :callable
      get 'choice-libor' => 'products#choice_libor', as: :choice_libor
      get 'community-investment-program' => 'error#not_found', as: :cip
      get 'convertible' => 'products#convertible', as: :convertible
      get 'fixed-rate-credit' => 'products#frc', as: :frc
      get 'frc-embedded' => 'products#frc_embedded', as: :frc_embedded
      get 'knockout' => 'products#knockout', as: :knockout
      get 'mortgage-partnership-finance' => 'products#mpf', as: :mpf
      get 'pfi' => 'products#pfi', as: :pfi
      get 'other-cash-needs' => 'products#ocn', as: :ocn
      get 'putable' => 'products#putable', as: :putable
      get 'securities-backed-credit' => 'products#sbc', as: :sbc
      get 'variable-rate-credit' => 'products#vrc', as: :vrc
    end
  end

  constraints Constraints::FeatureEnabled.new('securities') do
    scope 'securities', as: :securities do
      get 'manage' => 'securities#manage'
      get 'requests' => 'securities#requests'
      delete 'request/:request_id' => 'securities#delete_request', as: 'delete_request'

      scope 'release', as: :release do
        get 'view/:request_id' => 'securities#view_request', as: 'view', defaults: { type: :release }
        get 'authorized/:request_id' => 'securities#generate_authorized_request', as: 'generate_authorized_request', defaults: { type: :release }
        post 'edit' => 'securities#edit_release'
        post 'download' => 'securities#download_release'
        post 'upload' => 'securities#upload_securities', defaults: { type: :release }
        post 'submit' => 'securities#submit_request', defaults: { type: :release }
        get 'pledge_success' => 'securities#submit_request_success', defaults: { kind: :pledge_release }
        get 'safekeep_success' => 'securities#submit_request_success', defaults: { kind: :safekept_release }
      end
      scope 'safekeep', as: :safekeep do
        get 'view/:request_id' => 'securities#view_request', as: 'view', defaults: { type: :safekeep }
        get 'edit' => 'securities#edit_safekeep'
        post 'download' => 'securities#download_safekeep'
        post 'upload' => 'securities#upload_securities', defaults: { type: :safekeep }
        post 'submit' => 'securities#submit_request', defaults: { type: :safekeep }
        get 'success' => 'securities#submit_request_success', defaults: {kind: :safekept_intake}
      end
      scope 'pledge', as: :pledge do
        get 'view/:request_id' => 'securities#view_request', as: 'view', defaults: { type: :pledge }
        get 'edit' => 'securities#edit_pledge'
        post 'download' => 'securities#download_pledge'
        post 'upload' => 'securities#upload_securities', defaults: { type: :pledge }
        post 'submit' => 'securities#submit_request', defaults: { type: :pledge }
        get 'success' => 'securities#submit_request_success', defaults: {kind: :pledge_intake}
      end
      scope 'transfer', as: :transfer do
        post 'edit' => 'securities#edit_transfer'
        post 'download' => 'securities#download_transfer'
        post 'upload' => 'securities#upload_securities', defaults: { type: :transfer }
        post 'submit' => 'securities#submit_request', defaults: { type: :transfer }
        get 'pledge_success' => 'securities#submit_request_success', defaults: { kind: :pledge_transfer }
        get 'safekeep_success' => 'securities#submit_request_success', defaults: { kind: :safekept_transfer }
        get 'view/:request_id' => 'securities#view_request', as: 'view', defaults: { type: :transfer }
      end
    end
  end

  constraints Constraints::FeatureEnabled.new('letters-of-credit') do
    scope 'letters-of-credit', as: :letters_of_credit do
      get 'manage' => 'letters_of_credit#manage'
      get 'request' => 'letters_of_credit#new'
      post 'preview' => 'letters_of_credit#preview'
      post 'execute' => 'letters_of_credit#execute'
      get 'view' => 'letters_of_credit#view'
    end
  end

  devise_scope :user do
    get '/' => 'users/sessions#new', :as => :new_user_session
    post '/' => 'users/sessions#create', :as => :user_session
    delete 'logout' => 'users/sessions#destroy', :as => :destroy_user_session
    get 'logged-out' => 'members#logged_out'
    post '/switch' => 'members#switch_member', :as => :members_switch_member
    get '/member' => 'members#select_member', :as => :members_select_member
    post '/member' => 'members#set_member', :as => :members_set_member
    get 'member/terms' => 'members#terms', :as => :terms
    post 'member/terms' => 'members#accept_terms', :as => :accept_terms
    get 'member/password' => 'users/passwords#new', as: :new_user_password
    post 'member/password' => 'users/passwords#create', as: :user_password
    get 'member/password/reset' => 'users/passwords#edit', as: :edit_user_password
    put 'member/password' => 'users/passwords#update'
    get '/terms-of-use' => 'members#terms_of_use', as: :terms_of_use
    get '/contact' => 'members#contact', as: :contact
    get '/privacy-policy' => 'members#privacy_policy', as: :privacy_policy
  end
  devise_for :users, controllers: { sessions: 'users/sessions', passwords: 'users/passwords' }, :skip => [:sessions, :passwords]

  root 'users/sessions#new'

  constraints Constraints::WebAdmin.new do
    scope :admin do
      get '/' => 'admin/dashboard#index', as: :dashboard_admin
      scope :features do
        get '/' => 'admin/features#index', as: :features_admin
        get '/:feature' => 'admin/features#view', as: :feature_admin
        put '/:feature/enable' => 'admin/features#enable_feature', as: :feature_enable_admin
        put '/:feature/disable' => 'admin/features#disable_feature', as: :feature_disable_admin
        post '/:feature/member' => 'admin/features#add_member', as: :feature_add_member_admin
        delete '/:feature/member/:member_id' => 'admin/features#remove_member', as: :feature_remove_member_admin
        post '/:feature/user' => 'admin/features#add_user', as: :feature_add_user_admin
        delete '/:feature/user/:username' => 'admin/features#remove_user', as: :feature_remove_user_admin
      end
      scope :rules do
        scope :term do
          get '/limits' => 'admin/rules#limits', as: :rules_term_limits
          put '/limits' => 'admin/rules#update_limits', as: :rules_update_term_limits
        end
      end
      constraints Constraints::WebAdmin.new(:edit_features?) do
        mount Flipper::UI.app(Rails.application.flipper) => '/flipper-features', as: :flipper_features_admin
      end
    end
  end

  get '/error' => 'error#standard_error' unless Rails.env.production?
  get '/maintenance' => 'error#maintenance' unless Rails.env.production?
  get '/not-found' => 'error#not_found' unless Rails.env.production?

  # BEGIN REDIRECT BLOCK- Redirect possibly bookmarked URLs from old member portal
  get '/Default.aspx' => redirect('/dashboard', status: 302)
  get '/member/index.aspx' => redirect('/dashboard', status: 302)
  get '/member/reports/sta/monthly.aspx' => redirect('/reports/settlement-transaction-account', status: 302)
  get '/member/rates/current/default.aspx' => redirect('/reports/current-price-indications', status: 302)
  get '/member/reports/securities/transaction.aspx' => redirect('/reports/securities-transactions', status: 302)
  get '/member/reports/advances/advances.aspx' =>	redirect('/reports/advances', status: 302)
  get '/member/profile/overview.aspx' => redirect('/reports/account-summary', status: 302)
  get '/member/profile/collateral/collateral.aspx' => redirect('/reports/borrowing-capacity', status: 302)
  get '/member/reports/advances/today.aspx' => redirect('/reports/todays-credit', status: 302)
  get '/member/profile/sta/sta.aspx' => redirect('/reports/settlement-transaction-account', status: 302)
  get '/accountservices' => redirect('/reports/account-summary', status: 302)
  get '/accountservices/*all' => redirect('/reports/account-summary', status: 302)
  get '/member/ps/forms' => redirect('/resources/forms', status: 302)
  get '/member/ps/forms/*all' => redirect('/resources/forms', status: 302)
  get '/member/ps/guides' => redirect('/resources/guides', status: 302)
  get '/member/ps/guides/*all' => redirect('/resources/guides', status: 302)
  get '/member/ps' => redirect('/products/summary', status: 302)
  get '/member/ps/*unmatched_route' => redirect('/products/summary', status: 302)
  get '/member/etransact' => redirect('/advances/manage', status: 302)
  get '/member/etransact/*all' => redirect('/advances/manage', status: 302)
  get '/member/accessmanager' => redirect('/settings/users', status: 302)
  get '/member/accessmanager/*all' => redirect('/settings/users', status: 302)
  get '/member/reports' => redirect('/reports', status: 302)
  get '/member/reports/*unmatched_route' => redirect('/reports', status: 302)
  get '/member/*unmatched_route' => redirect('/dashboard', status: 302)
  # END REDIRECT BLOCK

  # This catchall route MUST be listed here last to avoid catching previously-named routes
  get '*unmatched_route' => 'error#not_found'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end

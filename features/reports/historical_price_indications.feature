@jira-mem-69
Feature: Visiting the Historical Price Indications Report Page
  As a user
  I want to use visit the historical price indications report page for the FHLB Member Portal
  In order to view historic price indications (rates)

Background:
  Given I am logged in

@smoke @jira-mem-311
Scenario: Visit historical price indications from header link
  Given I visit the dashboard
  When I select "Historical" from the reports dropdown
  Then I should see "Historical Price Indications"
  When I wait for the report to load
  Then I should see a report header
  And I should see a report table with multiple data rows

@jira-mem-311
Scenario: Defaults to Standard Collateral Program FRC
  Given I am on the "Historical Price Indications" report page
  Then I should see "Standard Credit Program"
  And I should see "Fixed Rate Credit (FRC)"

@jira-mem-358
Scenario: Choosing an SBC credit program should select the default credit type if the current credit_type is not available in SBC programs.
  Given I am on the "Historical Price Indications" report page
  And I select "Adjustable Rate Credit (ARC) Daily Prime" from the credit type selector
  And I wait for the report to load
  When I select "Securities-Backed Credit" from the collateral type selector
  And I wait for the report to load
  Then I should see "Fixed Rate Credit (FRC)"

@smoke @jira-mem-318 @jira-mem-402 @jira-mem-358
Scenario Outline: Choosing different historic price indication reports
  Given I am on the "Historical Price Indications" report page
  When I select "<collateral_type>" from the <collateral_selector> type selector
  And I wait for the report to load
  When I select "<credit_type>" from the <credit_selector> type selector
  And I wait for the report to load
  Then I should see "<credit_type>"
  Then I should see the table heading "<table_heading>" on the table "<table>"
  Examples:
  | collateral_type                  | collateral_selector | credit_type                                | credit_selector | table_heading                | table                      |
  | Standard Credit Program          | collateral          | Adjustable Rate Credit (ARC) 1 month LIBOR | credit          | 1 mo LIBOR                   | standard-1m_libor-table    |
  | Standard Credit Program          | collateral          | Adjustable Rate Credit (ARC) 3 month LIBOR | credit          | 3 mo LIBOR                   | standard-3m_libor-table    |
  | Standard Credit Program          | collateral          | Adjustable Rate Credit (ARC) 6 month LIBOR | credit          | 6 mo LIBOR                   | standard-6m_libor-table    |
  | Standard Credit Program          | collateral          | Adjustable Rate Credit (ARC) Daily Prime   | credit          | 1 year 2 year 3 year 5 year  | standard-daily_prime-table |
  | Securities-Backed Credit Program | collateral          | Adjustable Rate Credit (ARC) 1 month LIBOR | credit          | 1 mo LIBOR                   | sbc-1m_libor-table         |
  | Securities-Backed Credit Program | collateral          | Adjustable Rate Credit (ARC) 3 month LIBOR | credit          | 3 mo LIBOR                   | sbc-3m_libor-table         |
  | Securities-Backed Credit Program | collateral          | Adjustable Rate Credit (ARC) 6 month LIBOR | credit          | 6 mo LIBOR                   | sbc-6m_libor-table         |

@jira-mem-318 @jira-mem-402 @jira-mem-358
Scenario Outline: Choosing different historic price indication reports
  Given I am on the "Historical Price Indications" report page
  When I select "<collateral_type>" from the <collateral_selector> type selector
  And I wait for the report to load
  When I select "<credit_type>" from the <credit_selector> type selector
  And I wait for the report to load
  Then I should see "<credit_type>"
  Then I should not see a table heading row on the table "<table>"
  Examples:
  | collateral_type                  | collateral_selector | credit_type                                | credit_selector | table                      |
  | Standard Credit Program          | collateral          | Variable Rate Credit (VRC)                 | credit          | standard-vrc-table         |
  | Securities-Backed Credit Program | collateral          | Variable Rate Credit (VRC)                 | credit          | sbc-vrc-table              |

@smoke @jira-mem-1287
Scenario: Choosing sta option on historic price indication reports
  Given I am on the "Historical Price Indications" report page
  When I select "Settlement/Transaction Acct. Rate" from the collateral type selector
  And I wait for the report to load
  Then I should see "STA Rates"

@jira-mem-359 @jira-mem-537
Scenario: Custom datepicker options
  Given I am on the "Historical Price Indications" report page
  When I click the datepicker field
  Then I should see the datepicker preset for "month to date"
  And I should see the datepicker preset for "last month"
  And I should see the datepicker preset for "last year"

@jira-mem-359 @jira-mem-537
Scenario: Choosing different presets in the datepicker
  Given I am on the "Historical Price Indications" report page
  When I click the datepicker field
  And I choose the "month to date" preset in the datepicker
  Then I should see a report with dates for "month to date"
  When I click the datepicker field
  And I choose the "last month" preset in the datepicker
  Then I should see a report with dates for "last month"
  When I click the datepicker field
  And I choose the "last year" preset in the datepicker
  Then I should see a report with dates for "last year"

@data-unavailable @jira-mem-283 @jira-mem-1053
Scenario: No data is available to show in the Historical Price Indications report
  Given I am on the "Historical Price Indications" report page
  When the "Historical Price Indications" table has no data
  Then I should see an empty report table with No Records messaging

@data-unavailable @jira-mem-282 @jira-mem-1053
Scenario: The Historical Price Indications report has been disabled
  Given I am on the "Historical Price Indications" report page
  When the "Historical Price Indications" report has been disabled
  Then I should see an empty report table with Data Unavailable messaging

@resque-backed @smoke @jira-mem-793
Scenario: Member downloads an XLSX of the Historical Price Indications report
  Given I am on the "Historical Price Indications" report page
  When I request an XLSX
  Then I should begin downloading a file

@jira-mem-919
Scenario: The datepicker handles two-digit years and prohibited characters
  Given I am on the "Historical Price Indications" report page
  When I click the datepicker field
  Then I am able to enter two-digit years in the datepicker inputs
  And I am not able to enter prohibited characters in the datepicker inputs
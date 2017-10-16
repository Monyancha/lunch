@jira-mem-69
Feature: Visiting the Securities Services Monthly Fee Statement Page
  As a user
  I want to use visit the Securities Services Monthly Fee Statement page for the FHLB Member Portal
  In order to view my account charges.

Background:
  Given I am logged in to a bank with data for the "Securities Services Monthly Fee Statement" report

@jira-mem-536
Scenario: Member sees Securities Services Statement
  Given I visit the dashboard
  When I select "Securities Services Monthly Fee Statement" from the reports dropdown
  Then I should see report summary data
  And I should see a report header
  And I should see 4 report tables with multiple data rows

@jira-mem-1196
Scenario: The Securities Services Monthly Fee Statement report dropdown controls which report is shown
  Given I am on the "Securities Services Monthly Fee Statement" report page
  When I select the last entry from the month year dropdown
  Then I should see a report for the last entry from the month year dropdown

@data-unavailable @jira-mem-536
Scenario: No data is available to show in spefic sections of the Securities Services Statement
  Given I am on the "Securities Services Monthly Fee Statement" report page
  When the "Dividend Summary" table has no data
  Then I should see a "Dividend Summary" report table with all data missing
  When the "Dividend Details" table has no data
  Then I should see the "Dividend Details" report table with Data Unavailable messaging

@data-unavailable @jira-mem-1309
Scenario: No data at all is available for the Securities Services Statement
  Given I am on the "Securities Services Monthly Fee Statement" report page
  When the "Securities Services Monthly Fee Statement" report has no data
  Then I should see the has no data state for the Securities Services Monthly Fee Statement

@data-unavailable @jira-mem-536
Scenario: The Securities Services Statement has been disabled
  Given I am on the "Securities Services Monthly Fee Statement" report page
  When the "Dividend Transaction Statement" report has been disabled
  Then I should see a "Dividend Summary" report table with all data missing
  Then I should see the "Dividend Details" report table with Data Unavailable messaging

@resque-backed @jira-mem-822
Scenario: Member downloads a PDF of the Securities Services Statement report
  Given I am on the "Securities Services Monthly Fee Statement" report page
  When I request a PDF
  Then I should begin downloading a file  
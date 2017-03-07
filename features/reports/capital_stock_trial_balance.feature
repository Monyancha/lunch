@jira-mem-1020
Feature: Visiting the Capital Stock Trial Balance Report Page
  As a user
  I want to use visit the aCapital Stock Trial Balance page for the FHLB Member Portal
  In order to view the details of my Capital Stock Trial Balance

Background:
  Given I am logged in

@smoke
Scenario: Visit Capital Stock Trial Balance from header link
  Given I visit the dashboard
  When I select "Capital Stock Trial Balance" from the reports dropdown
  Then I should see "Capital Stock Trial Balance"
  And I should see a report header
  And I should see a report table with multiple data rows

@smoke
Scenario: Visiting the Capital Stock Trial Balance Report Page
  Given I am on the "Capital Stock Trial Balance" report page
  Then I should see "Certificate Sequence"
  Then I should see "Issue Date"
  Then I should see "Transaction Type"
  Then I should see "Shares Outstanding"
  And I should see Capital Stock Trial Balance report

@data-unavailable @smoke
Scenario: Capital Stock Trial Balance Report has been disabled
  Given I am on the "Capital Stock Trial Balance" report page
  When the "Capital Stock Trial Balance" report has been disabled
  Then I should see an empty report table with Data Unavailable messaging

@resque-backed @smoke @jira-mem-1066
Scenario: Member downloads an XLSX of the Capital Stock Trial Balance report
  Given I am on the "Capital Stock Trial Balance" report page
  When I request an XLSX
  Then I should begin downloading a file

@jira-mem-2145
Scenario: Member downloads a PDF of the Capital Stock Trial Balance report
  Given I am on the "Capital Stock Trial Balance" report page
  When I request a PDF
  Then I should begin downloading a file

@jira-mem-1237
Scenario: Member tries to pick a date occuring before January 1, 2002
  Given I am on the "Capital Stock Trial Balance" report page
  When I click the datepicker field
  And I write "01/01/1999" in the datepicker start input field
  And I click the datepicker apply button
  Then I should see a report for "January 1, 2002"

@jira-mem-919
Scenario: The datepicker handles two-digit years and prohibited characters
  Given I am on the "Capital Stock Trial Balance" report page
  When I click the datepicker field
  Then I am able to enter two-digit years in the datepicker input
  And I am not able to enter prohibited characters in the datepicker input

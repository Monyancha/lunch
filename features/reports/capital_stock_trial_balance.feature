@jira-mem-1020
Feature: Visiting the Capital Stock Trial Balance Report Page
  As a user
  I want to use visit the Capital Stock Trial Balance report page for the FHLB Member Portal

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
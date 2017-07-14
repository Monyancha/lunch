@jira-mem-69
Feature: Visiting the Borrowing Capacity Statement Page
  As a user
  I want to use visit the borrowing capacity statement page for the FHLB Member Portal
  In order to view my current borrowing capacity details

Background:
  Given I am logged in

@smoke
Scenario: Member sees Borrowing Capacity Statement
  Given I visit the dashboard
  When I select "Borrowing Capacity" from the reports dropdown
  And I wait for the report to load
  Then I should see report summary data
  And I should see a report header
  And I should see the "Standard Credit Program" table and "3" subtables
  And I should see the "Securities-Backed Credit Program" table and "1" subtable

@jira-mem-2410 @smoke @flip-on-report-borrowing-capacity-historical-data
Scenario: Member requests historical data on the Borrowing Capacity Statement
  Given I visit the dashboard
  When I select "Borrowing Capacity" from the reports dropdown
  When I select the last entry from the month year dropdown
  And I wait for the report to load
  Then I should see report summary data
  And I should see a report header
  And I should see the "Standard Credit Program" table and "3" subtables
  And I should see the "Securities-Backed Credit Program" table and "1" subtable

Scenario: Member sorts the Standard Credit Program table on the Borrowing Capacity Statement by original amount
  Given I am on the "Borrowing Capacity Statement" report page
  When I click the "Original Amount" column heading on the "Standard Credit Program" parent table
  Then I should see the "Original Amount" column values in "ascending" order on the "Standard Credit Program" parent table
  When I click the "Original Amount" column heading on the "Standard Credit Program" parent table
  Then I should see the "Original Amount" column values in "descending" order on the "Standard Credit Program" parent table

@data-unavailable @jira-mem-283 @jira-mem-1053
Scenario: No data is available to show in the Borrowing Capacity Statement
  Given I am on the "Borrowing Capacity Statement" report page
  When the "Borrowing Capacity Statement" table has no data
  Then I should see an empty report table with No Records messaging

@data-unavailable @jira-mem-282 @jira-mem-1053
Scenario: The Borrowing Capacity Statement has been disabled
  Given I am on the "Borrowing Capacity Statement" report page
  When the "Borrowing Capacity Statement" report has been disabled
  Then I should see an empty report table with Data Unavailable messaging

@resque-backed @smoke @jira-mem-416
Scenario: Member downloads a PDF of the Borrowing Capacity report
  Given I am on the "Borrowing Capacity Statement" report page
  When I request a PDF
  Then I should begin downloading a file
@flip-on-securities
Feature: Safekeep Securities
  As a user
  I want to add new safekept securities

Background:
  Given I am logged in

@jira-mem-1679
Scenario: View the safekeep securities page
  When I am on the manage securities page
  And I click the button to create a new safekeep request
  Then I should be on the safekeep securities page

@jira-mem-1679
Scenario: View the various Delivery Instructions field sets
  When I am on the safekeep securities page
  Then I should see "DTC" as the selected release delivery instructions
  And I should see the "DTC" release instructions fields
  When I select "Fed" as the release delivery instructions
  Then I should see "Fed" as the selected release delivery instructions
  And I should see the "Fed" release instructions fields
  When I select "Physical" as the release delivery instructions
  Then I should see "Physical" as the selected release delivery instructions
  And I should see the "Physical" release instructions fields
  When I select "Mutual Fund" as the release delivery instructions
  Then I should see "Mutual Fund" as the selected release delivery instructions
  And I should see the "Mutual Fund" release instructions fields

@jira-mem-1679
Scenario: Member interacts with the Delete Release flyout dialogue
  Given I am on the safekeep securities page
  When I click the button to delete the release
  Then I should see the delete release flyout dialogue
  When I click on the button to continue with the release
  Then I should not see the delete release flyout dialogue
  When I click the button to delete the release
  And I click on the button to delete the release
  Then I should be on the Manage Securities page

@jira-mem-1679
Scenario: Member changes trade and settlement dates
  # This should be flushed out once we have actual date ranges to check
  Given I am on the safekeep securities page
  When I click the trade date datepicker
  And I click the datepicker apply button
  Then I should be on the safekeep securities page
  When I click the trade date datepicker
  And I click the datepicker cancel button
  Then I should be on the safekeep securities page
  When I click the settlement date datepicker
  And I click the datepicker apply button
  Then I should be on the safekeep securities page
  When I click the settlement date datepicker
  And I click the datepicker cancel button
  Then I should be on the safekeep securities page

@jira-mem-1679
Scenario: Member cannot click on the account number input
  Given I am on the safekeep securities page
  Then Account Number should be disabled
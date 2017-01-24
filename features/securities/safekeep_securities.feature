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

@jira-mem-2070
Scenario: View the safekeep securities page from the nav
  When I click on the securities link in the header
  And I click on the safekeep new link in the header
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
Scenario: Member cannot click on the account number input
  Given I am on the safekeep securities page
  Then the Safekeep Account Number should be disabled

@jira-mem-1677 @jira-mem-1986
Scenario Outline: Member views edit securities instructions
  Given I am on the <page> page
  Then I should see instructions on how to upload securities
  Examples:
    | page                |
    | safekeep securities |
    | pledge securities   |

@jira-mem-1669
Scenario: A signer views a previously submitted safekeep request
  Given I am logged in as a "quick-advance signer"
  And I am on the securities request page
  When I click to Authorize the first safekept intake
  Then I should be on the Safekeep Securities page
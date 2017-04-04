Feature: Global header
  As a user
  I want to use the global header
  In order to navigate the site

Background:
  Given I am logged in

Scenario: Member sees reports dropdown
  Given I visit the dashboard
  And I don't see the reports dropdown
  When I click on the reports link in the header
  Then I should see the reports dropdown

Scenario: Member sees resources dropdown
  Given I visit the dashboard
  And I don't see the resources dropdown
  When I click on the resources link in the header
  Then I should see the resources dropdown

Scenario: Member sees products dropdown
  Given I visit the dashboard
  And I don't see the products dropdown
  When I click on the products link in the header
  Then I should see the products dropdown

Scenario: Intranet user sees bank name in header
  Given I visit the root path
  When I log in as a "primary user"
  Then I should see the primary bank name in the header

Scenario: Member sees render time in navigation header
  Given I visit the dashboard
  Then I should see a datestamp in the navigation header

@jira-mem-262 @flip-on-securities
Scenario: Member sees active nav state when a subpage is viewed
  When I click on the advances link in the header
  And I click on the manage advances link in the header
  Then I should see the active state of the advances nav item
  When I click on the securities link in the header
  And I click on the manage securities link in the header
  Then I should see the active state of the securities nav item
  When I click on the reports link in the header
  And I click on the learn more link in the header
  Then I should see the active state of the reports nav item
  When I click on the resources link in the header
  And I click on the agreements link in the header
  Then I should see the active state of the resources nav item
  When I click on the products link in the header
  And I click on the products summary link in the header
  Then I should see the active state of the products nav item

@flip-on-securities
Scenario: Member sees securities dropdown
  Given I visit the dashboard
  And I don't see the securities dropdown
  When I click on the securities link in the header
  Then I should see the securities dropdown

@jira-mem-2267
Scenario: Member closes the nav by pressing the Esc key
  Given I visit the dashboard
  When I click on the reports link in the header
  Then I should see the reports dropdown
  When I press the Esc key
  Then I don't see the reports dropdown

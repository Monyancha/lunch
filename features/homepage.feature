
Feature: Visiting Homepage
  As a user
  I want to use visit the FHLB Member Portal
  In order to find information

  Background:
    Given I am logged out

  @smoke
  Scenario: Visit homepage
    When I visit the root path
    Then I should see "Welcome!"
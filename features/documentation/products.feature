Feature: Products Page
  As a user
  I want to learn more about the products offered by FHLB
  In order to decide which ones are right for my bank

  Background:
    Given I am logged in

  @smoke @jira-mem-696
  Scenario: Member navigates to the product summary page via the resources dropdown
    Given I click on the products link in the header
    When I click on the products summary link in the header
    Then I should see the "products summary" product page

  @smoke @jira-mem-846
  Scenario: Member navigates to the ARC embedded product page
    Given I click on the products link in the header
    When I click on the arc embedded link in the products advances dropdown
    Then I should see the "arc embedded" product page

  @smoke @jira-mem-697
  Scenario: Member navigates to the FRC product page
    Given I click on the products link in the header
    When I click on the frc link in the products advances dropdown
    Then I should see the "frc" product page

  @smoke @jira-mem-851
  Scenario: Member navigates to the FRC Embedded Cap product page
    Given I click on the products link in the header
    When I click on the frc embedded link in the products advances dropdown
    Then I should see the "frc embedded" product page

  @smoke @jira-mem-843
  Scenario: Member navigates to the ARC product page
    Given I click on the products link in the header
    When I click on the arc link in the products advances dropdown
    Then I should see the "arc" product page

  Scenario: Member navigates to the amortizing page via the products advances dropdown
    Given I click on the products link in the header
    When I click on the amortizing link in the products advances dropdown
    Then I should see the "amortizing" product page

  @smoke @jira-mem-848
  Scenario: Member navigates to the choice libor product page
    Given I click on the products link in the header
    When I click on the choice libor link in the products advances dropdown
    Then I should see the "choice libor" product page

  @smoke @jira-mem-851
  Scenario: Member navigates to the knockout product page
    Given I click on the products link in the header
    When I click on the knockout link in the products advances dropdown
    Then I should see the "knockout" product page

  @smoke @jira-mem-855
  Scenario: Member navigates to the putable product page
    Given I click on the products link in the header
    When I click on the putable link in the products advances dropdown
    Then I should see the "putable" product page

  @smoke @jira-mem-854
  Scenario: Member navigates to the other cash needs product page
    Given I click on the products link in the header
    When I click on the other cash needs link in the products advances dropdown
    Then I should see the "other cash needs" product page

  @smoke @jira-mem-847
  Scenario: Member navigates to the callable advance product page
    Given I click on the products link in the header
    When I click on the callable link in the header
    Then I should see the "callable" product page

  @smoke @jira-mem-854
  Scenario: Member navigates to the variable rate credit product page
    Given I click on the products link in the header
    When I click on the variable rate credit link in the header
    Then I should see the "variable rate credit" product page

  @smoke @jira-mem-851
  Scenario: Member navigates to the securities backed credit product page
    Given I click on the products link in the header
    When I click on the securities backed credit link in the header
    Then I should see the "securities backed credit" product page

  @smoke @jira-mem-853
  Scenario: Member navigates to the mortgage partnership finance product page
    Given I click on the products link in the header
    When I click on the mortgage partnership finance link in the products advances dropdown
    Then I should see the "mortgage partnership finance" product page

  @smoke @jira-mem-1024
  Scenario: Member navigates to the mortgage partnership finance product page
    Given I click on the products link in the header
    When I click on the mortgage partnership finance link in the products advances dropdown
    Then I should see the "mortgage partnership finance" product page
    When I click on the pfi link
    Then I should see the pfi page

  @smoke @jira-mem-1024
  Scenario: Member sees forms on the pfi page
    Given I am on the pfi page
    Then I should see at least one pfi form to download

  @smoke @jira-mem-2268
  Scenario: Member navigates to the convertible product page
    Given I click on the products link in the header
    When I click on the convertible link in the header
    Then I should see the "convertible" product page
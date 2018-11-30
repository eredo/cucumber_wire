Feature: dart cucumber wire
  Scenario: Wired
    Given we're all wired
    And I navigate to https://www.google.com/
    Then I see the download button containing the text "Google"

  Scenario Outline: Wired with table
    Given we're all wired
    And I navigate to <website>
    Then I see the download button containing the text "<text>"

    Examples:
      | website                 | text         |
      | https://www.google.com/ | Google |

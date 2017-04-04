When /^I visit the root path$/ do
  visit "/"
end

Then(/^I should see "([^"]*)"$/) do |text|
  grab_screen("I should see #{text}")
  page.should have_content(text)
end

Then(/^I should see something like "(.*?)"$/) do |text|
  regex = text.gsub(".....",".+")
  page.text.should match(/#{regex}/)
end

Then(/^I should not see "(.*?)"$/) do |text|
  page.should_not have_content(text)
end

When(/^I enter "(.*?)" into the "(.*?)" input field$/) do |input_text, input_selector|
  page.find(input_selector).set(input_text)
end

When(/^I press the back button$/) do
  page.evaluate_script('window.history.back()')
end

Then(/^I take a screen grab of "(.*?)"$/) do |text|
  grab_screen("I take a screen grab of #{text}")
end

Then(/^I should see an error page$/) do
  page.assert_selector('.error-page', visible: true)
end

When(/^I scroll to the bottom of the screen$/) do
  page.execute_script "window.scrollBy(0,10000)"
end

Given(/^I wait for (\d+) seconds$/) do |seconds|
  sleep(seconds.to_f)
end

Then(/^I should see a success flash$/) do
  page.assert_selector('.form-flash-message[data-type=success]')
end

Then(/^I should not see an error flash$/) do
  page.assert_no_selector('.form-flash-message[data-type=error]', visible: true)
end

Then(/^I should not see any success or failure messages$/) do
  page.assert_no_selector('.form-flash-message[data-type=success]', visible: true)
  page.assert_no_selector('.form-flash-message[data-type=error]', visible: true)
end

When(/^I use the browser back button$/) do
  page.driver.go_back
end

Then(/^I should see a flyout$/) do
  page.assert_selector('.flyout', visible: true)
end

When(/^I click on the flyout close button$/) do
  page.find('.flyout-close-button').click
end

Then(/^I should not see a flyout$/) do
  page.assert_selector('.flyout', :visible => :hidden)
end

Then(/^I should( not)? see an "([^"]*)" button$/) do |negation, text|
  options = ['.secondary-button, .primary-button', text: /#{Regexp.quote(text)}/i, visible: true, exact: true]
  if negation
    page.assert_no_selector(*options)
  else
    page.assert_selector(*options)
  end
end

When(/^I press the Esc key$/) do
  jquery_execute("
    var event = jQuery.Event('keydown');
    event.keyCode = 27;
    $(document).trigger(event);
  ")
end

def jquery_guard(timeout=10)
  times_out_at = Time.now + timeout
  while page.evaluate_script('typeof $') == 'undefined'
    raise Capybara::CapybaraError.new('jQuery was not found') if Time.now > times_out_at
  end
end

def jquery_execute(script)
  jquery_guard
  page.execute_script(script)
end

def jquery_evaluate(script)
  jquery_guard
  page.evaluate_script(script)
end

def links_from_frame frame_name, opts={limit: 20}
  cur_frame = page.find("frame[name=#{frame_name}]")

  links = nil
  within_frame cur_frame do
    links = page.all 'a'
    links = links[0..(opts[:limit]-1)].map { |l| l[:href] }
  end

  puts "found #{links.length} links"

  links
end

#fails if any link produces a response that looks like a 404 or 500
def visit_all links
  not_found = []
  server_error = []

  links.each do |link|
    puts "visiting link: #{link}"
    visit link

    grab_screen "visited #{link}"
    current_url.should == link

    if page.has_content?('404')
      not_found << link
      next
    end

    server_error << link if page.has_content?('500') || page.has_content?('rror') || page.has_content?('ception')
  end

  unless not_found.empty? && server_error.empty?
    fail "The following links responded with status 404: #{not_found.inspect} and these responded with status 500: #{server_error}"
  end
end
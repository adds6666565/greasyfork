require "application_system_test_case"

class CreateTest < ApplicationSystemTestCase
  test "script creation" do
    user = User.first
    login_as(user, scope: :user)
    visit new_script_version_url
    code = <<~EOF
      // ==UserScript==
      // @name A Test!
      // @description Unit test.
      // @version 1.1
      // @namespace http://greasyfork.local/users/1
      // ==/UserScript==
      var foo = 1;
    EOF
    fill_in 'Code', with: code
    click_button 'Post script'
    assert_selector 'h2', text: 'A Test!'
    assert_includes(Script.last.users, user)
  end

  test "css script creation" do
    user = User.first
    login_as(user, scope: :user)
    visit new_script_version_url(language: 'css')
    code = <<~EOF
      /* ==UserStyle==
      @name        Example UserCSS style
      @description This is an example
      @namespace   github.com/openstyles/stylus
      @version     1.0.0
      @license     unlicense
      ==/UserStyle== */
      
      @-moz-document domain("example.com") {
        a {
          color: red;
        }
      }
    EOF
    fill_in 'Code', with: code
    click_button 'Post script'
    assert_selector 'h2', text: 'Example UserCSS style'
    assert_includes(Script.last.users, user)
  end

  test "library creation with meta block" do
    user = User.first
    login_as(user, scope: :user)
    visit new_script_version_url
    code = <<~EOF
      // ==UserScript==
      // @name My library
      // @description Unit test.
      // @version 1.1
      // @namespace http://greasyfork.local/users/1
      // ==/UserScript==
      var foo = 1;
    EOF
    fill_in 'Code', with: code
    choose 'Library - a script intended to be @require-d from other scripts and not installed directly.'
    click_button 'Post script'
    assert_selector 'h2', text: 'My library'
    assert_includes(Script.last.users, user)
  end

  test "library creation without meta block" do
    user = User.first
    login_as(user, scope: :user)
    visit new_script_version_url
    code = <<~EOF
      var foo = 1;
    EOF
    fill_in 'Code', with: code
    choose 'Library - a script intended to be @require-d from other scripts and not installed directly.'
    click_button 'Post script'
    fill_in 'Name', with: 'My library'
    fill_in 'Description', with: 'My library description'
    click_button 'Post script'
    assert_selector 'h2', text: 'My library'
    assert_includes(Script.last.users, user)
  end

  test 'blocked email domain' do
    user = User.first
    user.skip_reconfirmation!
    user.update(email: 'ich@derspamhaus.de')
    login_as(user, scope: :user)
    visit new_script_version_url
    assert_content "You must confirm your email before posting scripts."
  end

  test 'suspicious email domain, not confirmed' do
    user = User.first
    user.skip_reconfirmation!
    user.update(email: 'salomon@fishy.hut', confirmed_at: nil)
    login_as(user, scope: :user)
    visit new_script_version_url
    assert_content "You must confirm your email before posting scripts."
  end

  test "disallowed with originating script" do
    user = User.find(4)
    login_as(user, scope: :user)
    visit new_script_version_url
    code = <<~EOF
      // ==UserScript==
      // @name A Test!
      // @description Unit test.
      // @version 1.1
      // @namespace http://greasyfork.local/users/1
      // ==/UserScript==
      this.was.copied.from.another.script
    EOF
    fill_in 'Code', with: code
    click_button 'Post script'
    assert_selector 'li', text: 'This code appears to be an unauthorized copy'
  end

  test 'confirmed, disposable email' do
    user = User.first
    user.update(email: 'test@example.com', confirmed_at: Time.now, disposable_email: true)
    login_as(user, scope: :user)
    visit new_script_version_url
    assert_content "You may not post scripts if you use a disposable email address."
  end

  test "banned via disallowed url" do
    user = User.find(4)
    login_as(user, scope: :user)
    visit new_script_version_url
    code = <<~EOF
      // ==UserScript==
      // @name A Test!
      // @description Unit test.
      // @version 1.1
      // @namespace http://greasyfork.local/users/1
      // ==/UserScript==
      location.href = "https://example.com/unique-test-value"
    EOF
    fill_in 'Code', with: code
    assert_changes -> { user.reload.banned }, from: false, to: true do
      click_button 'Post script'
      assert_content 'This script has been deleted'
    end
  end
end

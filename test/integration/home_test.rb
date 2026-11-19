require "test_helper"

class HomeTest < ActionDispatch::IntegrationTest
  test "serves the React entrypoint and its compiled asset" do
    get root_path

    assert_response :success
    assert_select "div#app"
    assert_select "script[src*='application-']" do |scripts|
      get scripts.first["src"]
      assert_response :success
      assert_includes response.body, "ACME Salary Management"
    end
  end
end

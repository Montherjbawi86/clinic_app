require "test_helper"

class Dashboard::OverviewControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get dashboard_overview_index_url
    assert_response :success
  end
end

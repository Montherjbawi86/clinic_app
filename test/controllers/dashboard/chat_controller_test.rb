require "test_helper"

class Dashboard::ChatControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get dashboard_chat_index_url
    assert_response :success
  end

  test "should get create" do
    get dashboard_chat_create_url
    assert_response :success
  end
end

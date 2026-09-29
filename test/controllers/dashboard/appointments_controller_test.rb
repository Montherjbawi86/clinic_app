require "test_helper"

class Dashboard::AppointmentsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get dashboard_appointments_index_url
    assert_response :success
  end

  test "should get create" do
    get dashboard_appointments_create_url
    assert_response :success
  end

  test "should get update" do
    get dashboard_appointments_update_url
    assert_response :success
  end
end

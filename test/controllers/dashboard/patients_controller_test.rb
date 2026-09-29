require "test_helper"

class Dashboard::PatientsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get dashboard_patients_index_url
    assert_response :success
  end

  test "should get create" do
    get dashboard_patients_create_url
    assert_response :success
  end

  test "should get update" do
    get dashboard_patients_update_url
    assert_response :success
  end

  test "should get destroy" do
    get dashboard_patients_destroy_url
    assert_response :success
  end
end

User.find_or_create_by!(email: "admin@clinic.com") { |u| u.name = "Admin Doctor"; u.password = "password123"; u.role = "admin"; u.locale = "en" }

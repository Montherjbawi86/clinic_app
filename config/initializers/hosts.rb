# Allow LAN access in development (for QR scanning from phones)
if Rails.env.development?
  Rails.application.config.hosts.clear
  Rails.application.config.hosts << IPAddr.new("0.0.0.0/0")
  Rails.application.config.hosts << ".local"
  Rails.application.config.hosts << "localhost"
end

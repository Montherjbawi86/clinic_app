if defined?(WickedPdf)
  WickedPdf.configure do |config|
    config.exe_path = "/usr/local/bin/wkhtmltopdf"
    config.enable_local_file_access = true
    config.orientation = "Portrait"
    config.encoding = "UTF-8"
  end
end

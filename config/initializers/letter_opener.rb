# Don't auto-open emails in the browser (Chrome blocks file:// to tmp/)
if defined?(LetterOpener)
  LetterOpener.configure do |config|
    config.file_uri_scheme = "file://"
    # We use `lastmail` in the terminal instead of auto-open
    config.message_template = :light
  end
end

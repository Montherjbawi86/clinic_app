namespace :reminders do
  desc "Send appointment reminders for tomorrow (manual run)"
  task send: :environment do
    puts "🔔 Running AppointmentReminderJob manually…"
    AppointmentReminderJob.perform_now
    puts "✅ Done"
  end
end

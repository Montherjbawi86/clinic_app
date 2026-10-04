namespace :subscriptions do
  desc "Create a subscription for a clinic by ID. Usage: rails subscriptions:create[CLINIC_ID,PLAN]"
  task :create, [:clinic_id, :plan] => :environment do |_, args|
    clinic = Clinic.find(args[:clinic_id])
    plan   = args[:plan] || "basic"

    sub = Subscription.create!(
      clinic:     clinic,
      plan:       plan,
      status:     "active",
      expires_at: 1.year.from_now
    )
    puts "✅ Created #{plan} subscription for #{clinic.name} (id: #{sub.id})"
  end
end

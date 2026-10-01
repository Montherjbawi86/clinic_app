namespace :clinic_app do
  desc "Backfill clinic_members from clinic owners"
  task backfill_members: :environment do
    created = 0
    Clinic.find_each do |c|
      cm = ClinicMember.find_or_create_by!(clinic: c, user: c.owner) { |m| m.role = "owner" }
      created += 1 if cm.previously_new_record?
    end
    puts "Done. Created #{created} memberships. Total: #{ClinicMember.count}"
  end
end

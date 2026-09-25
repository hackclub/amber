namespace :slack do
  desc "Rewrite Slack markup in tickets filed before SlackText existed"
  task backfill_text: :environment do
    client = SlackNotifier.enabled? ? SlackNotifier.reader : nil
    puts "Resolving names via Slack" if client
    changed = 0

    Ticket.find_each do |ticket|
      cleaned = SlackText.to_markdown(ticket.message, client: client)
      next if cleaned == ticket.message

      # update_column: this is a text fix-up, not a change anyone should be
      # emailed or DM'd about.
      ticket.update_column(:message, cleaned)
      changed += 1
      puts "  ##{ticket.id} #{ticket.title.truncate(60)}"
    end

    puts "Rewrote #{changed} of #{Ticket.count} tickets."
  end
end

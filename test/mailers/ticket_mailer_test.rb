require "test_helper"

class TicketMailerTest < ActionMailer::TestCase
  test "created notifies admins" do
    mail = TicketMailer.created(tickets(:website_bug))

    assert_equal User.admin_emails, mail.to
    assert_match tickets(:website_bug).title, mail.subject
  end

  test "status_changed notifies the requester" do
    mail = TicketMailer.status_changed(tickets(:website_bug))

    assert_equal [ tickets(:website_bug).user.email ], mail.to
  end
end

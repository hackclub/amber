require "test_helper"

class TicketsControllerTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    get "/auth/developer/callback", params: { name: user.name, email: user.email }
  end

  test "creating a ticket enqueues a notification email" do
    sign_in(users(:requester))

    assert_enqueued_emails 1 do
      post tickets_path, params: {
        ticket: {
          title: "Something is broken",
          service_id: services(:website).id,
          topic_id: topics(:bug).id,
          message: "Please help"
        }
      }
    end

    assert_redirected_to ticket_path(Ticket.last)
  end

  test "a non-owner cannot view someone else's ticket" do
    other_user = User.create!(sub: "sub_other", email: "other@example.com", name: "Other")
    sign_in(other_user)

    get ticket_path(tickets(:website_bug))

    assert_redirected_to root_path
  end

  test "the owner can view their own ticket" do
    sign_in(users(:requester))

    get ticket_path(tickets(:website_bug))

    assert_response :success
  end

  test "an admin can attach a note to a status change" do
    sign_in(users(:amber))
    ticket = tickets(:website_bug)

    patch ticket_path(ticket), params: { ticket: { status: "done", status_note: "Shipped this morning." } }

    ticket.reload
    assert ticket.done?
    assert_equal "Shipped this morning.", ticket.status_note
  end

  test "a status change without a note clears a stale one" do
    sign_in(users(:amber))
    ticket = tickets(:website_bug)
    ticket.update!(status_note: "An old note")

    patch ticket_path(ticket), params: { ticket: { status: "in_progress" } }

    assert_nil ticket.reload.status_note
  end

  test "a non-admin cannot change a ticket's status" do
    sign_in(users(:requester))
    ticket = tickets(:website_bug)

    patch ticket_path(ticket), params: { ticket: { status: "done" } }

    refute ticket.reload.done?
  end
end

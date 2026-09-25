require "test_helper"

class TicketDeadlinesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  def sign_in(user)
    get "/auth/developer/callback", params: { name: user.name, email: user.email }
  end

  test "an admin can set a deadline without reloading the page" do
    sign_in(users(:amber))
    ticket = tickets(:website_bug)

    patch ticket_deadline_path(ticket),
          params: { ticket: { due_at: "2026-10-01T17:00" } },
          as: :turbo_stream

    assert_response :success
    assert_equal Time.zone.local(2026, 10, 1, 17, 0), ticket.reload.due_at
    assert_match dom_id(ticket, :badges), response.body
    assert_match "queue", response.body
  end

  test "an admin can clear a deadline" do
    sign_in(users(:amber))
    ticket = tickets(:website_bug)
    ticket.update!(due_at: 1.day.from_now)

    delete ticket_deadline_path(ticket), as: :turbo_stream

    assert_response :success
    assert_nil ticket.reload.due_at
  end

  test "submitting an empty deadline clears it too" do
    sign_in(users(:amber))
    ticket = tickets(:website_bug)
    ticket.update!(due_at: 1.day.from_now)

    patch ticket_deadline_path(ticket), params: { ticket: { due_at: "" } }

    assert_nil ticket.reload.due_at
  end

  test "a requester cannot set a deadline, even on their own ticket" do
    sign_in(users(:requester))
    ticket = tickets(:website_bug)

    patch ticket_deadline_path(ticket), params: { ticket: { due_at: "2026-10-01T17:00" } }

    assert_redirected_to root_path
    assert_nil ticket.reload.due_at
  end

  test "changing a deadline notifies nobody" do
    sign_in(users(:amber))

    assert_no_enqueued_emails do
      patch ticket_deadline_path(tickets(:website_bug)), params: { ticket: { due_at: "2026-10-01T17:00" } }
    end
  end
end

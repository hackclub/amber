require "test_helper"

class TicketNotesControllerTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    get "/auth/developer/callback", params: { name: user.name, email: user.email }
  end

  test "an admin can add a note from the ticket page" do
    ticket = tickets(:website_bug)
    sign_in(users(:amber))

    assert_difference -> { ticket.notes.count }, 1 do
      post ticket_notes_path(ticket), params: { ticket_note: { body: "Chased this on Tuesday" } }
    end

    assert_redirected_to ticket_path(ticket)
    assert_equal users(:amber), ticket.notes.last.author
  end

  test "a blank note is rejected without a crash" do
    ticket = tickets(:website_bug)
    sign_in(users(:amber))

    assert_no_difference -> { ticket.notes.count } do
      post ticket_notes_path(ticket), params: { ticket_note: { body: "  " } }
    end

    assert_redirected_to ticket_path(ticket)
    assert flash[:alert].present?
  end

  test "the requester can't add notes to their own ticket" do
    ticket = tickets(:website_bug)
    sign_in(users(:requester))

    assert_no_difference -> { ticket.notes.count } do
      post ticket_notes_path(ticket), params: { ticket_note: { body: "let me in" } }
    end

    assert_redirected_to root_path
  end

  test "the requester never sees notes on their own ticket page" do
    ticket = tickets(:website_bug)
    ticket.notes.create!(body: "Privately annoyed about this", author: users(:amber))
    sign_in(users(:requester))

    get ticket_path(ticket)

    assert_response :success
    assert_no_match(/Privately annoyed about this/, response.body)
    assert_no_match(/Internal notes/, response.body)
  end

  test "an admin sees the notes on the ticket page" do
    ticket = tickets(:website_bug)
    ticket.notes.create!(body: "Privately annoyed about this", author: users(:amber))
    sign_in(users(:amber))

    get ticket_path(ticket)

    assert_match "Privately annoyed about this", response.body
    assert_match "Internal notes", response.body
  end

  test "an admin can delete a note" do
    ticket = tickets(:website_bug)
    note = ticket.notes.create!(body: "never mind", author: users(:amber))
    sign_in(users(:amber))

    assert_difference -> { ticket.notes.count }, -1 do
      delete ticket_note_path(ticket, note)
    end

    assert_redirected_to ticket_path(ticket)
  end

  test "notes go away with their ticket" do
    ticket = tickets(:website_bug)
    ticket.notes.create!(body: "gone soon", author: users(:amber))

    assert_difference -> { TicketNote.count }, -1 do
      ticket.destroy
    end
  end
end

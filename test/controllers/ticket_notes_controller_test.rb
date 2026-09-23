require "test_helper"

class TicketNotesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

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

  test "adding a note over turbo streams the note in without a redirect" do
    ticket = tickets(:website_bug)
    sign_in(users(:amber))

    post ticket_notes_path(ticket), params: { ticket_note: { body: "Chased ops" } }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match %(action="append" target="#{dom_id(ticket, :notes)}"), response.body
    assert_match %(action="replace" target="#{dom_id(ticket, :note_form)}"), response.body
    assert_match "Chased ops", response.body
  end

  test "a blank note over turbo reports the error without appending" do
    ticket = tickets(:website_bug)
    sign_in(users(:amber))

    post ticket_notes_path(ticket), params: { ticket_note: { body: "" } }, as: :turbo_stream

    assert_response :success
    assert_no_match(/action="append"/, response.body)
    assert_match %(target="flash"), response.body
    assert_match "can&#39;t be blank", response.body
  end

  test "deleting a note over turbo removes just that note" do
    ticket = tickets(:website_bug)
    note = ticket.notes.create!(body: "never mind", author: users(:amber))
    sign_in(users(:amber))

    delete ticket_note_path(ticket, note), as: :turbo_stream

    assert_response :success
    assert_match %(action="remove" target="#{dom_id(note)}"), response.body
  end

  test "notes go away with their ticket" do
    ticket = tickets(:website_bug)
    ticket.notes.create!(body: "gone soon", author: users(:amber))

    assert_difference -> { TicketNote.count }, -1 do
      ticket.destroy
    end
  end
end

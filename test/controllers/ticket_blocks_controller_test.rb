require "test_helper"

class TicketBlocksControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  def sign_in(user)
    get "/auth/developer/callback", params: { name: user.name, email: user.email }
  end

  def other_ticket(title = "Something else")
    Ticket.create!(user: users(:requester), service: services(:website), topic: topics(:bug),
                   title: title, message: "Details here.")
  end

  test "an admin can link a ticket to what it's waiting on" do
    sign_in(users(:amber))
    ticket = tickets(:website_bug)
    blocker = other_ticket

    assert_difference -> { TicketBlock.count } do
      post ticket_blocks_path(ticket), params: { blocker_ticket_id: blocker.id }, as: :turbo_stream
    end

    assert_response :success
    assert_equal [ blocker ], ticket.reload.blockers
    assert_match dom_id(ticket, :scheduling), response.body
  end

  test "an admin can unlink one" do
    sign_in(users(:amber))
    ticket = tickets(:website_bug)
    link = ticket.blocked_links.create!(blocker_ticket: other_ticket)

    assert_difference -> { TicketBlock.count }, -1 do
      delete ticket_block_path(ticket, link), as: :turbo_stream
    end

    assert_response :success
    assert_empty ticket.reload.blockers
  end

  test "a link that would close a loop is refused with an explanation" do
    sign_in(users(:amber))
    ticket = tickets(:website_bug)
    blocker = other_ticket
    ticket.blocked_links.create!(blocker_ticket: blocker)

    assert_no_difference -> { TicketBlock.count } do
      post ticket_blocks_path(blocker), params: { blocker_ticket_id: ticket.id }, as: :turbo_stream
    end

    assert_response :success
    assert_match "would create a loop", response.body
  end

  test "a requester cannot link tickets" do
    sign_in(users(:requester))

    assert_no_difference -> { TicketBlock.count } do
      post ticket_blocks_path(tickets(:website_bug)), params: { blocker_ticket_id: other_ticket.id }
    end

    assert_redirected_to root_path
  end
end

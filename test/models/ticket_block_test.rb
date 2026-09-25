require "test_helper"

class TicketBlockTest < ActiveSupport::TestCase
  def ticket(title)
    Ticket.create!(
      user: users(:requester), service: services(:website), topic: topics(:bug),
      title: title, message: "Details here."
    )
  end

  test "a ticket can wait on another" do
    x = ticket("x")
    y = ticket("y")

    assert x.blocked_links.create(blocker_ticket: y).persisted?
    assert_equal [ y ], x.reload.blockers
    assert_equal [ x ], y.reload.blocking
  end

  test "a ticket can't wait on itself" do
    x = ticket("x")
    link = x.blocked_links.new(blocker_ticket: x)

    refute link.valid?
    assert_includes link.errors[:blocker_ticket], "can't block itself"
  end

  test "the same link can't be added twice" do
    x = ticket("x")
    y = ticket("y")
    x.blocked_links.create!(blocker_ticket: y)

    link = x.blocked_links.new(blocker_ticket: y)

    refute link.valid?
    assert_includes link.errors[:blocker_ticket_id], "is already blocking this ticket"
  end

  test "a chain is fine: x waits on y waits on f" do
    x = ticket("x")
    y = ticket("y")
    f = ticket("f")

    x.blocked_links.create!(blocker_ticket: y)

    assert y.blocked_links.create(blocker_ticket: f).persisted?
    assert x.reload.blocked_by_transitively?(f)
  end

  test "a loop is rejected, however long the chain" do
    x = ticket("x")
    y = ticket("y")
    f = ticket("f")
    x.blocked_links.create!(blocker_ticket: y)
    y.blocked_links.create!(blocker_ticket: f)

    link = f.blocked_links.new(blocker_ticket: x)

    refute link.valid?
    assert_match(/would create a loop/, link.errors[:blocker_ticket].to_sentence)
  end

  test "the loop message names both ends of the chain" do
    x = ticket("x")
    y = ticket("y")
    x.blocked_links.create!(blocker_ticket: y)

    link = y.blocked_links.new(blocker_ticket: x)
    link.valid?

    assert_match(/##{x.id}/, link.errors[:blocker_ticket].to_sentence)
    assert_match(/##{y.id}/, link.errors[:blocker_ticket].to_sentence)
  end

  test "deleting a ticket takes its links with it" do
    x = ticket("x")
    y = ticket("y")
    x.blocked_links.create!(blocker_ticket: y)

    assert_difference -> { TicketBlock.count }, -1 do
      y.destroy
    end
  end
end

require "test_helper"

class TicketTest < ActiveSupport::TestCase
  def valid_attributes
    {
      user: users(:requester),
      service: services(:website),
      topic: topics(:bug),
      title: "Something broke",
      message: "Details here."
    }
  end

  test "valid with required attributes" do
    assert Ticket.new(valid_attributes).valid?
  end

  test "invalid when topic does not belong to the selected service" do
    ticket = Ticket.new(valid_attributes.merge(topic: topics(:access_request)))

    refute ticket.valid?
    assert_includes ticket.errors[:topic], "must belong to the selected service"
  end

  test "invalid with a non-http(s) url" do
    ticket = Ticket.new(valid_attributes.merge(url: "not a url"))

    refute ticket.valid?
    assert ticket.errors[:url].present?
  end

  test "valid with a blank url" do
    ticket = Ticket.new(valid_attributes.merge(url: ""))

    assert ticket.valid?
  end

  test "defaults to medium priority and open status" do
    ticket = Ticket.create!(valid_attributes)

    assert ticket.medium?
    assert ticket.open?
  end
end

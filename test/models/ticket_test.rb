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

  test "defaults to low priority and open status" do
    ticket = Ticket.create!(valid_attributes)

    assert ticket.low?
    assert ticket.open?
  end

  test "the database default matches the model default" do
    ticket = Ticket.create!(valid_attributes)

    assert_equal Ticket.columns_hash["priority"].default.to_i, Ticket.priorities[ticket.priority]
  end

  test "wont do is a closed state, so it drops off the queue" do
    ticket = Ticket.create!(valid_attributes)
    assert_includes Ticket.needs_attention, ticket

    ticket.update!(status: :wont_do)

    refute_includes Ticket.needs_attention, ticket
    assert_includes Ticket.needs_attention, Ticket.create!(valid_attributes)
  end

  test "every status reads as a sentence" do
    ticket = Ticket.new(valid_attributes)

    Ticket.statuses.each_key do |status|
      ticket.status = status
      assert ticket.status_sentence.present?
      refute_match(/_/, ticket.status_sentence, "#{status} still reads like an enum key")
    end

    ticket.status = :wont_do
    assert_equal "closed — won't do", ticket.status_sentence
    assert_equal "Won't do", ticket.status_label
  end

  test "every status has a label that isn't just the enum key" do
    Ticket.statuses.each_key do |status|
      label = Ticket.status_label(status)
      assert label.present?
      refute_match(/_/, label, "#{status} has no proper label")
    end

    # humanize would give "Wont do" — the apostrophe is why labels are mapped.
    assert_equal "Won't do", Ticket.status_label(:wont_do)
    assert_includes Ticket.status_options, [ "Won't do", "wont_do" ]
  end

  test "closing as wont do still notifies the requester" do
    ticket = Ticket.create!(valid_attributes)

    assert_enqueued_emails 1 do
      assert_enqueued_with job: SlackNotificationJob, args: [ ticket.id, "status_changed" ] do
        ticket.update!(status: :wont_do)
      end
    end
  end

  test "creating a ticket notifies by email and Slack" do
    assert_enqueued_emails 1 do
      assert_enqueued_with job: SlackNotificationJob do
        Ticket.create!(valid_attributes)
      end
    end
  end

  test "changing status notifies the requester by email and Slack" do
    ticket = Ticket.create!(valid_attributes)

    assert_enqueued_emails 1 do
      assert_enqueued_with job: SlackNotificationJob, args: [ ticket.id, "status_changed" ] do
        ticket.update!(status: :done)
      end
    end
  end

  test "editing something other than status does not notify" do
    ticket = Ticket.create!(valid_attributes)

    assert_no_enqueued_emails do
      ticket.update!(title: "A different title")
    end
  end
end

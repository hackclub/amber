# Feeds the per-request query counter in the page footer.
ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, start, finish, _id, payload|
  next if payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) || payload[:cached]

  Current.record_query((finish - start) * 1000)
end

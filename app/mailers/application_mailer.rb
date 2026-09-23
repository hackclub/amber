class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM", "tickets@hackclub.com") }
  layout "mailer"
  helper :application
end

# Tickets

A small internal ticket tracker: anyone signs in with Hack Club Auth, files a
ticket (service, topic, priority, a markdown message), and gets emailed when
its status changes. The admin dashboard (anyone listed in `ADMIN_EMAILS`)
shows every open/in-progress ticket, sorted with VIP requesters and higher
priority first.

## Stack

Rails 8.1, PostgreSQL, Tailwind (via `tailwindcss-rails`, no Node needed),
Solid Queue for background email delivery, OmniAuth + Hack Club Auth (OIDC)
for sign-in.

## Setup

```
bin/setup        # bundle install, db:prepare
cp .env.example .env
bin/dev          # Rails server + Tailwind watcher
```

Visit `http://localhost:3000`. With no `HACKCLUB_AUTH_CLIENT_ID` set, sign-in
uses a local-only `:developer` strategy (type any name/email) instead of the
real Hack Club Auth flow — handy for developing without registering an app
first. Notification emails pop open in your browser via `letter_opener`
instead of requiring real SMTP credentials.

## Going live with real Hack Club Auth

1. Register an app at https://auth.hackclub.com/developer/apps.
2. Set its redirect URI to `https://<your-host>/auth/hackclub/callback`.
3. Set `HACKCLUB_AUTH_CLIENT_ID`, `HACKCLUB_AUTH_CLIENT_SECRET`, and
   `HACKCLUB_AUTH_REDIRECT_URI` (see `.env.example`).

Once `HACKCLUB_AUTH_CLIENT_ID` is present, the app always uses the real OIDC
strategy in every environment except test.

## Configuring services & topics

Services and topics (each topic belongs to one service) are managed from
`/admin/services` and `/admin/topics` by anyone in `ADMIN_EMAILS` — no code
changes needed to add or retire a category. `db/seeds.rb` creates a starter
set.

## Email

Development uses `letter_opener`. Production sends via SMTP — set
`SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_DOMAIN`, `SMTP_USER_NAME`, `SMTP_PASSWORD`.

## Tests

```
bin/rails test
```

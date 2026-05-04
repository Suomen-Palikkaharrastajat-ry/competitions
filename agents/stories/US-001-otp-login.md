# US-001: OTP Email Login

**As a participant or reviewer,** I want to log in using only my email address and a one-time code, so that I do not need to create or remember a password.

## Acceptance Criteria

- [ ] Given I am on the login page, when I enter a local-only email and click "Lähetä kirjautumiskoodi", then PocketBase sends a 6-digit OTP to that email address.
- [ ] Given my email belongs to a `keycloak_users` record, when I request OTP, then the request fails with `keycloak_required` and I am directed to Keycloak login.
- [ ] Given I have received the OTP, when I enter the correct 6-digit code, then I am logged in and my name appears in the header.
- [ ] Given I enter an incorrect OTP, when I submit, then an error message "Väärä koodi tai vanhentunut linkki" is shown and I can try again.
- [ ] Given I have logged in, when I reload the page, then I am still logged in (auth token persisted in localStorage).
- [ ] Given I am logged in, when I click "Kirjaudu ulos", then my token is removed and I am returned to the login page.
- [ ] Given I am a reviewer (`is_reviewer = true`), when I log in, then I see the "Arvosteltavat" nav item that regular participants do not see.

## Notes

- OTP length: 6 digits. Expiry: 10 minutes.
- Email/password auth is disabled — no password field anywhere in the UI.
- First local OTP login creates or links a `local_users` record and a shared `profiles` record.
- Keycloak OIDC login creates or links a `keycloak_users` record and the same shared `profiles` identity.
- User must set `display_name` on first login (prompt after OTP success if `display_name` is empty).

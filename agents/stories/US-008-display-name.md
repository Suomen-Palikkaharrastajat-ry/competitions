# US-008: Set Display Name on First Login

**As a new user,** I want to set my public display name after logging in for the first time, so that my name appears correctly in the gallery and on my entries.

## Acceptance Criteria

- [ ] Given I have just logged in for the first time, when PocketBase responds with an auth record whose linked profile has an empty `display_name`, then I am shown a "Valitse näyttönimi" prompt before reaching the dashboard.
- [ ] Given I enter a display name and click "Tallenna", when the update succeeds, then I am taken to the dashboard and my display name is shown in the header.
- [ ] Given I try to save with an empty display name, then a validation error "Näyttönimi on pakollinen" is shown.
- [ ] Given my display name is already set, when I log in, then the name prompt is skipped and I go directly to the dashboard.
- [ ] Given I am logged in, when I open account settings, then I can update my display name.

## Notes

- Display name is stored in `profiles.display_name` and copied to the active auth record for access-rule convenience.
- The display name shown in the gallery is `display_name`; if `anonymize_submitters = true`, it is hidden anyway.
- Account settings page is not a separate route in MVP — a simple edit inline in the header or a `/settings` page stub is sufficient.

# US-003: Submit a MOC Entry

**As a participant,** I want to submit my MOC to a competition by providing a title, description, and photos, so that reviewers can evaluate it.

## Acceptance Criteria

- [ ] Given I am on the entry submission form, when I fill in the title and add at least one image, then the "Lähetä arvosteltavaksi" button is enabled.
- [ ] Given I click "Tallenna luonnos", when the save succeeds, then the form remains open and a success notification shows "Luonnos tallennettu."
- [ ] Given I have a saved draft, when I navigate away and return to "Omat osallistumiset", then my draft is listed with a "Luonnos" badge.
- [ ] Given I click "Lähetä arvosteltavaksi", when I confirm the submission dialog, then the entry status changes to `submitted` and a success message is shown.
- [ ] Given an entry is in `submitted` status, when I view "Omat osallistumiset", then the "Muokkaa" and "Lähetä" buttons are hidden (editing locked).
- [ ] Given I try to submit without a title, when I click "Lähetä", then a validation error "Nimi on pakollinen" is shown.
- [ ] Given I try to submit with no images, when I click "Lähetä", then a validation error "Lisää vähintään yksi kuva" is shown.
- [ ] Given I add more than 10 images, when I try to add an 11th, then the file input is disabled and a note "Enintään 10 kuvaa" is shown.
- [ ] Given I am on the submission form, I can remove individual images from the selection before saving.
- [ ] Given the competition's end_date has passed, when I try to submit, then an error "Kilpailun ilmoittautumisaika on umpeutunut" is shown.

## Notes

- Images: JPEG, PNG, WebP only. Max 10 MB per image. Max 10 images per entry.
- Draft auto-save is optional but recommended. MVP: explicit "Tallenna luonnos" button.
- The submission confirmation dialog must clearly warn that editing is not possible after submission.

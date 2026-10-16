module I18n exposing (MsgKey(..), t, translate)

{-| Internationalization for the competition platform: every display text of the
app, in each language.
-}

import Lang exposing (Lang(..))


{-| Translation keys
-}
type MsgKey
    = SkipToContent
    | Competition
    | Participants
    | Review
    | LogIn
    | LogOut
    | Submit
    | OrgName
    | NavCompetitions
    | MyEntries
    | NavReview
    | EmailLabel
    | EmailPlaceholder
    | SendCode
    | KeycloakLogin
    | CodeHint
    | CheckEmailTitle
    | CodeSentTo
    | CodeLabel
    | LoginSubmit
    | ChangeAddress
    | DisplayNameTitle
    | DisplayNameLabel
    | Save
    | AdminLinkLabel
    | AdminLinkText
    | NoAccess
    | PageNotFound
    | OpenCompetitions
    | CompetitionsLoadFailed
    | NoOpenCompetitions
    | NoCoverImage
    | ThemePrefix
    | EndsPrefix
    | Participate
    | Loading
    | LoadFailed
    | NoEntries
    | NewEntry
    | Edit
    | ScorePrefix
    | StatusDraft
    | StatusSubmitted
    | StatusApproved
    | StatusRejected
    | EntrySubmitted
    | EntrySubmittedBody
    | ParticipateIn
    | NameLabel
    | NamePlaceholder
    | DescriptionLabel
    | DescriptionPlaceholder
    | ImagesLabelStart
    | ImagesLabelEnd
    | ImagesSuffix
    | NoEditAfterSubmit
    | Saving
    | SaveDraft
    | SubmitForReview
    | ReviewQueueTitle
    | FilterAll
    | NotYetReviewed
    | EditReview
    | Rate
    | ApproveEntryPrefix
    | Approve
    | RejectEntryPrefix
    | Reject
    | ReviewPrefix
    | CloseReviewForm
    | ScoreTheme
    | ScoreOriginality
    | ScoreTechnique
    | ScorePresentation
    | TotalScore
    | CommentLabel
    | SaveAndPublish
    | StarPrefix
    | StarSuffix
    | ErrorPrefix
    | ErrKeycloakOnly
    | ErrEmailSendFailed
    | ErrWrongCode
    | ErrLoginFailed
    | ErrKeycloakLoginFailed
    | ErrDisplayNameSave
    | ErrDraftSave
    | ErrSubmitFailed
    | ErrNoCompetitionSelected
    | ErrCompetitionLoad
    | ErrDraftNotFound
    | ErrReviewSave
    | ErrStatusChange
    | ErrInvalidEmail
    | ErrOtpFormat
    | ErrNameRequired
    | ErrNameTooLong
    | ErrAddOneImage
    | AddAtLeastPrefix
    | AtMostPrefix
    | AtMostSuffix
    | HttpNetwork
    | HttpSessionExpired
    | HttpForbidden
    | HttpNotFound
    | HttpUnexpected


{-| The text of a key in the given language.
-}
t : Lang -> MsgKey -> String
t lang key =
    case lang of
        Fi ->
            fi key

        En ->
            en key


{-| Alias of `t`, kept for the callers that used the earlier name.
-}
translate : Lang -> MsgKey -> String
translate =
    t


fi : MsgKey -> String
fi key =
    case key of
        SkipToContent ->
            "Siirry pääsisältöön"

        Competition ->
            "Kilpailu"

        Participants ->
            "Osallistujat"

        Review ->
            "Arvostelu"

        LogIn ->
            "Kirjaudu sisään"

        LogOut ->
            "Kirjaudu ulos"

        Submit ->
            "Lähetä"

        OrgName ->
            "Suomen Palikkaharrastajat ry"

        NavCompetitions ->
            "Kilpailut"

        MyEntries ->
            "Omat osallistumiset"

        NavReview ->
            "Arvosteltavat"

        EmailLabel ->
            "Sähköpostiosoite"

        EmailPlaceholder ->
            "sinä@example.com"

        SendCode ->
            "Lähetä kirjautumiskoodi"

        KeycloakLogin ->
            "Kirjaudu Keycloakilla"

        CodeHint ->
            "Saat 6-numeroisen koodin sähköpostiisi."

        CheckEmailTitle ->
            "Tarkista sähköpostisi"

        CodeSentTo ->
            "Koodi lähetetty: "

        CodeLabel ->
            "Kirjautumiskoodi"

        LoginSubmit ->
            "Kirjaudu"

        ChangeAddress ->
            "← Vaihda osoite"

        DisplayNameTitle ->
            "Valitse näyttönimi"

        DisplayNameLabel ->
            "Näyttönimi"

        Save ->
            "Tallenna"

        AdminLinkLabel ->
            "Kilpailujen hallinta: "

        AdminLinkText ->
            "Admin UI →"

        NoAccess ->
            "Ei oikeutta."

        PageNotFound ->
            "Sivua ei löydy."

        OpenCompetitions ->
            "Avoimet kilpailut"

        CompetitionsLoadFailed ->
            "Kilpailujen lataus epäonnistui."

        NoOpenCompetitions ->
            "Ei avoimia kilpailuja."

        NoCoverImage ->
            "Ei kansikuvaa"

        ThemePrefix ->
            "Teema: "

        EndsPrefix ->
            "Päättyy: "

        Participate ->
            "Osallistu →"

        Loading ->
            "Ladataan…"

        LoadFailed ->
            "Lataus epäonnistui."

        NoEntries ->
            "Ei osallistumisia."

        NewEntry ->
            "+ Uusi osallistuminen"

        Edit ->
            "Muokkaa"

        ScorePrefix ->
            "Pisteet: "

        StatusDraft ->
            "Luonnos"

        StatusSubmitted ->
            "Lähetetty"

        StatusApproved ->
            "Hyväksytty"

        StatusRejected ->
            "Hylätty"

        EntrySubmitted ->
            "Osallistuminen lähetetty!"

        EntrySubmittedBody ->
            "Osallistumisesi on lähetetty arvioitavaksi. Näet sen Omat osallistumiset -sivulla."

        ParticipateIn ->
            "Osallistu kilpailuun: "

        NameLabel ->
            "Nimi *"

        NamePlaceholder ->
            "MOC:n nimi"

        DescriptionLabel ->
            "Kuvaus"

        DescriptionPlaceholder ->
            "Kerro MOC:stasi..."

        ImagesLabelStart ->
            "Kuvat * ("

        ImagesLabelEnd ->
            ", jpg/png/webp, max 10 MB/kuva)"

        ImagesSuffix ->
            " kuvaa"

        NoEditAfterSubmit ->
            "ℹ Lähettämisen jälkeen muokkaus ei ole mahdollista."

        Saving ->
            "Tallennetaan..."

        SaveDraft ->
            "Tallenna luonnos"

        SubmitForReview ->
            "Lähetä arvosteltavaksi"

        ReviewQueueTitle ->
            "Arvosteltavat osallistumiset"

        FilterAll ->
            "Kaikki"

        NotYetReviewed ->
            "Ei vielä arvosteltu"

        EditReview ->
            "Muokkaa arvostelua"

        Rate ->
            "Arvioi"

        ApproveEntryPrefix ->
            "Hyväksy osallistuminen: "

        Approve ->
            "Hyväksy"

        RejectEntryPrefix ->
            "Hylkää osallistuminen: "

        Reject ->
            "Hylkää"

        ReviewPrefix ->
            "Arvostele: "

        CloseReviewForm ->
            "Sulje arvostelulomake"

        ScoreTheme ->
            "Teema-vastaavuus"

        ScoreOriginality ->
            "Omaperäisyys"

        ScoreTechnique ->
            "Rakennustekniikka"

        ScorePresentation ->
            "Esitys (kuvat)"

        TotalScore ->
            "Kokonaispisteet: "

        CommentLabel ->
            "Kommentti"

        SaveAndPublish ->
            "Tallenna ja julkaise"

        StarPrefix ->
            "Arvo "

        StarSuffix ->
            " viidestä"

        ErrorPrefix ->
            "Virhe: "

        ErrKeycloakOnly ->
            "Kirjaudu tällä osoitteella Keycloakin kautta"

        ErrEmailSendFailed ->
            "Sähköpostin lähetys epäonnistui"

        ErrWrongCode ->
            "Väärä koodi tai vanhentunut linkki"

        ErrLoginFailed ->
            "Kirjautuminen epäonnistui"

        ErrKeycloakLoginFailed ->
            "Keycloak-kirjautuminen epäonnistui"

        ErrDisplayNameSave ->
            "Näyttönimen tallennus epäonnistui"

        ErrDraftSave ->
            "Luonnoksen tallennus epäonnistui"

        ErrSubmitFailed ->
            "Lähettäminen epäonnistui"

        ErrNoCompetitionSelected ->
            "Kilpailua ei ole valittu"

        ErrCompetitionLoad ->
            "Kilpailun tietoja ei voitu ladata"

        ErrDraftNotFound ->
            "Luonnosta ei löytynyt"

        ErrReviewSave ->
            "Arvostelun tallennus epäonnistui"

        ErrStatusChange ->
            "Tilan vaihto epäonnistui"

        ErrInvalidEmail ->
            "Syötä kelvollinen sähköpostiosoite"

        ErrOtpFormat ->
            "Koodi koostuu kuudesta numerosta"

        ErrNameRequired ->
            "Nimi on pakollinen"

        ErrNameTooLong ->
            "Nimi on liian pitkä (max 200 merkkiä)"

        ErrAddOneImage ->
            "Lisää vähintään yksi kuva"

        AddAtLeastPrefix ->
            "Lisää vähintään "

        AtMostPrefix ->
            "Enintään "

        AtMostSuffix ->
            " kuvaa sallittu"

        HttpNetwork ->
            "Verkkovirhe — tarkista yhteys"

        HttpSessionExpired ->
            "Istunto vanhentunut — kirjaudu uudelleen"

        HttpForbidden ->
            "Ei oikeutta"

        HttpNotFound ->
            "Ei löydy"

        HttpUnexpected ->
            "Odottamaton virhe; yritä uudelleen"


en : MsgKey -> String
en key =
    case key of
        SkipToContent ->
            "Skip to main content"

        Competition ->
            "Competition"

        Participants ->
            "Participants"

        Review ->
            "Review"

        LogIn ->
            "Log in"

        LogOut ->
            "Log out"

        Submit ->
            "Submit"

        OrgName ->
            "Suomen Palikkaharrastajat ry"

        NavCompetitions ->
            "Competitions"

        MyEntries ->
            "My entries"

        NavReview ->
            "For review"

        EmailLabel ->
            "Email address"

        EmailPlaceholder ->
            "you@example.com"

        SendCode ->
            "Send login code"

        KeycloakLogin ->
            "Log in with Keycloak"

        CodeHint ->
            "You will receive a 6-digit code by email."

        CheckEmailTitle ->
            "Check your email"

        CodeSentTo ->
            "Code sent to: "

        CodeLabel ->
            "Login code"

        LoginSubmit ->
            "Log in"

        ChangeAddress ->
            "← Change address"

        DisplayNameTitle ->
            "Choose a display name"

        DisplayNameLabel ->
            "Display name"

        Save ->
            "Save"

        AdminLinkLabel ->
            "Competition management: "

        AdminLinkText ->
            "Admin UI →"

        NoAccess ->
            "No access."

        PageNotFound ->
            "Page not found."

        OpenCompetitions ->
            "Open competitions"

        CompetitionsLoadFailed ->
            "Loading competitions failed."

        NoOpenCompetitions ->
            "No open competitions."

        NoCoverImage ->
            "No cover image"

        ThemePrefix ->
            "Theme: "

        EndsPrefix ->
            "Ends: "

        Participate ->
            "Enter →"

        Loading ->
            "Loading…"

        LoadFailed ->
            "Loading failed."

        NoEntries ->
            "No entries."

        NewEntry ->
            "+ New entry"

        Edit ->
            "Edit"

        ScorePrefix ->
            "Score: "

        StatusDraft ->
            "Draft"

        StatusSubmitted ->
            "Submitted"

        StatusApproved ->
            "Approved"

        StatusRejected ->
            "Rejected"

        EntrySubmitted ->
            "Entry submitted!"

        EntrySubmittedBody ->
            "Your entry has been submitted for review. You can see it on the My entries page."

        ParticipateIn ->
            "Enter the competition: "

        NameLabel ->
            "Name *"

        NamePlaceholder ->
            "Name of the MOC"

        DescriptionLabel ->
            "Description"

        DescriptionPlaceholder ->
            "Tell us about your MOC..."

        ImagesLabelStart ->
            "Images * ("

        ImagesLabelEnd ->
            ", jpg/png/webp, max 10 MB/image)"

        ImagesSuffix ->
            " images"

        NoEditAfterSubmit ->
            "ℹ An entry cannot be edited after it has been submitted."

        Saving ->
            "Saving..."

        SaveDraft ->
            "Save draft"

        SubmitForReview ->
            "Submit for review"

        ReviewQueueTitle ->
            "Entries to review"

        FilterAll ->
            "All"

        NotYetReviewed ->
            "Not reviewed yet"

        EditReview ->
            "Edit review"

        Rate ->
            "Review"

        ApproveEntryPrefix ->
            "Approve entry: "

        Approve ->
            "Approve"

        RejectEntryPrefix ->
            "Reject entry: "

        Reject ->
            "Reject"

        ReviewPrefix ->
            "Review: "

        CloseReviewForm ->
            "Close the review form"

        ScoreTheme ->
            "Fit to the theme"

        ScoreOriginality ->
            "Originality"

        ScoreTechnique ->
            "Building technique"

        ScorePresentation ->
            "Presentation (images)"

        TotalScore ->
            "Total score: "

        CommentLabel ->
            "Comment"

        SaveAndPublish ->
            "Save and publish"

        StarPrefix ->
            "Score "

        StarSuffix ->
            " out of five"

        ErrorPrefix ->
            "Error: "

        ErrKeycloakOnly ->
            "Log in with this address through Keycloak"

        ErrEmailSendFailed ->
            "Sending the email failed"

        ErrWrongCode ->
            "Wrong code or expired link"

        ErrLoginFailed ->
            "Login failed"

        ErrKeycloakLoginFailed ->
            "Keycloak login failed"

        ErrDisplayNameSave ->
            "Saving the display name failed"

        ErrDraftSave ->
            "Saving the draft failed"

        ErrSubmitFailed ->
            "Submitting failed"

        ErrNoCompetitionSelected ->
            "No competition has been selected"

        ErrCompetitionLoad ->
            "The competition could not be loaded"

        ErrDraftNotFound ->
            "Draft not found"

        ErrReviewSave ->
            "Saving the review failed"

        ErrStatusChange ->
            "Changing the status failed"

        ErrInvalidEmail ->
            "Enter a valid email address"

        ErrOtpFormat ->
            "The code consists of six digits"

        ErrNameRequired ->
            "Name is required"

        ErrNameTooLong ->
            "Name is too long (max 200 characters)"

        ErrAddOneImage ->
            "Add at least one image"

        AddAtLeastPrefix ->
            "Add at least "

        AtMostPrefix ->
            "At most "

        AtMostSuffix ->
            " images allowed"

        HttpNetwork ->
            "Network error — check your connection"

        HttpSessionExpired ->
            "Session expired — log in again"

        HttpForbidden ->
            "No access"

        HttpNotFound ->
            "Not found"

        HttpUnexpected ->
            "Unexpected error; try again"

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
    | NavAdmin
    | AdminPocketBaseLink
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
    | CompressingImages
    | ImagesOptimizedWebP
    | ErrImageCompression
    | ErrImageCompressionGeneric
    | ErrExcessImagesDropped
    | RemoveFile
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
    | DraftSavedNotice
    | ConfirmSubmitTitle
    | ConfirmSubmitBody
    | ConfirmSubmitYes
    | Cancel
    | MaxEntriesUsed
    | ReviewerCommentPrefix
    | ChangesSavedNotice
    | SaveChanges
    | ErrEditClosed
    | EntryNotFound
    | EditableUntilDeadline
    | PeriodPrefix
    | PeriodTo
    | AdminHeading
    | AdminNewCompetition
    | AdminEntries
    | AdminNoCompetitions
    | CompetitionStatusDraft
    | CompetitionStatusOpen
    | CompetitionStatusClosed
    | CompetitionStatusJudging
    | CompetitionStatusFinished
    | AdminFormNew
    | AdminFormEdit
    | AdminFieldTitle
    | AdminFieldSlug
    | AdminFieldTheme
    | AdminFieldDescription
    | AdminFieldStart
    | AdminFieldEnd
    | AdminFieldJudging
    | AdminFieldMaxEntries
    | AdminFieldMinImages
    | AdminFieldMaxImages
    | AdminFieldStatus
    | AdminSave
    | AdminSaving
    | AdminErrTitle
    | AdminErrSlug
    | AdminErrDate
    | AdminErrEndBeforeStart
    | AdminErrMaxEntries
    | AdminErrImageLimits
    | AdminErrServer
    | AdminMoveTo
    | AdminNotFound
    | AdminImagesCount
    | AdminPublishedReviews
    | AdminApprove
    | AdminReject
    | AdminReset
    | VotingOpenHeading
    | Vote
    | VotingEndsPrefix
    | VoteHeading
    | VoteInstructions
    | VoteRequiredNote
    | VoteBallotHeading
    | VoteEmptySlot
    | VotePointsSuffix
    | VoteMoveUp
    | VoteMoveDown
    | VoteRemove
    | VoteCandidatesHeading
    | VotePick
    | VotePickedPrefix
    | VoteBallotFull
    | VoteSave
    | VoteSaving
    | VoteSaved
    | VoteUnsaved
    | VoteNoCandidates
    | VoteNotEnabled
    | ErrBallotLoad
    | ErrBallotEmpty
    | ErrBallotRejected
    | ErrBallotSave
    | AdminFieldVotingEnabled
    | AdminFieldVotingRequired
    | AdminFieldVotingStart
    | AdminFieldVotingEnd
    | AdminErrVotingDates
    | AdminVoteResultHeading
    | AdminBallotCount
    | AdminNotVoted


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

        NavAdmin ->
            "Ylläpito"

        AdminPocketBaseLink ->
            "PocketBase-hallinta (pääkäyttäjät) →"

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

        CompressingImages ->
            "Optimoidaan kuvia..."

        ImagesOptimizedWebP ->
            "Kuvat optimoidaan automaattisesti WebP-muotoon."

        ErrImageCompression ->
            "Kuvan pakkaus epäonnistui: "

        ErrImageCompressionGeneric ->
            "Kuvan pakkaus epäonnistui."

        ErrExcessImagesDropped ->
            "Kuvia valittiin enemmän kuin mahtuu. Vain ensimmäiset lisättiin."

        RemoveFile ->
            "Poista kuva"

        NoEditAfterSubmit ->
            "ℹ Lähettämisen jälkeen voit muokata osallistumista määräaikaan asti."

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

        DraftSavedNotice ->
            "Luonnos tallennettu."

        ConfirmSubmitTitle ->
            "Lähetetäänkö arvioitavaksi?"

        ConfirmSubmitBody ->
            "Lähettämisen jälkeen voit muokata osallistumista määräaikaan asti."

        ConfirmSubmitYes ->
            "Lähetä"

        Cancel ->
            "Peruuta"

        MaxEntriesUsed ->
            "Olet käyttänyt kaikki osallistumispaikkasi tässä kilpailussa."

        ReviewerCommentPrefix ->
            "Arvioijan kommentti: "

        ChangesSavedNotice ->
            "Muutokset tallennettu."

        SaveChanges ->
            "Tallenna muutokset"

        ErrEditClosed ->
            "Muokkaus ei ole enää mahdollista; kilpailun määräaika on umpeutunut."

        EntryNotFound ->
            "Osallistumista ei löytynyt."

        EditableUntilDeadline ->
            "Voit muokata osallistumista kilpailun määräaikaan asti."

        PeriodPrefix ->
            "Kilpailuaika: "

        PeriodTo ->
            " – "

        AdminHeading ->
            "Ylläpito"

        AdminNewCompetition ->
            "+ Uusi kilpailu"

        AdminEntries ->
            "Osallistumiset"

        AdminNoCompetitions ->
            "Ei kilpailuja."

        CompetitionStatusDraft ->
            "Luonnos"

        CompetitionStatusOpen ->
            "Avoin"

        CompetitionStatusClosed ->
            "Suljettu"

        CompetitionStatusJudging ->
            "Arvostelussa"

        CompetitionStatusFinished ->
            "Päättynyt"

        AdminFormNew ->
            "Uusi kilpailu"

        AdminFormEdit ->
            "Muokkaa kilpailua"

        AdminFieldTitle ->
            "Nimi"

        AdminFieldSlug ->
            "Tunniste (osoitteeseen)"

        AdminFieldTheme ->
            "Teema"

        AdminFieldDescription ->
            "Kuvaus"

        AdminFieldStart ->
            "Alkaa"

        AdminFieldEnd ->
            "Osallistumisen päättyy"

        AdminFieldJudging ->
            "Arvostelun päättyy"

        AdminFieldMaxEntries ->
            "Osallistumisia per osallistuja (tyhjä = oletus)"

        AdminFieldMinImages ->
            "Kuvia vähintään"

        AdminFieldMaxImages ->
            "Kuvia enintään"

        AdminFieldStatus ->
            "Tila"

        AdminSave ->
            "Tallenna"

        AdminSaving ->
            "Tallennetaan…"

        AdminErrTitle ->
            "Nimi on pakollinen."

        AdminErrSlug ->
            "Tunniste saa sisältää vain pieniä kirjaimia, numeroita ja väliviivoja."

        AdminErrDate ->
            "Päivämäärät muodossa VVVV-KK-PP."

        AdminErrEndBeforeStart ->
            "Päättymispäivän on oltava alkamispäivän jälkeen."

        AdminErrMaxEntries ->
            "Osallistumisten määrän on oltava nolla tai enemmän."

        AdminErrImageLimits ->
            "Kuvarajat: vähintään ≤ enintään, molemmat välillä 0–10."

        AdminErrServer ->
            "Tallennus ei onnistunut. Tarkista tiedot; tunniste ei saa olla käytössä."

        AdminMoveTo ->
            "Siirrä tilaan: "

        AdminNotFound ->
            "Kilpailua ei löytynyt."

        AdminImagesCount ->
            "Kuvia: "

        AdminPublishedReviews ->
            "Julkaistuja arvioita: "

        AdminApprove ->
            "Hyväksy"

        AdminReject ->
            "Hylkää"

        AdminReset ->
            "Palauta lähetetyksi"

        VotingOpenHeading ->
            "Äänestys käynnissä"

        Vote ->
            "Äänestä"

        VotingEndsPrefix ->
            "Äänestä viimeistään "

        VoteHeading ->
            "Äänestys"

        VoteInstructions ->
            "Valitse enintään viisi parasta työtä paremmuusjärjestyksessä. 1. sija saa 8 pistettä, 2. sija 5, 3. sija 3, 4. sija 2 ja 5. sija 1 pisteen. Voit muuttaa ääntäsi äänestyksen loppuun asti."

        VoteRequiredNote ->
            "Osallistujien on äänestettävä: jos osallistuja ei äänestä, hänen työnsä ei saa sijoitusta äänestyksen tuloksissa."

        VoteBallotHeading ->
            "Äänestyslistasi"

        VoteEmptySlot ->
            "Valitse työ alta"

        VotePointsSuffix ->
            " p"

        VoteMoveUp ->
            "Siirrä ylemmäs"

        VoteMoveDown ->
            "Siirrä alemmas"

        VoteRemove ->
            "Poista listalta"

        VoteCandidatesHeading ->
            "Kilpailun työt"

        VotePick ->
            "Valitse"

        VotePickedPrefix ->
            "Valittu sijalle "

        VoteBallotFull ->
            "Lista on täynnä"

        VoteSave ->
            "Tallenna ääni"

        VoteSaving ->
            "Tallennetaan…"

        VoteSaved ->
            "Äänesi on tallennettu."

        VoteUnsaved ->
            "Muutoksia ei ole vielä tallennettu."

        VoteNoCandidates ->
            "Kilpailussa ei ole vielä hyväksyttyjä töitä."

        VoteNotEnabled ->
            "Tässä kilpailussa ei äänestetä."

        ErrBallotLoad ->
            "Äänesi lataaminen epäonnistui. Lataa sivu uudelleen."

        ErrBallotEmpty ->
            "Valitse vähintään yksi työ."

        ErrBallotRejected ->
            "Ääntä ei hyväksytty: äänestys ei ole käynnissä, tai valittu työ ei ole enää mukana."

        ErrBallotSave ->
            "Äänen tallennus epäonnistui. Yritä uudelleen."

        AdminFieldVotingEnabled ->
            "Yleisöäänestys käytössä"

        AdminFieldVotingRequired ->
            "Osallistujien on äänestettävä"

        AdminFieldVotingStart ->
            "Äänestys alkaa"

        AdminFieldVotingEnd ->
            "Äänestys suljetaan (päivän alussa)"

        AdminErrVotingDates ->
            "Äänestykseen tarvitaan alku- ja loppupäivä, ja loppupäivän on oltava alun jälkeen."

        AdminVoteResultHeading ->
            "Äänestystulos"

        AdminBallotCount ->
            "Ääniä: "

        AdminNotVoted ->
            "Ei sijoitusta, koska osallistuja ei äänestänyt: "


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

        NavAdmin ->
            "Administration"

        AdminPocketBaseLink ->
            "PocketBase admin (superusers) →"

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

        CompressingImages ->
            "Optimizing images..."

        ImagesOptimizedWebP ->
            "Images are automatically optimized to WebP format."

        ErrImageCompression ->
            "Image compression failed: "

        ErrImageCompressionGeneric ->
            "Image compression failed."

        ErrExcessImagesDropped ->
            "More images were selected than allowed. Only the first were added."

        RemoveFile ->
            "Remove image"

        NoEditAfterSubmit ->
            "ℹ After submitting, you can edit the entry until the deadline."

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

        DraftSavedNotice ->
            "Draft saved."

        ConfirmSubmitTitle ->
            "Submit for review?"

        ConfirmSubmitBody ->
            "After submitting, you can edit the entry until the deadline."

        ConfirmSubmitYes ->
            "Submit"

        Cancel ->
            "Cancel"

        MaxEntriesUsed ->
            "You have used all your entries in this competition."

        ReviewerCommentPrefix ->
            "Reviewer's comment: "

        ChangesSavedNotice ->
            "Changes saved."

        SaveChanges ->
            "Save changes"

        ErrEditClosed ->
            "Editing is no longer possible; the competition deadline has passed."

        EntryNotFound ->
            "Entry not found."

        EditableUntilDeadline ->
            "You can edit this entry until the competition deadline."

        PeriodPrefix ->
            "Competition period: "

        PeriodTo ->
            " – "

        AdminHeading ->
            "Administration"

        AdminNewCompetition ->
            "+ New competition"

        AdminEntries ->
            "Entries"

        AdminNoCompetitions ->
            "No competitions."

        CompetitionStatusDraft ->
            "Draft"

        CompetitionStatusOpen ->
            "Open"

        CompetitionStatusClosed ->
            "Closed"

        CompetitionStatusJudging ->
            "Judging"

        CompetitionStatusFinished ->
            "Finished"

        AdminFormNew ->
            "New competition"

        AdminFormEdit ->
            "Edit competition"

        AdminFieldTitle ->
            "Name"

        AdminFieldSlug ->
            "Address name (slug)"

        AdminFieldTheme ->
            "Theme"

        AdminFieldDescription ->
            "Description"

        AdminFieldStart ->
            "Starts"

        AdminFieldEnd ->
            "Entries close"

        AdminFieldJudging ->
            "Judging ends"

        AdminFieldMaxEntries ->
            "Entries per participant (empty = default)"

        AdminFieldMinImages ->
            "Images at least"

        AdminFieldMaxImages ->
            "Images at most"

        AdminFieldStatus ->
            "Status"

        AdminSave ->
            "Save"

        AdminSaving ->
            "Saving…"

        AdminErrTitle ->
            "Name is required."

        AdminErrSlug ->
            "The address name may only contain lowercase letters, digits and dashes."

        AdminErrDate ->
            "Dates must be in the form YYYY-MM-DD."

        AdminErrEndBeforeStart ->
            "The end date must be after the start date."

        AdminErrMaxEntries ->
            "The number of entries must be zero or more."

        AdminErrImageLimits ->
            "Image limits: min ≤ max, both between 0 and 10."

        AdminErrServer ->
            "Saving failed. Check the details; the address name must not be in use."

        AdminMoveTo ->
            "Move to: "

        AdminNotFound ->
            "Competition not found."

        AdminImagesCount ->
            "Images: "

        AdminPublishedReviews ->
            "Published reviews: "

        AdminApprove ->
            "Approve"

        AdminReject ->
            "Reject"

        AdminReset ->
            "Reset to submitted"

        VotingOpenHeading ->
            "Voting open"

        Vote ->
            "Vote"

        VotingEndsPrefix ->
            "Vote by "

        VoteHeading ->
            "Voting"

        VoteInstructions ->
            "Choose at most five best entries in order of preference. 1st place gets 8 points, 2nd 5, 3rd 3, 4th 2 and 5th 1 point. You can change your vote until voting ends."

        VoteRequiredNote ->
            "Participants must vote: an entry whose submitter does not vote gets no place in the vote result."

        VoteBallotHeading ->
            "Your ballot"

        VoteEmptySlot ->
            "Choose an entry below"

        VotePointsSuffix ->
            " pts"

        VoteMoveUp ->
            "Move up"

        VoteMoveDown ->
            "Move down"

        VoteRemove ->
            "Remove from ballot"

        VoteCandidatesHeading ->
            "Entries"

        VotePick ->
            "Choose"

        VotePickedPrefix ->
            "Chosen for place "

        VoteBallotFull ->
            "Ballot is full"

        VoteSave ->
            "Save vote"

        VoteSaving ->
            "Saving…"

        VoteSaved ->
            "Your vote has been saved."

        VoteUnsaved ->
            "Your changes are not saved yet."

        VoteNoCandidates ->
            "The competition has no approved entries yet."

        VoteNotEnabled ->
            "This competition has no voting."

        ErrBallotLoad ->
            "Your vote could not be loaded. Reload the page."

        ErrBallotEmpty ->
            "Choose at least one entry."

        ErrBallotRejected ->
            "The vote was not accepted: voting is not open, or a chosen entry is no longer in the competition."

        ErrBallotSave ->
            "Saving the vote failed. Try again."

        AdminFieldVotingEnabled ->
            "Public voting enabled"

        AdminFieldVotingRequired ->
            "Participants must vote"

        AdminFieldVotingStart ->
            "Voting starts"

        AdminFieldVotingEnd ->
            "Voting closes (at the start of the day)"

        AdminErrVotingDates ->
            "Voting needs a start and an end date, and the end must be after the start."

        AdminVoteResultHeading ->
            "Vote result"

        AdminBallotCount ->
            "Ballots: "

        AdminNotVoted ->
            "No place, as the submitter did not vote: "

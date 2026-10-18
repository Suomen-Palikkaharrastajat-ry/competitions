module SubmitFormTest exposing (suite)

{-| Tests for entry submission form state and validation.

Given a model with a submit form
When form-related messages are processed via update / validateForm is called
Then state transitions and validation errors are correct

-}

import Dict
import Expect
import Http
import Json.Encode as Encode
import Lang exposing (Lang(..))
import Main exposing (canSubmitMore, update, validateForm)
import RemoteData
import Scoring exposing (canEditEntry, deadlineUrgency, isDeadlinePassed)
import Test exposing (Test, describe, test)
import TestSite
import Time
import Types exposing (..)


emptyForm : SubmitForm
emptyForm =
    { entryId = Nothing
    , title = ""
    , description = ""
    , selectedFiles = []
    , existingImages = []
    , imagesToRemove = []
    , isCompressing = False
    , step = FillingForm
    , draftSaved = False
    , previews = Dict.empty
    }


testCompetition : Competition
testCompetition =
    { id = "comp1"
    , title = "Kaupunki 2026"
    , slug = "kaupunki-2026"
    , theme = Just "Kaupunki"
    , description = Nothing
    , endDate = "2026-12-31 00:00:00.000Z"
    , coverImage = Nothing
    , maxEntriesPerUser = Just 3
    , minImagesPerEntry = Nothing
    , maxImagesPerEntry = Nothing
    , startDate = "2026-06-01 00:00:00.000Z"
    , judgingEndDate = Nothing
    , status = COpen
    }


testEntry : Entry
testEntry =
    { id = "entry1"
    , competitionId = "comp1"
    , competition = Just testCompetition
    , title = "My MOC"
    , description = Nothing
    , images = [ "photo.jpg" ]
    , status = Draft
    , publishedReviews = []
    }


testUser : AuthUser
testUser =
    { id = "user1"
    , authCollection = "local_users"
    , profileId = "profile1"
    , email = "user@example.fi"
    , token = "eyJtoken"
    , displayName = "Pekka"
    , isReviewer = False
    }


beforeDeadline : Time.Posix
beforeDeadline =
    Time.millisToPosix 1780272000000


afterDeadline : Time.Posix
afterDeadline =
    Time.millisToPosix 1798848000000


noonOnDeadlineDay : Time.Posix
noonOnDeadlineDay =
    Time.millisToPosix 1798718400000


editClosedMessage : String
editClosedMessage =
    "Muokkaus ei ole enää mahdollista; kilpailun määräaika on umpeutunut."


baseModel : Model
baseModel =
    { auth = LoggedIn testUser
    , pbUrl = "http://localhost:8090"
    , emailInput = ""
    , otpInput = ""
    , authError = Nothing
    , displayNameInput = ""
    , page = DashboardPage
    , lang = Fi
    , site = TestSite.site Fi
    , menuOpen = False
    , now = Time.millisToPosix 0
    , competitions = RemoteData.NotAsked
    , myEntries = RemoteData.NotAsked
    , submitForm = emptyForm
    , selectedCompetition = Just testCompetition
    , reviewQueue = RemoteData.NotAsked
    , activeReview = Nothing
    , reviewFilter = AllEntries
    , adminCompetitions = RemoteData.NotAsked
    , adminForm = Nothing
    , adminFormErrors = []
    , adminEntries = RemoteData.NotAsked
    , criteria = TestSite.criteria Fi
    }


suite : Test
suite =
    describe "Entry submission"
        [ describe "Submitting with confirmation (US-003)"
            -- Given a filled form
            -- When the participant clicks "Lähetä arvosteltavaksi"
            -- Then a confirmation is asked, and confirming saves and submits in one request
            [ test "a valid form asks for confirmation, without a saved draft" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update SubmitEntry { baseModel | submitForm = { emptyForm | title = "MOC", existingImages = [ "a.png" ] } }
                    in
                    model.submitForm.step |> Expect.equal ConfirmingSubmit
            , test "an invalid form shows the error and asks nothing" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update SubmitEntry { baseModel | submitForm = { emptyForm | title = "MOC" } }
                    in
                    ( model.submitForm.step, model.authError /= Nothing ) |> Expect.equal ( FillingForm, True )
            , test "confirming uploads" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update ConfirmSubmit { baseModel | submitForm = { emptyForm | title = "MOC", step = ConfirmingSubmit } }
                    in
                    model.submitForm.step |> Expect.equal Uploading
            , test "cancelling returns to the form" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update CancelSubmit { baseModel | submitForm = { emptyForm | step = ConfirmingSubmit } }
                    in
                    model.submitForm.step |> Expect.equal FillingForm
            , test "Escape cancels the confirmation dialog" <|
                -- Given the confirmation dialog is open
                -- When the user presses Escape
                -- Then the form is shown again without uploading
                \_ ->
                    let
                        ( model, _ ) =
                            update EscapePressed { baseModel | submitForm = { emptyForm | title = "MOC", step = ConfirmingSubmit } }
                    in
                    model.submitForm.step |> Expect.equal FillingForm
            ]
        , describe "Draft saved notice (US-003)"
            [ test "saving a draft shows the notice" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (DraftSaved (Ok testEntry)) baseModel
                    in
                    model.submitForm.draftSaved |> Expect.equal True
            , test "editing the form clears the notice" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (EntryTitleChanged "New") { baseModel | submitForm = { emptyForm | draftSaved = True } }
                    in
                    model.submitForm.draftSaved |> Expect.equal False
            ]
        , describe "validateForm"
            [ test "empty title returns Err" <|
                \_ ->
                    let
                        form =
                            { emptyForm | existingImages = [ "photo.jpg" ] }
                    in
                    case validateForm Fi testCompetition form of
                        Err _ ->
                            Expect.pass

                        Ok _ ->
                            Expect.fail "Should have returned Err for empty title"
            , test "no images returns Err" <|
                \_ ->
                    let
                        form =
                            { emptyForm | title = "My MOC" }
                    in
                    case validateForm Fi testCompetition form of
                        Err msg ->
                            Expect.equal "Lisää vähintään yksi kuva" msg

                        Ok _ ->
                            Expect.fail "Should have returned Err for no images"
            , test "valid form returns Ok" <|
                \_ ->
                    let
                        form =
                            { emptyForm
                                | title = "My MOC"
                                , existingImages = [ "photo.jpg" ]
                            }
                    in
                    case validateForm Fi testCompetition form of
                        Ok _ ->
                            Expect.pass

                        Err msg ->
                            Expect.fail ("Should have returned Ok but got: " ++ msg)
            , test "custom minimum image count is enforced on submit validation" <|
                \_ ->
                    let
                        competition =
                            { testCompetition | minImagesPerEntry = Just 2 }

                        form =
                            { emptyForm
                                | title = "My MOC"
                                , existingImages = [ "photo.jpg" ]
                            }
                    in
                    case validateForm Fi competition form of
                        Err msg ->
                            Expect.equal "Lisää vähintään 2 kuvaa" msg

                        Ok _ ->
                            Expect.fail "Should have returned Err for too few images"
            , test "custom maximum image count is enforced" <|
                \_ ->
                    let
                        competition =
                            { testCompetition | maxImagesPerEntry = Just 2 }

                        form =
                            { emptyForm
                                | title = "My MOC"
                                , existingImages = [ "a.jpg", "b.jpg", "c.jpg" ]
                            }
                    in
                    case validateForm Fi competition form of
                        Err msg ->
                            Expect.equal "Enintään 2 kuvaa sallittu" msg

                        Ok _ ->
                            Expect.fail "Should have returned Err for too many images"
            , test "default maximum image count is enforced" <|
                \_ ->
                    let
                        form =
                            { emptyForm
                                | title = "My MOC"
                                , existingImages =
                                    [ "1.jpg"
                                    , "2.jpg"
                                    , "3.jpg"
                                    , "4.jpg"
                                    , "5.jpg"
                                    , "6.jpg"
                                    , "7.jpg"
                                    , "8.jpg"
                                    , "9.jpg"
                                    , "10.jpg"
                                    , "11.jpg"
                                    ]
                            }
                    in
                    case validateForm Fi testCompetition form of
                        Err msg ->
                            Expect.equal "Enintään 10 kuvaa sallittu" msg

                        Ok _ ->
                            Expect.fail "Should have returned Err for too many images"
            ]
        , describe "EntryTitleChanged"
            [ test "updates submitForm.title" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (EntryTitleChanged "My MOC") baseModel
                    in
                    model.submitForm.title |> Expect.equal "My MOC"
            ]
        , describe "EntryDescriptionChanged"
            [ test "updates submitForm.description" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (EntryDescriptionChanged "A great MOC") baseModel
                    in
                    model.submitForm.description |> Expect.equal "A great MOC"
            ]
        , describe "RemoveExistingImage"
            [ test "removes filename from existingImages" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | submitForm =
                                    { emptyForm
                                        | existingImages = [ "a.jpg", "b.jpg" ]
                                    }
                            }

                        ( updated, _ ) =
                            update (RemoveExistingImage "a.jpg") model
                    in
                    updated.submitForm.existingImages |> Expect.equal [ "b.jpg" ]
            , test "adds filename to imagesToRemove" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | submitForm =
                                    { emptyForm
                                        | existingImages = [ "a.jpg", "b.jpg" ]
                                    }
                            }

                        ( updated, _ ) =
                            update (RemoveExistingImage "a.jpg") model
                    in
                    updated.submitForm.imagesToRemove |> Expect.equal [ "a.jpg" ]
            ]
        , describe "SaveDraft"
            [ test "transitions step to Uploading" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | submitForm = { emptyForm | title = "My MOC" }
                            }

                        ( updated, _ ) =
                            update SaveDraft model
                    in
                    updated.submitForm.step |> Expect.equal Uploading
            , test "does not validate against competition image minimum" <|
                \_ ->
                    let
                        competition =
                            { testCompetition | minImagesPerEntry = Just 2 }

                        model =
                            { baseModel
                                | selectedCompetition = Just competition
                                , submitForm = { emptyForm | title = "My MOC" }
                            }

                        ( updated, _ ) =
                            update SaveDraft model
                    in
                    updated.submitForm.step |> Expect.equal Uploading
            ]
        , describe "EditEntry"
            [ test "hydrates form and selected competition from expanded draft" <|
                \_ ->
                    let
                        ( updated, _ ) =
                            update
                                (EditEntry testEntry.id)
                                { baseModel
                                    | myEntries = RemoteData.Success [ testEntry ]
                                    , selectedCompetition = Nothing
                                }
                    in
                    Expect.all
                        [ \m -> m.submitForm.entryId |> Expect.equal (Just testEntry.id)
                        , \m -> m.submitForm.title |> Expect.equal testEntry.title
                        , \m -> m.submitForm.existingImages |> Expect.equal testEntry.images
                        , \m -> m.selectedCompetition |> Expect.equal (Just testCompetition)
                        ]
                        updated
            , test "opens a submitted entry while its competition deadline has not passed" <|
                \_ ->
                    let
                        ( updated, _ ) =
                            update
                                (EditEntry testEntry.id)
                                { baseModel | myEntries = RemoteData.Success [ { testEntry | status = Submitted } ], now = beforeDeadline }
                    in
                    Expect.all
                        [ \m -> m.submitForm.entryId |> Expect.equal (Just testEntry.id)
                        , \m -> m.page |> Expect.equal (SubmitEntryPage (Just testEntry.id))
                        ]
                        updated
            , test "refuses a submitted entry once the competition deadline has passed" <|
                \_ ->
                    let
                        ( updated, _ ) =
                            update
                                (EditEntry testEntry.id)
                                { baseModel
                                    | myEntries = RemoteData.Success [ { testEntry | status = Submitted } ]
                                    , now = afterDeadline
                                }
                    in
                    Expect.all
                        [ \m -> m.submitForm.entryId |> Expect.equal Nothing
                        , \m -> m.authError |> Expect.equal (Just editClosedMessage)
                        ]
                        updated
            , test "reports an error when expanded competition is unavailable" <|
                \_ ->
                    let
                        entryWithoutCompetition =
                            { testEntry | competition = Nothing }

                        ( updated, _ ) =
                            update
                                (EditEntry testEntry.id)
                                { baseModel | myEntries = RemoteData.Success [ entryWithoutCompetition ] }
                    in
                    updated.authError |> Expect.equal (Just "Kilpailun tietoja ei voitu ladata")
            ]
        , describe "SaveDraft on a submitted entry"
            [ test "saves the changes without changing the status" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | myEntries = RemoteData.Success [ { testEntry | status = Submitted } ]
                                , now = beforeDeadline
                                , submitForm = { emptyForm | entryId = Just testEntry.id, title = "My MOC", existingImages = [ "photo.jpg" ] }
                            }

                        ( updated, _ ) =
                            update SaveDraft model
                    in
                    updated.submitForm.step |> Expect.equal Uploading
            , test "is refused when the saved changes would break the image limit" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | myEntries = RemoteData.Success [ { testEntry | status = Submitted, images = [] } ]
                                , now = beforeDeadline
                                , submitForm = { emptyForm | entryId = Just testEntry.id, title = "My MOC" }
                            }

                        ( updated, _ ) =
                            update SaveDraft model
                    in
                    Expect.all
                        [ \m -> m.submitForm.step |> Expect.equal FillingForm
                        , \m -> m.authError |> Expect.notEqual Nothing
                        ]
                        updated
            , test "is refused once the competition deadline has passed" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | myEntries = RemoteData.Success [ { testEntry | status = Submitted } ]
                                , now = afterDeadline
                                , submitForm = { emptyForm | entryId = Just testEntry.id }
                            }

                        ( updated, _ ) =
                            update SaveDraft model
                    in
                    Expect.all
                        [ \m -> m.submitForm.step |> Expect.equal FillingForm
                        , \m -> m.authError |> Expect.equal (Just editClosedMessage)
                        ]
                        updated
            ]
        , describe "SelectCompetition"
            [ test "opens the new entry form without an entry id" <|
                \_ ->
                    let
                        ( updated, _ ) =
                            update (SelectCompetition testCompetition) baseModel
                    in
                    updated.page |> Expect.equal (SubmitEntryPage Nothing)
            ]
        , describe "PreviewReady"
            [ test "stores the preview of a selected file under its key" <|
                \_ ->
                    let
                        ( updated, _ ) =
                            update (PreviewReady "photo.jpg|1024" "data:image/webp;base64,AAA") baseModel
                    in
                    Dict.get "photo.jpg|1024" updated.submitForm.previews
                        |> Expect.equal (Just "data:image/webp;base64,AAA")
            ]
        , describe "CancelEdit"
            [ test "returns to the participation being edited" <|
                \_ ->
                    let
                        ( updated, _ ) =
                            update CancelEdit { baseModel | submitForm = { emptyForm | entryId = Just testEntry.id } }
                    in
                    updated.page |> Expect.equal (ParticipationPage testEntry.id)
            ]
        , describe "canEditEntry"
            [ test "a draft can be edited after the deadline" <|
                \_ -> canEditEntry afterDeadline { testEntry | status = Draft } |> Expect.equal True
            , test "a submitted entry can be edited until the deadline" <|
                \_ -> canEditEntry beforeDeadline { testEntry | status = Submitted } |> Expect.equal True
            , test "a submitted entry cannot be edited after the deadline" <|
                \_ -> canEditEntry afterDeadline { testEntry | status = Submitted } |> Expect.equal False
            , test "a submitted entry without its competition cannot be edited" <|
                \_ -> canEditEntry beforeDeadline { testEntry | status = Submitted, competition = Nothing } |> Expect.equal False
            , test "the deadline is the time of day of end_date, not its midnight" <|
                \_ ->
                    let
                        lateOnDeadlineDay =
                            { testEntry
                                | status = Submitted
                                , competition = Just { testCompetition | endDate = "2026-12-31 23:59:59.000Z" }
                            }
                    in
                    canEditEntry noonOnDeadlineDay lateOnDeadlineDay |> Expect.equal True
            , test "approved and rejected entries cannot be edited" <|
                \_ ->
                    [ Approved, Rejected ]
                        |> List.map (\status -> canEditEntry beforeDeadline { testEntry | status = status })
                        |> Expect.equal [ False, False ]
            ]
        , describe "DraftSaved"
            [ test "Ok returns step to FillingForm" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | submitForm = { emptyForm | step = Uploading }
                            }

                        ( updated, _ ) =
                            update (DraftSaved (Ok testEntry)) model
                    in
                    updated.submitForm.step |> Expect.equal FillingForm
            , test "Ok stores entry id in form" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | submitForm = { emptyForm | step = Uploading }
                            }

                        ( updated, _ ) =
                            update (DraftSaved (Ok testEntry)) model
                    in
                    updated.submitForm.entryId |> Expect.equal (Just "entry1")
            , test "Err sets UploadError step" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | submitForm = { emptyForm | step = Uploading }
                            }

                        ( updated, _ ) =
                            update (DraftSaved (Err Http.NetworkError)) model
                    in
                    case updated.submitForm.step of
                        UploadError _ ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected UploadError step"
            ]
        , describe "EntrySubmitted"
            [ test "Ok sets step to SubmitSuccess" <|
                \_ ->
                    let
                        submitted =
                            { testEntry | status = Submitted }

                        ( updated, _ ) =
                            update (EntrySubmitted (Ok submitted)) baseModel
                    in
                    updated.submitForm.step |> Expect.equal SubmitSuccess
            , test "Err sets UploadError step" <|
                \_ ->
                    let
                        ( updated, _ ) =
                            update (EntrySubmitted (Err Http.NetworkError)) baseModel
                    in
                    case updated.submitForm.step of
                        UploadError _ ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected UploadError step"
            ]
        , describe "canSubmitMore"
            [ test "returns True when below limit" <|
                \_ ->
                    let
                        entries =
                            [ testEntry ]
                    in
                    canSubmitMore testCompetition entries |> Expect.equal True
            , test "returns False when at limit" <|
                \_ ->
                    let
                        entries =
                            [ testEntry
                            , { testEntry | id = "e2" }
                            , { testEntry | id = "e3" }
                            ]
                    in
                    canSubmitMore testCompetition entries |> Expect.equal False
            , test "returns True when limit is 0 (unlimited)" <|
                \_ ->
                    let
                        unlimitedComp =
                            { testCompetition | maxEntriesPerUser = Just 0 }

                        entries =
                            List.repeat 10 testEntry
                    in
                    canSubmitMore unlimitedComp entries |> Expect.equal True
            ]
        , describe "isDeadlinePassed"
            [ test "past deadline returns True" <|
                \_ ->
                    let
                        -- Jan 2, 2026 in milliseconds
                        jan2 =
                            Time.millisToPosix 1767312000000
                    in
                    isDeadlinePassed "2026-01-01T00:00:00Z" jan2
                        |> Expect.equal True
            , test "future deadline returns False" <|
                \_ ->
                    let
                        -- Jan 2, 2026 in milliseconds
                        jan2 =
                            Time.millisToPosix 1767312000000
                    in
                    isDeadlinePassed "2026-12-31T00:00:00Z" jan2
                        |> Expect.equal False
            , test "PocketBase date format (with space) is handled" <|
                \_ ->
                    let
                        jan2 =
                            Time.millisToPosix 1767312000000
                    in
                    isDeadlinePassed "2026-01-01 00:00:00.000Z" jan2
                        |> Expect.equal True
            ]
        , describe "deadlineUrgency"
            [ test "Given endDate tomorrow, Then Just text-brand-red" <|
                \_ ->
                    -- now = Jan 1 2026, endDate = Jan 3 2026 (2 days away)
                    let
                        jan1 =
                            Time.millisToPosix 1767225600000
                    in
                    deadlineUrgency "2026-01-03" jan1
                        |> Expect.equal (Just "text-brand-red")
            , test "Given endDate 8 days away, Then Nothing" <|
                \_ ->
                    -- now = Jan 1 2026, endDate = Jan 9 2026 (8 days away)
                    let
                        jan1 =
                            Time.millisToPosix 1767225600000
                    in
                    deadlineUrgency "2026-01-09" jan1
                        |> Expect.equal Nothing
            , test "Given past deadline, Then Nothing" <|
                \_ ->
                    -- now = Jan 10 2026, endDate = Jan 1 2026 (already passed)
                    let
                        jan10 =
                            Time.millisToPosix (1767225600000 + 9 * 24 * 60 * 60 * 1000)
                    in
                    deadlineUrgency "2026-01-01" jan10
                        |> Expect.equal Nothing
            ]
        , describe "WebP image compression & form selection"
            [ test "Given emptyForm, Then isCompressing is False" <|
                \_ ->
                    emptyForm.isCompressing
                        |> Expect.equal False
            , test "Given form with remaining slots, When RawFilesSelected received, Then isCompressing becomes True" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | submitForm = emptyForm
                                , authError = Just "Previous error"
                            }

                        ( updatedModel, _ ) =
                            update (RawFilesSelected (Encode.list Encode.string [])) model
                    in
                    Expect.all
                        [ \m -> Expect.equal True m.submitForm.isCompressing
                        , \m -> Expect.equal Nothing m.authError
                        ]
                        updatedModel
            , test "Given zero remaining slots, When RawFilesSelected received, Then isCompressing remains False and error shown" <|
                \_ ->
                    let
                        fullComp =
                            { testCompetition | maxImagesPerEntry = Just 2 }

                        model =
                            { baseModel
                                | selectedCompetition = Just fullComp
                                , submitForm = { emptyForm | existingImages = [ "1.webp", "2.webp" ] }
                            }

                        ( updatedModel, _ ) =
                            update (RawFilesSelected (Encode.object [ ( "length", Encode.int 1 ) ])) model
                    in
                    Expect.all
                        [ \m -> Expect.equal False m.submitForm.isCompressing
                        , \m -> Expect.equal (Just "Enintään 2 kuvaa sallittu") m.authError
                        ]
                        updatedModel
            , test "Given excess files selected, When RawFilesSelected received, Then warning feedback shown" <|
                \_ ->
                    let
                        comp =
                            { testCompetition | maxImagesPerEntry = Just 2 }

                        model =
                            { baseModel
                                | selectedCompetition = Just comp
                                , submitForm = emptyForm
                            }

                        ( updatedModel, _ ) =
                            update (RawFilesSelected (Encode.object [ ( "length", Encode.int 5 ) ])) model
                    in
                    Expect.all
                        [ \m -> Expect.equal True m.submitForm.isCompressing
                        , \m -> Expect.equal (Just "Kuvia valittiin enemmän kuin mahtuu. Vain ensimmäiset lisättiin.") m.authError
                        ]
                        updatedModel
            , test "Given valid compressed files, When ImagesCompressed received, Then isCompressing becomes False" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | submitForm = { emptyForm | isCompressing = True }
                            }

                        ( updatedModel, _ ) =
                            update (ImagesCompressed (Encode.list identity [])) model
                    in
                    Expect.equal False updatedModel.submitForm.isCompressing
            , test "Given invalid JSON payload, When ImagesCompressed received, Then isCompressing becomes False and generic error shown" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | submitForm = { emptyForm | isCompressing = True }
                            }

                        ( updatedModel, _ ) =
                            update (ImagesCompressed (Encode.string "invalid payload")) model
                    in
                    Expect.all
                        [ \m -> Expect.equal False m.submitForm.isCompressing
                        , \m -> Expect.equal (UploadError "Kuvan pakkaus epäonnistui.") m.submitForm.step
                        ]
                        updatedModel
            , test "Given compressing form, When CompressionFailed received, Then isCompressing becomes False and error shown" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | submitForm = { emptyForm | isCompressing = True }
                            }

                        ( updatedModel, _ ) =
                            update (CompressionFailed "corrupt format") model
                    in
                    Expect.all
                        [ \m -> Expect.equal False m.submitForm.isCompressing
                        , \m -> Expect.equal (UploadError "Kuvan pakkaus epäonnistui: corrupt format") m.submitForm.step
                        ]
                        updatedModel
            , test "Given compressing form, When SaveDraft triggered, Then submission is blocked" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | submitForm = { emptyForm | isCompressing = True }
                            }

                        ( updatedModel, cmd ) =
                            update SaveDraft model
                    in
                    Expect.all
                        [ \m -> Expect.equal True m.submitForm.isCompressing
                        , \m -> Expect.notEqual Uploading m.submitForm.step
                        , \_ -> Expect.equal Cmd.none cmd
                        ]
                        updatedModel
            , test "Given compressing form, When SubmitEntry triggered, Then submission is blocked" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | submitForm =
                                    { emptyForm
                                        | entryId = Just "entry1"
                                        , isCompressing = True
                                        , title = "My MOC"
                                        , existingImages = [ "a.webp" ]
                                    }
                            }

                        ( updatedModel, cmd ) =
                            update SubmitEntry model
                    in
                    Expect.all
                        [ \m -> Expect.equal True m.submitForm.isCompressing
                        , \_ -> Expect.equal Cmd.none cmd
                        ]
                        updatedModel
            , test "Given form with empty selected files, When RemoveSelectedFile received, Then list remains empty" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | submitForm = { emptyForm | selectedFiles = [] }
                            }

                        ( updatedModel, _ ) =
                            update (RemoveSelectedFile 0) model
                    in
                    Expect.equal [] updatedModel.submitForm.selectedFiles
            , test "Given list removal logic by index, removing index 1 leaves first and third items" <|
                \_ ->
                    let
                        items =
                            [ "first", "second", "third" ]

                        removeAtIndex idx list =
                            list
                                |> List.indexedMap Tuple.pair
                                |> List.filter (\( i, _ ) -> i /= idx)
                                |> List.map Tuple.second
                    in
                    removeAtIndex 1 items
                        |> Expect.equal [ "first", "third" ]
            ]
        ]

module SubmitFormTest exposing (suite)

{-| Tests for entry submission form state and validation.

Given a model with a submit form
When form-related messages are processed via update / validateForm is called
Then state transitions and validation errors are correct

-}

import Expect
import Http
import Main exposing (canSubmitMore, update, validateForm)
import RemoteData
import Scoring exposing (deadlineUrgency, isDeadlinePassed)
import Test exposing (Test, describe, test)
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
    , step = FillingForm
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
    }


testEntry : Entry
testEntry =
    { id = "entry1"
    , competitionId = "comp1"
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
    , now = Time.millisToPosix 0
    , competitions = RemoteData.NotAsked
    , myEntries = RemoteData.NotAsked
    , submitForm = emptyForm
    , selectedCompetition = Just testCompetition
    , reviewQueue = RemoteData.NotAsked
    , activeReview = Nothing
    , reviewFilter = AllEntries
    }


suite : Test
suite =
    describe "Entry submission"
        [ describe "validateForm"
            [ test "empty title returns Err" <|
                \_ ->
                    let
                        form =
                            { emptyForm | existingImages = [ "photo.jpg" ] }
                    in
                    case validateForm form of
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
                    case validateForm form of
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
                    case validateForm form of
                        Ok _ ->
                            Expect.pass

                        Err msg ->
                            Expect.fail ("Should have returned Ok but got: " ++ msg)
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
        ]

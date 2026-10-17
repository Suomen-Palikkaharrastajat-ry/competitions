module ReviewTest exposing (suite)

{-| Tests for the reviewer tools: queue loading, filtering, scoring, save/approve/reject.

Given a model with a review queue
When review-related messages are processed
Then state transitions are correct

-}

import Dict
import Expect
import Http
import Json.Decode as Decode
import Lang exposing (Lang(..))
import Main exposing (emptyReview, filteredReviewQueue, reviewableEntryDecoder, update)
import RemoteData
import Scoring exposing (entryAverage, reviewTotal)
import Test exposing (Test, describe, test)
import TestSite
import Time
import Types exposing (..)


testUser : AuthUser
testUser =
    { id = "reviewer1"
    , authCollection = "local_users"
    , profileId = "profile1"
    , email = "reviewer@example.fi"
    , token = "eyJtoken"
    , displayName = "Reviewer"
    , isReviewer = True
    }


testCompetition : Competition
testCompetition =
    { id = "comp1"
    , title = "Kaupunki 2026"
    , slug = "kaupunki-2026"
    , theme = Nothing
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
    , status = Submitted
    , publishedReviews = []
    }


testReview : Review
testReview =
    { id = Just "rev1"
    , entryId = "entry1"
    , reviewerId = "reviewer1"
    , scoreTheme = 4
    , scoreOriginality = 3
    , scoreTechnique = 5
    , scorePresentation = 4
    , comment = "Great MOC"
    , isPublished = True
    }


testReviewableEntry : ReviewableEntry
testReviewableEntry =
    { entry = testEntry
    , competition = testCompetition
    , submitterName = "Pekka"
    , myReview = Nothing
    }


testReviewableEntryWithReview : ReviewableEntry
testReviewableEntryWithReview =
    { testReviewableEntry | myReview = Just testReview }


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


baseModel : Model
baseModel =
    { auth = LoggedIn testUser
    , pbUrl = "http://localhost:8090"
    , emailInput = ""
    , otpInput = ""
    , authError = Nothing
    , displayNameInput = ""
    , page = ReviewQueuePage
    , lang = Fi
    , site = TestSite.site Fi
    , menuOpen = False
    , now = Time.millisToPosix 0
    , competitions = RemoteData.NotAsked
    , myEntries = RemoteData.NotAsked
    , submitForm = emptyForm
    , selectedCompetition = Nothing
    , reviewQueue = RemoteData.NotAsked
    , activeReview = Nothing
    , reviewFilter = AllEntries
    , adminCompetitions = RemoteData.NotAsked
    , adminForm = Nothing
    , adminFormErrors = []
    , adminEntries = RemoteData.NotAsked
    }


suite : Test
suite =
    describe "Reviewer tools"
        [ describe "Review queue with the reviewer's own reviews (US-004)"
            -- Given entries expanded with all their reviews
            -- When the queue is decoded for a reviewer
            -- Then each entry carries that reviewer's review, so the form is pre-filled and saving updates it
            [ test "picks the reviewer's own review" <|
                \_ ->
                    Decode.decodeString (reviewableEntryDecoder "profile1") queueItemJson
                        |> Result.map (.myReview >> Maybe.andThen .id)
                        |> Expect.equal (Ok (Just "mine"))
            , test "ignores other reviewers' reviews" <|
                \_ ->
                    Decode.decodeString (reviewableEntryDecoder "profile3") queueItemJson
                        |> Result.map .myReview
                        |> Expect.equal (Ok Nothing)
            , test "reads the submitter's name" <|
                \_ ->
                    Decode.decodeString (reviewableEntryDecoder "profile1") queueItemJson
                        |> Result.map .submitterName
                        |> Expect.equal (Ok "Aino")
            ]
        , describe "Scoring.reviewTotal"
            [ test "all 3s gives 12" <|
                \_ ->
                    reviewTotal
                        { scoreTheme = 3
                        , scoreOriginality = 3
                        , scoreTechnique = 3
                        , scorePresentation = 3
                        }
                        |> Expect.equal 12
            , test "mixed scores" <|
                \_ ->
                    reviewTotal
                        { scoreTheme = 4
                        , scoreOriginality = 3
                        , scoreTechnique = 5
                        , scorePresentation = 4
                        }
                        |> Expect.equal 16
            ]
        , describe "Scoring.entryAverage"
            [ test "three review totals" <|
                \_ ->
                    entryAverage [ 16, 18, 14 ]
                        |> Expect.equal 16.0
            , test "empty list returns 0.0" <|
                \_ ->
                    entryAverage []
                        |> Expect.equal 0.0
            , test "single review" <|
                \_ ->
                    entryAverage [ 20 ]
                        |> Expect.equal 20.0
            ]
        , describe "emptyReview"
            [ test "creates review with default scores 3" <|
                \_ ->
                    let
                        r =
                            emptyReview "entry1" "reviewer1"
                    in
                    Expect.all
                        [ \_ -> Expect.equal Nothing r.id
                        , \_ -> Expect.equal "entry1" r.entryId
                        , \_ -> Expect.equal 3 r.scoreTheme
                        , \_ -> Expect.equal 3 r.scoreOriginality
                        , \_ -> Expect.equal 3 r.scoreTechnique
                        , \_ -> Expect.equal 3 r.scorePresentation
                        , \_ -> Expect.equal False r.isPublished
                        ]
                        ()
            ]
        , describe "ReviewQueueLoaded"
            [ test "Ok stores entries in reviewQueue" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (ReviewQueueLoaded (Ok [ testReviewableEntry ])) baseModel
                    in
                    case model.reviewQueue of
                        RemoteData.Success entries ->
                            List.length entries |> Expect.equal 1

                        _ ->
                            Expect.fail "Expected Success"
            , test "Err sets Failure" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (ReviewQueueLoaded (Err Http.NetworkError)) baseModel
                    in
                    case model.reviewQueue of
                        RemoteData.Failure _ ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected Failure"
            ]
        , describe "ReviewFilterChanged"
            [ test "updates reviewFilter" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (ReviewFilterChanged NotYetReviewed) baseModel
                    in
                    model.reviewFilter |> Expect.equal NotYetReviewed
            ]
        , describe "filteredReviewQueue"
            [ test "AllEntries returns all" <|
                \_ ->
                    filteredReviewQueue AllEntries
                        [ testReviewableEntry, testReviewableEntryWithReview ]
                        |> List.length
                        |> Expect.equal 2
            , test "NotYetReviewed filters out reviewed entries" <|
                \_ ->
                    filteredReviewQueue NotYetReviewed
                        [ testReviewableEntry, testReviewableEntryWithReview ]
                        |> List.length
                        |> Expect.equal 1
            , test "ByCompetition filters by competition id" <|
                \_ ->
                    let
                        other =
                            { testReviewableEntry
                                | competition = { testCompetition | id = "comp2" }
                            }
                    in
                    filteredReviewQueue (ByCompetition "comp1")
                        [ testReviewableEntry, other ]
                        |> List.length
                        |> Expect.equal 1
            ]
        , describe "OpenReviewForm"
            [ test "sets activeReview" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (OpenReviewForm testReviewableEntry) baseModel
                    in
                    case model.activeReview of
                        Just reviewForm ->
                            reviewForm.reviewableEntry.entry.id |> Expect.equal "entry1"

                        Nothing ->
                            Expect.fail "Expected activeReview to be set"
            , test "pre-fills existing review when present" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (OpenReviewForm testReviewableEntryWithReview) baseModel
                    in
                    case model.activeReview of
                        Just reviewForm ->
                            reviewForm.draftReview.scoreTheme |> Expect.equal 4

                        Nothing ->
                            Expect.fail "Expected activeReview to be set"
            ]
        , describe "CloseReviewForm"
            [ test "clears activeReview" <|
                \_ ->
                    let
                        modelWithReview =
                            { baseModel
                                | activeReview =
                                    Just
                                        { reviewableEntry = testReviewableEntry
                                        , draftReview = emptyReview "entry1" "reviewer1"
                                        , saving = False
                                        , saveError = Nothing
                                        }
                            }

                        ( model, _ ) =
                            update CloseReviewForm modelWithReview
                    in
                    model.activeReview |> Expect.equal Nothing
            ]
        , describe "Saving a review"
            -- Given an open review form
            -- When the reviewer clicks "Tallenna" or "Tallenna ja julkaise"
            -- Then the review is saved unpublished or published
            [ test "SaveReview saves the review unpublished" <|
                \_ ->
                    let
                        published =
                            emptyReview "entry1" "reviewer1"

                        ( model, _ ) =
                            update SaveReview (withReviewForm { published | isPublished = True })
                    in
                    case model.activeReview of
                        Just rf ->
                            Expect.equal ( rf.saving, rf.draftReview.isPublished ) ( True, False )

                        Nothing ->
                            Expect.fail "Expected activeReview"
            , test "SaveAndPublishReview saves the review published" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update SaveAndPublishReview (withReviewForm (emptyReview "entry1" "reviewer1"))
                    in
                    case model.activeReview of
                        Just rf ->
                            Expect.equal ( rf.saving, rf.draftReview.isPublished ) ( True, True )

                        Nothing ->
                            Expect.fail "Expected activeReview"
            ]
        , describe "Score changes"
            [ test "ScoreThemeChanged updates draftReview.scoreTheme" <|
                \_ ->
                    let
                        modelWithReview =
                            { baseModel
                                | activeReview =
                                    Just
                                        { reviewableEntry = testReviewableEntry
                                        , draftReview = emptyReview "entry1" "reviewer1"
                                        , saving = False
                                        , saveError = Nothing
                                        }
                            }

                        ( model, _ ) =
                            update (ScoreThemeChanged 5) modelWithReview
                    in
                    case model.activeReview of
                        Just rf ->
                            rf.draftReview.scoreTheme |> Expect.equal 5

                        Nothing ->
                            Expect.fail "Expected activeReview"
            , test "ReviewCommentChanged updates draftReview.comment" <|
                \_ ->
                    let
                        modelWithReview =
                            { baseModel
                                | activeReview =
                                    Just
                                        { reviewableEntry = testReviewableEntry
                                        , draftReview = emptyReview "entry1" "reviewer1"
                                        , saving = False
                                        , saveError = Nothing
                                        }
                            }

                        ( model, _ ) =
                            update (ReviewCommentChanged "Nice work") modelWithReview
                    in
                    case model.activeReview of
                        Just rf ->
                            rf.draftReview.comment |> Expect.equal "Nice work"

                        Nothing ->
                            Expect.fail "Expected activeReview"
            ]
        , describe "SaveReview"
            [ test "sets saving = True" <|
                \_ ->
                    let
                        modelWithReview =
                            { baseModel
                                | activeReview =
                                    Just
                                        { reviewableEntry = testReviewableEntry
                                        , draftReview = emptyReview "entry1" "reviewer1"
                                        , saving = False
                                        , saveError = Nothing
                                        }
                            }

                        ( model, _ ) =
                            update SaveReview modelWithReview
                    in
                    case model.activeReview of
                        Just rf ->
                            rf.saving |> Expect.equal True

                        Nothing ->
                            Expect.fail "Expected activeReview"
            ]
        , describe "ReviewSaved"
            [ test "Err 401 clears auth and navigates to LoginPage" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (ReviewSaved (Err (Http.BadStatus 401))) baseModel
                    in
                    Expect.all
                        [ \m -> m.auth |> Expect.equal LoggedOut
                        , \m -> m.page |> Expect.equal LoginPage
                        ]
                        model
            , test "Ok clears saving and updates queue entry" <|
                \_ ->
                    let
                        queueModel =
                            { baseModel
                                | reviewQueue =
                                    RemoteData.Success
                                        [ testReviewableEntry ]
                                , activeReview =
                                    Just
                                        { reviewableEntry = testReviewableEntry
                                        , draftReview = emptyReview "entry1" "reviewer1"
                                        , saving = True
                                        , saveError = Nothing
                                        }
                            }

                        ( model, _ ) =
                            update (ReviewSaved (Ok testReview)) queueModel
                    in
                    case model.activeReview of
                        Just rf ->
                            rf.saving |> Expect.equal False

                        Nothing ->
                            Expect.fail "Expected activeReview"
            ]
        , describe "EntryStatusChanged"
            [ test "Ok Approved updates entry status in queue" <|
                \_ ->
                    let
                        queueModel =
                            { baseModel
                                | reviewQueue =
                                    RemoteData.Success [ testReviewableEntry ]
                            }

                        ( model, _ ) =
                            update
                                (EntryStatusChanged "entry1" Approved (Ok ()))
                                queueModel
                    in
                    case model.reviewQueue of
                        RemoteData.Success entries ->
                            case List.head entries of
                                Just re ->
                                    re.entry.status |> Expect.equal Approved

                                Nothing ->
                                    Expect.fail "Expected entry"

                        _ ->
                            Expect.fail "Expected Success"
            ]
        ]


withReviewForm : Review -> Model
withReviewForm review =
    { baseModel
        | activeReview =
            Just
                { reviewableEntry = testReviewableEntry
                , draftReview = review
                , saving = False
                , saveError = Nothing
                }
    }


queueItemJson : String
queueItemJson =
    """
    { "id": "entry1", "competition": "comp1", "title": "MOC", "description": "", "images": ["a.png"], "status": "submitted"
    , "expand":
        { "competition": { "id": "comp1", "title": "Kaupunki 2026", "slug": "kaupunki-2026", "start_date": "2026-06-01 00:00:00.000Z", "end_date": "2026-12-31 00:00:00.000Z" }
        , "submitter": { "id": "profile9", "display_name": "Aino" }
        , "reviews_via_entry":
            [ { "id": "theirs", "entry": "entry1", "reviewer": "profile2", "score_theme": 1, "score_originality": 1, "score_technique": 1, "score_presentation": 1, "comment": "", "is_published": false }
            , { "id": "mine", "entry": "entry1", "reviewer": "profile1", "score_theme": 5, "score_originality": 4, "score_technique": 4, "score_presentation": 5, "comment": "Hieno", "is_published": true }
            ]
        }
    }
    """

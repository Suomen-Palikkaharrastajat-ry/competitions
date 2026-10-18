module ReviewTest exposing (suite)

{-| Tests for the reviewer tools: queue loading, filtering, scoring, save/approve/reject.

Given a model with a review queue
When review-related messages are processed
Then state transitions are correct

-}

import Criteria exposing (Criterion)
import Dict
import Expect
import Http
import Json.Decode as Decode
import Lang exposing (Lang(..))
import Main exposing (emptyReview, filteredReviewQueue, reviewableEntryDecoder, update)
import RemoteData
import Scoring exposing (entryAverage, reviewTotal, scoreMax)
import Test exposing (Test, describe, test)
import TestSite
import Time
import Types exposing (..)
import Voting


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
    , votingEnabled = False
    , votingRequired = False
    , votingStartDate = Nothing
    , votingEndDate = Nothing
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
    , submitterId = "profile1"
    , publishedReviews = []
    }


testReview : Review
testReview =
    { id = Just "rev1"
    , entryId = "entry1"
    , reviewerId = "reviewer1"
    , scores = Dict.fromList [ ( "theme", 4 ), ( "originality", 3 ), ( "technique", 5 ), ( "presentation", 4 ) ]
    , comment = "Great MOC"
    , isPublished = True
    }


{-| The review criteria of the app's config.toml, in Finnish.
-}
testCriteria : List Criterion
testCriteria =
    TestSite.criteria Fi


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
    , criteria = testCriteria
    , voting = Voting.init
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
            , test "totals only the published reviews, from their scores" <|
                \_ ->
                    Decode.decodeString (reviewableEntryDecoder "profile1") queueItemJson
                        |> Result.map (.entry >> .publishedReviews >> List.map .total)
                        |> Expect.equal (Ok [ 18 ])
            ]
        , describe "Scoring.reviewTotal"
            [ test "all 3s gives 12" <|
                \_ ->
                    reviewTotal
                        { scores = Dict.fromList [ ( "theme", 3 ), ( "originality", 3 ), ( "technique", 3 ), ( "presentation", 3 ) ] }
                        |> Expect.equal 12
            , test "mixed scores" <|
                \_ ->
                    reviewTotal
                        { scores = Dict.fromList [ ( "theme", 4 ), ( "originality", 3 ), ( "technique", 5 ), ( "presentation", 4 ) ] }
                        |> Expect.equal 16
            , test "sums however many criteria the review has" <|
                \_ ->
                    reviewTotal
                        { scores = Dict.fromList [ ( "clarity", 5 ), ( "humour", 2 ) ] }
                        |> Expect.equal 7
            ]
        , describe "Scoring.scoreMax"
            [ test "five per configured criterion" <|
                \_ ->
                    scoreMax testCriteria
                        |> Expect.equal 20
            , test "follows the number of criteria" <|
                \_ ->
                    scoreMax [ { id = "clarity", label = "Clarity" }, { id = "humour", label = "Humour" } ]
                        |> Expect.equal 10
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
                            emptyReview testCriteria "entry1" "reviewer1"
                    in
                    Expect.all
                        [ \_ -> Expect.equal Nothing r.id
                        , \_ -> Expect.equal "entry1" r.entryId
                        , \_ -> Expect.equal (Just 3) (Dict.get "theme" r.scores)
                        , \_ -> Expect.equal (Just 3) (Dict.get "originality" r.scores)
                        , \_ -> Expect.equal (Just 3) (Dict.get "technique" r.scores)
                        , \_ -> Expect.equal (Just 3) (Dict.get "presentation" r.scores)
                        , \_ -> Expect.equal False r.isPublished
                        ]
                        ()
            , test "has one score per configured criterion, and no others" <|
                \_ ->
                    emptyReview [ { id = "clarity", label = "Clarity" } ] "entry1" "reviewer1"
                        |> .scores
                        |> Expect.equal (Dict.fromList [ ( "clarity", 3 ) ])
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
                            Dict.get "theme" reviewForm.draftReview.scores |> Expect.equal (Just 4)

                        Nothing ->
                            Expect.fail "Expected activeReview to be set"
            ]
        , describe "EscapePressed"
            -- Given the review form is open
            -- When the user presses Escape
            -- Then the review form closes
            [ test "closes an open review form" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update EscapePressed (withReviewForm (emptyReview testCriteria "entry1" "reviewer1"))
                    in
                    model.activeReview |> Expect.equal Nothing
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
                                        , draftReview = emptyReview testCriteria "entry1" "reviewer1"
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
                            emptyReview testCriteria "entry1" "reviewer1"

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
                            update SaveAndPublishReview (withReviewForm (emptyReview testCriteria "entry1" "reviewer1"))
                    in
                    case model.activeReview of
                        Just rf ->
                            Expect.equal ( rf.saving, rf.draftReview.isPublished ) ( True, True )

                        Nothing ->
                            Expect.fail "Expected activeReview"
            ]
        , describe "Score changes"
            [ test "ScoreChanged updates that criterion's score in draftReview" <|
                \_ ->
                    let
                        modelWithReview =
                            { baseModel
                                | activeReview =
                                    Just
                                        { reviewableEntry = testReviewableEntry
                                        , draftReview = emptyReview testCriteria "entry1" "reviewer1"
                                        , saving = False
                                        , saveError = Nothing
                                        }
                            }

                        ( model, _ ) =
                            update (ScoreChanged "theme" 5) modelWithReview
                    in
                    case model.activeReview of
                        Just rf ->
                            Dict.get "theme" rf.draftReview.scores |> Expect.equal (Just 5)

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
                                        , draftReview = emptyReview testCriteria "entry1" "reviewer1"
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
                                        , draftReview = emptyReview testCriteria "entry1" "reviewer1"
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
                                        , draftReview = emptyReview testCriteria "entry1" "reviewer1"
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
            [ { "id": "theirs", "entry": "entry1", "reviewer": "profile2", "scores": { "theme": 1, "originality": 1, "technique": 1, "presentation": 1 }, "comment": "", "is_published": false }
            , { "id": "mine", "entry": "entry1", "reviewer": "profile1", "scores": { "theme": 5, "originality": 4, "technique": 4, "presentation": 5 }, "comment": "Hieno", "is_published": true }
            ]
        }
    }
    """

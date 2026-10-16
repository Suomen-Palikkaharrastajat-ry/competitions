module ViewTest exposing (suite)

{-| Tests for view rendering: admin UI link, published review scores.

Given a model / user state
When the view is rendered
Then the correct HTML elements are present

-}

import Expect
import Html.Attributes
import Lang exposing (Lang(..))
import RemoteData
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector exposing (attribute, containing, tag, text)
import TestSite
import Time
import Types exposing (..)
import View


testUser : AuthUser
testUser =
    { id = "u1"
    , authCollection = "local_users"
    , profileId = "profile1"
    , email = "u@example.fi"
    , token = "tok"
    , displayName = "Matti"
    , isReviewer = False
    }


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
    }


loggedOutModel : Model
loggedOutModel =
    { auth = LoggedOut
    , pbUrl = "http://localhost:8090"
    , emailInput = ""
    , otpInput = ""
    , authError = Nothing
    , displayNameInput = ""
    , page = LoginPage
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


suite : Test
suite =
    describe "View"
        [ describe "Dashboard entry limit (US-002)"
            [ test "a competition whose entries are used up shows the note instead of the button" <|
                \_ ->
                    View.view
                        { loggedOutModel
                            | auth = LoggedIn testUser
                            , page = DashboardPage
                            , competitions = RemoteData.Success [ { testCompetition | maxEntriesPerUser = Just 1 } ]
                            , myEntries = RemoteData.Success [ testEntry ]
                        }
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.has [ text "Olet käyttänyt kaikki osallistumispaikkasi tässä kilpailussa." ]
                            , Query.findAll [ tag "button", containing [ text "Osallistu" ] ] >> Query.count (Expect.equal 0)
                            ]
            ]
        , describe "My entries (US-007)"
            [ test "shows the competition's title and the reviewer's comment" <|
                \_ ->
                    View.view
                        { loggedOutModel
                            | auth = LoggedIn testUser
                            , page = MyEntriesPage
                            , myEntries =
                                RemoteData.Success
                                    [ { testEntry | status = Approved, publishedReviews = [ { total = 18, comment = Just "Upea!" } ] } ]
                        }
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.has [ text testCompetition.title ]
                            , Query.has [ text "Arvioijan kommentti: Upea!" ]
                            ]
            ]
        , describe "dashboard — admin UI link"
            [ test "reviewer sees Admin UI link" <|
                \_ ->
                    View.view { loggedOutModel | auth = LoggedIn { testUser | isReviewer = True }, page = DashboardPage }
                        |> Query.fromHtml
                        |> Query.findAll [ tag "a", containing [ text "Admin UI" ] ]
                        |> Query.count (Expect.equal 1)
            , test "non-reviewer does NOT see Admin UI link" <|
                \_ ->
                    View.view { loggedOutModel | auth = LoggedIn { testUser | isReviewer = False }, page = DashboardPage }
                        |> Query.fromHtml
                        |> Query.findAll [ tag "a", containing [ text "Admin UI" ] ]
                        |> Query.count (Expect.equal 0)
            ]
        , describe "layout — navigation"
            [ test "reviewer's navigation links to the review queue" <|
                \_ ->
                    View.view { loggedOutModel | auth = LoggedIn { testUser | isReviewer = True }, page = DashboardPage }
                        |> Query.fromHtml
                        |> Query.has [ tag "a", attribute (Html.Attributes.href "#/arvostelu") ]
            , test "non-reviewer's navigation has no link to the review queue" <|
                \_ ->
                    View.view { loggedOutModel | auth = LoggedIn testUser, page = DashboardPage }
                        |> Query.fromHtml
                        |> Query.findAll [ tag "a", attribute (Html.Attributes.href "#/arvostelu") ]
                        |> Query.count (Expect.equal 0)
            , test "page content sits in main#main-content" <|
                \_ ->
                    View.view loggedOutModel
                        |> Query.fromHtml
                        |> Query.has [ tag "main", attribute (Html.Attributes.id "main-content") ]
            ]
        , describe "viewError — role=alert"
            [ test "authError present renders role=alert" <|
                \_ ->
                    View.view { loggedOutModel | authError = Just "virhe" }
                        |> Query.fromHtml
                        |> Query.find [ attribute (Html.Attributes.attribute "role" "alert") ]
                        |> Query.has [ text "virhe" ]
            ]
        , describe "viewEntryRow — published review scores"
            [ test "entry with no published reviews shows no score" <|
                \_ ->
                    View.viewEntryRow Fi testEntry
                        |> Query.fromHtml
                        |> Query.findAll [ containing [ text "Pisteet:" ] ]
                        |> Query.count (Expect.equal 0)
            , test "entry with published reviews shows average score" <|
                \_ ->
                    -- Two reviews: total 16 and 18 → average 17.0 / 20
                    let
                        entryWithReviews =
                            { testEntry
                                | publishedReviews =
                                    [ { total = 16, comment = Nothing }
                                    , { total = 18, comment = Nothing }
                                    ]
                            }
                    in
                    View.viewEntryRow Fi entryWithReviews
                        |> Query.fromHtml
                        |> Query.findAll [ containing [ text "Pisteet: 17.0 / 20" ] ]
                        |> Query.count (Expect.equal 1)
            ]
        , describe "review form images"
            [ test "active review panel shows all entry images" <|
                \_ ->
                    let
                        entry =
                            { testEntry | images = [ "a.jpg", "b.jpg", "c.jpg" ] }

                        reviewableEntry =
                            { entry = entry
                            , competition = testCompetition
                            , submitterName = "Pekka"
                            , myReview = Nothing
                            }

                        model =
                            { loggedOutModel
                                | auth = LoggedIn { testUser | isReviewer = True }
                                , page = ReviewQueuePage
                                , activeReview =
                                    Just
                                        { reviewableEntry = reviewableEntry
                                        , draftReview =
                                            { id = Nothing
                                            , entryId = "entry1"
                                            , reviewerId = "profile1"
                                            , scoreTheme = 3
                                            , scoreOriginality = 3
                                            , scoreTechnique = 3
                                            , scorePresentation = 3
                                            , comment = ""
                                            , isPublished = False
                                            }
                                        , saving = False
                                        , saveError = Nothing
                                        }
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.find [ tag "main" ]
                        |> Query.findAll [ tag "img" ]
                        |> Query.count (Expect.equal 3)
            ]
        ]

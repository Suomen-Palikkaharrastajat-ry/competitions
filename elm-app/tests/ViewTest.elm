module ViewTest exposing (suite)

{-| Tests for view rendering: admin UI link, published review scores.

Given a model / user state
When the view is rendered
Then the correct HTML elements are present

-}

import Expect
import Html.Attributes
import RemoteData
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector exposing (attribute, containing, tag, text)
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
    , step = FillingForm
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
    , now = Time.millisToPosix 0
    , competitions = RemoteData.NotAsked
    , myEntries = RemoteData.NotAsked
    , submitForm = emptyForm
    , selectedCompetition = Nothing
    , reviewQueue = RemoteData.NotAsked
    , activeReview = Nothing
    , reviewFilter = AllEntries
    }


testEntry : Entry
testEntry =
    { id = "entry1"
    , competitionId = "comp1"
    , title = "My MOC"
    , description = Nothing
    , images = [ "photo.jpg" ]
    , status = Submitted
    , publishedReviews = []
    }


suite : Test
suite =
    describe "View"
        [ describe "viewHeader — admin UI link"
            [ test "reviewer sees Admin UI link" <|
                \_ ->
                    View.viewHeader { testUser | isReviewer = True } "http://localhost:8090"
                        |> Query.fromHtml
                        |> Query.findAll [ tag "a", containing [ text "Admin UI" ] ]
                        |> Query.count (Expect.equal 1)
            , test "non-reviewer does NOT see Admin UI link" <|
                \_ ->
                    View.viewHeader { testUser | isReviewer = False } "http://localhost:8090"
                        |> Query.fromHtml
                        |> Query.findAll [ tag "a", containing [ text "Admin UI" ] ]
                        |> Query.count (Expect.equal 0)
            ]
        , describe "viewHeader — nav aria-label"
            [ test "nav has aria-label=Sivunavigaatio" <|
                \_ ->
                    View.viewHeader testUser "http://localhost:8090"
                        |> Query.fromHtml
                        |> Query.find [ tag "nav" ]
                        |> Query.has [ attribute (Html.Attributes.attribute "aria-label" "Sivunavigaatio") ]
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
                    View.viewEntryRow testEntry
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
                    View.viewEntryRow entryWithReviews
                        |> Query.fromHtml
                        |> Query.findAll [ containing [ text "Pisteet: 17.0 / 20" ] ]
                        |> Query.count (Expect.equal 1)
            ]
        ]

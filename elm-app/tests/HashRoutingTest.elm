module HashRoutingTest exposing (suite)

{-| Tests for keeping the location hash and the page in step.

Given a user signing in or opening a deep link
When the browser reports hash changes
Then the display-name step cannot be skipped and Back stays in the app

-}

import Dict
import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Lang exposing (Lang(..))
import Main
import RemoteData
import SiteFixture
import Test exposing (Test, describe, test)
import TestSite
import Time
import Types exposing (..)


user : AuthUser
user =
    { id = "u1"
    , authCollection = "local_users"
    , profileId = "profile1"
    , email = "u@example.fi"
    , token = "tok"
    , displayName = "Matti"
    , isReviewer = False
    }


newUser : AuthUser
newUser =
    { user | displayName = "" }


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


loggedOut : Model
loggedOut =
    { auth = LoggedOut
    , pbUrl = "http://localhost:8090"
    , emailInput = ""
    , otpInput = ""
    , authError = Nothing
    , displayNameInput = ""
    , page = LoginPage
    , lang = Fi
    , site = Main.init (flags Nothing "") |> Tuple.first |> .site
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
    , criteria = TestSite.criteria Fi
    }


flags : Maybe AuthUser -> String -> Flags
flags restored hash =
    { pbUrl = "http://localhost:8090"
    , restoredAuth = restored
    , siteConfig = Decode.decodeString Decode.value SiteFixture.json |> Result.withDefault Encode.null
    , requestedLang = Nothing
    , hash = hash
    }


pageAfter : List Msg -> Model -> Page
pageAfter msgs model =
    List.foldl (\msg m -> Main.update msg m |> Tuple.first) model msgs |> .page


suite : Test
suite =
    describe "Hash routing"
        [ test "a fresh login from an empty hash stays on the display-name page" <|
            \_ ->
                loggedOut
                    |> pageAfter
                        [ KeycloakLoginCompleted { token = "tok", record = newUser }
                        , HashChanged "#/"
                        ]
                    |> Expect.equal SetDisplayNamePage
        , test "a login from a bookmarked #/omat stays on the display-name page" <|
            \_ ->
                loggedOut
                    |> pageAfter
                        [ HashChanged "#/omat"
                        , KeycloakLoginCompleted { token = "tok", record = newUser }
                        , HashChanged "#/"
                        ]
                    |> Expect.equal SetDisplayNamePage
        , test "Back to another hash cannot leave the display-name page" <|
            \_ ->
                loggedOut
                    |> pageAfter
                        [ KeycloakLoginCompleted { token = "tok", record = newUser }
                        , HashChanged "#/omat"
                        ]
                    |> Expect.equal SetDisplayNamePage
        , test "hash changes are ignored while logged out" <|
            \_ ->
                loggedOut
                    |> pageAfter [ HashChanged "#/omat" ]
                    |> Expect.equal LoginPage
        , test "a returning user follows the hash" <|
            \_ ->
                { loggedOut | auth = LoggedIn user, page = DashboardPage }
                    |> pageAfter [ HashChanged "#/omat" ]
                    |> Expect.equal MyEntriesPage
        , describe "Admin access"
            [ test "a non-reviewer deep link to #/admin opens the dashboard" <|
                \_ ->
                    Main.init (flags (Just user) "#/admin")
                        |> Tuple.first
                        |> .page
                        |> Expect.equal DashboardPage
            , test "a reviewer deep link to #/admin opens the admin home" <|
                \_ ->
                    Main.init (flags (Just { user | isReviewer = True }) "#/admin")
                        |> Tuple.first
                        |> .page
                        |> Expect.equal AdminPage
            , test "a reviewer reload on the entries of a competition opens them" <|
                \_ ->
                    Main.init (flags (Just { user | isReviewer = True }) "#/admin/osallistumiset/c1")
                        |> Tuple.first
                        |> .page
                        |> Expect.equal (AdminEntriesPage "c1")
            ]
        , test "a non-reviewer is sent to the dashboard from #/arvostelu without a fetch" <|
            \_ ->
                let
                    ( m, _ ) =
                        Main.update (HashChanged "#/arvostelu") { loggedOut | auth = LoggedIn user, page = MyEntriesPage }
                in
                Expect.equal ( DashboardPage, RemoteData.NotAsked ) ( m.page, m.reviewQueue )
        , test "a deep link to an unknown hash opens the dashboard" <|
            \_ ->
                Main.init (flags (Just user) "#/osallistu")
                    |> Tuple.first
                    |> .page
                    |> Expect.equal DashboardPage
        , test "a non-reviewer deep link to #/arvostelu opens the dashboard" <|
            \_ ->
                Main.init (flags (Just user) "#/arvostelu")
                    |> Tuple.first
                    |> (\m -> ( m.page, m.reviewQueue ))
                    |> Expect.equal ( DashboardPage, RemoteData.NotAsked )
        , test "a reviewer deep link to #/arvostelu opens the queue" <|
            \_ ->
                Main.init (flags (Just { user | isReviewer = True }) "#/arvostelu")
                    |> Tuple.first
                    |> .page
                    |> Expect.equal ReviewQueuePage
        , test "following the browser's hash never pushes an entry" <|
            \_ ->
                Expect.equal
                    [ Main.KeepHash, Main.ReplaceHash "#/", Main.ReplaceHash "#/" ]
                    [ Main.hashEffect MyEntriesPage MyEntriesPage (Just "#/omat")
                    , Main.hashEffect MyEntriesPage DashboardPage (Just "")
                    , Main.hashEffect MyEntriesPage DashboardPage (Just "#/osallistu")
                    ]
        , test "a canonical incoming hash is left alone" <|
            \_ ->
                Main.hashEffect DashboardPage MyEntriesPage (Just "#/omat")
                    |> Expect.equal Main.KeepHash
        , test "app-initiated navigation pushes the canonical hash" <|
            \_ ->
                Main.hashEffect DashboardPage MyEntriesPage Nothing
                    |> Expect.equal (Main.PushHash "#/omat")
        , test "no page change leaves the hash alone" <|
            \_ ->
                Main.hashEffect DashboardPage DashboardPage Nothing
                    |> Expect.equal Main.KeepHash
        ]

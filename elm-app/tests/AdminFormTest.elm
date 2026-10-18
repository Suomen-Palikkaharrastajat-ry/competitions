module AdminFormTest exposing (suite)

{-| Tests for the admin's competition form: what saving does with a valid,
invalid or rejected form.

Given the admin is editing a competition form
When it is saved, or the server answers
Then the form keeps its values and shows what is wrong

-}

import Dict
import Expect
import Http
import Lang exposing (Lang(..))
import Main exposing (update)
import RemoteData
import Test exposing (Test, describe, test)
import TestSite
import Time
import Types exposing (..)


validForm : CompetitionForm
validForm =
    { title = "Kaupunki"
    , slug = "kaupunki-2026"
    , theme = ""
    , description = ""
    , startDate = "2026-01-01"
    , endDate = "2026-06-01"
    , judgingEndDate = ""
    , maxEntriesPerUser = ""
    , minImagesPerEntry = ""
    , maxImagesPerEntry = ""
    , status = CDraft
    }


reviewer : AuthUser
reviewer =
    { id = "u1"
    , authCollection = "local_users"
    , profileId = "profile1"
    , email = "r@example.fi"
    , token = "tok"
    , displayName = "Reviewer"
    , isReviewer = True
    }


competitionForTest : Competition
competitionForTest =
    { id = "c1"
    , title = "Kevät"
    , slug = "kevat"
    , theme = Nothing
    , description = Nothing
    , startDate = "2026-01-01 00:00:00.000Z"
    , endDate = "2026-06-01 00:00:00.000Z"
    , judgingEndDate = Nothing
    , status = COpen
    , coverImage = Nothing
    , maxEntriesPerUser = Nothing
    , minImagesPerEntry = Nothing
    , maxImagesPerEntry = Nothing
    }


editing : Model
editing =
    { auth = LoggedIn reviewer
    , pbUrl = "http://localhost:8090"
    , emailInput = ""
    , otpInput = ""
    , authError = Nothing
    , displayNameInput = ""
    , page = AdminCompetitionPage Nothing
    , lang = Fi
    , site = TestSite.site Fi
    , menuOpen = False
    , now = Time.millisToPosix 0
    , competitions = RemoteData.NotAsked
    , myEntries = RemoteData.NotAsked
    , submitForm =
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
    , selectedCompetition = Nothing
    , reviewQueue = RemoteData.NotAsked
    , activeReview = Nothing
    , reviewFilter = AllEntries
    , adminCompetitions = RemoteData.NotAsked
    , adminForm = Just validForm
    , adminFormErrors = []
    , adminEntries = RemoteData.NotAsked
    , criteria = TestSite.criteria Fi
    }


suite : Test
suite =
    describe "Admin competition form"
        [ describe "SaveCompetition"
            [ test "an invalid form is kept and its errors are shown" <|
                \_ ->
                    let
                        ( updated, _ ) =
                            update SaveCompetition { editing | adminForm = Just { validForm | title = "" } }
                    in
                    ( updated.adminFormErrors, updated.adminForm == Just { validForm | title = "" } )
                        |> Expect.equal ( [ TitleRequired ], True )
            , test "a valid form clears earlier errors" <|
                \_ ->
                    let
                        ( updated, _ ) =
                            update SaveCompetition { editing | adminFormErrors = [ TitleRequired ] }
                    in
                    updated.adminFormErrors |> Expect.equal []
            ]
        , describe "CompetitionSaved"
            [ test "a rejected save keeps the form and says so" <|
                \_ ->
                    let
                        ( updated, _ ) =
                            update (CompetitionSaved (Err (Http.BadStatus 400))) editing
                    in
                    ( updated.adminFormErrors, updated.adminForm == Just validForm )
                        |> Expect.equal ( [ ServerRejected ], True )
            ]
        , describe "Entry status in the admin list"
            [ test "a status change updates the entry in the admin list" <|
                \_ ->
                    let
                        reviewable =
                            { entry = { id = "e1", competitionId = "c1", competition = Nothing, title = "MOC", description = Nothing, images = [], status = Submitted, publishedReviews = [] }
                            , competition = competitionForTest
                            , submitterName = "Aino"
                            , myReview = Nothing
                            }

                        ( updated, _ ) =
                            update (EntryStatusChanged "e1" Rejected (Ok ())) { editing | adminEntries = RemoteData.Success [ reviewable ] }
                    in
                    updated.adminEntries
                        |> RemoteData.map (List.map (\re -> re.entry.status))
                        |> Expect.equal (RemoteData.Success [ Rejected ])
            ]
        , describe "Loading the competitions of the edit page"
            [ test "the loaded competition fills an empty form" <|
                \_ ->
                    let
                        ( updated, _ ) =
                            update (AdminCompetitionsLoaded (Ok [ competitionForTest ]))
                                { editing | page = AdminCompetitionPage (Just "c1"), adminForm = Nothing }
                    in
                    updated.adminForm |> Maybe.map .slug |> Expect.equal (Just "kevat")
            , test "a late load does not overwrite what the admin is typing" <|
                \_ ->
                    let
                        ( updated, _ ) =
                            update (AdminCompetitionsLoaded (Ok [ competitionForTest ]))
                                { editing | page = AdminCompetitionPage (Just "c1"), adminForm = Just { validForm | title = "Muokattu" } }
                    in
                    updated.adminForm |> Maybe.map .title |> Expect.equal (Just "Muokattu")
            ]
        , describe "Status change"
            [ test "a status change keeps the page and the title being edited" <|
                \_ ->
                    let
                        ( updated, _ ) =
                            update (CompetitionStatusSaved (Ok { competitionForTest | status = CClosed }))
                                { editing | page = AdminCompetitionPage (Just "c1"), adminForm = Just { validForm | title = "Muokattu", status = COpen } }
                    in
                    ( updated.page, updated.adminForm |> Maybe.map (\f -> ( f.title, f.status )) )
                        |> Expect.equal ( AdminCompetitionPage (Just "c1"), Just ( "Muokattu", CClosed ) )
            ]
        , describe "AdminFieldChanged"
            [ test "changing a field updates the form" <|
                \_ ->
                    let
                        ( updated, _ ) =
                            update (AdminFieldChanged FieldSlug "kevat") editing
                    in
                    updated.adminForm
                        |> Maybe.map .slug
                        |> Expect.equal (Just "kevat")
            ]
        ]

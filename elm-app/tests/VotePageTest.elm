module VotePageTest exposing (suite)

{-| Tests for the vote page, the dashboard's voting list and the admin's vote
count (US-012, ADR-0007).

Given a signed-in user and a competition whose voting is running
When they open its vote page and rank entries
Then every entry is shown with its first image, the ballot keeps at most five
in order, and the ballot is only changed once the stored one has loaded.

Given a reviewer on a competition's entries page
When the competition has voting
Then the live vote result is shown, with the entries left out because their
submitter did not vote.

-}

import Expect
import Html.Attributes
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Main
import RemoteData
import SiteFixture
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector exposing (attribute, containing, id, tag, text)
import Types exposing (..)
import View
import Voting


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


{-| The app as opened from a link, signed in.
-}
openAt : AuthUser -> String -> ( Model, Cmd Msg )
openAt authUser hash =
    Main.init
        { pbUrl = "http://localhost:8090"
        , restoredAuth = Just authUser
        , siteConfig = Decode.decodeString Decode.value SiteFixture.json |> Result.withDefault Encode.null
        , requestedLang = Nothing
        , hash = hash
        }


votingCompetition : Competition
votingCompetition =
    { id = "comp1"
    , title = "Kesäkisa"
    , slug = "kesakisa"
    , theme = Nothing
    , description = Nothing
    , startDate = "2026-06-01 00:00:00.000Z"
    , endDate = "2026-07-01 00:00:00.000Z"
    , judgingEndDate = Nothing
    , status = CClosed
    , coverImage = Nothing
    , maxEntriesPerUser = Nothing
    , minImagesPerEntry = Nothing
    , maxImagesPerEntry = Nothing
    , votingEnabled = True
    , votingRequired = False
    , votingStartDate = Just "2026-07-07 00:00:00.000Z"
    , votingEndDate = Just "2026-07-15 00:00:00.000Z"
    }


candidate : String -> Entry
candidate n =
    { id = "e" ++ n
    , competitionId = "comp1"
    , competition = Nothing
    , submitterId = "p" ++ n
    , title = "Teos " ++ n
    , description = Nothing
    , images = [ "first" ++ n ++ ".jpg", "second" ++ n ++ ".jpg" ]
    , status = Approved
    , publishedReviews = []
    }


candidates : List Entry
candidates =
    List.map (String.fromInt >> candidate) (List.range 1 6)


{-| The vote page with its competition, entries and (no) stored ballot loaded.
-}
loadedVotePage : Competition -> Model
loadedVotePage competition =
    openAt user "#/aanestys/comp1"
        |> Tuple.first
        |> step (VoteCompetitionLoaded "comp1" (Ok competition))
        |> step (VoteCandidatesLoaded "comp1" (Ok candidates))
        |> step (MyBallotLoaded "comp1" (Ok Nothing))


step : Msg -> Model -> Model
step msg model =
    Main.update msg model |> Tuple.first


firstImageSrc : String -> String
firstImageSrc n =
    "http://localhost:8090/api/files/entries/e" ++ n ++ "/first" ++ n ++ ".jpg?thumb=400x300"


suite : Test
suite =
    describe "Voting pages"
        [ describe "dashboard"
            [ test "a competition whose voting runs is listed with a vote button" <|
                \_ ->
                    let
                        model =
                            openAt user "#/"
                                |> Tuple.first
                                |> step (VotingCompetitionsLoaded (Ok [ votingCompetition ]))
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.has [ text "Äänestys käynnissä" ]
                            , Query.has [ text "Äänestä viimeistään 14.7.2026" ]
                            , Query.find [ tag "button", containing [ text "Äänestä" ] ]
                                >> Event.simulate Event.click
                                >> Event.expect (NavigateTo (VotePage "comp1"))
                            ]
            , test "a failed load of the running votes says so" <|
                \_ ->
                    openAt user "#/"
                        |> Tuple.first
                        |> step (VotingCompetitionsLoaded (Err Http.NetworkError))
                        |> View.view
                        |> Query.fromHtml
                        |> Query.has [ text "Lataus epäonnistui." ]
            , test "without running votes there is no voting list" <|
                \_ ->
                    openAt user "#/"
                        |> Tuple.first
                        |> step (VotingCompetitionsLoaded (Ok []))
                        |> View.view
                        |> Query.fromHtml
                        |> Query.hasNot [ text "Äänestys käynnissä" ]
            ]
        , describe "vote page"
            [ test "a link opens the vote page with an empty ballot of the user" <|
                \_ ->
                    openAt user "#/aanestys/comp1"
                        |> Tuple.first
                        |> (\model -> ( model.page, model.voting.ballot ))
                        |> Expect.equal ( VotePage "comp1", Voting.emptyBallot "comp1" "profile1" )
            , test "every entry is shown with its first image" <|
                \_ ->
                    View.view (loadedVotePage votingCompetition)
                        |> Query.fromHtml
                        |> Expect.all
                            (List.map
                                (\n -> Query.has [ tag "img", attribute (Html.Attributes.src (firstImageSrc (String.fromInt n))) ])
                                (List.range 1 6)
                            )
            , test "a chosen entry is shown on its place with its first image and points" <|
                \_ ->
                    loadedVotePage votingCompetition
                        |> step (PickEntry "e3")
                        |> View.view
                        |> Query.fromHtml
                        |> Query.find [ id "ballot" ]
                        |> Expect.all
                            [ Query.has [ tag "img", attribute (Html.Attributes.src (firstImageSrc "3")) ]
                            , Query.has [ text "Teos 3" ]
                            , Query.has [ text "8 p" ]
                            ]
            , test "choosing an entry from the list puts it on the ballot" <|
                \_ ->
                    View.view (loadedVotePage votingCompetition)
                        |> Query.fromHtml
                        |> Query.find [ tag "button", attribute (Html.Attributes.attribute "aria-label" "Valitse: Teos 2") ]
                        |> Event.simulate Event.click
                        |> Event.expect (PickEntry "e2")
            , test "when five are chosen, the others cannot be chosen" <|
                \_ ->
                    List.foldl (\n model -> step (PickEntry ("e" ++ String.fromInt n)) model)
                        (loadedVotePage votingCompetition)
                        (List.range 1 5)
                        |> View.view
                        |> Query.fromHtml
                        |> Query.find [ tag "button", attribute (Html.Attributes.attribute "aria-label" "Lista on täynnä: Teos 6") ]
                        |> Query.has [ attribute (Html.Attributes.disabled True) ]
            , test "the ballot keeps the order of choosing, and a sixth choice is ignored" <|
                \_ ->
                    List.foldl (\n model -> step (PickEntry ("e" ++ String.fromInt n)) model)
                        (loadedVotePage votingCompetition)
                        [ 4, 2, 6, 1, 3, 5 ]
                        |> (.voting >> .ballot >> .ranking)
                        |> Expect.equal [ "e4", "e2", "e6", "e1", "e3" ]
            , test "nothing is chosen before the stored ballot has loaded" <|
                \_ ->
                    openAt user "#/aanestys/comp1"
                        |> Tuple.first
                        |> step (PickEntry "e1")
                        |> (.voting >> .ballot >> .ranking)
                        |> Expect.equal []
            , test "a stored ballot is shown for changing" <|
                \_ ->
                    openAt user "#/aanestys/comp1"
                        |> Tuple.first
                        |> step (VoteCompetitionLoaded "comp1" (Ok votingCompetition))
                        |> step (VoteCandidatesLoaded "comp1" (Ok candidates))
                        |> step (MyBallotLoaded "comp1" (Ok (Just { id = Just "v1", competitionId = "comp1", voterId = "profile1", ranking = [ "e2", "e1" ] })))
                        |> step (MoveEntryUp "e1")
                        |> .voting
                        |> (\voting -> ( voting.ballot.id, voting.ballot.ranking, voting.saved ))
                        |> Expect.equal ( Just "v1", [ "e1", "e2" ], False )
            , test "an empty ballot is not sent" <|
                \_ ->
                    loadedVotePage votingCompetition
                        |> step SaveBallot
                        |> .voting
                        |> (\voting -> ( voting.saving, voting.error ))
                        |> Expect.equal ( False, Just "Valitse vähintään yksi työ." )
            , test "a ballot refused by the server says why" <|
                \_ ->
                    loadedVotePage votingCompetition
                        |> step (PickEntry "e1")
                        |> step SaveBallot
                        |> step (BallotSaved "comp1" (Err { error = Http.BadStatus 400, message = Nothing }))
                        |> .voting
                        |> (\voting -> ( voting.saving, voting.error /= Nothing, voting.saved ))
                        |> Expect.equal ( False, True, False )
            , test "a refused ballot shows the server's reason" <|
                \_ ->
                    loadedVotePage votingCompetition
                        |> step (PickEntry "e1")
                        |> step SaveBallot
                        |> step (BallotSaved "comp1" (Err { error = Http.BadStatus 400, message = Just "Äänestys ei ole käynnissä" }))
                        |> (.voting >> .error)
                        |> Expect.equal (Just "Äänestys ei ole käynnissä")

            -- Given the voter moved on to another competition's vote page
            -- When a response about the previous one arrives late
            -- Then it does not change the ballot on screen
            , test "a late ballot of another competition is ignored" <|
                \_ ->
                    openAt user "#/aanestys/comp1"
                        |> Tuple.first
                        |> step (MyBallotLoaded "comp2" (Ok (Just { id = Just "v2", competitionId = "comp2", voterId = "profile1", ranking = [ "x" ] })))
                        |> .voting
                        |> (\voting -> ( voting.ballotLoaded, voting.ballot ))
                        |> Expect.equal ( False, Voting.emptyBallot "comp1" "profile1" )
            , test "a late save of another competition is ignored" <|
                \_ ->
                    loadedVotePage votingCompetition
                        |> step (BallotSaved "comp2" (Ok { id = Just "v2", competitionId = "comp2", voterId = "profile1", ranking = [ "x" ] }))
                        |> .voting
                        |> (\voting -> ( voting.saved, voting.ballot.id ))
                        |> Expect.equal ( False, Nothing )
            , test "late entries of another competition are ignored" <|
                \_ ->
                    openAt user "#/aanestys/comp1"
                        |> Tuple.first
                        |> step (VoteCandidatesLoaded "comp2" (Ok candidates))
                        |> (.voting >> .candidates)
                        |> Expect.equal RemoteData.Loading

            -- Given an entry on the stored ballot is no longer approved
            -- When the vote page loads
            -- Then it is taken off the ballot, which must be saved again
            , test "an entry that is no longer a candidate is dropped from the stored ballot" <|
                \_ ->
                    openAt user "#/aanestys/comp1"
                        |> Tuple.first
                        |> step (MyBallotLoaded "comp1" (Ok (Just { id = Just "v1", competitionId = "comp1", voterId = "profile1", ranking = [ "rejected", "e1" ] })))
                        |> step (VoteCandidatesLoaded "comp1" (Ok candidates))
                        |> .voting
                        |> (\voting -> ( voting.ballot.ranking, voting.saved ))
                        |> Expect.equal ( [ "e1" ], False )
            , test "the vote page shows the last day of voting" <|
                \_ ->
                    View.view (loadedVotePage votingCompetition)
                        |> Query.fromHtml
                        |> Query.has [ text "Äänestä viimeistään 14.7.2026" ]
            , test "a saved ballot is marked saved and keeps its id for the next change" <|
                \_ ->
                    loadedVotePage votingCompetition
                        |> step (PickEntry "e1")
                        |> step SaveBallot
                        |> step (BallotSaved "comp1" (Ok { id = Just "v9", competitionId = "comp1", voterId = "profile1", ranking = [ "e1" ] }))
                        |> .voting
                        |> (\voting -> ( voting.saved, voting.ballot.id ))
                        |> Expect.equal ( True, Just "v9" )
            , test "a required vote is explained to the voter" <|
                \_ ->
                    View.view (loadedVotePage { votingCompetition | votingRequired = True })
                        |> Query.fromHtml
                        |> Query.has [ text "Osallistujien on äänestettävä: jos osallistuja ei äänestä, hänen työnsä ei saa sijoitusta äänestyksen tuloksissa." ]
            , test "a competition without voting has no ballot" <|
                \_ ->
                    View.view (loadedVotePage { votingCompetition | votingEnabled = False })
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.has [ text "Tässä kilpailussa ei äänestetä." ]
                            , Query.hasNot [ id "ballot" ]
                            ]
            ]
        , describe "admin vote result"
            [ test "a failed load of the ballots says so" <|
                \_ ->
                    openAt { user | isReviewer = True } "#/admin/osallistumiset/comp1"
                        |> Tuple.first
                        |> step (AdminCompetitionsLoaded (Ok [ votingCompetition ]))
                        |> step (AdminEntriesLoaded (Ok []))
                        |> step (AdminBallotsLoaded "comp1" (Err Http.NetworkError))
                        |> View.view
                        |> Query.fromHtml
                        |> Query.find [ id "vote-result" ]
                        |> Query.has [ text "Lataus epäonnistui." ]
            , test "late ballots of another competition are ignored" <|
                \_ ->
                    openAt { user | isReviewer = True } "#/admin/osallistumiset/comp1"
                        |> Tuple.first
                        |> step (AdminBallotsLoaded "comp2" (Ok []))
                        |> (.voting >> .adminBallots)
                        |> Expect.equal RemoteData.Loading
            , test "shows the places and points, and the entries of non-voters" <|
                \_ ->
                    let
                        reviewer =
                            { user | isReviewer = True }

                        reviewable n =
                            { entry = candidate n, competition = votingCompetition, submitterName = "Rakentaja " ++ n, myReview = Nothing }

                        model =
                            openAt reviewer "#/admin/osallistumiset/comp1"
                                |> Tuple.first
                                |> step (AdminCompetitionsLoaded (Ok [ { votingCompetition | votingRequired = True } ]))
                                |> step (AdminEntriesLoaded (Ok [ reviewable "1", reviewable "2" ]))
                                |> step (AdminBallotsLoaded "comp1" (Ok [ { id = Just "v1", competitionId = "comp1", voterId = "p1", ranking = [ "e2", "e1" ] } ]))
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.find [ id "vote-result" ]
                        |> Expect.all
                            [ Query.has [ text "Ääniä: 1" ]
                            , Query.has [ text "Teos 1 — Rakentaja 1" ]
                            , Query.has [ text "5 p" ]
                            , Query.has [ text "Ei sijoitusta, koska osallistuja ei äänestänyt: Teos 2 (Rakentaja 2)" ]
                            ]
            ]
        ]

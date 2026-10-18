module Voting exposing
    ( Tally
    , TallyRow
    , ballotDecoder
    , emptyBallot
    , encodeBallot
    , init
    , isFull
    , lastDay
    , maxRanks
    , moveDown
    , moveUp
    , pick
    , points
    , tally
    , unpick
    )

{-| Ranked voting (ADR-0007): a voter ranks at most five entries of a
competition, and the votes are counted with fixed points.

    1st = 8, 2nd = 5, 3rd = 3, 4th = 2, 5th = 1 points

Equal points are broken by the number of first places, then of second places,
and so on; entries equal in all of these share a place and are listed by
title. When the competition
requires voting, an entry whose submitter cast no ballot is left out of the
result. The Haskell gallery (`GalleryTypes.rankByVotes`) counts the same way.

-}

import Dict exposing (Dict)
import Json.Decode as Decode
import Json.Encode as Encode
import RemoteData
import Scoring
import Time
import Types exposing (Ballot, Entry, VotingModel)


{-| The number of places on a ballot.
-}
maxRanks : Int
maxRanks =
    5


{-| The points of a place on the ballot (1st to 5th).
-}
points : Int -> Int
points place =
    case place of
        1 ->
            8

        2 ->
            5

        3 ->
            3

        4 ->
            2

        5 ->
            1

        _ ->
            0


{-| Nothing loaded yet.
-}
init : VotingModel
init =
    { openCompetitions = RemoteData.NotAsked
    , competition = RemoteData.NotAsked
    , candidates = RemoteData.NotAsked
    , ballot = emptyBallot "" ""
    , ballotLoaded = False
    , saving = False
    , saved = False
    , error = Nothing
    , adminBallots = RemoteData.NotAsked
    }


{-| A new ballot of a voter (a profile) in a competition.
-}
emptyBallot : String -> String -> Ballot
emptyBallot competitionId voterId =
    { id = Nothing, competitionId = competitionId, voterId = voterId, ranking = [] }


{-| True when the ballot has no free place left.
-}
isFull : List String -> Bool
isFull ranking =
    List.length ranking >= maxRanks


{-| Put an entry on the next free place. An entry already on the ballot, or
a sixth one, is ignored.
-}
pick : String -> List String -> List String
pick entryId ranking =
    if List.member entryId ranking || isFull ranking then
        ranking

    else
        ranking ++ [ entryId ]


{-| Take an entry off the ballot; the entries below it move up.
-}
unpick : String -> List String -> List String
unpick entryId ranking =
    List.filter ((/=) entryId) ranking


{-| Swap an entry with the one above it.
-}
moveUp : String -> List String -> List String
moveUp entryId ranking =
    List.reverse (moveDown entryId (List.reverse ranking))


{-| Swap an entry with the one below it.
-}
moveDown : String -> List String -> List String
moveDown entryId ranking =
    case ranking of
        first :: second :: rest ->
            if first == entryId then
                second :: first :: rest

            else
                first :: moveDown entryId (second :: rest)

        _ ->
            ranking


{-| The last day one can vote ("D.M.YYYY", UTC), from the voting end: the
day before when voting closes at midnight (ADR-0007).
-}
lastDay : String -> Maybe String
lastDay votingEnd =
    Scoring.parseDateToMillis votingEnd
        |> Maybe.map
            (\millis ->
                let
                    posix =
                        Time.millisToPosix (millis - 1)
                in
                String.fromInt (Time.toDay Time.utc posix)
                    ++ "."
                    ++ String.fromInt (monthNumber (Time.toMonth Time.utc posix))
                    ++ "."
                    ++ String.fromInt (Time.toYear Time.utc posix)
            )


monthNumber : Time.Month -> Int
monthNumber month =
    case month of
        Time.Jan ->
            1

        Time.Feb ->
            2

        Time.Mar ->
            3

        Time.Apr ->
            4

        Time.May ->
            5

        Time.Jun ->
            6

        Time.Jul ->
            7

        Time.Aug ->
            8

        Time.Sep ->
            9

        Time.Oct ->
            10

        Time.Nov ->
            11

        Time.Dec ->
            12



-- COUNTING


{-| One entry of the vote result.
-}
type alias TallyRow =
    { entry : Entry
    , points : Int
    , place : Int
    }


{-| The vote result: the ranked entries, and the entries left out because
their submitter did not vote although voting was required.
-}
type alias Tally =
    { ranked : List TallyRow
    , excluded : List Entry
    }


{-| Count the ballots over the entries (the competition's approved ones). The
first argument tells whether voting is required of the participants.
-}
tally : Bool -> List Entry -> List Ballot -> Tally
tally required entries ballots =
    let
        voters =
            List.map .voterId ballots

        ( counted, excluded ) =
            List.partition (\entry -> not required || List.member entry.submitterId voters) entries

        countedIds =
            List.map .id counted

        -- Entry id -> how many times it was chosen at each place, 1st to 5th.
        placeCounts : Dict String (List Int)
        placeCounts =
            List.foldl
                (\ballot acc ->
                    ballot.ranking
                        |> List.take maxRanks
                        |> List.indexedMap Tuple.pair
                        |> List.foldl
                            (\( index, entryId ) inner ->
                                if List.member entryId countedIds then
                                    Dict.update entryId (Just << addAt index << Maybe.withDefault noPlaces) inner

                                else
                                    inner
                            )
                            acc
                )
                Dict.empty
                ballots

        key entry =
            let
                counts =
                    Dict.get entry.id placeCounts |> Maybe.withDefault noPlaces
            in
            ( totalPoints counts, counts )

        keyed =
            List.map (\entry -> ( key entry, entry )) counted
                |> List.sortWith
                    (\( a, entryA ) ( b, entryB ) ->
                        case compare b a of
                            EQ ->
                                compare ( entryA.title, entryA.id ) ( entryB.title, entryB.id )

                            order ->
                                order
                    )

        keys =
            List.map Tuple.first keyed
    in
    { ranked =
        List.map
            (\( entryKey, entry ) ->
                { entry = entry
                , points = Tuple.first entryKey
                , place = 1 + List.length (List.filter (\other -> other > entryKey) keys)
                }
            )
            keyed
    , excluded = excluded
    }


noPlaces : List Int
noPlaces =
    List.repeat maxRanks 0


addAt : Int -> List Int -> List Int
addAt index =
    List.indexedMap
        (\i count ->
            if i == index then
                count + 1

            else
                count
        )


totalPoints : List Int -> Int
totalPoints counts =
    counts
        |> List.indexedMap (\index count -> count * points (index + 1))
        |> List.sum



-- JSON


{-| The ballot as PocketBase stores it.
-}
encodeBallot : Ballot -> Encode.Value
encodeBallot ballot =
    Encode.object
        [ ( "competition", Encode.string ballot.competitionId )
        , ( "voter", Encode.string ballot.voterId )
        , ( "ranking", Encode.list Encode.string ballot.ranking )
        ]


{-| A stored ballot. A missing or empty ranking reads as an empty one.
-}
ballotDecoder : Decode.Decoder Ballot
ballotDecoder =
    Decode.map4 Ballot
        (Decode.map Just (Decode.field "id" Decode.string))
        (Decode.field "competition" Decode.string)
        (Decode.field "voter" Decode.string)
        (Decode.oneOf
            [ Decode.field "ranking" (Decode.list Decode.string)
            , Decode.succeed []
            ]
        )

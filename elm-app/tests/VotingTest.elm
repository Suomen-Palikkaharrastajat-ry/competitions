module VotingTest exposing (suite)

{-| Tests for ranked voting (ADR-0007): building a ballot and counting the votes.

Given a ballot of at most five entries in preference order
When entries are picked, removed and moved
Then the ballot keeps its order, has no duplicates and never grows past five.

Given the ballots of a competition
When the votes are counted
Then the 1st to 5th choices give 8, 5, 3, 2 and 1 points, ties are broken by
the number of first places (then second places…), and when voting is required
an entry whose submitter cast no ballot is left out.

-}

import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (Test, describe, test)
import Types exposing (Ballot, Entry, EntryStatus(..))
import Voting


entry : String -> String -> Entry
entry id submitterId =
    { id = id
    , competitionId = "comp1"
    , competition = Nothing
    , submitterId = submitterId
    , title = "Entry " ++ id
    , description = Nothing
    , images = [ id ++ ".png" ]
    , status = Approved
    , publishedReviews = []
    }


titled : String -> Entry -> Entry
titled title e =
    { e | title = title }


ballot : String -> List String -> Ballot
ballot voterId ranking =
    { id = Just ("vote-" ++ voterId), competitionId = "comp1", voterId = voterId, ranking = ranking }


placesAndPoints : Voting.Tally -> List ( Int, String, Int )
placesAndPoints result =
    List.map (\row -> ( row.place, row.entry.id, row.points )) result.ranked


suite : Test
suite =
    describe "Voting"
        [ describe "points"
            [ test "1st to 5th give 8, 5, 3, 2 and 1 points" <|
                \_ ->
                    List.map Voting.points [ 1, 2, 3, 4, 5 ]
                        |> Expect.equal [ 8, 5, 3, 2, 1 ]
            , test "outside the five places gives nothing" <|
                \_ ->
                    List.map Voting.points [ 0, 6 ]
                        |> Expect.equal [ 0, 0 ]
            ]
        , describe "pick"
            [ test "adds the entry to the next free place" <|
                \_ ->
                    Voting.pick "b" [ "a" ]
                        |> Expect.equal [ "a", "b" ]
            , test "ignores an entry already on the ballot" <|
                \_ ->
                    Voting.pick "a" [ "a", "b" ]
                        |> Expect.equal [ "a", "b" ]
            , test "ignores a sixth entry" <|
                \_ ->
                    Voting.pick "f" [ "a", "b", "c", "d", "e" ]
                        |> Expect.equal [ "a", "b", "c", "d", "e" ]
            , test "a ballot of five is full" <|
                \_ ->
                    ( Voting.isFull [ "a", "b", "c", "d" ], Voting.isFull [ "a", "b", "c", "d", "e" ] )
                        |> Expect.equal ( False, True )
            ]
        , describe "unpick and move"
            [ test "removing an entry moves the later ones up" <|
                \_ ->
                    Voting.unpick "b" [ "a", "b", "c" ]
                        |> Expect.equal [ "a", "c" ]
            , test "moving up swaps with the place above" <|
                \_ ->
                    Voting.moveUp "c" [ "a", "b", "c" ]
                        |> Expect.equal [ "a", "c", "b" ]
            , test "moving the first up keeps the order" <|
                \_ ->
                    Voting.moveUp "a" [ "a", "b" ]
                        |> Expect.equal [ "a", "b" ]
            , test "moving down swaps with the place below" <|
                \_ ->
                    Voting.moveDown "a" [ "a", "b", "c" ]
                        |> Expect.equal [ "b", "a", "c" ]
            , test "moving the last down keeps the order" <|
                \_ ->
                    Voting.moveDown "c" [ "a", "b", "c" ]
                        |> Expect.equal [ "a", "b", "c" ]
            ]
        , describe "tally"
            [ test "sums the points of every ballot, best first" <|
                \_ ->
                    -- a: 8 + 3 = 11, b: 5 + 8 = 13, c: 5
                    Voting.tally False
                        [ entry "a" "pa", entry "b" "pb", entry "c" "pc" ]
                        [ ballot "v1" [ "a", "b" ], ballot "v2" [ "b", "c", "a" ] ]
                        |> placesAndPoints
                        |> Expect.equal [ ( 1, "b", 13 ), ( 2, "a", 11 ), ( 3, "c", 5 ) ]
            , test "an entry nobody chose is listed last with no points" <|
                \_ ->
                    Voting.tally False
                        [ entry "a" "pa", entry "b" "pb" ]
                        [ ballot "v1" [ "a" ] ]
                        |> placesAndPoints
                        |> Expect.equal [ ( 1, "a", 8 ), ( 2, "b", 0 ) ]
            , test "equal points are broken by the number of first places" <|
                \_ ->
                    -- a: 5 + 5 = 10 (no 1st places), b: 8 + 2 = 10 (one 1st place)
                    Voting.tally False
                        [ entry "a" "pa", entry "b" "pb", entry "x" "px", entry "y" "py" ]
                        [ ballot "v1" [ "b", "a" ], ballot "v2" [ "x", "a", "y", "b" ] ]
                        |> placesAndPoints
                        |> List.take 2
                        |> Expect.equal [ ( 1, "b", 10 ), ( 2, "a", 10 ) ]
            , test "fully equal entries share a place" <|
                \_ ->
                    Voting.tally False
                        [ entry "a" "pa", entry "b" "pb" ]
                        [ ballot "v1" [ "a", "b" ], ballot "v2" [ "b", "a" ] ]
                        |> placesAndPoints
                        |> Expect.equal [ ( 1, "a", 13 ), ( 1, "b", 13 ) ]
            , test "entries sharing a place are listed by title" <|
                \_ ->
                    Voting.tally False
                        [ titled "Zeta" (entry "b" "pb"), titled "Alpha" (entry "a" "pa") ]
                        []
                        |> .ranked
                        |> List.map (\row -> ( row.place, row.entry.title ))
                        |> Expect.equal [ ( 1, "Alpha" ), ( 1, "Zeta" ) ]
            , test "a choice of an entry not in the competition is ignored" <|
                \_ ->
                    Voting.tally False
                        [ entry "a" "pa" ]
                        [ ballot "v1" [ "gone", "a" ] ]
                        |> placesAndPoints
                        |> Expect.equal [ ( 1, "a", 5 ) ]
            , test "when voting is required, an entry of a non-voter is left out" <|
                \_ ->
                    let
                        result =
                            Voting.tally True
                                [ entry "a" "pa", entry "b" "pb" ]
                                [ ballot "pa" [ "b", "a" ] ]
                    in
                    ( placesAndPoints result, List.map .id result.excluded )
                        |> Expect.equal ( [ ( 1, "a", 5 ) ], [ "b" ] )
            , test "when voting is optional, nobody is left out" <|
                \_ ->
                    Voting.tally False
                        [ entry "a" "pa", entry "b" "pb" ]
                        [ ballot "pa" [ "b", "a" ] ]
                        |> .excluded
                        |> Expect.equal []
            ]
        , describe "lastDay"
            [ test "voting that closes at midnight ends on the day before" <|
                \_ -> Voting.lastDay "2026-07-15 00:00:00.000Z" |> Expect.equal (Just "14.7.2026")
            , test "voting that closes during a day ends on that day" <|
                \_ -> Voting.lastDay "2026-07-15 12:00:00.000Z" |> Expect.equal (Just "15.7.2026")
            , test "the day before the 1st is the last of the previous month" <|
                \_ -> Voting.lastDay "2026-03-01 00:00:00.000Z" |> Expect.equal (Just "28.2.2026")
            , test "an unreadable date gives nothing" <|
                \_ -> Voting.lastDay "" |> Expect.equal Nothing
            ]
        , describe "JSON"
            [ test "a ballot is sent with its competition, voter and ranking" <|
                \_ ->
                    Voting.encodeBallot (ballot "p1" [ "a", "b" ])
                        |> Encode.encode 0
                        |> Expect.equal "{\"competition\":\"comp1\",\"voter\":\"p1\",\"ranking\":[\"a\",\"b\"]}"
            , test "a stored ballot is read back" <|
                \_ ->
                    Decode.decodeString Voting.ballotDecoder
                        "{\"id\":\"vote-p1\",\"competition\":\"comp1\",\"voter\":\"p1\",\"ranking\":[\"a\",\"b\"]}"
                        |> Expect.equal (Ok (ballot "p1" [ "a", "b" ]))
            , test "a stored ballot without a ranking reads as empty" <|
                \_ ->
                    Decode.decodeString Voting.ballotDecoder
                        "{\"id\":\"vote-p1\",\"competition\":\"comp1\",\"voter\":\"p1\",\"ranking\":null}"
                        |> Result.map .ranking
                        |> Expect.equal (Ok [])
            ]
        ]

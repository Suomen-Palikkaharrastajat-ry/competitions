module DecoderTest exposing (suite)

{-| Tests for PocketBase response decoders.

Given a JSON payload from PocketBase
When decoded with the competition/entry/auth decoders
Then all fields are correctly populated

These decoders are implemented in Main.elm and cover competitions, entries, and auth responses.

-}

import Expect
import Json.Decode as Decode
import Main exposing (authResponseDecoder, competitionDecoder, entryDecoder, myEntriesUrl, otpResponseDecoder, reviewQueueUrl, votingCompetitionsUrl)
import Test exposing (Test, describe, test)
import Types exposing (CompetitionStatus(..), EntryStatus(..))



-- ---------------------------------------------------------------------------
-- Minimal decoders (stubs — expanded in TODO-02/03/04)
-- ---------------------------------------------------------------------------


type alias Competition =
    { id : String
    , title : String
    , slug : String
    , status : String
    }


decodeCompetition : Decode.Decoder Competition
decodeCompetition =
    Decode.map4 Competition
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "slug" Decode.string)
        (Decode.field "status" Decode.string)


type alias Entry =
    { id : String
    , title : String
    , status : String
    , images : List String
    }


decodeEntry : Decode.Decoder Entry
decodeEntry =
    Decode.map4 Entry
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "status" Decode.string)
        (Decode.field "images" (Decode.list Decode.string))



-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------


suite : Test
suite =
    describe "PocketBase decoders"
        [ describe "Competition decoder"
            [ test "decodes a valid competition JSON" <|
                \_ ->
                    let
                        json =
                            """{"id":"abc123","title":"Test Competition","slug":"test-2026","status":"open","start_date":"2026-01-01 00:00:00.000Z","end_date":"2026-06-01 00:00:00.000Z"}"""

                        result =
                            Decode.decodeString decodeCompetition json
                    in
                    case result of
                        Ok comp ->
                            Expect.all
                                [ \_ -> Expect.equal "abc123" comp.id
                                , \_ -> Expect.equal "Test Competition" comp.title
                                , \_ -> Expect.equal "test-2026" comp.slug
                                , \_ -> Expect.equal "open" comp.status
                                ]
                                ()

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "fails on missing required fields" <|
                \_ ->
                    let
                        json =
                            """{"id":"abc123"}"""

                        result =
                            Decode.decodeString decodeCompetition json
                    in
                    case result of
                        Ok _ ->
                            Expect.fail "Should have failed"

                        Err _ ->
                            Expect.pass
            ]
        , describe "Entry decoder"
            [ test "decodes a valid entry JSON" <|
                \_ ->
                    let
                        json =
                            """{"id":"entry1","title":"My MOC","status":"approved","images":["img1.jpg","img2.jpg"]}"""

                        result =
                            Decode.decodeString decodeEntry json
                    in
                    case result of
                        Ok entry ->
                            Expect.all
                                [ \_ -> Expect.equal "entry1" entry.id
                                , \_ -> Expect.equal "My MOC" entry.title
                                , \_ -> Expect.equal "approved" entry.status
                                , \_ -> Expect.equal 2 (List.length entry.images)
                                ]
                                ()

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "images field returns a list of filenames" <|
                \_ ->
                    let
                        json =
                            """{"id":"e1","title":"MOC","status":"draft","images":["photo.jpg"]}"""

                        result =
                            Decode.decodeString decodeEntry json
                    in
                    case result of
                        Ok entry ->
                            Expect.equal [ "photo.jpg" ] entry.images

                        Err err ->
                            Expect.fail (Decode.errorToString err)

            -- Given a logged-in participant's profile id
            -- When the app builds the "Omat osallistumiset" PocketBase URL
            -- Then it sorts newest first by the entry creation timestamp and expands competition plus published reviews.
            , test "builds my entries URL with competition and review expands" <|
                \_ ->
                    myEntriesUrl "http://127.0.0.1:8080" "profile123"
                        |> Expect.equal
                            "http://127.0.0.1:8080/api/collections/entries/records?filter=submitter%3D%22profile123%22&sort=-created&expand=competition%2Creviews_via_entry"
            , test "builds the review queue URL asking for up to 200 entries, not the default 30" <|
                \_ ->
                    reviewQueueUrl "http://127.0.0.1:8080"
                        |> Expect.equal
                            "http://127.0.0.1:8080/api/collections/entries/records?filter=status%3D%22submitted%22||status%3D%22approved%22||status%3D%22rejected%22&expand=competition%2Csubmitter%2Creviews_via_entry&sort=created&perPage=200"
            ]
        , describe "Competition status"
            [ test "competitionDecoder reads status and judging_end_date" <|
                \_ ->
                    let
                        json =
                            """{"id":"c1","title":"T","slug":"t","status":"judging","start_date":"2026-01-01 00:00:00.000Z","end_date":"2026-06-01 00:00:00.000Z","judging_end_date":"2026-07-01 00:00:00.000Z"}"""
                    in
                    Decode.decodeString competitionDecoder json
                        |> Result.map (\c -> ( c.status, c.judgingEndDate ))
                        |> Expect.equal (Ok ( CJudging, Just "2026-07-01 00:00:00.000Z" ))
            , test "competitionDecoder reads the voting settings and period" <|
                \_ ->
                    let
                        json =
                            """{"id":"c1","title":"T","slug":"t","status":"closed","start_date":"2026-01-01 00:00:00.000Z","end_date":"2026-06-01 00:00:00.000Z","voting_enabled":true,"voting_required":true,"voting_start_date":"2026-07-07 00:00:00.000Z","voting_end_date":"2026-07-15 00:00:00.000Z"}"""
                    in
                    Decode.decodeString competitionDecoder json
                        |> Result.map (\c -> ( ( c.votingEnabled, c.votingRequired ), ( c.votingStartDate, c.votingEndDate ) ))
                        |> Expect.equal (Ok ( ( True, True ), ( Just "2026-07-07 00:00:00.000Z", Just "2026-07-15 00:00:00.000Z" ) ))
            , test "an unset voting period (empty dates) reads as none, and voting as off" <|
                \_ ->
                    let
                        json =
                            """{"id":"c1","title":"T","slug":"t","start_date":"2026-01-01 00:00:00.000Z","end_date":"2026-06-01 00:00:00.000Z","voting_start_date":"","voting_end_date":""}"""
                    in
                    Decode.decodeString competitionDecoder json
                        |> Result.map (\c -> ( c.votingEnabled, c.votingStartDate, c.votingEndDate ))
                        |> Expect.equal (Ok ( False, Nothing, Nothing ))
            , test "the dashboard asks PocketBase for the competitions whose voting runs now" <|
                \_ ->
                    votingCompetitionsUrl "http://127.0.0.1:8080"
                        |> Expect.equal
                            "http://127.0.0.1:8080/api/collections/competitions/records?filter=voting_enabled%20%3D%20true%20%26%26%20status%20!%3D%20%22draft%22%20%26%26%20voting_start_date%20!%3D%20%22%22%20%26%26%20voting_start_date%20%3C%3D%20%40now%20%26%26%20voting_end_date%20%3E%20%40now&sort=voting_end_date"
            , test "a missing status is a draft" <|
                \_ ->
                    let
                        json =
                            """{"id":"c1","title":"T","slug":"t","start_date":"2026-01-01 00:00:00.000Z","end_date":"2026-06-01 00:00:00.000Z"}"""
                    in
                    Decode.decodeString competitionDecoder json
                        |> Result.map .status
                        |> Expect.equal (Ok CDraft)
            ]
        , describe "Auth decoders"
            [ test "otpResponseDecoder decodes otpId" <|
                \_ ->
                    let
                        json =
                            """{"otpId":"abc123xyz"}"""

                        result =
                            Decode.decodeString otpResponseDecoder json
                    in
                    case result of
                        Ok resp ->
                            Expect.equal "abc123xyz" resp.otpId

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "authResponseDecoder decodes token and record" <|
                \_ ->
                    let
                        json =
                            """{"token":"eyJtoken","record":{"id":"u1","collectionName":"local_users","profile_id":"p1","email":"u@example.fi","display_name":"Pekka","is_reviewer":false}}"""

                        result =
                            Decode.decodeString authResponseDecoder json
                    in
                    case result of
                        Ok resp ->
                            Expect.all
                                [ \_ -> Expect.equal "eyJtoken" resp.token
                                , \_ -> Expect.equal "u1" resp.record.id
                                , \_ -> Expect.equal "local_users" resp.record.authCollection
                                , \_ -> Expect.equal "p1" resp.record.profileId
                                , \_ -> Expect.equal "u@example.fi" resp.record.email
                                , \_ -> Expect.equal "Pekka" resp.record.displayName
                                , \_ -> Expect.equal False resp.record.isReviewer
                                ]
                                ()

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "authResponseDecoder copies token into record" <|
                \_ ->
                    let
                        json =
                            """{"token":"eyJtoken","record":{"id":"u1","email":"u@example.fi"}}"""

                        result =
                            Decode.decodeString authResponseDecoder json
                    in
                    case result of
                        Ok resp ->
                            Expect.equal "eyJtoken" resp.record.token

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "authResponseDecoder handles missing optional fields" <|
                \_ ->
                    let
                        json =
                            """{"token":"tok","record":{"id":"u1","email":"u@example.fi"}}"""

                        result =
                            Decode.decodeString authResponseDecoder json
                    in
                    case result of
                        Ok resp ->
                            Expect.all
                                [ \_ -> Expect.equal "" resp.record.displayName
                                , \_ -> Expect.equal False resp.record.isReviewer
                                ]
                                ()

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            ]
        , describe "Competition PocketBase decoder"
            [ test "decodes all fields" <|
                \_ ->
                    let
                        json =
                            """{"id":"c1","title":"Kaupunki 2026","slug":"kaupunki-2026","theme":"Kaupunki","description":"Kuvaile kaupunkia","start_date":"2026-01-01 00:00:00.000Z","end_date":"2026-06-01 00:00:00.000Z","cover_image":"","max_entries_per_user":3,"min_images_per_entry":2,"max_images_per_entry":8}"""

                        result =
                            Decode.decodeString competitionDecoder json
                    in
                    case result of
                        Ok comp ->
                            Expect.all
                                [ \_ -> Expect.equal "c1" comp.id
                                , \_ -> Expect.equal "Kaupunki 2026" comp.title
                                , \_ -> Expect.equal "kaupunki-2026" comp.slug
                                , \_ -> Expect.equal (Just "Kaupunki") comp.theme
                                , \_ -> Expect.equal (Just 3) comp.maxEntriesPerUser
                                , \_ -> Expect.equal (Just 2) comp.minImagesPerEntry
                                , \_ -> Expect.equal (Just 8) comp.maxImagesPerEntry
                                ]
                                ()

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "empty cover_image decoded as Nothing" <|
                \_ ->
                    let
                        json =
                            """{"id":"c1","title":"T","slug":"t","start_date":"2025-01-01 00:00:00.000Z","end_date":"2026-01-01 00:00:00.000Z","cover_image":""}"""

                        result =
                            Decode.decodeString competitionDecoder json
                    in
                    case result of
                        Ok comp ->
                            comp.coverImage |> Expect.equal Nothing

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "missing image limit fields decode as Nothing" <|
                \_ ->
                    let
                        json =
                            """{"id":"c1","title":"T","slug":"t","start_date":"2025-01-01 00:00:00.000Z","end_date":"2026-01-01 00:00:00.000Z","cover_image":""}"""

                        result =
                            Decode.decodeString competitionDecoder json
                    in
                    case result of
                        Ok comp ->
                            Expect.all
                                [ \_ -> Expect.equal Nothing comp.minImagesPerEntry
                                , \_ -> Expect.equal Nothing comp.maxImagesPerEntry
                                ]
                                ()

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            ]
        , describe "Entry PocketBase decoder"
            [ test "decodes status draft" <|
                \_ ->
                    let
                        json =
                            """{"id":"e1","competition":"c1","title":"My MOC","images":["photo.jpg"],"status":"draft"}"""

                        result =
                            Decode.decodeString entryDecoder json
                    in
                    case result of
                        Ok entry ->
                            entry.status |> Expect.equal Draft

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "decodes the submitter's profile id" <|
                \_ ->
                    Decode.decodeString entryDecoder """{"id":"e1","competition":"c1","submitter":"p1","title":"My MOC","images":[],"status":"approved"}"""
                        |> Result.map .submitterId
                        |> Expect.equal (Ok "p1")
            , test "decodes status submitted" <|
                \_ ->
                    let
                        json =
                            """{"id":"e1","competition":"c1","title":"My MOC","images":[],"status":"submitted"}"""

                        result =
                            Decode.decodeString entryDecoder json
                    in
                    case result of
                        Ok entry ->
                            entry.status |> Expect.equal Submitted

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "decodes images list" <|
                \_ ->
                    let
                        json =
                            """{"id":"e1","competition":"c1","title":"MOC","images":["a.jpg","b.jpg"],"status":"draft"}"""

                        result =
                            Decode.decodeString entryDecoder json
                    in
                    case result of
                        Ok entry ->
                            List.length entry.images |> Expect.equal 2

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "decodes missing expanded competition as Nothing" <|
                \_ ->
                    let
                        json =
                            """{"id":"e1","competition":"c1","title":"MOC","images":["a.jpg"],"status":"draft"}"""

                        result =
                            Decode.decodeString entryDecoder json
                    in
                    case result of
                        Ok entry ->
                            entry.competition |> Expect.equal Nothing

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "decodes expanded competition for draft editing" <|
                \_ ->
                    let
                        json =
                            """{"id":"e1","competition":"c1","title":"MOC","images":["a.jpg"],"status":"draft","expand":{"competition":{"id":"c1","title":"Kaupunki 2026","slug":"kaupunki-2026","start_date":"2026-01-01 00:00:00.000Z","end_date":"2026-06-01 00:00:00.000Z","cover_image":"","min_images_per_entry":2,"max_images_per_entry":8}}}"""

                        result =
                            Decode.decodeString entryDecoder json
                    in
                    case result of
                        Ok entry ->
                            case entry.competition of
                                Just comp ->
                                    Expect.all
                                        [ \_ -> Expect.equal "c1" comp.id
                                        , \_ -> Expect.equal (Just 2) comp.minImagesPerEntry
                                        , \_ -> Expect.equal (Just 8) comp.maxImagesPerEntry
                                        ]
                                        ()

                                Nothing ->
                                    Expect.fail "Expected expanded competition"

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            ]
        ]

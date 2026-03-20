module DecoderTest exposing (suite)

{-| Tests for PocketBase response decoders.

Given  a JSON payload from PocketBase
When   decoded with the competition/entry decoders
Then   all fields are correctly populated

These decoders will be implemented in TODO-02/03/04.
This file defines the expected shapes as compile-time documentation.
-}

import Expect
import Json.Decode as Decode
import Test exposing (Test, describe, test)


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
            ]
        ]

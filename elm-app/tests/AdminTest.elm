module AdminTest exposing (suite)

{-| Tests for the admin's competition helpers: the status lifecycle, the form
checks and the request body.

Given a competition form or status
When it is checked, moved along, or encoded
Then the lifecycle, the errors and the JSON are as the admin expects

-}

import Admin
import Expect
import Json.Encode as Encode
import Test exposing (Test, describe, test)
import Types exposing (AdminField(..), Competition, CompetitionForm, CompetitionStatus(..), FormError(..))


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


sampleCompetition : Competition
sampleCompetition =
    { id = "c1"
    , title = "Kaupunki"
    , slug = "kaupunki-2026"
    , theme = Nothing
    , description = Nothing
    , startDate = "2026-01-01 00:00:00.000Z"
    , endDate = "2026-12-31 23:59:59.000Z"
    , judgingEndDate = Just "2027-01-15 00:00:00.000Z"
    , status = COpen
    , coverImage = Nothing
    , maxEntriesPerUser = Just 3
    , minImagesPerEntry = Nothing
    , maxImagesPerEntry = Nothing
    }


suite : Test
suite =
    describe "Admin"
        [ describe "status lifecycle"
            [ test "nextStatus walks from draft to finished" <|
                \_ ->
                    [ CDraft, COpen, CClosed, CJudging ]
                        |> List.map Admin.nextStatus
                        |> Expect.equal [ Just COpen, Just CClosed, Just CJudging, Just CFinished ]
            , test "a finished competition has no next status" <|
                \_ -> Admin.nextStatus CFinished |> Expect.equal Nothing
            , test "previousStatus walks back and a draft has none" <|
                \_ ->
                    ( Admin.previousStatus COpen, Admin.previousStatus CDraft )
                        |> Expect.equal ( Just CDraft, Nothing )
            , test "statusToString round-trips with statusFromString" <|
                \_ ->
                    [ CDraft, COpen, CClosed, CJudging, CFinished ]
                        |> List.map (Admin.statusToString >> Admin.statusFromString)
                        |> Expect.equal [ Just CDraft, Just COpen, Just CClosed, Just CJudging, Just CFinished ]
            ]
        , describe "validateCompetitionForm"
            [ test "a complete form has no errors" <|
                \_ -> Admin.validateCompetitionForm validForm |> Expect.equal []
            , test "the title is required" <|
                \_ ->
                    Admin.validateCompetitionForm { validForm | title = "  " }
                        |> Expect.equal [ TitleRequired ]
            , test "the slug may only use lowercase letters, digits and dashes" <|
                \_ ->
                    Admin.validateCompetitionForm { validForm | slug = "Kaupunki 2026" }
                        |> Expect.equal [ SlugInvalid ]
            , test "the dates must be YYYY-MM-DD" <|
                \_ ->
                    Admin.validateCompetitionForm { validForm | startDate = "1.1.2026" }
                        |> Expect.equal [ DateInvalid ]
            , test "the end date must be after the start date" <|
                \_ ->
                    Admin.validateCompetitionForm { validForm | endDate = "2025-12-31" }
                        |> Expect.equal [ EndBeforeStart ]
            , test "image limits must be between 0 and 10 with min not above max" <|
                \_ ->
                    Admin.validateCompetitionForm { validForm | minImagesPerEntry = "3", maxImagesPerEntry = "2" }
                        |> Expect.equal [ ImageLimitsInvalid ]
            ]
        , describe "updateField"
            [ test "sets the named field and leaves the others" <|
                \_ ->
                    Admin.updateField FieldSlug "kevat-2027" validForm
                        |> (\form -> ( form.slug, form.title ))
                        |> Expect.equal ( "kevat-2027", "Kaupunki" )
            ]
        , describe "formFromCompetition"
            [ test "fills the form with the competition's dates as YYYY-MM-DD" <|
                \_ ->
                    Admin.formFromCompetition
                        { id = "c1"
                        , title = "Kaupunki"
                        , slug = "kaupunki-2026"
                        , theme = Nothing
                        , description = Nothing
                        , startDate = "2026-01-01 00:00:00.000Z"
                        , endDate = "2026-06-01 00:00:00.000Z"
                        , judgingEndDate = Just "2026-07-01 00:00:00.000Z"
                        , status = COpen
                        , coverImage = Nothing
                        , maxEntriesPerUser = Just 3
                        , minImagesPerEntry = Nothing
                        , maxImagesPerEntry = Nothing
                        }
                        |> (\form -> ( ( form.startDate, form.endDate ), ( form.judgingEndDate, form.status ) ))
                        |> Expect.equal ( ( "2026-01-01", "2026-06-01" ), ( "2026-07-01", COpen ) )
            ]
        , describe "encodeCompetition when editing"
            [ test "keeps the stored time of a date whose day did not change" <|
                \_ ->
                    Admin.encodeCompetition (Just sampleCompetition) { validForm | endDate = "2026-12-31" }
                        |> Encode.encode 0
                        |> String.contains "\"end_date\":\"2026-12-31 23:59:59.000Z\""
                        |> Expect.equal True
            , test "sends a changed day at midnight" <|
                \_ ->
                    Admin.encodeCompetition (Just sampleCompetition) { validForm | endDate = "2027-01-02" }
                        |> Encode.encode 0
                        |> String.contains "\"end_date\":\"2027-01-02 00:00:00.000Z\""
                        |> Expect.equal True
            , test "clears an emptied number and judging date" <|
                \_ ->
                    Admin.encodeCompetition (Just sampleCompetition) { validForm | maxEntriesPerUser = "" }
                        |> Encode.encode 0
                        |> (\json -> ( String.contains "\"max_entries_per_user\":null" json, String.contains "\"judging_end_date\":\"\"" json ))
                        |> Expect.equal ( True, True )
            ]
        , describe "encodeCompetition"
            [ test "omits empty optional numbers" <|
                \_ ->
                    Admin.encodeCompetition Nothing validForm
                        |> Encode.encode 0
                        |> String.contains "max_entries_per_user"
                        |> Expect.equal False
            , test "sends a filled-in optional number" <|
                \_ ->
                    Admin.encodeCompetition Nothing { validForm | maxEntriesPerUser = "3" }
                        |> Encode.encode 0
                        |> String.contains "\"max_entries_per_user\":3"
                        |> Expect.equal True
            , test "sends dates as PocketBase timestamps at midnight UTC" <|
                \_ ->
                    Admin.encodeCompetition Nothing validForm
                        |> Encode.encode 0
                        |> String.contains "\"end_date\":\"2026-06-01 00:00:00.000Z\""
                        |> Expect.equal True
            ]
        ]

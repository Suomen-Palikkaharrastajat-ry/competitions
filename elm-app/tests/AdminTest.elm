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
import Types exposing (AdminField(..), AdminFlag(..), Competition, CompetitionForm, CompetitionStatus(..), FormError(..))


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
    , votingEnabled = False
    , votingRequired = False
    , votingStartDate = ""
    , votingEndDate = ""
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
    , votingEnabled = False
    , votingRequired = False
    , votingStartDate = Nothing
    , votingEndDate = Nothing
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

            -- Given voting is enabled, when its period is missing or ends
            -- before it starts, then the form cannot be saved.
            , test "voting needs a start and an end date" <|
                \_ ->
                    Admin.validateCompetitionForm { validForm | votingEnabled = True, votingStartDate = "2026-07-07" }
                        |> Expect.equal [ VotingDatesInvalid ]
            , test "voting must end after it starts" <|
                \_ ->
                    Admin.validateCompetitionForm { validForm | votingEnabled = True, votingStartDate = "2026-07-07", votingEndDate = "2026-07-07" }
                        |> Expect.equal [ VotingDatesInvalid ]
            , test "a voting period with valid dates is accepted" <|
                \_ ->
                    Admin.validateCompetitionForm { validForm | votingEnabled = True, votingStartDate = "2026-07-07", votingEndDate = "2026-07-15" }
                        |> Expect.equal []
            , test "without voting, the voting dates may be left empty" <|
                \_ ->
                    Admin.validateCompetitionForm { validForm | votingRequired = True }
                        |> Expect.equal []
            ]
        , describe "updateField"
            [ test "sets the named field and leaves the others" <|
                \_ ->
                    Admin.updateField FieldSlug "kevat-2027" validForm
                        |> (\form -> ( form.slug, form.title ))
                        |> Expect.equal ( "kevat-2027", "Kaupunki" )
            , test "updateFlag turns voting on and makes it required" <|
                \_ ->
                    validForm
                        |> Admin.updateFlag FlagVotingEnabled True
                        |> Admin.updateFlag FlagVotingRequired True
                        |> (\form -> ( form.votingEnabled, form.votingRequired ))
                        |> Expect.equal ( True, True )
            , test "updateField sets the voting dates" <|
                \_ ->
                    validForm
                        |> Admin.updateField FieldVotingStartDate "2026-07-07"
                        |> Admin.updateField FieldVotingEndDate "2026-07-15"
                        |> (\form -> ( form.votingStartDate, form.votingEndDate ))
                        |> Expect.equal ( "2026-07-07", "2026-07-15" )
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
                        , votingEnabled = True
                        , votingRequired = True
                        , votingStartDate = Just "2026-07-07 00:00:00.000Z"
                        , votingEndDate = Just "2026-07-15 00:00:00.000Z"
                        }
                        |> (\form -> ( ( form.startDate, form.endDate ), ( form.judgingEndDate, form.status ), ( ( form.votingEnabled, form.votingRequired ), ( form.votingStartDate, form.votingEndDate ) ) ))
                        |> Expect.equal ( ( "2026-01-01", "2026-06-01" ), ( "2026-07-01", COpen ), ( ( True, True ), ( "2026-07-07", "2026-07-15" ) ) )
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
            , test "sends the voting settings and period" <|
                \_ ->
                    Admin.encodeCompetition Nothing { validForm | votingEnabled = True, votingRequired = True, votingStartDate = "2026-07-07", votingEndDate = "2026-07-15" }
                        |> Encode.encode 0
                        |> (\json ->
                                List.map (\part -> String.contains part json)
                                    [ "\"voting_enabled\":true"
                                    , "\"voting_required\":true"
                                    , "\"voting_start_date\":\"2026-07-07 00:00:00.000Z\""
                                    , "\"voting_end_date\":\"2026-07-15 00:00:00.000Z\""
                                    ]
                           )
                        |> Expect.equal [ True, True, True, True ]
            , test "a new competition without voting omits the voting period" <|
                \_ ->
                    Admin.encodeCompetition Nothing validForm
                        |> Encode.encode 0
                        |> (\json -> ( String.contains "\"voting_enabled\":false" json, String.contains "voting_start_date" json ))
                        |> Expect.equal ( True, False )
            ]
        ]

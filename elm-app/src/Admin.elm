module Admin exposing
    ( emptyCompetitionForm
    , encodeCompetition
    , formFromCompetition
    , nextStatus
    , previousStatus
    , statusFromString
    , statusToString
    , updateField
    , updateFlag
    , validateCompetitionForm
    )

{-| Helpers of the in-app admin: the competition lifecycle, the checks of the
competition form and the request body sent to PocketBase.

The functions are pure. Messages for the errors are in `I18n`; this module only
names them.

-}

import Json.Encode as Encode
import Types exposing (AdminField(..), AdminFlag(..), Competition, CompetitionForm, CompetitionStatus(..), FormError(..))


{-| A new competition: no values, a draft.
-}
emptyCompetitionForm : CompetitionForm
emptyCompetitionForm =
    { title = ""
    , slug = ""
    , theme = ""
    , description = ""
    , startDate = ""
    , endDate = ""
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


{-| The form with one field replaced.
-}
updateField : AdminField -> String -> CompetitionForm -> CompetitionForm
updateField field value form =
    case field of
        FieldTitle ->
            { form | title = value }

        FieldSlug ->
            { form | slug = value }

        FieldTheme ->
            { form | theme = value }

        FieldDescription ->
            { form | description = value }

        FieldStartDate ->
            { form | startDate = value }

        FieldEndDate ->
            { form | endDate = value }

        FieldJudgingEndDate ->
            { form | judgingEndDate = value }

        FieldMaxEntries ->
            { form | maxEntriesPerUser = value }

        FieldMinImages ->
            { form | minImagesPerEntry = value }

        FieldMaxImages ->
            { form | maxImagesPerEntry = value }

        FieldVotingStartDate ->
            { form | votingStartDate = value }

        FieldVotingEndDate ->
            { form | votingEndDate = value }


{-| The form with one yes/no setting changed.
-}
updateFlag : AdminFlag -> Bool -> CompetitionForm -> CompetitionForm
updateFlag flag value form =
    case flag of
        FlagVotingEnabled ->
            { form | votingEnabled = value }

        FlagVotingRequired ->
            { form | votingRequired = value }


{-| The status a competition moves to next, if any.
-}
nextStatus : CompetitionStatus -> Maybe CompetitionStatus
nextStatus status =
    case status of
        CDraft ->
            Just COpen

        COpen ->
            Just CClosed

        CClosed ->
            Just CJudging

        CJudging ->
            Just CFinished

        CFinished ->
            Nothing


{-| The status a competition moves back to, if any.
-}
previousStatus : CompetitionStatus -> Maybe CompetitionStatus
previousStatus status =
    case status of
        CDraft ->
            Nothing

        COpen ->
            Just CDraft

        CClosed ->
            Just COpen

        CJudging ->
            Just CClosed

        CFinished ->
            Just CJudging


statusToString : CompetitionStatus -> String
statusToString status =
    case status of
        CDraft ->
            "draft"

        COpen ->
            "open"

        CClosed ->
            "closed"

        CJudging ->
            "judging"

        CFinished ->
            "finished"


statusFromString : String -> Maybe CompetitionStatus
statusFromString value =
    case value of
        "draft" ->
            Just CDraft

        "open" ->
            Just COpen

        "closed" ->
            Just CClosed

        "judging" ->
            Just CJudging

        "finished" ->
            Just CFinished

        _ ->
            Nothing


{-| The errors of a competition form. An empty list means it can be saved.
-}
validateCompetitionForm : CompetitionForm -> List FormError
validateCompetitionForm form =
    List.filterMap identity
        [ if String.isEmpty (String.trim form.title) then
            Just TitleRequired

          else
            Nothing
        , if isValidSlug form.slug then
            Nothing

          else
            Just SlugInvalid
        , if isDate form.startDate && isDate form.endDate && (String.isEmpty form.judgingEndDate || isDate form.judgingEndDate) then
            Nothing

          else
            Just DateInvalid
        , if isDate form.startDate && isDate form.endDate && form.endDate <= form.startDate then
            Just EndBeforeStart

          else
            Nothing
        , if isBlankOr isCount0 form.maxEntriesPerUser then
            Nothing

          else
            Just MaxEntriesInvalid
        , if imageLimitsValid form.minImagesPerEntry form.maxImagesPerEntry then
            Nothing

          else
            Just ImageLimitsInvalid
        , if votingPeriodValid form then
            Nothing

          else
            Just VotingDatesInvalid
        ]


{-| Voting needs its whole period, ending after it starts. Without voting the
dates may be empty, but a date typed in must still be a date.
-}
votingPeriodValid : CompetitionForm -> Bool
votingPeriodValid form =
    if form.votingEnabled then
        isDate form.votingStartDate && isDate form.votingEndDate && form.votingStartDate < form.votingEndDate

    else
        (String.isEmpty form.votingStartDate || isDate form.votingStartDate)
            && (String.isEmpty form.votingEndDate || isDate form.votingEndDate)


{-| The competition as PocketBase stores it. A new competition leaves out
empty optional fields, so PocketBase keeps its defaults. An edit sends them as
cleared (null, or an empty date), and keeps the stored time of a date whose day
was not changed.
-}
encodeCompetition : Maybe Competition -> CompetitionForm -> Encode.Value
encodeCompetition original form =
    Encode.object
        (List.filterMap identity
            [ Just ( "title", Encode.string (String.trim form.title) )
            , Just ( "slug", Encode.string form.slug )
            , Just ( "theme", Encode.string (String.trim form.theme) )
            , Just ( "description", Encode.string (String.trim form.description) )
            , Just ( "start_date", Encode.string (timestamp (Maybe.map .startDate original) form.startDate) )
            , Just ( "end_date", Encode.string (timestamp (Maybe.map .endDate original) form.endDate) )
            , optionalDateField "judging_end_date" (Maybe.andThen .judgingEndDate original) original form.judgingEndDate
            , Just ( "voting_enabled", Encode.bool form.votingEnabled )
            , Just ( "voting_required", Encode.bool form.votingRequired )
            , optionalDateField "voting_start_date" (Maybe.andThen .votingStartDate original) original form.votingStartDate
            , optionalDateField "voting_end_date" (Maybe.andThen .votingEndDate original) original form.votingEndDate
            , Just ( "status", Encode.string (statusToString form.status) )
            , numberField "max_entries_per_user" original form.maxEntriesPerUser
            , numberField "min_images_per_entry" original form.minImagesPerEntry
            , numberField "max_images_per_entry" original form.maxImagesPerEntry
            ]
        )


{-| An optional date: left out of a new competition when empty, cleared on an
edit, and otherwise sent like the required dates.
-}
optionalDateField : String -> Maybe String -> Maybe Competition -> String -> Maybe ( String, Encode.Value )
optionalDateField name stored original value =
    case ( original, String.isEmpty value ) of
        ( Nothing, True ) ->
            Nothing

        ( Nothing, False ) ->
            Just ( name, Encode.string (timestamp Nothing value) )

        ( Just _, True ) ->
            Just ( name, Encode.string "" )

        ( Just _, False ) ->
            Just ( name, Encode.string (timestamp stored value) )


numberField : String -> Maybe Competition -> String -> Maybe ( String, Encode.Value )
numberField name original value =
    case ( intField name value, original ) of
        ( Just field, _ ) ->
            Just field

        ( Nothing, Just _ ) ->
            Just ( name, Encode.null )

        ( Nothing, Nothing ) ->
            Nothing


{-| The form that edits an existing competition.
-}
formFromCompetition : Competition -> CompetitionForm
formFromCompetition competition =
    { title = competition.title
    , slug = competition.slug
    , theme = Maybe.withDefault "" competition.theme
    , description = Maybe.withDefault "" competition.description
    , startDate = String.left 10 competition.startDate
    , endDate = String.left 10 competition.endDate
    , judgingEndDate = Maybe.withDefault "" (Maybe.map (String.left 10) competition.judgingEndDate)
    , maxEntriesPerUser = maybeIntText competition.maxEntriesPerUser
    , minImagesPerEntry = maybeIntText competition.minImagesPerEntry
    , maxImagesPerEntry = maybeIntText competition.maxImagesPerEntry
    , votingEnabled = competition.votingEnabled
    , votingRequired = competition.votingRequired
    , votingStartDate = Maybe.withDefault "" (Maybe.map (String.left 10) competition.votingStartDate)
    , votingEndDate = Maybe.withDefault "" (Maybe.map (String.left 10) competition.votingEndDate)
    , status = competition.status
    }



-- HELPERS


intField : String -> String -> Maybe ( String, Encode.Value )
intField name value =
    if String.isEmpty (String.trim value) then
        Nothing

    else
        String.toInt (String.trim value)
            |> Maybe.map (\number -> ( name, Encode.int number ))


maybeIntText : Maybe Int -> String
maybeIntText value =
    Maybe.withDefault "" (Maybe.map String.fromInt value)


toTimestamp : String -> String
toTimestamp date =
    date ++ " 00:00:00.000Z"


{-| The stored timestamp when its day is still the day in the form, otherwise
the day at midnight UTC.
-}
timestamp : Maybe String -> String -> String
timestamp stored day =
    case stored of
        Just value ->
            if String.left 10 value == day then
                value

            else
                toTimestamp day

        Nothing ->
            toTimestamp day


isDate : String -> Bool
isDate value =
    case String.split "-" value of
        [ year, month, day ] ->
            String.length year
                == 4
                && String.length month
                == 2
                && String.length day
                == 2
                && isBetween 1 12 month
                && isBetween 1 31 day
                && isCount year

        _ ->
            False


isBetween : Int -> Int -> String -> Bool
isBetween low high value =
    case String.toInt value of
        Just number ->
            number >= low && number <= high

        Nothing ->
            False


isCount : String -> Bool
isCount value =
    String.all Char.isDigit value && not (String.isEmpty value)


isValidSlug : String -> Bool
isValidSlug value =
    not (String.isEmpty value)
        && String.all (\c -> Char.isLower c || Char.isDigit c || c == '-') value


isCount0 : String -> Bool
isCount0 value =
    isBetween 0 1000000 value


isBlankOr : (String -> Bool) -> String -> Bool
isBlankOr check value =
    String.isEmpty (String.trim value) || check (String.trim value)


imageLimitsValid : String -> String -> Bool
imageLimitsValid minText maxText =
    let
        minOk =
            isBlankOr (isBetween 0 10) minText

        maxOk =
            isBlankOr (isBetween 0 10) maxText

        ordered =
            case ( String.toInt (String.trim minText), String.toInt (String.trim maxText) ) of
                ( Just low, Just high ) ->
                    low <= high

                _ ->
                    True
    in
    minOk && maxOk && ordered

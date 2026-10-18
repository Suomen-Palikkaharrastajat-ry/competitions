module Scoring exposing (canEditEntry, canSubmitMore, deadlineUrgency, entryAverage, findEntry, formatDate, isDeadlinePassed, parseDateToMillis, reviewTotal, scoreMax)

{-| Canonical score aggregation formula used by both Elm and Haskell gallery.

    review_total = sum of the review's scores, one per criterion (each 1–5)
    score_max    = 5 × number of criteria (20 for the four current criteria)

    entry_average = sum(review_totals) / count  (0.0 when no published reviews)

Also contains deadline date helpers and the edit rule used by View and Main.

-}

import Criteria exposing (Criterion)
import Dict exposing (Dict)
import Time
import Types exposing (Entry, EntryStatus(..))


{-| Sum of the scores of a single review, one per criterion.
-}
reviewTotal : { a | scores : Dict String Int } -> Int
reviewTotal r =
    Dict.foldl (\_ score total -> total + score) 0 r.scores


{-| Average total score across a list of per-review totals. Returns 0.0 when empty.
-}
entryAverage : List Int -> Float
entryAverage totals =
    case totals of
        [] ->
            0.0

        _ ->
            toFloat (List.sum totals) / toFloat (List.length totals)


{-| Maximum possible score for a single review: the top of the 1–5 scale for
each of the criteria.
-}
scoreMax : List Criterion -> Int
scoreMax criteria =
    5 * List.length criteria


{-| Return Just "text-brand-red" when the competition ends within 7 days, Nothing otherwise.
-}
deadlineUrgency : String -> Time.Posix -> Maybe String
deadlineUrgency endDate now =
    parseDateToMillis endDate
        |> Maybe.andThen
            (\deadlineMs ->
                let
                    nowMs =
                        Time.posixToMillis now

                    sevenDaysMs =
                        7 * 24 * 60 * 60 * 1000
                in
                if deadlineMs > nowMs && deadlineMs - nowMs <= sevenDaysMs then
                    Just "text-brand-red"

                else
                    Nothing
            )


{-| True if endDate has already passed relative to now.
-}
isDeadlinePassed : String -> Time.Posix -> Bool
isDeadlinePassed endDate now =
    case parseDateToMillis endDate of
        Just deadlineMs ->
            Time.posixToMillis now >= deadlineMs

        Nothing ->
            False


{-| A PocketBase timestamp ("YYYY-MM-DD HH:MM:SS.mmmZ") in milliseconds since
the epoch, UTC.
-}
parseDateToMillis : String -> Maybe Int
parseDateToMillis s =
    case List.filterMap String.toInt (String.split "-" (String.left 10 s)) of
        [ y, m, d ] ->
            Just (calendarToMillis y m d + timeOfDayMillis s)

        _ ->
            Nothing


{-| The time of day in "YYYY-MM-DD HH:MM:SS.mmmZ", in milliseconds from midnight.
A date without a time counts from midnight.
-}
timeOfDayMillis : String -> Int
timeOfDayMillis s =
    case List.filterMap String.toInt (String.split ":" (String.slice 11 19 s)) of
        [ h, mi, sec ] ->
            ((h * 60 + mi) * 60 + sec) * 1000

        _ ->
            0


calendarToMillis : Int -> Int -> Int -> Int
calendarToMillis year month day =
    let
        isLeap y =
            (modBy 4 y == 0 && modBy 100 y /= 0) || modBy 400 y == 0

        daysPerYear y =
            if isLeap y then
                366

            else
                365

        yearDays =
            List.range 1970 (year - 1)
                |> List.map daysPerYear
                |> List.sum

        daysPerMonth y m =
            case m of
                1 ->
                    31

                2 ->
                    if isLeap y then
                        29

                    else
                        28

                3 ->
                    31

                4 ->
                    30

                5 ->
                    31

                6 ->
                    30

                7 ->
                    31

                8 ->
                    31

                9 ->
                    30

                10 ->
                    31

                11 ->
                    30

                _ ->
                    31

        monthDays =
            List.range 1 (month - 1)
                |> List.map (daysPerMonth year)
                |> List.sum
    in
    (yearDays + monthDays + day - 1) * 86400000


{-| Whether the user may still enter `competition`, given their own entries
(any status): `max_entries_per_user` 0 means no limit, and none means 3.
-}
canSubmitMore : { c | id : String, maxEntriesPerUser : Maybe Int } -> List { e | competitionId : String } -> Bool
canSubmitMore competition entries =
    let
        myCount =
            List.length (List.filter (\e -> e.competitionId == competition.id) entries)

        limit =
            Maybe.withDefault 3 competition.maxEntriesPerUser
    in
    limit == 0 || myCount < limit


{-| A draft can always be edited. A submitted entry can be edited until the
competition's end date; approved and rejected entries cannot be edited.
-}
canEditEntry : Time.Posix -> Entry -> Bool
canEditEntry now entry =
    case entry.status of
        Draft ->
            True

        Submitted ->
            case entry.competition of
                Just competition ->
                    not (isDeadlinePassed competition.endDate now)

                Nothing ->
                    False

        Approved ->
            False

        Rejected ->
            False


{-| The entry with this id, if it is among the loaded entries.
-}
findEntry : Maybe String -> List Entry -> Maybe Entry
findEntry entryId entries =
    entryId
        |> Maybe.andThen (\id -> List.filter (\entry -> entry.id == id) entries |> List.head)


{-| A date as day.month.year, for example "2026-06-01 00:00:00.000Z" as "1.6.2026".
Anything that is not a date is returned as it is.
-}
formatDate : String -> String
formatDate s =
    case String.split "-" (String.left 10 s) of
        [ y, m, d ] ->
            String.join "." [ String.fromInt (Maybe.withDefault 0 (String.toInt d)), String.fromInt (Maybe.withDefault 0 (String.toInt m)), y ]

        _ ->
            s

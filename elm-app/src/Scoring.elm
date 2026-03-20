module Scoring exposing (deadlineUrgency, entryAverage, isDeadlinePassed, reviewTotal, scoreMax)

{-| Canonical score aggregation formula used by both Elm and Haskell gallery.

    review_total = score_theme + score_originality + score_technique + score_presentation
    range: 4–20 per review (each criterion 1–5)

    entry_average = sum(review_totals) / count  (0.0 when no published reviews)

Also contains deadline date helpers used by View and Main.
-}

import Time


{-| Sum of the four criteria for a single review. Range 4–20.
-}
reviewTotal :
    { a
        | scoreTheme : Int
        , scoreOriginality : Int
        , scoreTechnique : Int
        , scorePresentation : Int
    }
    -> Int
reviewTotal r =
    r.scoreTheme + r.scoreOriginality + r.scoreTechnique + r.scorePresentation


{-| Average total score across a list of per-review totals. Returns 0.0 when empty.
-}
entryAverage : List Int -> Float
entryAverage totals =
    case totals of
        [] ->
            0.0

        _ ->
            toFloat (List.sum totals) / toFloat (List.length totals)


{-| Maximum possible score for a single review.
-}
scoreMax : Int
scoreMax =
    20


{-| Return Just "text-red-600" when the competition ends within 7 days, Nothing otherwise.
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
                    Just "text-red-600"

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


parseDateToMillis : String -> Maybe Int
parseDateToMillis s =
    let
        datePart =
            String.left 10 s
    in
    case List.filterMap String.toInt (String.split "-" datePart) of
        [ y, m, d ] ->
            Just (calendarToMillis y m d)

        _ ->
            Nothing


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

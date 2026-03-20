module Scoring exposing (entryAverage, reviewTotal, scoreMax)

{-| Canonical score aggregation formula used by both Elm and Haskell gallery.

    review_total = score_theme + score_originality + score_technique + score_presentation
    range: 4–20 per review (each criterion 1–5)

    entry_average = sum(review_totals) / count  (0.0 when no published reviews)
-}


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

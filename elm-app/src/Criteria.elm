module Criteria exposing (Criterion, decoder)

{-| The review criteria: the Likert items a reviewer scores each entry on.

They are configured in config.toml under `[app]`: `criteria` lists the ids in
the order they are shown, and each id's label is in `[app.strings]` as
`criterion_<id>` (and in the other declared languages). Read them with
`SiteSettings.appDecoder lang decoder`.

-}

import Dict
import Json.Decode as Decode exposing (Decoder)


{-| One review criterion: a stable id (the key of the score in a review) and
the label shown to reviewers, in the language being read.
-}
type alias Criterion =
    { id : String
    , label : String
    }


{-| The criteria of the app's settings. Fails when no criterion is configured,
or when one of them has no label in the language.
-}
decoder : Decoder (List Criterion)
decoder =
    Decode.map2 Tuple.pair
        (Decode.field "criteria" (Decode.list Decode.string))
        (Decode.field "strings" (Decode.dict Decode.string))
        |> Decode.andThen
            (\( ids, labels ) ->
                let
                    missing =
                        List.filter (\id -> not (Dict.member (labelKey id) labels)) ids
                in
                if List.isEmpty ids then
                    Decode.fail "No review criteria are configured in [app] criteria."

                else if not (List.isEmpty missing) then
                    Decode.fail ("No label in [app.strings] for the criteria: " ++ String.join ", " missing)

                else
                    Decode.succeed (List.filterMap (\id -> Dict.get (labelKey id) labels |> Maybe.map (Criterion id)) ids)
            )


labelKey : String -> String
labelKey id =
    "criterion_" ++ id

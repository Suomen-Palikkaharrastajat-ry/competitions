module CriteriaTest exposing (suite)

{-| The review criteria are read from the `[app]` settings of config.toml, in
the language shown: each criterion has an id and a label per language.

Given config.toml lists criteria and labels in every declared language
When the app reads them for a language
Then the criteria come in the configured order, with that language's labels
And a criterion without a label is a configuration error, not a blank label

-}

import Criteria exposing (Criterion)
import Expect
import Json.Decode as Decode
import Lang exposing (Lang(..))
import SiteFixture
import SiteSettings
import Test exposing (Test, describe, test)


readCriteria : Lang -> Result Decode.Error (List Criterion)
readCriteria lang =
    Decode.decodeString (SiteSettings.appDecoder lang Criteria.decoder) SiteFixture.json


suite : Test
suite =
    describe "Review criteria from config.toml"
        [ test "the Finnish labels of the current criteria, in order" <|
            \_ ->
                readCriteria Fi
                    |> Expect.equal
                        (Ok
                            [ { id = "theme", label = "Teema-vastaavuus" }
                            , { id = "originality", label = "Omaperäisyys" }
                            , { id = "technique", label = "Rakennustekniikka" }
                            , { id = "presentation", label = "Esitys (kuvat)" }
                            ]
                        )
        , test "the English labels come from the English table" <|
            \_ ->
                readCriteria En
                    |> Result.map (List.map .label)
                    |> Expect.equal (Ok [ "Fit to the theme", "Originality", "Building technique", "Presentation (images)" ])
        , test "a criterion without a label in the config is an error" <|
            \_ ->
                Decode.decodeString Criteria.decoder """{"criteria": ["theme", "style"], "strings": {"criterion_theme": "Theme"}}"""
                    |> Result.mapError (always ())
                    |> Expect.err
        , test "no criteria at all is an error" <|
            \_ ->
                Decode.decodeString Criteria.decoder """{"criteria": [], "strings": {}}"""
                    |> Result.mapError (always ())
                    |> Expect.err
        ]

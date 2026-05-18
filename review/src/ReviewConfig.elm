module ReviewConfig exposing (config)

{-| elm-review configuration for the competition Elm app.

The rules focus on readability contracts that complement `elm-format` and
`elm-test`: module purpose, explicit public APIs, top-level type annotations,
no committed debug code, and no inline style attributes that bypass brand tokens.

-}

import LlmAgent.NoDebug
import LlmAgent.NoExposingEverything
import LlmAgent.NoInlineStyleAttribute
import LlmAgent.RequireModuleDoc
import LlmAgent.RequireTypeAnnotation
import Review.Rule as Rule exposing (Rule)


generatedDirectories : List String
generatedDirectories =
    [ ".elm-tailwind/" ]


testDirectories : List String
testDirectories =
    [ "tests/" ]


packageDirectories : List String
packageDirectories =
    [ "packages/" ]


config : List Rule
config =
    [ LlmAgent.NoDebug.rule
    , LlmAgent.NoExposingEverything.rule
    , LlmAgent.NoInlineStyleAttribute.rule
        |> Rule.ignoreErrorsForDirectories packageDirectories
    , LlmAgent.RequireModuleDoc.rule
        |> Rule.ignoreErrorsForDirectories testDirectories
    , LlmAgent.RequireTypeAnnotation.rule
        |> Rule.ignoreErrorsForDirectories testDirectories
    ]
        |> List.map (Rule.ignoreErrorsForDirectories generatedDirectories)

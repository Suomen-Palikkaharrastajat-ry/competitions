module ReviewConfig exposing (config)

{-| elm-review configuration for the competition Elm app.

Uses the shared LlmAgent rules maintained in master-builder
(`review/src/LlmAgent` is a symlink to `vendor/master-builder/review/src/LlmAgent`):
typed Tailwind tokens instead of `Tw.raw`, module purpose, explicit public
APIs, top-level type annotations, no committed debug code, and no inline style
attributes that bypass brand tokens.

-}

import LlmAgent.NoDebug
import LlmAgent.NoExposingEverything
import LlmAgent.NoInlineStyleAttribute
import LlmAgent.NoTailwindRawStrings
import LlmAgent.RequireModuleDoc
import LlmAgent.RequireTypeAnnotation
import Review.Rule as Rule exposing (Rule)


generatedDirectories : List String
generatedDirectories =
    [ ".elm-tailwind/", "packages/" ]


testDirectories : List String
testDirectories =
    [ "tests/" ]


config : List Rule
config =
    [ LlmAgent.NoTailwindRawStrings.rule
    , LlmAgent.NoDebug.rule
    , LlmAgent.NoExposingEverything.rule
    , LlmAgent.NoInlineStyleAttribute.rule
    , LlmAgent.RequireModuleDoc.rule
        |> Rule.ignoreErrorsForDirectories testDirectories
    , LlmAgent.RequireTypeAnnotation.rule
        |> Rule.ignoreErrorsForDirectories testDirectories
    ]
        |> List.map (Rule.ignoreErrorsForDirectories generatedDirectories)

module LlmAgent.NoExposingEverything exposing (rule)

{-| Forbids `module Foo exposing (..)` wildcard exports.

Explicit export lists make each module's public API visible at the top of the
file, which keeps review and agent-assisted changes safer.

-}

import Elm.Syntax.Exposing as Exposing
import Elm.Syntax.Module as Module exposing (Module)
import Elm.Syntax.Node as Node exposing (Node)
import Review.Rule as Rule exposing (Rule)


rule : Rule
rule =
    Rule.newModuleRuleSchema "LlmAgent.NoExposingEverything" ()
        |> Rule.withModuleDefinitionVisitor moduleDefinitionVisitor
        |> Rule.fromModuleRuleSchema


moduleDefinitionVisitor : Node Module -> () -> ( List (Rule.Error {}), () )
moduleDefinitionVisitor node () =
    let
        exposingList =
            case Node.value node of
                Module.NormalModule data ->
                    Node.value data.exposingList

                Module.PortModule data ->
                    Node.value data.exposingList

                Module.EffectModule data ->
                    Node.value data.exposingList
    in
    case exposingList of
        Exposing.All range ->
            ( [ Rule.error
                    { message = "Avoid `exposing (..)`; list exports explicitly"
                    , details =
                        [ "Wildcard exports hide the module boundary."
                        , "Replace `exposing (..)` with a concrete export list."
                        ]
                    }
                    range
              ]
            , ()
            )

        Exposing.Explicit _ ->
            ( [], () )

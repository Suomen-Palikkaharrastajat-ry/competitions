module LlmAgent.RequireModuleDoc exposing (rule)

{-| Requires every production Elm module to have module documentation.

A short module comment gives reviewers and agents a fast orientation point
before they dive into implementation details.

-}

import Elm.Syntax.Module as Module exposing (Module)
import Elm.Syntax.Node as Node exposing (Node)
import Elm.Syntax.Range exposing (Range)
import Review.Rule as Rule exposing (Rule)


type alias Context =
    { moduleDefinitionRange : Range
    }


rule : Rule
rule =
    Rule.newModuleRuleSchema "LlmAgent.RequireModuleDoc"
        { moduleDefinitionRange = { start = { row = 1, column = 1 }, end = { row = 1, column = 1 } }
        }
        |> Rule.withModuleDefinitionVisitor moduleDefinitionVisitor
        |> Rule.withModuleDocumentationVisitor moduleDocumentationVisitor
        |> Rule.fromModuleRuleSchema


moduleDefinitionVisitor : Node Module -> Context -> ( List (Rule.Error {}), Context )
moduleDefinitionVisitor node context =
    ( [], { context | moduleDefinitionRange = Node.range node } )


moduleDocumentationVisitor : Maybe (Node String) -> Context -> ( List (Rule.Error {}), Context )
moduleDocumentationVisitor maybeDoc context =
    case maybeDoc of
        Just _ ->
            ( [], context )

        Nothing ->
            ( [ Rule.error
                    { message = "Module is missing a documentation comment"
                    , details =
                        [ "Add a short {-| ... -} comment directly below the module declaration."
                        , "The comment should describe the module's purpose and any important usage constraints."
                        ]
                    }
                    context.moduleDefinitionRange
              ]
            , context
            )

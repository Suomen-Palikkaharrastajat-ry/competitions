module LlmAgent.RequireTypeAnnotation exposing (rule)

{-| Requires every top-level production function/value to have a type annotation.

Top-level annotations are the public contract for readers, reviewers, and
agent-assisted edits. They also make refactors fail earlier and more clearly.

-}

import Elm.Syntax.Declaration as Declaration exposing (Declaration)
import Elm.Syntax.Node as Node exposing (Node)
import Review.Rule as Rule exposing (Rule)


rule : Rule
rule =
    Rule.newModuleRuleSchema "LlmAgent.RequireTypeAnnotation" ()
        |> Rule.withDeclarationEnterVisitor declarationVisitor
        |> Rule.fromModuleRuleSchema


declarationVisitor : Node Declaration -> () -> ( List (Rule.Error {}), () )
declarationVisitor node () =
    case Node.value node of
        Declaration.FunctionDeclaration function ->
            case function.signature of
                Just _ ->
                    ( [], () )

                Nothing ->
                    let
                        functionName =
                            function.declaration
                                |> Node.value
                                |> .name
                                |> Node.value
                    in
                    ( [ Rule.error
                            { message = "Top-level declaration `" ++ functionName ++ "` is missing a type annotation"
                            , details =
                                [ "Add an explicit type annotation above the declaration."
                                , "Top-level annotations make the module contract readable without tracing implementation details."
                                ]
                            }
                            (Node.range node)
                      ]
                    , ()
                    )

        _ ->
            ( [], () )

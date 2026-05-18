module LlmAgent.NoDebug exposing (rule)

{-| Forbids committed uses of Elm's `Debug` helpers.

`Debug.log`, `Debug.todo`, and `Debug.toString` are useful locally, but they
should not reach the shared codebase or CI quality gate.

-}

import Elm.Syntax.Expression as Expression exposing (Expression)
import Elm.Syntax.Node as Node exposing (Node)
import Review.Rule as Rule exposing (Rule)


rule : Rule
rule =
    Rule.newModuleRuleSchema "LlmAgent.NoDebug" ()
        |> Rule.withExpressionEnterVisitor expressionVisitor
        |> Rule.fromModuleRuleSchema


expressionVisitor : Node Expression -> () -> ( List (Rule.Error {}), () )
expressionVisitor node () =
    case Node.value node of
        Expression.Application (functionNode :: _) ->
            case Node.value functionNode of
                Expression.FunctionOrValue [ "Debug" ] functionName ->
                    if List.member functionName [ "log", "todo", "toString" ] then
                        ( [ Rule.error
                                { message = "Remove Debug." ++ functionName
                                , details =
                                    [ "Debug helpers are for local diagnosis only."
                                    , "Use an explicit test expectation, user-facing error, or temporary local log outside committed code."
                                    ]
                                }
                                (Node.range node)
                          ]
                        , ()
                        )

                    else
                        ( [], () )

                _ ->
                    ( [], () )

        _ ->
            ( [], () )

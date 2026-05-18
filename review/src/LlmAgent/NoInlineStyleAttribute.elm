module LlmAgent.NoInlineStyleAttribute exposing (rule)

{-| Forbids direct `Html.Attributes.style` calls.

The app should express UI styling through the Suomen Palikkaharrastajat brand
tokens and Tailwind utility classes instead of ad hoc inline style values.

-}

import Elm.Syntax.Expression as Expression exposing (Expression)
import Elm.Syntax.Node as Node exposing (Node)
import Review.Rule as Rule exposing (Rule)


rule : Rule
rule =
    Rule.newModuleRuleSchema "LlmAgent.NoInlineStyleAttribute" ()
        |> Rule.withExpressionEnterVisitor expressionVisitor
        |> Rule.fromModuleRuleSchema


expressionVisitor : Node Expression -> () -> ( List (Rule.Error {}), () )
expressionVisitor node () =
    case Node.value node of
        Expression.Application (functionNode :: _) ->
            case Node.value functionNode of
                Expression.FunctionOrValue qualifier "style" ->
                    if List.member qualifier [ [ "Html", "Attributes" ], [ "Attr" ] ] then
                        ( [ Rule.error
                                { message = "Avoid inline style attributes"
                                , details =
                                    [ "Inline styles bypass the brand token system and are hard to review consistently."
                                    , "Use existing Tailwind token classes or add a named token/utility before styling UI."
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

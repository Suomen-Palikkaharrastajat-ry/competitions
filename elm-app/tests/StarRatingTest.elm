module StarRatingTest exposing (suite)

{-| Tests for the star rating component.
-}

import Expect
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Html.Attributes
import Test.Html.Selector exposing (attribute, class, tag)
import View exposing (starRating)


suite : Test
suite =
    describe "starRating"
        [ test "renders 5 star buttons" <|
            \_ ->
                starRating 3 identity
                    |> Query.fromHtml
                    |> Query.findAll [ tag "button" ]
                    |> Query.count (Expect.equal 5)
        , test "score 0: all stars have text-gray-300" <|
            \_ ->
                starRating 0 identity
                    |> Query.fromHtml
                    |> Query.findAll [ class "text-gray-300" ]
                    |> Query.count (Expect.equal 5)
        , test "score 5: all stars have text-brand-yellow" <|
            \_ ->
                starRating 5 identity
                    |> Query.fromHtml
                    |> Query.findAll [ class "text-brand-yellow" ]
                    |> Query.count (Expect.equal 5)
        , test "first button has aria-label=Arvo 1 viidestä" <|
            \_ ->
                starRating 3 identity
                    |> Query.fromHtml
                    |> Query.findAll [ tag "button" ]
                    |> Query.first
                    |> Query.has [ attribute (Html.Attributes.attribute "aria-label" "Arvo 1 viidestä") ]
        , test "fifth button has aria-label=Arvo 5 viidestä" <|
            \_ ->
                starRating 3 identity
                    |> Query.fromHtml
                    |> Query.findAll [ tag "button" ]
                    |> Query.index 4
                    |> Query.has [ attribute (Html.Attributes.attribute "aria-label" "Arvo 5 viidestä") ]
        , test "score 3: 3 yellow stars and 2 gray stars" <|
            \_ ->
                starRating 3 identity
                    |> Query.fromHtml
                    |> (\html ->
                            Expect.all
                                [ \_ ->
                                    html
                                        |> Query.findAll [ class "text-brand-yellow" ]
                                        |> Query.count (Expect.equal 3)
                                , \_ ->
                                    html
                                        |> Query.findAll [ class "text-gray-300" ]
                                        |> Query.count (Expect.equal 2)
                                ]
                                ()
                       )
        ]

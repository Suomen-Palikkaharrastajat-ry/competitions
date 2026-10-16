module RouteTest exposing (suite)

{-| Tests for the location hashes of pages.

Given a page or a hash
When it is converted
Then the page and the hash agree, and unknown hashes are ignored

-}

import Expect
import Route
import Test exposing (Test, describe, test)
import Types exposing (Page(..))


suite : Test
suite =
    describe "Route"
        [ test "dashboard has the root hash" <|
            \_ -> Expect.equal "#/" (Route.toHash DashboardPage)
        , test "linkable pages round-trip" <|
            \_ ->
                [ DashboardPage, MyEntriesPage, ReviewQueuePage ]
                    |> List.map (\page -> Route.fromHash (Route.toHash page))
                    |> Expect.equal [ Just DashboardPage, Just MyEntriesPage, Just ReviewQueuePage ]
        , test "an empty hash is the dashboard" <|
            \_ -> Expect.equal (Just DashboardPage) (Route.fromHash "")
        , test "an unknown hash is ignored" <|
            \_ -> Expect.equal Nothing (Route.fromHash "#/ei-ole")
        , test "the submit form is not linkable" <|
            \_ -> Expect.equal Nothing (Route.fromHash (Route.toHash (SubmitEntryPage Nothing)))
        ]

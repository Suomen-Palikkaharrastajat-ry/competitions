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
        , test "a participation has its own hash under the entries list" <|
            \_ -> Expect.equal "#/omat/entry1" (Route.toHash (ParticipationPage "entry1"))
        , test "a participation round-trips" <|
            \_ ->
                Route.fromHash (Route.toHash (ParticipationPage "entry1"))
                    |> Expect.equal (Just (ParticipationPage "entry1"))
        , test "the edit page is the participation's hash with /muokkaa" <|
            \_ -> Expect.equal "#/omat/entry1/muokkaa" (Route.toHash (SubmitEntryPage (Just "entry1")))
        , test "reloading the edit page opens the participation, which can be edited again" <|
            \_ ->
                Route.fromHash "#/omat/entry1/muokkaa"
                    |> Expect.equal (Just (ParticipationPage "entry1"))
        , test "a participation hash without an entry id is ignored" <|
            \_ -> Expect.equal Nothing (Route.fromHash "#/omat/")
        , test "the admin pages have hashes of their own" <|
            \_ ->
                [ AdminPage
                , AdminCompetitionPage Nothing
                , AdminCompetitionPage (Just "c1")
                , AdminEntriesPage "c1"
                ]
                    |> List.map Route.toHash
                    |> Expect.equal [ "#/admin", "#/admin/kilpailut/uusi", "#/admin/kilpailut/c1", "#/admin/osallistumiset/c1" ]
        , test "the admin pages round-trip" <|
            \_ ->
                [ AdminPage
                , AdminCompetitionPage Nothing
                , AdminCompetitionPage (Just "c1")
                , AdminEntriesPage "c1"
                ]
                    |> List.map (\page -> Route.fromHash (Route.toHash page))
                    |> Expect.equal [ Just AdminPage, Just (AdminCompetitionPage Nothing), Just (AdminCompetitionPage (Just "c1")), Just (AdminEntriesPage "c1") ]
        , test "every admin page belongs to the admin area" <|
            \_ ->
                ( Route.isAdminPage AdminPage, Route.isAdminPage (AdminEntriesPage "c1"), Route.isAdminPage DashboardPage )
                    |> Expect.equal ( True, True, False )
        , test "an admin competition hash without an id is ignored" <|
            \_ -> Expect.equal Nothing (Route.fromHash "#/admin/kilpailut/")
        ]

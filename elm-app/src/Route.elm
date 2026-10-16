module Route exposing (fromHash, toHash)

{-| Location hashes of the application's pages.

The shared layout renders its navigation as plain links, so each page that can
be linked to has a hash. `Main` keeps the browser's hash and the current page
in step in both directions.

-}

import Types exposing (Page(..))


{-| The hash of a page. Pages without an address of their own share the
dashboard's.
-}
toHash : Page -> String
toHash page =
    case page of
        MyEntriesPage ->
            "#/omat"

        SubmitEntryPage _ ->
            "#/osallistu"

        ReviewQueuePage ->
            "#/arvostelu"

        LoginPage ->
            "#/"

        SetDisplayNamePage ->
            "#/"

        DashboardPage ->
            "#/"

        NotFoundPage ->
            "#/"


{-| The page a hash links to. `#/osallistu` is not linkable: submitting needs
a competition chosen first.
-}
fromHash : String -> Maybe Page
fromHash hash =
    case hash of
        "" ->
            Just DashboardPage

        "#" ->
            Just DashboardPage

        "#/" ->
            Just DashboardPage

        "#/omat" ->
            Just MyEntriesPage

        "#/arvostelu" ->
            Just ReviewQueuePage

        _ ->
            Nothing

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

        ParticipationPage entryId ->
            "#/omat/" ++ entryId

        SubmitEntryPage (Just entryId) ->
            "#/omat/" ++ entryId ++ "/muokkaa"

        SubmitEntryPage Nothing ->
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
a competition chosen first. The edit page's hash opens the participation it
edits, because the form is filled from the participation list, not from the
address.
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
            case String.split "/" hash of
                [ "#", "omat", entryId ] ->
                    participation entryId

                [ "#", "omat", entryId, "muokkaa" ] ->
                    participation entryId

                _ ->
                    Nothing


participation : String -> Maybe Page
participation entryId =
    if String.isEmpty entryId then
        Nothing

    else
        Just (ParticipationPage entryId)

module View.Vote exposing (viewVotePage, viewVotingCompetitions)

{-| Ranked voting (ADR-0007): the competitions whose voting is running, and
the vote page where a voter ranks at most five entries.

Each entry is shown with its first image, on the ballot and in the list of
entries to choose from, so the voter can rank the builds by sight. The ballot
is changed with buttons only (no drag and drop), so it works with a keyboard
and on a phone.

-}

import Html exposing (Html, button, div, h1, h2, img, li, ol, p, span, text, ul)
import Html.Attributes as Attr
import Html.Events as Events
import I18n exposing (t)
import Lang exposing (Lang)
import RemoteData
import Types exposing (Competition, Entry, Model, Msg(..), Page(..))
import Voting


{-| The dashboard's list of competitions open for voting. Nothing is shown
when there are none.
-}
viewVotingCompetitions : Model -> Html Msg
viewVotingCompetitions model =
    case model.voting.openCompetitions of
        RemoteData.Success ((_ :: _) as competitions) ->
            div [ Attr.class "mb-8" ]
                [ h2 [ Attr.class "type-h3 text-brand mb-6" ] [ text (t model.lang I18n.VotingOpenHeading) ]
                , ul [ Attr.class "grid grid-cols-1 sm:grid-cols-2 gap-4" ]
                    (List.map (viewVotingCard model.lang) competitions)
                ]

        RemoteData.Failure _ ->
            p [ Attr.class "text-brand-red mb-8" ] [ text (t model.lang I18n.LoadFailed) ]

        _ ->
            text ""


viewVotingCard : Lang -> Competition -> Html Msg
viewVotingCard lang competition =
    li [ Attr.class "rounded-lg border border-border-default bg-white p-4" ]
        [ p [ Attr.class "type-h4 text-brand mb-1" ] [ text competition.title ]
        , viewVotingEnds lang competition
        , button
            [ Attr.type_ "button"
            , Attr.class "mt-4 bg-brand-yellow text-brand type-body-small px-4 py-2 rounded hover:opacity-90 motion-safe:transition-opacity outline-none focus-visible:ring-2 focus-visible:ring-brand"
            , Events.onClick (NavigateTo (VotePage competition.id))
            ]
            [ text (t lang I18n.Vote) ]
        ]


viewVotingEnds : Lang -> Competition -> Html msg
viewVotingEnds lang competition =
    case Maybe.andThen Voting.lastDay competition.votingEndDate of
        Just day ->
            p [ Attr.class "type-caption text-text-muted" ]
                [ text (t lang I18n.VotingEndsPrefix ++ day) ]

        Nothing ->
            text ""


{-| The vote page of a competition.
-}
viewVotePage : Model -> Html Msg
viewVotePage model =
    let
        lang =
            model.lang

        voting =
            model.voting
    in
    case ( voting.competition, voting.candidates, voting.ballotLoaded || voting.error /= Nothing ) of
        ( RemoteData.Failure _, _, _ ) ->
            p [ Attr.class "text-brand-red" ] [ text (t lang I18n.LoadFailed) ]

        ( _, RemoteData.Failure _, _ ) ->
            p [ Attr.class "text-brand-red" ] [ text (t lang I18n.LoadFailed) ]

        ( RemoteData.Success competition, RemoteData.Success candidates, True ) ->
            div []
                [ h1 [ Attr.class "type-h1 text-brand mb-2" ] [ text (t lang I18n.VoteHeading ++ ": " ++ competition.title) ]
                , viewVotingEnds lang competition
                , if competition.votingEnabled then
                    viewBallotForm model competition candidates

                  else
                    p [ Attr.class "text-text-muted mt-6" ] [ text (t lang I18n.VoteNotEnabled) ]
                ]

        _ ->
            p [ Attr.class "text-text-muted motion-safe:animate-pulse" ] [ text (t lang I18n.Loading) ]


viewBallotForm : Model -> Competition -> List Entry -> Html Msg
viewBallotForm model competition candidates =
    let
        lang =
            model.lang

        voting =
            model.voting

        ranking =
            voting.ballot.ranking

        chosen =
            List.filterMap (\entryId -> List.filter (\entry -> entry.id == entryId) candidates |> List.head) ranking
    in
    div []
        [ p [ Attr.class "type-body text-brand mt-4 mb-2 max-w-2xl" ] [ text (t lang I18n.VoteInstructions) ]
        , if competition.votingRequired then
            p [ Attr.class "type-body-small text-brand mb-4 max-w-2xl" ] [ text (t lang I18n.VoteRequiredNote) ]

          else
            text ""
        , if List.isEmpty candidates then
            p [ Attr.class "text-text-muted mt-6" ] [ text (t lang I18n.VoteNoCandidates) ]

          else
            div []
                [ h2 [ Attr.class "type-h3 text-brand mt-6 mb-4" ] [ text (t lang I18n.VoteBallotHeading) ]
                , ol [ Attr.class "list-none grid gap-3 max-w-2xl", Attr.id "ballot" ]
                    (List.map (viewSlot model chosen) (List.range 1 Voting.maxRanks))
                , viewSaveRow model
                , h2 [ Attr.class "type-h3 text-brand mt-8 mb-4" ] [ text (t lang I18n.VoteCandidatesHeading) ]
                , ul [ Attr.class "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" ]
                    (List.map (viewCandidate model ranking) candidates)
                ]
        ]


{-| One place on the ballot: the chosen entry with its first image, or an
empty place.
-}
viewSlot : Model -> List Entry -> Int -> Html Msg
viewSlot model chosen place =
    let
        lang =
            model.lang

        placeLabel =
            span [ Attr.class "type-h4 text-brand w-8 shrink-0" ] [ text (String.fromInt place ++ ".") ]

        pointsLabel =
            span [ Attr.class "type-caption text-text-muted shrink-0" ]
                [ text (String.fromInt (Voting.points place) ++ t lang I18n.VotePointsSuffix) ]
    in
    case List.drop (place - 1) chosen |> List.head of
        Just entry ->
            li [ Attr.class "flex items-center gap-3 rounded-lg border border-border-default bg-white p-2" ]
                [ placeLabel
                , viewThumbnail model.pbUrl "h-16 w-20 shrink-0" entry
                , span [ Attr.class "type-body-small text-brand flex-1 min-w-0 truncate" ] [ text entry.title ]
                , pointsLabel
                , slotButton (t lang I18n.VoteMoveUp ++ ": " ++ entry.title) "↑" (place == 1) (MoveEntryUp entry.id)
                , slotButton (t lang I18n.VoteMoveDown ++ ": " ++ entry.title) "↓" (place == List.length chosen) (MoveEntryDown entry.id)
                , slotButton (t lang I18n.VoteRemove ++ ": " ++ entry.title) "×" False (UnpickEntry entry.id)
                ]

        Nothing ->
            li [ Attr.class "flex items-center gap-3 rounded-lg border border-dashed border-border-default p-2" ]
                [ placeLabel
                , span [ Attr.class "h-16 w-20 shrink-0 rounded bg-bg-subtle" ] []
                , span [ Attr.class "type-caption text-text-muted flex-1" ] [ text (t lang I18n.VoteEmptySlot) ]
                , pointsLabel
                ]


slotButton : String -> String -> Bool -> Msg -> Html Msg
slotButton label symbol disabled msg =
    button
        [ Attr.type_ "button"
        , Attr.attribute "aria-label" label
        , Attr.title label
        , Attr.disabled disabled
        , Attr.class "flex h-8 w-8 shrink-0 items-center justify-center rounded border border-border-default text-brand outline-none hover:bg-bg-subtle disabled:opacity-40 focus-visible:ring-2 focus-visible:ring-brand"
        , Events.onClick msg
        ]
        [ span [ Attr.attribute "aria-hidden" "true" ] [ text symbol ] ]


viewSaveRow : Model -> Html Msg
viewSaveRow model =
    let
        lang =
            model.lang

        voting =
            model.voting
    in
    div [ Attr.class "flex flex-wrap items-center gap-4 mt-4" ]
        [ button
            [ Attr.type_ "button"
            , Attr.class "bg-brand-yellow text-brand type-body-small px-6 py-3 rounded hover:opacity-90 motion-safe:transition-opacity outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:opacity-40"
            , Attr.disabled (voting.saving || List.isEmpty voting.ballot.ranking)
            , Events.onClick SaveBallot
            ]
            [ text
                (t lang
                    (if voting.saving then
                        I18n.VoteSaving

                     else
                        I18n.VoteSave
                    )
                )
            ]
        , case voting.error of
            Just message ->
                p [ Attr.attribute "role" "alert", Attr.class "type-body-small text-brand-red" ] [ text message ]

            Nothing ->
                p [ Attr.attribute "role" "status", Attr.class "type-body-small text-text-muted" ]
                    [ text
                        (if voting.saved then
                            t lang I18n.VoteSaved

                         else if List.isEmpty voting.ballot.ranking then
                            ""

                         else
                            t lang I18n.VoteUnsaved
                        )
                    ]
        ]


{-| An entry to choose, with its first image.
-}
viewCandidate : Model -> List String -> Entry -> Html Msg
viewCandidate model ranking entry =
    let
        lang =
            model.lang

        place =
            List.indexedMap Tuple.pair ranking
                |> List.filter (\( _, entryId ) -> entryId == entry.id)
                |> List.head
                |> Maybe.map (Tuple.first >> (+) 1)

        ( label, disabled ) =
            case place of
                Just n ->
                    ( t lang I18n.VotePickedPrefix ++ String.fromInt n, True )

                Nothing ->
                    if Voting.isFull ranking then
                        ( t lang I18n.VoteBallotFull, True )

                    else
                        ( t lang I18n.VotePick, False )
    in
    li [ Attr.class "rounded-lg overflow-hidden border border-border-default bg-white" ]
        [ viewThumbnail model.pbUrl "aspect-video w-full" entry
        , div [ Attr.class "p-4" ]
            [ p [ Attr.class "type-h4 text-brand mb-1" ] [ text entry.title ]
            , case entry.description of
                Just description ->
                    p [ Attr.class "type-caption text-text-muted mb-3 line-clamp-3" ] [ text description ]

                Nothing ->
                    text ""
            , button
                [ Attr.type_ "button"
                , Attr.class
                    ("type-body-small px-4 py-2 rounded outline-none focus-visible:ring-2 focus-visible:ring-brand "
                        ++ (if disabled then
                                "bg-bg-subtle text-text-muted"

                            else
                                "bg-brand-yellow text-brand hover:opacity-90 motion-safe:transition-opacity"
                           )
                    )
                , Attr.disabled disabled
                , Attr.attribute "aria-label" (label ++ ": " ++ entry.title)
                , Events.onClick (PickEntry entry.id)
                ]
                [ text label ]
            ]
        ]


{-| The entry's first image, or an empty tile when it has none.
-}
viewThumbnail : String -> String -> Entry -> Html msg
viewThumbnail pbUrl classes entry =
    case entry.images of
        first :: _ ->
            img
                [ Attr.src (pbUrl ++ "/api/files/entries/" ++ entry.id ++ "/" ++ first ++ "?thumb=400x300")
                , Attr.alt entry.title
                , Attr.class ("object-cover rounded bg-bg-subtle " ++ classes)
                ]
                []

        [] ->
            span [ Attr.class ("block rounded bg-bg-subtle " ++ classes) ] []

module View.Admin exposing (viewAdminCompetition, viewAdminEntries, viewAdminHome)

{-| The admin's home: every competition with its status and dates, and the
actions on it.
-}

import Admin
import Html exposing (Html, a, button, div, h1, h2, img, input, label, li, ol, p, span, text, textarea, ul)
import Html.Attributes as Attr
import Html.Events as Events
import I18n exposing (t)
import Lang exposing (Lang)
import RemoteData
import Scoring
import Types exposing (AdminField(..), AdminFlag(..), Ballot, Competition, CompetitionForm, CompetitionStatus(..), Entry, EntryStatus(..), FormError(..), Model, Msg(..), Page(..), ReviewableEntry)
import Voting


viewAdminHome : Model -> Html Msg
viewAdminHome model =
    div [ Attr.class "max-w-5xl mx-auto px-4" ]
        [ h1 [ Attr.class "type-h1 text-brand mb-6" ] [ text (t model.lang I18n.AdminHeading) ]
        , button
            [ Attr.class "bg-brand-yellow text-brand type-body-small px-4 py-2 rounded hover:opacity-90 motion-safe:transition-opacity focus-visible:ring-2 focus-visible:ring-brand outline-none mb-6"
            , Events.onClick (NavigateTo (AdminCompetitionPage Nothing))
            ]
            [ text (t model.lang I18n.AdminNewCompetition) ]
        , p [ Attr.class "type-caption text-text-muted mb-6" ]
            [ a
                [ Attr.href (model.pbUrl ++ "/_/")
                , Attr.class "text-brand hover:underline focus-visible:ring-2 focus-visible:ring-brand outline-none"
                , Attr.target "_blank"
                , Attr.rel "noopener"
                ]
                [ text (t model.lang I18n.AdminPocketBaseLink) ]
            ]
        , case model.adminCompetitions of
            RemoteData.Success competitions ->
                if List.isEmpty competitions then
                    p [ Attr.class "text-text-muted" ] [ text (t model.lang I18n.AdminNoCompetitions) ]

                else
                    ul [ Attr.class "grid gap-4" ] (List.map (viewCompetitionCard model.lang) competitions)

            RemoteData.Loading ->
                p [ Attr.class "text-text-muted motion-safe:animate-pulse" ] [ text (t model.lang I18n.Loading) ]

            RemoteData.Failure _ ->
                p [ Attr.class "text-brand-red" ] [ text (t model.lang I18n.LoadFailed) ]

            RemoteData.NotAsked ->
                text ""
        ]


viewCompetitionCard : Lang -> Competition -> Html Msg
viewCompetitionCard lang competition =
    li [ Attr.class "rounded-lg bg-white shadow-sm border border-border-default p-6" ]
        [ div [ Attr.class "flex flex-wrap items-center gap-3 mb-2" ]
            [ h2 [ Attr.class "type-h3 text-brand" ] [ text competition.title ]
            , span [ Attr.class "type-caption rounded-full px-2 py-0.5 bg-bg-subtle text-brand" ]
                [ text (statusLabel lang competition.status) ]
            ]
        , p [ Attr.class "type-caption text-text-muted mb-4" ]
            [ text (Scoring.formatDate competition.startDate ++ " – " ++ Scoring.formatDate competition.endDate) ]
        , div [ Attr.class "flex flex-wrap gap-3" ]
            [ button
                [ Attr.class "type-body-small text-brand underline focus-visible:ring-2 focus-visible:ring-brand outline-none"
                , Events.onClick (NavigateTo (AdminCompetitionPage (Just competition.id)))
                ]
                [ text (t lang I18n.Edit) ]
            , button
                [ Attr.class "type-body-small text-brand underline focus-visible:ring-2 focus-visible:ring-brand outline-none"
                , Events.onClick (NavigateTo (AdminEntriesPage competition.id))
                ]
                [ text (t lang I18n.AdminEntries) ]
            ]
        ]


statusLabel : Lang -> CompetitionStatus -> String
statusLabel lang status =
    case status of
        CDraft ->
            t lang I18n.CompetitionStatusDraft

        COpen ->
            t lang I18n.CompetitionStatusOpen

        CClosed ->
            t lang I18n.CompetitionStatusClosed

        CJudging ->
            t lang I18n.CompetitionStatusJudging

        CFinished ->
            t lang I18n.CompetitionStatusFinished


{-| The form of one competition: the new one (Nothing) or an existing one.
-}
viewAdminCompetition : Model -> Maybe String -> Html Msg
viewAdminCompetition model target =
    case model.adminForm of
        Just form ->
            div [ Attr.class "max-w-5xl mx-auto px-4" ]
                [ h1 [ Attr.class "type-h1 text-brand mb-6" ]
                    [ text
                        (t model.lang
                            (case target of
                                Just _ ->
                                    I18n.AdminFormEdit

                                Nothing ->
                                    I18n.AdminFormNew
                            )
                        )
                    ]
                , viewFormErrors model.lang model.adminFormErrors
                , div [ Attr.class "rounded-lg bg-white shadow-sm border border-border-default p-6 grid gap-4 max-w-2xl" ]
                    [ viewTextField model.lang "admin-title" I18n.AdminFieldTitle FieldTitle form.title
                    , viewTextField model.lang "admin-slug" I18n.AdminFieldSlug FieldSlug form.slug
                    , viewTextField model.lang "admin-theme" I18n.AdminFieldTheme FieldTheme form.theme
                    , viewTextArea model.lang "admin-description" I18n.AdminFieldDescription FieldDescription form.description
                    , viewDateField model.lang "admin-start" I18n.AdminFieldStart FieldStartDate form.startDate
                    , viewDateField model.lang "admin-end" I18n.AdminFieldEnd FieldEndDate form.endDate
                    , viewDateField model.lang "admin-judging" I18n.AdminFieldJudging FieldJudgingEndDate form.judgingEndDate
                    , viewNumberField model.lang "admin-max-entries" I18n.AdminFieldMaxEntries FieldMaxEntries form.maxEntriesPerUser
                    , viewNumberField model.lang "admin-min-images" I18n.AdminFieldMinImages FieldMinImages form.minImagesPerEntry
                    , viewNumberField model.lang "admin-max-images" I18n.AdminFieldMaxImages FieldMaxImages form.maxImagesPerEntry
                    , viewCheckbox model.lang "admin-voting-enabled" I18n.AdminFieldVotingEnabled FlagVotingEnabled form.votingEnabled
                    , if form.votingEnabled then
                        div [ Attr.class "grid gap-4 pl-4 border-l-2 border-border-default" ]
                            [ viewCheckbox model.lang "admin-voting-required" I18n.AdminFieldVotingRequired FlagVotingRequired form.votingRequired
                            , viewDateField model.lang "admin-voting-start" I18n.AdminFieldVotingStart FieldVotingStartDate form.votingStartDate
                            , viewDateField model.lang "admin-voting-end" I18n.AdminFieldVotingEnd FieldVotingEndDate form.votingEndDate
                            ]

                      else
                        text ""
                    , case target of
                        Just _ ->
                            viewStatusControl model.lang form.status

                        Nothing ->
                            text ""
                    , button
                        [ Attr.class "justify-self-start bg-brand-yellow text-brand type-body-small px-6 py-3 rounded hover:opacity-90 motion-safe:transition-opacity focus-visible:ring-2 focus-visible:ring-brand outline-none"
                        , Events.onClick SaveCompetition
                        ]
                        [ text (t model.lang I18n.AdminSave) ]
                    ]
                ]

        Nothing ->
            case ( target, model.adminCompetitions ) of
                ( Just _, RemoteData.Failure _ ) ->
                    p [ Attr.class "text-brand-red" ] [ text (t model.lang I18n.LoadFailed) ]

                ( Just _, RemoteData.Success _ ) ->
                    p [ Attr.class "text-text-muted" ] [ text (t model.lang I18n.AdminNotFound) ]

                _ ->
                    p [ Attr.class "text-text-muted motion-safe:animate-pulse" ] [ text (t model.lang I18n.Loading) ]


{-| The status can only move one step at a time: back to the previous status
or on to the next. Each button saves the change at once.
-}
viewStatusControl : Lang -> CompetitionStatus -> Html Msg
viewStatusControl lang status =
    div [ Attr.class "flex flex-wrap items-center gap-3" ]
        (span [ Attr.class "type-body-small text-brand" ]
            [ text (t lang I18n.AdminFieldStatus ++ ": " ++ statusLabel lang status) ]
            :: List.filterMap identity
                [ Maybe.map (viewStatusButton lang) (Admin.previousStatus status)
                , Maybe.map (viewStatusButton lang) (Admin.nextStatus status)
                ]
        )


viewStatusButton : Lang -> CompetitionStatus -> Html Msg
viewStatusButton lang target =
    button
        [ Attr.type_ "button"
        , Attr.class "type-body-small text-brand underline focus-visible:ring-2 focus-visible:ring-brand outline-none"
        , Events.onClick (SetCompetitionStatus target)
        ]
        [ text (t lang I18n.AdminMoveTo ++ statusLabel lang target) ]


viewFormErrors : Lang -> List FormError -> Html msg
viewFormErrors lang errors =
    if List.isEmpty errors then
        text ""

    else
        div [ Attr.attribute "role" "alert", Attr.class "rounded-lg border border-brand-red text-brand-red p-4 mb-4 max-w-2xl" ]
            [ ul [] (List.map (\error -> li [] [ text (t lang (errorKey error)) ]) errors) ]


errorKey : FormError -> I18n.MsgKey
errorKey error =
    case error of
        TitleRequired ->
            I18n.AdminErrTitle

        SlugInvalid ->
            I18n.AdminErrSlug

        DateInvalid ->
            I18n.AdminErrDate

        EndBeforeStart ->
            I18n.AdminErrEndBeforeStart

        MaxEntriesInvalid ->
            I18n.AdminErrMaxEntries

        ImageLimitsInvalid ->
            I18n.AdminErrImageLimits

        VotingDatesInvalid ->
            I18n.AdminErrVotingDates

        ServerRejected ->
            I18n.AdminErrServer


viewTextField : Lang -> String -> I18n.MsgKey -> AdminField -> String -> Html Msg
viewTextField lang fieldId labelKey field value =
    fieldShell lang
        fieldId
        labelKey
        (input
            [ Attr.id fieldId
            , Attr.type_ "text"
            , Attr.value value
            , Attr.class fieldClass
            , Events.onInput (AdminFieldChanged field)
            ]
            []
        )


viewDateField : Lang -> String -> I18n.MsgKey -> AdminField -> String -> Html Msg
viewDateField lang fieldId labelKey field value =
    fieldShell lang
        fieldId
        labelKey
        (input
            [ Attr.id fieldId
            , Attr.type_ "date"
            , Attr.value value
            , Attr.class fieldClass
            , Events.onInput (AdminFieldChanged field)
            ]
            []
        )


viewCheckbox : Lang -> String -> I18n.MsgKey -> AdminFlag -> Bool -> Html Msg
viewCheckbox lang fieldId labelKey flag value =
    label [ Attr.for fieldId, Attr.class "flex items-center gap-3 type-body-small text-brand" ]
        [ input
            [ Attr.id fieldId
            , Attr.type_ "checkbox"
            , Attr.checked value
            , Attr.class "h-5 w-5 accent-brand outline-none focus-visible:ring-2 focus-visible:ring-brand"
            , Events.onCheck (AdminFlagChanged flag)
            ]
            []
        , text (t lang labelKey)
        ]


viewNumberField : Lang -> String -> I18n.MsgKey -> AdminField -> String -> Html Msg
viewNumberField lang fieldId labelKey field value =
    fieldShell lang
        fieldId
        labelKey
        (input
            [ Attr.id fieldId
            , Attr.type_ "number"
            , Attr.attribute "min" "0"
            , Attr.value value
            , Attr.class fieldClass
            , Events.onInput (AdminFieldChanged field)
            ]
            []
        )


viewTextArea : Lang -> String -> I18n.MsgKey -> AdminField -> String -> Html Msg
viewTextArea lang fieldId labelKey field value =
    fieldShell lang
        fieldId
        labelKey
        (textarea
            [ Attr.id fieldId
            , Attr.rows 3
            , Attr.value value
            , Attr.class fieldClass
            , Events.onInput (AdminFieldChanged field)
            ]
            []
        )


fieldShell : Lang -> String -> I18n.MsgKey -> Html Msg -> Html Msg
fieldShell lang fieldId labelKey control =
    div []
        [ label [ Attr.for fieldId, Attr.class "block mb-1 type-body-small text-brand" ]
            [ text (t lang labelKey) ]
        , control
        ]


fieldClass : String
fieldClass =
    "w-full rounded border border-border-default px-3 py-2 text-brand focus-visible:ring-2 focus-visible:ring-brand outline-none"


{-| The entries of one competition, one card each, so they fit a phone.
-}
viewAdminEntries : Model -> String -> Html Msg
viewAdminEntries model competitionId =
    let
        competition =
            case model.adminCompetitions of
                RemoteData.Success competitions ->
                    competitions
                        |> List.filter (\c -> c.id == competitionId)
                        |> List.head

                _ ->
                    Nothing

        competitionTitle =
            Maybe.map .title competition |> Maybe.withDefault ""

        lang =
            model.lang
    in
    div [ Attr.class "max-w-5xl mx-auto px-4" ]
        [ h1 [ Attr.class "type-h1 text-brand mb-2" ] [ text (t lang I18n.AdminEntries) ]
        , p [ Attr.class "type-caption text-text-muted mb-6" ] [ text competitionTitle ]
        , viewAdminError model.authError
        , case ( competition, model.adminEntries, model.voting.adminBallots ) of
            ( Just c, RemoteData.Success entries, RemoteData.Success ballots ) ->
                if c.votingEnabled then
                    viewVoteResult lang c entries ballots

                else
                    text ""

            ( Just c, _, RemoteData.Failure _ ) ->
                if c.votingEnabled then
                    div [ Attr.class "rounded-lg bg-white shadow-sm border border-border-default p-6 mb-6", Attr.id "vote-result" ]
                        [ h2 [ Attr.class "type-h3 text-brand mb-2" ] [ text (t lang I18n.AdminVoteResultHeading) ]
                        , p [ Attr.class "text-brand-red" ] [ text (t lang I18n.LoadFailed) ]
                        ]

                else
                    text ""

            _ ->
                text ""
        , case model.adminEntries of
            RemoteData.Success entries ->
                if List.isEmpty entries then
                    p [ Attr.class "text-text-muted" ] [ text (t model.lang I18n.NoEntries) ]

                else
                    ul [ Attr.class "grid gap-4" ] (List.map (viewAdminEntryCard model) entries)

            RemoteData.Loading ->
                p [ Attr.class "text-text-muted motion-safe:animate-pulse" ] [ text (t model.lang I18n.Loading) ]

            RemoteData.Failure _ ->
                p [ Attr.class "text-brand-red" ] [ text (t model.lang I18n.LoadFailed) ]

            RemoteData.NotAsked ->
                text ""
        ]


{-| The live count of the votes, for the organiser (ADR-0007): the approved
entries by points, and those left out because their submitter did not vote.
-}
viewVoteResult : Lang -> Competition -> List ReviewableEntry -> List Ballot -> Html Msg
viewVoteResult lang competition reviewables ballots =
    let
        approved =
            List.filter (\r -> r.entry.status == Approved) reviewables

        result =
            Voting.tally competition.votingRequired (List.map .entry approved) ballots

        submitterOf entry =
            approved
                |> List.filter (\r -> r.entry.id == entry.id)
                |> List.head
                |> Maybe.map .submitterName
                |> Maybe.withDefault ""
    in
    div [ Attr.class "rounded-lg bg-white shadow-sm border border-border-default p-6 mb-6", Attr.id "vote-result" ]
        [ h2 [ Attr.class "type-h3 text-brand mb-2" ] [ text (t lang I18n.AdminVoteResultHeading) ]
        , p [ Attr.class "type-caption text-text-muted mb-4" ]
            [ text (t lang I18n.AdminBallotCount ++ String.fromInt (List.length ballots)) ]
        , ol [ Attr.class "grid gap-1" ]
            (List.map
                (\row ->
                    li [ Attr.class "type-body-small text-brand flex gap-3" ]
                        [ span [ Attr.class "w-8" ] [ text (String.fromInt row.place ++ ".") ]
                        , span [ Attr.class "flex-1" ] [ text (row.entry.title ++ " — " ++ submitterOf row.entry) ]
                        , span [] [ text (String.fromInt row.points ++ t lang I18n.VotePointsSuffix) ]
                        ]
                )
                result.ranked
            )
        , if List.isEmpty result.excluded then
            text ""

          else
            p [ Attr.class "type-caption text-text-muted mt-4" ]
                [ text
                    (t lang I18n.AdminNotVoted
                        ++ String.join ", " (List.map (\entry -> entry.title ++ " (" ++ submitterOf entry ++ ")") result.excluded)
                    )
                ]
        ]


viewAdminEntryCard : Model -> ReviewableEntry -> Html Msg
viewAdminEntryCard model reviewable =
    let
        lang =
            model.lang
    in
    li [ Attr.class "rounded-lg bg-white shadow-sm border border-border-default p-6" ]
        [ div [ Attr.class "flex flex-wrap items-center gap-3 mb-2" ]
            [ h2 [ Attr.class "type-h4 text-brand" ] [ text reviewable.entry.title ]
            , span [ Attr.class "type-caption rounded-full px-2 py-0.5 bg-bg-subtle text-brand" ]
                [ text (entryStatusLabel lang reviewable.entry.status) ]
            ]
        , p [ Attr.class "type-caption text-text-muted" ] [ text reviewable.submitterName ]
        , case reviewable.entry.description of
            Just description ->
                p [ Attr.class "text-brand mb-4 whitespace-pre-line" ] [ text description ]

            Nothing ->
                text ""
        , div [ Attr.class "flex flex-wrap gap-3 mb-4" ]
            (List.map (viewEntryImage model reviewable.entry) reviewable.entry.images)
        , p [ Attr.class "type-caption text-text-muted" ]
            [ text (t lang I18n.AdminImagesCount ++ String.fromInt (List.length reviewable.entry.images)) ]
        , p [ Attr.class "type-caption text-text-muted" ]
            [ text (t lang I18n.AdminPublishedReviews ++ String.fromInt (List.length reviewable.entry.publishedReviews)) ]
        , viewEntryActions lang reviewable.entry
        ]


{-| The status changes an admin can make on an entry. Rejecting is the only
red action.
-}
viewEntryActions : Lang -> Entry -> Html Msg
viewEntryActions lang entry =
    let
        action label msg classes =
            button
                [ Attr.type_ "button"
                , Attr.class ("type-body-small px-4 py-2 rounded focus-visible:ring-2 focus-visible:ring-brand outline-none hover:opacity-90 motion-safe:transition-opacity " ++ classes)
                , Events.onClick msg
                ]
                [ text label ]
    in
    div [ Attr.class "flex flex-wrap gap-3 mt-4" ]
        (case entry.status of
            Submitted ->
                [ action (t lang I18n.AdminApprove) (ApproveEntry entry.id) "bg-brand-yellow text-brand"
                , action (t lang I18n.AdminReject) (RejectEntry entry.id) "bg-brand-red text-text-on-dark"
                ]

            Approved ->
                [ action (t lang I18n.AdminReset) (ResetEntry entry.id) "bg-bg-subtle text-brand"
                , action (t lang I18n.AdminReject) (RejectEntry entry.id) "bg-brand-red text-text-on-dark"
                ]

            Rejected ->
                [ action (t lang I18n.AdminReset) (ResetEntry entry.id) "bg-bg-subtle text-brand" ]

            Draft ->
                []
        )


entryStatusLabel : Lang -> EntryStatus -> String
entryStatusLabel lang status =
    case status of
        Draft ->
            t lang I18n.StatusDraft

        Submitted ->
            t lang I18n.StatusSubmitted

        Approved ->
            t lang I18n.StatusApproved

        Rejected ->
            t lang I18n.StatusRejected


viewAdminError : Maybe String -> Html msg
viewAdminError maybeError =
    case maybeError of
        Just message ->
            p [ Attr.attribute "role" "alert", Attr.class "text-brand-red type-caption mb-4" ] [ text message ]

        Nothing ->
            text ""


viewEntryImage : Model -> Entry -> String -> Html Msg
viewEntryImage model entry filename =
    img
        [ Attr.src (model.pbUrl ++ "/api/files/entries/" ++ entry.id ++ "/" ++ filename ++ "?thumb=400x300")
        , Attr.alt (entry.title ++ ": " ++ filename)
        , Attr.class "h-32 w-44 object-cover rounded-lg border border-border-default"
        ]
        []

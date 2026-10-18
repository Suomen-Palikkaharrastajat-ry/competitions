module View exposing (fileKey, starRating, view, viewEntryRow)

{-| View rendering for the competition platform.
-}

import Criteria exposing (Criterion)
import Dict exposing (Dict)
import File
import Html exposing (Html, a, button, div, form, h1, h2, header, img, input, label, main_, nav, p, span, text, textarea)
import Html.Attributes as Attr
import Html.Events as Events
import I18n exposing (t)
import Json.Decode as Decode
import Lang exposing (Lang)
import RemoteData
import Scoring
import Time
import Types exposing (..)
import View.Admin exposing (viewAdminCompetition, viewAdminEntries, viewAdminHome)
import View.Layout
import View.Vote exposing (viewVotePage, viewVotingCompetitions)


{-| Top-level view — the shared layout around the page for the auth state.
-}
view : Model -> Html Msg
view model =
    div []
        (View.Layout.view
            { model = model
            , main =
                main_
                    [ Attr.id "main-content"
                    , Attr.attribute "tabindex" "-1"
                    , Attr.class "max-w-5xl mx-auto w-full px-4 py-8 flex-1"
                    ]
                    [ case model.auth of
                        LoggedOut ->
                            viewLoginEmail model

                        AwaitingOtp state ->
                            viewLoginOtp state model

                        LoggedIn user ->
                            viewPage user model
                    ]
            }
        )


viewLoginEmail : Model -> Html Msg
viewLoginEmail model =
    div [ Attr.class "flex items-center justify-center" ]
        [ div [ Attr.class "max-w-5xl mx-auto w-full" ]
            [ div [ Attr.class "rounded-lg bg-white shadow-sm border border-border-default p-8 max-w-md mx-auto" ]
                [ h1 [ Attr.class "type-h1 tracking-tight text-brand mb-6" ]
                    [ text (t model.lang I18n.LogIn) ]
                , form [ Events.onSubmit RequestOtp ]
                    [ label [ Attr.class "block mb-1 type-body-small text-brand", Attr.for "email" ]
                        [ text (t model.lang I18n.EmailLabel) ]
                    , input
                        [ Attr.id "email"
                        , Attr.type_ "email"
                        , Attr.placeholder (t model.lang I18n.EmailPlaceholder)
                        , Attr.value model.emailInput
                        , Attr.class "w-full rounded border border-border-default px-3 py-2 text-brand focus-visible:ring-2 focus-visible:ring-brand outline-none mb-4"
                        , Events.onInput EmailChanged
                        ]
                        []
                    , button
                        [ Attr.type_ "submit"
                        , Attr.class "bg-brand-yellow text-brand type-body-small px-6 py-3 rounded hover:opacity-90 motion-safe:transition-opacity w-full"
                        ]
                        [ text (t model.lang I18n.SendCode) ]
                    , button
                        [ Attr.type_ "button"
                        , Attr.class "mt-3 border border-border-default text-brand type-body-small px-6 py-3 rounded hover:bg-bg-subtle motion-safe:transition-colors w-full"
                        , Events.onClick StartKeycloakLogin
                        ]
                        [ text (t model.lang I18n.KeycloakLogin) ]
                    ]
                , viewError model.lang model.authError
                , p [ Attr.class "mt-4 type-caption text-text-muted" ]
                    [ text (t model.lang I18n.CodeHint) ]
                ]
            ]
        ]


viewLoginOtp : { email : String, otpId : String } -> Model -> Html Msg
viewLoginOtp state model =
    div [ Attr.class "flex items-center justify-center" ]
        [ div [ Attr.class "max-w-5xl mx-auto w-full" ]
            [ div [ Attr.class "rounded-lg bg-white shadow-sm border border-border-default p-8 max-w-md mx-auto" ]
                [ h1 [ Attr.class "type-h1 tracking-tight text-brand mb-2" ]
                    [ text (t model.lang I18n.CheckEmailTitle) ]
                , p [ Attr.class "type-caption text-text-muted mb-6" ]
                    [ text (t model.lang I18n.CodeSentTo ++ state.email) ]
                , form [ Events.onSubmit SubmitOtp ]
                    [ label [ Attr.class "block mb-1 type-body-small text-brand", Attr.for "otp" ]
                        [ text (t model.lang I18n.CodeLabel) ]
                    , input
                        [ Attr.id "otp"
                        , Attr.type_ "text"
                        , Attr.attribute "inputmode" "numeric"
                        , Attr.attribute "pattern" "[0-9]{6}"
                        , Attr.maxlength 6
                        , Attr.placeholder "123456"
                        , Attr.value model.otpInput
                        , Attr.class "w-full rounded border border-border-default px-3 py-2 text-brand focus-visible:ring-2 focus-visible:ring-brand outline-none mb-4"
                        , Events.onInput OtpCodeChanged
                        ]
                        []
                    , div [ Attr.class "flex gap-3" ]
                        [ button
                            [ Attr.type_ "submit"
                            , Attr.class "bg-brand-yellow text-brand type-body-small px-6 py-3 rounded hover:opacity-90 motion-safe:transition-opacity"
                            ]
                            [ text (t model.lang I18n.LoginSubmit) ]
                        , button
                            [ Attr.type_ "button"
                            , Attr.class "text-brand underline px-3 py-3"
                            , Events.onClick (NavigateTo LoginPage)
                            ]
                            [ text (t model.lang I18n.ChangeAddress) ]
                        ]
                    ]
                , viewError model.lang model.authError
                ]
            ]
        ]


viewSetDisplayName : Model -> Html Msg
viewSetDisplayName model =
    div [ Attr.class "flex items-center justify-center" ]
        [ div [ Attr.class "max-w-5xl mx-auto w-full" ]
            [ div [ Attr.class "rounded-lg bg-white shadow-sm border border-border-default p-8 max-w-md mx-auto" ]
                [ h1 [ Attr.class "type-h1 tracking-tight text-brand mb-6" ]
                    [ text (t model.lang I18n.DisplayNameTitle) ]
                , form [ Events.onSubmit SaveDisplayName ]
                    [ label [ Attr.class "block mb-1 type-body-small text-brand", Attr.for "displayName" ]
                        [ text (t model.lang I18n.DisplayNameLabel) ]
                    , input
                        [ Attr.id "displayName"
                        , Attr.type_ "text"
                        , Attr.placeholder "Pekka Palikka"
                        , Attr.value model.displayNameInput
                        , Attr.class "w-full rounded border border-border-default px-3 py-2 text-brand focus-visible:ring-2 focus-visible:ring-brand outline-none mb-4"
                        , Events.onInput DisplayNameChanged
                        ]
                        []
                    , button
                        [ Attr.type_ "submit"
                        , Attr.class "bg-brand-yellow text-brand type-body-small px-6 py-3 rounded hover:opacity-90 motion-safe:transition-opacity w-full"
                        ]
                        [ text (t model.lang I18n.Save) ]
                    ]
                , viewError model.lang model.authError
                ]
            ]
        ]


viewPage : AuthUser -> Model -> Html Msg
viewPage user model =
    case model.page of
        LoginPage ->
            viewLoginEmail model

        SetDisplayNamePage ->
            viewSetDisplayName model

        DashboardPage ->
            viewDashboard user model

        MyEntriesPage ->
            viewMyEntries user model

        ParticipationPage entryId ->
            viewParticipation model entryId

        SubmitEntryPage _ ->
            viewSubmitForm model

        ReviewQueuePage ->
            if user.isReviewer then
                viewReviewQueue user model

            else
                div [] [ text (t model.lang I18n.NoAccess) ]

        AdminPage ->
            viewAdminHome model

        AdminCompetitionPage target ->
            viewAdminCompetition model target

        AdminEntriesPage competitionId ->
            viewAdminEntries model competitionId

        VotePage _ ->
            viewVotePage model

        NotFoundPage ->
            div [] [ text (t model.lang I18n.PageNotFound) ]


viewDashboard : AuthUser -> Model -> Html Msg
viewDashboard user model =
    div []
        [ viewVotingCompetitions model
        , h2 [ Attr.class "type-h3 text-brand mb-6" ] [ text (t model.lang I18n.OpenCompetitions) ]
        , case model.competitions of
            RemoteData.NotAsked ->
                text ""

            RemoteData.Loading ->
                viewLoadingSkeleton model.lang

            RemoteData.Failure _ ->
                p [ Attr.class "text-brand-red" ] [ text (t model.lang I18n.CompetitionsLoadFailed) ]

            RemoteData.Success comps ->
                if List.isEmpty comps then
                    p [ Attr.class "text-text-muted" ] [ text (t model.lang I18n.NoOpenCompetitions) ]

                else
                    let
                        myEntries =
                            RemoteData.withDefault [] model.myEntries
                    in
                    div [ Attr.class "grid grid-cols-1 sm:grid-cols-2 gap-4" ]
                        (List.map
                            (\comp -> viewCompetitionCard model.lang model.pbUrl model.now (Scoring.canSubmitMore comp myEntries) comp)
                            comps
                        )
        ]


viewCompetitionCard : Lang -> String -> Time.Posix -> Bool -> Competition -> Html Msg
viewCompetitionCard lang pbUrl now canEnter comp =
    div
        [ Attr.class "rounded-lg overflow-hidden border border-border-default bg-white hover:shadow-md motion-safe:transition-shadow"
        ]
        [ case comp.coverImage of
            Just filename ->
                img
                    [ Attr.src (pbUrl ++ "/api/files/competitions/" ++ comp.id ++ "/" ++ filename)
                    , Attr.alt comp.title
                    , Attr.class "aspect-video object-cover w-full"
                    ]
                    []

            Nothing ->
                div [ Attr.class "aspect-video bg-bg-subtle flex items-center justify-center" ]
                    [ span [ Attr.class "type-caption text-text-subtle" ] [ text (t lang I18n.NoCoverImage) ] ]
        , div [ Attr.class "p-4" ]
            [ p [ Attr.class "type-h4 text-brand mb-1" ] [ text comp.title ]
            , case comp.theme of
                Just theme ->
                    p [ Attr.class "type-caption text-text-muted mb-2" ] [ text (t lang I18n.ThemePrefix ++ theme) ]

                Nothing ->
                    text ""
            , p [ Attr.class ("type-caption mb-4 " ++ (Scoring.deadlineUrgency comp.endDate now |> Maybe.withDefault "text-text-muted")) ]
                [ text (t lang I18n.EndsPrefix ++ String.left 16 comp.endDate) ]
            , if canEnter then
                button
                    [ Attr.class "bg-brand-yellow text-brand type-body-small px-4 py-2 rounded hover:opacity-90 motion-safe:transition-opacity"
                    , Events.onClick (SelectCompetition comp)
                    ]
                    [ text (t lang I18n.Participate) ]

              else
                p [ Attr.class "type-caption text-text-muted" ] [ text (t lang I18n.MaxEntriesUsed) ]
            ]
        ]


viewLoadingSkeleton : Lang -> Html msg
viewLoadingSkeleton lang =
    div
        [ Attr.attribute "aria-busy" "true"
        , Attr.attribute "aria-label" (t lang I18n.Loading)
        ]
        (List.repeat 3 (div [ Attr.class "motion-safe:animate-pulse bg-border-default rounded h-6 mb-2" ] []))


viewMyEntries : AuthUser -> Model -> Html Msg
viewMyEntries _ model =
    div []
        [ h2 [ Attr.class "type-h3 text-brand mb-6" ] [ text (t model.lang I18n.MyEntries) ]
        , case model.myEntries of
            RemoteData.NotAsked ->
                text ""

            RemoteData.Loading ->
                viewLoadingSkeleton model.lang

            RemoteData.Failure _ ->
                p [ Attr.class "text-brand-red" ] [ text (t model.lang I18n.LoadFailed) ]

            RemoteData.Success entries ->
                div []
                    [ if List.isEmpty entries then
                        p [ Attr.class "text-text-muted mb-4" ] [ text (t model.lang I18n.NoEntries) ]

                      else
                        div [ Attr.class "border border-border-default rounded-lg divide-y divide-border-default mb-4" ]
                            (List.map (viewEntryRow model.lang model.criteria) entries)
                    , button
                        [ Attr.class "bg-brand-yellow text-brand type-body-small px-4 py-2 rounded hover:opacity-90 motion-safe:transition-opacity"
                        , Events.onClick (NavigateTo DashboardPage)
                        ]
                        [ text (t model.lang I18n.NewEntry) ]
                    ]
        ]


viewParticipation : Model -> String -> Html Msg
viewParticipation model entryId =
    case model.myEntries of
        RemoteData.NotAsked ->
            text ""

        RemoteData.Loading ->
            viewLoadingSkeleton model.lang

        RemoteData.Failure _ ->
            p [ Attr.class "text-brand-red" ] [ text (t model.lang I18n.LoadFailed) ]

        RemoteData.Success entries ->
            case Scoring.findEntry (Just entryId) entries of
                Just entry ->
                    viewParticipationDetail model entry

                Nothing ->
                    p [ Attr.class "text-text-muted" ] [ text (t model.lang I18n.EntryNotFound) ]


viewParticipationDetail : Model -> Entry -> Html Msg
viewParticipationDetail model entry =
    let
        lang =
            model.lang

        description =
            entry.description
                |> Maybe.map String.trim
                |> Maybe.andThen
                    (\trimmed ->
                        if String.isEmpty trimmed then
                            Nothing

                        else
                            Just trimmed
                    )
    in
    div [ Attr.class "rounded-lg bg-white shadow-sm border border-border-default p-8 max-w-2xl" ]
        [ button
            [ Attr.class "type-caption text-brand underline mb-4 focus-visible:ring-2 focus-visible:ring-brand outline-none"
            , Events.onClick (NavigateTo MyEntriesPage)
            ]
            [ text (t lang I18n.MyEntries) ]
        , h1 [ Attr.class "type-h1 tracking-tight text-brand mb-2" ] [ text entry.title ]
        , p [ Attr.class "type-caption text-text-muted" ]
            [ text (entry.competition |> Maybe.map .title |> Maybe.withDefault entry.competitionId) ]
        , div [ Attr.class "mb-4" ] [ viewCompetitionPeriod lang entry.competition ]
        , div [ Attr.class "mb-4" ] [ viewStatusBadge lang entry.status ]
        , viewPublishedScores lang model.criteria entry.publishedReviews
        , case description of
            Just text_ ->
                p [ Attr.class "text-brand mb-4 whitespace-pre-line" ] [ text text_ ]

            Nothing ->
                text ""
        , viewEntryImages model.pbUrl entry
        , if Scoring.canEditEntry model.now entry then
            div [ Attr.class "flex flex-wrap items-center gap-4 mt-6" ]
                [ if entry.status == Submitted then
                    p [ Attr.class "type-caption text-text-muted" ] [ text (t lang I18n.EditableUntilDeadline) ]

                  else
                    text ""
                , button
                    [ Attr.class "bg-brand-yellow text-brand type-body-small px-6 py-3 rounded hover:opacity-90 motion-safe:transition-opacity"
                    , Events.onClick (EditEntry entry.id)
                    ]
                    [ text (t lang I18n.Edit) ]
                ]

          else
            text ""
        ]


viewCompetitionPeriod : Lang -> Maybe Competition -> Html msg
viewCompetitionPeriod lang competition =
    case competition of
        Just comp ->
            p [ Attr.class "type-caption text-text-muted" ]
                [ text
                    (t lang I18n.PeriodPrefix
                        ++ Scoring.formatDate comp.startDate
                        ++ t lang I18n.PeriodTo
                        ++ Scoring.formatDate comp.endDate
                    )
                ]

        Nothing ->
            text ""


viewEntryRow : Lang -> List Criterion -> Entry -> Html Msg
viewEntryRow lang criteria entry =
    div [ Attr.class "flex items-center gap-4 p-4" ]
        [ div [ Attr.class "flex-1" ]
            [ button
                [ Attr.class "type-body-small text-brand text-left underline focus-visible:ring-2 focus-visible:ring-brand outline-none"
                , Events.onClick (NavigateTo (ParticipationPage entry.id))
                ]
                [ text entry.title ]
            , p [ Attr.class "type-caption text-text-muted" ]
                [ text (entry.competition |> Maybe.map .title |> Maybe.withDefault entry.competitionId) ]
            , viewCompetitionPeriod lang entry.competition
            , viewPublishedScores lang criteria entry.publishedReviews
            ]
        , viewStatusBadge lang entry.status
        , case entry.status of
            Draft ->
                div [ Attr.class "flex gap-2" ]
                    [ button
                        [ Attr.class "type-caption text-brand underline focus-visible:ring-2 focus-visible:ring-brand outline-none"
                        , Events.onClick (EditEntry entry.id)
                        ]
                        [ text (t lang I18n.Edit) ]
                    ]

            _ ->
                text ""
        ]


viewPublishedScores : Lang -> List Criterion -> List ReviewSummary -> Html msg
viewPublishedScores lang criteria reviews =
    if List.isEmpty reviews then
        text ""

    else
        let
            avg =
                Scoring.entryAverage (List.map .total reviews)

            -- Always show one decimal place, e.g. 17.0, 16.5
            intPart =
                floor avg

            decPart =
                round ((avg - toFloat intPart) * 10)

            avgStr =
                String.fromInt intPart ++ "." ++ String.fromInt decPart
        in
        div []
            (p [ Attr.class "type-caption text-text-muted mt-1" ]
                [ text (t lang I18n.ScorePrefix ++ avgStr ++ " / " ++ String.fromInt (Scoring.scoreMax criteria)) ]
                :: List.filterMap
                    (\review ->
                        review.comment
                            |> Maybe.map String.trim
                            |> Maybe.andThen
                                (\comment ->
                                    if String.isEmpty comment then
                                        Nothing

                                    else
                                        Just (p [ Attr.class "type-caption text-text-muted" ] [ text (t lang I18n.ReviewerCommentPrefix ++ comment) ])
                                )
                    )
                    reviews
            )


viewStatusBadge : Lang -> EntryStatus -> Html msg
viewStatusBadge lang status =
    let
        ( label, cls ) =
            case status of
                Draft ->
                    ( t lang I18n.StatusDraft, "bg-brand-yellow/20 text-brand" )

                Submitted ->
                    ( t lang I18n.StatusSubmitted, "bg-brand/15 text-brand" )

                Approved ->
                    ( t lang I18n.StatusApproved, "bg-brand-nougat-light text-brand-nougat-dark" )

                Rejected ->
                    ( t lang I18n.StatusRejected, "bg-brand-red/15 text-brand-red" )
    in
    span [ Attr.class (cls ++ " type-caption px-2 py-0.5 rounded-full") ] [ text label ]


viewSubmitForm : Model -> Html Msg
viewSubmitForm model =
    let
        form =
            model.submitForm

        competition =
            model.selectedCompetition

        competitionTitle =
            competition
                |> Maybe.map .title
                |> Maybe.withDefault (t model.lang I18n.Competition)

        minImages =
            competition
                |> Maybe.andThen .minImagesPerEntry
                |> Maybe.withDefault 1
                |> max 0

        maxImages =
            competition
                |> Maybe.andThen .maxImagesPerEntry
                |> Maybe.withDefault 10
                |> min 10
                |> max minImages

        currentImageCount =
            List.length form.existingImages + List.length form.selectedFiles

        imageLimitText =
            String.fromInt minImages ++ "-" ++ String.fromInt maxImages

        -- A submitted entry is only saved again; its status does not change.
        submittedEdit =
            Scoring.findEntry form.entryId (RemoteData.withDefault [] model.myEntries)
                |> Maybe.map (\entry -> entry.status == Submitted)
                |> Maybe.withDefault False
    in
    case form.step of
        SubmitSuccess ->
            div [ Attr.class "rounded-lg bg-white shadow-sm border border-border-default p-8 max-w-2xl" ]
                [ h1 [ Attr.class "type-h1 text-brand mb-4" ] [ text (t model.lang I18n.EntrySubmitted) ]
                , p [ Attr.class "text-text-muted mb-6" ]
                    [ text (t model.lang I18n.EntrySubmittedBody) ]
                , button
                    [ Attr.class "bg-brand-yellow text-brand type-body-small px-6 py-3 rounded hover:opacity-90 motion-safe:transition-opacity"
                    , Events.onClick (NavigateTo MyEntriesPage)
                    ]
                    [ text (t model.lang I18n.MyEntries) ]
                ]

        _ ->
            div [ Attr.class "rounded-lg bg-white shadow-sm border border-border-default p-8 max-w-2xl" ]
                [ h1 [ Attr.class "type-h1 tracking-tight text-brand mb-6" ]
                    [ text (t model.lang I18n.ParticipateIn ++ competitionTitle) ]
                , div []
                    [ label [ Attr.class "block mb-1 type-body-small text-brand", Attr.for "entry-title" ]
                        [ text (t model.lang I18n.NameLabel) ]
                    , input
                        [ Attr.id "entry-title"
                        , Attr.type_ "text"
                        , Attr.placeholder (t model.lang I18n.NamePlaceholder)
                        , Attr.value form.title
                        , Attr.class "w-full rounded border border-border-default px-3 py-2 text-brand focus-visible:ring-2 focus-visible:ring-brand outline-none mb-4"
                        , Events.onInput EntryTitleChanged
                        ]
                        []
                    , label [ Attr.class "block mb-1 type-body-small text-brand", Attr.for "entry-desc" ]
                        [ text (t model.lang I18n.DescriptionLabel) ]
                    , textarea
                        [ Attr.id "entry-desc"
                        , Attr.rows 4
                        , Attr.placeholder (t model.lang I18n.DescriptionPlaceholder)
                        , Attr.value form.description
                        , Attr.class "w-full rounded border border-border-default px-3 py-2 text-brand focus-visible:ring-2 focus-visible:ring-brand outline-none mb-4"
                        , Events.onInput EntryDescriptionChanged
                        ]
                        []
                    , label [ Attr.class "block mb-1 type-body-small text-brand", Attr.for "entry-images" ]
                        [ text (t model.lang I18n.ImagesLabelStart ++ imageLimitText ++ t model.lang I18n.ImagesLabelEnd) ]
                    , div [ Attr.class "border-2 border-dashed border-border-default rounded-lg p-6 mb-4" ]
                        [ input
                            [ Attr.id "entry-images"
                            , Attr.type_ "file"
                            , Attr.multiple True
                            , Attr.accept "image/jpeg,image/png,image/webp"
                            , Attr.class "mb-2"
                            , Attr.disabled (currentImageCount >= maxImages || form.isCompressing)
                            , rawFilesOnChange RawFilesSelected
                            ]
                            []
                        , p [ Attr.class "type-caption text-text-muted" ]
                            [ text (String.fromInt currentImageCount ++ " / " ++ String.fromInt maxImages ++ t model.lang I18n.ImagesSuffix) ]
                        , p [ Attr.class "type-caption text-text-muted mt-1" ]
                            [ text (t model.lang I18n.ImagesOptimizedWebP) ]
                        , if form.isCompressing then
                            p [ Attr.class "type-caption text-text-muted mt-2 motion-safe:animate-pulse" ]
                                [ text (t model.lang I18n.CompressingImages) ]

                          else
                            text ""
                        , if not (List.isEmpty form.existingImages) || not (List.isEmpty form.selectedFiles) then
                            div [ Attr.class "flex flex-wrap gap-2 mt-2" ]
                                (List.map (viewExistingImageTile model.lang (entryImageUrl model.pbUrl (Maybe.withDefault "" form.entryId))) form.existingImages
                                    ++ List.indexedMap (viewSelectedFileTile model.lang form.previews) form.selectedFiles
                                )

                          else
                            text ""
                        ]
                    , case form.step of
                        UploadError err ->
                            p [ Attr.class "text-brand-red type-caption mb-4" ] [ text err ]

                        _ ->
                            text ""
                    , viewError model.lang model.authError
                    , p [ Attr.attribute "role" "status", Attr.class "type-caption text-brand mb-4" ]
                        [ if form.draftSaved then
                            text
                                (t model.lang
                                    (if submittedEdit then
                                        I18n.ChangesSavedNotice

                                     else
                                        I18n.DraftSavedNotice
                                    )
                                )

                          else
                            text ""
                        ]
                    , if submittedEdit then
                        text ""

                      else
                        p [ Attr.class "type-caption text-text-muted mb-4" ]
                            [ text (t model.lang I18n.NoEditAfterSubmit) ]
                    , div [ Attr.class "flex gap-3" ]
                        ([ button
                            [ Attr.class
                                (if submittedEdit then
                                    "bg-brand-yellow text-brand type-body-small px-6 py-3 rounded hover:opacity-90 motion-safe:transition-opacity"

                                 else
                                    "bg-bg-subtle text-brand type-body-small px-6 py-3 rounded hover:bg-border-default motion-safe:transition-colors"
                                )
                            , Attr.disabled (form.isCompressing || form.step == Uploading)
                            , Events.onClick SaveDraft
                            ]
                            [ text
                                (if form.step == Uploading then
                                    t model.lang I18n.Saving

                                 else if submittedEdit then
                                    t model.lang I18n.SaveChanges

                                 else
                                    t model.lang I18n.SaveDraft
                                )
                            ]
                         ]
                            ++ (if submittedEdit then
                                    []

                                else
                                    [ button
                                        [ Attr.class "bg-brand-yellow text-brand type-body-small px-6 py-3 rounded hover:opacity-90 motion-safe:transition-opacity"
                                        , Attr.disabled (form.isCompressing || form.step == Uploading)
                                        , Events.onClick SubmitEntry
                                        ]
                                        [ text (t model.lang I18n.SubmitForReview) ]
                                    ]
                               )
                            ++ (if form.entryId == Nothing then
                                    []

                                else
                                    [ button
                                        [ Attr.class "bg-bg-subtle text-brand type-body-small px-6 py-3 rounded hover:bg-border-default motion-safe:transition-colors"
                                        , Events.onClick CancelEdit
                                        ]
                                        [ text (t model.lang I18n.Cancel) ]
                                    ]
                               )
                        )
                    ]
                , if form.step == ConfirmingSubmit then
                    viewConfirmSubmit model.lang

                  else
                    text ""
                ]


viewConfirmSubmit : Lang -> Html Msg
viewConfirmSubmit lang =
    div
        [ Attr.attribute "role" "dialog"
        , Attr.attribute "aria-modal" "true"
        , Attr.attribute "aria-labelledby" "confirm-submit-title"
        , Attr.class "fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4"
        ]
        [ div [ Attr.class "bg-white rounded-lg shadow-xl max-w-md w-full p-6" ]
            [ h2 [ Attr.id "confirm-submit-title", Attr.class "type-h3 text-brand mb-2" ]
                [ text (t lang I18n.ConfirmSubmitTitle) ]
            , p [ Attr.class "text-text-muted mb-6" ] [ text (t lang I18n.ConfirmSubmitBody) ]
            , div [ Attr.class "flex gap-3 justify-end" ]
                [ button
                    [ Attr.class "bg-bg-subtle text-brand type-body-small px-6 py-3 rounded hover:bg-border-default focus-visible:ring-2 focus-visible:ring-brand outline-none"
                    , Events.onClick CancelSubmit
                    ]
                    [ text (t lang I18n.Cancel) ]
                , button
                    [ Attr.class "bg-brand-yellow text-brand type-body-small px-6 py-3 rounded hover:opacity-90 focus-visible:ring-2 focus-visible:ring-brand outline-none"
                    , Attr.autofocus True
                    , Events.onClick ConfirmSubmit
                    ]
                    [ text (t lang I18n.ConfirmSubmitYes) ]
                ]
            ]
        ]


formatFileSize : Int -> String
formatFileSize bytes =
    if bytes < 1024 then
        String.fromInt bytes ++ " B"

    else if bytes < 1048576 then
        String.fromInt (bytes // 1024) ++ " KB"

    else
        let
            mb10 =
                round (toFloat bytes / 104857.6)
        in
        String.fromInt (mb10 // 10) ++ "." ++ String.fromInt (modBy 10 mb10) ++ " MB"


{-| Identifies a selected file in the form's previews. The same file chosen
twice shares one preview.
-}
fileKey : File.File -> String
fileKey file =
    File.name file ++ "|" ++ String.fromInt (File.size file)


{-| An image in the entry form: a large preview with the file name only as its
tooltip and accessible name, and a button to remove it. Without a preview yet,
a placeholder keeps the tile's size.
-}
viewImageTile : Lang -> String -> String -> Maybe String -> Msg -> Html Msg
viewImageTile lang tooltip filename maybeUrl onRemove =
    div
        [ Attr.class "relative h-40 w-full max-w-52 overflow-hidden rounded-lg border border-border-default bg-bg-subtle"
        , Attr.title tooltip
        ]
        [ case maybeUrl of
            Just url ->
                img
                    [ Attr.src url
                    , Attr.alt filename
                    , Attr.class "h-full w-full object-cover"
                    ]
                    []

            Nothing ->
                span [ Attr.class "block h-full w-full bg-border-default motion-safe:animate-pulse" ] []
        , button
            [ Attr.type_ "button"
            , Attr.attribute "aria-label" (t lang I18n.RemoveFile ++ ": " ++ filename)
            , Attr.class "absolute right-2 top-2 flex h-8 w-8 items-center justify-center rounded-full bg-brand text-text-on-dark outline-none hover:opacity-90 focus-visible:ring-2 focus-visible:ring-brand-yellow focus-visible:ring-offset-2"
            , Events.onClick onRemove
            ]
            [ span [ Attr.attribute "aria-hidden" "true" ] [ text "×" ] ]
        ]


entryImageUrl : String -> String -> String -> String
entryImageUrl pbUrl entryId filename =
    pbUrl ++ "/api/files/entries/" ++ entryId ++ "/" ++ filename ++ "?thumb=400x300"


viewSelectedFileTile : Lang -> Dict String String -> Int -> File.File -> Html Msg
viewSelectedFileTile lang previews index file =
    let
        filename =
            File.name file
    in
    viewImageTile lang
        (filename ++ " (" ++ formatFileSize (File.size file) ++ ")")
        filename
        (Dict.get (fileKey file) previews)
        (RemoveSelectedFile index)


viewExistingImageTile : Lang -> (String -> String) -> String -> Html Msg
viewExistingImageTile lang thumbnailUrl filename =
    viewImageTile lang filename filename (Just (thumbnailUrl filename)) (RemoveExistingImage filename)


rawFilesOnChange : (Decode.Value -> msg) -> Html.Attribute msg
rawFilesOnChange toMsg =
    Events.custom "change"
        (Decode.at [ "target", "files" ] Decode.value
            |> Decode.map
                (\files ->
                    { message = toMsg files
                    , stopPropagation = False
                    , preventDefault = False
                    }
                )
        )


viewReviewQueue : AuthUser -> Model -> Html Msg
viewReviewQueue _ model =
    let
        applyFilter all =
            case model.reviewFilter of
                AllEntries ->
                    all

                NotYetReviewed ->
                    List.filter (\re -> re.myReview == Nothing) all

                ByCompetition compId ->
                    List.filter (\re -> re.competition.id == compId) all

        entries =
            case model.reviewQueue of
                RemoteData.Success all ->
                    applyFilter all

                _ ->
                    []
    in
    div []
        [ h2 [ Attr.class "type-h3 text-brand mb-4" ]
            [ text (t model.lang I18n.ReviewQueueTitle) ]
        , case model.reviewQueue of
            RemoteData.Loading ->
                viewLoadingSkeleton model.lang

            RemoteData.Failure _ ->
                p [ Attr.class "text-brand-red" ] [ text (t model.lang I18n.LoadFailed) ]

            _ ->
                div []
                    [ div [ Attr.class "flex gap-4 mb-4 type-caption" ]
                        [ filterBtn AllEntries model.reviewFilter (t model.lang I18n.FilterAll)
                        , filterBtn NotYetReviewed model.reviewFilter (t model.lang I18n.NotYetReviewed)
                        ]
                    , if List.isEmpty entries then
                        p [ Attr.class "text-text-muted" ] [ text (t model.lang I18n.NoEntries) ]

                      else
                        div [ Attr.class "border border-border-default rounded-lg divide-y divide-border-default" ]
                            (List.map (viewReviewQueueRow model.lang model.criteria) entries)
                    ]
        , case model.activeReview of
            Just rf ->
                viewReviewFormPanel model.lang model.criteria model.pbUrl rf

            Nothing ->
                text ""
        ]


filterBtn : ReviewFilter -> ReviewFilter -> String -> Html Msg
filterBtn target current label =
    button
        [ Attr.class
            (if target == current then
                "type-body-small text-brand underline"

             else
                "text-text-muted hover:text-brand"
            )
        , Events.onClick (ReviewFilterChanged target)
        ]
        [ text label ]


viewReviewQueueRow : Lang -> List Criterion -> ReviewableEntry -> Html Msg
viewReviewQueueRow lang criteria re =
    div [ Attr.class "flex items-center gap-4 p-4" ]
        [ div [ Attr.class "flex-1" ]
            [ p [ Attr.class "type-body-small text-brand" ] [ text re.entry.title ]
            , p [ Attr.class "type-caption text-text-muted" ]
                [ text (re.competition.title ++ " — " ++ re.submitterName) ]
            , case re.myReview of
                Just review ->
                    span [ Attr.class "bg-brand text-white type-caption px-3 py-1 rounded-full" ]
                        [ text
                            (t lang I18n.ScorePrefix
                                ++ String.fromInt (Scoring.reviewTotal review)
                                ++ "/"
                                ++ String.fromInt (Scoring.scoreMax criteria)
                            )
                        ]

                Nothing ->
                    span [ Attr.class "type-caption text-text-subtle" ] [ text (t lang I18n.NotYetReviewed) ]
            ]
        , viewStatusBadge lang re.entry.status
        , button
            [ Attr.class "type-body-small bg-brand-yellow text-brand px-3 py-1 rounded hover:opacity-90 focus-visible:ring-2 focus-visible:ring-brand outline-none"
            , Events.onClick (OpenReviewForm re)
            ]
            [ text
                (case re.myReview of
                    Just _ ->
                        t lang I18n.EditReview

                    Nothing ->
                        t lang I18n.Rate
                )
            ]
        , button
            [ Attr.class "type-body-small bg-brand-yellow text-brand px-3 py-1 rounded hover:opacity-90 focus-visible:ring-2 focus-visible:ring-brand outline-none"
            , Attr.attribute "aria-label" (t lang I18n.ApproveEntryPrefix ++ re.entry.title)
            , Events.onClick (ApproveEntry re.entry.id)
            ]
            [ text (t lang I18n.Approve) ]
        , button
            [ Attr.class "type-body-small bg-brand-red text-white px-3 py-1 rounded hover:opacity-90 focus-visible:ring-2 focus-visible:ring-brand outline-none"
            , Attr.attribute "aria-label" (t lang I18n.RejectEntryPrefix ++ re.entry.title)
            , Events.onClick (RejectEntry re.entry.id)
            ]
            [ text (t lang I18n.Reject) ]
        ]


viewReviewFormPanel : Lang -> List Criterion -> String -> ReviewForm -> Html Msg
viewReviewFormPanel lang criteria pbUrl rf =
    let
        r =
            rf.draftReview

        total =
            Scoring.reviewTotal r
    in
    div
        [ Attr.attribute "role" "dialog"
        , Attr.attribute "aria-modal" "true"
        , Attr.attribute "aria-labelledby" "review-form-title"
        , Attr.class "fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4"
        ]
        [ div [ Attr.class "bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-screen overflow-y-auto p-6" ]
            [ div [ Attr.class "flex items-center justify-between mb-4" ]
                [ h2
                    [ Attr.id "review-form-title"
                    , Attr.class "type-h3 text-brand"
                    ]
                    [ text (t lang I18n.ReviewPrefix ++ rf.reviewableEntry.entry.title) ]
                , button
                    [ Attr.class "text-text-subtle hover:text-brand type-h1 focus-visible:ring-2 focus-visible:ring-brand outline-none"
                    , Attr.attribute "aria-label" (t lang I18n.CloseReviewForm)
                    , Events.onClick CloseReviewForm
                    ]
                    [ text "×" ]
                ]
            , viewEntryImages pbUrl rf.reviewableEntry.entry
            , case rf.reviewableEntry.entry.description of
                Just desc ->
                    p [ Attr.class "type-body text-brand mb-6" ] [ text desc ]

                Nothing ->
                    text ""
            , div [ Attr.class "mb-6" ]
                (List.map
                    (\criterion ->
                        viewScoreRow lang criterion.label (Dict.get criterion.id r.scores |> Maybe.withDefault 3) (ScoreChanged criterion.id)
                    )
                    criteria
                    ++ [ p [ Attr.class "type-h4 text-brand mt-4" ]
                            [ text (t lang I18n.TotalScore ++ String.fromInt total ++ "/" ++ String.fromInt (Scoring.scoreMax criteria)) ]
                       ]
                )
            , label [ Attr.class "block mb-1 type-body-small text-brand", Attr.for "review-comment" ]
                [ text (t lang I18n.CommentLabel) ]
            , textarea
                [ Attr.id "review-comment"
                , Attr.rows 4
                , Attr.value r.comment
                , Attr.class "w-full rounded border border-border-default px-3 py-2 text-brand focus-visible:ring-2 focus-visible:ring-brand outline-none mb-4"
                , Events.onInput ReviewCommentChanged
                ]
                []
            , case rf.saveError of
                Just err ->
                    p [ Attr.class "text-brand-red type-caption mb-4" ] [ text err ]

                Nothing ->
                    text ""
            , div [ Attr.class "flex gap-3" ]
                [ button
                    [ Attr.class "bg-bg-subtle text-brand type-body-small px-6 py-3 rounded hover:bg-border-default focus-visible:ring-2 focus-visible:ring-brand outline-none"
                    , Attr.disabled rf.saving
                    , Events.onClick SaveReview
                    ]
                    [ text
                        (if rf.saving then
                            t lang I18n.Saving

                         else
                            t lang I18n.Save
                        )
                    ]
                , button
                    [ Attr.class "bg-brand-yellow text-brand type-body-small px-6 py-3 rounded hover:opacity-90 focus-visible:ring-2 focus-visible:ring-brand outline-none"
                    , Attr.disabled rf.saving
                    , Events.onClick SaveAndPublishReview
                    ]
                    [ text (t lang I18n.SaveAndPublish) ]
                ]
            ]
        ]


viewEntryImages : String -> Entry -> Html Msg
viewEntryImages pbUrl entry =
    if List.isEmpty entry.images then
        text ""

    else
        div [ Attr.class "flex gap-3 overflow-x-auto mb-6" ]
            (entry.images
                |> List.map
                    (\filename ->
                        img
                            [ Attr.src (pbUrl ++ "/api/files/entries/" ++ entry.id ++ "/" ++ filename ++ "?thumb=400x300")
                            , Attr.alt (entry.title ++ ": " ++ filename)
                            , Attr.class "h-32 w-44 object-cover rounded-lg border border-border-default"
                            ]
                            []
                    )
            )


viewScoreRow : Lang -> String -> Int -> (Int -> Msg) -> Html Msg
viewScoreRow lang label current onChange =
    div [ Attr.class "flex items-center gap-4 mb-2" ]
        [ span [ Attr.class "w-48 type-caption text-text-muted" ] [ text label ]
        , starRating lang current onChange
        , span [ Attr.class "type-caption text-brand w-8" ]
            [ text (String.fromInt current ++ "/5") ]
        ]


{-| A row of 5 clickable stars. Filled stars (1..current) are brand-yellow; rest are gray.
-}
starRating : Lang -> Int -> (Int -> msg) -> Html msg
starRating lang current onChange =
    div [ Attr.class "flex gap-1" ]
        (List.range 1 5
            |> List.map
                (\n ->
                    button
                        [ Attr.type_ "button"
                        , Attr.class
                            (if n <= current then
                                "text-brand-yellow type-h3 focus-visible:ring-2 focus-visible:ring-brand outline-none"

                             else
                                "text-text-subtle type-h3 focus-visible:ring-2 focus-visible:ring-brand outline-none"
                            )
                        , Attr.attribute "aria-label" (t lang I18n.StarPrefix ++ String.fromInt n ++ t lang I18n.StarSuffix)
                        , Events.onClick (onChange n)
                        ]
                        [ text "★" ]
                )
        )


viewError : Lang -> Maybe String -> Html msg
viewError lang maybeError =
    case maybeError of
        Just err ->
            p
                [ Attr.class "mt-3 type-caption text-brand-red"
                , Attr.attribute "role" "alert"
                ]
                [ text (t lang I18n.ErrorPrefix ++ err) ]

        Nothing ->
            text ""

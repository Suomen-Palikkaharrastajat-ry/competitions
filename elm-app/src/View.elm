module View exposing (starRating, view)

{-| View rendering for the competition platform.
-}

import File
import Html exposing (Html, a, button, div, form, h1, h2, header, img, input, label, main_, nav, p, span, text, textarea)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import RemoteData
import Scoring
import Types exposing (..)


{-| Top-level view — dispatches to page views based on auth and page state.
-}
view : Model -> Html Msg
view model =
    case model.auth of
        LoggedOut ->
            viewLoginEmail model

        AwaitingOtp state ->
            viewLoginOtp state model

        LoggedIn user ->
            viewAppShell user model


viewLoginEmail : Model -> Html Msg
viewLoginEmail model =
    div [ Attr.class "min-h-screen bg-gray-50 flex items-center justify-center px-4" ]
        [ div [ Attr.class "max-w-5xl mx-auto w-full" ]
            [ div [ Attr.class "rounded-lg bg-white shadow-sm border border-gray-200 p-8 max-w-md mx-auto" ]
                [ h1 [ Attr.class "text-2xl font-bold tracking-tight text-brand mb-6" ]
                    [ text "Kirjaudu sisään" ]
                , form [ Events.onSubmit RequestOtp ]
                    [ label [ Attr.class "block mb-1 font-medium text-brand", Attr.for "email" ]
                        [ text "Sähköpostiosoite" ]
                    , input
                        [ Attr.id "email"
                        , Attr.type_ "email"
                        , Attr.placeholder "sinä@example.com"
                        , Attr.value model.emailInput
                        , Attr.class "w-full rounded border border-gray-300 px-3 py-2 text-brand focus-visible:ring-2 focus-visible:ring-brand outline-none mb-4"
                        , Events.onInput EmailChanged
                        ]
                        []
                    , button
                        [ Attr.type_ "submit"
                        , Attr.class "bg-brand-yellow text-brand font-semibold px-6 py-3 rounded hover:opacity-90 transition-opacity w-full"
                        ]
                        [ text "Lähetä kirjautumiskoodi" ]
                    ]
                , viewError model.authError
                , p [ Attr.class "mt-4 text-sm text-gray-600" ]
                    [ text "Saat 6-numeroisen koodin sähköpostiisi." ]
                ]
            ]
        ]


viewLoginOtp : { email : String, otpId : String } -> Model -> Html Msg
viewLoginOtp state model =
    div [ Attr.class "min-h-screen bg-gray-50 flex items-center justify-center px-4" ]
        [ div [ Attr.class "max-w-5xl mx-auto w-full" ]
            [ div [ Attr.class "rounded-lg bg-white shadow-sm border border-gray-200 p-8 max-w-md mx-auto" ]
                [ h1 [ Attr.class "text-2xl font-bold tracking-tight text-brand mb-2" ]
                    [ text "Tarkista sähköpostisi" ]
                , p [ Attr.class "text-sm text-gray-600 mb-6" ]
                    [ text ("Koodi lähetetty: " ++ state.email) ]
                , form [ Events.onSubmit SubmitOtp ]
                    [ label [ Attr.class "block mb-1 font-medium text-brand", Attr.for "otp" ]
                        [ text "Kirjautumiskoodi" ]
                    , input
                        [ Attr.id "otp"
                        , Attr.type_ "text"
                        , Attr.attribute "inputmode" "numeric"
                        , Attr.attribute "pattern" "[0-9]{6}"
                        , Attr.maxlength 6
                        , Attr.placeholder "123456"
                        , Attr.value model.otpInput
                        , Attr.class "w-full rounded border border-gray-300 px-3 py-2 text-brand focus-visible:ring-2 focus-visible:ring-brand outline-none mb-4"
                        , Events.onInput OtpCodeChanged
                        ]
                        []
                    , div [ Attr.class "flex gap-3" ]
                        [ button
                            [ Attr.type_ "submit"
                            , Attr.class "bg-brand-yellow text-brand font-semibold px-6 py-3 rounded hover:opacity-90 transition-opacity"
                            ]
                            [ text "Kirjaudu" ]
                        , button
                            [ Attr.type_ "button"
                            , Attr.class "text-brand underline px-3 py-3"
                            , Events.onClick (NavigateTo LoginPage)
                            ]
                            [ text "← Vaihda osoite" ]
                        ]
                    ]
                , viewError model.authError
                ]
            ]
        ]


viewSetDisplayName : Model -> Html Msg
viewSetDisplayName model =
    div [ Attr.class "min-h-screen bg-gray-50 flex items-center justify-center px-4" ]
        [ div [ Attr.class "max-w-5xl mx-auto w-full" ]
            [ div [ Attr.class "rounded-lg bg-white shadow-sm border border-gray-200 p-8 max-w-md mx-auto" ]
                [ h1 [ Attr.class "text-2xl font-bold tracking-tight text-brand mb-6" ]
                    [ text "Valitse näyttönimi" ]
                , form [ Events.onSubmit SaveDisplayName ]
                    [ label [ Attr.class "block mb-1 font-medium text-brand", Attr.for "displayName" ]
                        [ text "Näyttönimi" ]
                    , input
                        [ Attr.id "displayName"
                        , Attr.type_ "text"
                        , Attr.placeholder "Pekka Palikka"
                        , Attr.value model.displayNameInput
                        , Attr.class "w-full rounded border border-gray-300 px-3 py-2 text-brand focus-visible:ring-2 focus-visible:ring-brand outline-none mb-4"
                        , Events.onInput DisplayNameChanged
                        ]
                        []
                    , button
                        [ Attr.type_ "submit"
                        , Attr.class "bg-brand-yellow text-brand font-semibold px-6 py-3 rounded hover:opacity-90 transition-opacity w-full"
                        ]
                        [ text "Tallenna" ]
                    ]
                , viewError model.authError
                ]
            ]
        ]


viewAppShell : AuthUser -> Model -> Html Msg
viewAppShell user model =
    div [ Attr.class "min-h-screen bg-gray-50" ]
        [ viewHeader user
        , main_ [ Attr.class "max-w-5xl mx-auto px-4 py-8" ]
            [ viewPage user model ]
        ]


viewHeader : AuthUser -> Html Msg
viewHeader user =
    header [ Attr.class "bg-white border-b border-gray-200" ]
        [ div [ Attr.class "max-w-5xl mx-auto px-4 flex items-center justify-between h-14" ]
            [ span [ Attr.class "font-bold text-brand" ] [ text "Palikkakilpailu" ]
            , nav [ Attr.class "flex items-center gap-4 text-sm" ]
                ([ a
                    [ Attr.href "#"
                    , Attr.class "text-brand hover:underline"
                    , Events.onClick (NavigateTo DashboardPage)
                    ]
                    [ text "Kilpailut" ]
                 , a
                    [ Attr.href "#"
                    , Attr.class "text-brand hover:underline"
                    , Events.onClick (NavigateTo MyEntriesPage)
                    ]
                    [ text "Omat osallistumiset" ]
                 ]
                    ++ (if user.isReviewer then
                            [ a
                                [ Attr.href "#"
                                , Attr.class "text-brand hover:underline"
                                , Events.onClick (NavigateTo ReviewQueuePage)
                                ]
                                [ text "Arvosteltavat" ]
                            ]

                        else
                            []
                       )
                    ++ [ span [ Attr.class "text-gray-500" ] [ text user.displayName ]
                       , button
                            [ Attr.class "text-brand underline focus-visible:ring-2 focus-visible:ring-brand outline-none"
                            , Events.onClick LogOut
                            ]
                            [ text "Kirjaudu ulos" ]
                       ]
                )
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

        SubmitEntryPage _ ->
            viewSubmitForm model

        ReviewQueuePage ->
            if user.isReviewer then
                viewReviewQueue user model

            else
                div [] [ text "Ei oikeutta." ]

        NotFoundPage ->
            div [] [ text "Sivua ei löydy." ]


viewDashboard : AuthUser -> Model -> Html Msg
viewDashboard _ model =
    div []
        [ h2 [ Attr.class "text-xl font-bold text-brand mb-6" ] [ text "Avoimet kilpailut" ]
        , case model.competitions of
            RemoteData.NotAsked ->
                text ""

            RemoteData.Loading ->
                p [ Attr.class "text-gray-500" ] [ text "Ladataan..." ]

            RemoteData.Failure _ ->
                p [ Attr.class "text-red-600" ] [ text "Kilpailujen lataus epäonnistui." ]

            RemoteData.Success comps ->
                if List.isEmpty comps then
                    p [ Attr.class "text-gray-500" ] [ text "Ei avoimia kilpailuja." ]

                else
                    div [ Attr.class "grid grid-cols-1 sm:grid-cols-2 gap-4" ]
                        (List.map viewCompetitionCard comps)
        ]


viewCompetitionCard : Competition -> Html Msg
viewCompetitionCard comp =
    div
        [ Attr.class "rounded-lg overflow-hidden border border-gray-200 bg-white hover:shadow-md transition-shadow"
        ]
        [ case comp.coverImage of
            Just filename ->
                img
                    [ Attr.src ("/api/files/competitions/" ++ comp.id ++ "/" ++ filename)
                    , Attr.alt comp.title
                    , Attr.class "aspect-video object-cover w-full"
                    ]
                    []

            Nothing ->
                div [ Attr.class "aspect-video bg-gray-100 flex items-center justify-center" ]
                    [ span [ Attr.class "text-gray-400 text-sm" ] [ text "Ei kansikuvaa" ] ]
        , div [ Attr.class "p-4" ]
            [ p [ Attr.class "text-lg font-semibold text-brand mb-1" ] [ text comp.title ]
            , case comp.theme of
                Just theme ->
                    p [ Attr.class "text-sm text-gray-600 mb-2" ] [ text ("Teema: " ++ theme) ]

                Nothing ->
                    text ""
            , p [ Attr.class "text-sm text-gray-500 mb-4" ]
                [ text ("Päättyy: " ++ String.left 10 comp.endDate) ]
            , button
                [ Attr.class "bg-brand-yellow text-brand font-semibold px-4 py-2 rounded hover:opacity-90 transition-opacity"
                , Events.onClick (SelectCompetition comp)
                ]
                [ text "Osallistu →" ]
            ]
        ]


viewMyEntries : AuthUser -> Model -> Html Msg
viewMyEntries _ model =
    div []
        [ h2 [ Attr.class "text-xl font-bold text-brand mb-6" ] [ text "Omat osallistumiset" ]
        , case model.myEntries of
            RemoteData.NotAsked ->
                text ""

            RemoteData.Loading ->
                p [ Attr.class "text-gray-500" ] [ text "Ladataan..." ]

            RemoteData.Failure _ ->
                p [ Attr.class "text-red-600" ] [ text "Lataus epäonnistui." ]

            RemoteData.Success entries ->
                div []
                    [ if List.isEmpty entries then
                        p [ Attr.class "text-gray-500 mb-4" ] [ text "Ei osallistumisia." ]

                      else
                        div [ Attr.class "border border-gray-200 rounded-lg divide-y divide-gray-200 mb-4" ]
                            (List.map viewEntryRow entries)
                    , button
                        [ Attr.class "bg-brand-yellow text-brand font-semibold px-4 py-2 rounded hover:opacity-90 transition-opacity"
                        , Events.onClick (NavigateTo DashboardPage)
                        ]
                        [ text "+ Uusi osallistuminen" ]
                    ]
        ]


viewEntryRow : Entry -> Html Msg
viewEntryRow entry =
    div [ Attr.class "flex items-center gap-4 p-4" ]
        [ div [ Attr.class "flex-1" ]
            [ p [ Attr.class "font-medium text-brand" ] [ text entry.title ]
            , p [ Attr.class "text-sm text-gray-500" ] [ text entry.competitionId ]
            ]
        , viewStatusBadge entry.status
        , case entry.status of
            Draft ->
                div [ Attr.class "flex gap-2" ]
                    [ button
                        [ Attr.class "text-sm text-brand underline focus-visible:ring-2 focus-visible:ring-brand outline-none"
                        , Events.onClick (EditDraft entry.id)
                        ]
                        [ text "Muokkaa" ]
                    ]

            _ ->
                text ""
        ]


viewStatusBadge : EntryStatus -> Html msg
viewStatusBadge status =
    let
        ( label, cls ) =
            case status of
                Draft ->
                    ( "Luonnos", "bg-yellow-100 text-yellow-800" )

                Submitted ->
                    ( "Lähetetty", "bg-blue-100 text-blue-800" )

                Approved ->
                    ( "Hyväksytty", "bg-green-100 text-green-800" )

                Rejected ->
                    ( "Hylätty", "bg-red-100 text-red-800" )
    in
    span [ Attr.class (cls ++ " text-xs px-2 py-0.5 rounded-full") ] [ text label ]


viewSubmitForm : Model -> Html Msg
viewSubmitForm model =
    let
        form =
            model.submitForm

        competitionTitle =
            model.selectedCompetition
                |> Maybe.map .title
                |> Maybe.withDefault "Kilpailu"
    in
    case form.step of
        SubmitSuccess ->
            div [ Attr.class "rounded-lg bg-white shadow-sm border border-gray-200 p-8 max-w-2xl" ]
                [ h1 [ Attr.class "text-2xl font-bold text-brand mb-4" ] [ text "Osallistuminen lähetetty!" ]
                , p [ Attr.class "text-gray-600 mb-6" ]
                    [ text "Osallistumisesi on lähetetty arvioitavaksi. Näet sen Omat osallistumiset -sivulla." ]
                , button
                    [ Attr.class "bg-brand-yellow text-brand font-semibold px-6 py-3 rounded hover:opacity-90 transition-opacity"
                    , Events.onClick (NavigateTo MyEntriesPage)
                    ]
                    [ text "Omat osallistumiset" ]
                ]

        _ ->
            div [ Attr.class "rounded-lg bg-white shadow-sm border border-gray-200 p-8 max-w-2xl" ]
                [ h1 [ Attr.class "text-2xl font-bold tracking-tight text-brand mb-6" ]
                    [ text ("Osallistu kilpailuun: " ++ competitionTitle) ]
                , div []
                    [ label [ Attr.class "block mb-1 font-medium text-brand", Attr.for "entry-title" ]
                        [ text "Nimi *" ]
                    , input
                        [ Attr.id "entry-title"
                        , Attr.type_ "text"
                        , Attr.placeholder "MOC:n nimi"
                        , Attr.value form.title
                        , Attr.class "w-full rounded border border-gray-300 px-3 py-2 text-brand focus-visible:ring-2 focus-visible:ring-brand outline-none mb-4"
                        , Events.onInput EntryTitleChanged
                        ]
                        []
                    , label [ Attr.class "block mb-1 font-medium text-brand", Attr.for "entry-desc" ]
                        [ text "Kuvaus" ]
                    , textarea
                        [ Attr.id "entry-desc"
                        , Attr.rows 4
                        , Attr.placeholder "Kerro MOC:stasi..."
                        , Attr.value form.description
                        , Attr.class "w-full rounded border border-gray-300 px-3 py-2 text-brand focus-visible:ring-2 focus-visible:ring-brand outline-none mb-4"
                        , Events.onInput EntryDescriptionChanged
                        ]
                        []
                    , label [ Attr.class "block mb-1 font-medium text-brand" ]
                        [ text "Kuvat * (max 10, jpg/png/webp, max 10 MB/kuva)" ]
                    , div [ Attr.class "border-2 border-dashed border-gray-300 rounded-lg p-6 mb-4" ]
                        [ input
                            [ Attr.type_ "file"
                            , Attr.multiple True
                            , Attr.accept "image/jpeg,image/png,image/webp"
                            , Attr.class "mb-2"
                            , filesOnChange FilesSelected
                            ]
                            []
                        , if not (List.isEmpty form.existingImages) then
                            div [ Attr.class "flex flex-wrap gap-2 mt-2" ]
                                (List.map (viewImageChip True) form.existingImages)

                          else
                            text ""
                        ]
                    , case form.step of
                        UploadError err ->
                            p [ Attr.class "text-red-600 text-sm mb-4" ] [ text err ]

                        _ ->
                            text ""
                    , viewError model.authError
                    , p [ Attr.class "text-sm text-gray-500 mb-4" ]
                        [ text "ℹ Lähettämisen jälkeen muokkaus ei ole mahdollista." ]
                    , div [ Attr.class "flex gap-3" ]
                        [ button
                            [ Attr.class "bg-gray-100 text-brand font-semibold px-6 py-3 rounded hover:bg-gray-200 transition-colors"
                            , Attr.disabled (form.step == Uploading)
                            , Events.onClick SaveDraft
                            ]
                            [ text
                                (if form.step == Uploading then
                                    "Tallennetaan..."

                                 else
                                    "Tallenna luonnos"
                                )
                            ]
                        , button
                            [ Attr.class "bg-brand-yellow text-brand font-semibold px-6 py-3 rounded hover:opacity-90 transition-opacity"
                            , Attr.disabled (form.step == Uploading)
                            , Events.onClick SubmitEntry
                            ]
                            [ text "Lähetä arvosteltavaksi" ]
                        ]
                    ]
                ]


viewImageChip : Bool -> String -> Html Msg
viewImageChip removable filename =
    div [ Attr.class "flex items-center gap-1 bg-gray-100 rounded px-2 py-1 text-sm text-brand" ]
        [ text filename
        , if removable then
            button
                [ Attr.class "ml-1 text-gray-500 hover:text-red-600 focus-visible:ring-2 focus-visible:ring-brand outline-none"
                , Events.onClick (RemoveExistingImage filename)
                ]
                [ text "×" ]

          else
            text ""
        ]


filesOnChange : (File.File -> List File.File -> msg) -> Html.Attribute msg
filesOnChange toMsg =
    Events.custom "change"
        (Decode.at [ "target", "files" ]
            (Decode.oneOrMore toMsg File.decoder)
            |> Decode.map
                (\msg ->
                    { message = msg
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
        [ h2 [ Attr.class "text-xl font-bold text-brand mb-4" ]
            [ text "Arvosteltavat osallistumiset" ]
        , case model.reviewQueue of
            RemoteData.Loading ->
                p [ Attr.class "text-gray-500" ] [ text "Ladataan..." ]

            RemoteData.Failure _ ->
                p [ Attr.class "text-red-600" ] [ text "Lataus epäonnistui." ]

            _ ->
                div []
                    [ div [ Attr.class "flex gap-4 mb-4 text-sm" ]
                        [ filterBtn AllEntries model.reviewFilter "Kaikki"
                        , filterBtn NotYetReviewed model.reviewFilter "Ei vielä arvosteltu"
                        ]
                    , if List.isEmpty entries then
                        p [ Attr.class "text-gray-500" ] [ text "Ei osallistumisia." ]

                      else
                        div [ Attr.class "border border-gray-200 rounded-lg divide-y divide-gray-200" ]
                            (List.map viewReviewQueueRow entries)
                    ]
        , case model.activeReview of
            Just rf ->
                viewReviewFormPanel rf

            Nothing ->
                text ""
        ]


filterBtn : ReviewFilter -> ReviewFilter -> String -> Html Msg
filterBtn target current label =
    button
        [ Attr.class
            (if target == current then
                "font-semibold text-brand underline"

             else
                "text-gray-500 hover:text-brand"
            )
        , Events.onClick (ReviewFilterChanged target)
        ]
        [ text label ]


viewReviewQueueRow : ReviewableEntry -> Html Msg
viewReviewQueueRow re =
    div [ Attr.class "flex items-center gap-4 p-4" ]
        [ div [ Attr.class "flex-1" ]
            [ p [ Attr.class "font-medium text-brand" ] [ text re.entry.title ]
            , p [ Attr.class "text-sm text-gray-500" ]
                [ text (re.competition.title ++ " — " ++ re.submitterName) ]
            , case re.myReview of
                Just review ->
                    span [ Attr.class "bg-brand text-white text-sm px-3 py-1 rounded-full" ]
                        [ text
                            ("Pisteet: "
                                ++ String.fromInt (Scoring.reviewTotal review)
                                ++ "/"
                                ++ String.fromInt Scoring.scoreMax
                            )
                        ]

                Nothing ->
                    span [ Attr.class "text-sm text-gray-400" ] [ text "Ei vielä arvosteltu" ]
            ]
        , viewStatusBadge re.entry.status
        , button
            [ Attr.class "text-sm bg-brand-yellow text-brand font-semibold px-3 py-1 rounded hover:opacity-90 focus-visible:ring-2 focus-visible:ring-brand outline-none"
            , Events.onClick (OpenReviewForm re)
            ]
            [ text
                (case re.myReview of
                    Just _ ->
                        "Muokkaa arvostelua"

                    Nothing ->
                        "Arvioi"
                )
            ]
        , button
            [ Attr.class "text-sm bg-green-600 text-white px-3 py-1 rounded hover:opacity-90 focus-visible:ring-2 focus-visible:ring-brand outline-none"
            , Attr.attribute "aria-label" ("Hyväksy osallistuminen: " ++ re.entry.title)
            , Events.onClick (ApproveEntry re.entry.id)
            ]
            [ text "Hyväksy" ]
        , button
            [ Attr.class "text-sm bg-red-700 text-white px-3 py-1 rounded hover:opacity-90 focus-visible:ring-2 focus-visible:ring-brand outline-none"
            , Attr.attribute "aria-label" ("Hylkää osallistuminen: " ++ re.entry.title)
            , Events.onClick (RejectEntry re.entry.id)
            ]
            [ text "Hylkää" ]
        ]


viewReviewFormPanel : ReviewForm -> Html Msg
viewReviewFormPanel rf =
    let
        r =
            rf.draftReview

        total =
            Scoring.reviewTotal r
    in
    div
        [ Attr.attribute "role" "dialog"
        , Attr.attribute "aria-labelledby" "review-form-title"
        , Attr.class "fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4"
        ]
        [ div [ Attr.class "bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-screen overflow-y-auto p-6" ]
            [ div [ Attr.class "flex items-center justify-between mb-4" ]
                [ h2
                    [ Attr.id "review-form-title"
                    , Attr.class "text-xl font-bold text-brand"
                    ]
                    [ text ("Arvostele: " ++ rf.reviewableEntry.entry.title) ]
                , button
                    [ Attr.class "text-gray-400 hover:text-brand text-2xl focus-visible:ring-2 focus-visible:ring-brand outline-none"
                    , Attr.attribute "aria-label" "Sulje arvostelulomake"
                    , Events.onClick CloseReviewForm
                    ]
                    [ text "×" ]
                ]
            , div [ Attr.class "mb-6" ]
                [ viewScoreRow "Teema-vastaavuus" r.scoreTheme ScoreThemeChanged
                , viewScoreRow "Omaperäisyys" r.scoreOriginality ScoreOriginalityChanged
                , viewScoreRow "Rakennustekniikka" r.scoreTechnique ScoreTechniqueChanged
                , viewScoreRow "Esitys (kuvat)" r.scorePresentation ScorePresentationChanged
                , p [ Attr.class "text-lg font-bold text-brand mt-4" ]
                    [ text ("Kokonaispisteet: " ++ String.fromInt total ++ "/" ++ String.fromInt Scoring.scoreMax) ]
                ]
            , label [ Attr.class "block mb-1 font-medium text-brand", Attr.for "review-comment" ]
                [ text "Kommentti" ]
            , textarea
                [ Attr.id "review-comment"
                , Attr.rows 4
                , Attr.value r.comment
                , Attr.class "w-full rounded border border-gray-300 px-3 py-2 text-brand focus-visible:ring-2 focus-visible:ring-brand outline-none mb-4"
                , Events.onInput ReviewCommentChanged
                ]
                []
            , case rf.saveError of
                Just err ->
                    p [ Attr.class "text-red-600 text-sm mb-4" ] [ text err ]

                Nothing ->
                    text ""
            , div [ Attr.class "flex gap-3" ]
                [ button
                    [ Attr.class "bg-gray-100 text-brand font-semibold px-6 py-3 rounded hover:bg-gray-200 focus-visible:ring-2 focus-visible:ring-brand outline-none"
                    , Attr.disabled rf.saving
                    , Events.onClick SaveReview
                    ]
                    [ text
                        (if rf.saving then
                            "Tallennetaan..."

                         else
                            "Tallenna"
                        )
                    ]
                , button
                    [ Attr.class "bg-brand-yellow text-brand font-semibold px-6 py-3 rounded hover:opacity-90 focus-visible:ring-2 focus-visible:ring-brand outline-none"
                    , Attr.disabled rf.saving
                    , Events.onClick SaveReview
                    ]
                    [ text "Tallenna ja julkaise" ]
                ]
            ]
        ]


viewScoreRow : String -> Int -> (Int -> Msg) -> Html Msg
viewScoreRow label current onChange =
    div [ Attr.class "flex items-center gap-4 mb-2" ]
        [ span [ Attr.class "w-48 text-sm text-gray-600" ] [ text label ]
        , starRating current onChange
        , span [ Attr.class "text-sm text-brand w-8" ]
            [ text (String.fromInt current ++ "/5") ]
        ]


{-| A row of 5 clickable stars. Filled stars (1..current) are brand-yellow; rest are gray.
-}
starRating : Int -> (Int -> msg) -> Html msg
starRating current onChange =
    div [ Attr.class "flex gap-1" ]
        (List.range 1 5
            |> List.map
                (\n ->
                    button
                        [ Attr.type_ "button"
                        , Attr.class
                            (if n <= current then
                                "text-brand-yellow text-xl focus-visible:ring-2 focus-visible:ring-brand outline-none"

                             else
                                "text-gray-300 text-xl focus-visible:ring-2 focus-visible:ring-brand outline-none"
                            )
                        , Attr.attribute "aria-label" ("Arvo " ++ String.fromInt n ++ " viidestä")
                        , Events.onClick (onChange n)
                        ]
                        [ text "★" ]
                )
        )


viewError : Maybe String -> Html msg
viewError maybeError =
    case maybeError of
        Just err ->
            p [ Attr.class "mt-3 text-sm text-red-600" ] [ text ("Virhe: " ++ err) ]

        Nothing ->
            text ""

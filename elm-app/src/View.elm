module View exposing (view)

{-| View rendering for the competition platform.
-}

import Html exposing (Html, a, button, div, form, h1, header, input, label, main_, nav, p, span, text)
import Html.Attributes as Attr
import Html.Events as Events
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


viewSetDisplayName : AuthUser -> Model -> Html Msg
viewSetDisplayName _ model =
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
                    [ Attr.href "#", Attr.class "text-brand hover:underline", Events.onClick (NavigateTo DashboardPage) ]
                    [ text "Kilpailut" ]
                 , a
                    [ Attr.href "#", Attr.class "text-brand hover:underline", Events.onClick (NavigateTo MyEntriesPage) ]
                    [ text "Omat osallistumiset" ]
                 ]
                    ++ (if user.isReviewer then
                            [ a
                                [ Attr.href "#", Attr.class "text-brand hover:underline", Events.onClick (NavigateTo ReviewQueuePage) ]
                                [ text "Arvosteltavat" ]
                            ]

                        else
                            []
                       )
                    ++ [ span [ Attr.class "text-gray-500" ] [ text user.displayName ]
                       , button
                            [ Attr.class "text-brand underline"
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
            viewSetDisplayName user model

        DashboardPage ->
            div [] [ text "Tervetuloa! Kilpailut tulossa pian." ]

        MyEntriesPage ->
            div [] [ text "Omat osallistumiset tulossa pian." ]

        SubmitEntryPage _ ->
            div [] [ text "Osallistumislomake tulossa pian." ]

        ReviewQueuePage ->
            div [] [ text "Arvostelujono tulossa pian." ]

        NotFoundPage ->
            div [] [ text "Sivua ei löydy." ]


viewError : Maybe String -> Html msg
viewError maybeError =
    case maybeError of
        Just err ->
            p [ Attr.class "mt-3 text-sm text-red-600" ] [ text ("Virhe: " ++ err) ]

        Nothing ->
            text ""

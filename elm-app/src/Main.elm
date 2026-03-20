module Main exposing
    ( authResponseDecoder
    , main
    , otpResponseDecoder
    , update
    , validateEmail
    , validateOtpCode
    )

{-| Entry point for the Palikkakilpailu competition platform application.
-}

import Browser
import Html exposing (Html)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Ports
import Types exposing (..)
import View


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        ( auth, page ) =
            case flags.restoredAuth of
                Just user ->
                    ( LoggedIn user
                    , if String.isEmpty user.displayName then
                        SetDisplayNamePage

                      else
                        DashboardPage
                    )

                Nothing ->
                    ( LoggedOut, LoginPage )
    in
    ( { auth = auth
      , pbUrl = flags.pbUrl
      , emailInput = ""
      , otpInput = ""
      , authError = Nothing
      , displayNameInput = ""
      , page = page
      , lang = Fi
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        EmailChanged email ->
            ( { model | emailInput = email, authError = Nothing }, Cmd.none )

        OtpCodeChanged code ->
            ( { model | otpInput = code, authError = Nothing }, Cmd.none )

        RequestOtp ->
            case validateEmail model.emailInput of
                Err e ->
                    ( { model | authError = Just e }, Cmd.none )

                Ok email ->
                    ( model, requestOtp model.pbUrl email )

        OtpRequested (Ok resp) ->
            ( { model | auth = AwaitingOtp { email = model.emailInput, otpId = resp.otpId } }
            , Cmd.none
            )

        OtpRequested (Err _) ->
            ( { model | authError = Just "Sähköpostin lähetys epäonnistui" }, Cmd.none )

        SubmitOtp ->
            case model.auth of
                AwaitingOtp state ->
                    case validateOtpCode model.otpInput of
                        Err e ->
                            ( { model | authError = Just e }, Cmd.none )

                        Ok code ->
                            ( model, submitOtp model.pbUrl state.otpId code )

                _ ->
                    ( model, Cmd.none )

        OtpSubmitted (Ok resp) ->
            let
                rec =
                    resp.record

                user =
                    { rec | token = resp.token }

                page =
                    if String.isEmpty user.displayName then
                        SetDisplayNamePage

                    else
                        DashboardPage
            in
            ( { model | auth = LoggedIn user, page = page, authError = Nothing }
            , Ports.storeAuth user
            )

        OtpSubmitted (Err (Http.BadStatus 400)) ->
            ( { model | authError = Just "Väärä koodi tai vanhentunut linkki" }, Cmd.none )

        OtpSubmitted (Err _) ->
            ( { model | authError = Just "Kirjautuminen epäonnistui" }, Cmd.none )

        LogOut ->
            ( { model
                | auth = LoggedOut
                , page = LoginPage
                , emailInput = ""
                , otpInput = ""
                , authError = Nothing
              }
            , Ports.clearAuth ()
            )

        DisplayNameChanged name ->
            ( { model | displayNameInput = name }, Cmd.none )

        SaveDisplayName ->
            case model.auth of
                LoggedIn user ->
                    ( model, saveDisplayName model.pbUrl user.id user.token model.displayNameInput )

                _ ->
                    ( model, Cmd.none )

        DisplayNameSaved (Ok updatedUser) ->
            ( { model | auth = LoggedIn updatedUser, page = DashboardPage }
            , Ports.storeAuth updatedUser
            )

        DisplayNameSaved (Err _) ->
            ( { model | authError = Just "Näyttönimen tallennus epäonnistui" }, Cmd.none )

        NavigateTo page ->
            ( { model | page = page }, Cmd.none )


view : Model -> Html Msg
view model =
    View.view model


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------


{-| Validate an email address (simple format check).
-}
validateEmail : String -> Result String String
validateEmail email =
    case String.split "@" email of
        [ before, after ] ->
            if String.length before > 0 && String.contains "." after && String.length after > 1 then
                Ok email

            else
                Err "Syötä kelvollinen sähköpostiosoite"

        _ ->
            Err "Syötä kelvollinen sähköpostiosoite"


{-| Validate a 6-digit numeric OTP code.
-}
validateOtpCode : String -> Result String String
validateOtpCode code =
    if String.length code == 6 && String.all Char.isDigit code then
        Ok code

    else
        Err "Koodi koostuu kuudesta numerosta"



-- ---------------------------------------------------------------------------
-- HTTP commands
-- ---------------------------------------------------------------------------


requestOtp : String -> String -> Cmd Msg
requestOtp pbUrl email =
    Http.post
        { url = pbUrl ++ "/api/collections/users/auth-with-otp"
        , body =
            Http.jsonBody
                (Encode.object [ ( "email", Encode.string email ) ])
        , expect = Http.expectJson OtpRequested otpResponseDecoder
        }


submitOtp : String -> String -> String -> Cmd Msg
submitOtp pbUrl otpId code =
    Http.post
        { url = pbUrl ++ "/api/collections/users/auth-with-otp"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "otpId", Encode.string otpId )
                    , ( "password", Encode.string code )
                    ]
                )
        , expect = Http.expectJson OtpSubmitted authResponseDecoder
        }


saveDisplayName : String -> String -> String -> String -> Cmd Msg
saveDisplayName pbUrl userId token displayName =
    Http.request
        { method = "PATCH"
        , headers = [ Http.header "Authorization" token ]
        , url = pbUrl ++ "/api/collections/users/records/" ++ userId
        , body =
            Http.jsonBody
                (Encode.object [ ( "display_name", Encode.string displayName ) ])
        , expect = Http.expectJson DisplayNameSaved authUserDecoder
        , timeout = Nothing
        , tracker = Nothing
        }



-- ---------------------------------------------------------------------------
-- Decoders
-- ---------------------------------------------------------------------------


{-| Decode the OTP request response: { "otpId": "..." }
-}
otpResponseDecoder : Decode.Decoder OtpResponse
otpResponseDecoder =
    Decode.map OtpResponse
        (Decode.field "otpId" Decode.string)


{-| Decode the auth user record from PocketBase.
-}
authUserDecoder : Decode.Decoder AuthUser
authUserDecoder =
    Decode.map5 AuthUser
        (Decode.field "id" Decode.string)
        (Decode.field "email" Decode.string)
        (Decode.succeed "")
        (Decode.maybe (Decode.field "display_name" Decode.string)
            |> Decode.map (Maybe.withDefault "")
        )
        (Decode.maybe (Decode.field "is_reviewer" Decode.bool)
            |> Decode.map (Maybe.withDefault False)
        )


{-| Decode the full auth response: { "token": "...", "record": { ... } }
-}
authResponseDecoder : Decode.Decoder AuthResponse
authResponseDecoder =
    Decode.field "token" Decode.string
        |> Decode.andThen
            (\token ->
                Decode.field "record"
                    (Decode.map4
                        (\id email displayName isReviewer ->
                            { token = token
                            , record =
                                AuthUser id email token displayName isReviewer
                            }
                        )
                        (Decode.field "id" Decode.string)
                        (Decode.field "email" Decode.string)
                        (Decode.maybe (Decode.field "display_name" Decode.string)
                            |> Decode.map (Maybe.withDefault "")
                        )
                        (Decode.maybe (Decode.field "is_reviewer" Decode.bool)
                            |> Decode.map (Maybe.withDefault False)
                        )
                    )
            )

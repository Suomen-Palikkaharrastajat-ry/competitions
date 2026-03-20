module Main exposing (main)

{-| Entry point for the Palikkakilpailu competition platform application
-}

import Browser
import Html exposing (Html)
import Ports
import Types exposing (AuthState(..), Lang(..), Model, Msg(..))
import View


main : Program (Maybe String) Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


init : Maybe String -> ( Model, Cmd Msg )
init maybeToken =
    let
        authState =
            case maybeToken of
                Just token ->
                    LoggedIn token

                Nothing ->
                    LoggedOut
    in
    ( { authState = authState, lang = Fi }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        TokenLoaded maybeToken ->
            let
                authState =
                    case maybeToken of
                        Just token ->
                            LoggedIn token

                        Nothing ->
                            LoggedOut
            in
            ( { model | authState = authState }, Cmd.none )


view : Model -> Html Msg
view model =
    View.view model


subscriptions : Model -> Sub Msg
subscriptions _ =
    Ports.loadToken TokenLoaded

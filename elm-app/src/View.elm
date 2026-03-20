module View exposing (view)

{-| View rendering for the competition platform
-}

import Html exposing (Html, h1, text)
import Html.Attributes as Attr
import Types exposing (Model, Msg)


{-| Main view — renders the app shell
-}
view : Model -> Html Msg
view _ =
    h1 [ Attr.class "text-2xl font-bold text-brand" ] [ text "Kilpailu" ]

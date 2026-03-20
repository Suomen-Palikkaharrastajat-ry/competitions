module Types exposing
    ( Model
    , Msg(..)
    , AuthState(..)
    , Lang(..)
    )

{-| Core types for the competition platform application
-}


{-| Supported display languages
-}
type Lang
    = Fi
    | En


{-| Authentication state — either logged out or logged in with a token
-}
type AuthState
    = LoggedOut
    | LoggedIn String


{-| The application model
-}
type alias Model =
    { authState : AuthState
    , lang : Lang
    }


{-| Messages for the Elm Architecture update loop
-}
type Msg
    = NoOp
    | TokenLoaded (Maybe String)

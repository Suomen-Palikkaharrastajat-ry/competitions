port module Ports exposing (storeToken, loadToken)

{-| Ports for JS interop — auth token persistence via localStorage
-}


{-| Send auth token to JavaScript to save in localStorage
-}
port storeToken : String -> Cmd msg


{-| Receive auth token from JavaScript on app initialization
-}
port loadToken : (Maybe String -> msg) -> Sub msg

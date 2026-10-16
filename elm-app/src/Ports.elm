port module Ports exposing (clearAuth, compressImages, compressionFailed, hashChanged, imagesCompressed, keycloakLoginFailed, keycloakLoginSucceeded, onAuthRestored, replaceHash, reportError, setHash, startKeycloakLogin, storeAuth)

{-| Ports for JS interop — auth persistence via localStorage and image compression.
-}

import Json.Decode
import Json.Encode
import Types exposing (AuthResponse, AuthUser)


{-| Save auth user to localStorage.
-}
port storeAuth : AuthUser -> Cmd msg


{-| Clear auth from localStorage (on logout).
-}
port clearAuth : () -> Cmd msg


{-| Start the Keycloak/OIDC login popup through the PocketBase JS SDK.
-}
port startKeycloakLogin : String -> Cmd msg


{-| Receive successful Keycloak auth from JavaScript.
-}
port keycloakLoginSucceeded : (AuthResponse -> msg) -> Sub msg


{-| Receive Keycloak auth failures from JavaScript.
-}
port keycloakLoginFailed : (String -> msg) -> Sub msg


{-| Receive restored auth from localStorage on app init (subscription variant).
-}
port onAuthRestored : (AuthUser -> msg) -> Sub msg


{-| Set the location hash of the page (without adding a history entry for the
same value).
-}
port setHash : String -> Cmd msg


{-| Replace the current location hash without adding a history entry or
raising a hash change. Used to normalise addresses the app does not keep.
-}
port replaceHash : String -> Cmd msg


{-| Receive the new location hash when it changes, for instance when a link
of the layout is followed.
-}
port hashChanged : (String -> msg) -> Sub msg


{-| Report a problem to the browser console.
-}
port reportError : String -> Cmd msg


{-| Request in-browser image compression to WebP.
-}
port compressImages : Json.Encode.Value -> Cmd msg


{-| Receive compressed WebP File objects from JavaScript.
-}
port imagesCompressed : (Json.Decode.Value -> msg) -> Sub msg


{-| Receive compression failure notifications from JavaScript.
-}
port compressionFailed : (String -> msg) -> Sub msg

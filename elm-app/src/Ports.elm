port module Ports exposing (clearAuth, keycloakLoginFailed, keycloakLoginSucceeded, onAuthRestored, startKeycloakLogin, storeAuth)

{-| Ports for JS interop — auth persistence via localStorage.
-}

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

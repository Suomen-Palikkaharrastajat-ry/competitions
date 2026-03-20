port module Ports exposing (clearAuth, onAuthRestored, storeAuth)

{-| Ports for JS interop — auth persistence via localStorage.
-}

import Types exposing (AuthUser)


{-| Save auth user to localStorage.
-}
port storeAuth : AuthUser -> Cmd msg


{-| Clear auth from localStorage (on logout).
-}
port clearAuth : () -> Cmd msg


{-| Receive restored auth from localStorage on app init (subscription variant).
-}
port onAuthRestored : (AuthUser -> msg) -> Sub msg

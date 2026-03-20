module Types exposing
    ( AuthResponse
    , AuthState(..)
    , AuthUser
    , Flags
    , Lang(..)
    , Model
    , Msg(..)
    , OtpResponse
    , Page(..)
    )

{-| Core types for the competition platform application.
-}

import Http


{-| Supported display languages.
-}
type Lang
    = Fi
    | En


{-| An authenticated user with PocketBase auth token and profile.
-}
type alias AuthUser =
    { id : String
    , email : String
    , token : String
    , displayName : String
    , isReviewer : Bool
    }


{-| Response from the first OTP step (email request).
-}
type alias OtpResponse =
    { otpId : String }


{-| Response from the second OTP step (code submission).
-}
type alias AuthResponse =
    { token : String
    , record : AuthUser
    }


{-| Authentication state machine.
-}
type AuthState
    = LoggedOut
    | AwaitingOtp { email : String, otpId : String }
    | LoggedIn AuthUser


{-| All pages in the application.
-}
type Page
    = LoginPage
    | SetDisplayNamePage
    | DashboardPage
    | MyEntriesPage
    | SubmitEntryPage (Maybe String)
    | ReviewQueuePage
    | NotFoundPage


{-| Flags passed from index.html on init.
-}
type alias Flags =
    { pbUrl : String
    , restoredAuth : Maybe AuthUser
    }


{-| The application model.
-}
type alias Model =
    { auth : AuthState
    , pbUrl : String
    , emailInput : String
    , otpInput : String
    , authError : Maybe String
    , displayNameInput : String
    , page : Page
    , lang : Lang
    }


{-| All messages in the Elm Architecture update loop.
-}
type Msg
    = EmailChanged String
    | OtpCodeChanged String
    | RequestOtp
    | OtpRequested (Result Http.Error OtpResponse)
    | SubmitOtp
    | OtpSubmitted (Result Http.Error AuthResponse)
    | LogOut
    | DisplayNameChanged String
    | SaveDisplayName
    | DisplayNameSaved (Result Http.Error AuthUser)
    | NavigateTo Page

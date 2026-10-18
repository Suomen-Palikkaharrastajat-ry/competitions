module AuthTest exposing (suite)

{-| Tests for auth state transitions and validation.

Given a model in a particular auth state
When an auth-related Msg is processed via update
Then the model transitions correctly

Given email / OTP code strings
When validateEmail / validateOtpCode is called
Then Ok or Err is returned according to the validation rules

-}

import Dict
import Expect
import Http
import Lang exposing (Lang(..))
import Main exposing (requestOtpUrl, update, validateEmail, validateOtpCode)
import RemoteData
import Test exposing (Test, describe, test)
import TestSite
import Time
import Types exposing (..)


emptyForm : SubmitForm
emptyForm =
    { entryId = Nothing
    , title = ""
    , description = ""
    , selectedFiles = []
    , existingImages = []
    , imagesToRemove = []
    , isCompressing = False
    , step = FillingForm
    , draftSaved = False
    , previews = Dict.empty
    }


baseModel : Model
baseModel =
    { auth = LoggedOut
    , pbUrl = "http://localhost:8090"
    , emailInput = ""
    , otpInput = ""
    , authError = Nothing
    , displayNameInput = ""
    , page = LoginPage
    , lang = Fi
    , site = TestSite.site Fi
    , menuOpen = False
    , now = Time.millisToPosix 0
    , competitions = RemoteData.NotAsked
    , myEntries = RemoteData.NotAsked
    , submitForm = emptyForm
    , selectedCompetition = Nothing
    , reviewQueue = RemoteData.NotAsked
    , activeReview = Nothing
    , reviewFilter = AllEntries
    , adminCompetitions = RemoteData.NotAsked
    , adminForm = Nothing
    , adminFormErrors = []
    , adminEntries = RemoteData.NotAsked
    , criteria = TestSite.criteria Fi
    }


testUser : AuthUser
testUser =
    { id = "user1"
    , authCollection = "local_users"
    , profileId = "profile1"
    , email = "user@example.fi"
    , token = "eyJtoken"
    , displayName = "Pekka"
    , isReviewer = False
    }


suite : Test
suite =
    describe "Auth"
        [ describe "Restored session check (#3)"
            -- Given a session restored from localStorage
            -- When PocketBase answers the token refresh
            -- Then an invalid token signs out and a valid one is renewed
            [ test "a rejected token signs out" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (SessionRefreshed (Err (Http.BadStatus 401))) { baseModel | auth = LoggedIn testUser, page = MyEntriesPage }
                    in
                    ( model.auth, model.page ) |> Expect.equal ( LoggedOut, LoginPage )
            , test "a network error keeps the session" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (SessionRefreshed (Err Http.NetworkError)) { baseModel | auth = LoggedIn testUser }
                    in
                    model.auth |> Expect.equal (LoggedIn testUser)
            , test "a refreshed token replaces the stored one" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (SessionRefreshed (Ok { token = "fresh", record = testUser })) { baseModel | auth = LoggedIn testUser }
                    in
                    case model.auth of
                        LoggedIn user ->
                            user.token |> Expect.equal "fresh"

                        _ ->
                            Expect.fail "Expected LoggedIn"
            ]
        , describe "validateEmail"
            [ test "valid email returns Ok" <|
                \_ ->
                    validateEmail Fi "user@example.fi"
                        |> Expect.equal (Ok "user@example.fi")
            , test "missing @ returns Err" <|
                \_ ->
                    case validateEmail Fi "notanemail" of
                        Err _ ->
                            Expect.pass

                        Ok _ ->
                            Expect.fail "Should have returned Err"
            , test "missing dot returns Err" <|
                \_ ->
                    case validateEmail Fi "no@dot" of
                        Err _ ->
                            Expect.pass

                        Ok _ ->
                            Expect.fail "Should have returned Err"
            , test "empty string returns Err" <|
                \_ ->
                    case validateEmail Fi "" of
                        Err _ ->
                            Expect.pass

                        Ok _ ->
                            Expect.fail "Should have returned Err"
            ]
        , describe "validateOtpCode"
            [ test "6-digit code returns Ok" <|
                \_ ->
                    validateOtpCode Fi "123456"
                        |> Expect.equal (Ok "123456")
            , test "5-digit code returns Err" <|
                \_ ->
                    case validateOtpCode Fi "12345" of
                        Err _ ->
                            Expect.pass

                        Ok _ ->
                            Expect.fail "Should have returned Err"
            , test "7-digit code returns Err" <|
                \_ ->
                    case validateOtpCode Fi "1234567" of
                        Err _ ->
                            Expect.pass

                        Ok _ ->
                            Expect.fail "Should have returned Err"
            , test "non-numeric 6 chars returns Err" <|
                \_ ->
                    case validateOtpCode Fi "abc123" of
                        Err _ ->
                            Expect.pass

                        Ok _ ->
                            Expect.fail "Should have returned Err"
            , test "empty string returns Err" <|
                \_ ->
                    case validateOtpCode Fi "" of
                        Err _ ->
                            Expect.pass

                        Ok _ ->
                            Expect.fail "Should have returned Err"
            ]
        , describe "EmailChanged"
            [ test "updates emailInput" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (EmailChanged "user@example.fi") baseModel
                    in
                    model.emailInput |> Expect.equal "user@example.fi"
            , test "clears authError" <|
                \_ ->
                    let
                        modelWithError =
                            { baseModel | authError = Just "some error" }

                        ( model, _ ) =
                            update (EmailChanged "x@x.fi") modelWithError
                    in
                    model.authError |> Expect.equal Nothing
            ]
        , describe "OtpCodeChanged"
            [ test "updates otpInput" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (OtpCodeChanged "123456") baseModel
                    in
                    model.otpInput |> Expect.equal "123456"
            ]
        , describe "RequestOtp"
            [ test "invalid email sets authError" <|
                \_ ->
                    let
                        model =
                            { baseModel | emailInput = "notanemail" }

                        ( updated, _ ) =
                            update RequestOtp model
                    in
                    case updated.authError of
                        Just _ ->
                            Expect.pass

                        Nothing ->
                            Expect.fail "Should have set authError"
            , test "valid email keeps auth as LoggedOut while waiting" <|
                \_ ->
                    let
                        model =
                            { baseModel | emailInput = "user@example.fi" }

                        ( updated, _ ) =
                            update RequestOtp model
                    in
                    updated.auth |> Expect.equal LoggedOut
            , test "uses PocketBase request-otp endpoint for the first OTP step" <|
                \_ ->
                    -- Given the app needs to request a fresh OTP email
                    -- When building the request URL
                    -- Then it uses the local_users OTP request endpoint, not the Keycloak auth collection
                    requestOtpUrl "http://localhost:8090"
                        |> Expect.equal "http://localhost:8090/api/collections/local_users/request-otp"
            ]
        , describe "OtpRequested"
            [ test "Ok transitions auth to AwaitingOtp" <|
                \_ ->
                    let
                        model =
                            { baseModel | emailInput = "user@example.fi" }

                        ( updated, _ ) =
                            update (OtpRequested (Ok { otpId = "otp123" })) model
                    in
                    case updated.auth of
                        AwaitingOtp state ->
                            Expect.all
                                [ \_ -> Expect.equal "user@example.fi" state.email
                                , \_ -> Expect.equal "otp123" state.otpId
                                ]
                                ()

                        _ ->
                            Expect.fail "Expected AwaitingOtp state"
            , test "Err sets authError" <|
                \_ ->
                    let
                        ( updated, _ ) =
                            update (OtpRequested (Err Http.NetworkError)) baseModel
                    in
                    case updated.authError of
                        Just _ ->
                            Expect.pass

                        Nothing ->
                            Expect.fail "Should have set authError"
            ]
        , describe "OtpSubmitted"
            [ test "Ok transitions auth to LoggedIn" <|
                \_ ->
                    let
                        awaitingModel =
                            { baseModel
                                | auth = AwaitingOtp { email = "user@example.fi", otpId = "otp123" }
                            }

                        resp =
                            { token = "eyJtoken"
                            , record = testUser
                            }

                        ( updated, _ ) =
                            update (OtpSubmitted (Ok resp)) awaitingModel
                    in
                    case updated.auth of
                        LoggedIn user ->
                            Expect.equal testUser.id user.id

                        _ ->
                            Expect.fail "Expected LoggedIn state"
            , test "Ok with empty displayName goes to SetDisplayNamePage" <|
                \_ ->
                    let
                        awaitingModel =
                            { baseModel
                                | auth = AwaitingOtp { email = "user@example.fi", otpId = "otp123" }
                            }

                        userNoName =
                            { testUser | displayName = "" }

                        resp =
                            { token = "eyJtoken", record = userNoName }

                        ( updated, _ ) =
                            update (OtpSubmitted (Ok resp)) awaitingModel
                    in
                    updated.page |> Expect.equal SetDisplayNamePage
            , test "Ok with displayName goes to DashboardPage" <|
                \_ ->
                    let
                        awaitingModel =
                            { baseModel
                                | auth = AwaitingOtp { email = "user@example.fi", otpId = "otp123" }
                            }

                        resp =
                            { token = "eyJtoken", record = testUser }

                        ( updated, _ ) =
                            update (OtpSubmitted (Ok resp)) awaitingModel
                    in
                    updated.page |> Expect.equal DashboardPage
            , test "Err BadStatus 400 sets Finnish error message" <|
                \_ ->
                    let
                        awaitingModel =
                            { baseModel
                                | auth = AwaitingOtp { email = "user@example.fi", otpId = "otp123" }
                            }

                        ( updated, _ ) =
                            update (OtpSubmitted (Err (Http.BadStatus 400))) awaitingModel
                    in
                    case updated.authError of
                        Just msg ->
                            Expect.equal "Väärä koodi tai vanhentunut linkki" msg

                        Nothing ->
                            Expect.fail "Should have set authError"
            , test "Err BadStatus 400 keeps AwaitingOtp so user can retry" <|
                \_ ->
                    let
                        awaitingModel =
                            { baseModel
                                | auth = AwaitingOtp { email = "user@example.fi", otpId = "otp123" }
                            }

                        ( updated, _ ) =
                            update (OtpSubmitted (Err (Http.BadStatus 400))) awaitingModel
                    in
                    case updated.auth of
                        AwaitingOtp _ ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected AwaitingOtp to be preserved"
            ]
        , describe "LogOut"
            [ test "transitions auth to LoggedOut" <|
                \_ ->
                    let
                        loggedInModel =
                            { baseModel | auth = LoggedIn testUser }

                        ( updated, _ ) =
                            update LogOut loggedInModel
                    in
                    updated.auth |> Expect.equal LoggedOut
            , test "navigates to LoginPage" <|
                \_ ->
                    let
                        loggedInModel =
                            { baseModel | auth = LoggedIn testUser, page = DashboardPage }

                        ( updated, _ ) =
                            update LogOut loggedInModel
                    in
                    updated.page |> Expect.equal LoginPage
            ]
        , describe "401 auto-logout"
            [ test "CompetitionsLoaded 401 clears auth and goes to LoginPage" <|
                \_ ->
                    let
                        loggedInModel =
                            { baseModel | auth = LoggedIn testUser }

                        ( updated, _ ) =
                            update (CompetitionsLoaded (Err (Http.BadStatus 401))) loggedInModel
                    in
                    Expect.all
                        [ \m -> m.auth |> Expect.equal LoggedOut
                        , \m -> m.page |> Expect.equal LoginPage
                        ]
                        updated
            , test "MyEntriesLoaded 401 clears auth and goes to LoginPage" <|
                \_ ->
                    let
                        loggedInModel =
                            { baseModel | auth = LoggedIn testUser }

                        ( updated, _ ) =
                            update (MyEntriesLoaded (Err (Http.BadStatus 401))) loggedInModel
                    in
                    updated.auth |> Expect.equal LoggedOut
            , test "ReviewQueueLoaded 401 clears auth and goes to LoginPage" <|
                \_ ->
                    let
                        loggedInModel =
                            { baseModel | auth = LoggedIn testUser }

                        ( updated, _ ) =
                            update (ReviewQueueLoaded (Err (Http.BadStatus 401))) loggedInModel
                    in
                    updated.auth |> Expect.equal LoggedOut
            ]
        , describe "DisplayNameChanged"
            [ test "updates displayNameInput" <|
                \_ ->
                    let
                        ( model, _ ) =
                            update (DisplayNameChanged "Pekka") baseModel
                    in
                    model.displayNameInput |> Expect.equal "Pekka"
            ]
        , describe "DisplayNameSaved"
            [ test "Ok transitions to DashboardPage" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | auth = LoggedIn { testUser | displayName = "" }
                                , page = SetDisplayNamePage
                            }

                        ( updated, _ ) =
                            update (DisplayNameSaved (Ok "Pekka")) model
                    in
                    updated.page |> Expect.equal DashboardPage
            , test "Ok updates the displayName in auth" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | auth = LoggedIn { testUser | displayName = "" }
                                , page = SetDisplayNamePage
                            }

                        ( updated, _ ) =
                            update (DisplayNameSaved (Ok "Pekka")) model
                    in
                    case updated.auth of
                        LoggedIn user ->
                            user.displayName |> Expect.equal "Pekka"

                        _ ->
                            Expect.fail "Expected LoggedIn"
            , test "Err sets authError" <|
                \_ ->
                    let
                        model =
                            { baseModel
                                | auth = LoggedIn { testUser | displayName = "" }
                                , page = SetDisplayNamePage
                            }

                        ( updated, _ ) =
                            update (DisplayNameSaved (Err Http.NetworkError)) model
                    in
                    case updated.authError of
                        Just _ ->
                            Expect.pass

                        Nothing ->
                            Expect.fail "Should have set authError"
            ]
        ]

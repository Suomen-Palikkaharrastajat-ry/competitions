module MainTest exposing (suite)

{-| Verifies the competition platform Elm app compiles and core types are present.
-}

import Expect
import I18n
import Lang exposing (Lang(..))
import Test exposing (Test, describe, test)
import Types exposing (AuthState(..), AuthUser)


testUser : AuthUser
testUser =
    { id = "u1"
    , authCollection = "local_users"
    , profileId = "profile1"
    , email = "u@example.fi"
    , token = "tok"
    , displayName = "Matti"
    , isReviewer = False
    }


suite : Test
suite =
    describe "Competition platform types"
        [ test "AuthState LoggedOut" <|
            \_ ->
                Expect.equal LoggedOut LoggedOut
        , test "AuthState LoggedIn" <|
            \_ ->
                Expect.equal (LoggedIn testUser) (LoggedIn testUser)
        , test "Lang Fi" <|
            \_ ->
                Expect.equal Fi Fi
        , test "Lang En" <|
            \_ ->
                Expect.equal En En
        , test "I18n Competition Fi" <|
            \_ ->
                Expect.equal "Kilpailu" (I18n.translate Fi I18n.Competition)
        , test "I18n keeps the Finnish validation text" <|
            \_ ->
                Expect.equal "Syötä kelvollinen sähköpostiosoite" (I18n.t Fi I18n.ErrInvalidEmail)
        , test "I18n has an English validation text" <|
            \_ ->
                Expect.equal "Enter a valid email address" (I18n.t En I18n.ErrInvalidEmail)
        , test "I18n Competition En" <|
            \_ ->
                Expect.equal "Competition" (I18n.translate En I18n.Competition)
        ]

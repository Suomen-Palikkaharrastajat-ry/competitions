module MainTest exposing (suite)

{-| Stub test suite — verifies the competition platform Elm app compiles
and core types are present.
-}

import Expect
import Test exposing (Test, describe, test)
import Types exposing (AuthState(..), Lang(..))
import I18n


suite : Test
suite =
    describe "Competition platform stub"
        [ test "AuthState LoggedOut" <|
            \_ ->
                Expect.equal LoggedOut LoggedOut
        , test "AuthState LoggedIn" <|
            \_ ->
                Expect.equal (LoggedIn "token") (LoggedIn "token")
        , test "Lang Fi" <|
            \_ ->
                Expect.equal Fi Fi
        , test "Lang En" <|
            \_ ->
                Expect.equal En En
        , test "I18n Competition Fi" <|
            \_ ->
                Expect.equal "Kilpailu" (I18n.translate Fi I18n.Competition)
        , test "I18n Competition En" <|
            \_ ->
                Expect.equal "Competition" (I18n.translate En I18n.Competition)
        ]

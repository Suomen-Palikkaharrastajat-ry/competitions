module I18n exposing (MsgKey(..), translate)

{-| Internationalization for the competition platform
-}

import Lang exposing (Lang(..))


{-| Translation keys
-}
type MsgKey
    = SkipToContent
    | Competition
    | Participants
    | Review
    | LogIn
    | LogOut
    | Submit
    | OrgName


{-| Translate a key to the given language
-}
translate : Lang -> MsgKey -> String
translate lang key =
    case lang of
        Fi ->
            case key of
                SkipToContent ->
                    "Siirry pääsisältöön"

                Competition ->
                    "Kilpailu"

                Participants ->
                    "Osallistujat"

                Review ->
                    "Arvostelu"

                LogIn ->
                    "Kirjaudu sisään"

                LogOut ->
                    "Kirjaudu ulos"

                Submit ->
                    "Lähetä"

                OrgName ->
                    "Suomen Palikkaharrastajat ry"

        En ->
            case key of
                SkipToContent ->
                    "Skip to main content"

                Competition ->
                    "Competition"

                Participants ->
                    "Participants"

                Review ->
                    "Review"

                LogIn ->
                    "Log in"

                LogOut ->
                    "Log out"

                Submit ->
                    "Submit"

                OrgName ->
                    "Suomen Palikkaharrastajat ry"

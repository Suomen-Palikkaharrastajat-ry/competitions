module View.Layout exposing (view)

{-| Page chrome: the shared family shell with this app's navigation and account
controls.
-}

import Component.Account as Account
import Component.Layout as Layout
import Html exposing (Html, div, nav)
import Html.Attributes exposing (attribute, class)
import I18n exposing (t)
import Lang exposing (Lang)
import Route
import Types exposing (AuthState(..), AuthUser, Model, Msg(..), Page(..))
import UiStrings


{-| The whole page: `main` is the app's `<main id="main-content">`.
-}
view : { model : Model, main : Html Msg } -> List (Html Msg)
view config =
    let
        model =
            config.model

        strings =
            UiStrings.forLang model.lang

        account =
            { strings = strings
            , user =
                case model.auth of
                    LoggedIn user ->
                        Just { name = user.displayName, email = user.email }

                    _ ->
                        Nothing
            , onSignIn = StartKeycloakLogin
            , onSignOut = LogOut
            }

        link page label =
            { label = label
            , href = Route.toHash page
            , mobileOnly = False
            , isActive =
                if page == AdminPage then
                    Route.isAdminPage model.page

                else
                    model.page == page
            }
    in
    Layout.view
        { site = model.site
        , strings = strings
        , attributes = [ class "min-h-screen flex flex-col bg-bg-subtle" ]
        , home = { href = Route.toHash DashboardPage, onClick = Nothing }
        , links =
            case model.auth of
                LoggedIn user ->
                    links model.lang link user

                _ ->
                    []
        , headerActions = [ Account.viewHeader account ]
        , showHeader = True
        , menu =
            Just
                { isOpen = model.menuOpen
                , onToggle = ToggleMenu
                , onClose = CloseMenu
                , content =
                    \navLinks ->
                        [ nav [ class "p-4", attribute "aria-label" strings.mainNav ] [ navLinks ]
                        , div [ class "p-4 border-t border-border-default" ]
                            [ Account.viewDrawer account ]
                        ]
                }
        , main = config.main
        , aboveFooter = []
        , footer = Just { topMargin = False, extra = [] }
        , scrollToTop = Nothing
        , toasts = Nothing
        , overlays = []
        }


links :
    Lang
    -> (Page -> String -> { label : String, href : String, mobileOnly : Bool, isActive : Bool })
    -> AuthUser
    -> List { label : String, href : String, mobileOnly : Bool, isActive : Bool }
links lang link user =
    [ link DashboardPage (t lang I18n.NavCompetitions)
    , link MyEntriesPage (t lang I18n.MyEntries)
    ]
        ++ (if user.isReviewer then
                [ link ReviewQueuePage (t lang I18n.NavReview)
                , link AdminPage (t lang I18n.NavAdmin)
                ]

            else
                []
           )

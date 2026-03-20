module Main exposing
    ( authResponseDecoder
    , canSubmitMore
    , competitionDecoder
    , entryDecoder
    , isDeadlinePassed
    , main
    , otpResponseDecoder
    , update
    , validateEmail
    , validateForm
    , validateOtpCode
    )

{-| Entry point for the Palikkakilpailu competition platform application.
-}

import Browser
import Html exposing (Html)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Ports
import RemoteData
import Time
import Types exposing (..)
import View


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


emptyForm : SubmitForm
emptyForm =
    { entryId = Nothing
    , title = ""
    , description = ""
    , selectedFiles = []
    , existingImages = []
    , imagesToRemove = []
    , step = FillingForm
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        ( auth, page ) =
            case flags.restoredAuth of
                Just user ->
                    ( LoggedIn user
                    , if String.isEmpty user.displayName then
                        SetDisplayNamePage

                      else
                        DashboardPage
                    )

                Nothing ->
                    ( LoggedOut, LoginPage )

        fetchCmd =
            case ( flags.restoredAuth, page ) of
                ( Just user, DashboardPage ) ->
                    fetchCompetitions flags.pbUrl user.token

                _ ->
                    Cmd.none

        competitionsState =
            case page of
                DashboardPage ->
                    RemoteData.Loading

                _ ->
                    RemoteData.NotAsked
    in
    ( { auth = auth
      , pbUrl = flags.pbUrl
      , emailInput = ""
      , otpInput = ""
      , authError = Nothing
      , displayNameInput = ""
      , page = page
      , lang = Fi
      , competitions = competitionsState
      , myEntries = RemoteData.NotAsked
      , submitForm = emptyForm
      , selectedCompetition = Nothing
      }
    , fetchCmd
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- Auth
        EmailChanged email ->
            ( { model | emailInput = email, authError = Nothing }, Cmd.none )

        OtpCodeChanged code ->
            ( { model | otpInput = code, authError = Nothing }, Cmd.none )

        RequestOtp ->
            case validateEmail model.emailInput of
                Err e ->
                    ( { model | authError = Just e }, Cmd.none )

                Ok email ->
                    ( model, requestOtp model.pbUrl email )

        OtpRequested (Ok resp) ->
            ( { model | auth = AwaitingOtp { email = model.emailInput, otpId = resp.otpId } }
            , Cmd.none
            )

        OtpRequested (Err _) ->
            ( { model | authError = Just "Sähköpostin lähetys epäonnistui" }, Cmd.none )

        SubmitOtp ->
            case model.auth of
                AwaitingOtp state ->
                    case validateOtpCode model.otpInput of
                        Err e ->
                            ( { model | authError = Just e }, Cmd.none )

                        Ok code ->
                            ( model, submitOtp model.pbUrl state.otpId code )

                _ ->
                    ( model, Cmd.none )

        OtpSubmitted (Ok resp) ->
            let
                rec =
                    resp.record

                user =
                    { rec | token = resp.token }

                page =
                    if String.isEmpty user.displayName then
                        SetDisplayNamePage

                    else
                        DashboardPage
            in
            ( { model
                | auth = LoggedIn user
                , page = page
                , authError = Nothing
                , competitions = RemoteData.Loading
              }
            , Cmd.batch
                [ Ports.storeAuth user
                , if page == DashboardPage then
                    fetchCompetitions model.pbUrl user.token

                  else
                    Cmd.none
                ]
            )

        OtpSubmitted (Err (Http.BadStatus 400)) ->
            ( { model | authError = Just "Väärä koodi tai vanhentunut linkki" }, Cmd.none )

        OtpSubmitted (Err _) ->
            ( { model | authError = Just "Kirjautuminen epäonnistui" }, Cmd.none )

        LogOut ->
            ( { model
                | auth = LoggedOut
                , page = LoginPage
                , emailInput = ""
                , otpInput = ""
                , authError = Nothing
                , competitions = RemoteData.NotAsked
                , myEntries = RemoteData.NotAsked
              }
            , Ports.clearAuth ()
            )

        DisplayNameChanged name ->
            ( { model | displayNameInput = name }, Cmd.none )

        SaveDisplayName ->
            case model.auth of
                LoggedIn user ->
                    ( model, saveDisplayName model.pbUrl user.id user.token model.displayNameInput )

                _ ->
                    ( model, Cmd.none )

        DisplayNameSaved (Ok updatedUser) ->
            ( { model
                | auth = LoggedIn updatedUser
                , page = DashboardPage
                , competitions = RemoteData.Loading
              }
            , Cmd.batch
                [ Ports.storeAuth updatedUser
                , fetchCompetitions model.pbUrl updatedUser.token
                ]
            )

        DisplayNameSaved (Err _) ->
            ( { model | authError = Just "Näyttönimen tallennus epäonnistui" }, Cmd.none )

        -- Navigation
        NavigateTo page ->
            case ( page, model.auth ) of
                ( DashboardPage, LoggedIn user ) ->
                    ( { model | page = page, competitions = RemoteData.Loading }
                    , fetchCompetitions model.pbUrl user.token
                    )

                ( MyEntriesPage, LoggedIn user ) ->
                    ( { model | page = page, myEntries = RemoteData.Loading }
                    , fetchMyEntries model.pbUrl user.token user.id
                    )

                _ ->
                    ( { model | page = page }, Cmd.none )

        -- Competitions
        CompetitionsLoaded (Ok comps) ->
            ( { model | competitions = RemoteData.Success comps }, Cmd.none )

        CompetitionsLoaded (Err err) ->
            ( { model | competitions = RemoteData.Failure err }, Cmd.none )

        SelectCompetition comp ->
            ( { model
                | selectedCompetition = Just comp
                , page = SubmitEntryPage (Just comp.id)
                , submitForm = emptyForm
              }
            , Cmd.none
            )

        -- Entry form
        EntryTitleChanged title ->
            let
                form =
                    model.submitForm
            in
            ( { model | submitForm = { form | title = title } }, Cmd.none )

        EntryDescriptionChanged desc ->
            let
                form =
                    model.submitForm
            in
            ( { model | submitForm = { form | description = desc } }, Cmd.none )

        FilesSelected first rest ->
            let
                form =
                    model.submitForm

                newFiles =
                    form.selectedFiles ++ (first :: rest)
            in
            ( { model | submitForm = { form | selectedFiles = newFiles } }, Cmd.none )

        RemoveExistingImage filename ->
            let
                form =
                    model.submitForm

                updated =
                    { form
                        | existingImages = List.filter (\f -> f /= filename) form.existingImages
                        , imagesToRemove = form.imagesToRemove ++ [ filename ]
                    }
            in
            ( { model | submitForm = updated }, Cmd.none )

        SaveDraft ->
            case model.auth of
                LoggedIn user ->
                    let
                        form =
                            model.submitForm

                        updatedForm =
                            { form | step = Uploading }
                    in
                    case ( form.entryId, model.selectedCompetition ) of
                        ( Nothing, Just comp ) ->
                            ( { model | submitForm = updatedForm }
                            , createDraft model.pbUrl user comp form
                            )

                        ( Just entryId, _ ) ->
                            ( { model | submitForm = updatedForm }
                            , updateDraft model.pbUrl user entryId form
                            )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        DraftSaved (Ok entry) ->
            let
                form =
                    model.submitForm
            in
            ( { model
                | submitForm =
                    { form
                        | step = FillingForm
                        , entryId = Just entry.id
                        , existingImages = entry.images
                        , selectedFiles = []
                        , imagesToRemove = []
                    }
              }
            , Cmd.none
            )

        DraftSaved (Err _) ->
            let
                form =
                    model.submitForm
            in
            ( { model | submitForm = { form | step = UploadError "Luonnoksen tallennus epäonnistui" } }
            , Cmd.none
            )

        SubmitEntry ->
            case ( model.auth, model.submitForm.entryId ) of
                ( LoggedIn user, Just entryId ) ->
                    case validateForm model.submitForm of
                        Err e ->
                            ( { model | authError = Just e }, Cmd.none )

                        Ok _ ->
                            ( model, submitEntryCmd model.pbUrl user.token entryId )

                _ ->
                    ( model, Cmd.none )

        EntrySubmitted (Ok _) ->
            let
                form =
                    model.submitForm
            in
            ( { model | submitForm = { form | step = SubmitSuccess } }, Cmd.none )

        EntrySubmitted (Err _) ->
            let
                form =
                    model.submitForm
            in
            ( { model | submitForm = { form | step = UploadError "Lähettäminen epäonnistui" } }
            , Cmd.none
            )

        -- My entries
        MyEntriesLoaded (Ok entries) ->
            ( { model | myEntries = RemoteData.Success entries }, Cmd.none )

        MyEntriesLoaded (Err err) ->
            ( { model | myEntries = RemoteData.Failure err }, Cmd.none )

        EditDraft entryId ->
            ( { model | page = SubmitEntryPage (Just entryId) }, Cmd.none )

        CancelEdit ->
            ( { model | page = MyEntriesPage, submitForm = emptyForm }, Cmd.none )


view : Model -> Html Msg
view model =
    View.view model


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------


validateEmail : String -> Result String String
validateEmail email =
    case String.split "@" email of
        [ before, after ] ->
            if String.length before > 0 && String.contains "." after && String.length after > 1 then
                Ok email

            else
                Err "Syötä kelvollinen sähköpostiosoite"

        _ ->
            Err "Syötä kelvollinen sähköpostiosoite"


validateOtpCode : String -> Result String String
validateOtpCode code =
    if String.length code == 6 && String.all Char.isDigit code then
        Ok code

    else
        Err "Koodi koostuu kuudesta numerosta"


validateForm : SubmitForm -> Result String SubmitForm
validateForm form =
    if String.isEmpty form.title then
        Err "Nimi on pakollinen"

    else if String.length form.title > 200 then
        Err "Nimi on liian pitkä (max 200 merkkiä)"

    else if List.isEmpty form.selectedFiles && List.isEmpty form.existingImages then
        Err "Lisää vähintään yksi kuva"

    else if List.length form.selectedFiles + List.length form.existingImages > 10 then
        Err "Enintään 10 kuvaa sallittu"

    else
        Ok form


canSubmitMore : Competition -> List Entry -> Bool
canSubmitMore competition entries =
    let
        myCount =
            List.length (List.filter (\e -> e.competitionId == competition.id) entries)

        limit =
            Maybe.withDefault 3 competition.maxEntriesPerUser
    in
    limit == 0 || myCount < limit


isDeadlinePassed : String -> Time.Posix -> Bool
isDeadlinePassed endDate now =
    case parseDateToMillis endDate of
        Just deadlineMs ->
            Time.posixToMillis now >= deadlineMs

        Nothing ->
            False


parseDateToMillis : String -> Maybe Int
parseDateToMillis s =
    let
        datePart =
            String.left 10 s
    in
    case List.filterMap String.toInt (String.split "-" datePart) of
        [ y, m, d ] ->
            Just (calendarToMillis y m d)

        _ ->
            Nothing


calendarToMillis : Int -> Int -> Int -> Int
calendarToMillis year month day =
    let
        isLeap y =
            (modBy 4 y == 0 && modBy 100 y /= 0) || modBy 400 y == 0

        daysPerYear y =
            if isLeap y then
                366

            else
                365

        yearDays =
            List.range 1970 (year - 1)
                |> List.map daysPerYear
                |> List.sum

        daysPerMonth y m =
            case m of
                1 ->
                    31

                2 ->
                    if isLeap y then
                        29

                    else
                        28

                3 ->
                    31

                4 ->
                    30

                5 ->
                    31

                6 ->
                    30

                7 ->
                    31

                8 ->
                    31

                9 ->
                    30

                10 ->
                    31

                11 ->
                    30

                _ ->
                    31

        monthDays =
            List.range 1 (month - 1)
                |> List.map (daysPerMonth year)
                |> List.sum
    in
    (yearDays + monthDays + day - 1) * 86400000



-- ---------------------------------------------------------------------------
-- HTTP commands
-- ---------------------------------------------------------------------------


requestOtp : String -> String -> Cmd Msg
requestOtp pbUrl email =
    Http.post
        { url = pbUrl ++ "/api/collections/users/auth-with-otp"
        , body =
            Http.jsonBody
                (Encode.object [ ( "email", Encode.string email ) ])
        , expect = Http.expectJson OtpRequested otpResponseDecoder
        }


submitOtp : String -> String -> String -> Cmd Msg
submitOtp pbUrl otpId code =
    Http.post
        { url = pbUrl ++ "/api/collections/users/auth-with-otp"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "otpId", Encode.string otpId )
                    , ( "password", Encode.string code )
                    ]
                )
        , expect = Http.expectJson OtpSubmitted authResponseDecoder
        }


saveDisplayName : String -> String -> String -> String -> Cmd Msg
saveDisplayName pbUrl userId token displayName =
    Http.request
        { method = "PATCH"
        , headers = [ Http.header "Authorization" token ]
        , url = pbUrl ++ "/api/collections/users/records/" ++ userId
        , body =
            Http.jsonBody
                (Encode.object [ ( "display_name", Encode.string displayName ) ])
        , expect = Http.expectJson DisplayNameSaved authUserDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


fetchCompetitions : String -> String -> Cmd Msg
fetchCompetitions pbUrl token =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" token ]
        , url =
            pbUrl
                ++ "/api/collections/competitions/records"
                ++ "?filter=status%3D%22open%22&sort=end_date"
                ++ "&fields=id%2Ctitle%2Cslug%2Ctheme%2Cdescription%2Cend_date%2Ccover_image%2Cmax_entries_per_user"
        , body = Http.emptyBody
        , expect = Http.expectJson CompetitionsLoaded (pbListDecoder competitionDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }


fetchMyEntries : String -> String -> String -> Cmd Msg
fetchMyEntries pbUrl token userId =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" token ]
        , url =
            pbUrl
                ++ "/api/collections/entries/records"
                ++ "?filter=submitter%3D%22"
                ++ userId
                ++ "%22&sort=-created"
        , body = Http.emptyBody
        , expect = Http.expectJson MyEntriesLoaded (pbListDecoder entryDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }


createDraft : String -> AuthUser -> Competition -> SubmitForm -> Cmd Msg
createDraft pbUrl user comp form =
    Http.request
        { method = "POST"
        , headers = [ Http.header "Authorization" user.token ]
        , url = pbUrl ++ "/api/collections/entries/records"
        , body =
            Http.multipartBody
                ([ Http.stringPart "competition" comp.id
                 , Http.stringPart "submitter" user.id
                 , Http.stringPart "title" form.title
                 , Http.stringPart "description" form.description
                 , Http.stringPart "status" "draft"
                 ]
                    ++ List.map (Http.filePart "images") form.selectedFiles
                )
        , expect = Http.expectJson DraftSaved entryDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


updateDraft : String -> AuthUser -> String -> SubmitForm -> Cmd Msg
updateDraft pbUrl user entryId form =
    Http.request
        { method = "PATCH"
        , headers = [ Http.header "Authorization" user.token ]
        , url = pbUrl ++ "/api/collections/entries/records/" ++ entryId
        , body =
            Http.multipartBody
                ([ Http.stringPart "title" form.title
                 , Http.stringPart "description" form.description
                 ]
                    ++ List.map (Http.filePart "images+") form.selectedFiles
                    ++ (if List.isEmpty form.imagesToRemove then
                            []

                        else
                            [ Http.stringPart "images-"
                                (Encode.encode 0
                                    (Encode.list Encode.string form.imagesToRemove)
                                )
                            ]
                       )
                )
        , expect = Http.expectJson DraftSaved entryDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


submitEntryCmd : String -> String -> String -> Cmd Msg
submitEntryCmd pbUrl token entryId =
    Http.request
        { method = "PATCH"
        , headers = [ Http.header "Authorization" token ]
        , url = pbUrl ++ "/api/collections/entries/records/" ++ entryId
        , body =
            Http.jsonBody
                (Encode.object [ ( "status", Encode.string "submitted" ) ])
        , expect = Http.expectJson EntrySubmitted entryDecoder
        , timeout = Nothing
        , tracker = Nothing
        }



-- ---------------------------------------------------------------------------
-- Decoders
-- ---------------------------------------------------------------------------


otpResponseDecoder : Decode.Decoder OtpResponse
otpResponseDecoder =
    Decode.map OtpResponse
        (Decode.field "otpId" Decode.string)


authUserDecoder : Decode.Decoder AuthUser
authUserDecoder =
    Decode.map5 AuthUser
        (Decode.field "id" Decode.string)
        (Decode.field "email" Decode.string)
        (Decode.succeed "")
        (Decode.maybe (Decode.field "display_name" Decode.string)
            |> Decode.map (Maybe.withDefault "")
        )
        (Decode.maybe (Decode.field "is_reviewer" Decode.bool)
            |> Decode.map (Maybe.withDefault False)
        )


authResponseDecoder : Decode.Decoder AuthResponse
authResponseDecoder =
    Decode.field "token" Decode.string
        |> Decode.andThen
            (\token ->
                Decode.field "record"
                    (Decode.map4
                        (\id email displayName isReviewer ->
                            { token = token
                            , record =
                                AuthUser id email token displayName isReviewer
                            }
                        )
                        (Decode.field "id" Decode.string)
                        (Decode.field "email" Decode.string)
                        (Decode.maybe (Decode.field "display_name" Decode.string)
                            |> Decode.map (Maybe.withDefault "")
                        )
                        (Decode.maybe (Decode.field "is_reviewer" Decode.bool)
                            |> Decode.map (Maybe.withDefault False)
                        )
                    )
            )


competitionDecoder : Decode.Decoder Competition
competitionDecoder =
    Decode.map8 Competition
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "slug" Decode.string)
        (Decode.maybe (Decode.field "theme" Decode.string))
        (Decode.maybe (Decode.field "description" Decode.string))
        (Decode.field "end_date" Decode.string)
        (Decode.maybe (Decode.field "cover_image" Decode.string)
            |> Decode.map
                (Maybe.andThen
                    (\s ->
                        if String.isEmpty s then
                            Nothing

                        else
                            Just s
                    )
                )
        )
        (Decode.maybe (Decode.field "max_entries_per_user" Decode.int))


entryStatusDecoder : Decode.Decoder EntryStatus
entryStatusDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "draft" ->
                        Decode.succeed Draft

                    "submitted" ->
                        Decode.succeed Submitted

                    "approved" ->
                        Decode.succeed Approved

                    "rejected" ->
                        Decode.succeed Rejected

                    _ ->
                        Decode.fail ("Unknown entry status: " ++ s)
            )


entryDecoder : Decode.Decoder Entry
entryDecoder =
    Decode.map6 Entry
        (Decode.field "id" Decode.string)
        (Decode.field "competition" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.maybe (Decode.field "description" Decode.string))
        (Decode.field "images" (Decode.list Decode.string))
        (Decode.field "status" entryStatusDecoder)


pbListDecoder : Decode.Decoder a -> Decode.Decoder (List a)
pbListDecoder itemDecoder =
    Decode.field "items" (Decode.list itemDecoder)



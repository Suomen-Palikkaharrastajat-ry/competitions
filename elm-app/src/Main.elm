module Main exposing
    ( HashEffect(..)
    , authResponseDecoder
    , canSubmitMore
    , competitionDecoder
    , emptyReview
    , entryDecoder
    , filteredReviewQueue
    , handleHttpError
    , hashEffect
    , httpErrorMessage
    , imageMax
    , imageMin
    , init
    , main
    , myEntriesUrl
    , otpResponseDecoder
    , requestOtpUrl
    , reviewQueueUrl
    , reviewableEntryDecoder
    , update
    , validateEmail
    , validateForm
    , validateOtpCode
    , votingCompetitionsUrl
    )

{-| Entry point for the Palikkakilpailu competition platform application.
-}

import Admin
import Browser
import Browser.Events
import Component.Layout as Layout
import Criteria exposing (Criterion)
import Dict
import File
import Html exposing (Html)
import Http
import I18n exposing (t)
import Json.Decode as Decode
import Json.Encode as Encode
import Lang exposing (Lang)
import Ports
import RemoteData
import Route
import Scoring
import SiteSettings
import Task
import Time
import Types exposing (..)
import Url
import View
import Voting


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
    , isCompressing = False
    , step = FillingForm
    , draftSaved = False
    , previews = Dict.empty
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        settings =
            SiteSettings.fromFlags flags.requestedLang flags.siteConfig

        criteriaResult =
            Decode.decodeValue (SiteSettings.appDecoder settings.lang Criteria.decoder) flags.siteConfig

        configError =
            case ( settings.error, criteriaResult ) of
                ( Just problem, _ ) ->
                    Just problem

                ( Nothing, Err problem ) ->
                    Just ("The review criteria could not be read: " ++ Decode.errorToString problem)

                ( Nothing, Ok _ ) ->
                    Nothing

        ( auth, page ) =
            case flags.restoredAuth of
                Just user ->
                    ( LoggedIn user
                    , if String.isEmpty user.displayName then
                        SetDisplayNamePage

                      else
                        Route.fromHash flags.hash
                            |> Maybe.withDefault DashboardPage
                            |> allowedPage user
                    )

                Nothing ->
                    ( LoggedOut, LoginPage )

        ( model, pageCmd ) =
            enterPage page
                { auth = auth
                , pbUrl = flags.pbUrl
                , emailInput = ""
                , otpInput = ""
                , authError = Nothing
                , displayNameInput = ""
                , page = page
                , lang = settings.lang
                , site = settings.site
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
                , criteria = Result.withDefault [] criteriaResult
                , voting = Voting.init
                }

        -- A deep link the app does not keep (unknown, or not allowed for the
        -- user) is replaced by the address of the page shown, so that Back
        -- stays inside the app.
        hashCmd =
            if List.member flags.hash [ "", "#", Route.toHash model.page ] || model.auth == LoggedOut then
                Cmd.none

            else
                Ports.replaceHash (Route.toHash model.page)
    in
    ( model
    , Cmd.batch
        [ pageCmd
        , hashCmd
        , case flags.restoredAuth of
            Just user ->
                refreshSession flags.pbUrl user

            Nothing ->
                Cmd.none
        , case configError of
            Just problem ->
                Ports.reportError problem

            Nothing ->
                Cmd.none
        ]
    )


{-| The page itself, or the dashboard when the user may not see it.
-}
allowedPage : AuthUser -> Page -> Page
allowedPage user page =
    if (page == ReviewQueuePage || Route.isAdminPage page) && not user.isReviewer then
        DashboardPage

    else
        page


{-| Switch to a page and start loading the data it shows.
-}
enterPage : Page -> Model -> ( Model, Cmd Msg )
enterPage page_ model =
    let
        page =
            case model.auth of
                LoggedIn user ->
                    allowedPage user page_

                _ ->
                    page_
    in
    case ( page, model.auth ) of
        ( DashboardPage, LoggedIn user ) ->
            -- The user's own entries tell which competitions are full.
            let
                voting =
                    model.voting
            in
            ( { model
                | page = page
                , competitions = RemoteData.Loading
                , myEntries = RemoteData.Loading
                , voting = { voting | openCompetitions = RemoteData.Loading }
              }
            , Cmd.batch
                [ fetchCompetitions model.pbUrl user.token
                , fetchMyEntries model.pbUrl user.token user.profileId
                , fetchVotingCompetitions model.pbUrl user.token
                ]
            )

        ( VotePage competitionId, LoggedIn user ) ->
            -- The ballot starts empty until the voter's stored one is loaded.
            let
                voting =
                    model.voting
            in
            ( { model
                | page = page
                , voting =
                    { voting
                        | competition = RemoteData.Loading
                        , candidates = RemoteData.Loading
                        , ballot = Voting.emptyBallot competitionId user.profileId
                        , ballotLoaded = False
                        , saving = False
                        , saved = False
                        , error = Nothing
                    }
              }
            , Cmd.batch
                [ fetchVoteCompetition model.pbUrl user.token competitionId
                , fetchVoteCandidates model.pbUrl user.token competitionId
                , fetchMyBallot model.pbUrl user.token competitionId user.profileId
                ]
            )

        ( MyEntriesPage, LoggedIn user ) ->
            ( { model | page = page, myEntries = RemoteData.Loading }
            , fetchMyEntries model.pbUrl user.token user.profileId
            )

        ( ParticipationPage _, LoggedIn user ) ->
            ( { model | page = page, myEntries = RemoteData.Loading }
            , fetchMyEntries model.pbUrl user.token user.profileId
            )

        ( AdminPage, LoggedIn user ) ->
            ( { model | page = page, adminCompetitions = RemoteData.Loading }
            , fetchAdminCompetitions model.pbUrl user.token
            )

        ( AdminEntriesPage competitionId, LoggedIn user ) ->
            let
                voting =
                    model.voting
            in
            ( { model
                | page = page
                , adminEntries = RemoteData.Loading
                , voting = { voting | adminBallots = RemoteData.Loading }
              }
            , Cmd.batch
                [ fetchAdminEntries model.pbUrl user.token competitionId
                , fetchAdminCompetitions model.pbUrl user.token
                , fetchAdminBallots model.pbUrl user.token competitionId
                ]
            )

        ( AdminCompetitionPage Nothing, LoggedIn _ ) ->
            ( { model | page = page, adminForm = Just Admin.emptyCompetitionForm, adminFormErrors = [] }
            , Cmd.none
            )

        ( AdminCompetitionPage (Just _), LoggedIn user ) ->
            ( { model | page = page, adminForm = Nothing, adminFormErrors = [], adminCompetitions = RemoteData.Loading }
            , fetchAdminCompetitions model.pbUrl user.token
            )

        ( ReviewQueuePage, LoggedIn user ) ->
            ( { model | page = page, reviewQueue = RemoteData.Loading }
            , fetchReviewQueue model.pbUrl user.token user.profileId
            )

        _ ->
            ( { model | page = page }, Cmd.none )


{-| What to do to the browser's hash after a page change.
-}
type HashEffect
    = KeepHash
    | PushHash String
    | ReplaceHash String


{-| The reason a submitted entry's changes cannot be saved, if any: a
submitted entry must still pass the form's checks (for example its image count).
-}
submittedEditError : Model -> Maybe String
submittedEditError model =
    case Scoring.findEntry model.submitForm.entryId (RemoteData.withDefault [] model.myEntries) of
        Just entry ->
            case ( entry.status == Submitted, model.selectedCompetition ) of
                ( True, Just competition ) ->
                    case validateForm model.lang competition model.submitForm of
                        Err err ->
                            Just err

                        Ok _ ->
                            Nothing

                _ ->
                    Nothing

        Nothing ->
            Nothing


{-| True when the entry being edited can no longer be changed, because a
submitted entry's competition deadline has passed.
-}
editingLocked : Model -> Bool
editingLocked model =
    case Scoring.findEntry model.submitForm.entryId (RemoteData.withDefault [] model.myEntries) of
        Just entry ->
            not (Scoring.canEditEntry model.now entry)

        Nothing ->
            False


{-| Decide how to keep the hash in step with the page. `incoming` is the hash
the browser reported when the change follows `HashChanged`; it must never
push a history entry, only correct a non-canonical hash in place.
-}
hashEffect : Page -> Page -> Maybe String -> HashEffect
hashEffect oldPage newPage incoming =
    if newPage == oldPage then
        KeepHash

    else
        case incoming of
            Nothing ->
                PushHash (Route.toHash newPage)

            Just hash ->
                if hash == Route.toHash newPage then
                    KeepHash

                else
                    ReplaceHash (Route.toHash newPage)


{-| Read a selected image into a data URL, for its preview in the form.
-}
previewCmd : File.File -> Cmd Msg
previewCmd file =
    Task.perform (PreviewReady (View.fileKey file)) (File.toUrl file)


{-| Run `updateModel` and keep the browser's hash in step with the page.
-}
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        ( newModel, cmd ) =
            updateModel msg model

        incoming =
            case msg of
                HashChanged hash ->
                    Just hash

                _ ->
                    Nothing
    in
    case hashEffect model.page newModel.page incoming of
        KeepHash ->
            ( newModel, cmd )

        PushHash hash ->
            ( newModel, Cmd.batch [ cmd, Ports.setHash hash ] )

        ReplaceHash hash ->
            ( newModel, Cmd.batch [ cmd, Ports.replaceHash hash ] )


updateModel : Msg -> Model -> ( Model, Cmd Msg )
updateModel msg model =
    if model.submitForm.isCompressing && savesTheEntry msg then
        -- The selected images are still being compressed.
        ( model, Cmd.none )

    else
        updateModelWith msg model


{-| Messages that save or submit the entry form.
-}
savesTheEntry : Msg -> Bool
savesTheEntry msg =
    case msg of
        SaveDraft ->
            True

        SubmitEntry ->
            True

        ConfirmSubmit ->
            True

        _ ->
            False


updateModelWith : Msg -> Model -> ( Model, Cmd Msg )
updateModelWith msg model =
    case msg of
        -- Auth
        EmailChanged email ->
            ( { model | emailInput = email, authError = Nothing }, Cmd.none )

        OtpCodeChanged code ->
            ( { model | otpInput = code, authError = Nothing }, Cmd.none )

        RequestOtp ->
            case validateEmail model.lang model.emailInput of
                Err e ->
                    ( { model | authError = Just e }, Cmd.none )

                Ok email ->
                    ( model, requestOtp model.pbUrl email )

        OtpRequested (Ok resp) ->
            ( { model | auth = AwaitingOtp { email = model.emailInput, otpId = resp.otpId } }
            , Cmd.none
            )

        OtpRequested (Err (Http.BadStatus 409)) ->
            ( { model | authError = Just (t model.lang I18n.ErrKeycloakOnly) }, Cmd.none )

        OtpRequested (Err _) ->
            ( { model | authError = Just (t model.lang I18n.ErrEmailSendFailed) }, Cmd.none )

        SubmitOtp ->
            case model.auth of
                AwaitingOtp state ->
                    case validateOtpCode model.lang model.otpInput of
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
            signedIn user page model

        OtpSubmitted (Err (Http.BadStatus 400)) ->
            ( { model | authError = Just (t model.lang I18n.ErrWrongCode) }, Cmd.none )

        OtpSubmitted (Err (Http.BadStatus 409)) ->
            ( { model | authError = Just (t model.lang I18n.ErrKeycloakOnly) }, Cmd.none )

        OtpSubmitted (Err _) ->
            ( { model | authError = Just (t model.lang I18n.ErrLoginFailed) }, Cmd.none )

        StartKeycloakLogin ->
            ( { model | authError = Nothing, menuOpen = False }
            , Cmd.batch
                [ Ports.startKeycloakLogin model.pbUrl
                , if model.menuOpen then
                    Layout.onMenuClosed NoOp

                  else
                    Cmd.none
                ]
            )

        KeycloakLoginCompleted resp ->
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
            signedIn user page model

        KeycloakLoginFailed _ ->
            ( { model | authError = Just (t model.lang I18n.ErrKeycloakLoginFailed) }, Cmd.none )

        LogOut ->
            ( { model
                | auth = LoggedOut
                , page = LoginPage
                , emailInput = ""
                , otpInput = ""
                , authError = Nothing
                , competitions = RemoteData.NotAsked
                , myEntries = RemoteData.NotAsked
                , menuOpen = False
                , voting = Voting.init
              }
            , Cmd.batch
                [ Ports.clearAuth ()
                , if model.menuOpen then
                    Layout.onMenuClosed NoOp

                  else
                    Cmd.none
                ]
            )

        SessionRefreshed (Ok resp) ->
            case model.auth of
                LoggedIn user ->
                    let
                        refreshed =
                            { user
                                | token = resp.token
                                , displayName = resp.record.displayName
                                , isReviewer = resp.record.isReviewer
                            }
                    in
                    ( { model | auth = LoggedIn refreshed }, Ports.storeAuth refreshed )

                _ ->
                    ( model, Cmd.none )

        SessionRefreshed (Err err) ->
            -- An invalid or expired stored token: PocketBase would answer
            -- other requests as a guest, so sign out instead of looking
            -- signed in. A network error keeps the session.
            case err of
                Http.BadStatus status ->
                    if List.member status [ 401, 403, 404 ] then
                        ( { model
                            | auth = LoggedOut
                            , page = LoginPage
                            , authError = Just (t model.lang I18n.HttpSessionExpired)
                            , competitions = RemoteData.NotAsked
                            , myEntries = RemoteData.NotAsked
                          }
                        , Ports.clearAuth ()
                        )

                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        DisplayNameChanged name ->
            ( { model | displayNameInput = name }, Cmd.none )

        SaveDisplayName ->
            case model.auth of
                LoggedIn user ->
                    ( model, saveDisplayName model.pbUrl user.profileId user.token model.displayNameInput )

                _ ->
                    ( model, Cmd.none )

        DisplayNameSaved (Ok displayName) ->
            case model.auth of
                LoggedIn user ->
                    let
                        updatedUser =
                            { user | displayName = displayName }
                    in
                    signedIn updatedUser DashboardPage model

                _ ->
                    ( model, Cmd.none )

        DisplayNameSaved (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
                    ( { model | authError = Just (t model.lang I18n.ErrDisplayNameSave) }, Cmd.none )

        -- Navigation
        NavigateTo page ->
            enterPage page model

        HashChanged hash ->
            -- The hash of the page shown is ours (the display-name page
            -- shares the dashboard's), and the display-name step cannot be
            -- skipped by navigating.
            if Route.toHash model.page == hash || model.page == SetDisplayNamePage || model.auth == LoggedOut then
                ( model, Cmd.none )

            else
                case Route.fromHash hash of
                    Just page ->
                        if page == model.page then
                            ( model, Cmd.none )

                        else
                            let
                                ( newModel, cmd ) =
                                    enterPage page model
                            in
                            if newModel.page == model.page then
                                -- Redirected back to where we are: `update` sees
                                -- no page change, so correct the hash here.
                                ( newModel, Cmd.batch [ cmd, Ports.replaceHash (Route.toHash newModel.page) ] )

                            else
                                ( newModel, cmd )

                    Nothing ->
                        ( model, Cmd.none )

        ToggleMenu ->
            if model.menuOpen then
                ( { model | menuOpen = False }, Layout.onMenuClosed NoOp )

            else
                ( { model | menuOpen = True }, Layout.onMenuOpened NoOp )

        CloseMenu ->
            if model.menuOpen then
                ( { model | menuOpen = False }, Layout.onMenuClosed NoOp )

            else
                ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )

        -- Competitions
        CompetitionsLoaded (Ok comps) ->
            ( { model | competitions = RemoteData.Success comps }, Cmd.none )

        CompetitionsLoaded (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
                    ( { model | competitions = RemoteData.Failure err }, Cmd.none )

        SelectCompetition comp ->
            ( { model
                | selectedCompetition = Just comp
                , page = SubmitEntryPage Nothing
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
            ( { model | submitForm = { form | title = title, draftSaved = False } }, Cmd.none )

        EntryDescriptionChanged desc ->
            let
                form =
                    model.submitForm
            in
            ( { model | submitForm = { form | description = desc, draftSaved = False } }, Cmd.none )

        RawFilesSelected filesValue ->
            let
                form =
                    model.submitForm

                maxImages =
                    model.selectedCompetition
                        |> Maybe.map imageMax
                        |> Maybe.withDefault 10

                remainingSlots =
                    max 0 (maxImages - List.length form.existingImages - List.length form.selectedFiles)

                selectedCount =
                    Decode.decodeValue (Decode.field "length" Decode.int) filesValue
                        |> Result.withDefault 1
            in
            if remainingSlots <= 0 then
                ( { model
                    | authError =
                        Just
                            (t model.lang I18n.AtMostPrefix
                                ++ String.fromInt maxImages
                                ++ t model.lang I18n.AtMostSuffix
                            )
                  }
                , Cmd.none
                )

            else
                let
                    excessFeedback =
                        if selectedCount > remainingSlots then
                            Just (t model.lang I18n.ErrExcessImagesDropped)

                        else
                            Nothing
                in
                ( { model
                    | submitForm = { form | isCompressing = True, step = FillingForm }
                    , authError = excessFeedback
                  }
                , Ports.compressImages
                    (Encode.object
                        [ ( "files", filesValue )
                        , ( "maxDimension", Encode.int 1920 )
                        , ( "quality", Encode.float 0.82 )
                        , ( "remainingSlots", Encode.int remainingSlots )
                        ]
                    )
                )

        ImagesCompressed jsonValue ->
            let
                form =
                    model.submitForm

                maxImages =
                    model.selectedCompetition
                        |> Maybe.map imageMax
                        |> Maybe.withDefault 10

                remainingSlots =
                    max 0 (maxImages - List.length form.existingImages - List.length form.selectedFiles)
            in
            case Decode.decodeValue (Decode.list File.decoder) jsonValue of
                Ok decodedFiles ->
                    let
                        added =
                            List.take remainingSlots decodedFiles
                    in
                    ( { model
                        | submitForm =
                            { form
                                | selectedFiles = form.selectedFiles ++ added
                                , isCompressing = False
                                , draftSaved = False
                            }
                      }
                    , Cmd.batch (List.map previewCmd added)
                    )

                Err _ ->
                    ( { model
                        | submitForm =
                            { form
                                | isCompressing = False
                                , step = UploadError (t model.lang I18n.ErrImageCompressionGeneric)
                            }
                      }
                    , Cmd.none
                    )

        CompressionFailed err ->
            let
                form =
                    model.submitForm
            in
            ( { model
                | submitForm =
                    { form
                        | isCompressing = False
                        , step = UploadError (t model.lang I18n.ErrImageCompression ++ err)
                    }
              }
            , Cmd.none
            )

        PreviewReady key url ->
            let
                form =
                    model.submitForm
            in
            ( { model | submitForm = { form | previews = Dict.insert key url form.previews } }, Cmd.none )

        RemoveSelectedFile index ->
            let
                form =
                    model.submitForm

                remaining =
                    form.selectedFiles
                        |> List.indexedMap Tuple.pair
                        |> List.filter (\( i, _ ) -> i /= index)
                        |> List.map Tuple.second

                -- Keep only the previews of files still selected.
                previews =
                    Dict.filter (\key _ -> List.any (\file -> View.fileKey file == key) remaining) form.previews

                updated =
                    { form
                        | selectedFiles = remaining
                        , previews = previews
                        , draftSaved = False
                    }
            in
            ( { model | submitForm = updated }, Cmd.none )

        RemoveExistingImage filename ->
            let
                form =
                    model.submitForm

                updated =
                    { form
                        | existingImages = List.filter (\f -> f /= filename) form.existingImages
                        , imagesToRemove = form.imagesToRemove ++ [ filename ]
                        , draftSaved = False
                    }
            in
            ( { model | submitForm = updated }, Cmd.none )

        SaveDraft ->
            case ( editingLocked model, submittedEditError model, model.auth ) of
                ( True, _, _ ) ->
                    ( { model | authError = Just (t model.lang I18n.ErrEditClosed) }, Cmd.none )

                ( False, Just err, _ ) ->
                    ( { model | authError = Just err }, Cmd.none )

                ( False, Nothing, LoggedIn user ) ->
                    let
                        form =
                            model.submitForm

                        updatedForm =
                            { form | step = Uploading }
                    in
                    case ( form.entryId, model.selectedCompetition ) of
                        ( Nothing, Just comp ) ->
                            ( { model | submitForm = updatedForm }
                            , createEntry model.pbUrl user comp form "draft" DraftSaved
                            )

                        ( Just entryId, _ ) ->
                            ( { model | submitForm = updatedForm }
                            , updateEntry model.pbUrl user entryId form Nothing DraftSaved
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
                        , draftSaved = True
                    }
              }
            , Cmd.none
            )

        DraftSaved (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
                    let
                        form =
                            model.submitForm
                    in
                    ( { model | submitForm = { form | step = UploadError (t model.lang I18n.ErrDraftSave) } }
                    , Cmd.none
                    )

        SubmitEntry ->
            -- Validate, then ask for confirmation: a submitted entry can no
            -- longer be edited.
            case ( model.auth, model.selectedCompetition ) of
                ( LoggedIn _, Just competition ) ->
                    case validateForm model.lang competition model.submitForm of
                        Err e ->
                            ( { model | authError = Just e }, Cmd.none )

                        Ok _ ->
                            let
                                form =
                                    model.submitForm
                            in
                            ( { model | authError = Nothing, submitForm = { form | step = ConfirmingSubmit } }, Cmd.none )

                ( LoggedIn _, Nothing ) ->
                    ( { model | authError = Just (t model.lang I18n.ErrNoCompetitionSelected) }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ConfirmSubmit ->
            -- Save the form as it is now and submit it in one request, so
            -- a new entry needs no draft first and unsaved changes (images
            -- added after the last draft save) are not lost.
            case ( model.auth, model.selectedCompetition ) of
                ( LoggedIn user, Just competition ) ->
                    let
                        form =
                            model.submitForm
                    in
                    ( { model | submitForm = { form | step = Uploading } }
                    , case form.entryId of
                        Nothing ->
                            createEntry model.pbUrl user competition form "submitted" EntrySubmitted

                        Just entryId ->
                            updateEntry model.pbUrl user entryId form (Just "submitted") EntrySubmitted
                    )

                _ ->
                    ( model, Cmd.none )

        CancelSubmit ->
            let
                form =
                    model.submitForm
            in
            ( { model | submitForm = { form | step = FillingForm } }, Cmd.none )

        EscapePressed ->
            -- Escape closes the open modal: the submit confirmation first,
            -- then the review form. Other keys never reach here.
            if model.submitForm.step == ConfirmingSubmit then
                update CancelSubmit model

            else if model.activeReview /= Nothing then
                update CloseReviewForm model

            else
                ( model, Cmd.none )

        EntrySubmitted (Ok _) ->
            let
                form =
                    model.submitForm
            in
            ( { model | submitForm = { form | step = SubmitSuccess } }, Cmd.none )

        EntrySubmitted (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
                    let
                        form =
                            model.submitForm
                    in
                    ( { model | submitForm = { form | step = UploadError (t model.lang I18n.ErrSubmitFailed) } }
                    , Cmd.none
                    )

        -- My entries
        MyEntriesLoaded (Ok entries) ->
            ( { model | myEntries = RemoteData.Success entries }, Cmd.none )

        MyEntriesLoaded (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
                    ( { model | myEntries = RemoteData.Failure err }, Cmd.none )

        EditEntry entryId ->
            case model.myEntries of
                RemoteData.Success entries ->
                    case List.filter (\entry -> entry.id == entryId) entries |> List.head of
                        Just entry ->
                            if not (Scoring.canEditEntry model.now entry) then
                                ( { model | authError = Just (t model.lang I18n.ErrEditClosed) }, Cmd.none )

                            else
                                case entry.competition of
                                    Just competition ->
                                        ( { model
                                            | page = SubmitEntryPage (Just entryId)
                                            , selectedCompetition = Just competition
                                            , authError = Nothing
                                            , submitForm =
                                                { emptyForm
                                                    | entryId = Just entry.id
                                                    , title = entry.title
                                                    , description = Maybe.withDefault "" entry.description
                                                    , existingImages = entry.images
                                                }
                                          }
                                        , Cmd.none
                                        )

                                    Nothing ->
                                        ( { model
                                            | selectedCompetition = Nothing
                                            , authError = Just (t model.lang I18n.ErrCompetitionLoad)
                                          }
                                        , Cmd.none
                                        )

                        Nothing ->
                            ( { model | authError = Just (t model.lang I18n.ErrDraftNotFound) }, Cmd.none )

                _ ->
                    ( { model | authError = Just (t model.lang I18n.ErrDraftNotFound) }, Cmd.none )

        CancelEdit ->
            case model.submitForm.entryId of
                Just entryId ->
                    enterPage (ParticipationPage entryId) { model | submitForm = emptyForm }

                Nothing ->
                    ( { model | page = MyEntriesPage, submitForm = emptyForm }, Cmd.none )

        -- Review queue
        AdminCompetitionsLoaded (Ok competitions) ->
            let
                -- Opening a competition's page fills its form from the list, once:
                -- a later load must not overwrite what the admin is typing.
                form =
                    case ( model.page, model.adminForm ) of
                        ( AdminCompetitionPage (Just competitionId), Nothing ) ->
                            competitions
                                |> List.filter (\competition -> competition.id == competitionId)
                                |> List.head
                                |> Maybe.map Admin.formFromCompetition

                        _ ->
                            model.adminForm
            in
            ( { model | adminCompetitions = RemoteData.Success competitions, adminForm = form }, Cmd.none )

        AdminCompetitionsLoaded (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
                    ( { model | adminCompetitions = RemoteData.Failure err }, Cmd.none )

        AdminEntriesLoaded (Ok entries) ->
            ( { model | adminEntries = RemoteData.Success entries }, Cmd.none )

        AdminEntriesLoaded (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
                    ( { model | adminEntries = RemoteData.Failure err }, Cmd.none )

        AdminFieldChanged field value ->
            ( { model | adminForm = Maybe.map (Admin.updateField field value) model.adminForm }, Cmd.none )

        AdminFlagChanged flag value ->
            ( { model | adminForm = Maybe.map (Admin.updateFlag flag value) model.adminForm }, Cmd.none )

        SaveCompetition ->
            case ( model.adminForm, model.auth ) of
                ( Just form, LoggedIn user ) ->
                    case Admin.validateCompetitionForm form of
                        [] ->
                            let
                                target =
                                    adminCompetitionTarget model
                            in
                            ( { model | adminFormErrors = [] }
                            , saveCompetitionCmd model.pbUrl user.token target (Maybe.andThen (adminCompetitionById model) target) form
                            )

                        errors ->
                            ( { model | adminFormErrors = errors }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        CompetitionStatusSaved (Ok competition) ->
            -- A status change stays on the page: the rest of the form is kept.
            ( { model
                | adminForm = Maybe.map (\form -> { form | status = competition.status }) model.adminForm
                , adminCompetitions =
                    RemoteData.map
                        (List.map
                            (\c ->
                                if c.id == competition.id then
                                    competition

                                else
                                    c
                            )
                        )
                        model.adminCompetitions
              }
            , Cmd.none
            )

        CompetitionStatusSaved (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
                    ( { model | adminFormErrors = [ ServerRejected ] }, Cmd.none )

        SetCompetitionStatus status ->
            case ( adminCompetitionTarget model, model.auth ) of
                ( Just competitionId, LoggedIn user ) ->
                    ( model, setCompetitionStatusCmd model.pbUrl user.token competitionId status )

                _ ->
                    ( model, Cmd.none )

        CompetitionSaved (Ok _) ->
            case model.auth of
                LoggedIn user ->
                    ( { model | page = AdminPage, adminForm = Nothing, adminFormErrors = [], adminCompetitions = RemoteData.Loading }
                    , fetchAdminCompetitions model.pbUrl user.token
                    )

                _ ->
                    ( model, Cmd.none )

        CompetitionSaved (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
                    ( { model | adminFormErrors = [ ServerRejected ] }, Cmd.none )

        ReviewQueueLoaded (Ok entries) ->
            ( { model | reviewQueue = RemoteData.Success entries }, Cmd.none )

        ReviewQueueLoaded (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
                    ( { model | reviewQueue = RemoteData.Failure err }, Cmd.none )

        ReviewFilterChanged filter ->
            ( { model | reviewFilter = filter }, Cmd.none )

        OpenReviewForm reviewableEntry ->
            let
                draft =
                    case reviewableEntry.myReview of
                        Just existing ->
                            { existing | scores = Dict.union existing.scores (defaultScores model.criteria) }

                        Nothing ->
                            case model.auth of
                                LoggedIn user ->
                                    emptyReview model.criteria reviewableEntry.entry.id user.profileId

                                _ ->
                                    emptyReview model.criteria reviewableEntry.entry.id ""
            in
            ( { model
                | activeReview =
                    Just
                        { reviewableEntry = reviewableEntry
                        , draftReview = draft
                        , saving = False
                        , saveError = Nothing
                        }
              }
            , Cmd.none
            )

        CloseReviewForm ->
            ( { model | activeReview = Nothing }, Cmd.none )

        -- Scoring
        ScoreChanged criterionId n ->
            updateDraftScore (\r -> { r | scores = Dict.insert criterionId n r.scores }) model

        ReviewCommentChanged comment ->
            updateDraftScore (\r -> { r | comment = comment }) model

        -- Review actions
        SaveReview ->
            saveReview False model

        SaveAndPublishReview ->
            saveReview True model

        ReviewSaved (Ok review) ->
            let
                updateQueueEntry re =
                    if re.entry.id == review.entryId then
                        { re | myReview = Just review }

                    else
                        re

                updatedQueue =
                    RemoteData.map (List.map updateQueueEntry) model.reviewQueue
            in
            case model.activeReview of
                Just rf ->
                    ( { model
                        | activeReview =
                            Just
                                { rf
                                    | saving = False
                                    , draftReview = review
                                    , saveError = Nothing
                                }
                        , reviewQueue = updatedQueue
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( { model | reviewQueue = updatedQueue }, Cmd.none )

        ReviewSaved (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
                    case model.activeReview of
                        Just rf ->
                            ( { model
                                | activeReview =
                                    Just
                                        { rf
                                            | saving = False
                                            , saveError = Just (t model.lang I18n.ErrReviewSave)
                                        }
                              }
                            , Cmd.none
                            )

                        Nothing ->
                            ( model, Cmd.none )

        ApproveEntry entryId ->
            case model.auth of
                LoggedIn user ->
                    ( model, changeEntryStatus model.pbUrl user.token entryId "approved" Approved )

                _ ->
                    ( model, Cmd.none )

        RejectEntry entryId ->
            case model.auth of
                LoggedIn user ->
                    ( model, changeEntryStatus model.pbUrl user.token entryId "rejected" Rejected )

                _ ->
                    ( model, Cmd.none )

        ResetEntry entryId ->
            case model.auth of
                LoggedIn user ->
                    ( model, changeEntryStatus model.pbUrl user.token entryId "submitted" Submitted )

                _ ->
                    ( model, Cmd.none )

        EntryStatusChanged entryId newStatus (Ok ()) ->
            let
                setStatus re =
                    if re.entry.id == entryId then
                        let
                            e =
                                re.entry
                        in
                        { re | entry = { e | status = newStatus } }

                    else
                        re
            in
            ( { model
                | reviewQueue = RemoteData.map (List.map setStatus) model.reviewQueue
                , adminEntries = RemoteData.map (List.map setStatus) model.adminEntries
              }
            , Cmd.none
            )

        EntryStatusChanged _ _ (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
                    ( { model | authError = Just (t model.lang I18n.ErrStatusChange) }, Cmd.none )

        -- Voting
        VotingCompetitionsLoaded result ->
            updateVoting result (\loaded voting -> { voting | openCompetitions = loaded }) model

        VoteCompetitionLoaded competitionId result ->
            onVotePage competitionId model <|
                updateVoting result (\loaded voting -> { voting | competition = loaded }) model

        VoteCandidatesLoaded competitionId result ->
            onVotePage competitionId model <|
                updateVoting result (\loaded voting -> dropUnknownEntries { voting | candidates = loaded }) model

        MyBallotLoaded competitionId (Ok stored) ->
            let
                voting =
                    model.voting
            in
            onVotePage competitionId model <|
                ( { model
                    | voting =
                        dropUnknownEntries
                            { voting
                                | ballot = Maybe.withDefault voting.ballot stored
                                , ballotLoaded = True
                                , saved = stored /= Nothing
                            }
                  }
                , Cmd.none
                )

        MyBallotLoaded competitionId (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
                    let
                        voting =
                            model.voting
                    in
                    onVotePage competitionId model <|
                        ( { model | voting = { voting | error = Just (t model.lang I18n.ErrBallotLoad) } }, Cmd.none )

        PickEntry entryId ->
            changeRanking (Voting.pick entryId) model

        UnpickEntry entryId ->
            changeRanking (Voting.unpick entryId) model

        MoveEntryUp entryId ->
            changeRanking (Voting.moveUp entryId) model

        MoveEntryDown entryId ->
            changeRanking (Voting.moveDown entryId) model

        SaveBallot ->
            let
                voting =
                    model.voting
            in
            case model.auth of
                LoggedIn user ->
                    if not voting.ballotLoaded || voting.saving then
                        ( model, Cmd.none )

                    else if List.isEmpty voting.ballot.ranking then
                        ( { model | voting = { voting | error = Just (t model.lang I18n.ErrBallotEmpty) } }, Cmd.none )

                    else
                        ( { model | voting = { voting | saving = True, error = Nothing } }
                        , saveBallotCmd model.pbUrl user.token voting.ballot
                        )

                _ ->
                    ( model, Cmd.none )

        BallotSaved competitionId (Ok saved) ->
            let
                voting =
                    model.voting
            in
            onVotePage competitionId model <|
                ( { model | voting = { voting | ballot = saved, saving = False, saved = True, error = Nothing } }, Cmd.none )

        BallotSaved competitionId (Err failure) ->
            case failure.error of
                Http.BadStatus 401 ->
                    handleHttpError failure.error model

                _ ->
                    let
                        voting =
                            model.voting

                        -- The hook says why it refused the ballot.
                        message =
                            case ( failure.error, failure.message ) of
                                ( Http.BadStatus 400, Just reason ) ->
                                    reason

                                ( Http.BadStatus 400, Nothing ) ->
                                    t model.lang I18n.ErrBallotRejected

                                _ ->
                                    t model.lang I18n.ErrBallotSave
                    in
                    onVotePage competitionId model <|
                        ( { model | voting = { voting | saving = False, error = Just message } }, Cmd.none )

        AdminBallotsLoaded competitionId result ->
            if model.page == AdminEntriesPage competitionId then
                updateVoting result (\loaded voting -> { voting | adminBallots = loaded }) model

            else
                ( model, Cmd.none )

        Tick time ->
            ( { model | now = time }, Cmd.none )


view : Model -> Html Msg
view model =
    View.view model


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every 60000 Tick
        , Ports.hashChanged HashChanged
        , Layout.subscriptions { isOpen = model.menuOpen, onClose = CloseMenu }
        , modalSubscriptions model
        , Ports.keycloakLoginSucceeded KeycloakLoginCompleted
        , Ports.keycloakLoginFailed KeycloakLoginFailed
        , Ports.imagesCompressed ImagesCompressed
        , Ports.compressionFailed CompressionFailed
        ]


{-| Listens for Escape while a modal dialog is open. The mobile menu has its
own listener in `Layout.subscriptions`.
-}
modalSubscriptions : Model -> Sub Msg
modalSubscriptions model =
    if model.submitForm.step == ConfirmingSubmit || model.activeReview /= Nothing then
        Browser.Events.onKeyDown
            (Decode.field "key" Decode.string
                |> Decode.andThen
                    (\key ->
                        if key == "Escape" then
                            Decode.succeed EscapePressed

                        else
                            Decode.fail "not Escape"
                    )
            )

    else
        Sub.none



-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------


validateEmail : Lang -> String -> Result String String
validateEmail lang email =
    case String.split "@" email of
        [ before, after ] ->
            if String.length before > 0 && String.contains "." after && String.length after > 1 then
                Ok email

            else
                Err (t lang I18n.ErrInvalidEmail)

        _ ->
            Err (t lang I18n.ErrInvalidEmail)


validateOtpCode : Lang -> String -> Result String String
validateOtpCode lang code =
    if String.length code == 6 && String.all Char.isDigit code then
        Ok code

    else
        Err (t lang I18n.ErrOtpFormat)


imageMin : Competition -> Int
imageMin competition =
    competition.minImagesPerEntry
        |> Maybe.withDefault 1
        |> max 0


imageMax : Competition -> Int
imageMax competition =
    let
        configured =
            competition.maxImagesPerEntry
                |> Maybe.withDefault 10
                |> min 10
                |> max 0
    in
    max configured (imageMin competition)


validateForm : Lang -> Competition -> SubmitForm -> Result String SubmitForm
validateForm lang competition form =
    let
        count =
            List.length form.selectedFiles + List.length form.existingImages

        minImages =
            imageMin competition

        maxImages =
            imageMax competition
    in
    if String.isEmpty form.title then
        Err (t lang I18n.ErrNameRequired)

    else if String.length form.title > 200 then
        Err (t lang I18n.ErrNameTooLong)

    else if count < minImages then
        if minImages <= 1 then
            Err (t lang I18n.ErrAddOneImage)

        else
            Err (t lang I18n.AddAtLeastPrefix ++ String.fromInt minImages ++ t lang I18n.ImagesSuffix)

    else if count > maxImages then
        Err (t lang I18n.AtMostPrefix ++ String.fromInt maxImages ++ t lang I18n.AtMostSuffix)

    else
        Ok form


emptyReview : List Criterion -> String -> String -> Review
emptyReview criteria entryId reviewerId =
    { id = Nothing
    , entryId = entryId
    , reviewerId = reviewerId
    , scores = defaultScores criteria
    , comment = ""
    , isPublished = False
    }


{-| The starting score of each criterion: the middle of the 1–5 scale.
-}
defaultScores : List Criterion -> Dict.Dict String Int
defaultScores criteria =
    Dict.fromList (List.map (\criterion -> ( criterion.id, 3 )) criteria)


filteredReviewQueue : ReviewFilter -> List ReviewableEntry -> List ReviewableEntry
filteredReviewQueue filter entries =
    case filter of
        AllEntries ->
            entries

        NotYetReviewed ->
            List.filter (\re -> re.myReview == Nothing) entries

        ByCompetition compId ->
            List.filter (\re -> re.competition.id == compId) entries


updateDraftScore : (Review -> Review) -> Model -> ( Model, Cmd Msg )
updateDraftScore f model =
    case model.activeReview of
        Just rf ->
            ( { model | activeReview = Just { rf | draftReview = f rf.draftReview } }
            , Cmd.none
            )

        Nothing ->
            ( model, Cmd.none )


{-| Store a loaded part of the voting state; a 401 signs out.
-}
updateVoting : Result Http.Error a -> (RemoteData.RemoteData Http.Error a -> VotingModel -> VotingModel) -> Model -> ( Model, Cmd Msg )
updateVoting result store model =
    case result of
        Err (Http.BadStatus 401) ->
            handleHttpError (Http.BadStatus 401) model

        _ ->
            ( { model | voting = store (RemoteData.fromResult result) model.voting }, Cmd.none )


{-| Apply a response about a competition's vote page only while that page is
shown: a late answer about the previous page must not change this one.
-}
onVotePage : String -> Model -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
onVotePage competitionId model result =
    if model.page == VotePage competitionId then
        result

    else
        ( model, Cmd.none )


{-| Once both the stored ballot and the entries have loaded, take off the
ballot the entries that are no longer approved (ADR-0007): the server would
refuse the ballot with them, and the voter could not see them to remove them.
The ballot must then be saved again.
-}
dropUnknownEntries : VotingModel -> VotingModel
dropUnknownEntries voting =
    case ( voting.ballotLoaded, voting.candidates ) of
        ( True, RemoteData.Success candidates ) ->
            let
                ballot =
                    voting.ballot

                ids =
                    List.map .id candidates

                ranking =
                    List.filter (\entryId -> List.member entryId ids) ballot.ranking
            in
            if ranking == ballot.ranking then
                voting

            else
                { voting | ballot = { ballot | ranking = ranking }, saved = False }

        _ ->
            voting


{-| Change the ballot being made. Nothing changes while it loads or saves.
-}
changeRanking : (List String -> List String) -> Model -> ( Model, Cmd Msg )
changeRanking change model =
    let
        voting =
            model.voting

        ballot =
            voting.ballot
    in
    if not voting.ballotLoaded || voting.saving then
        ( model, Cmd.none )

    else
        let
            ranking =
                change ballot.ranking
        in
        if ranking == ballot.ranking then
            ( model, Cmd.none )

        else
            ( { model | voting = { voting | ballot = { ballot | ranking = ranking }, saved = False, error = Nothing } }
            , Cmd.none
            )



-- | Map an Http.Error to a user-facing message in the given language.


httpErrorMessage : Lang -> Http.Error -> String
httpErrorMessage lang err =
    case err of
        Http.NetworkError ->
            t lang I18n.HttpNetwork

        Http.BadStatus 401 ->
            t lang I18n.HttpSessionExpired

        Http.BadStatus 403 ->
            t lang I18n.HttpForbidden

        Http.BadStatus 404 ->
            t lang I18n.HttpNotFound

        _ ->
            t lang I18n.HttpUnexpected



-- | Handle a 401 response by logging out; otherwise leave model unchanged.


handleHttpError : Http.Error -> Model -> ( Model, Cmd Msg )
handleHttpError err model =
    case err of
        Http.BadStatus 401 ->
            ( { model | auth = LoggedOut, page = LoginPage }
            , Ports.clearAuth ()
            )

        _ ->
            ( model, Cmd.none )


canSubmitMore : Competition -> List Entry -> Bool
canSubmitMore =
    Scoring.canSubmitMore



-- ---------------------------------------------------------------------------
-- HTTP commands
-- ---------------------------------------------------------------------------


{-| Store a signed-in user and show `page` (loading its data).
-}
signedIn : AuthUser -> Page -> Model -> ( Model, Cmd Msg )
signedIn user page model =
    let
        ( newModel, cmd ) =
            enterPage page { model | auth = LoggedIn user, authError = Nothing }
    in
    ( newModel, Cmd.batch [ Ports.storeAuth user, cmd ] )


{-| Check a restored session with PocketBase and get a fresh token.
-}
refreshSession : String -> AuthUser -> Cmd Msg
refreshSession pbUrl user =
    Http.request
        { method = "POST"
        , headers = [ Http.header "Authorization" user.token ]
        , url = pbUrl ++ "/api/collections/" ++ user.authCollection ++ "/auth-refresh"
        , body = Http.emptyBody
        , expect = Http.expectJson SessionRefreshed authResponseDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


requestOtp : String -> String -> Cmd Msg
requestOtp pbUrl email =
    Http.post
        { url = requestOtpUrl pbUrl
        , body =
            Http.jsonBody
                (Encode.object [ ( "email", Encode.string email ) ])
        , expect = Http.expectJson OtpRequested otpResponseDecoder
        }


requestOtpUrl : String -> String
requestOtpUrl pbUrl =
    pbUrl ++ "/api/collections/local_users/request-otp"


submitOtp : String -> String -> String -> Cmd Msg
submitOtp pbUrl otpId code =
    Http.post
        { url = pbUrl ++ "/api/collections/local_users/auth-with-otp"
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
        , url = pbUrl ++ "/api/collections/profiles/records/" ++ userId
        , body =
            Http.jsonBody
                (Encode.object [ ( "display_name", Encode.string displayName ) ])
        , expect = Http.expectJson DisplayNameSaved (Decode.field "display_name" Decode.string)
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
                ++ "&fields=id%2Ctitle%2Cslug%2Ctheme%2Cdescription%2Cstart_date%2Cend_date%2Cjudging_end_date%2Cstatus%2Ccover_image%2Cmax_entries_per_user%2Cmin_images_per_entry%2Cmax_images_per_entry%2Cvoting_enabled%2Cvoting_required%2Cvoting_start_date%2Cvoting_end_date"
        , body = Http.emptyBody
        , expect = Http.expectJson CompetitionsLoaded (pbListDecoder competitionDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }


{-| The competitions whose voting period is running now, the one ending
first first. PocketBase decides what "now" is.
-}
fetchVotingCompetitions : String -> String -> Cmd Msg
fetchVotingCompetitions pbUrl token =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" token ]
        , url = votingCompetitionsUrl pbUrl
        , body = Http.emptyBody
        , expect = Http.expectJson VotingCompetitionsLoaded (pbListDecoder competitionDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }


votingCompetitionsUrl : String -> String
votingCompetitionsUrl pbUrl =
    pbUrl
        ++ "/api/collections/competitions/records?filter="
        ++ Url.percentEncode "voting_enabled = true && status != \"draft\" && voting_start_date != \"\" && voting_start_date <= @now && voting_end_date > @now"
        ++ "&sort=voting_end_date"


fetchVoteCompetition : String -> String -> String -> Cmd Msg
fetchVoteCompetition pbUrl token competitionId =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" token ]
        , url = pbUrl ++ "/api/collections/competitions/records/" ++ competitionId
        , body = Http.emptyBody
        , expect = Http.expectJson (VoteCompetitionLoaded competitionId) competitionDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


{-| The entries one can vote for: the approved entries of the competition.
-}
fetchVoteCandidates : String -> String -> String -> Cmd Msg
fetchVoteCandidates pbUrl token competitionId =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" token ]
        , url =
            pbUrl
                ++ "/api/collections/entries/records?filter="
                ++ Url.percentEncode ("competition = \"" ++ competitionId ++ "\" && status = \"approved\"")
                ++ "&sort=created&perPage=200"
        , body = Http.emptyBody
        , expect = Http.expectJson (VoteCandidatesLoaded competitionId) (pbListDecoder entryDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }


{-| The voter's own ballot in the competition, if one is stored.
-}
fetchMyBallot : String -> String -> String -> String -> Cmd Msg
fetchMyBallot pbUrl token competitionId profileId =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" token ]
        , url =
            pbUrl
                ++ "/api/collections/votes/records?filter="
                ++ Url.percentEncode ("competition = \"" ++ competitionId ++ "\" && voter = \"" ++ profileId ++ "\"")
                ++ "&perPage=1"
        , body = Http.emptyBody
        , expect = Http.expectJson (MyBallotLoaded competitionId) (pbListDecoder Voting.ballotDecoder |> Decode.map List.head)
        , timeout = Nothing
        , tracker = Nothing
        }


{-| Every ballot of a competition, for the admin's count. Only reviewers may
read them.
-}
fetchAdminBallots : String -> String -> String -> Cmd Msg
fetchAdminBallots pbUrl token competitionId =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" token ]
        , url =
            pbUrl
                ++ "/api/collections/votes/records?filter="
                ++ Url.percentEncode ("competition = \"" ++ competitionId ++ "\"")
                ++ "&perPage=1000"
        , body = Http.emptyBody
        , expect = Http.expectJson (AdminBallotsLoaded competitionId) (pbListDecoder Voting.ballotDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }


{-| Cast the ballot (POST) or change the stored one (PATCH).
-}
saveBallotCmd : String -> String -> Ballot -> Cmd Msg
saveBallotCmd pbUrl token ballot =
    let
        url =
            pbUrl ++ "/api/collections/votes/records"
    in
    Http.request
        { method =
            case ballot.id of
                Just _ ->
                    "PATCH"

                Nothing ->
                    "POST"
        , headers = [ Http.header "Authorization" token ]
        , url =
            case ballot.id of
                Just ballotId ->
                    url ++ "/" ++ ballotId

                Nothing ->
                    url
        , body = Http.jsonBody (Voting.encodeBallot ballot)
        , expect = expectWithMessage (BallotSaved ballot.competitionId) Voting.ballotDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


{-| Like `Http.expectJson`, but a failure keeps the `message` PocketBase sent
with it, such as the reason a hook refused the request.
-}
expectWithMessage : (Result ServerError a -> msg) -> Decode.Decoder a -> Http.Expect msg
expectWithMessage toMsg decoder =
    Http.expectStringResponse toMsg
        (\response ->
            let
                failure error body =
                    Err { error = error, message = Decode.decodeString (Decode.field "message" Decode.string) body |> Result.toMaybe }
            in
            case response of
                Http.BadUrl_ url ->
                    Err { error = Http.BadUrl url, message = Nothing }

                Http.Timeout_ ->
                    Err { error = Http.Timeout, message = Nothing }

                Http.NetworkError_ ->
                    Err { error = Http.NetworkError, message = Nothing }

                Http.BadStatus_ metadata body ->
                    failure (Http.BadStatus metadata.statusCode) body

                Http.GoodStatus_ _ body ->
                    Decode.decodeString decoder body
                        |> Result.mapError (\problem -> { error = Http.BadBody (Decode.errorToString problem), message = Nothing })
        )


{-| Every competition, whatever its status, newest first.
-}
fetchAdminCompetitions : String -> String -> Cmd Msg
fetchAdminCompetitions pbUrl token =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" token ]
        , url = pbUrl ++ "/api/collections/competitions/records?sort=-start_date&perPage=200"
        , body = Http.emptyBody
        , expect = Http.expectJson AdminCompetitionsLoaded (pbListDecoder competitionDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }


{-| The loaded competition with this id, if the list has it.
-}
adminCompetitionById : Model -> String -> Maybe Competition
adminCompetitionById model competitionId =
    case model.adminCompetitions of
        RemoteData.Success competitions ->
            competitions
                |> List.filter (\competition -> competition.id == competitionId)
                |> List.head

        _ ->
            Nothing


{-| The competition an admin page is about: Nothing for a new one.
-}
adminCompetitionTarget : Model -> Maybe String
adminCompetitionTarget model =
    case model.page of
        AdminCompetitionPage target ->
            target

        _ ->
            Nothing


{-| Create a competition (POST) or change an existing one (PATCH).
-}
saveCompetitionCmd : String -> String -> Maybe String -> Maybe Competition -> CompetitionForm -> Cmd Msg
saveCompetitionCmd pbUrl token target original form =
    let
        url =
            pbUrl ++ "/api/collections/competitions/records"
    in
    Http.request
        { method =
            case target of
                Just _ ->
                    "PATCH"

                Nothing ->
                    "POST"
        , headers = [ Http.header "Authorization" token ]
        , url =
            case target of
                Just competitionId ->
                    url ++ "/" ++ competitionId

                Nothing ->
                    url
        , body = Http.jsonBody (Admin.encodeCompetition original form)
        , expect = Http.expectJson CompetitionSaved competitionDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


{-| Change only the status of a competition.
-}
setCompetitionStatusCmd : String -> String -> String -> CompetitionStatus -> Cmd Msg
setCompetitionStatusCmd pbUrl token competitionId status =
    Http.request
        { method = "PATCH"
        , headers = [ Http.header "Authorization" token ]
        , url = pbUrl ++ "/api/collections/competitions/records/" ++ competitionId
        , body = Http.jsonBody (Encode.object [ ( "status", Encode.string (Admin.statusToString status) ) ])
        , expect = Http.expectJson CompetitionStatusSaved competitionDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


{-| Every entry of a competition, drafts included, with its submitter and reviews.
-}
fetchAdminEntries : String -> String -> String -> Cmd Msg
fetchAdminEntries pbUrl token competitionId =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" token ]
        , url =
            pbUrl
                ++ "/api/collections/entries/records"
                ++ "?filter=competition%3D%22"
                ++ competitionId
                ++ "%22&expand=competition%2Csubmitter%2Creviews_via_entry&sort=-created&perPage=200"
        , body = Http.emptyBody
        , expect = Http.expectJson AdminEntriesLoaded (pbListDecoder (reviewableEntryDecoder ""))
        , timeout = Nothing
        , tracker = Nothing
        }


fetchMyEntries : String -> String -> String -> Cmd Msg
fetchMyEntries pbUrl token userId =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" token ]
        , url = myEntriesUrl pbUrl userId
        , body = Http.emptyBody
        , expect = Http.expectJson MyEntriesLoaded (pbListDecoder entryDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }


myEntriesUrl : String -> String -> String
myEntriesUrl pbUrl userId =
    pbUrl
        ++ "/api/collections/entries/records"
        ++ "?filter=submitter%3D%22"
        ++ userId
        ++ "%22&sort=-created&expand=competition%2Creviews_via_entry"


{-| Create an entry from the form with the given status ("draft" or
"submitted").
-}
createEntry : String -> AuthUser -> Competition -> SubmitForm -> String -> (Result Http.Error Entry -> Msg) -> Cmd Msg
createEntry pbUrl user comp form status toMsg =
    Http.request
        { method = "POST"
        , headers = [ Http.header "Authorization" user.token ]
        , url = pbUrl ++ "/api/collections/entries/records"
        , body =
            Http.multipartBody
                ([ Http.stringPart "competition" comp.id
                 , Http.stringPart "submitter" user.profileId
                 , Http.stringPart "title" form.title
                 , Http.stringPart "description" form.description
                 , Http.stringPart "status" status
                 ]
                    ++ List.map (Http.filePart "images") form.selectedFiles
                )
        , expect = Http.expectJson toMsg entryDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


{-| Save the form to an existing entry, optionally changing its status.
-}
updateEntry : String -> AuthUser -> String -> SubmitForm -> Maybe String -> (Result Http.Error Entry -> Msg) -> Cmd Msg
updateEntry pbUrl user entryId form status toMsg =
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
                    ++ (case status of
                            Just value ->
                                [ Http.stringPart "status" value ]

                            Nothing ->
                                []
                       )
                )
        , expect = Http.expectJson toMsg entryDecoder
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
    Decode.map7 AuthUser
        (Decode.field "id" Decode.string)
        (Decode.maybe (Decode.field "collectionName" Decode.string)
            |> Decode.map (Maybe.withDefault "local_users")
        )
        (Decode.maybe (Decode.field "profile_id" Decode.string)
            |> Decode.map (Maybe.withDefault "")
        )
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
                    (Decode.map6
                        (\id authCollection profileId email displayName isReviewer ->
                            { token = token
                            , record =
                                AuthUser id authCollection profileId email token displayName isReviewer
                            }
                        )
                        (Decode.field "id" Decode.string)
                        (Decode.maybe (Decode.field "collectionName" Decode.string)
                            |> Decode.map (Maybe.withDefault "local_users")
                        )
                        (Decode.maybe (Decode.field "profile_id" Decode.string)
                            |> Decode.map (Maybe.withDefault "")
                        )
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
    Decode.map8
        (\id title slug theme description startDate endDate coverImage ->
            \maxEntriesPerUser minImagesPerEntry maxImagesPerEntry judgingEndDate status ->
                \votingEnabled votingRequired votingStartDate votingEndDate ->
                    Competition id title slug theme description startDate endDate judgingEndDate status coverImage maxEntriesPerUser minImagesPerEntry maxImagesPerEntry votingEnabled votingRequired votingStartDate votingEndDate
        )
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "slug" Decode.string)
        (Decode.maybe (Decode.field "theme" Decode.string))
        (Decode.maybe (Decode.field "description" Decode.string))
        (Decode.field "start_date" Decode.string)
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
        |> Decode.andThen
            (\build ->
                Decode.map5 build
                    (Decode.maybe (Decode.field "max_entries_per_user" Decode.int))
                    (Decode.maybe (Decode.field "min_images_per_entry" Decode.int))
                    (Decode.maybe (Decode.field "max_images_per_entry" Decode.int))
                    (Decode.maybe (Decode.field "judging_end_date" Decode.string))
                    (Decode.map (Maybe.withDefault CDraft) (Decode.maybe (Decode.field "status" competitionStatusDecoder)))
            )
        |> Decode.andThen
            (\build ->
                Decode.map4 build
                    (optionalBool "voting_enabled")
                    (optionalBool "voting_required")
                    (optionalDate "voting_start_date")
                    (optionalDate "voting_end_date")
            )


optionalBool : String -> Decode.Decoder Bool
optionalBool name =
    Decode.maybe (Decode.field name Decode.bool)
        |> Decode.map (Maybe.withDefault False)


{-| A PocketBase date field: empty when not set.
-}
optionalDate : String -> Decode.Decoder (Maybe String)
optionalDate name =
    Decode.maybe (Decode.field name Decode.string)
        |> Decode.map
            (Maybe.andThen
                (\value ->
                    if String.isEmpty value then
                        Nothing

                    else
                        Just value
                )
            )


competitionStatusDecoder : Decode.Decoder CompetitionStatus
competitionStatusDecoder =
    Decode.string
        |> Decode.andThen
            (\value ->
                case value of
                    "open" ->
                        Decode.succeed COpen

                    "closed" ->
                        Decode.succeed CClosed

                    "judging" ->
                        Decode.succeed CJudging

                    "finished" ->
                        Decode.succeed CFinished

                    _ ->
                        Decode.succeed CDraft
            )


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



-- | Decode published reviews from the expand.reviews_via_entry field.
-- Returns [] when the field is absent (entries fetched without expand).


publishedReviewsDecoder : Decode.Decoder (List ReviewSummary)
publishedReviewsDecoder =
    let
        rawDecoder =
            Decode.map3
                (\published total comment ->
                    if published then
                        Just (ReviewSummary total comment)

                    else
                        Nothing
                )
                (Decode.field "is_published" Decode.bool)
                (Decode.field "scores" (Decode.dict Decode.int)
                    |> Decode.map (Dict.values >> List.sum)
                )
                (Decode.maybe (Decode.field "comment" Decode.string))
    in
    Decode.maybe
        (Decode.at [ "expand", "reviews_via_entry" ] (Decode.list rawDecoder))
        |> Decode.map (Maybe.withDefault [] >> List.filterMap identity)


entryDecoder : Decode.Decoder Entry
entryDecoder =
    Decode.map8 Entry
        (Decode.field "id" Decode.string)
        (Decode.field "competition" Decode.string)
        (Decode.maybe (Decode.at [ "expand", "competition" ] competitionDecoder))
        (Decode.oneOf [ Decode.field "submitter" Decode.string, Decode.succeed "" ])
        (Decode.field "title" Decode.string)
        (Decode.maybe (Decode.field "description" Decode.string))
        (Decode.field "images" (Decode.list Decode.string))
        (Decode.field "status" entryStatusDecoder)
        |> Decode.andThen (\build -> Decode.map build publishedReviewsDecoder)


fetchReviewQueue : String -> String -> String -> Cmd Msg
fetchReviewQueue pbUrl token profileId =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" token ]
        , url = reviewQueueUrl pbUrl
        , body = Http.emptyBody
        , expect = Http.expectJson ReviewQueueLoaded (pbListDecoder (reviewableEntryDecoder profileId))
        , timeout = Nothing
        , tracker = Nothing
        }


{-| The review queue: every submitted, approved or rejected entry. PocketBase
returns 30 records per page unless asked for more.
-}
reviewQueueUrl : String -> String
reviewQueueUrl pbUrl =
    pbUrl
        ++ "/api/collections/entries/records"
        ++ "?filter=status%3D%22submitted%22||status%3D%22approved%22||status%3D%22rejected%22"
        ++ "&expand=competition%2Csubmitter%2Creviews_via_entry&sort=created&perPage=200"


{-| Save the open review form; `isPublished` decides whether the submitter
sees the scores ("Tallenna ja julkaise") or not ("Tallenna").
-}
saveReview : Bool -> Model -> ( Model, Cmd Msg )
saveReview isPublished model =
    case ( model.auth, model.activeReview ) of
        ( LoggedIn user, Just reviewForm ) ->
            let
                draft =
                    reviewForm.draftReview

                review =
                    { draft | isPublished = isPublished }
            in
            ( { model | activeReview = Just { reviewForm | saving = True, draftReview = review } }
            , saveReviewCmd model.pbUrl user.token review
            )

        _ ->
            ( model, Cmd.none )


saveReviewCmd : String -> String -> Review -> Cmd Msg
saveReviewCmd pbUrl token review =
    let
        body =
            Http.jsonBody
                (Encode.object
                    [ ( "entry", Encode.string review.entryId )
                    , ( "reviewer", Encode.string review.reviewerId )
                    , ( "scores", Encode.dict identity Encode.int review.scores )
                    , ( "comment", Encode.string review.comment )
                    , ( "is_published", Encode.bool review.isPublished )
                    ]
                )
    in
    case review.id of
        Nothing ->
            Http.request
                { method = "POST"
                , headers = [ Http.header "Authorization" token ]
                , url = pbUrl ++ "/api/collections/reviews/records"
                , body = body
                , expect = Http.expectJson ReviewSaved reviewDecoder
                , timeout = Nothing
                , tracker = Nothing
                }

        Just reviewId ->
            Http.request
                { method = "PATCH"
                , headers = [ Http.header "Authorization" token ]
                , url = pbUrl ++ "/api/collections/reviews/records/" ++ reviewId
                , body = body
                , expect = Http.expectJson ReviewSaved reviewDecoder
                , timeout = Nothing
                , tracker = Nothing
                }


changeEntryStatus : String -> String -> String -> String -> EntryStatus -> Cmd Msg
changeEntryStatus pbUrl token entryId statusStr newStatus =
    Http.request
        { method = "PATCH"
        , headers = [ Http.header "Authorization" token ]
        , url = pbUrl ++ "/api/collections/entries/records/" ++ entryId
        , body =
            Http.jsonBody
                (Encode.object [ ( "status", Encode.string statusStr ) ])
        , expect = Http.expectWhatever (EntryStatusChanged entryId newStatus)
        , timeout = Nothing
        , tracker = Nothing
        }


reviewDecoder : Decode.Decoder Review
reviewDecoder =
    Decode.field "id" Decode.string
        |> Decode.andThen
            (\id ->
                Decode.map5
                    (Review (Just id))
                    (Decode.field "entry" Decode.string)
                    (Decode.field "reviewer" Decode.string)
                    (Decode.field "scores" (Decode.dict Decode.int))
                    (Decode.maybe (Decode.field "comment" Decode.string)
                        |> Decode.map (Maybe.withDefault "")
                    )
                    (Decode.maybe (Decode.field "is_published" Decode.bool)
                        |> Decode.map (Maybe.withDefault False)
                    )
            )


{-| An entry in the review queue, with the review `reviewerId` (a profile)
has already given it, if any, from `expand.reviews_via_entry`.
-}
reviewableEntryDecoder : String -> Decode.Decoder ReviewableEntry
reviewableEntryDecoder reviewerId =
    Decode.map4 ReviewableEntry
        entryDecoder
        (Decode.at [ "expand", "competition" ] competitionDecoder)
        (Decode.maybe (Decode.at [ "expand", "submitter", "display_name" ] Decode.string)
            |> Decode.map (Maybe.withDefault "")
        )
        (Decode.maybe (Decode.at [ "expand", "reviews_via_entry" ] (Decode.list reviewDecoder))
            |> Decode.map
                (Maybe.withDefault []
                    >> List.filter (\review -> review.reviewerId == reviewerId)
                    >> List.head
                )
        )


pbListDecoder : Decode.Decoder a -> Decode.Decoder (List a)
pbListDecoder itemDecoder =
    Decode.field "items" (Decode.list itemDecoder)

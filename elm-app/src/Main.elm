module Main exposing
    ( authResponseDecoder
    , canSubmitMore
    , competitionDecoder
    , emptyReview
    , entryDecoder
    , filteredReviewQueue
    , handleHttpError
    , httpErrorMessage
    , imageMax
    , imageMin
    , main
    , myEntriesUrl
    , otpResponseDecoder
    , requestOtpUrl
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
import Scoring
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
      , now = Time.millisToPosix 0
      , competitions = competitionsState
      , myEntries = RemoteData.NotAsked
      , submitForm = emptyForm
      , selectedCompetition = Nothing
      , reviewQueue = RemoteData.NotAsked
      , activeReview = Nothing
      , reviewFilter = AllEntries
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

        OtpRequested (Err (Http.BadStatus 409)) ->
            ( { model | authError = Just "Kirjaudu tällä osoitteella Keycloakin kautta" }, Cmd.none )

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

        OtpSubmitted (Err (Http.BadStatus 409)) ->
            ( { model | authError = Just "Kirjaudu tällä osoitteella Keycloakin kautta" }, Cmd.none )

        OtpSubmitted (Err _) ->
            ( { model | authError = Just "Kirjautuminen epäonnistui" }, Cmd.none )

        StartKeycloakLogin ->
            ( { model | authError = Nothing }, Ports.startKeycloakLogin model.pbUrl )

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

        KeycloakLoginFailed message ->
            ( { model | authError = Just message }, Cmd.none )

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

                _ ->
                    ( model, Cmd.none )

        DisplayNameSaved (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
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
                    , fetchMyEntries model.pbUrl user.token user.profileId
                    )

                ( ReviewQueuePage, LoggedIn user ) ->
                    ( { model | page = page, reviewQueue = RemoteData.Loading }
                    , fetchReviewQueue model.pbUrl user.token
                    )

                _ ->
                    ( { model | page = page }, Cmd.none )

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

                maxImages =
                    model.selectedCompetition
                        |> Maybe.map imageMax
                        |> Maybe.withDefault 10

                remainingSlots =
                    max 0 (maxImages - List.length form.existingImages - List.length form.selectedFiles)

                newFiles =
                    form.selectedFiles ++ List.take remainingSlots (first :: rest)
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

        DraftSaved (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
                    let
                        form =
                            model.submitForm
                    in
                    ( { model | submitForm = { form | step = UploadError "Luonnoksen tallennus epäonnistui" } }
                    , Cmd.none
                    )

        SubmitEntry ->
            case ( model.auth, model.submitForm.entryId, model.selectedCompetition ) of
                ( LoggedIn user, Just entryId, Just competition ) ->
                    case validateForm competition model.submitForm of
                        Err e ->
                            ( { model | authError = Just e }, Cmd.none )

                        Ok _ ->
                            ( model, submitEntryCmd model.pbUrl user.token entryId )

                ( LoggedIn _, Just _, Nothing ) ->
                    ( { model | authError = Just "Kilpailua ei ole valittu" }, Cmd.none )

                _ ->
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
                    ( { model | submitForm = { form | step = UploadError "Lähettäminen epäonnistui" } }
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

        EditDraft entryId ->
            case model.myEntries of
                RemoteData.Success entries ->
                    case List.filter (\entry -> entry.id == entryId) entries |> List.head of
                        Just entry ->
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
                                        , authError = Just "Kilpailun tietoja ei voitu ladata"
                                      }
                                    , Cmd.none
                                    )

                        Nothing ->
                            ( { model | authError = Just "Luonnosta ei löytynyt" }, Cmd.none )

                _ ->
                    ( { model | authError = Just "Luonnosta ei löytynyt" }, Cmd.none )

        CancelEdit ->
            ( { model | page = MyEntriesPage, submitForm = emptyForm }, Cmd.none )

        -- Review queue
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
                            existing

                        Nothing ->
                            case model.auth of
                                LoggedIn user ->
                                    emptyReview reviewableEntry.entry.id user.profileId

                                _ ->
                                    emptyReview reviewableEntry.entry.id ""
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
        ScoreThemeChanged n ->
            updateDraftScore (\r -> { r | scoreTheme = n }) model

        ScoreOriginalityChanged n ->
            updateDraftScore (\r -> { r | scoreOriginality = n }) model

        ScoreTechniqueChanged n ->
            updateDraftScore (\r -> { r | scoreTechnique = n }) model

        ScorePresentationChanged n ->
            updateDraftScore (\r -> { r | scorePresentation = n }) model

        ReviewCommentChanged comment ->
            updateDraftScore (\r -> { r | comment = comment }) model

        -- Review actions
        SaveReview ->
            case ( model.auth, model.activeReview ) of
                ( LoggedIn user, Just reviewForm ) ->
                    ( { model | activeReview = Just { reviewForm | saving = True } }
                    , saveReviewCmd model.pbUrl user.token reviewForm.draftReview
                    )

                _ ->
                    ( model, Cmd.none )

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
                                            , saveError = Just "Arvostelun tallennus epäonnistui"
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

        EntryStatusChanged entryId newStatus (Ok ()) ->
            let
                updateEntry re =
                    if re.entry.id == entryId then
                        let
                            e =
                                re.entry
                        in
                        { re | entry = { e | status = newStatus } }

                    else
                        re
            in
            ( { model | reviewQueue = RemoteData.map (List.map updateEntry) model.reviewQueue }
            , Cmd.none
            )

        EntryStatusChanged _ _ (Err err) ->
            case err of
                Http.BadStatus 401 ->
                    handleHttpError err model

                _ ->
                    ( { model | authError = Just "Tilan vaihto epäonnistui" }, Cmd.none )

        Tick time ->
            ( { model | now = time }, Cmd.none )


view : Model -> Html Msg
view model =
    View.view model


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Time.every 60000 Tick
        , Ports.keycloakLoginSucceeded KeycloakLoginCompleted
        , Ports.keycloakLoginFailed KeycloakLoginFailed
        ]



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


validateForm : Competition -> SubmitForm -> Result String SubmitForm
validateForm competition form =
    let
        count =
            List.length form.selectedFiles + List.length form.existingImages

        minImages =
            imageMin competition

        maxImages =
            imageMax competition
    in
    if String.isEmpty form.title then
        Err "Nimi on pakollinen"

    else if String.length form.title > 200 then
        Err "Nimi on liian pitkä (max 200 merkkiä)"

    else if count < minImages then
        if minImages <= 1 then
            Err "Lisää vähintään yksi kuva"

        else
            Err ("Lisää vähintään " ++ String.fromInt minImages ++ " kuvaa")

    else if count > maxImages then
        Err ("Enintään " ++ String.fromInt maxImages ++ " kuvaa sallittu")

    else
        Ok form


emptyReview : String -> String -> Review
emptyReview entryId reviewerId =
    { id = Nothing
    , entryId = entryId
    , reviewerId = reviewerId
    , scoreTheme = 3
    , scoreOriginality = 3
    , scoreTechnique = 3
    , scorePresentation = 3
    , comment = ""
    , isPublished = False
    }


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



-- | Map an Http.Error to a Finnish user-facing message.


httpErrorMessage : Http.Error -> String
httpErrorMessage err =
    case err of
        Http.NetworkError ->
            "Verkkovirhe — tarkista yhteys"

        Http.BadStatus 401 ->
            "Istunto vanhentunut — kirjaudu uudelleen"

        Http.BadStatus 403 ->
            "Ei oikeutta"

        Http.BadStatus 404 ->
            "Ei löydy"

        _ ->
            "Odottamaton virhe; yritä uudelleen"



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
canSubmitMore competition entries =
    let
        myCount =
            List.length (List.filter (\e -> e.competitionId == competition.id) entries)

        limit =
            Maybe.withDefault 3 competition.maxEntriesPerUser
    in
    limit == 0 || myCount < limit



-- ---------------------------------------------------------------------------
-- HTTP commands
-- ---------------------------------------------------------------------------


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
                ++ "&fields=id%2Ctitle%2Cslug%2Ctheme%2Cdescription%2Cend_date%2Ccover_image%2Cmax_entries_per_user%2Cmin_images_per_entry%2Cmax_images_per_entry"
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


createDraft : String -> AuthUser -> Competition -> SubmitForm -> Cmd Msg
createDraft pbUrl user comp form =
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
        (\id title slug theme description endDate coverImage maxEntriesPerUser ->
            \minImagesPerEntry maxImagesPerEntry ->
                Competition id title slug theme description endDate coverImage maxEntriesPerUser minImagesPerEntry maxImagesPerEntry
        )
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
        |> Decode.andThen
            (\build ->
                Decode.map2 build
                    (Decode.maybe (Decode.field "min_images_per_entry" Decode.int))
                    (Decode.maybe (Decode.field "max_images_per_entry" Decode.int))
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
                (Decode.map4 (\t o tc p -> t + o + tc + p)
                    (Decode.field "score_theme" Decode.int)
                    (Decode.field "score_originality" Decode.int)
                    (Decode.field "score_technique" Decode.int)
                    (Decode.field "score_presentation" Decode.int)
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
        (Decode.field "title" Decode.string)
        (Decode.maybe (Decode.field "description" Decode.string))
        (Decode.field "images" (Decode.list Decode.string))
        (Decode.field "status" entryStatusDecoder)
        publishedReviewsDecoder


fetchReviewQueue : String -> String -> Cmd Msg
fetchReviewQueue pbUrl token =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" token ]
        , url =
            pbUrl
                ++ "/api/collections/entries/records"
                ++ "?filter=status%3D%22submitted%22||status%3D%22approved%22||status%3D%22rejected%22"
                ++ "&expand=competition%2Csubmitter&sort=created"
        , body = Http.emptyBody
        , expect = Http.expectJson ReviewQueueLoaded (pbListDecoder reviewableEntryDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }


saveReviewCmd : String -> String -> Review -> Cmd Msg
saveReviewCmd pbUrl token review =
    let
        body =
            Http.jsonBody
                (Encode.object
                    [ ( "entry", Encode.string review.entryId )
                    , ( "reviewer", Encode.string review.reviewerId )
                    , ( "score_theme", Encode.int review.scoreTheme )
                    , ( "score_originality", Encode.int review.scoreOriginality )
                    , ( "score_technique", Encode.int review.scoreTechnique )
                    , ( "score_presentation", Encode.int review.scorePresentation )
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
                Decode.map8
                    (Review (Just id))
                    (Decode.field "entry" Decode.string)
                    (Decode.field "reviewer" Decode.string)
                    (Decode.field "score_theme" Decode.int)
                    (Decode.field "score_originality" Decode.int)
                    (Decode.field "score_technique" Decode.int)
                    (Decode.field "score_presentation" Decode.int)
                    (Decode.maybe (Decode.field "comment" Decode.string)
                        |> Decode.map (Maybe.withDefault "")
                    )
                    (Decode.maybe (Decode.field "is_published" Decode.bool)
                        |> Decode.map (Maybe.withDefault False)
                    )
            )


reviewableEntryDecoder : Decode.Decoder ReviewableEntry
reviewableEntryDecoder =
    Decode.map4 ReviewableEntry
        entryDecoder
        (Decode.at [ "expand", "competition" ] competitionDecoder)
        (Decode.maybe (Decode.at [ "expand", "submitter", "display_name" ] Decode.string)
            |> Decode.map (Maybe.withDefault "")
        )
        (Decode.succeed Nothing)


pbListDecoder : Decode.Decoder a -> Decode.Decoder (List a)
pbListDecoder itemDecoder =
    Decode.field "items" (Decode.list itemDecoder)

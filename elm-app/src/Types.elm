module Types exposing
    ( AuthResponse
    , AuthState(..)
    , AuthUser
    , Competition
    , Entry
    , EntryStatus(..)
    , Flags
    , Model
    , Msg(..)
    , OtpResponse
    , Page(..)
    , Review
    , ReviewFilter(..)
    , ReviewForm
    , ReviewSummary
    , ReviewableEntry
    , SubmitForm
    , SubmitFormStep(..)
    )

{-| Core types for the competition platform application.
-}

import Dict exposing (Dict)
import File exposing (File)
import Http
import Json.Decode as Decode
import Lang exposing (Lang)
import RemoteData exposing (RemoteData)
import SiteSettings exposing (SiteSettings)
import Time


{-| An authenticated user with PocketBase auth token and profile.
-}
type alias AuthUser =
    { id : String
    , authCollection : String
    , profileId : String
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


{-| A competition event from PocketBase.
-}
type alias Competition =
    { id : String
    , title : String
    , slug : String
    , theme : Maybe String
    , description : Maybe String
    , startDate : String
    , endDate : String
    , coverImage : Maybe String
    , maxEntriesPerUser : Maybe Int
    , minImagesPerEntry : Maybe Int
    , maxImagesPerEntry : Maybe Int
    }


{-| Possible statuses for an entry submission.
-}
type EntryStatus
    = Draft
    | Submitted
    | Approved
    | Rejected


{-| A published review score summary shown to the entry submitter.
-}
type alias ReviewSummary =
    { total : Int
    , comment : Maybe String
    }


{-| A MOC entry from PocketBase.
-}
type alias Entry =
    { id : String
    , competitionId : String
    , competition : Maybe Competition
    , title : String
    , description : Maybe String
    , images : List String
    , status : EntryStatus
    , publishedReviews : List ReviewSummary
    }


{-| Steps in the submission form workflow.
-}
type SubmitFormStep
    = FillingForm
    | ConfirmingSubmit
    | Uploading
    | UploadError String
    | SubmitSuccess


{-| State for the entry submission/edit form.
-}
type alias SubmitForm =
    { entryId : Maybe String
    , title : String
    , description : String
    , selectedFiles : List File
    , existingImages : List String
    , imagesToRemove : List String
    , isCompressing : Bool
    , step : SubmitFormStep
    , draftSaved : Bool
    , previews : Dict String String
    }


{-| A reviewer's score for one entry (4 criteria, 1–5 each).
-}
type alias Review =
    { id : Maybe String
    , entryId : String
    , reviewerId : String
    , scoreTheme : Int
    , scoreOriginality : Int
    , scoreTechnique : Int
    , scorePresentation : Int
    , comment : String
    , isPublished : Bool
    }


{-| An entry with its expanded competition and submitter, ready for review.
-}
type alias ReviewableEntry =
    { entry : Entry
    , competition : Competition
    , submitterName : String
    , myReview : Maybe Review
    }


{-| Working state for the review form panel.
-}
type alias ReviewForm =
    { reviewableEntry : ReviewableEntry
    , draftReview : Review
    , saving : Bool
    , saveError : Maybe String
    }


{-| Filter for the review queue.
-}
type ReviewFilter
    = AllEntries
    | NotYetReviewed
    | ByCompetition String


{-| All pages in the application.
-}
type Page
    = LoginPage
    | SetDisplayNamePage
    | DashboardPage
    | MyEntriesPage
    | ParticipationPage String
    | SubmitEntryPage (Maybe String)
    | ReviewQueuePage
    | NotFoundPage


{-| Flags passed from index.html on init.
-}
type alias Flags =
    { pbUrl : String
    , restoredAuth : Maybe AuthUser
    , siteConfig : Decode.Value
    , requestedLang : Maybe String
    , hash : String
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
    , site : SiteSettings
    , menuOpen : Bool
    , now : Time.Posix
    , competitions : RemoteData Http.Error (List Competition)
    , myEntries : RemoteData Http.Error (List Entry)
    , submitForm : SubmitForm
    , selectedCompetition : Maybe Competition
    , reviewQueue : RemoteData Http.Error (List ReviewableEntry)
    , activeReview : Maybe ReviewForm
    , reviewFilter : ReviewFilter
    }


{-| All messages in the Elm Architecture update loop.
-}
type Msg
    = -- Auth
      EmailChanged String
    | OtpCodeChanged String
    | RequestOtp
    | OtpRequested (Result Http.Error OtpResponse)
    | SubmitOtp
    | OtpSubmitted (Result Http.Error AuthResponse)
    | LogOut
    | SessionRefreshed (Result Http.Error AuthResponse)
    | DisplayNameChanged String
    | SaveDisplayName
    | DisplayNameSaved (Result Http.Error String)
    | StartKeycloakLogin
    | KeycloakLoginCompleted AuthResponse
    | KeycloakLoginFailed String
      -- Navigation
    | NavigateTo Page
    | HashChanged String
    | ToggleMenu
    | CloseMenu
    | NoOp
      -- Competitions
    | CompetitionsLoaded (Result Http.Error (List Competition))
    | SelectCompetition Competition
      -- Entry form
    | EntryTitleChanged String
    | EntryDescriptionChanged String
    | RawFilesSelected Decode.Value
    | ImagesCompressed Decode.Value
    | CompressionFailed String
    | RemoveSelectedFile Int
    | RemoveExistingImage String
    | SaveDraft
    | DraftSaved (Result Http.Error Entry)
    | PreviewReady String String
    | SubmitEntry
    | ConfirmSubmit
    | CancelSubmit
    | EntrySubmitted (Result Http.Error Entry)
      -- My entries
    | MyEntriesLoaded (Result Http.Error (List Entry))
    | EditEntry String
    | CancelEdit
      -- Review queue
    | ReviewQueueLoaded (Result Http.Error (List ReviewableEntry))
    | ReviewFilterChanged ReviewFilter
    | OpenReviewForm ReviewableEntry
    | CloseReviewForm
      -- Scoring
    | ScoreThemeChanged Int
    | ScoreOriginalityChanged Int
    | ScoreTechniqueChanged Int
    | ScorePresentationChanged Int
    | ReviewCommentChanged String
      -- Review actions
    | SaveReview
    | SaveAndPublishReview
    | ReviewSaved (Result Http.Error Review)
    | ApproveEntry String
    | RejectEntry String
    | EntryStatusChanged String EntryStatus (Result Http.Error ())
      -- Time
    | Tick Time.Posix

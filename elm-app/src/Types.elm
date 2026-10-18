module Types exposing
    ( AdminField(..)
    , AdminFlag(..)
    , AuthResponse
    , AuthState(..)
    , AuthUser
    , Ballot
    , Competition
    , CompetitionForm
    , CompetitionStatus(..)
    , Entry
    , EntryStatus(..)
    , Flags
    , FormError(..)
    , Model
    , Msg(..)
    , OtpResponse
    , Page(..)
    , Review
    , ReviewFilter(..)
    , ReviewForm
    , ReviewSummary
    , ReviewableEntry
    , ServerError
    , SubmitForm
    , SubmitFormStep(..)
    , VotingModel
    )

{-| Core types for the competition platform application.
-}

import Criteria exposing (Criterion)
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


{-| A field of the competition form.
-}
type AdminField
    = FieldTitle
    | FieldSlug
    | FieldTheme
    | FieldDescription
    | FieldStartDate
    | FieldEndDate
    | FieldJudgingEndDate
    | FieldMaxEntries
    | FieldMinImages
    | FieldMaxImages
    | FieldVotingStartDate
    | FieldVotingEndDate


{-| A yes/no setting of the competition form.
-}
type AdminFlag
    = FlagVotingEnabled
    | FlagVotingRequired


{-| Why a competition form cannot be saved.
-}
type FormError
    = TitleRequired
    | SlugInvalid
    | DateInvalid
    | EndBeforeStart
    | MaxEntriesInvalid
    | ImageLimitsInvalid
    | VotingDatesInvalid
    | ServerRejected


{-| A competition as the admin edits it. Every field is text, as typed; dates
are "YYYY-MM-DD" and empty optional numbers mean "not set".
-}
type alias CompetitionForm =
    { title : String
    , slug : String
    , theme : String
    , description : String
    , startDate : String
    , endDate : String
    , judgingEndDate : String
    , maxEntriesPerUser : String
    , minImagesPerEntry : String
    , maxImagesPerEntry : String
    , votingEnabled : Bool
    , votingRequired : Bool
    , votingStartDate : String
    , votingEndDate : String
    , status : CompetitionStatus
    }


{-| The lifecycle of a competition: draft, open for entries, closed for entries,
being judged, finished. The app lists only open competitions.
-}
type CompetitionStatus
    = CDraft
    | COpen
    | CClosed
    | CJudging
    | CFinished


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
    , judgingEndDate : Maybe String
    , status : CompetitionStatus
    , coverImage : Maybe String
    , maxEntriesPerUser : Maybe Int
    , minImagesPerEntry : Maybe Int
    , maxImagesPerEntry : Maybe Int
    , votingEnabled : Bool
    , votingRequired : Bool
    , votingStartDate : Maybe String
    , votingEndDate : Maybe String
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
    , submitterId : String
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


{-| A reviewer's score for one entry: one 1–5 score per review criterion, keyed
by the criterion's id.
-}
type alias Review =
    { id : Maybe String
    , entryId : String
    , reviewerId : String
    , scores : Dict String Int
    , comment : String
    , isPublished : Bool
    }


{-| A voter's ranking of a competition's entries: entry ids in preference
order, 1st to at most 5th (ADR-0007).
-}
type alias Ballot =
    { id : Maybe String
    , competitionId : String
    , voterId : String
    , ranking : List String
    }


{-| A failed request with the server's message, when it sent one.
-}
type alias ServerError =
    { error : Http.Error
    , message : Maybe String
    }


{-| The state of ranked voting: the competitions whose voting is running (on
the dashboard), the vote page of one competition with the ballot being made,
and the ballots an admin counts.
-}
type alias VotingModel =
    { openCompetitions : RemoteData Http.Error (List Competition)
    , competition : RemoteData Http.Error Competition
    , candidates : RemoteData Http.Error (List Entry)
    , ballot : Ballot
    , ballotLoaded : Bool
    , saving : Bool
    , saved : Bool
    , error : Maybe String
    , adminBallots : RemoteData Http.Error (List Ballot)
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
    | AdminPage
    | AdminCompetitionPage (Maybe String)
    | AdminEntriesPage String
    | VotePage String
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
    , adminCompetitions : RemoteData Http.Error (List Competition)
    , adminForm : Maybe CompetitionForm
    , adminFormErrors : List FormError
    , adminEntries : RemoteData Http.Error (List ReviewableEntry)
    , criteria : List Criterion
    , voting : VotingModel
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
    | EscapePressed
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
    | AdminCompetitionsLoaded (Result Http.Error (List Competition))
    | AdminEntriesLoaded (Result Http.Error (List ReviewableEntry))
    | AdminFieldChanged AdminField String
    | AdminFlagChanged AdminFlag Bool
    | SaveCompetition
    | SetCompetitionStatus CompetitionStatus
    | CompetitionSaved (Result Http.Error Competition)
    | CompetitionStatusSaved (Result Http.Error Competition)
    | ReviewFilterChanged ReviewFilter
    | OpenReviewForm ReviewableEntry
    | CloseReviewForm
      -- Scoring
    | ScoreChanged String Int
    | ReviewCommentChanged String
      -- Review actions
    | SaveReview
    | SaveAndPublishReview
    | ReviewSaved (Result Http.Error Review)
    | ApproveEntry String
    | RejectEntry String
    | ResetEntry String
    | EntryStatusChanged String EntryStatus (Result Http.Error ())
      -- Voting
    | VotingCompetitionsLoaded (Result Http.Error (List Competition))
    | VoteCompetitionLoaded String (Result Http.Error Competition)
    | VoteCandidatesLoaded String (Result Http.Error (List Entry))
    | MyBallotLoaded String (Result Http.Error (Maybe Ballot))
    | PickEntry String
    | UnpickEntry String
    | MoveEntryUp String
    | MoveEntryDown String
    | SaveBallot
    | BallotSaved String (Result ServerError Ballot)
    | AdminBallotsLoaded String (Result Http.Error (List Ballot))
      -- Time
    | Tick Time.Posix

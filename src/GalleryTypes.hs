{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Domain types for the competition platform gallery pipeline.
-- These are decoded from PocketBase REST API responses.
module GalleryTypes
    ( Competition (..)
    , Entry (..)
    , Review (..)
    , RankedEntry (..)
    , CompetitionStatus (..)
    , EntryStatus (..)
    , rankEntries
    ) where

import Data.Aeson
    ( FromJSON (..)
    , withObject
    , withText
    , (.:)
    , (.:?)
    )
import Data.Text (Text)
import GHC.Generics (Generic)

-- ---------------------------------------------------------------------------
-- Status enumerations
-- ---------------------------------------------------------------------------

data CompetitionStatus
    = Draft
    | Open
    | Closed
    | Judging
    | Finished
    deriving (Show, Eq, Generic)

instance FromJSON CompetitionStatus where
    parseJSON = withText "CompetitionStatus" $ \t -> case t of
        "draft"    -> pure Draft
        "open"     -> pure Open
        "closed"   -> pure Closed
        "judging"  -> pure Judging
        "finished" -> pure Finished
        _          -> fail $ "Unknown competition status: " <> show t

data EntryStatus
    = EntryDraft
    | Submitted
    | Approved
    | Rejected
    deriving (Show, Eq, Generic)

instance FromJSON EntryStatus where
    parseJSON = withText "EntryStatus" $ \t -> case t of
        "draft"     -> pure EntryDraft
        "submitted" -> pure Submitted
        "approved"  -> pure Approved
        "rejected"  -> pure Rejected
        _           -> fail $ "Unknown entry status: " <> show t

-- ---------------------------------------------------------------------------
-- Core domain types
-- ---------------------------------------------------------------------------

data Competition = Competition
    { compId          :: Text
    , compTitle       :: Text
    , compSlug        :: Text
    , compDescription :: Maybe Text
    , compTheme       :: Maybe Text
    , compStatus      :: CompetitionStatus
    , compStartDate   :: Text
    , compEndDate     :: Text
    } deriving (Show, Eq, Generic)

instance FromJSON Competition where
    parseJSON = withObject "Competition" $ \o ->
        Competition
            <$> o .:  "id"
            <*> o .:  "title"
            <*> o .:  "slug"
            <*> o .:? "description"
            <*> o .:? "theme"
            <*> o .:  "status"
            <*> o .:  "start_date"
            <*> o .:  "end_date"

data Entry = Entry
    { entryId           :: Text
    , entryCompetition  :: Text   -- competition id
    , entrySubmitter    :: Text   -- user id
    , entryTitle        :: Text
    , entryDescription  :: Maybe Text
    , entryImages       :: [Text] -- list of filenames
    , entryCoverIndex   :: Int    -- index into entryImages
    , entryStatus       :: EntryStatus
    } deriving (Show, Eq, Generic)

instance FromJSON Entry where
    parseJSON = withObject "Entry" $ \o ->
        Entry
            <$> o .:  "id"
            <*> o .:  "competition"
            <*> o .:  "submitter"
            <*> o .:  "title"
            <*> o .:? "description"
            <*> o .:  "images"
            <*> (maybe 0 id <$> o .:? "cover_image_index")
            <*> o .:  "status"

data Review = Review
    { reviewId              :: Text
    , reviewEntry           :: Text   -- entry id
    , reviewReviewer        :: Text   -- user id
    , reviewScoreTheme      :: Int
    , reviewScoreOriginality :: Int
    , reviewScoreTechnique  :: Int
    , reviewScorePresentation :: Int
    , reviewComment         :: Maybe Text
    , reviewIsPublished     :: Bool
    } deriving (Show, Eq, Generic)

instance FromJSON Review where
    parseJSON = withObject "Review" $ \o ->
        Review
            <$> o .:  "id"
            <*> o .:  "entry"
            <*> o .:  "reviewer"
            <*> o .:  "score_theme"
            <*> o .:  "score_originality"
            <*> o .:  "score_technique"
            <*> o .:  "score_presentation"
            <*> o .:? "comment"
            <*> (maybe False id <$> o .:? "is_published")

-- ---------------------------------------------------------------------------
-- Ranking
-- ---------------------------------------------------------------------------

-- | An entry with its computed total score from all published reviews.
data RankedEntry = RankedEntry
    { rankedEntry      :: Entry
    , rankedReviews    :: [Review]
    , rankedTotalScore :: Int
    , rankedRank       :: Int
    } deriving (Show, Eq, Generic)

-- | Rank entries by average published review score (descending).
-- Entries without any published reviews are listed last.
rankEntries :: [(Entry, [Review])] -> [RankedEntry]
rankEntries pairs =
    let scored = map scoreEntry pairs
        sorted = reverse $ map snd $ sort $ map (\re -> (rankedTotalScore re, re)) scored
        ranked = zipWith (\rank re -> re { rankedRank = rank }) [1..] sorted
    in ranked
  where
    scoreEntry (e, rs) =
        let published = filter reviewIsPublished rs
            total = sum $ map reviewTotal published
        in RankedEntry e rs total 0

    reviewTotal r =
        reviewScoreTheme r
        + reviewScoreOriginality r
        + reviewScoreTechnique r
        + reviewScorePresentation r

    sort [] = []
    sort (x:xs) =
        sort [y | y <- xs, fst y <= fst x]
        ++ [x]
        ++ sort [y | y <- xs, fst y > fst x]

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

{- | Domain types for the competition platform gallery pipeline.
These are decoded from PocketBase REST API responses.
-}
module GalleryTypes (
    Competition (..),
    Entry (..),
    Review (..),
    RankedEntry (..),
    Vote (..),
    VoteRankedEntry (..),
    CompetitionStatus (..),
    EntryStatus (..),
    rankEntries,
    rankByVotes,
    votePoints,
    votingClosed,
) where

import Data.Aeson (
    FromJSON (..),
    withObject,
    withText,
    (.:),
    (.:?),
 )
import Data.List (sortBy, sortOn)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Ord (Down (..), comparing)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
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
        "draft" -> pure Draft
        "open" -> pure Open
        "closed" -> pure Closed
        "judging" -> pure Judging
        "finished" -> pure Finished
        _ -> fail $ "Unknown competition status: " <> show t

data EntryStatus
    = EntryDraft
    | Submitted
    | Approved
    | Rejected
    deriving (Show, Eq, Generic)

instance FromJSON EntryStatus where
    parseJSON = withText "EntryStatus" $ \t -> case t of
        "draft" -> pure EntryDraft
        "submitted" -> pure Submitted
        "approved" -> pure Approved
        "rejected" -> pure Rejected
        _ -> fail $ "Unknown entry status: " <> show t

-- ---------------------------------------------------------------------------
-- Core domain types
-- ---------------------------------------------------------------------------

data Competition = Competition
    { compId :: Text
    , compTitle :: Text
    , compSlug :: Text
    , compDescription :: Maybe Text
    , compTheme :: Maybe Text
    , compStatus :: CompetitionStatus
    , compStartDate :: Text
    , compEndDate :: Text
    , compMinImagesPerEntry :: Maybe Int
    , compMaxImagesPerEntry :: Maybe Int
    , compVotingEnabled :: Bool
    , compVotingRequired :: Bool
    , compVotingEndDate :: Maybe Text -- Nothing when not set
    }
    deriving (Show, Eq, Generic)

instance FromJSON Competition where
    parseJSON = withObject "Competition" $ \o ->
        Competition
            <$> o .: "id"
            <*> o .: "title"
            <*> o .: "slug"
            <*> o .:? "description"
            <*> o .:? "theme"
            <*> o .: "status"
            <*> o .: "start_date"
            <*> o .: "end_date"
            <*> o .:? "min_images_per_entry"
            <*> o .:? "max_images_per_entry"
            <*> (fromMaybe False <$> o .:? "voting_enabled")
            <*> (fromMaybe False <$> o .:? "voting_required")
            <*> (nonEmpty <$> o .:? "voting_end_date")
      where
        -- PocketBase sends an unset date as "".
        nonEmpty (Just t) | not (T.null t) = Just t
        nonEmpty _ = Nothing

data Entry = Entry
    { entryId :: Text
    , entryCompetition :: Text -- competition id
    , entrySubmitter :: Text -- user id
    , entryTitle :: Text
    , entryDescription :: Maybe Text
    , entryImages :: [Text] -- list of filenames
    , entryCoverIndex :: Int -- index into entryImages
    , entryStatus :: EntryStatus
    }
    deriving (Show, Eq, Generic)

instance FromJSON Entry where
    parseJSON = withObject "Entry" $ \o ->
        Entry
            <$> o .: "id"
            <*> o .: "competition"
            <*> o .: "submitter"
            <*> o .: "title"
            <*> o .:? "description"
            <*> o .: "images"
            <*> (fromMaybe 0 <$> o .:? "cover_image_index")
            <*> o .: "status"

data Review = Review
    { reviewId :: Text
    , reviewEntry :: Text -- entry id
    , reviewReviewer :: Text -- user id
    , reviewScores :: Map.Map Text Int -- criterion id -> score (1-5)
    , reviewComment :: Maybe Text
    , reviewIsPublished :: Bool
    }
    deriving (Show, Eq, Generic)

instance FromJSON Review where
    parseJSON = withObject "Review" $ \o ->
        Review
            <$> o .: "id"
            <*> o .: "entry"
            <*> o .: "reviewer"
            <*> o .: "scores"
            <*> o .:? "comment"
            <*> (fromMaybe False <$> o .:? "is_published")

-- ---------------------------------------------------------------------------
-- Ranking
-- ---------------------------------------------------------------------------

-- | An entry with its computed total score from all published reviews.
data RankedEntry = RankedEntry
    { rankedEntry :: Entry
    , rankedReviews :: [Review]
    , rankedTotalScore :: Int
    , rankedRank :: Int
    }
    deriving (Show, Eq, Generic)

{- | Rank entries by average published review score (descending).
Entries without any published reviews are listed last.
-}
rankEntries :: [(Entry, [Review])] -> [RankedEntry]
rankEntries pairs =
    let scored = map scoreEntry pairs
        sorted = map snd $ sortBy (comparing (Down . fst)) $ map (\re -> (rankedTotalScore re, re)) scored
        ranked = zipWith (\rank re -> re{rankedRank = rank}) [1 ..] sorted
     in ranked
  where
    scoreEntry (e, rs) =
        let published = filter reviewIsPublished rs
            total = sum $ map reviewTotal published
         in RankedEntry e rs total 0

    reviewTotal = sum . Map.elems . reviewScores

-- ---------------------------------------------------------------------------
-- Ranked voting (ADR-0007)
-- ---------------------------------------------------------------------------

-- | A voter's ballot: entry ids in preference order, 1st to at most 5th.
data Vote = Vote
    { voteCompetition :: Text
    , voteVoter :: Text -- profile id
    , voteRanking :: [Text]
    }
    deriving (Show, Eq, Generic)

instance FromJSON Vote where
    parseJSON = withObject "Vote" $ \o ->
        Vote
            <$> o .: "competition"
            <*> o .: "voter"
            <*> (fromMaybe [] <$> o .:? "ranking")

-- | An entry of the vote result.
data VoteRankedEntry = VoteRankedEntry
    { votedEntry :: Entry
    , votedPoints :: Int
    , votedPlace :: Int
    }
    deriving (Show, Eq, Generic)

-- | The places on a ballot.
maxRanks :: Int
maxRanks = 5

-- | Points of a place on the ballot: 1st = 8, 2nd = 5, 3rd = 3, 4th = 2, 5th = 1.
votePoints :: Int -> Int
votePoints place = case place of
    1 -> 8
    2 -> 5
    3 -> 3
    4 -> 2
    5 -> 1
    _ -> 0

{- | Count the ballots over the entries (a competition's approved ones), as the
Elm app's @Voting.tally@ does. Equal points are broken by the number of first
places, then of second places, and so on; entries equal in all of these share
a place and are listed by title. When voting is required (the first argument), an entry whose
submitter cast no ballot is left out.
-}
rankByVotes :: Bool -> [Entry] -> [Vote] -> [VoteRankedEntry]
rankByVotes required entries votes =
    let voters = Set.fromList (map voteVoter votes)
        counted = filter (\e -> not required || Set.member (entrySubmitter e) voters) entries
        countedIds = Set.fromList (map entryId counted)
        noPlaces = replicate maxRanks 0
        oneAt i = [if j == i then 1 else 0 | j <- [0 .. maxRanks - 1]]
        placeCounts =
            Map.fromListWith
                (zipWith (+))
                [ (eid, oneAt i)
                | v <- votes
                , (i, eid) <- zip [0 ..] (take maxRanks (voteRanking v))
                , Set.member eid countedIds
                ]
        total counts = sum (zipWith (*) counts (map votePoints [1 ..]))
        key e =
            let counts = Map.findWithDefault noPlaces (entryId e) placeCounts
             in (total counts, counts)
        sorted = sortOn (\(k, e) -> (Down k, entryTitle e, entryId e)) [(key e, e) | e <- counted]
        keys = map fst sorted
     in [ VoteRankedEntry e (fst k) (1 + length (filter (> k) keys))
        | (k, e) <- sorted
        ]

{- | True when the competition has voting and its voting period has ended.
@now@ is "YYYY-MM-DD HH:MM:SS" in UTC, compared with PocketBase's timestamp.
-}
votingClosed :: Text -> Competition -> Bool
votingClosed now comp =
    compVotingEnabled comp
        && maybe False (\end -> T.take 19 end <= now) (compVotingEndDate comp)

{-# LANGUAGE OverloadedStrings #-}

-- | Fetches and organises gallery data from PocketBase.
module GalleryFetcher
    ( GalleryData (..)
    , fetchGalleryData
    , resolveFileUrl
    , sortCompetitions
    , groupByCompetition
    ) where

import Data.Aeson (parseJSON)
import Data.Aeson.Types (parseMaybe)
import Data.List (sortBy)
import qualified Data.Map.Strict as Map
import Data.Ord (Down (..), comparing)
import Data.Text (Text)
import qualified Data.Text as T

import GalleryTypes
import PocketBase

-- ---------------------------------------------------------------------------
-- Gallery data bundle
-- ---------------------------------------------------------------------------

data GalleryData = GalleryData
    { gdCompetitions :: [Competition]           -- sorted by end_date desc
    , gdRankedByComp :: Map.Map Text [RankedEntry] -- comp id → ranked entries
    , gdDisplayNames :: Map.Map Text Text       -- user id → display name
    , gdPbUrl        :: Text
    } deriving (Show)

-- ---------------------------------------------------------------------------
-- Pure helpers
-- ---------------------------------------------------------------------------

-- | Build a PocketBase file download URL for an entry image.
-- Format: {pbUrl}/api/files/entries/{entryId}/{filename}
resolveFileUrl :: Text -> Text -> Text -> Text
resolveFileUrl pbUrl entryId_ filename =
    stripTrailingSlash pbUrl
    <> "/api/files/entries/"
    <> entryId_
    <> "/"
    <> filename
  where
    stripTrailingSlash t
        | T.isSuffixOf "/" t = T.dropEnd 1 t
        | otherwise          = t

-- | Sort competitions by end_date descending (most recently finished first).
-- Relies on lexicographic ordering of ISO-ish date strings.
sortCompetitions :: [Competition] -> [Competition]
sortCompetitions = sortBy (comparing (Down . compEndDate))

-- | Group entries by their competition id.
groupByCompetition :: [Entry] -> Map.Map Text [Entry]
groupByCompetition entries =
    Map.fromListWith (++)
        [ (entryCompetition e, [e]) | e <- entries ]

-- ---------------------------------------------------------------------------
-- IO: fetch everything from PocketBase
-- ---------------------------------------------------------------------------

-- | Fetch all gallery data from PocketBase.
-- Only approved entries and published reviews are included.
fetchGalleryData :: PbConfig -> IO GalleryData
fetchGalleryData cfg = do
    compsRaw   <- fetchAll cfg "competitions"
    entriesRaw <- fetchAll cfg "entries"
    reviewsRaw <- fetchAll cfg "reviews"

    let comps   = parseAll compsRaw   :: [Competition]
        entries = parseAll entriesRaw :: [Entry]
        reviews = parseAll reviewsRaw :: [Review]

        approvedEntries  = filter ((== Approved) . entryStatus) entries
        publishedReviews = filter reviewIsPublished reviews

        reviewsByEntry =
            Map.fromListWith (++)
                [ (reviewEntry r, [r]) | r <- publishedReviews ]

        entriesByComp = groupByCompetition approvedEntries

        rankedByComp =
            Map.map
                (\es -> rankEntries
                    [ (e, Map.findWithDefault [] (entryId e) reviewsByEntry)
                    | e <- es
                    ])
                entriesByComp

    return $ GalleryData
        { gdCompetitions = sortCompetitions comps
        , gdRankedByComp = rankedByComp
        , gdDisplayNames = Map.empty   -- populated separately if needed
        , gdPbUrl        = pbBaseUrl cfg
        }
  where
    parseAll vs = [ v' | Just v' <- map (parseMaybe parseJSON) vs ]

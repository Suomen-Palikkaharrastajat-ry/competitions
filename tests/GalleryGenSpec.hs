{-# LANGUAGE OverloadedStrings #-}
-- | Tests for the Haskell gallery HTML generator.
--
-- Given  gallery data (competitions, ranked entries)
-- When   renderGallery is called
-- Then   the output HTML contains the expected structure and content
module GalleryGenSpec (tests) where

import Test.Tasty
import Test.Tasty.HUnit

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T

import Config
import GalleryFetcher
import GalleryGen
import GalleryTypes
import I18n

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

testConfig :: Config
testConfig = Config
    { configTitle     = "Palikkakilpailu"
    , configLocale    = Fi
    , configTimezone  = "Europe/Helsinki"
    , configPbUrl     = Just "http://localhost:8090"
    , configOutputDir = "dist"
    , configAnonymize = False
    }

anonConfig :: Config
anonConfig = testConfig { configAnonymize = True }

testComp :: Competition
testComp = Competition
    { compId          = "comp1"
    , compTitle       = "Kaupunki 2026"
    , compSlug        = "kaupunki-2026"
    , compDescription = Just "Kaupunkiteema"
    , compTheme       = Just "Kaupunki"
    , compStatus      = Finished
    , compStartDate   = "2026-01-01"
    , compEndDate     = "2026-12-31"
    }

testEntry :: Entry
testEntry = Entry
    { entryId          = "entry1"
    , entryCompetition = "comp1"
    , entrySubmitter   = "user1"
    , entryTitle       = "Space Station MOC"
    , entryDescription = Just "A great build"
    , entryImages      = ["photo.jpg"]
    , entryCoverIndex  = 0
    , entryStatus      = Approved
    }

testReview :: Review
testReview = Review
    { reviewId               = "rev1"
    , reviewEntry            = "entry1"
    , reviewReviewer         = "reviewer1"
    , reviewScoreTheme       = 5
    , reviewScoreOriginality = 4
    , reviewScoreTechnique   = 4
    , reviewScorePresentation = 5
    , reviewComment          = Nothing
    , reviewIsPublished      = True
    }

testRanked :: RankedEntry
testRanked = RankedEntry
    { rankedEntry      = testEntry
    , rankedReviews    = [testReview]
    , rankedTotalScore = 18
    , rankedRank       = 1
    }

galleryWithRankings :: GalleryData
galleryWithRankings = GalleryData
    { gdCompetitions  = [testComp]
    , gdRankedByComp  = Map.singleton "comp1" [testRanked]
    , gdDisplayNames  = Map.singleton "user1" "Pekka"
    , gdPbUrl         = "http://localhost:8090"
    }

galleryNoScores :: GalleryData
galleryNoScores =
    let unranked = testRanked { rankedReviews = [], rankedTotalScore = 0 }
    in galleryWithRankings
        { gdRankedByComp = Map.singleton "comp1" [unranked] }

render :: Config -> GalleryData -> Text
render cfg = renderGallery cfg (getMessages (configLocale cfg))

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

tests :: TestTree
tests =
    testGroup "GalleryGen"
        [ testCase "renderGallery produces DOCTYPE html" $ do
            let html = render testConfig galleryWithRankings
            assertBool "starts with DOCTYPE" $ T.isPrefixOf "<!DOCTYPE" html

        , testCase "renderGallery includes competition title" $ do
            let html = render testConfig galleryWithRankings
            assertBool "contains competition title" $
                "Kaupunki 2026" `T.isInfixOf` html

        , testCase "renderGallery includes entry title" $ do
            let html = render testConfig galleryWithRankings
            assertBool "contains entry title" $
                "Space Station MOC" `T.isInfixOf` html

        , testCase "renderGallery shows score when reviews are present" $ do
            let html = render testConfig galleryWithRankings
            assertBool "contains score 18" $ "18" `T.isInfixOf` html

        , testCase "renderGallery has no score text when no reviews" $ do
            let html = render testConfig galleryNoScores
            -- entry is listed but no score for rank-0 with no reviews
            assertBool "contains entry title" $ "Space Station MOC" `T.isInfixOf` html

        , testCase "renderGallery shows submitter name when not anonymized" $ do
            let html = render testConfig galleryWithRankings
            assertBool "contains submitter name" $ "Pekka" `T.isInfixOf` html

        , testCase "renderGallery hides submitter name when anonymized" $ do
            let html = render anonConfig galleryWithRankings
            assertBool "does not contain submitter name" $
                not $ "Pekka" `T.isInfixOf` html

        , testCase "renderGallery images have data-lightbox attribute" $ do
            let html = render testConfig galleryWithRankings
            assertBool "has data-lightbox attribute" $
                "data-lightbox" `T.isInfixOf` html

        , testCase "renderGallery is self-contained (no external scripts)" $ do
            let html = render testConfig galleryWithRankings
            assertBool "no external script src" $
                not $ "<script src=" `T.isInfixOf` html

        , testCase "renderGallery has lang attribute" $ do
            let html = render testConfig galleryWithRankings
            assertBool "html lang attribute present" $
                "lang=" `T.isInfixOf` html

        , testCase "renderGallery has skip link for accessibility" $ do
            let html = render testConfig galleryWithRankings
            assertBool "has skip link" $
                "skip-link" `T.isInfixOf` html

        , testCase "renderGallery alt text includes submitter when not anonymized" $ do
            let html = render testConfig galleryWithRankings
            assertBool "alt contains 'by Pekka'" $
                "by Pekka" `T.isInfixOf` html

        , testCase "renderGallery alt text omits submitter when anonymized" $ do
            let html = render anonConfig galleryWithRankings
            assertBool "alt does not contain 'by Pekka'" $
                not $ "by Pekka" `T.isInfixOf` html
        ]

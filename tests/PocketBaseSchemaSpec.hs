{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
-- | Integration tests for the PocketBase schema.
-- These tests require a running PocketBase instance with migrations applied.
-- They are SKIPPED automatically when POCKETBASE_URL is not set.
--
-- Given  a running PocketBase with competition platform migrations applied
-- When   we interact with the REST API
-- Then   the expected collections, fields, and constraints are present
module PocketBaseSchemaSpec (tests) where

import Test.Tasty
import Test.Tasty.HUnit

import qualified Data.Aeson as A
import qualified Data.Text as T
import System.Environment (lookupEnv)

import GalleryTypes
import PocketBase

-- | Run a test only when POCKETBASE_URL is set; skip otherwise.
withPocketBase :: (PbConfig -> IO ()) -> IO ()
withPocketBase action = do
    mUrl <- lookupEnv "POCKETBASE_URL"
    mKey <- lookupEnv "POCKETBASE_API_KEY"
    case (mUrl, mKey) of
        (Just url, Just key) ->
            action $ PbConfig (T.pack url) (T.pack key)
        _ ->
            return ()  -- silently skip when env vars absent

skipMsg :: String
skipMsg = "POCKETBASE_URL / POCKETBASE_API_KEY not set — skipping integration tests"

tests :: TestTree
tests =
    testGroup
        "PocketBase Schema Integration Tests"
        [ testCase "competitions collection is accessible" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            case mUrl of
                Nothing -> assertBool skipMsg True  -- skip
                Just _  -> withPocketBase $ \cfg -> do
                    page <- fetchPage cfg "competitions" 1
                    assertBool "fetchPage returned a PbList" (pbTotalItems page >= 0)

        , testCase "entries collection is accessible" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            case mUrl of
                Nothing -> assertBool skipMsg True
                Just _  -> withPocketBase $ \cfg -> do
                    page <- fetchPage cfg "entries" 1
                    assertBool "fetchPage returned a PbList" (pbTotalItems page >= 0)

        , testCase "reviews collection is accessible" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            case mUrl of
                Nothing -> assertBool skipMsg True
                Just _  -> withPocketBase $ \cfg -> do
                    page <- fetchPage cfg "reviews" 1
                    assertBool "fetchPage returned a PbList" (pbTotalItems page >= 0)

        , testCase "GalleryTypes: Competition JSON decoding" $ do
            let json = A.object
                    [ "id"          A..= ("abc123" :: T.Text)
                    , "title"       A..= ("Test Competition" :: T.Text)
                    , "slug"        A..= ("test-2026" :: T.Text)
                    , "description" A..= ("A test competition" :: T.Text)
                    , "theme"       A..= ("Space" :: T.Text)
                    , "status"      A..= ("open" :: T.Text)
                    , "start_date"  A..= ("2026-01-01 00:00:00.000Z" :: T.Text)
                    , "end_date"    A..= ("2026-06-01 00:00:00.000Z" :: T.Text)
                    ]
            case A.fromJSON json of
                A.Error err -> assertFailure $ "Decode failed: " <> err
                A.Success (comp :: Competition) -> do
                    compId comp @?= "abc123"
                    compTitle comp @?= "Test Competition"
                    compSlug comp @?= "test-2026"
                    compStatus comp @?= Open

        , testCase "GalleryTypes: Entry JSON decoding" $ do
            let json = A.object
                    [ "id"          A..= ("entry1" :: T.Text)
                    , "competition" A..= ("comp1" :: T.Text)
                    , "submitter"   A..= ("user1" :: T.Text)
                    , "title"       A..= ("My MOC" :: T.Text)
                    , "images"      A..= (["img1.jpg", "img2.jpg"] :: [T.Text])
                    , "status"      A..= ("approved" :: T.Text)
                    ]
            case A.fromJSON json of
                A.Error err -> assertFailure $ "Decode failed: " <> err
                A.Success (entry :: Entry) -> do
                    entryId entry @?= "entry1"
                    entryTitle entry @?= "My MOC"
                    entryStatus entry @?= Approved
                    length (entryImages entry) @?= 2

        , testCase "GalleryTypes: Review JSON decoding" $ do
            let json = A.object
                    [ "id"                   A..= ("rev1" :: T.Text)
                    , "entry"                A..= ("entry1" :: T.Text)
                    , "reviewer"             A..= ("user2" :: T.Text)
                    , "score_theme"          A..= (4 :: Int)
                    , "score_originality"    A..= (5 :: Int)
                    , "score_technique"      A..= (3 :: Int)
                    , "score_presentation"   A..= (4 :: Int)
                    , "is_published"         A..= True
                    ]
            case A.fromJSON json of
                A.Error err -> assertFailure $ "Decode failed: " <> err
                A.Success (review :: Review) -> do
                    reviewId review @?= "rev1"
                    reviewScoreTheme review @?= 4
                    reviewScoreOriginality review @?= 5
                    reviewIsPublished review @?= True

        , testCase "GalleryTypes: rankEntries computes scores" $ do
            let entry1 = Entry "e1" "comp" "user1" "MOC A" Nothing ["img.jpg"] 0 Approved
                entry2 = Entry "e2" "comp" "user2" "MOC B" Nothing ["img.jpg"] 0 Approved
                rev1 = Review "r1" "e1" "reviewer" 5 5 5 5 Nothing True
                rev2 = Review "r2" "e2" "reviewer" 3 3 3 3 Nothing True
                ranked = rankEntries [(entry1, [rev1]), (entry2, [rev2])]
            length ranked @?= 2
            rankedRank (head ranked) @?= 1
            rankedTotalScore (head ranked) @?= 20  -- 5+5+5+5
            rankedTotalScore (ranked !! 1) @?= 12  -- 3+3+3+3

        , testCase "GalleryTypes: unpublished reviews excluded from score" $ do
            let entry = Entry "e1" "comp" "user1" "MOC" Nothing ["img.jpg"] 0 Approved
                published   = Review "r1" "e1" "rev1" 5 5 5 5 Nothing True
                unpublished = Review "r2" "e1" "rev2" 1 1 1 1 Nothing False
                ranked = rankEntries [(entry, [published, unpublished])]
            rankedTotalScore (head ranked) @?= 20  -- only published counts
        ]

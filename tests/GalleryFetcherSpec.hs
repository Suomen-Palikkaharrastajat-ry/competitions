{-# LANGUAGE OverloadedStrings #-}
-- | Unit tests for GalleryFetcher pure functions.
--
-- Given  lists of competitions / entries
-- When   sortCompetitions / resolveFileUrl / groupByCompetition are called
-- Then   results match expectations
module GalleryFetcherSpec (tests) where

import Test.Tasty
import Test.Tasty.HUnit

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T

import qualified Data.Aeson as A

import GalleryFetcher
import GalleryTypes

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

-- | Build a minimal Competition fixture.
-- First argument: competition id. Second argument: endDate.
-- startDate is always fixed at "2026-01-01" for test purposes.
mkComp :: Text -> Text -> Competition
mkComp cid =
    Competition cid ("Title " <> cid) ("slug-" <> cid) Nothing Nothing Open "2026-01-01"

mkEntry :: Text -> Text -> Entry
mkEntry eid cid =
    Entry eid cid "user1" "My MOC" Nothing ["photo.jpg"] 0 Approved

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

tests :: TestTree
tests =
    testGroup "GalleryFetcher"
        [ testCase "resolveFileUrl builds PocketBase file URL" $ do
            let url = resolveFileUrl "http://localhost:8090" "entry123" "photo.jpg"
            url @?= "http://localhost:8090/api/files/entries/entry123/photo.jpg"

        , testCase "resolveFileUrl handles trailing slash in pbUrl" $ do
            let url = resolveFileUrl "http://localhost:8090/" "e1" "img.png"
            -- should not double-slash
            assertBool "no double slash" $ not $ T.isInfixOf "//" (T.drop 8 url)

        , testCase "sortCompetitions orders by end_date descending" $ do
            let c1 = mkComp "c1" "2026-01-01"
                c2 = mkComp "c2" "2026-12-31"
                c3 = mkComp "c3" "2026-06-15"
                sorted = sortCompetitions [c1, c2, c3]
            map compId sorted @?= ["c2", "c3", "c1"]

        , testCase "sortCompetitions single element unchanged" $ do
            let c = mkComp "c1" "2026-01-01"
            sortCompetitions [c] @?= [c]

        , testCase "sortCompetitions empty list unchanged" $
            sortCompetitions [] @?= []

        , testCase "groupByCompetition groups entries by competition" $ do
            let e1 = mkEntry "e1" "comp1"
                e2 = mkEntry "e2" "comp1"
                e3 = mkEntry "e3" "comp2"
                grouped = groupByCompetition [e1, e2, e3]
            length (Map.findWithDefault [] "comp1" grouped) @?= 2
            length (Map.findWithDefault [] "comp2" grouped) @?= 1

        , testCase "groupByCompetition empty list gives empty map" $
            groupByCompetition [] @?= Map.empty

        -- Given a list of raw PocketBase user records
        -- When parseDisplayNames is called
        -- Then a map of user id -> display_name is returned
        , testCase "parseDisplayNames builds user id -> display_name map" $ do
            let userJson = A.object
                    [ "id"           A..= ("user1" :: T.Text)
                    , "display_name" A..= ("Alice Smith" :: T.Text)
                    ]
            Map.lookup "user1" (parseDisplayNames [userJson]) @?= Just "Alice Smith"

        , testCase "parseDisplayNames skips records without display_name" $ do
            let userJson = A.object [ "id" A..= ("user2" :: T.Text) ]
            Map.lookup "user2" (parseDisplayNames [userJson]) @?= Nothing

        , testCase "parseDisplayNames skips empty display_name" $ do
            let userJson = A.object
                    [ "id"           A..= ("user3" :: T.Text)
                    , "display_name" A..= ("" :: T.Text)
                    ]
            Map.lookup "user3" (parseDisplayNames [userJson]) @?= Nothing
        ]

{-# LANGUAGE OverloadedStrings #-}

{- | Unit tests for GalleryFetcher pure functions.

Given  lists of competitions / entries
When   sortCompetitions / resolveFileUrl / groupByCompetition are called
Then   results match expectations
-}
module GalleryFetcherSpec (tests) where

import Test.Tasty
import Test.Tasty.HUnit

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T

import qualified Data.Aeson as A

import GalleryFetcher
import GalleryTypes
import PocketBase (PbConfig (..))

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

{- | Build a minimal Competition fixture.
First argument: competition id. Second argument: endDate.
startDate is always fixed at "2026-01-01" for test purposes.
-}
mkComp :: Text -> Text -> Competition
mkComp cid endDate =
    Competition cid ("Title " <> cid) ("slug-" <> cid) Nothing Nothing Open "2026-01-01" endDate Nothing Nothing False False Nothing

-- | A competition whose voting ends at the given time (PocketBase format).
mkVotingComp :: Text -> Bool -> Text -> Competition
mkVotingComp cid required votingEnd =
    (mkComp cid "2026-07-01")
        { compVotingEnabled = True
        , compVotingRequired = required
        , compVotingEndDate = Just votingEnd
        }

mkSubmitted :: Text -> Text -> Entry
mkSubmitted eid submitter = (mkEntry eid "comp1"){entrySubmitter = submitter}

mkVote :: Text -> [Text] -> Vote
mkVote = Vote "comp1"

placesAndPoints :: [VoteRankedEntry] -> [(Int, Text, Int)]
placesAndPoints = map (\r -> (votedPlace r, entryId (votedEntry r), votedPoints r))

mkEntry :: Text -> Text -> Entry
mkEntry eid cid =
    Entry eid cid "user1" "My MOC" Nothing ["photo.jpg"] 0 Approved

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

tests :: TestTree
tests =
    testGroup
        "GalleryFetcher"
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
        , -- Given a list of raw PocketBase user records
          -- When parseDisplayNames is called
          -- Then a map of user id -> display_name is returned
          testCase "parseDisplayNames builds user id -> display_name map" $ do
            let userJson =
                    A.object
                        [ "id" A..= ("user1" :: T.Text)
                        , "display_name" A..= ("Alice Smith" :: T.Text)
                        ]
            Map.lookup "user1" (parseDisplayNames [userJson]) @?= Just "Alice Smith"
        , testCase "parseDisplayNames skips records without display_name" $ do
            let userJson = A.object ["id" A..= ("user2" :: T.Text)]
            Map.lookup "user2" (parseDisplayNames [userJson]) @?= Nothing
        , testCase "parseDisplayNames skips empty display_name" $ do
            let userJson =
                    A.object
                        [ "id" A..= ("user3" :: T.Text)
                        , "display_name" A..= ("" :: T.Text)
                        ]
            Map.lookup "user3" (parseDisplayNames [userJson]) @?= Nothing
        , -- Given a PocketBase config without a superuser token
          -- When gallery data is fetched
          -- Then auth-collection display names are skipped instead of breaking public gallery generation
          testCase "shouldFetchDisplayNames is false without API token" $
            shouldFetchDisplayNames (PbConfig "http://localhost:8090" "") @?= False
        , testCase "shouldFetchDisplayNames ignores whitespace-only API token" $
            shouldFetchDisplayNames (PbConfig "http://localhost:8090" "  ") @?= False
        , testCase "shouldFetchDisplayNames is true with API token" $
            shouldFetchDisplayNames (PbConfig "http://localhost:8090" "token") @?= True
        , -- Given the ballots of a competition (ADR-0007)
          -- When the votes are counted
          -- Then the 1st-5th choices give 8, 5, 3, 2, 1 points, as in the Elm app
          testCase "rankByVotes sums 8-5-3-2-1 points, best first" $
            placesAndPoints
                ( rankByVotes
                    False
                    [mkSubmitted "a" "pa", mkSubmitted "b" "pb", mkSubmitted "c" "pc"]
                    [mkVote "v1" ["a", "b"], mkVote "v2" ["b", "c", "a"]]
                )
                @?= [(1, "b", 13), (2, "a", 11), (3, "c", 5)]
        , testCase "rankByVotes breaks equal points by first places" $
            take
                2
                ( placesAndPoints
                    ( rankByVotes
                        False
                        [mkSubmitted "a" "pa", mkSubmitted "b" "pb", mkSubmitted "x" "px", mkSubmitted "y" "py"]
                        [mkVote "v1" ["b", "a"], mkVote "v2" ["x", "a", "y", "b"]]
                    )
                )
                @?= [(1, "b", 10), (2, "a", 10)]
        , testCase "rankByVotes lets fully equal entries share a place" $
            placesAndPoints
                (rankByVotes False [mkSubmitted "a" "pa", mkSubmitted "b" "pb"] [mkVote "v1" ["a", "b"], mkVote "v2" ["b", "a"]])
                @?= [(1, "a", 13), (1, "b", 13)]
        , testCase "rankByVotes ignores choices of entries not in the competition" $
            placesAndPoints (rankByVotes False [mkSubmitted "a" "pa"] [mkVote "v1" ["gone", "a"]])
                @?= [(1, "a", 5)]
        , testCase "rankByVotes leaves out non-voters' entries when voting is required" $
            placesAndPoints (rankByVotes True [mkSubmitted "a" "pa", mkSubmitted "b" "pb"] [mkVote "pa" ["b", "a"]])
                @?= [(1, "a", 5)]
        , -- Given competitions with voting
          -- When the gallery is built
          -- Then only votes whose voting period has ended are counted
          testCase "votingClosed is true only after the voting end" $ do
            let comp = mkVotingComp "comp1" False "2026-07-15 00:00:00.000Z"
            votingClosed "2026-07-14 23:59:59" comp @?= False
            votingClosed "2026-07-15 00:00:00" comp @?= True
            votingClosed "2026-07-15 00:00:00" comp{compVotingEnabled = False} @?= False
            votingClosed "2026-07-15 00:00:00" comp{compVotingEndDate = Nothing} @?= False
        , testCase "voteResults counts only competitions whose voting has ended" $ do
            let ended = mkVotingComp "comp1" False "2026-07-15 00:00:00.000Z"
                running = mkVotingComp "comp2" False "2099-01-01 00:00:00.000Z"
                entries = [mkEntry "e1" "comp1", mkEntry "e2" "comp2"]
                votes = [Vote "comp1" "v1" ["e1"], Vote "comp2" "v1" ["e2"]]
                results = voteResults "2026-10-18 12:00:00" [ended, running] entries votes
            Map.keys results @?= ["comp1"]
            map votedPoints (Map.findWithDefault [] "comp1" results) @?= [8]
        , testCase "voteResults gives no result for an ended vote without ballots" $ do
            let ended = mkVotingComp "comp1" False "2026-07-15 00:00:00.000Z"
            voteResults "2026-10-18 12:00:00" [ended] [mkEntry "e1" "comp1"] [] @?= Map.empty
        , testCase "rankByVotes lists entries sharing a place by title" $
            map
                (\r -> (votedPlace r, entryTitle (votedEntry r)))
                (rankByVotes False [(mkSubmitted "b" "pb"){entryTitle = "Zeta"}, (mkSubmitted "a" "pa"){entryTitle = "Alpha"}] [mkVote "v1" []])
                @?= [(1, "Alpha"), (1, "Zeta")]
        , testCase "Vote decodes a ballot, a null ranking as empty" $ do
            A.decode "{\"competition\":\"c1\",\"voter\":\"p1\",\"ranking\":[\"e1\",\"e2\"]}" @?= Just (Vote "c1" "p1" ["e1", "e2"])
            A.decode "{\"competition\":\"c1\",\"voter\":\"p1\",\"ranking\":null}" @?= Just (Vote "c1" "p1" [])
        , testCase "Competition decodes the voting settings, an empty end date as none" $ do
            let json = "{\"id\":\"c1\",\"title\":\"T\",\"slug\":\"t\",\"status\":\"finished\",\"start_date\":\"2026-01-01\",\"end_date\":\"2026-02-01\",\"voting_enabled\":true,\"voting_required\":true,\"voting_end_date\":\"\"}"
            fmap (\c -> (compVotingEnabled c, compVotingRequired c, compVotingEndDate c)) (A.decode json)
                @?= Just (True, True, Nothing)
        ]

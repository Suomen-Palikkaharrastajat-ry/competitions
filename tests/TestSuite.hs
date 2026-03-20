{-# LANGUAGE OverloadedStrings #-}
module Main (main, tests) where

import Test.Tasty
import Test.Tasty.HUnit

import qualified Data.Text as T
import Data.Time.Format (TimeLocale (..), defaultTimeLocale)
import Text.HTML.TagSoup (Tag (..))
import Text.HTML.TagSoup.Tree (TagTree (..))

import Config
import HtmlSanitizer
import I18n
import PocketBase (urlEncodeFilter)
import qualified GalleryFetcherSpec
import qualified GalleryGenSpec
import qualified PocketBaseSchemaSpec

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
    testGroup
        "Competition Tests"
        [ configTests
        , i18nTests
        , htmlSanitizerTests
        , pocketBaseTests
        , PocketBaseSchemaSpec.tests
        , GalleryFetcherSpec.tests
        , GalleryGenSpec.tests
        ]

-- ---------------------------------------------------------------------------
-- Config tests (compile-time proof: Config has no FeedConfig field)
-- ---------------------------------------------------------------------------

configTests :: TestTree
configTests =
    testGroup
        "Config Tests"
        [ testCase "parseConfig valid competition.toml" $ do
            let toml =
                    T.unlines
                        [ "title = \"Palikkakilpailu\""
                        , "locale = \"fi\""
                        , "timezone = \"Europe/Helsinki\""
                        ]
            case parseConfig toml of
                Right config -> do
                    configTitle config @?= T.pack "Palikkakilpailu"
                    configLocale config @?= Fi
                    configTimezone config @?= T.pack "Europe/Helsinki"
                    configPbUrl config @?= Nothing
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        , testCase "parseConfig defaults when empty" $ do
            let toml = T.pack ""
            case parseConfig toml of
                Right config -> do
                    configTitle config @?= T.pack "Palikkakilpailu"
                    configLocale config @?= Fi
                    configTimezone config @?= T.pack "Europe/Helsinki"
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        , testCase "parseConfig English locale" $ do
            let toml = T.unlines ["title = \"Test\"", "locale = \"en\""]
            case parseConfig toml of
                Right config -> configLocale config @?= En
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        , testCase "parseConfig pocketbase_url" $ do
            let toml = T.unlines ["pocketbase_url = \"http://localhost:8090\""]
            case parseConfig toml of
                Right config -> configPbUrl config @?= Just (T.pack "http://localhost:8090")
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        ]

-- ---------------------------------------------------------------------------
-- I18n tests
-- ---------------------------------------------------------------------------

i18nTests :: TestTree
i18nTests =
    testGroup
        "I18n Tests"
        [ testCase "parseLocale fi" $ parseLocale (T.pack "fi") @?= Fi
        , testCase "parseLocale en" $ parseLocale (T.pack "en") @?= En
        , testCase "parseLocale unknown defaults to fi" $ parseLocale (T.pack "unknown") @?= Fi
        , testCase "defaultLocale is Fi" $ defaultLocale @?= Fi
        , testCase "getMessages Fi competition label" $
            msgCompetition (getMessages Fi) @?= T.pack "Kilpailu"
        , testCase "getMessages En competition label" $
            msgCompetition (getMessages En) @?= T.pack "Competition"
        , testCase "getMessages Fi skipToContent" $
            msgSkipToContent (getMessages Fi) @?= T.pack "Siirry pääsisältöön"
        , testCase "getTimeLocale Fi has Finnish months" $
            head (months (getTimeLocale Fi)) @?= ("tammikuu", "tammi")
        , testCase "getTimeLocale En is default" $
            wDays (getTimeLocale En) @?= wDays defaultTimeLocale
        ]

-- ---------------------------------------------------------------------------
-- HtmlSanitizer tests (kept: sanitiser is reused for entry descriptions)
-- ---------------------------------------------------------------------------

htmlSanitizerTests :: TestTree
htmlSanitizerTests =
    testGroup
        "HtmlSanitizer Tests"
        [ testCase "cleanAndTruncate short text unchanged" $ do
            let txt = T.pack "<p>Short text</p>"
            cleanAndTruncate 100 txt @?= T.pack "<p>Short text</p>"
        , testCase "cleanAndTruncate long text is truncated" $ do
            let txt = T.pack $ "<p>" ++ replicate 300 'a' ++ "</p>"
            let result = cleanAndTruncate 160 txt
            assertBool "Truncated" (T.length result < T.length txt)
            assertBool "Contains ..." (T.isInfixOf (T.pack "...") result)
        , testCase "normalizeVoids adds closing tag for img" $ do
            let tags = [TagOpen (T.pack "img") [(T.pack "src", T.pack "test")]]
                normalized = normalizeVoids tags
            length normalized @?= 2
        , testCase "pruneTree removes empty div" $ do
            let tree = [TagBranch (T.pack "div") [] []]
                pruned = pruneTree tree
            length pruned @?= 0
        , testCase "pruneTree keeps div with content" $ do
            let tree = [TagBranch (T.pack "p") [] [TagLeaf (TagText (T.pack "content"))]]
                pruned = pruneTree tree
            length pruned @?= 1
        ]

-- ---------------------------------------------------------------------------
-- PocketBase utility tests (no live PocketBase required)
-- ---------------------------------------------------------------------------

pocketBaseTests :: TestTree
pocketBaseTests =
    testGroup
        "PocketBase Utility Tests"
        [ testCase "urlEncodeFilter encodes special chars" $ do
            let result = urlEncodeFilter (T.pack "link=\"https://example.com\"")
            assertBool "contains %3D" $ T.isInfixOf (T.pack "%3D") result
            assertBool "contains %22" $ T.isInfixOf (T.pack "%22") result
            assertBool "contains %3A" $ T.isInfixOf (T.pack "%3A") result
            assertBool "contains %2F" $ T.isInfixOf (T.pack "%2F") result
        , testCase "urlEncodeFilter keeps alphanumeric unchanged" $ do
            let result = urlEncodeFilter (T.pack "abc123")
            result @?= T.pack "abc123"
        , testCase "urlEncodeFilter keeps safe chars unchanged" $ do
            let result = urlEncodeFilter (T.pack "-_.~")
            result @?= T.pack "-_.~"
        ]

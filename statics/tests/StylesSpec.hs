{-# LANGUAGE OverloadedStrings #-}

{- | Tests for the gallery's design tokens.

Given  the tokens the gallery declares (Styles.tokens)
When   they are compared with the hub's design-tokens.css
Then   every name exists there with the same value, and the CSS uses
       colours only through those tokens
-}
module StylesSpec (tests) where

import Test.Tasty
import Test.Tasty.HUnit

import Control.Monad (filterM, forM_)
import Data.Char (isHexDigit)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.Directory (doesFileExist)

import Styles (css, tokens)

-- | Where the hub's tokens are, seen from the repository root or statics/.
tokenFiles :: [FilePath]
tokenFiles =
    [ "vendor/master-builder/packages/design-tokens/design-tokens.css"
    , "../vendor/master-builder/packages/design-tokens/design-tokens.css"
    ]

-- | `--name: value;` declarations of a CSS file.
declarations :: Text -> Map.Map Text Text
declarations content =
    Map.fromList
        [ (T.strip name, normalize value)
        | line <- T.lines content
        , let (name, rest) = T.breakOn ":" (T.strip line)
        , "--" `T.isPrefixOf` name
        , not (T.null rest)
        , let value = T.dropWhileEnd (== ';') (T.strip (T.drop 1 rest))
        ]

normalize :: Text -> Text
normalize = T.toUpper . T.filter (/= ' ')

tests :: TestTree
tests =
    testGroup
        "Styles"
        [ testCase "tokens match the hub's design-tokens.css" $ do
            found <- filterM doesFileExist tokenFiles
            case found of
                -- Not available in a sandboxed package build of statics/
                -- alone; `make statics-test` runs it with the hub vendored.
                [] -> pure ()
                path : _ -> do
                    hub <- declarations <$> TIO.readFile path
                    forM_ tokens $ \(name, value) ->
                        Map.lookup name hub @?= Just (normalize value)
        , testCase "the CSS has no colour literals outside the tokens" $ do
            let tokenLines = [name <> ": " <> value <> ";" | (name, value) <- tokens]
                ruleLines = filter (\line -> T.strip line `notElem` tokenLines) (T.lines css)
                hexColour word = "#" `T.isPrefixOf` word && T.length word >= 4 && T.all isHexDigit (T.take 3 (T.drop 1 word))
            filter (any hexColour . T.words . T.map (\c -> if c `elem` (";(),{}" :: String) then ' ' else c)) ruleLines @?= []
        ]

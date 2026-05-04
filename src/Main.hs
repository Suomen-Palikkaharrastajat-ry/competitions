{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.Directory (createDirectoryIfMissing)
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.FilePath ((</>))

import Config
import GalleryFetcher
import GalleryGen
import I18n
import PocketBase

main :: IO ()
main = do
    tomlContent <- TIO.readFile "competition.toml"
    config <- case parseConfig tomlContent of
        Left err -> do
            putStrLn $ "Error parsing competition.toml: " <> T.unpack err
            exitFailure
        Right c -> return c

    pbCfgFromEnv <- loadPbConfig
    let pbUrl = case (configPbUrl config, pbCfgFromEnv) of
                    (Just u, _)       -> u
                    (Nothing, Just c) -> pbBaseUrl c
                    (Nothing, Nothing) -> T.pack "https://data.palikkaharrastajat.fi"
        pbToken = case pbCfgFromEnv of
                      Just c  -> pbApiToken c
                      Nothing -> T.pack ""

    mApiKey <- lookupEnv "POCKETBASE_API_KEY"
    let token = maybe pbToken T.pack mApiKey

    let pbCfg = PbConfig pbUrl token
    let msgs  = getMessages (configLocale config)

    putStrLn "Fetching gallery data..."
    gd <- fetchGalleryData pbCfg

    putStrLn "Rendering gallery..."
    let html = renderGallery config msgs gd

    let outDir  = configOutputDir config
        outFile = outDir </> "index.html"
    createDirectoryIfMissing True outDir
    TIO.writeFile outFile html
    putStrLn $ "Gallery written to " <> outFile

{-# LANGUAGE OverloadedStrings #-}

-- | Generates the static public gallery HTML from competition data.
module GalleryGen (renderGallery) where

import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Text.Blaze.Html5 ((!))
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as HA
import Text.Blaze.Html.Renderer.Text (renderHtml)

import Config
import GalleryFetcher
import GalleryTypes
import I18n
import Scripts (js)
import Styles (css)

-- ---------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------

-- | Render the full gallery as a self-contained HTML document.
renderGallery :: Config -> Messages -> GalleryData -> Text
renderGallery config msgs gd =
    TL.toStrict $ renderHtml $ galleryHtml config msgs gd

-- ---------------------------------------------------------------------------
-- HTML document
-- ---------------------------------------------------------------------------

langAttr :: Locale -> H.AttributeValue
langAttr Fi = "fi"
langAttr En = "en"

galleryHtml :: Config -> Messages -> GalleryData -> H.Html
galleryHtml config msgs gd = do
    H.docType
    H.html ! HA.lang (langAttr (configLocale config)) $ do
        H.head $ do
            H.meta ! HA.charset "utf-8"
            H.meta ! HA.name "viewport"
                   ! HA.content "width=device-width, initial-scale=1"
            H.title $ H.toHtml (configTitle config)
            H.link ! HA.rel "preconnect"
                   ! HA.href "https://fonts.googleapis.com"
            H.link ! HA.rel "preconnect"
                   ! HA.href "https://fonts.gstatic.com"
                   ! H.dataAttribute "crossorigin" ""
            H.link ! HA.rel "stylesheet"
                   ! HA.href "https://fonts.googleapis.com/css2?family=Outfit:wght@100..900&display=swap"
            H.style $ H.toHtml css
        H.body $ do
            H.a ! HA.href "#main-content"
                ! HA.class_ "skip-link"
                $ H.toHtml (msgSkipToContent msgs)
            H.header ! HA.class_ "site-header" $ do
                H.div ! HA.class_ "header-inner" $ do
                    H.h1 $ H.toHtml (configTitle config)
            H.main ! HA.id "main-content" $ do
                mapM_ (renderCompetitionSection config msgs gd)
                    (gdCompetitions gd)
            H.footer ! HA.class_ "site-footer" $ do
                H.p $ do
                    H.toHtml (msgGeneratedOn msgs <> " ")
                    H.toHtml (msgPoweredBy msgs)
            H.script $ H.toHtml js

-- ---------------------------------------------------------------------------
-- Competition section
-- ---------------------------------------------------------------------------

renderCompetitionSection :: Config -> Messages -> GalleryData -> Competition -> H.Html
renderCompetitionSection config msgs gd comp = do
    let ranked  = fromMaybe [] $ Map.lookup (compId comp) (gdRankedByComp gd)
        hasScores = any (not . null . rankedReviews) ranked
    H.section ! HA.class_ "competition-section"
              ! HA.id (H.toValue (compSlug comp)) $ do
        H.h2 ! HA.class_ "competition-title" $ H.toHtml (compTitle comp)
        case compDescription comp of
            Just desc -> H.p ! HA.class_ "competition-desc" $ H.toHtml desc
            Nothing   -> return ()
        if hasScores
            then renderPodium config msgs gd (take 3 ranked)
            else return ()
        H.div ! HA.class_ "entry-grid" $
            mapM_ (renderEntryCard config msgs gd) ranked

-- ---------------------------------------------------------------------------
-- Winner podium (top 3)
-- ---------------------------------------------------------------------------

renderPodium :: Config -> Messages -> GalleryData -> [RankedEntry] -> H.Html
renderPodium config msgs gd top3 = do
    H.div ! HA.class_ "podium" $ do
        H.h3 ! HA.class_ "podium-title" $ H.toHtml (msgWinners msgs)
        H.ol ! HA.class_ "podium-list" $
            mapM_ (renderPodiumItem config msgs gd) top3

renderPodiumItem :: Config -> Messages -> GalleryData -> RankedEntry -> H.Html
renderPodiumItem config msgs gd re = do
    let entry    = rankedEntry re
        score    = rankedTotalScore re
        rank     = rankedRank re
        imgUrl   = coverImageUrl (gdPbUrl gd) entry
        submitter = submitterName config msgs gd entry
    H.li ! HA.class_ (H.toValue ("podium-item rank-" <> show rank)) $ do
        H.span ! HA.class_ "podium-rank"
               $ H.toHtml (show rank <> ".")
        case imgUrl of
            Just url -> H.img ! HA.src (H.toValue url)
                              ! HA.alt (H.toValue (entryTitle entry))
                              ! HA.class_ "podium-img"
                              ! H.dataAttribute "lightbox" (H.toValue url)
            Nothing  -> return ()
        H.div ! HA.class_ "podium-info" $ do
            H.span ! HA.class_ "podium-entry-title"
                   $ H.toHtml (entryTitle entry)
            H.span ! HA.class_ "podium-score" $ do
                H.toHtml (msgScore msgs <> ": ")
                H.toHtml (show score)
            case submitter of
                Just name -> H.span ! HA.class_ "podium-submitter"
                                    $ H.toHtml name
                Nothing   -> return ()

-- ---------------------------------------------------------------------------
-- Entry card
-- ---------------------------------------------------------------------------

renderEntryCard :: Config -> Messages -> GalleryData -> RankedEntry -> H.Html
renderEntryCard config msgs gd re = do
    let entry     = rankedEntry re
        score     = rankedTotalScore re
        hasScore  = not (null (rankedReviews re))
        imgUrl    = coverImageUrl (gdPbUrl gd) entry
        submitter = submitterName config msgs gd entry
    H.article ! HA.class_ "entry-card" $ do
        case imgUrl of
            Just url ->
                H.div ! HA.class_ "entry-img-wrap" $
                    H.img ! HA.src (H.toValue url)
                          ! HA.alt (H.toValue (entryTitle entry))
                          ! HA.class_ "entry-img"
                          ! H.dataAttribute "lightbox" (H.toValue url)
            Nothing  -> return ()
        H.div ! HA.class_ "entry-body" $ do
            H.h3 ! HA.class_ "entry-title" $ H.toHtml (entryTitle entry)
            case entryDescription entry of
                Just desc -> H.p ! HA.class_ "entry-desc" $ H.toHtml desc
                Nothing   -> return ()
            case submitter of
                Just name ->
                    H.p ! HA.class_ "entry-submitter" $ H.toHtml name
                Nothing   -> return ()
            if hasScore
                then H.p ! HA.class_ "entry-score" $ do
                    H.toHtml (msgScore msgs <> ": ")
                    H.toHtml (show score)
                else return ()

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

coverImageUrl :: Text -> Entry -> Maybe Text
coverImageUrl pbUrl entry =
    case entryImages entry of
        []     -> Nothing
        imgs   ->
            let idx  = min (entryCoverIndex entry) (length imgs - 1)
                fname = imgs !! idx
            in Just $ resolveFileUrl pbUrl (entryId entry) fname

submitterName :: Config -> Messages -> GalleryData -> Entry -> Maybe Text
submitterName config msgs gd entry
    | configAnonymize config = Nothing
    | otherwise =
        let uid   = entrySubmitter entry
            name  = Map.lookup uid (gdDisplayNames gd)
            prefix = msgBy msgs
        in case name of
               Nothing -> Nothing
               Just n  ->
                   if T.null prefix
                       then Just n
                       else Just (prefix <> " " <> n)

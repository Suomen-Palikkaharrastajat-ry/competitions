{-# LANGUAGE OverloadedStrings #-}

-- | Generates the static public gallery HTML from competition data.
module GalleryGen (renderGallery) where

import Control.Monad (unless, when)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Text.Blaze.Html.Renderer.Text (renderHtml)
import Text.Blaze.Html5 ((!))
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as HA

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
            H.meta
                ! HA.name "viewport"
                ! HA.content "width=device-width, initial-scale=1"
            H.title $ H.toHtml (configTitle config)
            H.link
                ! HA.rel "preconnect"
                ! HA.href "https://fonts.googleapis.com"
            H.link
                ! HA.rel "preconnect"
                ! HA.href "https://fonts.gstatic.com"
                ! H.dataAttribute "crossorigin" ""
            H.link
                ! HA.rel "stylesheet"
                ! HA.href "https://fonts.googleapis.com/css2?family=Outfit:wght@100..900&display=swap"
            H.style $ H.toHtml css
        H.body $ do
            H.a
                ! HA.href "#main-content"
                ! HA.class_ "skip-link"
                $ H.toHtml (msgSkipToContent msgs)
            H.header ! HA.class_ "site-header" $
                H.div ! HA.class_ "header-inner" $
                    H.h1 $
                        H.toHtml (configTitle config)
            H.main ! HA.id "main-content" $
                mapM_
                    (renderCompetitionSection config msgs gd)
                    (gdCompetitions gd)
            H.footer ! HA.class_ "site-footer" $
                H.p $ do
                    H.toHtml (msgGeneratedOn msgs <> " ")
                    H.toHtml (msgPoweredBy msgs)
            H.div
                ! HA.id "lightbox"
                ! H.customAttribute "role" "dialog"
                ! H.customAttribute "aria-modal" "true"
                ! H.customAttribute "aria-label" "Image viewer"
                ! HA.tabindex "-1"
                $ H.img ! HA.alt ""
            H.script $ H.toHtml js

-- ---------------------------------------------------------------------------
-- Competition section
-- ---------------------------------------------------------------------------

renderCompetitionSection :: Config -> Messages -> GalleryData -> Competition -> H.Html
renderCompetitionSection config msgs gd comp = do
    let ranked = fromMaybe [] $ Map.lookup (compId comp) (gdRankedByComp gd)
        hasScores = not (all (null . rankedReviews) ranked)
    H.section
        ! HA.class_ "competition-section"
        ! HA.id (H.toValue (compSlug comp))
        $ do
            H.h2 ! HA.class_ "competition-title" $ H.toHtml (compTitle comp)
            case compDescription comp of
                Just desc -> H.p ! HA.class_ "competition-desc" $ H.toHtml desc
                Nothing -> return ()
            when hasScores $
                renderPodium config msgs gd (take 3 ranked)
            H.div ! HA.class_ "entry-grid" $
                mapM_ (renderEntryCard config msgs gd) ranked

-- ---------------------------------------------------------------------------
-- Winner podium (top 3)
-- ---------------------------------------------------------------------------

renderPodium :: Config -> Messages -> GalleryData -> [RankedEntry] -> H.Html
renderPodium config msgs gd top3 =
    H.div ! HA.class_ "podium" $ do
        H.h3 ! HA.class_ "podium-title" $ H.toHtml (msgWinners msgs)
        H.ol ! HA.class_ "podium-list" $
            mapM_ (renderPodiumItem config msgs gd) top3

renderPodiumItem :: Config -> Messages -> GalleryData -> RankedEntry -> H.Html
renderPodiumItem config msgs gd re = do
    let entry = rankedEntry re
        score = rankedTotalScore re
        rank = rankedRank re
        imgUrl = coverImageUrl (gdPbUrl gd) entry
        submitter = submitterName config msgs gd entry
    H.li ! HA.class_ (H.toValue ("podium-item rank-" <> show rank)) $ do
        H.span ! HA.class_ "podium-rank" $
            H.toHtml (show rank <> ".")
        case imgUrl of
            Just url ->
                H.img
                    ! HA.src (H.toValue url)
                    ! HA.alt (H.toValue (altText config gd entry (entryTitle entry)))
                    ! HA.class_ "podium-img"
                    ! H.dataAttribute "lightbox" (H.toValue url)
            Nothing -> return ()
        H.div ! HA.class_ "podium-info" $ do
            H.span ! HA.class_ "podium-entry-title" $
                H.toHtml (entryTitle entry)
            H.span ! HA.class_ "podium-score" $ do
                H.toHtml (msgScore msgs <> ": ")
                H.toHtml (show score)
            case submitter of
                Just name ->
                    H.span ! HA.class_ "podium-submitter" $
                        H.toHtml name
                Nothing -> return ()

-- ---------------------------------------------------------------------------
-- Entry card
-- ---------------------------------------------------------------------------

renderEntryCard :: Config -> Messages -> GalleryData -> RankedEntry -> H.Html
renderEntryCard config msgs gd re = do
    let entry = rankedEntry re
        score = rankedTotalScore re
        hasScore = not (null (rankedReviews re))
        imgUrls = entryImageUrls (gdPbUrl gd) entry
        submitter = submitterName config msgs gd entry
    H.article ! HA.class_ "entry-card" $ do
        renderEntryImages config gd entry imgUrls
        H.div ! HA.class_ "entry-body" $ do
            H.h3 ! HA.class_ "entry-title" $ H.toHtml (entryTitle entry)
            case entryDescription entry of
                Just desc -> H.p ! HA.class_ "entry-desc" $ H.toHtml desc
                Nothing -> return ()
            case submitter of
                Just name ->
                    H.p ! HA.class_ "entry-submitter" $ H.toHtml name
                Nothing -> return ()
            when hasScore $
                H.p ! HA.class_ "entry-score" $ do
                    H.toHtml (msgScore msgs <> ": ")
                    H.toHtml (show score)

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

coverImageUrl :: Text -> Entry -> Maybe Text
coverImageUrl pbUrl entry =
    case entryImageUrls pbUrl entry of
        [] -> Nothing
        url : _ -> Just url

entryImageUrls :: Text -> Entry -> [Text]
entryImageUrls pbUrl entry =
    case entryImages entry of
        [] -> []
        imgs ->
            let maxIdx = length imgs - 1
                coverIdx = max 0 (min (entryCoverIndex entry) maxIdx)
                (beforeCover, coverAndAfter) = splitAt coverIdx imgs
                ordered =
                    case coverAndAfter of
                        [] -> imgs
                        cover : afterCover -> cover : beforeCover ++ afterCover
             in map (resolveFileUrl pbUrl (entryId entry)) ordered

renderEntryImages :: Config -> GalleryData -> Entry -> [Text] -> H.Html
renderEntryImages config gd entry imgUrls =
    case imgUrls of
        [] ->
            return ()
        primary : rest -> do
            H.div ! HA.class_ "entry-img-wrap"
                $ H.a
                    ! HA.href (H.toValue primary)
                    ! HA.class_ "entry-img-link"
                    ! H.customAttribute "aria-label" (H.toValue ("Avaa kuva: " <> entryTitle entry))
                    ! H.dataAttribute "lightbox" (H.toValue primary)
                $ H.img
                    ! HA.src (H.toValue primary)
                    ! HA.alt (H.toValue (altText config gd entry (entryTitle entry)))
                    ! HA.class_ "entry-img"
            unless (null rest) $
                H.div ! HA.class_ "entry-thumb-row" $
                    mapM_ (renderEntryThumb config gd entry) rest

renderEntryThumb :: Config -> GalleryData -> Entry -> Text -> H.Html
renderEntryThumb config gd entry url =
    H.a
        ! HA.href (H.toValue url)
        ! HA.class_ "entry-thumb-link"
        ! H.customAttribute "aria-label" (H.toValue ("Avaa kuva: " <> entryTitle entry))
        ! H.dataAttribute "lightbox" (H.toValue url)
        $ H.img
            ! HA.src (H.toValue url)
            ! HA.alt (H.toValue (altText config gd entry (entryTitle entry)))
            ! HA.class_ "entry-thumb"

-- | Build the img alt text, appending " by {name}" when not anonymized.
altText :: Config -> GalleryData -> Entry -> Text -> Text
altText config gd entry title
    | configAnonymize config = title
    | otherwise =
        case Map.lookup (entrySubmitter entry) (gdDisplayNames gd) of
            Just name -> title <> " by " <> name
            Nothing -> title

submitterName :: Config -> Messages -> GalleryData -> Entry -> Maybe Text
submitterName config msgs gd entry
    | configAnonymize config = Nothing
    | otherwise =
        let uid = entrySubmitter entry
            name = Map.lookup uid (gdDisplayNames gd)
            prefix = msgBy msgs
         in case name of
                Nothing -> Nothing
                Just n ->
                    if T.null prefix
                        then Just n
                        else Just (prefix <> " " <> n)

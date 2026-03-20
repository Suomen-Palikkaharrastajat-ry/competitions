{-# LANGUAGE OverloadedStrings #-}

module I18n
    ( Locale (..)
    , Messages (..)
    , messagesEn
    , messagesFi
    , getMessages
    , getTimeLocale
    , defaultLocale
    , parseLocale
    , fiTimeLocale
    ) where

import Data.Text (Text)
import Data.Time.Format (TimeLocale (..), defaultTimeLocale)

-- | Supported locales
data Locale = En | Fi
    deriving (Show, Eq, Read)

-- | UI message keys for competition platform labels
data Messages = Messages
    { msgSkipToContent :: Text
    , msgCompetition   :: Text
    , msgParticipants  :: Text
    , msgReview        :: Text
    , msgLogIn         :: Text
    , msgLogOut        :: Text
    , msgSubmit        :: Text
    , msgGeneratedOn   :: Text
    , msgPoweredBy     :: Text
    , msgOrgName       :: Text
    }

messagesEn :: Messages
messagesEn =
    Messages
        { msgSkipToContent = "Skip to main content"
        , msgCompetition   = "Competition"
        , msgParticipants  = "Participants"
        , msgReview        = "Review"
        , msgLogIn         = "Log in"
        , msgLogOut        = "Log out"
        , msgSubmit        = "Submit"
        , msgGeneratedOn   = "Generated on"
        , msgPoweredBy     = "Powered by Suomen Palikkaharrastajat ry"
        , msgOrgName       = "Suomen Palikkaharrastajat ry"
        }

messagesFi :: Messages
messagesFi =
    Messages
        { msgSkipToContent = "Siirry pääsisältöön"
        , msgCompetition   = "Kilpailu"
        , msgParticipants  = "Osallistujat"
        , msgReview        = "Arvostelu"
        , msgLogIn         = "Kirjaudu sisään"
        , msgLogOut        = "Kirjaudu ulos"
        , msgSubmit        = "Lähetä"
        , msgGeneratedOn   = "Koottu"
        , msgPoweredBy     = "Suomen Palikkaharrastajat ry:n tuottama"
        , msgOrgName       = "Suomen Palikkaharrastajat ry"
        }

getMessages :: Locale -> Messages
getMessages En = messagesEn
getMessages Fi = messagesFi

getTimeLocale :: Locale -> TimeLocale
getTimeLocale En = defaultTimeLocale
getTimeLocale Fi = fiTimeLocale

defaultLocale :: Locale
defaultLocale = Fi

parseLocale :: Text -> Locale
parseLocale "en" = En
parseLocale "fi" = Fi
parseLocale _    = defaultLocale

fiTimeLocale :: TimeLocale
fiTimeLocale =
    defaultTimeLocale
        { wDays =
            [ ("sunnuntai", "su")
            , ("maanantai", "ma")
            , ("tiistai",   "ti")
            , ("keskiviikko", "ke")
            , ("torstai",   "to")
            , ("perjantai", "pe")
            , ("lauantai",  "la")
            ]
        , months =
            [ ("tammikuu",  "tammi")
            , ("helmikuu",  "helmi")
            , ("maaliskuu", "maalis")
            , ("huhtikuu",  "huhti")
            , ("toukokuu",  "touko")
            , ("kesäkuu",   "kesä")
            , ("heinäkuu",  "heinä")
            , ("elokuu",    "elo")
            , ("syyskuu",   "syys")
            , ("lokakuu",   "loka")
            , ("marraskuu", "marras")
            , ("joulukuu",  "joulu")
            ]
        , amPm       = ("ap.", "ip.")
        , dateTimeFmt = "%d.%m.%Y %H.%M.%S"
        , dateFmt     = "%d.%m.%Y"
        , timeFmt     = "%H.%M.%S"
        , time12Fmt   = "%H.%M.%S"
        }

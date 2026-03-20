module Config (Config (..), parseConfig) where

import qualified Data.HashMap.Strict as HM
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Text.Toml as Toml

import I18n

data Config = Config
    { configTitle    :: Text        -- Competition title shown in gallery
    , configLocale   :: Locale      -- "fi" | "en"
    , configTimezone :: Text        -- e.g. "Europe/Helsinki"
    , configPbUrl    :: Maybe Text  -- overrides POCKETBASE_URL env var
    }
    deriving (Show)

parseConfig :: Text -> Either Text Config
parseConfig content = do
    toml <- case Toml.parseTomlDoc "competition.toml" content of
        Left err -> Left $ T.pack $ show err
        Right t  -> Right t

    let title    = fromMaybe (T.pack "Palikkakilpailu") $ HM.lookup (T.pack "title") toml >>= extractText
    let locale   = parseLocale $ fromMaybe (T.pack "fi") $ HM.lookup (T.pack "locale") toml >>= extractText
    let timezone = fromMaybe (T.pack "Europe/Helsinki") $ HM.lookup (T.pack "timezone") toml >>= extractText
    let pbUrl    = HM.lookup (T.pack "pocketbase_url") toml >>= extractText

    Right $ Config title locale timezone pbUrl
  where
    extractText (Toml.VString t) = Just t
    extractText _                = Nothing

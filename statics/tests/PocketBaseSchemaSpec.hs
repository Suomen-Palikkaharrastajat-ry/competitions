{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

{- | Integration tests for the PocketBase schema.
These tests require a running PocketBase instance with migrations applied.
They are SKIPPED automatically when POCKETBASE_URL is not set.

Given  a running PocketBase with competition platform migrations applied
When   we interact with the REST API
Then   the expected collections, fields, and constraints are present
-}
module PocketBaseSchemaSpec (tests) where

import Test.Tasty
import Test.Tasty.HUnit

import qualified Data.Aeson as A
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import Data.Char (isDigit)
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time.Clock.POSIX (getPOSIXTime)
import Network.HTTP.Client (RequestBody (RequestBodyBS))
import Network.HTTP.Client.MultipartFormData (
    formDataBody,
    partBS,
    partFileRequestBody,
 )
import Network.HTTP.Simple (
    addRequestHeader,
    getResponseBody,
    getResponseStatusCode,
    httpLBS,
    parseRequest,
    setRequestBodyLBS,
 )
import Network.HTTP.Types (hAuthorization, hContentType)
import System.Environment (lookupEnv)

import GalleryTypes
import PocketBase

data TestIdentity = TestIdentity
    { testAuthId :: T.Text
    , testProfileId :: T.Text
    }

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- | Run a test only when POCKETBASE_URL is set; skip otherwise.
withPocketBase :: (PbConfig -> IO ()) -> IO ()
withPocketBase action = do
    mUrl <- lookupEnv "POCKETBASE_URL"
    mKey <- lookupEnv "POCKETBASE_API_KEY"
    case (mUrl, mKey) of
        (Just url, Just key) ->
            action $ PbConfig (T.pack url) (T.pack key)
        _ ->
            return () -- silently skip when env vars absent

skipMsg :: String
skipMsg = "POCKETBASE_URL / POCKETBASE_API_KEY not set — skipping integration tests"

-- | POST with no auth headers; returns HTTP status code.
postNoAuth :: String -> A.Value -> IO Int
postNoAuth url body = do
    req0 <- parseRequest ("POST " <> url)
    let req =
            setRequestBodyLBS (A.encode body) $
                addRequestHeader hContentType "application/json" req0
    resp <- httpLBS req
    return (getResponseStatusCode resp)

-- | POST with a bearer token; returns HTTP status code.
postWithToken :: String -> T.Text -> A.Value -> IO Int
postWithToken url token body = do
    req0 <- parseRequest ("POST " <> url)
    let req =
            setRequestBodyLBS (A.encode body) $
                addRequestHeader hAuthorization (BS8.pack "Bearer " <> TE.encodeUtf8 token) $
                    addRequestHeader hContentType "application/json" req0
    resp <- httpLBS req
    return (getResponseStatusCode resp)

-- | POST with a bearer token; returns status code and response body.
postWithTokenBody :: String -> T.Text -> A.Value -> IO (Int, A.Value)
postWithTokenBody url token body = do
    req0 <- parseRequest ("POST " <> url)
    let req =
            setRequestBodyLBS (A.encode body) $
                addRequestHeader hAuthorization (BS8.pack "Bearer " <> TE.encodeUtf8 token) $
                    addRequestHeader hContentType "application/json" req0
    resp <- httpLBS req
    let code = getResponseStatusCode resp
    let parsed = case A.eitherDecode (getResponseBody resp) of
            Right v -> v
            Left _ -> A.Null
    return (code, parsed)

-- | POST multipart form data with a bearer token; returns status code and response body.
postMultipartWithTokenBody :: String -> T.Text -> [(T.Text, BS8.ByteString)] -> Int -> IO (Int, A.Value)
postMultipartWithTokenBody url token fields imageCount = do
    req0 <- parseRequest ("POST " <> url)
    let reqAuth = addRequestHeader hAuthorization (BS8.pack "Bearer " <> TE.encodeUtf8 token) req0
        fieldParts = map (uncurry partBS) fields
        imageParts =
            replicate
                imageCount
                (partFileRequestBody "images" "test-image.png" (RequestBodyBS tinyPng))
    req <- formDataBody (fieldParts ++ imageParts) reqAuth
    resp <- httpLBS req
    let code = getResponseStatusCode resp
    let parsed = case A.eitherDecode (getResponseBody resp) of
            Right v -> v
            Left _ -> A.Null
    return (code, parsed)

-- | POST multipart form data with a bearer token and WebP images.
postMultipartWithWebpBody :: String -> T.Text -> [(T.Text, BS8.ByteString)] -> Int -> IO (Int, A.Value)
postMultipartWithWebpBody url token fields imageCount = do
    req0 <- parseRequest ("POST " <> url)
    let reqAuth = addRequestHeader hAuthorization (BS8.pack "Bearer " <> TE.encodeUtf8 token) req0
        fieldParts = map (uncurry partBS) fields
        imageParts =
            replicate
                imageCount
                (partFileRequestBody "images" "test-image.webp" (RequestBodyBS tinyWebp))
    req <- formDataBody (fieldParts ++ imageParts) reqAuth
    resp <- httpLBS req
    let code = getResponseStatusCode resp
    let parsed = case A.eitherDecode (getResponseBody resp) of
            Right v -> v
            Left _ -> A.Null
    return (code, parsed)

-- | A minimal 1x1 WebP used by multipart WebP tests.
tinyWebp :: BS.ByteString
tinyWebp =
    BS.pack
        [ 82
        , 73
        , 70
        , 70
        , 26
        , 0
        , 0
        , 0
        , 87
        , 69
        , 66
        , 80
        , 86
        , 80
        , 56
        , 32
        , 14
        , 0
        , 0
        , 0
        , 48
        , 1
        , 0
        , 157
        , 1
        , 42
        , 1
        , 0
        , 1
        , 0
        , 0
        , 52
        , 37
        , 164
        , 0
        , 3
        , 112
        , 0
        ]

-- | A minimal 1x1 PNG used by multipart image-count tests.
tinyPng :: BS.ByteString
tinyPng =
    BS.pack
        [ 137
        , 80
        , 78
        , 71
        , 13
        , 10
        , 26
        , 10
        , 0
        , 0
        , 0
        , 13
        , 73
        , 72
        , 68
        , 82
        , 0
        , 0
        , 0
        , 1
        , 0
        , 0
        , 0
        , 1
        , 8
        , 6
        , 0
        , 0
        , 0
        , 31
        , 21
        , 196
        , 137
        , 0
        , 0
        , 0
        , 10
        , 73
        , 68
        , 65
        , 84
        , 120
        , 156
        , 99
        , 248
        , 15
        , 0
        , 1
        , 1
        , 1
        , 0
        , 24
        , 221
        , 141
        , 24
        , 0
        , 0
        , 0
        , 0
        , 73
        , 69
        , 78
        , 68
        , 174
        , 66
        , 96
        , 130
        ]

-- | PATCH with a bearer token; returns HTTP status code.
patchWithToken :: String -> T.Text -> A.Value -> IO Int
patchWithToken url token body = do
    req0 <- parseRequest ("PATCH " <> url)
    let req =
            setRequestBodyLBS (A.encode body) $
                addRequestHeader hAuthorization (BS8.pack "Bearer " <> TE.encodeUtf8 token) $
                    addRequestHeader hContentType "application/json" req0
    resp <- httpLBS req
    return (getResponseStatusCode resp)

-- | GET with a bearer token; returns HTTP status code.
getWithToken :: String -> T.Text -> IO Int
getWithToken url token = do
    req0 <- parseRequest ("GET " <> url)
    let req = addRequestHeader hAuthorization (BS8.pack "Bearer " <> TE.encodeUtf8 token) req0
    resp <- httpLBS req
    return (getResponseStatusCode resp)

-- | PATCH a record via admin API.
patchAdminRecord :: PbConfig -> T.Text -> T.Text -> A.Value -> IO ()
patchAdminRecord cfg col recId body = do
    let url =
            T.unpack $
                pbBaseUrl cfg
                    <> "/api/collections/"
                    <> col
                    <> "/records/"
                    <> recId
    req0 <- parseRequest ("PATCH " <> url)
    let req =
            setRequestBodyLBS (A.encode body) $
                addRequestHeader hContentType "application/json" $
                    foldr (uncurry addRequestHeader) req0 (authHeaders cfg)
    resp <- httpLBS req
    let code = getResponseStatusCode resp
    assertBool ("PATCH " <> T.unpack col <> " failed with " <> show code) (code >= 200 && code < 300)

-- | Create a local auth user plus a profile via admin API.
uniqueEmail :: T.Text -> IO T.Text
uniqueEmail raw = do
    ts <- show <$> getPOSIXTime
    let digits = filter isDigit ts
    return $ T.takeWhile (/= '@') raw <> "+" <> T.pack (reverse (take 8 (reverse digits))) <> "@test.invalid"

createTestUser :: PbConfig -> T.Text -> IO TestIdentity
createTestUser cfg rawEmail = do
    email <- uniqueEmail rawEmail
    let body =
            A.object
                [ "email" A..= email
                , "emailVisibility" A..= True
                , "password" A..= ("testpass123456" :: T.Text)
                , "passwordConfirm" A..= ("testpass123456" :: T.Text)
                ]
    result <- createRecord cfg "local_users" body
    case result of
        Left err -> fail $ "createTestUser failed: " <> err
        Right uid -> do
            profile <- createProfile cfg email uid False
            patchAdminRecord
                cfg
                "local_users"
                uid
                (A.object ["profile_id" A..= profile])
            return (TestIdentity uid profile)

-- | Create a verified non-reviewer local user plus a profile via admin API.
createVerifiedNonReviewerUser :: PbConfig -> T.Text -> IO TestIdentity
createVerifiedNonReviewerUser cfg rawEmail = do
    email <- uniqueEmail rawEmail
    let body =
            A.object
                [ "email" A..= email
                , "emailVisibility" A..= True
                , "verified" A..= True
                , "password" A..= ("testpass123456" :: T.Text)
                , "passwordConfirm" A..= ("testpass123456" :: T.Text)
                ]
    result <- createRecord cfg "local_users" body
    case result of
        Left err -> fail $ "createVerifiedNonReviewerUser failed: " <> err
        Right uid -> do
            profile <- createProfile cfg email uid False
            patchAdminRecord
                cfg
                "local_users"
                uid
                (A.object ["profile_id" A..= profile])
            return (TestIdentity uid profile)

-- | Create a reviewer local user plus a profile via admin API.
createReviewerUser :: PbConfig -> T.Text -> IO TestIdentity
createReviewerUser cfg rawEmail = do
    email <- uniqueEmail rawEmail
    let body =
            A.object
                [ "email" A..= email
                , "emailVisibility" A..= True
                , "verified" A..= True
                , "is_reviewer" A..= True
                , "password" A..= ("testpass123456" :: T.Text)
                , "passwordConfirm" A..= ("testpass123456" :: T.Text)
                ]
    result <- createRecord cfg "local_users" body
    case result of
        Left err -> fail $ "createReviewerUser failed: " <> err
        Right uid -> do
            profile <- createProfile cfg email uid True
            patchAdminRecord
                cfg
                "local_users"
                uid
                (A.object ["profile_id" A..= profile])
            return (TestIdentity uid profile)

-- | Create the profile record used by domain relations.
createProfile :: PbConfig -> T.Text -> T.Text -> Bool -> IO T.Text
createProfile cfg email localUserId isReviewer = do
    let body =
            A.object
                [ "email" A..= email
                , "normalized_email" A..= T.toLower email
                , "display_name" A..= email
                , "is_reviewer" A..= isReviewer
                , "auth_source" A..= ("local" :: T.Text)
                , "local_user" A..= localUserId
                ]
    result <- createRecord cfg "profiles" body
    case result of
        Left err -> fail $ "createProfile failed: " <> err
        Right pid -> return pid

-- | Obtain a local user auth token via PocketBase admin impersonation.
impersonateUser :: PbConfig -> TestIdentity -> IO T.Text
impersonateUser cfg ident = do
    let url =
            T.unpack $
                pbBaseUrl cfg
                    <> "/api/collections/local_users/impersonate/"
                    <> testAuthId ident
    req0 <- parseRequest ("POST " <> url)
    let req =
            setRequestBodyLBS (A.encode (A.object [])) $
                foldr (uncurry addRequestHeader) req0 (authHeaders cfg)
    resp <- httpLBS req
    let body = getResponseBody resp
    case A.eitherDecode body of
        Left err -> fail $ "impersonateUser decode error: " <> err
        Right (A.Object km) ->
            case KM.lookup "token" km of
                Just (A.String t) -> return t
                _ -> fail "impersonateUser: no token in response"
        Right _ -> fail "impersonateUser: unexpected response shape"

-- | Delete a record via admin API (best-effort; ignores errors).
deleteTestRecord :: PbConfig -> T.Text -> T.Text -> IO ()
deleteTestRecord cfg col recId = do
    let url =
            T.unpack $
                pbBaseUrl cfg
                    <> "/api/collections/"
                    <> col
                    <> "/records/"
                    <> recId
    req0 <- parseRequest ("DELETE " <> url)
    let req = foldr (uncurry addRequestHeader) req0 (authHeaders cfg)
    _ <- httpLBS req
    return ()

-- | Create a minimal open competition via admin API; returns competition id.
createTestCompetition :: PbConfig -> IO T.Text
createTestCompetition cfg = do
    ts <- show <$> getPOSIXTime
    let digits = filter isDigit ts
        uniqueSlug = "ac-test-comp-" <> T.pack (reverse (take 10 (reverse digits)))
        body =
            A.object
                [ "title" A..= ("AC Test Competition" :: T.Text)
                , "slug" A..= uniqueSlug
                , "status" A..= ("open" :: T.Text)
                , "start_date" A..= ("2026-01-01 00:00:00.000Z" :: T.Text)
                , "end_date" A..= ("2099-12-31 00:00:00.000Z" :: T.Text)
                , "min_images_per_entry" A..= (1 :: Int)
                , "max_images_per_entry" A..= (5 :: Int)
                ]
    result <- createRecord cfg "competitions" body
    case result of
        Left err -> fail $ "createTestCompetition failed: " <> err
        Right cid -> return cid

-- | Create an open competition with explicit entry image limits.
createTestCompetitionWithImageLimits :: PbConfig -> Int -> Int -> IO T.Text
createTestCompetitionWithImageLimits cfg minImages maxImages = do
    ts <- show <$> getPOSIXTime
    let digits = filter isDigit ts
        suffix = T.pack (show minImages <> "-" <> show maxImages <> "-" <> reverse (take 10 (reverse digits)))
        body =
            A.object
                [ "title" A..= ("AC Image Limit Competition" :: T.Text)
                , "slug" A..= ("ac-image-limit-" <> suffix)
                , "status" A..= ("open" :: T.Text)
                , "start_date" A..= ("2026-01-01 00:00:00.000Z" :: T.Text)
                , "end_date" A..= ("2099-12-31 00:00:00.000Z" :: T.Text)
                , "min_images_per_entry" A..= minImages
                , "max_images_per_entry" A..= maxImages
                ]
    result <- createRecord cfg "competitions" body
    case result of
        Left err -> fail $ "createTestCompetitionWithImageLimits failed: " <> err
        Right cid -> return cid

-- | Create a submitted entry owned by a profile via admin API; returns entry id.
createTestEntry :: PbConfig -> T.Text -> T.Text -> IO T.Text
createTestEntry cfg profileId cid =
    createTestEntryWithImages cfg profileId cid "submitted" 1

-- | Create an entry with a configurable image count via multipart API.
createTestEntryWithImages :: PbConfig -> T.Text -> T.Text -> T.Text -> Int -> IO T.Text
createTestEntryWithImages cfg profileId cid status imageCount = do
    let url = T.unpack $ pbBaseUrl cfg <> "/api/collections/entries/records"
        fields =
            [ ("title", "AC Test MOC")
            , ("competition", TE.encodeUtf8 cid)
            , ("submitter", TE.encodeUtf8 profileId)
            , ("status", TE.encodeUtf8 status)
            ]
    (code, respBody) <- postMultipartWithTokenBody url (pbApiToken cfg) fields imageCount
    case (code, respBody) of
        (c, A.Object km)
            | c >= 200 && c < 300 ->
                case KM.lookup "id" km of
                    Just (A.String eid) -> return eid
                    _ -> fail "createTestEntryWithImages: no id in response"
        _ -> fail $ "createTestEntryWithImages failed with HTTP " <> show code <> ": " <> show respBody

-- | Scores for the four criteria of config.toml, by criterion id.
fourScores :: Int -> Int -> Int -> Int -> Map.Map T.Text Int
fourScores theme originality technique presentation =
    Map.fromList
        [ ("theme", theme)
        , ("originality", originality)
        , ("technique", technique)
        , ("presentation", presentation)
        ]

-- | Create a published review for an entry via admin API; returns review id.
createPublishedReview :: PbConfig -> T.Text -> T.Text -> IO T.Text
createPublishedReview cfg reviewerProfileId reviewedEntryId = do
    let body =
            A.object
                [ "entry" A..= reviewedEntryId
                , "reviewer" A..= reviewerProfileId
                , "scores"
                    A..= A.object
                        [ "theme" A..= (5 :: Int)
                        , "originality" A..= (4 :: Int)
                        , "technique" A..= (5 :: Int)
                        , "presentation" A..= (4 :: Int)
                        ]
                , "comment" A..= ("Published feedback" :: T.Text)
                , "is_published" A..= True
                ]
    result <- createRecord cfg "reviews" body
    case result of
        Left err -> fail $ "createPublishedReview failed: " <> err
        Right rid -> return rid

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

tests :: TestTree
tests =
    testGroup
        "PocketBase Schema Integration Tests"
        [ testCase "competitions collection is accessible" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            case mUrl of
                Nothing -> assertBool skipMsg True -- skip
                Just _ -> withPocketBase $ \cfg -> do
                    page <- fetchPage cfg "competitions" 1
                    assertBool "fetchPage returned a PbList" (pbTotalItems page >= 0)
        , testCase "entries collection is accessible" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            case mUrl of
                Nothing -> assertBool skipMsg True
                Just _ -> withPocketBase $ \cfg -> do
                    page <- fetchPage cfg "entries" 1
                    assertBool "fetchPage returned a PbList" (pbTotalItems page >= 0)
        , testCase "reviews collection is accessible" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            case mUrl of
                Nothing -> assertBool skipMsg True
                Just _ -> withPocketBase $ \cfg -> do
                    page <- fetchPage cfg "reviews" 1
                    assertBool "fetchPage returned a PbList" (pbTotalItems page >= 0)
        , -- -----------------------------------------------------------------------
          -- Access control: anonymous requests
          -- -----------------------------------------------------------------------

          testCase "anon POST to entries ->401" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            case mUrl of
                Nothing -> assertBool skipMsg True
                Just url -> do
                    code <- postNoAuth (url <> "/api/collections/entries/records") (A.object [])
                    assertBool "anon POST to entries rejected" (code == 400 || code == 401)
        , testCase "anon POST to competitions ->401" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            case mUrl of
                Nothing -> assertBool skipMsg True
                Just url -> do
                    code <- postNoAuth (url <> "/api/collections/competitions/records") (A.object [])
                    assertBool "anon POST to competitions rejected" (code == 400 || code == 401)
        , testCase "anon POST to reviews ->401" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            case mUrl of
                Nothing -> assertBool skipMsg True
                Just url -> do
                    code <- postNoAuth (url <> "/api/collections/reviews/records") (A.object [])
                    assertBool "anon POST to reviews rejected" (code == 400 || code == 401)
        , -- -----------------------------------------------------------------------
          -- Access control: participant cannot edit another user's entry
          -- -----------------------------------------------------------------------

          testCase "participant PATCH on others' entry ->403" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            mKey <- lookupEnv "POCKETBASE_API_KEY"
            case (mUrl, mKey) of
                (Nothing, _) -> assertBool skipMsg True
                (_, Nothing) -> assertBool skipMsg True
                (Just url, Just key) -> do
                    let cfg = PbConfig (T.pack url) (T.pack key)
                    -- Setup
                    u1 <- createTestUser cfg "actest-owner@test.invalid"
                    u2 <- createTestUser cfg "actest-other@test.invalid"
                    cid <- createTestCompetition cfg
                    eid <- createTestEntry cfg (testProfileId u1) cid
                    tok2 <- impersonateUser cfg u2
                    -- Act: participant2 tries to PATCH participant1's entry
                    let patchUrl = url <> "/api/collections/entries/records/" <> T.unpack eid
                    code <-
                        patchWithToken
                            patchUrl
                            tok2
                            (A.object [("title", A.toJSON ("Hacked" :: T.Text))])
                    -- Cleanup (best-effort)
                    deleteTestRecord cfg "entries" eid
                    deleteTestRecord cfg "competitions" cid
                    deleteTestRecord cfg "profiles" (testProfileId u1)
                    deleteTestRecord cfg "profiles" (testProfileId u2)
                    deleteTestRecord cfg "local_users" (testAuthId u1)
                    deleteTestRecord cfg "local_users" (testAuthId u2)
                    -- Assert
                    assertBool
                        ("expected 403 or 404, got " <> show code)
                        (code == 403 || code == 404)
        , -- -----------------------------------------------------------------------
          -- Access control: participant can read own draft
          -- -----------------------------------------------------------------------

          testCase "participant can read own draft entry" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            mKey <- lookupEnv "POCKETBASE_API_KEY"
            case (mUrl, mKey) of
                (Nothing, _) -> assertBool skipMsg True
                (_, Nothing) -> assertBool skipMsg True
                (Just url, Just key) -> do
                    let cfg = PbConfig (T.pack url) (T.pack key)
                    -- Setup
                    ident <- createTestUser cfg "actest-owner2@test.invalid"
                    cid <- createTestCompetition cfg
                    -- Create a draft entry owned by uid via admin
                    let body =
                            A.object
                                [ "title" A..= ("My Draft" :: T.Text)
                                , "competition" A..= cid
                                , "submitter" A..= testProfileId ident
                                , "status" A..= ("draft" :: T.Text)
                                ]
                    entryResult <- createRecord cfg "entries" body
                    case entryResult of
                        Left err -> do
                            deleteTestRecord cfg "competitions" cid
                            deleteTestRecord cfg "profiles" (testProfileId ident)
                            deleteTestRecord cfg "local_users" (testAuthId ident)
                            assertFailure $ "createRecord failed: " <> err
                        Right eid -> do
                            tok <- impersonateUser cfg ident
                            let getUrl = url <> "/api/collections/entries/records/" <> T.unpack eid
                            code <- getWithToken getUrl tok
                            deleteTestRecord cfg "entries" eid
                            deleteTestRecord cfg "competitions" cid
                            deleteTestRecord cfg "profiles" (testProfileId ident)
                            deleteTestRecord cfg "local_users" (testAuthId ident)
                            code @?= 200
        , -- Given a participant with an own submitted entry and a published review
          -- When listing own entries sorted by created timestamp with reviews expanded
          -- Then PocketBase returns HTTP 200 so "Omat osallistumiset" can render.
          testCase "participant can list own entries sorted by created with expanded reviews -> 200" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            mKey <- lookupEnv "POCKETBASE_API_KEY"
            case (mUrl, mKey) of
                (Nothing, _) -> assertBool skipMsg True
                (_, Nothing) -> assertBool skipMsg True
                (Just url, Just key) -> do
                    let cfg = PbConfig (T.pack url) (T.pack key)
                    participant <- createVerifiedNonReviewerUser cfg "my-entries-owner@test.invalid"
                    reviewer <- createReviewerUser cfg "my-entries-reviewer@test.invalid"
                    cid <- createTestCompetition cfg
                    eid <- createTestEntry cfg (testProfileId participant) cid
                    rid <- createPublishedReview cfg (testProfileId reviewer) eid
                    tok <- impersonateUser cfg participant
                    let getUrl =
                            url
                                <> "/api/collections/entries/records?filter=submitter%3D%22"
                                <> T.unpack (testProfileId participant)
                                <> "%22&sort=-created&expand=reviews_via_entry"
                    code <- getWithToken getUrl tok
                    deleteTestRecord cfg "reviews" rid
                    deleteTestRecord cfg "entries" eid
                    deleteTestRecord cfg "competitions" cid
                    deleteTestRecord cfg "profiles" (testProfileId participant)
                    deleteTestRecord cfg "profiles" (testProfileId reviewer)
                    deleteTestRecord cfg "local_users" (testAuthId participant)
                    deleteTestRecord cfg "local_users" (testAuthId reviewer)
                    code @?= 200
        , -- -----------------------------------------------------------------------
          -- GalleryTypes unit tests (no PocketBase connection needed)
          -- -----------------------------------------------------------------------

          testCase "GalleryTypes: Competition JSON decoding" $ do
            let json =
                    A.object
                        [ "id" A..= ("abc123" :: T.Text)
                        , "title" A..= ("Test Competition" :: T.Text)
                        , "slug" A..= ("test-2026" :: T.Text)
                        , "description" A..= ("A test competition" :: T.Text)
                        , "theme" A..= ("Space" :: T.Text)
                        , "status" A..= ("open" :: T.Text)
                        , "start_date" A..= ("2026-01-01 00:00:00.000Z" :: T.Text)
                        , "end_date" A..= ("2026-06-01 00:00:00.000Z" :: T.Text)
                        , "min_images_per_entry" A..= (2 :: Int)
                        , "max_images_per_entry" A..= (8 :: Int)
                        ]
            case A.fromJSON json of
                A.Error err -> assertFailure $ "Decode failed: " <> err
                A.Success (comp :: Competition) -> do
                    compId comp @?= "abc123"
                    compTitle comp @?= "Test Competition"
                    compSlug comp @?= "test-2026"
                    compStatus comp @?= Open
                    compMinImagesPerEntry comp @?= Just 2
                    compMaxImagesPerEntry comp @?= Just 8
        , testCase "GalleryTypes: Entry JSON decoding" $ do
            let json =
                    A.object
                        [ "id" A..= ("entry1" :: T.Text)
                        , "competition" A..= ("comp1" :: T.Text)
                        , "submitter" A..= ("user1" :: T.Text)
                        , "title" A..= ("My MOC" :: T.Text)
                        , "images" A..= (["img1.jpg", "img2.jpg"] :: [T.Text])
                        , "status" A..= ("approved" :: T.Text)
                        ]
            case A.fromJSON json of
                A.Error err -> assertFailure $ "Decode failed: " <> err
                A.Success (entry :: Entry) -> do
                    entryId entry @?= "entry1"
                    entryTitle entry @?= "My MOC"
                    entryStatus entry @?= Approved
                    length (entryImages entry) @?= 2
        , testCase "GalleryTypes: Review JSON decoding" $ do
            let json =
                    A.object
                        [ "id" A..= ("rev1" :: T.Text)
                        , "entry" A..= ("entry1" :: T.Text)
                        , "reviewer" A..= ("user2" :: T.Text)
                        , "scores"
                            A..= A.object
                                [ "theme" A..= (4 :: Int)
                                , "originality" A..= (5 :: Int)
                                , "technique" A..= (3 :: Int)
                                , "presentation" A..= (4 :: Int)
                                ]
                        , "is_published" A..= True
                        ]
            case A.fromJSON json of
                A.Error err -> assertFailure $ "Decode failed: " <> err
                A.Success (review :: Review) -> do
                    reviewId review @?= "rev1"
                    reviewScores review @?= fourScores 4 5 3 4
                    reviewIsPublished review @?= True
        , testCase "GalleryTypes: rankEntries computes scores" $ do
            let entry1 = Entry "e1" "comp" "user1" "MOC A" Nothing ["img.jpg"] 0 Approved
                entry2 = Entry "e2" "comp" "user2" "MOC B" Nothing ["img.jpg"] 0 Approved
                rev1 = Review "r1" "e1" "reviewer" (fourScores 5 5 5 5) Nothing True
                rev2 = Review "r2" "e2" "reviewer" (fourScores 3 3 3 3) Nothing True
                ranked = rankEntries [(entry1, [rev1]), (entry2, [rev2])]
            length ranked @?= 2
            rankedRank (head ranked) @?= 1
            rankedTotalScore (head ranked) @?= 20 -- 5+5+5+5
            rankedTotalScore (ranked !! 1) @?= 12 -- 3+3+3+3
        , testCase "GalleryTypes: total sums however many criteria a review scores" $ do
            let entry = Entry "e1" "comp" "user1" "MOC" Nothing ["img.jpg"] 0 Approved
                review = Review "r1" "e1" "rev1" (Map.fromList [("clarity", 5), ("humour", 2)]) Nothing True
                ranked = rankEntries [(entry, [review])]
            rankedTotalScore (head ranked) @?= 7
        , testCase "GalleryTypes: unpublished reviews excluded from score" $ do
            let entry = Entry "e1" "comp" "user1" "MOC" Nothing ["img.jpg"] 0 Approved
                published = Review "r1" "e1" "rev1" (fourScores 5 5 5 5) Nothing True
                unpublished = Review "r2" "e1" "rev2" (fourScores 1 1 1 1) Nothing False
                ranked = rankEntries [(entry, [published, unpublished])]
            rankedTotalScore (head ranked) @?= 20 -- only published counts
        , -- -----------------------------------------------------------------------
          -- Access control: competitions write rules require is_reviewer (migration 005)
          -- -----------------------------------------------------------------------

          -- Given a verified user who is NOT a reviewer
          -- When POST /api/collections/competitions/records
          -- Then HTTP 403 is returned (only reviewers may create competitions)
          testCase "verified non-reviewer cannot create competition -> 403" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            mKey <- lookupEnv "POCKETBASE_API_KEY"
            case (mUrl, mKey) of
                (Nothing, _) -> assertBool skipMsg True
                (_, Nothing) -> assertBool skipMsg True
                (Just url, Just key) -> do
                    let cfg = PbConfig (T.pack url) (T.pack key)
                    ident <- createVerifiedNonReviewerUser cfg "comp-create-nonrev@test.invalid"
                    tok <- impersonateUser cfg ident
                    let compUrl = url <> "/api/collections/competitions/records"
                    let body =
                            A.object
                                [ "title" A..= ("NonReviewer Comp" :: T.Text)
                                , "slug" A..= ("nonreviewer-comp" :: T.Text)
                                , "status" A..= ("draft" :: T.Text)
                                , "start_date" A..= ("2026-01-01 00:00:00.000Z" :: T.Text)
                                , "end_date" A..= ("2099-12-31 00:00:00.000Z" :: T.Text)
                                ]
                    code <- postWithToken compUrl tok body
                    deleteTestRecord cfg "profiles" (testProfileId ident)
                    deleteTestRecord cfg "local_users" (testAuthId ident)
                    assertBool "non-reviewer cannot create competition" (code == 400 || code == 403)
        , -- Given a reviewer user
          -- When POST /api/collections/competitions/records
          -- Then HTTP 200 is returned
          testCase "reviewer can create competition -> 200" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            mKey <- lookupEnv "POCKETBASE_API_KEY"
            case (mUrl, mKey) of
                (Nothing, _) -> assertBool skipMsg True
                (_, Nothing) -> assertBool skipMsg True
                (Just url, Just key) -> do
                    let cfg = PbConfig (T.pack url) (T.pack key)
                    ident <- createReviewerUser cfg "comp-create-reviewer@test.invalid"
                    tok <- impersonateUser cfg ident
                    let compUrl = url <> "/api/collections/competitions/records"
                    let body =
                            A.object
                                [ "title" A..= ("Reviewer Comp" :: T.Text)
                                , "slug" A..= ("reviewer-comp" :: T.Text)
                                , "status" A..= ("draft" :: T.Text)
                                , "start_date" A..= ("2026-01-01 00:00:00.000Z" :: T.Text)
                                , "end_date" A..= ("2099-12-31 00:00:00.000Z" :: T.Text)
                                ]
                    (code, respBody) <- postWithTokenBody compUrl tok body
                    -- Cleanup: delete the created competition record if successful
                    case respBody of
                        A.Object km ->
                            case KM.lookup "id" km of
                                Just (A.String createdCompId) ->
                                    deleteTestRecord cfg "competitions" createdCompId
                                _ -> return ()
                        _ -> return ()
                    deleteTestRecord cfg "profiles" (testProfileId ident)
                    deleteTestRecord cfg "local_users" (testAuthId ident)
                    assertBool ("expected 200, got " <> show code) (code >= 200 && code < 300)
        , -- -----------------------------------------------------------------------
          -- Access control: users cannot self-promote to reviewer (migration 006)
          -- -----------------------------------------------------------------------

          -- Given a regular user
          -- When PATCH own user record with is_reviewer = true
          -- Then HTTP 403 is returned
          testCase "user cannot self-promote to reviewer -> 403" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            mKey <- lookupEnv "POCKETBASE_API_KEY"
            case (mUrl, mKey) of
                (Nothing, _) -> assertBool skipMsg True
                (_, Nothing) -> assertBool skipMsg True
                (Just url, Just key) -> do
                    let cfg = PbConfig (T.pack url) (T.pack key)
                    ident <- createTestUser cfg "self-promote@test.invalid"
                    tok <- impersonateUser cfg ident
                    let profileUrl = url <> "/api/collections/profiles/records/" <> T.unpack (testProfileId ident)
                    code <-
                        patchWithToken
                            profileUrl
                            tok
                            (A.object [("is_reviewer", A.toJSON True)])
                    deleteTestRecord cfg "profiles" (testProfileId ident)
                    deleteTestRecord cfg "local_users" (testAuthId ident)
                    assertBool "user cannot self-promote to reviewer" (code == 403 || code == 404)
        , -- -----------------------------------------------------------------------
          -- Access control matrix: full coverage
          -- -----------------------------------------------------------------------

          -- Given an unauthenticated request to GET /api/collections/competitions/records
          -- Then HTTP 200 is returned (listRule = "")
          testCase "anon can list competitions -> 200" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            case mUrl of
                Nothing -> assertBool skipMsg True
                Just url -> do
                    req0 <- parseRequest (url <> "/api/collections/competitions/records")
                    resp <- httpLBS req0
                    getResponseStatusCode resp @?= 200
        , -- Given an unauthenticated GET on entries
          -- Then HTTP 200 is returned (approved entries are public)
          testCase "anon can list approved entries -> 200" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            case mUrl of
                Nothing -> assertBool skipMsg True
                Just url -> do
                    req0 <-
                        parseRequest
                            (url <> "/api/collections/entries/records?filter=status%3D%22approved%22")
                    resp <- httpLBS req0
                    getResponseStatusCode resp @?= 200
        , -- Given a verified participant
          -- When POST /api/collections/entries/records
          -- Then HTTP 200 is returned (verified users may create entries)
          testCase "participant can create entry -> 200" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            mKey <- lookupEnv "POCKETBASE_API_KEY"
            case (mUrl, mKey) of
                (Nothing, _) -> assertBool skipMsg True
                (_, Nothing) -> assertBool skipMsg True
                (Just url, Just key) -> do
                    let cfg = PbConfig (T.pack url) (T.pack key)
                    ident <- createVerifiedNonReviewerUser cfg "entry-create@test.invalid"
                    cid <- createTestCompetition cfg
                    tok <- impersonateUser cfg ident
                    let entryUrl = url <> "/api/collections/entries/records"
                    let body =
                            A.object
                                [ "title" A..= ("Participant Entry" :: T.Text)
                                , "competition" A..= cid
                                , "submitter" A..= testProfileId ident
                                , "status" A..= ("draft" :: T.Text)
                                ]
                    code <- postWithToken entryUrl tok body
                    deleteTestRecord cfg "competitions" cid
                    deleteTestRecord cfg "profiles" (testProfileId ident)
                    deleteTestRecord cfg "local_users" (testAuthId ident)
                    assertBool ("expected 200, got " <> show code) (code >= 200 && code < 300)
        , -- Given a participant and their own draft entry
          -- When PATCH that entry
          -- Then HTTP 200 is returned
          testCase "participant can update own draft entry -> 200" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            mKey <- lookupEnv "POCKETBASE_API_KEY"
            case (mUrl, mKey) of
                (Nothing, _) -> assertBool skipMsg True
                (_, Nothing) -> assertBool skipMsg True
                (Just url, Just key) -> do
                    let cfg = PbConfig (T.pack url) (T.pack key)
                    ident <- createVerifiedNonReviewerUser cfg "entry-update-own@test.invalid"
                    cid <- createTestCompetition cfg
                    let body =
                            A.object
                                [ "title" A..= ("My Draft" :: T.Text)
                                , "competition" A..= cid
                                , "submitter" A..= testProfileId ident
                                , "status" A..= ("draft" :: T.Text)
                                ]
                    entryResult <- createRecord cfg "entries" body
                    case entryResult of
                        Left err -> do
                            deleteTestRecord cfg "competitions" cid
                            deleteTestRecord cfg "profiles" (testProfileId ident)
                            deleteTestRecord cfg "local_users" (testAuthId ident)
                            assertFailure $ "setup failed: " <> err
                        Right eid -> do
                            tok <- impersonateUser cfg ident
                            let patchUrl = url <> "/api/collections/entries/records/" <> T.unpack eid
                            code <-
                                patchWithToken
                                    patchUrl
                                    tok
                                    (A.object [("title", A.toJSON ("Updated Title" :: T.Text))])
                            deleteTestRecord cfg "entries" eid
                            deleteTestRecord cfg "competitions" cid
                            deleteTestRecord cfg "profiles" (testProfileId ident)
                            deleteTestRecord cfg "local_users" (testAuthId ident)
                            assertBool ("expected 200, got " <> show code) (code >= 200 && code < 300)
        , -- Given a competition requiring at least two images
          -- When a participant saves a draft with no images
          -- Then HTTP 200 is returned because drafts may be incomplete
          testCase "participant can save image-incomplete draft -> 200" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            mKey <- lookupEnv "POCKETBASE_API_KEY"
            case (mUrl, mKey) of
                (Nothing, _) -> assertBool skipMsg True
                (_, Nothing) -> assertBool skipMsg True
                (Just url, Just key) -> do
                    let cfg = PbConfig (T.pack url) (T.pack key)
                    ident <- createVerifiedNonReviewerUser cfg "entry-draft-image-min@test.invalid"
                    cid <- createTestCompetitionWithImageLimits cfg 2 10
                    tok <- impersonateUser cfg ident
                    let entryUrl = url <> "/api/collections/entries/records"
                    let body =
                            A.object
                                [ "title" A..= ("Incomplete Draft" :: T.Text)
                                , "competition" A..= cid
                                , "submitter" A..= testProfileId ident
                                , "status" A..= ("draft" :: T.Text)
                                ]
                    (code, respBody) <- postWithTokenBody entryUrl tok body
                    case respBody of
                        A.Object km ->
                            case KM.lookup "id" km of
                                Just (A.String eid) ->
                                    deleteTestRecord cfg "entries" eid
                                _ -> return ()
                        _ -> return ()
                    deleteTestRecord cfg "competitions" cid
                    deleteTestRecord cfg "profiles" (testProfileId ident)
                    deleteTestRecord cfg "local_users" (testAuthId ident)
                    assertBool ("expected 200, got " <> show code) (code >= 200 && code < 300)
        , -- Given a competition requiring at least two images
          -- When a participant submits a draft with no images
          -- Then HTTP 400 is returned by the server-side image limit hook
          testCase "participant cannot submit below competition image minimum -> 400" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            mKey <- lookupEnv "POCKETBASE_API_KEY"
            case (mUrl, mKey) of
                (Nothing, _) -> assertBool skipMsg True
                (_, Nothing) -> assertBool skipMsg True
                (Just url, Just key) -> do
                    let cfg = PbConfig (T.pack url) (T.pack key)
                    ident <- createVerifiedNonReviewerUser cfg "entry-submit-image-min@test.invalid"
                    cid <- createTestCompetitionWithImageLimits cfg 2 10
                    let body =
                            A.object
                                [ "title" A..= ("Incomplete Submit" :: T.Text)
                                , "competition" A..= cid
                                , "submitter" A..= testProfileId ident
                                , "status" A..= ("draft" :: T.Text)
                                ]
                    entryResult <- createRecord cfg "entries" body
                    case entryResult of
                        Left err -> do
                            deleteTestRecord cfg "competitions" cid
                            deleteTestRecord cfg "profiles" (testProfileId ident)
                            deleteTestRecord cfg "local_users" (testAuthId ident)
                            assertFailure $ "setup failed: " <> err
                        Right eid -> do
                            tok <- impersonateUser cfg ident
                            let patchUrl = url <> "/api/collections/entries/records/" <> T.unpack eid
                            code <-
                                patchWithToken
                                    patchUrl
                                    tok
                                    (A.object [("status", A.toJSON ("submitted" :: T.Text))])
                            deleteTestRecord cfg "entries" eid
                            deleteTestRecord cfg "competitions" cid
                            deleteTestRecord cfg "profiles" (testProfileId ident)
                            deleteTestRecord cfg "local_users" (testAuthId ident)
                            code @?= 400
        , -- Given a competition allowing only one image per submitted entry
          -- When a participant submits an entry with two uploaded images
          -- Then HTTP 400 is returned by the server-side image limit hook
          testCase "participant cannot submit above competition image maximum -> 400" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            mKey <- lookupEnv "POCKETBASE_API_KEY"
            case (mUrl, mKey) of
                (Nothing, _) -> assertBool skipMsg True
                (_, Nothing) -> assertBool skipMsg True
                (Just url, Just key) -> do
                    let cfg = PbConfig (T.pack url) (T.pack key)
                    ident <- createVerifiedNonReviewerUser cfg "entry-submit-image-max@test.invalid"
                    cid <- createTestCompetitionWithImageLimits cfg 0 1
                    tok <- impersonateUser cfg ident
                    let entryUrl = url <> "/api/collections/entries/records"
                        fields =
                            [ ("title", "Too Many Images")
                            , ("competition", TE.encodeUtf8 cid)
                            , ("submitter", TE.encodeUtf8 (testProfileId ident))
                            , ("status", "submitted")
                            ]
                    (code, respBody) <- postMultipartWithTokenBody entryUrl tok fields 2
                    case respBody of
                        A.Object km ->
                            case KM.lookup "id" km of
                                Just (A.String eid) ->
                                    deleteTestRecord cfg "entries" eid
                                _ -> return ()
                        _ -> return ()
                    deleteTestRecord cfg "competitions" cid
                    deleteTestRecord cfg "profiles" (testProfileId ident)
                    deleteTestRecord cfg "local_users" (testAuthId ident)
                    code @?= 400
        , -- Given a competition requiring at least two images
          -- When a reviewer approves an image-incomplete draft
          -- Then HTTP 400 is returned by the server-side image limit hook
          testCase "reviewer cannot approve below competition image minimum -> 400" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            mKey <- lookupEnv "POCKETBASE_API_KEY"
            case (mUrl, mKey) of
                (Nothing, _) -> assertBool skipMsg True
                (_, Nothing) -> assertBool skipMsg True
                (Just url, Just key) -> do
                    let cfg = PbConfig (T.pack url) (T.pack key)
                    participant <- createVerifiedNonReviewerUser cfg "entry-approve-image-min@test.invalid"
                    reviewer <- createReviewerUser cfg "entry-approve-reviewer@test.invalid"
                    cid <- createTestCompetitionWithImageLimits cfg 2 10
                    let body =
                            A.object
                                [ "title" A..= ("Incomplete Approval" :: T.Text)
                                , "competition" A..= cid
                                , "submitter" A..= testProfileId participant
                                , "status" A..= ("draft" :: T.Text)
                                ]
                    entryResult <- createRecord cfg "entries" body
                    case entryResult of
                        Left err -> do
                            deleteTestRecord cfg "competitions" cid
                            deleteTestRecord cfg "profiles" (testProfileId participant)
                            deleteTestRecord cfg "profiles" (testProfileId reviewer)
                            deleteTestRecord cfg "local_users" (testAuthId participant)
                            deleteTestRecord cfg "local_users" (testAuthId reviewer)
                            assertFailure $ "setup failed: " <> err
                        Right eid -> do
                            tok <- impersonateUser cfg reviewer
                            let patchUrl = url <> "/api/collections/entries/records/" <> T.unpack eid
                            code <-
                                patchWithToken
                                    patchUrl
                                    tok
                                    (A.object [("status", A.toJSON ("approved" :: T.Text))])
                            deleteTestRecord cfg "entries" eid
                            deleteTestRecord cfg "competitions" cid
                            deleteTestRecord cfg "profiles" (testProfileId participant)
                            deleteTestRecord cfg "profiles" (testProfileId reviewer)
                            deleteTestRecord cfg "local_users" (testAuthId participant)
                            deleteTestRecord cfg "local_users" (testAuthId reviewer)
                            code @?= 400
        , -- Given an unauthenticated GET on reviews (published only)
          -- Then HTTP 200 is returned
          testCase "anon can list published reviews -> 200" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            case mUrl of
                Nothing -> assertBool skipMsg True
                Just url -> do
                    req0 <-
                        parseRequest
                            (url <> "/api/collections/reviews/records?filter=is_published%3Dtrue")
                    resp <- httpLBS req0
                    getResponseStatusCode resp @?= 200
        , -- Given an entry upload with a client-compressed WebP image
          -- When the participant saves a draft
          -- Then PocketBase accepts the WebP file and returns HTTP 200
          testCase "participant can upload WebP entry image -> 200" $ do
            mUrl <- lookupEnv "POCKETBASE_URL"
            mKey <- lookupEnv "POCKETBASE_API_KEY"
            case (mUrl, mKey) of
                (Nothing, _) -> assertBool skipMsg True
                (_, Nothing) -> assertBool skipMsg True
                (Just url, Just key) -> do
                    let cfg = PbConfig (T.pack url) (T.pack key)
                    cid <- createTestCompetitionWithImageLimits cfg 1 5
                    participant <- createVerifiedNonReviewerUser cfg "entry-webp@test.invalid"
                    tok <- impersonateUser cfg participant
                    let postUrl = url <> "/api/collections/entries/records"
                        fields =
                            [ ("title", "WebP MOC")
                            , ("competition", TE.encodeUtf8 cid)
                            , ("submitter", TE.encodeUtf8 (testProfileId participant))
                            , ("status", "draft")
                            ]
                    (code, respBody) <- postMultipartWithWebpBody postUrl tok fields 1
                    case respBody of
                        A.Object km ->
                            case KM.lookup "id" km of
                                Just (A.String eid) -> deleteTestRecord cfg "entries" eid
                                _ -> return ()
                        _ -> return ()
                    deleteTestRecord cfg "competitions" cid
                    deleteTestRecord cfg "profiles" (testProfileId participant)
                    deleteTestRecord cfg "local_users" (testAuthId participant)
                    code @?= 200
        ]

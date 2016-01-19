{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE TypeSynonymInstances #-}

module PostgREST.Error (pgErrResponse, errResponse) where


import           Data.Aeson                ((.=))
import qualified Data.Aeson                as JSON
import           Data.Monoid               ((<>))
import           Data.String.Conversions   (cs)
import           Data.Text                 (Text)
import qualified Data.Text                 as T
import qualified Hasql.Session             as H
import           Network.HTTP.Types.Header
import qualified Network.HTTP.Types.Status as HT
import           Network.Wai               (Response, responseLBS)

errResponse :: HT.Status -> Text -> Response
errResponse status message = responseLBS status [(hContentType, "application/json")] (cs $ T.concat ["{\"message\":\"",message,"\"}"])

pgErrResponse :: H.Error -> Response
pgErrResponse e = responseLBS (httpStatus e)
  [(hContentType, "application/json")] (JSON.encode e)

instance JSON.ToJSON H.Error where
  toJSON (H.ResultError (H.ServerError c m d h)) = JSON.object [
    "code" .= (cs c::T.Text),
    "message" .= (cs m::T.Text),
    "details" .= (fmap cs d::Maybe T.Text),
    "hint" .= (fmap cs h::Maybe T.Text)]
  toJSON (H.ResultError (H.UnexpectedResult m)) = JSON.object [
    "message" .= (cs m::T.Text)]
  toJSON (H.ResultError (H.RowError i H.EndOfInput)) = JSON.object [
    "message" .= ("Row error: end of input"::String),
    "details" .=
      ("Attempt to parse more columns than there are in the result"::String),
    "details" .= ("Row number " <> show i)]
  toJSON (H.ResultError (H.RowError i H.UnexpectedNull)) = JSON.object [
    "message" .= ("Row error: unexpected null"::String),
    "details" .= ("Attempt to parse a NULL as some value."::String),
    "details" .= ("Row number " <> show i)]
  toJSON (H.ResultError (H.RowError i (H.ValueError d))) = JSON.object [
    "message" .= ("Row error: Wrong value parser used"::String),
    "details" .= d,
    "details" .= ("Row number " <> show i)]
  toJSON (H.ResultError (H.UnexpectedAmountOfRows i)) = JSON.object [
    "message" .= ("Unexpected amount of rows"::String),
    "details" .= i]
  toJSON (H.ClientError d) = JSON.object [
    "message" .= ("Database client error"::String),
    "details" .= (fmap cs d::Maybe T.Text)]

httpStatus :: H.Error -> HT.Status
httpStatus (H.ResultError (H.ServerError c _ _ _)) =
  case cs c of
    '0':'8':_ -> HT.status503 -- pg connection err
    '0':'9':_ -> HT.status500 -- triggered action exception
    '0':'L':_ -> HT.status403 -- invalid grantor
    '0':'P':_ -> HT.status403 -- invalid role specification
    '2':'5':_ -> HT.status500 -- invalid tx state
    '2':'8':_ -> HT.status403 -- invalid auth specification
    '2':'D':_ -> HT.status500 -- invalid tx termination
    '3':'8':_ -> HT.status500 -- external routine exception
    '3':'9':_ -> HT.status500 -- external routine invocation
    '3':'B':_ -> HT.status500 -- savepoint exception
    '4':'0':_ -> HT.status500 -- tx rollback
    '5':'3':_ -> HT.status503 -- insufficient resources
    '5':'4':_ -> HT.status413 -- too complex
    '5':'5':_ -> HT.status500 -- obj not on prereq state
    '5':'7':_ -> HT.status500 -- operator intervention
    '5':'8':_ -> HT.status500 -- system error
    'F':'0':_ -> HT.status500 -- conf file error
    'H':'V':_ -> HT.status500 -- foreign data wrapper error
    'P':'0':_ -> HT.status500 -- PL/pgSQL Error
    'X':'X':_ -> HT.status500 -- internal Error
    "42P01" -> HT.status404 -- undefined table
    "42501" -> HT.status404 -- insufficient privilege
    _ -> HT.status400
httpStatus (H.ResultError _) = HT.status500
httpStatus (H.ClientError _) = HT.status503

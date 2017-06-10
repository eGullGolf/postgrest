module Main where

import Test.Hspec
import SpecHelper

import qualified Hasql.Pool as P

import PostgREST.DbStructure (getDbStructure)
import PostgREST.App (postgrest)
import Control.AutoUpdate
import Data.Function (id)
import Data.IORef
import Data.Time.Clock.POSIX   (getPOSIXTime)

import qualified Feature.AsciiJwtSecretSpec
import qualified Feature.AuthSpec
import qualified Feature.BinaryJwtSecretSpec
import qualified Feature.ConcurrentSpec
import qualified Feature.CorsSpec
import qualified Feature.DeleteSpec
import qualified Feature.InsertSpec
import qualified Feature.NoJwtSpec
import qualified Feature.QueryLimitedSpec
import qualified Feature.QuerySpec
import qualified Feature.RangeSpec
import qualified Feature.StructureSpec
import qualified Feature.SingularSpec
import qualified Feature.UnicodeSpec
import qualified Feature.Utf8JwtSecretSpec
import qualified Feature.ProxySpec
import qualified Feature.AndOrParamsSpec

import Protolude

main :: IO ()
main = do
  testDbConn <- getEnvVarWithDefault "POSTGREST_TEST_CONNECTION" "postgres://postgrest_test@localhost/postgrest_test"
  setupDb testDbConn

  pool <- P.acquire (3, 10, toS testDbConn)
  -- ask for the OS time at most once per second
  getTime <- mkAutoUpdate
    defaultUpdateSettings { updateAction = getPOSIXTime }


  result <- P.use pool $ getDbStructure "test"
  refDbStructure <- newIORef $ Just $ either (panic.show) id result
  let withApp      = return $ postgrest (testCfg testDbConn)          refDbStructure pool getTime $ pure ()
      ltdApp       = return $ postgrest (testLtdRowsCfg testDbConn)   refDbStructure pool getTime $ pure ()
      unicodeApp   = return $ postgrest (testUnicodeCfg testDbConn)   refDbStructure pool getTime $ pure ()
      proxyApp     = return $ postgrest (testProxyCfg testDbConn)     refDbStructure pool getTime $ pure ()
      noJwtApp     = return $ postgrest (testCfgNoJWT testDbConn)     refDbStructure pool getTime $ pure ()
      asciiJwtApp  = return $ postgrest (testCfgAsciiJWT testDbConn)  refDbStructure pool getTime $ pure ()
      utf8JwtApp   = return $ postgrest (testCfgUtf8JWT testDbConn)  refDbStructure pool getTime $ pure ()
      binaryJwtApp = return $ postgrest (testCfgBinaryJWT testDbConn) refDbStructure pool getTime $ pure ()

  let reset = resetDb testDbConn
  hspec $ do
    mapM_ (beforeAll_ reset . before withApp) specs

    -- this test runs with a different server flag
    beforeAll_ reset . before ltdApp $
      describe "Feature.QueryLimitedSpec" Feature.QueryLimitedSpec.spec

    -- this test runs with a different schema
    beforeAll_ reset . before unicodeApp $
      describe "Feature.UnicodeSpec" Feature.UnicodeSpec.spec

    -- this test runs with a proxy
    beforeAll_ reset . before proxyApp $
      describe "Feature.ProxySpec" Feature.ProxySpec.spec

    -- this test runs without a JWT secret
    beforeAll_ reset . before noJwtApp $
      describe "Feature.NoJwtSpec" Feature.NoJwtSpec.spec

    -- this test runs with an ASCII plain text JWT secret
    beforeAll_ reset . before asciiJwtApp $
      describe "Feature.AsciiJwtSecretSpec" Feature.AsciiJwtSecretSpec.spec

    -- this test runs with a Utf-8 Unicode JWT secret
    beforeAll_ reset . before utf8JwtApp $
      describe "Feature.Utf8JwtSecretSpec" Feature.Utf8JwtSecretSpec.spec

    -- this test runs with a binary JWT secret
    beforeAll_ reset . before binaryJwtApp $
      describe "Feature.BinaryJwtSecretSpec" Feature.BinaryJwtSecretSpec.spec

 where
  specs = map (uncurry describe) [
      ("Feature.AuthSpec"         , Feature.AuthSpec.spec)
    , ("Feature.ConcurrentSpec"   , Feature.ConcurrentSpec.spec)
    , ("Feature.CorsSpec"         , Feature.CorsSpec.spec)
    , ("Feature.DeleteSpec"       , Feature.DeleteSpec.spec)
    , ("Feature.InsertSpec"       , Feature.InsertSpec.spec)
    , ("Feature.QuerySpec"        , Feature.QuerySpec.spec)
    , ("Feature.RangeSpec"        , Feature.RangeSpec.spec)
    , ("Feature.SingularSpec"     , Feature.SingularSpec.spec)
    , ("Feature.StructureSpec"    , Feature.StructureSpec.spec)
    , ("Feature.AndOrParamsSpec"  , Feature.AndOrParamsSpec.spec)
    ]

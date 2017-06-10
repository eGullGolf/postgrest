module Feature.Utf8JwtSecretSpec where

-- {{{ Imports
import Test.Hspec
import Test.Hspec.Wai
import Network.HTTP.Types

import SpecHelper
import Network.Wai (Application)

import Protolude hiding (get)
-- }}}

spec :: SpecWith Application
spec = describe "server started with UTF-8 Unicode JWT secret" $

  it "succeeds with jwt token encoded with the same secret" $ do
    let auth = authHeaderJWT "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoicG9zdGdyZXN0X3Rlc3RfYXV0aG9yIn0.VFfaoJohnDeJMA-awM6Y7blbOjXDNwmtx48Z-0bIKrE"
    request methodGet "/authors_only" [auth] ""
      `shouldRespondWith` 200

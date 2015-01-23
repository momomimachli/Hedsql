module Main where

import Test.Framework (defaultMain)

import Hedsql.Common.Parser.Queries.Tests
import Hedsql.Common.Parser.Quoter.Tests

-- | Run the tests.
main :: IO()
main = defaultMain
    [ Hedsql.Common.Parser.Queries.Tests.tests
    , Hedsql.Common.Parser.Quoter.Tests.tests
    ]
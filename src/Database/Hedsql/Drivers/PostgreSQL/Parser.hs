{-# LANGUAGE GADTs            #-}
{-# LANGUAGE FlexibleContexts #-}

{-|
Module      : Database/Hedsql/Drivers/PostgreSQL/Parser.hs
Description : PostgreSQL parser implementation.
Copyright   : (c) Leonard Monnier2014
License     : GPL-3
Maintainer  : leonard.monnier@gmail.com
Stability   : experimental
Portability : portable

PostgreSQL parser implementation.
-}
module Database.Hedsql.Drivers.PostgreSQL.Parser
    ( parse
    ) where
    
import Database.Hedsql.Common.Constructor.Statements
import Database.Hedsql.Common.DataStructure
import Database.Hedsql.Common.Parser
import Database.Hedsql.Drivers.PostgreSQL.Driver

import qualified Database.Hedsql.Common.Parser.TableManipulations as T

import Control.Lens
import Data.List (intercalate)

-- Private.

{-|
Return True if one of the provided constraint is a PRIMARY KEY.
with auto increment.
-}
hasAutoIncrement :: [ColConstraint a] -> Bool
hasAutoIncrement =
    all (\x -> isAIPK $ x^.colConstraintType)
    where
        isAIPK (Primary isAI) = isAI
        isAIPK _              = False

-- | Create the PostgreSQL parser.
postgreSQLParser :: Parser PostgreSQL
postgreSQLParser =
    getParser $ getStmtParser postgreSQLQueryParser postgreSQLTableParser

-- | Create the PostgreSQL query parser.
postgreSQLQueryParser :: QueryParser PostgreSQL
postgreSQLQueryParser = 
    getQueryParser
        postgreSQLQueryParser
        postgreSQLTableParser

-- | Create the PostgreSQL table manipulations parser.
postgreSQLTableParser :: T.TableParser PostgreSQL
postgreSQLTableParser =
    getTableParser postgreSQLQueryParser postgreSQLTableParser
        & T.parseColConstType .~ colConstFunc
        & T.parseColCreate    .~ colCreateFunc
    where
        colConstFunc  = parsePostgreSQLColConstTypeFunc postgreSQLTableParser
        colCreateFunc = parsePostgreSqlColCreateFunc    postgreSQLTableParser

{-|
The AUTOINCREMENT constraint is not a constraint in PostgreSQL.
Instead, the "serial" data type is used.

We must therefore remove the AUTOINCREMENT constraint when parsing
a PRIMARY KEY column constraint.
-}
parsePostgreSQLColConstTypeFunc ::
    T.TableParser a -> ColConstraintType a -> String
parsePostgreSQLColConstTypeFunc parser constraint =
    case constraint of
        (Primary _) -> "PRIMARY KEY"
        _           -> T.parseColConstTypeFunc parser constraint

{- |
    Custom function for PostgreSQL for the creation of a table.
    The difference with the default implementation is that a PRIMARY KEY of
    type Integer with an AUTOINCREMENT constraints get translated as a "serial".
-}
parsePostgreSqlColCreateFunc :: T.TableParser a -> ColWrap a -> String
parsePostgreSqlColCreateFunc parser (ColWrap col) =
        parseCols (DataTypeWrap $ col^.colDataType) (col^.colConstraints)        
    where
        parseCols (DataTypeWrap Integer) colConsts@(_:_) =
            if hasAutoIncrement colConsts
            then cName ++ " serial"  ++ consts colConsts
            else cName ++ " integer" ++ consts colConsts 
        parseCols colType colConsts = concat
            [ cName
            , " " ++ (parser^.T.parseDataType) colType
            , consts colConsts
            ]
        
        cName = parser^.T.quoteElem $ col^.colName
        
        consts [] = ""
        consts cs = " " ++ intercalate ", " (map (parser ^. T.parseColConst) cs) 

-- Public.

{-|
Convert a SQL statement (or something which can be coerced to a statement)
to a SQL string.
-}
parse :: ToStmt (a PostgreSQL) (Statement PostgreSQL) => a PostgreSQL -> String
parse = (postgreSQLParser^.parseStmt).statement  
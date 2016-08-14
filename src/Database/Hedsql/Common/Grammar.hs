{-# LANGUAGE GADTs #-}
{-|
Module      : Database/Hedsql/Commun/Grammar
Description : SQL Grammar
Copyright   : (c) Leonard Monnier, 2016
License     : GPL-3
Maintainer  : leonard.monnier@gmail.com
Stability   : experimental
Portability : portable

Description of the grammar to build SQL statements.
-}
module Database.Hedsql.Common.Grammar
    ( -- * Insert
      InsertFromStmt(..)
    , InsertReturningStmt(..)

      -- * Update
    , UpdateSetStmt(..)
    , UpdateWhereStmt(..)
    , UpdateReturningStmt(..)

      -- * Delete
    , DeleteFromStmt(..)
    , DeleteWhereStmt(..)
    , DeleteReturningStmt(..)
    ) where

import Database.Hedsql.Common.AST

--------------------------------------------------------------------------------
-- INSERT
--------------------------------------------------------------------------------

data InsertFromStmt dbVendor =
    InsertFromStmt (Table dbVendor) [Assignment dbVendor]

data InsertReturningStmt colType dbVendor =
    InsertReturningStmt (Returning colType dbVendor) (InsertFromStmt dbVendor)

--------------------------------------------------------------------------------
-- UPDATE
--------------------------------------------------------------------------------

data UpdateSetStmt dbVendor =
    UpdateSetStmt (Table dbVendor) [Assignment dbVendor]

data UpdateWhereStmt dbVendor =
    UpdateWhereStmt (Where dbVendor) (UpdateSetStmt dbVendor)

data UpdateReturningStmt colType dbVendor =
    UpdateReturningStmt (Returning colType dbVendor) (UpdateWhereStmt dbVendor)

--------------------------------------------------------------------------------
-- DELETE
--------------------------------------------------------------------------------

data DeleteFromStmt dbVendor =
    DeleteFromStmt (Table dbVendor)

data DeleteWhereStmt dbVendor =
    DeleteWhereStmt (Where dbVendor) (DeleteFromStmt dbVendor)

data DeleteReturningStmt colType dbVendor =
      DeleteFromReturningStmt
          (Returning colType dbVendor)
          (DeleteFromStmt dbVendor)
    | DeleteWhereReturningStmt
          (Returning colType dbVendor)
          (DeleteWhereStmt dbVendor)

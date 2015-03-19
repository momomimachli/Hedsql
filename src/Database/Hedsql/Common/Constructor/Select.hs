{-# LANGUAGE FlexibleContexts       #-}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses  #-}

{-|
Module      : Database/Hedsql/Common/Constructor/Queries.hs
Description : Constructor functions for SQL SELECT queries.
Copyright   : (c) Leonard Monnier, 2014
License     : GPL-3
Maintainer  : leonard.monnier@gmail.com
Stability   : experimental
Portability : portable

Constructor functions for SQL SELECT queries.
-}
module Database.Hedsql.Common.Constructor.Select
    (
      -- * SELECT part
      SelectConstr  
    , select
    , selectDistinct
    , isDistinctFrom
    , isNotDistinctFrom
    , (//*)
    , alias
    
      -- * FROM part
    , from    
    , crossJoin
    , fullJoin
    , innerJoin
    , leftJoin
    , rightJoin
    , naturalFullJoin
    , naturalInnerJoin
    , naturalLeftJoin
    , naturalRightJoin
    , subQuery
    
    -- * WHERE part
    , where_
    
    -- * GROUP BY part
    , groupBy
    , having
    
    -- * ORDER BY part
    , orderBy
    , asc
    , desc
    , sortRef
    , sortRefs
    , nullsFirst
    , nullsLast
    
    -- * LIMIT part
    , offset
    , limit
    
    -- * Combined queries
    , combinedQuery
    , except
    , exceptAll
    , intersect
    , intersectAll
    , union
    , unionAll
    ) where
 
--------------------------------------------------------------------------------
-- IMPORTS
--------------------------------------------------------------------------------
    
import Database.Hedsql.Common.Constructor.Columns
import Database.Hedsql.Common.Constructor.Conditions
import Database.Hedsql.Common.Constructor.Functions()
import Database.Hedsql.Common.Constructor.Tables
import Database.Hedsql.Common.Constructor.Types
import Database.Hedsql.Common.DataStructure

import Control.Lens hiding (coerce, from)
import Unsafe.Coerce

--------------------------------------------------------------------------------
-- PRIVATE
--------------------------------------------------------------------------------

-- | Coerce a type to a CombinedQuery type.
class ToCombined a b where
    toCombined :: a c -> b c

instance ToCombined CombinedQuery CombinedQuery where
    toCombined = id
 
instance ToCombined SelectWrap CombinedQuery where
    toCombined = Single

-- | Coerce a type to a list of JoinClause type.
class ToJoinClauses a b | a -> b where
    toJoinClauses :: a -> b
    
-- | Create an ON join clause from a boolean function.
instance ToJoinClauses (Expression Bool a) [JoinClause a] where
    toJoinClauses = list . JoinClauseOn

-- | Create an USING join clause from a column.
instance ToJoinClauses (Column b a) [JoinClause a] where
    toJoinClauses c = list $ JoinClauseUsing [ColWrap c]

-- | Create an USING join clause from a list of columns.
instance ToJoinClauses [Column b a] [JoinClause a] where
    toJoinClauses = list . JoinClauseUsing . map ColWrap

-- | Create an USING join clause from a string which is a column name.
instance ToJoinClauses (SqlString a) [JoinClause a] where
    toJoinClauses = list . JoinClauseUsing . map ColWrap . toCols

-- | Create an USING join clause from a list of strings which are column names.    
instance ToJoinClauses [SqlString a] [JoinClause a] where
    toJoinClauses = list . JoinClauseUsing . map ColWrap . toCols

-- | Coerce a type to a list of SortRef types.
class ToSortRefs a b | a -> b where
    toSortRefs :: a -> b

instance ToSortRefs (Column b a) [SortRef a] where
    toSortRefs c = [SortRef (ColRefWrap $ colRef c) Nothing Nothing]

instance ToSortRefs [Column b a] [SortRef a] where
    toSortRefs = map (\c -> SortRef (ColRefWrap $ colRef c) Nothing Nothing)

instance ToSortRefs (ColWrap a) [SortRef a] where
    toSortRefs (ColWrap c) = [SortRef (ColRefWrap $ colRef c) Nothing Nothing]

instance ToSortRefs [ColWrap a] [SortRef a] where
    toSortRefs =
        map (\(ColWrap c) -> SortRef (ColRefWrap $ colRef c) Nothing Nothing)

instance ToSortRefs (ColRef b a) [SortRef a] where
    toSortRefs ref = [SortRef (ColRefWrap ref) Nothing Nothing]

instance ToSortRefs [ColRef b a] [SortRef a] where
    toSortRefs = map (\ref -> SortRef (ColRefWrap ref) Nothing Nothing)

instance ToSortRefs (ColRefWrap a) [SortRef a] where
    toSortRefs ref = [SortRef ref Nothing Nothing]

instance ToSortRefs [ColRefWrap a] [SortRef a] where
    toSortRefs = map (\ref -> SortRef ref Nothing Nothing)

instance ToSortRefs (SqlString a) [SortRef a] where
    toSortRefs name = [SortRef (ColRefWrap $ colRef name) Nothing Nothing]

instance ToSortRefs [SqlString a] [SortRef a] where
    toSortRefs =
        map (\name -> SortRef (ColRefWrap $ colRef name) Nothing Nothing)

instance ToSortRefs (SortRef a) [SortRef a] where
    toSortRefs = list

instance ToSortRefs [SortRef a] [SortRef a] where
    toSortRefs = id

-- | Create a join on columns with a USING or ON clause.
columnJoin ::
   (
      ToTableRefs   a [TableRef   d]
   ,  ToTableRefs   b [TableRef   d]
   ,  ToJoinClauses c [JoinClause d]
   )
   => JoinTypeCol d
   -> a
   -> b
   -> c
   -> Join        d
columnJoin joinType tableRef1 tableRef2 clause =
    JoinColumn
         joinType
        (tableRef tableRef1)
        (tableRef tableRef2)
        (joinClause clause)

-- | Create a JOIN clause such as ON or USING.
joinClause :: ToJoinClauses a [JoinClause b] => a -> JoinClause b
joinClause = toJoinClause

-- | Convert an element to a list with itself as the only item.
list :: a -> [a]
list a = [a]
 
-- | Create a join on tables (CROSS or NATURAL join).
tableJoin ::
    (  ToTableRefs   a [TableRef c]
    ,  ToTableRefs   b [TableRef c]
    )
    => JoinTypeTable c
    -> a
    -> b
    -> Join c
tableJoin joinType tableRef1 tableRef2 =
    JoinTable
        joinType
        (tableRef tableRef1)
        (tableRef tableRef2)

-- | Convert a type to a join clause.
toJoinClause :: ToJoinClauses a [JoinClause b] => a -> JoinClause b
toJoinClause = head.toJoinClauses

--------------------------------------------------------------------------------
-- PUBLIC
--------------------------------------------------------------------------------

----------------------------------------
-- SELECT
----------------------------------------

type SqlString' b a = String

emptyBody :: SelectBody a
emptyBody =
    SelectBody
        Nothing
        Nothing
        Nothing
        Nothing
        Nothing

class SelectConstr a b | a -> b where
    -- | Create a SELECT query.
    select :: a -> b
    
instance SelectConstr (SqlString' b a) (Select [Undefined] a) where
    select s = USelect (ColRefWrap $ colRef s) emptyBody

instance SelectConstr [SqlString' b a] (Select [[Undefined]] a) where
    select ss = UsSelect (map (ColRefWrap . colRef) ss) emptyBody

instance SelectConstr (ColRefWrap a) (Select [Undefined] a) where
    select c = USelect c emptyBody

instance SelectConstr [ColRefWrap a] (Select [[Undefined]] a) where
    select cs = UsSelect cs emptyBody

instance SelectConstr (Column b a) (Select [b] a) where
    select c =
        TSelect (colRef column) emptyBody
        where
            -- Unsafe coercion to the correct phantom types parameter.
            column :: Column [b] a
            column = unsafeCoerce c

instance SelectConstr [Column b a] (Select [[b]] a) where
    select cs =
        TsSelect (colRefs columns) emptyBody
        where
            -- Unsafe coercion to the correct phantom types parameter.
            columns :: [Column [[b]] a]
            columns = unsafeCoerce cs

instance SelectConstr (ColWrap a) (Select [Undefined] a) where
    select (ColWrap c) = USelect (ColRefWrap $ colRef c) emptyBody

instance SelectConstr [ColWrap a] (Select [[Undefined]] a) where
    select cs =
        UsSelect (map (\(ColWrap c) -> ColRefWrap $ colRef c) cs) emptyBody

instance SelectConstr (ColRef b a) (Select [b] a) where
    select c = TSelect cRef emptyBody
        where
            -- Unsafe coercion to the correct phantom types parameter.
            cRef :: ColRef [b] a
            cRef = unsafeCoerce c

instance SelectConstr [ColRef b a] (Select [[b]] a) where
    select cs =
        TsSelect cRefs emptyBody
        where
            -- Unsafe coercion to the correct phantom types parameter.
            cRefs :: [ColRef [[b]] a]
            cRefs = unsafeCoerce cs

instance SelectConstr (Expression b a) (Select [b] a) where
    select c =
        TSelect (colRef cRef) emptyBody
        where
            -- Unsafe coercion to the correct phantom types parameter.
            cRef :: Expression [b] a
            cRef = unsafeCoerce c

-- | Create a SELECT DISTINCT query.
selectDistinct :: SelectConstr a (Select c b) => a -> Select c b
selectDistinct = set (selectBody . selectType) (Just Distinct) . select

-- | Create a IS DISTINCT FROM operator.
isDistinctFrom ::
    ( ToColRefs a [ColRef c d]
    , ToColRefs b [ColRef c d]
    )
    => a
    -> b
    -> Expression Bool d
isDistinctFrom colRef1 colRef2 =
    IsDistinctFrom (colRef colRef1) (colRef colRef2)

-- | Create a IS NOT DISTINCT FROM operator.
isNotDistinctFrom ::
    ( ToColRefs a [ColRef c d]
    , ToColRefs b [ColRef c d]
    )
    => a
    -> b
    -> Expression Bool d
isNotDistinctFrom colRef1 colRef2 =
    IsNotDistinctFrom (colRef colRef1) (colRef colRef2)

-- | Create a joker - "*" - character.
(//*) :: Expression [Undefined] a
(//*) = Joker

----------------------------------------
-- FROM
----------------------------------------

-- | Add a FROM clause to a SELECT query.
from :: ToTableRefs a [TableRef b] => a -> From b
from = From . tableRefs

-- | Create a CROSS JOIN.
crossJoin ::
    (  ToTableRefs a [TableRef c]
    ,  ToTableRefs b [TableRef c]
    )
    => a
    -> b
    -> Join c
crossJoin = tableJoin CrossJoin

-- | Create a FULL JOIN.
fullJoin ::
    ( ToTableRefs   a [TableRef   d]
    , ToTableRefs   b [TableRef   d]
    , ToJoinClauses c [JoinClause d]
    )
    => a      -- ^ First table reference.
    -> b      -- ^ Second table reference.
    -> c      -- ^ Join clause.
    -> Join d
fullJoin = columnJoin FullJoin

{-|
Create an INNER JOIN.
If the join clause is a condition or a boolean function, it will be an ON
clause.
If the join clause is a column, a string or a list of columns or strings, it
will be an USING clause.
-} 
innerJoin ::
    ( ToTableRefs   a [TableRef   d]
    , ToTableRefs   b [TableRef   d]
    , ToJoinClauses c [JoinClause d]
    )
    => a      -- ^ First table reference.
    -> b      -- ^ Second table reference.
    -> c      -- ^ Join clause.
    -> Join d
innerJoin = columnJoin InnerJoin

-- | Create a LEFT JOIN.
leftJoin ::
    ( ToTableRefs   a [TableRef   d]
    , ToTableRefs   b [TableRef   d]
    , ToJoinClauses c [JoinClause d]
    )
    => a -- ^ First table reference.
    -> b -- ^ Second table reference.
    -> c -- ^ Join clause.
    -> Join d
leftJoin = columnJoin LeftJoin

-- | Create a NATURAL FULL JOIN.
naturalFullJoin ::
    (  ToTableRefs a [TableRef c]
    ,  ToTableRefs b [TableRef c]
    )
    => a
    -> b
    -> Join c
naturalFullJoin = tableJoin NaturalFullJoin

-- | Create a NATURAL LEFT JOIN.
naturalLeftJoin ::
    (  ToTableRefs a [TableRef c]
    ,  ToTableRefs b [TableRef c]
    )
    => a
    -> b
    -> Join c
naturalLeftJoin = tableJoin NaturalLeftJoin

-- | Create a NATURAL INNER JOIN.
naturalInnerJoin ::
    (  ToTableRefs a [TableRef c]
    ,  ToTableRefs b [TableRef c]
    )
    => a
    -> b
    -> Join c
naturalInnerJoin = tableJoin NaturalInnerJoin

-- | Create a NATURAL RIGHT JOIN.
naturalRightJoin ::
    (  ToTableRefs a [TableRef c]
    ,  ToTableRefs b [TableRef c]
    )
    => a
    -> b
    -> Join c
naturalRightJoin = tableJoin NaturalRightJoin

-- | Create a RIGHT JOIN.
rightJoin ::
    ( ToTableRefs   a [TableRef d]
    , ToTableRefs   b [TableRef d]
    , ToJoinClauses c [JoinClause d]
    )
    => a      -- ^ First table reference.
    -> b      -- ^ Second table reference.
    -> c      -- ^ Join clause.
    -> Join d
rightJoin = columnJoin RightJoin

-- | Create a sub-query in a FROM clause.
subQuery ::
       Select  b a -- ^ Sub-query.
    -> String      -- ^ Alias of the sub-query.
    -> TableRef a  -- ^ Table reference.
subQuery sub name = SelectTableRef (SelectWrap sub) $ TableRefAs name []

----------------------------------------
-- WHERE
----------------------------------------

-- | Create a WHERE clause for a SELECT query.
where_ :: ToConditions a [Expression Bool b] => a -> Where b
where_ = Where . condition

----------------------------------------
-- ORDER BY
----------------------------------------

-- | Add an ORDER BY clause to a query.
orderBy ::
       ToSortRefs a [SortRef b]
    => a          -- ^ Sorting references.
    -> OrderBy b
orderBy cs = OrderBy (sortRefs cs) Nothing Nothing

{-|
Add an ascending sorting order (ASC) to a sort reference
(which can be a column reference).
-}
asc :: ToSortRefs a [SortRef b] => a -> SortRef b
asc ref =  set sortRefOrder (Just Asc) (sortRef ref)

{-|
Add a descending sorting order (DESC) to a sort reference
(which can be a column reference).
-}
desc :: ToSortRefs a [SortRef b] => a -> SortRef b
desc ref =  set sortRefOrder (Just Desc) (sortRef ref)

{-|
Convert a value to a sorting reference: a reference which can be used in an
ORDER BY clause.
-}
sortRef :: ToSortRefs a [SortRef b] => a -> SortRef b
sortRef = head.toSortRefs

{-|
Convert a value to a list of sorting reference:
references which can be used in an ORDER BY clause.
-}
sortRefs :: ToSortRefs a [SortRef b] => a -> [SortRef b]
sortRefs = toSortRefs

{-|
Add a nulls first option (NULLS FIRST) to a sort reference
(which can be a column reference).
-}
nullsFirst :: ToSortRefs a [SortRef b] => a -> SortRef b
nullsFirst sRef =  set sortRefNulls (Just NullsFirst) (sortRef sRef)

{-|
Add a nulls last option (NULLS LAST) to a sort reference
(which can be a column reference).
-}
nullsLast:: ToSortRefs a [SortRef b] => a -> SortRef b
nullsLast sRef =  set sortRefNulls (Just NullsLast) (sortRef sRef)

----------------------------------------
-- GROUP BY
----------------------------------------

-- | Create a GROUP BY clause.
groupBy :: ToColRefWraps a [ColRefWrap b] => a -> GroupBy b
groupBy cs = GroupBy (colRefWraps cs) Nothing

-- | Add a HAVING clause to a GROUP BY clause.
having :: ToConditions a [Expression Bool b] => a -> Having b
having = Having . condition

----------------------------------------
-- LIMIT
----------------------------------------

-- | Add a LIMIT clause to an ORDER BY part.
limit :: Int -> Limit a
limit = Limit

-- | Create an OFFSET clause.
offset :: Int -> Offset a
offset = Offset

----------------------------------------
-- Combined queries
----------------------------------------

-- | Create a combined query such as an INTERSECT, EXCEPT, etc.
combinedQuery ::
    ToCombined b CombinedQuery => b a -> CombinedQuery a
combinedQuery = toCombined

-- | Apply an EXCEPT to two queries.
except ::
    ( ToCombined a CombinedQuery
    , ToCombined b CombinedQuery
    )
    => a c
    -> b c
    -> CombinedQuery c
except c1 c2 = Except [combinedQuery c1, combinedQuery c2]

-- | Apply an EXCEPT ALL to two queries.
exceptAll ::
    ( ToCombined a CombinedQuery
    , ToCombined b CombinedQuery
    )
    => a c
    -> b c
    -> CombinedQuery c
exceptAll c1 c2 = ExceptAll [combinedQuery c1, combinedQuery c2]

-- | Apply an INTERSECT to two queries.
intersect ::
    ( ToCombined a CombinedQuery
    , ToCombined b CombinedQuery
    )
    => a c
    -> b c
    -> CombinedQuery c
intersect c1 c2 = Intersect [combinedQuery c1, combinedQuery c2]

-- | Apply an INTERSECT ALL to two queries.
intersectAll ::
    ( ToCombined a CombinedQuery
    , ToCombined b CombinedQuery
    )
    => a c
    -> b c
    -> CombinedQuery c
intersectAll c1 c2 = IntersectAll [combinedQuery c1, combinedQuery c2]

-- | Create an UNION operation between two queries.
union ::
    ( ToCombined a CombinedQuery
    , ToCombined b CombinedQuery
    )
    => a c
    -> b c
    -> CombinedQuery c
union c1 c2 = Union [combinedQuery c1, combinedQuery c2]

-- | Create an UNION ALL operation between two queries.
unionAll ::
    ( ToCombined a CombinedQuery
    , ToCombined b CombinedQuery
    )
    => a c
    -> b c
    -> CombinedQuery c
unionAll c1 c2 = UnionAll [combinedQuery c1, combinedQuery c2]
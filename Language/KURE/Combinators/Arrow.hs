-- |
-- Module: Language.KURE.Combinators.Arrow
-- Copyright: (c) 2012 The University of Kansas
-- License: BSD3
--
-- Maintainer: Neil Sculthorpe <neil@ittc.ku.edu>
-- Stability: beta
-- Portability: ghc
--
-- This module provides some utility arrow routing combinators.

module Language.KURE.Combinators.Arrow
           ( -- * Arrow Routing
             -- | The names 'result' and 'argument' are taken from Conal Elliott's semantic editor combinators.
             result
           , argument
           , toFst
           , toSnd
           , swap
           , fork
           , forkFirst
           , forkSecond
           , constant
) where

import Control.Category
import Control.Arrow

------------------------------------------------------------------------------------------

-- | Apply a pure function to the result of an 'Arrow'.
result :: Arrow bi => (b -> c) -> bi a b -> bi a c
result f a = a >>^ f
{-# INLINE result #-}

-- | Apply a pure function to the argument to an 'Arrow'.
argument :: Arrow bi => (a -> b) -> bi b c -> bi a c
argument f a = f ^>> a
{-# INLINE argument #-}

-- | Apply an 'Arrow' to the first element of a pair, discarding the second element.
toFst :: Arrow bi => bi a b -> bi (a,x) b
toFst f = fst ^>> f
{-# INLINE toFst #-}

-- | Apply an 'Arrow' to the second element of a pair, discarding the first element.
toSnd :: Arrow bi => bi a b -> bi (x,a) b
toSnd f = snd ^>> f
{-# INLINE toSnd #-}

-- | A pure 'Arrow' that swaps the elements of a pair.
swap :: Arrow bi => bi (a,b) (b,a)
swap = arr (\(a,b) -> (b,a))
{-# INLINE swap #-}

-- | A pure 'Arrow' that duplicates its argument.
fork :: Arrow bi => bi a (a,a)
fork = arr (\a -> (a,a))
{-# INLINE fork #-}

-- | Tag the result of an 'Arrow' with its argument.
forkFirst :: Arrow bi => bi a b -> bi a (b,a)
forkFirst sf = fork >>> first sf
{-# INLINE forkFirst #-}

-- | Tag the result of an 'Arrow' with its argument.
forkSecond :: Arrow bi => bi a b -> bi a (a,b)
forkSecond sf = fork >>> second sf
{-# INLINE forkSecond #-}

-- | An arrow with a constant result.
constant :: Arrow bi => b -> bi a b
constant b = arr (const b)
{-# INLINE constant #-}

-------------------------------------------------------------------------------

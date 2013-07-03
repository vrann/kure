{-# LANGUAGE ScopedTypeVariables, FlexibleContexts #-}

-- |
-- Module: Language.KURE.Pathfinder
-- Copyright: (c) 2012--2013 The University of Kansas
-- License: BSD3
--
-- Maintainer: Neil Sculthorpe <neil@ittc.ku.edu>
-- Stability: beta
-- Portability: ghc
--
-- This module provides combinators to find paths sub-nodes specified by a predicate.

module Language.KURE.Pathfinder
        (
        -- * Finding 'LocalPath's
        -- ** Context Transformers
        -- | To find a 'LocalPath' to a node that satisfies a predicate, use @withLocalPathT (tt (acceptLocalPath q))@,
        --   where @q@ is a translation returning @Bool@, and @tt@ is a traversal strategy, such as 'collectT' or 'onetdT'.
        --   This will handle the tracking of the local path.
        --   See the example pathfinders below.
          WithLocalPath
        , withLocalPathT
        , exposeLocalPathT
        , acceptLocalPathT
        -- ** Example Pathfinders
        , pathsToT
        , onePathToT
        , oneNonEmptyPathToT
        , prunePathsToT
        , uniquePathToT
        , uniquePrunePathToT
) where

import Control.Category hiding ((.))
import Control.Arrow
import Data.Monoid (mempty)

import Language.KURE.MonadCatch
import Language.KURE.Translate
import Language.KURE.Combinators.Translate
import Language.KURE.Path
import Language.KURE.Walker
import Language.KURE.ExtendableContext

-------------------------------------------------------------------------------

type WithLocalPath c crumb = ExtendContext c (LocalPath crumb)

-- | Apply a translation that stores a 'LocalPath' in the context (starting at the current node).
withLocalPathT :: Translate (WithLocalPath c crumb) m a b -> Translate c m a b
withLocalPathT = liftContext (extendContext mempty)
{-# INLINE withLocalPathT #-}

-- | Extract the current 'LocalPath' from the context.
exposeLocalPathT :: Monad m => Translate (WithLocalPath c crumb) m a (LocalPath crumb)
exposeLocalPathT = contextT >>^ extraContext
{-# INLINE exposeLocalPathT #-}

-- | Return the current 'LocalPath' if the predicate translation succeeds.
acceptLocalPathT :: Monad m => Translate c m g Bool -> Translate (WithLocalPath c crumb) m g (LocalPath crumb)
acceptLocalPathT q = accepterR (liftContext baseContext q) >>> exposeLocalPathT
{-# INLINE acceptLocalPathT #-}

-------------------------------------------------------------------------------

-- | Find the 'Path's to every node that satisfies the predicate.
pathsToT :: (Walker (WithLocalPath c crumb) g, MonadCatch m) => Translate c m g Bool -> Translate c m g [LocalPath crumb]
pathsToT q = withLocalPathT (collectT $ acceptLocalPathT q)
{-# INLINE pathsToT #-}

-- | Find the 'Path's to every node that satisfies the predicate, ignoring nodes below successes.
prunePathsToT :: (Walker (WithLocalPath c crumb) g, MonadCatch m) => Translate c m g Bool -> Translate c m g [LocalPath crumb]
prunePathsToT q = withLocalPathT (collectPruneT $ acceptLocalPathT q)
{-# INLINE prunePathsToT #-}

-- | Find the 'Path' to the first node that satisfies the predicate (in a pre-order traversal).
onePathToT :: forall c crumb g m. (Walker (WithLocalPath c crumb) g, MonadCatch m) => Translate c m g Bool -> Translate c m g (LocalPath crumb)
onePathToT q = setFailMsg "No matching nodes found." $
               withLocalPathT (onetdT $ acceptLocalPathT q)
{-# INLINE onePathToT #-}

-- | Find the 'Path' to the first descendent node that satisfies the predicate (in a pre-order traversal).
oneNonEmptyPathToT :: (Walker (WithLocalPath c crumb) g, MonadCatch m) => Translate c m g Bool -> Translate c m g (LocalPath crumb)
oneNonEmptyPathToT q = setFailMsg "No matching nodes found." $
                       withLocalPathT (oneT $ onetdT $ acceptLocalPathT q)
{-# INLINE oneNonEmptyPathToT #-}


-- local function used by uniquePathToT and uniquePrunePathToT
requireUniquePath :: Monad m => Translate c m [LocalPath crumb] (LocalPath crumb)
requireUniquePath = contextfreeT $ \ ps -> case ps of
                                             []  -> fail "No matching nodes found."
                                             [p] -> return p
                                             _   -> fail $ "Ambiguous: " ++ show (length ps) ++ " matching nodes found."
{-# INLINE requireUniquePath #-}

-- | Find the 'Path' to the node that satisfies the predicate, failing if that does not uniquely identify a node.
uniquePathToT :: (Walker (WithLocalPath c crumb) g, MonadCatch m) => Translate c m g Bool -> Translate c m g (LocalPath crumb)
uniquePathToT q = pathsToT q >>> requireUniquePath
{-# INLINE uniquePathToT #-}

-- | Build a 'Path' to the node that satisfies the predicate, failing if that does not uniquely identify a node (ignoring nodes below successes).
uniquePrunePathToT :: (Walker (WithLocalPath c crumb) g, MonadCatch m) => Translate c m g Bool -> Translate c m g (LocalPath crumb)
uniquePrunePathToT q = prunePathsToT q >>> requireUniquePath
{-# INLINE uniquePrunePathToT #-}

-------------------------------------------------------------------------------

{-# LANGUAGE DeriveDataTypeable    #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverlappingInstances  #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE StandaloneDeriving    #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE UndecidableInstances  #-}
{-# OPTIONS_GHC -fno-warn-orphans  #-}

-- |
-- Module      : $Header$
-- Description : A modifier that can contain exactly one out of multiple modifiers of possible
--               different types.
-- Copyright   : (c) Benno Fünfstück
-- License     : GPL-3
--
-- Maintainer  : benno.fuenfstueck@gmail.com
-- Stability   : experimental
-- Portability : non-portable (uses various GHC-specific extensions)
module Data.VPlan.Modifier.Enum (
    (:><:)(R,L)
  , Close(..)
  , enumValue
  , enumSchedule
  , enumItem
  , scheduleItem
  , EnumContains
  ) where

import           Control.Applicative
import           Control.Lens
import           Data.Data
import           Data.Void
import qualified Data.VPlan.At       as A
import           Data.VPlan.Builder
import           Data.VPlan.Schedule
import           Data.VPlan.TH

-- | An Either for types with one type argument (which is passed to both sides)
data (:><:) a b s = L (a s) | R (b s) deriving (Eq)
infixr 7 :><:

makeModifier ''(:><:)
deriving instance (Typeable s, Typeable1 a, Typeable1 b, Data (b s), Data (a s)) => Data ((:><:) a b s)

-- | Shorter alias
type C = (:><:)

-- | This type signalizes the end of a chain of (:><:)'s.
data Close a = Close Void deriving (Eq)
makeModifier ''Close

deriving instance (Data a) => Data (Close a)

instance A.Contains f (Close a) where contains _ _ (Close v) = absurd v
instance A.Ixed f (Close a) where ix _ _ (Close v)           = absurd v

-- | Require that a type enum can contain the given value
class EnumContains a b where

  -- | Create an enum with the given value.
  enumValue :: a s -> b s

instance                       EnumContains a a       where enumValue = id
instance                       EnumContains a (C a b) where enumValue = L
instance (EnumContains c  b) => EnumContains c (C a b) where enumValue = R . enumValue

instance (A.Contains f (a s), A.Contains f (b s), Index (a s) ~ Index s, Index (b s) ~ Index s,
          Functor f) => A.Contains f (C a b s) where
  contains i f (L x) = L <$> A.contains i f x
  contains i f (R x) = R <$> A.contains i f x

instance (A.Ixed f (a s), Functor f, A.Ixed f (b s), Index (a s) ~ Index s, Index (b s) ~ Index s,
          IxValue (a s) ~ IxValue s, IxValue (b s) ~ IxValue s) => A.Ixed f (C a b s) where
  ix i f (L x) = L <$> A.ix i f x
  ix i f (R x) = R <$> A.ix i f x

-- | Build a value as a schedule containing an enum.
enumSchedule :: (EnumContains a s) => a (Schedule i v s) -> Schedule i v s
enumSchedule = view schedule . enumValue

-- | Build an enum value as a single item.
enumItem :: (EnumContains a e) => a (Schedule i v s) -> Builder (e (Schedule i v s)) ()
enumItem = item . enumValue

-- | Build an enum value as a single schedule item.
scheduleItem :: (EnumContains a s) => a (Schedule i v s) -> Builder (Schedule i v s) ()
scheduleItem = item . enumSchedule

instance (EnumContains m s) => Supported m (Schedule i v s) where new = enumSchedule
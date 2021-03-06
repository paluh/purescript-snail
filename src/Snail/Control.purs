module Snail.Control where

import Prelude hiding (when)

import Control.Monad.Error.Class (throwError)
import Control.Monad.Rec.Class (forever)
import Data.Either (Either(..))
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Data.Time.Duration (Milliseconds(..))
import Effect.Aff (Aff, attempt, delay)
import Effect.Exception as Error
import Node.FS.Aff as FS
import Snail.Types as T

-- | Pause the script for a given number of seconds
sleep :: Int -> Aff Unit
sleep n = delay (Milliseconds (toNumber $ n * 1000))

-- | Given a number of seconds n and a computation c, loop c every n seconds
loop :: forall a b. Int -> Aff a -> Aff b
loop n sn = forever $ sn *> sleep n

-- | Extract the value of a Just, failing with a given error message otherwise.
fromJust :: forall a. String -> Maybe a -> Aff a
fromJust _ (Just a) = pure a
fromJust msg _ = throwError $ Error.error msg

-- | Extract the value of a Maybe with a default if Nothing is found.
fromMaybe :: forall a. a -> Maybe a -> Aff a
fromMaybe _ (Just a) = pure a
fromMaybe a _ = pure a

-- | Extract the Right value of an Either, otherwise turn the Left into an error.
fromEither :: forall a b. Show a => Either a b -> Aff b
fromEither (Left a) = throwError $ Error.error $ show a
fromEither (Right b) = pure b

existsCheck :: forall a b. T.Address a => a -> Aff b -> Aff b
existsCheck f tr = exists f >>= if _
  then tr
  else throwError $ Error.error $ T.getAddress f <> " does not exist"

notExistsCheck :: forall a b. T.Address a => a -> Aff b -> Aff b
notExistsCheck f tr = do
  e <- exists f
  if not e
     then tr
     else throwError $ Error.error $ T.getAddress f <> " already exists"

-- | Run the first computation, and stop if that fails. Otherwise run the second.
andandand :: forall a b. Aff a -> Aff b -> Aff b
andandand sa sb = attempt sa >>= case _ of
  Left e -> throwError e
  _ -> sb

infixr 3 andandand as &&&

-- | Run the first computation, and stop if it succeeds.
ororor :: forall a b. Aff a -> Aff b -> Aff Unit
ororor sa sb = attempt sa >>= case _ of
  Right _ -> pure unit
  _ -> void sb

infixr 2 ororor as |||

-- | Check if a file or folder exists
exists :: forall address. T.Address address => address -> Aff Boolean
exists = FS.exists <<< T.getAddress

-- | Given a monadic boolean, run either the first thunked computation or the second.
mIf :: forall m a. Bind m => m Boolean -> (Unit -> m a) -> (Unit -> m a) -> m a
mIf b f g = b >>= if _
  then f unit
  else g unit

infixr 1 mIf as ~~>

-- | Run a given computation when a monadic boolean is true.
when :: forall m a. Monad m => m Boolean -> (Unit -> m a) -> m Unit
when mb ma = mb ~~> void <<< ma $ \_ -> pure unit

infixr 1 when as ~?>

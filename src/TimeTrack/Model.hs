{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module TimeTrack.Model
  ( Activity (..)
  , Task (..)
  , Tab (..)
  , Sheet (..)
  , Persisted (..)
  , Model (..)
  , Action (..)
  , activities
  , activityEmoji
  , activityName
  , initialModel
  , tasksForDay
  , timeLabel
  , updateModel
  ) where

import Control.Monad (when)
import Data.List (sortBy)
import Data.Ord (comparing)
import GHC.Generics (Generic)
import Miso (Effect, bts, get, io, io_, modify, web, withSink)
import Miso.JSON (FromJSON, ToJSON, decode, encode)
import Miso.String (MisoString, ms)
import TimeTrack.Store (dateForOffset, loadRaw, nowTime, saveRaw)

--------------------------------------------------------------------------------
-- Domain
--------------------------------------------------------------------------------

data Activity
  = Eat
  | Dishes
  | Cleaning
  | Call
  | Socialize
  | Read
  | Coding
  | Sleep
  | Plan
  | Journal
  | Socials
  | Dailies
  | Laundry
  | Writing
  | Walk
  | Shower
  deriving stock (Eq, Ord, Enum, Bounded, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

activities :: [Activity]
activities = [minBound .. maxBound]

activityEmoji :: Activity -> MisoString
activityEmoji = \case
  Eat -> "🍽️"
  Dishes -> "🍽️"
  Cleaning -> "🧹"
  Call -> "📞"
  Socialize -> "🗣️"
  Read -> "📖"
  Coding -> "💻"
  Sleep -> "😴"
  Plan -> "🗓️"
  Journal -> "📔"
  Socials -> "📱"
  Dailies -> "✅"
  Laundry -> "🧺"
  Writing -> "✍️"
  Walk -> "🚶"
  Shower -> "🚿"

activityName :: Activity -> MisoString
activityName = ms . show

--------------------------------------------------------------------------------

data Task = Task
  { taskId :: Int
  , taskDay :: MisoString
  , taskTime :: MisoString
  , taskActivity :: Activity
  , taskNote :: MisoString
  } deriving stock (Eq, Show, Generic)
    deriving anyclass (ToJSON, FromJSON)

data Tab = LogTab | TapTab
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

data Sheet
  = NoSheet
  | NoteSheet Int MisoString
  | EditSheet Int MisoString MisoString
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

data Persisted = Persisted
  { persistedTasks :: [Task]
  , persistedNextId :: Int
  } deriving stock (Eq, Show, Generic)
    deriving anyclass (ToJSON, FromJSON)

data Model = Model
  { modelTasks :: [Task]
  , modelDayOffset :: Int
  , modelDate :: MisoString
  , modelTab :: Tab
  , modelLastActivity :: Maybe Activity
  , modelLastTime :: MisoString
  , modelSheet :: Sheet
  , modelNextId :: Int
  } deriving stock (Eq, Show, Generic)
    deriving anyclass (ToJSON, FromJSON)

initialModel :: Model
initialModel = Model
  { modelTasks = []
  , modelDayOffset = 0
  , modelDate = "…"
  , modelTab = TapTab
  , modelLastActivity = Nothing
  , modelLastTime = ""
  , modelSheet = NoSheet
  , modelNextId = 1
  }

persisted :: Model -> Persisted
persisted m = Persisted (modelTasks m) (modelNextId m)

tasksForDay :: Model -> [Task]
tasksForDay m = sortBy (comparing taskTime) (filter ((== modelDate m) . taskDay) (modelTasks m))

timeLabel :: Activity -> MisoString -> MisoString
timeLabel a t = activityEmoji a <> " " <> activityName a <> " logged at " <> t

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

data Action
  = Boot
  | Restored (Maybe Persisted)
  | Tap Activity
  | Logged Int Activity MisoString MisoString
  | OpenNote Int
  | OpenEdit Int
  | SetNote MisoString
  | SetEditNote MisoString
  | SetEditTime MisoString
  | SaveNote
  | SaveEdit
  | DeleteTask Int
  | ShiftDay Int
  | DayChanged Int MisoString
  | GoTab Tab
  | CloseSheet
  deriving stock (Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------

updateModel :: Action -> Effect () () Model Action
updateModel = \case
  Boot -> do
    -- Native: only the background thread owns the model and native modules.
    -- Web: there is only one thread, so load there too.
    when (bts || web) $ do
      withSink $ \sink -> loadRaw (sink . Restored . (>>= decode))
      m <- get
      io (DayChanged (modelDayOffset m) <$> dateForOffset (modelDayOffset m))

  Restored Nothing -> pure ()
  Restored (Just p) -> do
    modify $ \m -> m
      { modelTasks = persistedTasks p
      , modelNextId = persistedNextId p
      }

  DayChanged off d ->
    modify $ \m -> m { modelDayOffset = off, modelDate = d }

  Tap a -> do
    m <- get
    let ident = modelNextId m
    io $ do
      t <- nowTime
      d <- dateForOffset 0
      pure (Logged ident a t d)

  Logged ident a t d -> do
    modify $ \m -> m
      { modelTasks = modelTasks m ++ [Task ident d t a ""]
      , modelNextId = ident + 1
      , modelLastActivity = Just a
      , modelLastTime = t
      , modelDayOffset = 0
      , modelDate = d
      }
    persist

  OpenNote tid -> do
    m <- get
    let note = maybe "" taskNote (findTask tid m)
    modify $ \x -> x { modelSheet = NoteSheet tid note }

  OpenEdit tid -> do
    m <- get
    case findTask tid m of
      Nothing -> pure ()
      Just t -> modify $ \x -> x { modelSheet = EditSheet tid (taskNote t) (taskTime t) }

  SetNote s ->
    modify $ \m -> m { modelSheet = case modelSheet m of
                                     NoteSheet i _ -> NoteSheet i s
                                     other -> other }

  SetEditNote s ->
    modify $ \m -> m { modelSheet = case modelSheet m of
                                     EditSheet i _ t -> EditSheet i s t
                                     other -> other }

  SetEditTime s ->
    modify $ \m -> m { modelSheet = case modelSheet m of
                                     EditSheet i n _ -> EditSheet i n s
                                     other -> other }

  SaveNote -> do
    m <- get
    case modelSheet m of
      NoteSheet i note -> updateTask i (\t -> t { taskNote = note })
      _ -> pure ()
    closeAndPersist

  SaveEdit -> do
    m <- get
    case modelSheet m of
      EditSheet i note t -> updateTask i (\x -> x { taskNote = note, taskTime = normaliseTime t })
      _ -> pure ()
    closeAndPersist

  DeleteTask i -> do
    modify $ \m -> m { modelTasks = filter ((/= i) . taskId) (modelTasks m)
                     , modelSheet = NoSheet
                     }
    persist

  ShiftDay n -> do
    m <- get
    let off = modelDayOffset m + n
    io (DayChanged off <$> dateForOffset off)

  GoTab t -> modify $ \m -> m { modelTab = t }

  CloseSheet -> modify $ \m -> m { modelSheet = NoSheet }

--------------------------------------------------------------------------------

findTask :: Int -> Model -> Maybe Task
findTask i = go . modelTasks
  where
    go [] = Nothing
    go (x:xs) | taskId x == i = Just x
              | otherwise = go xs

updateTask :: Int -> (Task -> Task) -> Effect () () Model Action
updateTask i f = modify $ \m -> m { modelTasks = map change (modelTasks m) }
  where
    change t | taskId t == i = f t
             | otherwise = t

closeAndPersist :: Effect () () Model Action
closeAndPersist = do
  modify $ \m -> m { modelSheet = NoSheet }
  persist

persist :: Effect () () Model Action
persist = do
  m <- get
  when (bts || web) (io_ (saveRaw (encode (persisted m))))

normaliseTime :: MisoString -> MisoString
normaliseTime s
  | valid = s
  | otherwise = "00:00"
  where
    raw = ms s
    valid = case break (== ':') raw of
      (h, ':':m') -> length h <= 2 && length m' == 2
                     && all (`elem` ("0123456789" :: String)) (h ++ m')
      _ -> False

{-# LANGUAGE CPP #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module TimeTrack.Store
  ( nowTime
  , dateForOffset
  , loadRaw
  , saveRaw
  ) where

import qualified Miso.Date as D
import Miso.String (MisoString, ms)
#ifdef NATIVE
import Miso.JSON (Value (..))
import Miso.Native.Module (callNativeModule, callNativeModuleWith)
#else
import Miso.Storage (getLocalStorage, setLocalStorage)
#endif

--------------------------------------------------------------------------------
-- Wall clock. Miso.Date wraps the JS Date global in both the browser and Lynx.
--------------------------------------------------------------------------------

pad2 :: Int -> String
pad2 n | n < 10 = '0' : show n
       | otherwise = show n

nowTime :: IO MisoString
nowTime = do
  d <- D.new
  h <- D.getHours d
  m <- D.getMinutes d
  pure (ms (pad2 h ++ ":" ++ pad2 m))

dateForOffset :: Int -> IO MisoString
dateForOffset n = do
  d <- D.new
  day <- D.getDate d
  _ <- D.setDate (day + n) d
  y <- D.getFullYear d
  mo <- D.getMonth d
  da <- D.getDate d
  pure (ms (show y ++ "-" ++ pad2 (mo + 1) ++ "-" ++ pad2 da))

--------------------------------------------------------------------------------
-- Persistence
--------------------------------------------------------------------------------

storageKey :: MisoString
storageKey = "timetrack/model-v1"

#ifdef NATIVE
-- The Android host registers NativeLocalStorageModule; miso's native module
-- bridge calls it on the background thread.
loadRaw :: (Maybe MisoString -> IO ()) -> IO ()
loadRaw cb =
  callNativeModuleWith "NativeLocalStorageModule" "getStorageItem" [String storageKey] $ \case
    Right v -> cb (Just v)
    Left _ -> cb Nothing

saveRaw :: MisoString -> IO ()
saveRaw raw =
  callNativeModule "NativeLocalStorageModule" "setStorageItem" [String storageKey, String raw]
#else
loadRaw :: (Maybe MisoString -> IO ()) -> IO ()
loadRaw cb = getLocalStorage storageKey >>= cb

saveRaw :: MisoString -> IO ()
saveRaw = setLocalStorage storageKey
#endif

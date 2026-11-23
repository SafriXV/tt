{-# LANGUAGE CPP #-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE JavaScriptFFI #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module TimeTrack.Store
  ( nowTime
  , dateForOffset
  , loadRaw
  , saveRaw
  ) where

import Miso.String (MisoString, pack)
#ifdef NATIVE
import Miso.JSON (Value (..))
import Miso.Native.Module (callNativeModule, callNativeModuleWith)
#else
import Miso.Storage (getLocalStorage, setLocalStorage)
#endif

--------------------------------------------------------------------------------
-- Wall clock. GHCJS exposes the JS Date global in both the browser and Lynx.
--------------------------------------------------------------------------------

foreign import javascript unsafe "new Date().getHours()"
  jsHours :: IO Int

foreign import javascript unsafe "new Date().getMinutes()"
  jsMinutes :: IO Int

foreign import javascript unsafe
  "(function(n){var d=new Date();d.setDate(d.getDate()+n);\
  \return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');})($1)"
  jsDateOffset :: Int -> IO MisoString

pad2 :: Int -> String
pad2 n | n < 10 = '0' : show n
       | otherwise = show n

nowTime :: IO MisoString
nowTime = do
  h <- jsHours
  m <- jsMinutes
  pure (fromString' (pad2 h ++ ":" ++ pad2 m))

fromString' :: String -> MisoString
fromString' = pack

dateForOffset :: Int -> IO MisoString
dateForOffset = jsDateOffset

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

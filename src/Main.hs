{-# LANGUAGE CPP #-}
#ifdef NATIVE
{-# LANGUAGE StaticPointers #-}
#endif

module Main where

import Miso (Component (..), component)
import TimeTrack.Model (Action (..), Model, initialModel, updateModel)
import TimeTrack.View (viewModel)
#ifdef NATIVE
import Miso.Native (mountStatic, native, nativeEvents, nativeXEvents)
#else
import Miso (defaultEvents, startApp)
#endif

app :: Component () () Model Action
app = (component initialModel updateModel viewModel) { mount = Just Boot }

#ifdef NATIVE
main :: IO ()
main = native (nativeEvents <> nativeXEvents) (static (mountStatic app))
#else
main :: IO ()
main = startApp defaultEvents app
#endif

{-# LANGUAGE CPP #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module TimeTrack.View (viewModel) where

import Miso (Attribute, View, text)
import Miso.String (MisoString)
import TimeTrack.Model

#ifdef NATIVE
import Miso.Native (scrollView_, text_, view_)
import Miso.Native.Element.View.Event (onTap)
import Miso.Native.X.Element (input_)
import Miso.Native.X.Element.Input.Event (inputValue, onInput)
import Miso.Property (textProp)
import qualified Miso.Html.Property as P
#else
import qualified Miso.Html.Element as H
import qualified Miso.Html.Event as E
import qualified Miso.Html.Property as P
#endif

type V = View () () Model Action

--------------------------------------------------------------------------------
-- Platform adapters. Everything below these definitions is shared.
--------------------------------------------------------------------------------

#ifdef NATIVE
node :: MisoString -> [Attribute Model Action] -> [V] -> V
node cls attrs kids = view_ (P.className cls : attrs) kids

scroller :: [V] -> V
scroller = scrollView_ []

label :: MisoString -> MisoString -> V
label cls s = text_ [P.className cls] [text s]

tap :: Action -> Attribute Model Action
tap = onTap

textInput :: MisoString -> MisoString -> MisoString -> (MisoString -> Action) -> V
textInput cls ph val setter =
  input_ [ P.className cls
         , textProp "placeholder" ph
         , textProp "value" val
         , onInput (setter . inputValue)
         ]
#else
node :: MisoString -> [Attribute Model Action] -> [V] -> V
node cls attrs kids = H.div_ (P.class_ cls : attrs) kids

scroller :: [V] -> V
scroller = H.div_ [P.class_ "page"]

label :: MisoString -> MisoString -> V
label cls s = H.span_ [P.class_ cls] [text s]

tap :: Action -> Attribute Model Action
tap = E.onClick

textInput :: MisoString -> MisoString -> MisoString -> (MisoString -> Action) -> V
textInput cls ph val setter =
  H.input_
    [ P.class_ cls
    , P.type_ "text"
    , P.placeholder_ ph
    , P.value_ val
    , E.onInput setter
    ]
#endif

--------------------------------------------------------------------------------
-- View
--------------------------------------------------------------------------------

viewModel :: Model -> V
viewModel m =
  node "page" []
    [ node "header" []
        [ node "title-wrap" []
            [ label "title" "TimeTrack"
            , label "subtitle" "Tap it. Log it. Get on with your day."
            ]
        ]
    , dateRow m
    , tabs m
    , case modelTab m of
        TapTab -> scroller (grid m)
        LogTab -> scroller (logView m)
    , feedback m
    , sheet m
    ]

dateRow :: Model -> V
dateRow m =
  node "date-row" []
    [ node "arrow-button" [tap (ShiftDay (-1))] [label "arrow" "‹"]
    , label "date" (modelDate m)
    , node "arrow-button" [tap (ShiftDay 1)] [label "arrow" "›"]
    ]

tabs :: Model -> V
tabs m =
  node "tabs" []
    [ node (tabClass TapTab (modelTab m)) [tap (GoTab TapTab)] [label "tab-text" "Tap"]
    , node (tabClass LogTab (modelTab m) <> "-last") [tap (GoTab LogTab)] [label "tab-text" "Log"]
    ]
  where
    tabClass t active = if t == active then "tab-active" else "tab"

grid :: Model -> [V]
grid m =
  [ node "grid" [] (map tile activities)
  , label "hint" "Every tap logs the activity at the current time."
  ]
  where
    tile a =
      let flashing = modelLastActivity m == Just a
      in node (if flashing then "tile-flash" else "tile") [tap (Tap a)]
           [ label "tile-emoji" (activityEmoji a)
           , label "tile-name" (activityName a)
           ]

feedback :: Model -> V
feedback m =
  case modelLastActivity m of
    Nothing -> label "feedback-empty" "No activity logged yet — pick an icon above."
    Just a -> node "feedback" [tap (OpenNote newestId)]
      [ label "feedback-text"
          (timeLabel a (modelLastTime m) <> "  ✎ add note")
      ]
  where
    newestId = case [ taskId t | t <- tasksForDay m
                               , Just (taskActivity t) == modelLastActivity m ] of
      [] -> 0
      xs -> last xs

logView :: Model -> [V]
logView m =
  case tasksForDay m of
    [] -> [label "empty" "Nothing logged for this day yet."]
    ts -> map row ts
  where
    row t =
      node "log-item" []
        [ label "log-emoji" (activityEmoji (taskActivity t))
        , node "log-body" []
            [ label "log-time" (taskTime t)
            , label "log-name" (activityName (taskActivity t))
            , if taskNote t == ""
                then label "log-note" ""
                else label "log-note" (taskNote t)
            ]
        , node "log-actions" []
            [ node "icon-button" [tap (OpenEdit (taskId t))] [label "icon-text" "✎"]
            , node "icon-button-danger" [tap (DeleteTask (taskId t))] [label "icon-text" "✕"]
            ]
        ]

sheet :: Model -> V
sheet m =
  case modelSheet m of
    NoSheet -> node "sheet-hidden" [] []
    NoteSheet _ note ->
      node "sheet" []
        [ label "sheet-title" "Add a note"
        , textInput "input" "What exactly did you do?" note SetNote
        , node "sheet-buttons" []
            [ node "button" [tap CloseSheet] [label "button-text" "Skip"]
            , node "button-primary" [tap SaveNote] [label "button-text" "Save"]
            ]
        ]
    EditSheet _ note t ->
      node "sheet" []
        [ label "sheet-title" "Edit entry"
        , textInput "input-time" "HH:MM" t SetEditTime
        , textInput "input" "Description" note SetEditNote
        , node "sheet-buttons" []
            [ node "button" [tap CloseSheet] [label "button-text" "Cancel"]
            , node "button-primary" [tap SaveEdit] [label "button-text" "Save"]
            ]
        ]

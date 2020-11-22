import XMonad
import XMonad.Util.Run(spawnPipe)
import qualified XMonad.StackSet as W
import XMonad.Util.CustomKeys

import XMonad.Hooks.SetWMName
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.Script

import XMonad.Layout.Grid
import XMonad.Layout.LayoutHints

import XMonad.Prompt
import XMonad.Prompt.Shell
import XMonad.Prompt.AppLauncher
import XMonad.Prompt.Window
import XMonad.Prompt.Layout
import XMonad.Prompt.AppendFile

import Data.Maybe

import System.IO

main = do
  xmproc <- spawnPipe "xmobar /home/rolph/.xmobarrc"
  xmonad defaultConfig
    { 
      startupHook = setWMName "LG3D" -- >> execScriptHook "startup"
    , layoutHook = avoidStruts $ layoutHints $ layoutHook defaultConfig
    , manageHook = manageDocks
    , handleEventHook = handleEventHook defaultConfig <+> docksEventHook
    , logHook = dynamicLogWithPP xmobarPP
                    { ppOutput = hPutStrLn xmproc
                    , ppLayout = const ""
                    --, ppTitle = xmobarColor "green" "" . shorten 50
                    -- , ppTitle = \t -> "<fc=white>" ++ (shorten 40 t) ++ "</fc>"
                    , ppTitle = const ""
                    }
                    >> setWMName "LG3D"
    , modMask = mod4Mask
    , terminal = "terminator"
    , focusedBorderColor = "#000000"
    , borderWidth = 0
    , keys = customKeys (const []) newKeys
    }

  where
    promptConfig =
      def {
        font   = "xft:Inconsolata:size=14:antialias=true"
      , height = 30
      , bgColor = "grey11"
      , borderColor = "grey33"
      }

    -- keep applying f until we find a nonempty workspace
    findNonEmptyWorkspace :: (Int -> Int) -> [WindowSpace] -> WorkspaceId -> WorkspaceId
    findNonEmptyWorkspace f ws si =
      let i   = (read si) :: Int in
      let i'  = wrap (f i) 1 9 in
      let si' = show i' in
      let w   = head (filter (\w -> W.tag w == si') ws) in
      case W.stack w of
        Nothing -> findNonEmptyWorkspace f ws si'
        Just _ -> W.tag w
      where wrap n lo hi
              | n < lo = hi
              | n > hi = lo
              | otherwise = n

    nextWorkspace :: [WindowSpace] -> WorkspaceId -> WorkspaceId
    nextWorkspace ws si = findNonEmptyWorkspace (+1) ws si

    prevWorkspace :: [WindowSpace] -> WorkspaceId -> WorkspaceId
    prevWorkspace ws si = findNonEmptyWorkspace (\x -> x - 1) ws si

    focusOnWorkspace :: ([WindowSpace] -> WorkspaceId -> WorkspaceId) -> X ()
    focusOnWorkspace focus =  
      windows go
      where go stackset =
              let ws  = W.workspaces stackset in
              let i   = W.currentTag stackset in
              let j   = focus ws i in
              W.greedyView j stackset

    newKeys conf@(XConfig { modMask = modm }) =
      [
        ((modm, xK_t), spawn $ terminal conf)
      , ((controlMask .|. shiftMask, xK_l), spawn "xscreensaver-command -lock")
      , ((modm, xK_w), spawn "x-www-browser")
      , ((modm, xK_f), spawn "thunar")
      , ((modm, xK_b), spawn "feh --bg-fill --randomize ~/pictures/wallpaper &")
      , ((controlMask, xK_F1), spawn "amixer set -q Master,0 toggle")
      , ((controlMask, xK_F2), spawn "amixer set -q Master,0 5%-")
      , ((controlMask, xK_F3), spawn "amixer set -q Master,0 5%+")
			, ((controlMask, xK_F5), spawn "xbacklight -dec 10")
			, ((controlMask, xK_F6), spawn "xbacklight -inc 10")
			, ((controlMask, xK_F7), spawn "xbacklight -set 0 -time 500 -steps 20")
			, ((controlMask, xK_F8), spawn "xbacklight -set 100 -time 500 -steps 20")
			, ((modm, xK_apostrophe), sendMessage ToggleStruts)
      , ((modm, xK_p), shellPrompt promptConfig)
      , ((modm, xK_g), launchApp promptConfig "xdg-open" )
      , ((modm, xK_Escape), windowPromptBring promptConfig)
      , ((modm, xK_grave), windowPromptGoto promptConfig)
      , ((controlMask, xK_F9), spawn "musicsay toggle")
      , ((controlMask, xK_F10), spawn "musicsay prev")
      , ((controlMask, xK_F11), spawn "musicsay next")
      , ((modm .|. shiftMask, xK_m), layoutPrompt def)
      , ((modm, xK_equal), focusOnWorkspace nextWorkspace)
      , ((modm, xK_minus), focusOnWorkspace prevWorkspace)
      , ((modm .|. shiftMask, xK_t), appendFilePrompt promptConfig "/home/rolph/scripts/todo.txt")
      , ((modm .|. shiftMask, xK_d), spawn "/home/rolph/scripts/donetodo")
      , ((modm, xK_Up), spawn "/home/rolph/scripts/prevtask")
      , ((modm, xK_Down), spawn "/home/rolph/scripts/nexttask")
      , ((modm, xK_r), withFocused $ windows . W.sink)
      , ((controlMask, xK_F12), spawn "monitortoggle")
      ]


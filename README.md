# MonitorHelper

A tiny macOS menu-bar app that toggles your laptop's position relative to your
external monitor — **laptop-to-the-left** ⇄ **laptop-below** — with a single
global hotkey, and confirms each switch with a frosted-glass overlay.

Built for a MacBook + one external monitor on macOS 14+ (developed on macOS 26
"Tahoe", Apple Silicon).

## Why

macOS remembers only **one** arrangement per monitor, so it can't toggle between
two layouts for the same display. MonitorHelper does exactly that.

## Features

- **⌃⌥⌘D** — toggle between the two arrangements (applies whichever isn't active).
- **Confirmation HUD** — a semi-transparent card with an animated monitor+laptop
  diagram that shows the new layout, auto-dismissing after ~1s.
- **Menu-bar card** — shows the current layout and lets you pick a layout
  directly, choose where the HUD appears, and enable **Start at Login**.
- **No special permissions** — uses Quartz Display Services + a Carbon hotkey, so
  no Accessibility / Screen Recording grants are required.

## Build & install

```sh
sh build.sh                 # produces MonitorHelper.app
mv MonitorHelper.app /Applications/
open /Applications/MonitorHelper.app
```

First launch may show a Gatekeeper prompt (the app is ad-hoc signed). Either
right-click → **Open**, or clear quarantine:

```sh
xattr -dr com.apple.quarantine /Applications/MonitorHelper.app
```

Enable **Start at Login** from the menu-bar card to have it run automatically.
(For Start at Login to stick, the app must live in `/Applications`.)

## How it works

- `DisplayManager` — enumerates displays (`CGGetOnlineDisplayList`, keyed by
  `CGDisplayIsBuiltin` so it survives hotplug) and sets origins inside a
  `CGBeginDisplayConfiguration` … `CGCompleteDisplayConfiguration(.permanently)`
  transaction. The external monitor stays primary at `(0,0)`; only the laptop
  moves (centered on the shared edge).
- `HotKeyManager` — registers the global hotkey with Carbon `RegisterEventHotKey`.
- `HUDController` — a borderless, click-through `NSPanel` hosting a SwiftUI HUD.
- `App.swift` — `MenuBarExtra` (window style) with the menu card.

## Notes

- Do **not** enable App Sandbox — it blocks permanent display reconfiguration.
- The hotkey deliberately includes ⌘/⌃ to avoid a macOS 15 Option-only-hotkey
  regression (FB15168205).

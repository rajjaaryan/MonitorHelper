# MonitorHelper — Project Notes / Session Handoff

> Purpose: pick up work across sessions. This captures **what was built, how it works,
> how to build/run it, the decisions made, what's verified, and what's still open.**
> User-facing usage lives in [README.md](README.md). The original approved design plan is at
> `~/.claude/plans/so-in-my-macbook-harmonic-deer.md`.

_Last updated: 2026-07-09. Developed on macOS 26.4.1 (Tahoe), Apple Silicon (arm64), Swift 6.3.1._

---

## 1. What this is

A tiny **menu-bar macOS app** that toggles the laptop's position relative to the external
monitor — **laptop-Left ⇄ laptop-Below** — on a single global hotkey, and confirms each
switch with a frosted-glass HUD overlay.

**Why:** macOS remembers only ONE arrangement per monitor, so it can't toggle between two
layouts for the same display. This app does exactly that.

**Status:** Built, code-signed, verified working live, and currently running from the project
folder. No special permissions required.

---

## 2. What it does (behavior spec)

- **⌃⌥⌘D** → applies the *opposite* of the current layout (a toggle).
- External monitor is always **primary at (0,0)**; only the laptop moves:
  - **Left:** laptop at `(-laptopWidth, verticallyCentered)` → laptop's right edge touches the
    monitor's left edge. Cursor exits the laptop's **right** side and enters the monitor's
    **left** side. (This is the user's real working setup.)
  - **Below:** laptop at `(horizontallyCentered, monitorHeight)`.
- On every switch (hotkey **or** menu) a **HUD** appears: bottom-center of the monitor,
  ~2.5s, an animated monitor+laptop diagram (the laptop tile springs into place), label
  "Laptop → Left/Below". Rapid re-triggers coalesce into one HUD.
- **No external monitor** → soft beep, no HUD, menu actions disabled.
- Robust to hotplug: displays identified by `CGDisplayIsBuiltin`, never cached IDs.

---

## 3. Decisions made with the user (don't re-litigate)

- **Left, not right** for the horizontal layout (user corrected this — laptop physically sits on the left).
- **Single toggle hotkey** (not two dedicated keys).
- **HUD default position: bottom-center** (configurable via the menu).
- **HUD motion: animated diagram** (laptop tile springs into its new position).
- **HUD made bigger + longer (2.5s) + stronger "smudged" frosted glass** (per user request).
- **Framework: SwiftUI** for all visual surfaces (easy to restyle) + thin AppKit for the
  overlay window and Carbon for the global hotkey.

---

## 4. Architecture / file map

All source in `Sources/`. Single `swiftc` build (no Xcode project).

| File | Role |
|---|---|
| `App.swift` | `@main` entry. Handles CLI flags (see §6), else launches the SwiftUI app. `MenuBarExtra` (window style) + the menu card + `LayoutButton`. |
| `AppDelegate.swift` | Registers the global hotkey, sets `.accessory` policy, refreshes state on display changes, and the `MH_PREVIEW_HUD` design hook. |
| `AppController.swift` | Coordinates toggle/apply + HUD. Shared by hotkey and menu so both behave identically. |
| `DisplayManager.swift` | **The core.** `Layout` enum (`.left`/`.below`), display enumeration, `apply(_:)`, `toggle()`, `currentLayout` detection. Uses Quartz Display Services. |
| `HotKeyManager.swift` (`Hotkey.swift`) | Carbon `RegisterEventHotKey` wrapper (no Accessibility permission needed). |
| `HUDController.swift` | Borderless, click-through `NSPanel` overlay; positioning per setting; show/auto-dismiss; coalescing. |
| `LayoutHUDView.swift` | SwiftUI HUD card + `VisualEffectView` (NSVisualEffectView `.hudWindow`) + `HUDModel`/`HUDRootView` (enter/exit animation). |
| `LayoutDiagram.swift` | Reusable animated monitor+laptop vector; centers the whole group in each state. |
| `AppSettings.swift` | UserDefaults-backed settings (`hudPosition`) + `LoginItem` (SMAppService wrapper). |
| `Resources/Info.plist` | `LSUIElement=true` (menu-bar agent, no Dock icon), bundle id `ai.angoor.monitorhelper`, min macOS 14. |
| `build.sh` | Compiles + assembles `MonitorHelper.app` + ad-hoc code-signs. |

---

## 5. How it works under the hood

- **Display move:** `CGBeginDisplayConfiguration` → `CGConfigureDisplayOrigin` (external at
  (0,0), laptop to left/below) → `CGCompleteDisplayConfiguration(.permanently)`. Same API
  System Settings uses; confirmed present & non-deprecated in the on-device 26.4 SDK.
- **Global hotkey:** Carbon `RegisterEventHotKey` (control+option+cmd+D). Unlike NSEvent
  global monitors, this needs **no Accessibility permission**. Cmd/Ctrl included on purpose
  to dodge the macOS 15 Option-only-hotkey regression (FB15168205).
- **Menu-bar-only:** `LSUIElement=true` → no Dock icon, no window, not in ⌘-Tab. The app is
  an idle background process (event-driven; ~0% CPU) woken only by the hotkey or a menu click.
- **HUD overlay:** non-activating `NSPanel` (borderless, `ignoresMouseEvents`, `.statusBar`
  level, joins all spaces + full-screen aux) hosting a SwiftUI view. Shown on the **primary
  monitor** (screen with frame origin (0,0)) — NOT `NSScreen.main`, which for a background
  agent can wrongly resolve to the built-in panel (this bug was found & fixed).
- **No App Sandbox** (it would block permanent display reconfig). Personal-use app, not App Store.

---

## 6. Build / run / quit / reopen

```sh
cd "/Users/rajjaaryan/Projects/Moniter helper"
sh build.sh                          # -> MonitorHelper.app (in the project folder)
open "MonitorHelper.app"             # launch (menu-bar icon appears; no Dock icon)
```

**Quit:** menu-bar icon → *Quit MonitorHelper*. Force: Activity Monitor → `MonitorHelper` →
Force Quit, or Terminal `killall MonitorHelper`. Note: ⌥⌘Esc (Force Quit window) does NOT
list menu-bar-only apps.

**Reopen:** `open "/Users/rajjaaryan/Projects/Moniter helper/MonitorHelper.app"` (or double-click).

**CLI mode (bonus, also handy for scripting/testing):**
```sh
BIN="MonitorHelper.app/Contents/MacOS/MonitorHelper"
"$BIN" --status      # prints: left | below | none
"$BIN" --left        # apply left arrangement and exit
"$BIN" --below       # apply below arrangement and exit
"$BIN" --toggle      # flip and exit
```

**Design preview hook (see the HUD without moving displays):**
```sh
MH_PREVIEW_HUD=left  "$BIN"   # launches app + shows the Left HUD, held open (no auto-dismiss)
MH_PREVIEW_HUD=below "$BIN"
```

---

## 7. Dev workflow & the #1 gotcha

**edit → rebuild → relaunch.** Editing source changes nothing until you `sh build.sh`
(recompile) AND relaunch (a running process keeps its old code in memory).

`build.sh` always outputs to the **project folder**. While iterating, run the app from there
(one copy, no sync headaches). If/when the app is moved to `/Applications`, remember there are
then **two copies** — a project-folder build and the installed one — and they diverge until you
copy the new build over and relaunch. (Option on the table: make `build.sh` install into
`/Applications` + relaunch in one step. Not done yet.)

---

## 8. Verified (done live on this machine)

- Display move works: `--left` → laptop at `(-1470, 242)`; `--below` → `(centered, 1440)`;
  `--toggle` flips; detection correct at every state. Original arrangement restored exactly after tests.
- App launches clean as a menu-bar agent (no crash, ~52 MB RAM, 0% CPU).
- Menu-bar icon appears; state-reflecting SF Symbol.
- HUD renders correctly in both layouts (frosted glass, correct diagram, label) — screenshots reviewed.
- HUD positioning bug fixed (was landing on the built-in panel; now targets the primary monitor).
- No entries in Privacy & Security → Accessibility (confirms no permission needed).
- The user confirmed the global hotkey physically toggled their display during testing.

**Not auto-testable here** (needs the user): the actual global keypress firing in daily use;
the menu dropdown visuals; Start-at-Login across a real reboot; light-mode / Reduce-Motion look.

---

## 9. Open items / next steps

- [ ] **Set active arrangement to Left** (user's working setup). They can press ⌃⌥⌘D / use the menu, or ask me.
- [ ] **Laptop vertical alignment in Left**: currently **vertically centered** vs. optional **top-aligned** (or custom offset) to match the physical desk for a natural cursor handoff. _Decision pending._
- [ ] **Move to /Applications** + make Start-at-Login solid; optionally auto-install from `build.sh`.
- [ ] **App icon** (currently no custom icon; `Resources/` is empty).
- [ ] Optional: re-apply preferred layout on monitor reconnect (`CGDisplayReconfigurationCallback`).
- [ ] Optional: subtle switch sound; editable hotkey from the menu.

**Easy restyle knobs (SwiftUI):** HUD card width & `corner` (`LayoutHUDView.swift`), material
(`VisualEffectView` — `.hudWindow`/`.regularMaterial`/etc.), spring feel (`response`/
`dampingFraction` in `LayoutDiagram.swift` & `HUDRootView`), `visibleDuration` + `panelSize`
(`HUDController.swift`), default HUD position (`AppSettings.hudPosition`), diagram `scale`.

---

## 10. Environment snapshot

- macOS 26.4.1 (Tahoe), Apple Silicon arm64; Swift 6.3.1; SDK 26.4.1.
- Displays: external `LS27D70xE` 2560×1440 (main), built-in `Color LCD` 1470×956.
- Original arrangement at session start: **below**, laptop origin `(519, 1440)`.

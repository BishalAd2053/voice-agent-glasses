# Building VoiceAgentGlasses on a Mac

You're authoring source on Windows. To ship to an iPhone you need a Mac for the
compile + sign + install step. This doc is the exact checklist.

## What you need

- A Mac running **macOS Sonoma 14.5+** (Xcode 15.4+ requires it).
- **Xcode 15.4 or newer** (free, App Store).
- An **Apple ID** — a free one is enough for sideloading to your own iPhone
  (7-day re-sign cycle). A paid Apple Developer Program account ($99/yr) is
  only needed for TestFlight / App Store.
- A **USB-C cable** for the iPhone 17 Pro Max.

## One-time setup

1. Install Xcode, open it once, accept the license, let it install components.
2. Xcode → Settings → Accounts → add your Apple ID.
3. Plug in the iPhone, unlock it, tap **Trust This Computer**.
4. On the iPhone: **Settings → Privacy & Security → Developer Mode → On**, reboot.

## Creating the Xcode project around this code

There's no `.xcodeproj` in this repo (Xcode generates one — easier to recreate
than to maintain by hand for now). To set it up:

1. **File → New → Project → iOS → App**
   - Product Name: `VoiceAgentGlasses`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: None
2. Save it inside the repo root, **replacing** the generated `VoiceAgentGlasses/`
   folder with the one already in this repo (it has our real source files).
   In Xcode, delete the auto-generated `ContentView.swift` and `…App.swift`
   references, then drag in the folder from Finder with
   *"Create groups"* selected.
3. In the project's **Info** tab, point the build setting
   `INFOPLIST_FILE` at `VoiceAgentGlasses/Resources/Info.plist`
   (or paste each key from our `Info.plist` into the auto-generated one).
4. **File → Add Package Dependencies…**
   - URL: `https://github.com/facebook/meta-wearables-dat-ios`
   - Add both `DeviceAccessToolkit` and `MockDeviceKit` to the app target.

## Running

- Pick your iPhone in the run-destination dropdown.
- Press **⌘R**.
- First run: iPhone will say *"Untrusted Developer"* — go to
  **Settings → General → VPN & Device Management** and trust your Apple ID.

## When you don't have glasses yet

The app auto-detects whether the real DAT SDK is linked. With only
`MockDeviceKit` linked, or when running in the Simulator, you'll see a
synthetic frame loop labeled `MOCK FRAME N` in the preview. That's expected
and proves Phase 1 is wired correctly.

## When you have glasses

Phase 1 still uses the mock loop even with real glasses — wiring the real DAT
discovery + session APIs is the first thing Phase 2 finishes, once we've
confirmed the SDK's actual entry points against its headers.

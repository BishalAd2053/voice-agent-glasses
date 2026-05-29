# Running Ollama on your Windows box for the iPhone to reach

Goal: your iPhone (on Wi-Fi) sends chat requests to `http://<your-pc-ip>:11434`,
which is Ollama running on your Windows desktop. No cloud, no API keys.

## 1. Install Ollama

Download from https://ollama.com/download/windows and install.

## 2. Pull a vision-capable model

Vision matters here because we attach glasses frames on "look/see" turns.

```powershell
ollama pull llava
# or, larger and better:
ollama pull llama3.2-vision
```

Text-only is fine too — just pull `llama3.1` and ignore vision.

## 3. Bind to all interfaces (not just localhost)

By default Ollama listens on `127.0.0.1`, which the phone can't reach. Set
`OLLAMA_HOST=0.0.0.0` permanently:

```powershell
[System.Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0", "User")
```

Then **fully quit and relaunch** Ollama (right-click the tray icon → Quit).

## 4. Open the firewall

```powershell
New-NetFirewallRule -DisplayName "Ollama LAN" -Direction Inbound `
  -LocalPort 11434 -Protocol TCP -Action Allow
```

## 5. Find your PC's LAN IP

```powershell
ipconfig | Select-String "IPv4"
```

Something like `192.168.1.42`.

## 6. Verify from the phone

In Safari on the iPhone, visit `http://192.168.1.42:11434`. You should see
`Ollama is running`.

## 7. Plug it into the app

In **Settings → Backend → Ollama**:
- Base URL: `http://192.168.1.42:11434`
- Model: `llava` (or whatever you pulled)

## Gotchas

- **Both devices must be on the same Wi-Fi.** Guest networks often isolate clients.
- iOS asks for **Local Network** permission the first time the app hits a LAN IP.
  Grant it. (Declared in `Info.plist` as `NSLocalNetworkUsageDescription`.)
- If your PC's IP changes (DHCP), reserve it on your router or update Settings.
- For access from outside your home, install Tailscale on both Windows and iPhone
  and use the Tailscale IP instead — no firewall changes needed.

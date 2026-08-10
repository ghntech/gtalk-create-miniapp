
# WebView Native Bridge Integration

This document describes how iOS, Android, and Electron host apps must integrate with the **miniapp-library-service** web app when loading it inside a WebView.

The web app runs entirely in the browser/WebView. For file downloads, native viewers, external links, and clipboard access, it posts messages to a native bridge. If the bridge is not wired up, the web app falls back gracefully — but native download/open dialogs will not appear.

---

## 1. Overview

### Communication flow

```
Web App  ──[bridge call]──▶  Native Host
             (action + payload)
```

The web app **never** waits for a return value from the native host. All bridge calls are fire-and-forget. The web app decides whether the bridge was wired up based on whether the bridge object exists in `window` at call time.

> **iOS exception:** iOS additionally exposes a separate `ghnPrinter` bridge for BLE thermal-printer jobs that **does** return a value (Promise-based request/reply, not fire-and-forget). It is not part of this contract — see §3.6.

### Bridge actions

| Action | Triggered when |
|--------|---------------|
| `downloadFile` | User taps the Download button on a file |
| `openFile` | User taps to open/preview a file inline. **iOS today handles this identically to `downloadFile`** (same handler, same code path) — see §3.4. |
| `copyToClipboard` | User copies a share link (fallback when `navigator.clipboard` fails) |

### Fallback behaviour when bridge is absent

| Action | Fallback |
|--------|----------|
| `downloadFile` | Mobile WebView: `window.open(url, '_self')` (native download listener must intercept). Desktop: blob download via `<a download>`. |
| `copyToClipboard` | `navigator.clipboard.writeText` → `document.execCommand('copy')` |

---

## 2. Required Setup (all platforms)

### 2.1 Inject platform identifier

Native apps must add `platform` to `window.appEnvConfig`. **Do not replace the whole object** — the Go server already injects `window.appEnvConfig` (with `apiUrl`, `loginUrl`, `defaultPageSize`, etc.) via a `<script>` tag in the HTML. A full replacement by either side would clobber the other's fields.

**Script execution order:**
```
[document start]  ← native WKUserScript / preload injects here
     ↓
[<script> in HTML]  ← Go server sets window.appEnvConfig = { apiUrl, loginUrl, ... }
     ↓
[React bundle]  ← reads window.appEnvConfig lazily (safe to inject until here)
```

Because native runs first and the Go server overwrites on the second line, the correct pattern for iOS and Android is an `Object.defineProperty` **setter intercept** — it traps the Go server's assignment and merges native fields back in. See §3.1 and §4.1 for platform-specific implementations.

For Electron (where preload runs in an isolated context), merge after `dom-ready` instead. See §5.3.

If `platform` is omitted entirely, the web app falls back to user-agent sniffing:
- `Electron/x.y.z` in UA → `electron`
- Android UA with `; wv)` → `android`
- iPhone/iPad UA without `Safari/` token → `ios`
- Everything else → `web`

### 2.2 Message contract

Every message from the web app has this shape:

```typescript
{
  action:  string,
  payload: {
    url?:      string,   // presigned S3 URL (time-limited, typically 15 min)
    fileName?: string,   // original file name with extension
    mimeType?: string,   // MIME type e.g. "application/pdf"
    text?:     string,   // for copyToClipboard only
  }
}
```

Payloads per action:

| Action | `url` | `fileName` | `mimeType` | `text` |
|--------|-------|-----------|---------|------|
| `downloadFile` | ✓ | ✓ | ✓ | — |
| `openFile` | ✓ | ✓ | ✓ | — |
| `copyToClipboard` | — | — | — | ✓ |

---

## 3. iOS Integration (WKWebView)

### 3.1 Inject platform config

Use a `WKUserScript` at `.atDocumentStart` to install a setter trap on `window.appEnvConfig`.
When the Go server later does `window.appEnvConfig = { apiUrl: "...", ... }`, the setter fires and merges `platform` back in — so both sets of fields survive.

> **Current implementation note:** GTalk iOS only attaches this script — and the message handlers in §3.2/§3.6 — when the page's host matches an allow-listed mini-app domain (`*.ghn.vn` in prod; `*.ghn.dev` / `*.ghn.tech` in test/staging; see `MiniAppURLHelper.isMiniAppUrl`). Any other host loaded in the same `WKWebView` type gets a plain WebView: no `appEnvConfig` injection, no bridge. If your host app reuses one `WKWebView` configuration for both the mini-app and generic browsing, gate the injection the same way — do not inject it unconditionally into every page.

```swift
import WebKit

let configScript = WKUserScript(
    source: """
        (function () {
            var _native = { platform: 'ios' };
            var _config = Object.assign({}, _native);
            Object.defineProperty(window, 'appEnvConfig', {
                get: function () { return _config; },
                set: function (v) {
                    // Go server sets the full object — merge native fields back in.
                    // Native fields win if there's a key conflict.
                    _config = Object.assign({}, v, _native);
                },
                configurable: true,
            });
        })();
    """,
    injectionTime: .atDocumentStart,
    forMainFrameOnly: true
)
configuration.userContentController.addUserScript(configScript)
```

To add more native-specific fields in the future, add them to `_native`. The Go server's fields are preserved automatically.

### 3.2 Register the message handler

Register a `WKScriptMessageHandler` named exactly `"nativeBridge"`:

```swift
configuration.userContentController.add(self, name: "nativeBridge")
```

> **Important:** The handler name must be `"nativeBridge"` — the web app calls
> `window.webkit.messageHandlers.nativeBridge.postMessage(msg)`.

### 3.3 Handle messages

> **Required — origin check:** validate `message.frameInfo.securityOrigin.host` against the same mini-app domain allow-list from §3.1 (`MiniAppURLHelper.isMiniAppUrl`) before acting on any message. This rejects a rogue iframe loaded inside the page from invoking the bridge (see also §8).

```swift
extension YourViewController: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard
            message.name == "nativeBridge",
            let body    = message.body as? [String: Any],
            let action  = body["action"]  as? String,
            let payload = body["payload"] as? [String: Any]
        else { return }

        // Origin check — only accept messages from a frame whose origin is the
        // mini-app domain, even for nested iframes (see §3.1 / §8).
        let originHost = message.frameInfo.securityOrigin.host
        guard MiniAppURLHelper.isMiniAppUrl(originHost) else { return }

        switch action {
        case "downloadFile", "openFile":
            let url      = payload["url"]      as? String ?? ""
            let fileName = payload["fileName"] as? String ?? "file"
            handleDownloadFile(url: url, fileName: fileName)

        case "copyToClipboard":
            let text = payload["text"] as? String ?? ""
            UIPasteboard.general.string = text

        default:
            break
        }
    }
}
```

### 3.4 Implement `handleDownloadFile`

Download the file then present a share sheet:

```swift
func handleDownloadFile(url: String, fileName: String) {
    guard let remoteURL = URL(string: url) else { return }

    let task = URLSession.shared.downloadTask(with: remoteURL) { [weak self] tempURL, _, error in
        guard let tempURL, error == nil else { return }

        // Move to a persistent temp location with the correct file name
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? FileManager.default.replaceItem(at: dest, withItemAt: tempURL,
                                             backupItemName: nil, options: [], resultingItemURL: nil)

        DispatchQueue.main.async {
            let vc = UIActivityViewController(activityItems: [dest], applicationActivities: nil)
            self?.present(vc, animated: true)
        }
    }
    task.resume()
}
```

> **Current implementation note:** GTalk iOS's production `handleDownloadFile` does not auto-present `UIActivityViewController`. It downloads to a temp file, then pushes an in-app `QLPreviewController`-based viewer (`FileViewer`) with a `ShareLink` button in the nav bar — the user explicitly taps "Chia sẻ" to reach the system share sheet. `openFile` is wired to this exact same code path; there is no separate "preview without download" mode today.

### 3.5 Memory management

Remove the message handler when the view controller is deallocated to avoid retain cycles:

```swift
deinit {
    webView.configuration.userContentController.removeScriptMessageHandler(forName: "nativeBridge")
}
```

### 3.6 Printer Bridge (`ghnPrinter`) — iOS-only extension

GTalk iOS additionally exposes a **second, independent bridge** for BLE thermal-printer jobs (printing shipping labels from the mini-app). It is scoped to mini-app pages only (same domain gate as §3.1) and is **not** part of the fire-and-forget contract in §1 — it's a Promise-based request/reply channel, so the web app *does* wait for a return value here.

**Feature-detect separately from `nativeBridge`** — the two bridges are independent and one being present does not imply the other is:
```javascript
!!window.webkit?.messageHandlers?.ghnPrinter   // → true only if the printer bridge is wired up
```

**Registration** uses `WKScriptMessageHandlerWithReply` (iOS 14+) on `contentWorld: .page`, not the plain `WKScriptMessageHandler` used for `nativeBridge`:

```swift
let printerHandler = WeakScriptMessageHandlerWithReply(delegate: PrinterBridgeService.shared)
configuration.userContentController.addScriptMessageHandler(
    printerHandler,
    contentWorld: .page,
    name: "ghnPrinter"
)
```

**Request contract** (web → native), version-tagged and correlated by `jobId`:

```typescript
{
  v:             1,
  action:        "listPrinters" | "print",
  jobId:         string,          // caller-generated, must be non-empty
  printerId?:    string,          // required for "print"
  payloadBase64?: string,         // required for "print" — base64-encoded ESC/POS bytes
}
```

**Reply contract** (native → web, resolves the Promise from `postMessage`):

```typescript
// success
{ v: 1, jobId: string, ok: true, printers?: [{ id: string, name: string }] }

// failure
{ v: 1, jobId: string, ok: false, code: string, message: string }
```

`code` is one of: `DISCONNECTED`, `TIMEOUT`, `NO_PRINTER`, `BT_OFF`, `BT_PERMISSION`, `PROTOCOL`, `write-failed`.

**Native → web events** (unsolicited — not a reply to any specific `postMessage` call, dispatched via `webView.evaluateJavaScript`):

| Event | Fired when |
|-------|-----------|
| `ghn-printer-bridge-ready` | Once, right after the bridge is registered (document end) — web can wait for this before calling `listPrinters` |
| `ghn-printer-printers-changed` | Whenever the native BLE printer registry changes; broadcast to every mini-app `WKWebView` currently open |

**Security:** same origin check as §3.3 applies — a message whose `frameInfo.securityOrigin.host` doesn't match the mini-app domain gets a `PROTOCOL` failure reply (not silently dropped, since there is always a Promise to settle).

**Platform status:** this bridge exists on iOS only today (FMP-4495). Android/Electron have no equivalent yet — do not assume `ghnPrinter` is available cross-platform.

---

## 4. Android Integration (WebView)

### 4.1 Inject platform config

Override `onPageStarted` in your `WebViewClient` to install a setter trap on `window.appEnvConfig` before any page scripts run. When the Go server later assigns the full config object, the setter merges `platform` back in.

```kotlin
webView.webViewClient = object : WebViewClient() {
    override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
        val js = """
            (function () {
                var _native = { platform: 'android' };
                var _config = Object.assign({}, _native);
                Object.defineProperty(window, 'appEnvConfig', {
                    get: function () { return _config; },
                    set: function (v) {
                        _config = Object.assign({}, v, _native);
                    },
                    configurable: true,
                });
            })();
        """.trimIndent()
        view.evaluateJavascript(js, null)
    }
}
```

To add more native-specific fields in the future, add them to `_native`. The Go server's fields are preserved automatically.

### 4.2 Enable JavaScript and add the interface

```kotlin
webView.settings.javaScriptEnabled = true
webView.addJavascriptInterface(NativeBridge(this), "AndroidBridge")
```

The interface name must be exactly `"AndroidBridge"`.

### 4.3 Implement `NativeBridge`

```kotlin
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.app.DownloadManager
import android.webkit.JavascriptInterface
import org.json.JSONObject

class NativeBridge(private val context: Context) {

    @JavascriptInterface
    fun postMessage(json: String) {
        val msg     = JSONObject(json)
        val action  = msg.getString("action")
        val payload = msg.getJSONObject("payload")

        when (action) {
            "downloadFile"     -> handleDownloadFile(payload)
            "copyToClipboard"  -> handleCopyToClipboard(payload)
        }
    }

    private fun handleDownloadFile(payload: JSONObject) {
        val url      = payload.optString("url")
        val fileName = payload.optString("fileName", "download")
        val mimeType = payload.optString("mimeType", "application/octet-stream")

        val req = DownloadManager.Request(Uri.parse(url)).apply {
            setTitle(fileName)
            setMimeType(mimeType)
            setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName)
            setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
            )
        }
        val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        dm.enqueue(req)
    }

    private fun handleCopyToClipboard(payload: JSONObject) {
        val text = payload.optString("text")
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("link", text))
    }
}
```

### 4.4 Required permissions

Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
```

For Android 10+ (API 29+), `WRITE_EXTERNAL_STORAGE` is not required for `DownloadManager` with `DIRECTORY_DOWNLOADS`.

### 4.5 Handle WebView download fallback

When the bridge is **not** wired up (or the user taps a download before the bridge loads), the web app calls `window.open(url, '_self')`. Set a `DownloadListener` to intercept this:

```kotlin
webView.setDownloadListener { url, userAgent, contentDisposition, mimeType, contentLength ->
    val req = DownloadManager.Request(Uri.parse(url)).apply {
        setMimeType(mimeType)
        addRequestHeader("User-Agent", userAgent)
        setDescription("Downloading file...")
        setNotificationVisibility(
            DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
        )
        setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS,
            URLUtil.guessFileName(url, contentDisposition, mimeType))
    }
    val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
    dm.enqueue(req)
    Toast.makeText(this, "Đang tải xuống...", Toast.LENGTH_SHORT).show()
}
```

---

## 5. Electron Integration

### 5.1 Project structure

```
main.js        — Electron main process
preload.js     — Runs in renderer context with Node access (contextIsolation: true)
```

### 5.2 Configure BrowserWindow

```javascript
// main.js
const { BrowserWindow } = require('electron');
const path = require('path');

const win = new BrowserWindow({
    webPreferences: {
        preload:          path.join(__dirname, 'preload.js'),
        contextIsolation: true,     // required for contextBridge
        nodeIntegration:  false,    // keep false for security
    }
});
```

### 5.3 Inject platform config

With `contextIsolation: true`, the preload script runs in an isolated JS world and **cannot** intercept page-side `window` property assignments. Instead, merge `platform` using `webContents.executeJavaScript` on `dom-ready` — by that point the Go server's `<script>` tag has already run and set all server fields:

```javascript
// main.js
win.webContents.on('dom-ready', () => {
    win.webContents.executeJavaScript(
        'window.appEnvConfig = Object.assign({}, window.appEnvConfig, { platform: "electron" });'
    );
});
```

This is safe because both `getEnv()` and `getPlatform()` in the web app are lazy — they read `window.appEnvConfig` at call time, not at module import time.

To add more native-specific fields in the future, extend the object literal in `Object.assign`.

**Alternative — `contextIsolation: false`:** If your app already runs with `contextIsolation: false`, use the same `Object.defineProperty` intercept from preload directly:

```javascript
// preload.js  (contextIsolation: false only)
(function () {
    var _native = { platform: 'electron' };
    var _config = Object.assign({}, _native);
    Object.defineProperty(window, 'appEnvConfig', {
        get: function () { return _config; },
        set: function (v) { _config = Object.assign({}, v, _native); },
        configurable: true,
    });
})();
```

### 5.4 Expose the bridge

```javascript
// preload.js
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronBridge', {
    send(action, payload) {
        ipcRenderer.send('native-bridge', { action, payload });
    }
});
```

### 5.5 Handle messages in main process

```javascript
// main.js
const { ipcMain, shell, clipboard, dialog, net } = require('electron');
const { BrowserWindow } = require('electron');
const path = require('path');
const fs   = require('fs');

ipcMain.on('native-bridge', (event, { action, payload }) => {
    switch (action) {
        case 'downloadFile':
            handleDownloadFile(event, payload);
            break;
        case 'copyToClipboard':
            clipboard.writeText(payload.text || '');
            break;
    }
});

async function handleDownloadFile(event, { url, fileName, mimeType }) {
    const win = BrowserWindow.fromWebContents(event.sender);

    const { filePath, canceled } = await dialog.showSaveDialog(win, {
        defaultPath: fileName,
        filters: [{ name: 'All Files', extensions: ['*'] }],
    });

    if (canceled || !filePath) return;

    const request = net.request(url);
    request.on('response', (response) => {
        const chunks = [];
        response.on('data', (chunk) => chunks.push(chunk));
        response.on('end', () => {
            fs.writeFile(filePath, Buffer.concat(chunks), (err) => {
                if (!err) shell.showItemInFolder(filePath);
            });
        });
    });
    request.end();
}
```

### 5.6 Notes for Electron

- For in-app preview, the existing web app preview modal works fine in Electron (Chromium renders PDF, video, audio natively).
- The `copyToClipboard` bridge action is optional for Electron because `navigator.clipboard` works in Electron renderer processes (HTTPS origin or `allowRunningInsecureContent` not needed).

---

## 6. Testing Checklist

### Verify platform config merge

Open DevTools console inside the WebView and run:

```javascript
// Both fields must be present — platform from native, apiUrl from Go server
window.appEnvConfig.platform  // → "ios" | "android" | "electron"
window.appEnvConfig.apiUrl    // → "https://your-api-host"  (must NOT be empty)
```

If `platform` is `undefined`, the native injection is not running or running too late.
If `apiUrl` is `undefined` or empty, the native script replaced the object instead of merging.

### Verify bridge presence

```javascript
// iOS
!!window.webkit?.messageHandlers?.nativeBridge   // → true
!!window.webkit?.messageHandlers?.ghnPrinter     // → true (iOS-only printer bridge, §3.6)

// Android
!!window.AndroidBridge   // → true

// Electron
!!window.electronBridge  // → true
```

### End-to-end test matrix

| Scenario | Expected behaviour |
|----------|--------------------|
| Tap Download on any file (bridge wired) | Native download dialog / Files share sheet appears |
| Tap Download on any file (bridge absent, mobile) | `window.open` fires; WebView download listener saves file |
| Tap Download on any file (desktop, bridge absent) | Browser blob download triggers |
| Copy share link (clipboard permission granted) | `navigator.clipboard` succeeds silently |
| Copy share link (clipboard permission denied) | Bridge `copyToClipboard` is called; falls back to `execCommand` |
| Preview PDF on Android WebView | Google Docs Viewer iframe loads (not a blank frame) |
| Preview PDF on iOS / desktop | Raw presigned URL loads in iframe |
| Preview mp4 video | `<video controls>` player renders |
| Preview mp3 audio | `<audio controls>` player renders |
| Print a label via BLE thermal printer (iOS, bridge wired) | `ghnPrinter.postMessage({action:"listPrinters"...})` Promise resolves with paired printers; `print` Promise resolves `ok:true` and the label prints |
| Print with Bluetooth off / no paired printer (iOS) | Promise resolves `ok:false` with `code` `BT_OFF` / `NO_PRINTER` — web must surface `message` to the user, not just retry silently |

---

## 7. Presigned URL Lifetime

All `url` values in bridge payloads are **presigned S3 URLs** generated on demand. They are:

- **Time-limited**: typically valid for 15 minutes from the moment the preview/download was initiated in the web app.
- **Single-purpose**: intended for one download or view session.
- **Not shareable**: do not cache or reuse URLs across sessions.

If the native download takes longer than the URL TTL (e.g. very large file on slow network), the download will fail with HTTP 403. In that case, the user should retry from the web app to get a fresh URL.

---

## 8. Security Notes

- The web app runs on the GHN internal domain. Ensure the WebView does **not** grant `allowUniversalAccessFromFileURLs` or `allowFileAccessFromFileURLs`.
- `NativeBridge` on Android is exposed to all JavaScript in the WebView. Validate that the origin of messages is expected if the WebView may load third-party content.
- **On iOS this is enforced today, not just a recommendation:** every incoming message on both `nativeBridge` and `ghnPrinter` (§3.3/§3.6) is checked against `message.frameInfo.securityOrigin.host` and rejected unless it matches the mini-app domain allow-list (`MiniAppURLHelper.isMiniAppUrl`). A third-party iframe embedded in the page cannot invoke either bridge because its frame origin won't match. Android/Electron should implement the equivalent check.
- Presigned URLs expire — avoid logging them or storing them beyond the active download session.
- On iOS, always use `contextIsolation: true` (Electron) or `WKAppBoundDomains` (WKWebView) to limit bridge exposure.

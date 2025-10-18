QuickOCR LLM (macOS Menu Bar App)

- SwiftUI macOS menu bar OCR app using LLMs (OpenAI and Gemini 2.0) for high-accuracy OCR from selection screenshots.
- Default: plain text output, auto-copy clipboard, optional notification, simple history.

Run (Xcode project)
- Open `QuickOCRLLM.xcodeproj` in Xcode. (Note: the old `OCR_LLM.xcodeproj` has been removed; please only use `QuickOCRLLM.xcodeproj`.)
- Select the `QuickOCRLLM` target and your Team, adjust `Bundle Identifier` if needed.
- Build & Run on "My Mac". LSUIElement hides the Dock icon by default.
- First run will request Screen Recording when capturing.
- Default hotkey: Shift+Command+E.

CLI build (macOS SDK)
- If you prefer CLI, use Xcode’s SDK with xcrun:
  - `xcrun --sdk macosx swift build`
  - `xcrun --sdk macosx swift run`
  This ensures AppKit/Carbon are found. Plain `swift build` may miss macOS SDK in some environments.

Distribution (signing & notarization)
- Target already enables Hardened Runtime and App Sandbox (with `com.apple.security.network.client`).
- You’ll need to set your Developer Team and sign the app in Xcode.
- Notarize via Xcode Organizer or `xcrun notarytool`.

Setup
- Settings window (Xcode menu: QuickOCRLLM > Settings…):
  - Provider: OpenAI or Gemini.
  - Models: OpenAI `gpt-4o-mini` (default), Gemini `gemini-2.0-flash` (default).
  - API keys are stored in Keychain.
  - Image compression and history size can be adjusted.

Privacy
- Only the selected region image is sent to the chosen LLM provider.
- Text history (no images) is stored locally in `~/Library/Application Support/QuickOCRLLM/`.
- Disable history or notifications by toggling settings.

Notes
- LSUIElement and hardened runtime/codesigning are recommended for distribution; for dev, runtime accessory policy is used.
- Gemini uses v1beta endpoint for 2.0 models: `.../v1beta/models/gemini-2.0-flash:generateContent`.
- Both providers are prompted to return plain text only; minimal post-processing normalizes whitespace.

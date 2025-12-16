# 📸 Screenshot Mode Instructions

## How to Use Screenshot Mode

Screenshot mode allows you to take App Store screenshots with placeholder artwork instead of real album artwork, which is required by Apple.

### ⚠️ IMPORTANT: This is TEMPORARY - Always disable after taking screenshots!

---

## Step-by-Step Instructions

### 1️⃣ Enable Screenshot Mode

1. Open `Services/ScreenshotModeManager.swift`
2. Find this line:
   ```swift
   private let usePlaceholders: Bool = false
   ```
3. Change it to:
   ```swift
   private let usePlaceholders: Bool = true  // ⚠️ Screenshot mode ON
   ```
4. Build and run the app

### 2️⃣ Take Your Screenshots

- All album artwork will now show as purple placeholders with music icons
- Take screenshots of all the screens you need for App Store Connect
- The placeholders look professional and match your app's design

### 3️⃣ DISABLE Screenshot Mode (CRITICAL!)

1. Open `Services/ScreenshotModeManager.swift` again
2. Change it back to:
   ```swift
   private let usePlaceholders: Bool = false  // ✅ Normal mode - real artwork
   ```
3. Build and run the app again

**⚠️ If you forget to disable this, your users will see placeholders instead of real artwork!**

---

## What Gets Replaced

When screenshot mode is enabled:
- ✅ All album artwork → Purple gradient placeholders with music icons
- ✅ All song artwork → Purple gradient placeholders with music icons  
- ✅ All artist artwork → Purple gradient placeholders with person icons

Everything else in your app (UI, text, functionality) remains exactly the same.

---

## How to Verify

1. **Before taking screenshots:**
   - Enable screenshot mode (`true`)
   - Build and run
   - Check that artwork shows as purple placeholders

2. **After taking screenshots:**
   - Disable screenshot mode (`false`)
   - Build and run
   - Verify real album artwork appears again

---

## Troubleshooting

**Q: Placeholders not showing?**
- Make sure you changed `usePlaceholders` to `true`
- Rebuild the app (Product → Clean Build Folder, then rebuild)

**Q: Still seeing real artwork after enabling?**
- Close and restart the app completely
- The change takes effect on next launch

**Q: How do I know if screenshot mode is enabled?**
- Check the Xcode console when the app launches
- You'll see a warning message if screenshot mode is ON

---

## Files Modified

- `Services/ScreenshotModeManager.swift` - The toggle controller
- `EnhancedArtworkView.swift` - Checks screenshot mode flag
- `CachedAsyncImage.swift` - Checks screenshot mode flag

All artwork throughout your app will automatically use placeholders when enabled.


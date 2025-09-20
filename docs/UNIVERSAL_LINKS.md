## Universal Links setup (Phase 4.2)

Follow these steps to enable universal links for join URLs like `https://<domain>/join/ABC123`.

1) Add Associated Domains to the app
- In Xcode Target → Signing & Capabilities → Associated Domains, add entries for your domain(s):
  - `applinks:yourdomain.com`
  - `applinks:www.yourdomain.com` (if you serve on www)
- Ensure this is enabled for all configurations (Debug/Release).

2) Host the AASA file on your domain
- Place `apple-app-site-association` at BOTH:
  - `https://yourdomain.com/apple-app-site-association`
  - `https://yourdomain.com/.well-known/apple-app-site-association`
- Must be served with `Content-Type: application/json` and NO redirects, NO `.json` extension.
- Minimal AASA content (replace TEAMID and bundle id):
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.cameronstanley.Bumpin",
        "paths": [ "/join/*" ]
      }
    ]
  }
}
```

3) Configure Firestore for dynamic domains (already supported by the app)
- Create doc: `config/links`
  - `domains`: array of strings, e.g. `["yourdomain.com", "www.yourdomain.com"]`
  - `primaryDomain`: string, e.g. `"yourdomain.com"`
- The app reads this via `AppConfig` and uses it for parsing and building invite URLs.

4) Verify on device
- Build to a device. Open Safari and navigate to `https://yourdomain.com/join/ABC123`.
- Expected: iOS shows the smart banner/open-in-app; tapping opens Bumpin and triggers join by code.

5) Troubleshooting
- Validate AASA is reachable and correct content-type:
```bash
curl -I https://yourdomain.com/apple-app-site-association
curl -I https://yourdomain.com/.well-known/apple-app-site-association
curl https://yourdomain.com/.well-known/apple-app-site-association | jq
```
- Confirm entitlements contain `applinks:yourdomain.com` entries in the built app.
- Universal links may be cached per device. After changing AASA, delete the app and reinstall.



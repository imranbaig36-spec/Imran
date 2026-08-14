# Self-Service Guide: Your Desktop Shortcuts Disappeared After a Software Update

**Version:** 1.0  
**Created:** 2026-08-14  
**For:** Floor 6 Users  
**Derived from:** runbook-legal-floor6-missing-desktop-shortcuts-2026-08-14.md

**Runbook Traceability (single source assurance):**
- This guide is a plain-language re-expression of the source runbook, not a separate method.
- Runbook Step 1 -> "Quick Fix" item 1 (Explorer restart).
- Runbook Step 2 -> "Quick Fix" item 2 (work account sync).
- Runbook Step 3 -> "Quick Fix" item 3 (verify shortcuts return).
- Runbook Step 4 and escalation path -> "If Shortcuts Still Don't Appear."

---

## What Happened?

Your desktop shortcuts were accidentally removed during a recent software deployment. The good news: this is fixable in about 15 minutes, and you can do most of it yourself.

---

## Quick Fix (Try This First)

1. **Restart your desktop view**
   - Press and hold `Win + R`, type `taskkill /f /im explorer.exe`, and press Enter
   - Wait 3 seconds
   - Press `Win + R` again, type `explorer.exe`, and press Enter
   - Your desktop will blink—don't panic. Shortcuts often reappear.

2. **Refresh your device's connection to the office**
   - Open Settings (press `Win + I`)
   - Go to **Accounts > Access work or school**
   - Click your work account, then **Info > Sync**
   - Wait 3 minutes

3. **Check if shortcuts came back**
   - Look at your desktop. Do your shortcuts appear?
   - Click one to make sure it works.

---

## If Shortcuts Still Don't Appear

Email the Service Desk with:
- Your device name (find it in **Settings > System > About > Device name**)
- The message: *"My desktop shortcuts are gone after the document management app was installed Friday"*

Attach a screenshot of your empty desktop. The team will send a fix that restores everything in about 10 minutes.

---

## Will This Happen Again?

We've documented this issue and the deployment team is working on preventing it in future updates. For now, if it happens again, just follow the steps above or contact the Service Desk.

**Questions?** Reply to your Service Desk ticket or call IT.

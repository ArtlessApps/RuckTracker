# Authentication Quick Reference Guide

## 🎯 User Types

| Type | Has Email? | Can Purchase? | Can Sign Out? | Status Indicator |
|------|------------|---------------|---------------|------------------|
| **App User** | ❌ No | ✅ Yes | ❌ No | 🟠 Orange "App User" |
| **Connected User** | ✅ Yes | ✅ Yes | ✅ Yes | 🟢 Green "Connected" |

**Premium:** Overlay on either type, tied to Apple ID

---

## 🔑 Key Rules

1. **Premium = StoreKit ONLY** (not authentication)
2. **Anonymous users CANNOT sign out** (data protection)
3. **Sign out creates NEW session** (not auth wall)
4. **NO "Guest" terminology** (use "App User")
5. **NO "Sign Out" for anonymous** (use "Disconnect" for connected)

---

## 📱 Common Scenarios

### Scenario 1: Anonymous User Buys Premium
```
State: App User (no email)
Action: Purchase premium
Result: Premium ✅, Still App User 🟠
Can access: All premium features
Cannot: Sign out
```

### Scenario 2: Premium User Connects Account
```
State: App User with premium
Action: Connect account (add email)
Result: Premium ✅, Now Connected 🟢
Can access: All features + multi-device sync
Can: Sign out (disconnect)
```

### Scenario 3: Connected User Signs Out
```
State: Connected User
Action: Disconnect account
Result: NEW App User session (different ID)
Premium: Maintained if subscription on Apple ID
Data: Old data not accessible (new session)
```

---

## 🔍 How to Check User State

```swift
// Is user connected?
SupabaseManager.shared.hasEmail // true = Connected, false = App User

// Can user sign out?
SupabaseManager.shared.canSignOut // true = show disconnect, false = hide

// Is user premium?
PremiumManager.shared.isPremiumUser // true = premium, false = free

// User type display
SupabaseManager.shared.userTypeDisplay // "App User" or "Connected"
```

---

## 🎨 UI Terminology

### ✅ DO Use:
- "App User" (for anonymous)
- "Connected" (for email users)
- "Connect Account" (action to add email)
- "Disconnect Account" (action to sign out)
- "Free" / "Premium" (subscription tier)

### ❌ DON'T Use:
- "Guest User"
- "Guest Account"
- "Sign Out" (for anonymous)
- "Anonymous" (user-facing)
- "Upgrade Account" (confusing)

---

## 🧪 Quick Tests

### Test 1: First Launch
```
✅ App opens immediately (no wall)
✅ Console: "Created new anonymous session"
✅ Profile shows: App User 🟠
```

### Test 2: Anonymous Premium
```
✅ Can purchase premium
✅ Premium features unlock
✅ Still shows App User 🟠
✅ No disconnect button visible
```

### Test 3: Connect Account
```
✅ Enter email/password
✅ Status changes to Connected 🟢
✅ Disconnect button appears
✅ Same user ID (data preserved)
```

### Test 4: Sign Out
```
✅ Only works if Connected
✅ Alert mentions new session
✅ New user ID created
✅ Premium maintained (Apple ID)
```

---

## 🐛 Common Issues

### Issue: "Sign out not working"
**Check:** Is user Connected? (needs email)
**Fix:** User must connect account first

### Issue: "Lost premium after sign out"
**Check:** Is subscription on Apple ID?
**Fix:** Premium tied to Apple ID, should persist

### Issue: "Can't access premium after purchase"
**Check:** StoreKit subscription status
**Debug:** Look for "Premium status updated" in console

### Issue: "Data lost after sign out"
**Expected:** Sign out creates NEW session
**Solution:** This is by design - sign out = fresh start

---

## 📞 Support Script

**User: "I'm a guest, how do I save my data?"**
> "You're an App User - your data is already saved! To access it on other devices, tap 'Connect Account' in your profile."

**User: "How do I sign out?"**
> "If you've connected an account, tap 'Disconnect Account' in your profile. This will create a fresh session while your data remains accessible when you reconnect."

**User: "Will I lose premium if I disconnect?"**
> "No! Your premium subscription is tied to your Apple ID, not your app account. You'll keep premium access even after disconnecting."

**User: "Can I use premium without an email?"**
> "Yes! Premium works immediately after purchase through Apple Pay. Connecting an account is optional - it's only needed to sync data across devices."

---

## 🔐 Security Notes

- Anonymous sessions are secure (Supabase-managed)
- Email linking validates email format
- Password minimum: 6 characters
- Sessions persist in secure storage
- Premium verified through StoreKit

---

## 🚀 Quick Reference Table

| Action | App User | Connected User |
|--------|----------|----------------|
| Use app | ✅ Yes | ✅ Yes |
| Create workouts | ✅ Yes | ✅ Yes |
| Purchase premium | ✅ Yes (Apple Pay) | ✅ Yes (Apple Pay) |
| Access premium features | ✅ Yes (if subscribed) | ✅ Yes (if subscribed) |
| Connect account | ✅ Yes (upgrades) | ✅ Already connected |
| Sign out / Disconnect | ❌ No (hidden) | ✅ Yes (creates new session) |
| Multi-device sync | ❌ No | ✅ Yes |
| Data cloud backup | ⚠️ Local only | ✅ Yes |

---

**Last Updated:** October 7, 2025
**Quick Help:** See `AUTHENTICATION_IMPLEMENTATION_COMPLETE.md` for full details


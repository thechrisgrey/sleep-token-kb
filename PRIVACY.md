# Privacy Policy

**Ritual Keyboard** (Sleep Token KB)
Last updated: 27 July 2026

## The short version

This app collects nothing, sends nothing, and has no servers. There is no
analytics, no tracking, no advertising, and no account. Nothing you type is
recorded, stored, or transmitted anywhere.

## What the keyboard can and cannot do

Custom keyboards on iOS are the most privacy-sensitive extension Apple offers,
so this is worth stating precisely rather than in general terms.

This keyboard **does not request Full Access**. In the app's `Info.plist`,
`RequestsOpenAccess` is set to `false`. That is not a promise — it is a setting
iOS enforces. With Full Access withheld, the operating system denies the
keyboard extension:

- any network access whatsoever, and
- access to the shared container it would otherwise share with the app.

So even if this app wanted to send your keystrokes somewhere, iOS would not
permit it. It also does not want to. There is no networking code anywhere in
either the app or the keyboard extension.

## What is stored, and where

The app stores a small number of preferences **on your device only**:

| Stored | What it is |
|---|---|
| Layout | QWERTY or A–Z |
| Key face | Runes, runes with Latin hints, or plain letters |
| Haptics | On or off |
| Theme | Ritual or Even in Arcadia |
| Easter egg progress | Which of the hidden flamingos you have found |

These live in `UserDefaults` — an App Group container shared between the app and
its keyboard, with a per-process fallback when that container is unavailable.
They never leave your device. Deleting the app deletes them.

This is declared formally in the app's privacy manifests
(`PrivacyInfo.xcprivacy`), which list `UserDefaults` under reason codes `1C8F.1`
and `CA92.1`, and declare zero collected data types and zero tracking.

## What you type

Nothing you type is stored or transmitted. The keyboard inserts ordinary English
characters into whatever app you are using; it keeps no history, no buffer, and
no log. Text you compose in Rune Pad exists only in the view while you are
composing it.

## When data does leave the app

Only when you deliberately make it happen:

- **Exporting from Rune Pad** places an image or text on your system pasteboard,
  or opens the iOS share sheet, so you can paste it where you choose. Where it
  goes from there is up to you and governed by the receiving app.
- **The hidden Easter egg**, once completed, offers to open a song in Apple
  Music. That hands off to Apple's app or your browser, whose own privacy terms
  then apply. Nothing about you is sent with it.

## Children

The app collects no data from anyone, including children.

## Third parties

There are none. No SDKs, no frameworks beyond Apple's own, no partners, no data
sharing, because there is no data.

## Changes

If this policy ever changes, the revision will be committed to this repository
and the date above updated. The history is public.

## Contact

christian.perez@altivum.io

---

*Ritual Keyboard is an unofficial fan project. It is not affiliated with,
endorsed by, or connected to Sleep Token or their rights holders.*

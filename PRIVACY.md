# Privacy Policy

**Ritual Keyboard** (Sleep Token KB)
Last updated: 30 July 2026

## The short version

This app collects nothing, sends nothing, and has no servers. There is no
analytics, no tracking, no advertising, and no account. Nothing you type is
recorded, stored, or transmitted anywhere.

## What the keyboard can and cannot do

Custom keyboards on iOS are the most privacy-sensitive extension Apple offers,
so this is worth stating precisely rather than in general terms.

This keyboard **requests Full Access**. It is worth being exact about why, about
what it changes, and about what it does not.

**Why it is requested.** One reason: key press haptics. iOS does not deliver
haptic feedback from a keyboard extension unless Full Access has been granted.
There is no supported way around that, and no other feature depends on it.

**Granting it is your choice, and the keyboard is complete without it.** Full
Access is off until you turn it on in Settings, and most people never will.
Everything except haptics works either way — both layouts, all three key faces,
both themes, Rune Pad, and the alphabet chart.

**What changes if you grant it.** iOS stops blocking two things it otherwise
denies the extension: network access, and access to the container it shares with
the app. Earlier versions of this policy claimed that the operating system made
sending your keystrokes anywhere *impossible*. With Full Access granted that is
no longer an enforced guarantee, and it would be dishonest to keep saying so.

What remains is a weaker claim, but a checkable one: there is no networking code
anywhere in this app or its keyboard extension. No URLSession, no sockets, no
third-party SDK that could carry data off the device. The source is public, so
this is something you can verify rather than take on trust.

Nothing you type is recorded, buffered, logged, or transmitted — with or without
Full Access.

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

# Privacy Policy

**Ceremonial Scripts** (`ai.altivum.SleepTokenKB`)
Last updated: 27 October 2026

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
| Glide typing | On or off |
| Theme | Ritual or EIA |
| Recent emoji | The last 24 emoji you picked from the keyboard's emoji page, so the Recents tab can show them |
| Easter egg progress | Which of the hidden flamingos you have found |

These live in `UserDefaults` — an App Group container shared between the app and
its keyboard, with a per-process fallback when that container is unavailable.
They never leave your device. Deleting the app deletes them.

The recent-emoji list is the one entry here that is a record of something you
typed: which emoji, in what order, most recent first, capped at 24. It is kept so
the Recents tab works, it is stored only on your device, and nothing else about
what you type is kept alongside it.

This is declared formally in the app's privacy manifests
(`PrivacyInfo.xcprivacy`), which list `UserDefaults` under reason codes `1C8F.1`
and `CA92.1`, and declare zero collected data types and zero tracking.

## What you type

Nothing you type is transmitted. The keyboard inserts ordinary English characters
into whatever app you are using; it keeps no history, buffer, or log of your
text. The one exception is the recent-emoji list described above, which records
which emoji you picked and nothing else. Text you compose in Rune Pad exists only
in the view while you are composing it.

Two features read your text or your device's data to work, and both do so only
on the device:

- **Spelling suggestions** look at the word you are currently typing, using the
  system spell checker, to offer corrections in the bar above the keys. The word
  is checked and forgotten; nothing is stored.
- **Glide typing** uses a bundled English word list, plus the names in your
  contacts and your text replacements, which iOS hands to every keyboard that
  asks for its "supplementary lexicon". They are used to recognise the word a
  glide traces and are never stored by the keyboard or sent anywhere. The
  request is made only while glide typing is switched on.

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

*Ceremonial Scripts is an unofficial fan project. It is not affiliated with,
endorsed by, or connected to Sleep Token or their rights holders.*

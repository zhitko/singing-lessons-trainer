# Google Play listing assets

Singing Lessons Trainer, package `by.intoncore.singinglessonstrainer`, is not
published. `store-listing.md` is the listing for this app, in English and
Russian. Do not upload it under an Inton Trainer package, and do not paste the
Chinese-edition listing or the privacy URL of that other product.

The app icon is the Singing Lessons mark (microphone, two notes, curved
staff). `res/icons/intontrainer.png` is the source, and the launcher bitmaps
in `android/res/` are generated from it. The feature graphic and screenshots
in this folder are still the inherited Inton Trainer artwork. Replace those
before any Play submission.

| File | Role |
|---|---|
| `store-listing.md` | Listing text for this app (EN + RU), contact fields, category, What’s new |
| `icon-512.png` | 512×512 Play icon, flattened from `res/icons/intontrainer.png` |
| `icon-512-zh.png` | Inherited Chinese-edition icon. Not used for this app's launcher |
| `feature-graphic-zh.png` | Inherited feature graphic. Do not upload it for this app |
| `feature-graphic-zh.svg` | Vector source of that inherited graphic |
| `screenshots/` | Inherited captures of the other product. Recapture this app first |
| `screenshots/README.md` | What those inherited captures show |

## Before a Play upload

1. Replace the feature graphic and screenshots with captures of Singing Lessons Trainer. The icon is already this app's mark.
2. Open **Grow users → Store presence → Main store listing**.
3. Copy the English name, short description, and full description from `store-listing.md`.
4. Add a **Russian** translation and paste the RU fields.
5. Open **Store settings** and fill category and the contact email.
6. The privacy notice is the in-app document (`docs/privacy_policy_en.md` and `docs/privacy_policy_ru.md`). This app has no published HTTPS privacy URL yet. Do not enter `https://intontrainer.by/intontrainer2policy.html`.

This app's version is `0.1.0` / `versionCode` 1. It has no Play release.
The version history in `scripts/android_build_guide.md` after the identity
banner describes Inton Trainer 2, not this package.

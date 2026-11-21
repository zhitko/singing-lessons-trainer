# Privacy Notice

**Last updated November 21, 2026**

Singing Lessons Trainer is made by Vladimir Zhitko and Boris Lobanov. This notice describes what the application actually does with the microphone, recordings, scores, and settings. It is the notice bundled with this app. It is not the privacy policy of any other product.

Questions about this notice: zhitko.vladimir@gmail.com.

## What the app stores

The app asks for the microphone (`RECORD_AUDIO`) and uses it to record you singing after a reference. The Android manifest requires the microphone. Internet access and storage permissions are removed from the manifest. Android backup of app data is off (`allowBackup="false"`).

On the device, and only on the device, the app stores:

- WAV recordings of your takes, together with the reference lesson name, the similarity score, and the date
- Training statistics (scores and progress for the lessons you have tried)
- Your settings, including language, theme, and analysis options

Desktop and AppImage builds keep that data in a folder named `by.intoncore/SingingLessonsTrainer` next to the program (for an AppImage, next to the image file). Android keeps it in this app's private storage. The app does not upload recordings, scores, or settings. It has no account, no analytics, and no network request for this data.

## How long it stays

The data stays until you delete it or you uninstall the app.

- You can delete individual records in the app.
- **Delete user data** in Settings removes your statistics and saved recordings on that device.
- Uninstalling the Android app removes its private storage. `allowBackup="false"` means Android backup does not keep a copy for this app.

## Sharing and children

The authors do not receive your recordings or scores, so they are not shared with anyone and are not transferred to another country by the app. The app does not collect personal information on a server. It has no separate age gate. A recording still exists on the device until it is deleted as described above.

## Changes and contact

If this notice changes, the updated text ships with the app. Contact zhitko.vladimir@gmail.com.

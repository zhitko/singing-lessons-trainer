# Singing Lessons Trainer

Vladimir Zhitko and Boris Lobanov.

The vocal exercises are presented as audio files recorded by experienced vocal teachers. The proposed set of exercises relies to a large extent on the speech-level singing method developed by the well-known vocal teacher Seth Riggs. Training is based on lip and tongue trills, balancing vowel and consonant sounds, and sliding "sirens".

Singing Lessons Trainer plays a reference sung by a vocal teacher. You sing the same line. The app draws both pitch curves and scores melodic similarity and a mean tonal error. Lessons include vocal exercises and short song fragments. The app is not published on Google Play. Nothing you record is uploaded.

## Lessons

The bundled lessons keep their original folders and file names, including Cyrillic and Belarusian names:

- Singing exercises
- Some songs examples
- Examples of singing

Each lesson is a WAV file. Some WAV files have a sibling `.sfk` file. That is a Sound Forge peak file. The app does not read it. Training uses the WAV, including any cue labels stored inside the WAV.

## How to practice

1. On the home screen, tap **Start Training**.
2. Open a folder and choose a WAV lesson.
3. Listen to the reference, then sing the same line. In the automatic mode the recording stops after you go quiet. Guided mode plays the reference, waits, then listens. Manual mode starts and stops when you tap Record.
4. Read the two numbers at the top and compare the curves. Red is the reference. Dark brown is your take.

## Scores

**Similarity** is how alike the two melodies are. It is the Pearson correlation of the aligned, normalized pitch curves, shown as a percent. A negative correlation is shown as 0. A small trend marker compares this take with your previous similarity.

**Error** is the mean tonal error, shown as a percent immediately to the right of similarity. For each sample the app takes the absolute difference between the reference curve and your curve, on those same aligned curves (and only on the nucleus, when that option is on). Those differences are averaged as a power mean with exponent p. The default is p = 3: the cube root of the mean of the cubes, so a large miss weighs more than many small ones. The percent on screen is that mean times 100. Change p with `tonalErrorPower` in the `[%General]` section of `settings.ini`. Boris Lobanov's exact formula was a picture that was lost from his notes, so this calculation still needs his confirmation.

## What stays on the device

The app needs the microphone. Recordings, scores, and settings stay on the device. You can delete records, or delete user data, from Settings. See the privacy notice in the app.

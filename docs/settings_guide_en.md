# Settings guide — Singing Lessons Trainer

A singing-practice app: a reference recorded by a vocal teacher, your take, pitch curves, melodic similarity, and a mean tonal error. Authors: Vladimir Zhitko and Boris Lobanov.

This document describes the settings as they appear in the current interface. In the voice-detector settings, "speech" means the sung phrase the microphone hears.

Important notes:

- Settings are kept between launches.
- The Settings page has an **Advanced** switch at the top. It only shows or hides advanced controls and is not stored in `settings.ini`.
- Some voice-detector settings apply on the next recording.

---

## General

### Language

Interface language, such as English or Russian.

### Language Title

The label shown next to the active language on the home screen. It is not the translation of the interface. The bundled value is `Singing Lessons`.

### Theme

Light, dark, or the system theme. Pitch-chart colors are the same color-blind-safe colors in every theme, and the chart panel stays light.

### Primary Color

Accent color for buttons, selection, and progress.

### Show Navigation Menu

Shows or hides the navigation bar. When it is off, the app uses a desktop-style menu and a visible vertical scrollbar.

### Delete user data

An action, not a stored setting. It deletes your statistics and saved recordings on this device.

---

## Error calculation

### Tonal Error Power

The exponent `p` of the power mean of the absolute per-sample difference between the reference curve and your curve. The default is `3` (cubic mean). A larger `p` gives a large miss more weight. The screen shows that mean times 100, immediately after similarity. Values that are not greater than zero are ignored. The value is stored as `tonalErrorPower` in the `[%General]` section of `settings.ini`. Boris Lobanov's exact formula still needs his confirmation: the picture in his notes was lost.

---

## Automatic recording and guided mode

### Auto Stop Recording

When on, the app can end a recording after a pause. When off, you stop the recording yourself.

### Enable "Guided" training mode

Step-by-step practice. The app plays the reference, then waits for you to start singing in a listen window.

### Listen Window Timeout (ms)

How long the app waits for you to start after recording opens in guided mode. If you do not start in time, it returns to idle and does not score that wait.

### Post-Playback Delay (ms)

The pause after the reference finishes and before recording starts.

### VAD Method

How the app decides that singing has started:

- `Energy` — loudness
- `Autocorrelation` — periodicity of the voice
- `Hybrid AND` — both must agree
- `Hybrid OR` — either one is enough

### Silence Duration (ms)

How many milliseconds of silence end an automatic recording.

### Minimum Record Length (%)

The shortest accepted recording, as a fraction of the reference length. This rejects takes that are too short to score.

### Energy Threshold (Pe)

Sensitivity of the energy detector. A lower threshold makes it easier for noise to count as singing.

### Autocorr. Threshold

Threshold for the autocorrelation detector. Used by the autocorrelation and hybrid methods.

### Autocorr Min F0 / Max F0

The frequency band, in hertz, where the detector looks for a voice.

### Show A(n) / Show U(n) / Show V(n) / Show Corr.

Diagnostic voice-detector curves.

### Calibration

**Calibrate** records a short background clip and picks an energy threshold for the current microphone and room. Stay quiet. For the autocorrelation detector it also stores a correlation threshold and an energy threshold measured on the same windows used while recording. Hybrid modes calibrate both detectors, so the dialog shows twice the duration. Calibrate again after you change microphone or room noise.

Singing onset is confirmed after 40 ms of consecutive positive detector decisions. In guided mode only a confirmed onset stops the listen timer. A short pre-buffer is kept so the start of the phrase is not clipped.

---

## Pitch / Pitch Log / UMP / Amplitude / Spectrum

These sections are under Advanced. They control how the signal is displayed and processed.

### Pitch

Fundamental-frequency (`F0`) options: raw and processed curves, normalization, interpolation, smoothing, and frequency limits.

### Pitch Log

Extra processing of logarithmic pitch: smoothing, a moving average, binarization, and a threshold.

### UMP — Unified Melodic Profile

Whether the pitch profile is shown, and how it is smoothed.

### Amplitude

The amplitude envelope and its derivative: display, window, hop, and smoothing.

### Spectrum

Spectrum and cepstrum display: FFT length, logarithmic scale, palette, and cepstrum order.

---

## DP / DTW alignment

How your recording is lined up with the reference.

### Show DTW Distances

Diagnostic view of the time alignment.

### Fixed start/end DP (morph)

Pins the start and end of the alignment to the file boundaries.

### Use Pitch Log as Mask

Uses logarithmic pitch as an extra mask during alignment.

### DTW Distance Limit

If a microphone take is too far from the reference in alignment distance, it is dropped and is not added to the statistics. `0` turns the limit off. The bundled lessons use `0`.

---

## Worth remembering

- In normal use, most settings are hidden behind **Advanced**.
- Guided mode needs **Auto Stop Recording** on.
- Changes on the Settings page are saved immediately.
- **Advanced** is also how you hide the extra controls when you only want the basic ones.

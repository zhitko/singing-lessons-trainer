# Singing Lessons Trainer - TODO (from Boris Lobanov, "Доработки-1.docx", Nov 17, 2026)

Base: copy of Inton Trainer 2 (zhitko/inton-trainer-2) with Boris's settings.ini and patterns.zip
(sent in the "Singing Lessons" thread on Nov 13, 2026).

## Content
- [x] User Guide preface: add the paragraph about vocal exercises recorded by experienced vocal
      teachers, based on Seth Riggs' Speech Level Singing method (lip and tongue trills,
      vowel/consonant balance, sliding "sirens").
- [x] Bundle Boris's settings.ini as defaults and his patterns as the lesson set.

## Scoring
- [x] Keep melodic similarity (correlation).
- [x] Add mean tonal error: per-sample difference between reference and performance, averaged.
- [x] Use a cubic (or higher power) mean so large errors weigh more. Exact formula: ask Boris
      (it was lost from the docx).
      Note: implemented as the power mean M_p = (mean |r_i - u_i|^p)^(1/p) with p = 3
      (`[%General]/tonalErrorPower`, default constant `kDefaultTonalErrorPower` in
      `src/services/helpers/tonalerror.h`). The formula image was lost, so this still needs
      Boris Lobanov's confirmation.
- [x] Show error percent (mean x 100) at the top, right after the similarity value.

## UI
- [x] Graph colors differ between Light and Dark themes. Keep graph colors the same in both
      themes and make the Dark theme background lighter.
      Note: the chart uses the Light theme curve and band colors in both themes, and the
      plot panel is the light surface (`#F9F9FF`) so the Dark theme chart is lighter.

## Singing evaluation metrics (from Boris Lobanov, "Вокальные упражнения.docx", Nov 16, 2026)

The method background is already in the User Guide: Seth Riggs' Speech Level Singing
(lip and tongue trills, vowel/consonant balance, sliding "sirens"). The items below
compare a sung take with the reference. None of them are done.

### Pitch
- [ ] Raw Pitch Accuracy: share of voiced frames within a tolerance of the reference.
      Default tolerance 50 cents.
- [ ] Raw Chroma Accuracy: same comparison, but octave errors are not counted.
- [ ] Voicing Recall and Voicing False Alarm: share of voiced frames found, and share of
      silence mistaken for sound.
- [ ] Overall Accuracy: one percentage for the whole take that combines pitch accuracy
      and voicing.
- [ ] Pitch deviation in cents: mean absolute error (MAE) and root-mean-square error (RMSE)
      between the reference frequency and the sung frequency.
      Note: this needs absolute pitch in cents relative to the reference, not only the
      min-max normalized curves used for similarity and mean tonal error.

### Rhythm
- [ ] Onset F-measure: note onsets within ±50 ms, combining precision and recall.
- [ ] Note-level F-measure with offsets: onset and offset must both match. Tolerance is
      20% of the note length or 50 ms.
- [ ] IOI deviation: difference of inter-onset intervals against the reference, so a
      tempo speed-up or slow-down shows up.
- [ ] DTW-based overall rhythmic alignment. Dynamic time warping is already used to
      align a take for similarity; expose that alignment as a rhythm score.

### Loudness dynamics
- [ ] RMS envelope correlation between the reference and the user.
- [ ] Short-term LUFS (perceived loudness with K-weighting).
- [ ] Dynamic range and crest factor (peak against RMS).
- [ ] Envelope correlation (Pearson) for crescendo, diminuendo, and accents.

### Follow-ups
- [ ] Make the tolerance thresholds adjustable for beginners versus advanced singers
      (cents and milliseconds).
- [ ] Preprocess before scoring: noise filtering and loudness normalization.
- [ ] Prototype the metrics in Python first (mir_eval, librosa, crepe/pYIN, parselmouth,
      pyloudnorm) on Boris's patterns and real takes, then port the chosen 3–4 metrics
      to C++.

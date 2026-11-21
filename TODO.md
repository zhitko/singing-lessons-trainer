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

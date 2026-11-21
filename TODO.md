# Singing Lessons Trainer - TODO (from Boris Lobanov, "Доработки-1.docx", Nov 17, 2026)

Base: copy of Inton Trainer 2 (zhitko/inton-trainer-2) with Boris's settings.ini and patterns.zip
(sent in the "Singing Lessons" thread on Nov 13, 2026).

## Content
- [ ] User Guide preface: add the paragraph about vocal exercises recorded by experienced vocal
      teachers, based on Seth Riggs' Speech Level Singing method (lip and tongue trills,
      vowel/consonant balance, sliding "sirens").
- [ ] Bundle Boris's settings.ini as defaults and his patterns as the lesson set.

## Scoring
- [ ] Keep melodic similarity (correlation).
- [ ] Add mean tonal error: per-sample difference between reference and performance, averaged.
- [ ] Use a cubic (or higher power) mean so large errors weigh more. Exact formula: ask Boris
      (it was lost from the docx).
- [ ] Show error percent (mean x 100) at the top, right after the similarity value.

## UI
- [ ] Graph colors differ between Light and Dark themes. Keep graph colors the same in both
      themes and make the Dark theme background lighter.

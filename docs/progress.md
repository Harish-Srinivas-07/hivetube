# PROGRESS
Job: Repair design rollout regressions in Home contrast, navigation, and Shorts.
Started: 2026-11-14
## Steps
- [x] 1. Restore readable themed Home surfaces | files: lib/app/app_shell.dart, lib/features/home/home_screen.dart, lib/widgets/hive_logo.dart, test/theme_contrast_test.dart | gate: six root screens in light and dark have title contrast >= 4.5
- [x] 2. Restore floating pill navigation | files: lib/app/app_shell.dart, lib/theme/app_theme.dart, lib/widgets/floating_nav.dart, lib/widgets/glass_surface.dart, test/floating_nav_test.dart, test/widget_test.dart, docs/design.md | gate: drag selection and Shorts glass/red indicator restored
- [ ] 3. Restore Shorts page layout and pre-swipe loading | files: lib/features/shorts/shorts_screen.dart, test/shorts_screen_test.dart (only if needed) | gate: full-page sizing, safe-area/nav alignment, loading-page behavior and upcoming video/data readiness match 1614be4^
## Log
- 2026-11-14 plan recorded. Steps run sequentially; app_shell.dart is shared by steps 1 and 2 because both requested fixes require it.
- 2026-11-14 step 1 DONE analyze=ok lint=0 tests=178 pass
- 2026-11-14 step 2 DONE analyze=ok lint=0 tests=178 pass
## Decisions needed
- none

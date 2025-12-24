# No Hangs - Development TODO

- [ ] **Data backup/export**: JSON/CSV import/export of all session data and exercise definitions
- [ ] **BLE reliability**: Auto-reconnect, save state on disconnect, handle backgrounding/timeouts, better error messages
- [ ] **Session notes**: Optional notes with tags (tired/injured/great), star rating, display on history page
- [ ] **UX improvements**: Landscape support, tablet layouts
- [ ] **Code quality**: Error handling review, logging, memory leak checks

---

## Completed

- [x] Battery monitoring with periodic refresh
- [x] Target input usability (select all on tap)
- [x] Time since last rep display
- [x] Bidirectional unit conversion (% ↔ kg)
- [x] Compact toggle buttons UI
- [x] Minimal color palette for stats
- [x] Flexible chart aspect ratio
- [x] Delete all sessions functionality
- [x] Android release signing configuration
- [x] App bundle build for Play Store
- [x] Refactored BLE protocol handler (TindeqProtocol service)
- [x] Refactored rep detection logic (RepDetectionService)
- [x] Refactored session management (SessionService)
- [x] Quick exercise switcher (horizontal swipe with auto-save)
- [x] Dark mode with theme system (Material 3, custom theme extensions)

---

## Notes

- Keep focus on auto-regulated training (time since last rep > rigid timers)
- Exercise system is intentionally flexible (not just hangboard-specific)
- Prioritize reliability and data safety over features

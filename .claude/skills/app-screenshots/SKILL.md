---
name: app-screenshots
description: Generate App Store screenshots for InfiniteStories in a specific language.
argument-hint: [language-code]
disable-model-invocation: true
---

Generate App Store screenshots for InfiniteStories in a specific language.

## Arguments
- $ARGUMENTS: Language code (e.g., "en" for English, "fr" for French)

## Prerequisites
- The app MUST already be built and running on a simulator
- XcodeBuildMCP session defaults must be configured (simulatorId, projectPath, scheme)
- Use `mcp__XcodeBuildMCP__list_sims` to find the active simulator if needed

## Steps

### 1. Create output directory
Create `screenshots/$ARGUMENTS/` directory under the project root.

### 2. Change app language in Settings
1. Navigate to the Settings tab (5th tab, rightmost in tab bar, tap at approximate x=341, y=832)
2. Wait for the Settings view to load
3. Find and tap the "Langue de l'app" / "App Language" picker
4. Select the language matching $ARGUMENTS:
   - "en" = English
   - "fr" = French (Par defaut du systeme or Francais)
5. If a restart alert appears, dismiss it
6. The app may need to be restarted for language changes to take effect. If so:
   - Stop the app: `mcp__XcodeBuildMCP__stop_app_sim`
   - Relaunch: `mcp__XcodeBuildMCP__launch_app_sim`

### 3. Capture all screenshots
Use `xcrun simctl io {SIMULATOR_ID} screenshot {PATH}` to save screenshots to disk.
Use `mcp__XcodeBuildMCP__tap` and `mcp__XcodeBuildMCP__swipe` for navigation.
Use `mcp__XcodeBuildMCP__describe_ui` when you need precise element coordinates.
Use `mcp__XcodeBuildMCP__screenshot` (without savePath) for visual verification.

Navigate through each screen and capture in this order:

#### Tab Screens
1. **Home Screen** (`01_home.png`): Tap Home tab (x=60, y=832). Capture the main view with heroes and recent stories.
2. **Library** (`02_library.png`): Tap Library tab (x=121, y=832). Capture story library with search, filters, and cards.
3. **Heroes** (`03_heroes.png`): Tap Heroes tab (x=201, y=832). Capture hero list with avatars and traits.
4. **Reading Journey** (`04a_journey_stats.png`): Tap Journey tab (x=261, y=832). Capture stats and activity chart.
5. **Reading Journey scrolled** (`04b_journey_milestones.png`): Swipe up (y:600->200). Capture milestones and hero performance.
6. **Reading Journey insights** (`04c_journey_insights.png`): Swipe up again. Capture reading insights.
7. **Settings** (`05_settings.png`): Tap Settings tab (x=341, y=832). Capture theme, language, preferences.

#### Hero Creation Flow
8. Tap Heroes tab, then tap "Creer un Nouveau Heros" / "Create New Hero" button.
9. **Step 1** (`06a_hero_step1_name.png`): Capture name input screen.
10. Type a hero name (use "Luna" for en, "Luna la licorne" for fr), tap Next.
11. **Step 2** (`06b_hero_step2_trait1.png`): Capture primary trait selection grid.
12. Tap Next (Brave is pre-selected).
13. **Step 3** (`06c_hero_step3_trait2.png`): Capture secondary trait selection.
14. Tap Next.
15. **Step 4** (`06d_hero_step4_preview.png`): Capture appearance and hero preview card.
16. Tap Cancel/Annuler to dismiss without creating.

#### Story Generation
17. Go to Home tab, tap the orange FAB button (label: "Creer une nouvelle histoire" or similar).
18. **Story Generation** (`07a_story_generation.png`): Capture hero card, event picker, generate button.
19. Tap the event picker button to open event selection.
20. **Event Picker** (`07b_event_picker.png`): Capture event categories and custom events.
21. Swipe up to see more events.
22. **Event List** (`07c_event_list.png`): Capture full event catalog.
23. Tap Cancel to dismiss event picker. Swipe down to dismiss story generation.

#### Audio Player
24. On Home screen, tap a story card to open the Audio Player.
25. **Audio Player** (`08_audio_player.png`): Capture full player with controls, story text, toolbar.
26. Tap "Termine" / "Done" to dismiss.

#### Custom Events
27. On Home screen, tap the blue grid FAB (label: "Gerer les evenements personnalises").
28. **Custom Events** (`09_custom_events.png`): Capture events grid with filters and search.
29. Dismiss the custom events view.

### 4. Verify screenshots
List the screenshots directory to confirm all files were saved:
```
ls -la screenshots/$ARGUMENTS/
```

### 5. Summary
Report the total number of screenshots captured and list any screens that could not be captured (e.g., if no stories exist for Audio Player).

## Important Notes
- Always use `sleep 1` before taking screenshots to allow animations to complete
- Use `xcrun simctl io {SIMULATOR_ID} screenshot {PATH}` for saving to disk (the MCP savePath parameter does NOT work)
- Use `mcp__XcodeBuildMCP__screenshot` (no savePath) only for visual verification during navigation
- Tab bar coordinates (iPhone 17): Home=60, Library=121, Heroes=201, Journey=261, Settings=341, all at y=832
- For swipe gestures use `mcp__XcodeBuildMCP__swipe` with x1,y1,x2,y2 as integers
- For tapping by label use `mcp__XcodeBuildMCP__tap` with the label parameter
- If a screen has no data (empty state), still capture it - empty states are valid screenshots

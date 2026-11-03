# AFK Remote — UX Spec

The app works without a server of our own. It talks directly to Discord REST v10 (`https://discord.com/api/v10`) using the user's own bot token, which is stored in the Keychain. Local data lives in SwiftData.

<screens>

## Root

### AFKRemoteApp / RootView (Sources/Views/RootView.swift)
- `@Observable CredentialStore` loads the token and channel ID from the Keychain synchronously at launch.
- It exposes `isConfigured` (both values non-empty).
- The root switches on state:
  - `if credentials.isConfigured { MainTabView() } else { OnboardingView() }`
- Dark color scheme is forced: `.preferredColorScheme(.dark)`.
- On first launch, `SeedService.seedIfNeeded(context)` inserts the seeded macros (see Data) when `AppSettings.didSeed == false`.

## Onboarding

### OnboardingView (Sources/Views/Onboarding/OnboardingView.swift)
This view owns its own NavigationStack.

**Step 1 — Welcome**
- App glyph: SF Symbol `gamecontroller.fill` in a red rounded square.
- Title: "AFK Remote".
- Copy: "Control your PC's Roblox macros from anywhere through your Discord bot."
- "Get Started" button pushes `CredentialsFormView`.

### CredentialsFormView (Sources/Views/Onboarding/CredentialsFormView.swift)
This view is reused by Settings.
- **Bot Token**: SecureField with an eye toggle to reveal.
- **Channel ID**: TextField with `.numberPad` and digits only.
- **Help disclosure: "Where do I find these?"**
  - Discord Developer Portal → Bot → Reset Token.
  - Enable **Message Content Intent**; without it, message text from other bots and webhooks appears empty.
  - Invite the bot with View Channel, Send Messages, Read Message History and Attach Files permissions.
  - Turn on Developer Mode → right-click the channel → Copy Channel ID.
- **"Test Connection"** (secondary button) calls `GET /channels/{id}` and shows an inline result row:
  - Success: green check + "Connected to #channel-name".
  - Failure: red message mapped from the status code (see Discord Client).
- **"Save & Continue"** (primary button):
  - Enabled when both fields are non-empty.
  - If the test has not passed, show a confirmation dialog: "Connection not verified. Save anyway?"
  - On save, write both values to the Keychain and call `credentials.reload()`.
  - `isConfigured` becomes true, the onboarding subtree unmounts and `MainTabView` mounts.
  - The onboarding view never navigates imperatively.

## MainTabView (Sources/Views/MainTabView.swift)
- `TabView(selection: $router.selectedTab)` with the system tab bar hidden: `.toolbar(.hidden, for: .tabBar)`.
- A custom `AFKTabBar` overlays the bottom safe area.
- Tab order: `.macros`, `.schedule`, `.home` (center, default), `.feed`, `.settings`.
- Each tab root view owns exactly one NavigationStack.
- `@Observable AppRouter` holds `selectedTab`, is injected through the environment, and is used by Home's "START MACRO" button.
- `@Observable FeedStore` is shared by Home and Feed. It holds:
  - `messages: [DiscordMessage]`, `isLoading`, `error`, `lastFetched`.
  - It hydrates from `CachedFeed` on launch.
  - It refreshes every `AppSettings.refreshInterval` seconds while the scene is active and pauses in the background.
- `@Observable ScheduleRunner` starts here (see Schedule).

### AFKTabBar (Sources/Views/Components/AFKTabBar.swift)
- Bar: 64pt tall, `#0F0F0F` background, top hairline `#272727`.
- Side tabs:
  - Icon 22pt above a caption label.
  - Selected: white icon, filled symbol variant, label in white.
  - Unselected: `#AAAAAA`.
- Center Home tab:
  - 56pt red circle raised 12pt above the bar, white `house.fill` icon (or the custom icon), with a subtle red glow shadow.
  - When selected, the circle shows a 2pt white ring.
- Icons come from `TabIconConfig` and render either the SF Symbol or the custom photo (clipped circle, 24pt).
- Labels: "Macros", "Schedule", "Home", "Feed", "Settings".
- Light haptic on tab change.

## HOME tab

### HomeView (Sources/Views/Home/HomeView.swift)
ScrollView with `.refreshable` (calls `feedStore.refresh()`). Sections top to bottom:

**1. Status header card**
- **Running**: green pulsing dot + "RUNNING", the macro name in title style, and the elapsed time `HH:MM:SS` via `TimelineView(.periodic(from: .now, by: 1))` with monospaced digits.
  - Caption shows the source: "Started from this app" or "Detected from channel".
  - A red "Stop" pill sits on the right.
- **Idle**: grey dot + "Nothing running" and a full-width 64pt red "START MACRO" button with `play.fill`. Tapping it sets `router.selectedTab = .macros`.
- Active state resolution, in order:
  1. The local `ActiveMacroState` (if present).
  2. Otherwise, inference from the newest feed message whose content matches `^\[App\] !(\w+)`:
     - If that command is a one-shot or stop command (category Utility, or `stop`/`cancel`/`close_all`/`close_ahks`), nothing is running.
     - Otherwise, look the command up in Macros for a display name (fallback: the raw command) and use the message timestamp as the start time.
  - If the channel shows a newer `[App] !stop` than the local `startTime`, clear the local state.

**2. Quick actions**
- A row of four equal square buttons: icon + label on a `#1F1F1F` card.
- Stop: `stop.fill`, red icon → `!stop`.
- Screenshot: `camera.fill` → `!send_screenshot`.
- Stats: `chart.bar.fill` → `!stats`.
- Reconnect: `arrow.clockwise` → `!reconnect`.
- Each sends `[App] !cmd` and shows a spinner on that button while sending.
- Success: haptic + toast "Sent !cmd", then a feed refresh after 3s.
- Stop also deletes `ActiveMacroState`.

**3. Latest Screenshot card**
- Source: the newest message with an image attachment (`content_type` hasPrefix `image/`) or an embed `image.url`.
- AsyncImage at 16:9 with `.fill` and a 12pt radius, fading in.
- Placeholder: shimmer.
- Failure: `photo` symbol + "Couldn't load image".
- Caption: author name + relative time.
- Tap opens `ImageViewer` (fullScreenCover).
- Empty: "No screenshots yet" + a "Request Screenshot" button that sends `!send_screenshot`.

**4. Latest Stats card**
- Source: the newest message whose content or embed title/description contains "stats" or "hourly" (case-insensitive).
- Renders the embed title, description and fields as a two-column grid of name/value pairs, or the plain content in monospaced text.
- Shows a timestamp.
- Empty: "No stats yet" + a "Request Stats" button.

**5. Recent Activity**
- The last 15 messages in chronological order (newest at the bottom) as compact `ChatBubbleRow`s.
- A "See all" link sets `router.selectedTab = .feed`.

**Loading, error and refresh**
- Loading on first launch with no cache: skeleton cards.
- Error: an inline red banner at the top with the mapped message and "Retry"; cached content stays visible below it.
- The toolbar title "AFK Remote" is large and leading.
- A trailing indicator shows "Updated 5s ago" with a small spinner while fetching.

## MACROS tab

### MacrosView (Sources/Views/Macros/MacrosView.swift)
- Navigation title "Macros"; `.searchable` filters by name or command.
- **Category selector**: a horizontal chip row.
  - PSX Classic: `pawprint.fill`.
  - PS99: `sparkles`.
  - Utility: `wrench.and.screwdriver.fill`.
  - Selected chip: red fill with white text. Unselected: `#272727`.
- **Body**: a List grouped by subcategory in fixed order (Event, Grinding, Hatching, Utility). Empty sections are hidden.
- **MacroRow**:
  - 52pt rounded thumbnail: `imageData`, or a placeholder tile using a dark gradient in the category tint plus the category SF Symbol.
  - Name (headline) and `!command` (caption, monospaced, `#AAAAAA`).
  - Trailing green "RUNNING" capsule if it is the active macro.
  - Trailing "Custom" tag if `isCustom`.
- Swipe actions: Edit (opens `MacroEditorView` sheet) and Delete. Delete asks for confirmation and also deletes the macro's schedules.
- Toolbar `+` presents `MacroEditorView` (sheet, new).
- Tap a row → push `MacroDetailView`.
- Empty search: "No macros match" + "Clear search".
- Empty category (all deleted): "No macros here" + "Add Macro".

### MacroDetailView (Sources/Views/Macros/MacroDetailView.swift)
- **Hero image**: full width, 4:3, from `imageData` or the placeholder tile. A small overlay button "Change Photo" opens a PhotosPicker; the image is downscaled to max 1200px JPEG 0.8 and saved to `imageData`. A "Remove Photo" menu item appears when an image is set.
- **Content**: name (display), description (body), then a details group of rows:
  - Game ("Pet Simulator X" / "Pet Simulator 99" / "Utility").
  - Category, Subcategory.
  - Date Created (formatted date).
  - Command `!command` with a copy button.
- **Primary action** pinned to the bottom (safe-area inset):
  - For PSX Classic and PS99 macros: a 56pt red "Start" button with `play.fill`.
    - It sends `[App] !command`.
    - On success, it upserts `ActiveMacroState(macroName, command, startTime: .now, startedFromApp: true)`, plays a success haptic, and animates into the Running state.
  - **Running state** (this macro is active): a green "Running" label, a live elapsed timer, and an outlined red "Stop" button. Stop sends `!stop`, clears the state and returns the button to Start.
  - If a different macro is running, Start shows a confirmation: "Stop X and start Y?" It sends `!stop`, then the new command 1s later.
  - For Utility macros: the button reads "Send" with `paperplane.fill`. It is one-shot, does not set the running state and shows a toast.
- Toolbar menu: Edit (sheet `MacroEditorView`) and Delete (confirm, then pop).

### MacroEditorView (Sources/Views/Macros/MacroEditorView.swift)
This is a sheet with its own NavigationStack. Form fields:
- Photo: PhotosPicker + preview.
- Name (required).
- Command (required; leading "!" is stripped; must match `^[A-Za-z0-9_]+$`; inline error otherwise).
- Description (multiline).
- Category (Picker: PSX Classic / PS99 / Utility). Game is derived from the category.
- Subcategory (Picker: Event / Grinding / Hatching / Utility).

Behaviour:
- Cancel / Save in the toolbar; Save is disabled until the form is valid.
- New macros get `isCustom = true` and `dateCreated = .now`.
- Seeded macros are editable, and edits keep `isCustom = false`.

## SCHEDULE tab

### ScheduleView (Sources/Views/Schedule/ScheduleView.swift)
- **"Up next" header card**: the next enabled occurrence across all schedules, showing the macro name, a weekday + time, and a live countdown `in 2h 14m 05s` (TimelineView, 1s).
  - None: "No upcoming schedules".
- **List of ScheduleRow**:
  - Macro thumbnail + name.
  - Time in large monospaced digits.
  - Repeat summary: "Once · Mar 4", "Daily", or "Mon, Wed, Fri".
  - Trailing Toggle (red tint) bound to `isEnabled`; changing it reschedules notifications.
  - Tap → `ScheduleEditorView` sheet (edit). Swipe → Delete.
- Toolbar `+` → `ScheduleEditorView` (new).
- **Info footer card** (always visible, `info.circle`), with exact text:
  - "How scheduling works: At the scheduled time you'll get a notification with a 'Start now' button. If AFK Remote is open, the command is sent automatically. iOS controls background activity, so automatic sending while the app is closed is best-effort and may be late or skipped — the notification is the reliable part."
- **Permission banner**: if notification authorization is denied, show a banner "Notifications are off — schedules can't alert you" + "Open Settings" (opens `UIApplication.openSettingsURLString`).
- Empty state: `calendar.badge.clock` icon, "Schedule a macro", and an "Add Schedule" button.

### ScheduleEditorView (Sources/Views/Schedule/ScheduleEditorView.swift)
This is a sheet with its own NavigationStack. Form fields:
- Macro picker: a NavigationLink inside the sheet's stack to a searchable list grouped by category.
- Time: DatePicker `.hourAndMinute`, wheel style.
- Repeat: segmented control Once / Daily / Weekdays.
  - Once: an additional date picker.
  - Weekdays: seven circular toggle chips S M T W T F S; at least one is required.
- Enabled toggle.

Behaviour:
- On first save, request notification authorization (contextual).
- Save reschedules notifications.

## FEED tab

### FeedView (Sources/Views/Feed/FeedView.swift)
- Navigation title "Feed".
- `.searchable` matches content, embed text and author name.
- Filter chips: All / Commands (content starts with `[App]`) / Screenshots (has an image) / Stats / Bots & Webhooks.
- LazyVStack of `MessageRow`, newest first, with `.refreshable`.
- Shares `FeedStore`, so auto-refresh applies.

### MessageRow (Sources/Views/Components/MessageRow.swift)
- 36pt avatar AsyncImage (Discord CDN, or a fallback `person.circle.fill`).
- Display name (bold) + a "BOT" or "WEBHOOK" capsule tag + relative timestamp. Long-press shows the absolute time.
- Content in body text with selectable text.
- `[App] !cmd` messages are rendered as a red-bordered command pill.
- Embeds: a card with a 3pt left bar in the embed color, title, description and a fields grid.
- Image attachments and embed images display inline (max height 240, radius 10). Tap → `ImageViewer`.
- Non-image attachments show a filename row with a `doc` icon that opens the URL with `Link`.
- Context menu: Copy Text, Share image.

**States**
- Loading: skeleton rows.
- Empty: "No messages in this channel yet" + "Refresh".
- Error: full-screen error with Retry if there is no cache; otherwise a top banner.
- No filter matches: "Nothing matches" + "Clear filters".

### ImageViewer (Sources/Views/Components/ImageViewer.swift)
- fullScreenCover on a black background.
- Pinch zoom with MagnifyGesture (1–4x) and double-tap to toggle 2x.
- Drag down to dismiss.
- Top bar: Close (`xmark`) and ShareLink (downloads the image data, then shares it as an Image).

## SETTINGS tab

### SettingsView (Sources/Views/Settings/SettingsView.swift)
This is a grouped List.

**Discord**
- Bot Token row shows a masked value (`••••••••` + last 4 characters). Tap → push `CredentialsFormView` in edit mode, prefilled; Save writes the Keychain and pops.
- Channel ID row shows the full ID and also opens the same form.
- "Test Connection" row runs the test inline and shows a spinner, then the result text.
- "Clear Credentials" (destructive, confirm) deletes the Keychain items and calls `credentials.reload()`. `isConfigured` becomes false and the root view shows onboarding.

**Appearance**
- "Tab Icons" → push `TabIconsView`.
- Accent Color picker with four presets:
  - YouTube Red `#FF0000` (default).
  - Orange `#FF6A00`.
  - Electric Blue `#3EA6FF`.
  - Lime `#22C55E`.
- Haptics toggle.

**Refresh**
- Auto-refresh interval picker: 10s / 15s (default) / 30s / 60s / Off.

**About**
- App version (from the bundle).
- One line: "AFK Remote sends commands to your Discord channel; your PC macro bot reads them."
- Privacy note: "Your token stays in this device's Keychain and is only sent to discord.com."

### TabIconsView (Sources/Views/Settings/TabIconsView.swift)
- A list of the five tabs with their current icon preview.
- Tap → sheet `TabIconPickerView`.
- "Reset All" restores the defaults.

### TabIconPickerView (Sources/Views/Settings/TabIconPickerView.swift)
This is a sheet with its own NavigationStack.
- Segmented control: SF Symbol / Photo.
- **SF Symbol**: a 5-column grid of 40 curated symbols, including `house.fill`, `gamecontroller.fill`, `bolt.fill`, `calendar`, `clock.fill`, `list.bullet.rectangle`, `bubble.left.and.bubble.right.fill`, `gearshape.fill`, `star.fill`, `flame.fill`, `pawprint.fill`, `sparkles`, `crown.fill`, `cube.fill`, `trophy.fill`, `heart.fill`, `bell.fill` and `terminal.fill`. The selected symbol has a red ring.
- **Photo**: a PhotosPicker; the image is cropped square and downscaled to 96px PNG.
- Save writes the `TabIconConfig`. "Use Default" clears it.

</screens>

<navigation>
- **Root (state-driven)**: `RootView` observes `CredentialStore.isConfigured`.
  - false → `OnboardingView` (own NavigationStack: Welcome → push CredentialsFormView).
  - true → `MainTabView`.
  - Saving credentials or clearing them flips state and the root swaps subtrees. Auth screens never navigate imperatively.
  - There are no user accounts, so no login or logout. "Clear Credentials" is the reset affordance.
- **MainTabView**: a TabView with a custom bar. Each tab root (`MacrosView`, `ScheduleView`, `HomeView`, `FeedView`, `SettingsView`) owns exactly one NavigationStack. Pushed views never create a NavigationStack.
- **Pushes**:
  - Macros → MacroDetailView.
  - Settings → CredentialsFormView (edit) and TabIconsView.
  - ScheduleEditorView (inside its sheet stack) → MacroPickerList.
- **Sheets** (each with its own NavigationStack): MacroEditorView, ScheduleEditorView, TabIconPickerView. All use slide-up presentation.
- **fullScreenCover**: ImageViewer (fades in).
- **Cross-tab moves**:
  - Home "START MACRO" → `router.selectedTab = .macros`.
  - Home "See all" → `.feed`.
  - Tapping a schedule notification body → `.schedule`.
  - The notification's "Start now" action sends the command without opening the app (background action), then posts a local confirmation notification "Started X".
- Push transitions use the standard trailing slide; pop goes back.
</navigation>

<design_direction>
**Audience and moment**
- A Roblox grinder checking on an AFK PC from the couch, bed or school. Quick glances, often at night.
- It should feel like a confident remote control: dark, punchy and media-app familiar.

**First screen**
- Home answers "is my macro running and is it working?" through the status plus timer, the latest screenshot, the latest stats, and one-tap quick actions.
- A first-time user goes through onboarding (credentials, then test, then save), lands on Home in the Idle state, taps START MACRO, then picks a seeded macro and taps Start. Seeing it running is the first success.

**References**
- YouTube: the dark chrome, red brand moments, clean bottom bar and dense card feed.
- Discord: message row anatomy (avatar, name, tag, timestamp, embeds with a color bar).
- Apple TV Remote: big, unambiguous control buttons.

**Appearance**: dark only.

**Palette**
| Role | Hex |
|---|---|
| Background | `#0F0F0F` |
| Surface (cards) | `#1F1F1F` |
| Elevated surface / chips | `#272727` |
| Hairline | `#303030` |
| Primary text | `#F1F1F1` |
| Secondary text | `#AAAAAA` |
| Brand | `#FF0000` (user-selectable preset; stored as `AppSettings.accentHex`) |
| Status accent (running/success) | `#2BA640` |

Red is used only for primary buttons, the center tab, the selected chip and destructive or stop actions.

**Typography**: SF Pro.
| Style | Spec |
|---|---|
| Display | 34 bold |
| Title | 22 bold |
| Headline | 17 semibold |
| Body | 15 regular |
| Caption | 12 medium, secondary color |

Timers and commands use SF Mono (`.monospaced()`) with `.monospacedDigit()`. Dynamic Type is supported.

**Shape and depth**
- Cards: 12pt radius on `#1F1F1F`, no shadows, separated by 8pt and 16pt gaps.
- Buttons: 12pt radius. Chips and pills: capsule.
- The only shadow is the center tab's red glow (radius 12, 40% opacity).

**Imagery**
- Real screenshots from the channel and user photos for macros. Otherwise SF Symbols.
- Macro placeholders are a category-tinted dark gradient tile with a large SF Symbol:
  - PSX `#3A1C1C`→`#1F1F1F` with `pawprint.fill`.
  - PS99 `#1C263A`→`#1F1F1F` with `sparkles`.
  - Utility `#262626`→`#1F1F1F` with `wrench.and.screwdriver.fill`.
- No generated art.

**Components**
- Primary button: brand fill, white semibold label, 52–64pt tall, full width.
- Secondary button: `#272727` fill with white label.
- Destructive outline: 1.5pt red stroke with red label.
- List rows: on surface, 60pt minimum height, hairline separators inset 16pt.
- Inputs: `#272727` fill, 10pt radius, red focus ring.
- Toast: a capsule at the top on `#272727` with an icon, auto-dismissing after 2s.
- Loading: shimmer skeletons using `#272727`→`#303030`.
- Empty state: a 44pt secondary-color SF Symbol, a headline, one line of caption, and one primary button.
- Error: a red-tinted banner (`#FF0000` at 15% opacity background, red icon) with a Retry text button.

**Theme file**: `Sources/Theme/Theme.swift` defines:
- Colors, with accent read from AppSettings via the environment.
- Fonts and the spacing scale (4, 8, 12, 16, 24, 32).
- Radii.
- `PrimaryButtonStyle`, `SecondaryButtonStyle`, `DestructiveOutlineButtonStyle`.
- `CardModifier`, `ChipView` and `ToastView`.

Views use no one-off colors.
</design_direction>

<animation_and_motion>
- Buttons scale to 0.96 on press using a spring (response 0.25).
- Start → Running uses a matched transition of the button morphing into the timer and Stop button (spring 0.35).
- The running dot pulses (opacity 1→0.4, 1.2s repeat). It is static when Reduce Motion is on.
- Haptics (when enabled):
  - `.success` when a command is sent.
  - `.error` on failure.
  - `.selection` on tab change and toggles.
- New feed messages insert with a fade and move.
- The countdown and timer use `.contentTransition(.numericText())`.
- With Reduce Motion on, all springs become crossfades.
</animation_and_motion>

## Local Data (SwiftData @Model, Sources/Models/)

**Macro**
- Fields: `id: UUID`, `name: String`, `command: String` (no `!`), `macroDescription: String`, `category: String` (`psxClassic` | `ps99` | `utility`), `subcategory: String` (`event` | `grinding` | `hatching` | `utility`), `game: String`, `imageData: Data?` (`@Attribute(.externalStorage)`), `dateCreated: Date`, `isCustom: Bool`.

**Schedule**
- Fields: `id: UUID`, `macroId: UUID`, `time: Date` (hour/minute used; for `once`, the full date), `repeatType: String` (`once` | `daily` | `weekdays`), `selectedWeekdays: [Int]` (1=Sun…7=Sat), `isEnabled: Bool`, `lastFiredAt: Date?`.

**ActiveMacroState**
- A single row.
- Fields: `macroName: String`, `command: String`, `startTime: Date`, `startedFromApp: Bool`.

**AppSettings**
- A single row, created on first launch.
- Fields: `refreshInterval: Int` (seconds, 0 = off, default 15), `accentHex: String` (default `#FF0000`), `hapticsEnabled: Bool` (true), `didSeed: Bool`.

**TabIconConfig**
- Fields: `tabKey: String` (unique: macros | schedule | home | feed | settings), `symbolName: String?`, `customImageData: Data?`.
- Defaults when absent: `square.grid.2x2.fill`, `calendar.badge.clock`, `house.fill`, `text.bubble.fill`, `gearshape.fill`.

**CachedFeed**
- A single row.
- Fields: `rawJSON: Data` (last messages response), `fetchedAt: Date`.
- Lets Home and Feed render instantly and offline.

## Seeded Macros
- Seeded with `isCustom = false`.
- Name is the command title-cased with underscores turned into spaces (e.g. `psx_candy` → "PSX Candy").
- Each gets a one-line description.

**PSX Classic** (game "Pet Simulator X")
- Grinding: `psx_candy`, `psx_chest`.
- Hatching: `psx_final_egg`.
- Event: `psx_halloween`.
- Utility: `psx_classic`.

**PS99** (game "Pet Simulator 99")
- Grinding: `best_area`, `start_raid`, `world_1`, `world_4`, `vault_raid`, `raid_xp_boosters`.
- Event: `gifts`, `rankup`, `default_hoverboard`.

**Utility** (game "Utility", subcategory Utility, one-shot "Send")
- `stop`, `reconnect`, `send_screenshot`, `stats`, `toggle_autoclicker`, `open_autoclicker`, `autoclicker_check`, `focus_roblox`, `check_disconnect`, `close_all`, `close_ahks`, `cancel`, `mouse_correction`, `pause_disconnect`, `unpause_disconnect`, `enable_autoclicker_warning`, `disable_autoclicker_warning`, `help`.

## Keychain (Sources/Services/KeychainService.swift)
- Uses `kSecClassGenericPassword` with service `com.afkremote.credentials`.
- Accounts: `botToken` and `channelId`.
- Accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, so background tasks can read them.
- Functions: `read(account)`, `save(account, value)`, `delete(account)`.

## Discord Client (Sources/Services/DiscordService.swift)
A URLSession `actor` with base URL `https://discord.com/api/v10`.

**Headers**
- `Authorization: Bot {token}`.
- `Content-Type: application/json`.
- `User-Agent: DiscordBot (https://afkremote.app, 1.0)`.

**Endpoints**
- `getChannel(id)`: `GET /channels/{id}` → `{id, name}`.
- `fetchMessages(id, limit: 50)`: `GET /channels/{id}/messages?limit=50` → `[DiscordMessage]`.
- `sendCommand(id, command)`: `POST /channels/{id}/messages` with body `{"content": "[App] !{command}"}`.

**Codable models** (snake_case decoding)
- `DiscordMessage`: `id`, `content`, `timestamp: Date` (ISO8601 with fractional seconds), `author{id, username, global_name?, avatar?, bot?}`, `webhook_id?`, `attachments[{id, filename, url, proxy_url, content_type?, width?, height?}]`, `embeds[{title?, description?, color?, image?{url}, thumbnail?{url}, fields?[{name, value}]}]`.
- Avatar URL: `https://cdn.discordapp.com/avatars/{author.id}/{avatar}.png?size=64`.
- Display name: `global_name ?? username`.

**Rate limits (429)**
- Read `retry_after` (seconds, Double) from the JSON body, falling back to the `Retry-After` header.
- Sleep, then retry, up to 2 retries.
- Surface "Rate limited — retrying in Xs" as a toast.

**Error mapping**
- 401 → "Invalid bot token".
- 403 → "Bot lacks permission for this channel".
- 404 / 10003 → "Channel not found — check the ID".
- Network errors → "No connection".
- Other → "Discord error (code)".

**Empty content**: if a non-own message has empty content and no embeds or attachments, the feed shows a hint once: "Some messages look empty — enable Message Content Intent for your bot."

## Scheduling (Sources/Services/ScheduleRunner.swift + NotificationService.swift)

**Notifications**
- `UNUserNotificationCenter` category `MACRO_SCHEDULE` with action `START_NOW` (title "Start now", no `.foreground` option, so it runs in the background).
- `userInfo` carries `scheduleId`, `macroId` and `command`.
- **Rescheduling** happens on every schedule change and on app launch:
  - Remove all pending notifications, then for each enabled schedule add:
    - `once`: one `UNCalendarNotificationTrigger` with the full date components, no repeat.
    - `daily`: hour and minute, repeating.
    - `weekdays`: one repeating trigger per weekday (weekday + hour + minute).
  - Notification text: title "Time to run {macro}", body "Tap Start now to send !{command}."
- **Delegate**:
  - `START_NOW`: send the command, set `ActiveMacroState` for non-utility macros, set `lastFiredAt`.
  - `willPresent` while in the foreground: suppress the banner if the runner already auto-sent.

**Foreground auto-send**
- While the scene is active, a 15s timer checks for any enabled schedule whose most recent occurrence is ≤ 60s ago and whose `lastFiredAt` is before that occurrence.
- For each match: send the command, set `lastFiredAt`, and show a toast "Scheduled: started X".
- A `once` schedule sets `isEnabled = false` after firing.

**Background**
- `BGAppRefreshTask` identifier `com.afkremote.schedule-refresh`, registered at launch.
- Info.plist needs `BGTaskSchedulerPermittedIdentifiers` and `UIBackgroundModes: fetch`.
- Submit a request with `earliestBeginDate` set to the next occurrence.
- The handler runs the same due-check, then resubmits for the next occurrence.
- The UI text states that this is best-effort.

**Next occurrence** is computed with `Calendar.nextDate(after:matching:)` and powers "Up next" and the countdown.

<component_standards>
- Every data screen (Home, Feed, Macros, Schedule) implements loading, empty (one action) and error (Retry) states as described above.
- AsyncImage always has a shimmer placeholder, a 0.2s fade-in and a `photo` fallback.
- Long content uses LazyVStack or List. Spacing follows the 8pt grid.
- Contrast: `#F1F1F1` and `#AAAAAA` on `#0F0F0F` both pass 4.5:1. Red buttons use white bold text.
- All tap targets are at least 44pt.
- VoiceOver labels:
  - Quick actions: "Stop macro", "Request screenshot", "Request stats", "Reconnect".
  - Timer reads "Running for 1 hour 4 minutes".
  - Tab bar items carry their labels plus the selected trait.
- Dynamic Type is supported; the quick-action row wraps to a 2×2 grid at accessibility sizes.
</component_standards>
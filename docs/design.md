# HIVETUBE DESIGN.MD (MASTER, AGENT-READ)

Audience: coding agents. Not for humans. Compact, normative.
Scope: mobile portrait only (phone). NO wide/desktop/tablet layouts. Do not add breakpoints or grid branches.
Goal: pixel-feel parity with real YouTube mobile app (flat, content-first, quiet chrome).
Precedence: this file > existing code style. If code conflicts, change the code.
Keywords: MUST, MUST NOT, SHOULD.

## 0. AGENT PROTOCOL
1. Before building any UI: find the component in section 4, reuse it. Do not create a parallel widget.
2. Missing token: add to theme/app_*.dart, then use. MUST NOT hardcode numbers, colors, font sizes in widgets.
3. One VideoCard (widgets/common/video_card.dart). One chip (AppChip). One button (AppButton). No duplicates.
4. Every list/feed screen MUST implement all 4 states: loading (skeleton), data, empty, error. See section 6.
5. Every screen MUST work light + dark.
6. After UI changes: `dart analyze` clean, grep section 8 banned patterns = 0 hits.
7. Behavior is not changed by restyle tasks. Restyle = visuals/spacing/motion only.
8. Unsure about spec: pick the YouTube mobile behavior, note it in one line in the final reply.

## 1. PRINCIPLES
- Flat. Zero shadow, elevation, glow, glass, blur, gradient, border on content surfaces.
- Separation by spacing and tonal fill, never lines/dividers/cards.
- Content (thumbnails) dominates. Chrome (bars, buttons) is neutral monochrome. Red (primary) is only for: progress/played, live badge, subscribe (filled=inverse, not red), notification dot, active seek.
- Thumbnails: phone feed = full-bleed 16:9, radius 0. Shelves/search/grid = radius 12.
- Text hierarchy by size/weight/opacity only: title 14 w500 onSurface, meta 12 w400 onSurfaceVariant.
- Tap targets >= 48 (visual can be smaller).
- Motion is functional and short (<=300ms). No decorative animation. Respect MediaQuery.disableAnimations.

## 2. TOKENS (define in theme/, names are canonical)

### 2.1 Spacing (AppSpacing)
xxs 2 | xs 4 | sm 8 | md 12 | lg 16 | xl 24 | xxl 32
- screenGutter = md (12). Cards text row gutter = md (12).
- feedCardGap = xl (24). shelfCardGap = md (12) (shorts gap sm 8).
- sectionHeaderPad: left md, top lg, bottom sm.
- iconGap = sm (8) inside buttons.

### 2.2 Radius (AppRadius)
xs 4 (badges) | sm 8 (chips, small thumbs) | md 12 (thumbs, banners, shorts) | lg 16 (sheet top, dialogs) | pill 999 (buttons, search field, avatar)

### 2.3 Sizes (AppSizes)
touchMin 48 | icon 24 | iconSm 20 | iconXs 16
avatarSm 24 | avatar 36 (feed, search, comments 40) | avatarLg 72 (channel header, library header)
chipHeight 32 | buttonHeight 36 | buttonLarge 40 | topBar 56 | bottomNav 56 (+ safe area)
thumbRatio 16/9 | shortRatio 9/16 (card 2:3 in shelf) | shortShelfCardW 150
trendingCardW 280 | compactThumbW 168 (compact row, 16:9 => 94 high)
seekTrack 3 | seekThumb 12 (touch: 16) | progressBarWatched 3
miniPlayerH 56 (thumb 16:9 left)

### 2.4 Typography (AppTextStyles) — font: Roboto/system; line heights explicit
| token | size/height | weight | use |
| pageTitle | 20/28 | 600 | top bar titles, channel name header |
| sectionTitle | 18/24 | 600 | shelf headers |
| videoTitle | 14/20 | 500 | card titles, list titles |
| body | 14/20 | 400 | descriptions, comments |
| bodyStrong | 14/20 | 500 | names, handles |
| meta | 12/16 | 400 | views, date, channel line |
| chipLabel | 14/20 | 500 | chips |
| buttonLabel | 14/20 | 500 | buttons |
| badge | 12/16 | 500 | duration, LIVE |
| caption | 11/16 | 400 | shorts views, counts |
| settingsTitle | 16/24 | 400 | settings rows |
| settingsSub | 13/18 | 400 | settings value |
Rule: no inline fontSize/fontWeight in widgets. Always token (.copyWith(color:) only).

### 2.5 Color (AppColors; light / dark)
| role | light | dark |
| background/surface | #FFFFFF | #0F0F0F |
| surfaceVariant (chips, fills, banners, search field) | #F2F2F2 | #272727 |
| onSurface (text primary) | #0F0F0F | #F1F1F1 |
| onSurfaceVariant (text secondary) | #606060 | #AAAAAA |
| outlineVariant (only if border unavoidable: outlined button) | #D0D0D0 | #3F3F3F |
| primary (YouTube red) | #FF0000 | #FF0000 |
| onPrimary | #FFFFFF | #FFFFFF |
| chipSelectedBg | #0F0F0F | #F1F1F1 |
| chipSelectedFg | #FFFFFF | #0F0F0F |
| badgeBg (duration) | #000000 @80% | same |
| badgeFg | #FFFFFF | same |
| scrim (player overlay, shorts bottom) | #000000 @40% / bottom-only gradient allowed for legibility ONLY on shorts and player | same |
| shimmerBase | #F2F2F2 | #272727 |
| shimmerHighlight | #E6E6E6 | #333333 |
| error | #CC0000 | #FF6B6B |
Rule: ThemeData must set scaffold=background, cardTheme elevation 0, appBar elevation 0, scrolledUnderElevation 0, sheets elevation 0.

### 2.6 Motion tokens (AppMotion)
fast 100ms | base 200ms | slow 300ms | shimmerLoop 1200ms
curves: enter = Curves.easeOutCubic | exit = Curves.easeInCubic | standard = Cubic(0.2, 0, 0, 1)
Rules:
- Press feedback = platform ripple/InkWell only (cards, tiles, icons). Buttons may scale 0.98 over fast.
- Selection change (chip, tab, switch) = color cross-fade base, no movement.
- Content appearing (image) = FadeIn 150ms. Lists MUST NOT animate item entrance (no staggered/slide-in).
- Sheets/dialogs = platform default.
- Never animate layout size of feed cards.

## 3. GLOBAL LAYOUT
- Root tabs (bottom nav, 4): Home, Shorts, Subscriptions, Library. Search is an icon in the top bar. Settings via Library.
- Bottom nav: flat bar, bg=background, no top border, no glass/blur, 56 + safe area. Item: icon 24 + label 11. Selected = onSurface filled icon, unselected = onSurfaceVariant outline icon. Selection change = icon swap, no animation beyond fade.
- Mini player: floating, draggable, width 55% of screen, 16:9, radius 12, flat (no shadow, no border). Snaps to the 4 corners (default bottom-right), clears the bottom nav and safe area. Tap or swipe up expands the watch panel. Controls: play/pause top-left, close top-right, each 40x40 on a black@60% circle, icon 16 white. 2px primary progress line on the bottom edge. Position persists for the session. Swipe is blocked while dragging.
- Scroll bottom padding on every root screen = bottomNav + safeArea + lg. The floating mini player does not add bottom padding. Applied ONCE (use SliverBottomInset; do not add an extra spacer).
- Status bar: transparent, icon brightness follows theme. Watch fullscreen hides system UI.
- Pull-to-refresh on Home, Subscriptions, Library lists, Channel, Search results (not Shorts, not Watch). Indicator color = onSurface, bg = surface.
- Tab re-tap (tabRefreshProvider): scroll to top first; if already at top, refresh.

## 4. COMPONENTS
Format: USE-WHEN | ANATOMY/SPEC | STATES | MOTION | DON'T

### 4.1 AppTopBar
USE-WHEN: every root screen. Height 56, side pad 12, bg=background, no elevation.
Home: logo (left) | language button 48 | search icon 48. Plain IconButtons, no background, no glass.
Library/Subs/History/Playlist/Channel/Settings: leading back (if pushed) or title pageTitle; trailing icons 48.
DON'T: GlassSurface, blur, border, tonal circle behind icons in top bar.

### 4.2 AppChipBar + AppChip
USE-WHEN: filter row (Home categories, Subscriptions channel filter, History filters).
Spec: bar height 48 (chip 32 + vert pad 8), side pad 12, gap 8, horizontal scroll, no scrollbar, no edge fade/ShaderMask.
Chip: height 32, radius 8, horizontal pad 12, chipLabel. Selected = chipSelectedBg/Fg. Unselected = surfaceVariant bg + onSurface text.
Optional leading icon 16 (e.g. Explore). First chip "All" selected by default.
STATES: default, selected, pressed (ripple).
MOTION: bg/fg cross-fade base. No scale, no slide.
BEHAVIOR: selecting calls controller.select(chip); keep scroll position of bar; selected chip scrolled into view with 200ms ease.
DON'T: pill radius, border, shadow, elevation.

### 4.3 ThumbnailWithDuration
Spec: AspectRatio 16/9, fill, placeholder=surfaceVariant flat (no spinner), CachedNetworkImage memCacheWidth = displayWidth*DPR, fadeIn 150ms.
Radius param: 0 (feed phone) | md (others).
Duration badge: bottom-right, inset 4, bg badgeBg, text badge, radius xs 4, pad h4 v2.
Live: badge red bg, text "LIVE", same position. Upcoming: "UPCOMING" dark badge.
Watched progress: bottom edge, height 3, track white@30%, fill primary, full width of thumb. Only if progress != null.
DON'T: overlay gradient on thumbs, play icon overlay, shadow.

### 4.4 ChannelAvatar
Circle, sizes avatarSm/avatar/avatarLg. Placeholder: surfaceVariant circle with first letter of name (onSurfaceVariant, bodyStrong). Image fade 150ms. No border. Tap => /channel/:id when channelId non-empty.
PERF: avatar url resolved via per-channel provider (family). Avatar load MUST NOT rebuild the parent list.

### 4.5 VideoCard (single widget, modes)
Fields: VideoItem {id,title,channelId,channelName,channelAvatarUrl,thumbUrl,durationText,viewsText,publishedText,isShort,progress?}.
Meta string = [channelName, viewsText, publishedText].where(nonEmpty).join(' · ').
Wrap each card in RepaintBoundary. ValueKey(video.id) at list level.

MODE feed (Home, Subscriptions, Watch-related-on-phone full):
- Thumb full-bleed 16:9 radius 0.
- Text row: padding L12 R4 T12 B0. Row: avatar 36 | 12 | Column(Expanded: title videoTitle max2, 2px gap, meta max2) | 3-dot 40x40 (icon 20, visualDensity compact).
- Card bottom margin 24 (between cards).
- Tap card => openWatchPanel(ref, id). Avatar tap => channel. 3-dot => video options sheet.
MODE grid / shelf (Trending, rounded): thumb radius 12, width per shelf (trending 280). Text row no avatar optional; padding L0 T8; title 14 max2; meta 12 max1-2. 3-dot 24 trailing.
MODE searchResult (Search): stacked. Thumb inset 12 each side, radius 12. Gap 12. Row padding 0 12: avatar 36 | 12 | title+meta | 3-dot. Bottom margin 16.
MODE compact (Playlist rows, History, Watch related list, Library lists): row, padding v4 h12. Thumb 168x94 radius 8 (left) | 12 | Column(title 14 max2, meta 12 max1, 2 lines total) | 3-dot 40. Row min height 102. Duration badge on thumb.
STATES: pressed ripple on whole card (InkWell, no radius on feed), watched (progress bar only; do not dim).
DON'T: elevation, border, shadow, Card() widget, divider between cards.

### 4.6 SectionHeader
Row: [leading icon 24 optional] [sectionTitle] [spacer] [trailing text button "View all" bodyStrong or chevron]. Padding L12 R4 T16 B8.

### 4.7 ShortsShelf + ShortCard
Header: Shorts icon 24 + "Shorts" sectionTitle. Placement: in Home feed after 4th video (index 4). Exactly one shelf per feed page.
Horizontal list height = cardW*1.5 (150x225), side pad 12, gap 8.
ShortCard: radius 12 clip, thumb cover. Bottom scrim (transparent -> black@60%, 40% of height). Title bottom-left (pad 8) white 13 w500 max2; views caption below. 3-dot top-right white icon 20, no bg.
Tap => shortsSelectionProvider.open(items,index); context.go('/shorts'); close watch panel first if open.

### 4.8 AppButton
Variants: filled (bg onSurface, fg surface) | tonal (surfaceVariant bg, onSurface fg) | text | outlined (1px outlineVariant, last resort) | destructive (primary bg).
Height 36 (large 40), pill radius, h pad 16, buttonLabel, icon 20 + gap 8.
Subscribe: filled (inverse). Subscribed: tonal + bell icon + chevron-down. Never red.
STATES: disabled opacity .38, loading = 16px spinner replace label.
MOTION: press scale .98 fast.

### 4.9 AppIconButton
48 touch, icon 24 onSurface. tonal=false default for top bars/lists. tonal=true only for action rows (watch actions). No shadow.

### 4.10 LikeDislikeSegment
Single pill (surfaceVariant), height 36: [thumbUp + count | 1px divider (outlineVariant@40%, 55% height) | thumbDown]. Active icon filled, color stays onSurface (YouTube behavior); count hidden for dislike unless RYD loaded.

### 4.11 ActionRow (Watch)
Horizontal scroll row of tonal pills: LikeDislike, Share, Download?, Save, Report. Height 36, gap 8, pad L12.

### 4.12 ListTile (AppListTile / SettingsTile)
Standard: min height 56, pad h16, leading 24 icon (onSurfaceVariant) with 24 gap to text, title 16 (settingsTitle), sub 13 (settingsSub, onSurfaceVariant), trailing icon/value/Switch. No divider. No card.
Settings section header: 13/18 w500 onSurfaceVariant, pad L16 T24 B8.
Library quick row (History, Playlists...): leading icon 24, title 15->use videoTitle 14? NO: use settingsTitle 16, trailing count meta.

### 4.13 BottomSheet (options menu, select dialogs)
Top radius 16, bg surface (dark: #212121), drag handle 32x4 radius 2 onSurfaceVariant@40% centered top pad 8. Rows 56 high: icon 24 + 24 gap + label settingsTitle. Selection list: radio on right. No elevation, scrim black@50%.
Video options: Add to queue, Save to playlist, Save to watch later, Download, Share, Not interested.

### 4.14 Dialog / Snackbar
Dialog radius 16, title pageTitle 18/24 w500, actions text buttons right. No elevation.
Snackbar: floating, margin 12, bg #323232 (light) / #F1F1F1 text dark (inverse), radius 8, text 14, single text action. 4s. Sits above mini player+nav.

### 4.15 InlineBanner
Row: surfaceVariant bg, radius 12, margin 12, pad 12, text 13 onSurface, trailing text button "Retry". Use for partial failures (e.g., some sources failed) while content is still shown. One banner max per screen.

### 4.16 EmptyState / ErrorRetry
Centered column: icon 48 onSurfaceVariant, 16 gap, title 16 w500, 8 gap, subtitle 14 onSurfaceVariant (max 2 lines), 24 gap, one AppButton.tonal. No illustrations. Fills remaining viewport (SliverFillRemaining).

### 4.17 Skeletons
Match real layout exactly (same sizes/radius/margins). Flat blocks shimmerBase, highlight sweep ltr, 1200ms linear loop, single shared AnimationController per skeleton screen.
FeedSkeleton: repeat [16:9 block full-bleed; row pad L12 T12: circle 36 | 12 | bar 14h 90% width, bar 12h 60% width, 2px gaps]; gap 24; count fill viewport + 1.
Shelf skeleton: header bar + cards. Compact skeleton: 168x94 radius 8 + two bars.
DON'T: spinner for first load of lists. Spinner only for: loadMore (24px, centered, pad 16), button loading, refresh.

### 4.18 SearchField (top bar on search screen)
Height 40, pill, bg surfaceVariant, leading back arrow 48 outside field, leading search icon 20 inside, clear (x) icon when non-empty, hint "Search", text 16. No border; focus = no ring (cursor primary only). Autofocus on open. Keyboard action = search.

### 4.19 SuggestionRow
Height 48, pad h16: leading icon 20 (history clock for recents, search for suggestions), text 16 (typed prefix regular, completion bold), trailing: arrow-up-left 20 (fills field, does not submit). Tap row = submit. Recents long-press = remove. Debounce 250ms; stale responses dropped; clear old list immediately on new query.

### 4.20 PlayerControls (watch, fullscreen, inline)
Overlay layout over video (scrim black@40% flat, fades 200ms):
- Top: collapse chevron-down (left) | spacer | captions (cc) | settings (gear) — icons 24 white, touch 48.
- Center: previous | play/pause (56 icon, 72 touch) | next. Buffering = spinner replaces play (32).
- Bottom: time "0:12 / 3:45" 12 white left | spacer | fullscreen icon 24. Seek bar full width directly above, edge to edge.
Behavior: single tap toggles overlay. Auto-hide 3s after last interaction when playing. Double-tap left/right third = seek -10/+10 with expanding ripple + "10 seconds" label, 400ms. Long-press hold = 2x speed (indicator top-center "2x"). Swipe down on inline player = minimize to mini player (follows finger, snap threshold 25% or velocity).
Fullscreen: landscape, hide system UI, overlay same, bottom row adds speed/quality in settings sheet.
Settings sheet rows: Quality (max 1080p), Playback speed, Captions, Sleep timer? (skip), Loop.

### 4.21 SeekBar
Track 3px, rounded. Colors: played primary, buffered white@50%, remaining white@30%. Thumb: hidden at rest (when overlay shown it is 12 primary dot), 16 while dragging. Drag shows time bubble above thumb (badge style) and, if available, chapter title. Scrubbing MUST NOT trigger rebuild of the whole player (use ValueListenable).
Mini player progress: 2px primary line, no thumb.

### 4.22 CommentTile
Row pad h12 v8: avatar 40 | 12 | Column: [@handle meta 12 bold + · time meta], text body (max 6 lines + "Read more"), action row [thumbUp 20 + count, thumbDown 20, reply "Reply" meta bold]. Replies collapsed under "N replies" (primary-colored? NO: onSurface bodyStrong with chevron). Pinned badge: small tonal pill.

### 4.23 PlaylistCard (library shelf)
Width 160. Thumb 16:9 radius 12 with stacked-look using 2 offset translucent bars above (6px/10px inset, surfaceVariant) — flat, no shadow. Bottom-right overlay badge: playlist icon 16 + count (badge style). Below: title videoTitle max2, meta "Updated X ago" 12.

### 4.24 ChannelHeader
Banner 16:9? use 6.2:1 ratio full-bleed (skip if none). Row: avatar 72 | 16 | Column(name pageTitle, "@handle · 1.2M subscribers · 120 videos" meta, 2-line description tap-to-expand). Subscribe button full-width row below (AppSubscribedButton, buttonLarge). Tab bar below: Home, Videos, Shorts, Playlists, About — text tabs 14 w500, indicator 2px onSurface under selected, no tab animation beyond 200ms indicator slide, scrollable.

## 5. SCREENS

### 5.1 HOME (/ , tab 0)
Order: TopBar(Home) -> ChipBar(All, Music, Movies, Gaming, Live, News, Podcasts, Sports, Comedy, Cooking, Science, Tech, Education) -> feed.
Feed: single CustomScrollView, ONE video sliver (SliverList.builder, keyed) with Shorts shelf injected at index 4, Trending shelf after the list (or at index 12 if videos>=12), then loading-more footer / "You're all caught up" (meta, pad 24 centered), then bottom inset.
Cards: VideoCard feed mode. Trending = horizontal shelf grid-mode cards width 280.
States: loading=FeedSkeleton | error=ErrorRetry("Unable to load Home") | empty=EmptyState("No videos found", Retry) | partial errors=ONE InlineBanner "Some sources could not load".
Behavior: scroll offset>0 or pointer-down => homeProvider.interact(); extentAfter < 1 screen => loadMore(); chip select => select(chip) (cached per chip, keep scroll per chip); pull-to-refresh => refresh(); tab re-tap => top then refresh.
Perf: select() fields from homeProvider; history progress map memoized; avatar updates do not rebuild list; RepaintBoundary per card; addAutomaticKeepAlives false.
No first-run helper text block.

### 5.2 SEARCH (/search)
Top: SearchField. Body modes:
 a) empty query: recents list (SuggestionRow history, max 10, "Clear all" text button right of a small header)
 b) typing: suggestions list (SuggestionRow), keyboard stays up, list scrolls with keyboard dismiss on drag.
 c) results: ChipBar (All, Videos, Channels, Playlists, Live — optional filter) then results list. Mix of VideoCard searchResult, channel row (avatar 72 + name bodyStrong + "@handle · N subscribers" meta + Subscribe button 36 right), playlist row (compact thumb with count badge + title + "Playlist · N videos"), Shorts shelf (horizontal) when present.
Results gap 16. Infinite scroll via continuation; footer spinner 24.
States: loading=Skeleton (searchResult layout) | empty="No results for 'x'" + subtitle "Try different keywords" | error=ErrorRetry.
Behavior: submitting saves term (await) to history (max 5-10 unique), unfocuses field, runs search. Back clears to prior mode. Focus must stay stable while suggestions update (existing focus test must pass).

### 5.3 WATCH (watchPanelProvider, openWatchPanel(ref,id))
Three states of one panel: expanded, minimized (mini player), closed.
Expanded layout (phone portrait): player 16:9 pinned top (stays while below scrolls) -> scroll area:
 1. Title: videoTitle but 16/22 w500, max 2 lines, tap expands description. Meta below: "1.2M views · 3 days ago" meta + "...more".
 2. Channel row: avatar 36 | name bodyStrong + subscribers meta | AppSubscribedButton (right).
 3. ActionRow (4.11).
 4. Comments teaser: surfaceVariant rounded 12 card (flat) pad 12: "Comments N" bodyStrong + top comment preview 1-2 lines + avatar 24. Tap => comments sheet (draggable, snap 60%/100%).
 5. Related: VideoCard feed mode list (phone). Loading more on scroll.
Description expanded: inline expand (animate height 200ms) or bottom sheet; show full text, links tappable, hashtags primary-colored text (onSurface bodyStrong acceptable), chapters list tappable (seek).
Minimize: vertical drag on player; panel collapses to MiniPlayer; audio continues (background play + media notification). Close removes session.
Fullscreen: rotate or button; controls 4.20. Exit restores portrait panel.
States: loading=player black 16:9 with centered spinner + below skeleton (title bars, channel row, actions) | error (stream fail)=in-player centered "Playback error" + Retry text button + "Open in browser"? no: Retry only | unavailable video=message in place of player.
Behavior extras: SponsorBlock auto-skip segments with snackbar "Skipped sponsor" + Undo; RYD dislike count; resume position from history; autoplay next from related (setting); history entry saved on play.
Motion: expand/collapse follows drag 1:1, settle slow 300ms easeOutCubic; content below fades in 150ms once player expanded.

### 5.4 SHORTS (/shorts, tab 1)
Full-screen vertical PageView (snap, physics clamping), black bg, system bars transparent. No top bar except overlay.
Per page: video cover-fit 9:16, tap = play/pause (brief center icon 56 fade 200ms), long-press = pause (resume on release), double-tap = like (heart burst 400ms, optional).
Overlays: right rail (bottom 96 from edge, x pad 12), vertical gap 20: like (thumbUp 28 + count caption), dislike (thumbDown 28 + "Dislike"), comments (28 + count), share (28 + "Share"), more (3-dot), channel avatar 36 at bottom of rail? NO: avatar is bottom-left.
Bottom-left (pad L12 B16, max width 75%): row avatar 32 | @channel bodyStrong white | Subscribe pill (filled white bg black text, height 32) ; below: title 14 white max2. Bottom gradient scrim black@50% 30% height (allowed here).
Top-left: back/close if pushed via home shelf; top-right: search + more 48 white.
Progress: 2px line at very bottom, primary, no thumb, scrubbable on drag (optional).
Behavior: preload next 1 page; pause when page not visible/app backgrounded; loop video; autoplay on page settle; mute state persistent.
States: loading=black + centered spinner | error=black + "Couldn't load Shorts" + Retry | end=stay on last.
Motion: page snap slow 300ms easeOutCubic; rail icons fade-in 150ms; like toggle = icon fill swap + scale 1.0->1.2->1.0 150ms.

### 5.5 CHANNEL (/channel/:id)
Top bar: back + search + more (overlay on banner, transparent, icons white with 24 shadow? NO shadow; use scrim top 56 black@40%).
Body: ChannelHeader (4.24) -> tabs.
 - Home: featured video (compact?) + shelves (Latest videos horizontal, Shorts shelf, Playlists shelf)
 - Videos: ChipBar (Latest, Popular, Oldest) + VideoCard feed list (or grid-mode rounded). Continuation scroll.
 - Shorts: 3-col grid, ratio 2:3 gap 2... use gap 4, radius 8, views caption bottom-left white on scrim.
 - Playlists: 2-col grid of PlaylistCard, gap 12.
 - About: description text, links, joined date, location, view count, stats as 2-line rows (settingsTitle + settingsSub).
Tab bar sticks under top bar on scroll (pinned). Header collapses (banner scrolls away, avatar row scrolls away; name stays in top bar on collapse via fade 200ms).
States: loading=header skeleton (circle 72 + bars) + tab body skeleton | error=ErrorRetry | empty tab=EmptyState ("This channel has no videos").
Behavior: subscribe toggles local subscription + optimistic UI; notification bell sheet (All/Personalized/None) when subscribed.

### 5.6 LIBRARY (tab 3, "You")
Layout top->bottom:
 1. Header row pad 16: avatar 72 (local profile) | 16 | Column(name pageTitle, "N videos watched · M playlists" meta). Below (pad T12): chips-style tonal buttons row: "Edit profile", "Backup" AppButton.tonal (height 36, pill). Settings gear 48 in top bar right.
 2. History shelf: SectionHeader("History","View all") -> horizontal list of cards (thumb 160x90 radius 8? use radius 12, title 13 max2, meta 12 max1; width 160) gap 12 pad L12. Empty: EmptyState compact (icon + "Videos you watch will show here"), no button.
 3. Playlists shelf: SectionHeader("Playlists","View all") + "New playlist" tonal pill leading card? Horizontal PlaylistCards. Empty: one row tile "Create playlist".
 4. Rows (ListTile, height 56, leading icon 24): Your videos? NO (no upload) -> Downloads, Liked videos, Watch later, Stats (local). Trailing count meta + chevron none.
States: loading=header skeleton + shelf skeletons | each section has own empty (never one global empty).
Behavior: Backup opens bottom sheet: Export to file / Import from file (+ Takeout import). Edit profile opens bottom sheet with avatar picker + name field (text field style: surfaceVariant fill, radius 12, no border).
Pull-to-refresh refreshes shelves.

### 5.7 SETTINGS (pushed from Library gear)
Plain full-width list, no cards, no dividers, no shadow. TopBar pageTitle "Settings", back.
Groups (header style 4.12): General | Playback | Privacy & data | Integrations | About.
 General: Content language (value: "Tamil, English") -> language sheet; Theme (System/Light/Dark) -> radio sheet; Home content mix (local ratio) -> slider sheet or radio.
 Playback: Max video quality (value "1080p") -> radio sheet; Autoplay (Switch); Background play (Switch); Playback speed default -> radio sheet.
 Privacy & data: Pause watch history (Switch); Clear watch history (confirm dialog); Clear search history (confirm dialog); Backup & restore -> sheet; Clear cache (value size).
 Integrations: SponsorBlock (Switch + subtitle categories -> sheet); Return YouTube Dislike (Switch); Captions default language -> sheet.
 About: Version, Licenses, Source/Feedback links.
Row: min 56; leading 24 icon; Switch = native, themed (selected track primary@50%, thumb primary).
Selecting radio option = apply immediately, sheet auto-closes 150ms after tap.
Destructive confirm: dialog title "Clear watch history?" body one line, actions Cancel (text) / Clear (text, primary color allowed).
States: none (static). Changed values reflect immediately in subtitle.

### 5.8 SUBSCRIPTIONS (tab 2)
Top: TopBar title "Subscriptions" | search 48 | manage ("Manage" text button).
Row 1: horizontal channel avatar strip: avatar 56 + name 12 max1 centered, width 72, gap 4, pad L12; first item "All" chip-like; unread new-video dot (8 primary) top-right of avatar. Tap avatar = filter feed to channel (selected: name bold, 2px underline? use bold + onSurface ring? NO border: use bold name only).
Row 2: ChipBar (All, Today, Videos, Shorts, Live, Continue watching) optional.
Feed: VideoCard feed mode, sorted by publishedAt desc (RSS merged; fallback to channel videos tab when RSS empty/404). Group headers by "Today / This week / This month" (sectionTitle 16? use sectionTitle) — flat, optional.
Manage (/subscriptions/manage): list rows: avatar 40 | name bodyStrong + meta | bell icon button 48 (opens notification sheet) | Unsubscribe via row menu. Import from Takeout CSV in top bar menu. Search channels field at top (SearchField small).
States: loading=skeleton strip + FeedSkeleton | empty (no subs)=EmptyState("No subscriptions yet" , "Subscribe to channels to see their videos here", button "Find channels"->search) | error=ErrorRetry | partial=InlineBanner.

### 5.9 HISTORY (/history)
TopBar: back, title "History", search 48 (filter local), more (Clear all, Pause history).
Body: grouped by day: header sectionTitle 16 ("Today", "Yesterday", "Mon, Nov 10") pad L12 T16 B8; rows = VideoCard compact with watched progress bar; trailing 3-dot (Remove from history, Add to playlist, Share).
Swipe to dismiss row = remove (snackbar "Removed from history" + Undo).
No Shorts distinction: isShort is not persisted. All entries render as compact rows.
States: loading=compact skeletons | empty=EmptyState("No watch history", "Videos you watch will appear here") | paused banner (InlineBanner "Watch history is paused", action "Turn on").
Perf: paged from DB (limit 50, load more at end), grouped lazily.

### 5.10 PLAYLIST (/playlist/:id)
Header (not sliver-pinned): cover = first video thumb 16:9 radius 12 margin 12; below: title pageTitle (editable inline if local), meta "N videos · Updated X · Private" ; action row: Play all (filled pill, play icon), Shuffle (tonal pill), Download (icon), Share (icon), More.
List: VideoCard compact rows, reorder via drag handle (local playlists, long-press to drag, handle icon 24 right), index number leading 24 meta optional.
Menu (3-dot): Remove from playlist, Move to top, Save to other playlist, Share.
Save-to-playlist sheet (save_to_playlist_sheet): list rows with checkbox (themed), "New playlist" row at top (plus icon), title field in dialog.
States: loading=header skeleton + compact skeletons | empty=EmptyState("This playlist is empty", "Add videos from Watch or Search") | error=ErrorRetry | unavailable videos shown disabled (title "Unavailable video" onSurfaceVariant, thumb surfaceVariant).

## 6. STATE MATRIX (all list screens)
| state | UI |
| initial load | skeleton matching final layout, no spinner |
| refreshing | pull indicator; keep stale content visible |
| loading more | footer spinner 24 centered pad 16 |
| end of list | meta text "You're all caught up" pad 24 (Home/Subs only) |
| empty | EmptyState, one line + one button max |
| fatal error | ErrorRetry, one Retry button |
| partial error | ONE InlineBanner above/below content with Retry |
| offline | same as error, subtitle "Check your connection" |
Never: blank screen, text-only "No videos found" without layout, multiple stacked error rows.

## 7. PERFORMANCE RULES (UI)
- Feeds: SliverList.builder, stable ValueKey(id), addAutomaticKeepAlives false, RepaintBoundary per card, no Opacity/ClipRRect around large subtrees unless needed (ClipRRect only on thumb).
- Images: CachedNetworkImage with memCacheWidth/maxWidthDiskCache = logical width * DPR; low-res placeholder = flat color; fadeInDuration 150ms; never decode full-size for thumbs.
- Provider reads: use ref.watch(provider.select(...)); parent lists MUST NOT watch per-item data (avatars, progress, like state). Per-item data via family providers inside the item.
- Avatar/metadata backfill: batch or family provider; one state update does not rebuild the list.
- Scrubbing, progress, timers: ValueListenable/stream scoped to the smallest widget.
- Skeleton: one AnimationController per screen, shared via inherited shimmer.
- Const constructors everywhere possible. No setState on screen root for chip selection if provider holds it.
- Debounce search 250ms; cancel in-flight (CancelToken).
- Large lists must paginate (history 50/page, search/continuations, subscriptions merged lazily).

## 8. ANTI-PATTERNS (grep = 0)
BoxShadow | elevation: (non-zero) | Card( | GlassSurface | BackdropFilter | ImageFilter.blur | ShaderMask | Divider( in feeds/settings | BorderSide (except outlined AppButton, text field focus none) | gradient (except shorts/player scrim) | fontSize: (inline) | Color(0x / Colors. (inline) | EdgeInsets with raw numbers (use AppSpacing) | SizedBox(height: <number>) raw | borderRadius: BorderRadius.circular(<number>) raw
Behavior bans: staggered list entrance animation, bouncing/elastic curves, parallax, auto-playing previews in Home feed, blocking spinners on first load, snackbar for non-actionable info, multiple error rows, emoji in UI chrome.

## 9. USECASE -> COMPONENT QUICK MAP
| need | use |
| show a video in a vertical feed | VideoCard.feed |
| video in horizontal shelf | VideoCard.grid/shelf (rounded, width fixed) |
| video in search | VideoCard.searchResult |
| dense list of videos (history, playlist, related) | VideoCard.compact |
| filter by category | AppChipBar + AppChip |
| primary action | AppButton.filled |
| secondary action | AppButton.tonal |
| icon action in bars | AppIconButton(tonal:false) |
| option choice (single) | BottomSheet radio list |
| option toggle | ListTile + Switch |
| dangerous action | Dialog confirm, text buttons |
| transient confirmation with undo | Snackbar + action |
| partial failure | InlineBanner |
| no data | EmptyState |
| failed fetch | ErrorRetry |
| initial loading | Skeleton (matching) |
| section with more | SectionHeader + horizontal list |
| user/channel picture | ChannelAvatar |

## 10. DEFINITION OF DONE (UI TASK)
1. Uses only components from section 4; no new duplicate widgets.
2. Tokens only; light + dark verified by theme usage (no hardcoded colors).
3. All states from section 6 implemented.
4. Bottom inset applied once; mini player overlap handled.
5. Section 8 grep clean; `dart analyze` clean; `flutter test` passes.
6. Behavior unchanged unless the task says so.
7. Final reply = one line: files changed | grep hits | analyze | tests.

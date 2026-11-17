# HIVETUBE DESIGN.MD (MASTER, AGENT-READ) — REV 5

Audience: coding agents. Not for humans. Compact, normative.
Scope: mobile portrait only (phone). NO wide/desktop/tablet layouts. Do not add breakpoints or grid branches.
Exception: video fullscreen is landscape. It is a player mode, not a layout. Only player UI (4.20, 4.25) may be landscape.
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
9. No ads, no sponsored cards, no purchase flows, no prices. Never render them even if the source data has them.

## 1. PRINCIPLES
- Content surfaces are flat: no shadow, elevation, glow, glass, blur, gradient or border. The shared app top bar and floating bottom navigation use glass as specified below.
- Separation by spacing and tonal fill, never lines/dividers/cards.
- Content (thumbnails) dominates. Chrome is mostly neutral; the selected bottom navigation icon and label can use primary red as specified below. Red is also used for progress/played, live badge, notification dot and active seek.
- Thumbnails: phone feed = full-bleed 16:9, radius 0. Shelves/search/grid/compact rows = radius 12.
- Text hierarchy by size/weight/opacity only: title 14 w500 onSurface, meta 12 w400 onSurfaceVariant.
- Tap targets >= 48 (visual can be smaller).
- Motion is functional and short (<=300ms). No decorative animation. Respect MediaQuery.disableAnimations.
- Context rule: when a list is already scoped to one channel (channel Videos tab, channel Home), meta MUST omit the channel name.

## 2. TOKENS (define in theme/, names are canonical)

### 2.1 Spacing (AppSpacing)
xxs 2 | xs 4 | sm 8 | md 12 | lg 16 | xl 24 | xxl 32
- screenGutter = md (12) on Home/Subscriptions/Search/Watch.
- listGutter = lg (16) on Channel, Library, History, Playlist, Settings, compact rows.
- Cards text row gutter = md (12).
- feedCardGap = xl (24). shelfCardGap = md (12) (shorts gap sm 8; library history shelf gap lg 16).
- sectionHeaderPad: left md (lg on Library/Channel), top lg, bottom sm.
- iconGap = sm (8) inside buttons.
- glassScrollRange, navSelection: existing glass tokens stay as defined in theme.

### 2.2 Radius (AppRadius)
xs 4 (badges) | sm 8 (chips, small thumbs) | md 12 (thumbs, banners, shorts, compact thumbs) | lg 16 (sheet top, dialogs, featured panel bottom) | pill 999 (buttons, search field, avatar)

### 2.3 Sizes (AppSizes)
touchMin 48 | icon 24 | iconSm 20 | iconXs 16
avatarSm 24 | avatar 36 (feed, search; comments 40) | avatarLg 72 (channel header, library header)
chipHeight 32 | buttonHeight 36 | buttonLarge 40 | topBar 56 | bottomNav 56 (+ safe area)
thumbRatio 16/9 | shortRatio 9/16 (card 2:3 in shelf) | shortShelfCardW 150
trendingCardW 280 | compactThumbW 160 (16:9 => 90 high)
historyCardW 144 (library shelf, 16:9 thumb)
playlistRowThumbW 136 (library list, 16:9)
bannerRatio 3.6 (channel banner width:height), bannerInset 16
badgeIcon 16 | verifiedIcon 20 (channel name) | verifiedIconSm 14 (inline)
seekTrack 3 | seekThumb 12 (touch: 16) | progressBarWatched 3
miniPlayerH 56 (thumb 16:9 left)
moreVideosCardW = 41% of landscape width (fullscreen panel only)

### 2.4 Typography (AppTextStyles) — font: Roboto/system; line heights explicit
| token | size/height | weight | use |
| headline | 24/32 | 600 | channel name, library profile name, shorts description title |
| pageTitle | 20/28 | 600 | top bar titles |
| sectionTitle | 18/24 | 600 | shelf headers |
| statValue | 20/28 | 600 | shorts description stats (likes/views/date) |
| rowTitle | 16/24 | 500 | library playlist rows, bottom-sheet emphasized rows |
| videoTitle | 14/20 | 500 | card titles, list titles |
| body | 14/20 | 400 | descriptions, comments |
| bodyStrong | 14/20 | 500 | names, handles, link rows |
| meta | 12/16 | 400 | views, date, channel line |
| chipLabel | 14/20 | 500 | chips |
| buttonLabel | 14/20 | 500 | buttons |
| tabLabel | 14/20 | 500 | channel tabs (selected onSurface, unselected onSurfaceVariant) |
| badge | 12/16 | 500 | duration, LIVE |
| caption | 11/16 | 400 | shorts views, counts |
| settingsTitle | 16/24 | 400 | settings rows |
| settingsSub | 13/18 | 400 | settings value, row subtitles |
Rule: no inline fontSize/fontWeight in widgets. Always token (.copyWith(color:) only).
Indic scripts (Tamil etc.) wrap taller: layouts MUST tolerate up to 3 title lines in compact rows without overflow.

### 2.5 Color (AppColors; light / dark)
| role | light | dark |
| background/surface | #FFFFFF | #0F0F0F |
| surfaceVariant (chips, fills, banners, search field, description card) | #F2F2F2 | #272727 |
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
| panelScrim (fullscreen More videos) | #000000 @70% | same |
| shimmerBase | #F2F2F2 | #272727 |
| shimmerHighlight | #E6E6E6 | #333333 |
| error | #CC0000 | #FF6B6B |
Rule: ThemeData must set scaffold=background, cardTheme elevation 0, appBar elevation 0, scrolledUnderElevation 0, sheets elevation 0.

### 2.6 Motion tokens (AppMotion)
fast 100ms | base 200ms | slow 300ms | shimmerLoop 1200ms
curves: enter = Curves.easeOutCubic | exit = Curves.easeInCubic | standard = Cubic(0.2, 0, 0, 1)
Rules:
- Press feedback = platform ripple/InkWell only (cards, tiles, icons). Buttons may scale 0.98 over fast.
- Selection change (chip, tab, switch) = color cross-fade base. Floating navigation also slides its selected pill using AppMotion.navSelection.
- Content appearing (image) = FadeIn 150ms. Lists MUST NOT animate item entrance (no staggered/slide-in).
- Sheets/dialogs = platform default.
- Never animate layout size of feed cards.

## 3. GLOBAL LAYOUT
- Root tabs (bottom nav, 4): Home, Shorts, Subscriptions, Library. Search is an icon in the top bar. Settings via Library.
- Bottom nav: centered floating pill, AppSizes.navBarWidth by AppSizes.navHeight, bottom inset safeArea + AppSpacing.sm. Use GlassSurface with theme-dependent translucent fill, blur, border and shadow. The selected cell has a translucent pill fill; selected icon and label are primary red in light theme and on Shorts, white in dark theme. Unselected icon and label use the theme text color at AppColors.navInactiveOpacity, or white on Shorts. Drag horizontally across the pill to select tabs; selection produces haptic feedback. Hide the pill as the watch panel expands, except on Shorts.
- Mini player: floating, draggable, width 55% of screen, 16:9, radius 12, flat (no shadow, no border). Snaps to the 4 corners (default bottom-right), clears the bottom nav and safe area. Tap or swipe up expands the watch panel. Controls: play/pause top-left, close top-right, each 40x40 on a black@60% circle, icon 16 white. 2px primary progress line on the bottom edge. Position persists for the session. Swipe is blocked while dragging.
- Scroll bottom padding on every root screen = bottomNav + safeArea + lg. The floating mini player does not add bottom padding. Applied ONCE (use SliverBottomInset; do not add an extra spacer).
- Status bar: transparent, icon brightness follows theme. Watch fullscreen hides system UI.
- Pull-to-refresh on Home, Subscriptions, Library lists, Channel, Search results (not Shorts, not Watch). Indicator color = onSurface, bg = surface.
- Tab re-tap (tabRefreshProvider): scroll to top first; if already at top, refresh.

## 4. COMPONENTS
Format: USE-WHEN | ANATOMY/SPEC | STATES | MOTION | DON'T

### 4.1 AppTopBar
USE-WHEN: root screens using the shared GlassAppBar. Height AppSizes.appBarHeight plus top inset; Home side pad AppSpacing.md. No elevation.
When a scroll controller is provided, the bar starts transparent and progressively applies the shared GlassSurface blur, theme fill and bottom border over AppSpacing.glassScrollRange. Without a controller it stays transparent. Status-bar icons follow theme brightness.
Home: logo (left) | plain language button | search icon. Reuse HomeTopBar and GlassAppBar; do not duplicate the glass styling.
Subs/History/Playlist/Settings: leading back (if pushed) or title pageTitle; trailing icons 48.
Channel: leading back | spacer | search | more (3-dot). Transparent at top, NOT overlaying the banner (banner sits below the bar). On scroll past the header, channel name (pageTitle) fades in after the back arrow (200ms) and the bar takes the glass fill.
Library: leading ProfileChip (4.26) | spacer | search | settings gear.
DON'T: tonal circles behind top-bar icons, duplicated glass wrappers or non-token glass values.

### 4.2 AppChipBar + AppChip
USE-WHEN: filter row (Home categories, Subscriptions channel filter, History filters, Library filters, channel Videos, fullscreen More videos).
Spec: bar height 48 (chip 32 + vert pad 8), side pad = screen gutter, gap 8, horizontal scroll, no scrollbar, no edge fade/ShaderMask.
Chip: height 32, radius 8, horizontal pad 12, chipLabel. Selected = chipSelectedBg/Fg. Unselected = surfaceVariant bg + onSurface text.
Optional leading icon 16 (e.g. Explore). First chip "All" selected by default.
Dropdown chip (AppChip.dropdown): label + trailing chevron-down 16, gap 4. Tap opens a radio BottomSheet (4.13). Shows the current value as label (e.g. "Latest", "Recent"). Selected styling applies (inverse fill) when it is the active filter group.
STATES: default, selected, pressed (ripple).
MOTION: bg/fg cross-fade base. No scale, no slide.
BEHAVIOR: selecting calls controller.select(chip); keep scroll position of bar; selected chip scrolled into view with 200ms ease.
DON'T: pill radius, border, shadow, elevation.

### 4.3 ThumbnailWithDuration
Spec: AspectRatio 16/9, fill, placeholder=surfaceVariant flat (no spinner), CachedNetworkImage memCacheWidth = displayWidth*DPR, fadeIn 150ms.
Radius param: 0 (feed phone) | md (all others).
Duration badge: bottom-right, inset 4, bg badgeBg, text badge, radius xs 4, pad h4 v2. In compact/history thumbs the badge MUST NOT hide title-relevant content: keep inset 4.
Live: badge red bg, text "LIVE", same position. Upcoming: "UPCOMING" dark badge.
Watched progress: bottom edge, height 3, track white@30%, fill primary, full width of thumb (clipped by the thumb radius). Only if progress != null.
DON'T: overlay gradient on thumbs, play icon overlay, shadow.

### 4.4 ChannelAvatar
Circle, sizes avatarSm/avatar/avatarLg. Placeholder: surfaceVariant circle with first letter of name (onSurfaceVariant, bodyStrong). Image fade 150ms. No border. Tap => /channel/:id when channelId non-empty.
PERF: avatar url resolved via per-channel provider (family). Avatar load MUST NOT rebuild the parent list.

### 4.5 VideoCard (single widget, modes)
Fields: VideoItem {id,title,channelId,channelName,channelAvatarUrl,thumbUrl,durationText,viewsText,publishedText,isShort,progress?}.
Meta string = [channelName, viewsText, publishedText].where(nonEmpty).join(' · '). When `hideChannel` is true (channel-scoped lists) channelName is dropped.
Wrap each card in RepaintBoundary. ValueKey(video.id) at list level.

MODE feed (Home, Subscriptions, Watch-related-on-phone full):
- Thumb full-bleed 16:9 radius 0.
- Text row: padding L12 R4 T12 B0. Row: avatar 36 | 12 | Column(Expanded: title videoTitle max2, 2px gap, meta max2) | 3-dot 40x40 (icon 20, visualDensity compact).
- Card bottom margin 24 (between cards).
- Tap card => openWatchPanel(ref, id). Avatar tap => channel. 3-dot => video options sheet.
MODE grid / shelf (Trending, rounded): thumb radius 12, width per shelf (trending 280). Text row no avatar optional; padding L0 T8; title 14 max2; meta 12 max1-2. 3-dot 24 trailing.
MODE searchResult (Search): stacked. Thumb inset 12 each side, radius 12. Gap 12. Row padding 0 12: avatar 36 | 12 | title+meta | 3-dot. Bottom margin 16.
MODE compact (Channel videos, Playlist rows, History, Watch related list): row, padding v8 h16 (listGutter). Thumb 160x90 radius 12 (left) | 16 | Column(title videoTitle max3, meta 12 max1) | 3-dot 40 top-aligned with the first title line. Row min height 106. Duration badge on thumb. Title aligns to the thumb top edge.
MODE featured (channel Home top card): thumb full-bleed 16:9 radius 0. Below it an info panel: background = thumb dominant color @20% over surface (flat tint, computed once per thumb and cached), bottom corners radius 16, padding L16 T12 R4 B16. Row: avatar 36 | 12 | title videoTitle max2 + meta (channel, views with leading play-outline icon 12, time; separated by gap 8, no dot) | 3-dot 40. Margin below 24.
STATES: pressed ripple on whole card (InkWell, no radius on feed), watched (progress bar only; do not dim).
DON'T: elevation, border, shadow, Card() widget, divider between cards.

### 4.6 SectionHeader
Row: [leading icon 24 optional] [sectionTitle] [chevron-right 24 OR trailing text button]. Padding L12 R4 T16 B8 (L16 on Library/Channel).
Variants: linked (title + chevron-right right after the title, whole row tappable; used for Library "History >", channel Home "Videos >") | plain (title only, e.g. Library "Library") | action (title, spacer, "View all" bodyStrong).

### 4.7 ShortsShelf + ShortCard
Header: Shorts icon 24 + "Shorts" sectionTitle. Placement: in Home feed after 4th video (index 4). Exactly one shelf per feed page.
Horizontal list height = cardW*1.5 (150x225), side pad 12, gap 8.
ShortCard: radius 12 clip, thumb cover. Bottom scrim (transparent -> black@60%, 40% of height). Title bottom-left (pad 8) white 13 w500 max2; views caption below. 3-dot top-right white icon 20, no bg.
Tap => shortsSelectionProvider.open(items,index); context.go('/shorts'); close watch panel first if open.

### 4.8 AppButton
Variants: filled (bg onSurface, fg surface) | tonal (surfaceVariant bg, onSurface fg) | text | outlined (1px outlineVariant, last resort) | destructive (primary bg).
Height 36 (large 40), pill radius, h pad 16, buttonLabel, icon 20 + gap 8.
Subscribe: filled (inverse). Subscribed: tonal + bell icon + chevron-down. Never red.
Equal-width pair: two buttons in a Row, each Expanded, gap 8 (Library header). Content-width trio: Row, gap 8, horizontal scroll if overflow (channel header).
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

### 4.13 BottomSheet (options menu, select dialogs)
Top radius 16, bg surface (dark: #212121), drag handle 32x4 radius 2 onSurfaceVariant@40% centered top pad 8. Rows 56 high: icon 24 + 24 gap + label settingsTitle. Selection list: radio on right. No elevation, scrim black@50%.
Sheet max width 480, centered, bottom-anchored.
Video options: Add to queue, Save to playlist, Save to watch later, Download, Share, Not interested.
Sort/filter dropdown sheets (Latest/Popular/Oldest, Recent/A-Z/Recently added): radio rows, auto-close 150ms after tap.

### 4.14 Dialog / Snackbar
Dialog radius 16, title pageTitle 18/24 w500, actions text buttons right. No elevation.
Snackbar: floating, margin 12, bg #323232 (light) / #F1F1F1 text dark (inverse), radius 8, text 14, single text action. 4s. Sits above mini player+nav.

### 4.15 InlineBanner
Row: surfaceVariant bg, radius 12, margin 12, pad 12, text 13 onSurface, trailing text button "Retry". Use for partial failures (e.g., some sources failed) while content is still shown. One banner max per screen.

### 4.16 EmptyState / ErrorRetry
Centered column: icon 48 onSurfaceVariant, 16 gap, title 16 w500, 8 gap, subtitle 14 onSurfaceVariant (max 2 lines), 24 gap, one AppButton.tonal. No illustrations. Fills remaining viewport (SliverFillRemaining).
Compact variant (inside a shelf area): icon 32, title + subtitle only, no button, height 160.

### 4.17 Skeletons
Match real layout exactly (same sizes/radius/margins). Flat blocks shimmerBase, highlight sweep ltr, 1200ms linear loop, single shared AnimationController per skeleton screen.
FeedSkeleton: repeat [16:9 block full-bleed; row pad L12 T12: circle 36 | 12 | bar 14h 90% width, bar 12h 60% width, 2px gaps]; gap 24; count fill viewport + 1.
Shelf skeleton: header bar + cards. Compact skeleton: 160x90 radius 12 + 2 bars (16 gap, pad h16 v8). ChannelHeader skeleton: banner block (bannerRatio, inset 16, radius 12) + circle 72 + 3 bars + pill row (3 blocks 40h) + tab bar bars.
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
Fullscreen controls (landscape):
- Top: title and channel, Autoplay, captions when available, and Settings.
- Center: Previous, Play/Pause/Replay, Next; unavailable Previous/Next are dimmed.
- Bottom: seek bar, time chip, fullscreen exit, and "More videos" / "Play next" action when Next exists. "More videos" opens MoreVideosPanel (4.25).
- Keep the flat scrim, double-tap seek, long-press 2x, brightness/volume drag, lock, system-back exit, and swipe-down exit.
Settings sheet rows: Quality (max 1080p), Playback speed, Captions, Audio only, Loop.

### 4.21 SeekBar
Track 3px, rounded. Colors: played primary, buffered white@50%, remaining white@30%. Thumb: hidden at rest (when overlay shown it is 12 primary dot), 16 while dragging. Drag shows time bubble above thumb (badge style) and, if available, chapter title. Scrubbing MUST NOT trigger rebuild of the whole player (use ValueListenable).
Mini player progress: 2px primary line, no thumb.

### 4.22 CommentTile
Row pad h12 v8: avatar 40 | 12 | Column: [@handle meta 12 bold + · time meta], text body (max 6 lines + "Read more"), action row [thumbUp 20 + count, thumbDown 20, reply "Reply" meta bold]. Replies collapsed under "N replies" (onSurface bodyStrong with chevron). Pinned badge: small tonal pill.

### 4.23 StackedCover + PlaylistCard + PlaylistRow
StackedCover (shared): 16:9 thumb radius 12 with ONE flat bar peeking above it: inset 10 each side, peek 8, top radius 8, color onSurface@16%. Overlay badge bottom-right inside the thumb: 32 circle black@60% with icon 16 white (thumbs-up for Liked videos, clock for Watch later, list icon + count for user playlists). No shadow.
PlaylistCard (channel Playlists tab grid, shelves): width fills the 2-col cell (gap 12). StackedCover, then title videoTitle max2, meta "Updated X ago" 12.
PlaylistRow (Library list): padding v8 h16. StackedCover width playlistRowThumbW (136) | 16 | Column(title rowTitle max2, meta settingsSub: "Private" / "N videos") | 3-dot 40 (top-aligned center). Row min height 96 (peek included). Tap => /playlist/:id (or /history-like built-ins: Liked, Watch later, Downloads).

### 4.24 ChannelHeader
Order top to bottom (screen gutter 16):
1. Banner: margin h16, ratio bannerRatio, radius 12, cover fit. Hidden entirely (no placeholder gap) if the channel has none. Sits below the top bar (top bar does not overlay it).
2. Identity row (pad T16): avatar 72 | 16 | Column: name headline + verified badge (check-circle icon verifiedIcon, onSurface) inline when verified; "@handle" bodyStrong? NO: handle meta onSurfaceVariant 14 (use body, onSurfaceVariant); "2.11m subscribers · 309 videos" meta onSurfaceVariant (use body size 14 onSurfaceVariant).
3. Description: 1 line (body, onSurfaceVariant) + inline "...more" bodyStrong onSurface. Tap => About tab. Padding T12.
4. Links row (when links exist): link icon 16 + "Instagram and 2 more links" bodyStrong onSurface. Tap => links sheet (radio-less list, tap opens browser). Padding T8.
5. Action pills row (pad T16, gap 8, height buttonLarge 40): Subscribe (filled; subscribed state = tonal + bell + chevron-down) | Join (tonal, star icon 20, only if the channel has memberships; opens the channel page in the external browser; MUST NOT show price/offer text) | Community (tonal, community icon 20, only if the Posts tab exists; switches to Posts tab). Row scrolls horizontally if it overflows; no scrollbar.
6. Tab bar: sticky under the top bar. Tabs: Home, Videos, Shorts, Playlists, Posts (Posts only if the channel has posts; About is reached via description tap or the more menu). tabLabel, horizontal scroll, tab horizontal pad 12, tab spacing 0, selected indicator 2px onSurface under the label (full tab width), indicator slide 200ms.
Subscribe behavior: optimistic toggle; notification sheet when subscribed bell tapped.

### 4.25 MoreVideosPanel (fullscreen landscape only)
Opens from fullscreen controls. Overlay over the paused-dim player (panelScrim). Layout: header row pad L24 R24 T16: "More videos" (pageTitle, white) | spacer | close X 24 (touch 48). Below: AppChipBar (All, Comedy, Related, For you, Live, Recently uploaded, Watched; chips on dark: unselected white@12% bg, selected white bg black text). Below: horizontal list of cards: width moreVideosCardW, gap 16, pad L24. Card: thumb 16:9 radius 12 with duration badge; text row below: avatar 36 | 12 | title (white, videoTitle max2) + meta (white@70%) | 3-dot white. No ad cards. Tap card => play it, panel closes. Back or X closes the panel and returns to controls.

### 4.26 ProfileChip + ProfileSheet (Library)
ProfileChip: tonal pill, height 40, label "Profile" (or local profile name if set) + chevron-down 16. In the Library top bar leading slot.
ProfileSheet (BottomSheet 4.13): rows: Edit profile, Stats, Backup & restore. No account switching (local profile only).

### 4.27 DescriptionSheet (Shorts and Watch)
Draggable bottom sheet (snap 60% of screen, expands to 100%, drag down or X closes). Top radius 16, handle 32x4. Content:
- Header row pad L16 R8 T16: title headline max 4 lines | close X 24 (touch 48).
- Channel row pad T16: avatar 36 | 12 | channel name bodyStrong (original case). Tap => channel.
- Stats row (pad T24, 3 equal columns, centered): statValue + meta label: "97k / Likes", "3.7m / Views", "10 Nov / 2026". Compact numbers (k/m).
- Description card (pad T24 h16): surfaceVariant bg, radius 12, pad 16, body text, max 8 lines then inline "...more" bodyStrong. Tap => expands the card in place (sheet scrolls). Hashtags and links tappable; timestamps seek.
On Shorts: the short video shrinks (contain fit) into the area above the sheet and keeps playing; it restores full height on close.

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
 1. Title: videoTitle but 16/22 w500, max 2 lines, tap opens DescriptionSheet (4.27). Meta below: "1.2M views · 3 days ago" meta + "...more".
 2. Channel row: avatar 36 | name bodyStrong + subscribers meta | AppSubscribedButton (right).
 3. ActionRow (4.11).
 4. Comments teaser: surfaceVariant rounded 12 card (flat) pad 12: "Comments N" bodyStrong + top comment preview 1-2 lines + avatar 24. Tap => comments sheet (draggable, snap 60%/100%).
 5. Related: VideoCard feed mode list (phone). Loading more on scroll.
Description: DescriptionSheet (4.27) is the single description UI. Show full text, links tappable, hashtags bodyStrong, chapters list tappable (seek).
Minimize: vertical drag on player; panel collapses to MiniPlayer; audio continues (background play + media notification). Close removes session.
Fullscreen: rotate or button; controls 4.20; More videos 4.25. Exit restores portrait panel.
Audio-only mode: toggle in player settings sheet. Video surface replaced by thumbnail; mode switch keeps position.
States: loading=player black 16:9 with centered spinner + below skeleton (title bars, channel row, actions) | error (stream fail)=in-player centered "Playback error" + Retry text button | unavailable video=message in place of player.
Behavior extras: SponsorBlock auto-skip segments with snackbar "Skipped sponsor" + Undo; RYD dislike count; resume position from history; autoplay next from related (setting); history entry saved on play.
Motion: expand/collapse follows drag 1:1, settle slow 300ms easeOutCubic; content below fades in 150ms once player expanded.

### 5.4 SHORTS (/shorts, tab 1)
Full-screen vertical PageView (snap, physics clamping), black bg, system bars transparent. No top bar except overlay.
Per page: video cover-fit 9:16, tap = play/pause (brief center icon 56 fade 200ms), long-press = pause (resume on release), double-tap = like (heart burst 400ms, optional).
Overlays: right rail (bottom 96 from edge, x pad 12), vertical gap 20: like (thumbUp 28 + count caption), dislike (thumbDown 28 + "Dislike"), comments (28 + count), share (28 + "Share"), more (3-dot).
Bottom-left (pad L12 B16, max width 75%): row avatar 32 | @channel bodyStrong white | Subscribe pill (filled white bg black text, height 32); below: title 14 white max2. Tapping the title or choosing "Description" in more => DescriptionSheet (4.27). Bottom gradient scrim black@50% 30% height (allowed here).
Top-left: back/close if pushed via home shelf; top-right: search + more 48 white.
Progress: 2px line at very bottom, primary, no thumb, scrubbable on drag (optional).
Behavior: preload next 1 page; pause when page not visible/app backgrounded; loop video; autoplay on page settle; mute state persistent. Shorts are never written to watch history.
States: loading=black + centered spinner | error=black + "Couldn't load Shorts" + Retry | end=stay on last.
Motion: page snap slow 300ms easeOutCubic; rail icons fade-in 150ms; like toggle = icon fill swap + scale 1.0->1.2->1.0 150ms.

### 5.5 CHANNEL (/channel/:id)
Top bar: 4.1 Channel variant. Body: ChannelHeader (4.24) -> pinned tabs.
Header scrolls away with the content; tabs pin under the glass top bar.
 - Home: featured VideoCard (featured mode: latest/featured video) -> SectionHeader linked "Videos >" (tap => Videos tab) -> VideoCard compact rows (hideChannel, latest 5) -> Shorts shelf (if any) -> Playlists shelf (PlaylistCard, horizontal, width 160) (if any).
 - Videos: ChipBar: AppChip.dropdown (Latest | Popular | Oldest), "Members only", "Public" (Members only / Public chips shown only when the channel has members content; otherwise just the dropdown). Then VideoCard compact list (hideChannel). Continuation scroll.
 - Shorts: 3-col grid, ratio 2:3 gap 4, radius 8, views caption bottom-left white on scrim.
 - Playlists: 2-col grid of PlaylistCard, gap 12, pad h16.
 - Posts: list of text posts (avatar 36 + name bodyStrong + time meta; body text max 8 lines + "Read more"; image radius 12 if any; like count meta). Tab hidden when the channel has no posts.
 - About: description text, links, joined date, location, view count, stats as 2-line rows (settingsTitle + settingsSub).
States: loading=ChannelHeader skeleton + tab body skeleton | error=ErrorRetry | empty tab=EmptyState ("This channel has no videos").
Behavior: subscribe toggles local subscription + optimistic UI; notification bell sheet (All/Personalized/None) when subscribed.

### 5.6 LIBRARY (tab 3, "You")
Library gutter = 16, applies to the header, shelves, rows.
Layout top->bottom:
 1. Top bar: ProfileChip (4.26) | spacer | search | settings gear.
 2. Header pad L16 R16 T8: avatar 72 (local profile) | 16 | Column(name headline, "N videos watched · M playlists" meta onSurfaceVariant).
 3. Button pair pad T12 h16: Row of two Expanded AppButton large (height 40), gap 8: "Edit profile" (filled) | "Backup" (tonal).
 4. History shelf: SectionHeader linked "History >" (tap => /history). Horizontal list pad L16, gap 16, card width historyCardW (144): thumb 16:9 radius 12 with duration badge + progress bar; below pad T8: title videoTitle max2 + 3-dot 24 trailing, meta 12 max1 (channel name). Empty: EmptyState compact ("Videos you watch will show here").
 5. SectionHeader plain "Library" (sectionTitle).
 6. Chip row (AppChipBar, pad L16): AppChip.dropdown "Recent" (sort sheet: Recent, A–Z, Recently added) | "Downloaded" | "Playlists" (filter chips, toggle; none selected = show all).
 7. PlaylistRow list (4.23): built-ins first (Liked videos, Watch later, Downloads when files exist), then user playlists per sort. Each row has a 3-dot menu (Play all, Share, Delete for user playlists). Empty (no user playlists): one PlaylistRow-style row "New playlist" with plus icon in the cover slot.
States: loading=header skeleton + shelf/list skeletons | each section has its own empty (never one global empty).
Behavior: Backup opens bottom sheet: Export to file / Import from file (+ Takeout import). Edit profile opens bottom sheet with avatar picker + name field (text field style: surfaceVariant fill, radius 12, no border). Stats lives in ProfileSheet. Pull-to-refresh refreshes shelves.

### 5.7 SETTINGS (pushed from Library gear)
Plain full-width list, no cards, no dividers, no shadow. TopBar pageTitle "Settings", back.
Groups (header style 4.12): General | Playback | Privacy & data | Integrations | About.
 General: Content language (value: "Tamil, English") -> language sheet; Theme (System/Light/Dark) -> radio sheet; Home content mix (local ratio) -> slider sheet or radio.
 Playback: Max video quality (value "1080p") -> radio sheet; Autoplay (Switch); Background play (Switch); Playback speed default -> radio sheet; Audio only by default (Switch).
 Privacy & data: Pause watch history (Switch); Clear watch history (confirm dialog); Clear search history (confirm dialog); Backup & restore -> sheet; Clear cache (value size).
 Integrations: SponsorBlock (Switch + subtitle categories -> sheet); Return YouTube Dislike (Switch); Captions default language -> sheet.
 About: Version, Check for updates, Licenses, Source/Feedback links.
Row: min 56; leading 24 icon; Switch = native, themed (selected track primary@50%, thumb primary).
Selecting radio option = apply immediately, sheet auto-closes 150ms after tap.
Destructive confirm: dialog title "Clear watch history?" body one line, actions Cancel (text) / Clear (text, primary color allowed).
States: none (static). Changed values reflect immediately in subtitle.

### 5.8 SUBSCRIPTIONS (tab 2)
Top: TopBar title "Subscriptions" | search 48 | manage ("Manage" text button).
Row 1: horizontal channel avatar strip: avatar 56 + name 12 max1 centered, width 72, gap 4, pad L12; first item "All" chip-like; unread new-video dot (8 primary) top-right of avatar. Tap avatar = filter feed to channel (selected: bold name only, no ring).
Row 2: ChipBar (All, Today, Videos, Shorts, Live, Continue watching) optional.
Feed: VideoCard feed mode, sorted by publishedAt desc (RSS merged; fallback to channel videos tab when RSS empty/404). Group headers by "Today / This week / This month" (sectionTitle) — flat, optional.
Manage (/subscriptions/manage): list rows: avatar 40 | name bodyStrong + meta | bell icon button 48 (opens notification sheet) | Unsubscribe via row menu. Import from Takeout CSV in top bar menu. Search channels field at top (SearchField small).
States: loading=skeleton strip + FeedSkeleton | empty (no subs)=EmptyState("No subscriptions yet" , "Subscribe to channels to see their videos here", button "Find channels"->search) | error=ErrorRetry | partial=InlineBanner.

### 5.9 HISTORY (/history)
TopBar: back, title "History", search 48 (filter local), more (Clear all, Pause history).
Body: grouped by day: header sectionTitle (pad L16 T16 B8: "Today", "Yesterday", "Mon, Nov 10"); rows = VideoCard compact (listGutter 16, thumb 160x90 radius 12) with watched progress bar; trailing 3-dot (Remove from history, Add to playlist, Share).
Swipe to dismiss row = remove (snackbar "Removed from history" + Undo).
Shorts are not in history (never saved). isShort is not persisted. All entries render as compact rows.
States: loading=compact skeletons | empty=EmptyState("No watch history", "Videos you watch will appear here") | paused banner (InlineBanner "Watch history is paused", action "Turn on").
Perf: paged from DB (limit 50, load more at end), grouped lazily.

### 5.10 PLAYLIST (/playlist/:id)
Header (not sliver-pinned): cover = first video thumb 16:9 radius 12 margin 16; below: title headline? NO: title pageTitle (editable inline if local), meta "N videos · Updated X · Private"; action row: Play all (filled pill, play icon), Shuffle (tonal pill), Download (icon), Share (icon), More.
List: VideoCard compact rows (listGutter 16), reorder via drag handle (local playlists, long-press to drag, handle icon 24 right), index number leading 24 meta optional.
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
- Images: CachedNetworkImage with memCacheWidth/maxWidthDiskCache = logical width * DPR; low-res placeholder = flat color; fadeInDuration 150ms; never decode full-size for thumbs. Banner/avatars follow the same rule.
- Featured-panel dominant color: compute once per thumb URL off the UI thread, cache in memory; fall back to surfaceVariant while pending.
- Provider reads: use ref.watch(provider.select(...)); parent lists MUST NOT watch per-item data (avatars, progress, like state). Per-item data via family providers inside the item.
- Avatar/metadata backfill: batch or family provider; one state update does not rebuild the list.
- Scrubbing, progress, timers: ValueListenable/stream scoped to the smallest widget.
- Skeleton: one AnimationController per screen, shared via inherited shimmer.
- Const constructors everywhere possible. No setState on screen root for chip selection if provider holds it.
- Debounce search 250ms; cancel in-flight (CancelToken).
- Large lists must paginate (history 50/page, search/continuations, subscriptions merged lazily).
- Audio-only mode: no video decode or download while on.

## 8. ANTI-PATTERNS (grep = 0)
BoxShadow (except floating navigation) | elevation: (non-zero) | Card( | GlassSurface (allowed in lib/widgets/floating_nav.dart and lib/widgets/home_top_bar.dart) | BackdropFilter / ImageFilter.blur (GlassSurface implementation only) | ShaderMask | Divider( in feeds/settings | BorderSide (except shared app top bar glass and outlined AppButton, text field focus none) | gradient (except shorts/player scrim) | fontSize: (inline) | Color(0x / Colors. (inline) | EdgeInsets with raw numbers (use AppSpacing) | SizedBox(height: <number>) raw | borderRadius: BorderRadius.circular(<number>) raw
Behavior bans: staggered list entrance animation, bouncing/elastic curves, parallax, auto-playing previews in Home feed, blocking spinners on first load, snackbar for non-actionable info, multiple error rows, emoji in UI chrome, ads/sponsored cards/prices, writing Shorts to history.

## 9. USECASE -> COMPONENT QUICK MAP
| need | use |
| show a video in a vertical feed | VideoCard.feed |
| video in horizontal shelf | VideoCard.grid/shelf (rounded, width fixed) |
| video in search | VideoCard.searchResult |
| dense list of videos (history, playlist, channel videos, related) | VideoCard.compact |
| top featured video on channel Home | VideoCard.featured |
| filter by category | AppChipBar + AppChip |
| sort/filter menu on a chip | AppChip.dropdown + radio BottomSheet |
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
| section with more | SectionHeader (linked or action) + horizontal list |
| user/channel picture | ChannelAvatar |
| playlist in a list | PlaylistRow (Library) / PlaylistCard (grid) |
| video/short details | DescriptionSheet |
| fullscreen related videos | MoreVideosPanel |
| profile actions | ProfileChip + ProfileSheet |

## 10. DEFINITION OF DONE (UI TASK)
1. Uses only components from section 4; no new duplicate widgets.
2. Tokens only; light + dark verified by theme usage (no hardcoded colors).
3. All states from section 6 implemented.
4. Bottom inset applied once; mini player overlap handled.
5. Section 8 grep clean; `dart analyze` clean; `flutter test` passes.
6. Behavior unchanged unless the task says so.
7. Final reply = one line: files changed | grep hits | analyze | tests.
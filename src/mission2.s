*----------------------------------------------------------
* Mission 2 — Level data (STUB for multi-mission boot).
*
* Loaded into bank $02 when current_mission = 2. Minimal scaffold
* so the boot completes and init_level's bank-$02 reads don't
* fault. NO actual gameplay content yet: empty sprite table,
* trivial level script (immediate OP_END), placeholder bounds /
* ladders / strata. Real mission-2 content lands in follow-on
* passes.
*
* Header layout mirrors mission1.s exactly so the engine reads
* the same offsets.
*----------------------------------------------------------
    org $020000

; Just enough opcodes for the trivial script.
OP_WAITX EQU 2
OP_RIGHT EQU 4         ; connect to right screen + enable right scroll
OP_DOWN  EQU 7         ; descend into below-screen content via ladder
OP_SCRLOCK EQU 8       ; lock all scrolling in the current view
OP_SCRMAX  EQU 15      ; set maximum world_offset (right-scroll clamp)
OP_END   EQU 9
OP_BOUNDS EQU 21       ; rewrite stratum bounds to one walkable row
OP_SCROLLSRC EQU 22    ; set scroll_src_off directly (post-OP_RIGHT)
OP_SCROLLSPLIT EQU 23  ; vertical-split right-scroll source (upper bank, split row)
OP_LADDER EQU 24       ; install a single ladder + enable scroll_up
OP_PLATFORM EQU 25     ; add ONE walkable row to bounds (no clear)
OP_UPSPLIT EQU 26      ; add a scrolling up-ladder + split-bank up-target
OP_ALADDER EQU 27      ; append an extra scroll-segment ladder (zig-zag
                       ; climbs; must precede the OP_UPSPLIT)
OP_SRCWO   EQU 28      ; scroll_src_off = world_offset (run-invariant
                       ; art placement; see game.s opcode table)

*==========================================================
* Level header — same field layout as mission1.s.
*==========================================================
level_header
num_screens    dfb 10          ; 10 backgrounds packed in /MISSION2/
initial_screen dfb 0
player_spawn_x dfb $20         ; on the platform, near its left edge
player_spawn_y dfb $51         ; 81 — upper-platform row (see bounds_scr0)
manifest_off   dw level_manifest
sprite_tbl_off dw sprite_table
sprite_dat_off dw $0000
mask_dat_off   dw $0000
anim_desc_off  dw anim_descs
level_scr_off  dw level_script
npc_scr_off    dw $0000
spr_addr_off   dw spr_addr_tbl
bounds_ptr_off dw bounds_ptrs
ladder_ptr_off dw ladders
strata_idx_off dw strata_index
s2s_off        dw screen_to_stratum
level_flags    dfb $01         ; +$1C — bit 0 = gravity enabled for platformer
ph_pad         dfb 0           ; +$1D pad

*-------------------------------
* Sprite-address table — Billy slots point at the PUT'd shared
* player_sprites.s labels; NPC slots are zeroed because mission 2
* doesn't ship NPC pixel data in bank $02. Layout mirrors
* mission1.s's spr_addr_tbl so init_level reads the same indices.
*-------------------------------
spr_addr_tbl
spr_image01    dw IMAGE01
spr_image02    dw IMAGE02
spr_image03    dw IMAGE03
spr_jump1      dw JUMP1
spr_jump2      dw JUMP2
spr_jump3      dw JUMP3
spr_kick1      dw KICK1
spr_kick2      dw KICK2
spr_punch11    dw PUNCH11
spr_punch12    dw PUNCH12
spr_punch21    dw PUNCH21
spr_punch22    dw PUNCH22
spr_bpunched   dw BPUNCHED
spr_william1   dw 0
spr_wpunched   dw 0
spr_wfall      dw 0
spr_wfallen    dw 0
spr_william2   dw 0
spr_william3   dw 0
spr_wpunch1    dw 0
spr_wpunch2    dw 0
spr_roper1     dw 0
spr_roper2     dw 0
spr_roper3     dw 0
spr_rpunch1    dw 0
spr_rpunch2    dw 0
spr_rpunched   dw 0
spr_rfall1     dw 0
spr_rfall2     dw 0
spr_linda1     dw 0
spr_linda2     dw 0
spr_linda3     dw 0
spr_lpunch1    dw 0
spr_lpunch2    dw 0
spr_lpunched   dw 0
spr_lfall1     dw 0
spr_lfall2     dw 0
spr_pointright dw 0       ; HUD overlay still in mission1.s — TBD share
spr_pointup    dw 0       ; mission 2 will need OP_UP eventually;
                          ; leave the up-arrow slot clear so the
                          ; future POINT_UP load doesn't collide.
spr_bclimb1    dw BCLIMB1
spr_bclimb2    dw BCLIMB2
spr_lclimb1    dw 0
spr_lclimb2    dw 0
* Compiled-sprite extras (compiled AND/ORA pipeline).
spr_pointright_mask         dw 0
spr_pointright_data_mirror  dw 0
spr_pointright_mask_mirror  dw 0
spr_pointup_mask            dw 0
spr_pointup_data_mirror     dw 0
spr_pointup_mask_mirror     dw 0
spr_image01_mask            dw IMAGE01_MASK
spr_image01_data_mirror     dw IMAGE01_DATA_MIRROR
spr_image01_mask_mirror     dw IMAGE01_MASK_MIRROR
spr_image02_mask            dw IMAGE02_MASK
spr_image02_data_mirror     dw IMAGE02_DATA_MIRROR
spr_image02_mask_mirror     dw IMAGE02_MASK_MIRROR
spr_image03_mask            dw IMAGE03_MASK
spr_image03_data_mirror     dw IMAGE03_DATA_MIRROR
spr_image03_mask_mirror     dw IMAGE03_MASK_MIRROR
spr_bclimb1_mask            dw BCLIMB1_MASK
spr_bclimb1_data_mirror     dw BCLIMB1_DATA_MIRROR
spr_bclimb1_mask_mirror     dw BCLIMB1_MASK_MIRROR
spr_bclimb2_mask            dw BCLIMB2_MASK
spr_bclimb2_data_mirror     dw BCLIMB2_DATA_MIRROR
spr_bclimb2_mask_mirror     dw BCLIMB2_MASK_MIRROR
spr_punch11_mask            dw PUNCH11_MASK
spr_punch11_data_mirror     dw PUNCH11_DATA_MIRROR
spr_punch11_mask_mirror     dw PUNCH11_MASK_MIRROR
spr_punch12_mask            dw PUNCH12_MASK
spr_punch12_data_mirror     dw PUNCH12_DATA_MIRROR
spr_punch12_mask_mirror     dw PUNCH12_MASK_MIRROR
spr_punch21_mask            dw PUNCH21_MASK
spr_punch21_data_mirror     dw PUNCH21_DATA_MIRROR
spr_punch21_mask_mirror     dw PUNCH21_MASK_MIRROR
spr_punch22_mask            dw PUNCH22_MASK
spr_punch22_data_mirror     dw PUNCH22_DATA_MIRROR
spr_punch22_mask_mirror     dw PUNCH22_MASK_MIRROR
spr_kick1_mask              dw KICK1_MASK
spr_kick1_data_mirror       dw KICK1_DATA_MIRROR
spr_kick1_mask_mirror       dw KICK1_MASK_MIRROR
spr_kick2_mask              dw KICK2_MASK
spr_kick2_data_mirror       dw KICK2_DATA_MIRROR
spr_kick2_mask_mirror       dw KICK2_MASK_MIRROR
spr_jump1_mask              dw JUMP1_MASK
spr_jump1_data_mirror       dw JUMP1_DATA_MIRROR
spr_jump1_mask_mirror       dw JUMP1_MASK_MIRROR
spr_jump2_mask              dw JUMP2_MASK
spr_jump2_data_mirror       dw JUMP2_DATA_MIRROR
spr_jump2_mask_mirror       dw JUMP2_MASK_MIRROR
spr_jump3_mask              dw JUMP3_MASK
spr_jump3_data_mirror       dw JUMP3_DATA_MIRROR
spr_jump3_mask_mirror       dw JUMP3_MASK_MIRROR
spr_bpunched_mask           dw BPUNCHED_MASK
spr_bpunched_data_mirror    dw BPUNCHED_DATA_MIRROR
spr_bpunched_mask_mirror    dw BPUNCHED_MASK_MIRROR
* William somersault / NPC-grab / held targets — no NPCs in mission 2.
spr_wsomer1   dw 0
spr_wsomer2   dw 0
spr_wsomer3   dw 0
spr_bupper1   dw BUPPER1
spr_bupper2   dw BUPPER2
spr_bupper3   dw BUPPER3
spr_bgrab1    dw BGRAB1
spr_bgrab2    dw BGRAB2
spr_wheld1    dw 0
spr_wheld2    dw 0
spr_rheld1    dw 0
spr_rheld2    dw 0
spr_lheld1    dw 0
spr_lheld2    dw 0
spr_bspin1    dw BSPIN1
spr_bspin2    dw BSPIN2
spr_bspin3    dw BSPIN3

* POINT_DOWN (offsets +256..+262). Filled with the vertically-
* flipped POINT_UP data defined below. OP_DOWN's overlay reads
* spr_pointdown to know what sprite to render.
              dw 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0      ; +222..+254 filler
spr_pointdown          dw POINT_DOWN_DATA
spr_pointdown_mask     dw POINT_DOWN_MASK
spr_pointdown_data_mirror dw POINT_DOWN_DATA_MIRROR
spr_pointdown_mask_mirror dw POINT_DOWN_MASK_MIRROR

*-------------------------------
* Sprite table — empty (just the null terminator the engine
* iteration loops look for).
*-------------------------------
sprite_table
 dw 0

*-------------------------------
* Animation descriptors — empty.
*-------------------------------
anim_descs
 dw 0

*-------------------------------
* Level script — gate OP_END behind an impossible OP_WAITX so the
* player can hear the music and walk back and forth on the
* platform indefinitely. Platform extends to x=149; threshold of
* 400 (abs_x) is unreachable until level/screen scrolling exists.
*-------------------------------
level_script
* OP_RIGHT,1 enables scroll into screen 1's BG art (MISSION22 at
* bank $04). After Billy walks/scrolls past abs_x=200 (somewhere
* on the lower platform), OP_DOWN fires to descend into screen 4
* (mission25). Phase 2 of the OP_DOWN implementation: single-bank
* down scroll (no left/right split yet). When the engine routine
* completes, scroll_down_enabled clears and the script resumes.
 db OP_RIGHT,1
 db OP_WAITX
 dw 100                    ; lowered from 200 so OP_DOWN fires near
                           ; the ladder column (world_x=107)
 db OP_DOWN,4,5,110,7,8,180,40
                           ; Layer 1: scr4/scr5 (mission25/26),
                           ; split at world byte 110, snap_at=180.
                           ; Layer 2 (chained): scr7/scr8
                           ; (mission28/29), snap_at=40. The art's
                           ; platform sits ~16px above mission28's
                           ; bottom; stopping at 40 (= 56 - 16) lines
                           ; that row up with Billy's feet at ypos=128.
* Post-descent platform. OP_DOWN's snap (chain-less) cleared
* scroll_down_enabled, is_climbing, and ladder_count. Billy is
* now standing at ypos=128. Pin walkable bounds to that single
* row across the full currently-visible playfield (world bytes
* 20..129) so he can walk left/right on the mission28/29 floor.
 db OP_BOUNDS,130
 dw 20                     ; span1 x_lo
 dw 155                    ; span1 x_hi (extended +2 bytes).
 dw 167                    ; span2 x_lo (moved -2 bytes to narrow the
                           ; gap; world 156..166 = 11-byte gap).
 dw 218                    ; span2 x_hi.
                           ; y=130 = post-descent ypos. OP_BOUNDS also
                           ; sets billy_sprite ypos to this row and
                           ; clears billy_airborne.
* Enable right-scroll into mission29 (screen 8 = bank $0B). After
* the descent, the playfield shows mission28 left + mission29 right
* (split at world byte 110). Walking right past the scroll
* threshold should now reveal more of mission29's content.
 db OP_RIGHT,8
* Sync the scroll source offset to the live world_offset so the
* next scroll-right reveals mission29's next unseen byte. The old
* fixed OP_SCROLLSRC,20 assumed the descent ended at wo=20 — but
* wo after OP_DOWN is wherever the player engaged the down-ladder
* (varies a few bytes run to run), and the baked-in 20 shifted ALL
* later fill art right by (wo-20) bytes ("mission21/22 art 16px
* right" when engaging 8 bytes late). src_off = wo is the
* invariant every fill path assumes.
 db OP_SRCWO
* Vertical-split source for right-scroll: rows 0..142 fill from
* mission26 (screen 5 = bank $08, the upper descent layer's rbank),
* rows 143..182 from scroll_src_bank (mission29 = bank $0B, set
* by OP_RIGHT,8 above). Both banks are world-aligned with the same
* content origin (= world byte 110), so scroll_src_off advances
* in lockstep for both halves.
* Place a new ladder on the descent-end platform — goes UP 77px
* from y=130 to y=53. Centered at world x=$AF=175 (3-byte wide on
* each side of the column). scroll_up_enabled gets set so the
* lenient ladder-fallback in check_y_bounds engages when Billy
* steps up off the platform onto the ladder column.
 db OP_LADDER
 dw 172                    ; x_left  ($AC)
 dw 178                    ; x_right ($B2)
 db 53                     ; y_top   ($35) — 92 - 39 = sprite top
                           ; such that Billy's feet sit at row 92.
 db 129                    ; y_bottom ($81) — platform_row - 1, engage row from above
* Upper platform at y=53, same x layout as the lower platform.
* Billy lands here at the top of the ladder.
 db OP_PLATFORM,53
 dw 20                     ; span1 x_lo
 dw 155                    ; span1 x_hi
 dw 167                    ; span2 x_lo
 dw 228                    ; span2 x_hi (+10 bytes / 20px right vs the
                           ; y=130 platform below, per art)
 db OP_SCROLLSPLIT,5,143,37
                           ; p3=37 = mission26 row that's currently at
                           ; playfield row 0 (= 179 - row_offset_after_
                           ; descent = 179 - 142 = 37). Pass A starts
                           ; reading mission26 from row 37 so the
                           ; scrolling-in extends the existing on-
                           ; screen art instead of restarting at row 0.
* Second climb segment (zig-zag): mission22's art ladder at world
* x=181..185 (art bytes 71..75, world = art+110), rising from the
* mid-climb platform to the lower building's roof at art row 89 —
* 79 rows above the mid platform's surface at art row 168. The
* player rides the scrolling climb below, steps off onto the mid
* platform (the OP_PLATFORM y=53 row) when it arrives, walks left
* from the 195..209 ladder to this column, and pressing up resumes
* the SAME scroll_up_split (the driver routes any ladder slot >=
* upsplit_ladder_idx to the scroll; OP_ALADDER claims that index).
* MUST come after OP_LADDER (locals take lower slots) and before
* OP_UPSPLIT (which parks the script until the climb snaps).
 db OP_ALADDER
 dw 176                    ; x_left  (world; engage zone 174..192
                           ; covers Billy's measured stand-point,
                           ; world_x 179, center 183 on the art)
 dw 190                    ; x_right
 db 13                     ; y_top   (climb range top; any <= y_bottom)
 db 53                     ; y_bottom = mid-platform row = engage row
* Scrolling up-ladder at world x=202 ($CA) on the upper platform.
* Climbing it scrolls UP into mission21 (left strip) + mission22
* (right / most of screen). Coexists with the local OP_LADDER above
* (172..178) — the climb driver routes by ladder index.
 db OP_UPSPLIT
 dw 195                    ; x_left  (world, ~202-7)
 dw 209                    ; x_right (world, ~202+7)
 db 13                     ; y_top   (climb range top; any <= y_bottom)
 db 53                     ; y_bottom = upper-platform row = engage row
* Layer 1: finish scrolling the CURRENT screens (mission25/26) up to
* their top before the new art. split=110 = same world seam as the
* descent (world-consistent). snap_at=36 ≈ the 37-row top portion of
* mission26 that OP_SCROLLSPLIT left unshown. hoff=4 corrects the
* observed 4-byte rightward shift of the scrolled-in art. (TUNABLE)
 db 4                      ; lbank screen 4 = mission25 (left)
 db 5                      ; rbank screen 5 = mission26 (right/most)
 db 110                    ; split (WORLD byte)
 db 36                     ; snap_at (rows to top of mission25/26)
 db 0                      ; hoff (base is now scroll_src_off — the same
                           ; origin the static rows were painted with —
                           ; so 0 = continue the on-screen art exactly)
* Layer 2 (chained): the new art, mission21 (left strip) + mission22
* (right/most). next_snap_at=180 so mission21/22's full height scrolls
* in (bottom connects to mission25/26's top). next_hoff calibrates the
* art's horizontal placement (see inline note). split/snap_at/hoff
* TUNABLE.
 db 0                      ; next_lbank screen 0 = mission21
 db 1                      ; next_rbank screen 1 = mission22
 db 110                    ; next_split (WORLD byte). mission22 byte 0
                           ; = world 110, the standard 110-byte screen
                           ; seam (same convention as mission25/26 and
                           ; every mission1 pair). The old 128/hoff=18
                           ; pair encoded the same fill math (Pass B
                           ; offset = src_off - 110 either way) with
                           ; two magic numbers that had to cancel.
 db 179                    ; next_snap_at. NOT 180: the first band reads
                           ; source rows snap_at..snap_at+3, and art
                           ; content ends at row 182 — snap_at=180 pulled
                           ; in blank row 183 (the 1px black seam line).
                           ; 179 → first band = rows 179..182.
 db 0                      ; next_hoff. 0 now that next_split encodes the
                           ; true world seam (110): the src_off base alone
                           ; places mission22 byte B at world B+110. The
                           ; playtested "13 bytes right" fix (hoff 5→18)
                           ; and this split/hoff rewrite are the same
                           ; correction expressed two ways.
 db 108                    ; next_stop_at: END the climb at off=108 —
                           ; the ROOFTOP floor (mission22 art rows
                           ; ~165..182) arrives at Billy's feet with
                           ; source row 179-104=75 left at the top of
                           ; the view. Scrolling the full 179 rows
                           ; overshot the rooftop by ~80 rows and
                           ; parked Billy on the HELICOPTER SKID (art
                           ; rows 60..62). The helicopter/upper art
                           ; (rows 0..74) stays above the view for a
                           ; later leg. TUNABLE ±4.
* Climb-top platform. OP_UPSPLIT now parks the script in
* SCRIPT_WAITUS until :snap_transition_up_split clears
* scroll_us_enabled, so this runs the frame the up-scroll ends.
* With stop_at=108 the climb ends with the ROOFTOP floor
* (mission22 art rows ~165..182, screen rows ~90..107 at the
* stopped view) under Billy. y=54 puts his feet (ypos+40 = 94)
* on the floor's surface line (art row ~168 = screen row ~93);
* the earlier 57 sank him 3px into the platform art.
 db OP_BOUNDS,54
 dw 162                    ; span1 x_lo (world) — the rooftop platform
                           ; is ~30 bytes wide with the leg-2 ladder
                           ; (176..190) about halfway along it
 dw 221                    ; span1 x_hi (world)
 dw $FFFF                  ; span2 x_lo (no span2)
 dw $0000                  ; span2 x_hi
* Freeze scrolling on the roof. The pre-climb right-scroll config
* (OP_RIGHT,8 + OP_SCROLLSPLIT: mission26 rows 0..142 over
* mission29) is still armed and belongs to the level BELOW —
* walking right past the scroll threshold up here painted stale
* mission26/29 columns in from the right edge while sliding the
* just-scrolled-in mission21/22 art off to the left (the "very
* jumbled screen" after the long climb). The roof span 168..220
* fits entirely in the wo=112 view, so nothing needs to scroll
* until the next leg re-arms its own sources.
 db OP_SCRLOCK
* Next leg: the 79px ladder from the rooftop up to the lower
* building's roofline. The art column is mission22 bytes 71..75
* (world 181..185, center 183), spanning art rows ~89 (roofline)
* to ~168 (rooftop floor) — visible on screen at the stopped
* view. The first climb's snap cleared ladder_buf, so this
* OP_UPSPLIT installs the climbable ladder fresh (slot 0;
* check_waitus reset upsplit_ladder_idx so it re-claims routing).
* Fill origin 71 continues the art exactly where leg 1 stopped
* (top of view = art row 75; first fill here shows 71..74).
* stop == snap (71): scrolls the remaining art to its top
* (final view top = art row 3) — the roofline (art 89) lands at
* screen row 86 = Billy's feet at the OP_BOUNDS y=46 below.
 db OP_UPSPLIT
 dw 176                    ; x_left  (world; engage zone 174..192)
 dw 190                    ; x_right
 db 13                     ; y_top   (climb range top)
 db 54                     ; y_bottom = rooftop standing row = engage row
 db 0                      ; lbank screen 0 = mission21
 db 1                      ; rbank screen 1 = mission22
 db 110                    ; split (world seam)
 db 71                     ; snap_at = fill origin (continues from 75)
 db 0                      ; hoff
 db $FF                    ; no chain layer
 db 0                      ; next_rbank (unused)
 db 0                      ; next_split (unused)
 db 0                      ; next_snap_at (unused)
 db 0                      ; next_hoff (unused)
 db 0                      ; next_stop_at (unused)
* Roofline platform. Feet (ypos+40 = 86) on the art-89 roofline
* (top of view = art 3 after the full remaining scroll → art 89
* at screen 86). Span: blue-building roof, west edge at world
* 168. Note the roof-edge ART continues west to ~world 118
* (mission22 row 89 is solid from art col ~8) — extend span1_lo
* when that stretch becomes walkable in the design. TUNABLE.
 db OP_BOUNDS,46
 dw 168                    ; span1 x_lo (world)
 dw 249                    ; span1 x_hi (world) — the roofline art
                           ; (m22/m23 trim rows 90..94) runs east to
                           ; world ~251; left-edge support to 249 puts
                           ; the walk-off/drop right at the building's
                           ; east face
 dw $FFFF                  ; span2 x_lo (no span2)
 dw $0000                  ; span2 x_hi
* Eastward into mission23/24: the heliport deck. Re-enable right
* scrolling with mission22 (screen 1, world origin 110) as the
* source; the 110-byte cursor wrap cascades linearly through
* mission23 (origin 220) and mission24 (origin 330).
 db OP_RIGHT,1
 db OP_SRCWO               ; cursor = wo (m22 is world-aligned at 110)
* Single-bank fill with source rows offset +3: the view's top has
* shown art row 3 since the up-split climbs (screen = art - 3), so
* incoming columns must pull rows 3..185 to line up.
 db OP_SCROLLSPLIT,0,0,3
* The deck: mission23's runway platform. Surface at art row 154
* (screen 151) → standing ypos 111 (feet 151). West edge just
* under the roof's drop point so a walk-off at 249/250 lands;
* east end under the parked RS-11 helicopter in mission24
* (boarding comes in a later leg). The player FALLS from the
* roofline (feet 86) ~65px onto this row — gravity's landing
* sweep handles it.
 db OP_PLATFORM,111
 dw 250                    ; span1 x_lo (world)
 dw 458                    ; span1 x_hi (world; TUNABLE vs chopper)
 dw $FFFF                  ; span2 x_lo (no span2)
 dw $0000                  ; span2 x_hi
* Cap the scroll at mission24's east edge (art ends at world 489;
* wo 380 shows 380..489). Prevents the cursor wrap from cascading
* into bank 7 (mission25 — the level below) past the loaded art.
 db OP_SCRMAX
 dw 380
 db OP_WAITX
 dw 600                    ; placeholder hold
 db OP_END

*-------------------------------
* Per-screen bounds pointers. Only screen 0 is reachable today;
* slots 1..9 alias to bounds_scr0 so any stray screen-change read
* still returns a defined table. Engine's load_screen_bounds_l
* indexes this by screen number.
*-------------------------------
bounds_ptrs
 dw bounds_scr0
 dw bounds_scr0
 dw bounds_scr0
 dw bounds_scr0
 dw bounds_scr0
 dw bounds_scr0
 dw bounds_scr0
 dw bounds_scr0
 dw bounds_scr0
 dw bounds_scr0

*-------------------------------
* Screen 0:
*   y=81   upper platform — walkable x=0..$44   (= 0..68)
*   y=128  lower platform — walkable x=$58..$95 (= 88..149)
*
* Bumped +4 vs the prior (77/124) layout to compensate for an art
* fix that moved the visible platform lines 4 rows down. Billy's
* sprite (IMAGE01) is 40 rows tall and ypos is sprite-top, so a
* walkable row of N puts his feet at row N+40 (e.g. lower=128 →
* feet at row 168, matching the art).
*
* All other rows are blocked (bmax=0). Tools/gen_strata.py reads
* this to build stratum_ground's world-coord table.
*-------------------------------
bounds_scr0
 LUP 81
 dfb 0,0
 --^
 dfb 0,$44       ; row 81  — upper platform
 LUP 46
 dfb 0,0
 --^
 dfb $58,$95     ; row 128 — lower platform
 LUP 71
 dfb 0,0
 --^

*-------------------------------
* Global ladder list. First byte is the count (read by copy_ladders).
* Each entry: dw x_left, dw x_right, dfb y_top, dfb y_bottom.
* x_left/x_right are world bytes; y_top/y_bottom are screen-local
* rows. check_ladder requires proposed_y == y_bottom to start a
* climb, so y_bottom = floor row (= player ypos when standing on
* the floor the ladder rises FROM).
*
* TODO: ladder mechanics require scroll_up_enabled — which is only
* set by OP_UP. Mission 2 ultimately wants OP_DOWN-style scrolling
* into mission25/26 (left/right halves below) → mission28/29 →
* final platform. That's a new engine feature. Until OP_DOWN lands,
* the ladder is just a stub data entry — Billy can't actually
* engage it because check_x_bounds_world's ladder-fallback is
* gated on scroll_up_enabled.
*-------------------------------
ladders
 dfb 1                   ; one ladder
* Ladder 1: at world_x=$6B=107 (mission22 art column). Spans rows
* 129..199 (below the lower platform at y=128). Billy on the lower
* platform pressing DOWN proposes y=129 = y_top → DOWN-engage gate
* fires (see check_ladder). y_bottom=199 lets him descend through
* the whole visible playfield; scroll_down then advances the camera
* below that.
* Widened ±4 bytes beyond the art column (104..110) so the engage
* window matches Billy's visual overlap — the strict window made
* down-engage feel unreliable (press down on the ladder, nothing
* happens). The down-engage snap in :ai_do_down re-centers Billy
* onto the art column at engage time, so the wide window never
* shows him climbing off-center.
 dw 100                  ; x_left  ($64)
 dw 114                  ; x_right ($72)
 dfb 129,199             ; y_top=129 (= platform_row+1), y_bottom=199

*==========================================================
* Level manifest — minimum viable: 10 backgrounds + mission2 NTP.
* No compiled sprites, no blit files, no boss code, no jimmy data.
* loading_str_ptr = 0 turns draw_loading_string into a no-op.
*==========================================================
level_manifest
 dw lm_dir            ; +0  level directory
 dfb 10               ; +2  bg_count
 dfb 17               ; +3  load_count (NTP + jimmy + 3 compiled-sprite
                      ;     files + boss-code stub + 11 immediate-mode
                      ;     blit files; all shared with mission 1)
 dw lm_loading_strs   ; +4  loading_str_ptr → table below
* +6 bg_ptr[0..9]
 dw lm_bg0
 dw lm_bg1
 dw lm_bg2
 dw lm_bg3
 dw lm_bg4
 dw lm_bg5
 dw lm_bg6
 dw lm_bg7
 dw lm_bg8
 dw lm_bg9
* +6+10*2 = +26: load_entries (17 entries × 4 bytes each)
* The compiled-sprite, jimmy, blit files, AND the boss-code stub
* live at /MISSION1/... on disk; mission2 just references the same
* paths (no duplication). The boss code (MISSION1/BOSS, bank $1E)
* must be loaded because update_anims unconditionally calls
* jsl bn_grab_end / bn_anim_ended / bn_try_grab — those routines
* live in bank $1E and self-gate on the active anim, so they RTL
* harmlessly when there's no Burnov on screen. Mission 2 still has
* no boss NTP because no Burnov music ever triggers.
 dw lm_lntp
 dfb $13,2            ; bank $13, kind 2 (load_and_unpack @ $0000)
 dw lm_jimmy
 dfb $1D,0            ; bank $1D, kind 0
 dw lm_m12
 dfb $19,0            ; bank $19, kind 0
 dw lm_m13
 dfb $1B,0            ; bank $1B, kind 0
 dw lm_m14
 dfb $1C,0            ; bank $1C, kind 0
 dw lm_boss
 dfb $1E,0            ; bank $1E, kind 0 — boss-code stub for the hooks
 dw lm_m13blit30
 dfb $30,0
 dw lm_m13blit31
 dfb $31,0
 dw lm_m1blit32
 dfb $32,0
 dw lm_m1jblit33
 dfb $33,0
 dw lm_m12blit34
 dfb $34,0
 dw lm_m12blit35
 dfb $35,0
 dw lm_m12blit36
 dfb $36,0
 dw lm_m12blit37
 dfb $37,0
 dw lm_m12blit38
 dfb $38,0
 dw lm_m14blit39
 dfb $39,0
 dw lm_m14blit3a
 dfb $3A,0

lm_dir   str 'MISSION2'
lm_bg0   str 'MISSION21'
lm_bg1   str 'MISSION22'
lm_bg2   str 'MISSION23'
lm_bg3   str 'MISSION24'
lm_bg4   str 'MISSION25'
lm_bg5   str 'MISSION26'
lm_bg6   str 'MISSION27'
lm_bg7   str 'MISSION28'
lm_bg8   str 'MISSION29'
lm_bg9   str 'MISSION210'
lm_lntp      str 'MISSION2/MISSION2NTP.PAK'
* Shared with mission 1 — paths point at /MISSION1/ files on disk.
lm_jimmy     str 'MISSION1/MISSION1JIMMY'
lm_m12       str 'MISSION1/MISSION12'
lm_m13       str 'MISSION1/MISSION13'
lm_m14       str 'MISSION1/MISSION14'
lm_boss      str 'MISSION1/BOSS'
lm_m13blit30 str 'MISSION1/MISSION13BLIT30'
lm_m13blit31 str 'MISSION1/MISSION13BLIT31'
lm_m1blit32  str 'MISSION1/MISSION1BLIT32'
lm_m1jblit33 str 'MISSION1/M1JIMMYBLIT33'
lm_m12blit34 str 'MISSION1/M12BLIT34'
lm_m12blit35 str 'MISSION1/M12BLIT35'
lm_m12blit36 str 'MISSION1/M12BLIT36'
lm_m12blit37 str 'MISSION1/M12BLIT37'
lm_m12blit38 str 'MISSION1/M12BLIT38'
lm_m14blit39 str 'MISSION1/M14BLIT39'
lm_m14blit3a str 'MISSION1/M14BLIT3A'

*----------------------------------------------------------
* Loading-status strings (same content as mission1 for now;
* customise per mission later). draw_loading_string reads them
* from bank $02 — that's why they need to live here, not in
* shared engine data.
*----------------------------------------------------------
lm_loading_strs
    dw lstr1
    dw lstr2
    dw lstr3
    dw lstr4
    dw lstr5
    dw lstr6
lstr1   asc '    Fueling Helicopter  ',00
lstr2   asc '     Polishing Ladders  ',00
lstr3   asc 'Activating Street Lights ',00
lstr4   asc '     Waking up Linda           ',00
lstr5   asc ' Giga Smooth Scrolling   ',00
lstr6   asc ' Now we become ZZTop Ah? ',00

* Billy pixel data (IMAGE01-03, JUMP1-3, KICK1-2, PUNCH11-22,
* BPUNCHED, BCLIMB1-2, BSPIN/UPPER/GRAB/etc. + compiled AND/ORA
* mask & mirror variants). Shared with mission1.s via PUT — see
* src/player_sprites.s. Labels referenced by spr_addr_tbl above.
 PUT player_sprites

* POINT_DOWN — vertical mirror of mission1's POINT_UP. Used by
* OP_DOWN's overlay to indicate "press down to descend". Mission 2
* has no OP_UP, so the spr_pointup slot is repurposed to point at
* POINT_DOWN_DATA (engine init_level patches spr_pointup from the
* bank-$02 header entry; OP_DOWN's overlay reads spr_pointup).
* Each row = 8 bytes (= 16 pixels wide), 24 rows tall. Rows are
* listed in reverse order from POINT_UP_DATA in mission1.s so the
* arrow tip ends up at the bottom of the sprite (pointing down)
* instead of the top.
POINT_DOWN_DATA
 HEX 000008C000800600
 HEX 0000009B111B9000
 HEX 000000C655BB1900
 HEX 00080A9999AAB196
 HEX 000A9B11BB99ABBC
 HEX 0CABB11BBBB9AA98
 HEX 00B111B9C51BB000
 HEX 09111B9A0911BAC6
 HEX CB1BB9CC0CBBB9C0
 HEX CB111BB980A999C0
 HEX CB1111BB90C00800
 HEX 0CB1111B90061BC0
 HEX C9CC080099CB1BC0
 HEX CB1B9CAB19511100
 HEX CB11BA911A511BC0
 HEX CB11BC9BB0AB1A00
 HEX CB11BACAC0CA5000
 HEX CBBBBA0000000000
 HEX CBBBBA8000000000
 HEX CB11BA0000000000
 HEX C911BC8000000000
 HEX 0099C00000000000
 HEX 0000000000000000
 HEX 0000000000000000

POINT_DOWN_MASK
 HEX FFFFF0000000F0FF
 HEX FFFFF000000000FF
 HEX FFFFF0000000000F
 HEX FFF0000000000000
 HEX FF00000000000000
 HEX F000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 000000000000000F
 HEX 000000000000000F
 HEX 000000000000F00F
 HEX 000000000000000F
 HEX 0000F0F00000000F
 HEX 00000000000000FF
 HEX 000000000000000F
 HEX 000000000000000F
 HEX 00000000000000FF
 HEX 0000000FFFFFFFFF
 HEX 0000000FFFFFFFFF
 HEX 0000000FFFFFFFFF
 HEX 0000000FFFFFFFFF
 HEX 000000FFFFFFFFFF
 HEX F0000FFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFF

POINT_DOWN_DATA_MIRROR
 HEX 006008000C800000
 HEX 0009B111B9000000
 HEX 0091BB556C000000
 HEX 691BAA9999A08000
 HEX CBBA99BB11B9A000
 HEX 89AA9BBBB11BBAC0
 HEX 000BB15C9B111B00
 HEX 6CAB1190A9B11190
 HEX 0C9BBBC0CC9BB1BC
 HEX 0C999A089BB111BC
 HEX 00800C09BB1111BC
 HEX 0CB16009B1111BC0
 HEX 0CB1BC990080CC9C
 HEX 00111591BAC9B1BC
 HEX 0CB115A119AB11BC
 HEX 00A1BA0BB9CB11BC
 HEX 0005AC0CACAB11BC
 HEX 0000000000ABBBBC
 HEX 0000000008ABBBBC
 HEX 0000000000AB11BC
 HEX 0000000008CB119C
 HEX 00000000000C9900
 HEX 0000000000000000
 HEX 0000000000000000

POINT_DOWN_MASK_MIRROR
 HEX FF0F0000000FFFFF
 HEX FF000000000FFFFF
 HEX F0000000000FFFFF
 HEX 0000000000000FFF
 HEX 00000000000000FF
 HEX 000000000000000F
 HEX 0000000000000000
 HEX 0000000000000000
 HEX F000000000000000
 HEX F000000000000000
 HEX F00F000000000000
 HEX F000000000000000
 HEX F00000000F0F0000
 HEX FF00000000000000
 HEX F000000000000000
 HEX F000000000000000
 HEX FF00000000000000
 HEX FFFFFFFFF0000000
 HEX FFFFFFFFF0000000
 HEX FFFFFFFFF0000000
 HEX FFFFFFFFF0000000
 HEX FFFFFFFFFF000000
 HEX FFFFFFFFFFF0000F
 HEX FFFFFFFFFFFFFFFF

* Auto-generated strata tables (strata_index, screen_to_stratum,
* stratum_ground). Built from tools/mission2_strata.txt +
* this file's bounds_scrN by tools/gen_strata.py.
 PUT mission2_strata

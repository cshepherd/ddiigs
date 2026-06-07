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
OP_END   EQU 9
OP_BOUNDS EQU 21       ; rewrite stratum bounds to one walkable row
OP_SCROLLSRC EQU 22    ; set scroll_src_off directly (post-OP_RIGHT)
OP_SCROLLSPLIT EQU 23  ; vertical-split right-scroll source (upper bank, split row)

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
spr_pointup    dw 0
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
* Skip mission29 bytes already on-screen (= playfield bytes 90..109
* = mission29 bytes 0..19). The next scroll-right should reveal
* mission29 byte 20+ (= world byte 130+), not byte 0.
 db OP_SCROLLSRC,20
* Vertical-split source for right-scroll: rows 0..142 fill from
* mission26 (screen 5 = bank $08, the upper descent layer's rbank),
* rows 143..182 from scroll_src_bank (mission29 = bank $0B, set
* by OP_RIGHT,8 above). Both banks are world-aligned with the same
* content origin (= world byte 110), so scroll_src_off advances
* in lockstep for both halves.
 db OP_SCROLLSPLIT,5,143,37
                           ; p3=37 = mission26 row that's currently at
                           ; playfield row 0 (= 179 - row_offset_after_
                           ; descent = 179 - 142 = 37). Pass A starts
                           ; reading mission26 from row 37 so the
                           ; scrolling-in extends the existing on-
                           ; screen art instead of restarting at row 0.
 db OP_WAITX
 dw 600                    ; placeholder hold after descent
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
 dw 104                  ; x_left  ($68)
 dw 110                  ; x_right ($6E)
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

* Auto-generated strata tables (strata_index, screen_to_stratum,
* stratum_ground). Built from tools/mission2_strata.txt +
* this file's bounds_scrN by tools/gen_strata.py.
 PUT mission2_strata

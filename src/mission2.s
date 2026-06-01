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
OP_END EQU 9

*==========================================================
* Level header — same field layout as mission1.s.
*==========================================================
level_header
num_screens    dfb 10          ; 10 backgrounds packed in /MISSION2/
initial_screen dfb 0
player_spawn_x dfb $20
player_spawn_y dfb $64
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

*-------------------------------
* Sprite-address table — init_level reads many entries from here
* (IMAGE01-03, JUMP1-3, KICK1-2, PUNCH11-22, BPUNCHED, WILLIAM*,
* ROPER*, LINDA*, BCLIMB*, …). Provide a generous zero-filled
* block so reads succeed; the cached spr_* values are never
* dereferenced because no NPCs spawn (empty sprite_table + the
* level_script ends immediately).
*-------------------------------
spr_addr_tbl
 ds 200, 0

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
* Level script — just end immediately. No screens advance, no
* NPCs spawn, no scrolling locks.
*-------------------------------
level_script
 db OP_END

*-------------------------------
* Per-screen bounds pointers — every screen maps to the same
* permissive bounds table. Engine's load_screen_bounds_l indexes
* this by screen number on screen transitions.
*-------------------------------
bounds_ptrs
 dw bounds_open
 dw bounds_open
 dw bounds_open
 dw bounds_open
 dw bounds_open
 dw bounds_open
 dw bounds_open
 dw bounds_open
 dw bounds_open
 dw bounds_open

bounds_open
 ds 64, 0       ; zero-filled bounds entry (no walls)

*-------------------------------
* Global ladder list — none.
*-------------------------------
ladders
 dw $FFFF

*-------------------------------
* Strata: one wide-open stratum, all screens map to it.
*-------------------------------
strata_index
 dw stratum0

stratum0
 ds 64, 0

screen_to_stratum
 dfb 0,0,0,0,0,0,0,0,0,0

*==========================================================
* Level manifest — minimum viable: 10 backgrounds + mission2 NTP.
* No compiled sprites, no blit files, no boss code, no jimmy data.
* loading_str_ptr = 0 turns draw_loading_string into a no-op.
*==========================================================
level_manifest
 dw lm_dir            ; +0  level directory
 dfb 10               ; +2  bg_count
 dfb 16               ; +3  load_count (NTP + jimmy + 3 compiled-sprite
                      ;     files + 11 immediate-mode blit files,
                      ;     shared with mission 1 by path)
 dw 0                 ; +4  loading_str_ptr = 0 (no loading strings yet)
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
* +6+10*2 = +26: load_entries (16 entries × 4 bytes each)
* The compiled-sprite, jimmy, and blit files live at /MISSION1/...
* on disk; mission2 just references the same paths (no duplication).
* Mission 2 does NOT load the boss code or boss NTP — no Burnov fight.
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

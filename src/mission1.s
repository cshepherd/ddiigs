*----------------------------------------------------------
* Mission 1 - Level data
* Loaded into bank $02 by the game engine.
* Contains screen map, sprite tables, sprite info blocks,
* animation descriptors, and references to background art.
*----------------------------------------------------------
    org $020000

; level script bytecodes
OP_NONE     EQU 0 ; NOP
OP_SCREEN   EQU 1 ; display screen (params: screen index)
OP_WAITX    EQU 2 ; wait for player to cross X threshold (params: X position)
OP_NPC      EQU 3 ; add NPC to screen (params: sprite ptr, xpos, ypos, orientation)
OP_RIGHT    EQU 4 ; connect screen to the right and permit scrolling (params: screen index)
OP_LEFT     EQU 5 ; connect screen to the left and permit scrolling (params: screen index)
OP_UP       EQU 6 ; scroll up (params: target screen, left-neighbor screen)
OP_DOWN     EQU 7 ; connect screen below and permit scrolling (params: screen index)
OP_SCRLOCK  EQU 8 ; lock scrolling in current screen (no params)
OP_END      EQU 9 ; end of level (no params)
OP_WAITY    EQU 10 ; wait for player to cross Y threshold (params: Y position)
OP_WAITCLR  EQU 11 ; wait for screen to be clear of enemies (no params)
OP_WAITNPC  EQU 12 ; wait for a particular count of NPC sprites to be active (params: count)
OP_WAITXREV EQU 13 ; wait for abs_x to descend to <= threshold (params: X position)
OP_SCRMIN   EQU 14 ; clamp world_offset from below (params: 2-byte wo minimum)
OP_SCRMAX   EQU 15 ; clamp world_offset from above (params: 2-byte wo maximum)
OP_SNAPSTATE EQU 16 ; restore engine to a "golden" state (17-byte payload)
                    ; Payload order: dw wo, dw abs_x, db xpos, db cs,
                    ; db ssrc_bank, db ssrc_off, db lsrc_bank, db lsrc_off,
                    ; dw up_anchor, db up_off, dw min_wo, dw max_wo
OP_SNAPSTATE_DEFER EQU 17 ; same as OP_SNAPSTATE but applied at next scroll_up
OP_BOSSMUSIC EQU 18 ; trigger boss music (no params)
OP_WAIT     EQU 19 ; wait N frames before continuing the script (params: 1-byte frame count)
; NOTE OP_WAITX and OP_WAITY use 'absolute X' (level-wide) not screen xpos/ypos
;  so it's easier to use for game logic
; NOTE OP_NPC params are: sprite_ptr (2b), xpos (1b), ypos (1b), orient (1b), behavior (1b)

; NPC behavior IDs (used in OP_NPC parameter)
BEHAV_NONE    EQU 0 ; just stand there
BEHAV_FACEOFF EQU 1 ; approach player to 5px and punch
BEHAV_FLANK   EQU 2 ; approach player from behind (TBD)
BEHAV_LURK    EQU 3 ; stay on opposite side of screen (TBD)
BEHAV_LADDER  EQU 4 ; descend ladder, then face off

*==========================================================
* Level header
*==========================================================
level_header
num_screens    dfb 5           ; number of screens in this level
initial_screen dfb 0           ; starting screen index
player_spawn_x dfb $20         ; player starting X position
player_spawn_y dfb $64         ; player starting Y position
screen_map_off dw screen_map   ; offset to screen map
sprite_tbl_off dw sprite_table ; offset to sprite table
sprite_dat_off dw $0000        ; offset to sprite pixel data (TBD)
mask_dat_off   dw $0000        ; offset to mask data (TBD)
anim_desc_off  dw anim_descs   ; offset to animation descriptors
level_scr_off  dw level_script  ; offset to level script
npc_scr_off    dw $0000        ; offset to NPC script table (TBD)
spr_addr_off   dw spr_addr_tbl ; offset to sprite address table
bounds_ptr_off dw bounds_ptrs   ; offset to per-screen bounds pointer table
ladder_ptr_off dw ladders       ; offset to global ladder list

*-------------------------------
* Sprite pixel data address table (bank $02 addresses)
* Engine reads these at init to set up frame_addr/idle_addr
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
spr_william1   dw WILLIAM1
spr_wpunched   dw WPUNCHED
spr_wfall      dw WFALL
spr_wfallen    dw WFALLEN
spr_william2   dw WILLIAM2
spr_william3   dw WILLIAM3
spr_wpunch1    dw WPUNCH1
spr_wpunch2    dw WPUNCH2
; Roper sprites
spr_roper1     dw ROPER1
spr_roper2     dw ROPER2
spr_roper3     dw ROPER3
spr_rpunch1    dw RPUNCH1
spr_rpunch2    dw RPUNCH2
spr_rpunched   dw RPUNCHED
spr_rfall1     dw RFALL1
spr_rfall2     dw RFALL2
; Linda Lash sprites
spr_linda1     dw LINDA1
spr_linda2     dw LINDA2
spr_linda3     dw LINDA3
spr_lpunch1    dw LPUNCH1
spr_lpunch2    dw LPUNCH2
spr_lpunched   dw LPUNCHED
spr_lfall1     dw LFALL1
spr_lfall2     dw LFALL2
; HUD overlays — main DATA pointers in original slots (offsets +74, +76)
spr_pointright dw POINT_RIGHT_DATA
spr_pointup    dw POINT_UP_DATA
; Billy climb frames
spr_bclimb1    dw BCLIMB1
spr_bclimb2    dw BCLIMB2
; Linda climb frames
spr_lclimb1    dw LCLIMB1
spr_lclimb2    dw LCLIMB2
; Compiled-sprite extras for AND/ORA pipeline (offsets +86..+96)
spr_pointright_mask         dw POINT_RIGHT_MASK
spr_pointright_data_mirror  dw POINT_RIGHT_DATA_MIRROR
spr_pointright_mask_mirror  dw POINT_RIGHT_MASK_MIRROR
spr_pointup_mask            dw POINT_UP_MASK
spr_pointup_data_mirror     dw POINT_UP_DATA_MIRROR
spr_pointup_mask_mirror     dw POINT_UP_MASK_MIRROR
; Billy walk frames — compiled (offsets +98..+114)
spr_image01_mask            dw IMAGE01_MASK
spr_image01_data_mirror     dw IMAGE01_DATA_MIRROR
spr_image01_mask_mirror     dw IMAGE01_MASK_MIRROR
spr_image02_mask            dw IMAGE02_MASK
spr_image02_data_mirror     dw IMAGE02_DATA_MIRROR
spr_image02_mask_mirror     dw IMAGE02_MASK_MIRROR
spr_image03_mask            dw IMAGE03_MASK
spr_image03_data_mirror     dw IMAGE03_DATA_MIRROR
spr_image03_mask_mirror     dw IMAGE03_MASK_MIRROR
; Billy climb frames — compiled (offsets +116..+126)
spr_bclimb1_mask            dw BCLIMB1_MASK
spr_bclimb1_data_mirror     dw BCLIMB1_DATA_MIRROR
spr_bclimb1_mask_mirror     dw BCLIMB1_MASK_MIRROR
spr_bclimb2_mask            dw BCLIMB2_MASK
spr_bclimb2_data_mirror     dw BCLIMB2_DATA_MIRROR
spr_bclimb2_mask_mirror     dw BCLIMB2_MASK_MIRROR
; Billy punch1 frames — compiled (offsets +128..+138)
spr_punch11_mask            dw PUNCH11_MASK
spr_punch11_data_mirror     dw PUNCH11_DATA_MIRROR
spr_punch11_mask_mirror     dw PUNCH11_MASK_MIRROR
spr_punch12_mask            dw PUNCH12_MASK
spr_punch12_data_mirror     dw PUNCH12_DATA_MIRROR
spr_punch12_mask_mirror     dw PUNCH12_MASK_MIRROR
; Billy punch2 frames — compiled (offsets +140..+150)
spr_punch21_mask            dw PUNCH21_MASK
spr_punch21_data_mirror     dw PUNCH21_DATA_MIRROR
spr_punch21_mask_mirror     dw PUNCH21_MASK_MIRROR
spr_punch22_mask            dw PUNCH22_MASK
spr_punch22_data_mirror     dw PUNCH22_DATA_MIRROR
spr_punch22_mask_mirror     dw PUNCH22_MASK_MIRROR
; Billy kick frames — compiled (offsets +152..+162)
spr_kick1_mask              dw KICK1_MASK
spr_kick1_data_mirror       dw KICK1_DATA_MIRROR
spr_kick1_mask_mirror       dw KICK1_MASK_MIRROR
spr_kick2_mask              dw KICK2_MASK
spr_kick2_data_mirror       dw KICK2_DATA_MIRROR
spr_kick2_mask_mirror       dw KICK2_MASK_MIRROR
; Billy jump frames — compiled (offsets +164..+180)
spr_jump1_mask              dw JUMP1_MASK
spr_jump1_data_mirror       dw JUMP1_DATA_MIRROR
spr_jump1_mask_mirror       dw JUMP1_MASK_MIRROR
spr_jump2_mask              dw JUMP2_MASK
spr_jump2_data_mirror       dw JUMP2_DATA_MIRROR
spr_jump2_mask_mirror       dw JUMP2_MASK_MIRROR
spr_jump3_mask              dw JUMP3_MASK
spr_jump3_data_mirror       dw JUMP3_DATA_MIRROR
spr_jump3_mask_mirror       dw JUMP3_MASK_MIRROR
; Billy hit-reaction frame — compiled (offsets +182..+186)
spr_bpunched_mask           dw BPUNCHED_MASK
spr_bpunched_data_mirror    dw BPUNCHED_DATA_MIRROR
spr_bpunched_mask_mirror    dw BPUNCHED_MASK_MIRROR

; William somersault frames — used by fo_somersault closer (offsets +188..+192)
spr_wsomer1   dw WSOMER1
spr_wsomer2   dw WSOMER2
spr_wsomer3   dw WSOMER3

; Billy uppercut frames — used by anim_uppercut (offsets +194..+198)
spr_bupper1   dw BUPPER1
spr_bupper2   dw BUPPER2
spr_bupper3   dw BUPPER3

; Grab system (offsets +200..+214). Billy = BGRAB1/2; held targets
; per enemy type.
spr_bgrab1    dw BGRAB1
spr_bgrab2    dw BGRAB2
spr_wheld1    dw WHELD1
spr_wheld2    dw WHELD2
spr_rheld1    dw RHELD1
spr_rheld2    dw RHELD2
spr_lheld1    dw LHELD1
spr_lheld2    dw LHELD2

; Level 1 script
level_script
; screen 1
    db OP_SCREEN, 0     ; start on screen 0
    db OP_NPC           ; William1 - face-off attacker
    dw william_sprite
    db $58,$5f,$01,BEHAV_FACEOFF  ; xpos, ypos, orientation, behavior
    db OP_NPC           ; William2
    dw william_sprite
    db $58,$84,$01,BEHAV_FLANK     ; xpos, ypos, orientation, behavior
    db OP_WAITCLR       ; wait for player to defeat NPCs
    db OP_NPC           ; William3
    dw william_sprite
    db $58,$5f,$00,BEHAV_FACEOFF     ; xpos, ypos, orientation, behavior
    db OP_WAITCLR
    db OP_RIGHT,1       ; connect screen 0 to screen 1 on the right

; screen 2
    db OP_WAITX
    dw $0112            ; wait for player abs_x >= 274 (scr2 Ropers)
    db OP_SCRLOCK       ; stuck here
    db OP_NPC           ; Roper near right edge
    dw roper_sprite
    db $58,$5f,$01,BEHAV_FACEOFF  ; xpos, ypos, orientation, behavior
    db OP_NPC           ; Roper running in frm left edge
    dw roper_sprite
    db $01,$5f,$00,BEHAV_FLANK     ; xpos, ypos, orientation, behavior
    db OP_WAITNPC,$01
    db OP_NPC           ; Final Roper near right edge
    dw roper_sprite
    db $58,$5f,$01,BEHAV_FACEOFF  ; xpos, ypos, orientation, behavior
    db OP_WAITCLR
    db OP_RIGHT,2       ; connect screen 1 to screen 2 on the right

; screen 3
     db OP_WAITX
     dw $0182            ; wait for player abs_x >= 402 (scr3 Linda)
     db OP_SCRLOCK
     db OP_NPC           ; Linda Lash #1 descending ladder
     dw linda_sprite
     db $00,$00,$01,BEHAV_LADDER  ; xpos/ypos snapped by behavior
     db OP_WAIT,100       ; ~10 px ladder gap (1 px / 4 frames)
     db OP_NPC           ; Linda Lash #2 descending ladder
     dw linda_sprite
     db $00,$00,$01,BEHAV_LADDER
     db OP_WAITNPC,$01
     db OP_NPC           ; Linda Lash on ladder
     dw linda_sprite
     db $00,$00,$01,BEHAV_LADDER
     db OP_WAITCLR
     db OP_NPC           ; William from right
     dw william_sprite
     db $58,$5f,$01,BEHAV_FACEOFF
     db OP_NPC           ; William from left
     dw william_sprite
     db $01,$5f,$00,BEHAV_FLANK
     db OP_WAITNPC,$01
     db OP_NPC           ; William from right
     dw william_sprite
     db $58,$5f,$01,BEHAV_FACEOFF
* Pre-climb golden state for ladder1 (recorded via 'g' key
* below first ladder). DEFERRED: applied at the first scroll_up
* call once climb begins. Includes a repaint region that paints
* scr3 art at canonical position so the lower playfield art
* matches the restored engine state.
    db OP_SNAPSTATE_DEFER
    dw $0128            ; world_offset
    dw $015C            ; abs_x
    db $34              ; IMAGE01_XPOS
    db $02              ; current_screen
    db $06              ; scroll_src_bank
    db $4C              ; scroll_src_off
    db $04              ; scroll_lsrc_bank
    db $6D              ; scroll_lsrc_off
    dw $014A            ; scroll_up_anchor
    db $B6              ; scroll_up_off
    dw $0000            ; scroll_min_wo
    dw $FFFF            ; scroll_max_wo
* Repaint config (two regions, 4 bytes each):
*   Region 1: scr3 (bank $06, byte 0) → playfield cols [34..109]
*     (= 76 bytes) for all 183 rows. With wo=$0128=296 and
*     scr3_origin=330, scr3 byte 0 sits at world 330 = playfield
*     col 330-296 = 34.
*   Region 2: scr2 (bank $05, byte 76) → playfield cols [0..33]
*     (= 34 bytes). With wo=296 and scr2_origin=220, the visible
*     scr2 starts at byte (296 - 220) = 76 and runs through byte
*     109 (= scr2's right edge), filling cols 0..33.
    db $06              ; region 1 bank (scr3)
    db $00              ; region 1 source byte
    db $4C              ; region 1 count = 76
    db $22              ; region 1 dst col (= 34)
    db $05              ; region 2 bank (scr2)
    db $4C              ; region 2 source byte = 76
    db $22              ; region 2 count = 34
    db $00              ; region 2 dst col = 0
    db OP_WAITCLR
    db OP_UP,5,6,7      ; Up to screen 5, left=screen 6, right=screen 7
* Post-climb golden state for ladder1 (recorded above first
* ladder). Fires after OP_UP completes — snap_transition has
* already run, so playfield matches canonical state. This op
* commits engine state to the recorded post-climb checkpoint.
    db OP_SNAPSTATE
    dw $0128            ; world_offset
    dw $015C            ; abs_x
    db $34              ; IMAGE01_XPOS
    db $05              ; current_screen
    db $08              ; scroll_src_bank
    db $4C              ; scroll_src_off
    db $07              ; scroll_lsrc_bank
    db $6D              ; scroll_lsrc_off
    dw $014A            ; scroll_up_anchor
    db $1A              ; scroll_up_off
    dw $0000            ; scroll_min_wo
    dw $FFFF            ; scroll_max_wo

; upper level (screen 5)
    db OP_SCRLOCK       ; lock scrolling on upper level
    db OP_NPC           ; William on upper level
    dw linda_flail_sprite
    db $58,$32,$01,BEHAV_FACEOFF  ; y=$32 (50) within walkable band
    db OP_WAITCLR       ; wait for enemies defeated

    db OP_RIGHT,7      ; connect screen 5 to screen 7 on the right

;    db OP_WAITX
;    dw 450              ; wait for player abs X >= 450
;    db OP_SCRLOCK       ; stuck here
;    db OP_NPC           ; Roper near right edge
;    dw roper_sprite
;    db $58,$5f,$01,BEHAV_FACEOFF  ; xpos, ypos, orientation, behavior

    db OP_WAITX
    dw 450
* Pre-climb golden state for ladder2 (recorded 'g' below ladder2
* on scr7). DEFERRED: applied at first scroll_up call (= climb
* start). Two repaint regions paint scr5 (left) and scr7 (right)
* at canonical wo=372.
    db OP_SNAPSTATE_DEFER
    dw $0174            ; world_offset = 372
    dw $01C4            ; abs_x = 452
    db $50              ; IMAGE01_XPOS = 80
    db $07              ; current_screen = scr7
    db $0A              ; scroll_src_bank (scr7)
    db $2A              ; scroll_src_off = 42
    db $09              ; scroll_lsrc_bank (scr6)
    db $6D              ; scroll_lsrc_off = 109
    dw $01B8            ; scroll_up_anchor = 440
    db $B6              ; scroll_up_off = 182 (full-height default)
    dw $0000            ; scroll_min_wo
    dw $FFFF            ; scroll_max_wo
* Repaint region 1: scr5 (bank $08) byte 42 → cols [0..67].
* wo=372, scr5_origin=330, scr5 byte 42 sits at world 372 = col 0.
    db $08              ; region 1 bank (scr5)
    db $2A              ; region 1 source byte = 42
    db $44              ; region 1 count = 68
    db $00              ; region 1 dst col = 0
* Repaint region 2: scr7 (bank $0A) byte 0 → cols [68..109].
* scr7_origin=440 = col 68.
    db $0A              ; region 2 bank (scr7)
    db $00              ; region 2 source byte = 0
    db $2A              ; region 2 count = 42
    db $44              ; region 2 dst col = 68
    db OP_UP,10,8,$ff     ; Up to screen 8, left=screen 9, right=none
* Post-climb golden state for ladder2 (recorded 'g' on scr10).
* lsrc_bank=$0B (scr8) and lsrc_off=$29 (=41) from snap_transition
* fix; this is the canonical lsrc to continue scrolling left
* through scr8 toward scr9.
    db OP_SNAPSTATE
    dw $0174            ; world_offset = 372
    dw $01C4            ; abs_x = 452
    db $50              ; IMAGE01_XPOS = 80
    db $0A              ; current_screen = scr10
    db $0D              ; scroll_src_bank (scr10)
    db $2A              ; scroll_src_off = 42
    db $0B              ; scroll_lsrc_bank (scr8) ← from snap fix
    db $29              ; scroll_lsrc_off = 41 ← lwidth-up_dst_start-1
    dw $01B8            ; scroll_up_anchor = 440
    db $1A              ; scroll_up_off = 26
    dw $0000            ; scroll_min_wo
    dw $FFFF            ; scroll_max_wo

    db OP_WAITXREV
    dw $0195              ; wait for player to descend back to abs_x <= 788
    db OP_LEFT,8          ; enable leftward scroll into scr8 (lsrc_off
                          ; preserved from snap_transition's lgap state)
* When player has scrolled through ~all of scr8, transition to scr9.
* The engine's wide-wrap path decrements lsrc_bank from $0B (scr8)
* to $0A (scr7) on underflow — wrong for our non-linear layout. We
* must switch lsrc to scr9 BEFORE that underflow.
* Trace: post-climb wo=360, lsrc_off=29. Scroll 7 ends with wo=332,
* lsrc_off=1, abs_x≈361 (= 332+29 with xpos clamped at 29 during
* scroll). Scroll 8 would underflow. Fire OP_LEFT,9 at abs_x=361
* so it lands between scrolls 7 and 8.
    db OP_WAITXREV
    dw $0169              ; abs_x ≤ 361 → just past scroll 7
    db OP_LEFT,9          ; transition lsrc to scr9 (lsrc_off resets to 109)
* Lock wo at 296 — both min and max set so scrolling past this
* point in either direction is blocked. The visible ladder3 art
* sits at world 329 = playfield col 33 once wo is locked.
    db OP_SCRMIN
    dw 296
    db OP_SCRMAX
    dw 296

* Pre-climb golden state for ladder3 (recorded 'g' at the bottom
* of ladder3 with wo locked at 296). DEFERRED: applied at first
* scroll_up call (= climb start). Two repaint regions canonicalize
* the playfield: scr9 (right portion bytes 76..109) at cols 0..33,
* scr8 (left portion bytes 0..75) at cols 34..109.
    db OP_SNAPSTATE_DEFER
    dw $0128            ; world_offset = 296
    dw $013D            ; abs_x = 317 (= wo + xpos)
    db $15              ; IMAGE01_XPOS = 21 (snap formula 26 - scr12 nudge 5)
    db $09              ; current_screen = scr9
    db $0C              ; scroll_src_bank (scr9)
    db $00              ; scroll_src_off = 0
    db $0C              ; scroll_lsrc_bank (scr9)
    db $45              ; scroll_lsrc_off = 69
    dw $00DD            ; scroll_up_anchor = 221 (scr12) — match game.s
    db $70              ; scroll_up_off = 112
    dw $0128            ; scroll_min_wo = 296
    dw $0128            ; scroll_max_wo = 296
* Repaint region 1: scr9 (bank $0C) byte 76 → cols [0..33]
* (= 34 bytes). With wo=296, scr9_origin=220, scr9 byte 76 sits
* at world 296 = playfield col 0; scr9 fills until scr8 at col 34.
    db $0C              ; region 1 bank (scr9)
    db $4C              ; region 1 source byte = 76
    db $22              ; region 1 count = 34
    db $00              ; region 1 dst col = 0
* Repaint region 2: scr8 (bank $0B) byte 0 → cols [34..109]
* (= 76 bytes). scr8_origin=330 = col 34 with wo=296.
    db $0B              ; region 2 bank (scr8)
    db $00              ; region 2 source byte = 0
    db $4C              ; region 2 count = 76
    db $22              ; region 2 dst col = 34

    db OP_UP,12,$FF,11    ; enable climb on ladder 3 (scr12→scr10, scr11 rfill)
* Post-climb golden state for ladder3 (recorded 'g' on scr12 after
* climb completed). Fires after snap_transition; commits engine
* state to the recorded post-climb checkpoint and unlocks
* scroll_max_wo so OP_WAITX/OP_RIGHT can progress off scr12.
* scroll_min_wo stays at 296 — leftward scroll back through scr12
* remains locked.
    db OP_SNAPSTATE
    dw $0128            ; world_offset = 296
    dw $013D            ; abs_x = 317
    db $15              ; IMAGE01_XPOS = 21
    db $0C              ; current_screen = scr12
    db $0E              ; scroll_src_bank (scr11)
    db $4B              ; scroll_src_off = 75
    db $0E              ; scroll_lsrc_bank (scr11)
    db $6D              ; scroll_lsrc_off = 109
    dw $00DD            ; scroll_up_anchor = 221
    db $1C              ; scroll_up_off = 28
    dw $0128            ; scroll_min_wo = 296
    dw $FFFF            ; scroll_max_wo (unlocked)

    db OP_WAITX
    dw $0198              ; wait for player abs X >= 600

    db OP_RIGHT,13        ; enable right-scroll → scr13 after scr11

    db OP_WAITX
    dw $01D8              ; wait for player abs X >= 472 (~16 px before 480)
    db OP_SCRLOCK         ; lock scrolling in screen 13 (final screen)
    db OP_BOSSMUSIC

    db OP_NPC           ; Burnov, the Mission 1 boss
    dw burnov_sprite
    db $58,$43,$01,BEHAV_FACEOFF  ; y=$43 (67) — within walkable band for
                                  ; the boss screen. Earlier $57 put him
                                  ; on the floor of the William fight area,
                                  ; outside this screen's walkable bounds.
    db OP_WAITCLR       ; wait for enemies defeated

    db OP_END           ; end of level

sfx_table
  dw sfx_punch
  dw sfx_punchlanded
  dw sfx_finger
  dw sfx_fall

sfx_punch
  dw 0000            ; position in sfx bank
  dw 100             ; playback speed
  dfb 17             ; filename length
  asc '/DDIIGS/PUNCH.RAW'

sfx_punchlanded
  dw 2800
  dw 100
  dfb 23
  asc '/DDIIGS/PUNCHLANDED.RAW'

sfx_finger
  dw 4800
  dw 100
  dfb 18
  asc '/DDIIGS/FINGER.RAW'

sfx_fall
  dw 7800
  dw 100
  dfb 16
  asc '/DDIIGS/FALL.RAW'

*==========================================================
* Screen map - one entry per screen
* Each entry: bg_bank, bg_half, right, left, up, down
* $FFFF = no exit in that direction
*==========================================================
screen_map

* Screen 0 (MISSION11) - starting screen
screen0
 dfb $03             ; bg_bank
 dfb $00             ; bg_half ($00 = low $0000, $80 = high $8000)
 dw $0001            ; right -> screen 1
 dw $FFFF            ; left -> none (start of level)
 dw $FFFF            ; up -> none
 dw $FFFF            ; down -> none
 dfb 17              ; bg filename length
 asc '/DDIIGS/MISSION11.PAK'

* Screen 1 (MISSION12)
screen1
 dfb $03             ; bg_bank
 dfb $80             ; bg_half (high half of bank $03)
 dw $0002            ; right -> screen 2
 dw $0000            ; left -> screen 0
 dw $FFFF            ; up -> none
 dw $FFFF            ; down -> none
 dfb 17              ; bg filename length
 asc '/DDIIGS/MISSION12.PAK'

* Screen 2 (MISSION13)
screen2
 dfb $04             ; bg_bank
 dfb $00             ; bg_half (low half of bank $04)
 dw $0003            ; right -> screen 3
 dw $0001            ; left -> screen 1
 dw $FFFF            ; up -> none
 dw $FFFF            ; down -> none
 dfb 17              ; bg filename length
 asc '/DDIIGS/MISSION13.PAK'

* Screen 3 (MISSION14)
screen3
 dfb $04             ; bg_bank
 dfb $80             ; bg_half (high half of bank $04)
 dw $0004            ; right -> screen 4
 dw $0002            ; left -> screen 2
 dw $FFFF            ; up -> none
 dw $FFFF            ; down -> none
 dfb 17              ; bg filename length
 asc '/DDIIGS/MISSION14.PAK'

* Screen 4 (MISSION15)
screen4
 dfb $05             ; bg_bank
 dfb $00             ; bg_half (low half of bank $05)
 dw $FFFF            ; right -> none (end of level)
 dw $0003            ; left -> screen 3
 dw $0005            ; up -> screen 5
 dw $FFFF            ; down -> none
 dfb 17              ; bg filename length
 asc '/DDIIGS/MISSION15.PAK'

* Screen 5 (MISSION16)
screen5
 dfb $05             ; bg_bank
 dfb $80             ; bg_half (high half of bank $05)
 dw $0007            ; right -> none
 dw $0006            ; left -> none
 dw $FFFF            ; up -> none
 dw $FFFF            ; down -> none
 dfb 17              ; bg filename length
 asc '/DDIIGS/MISSION16.PAK'

* Screen 6 (MISSION17)
screen6
 dfb $06             ; bg_bank
 dfb $00             ; bg_half (low half of bank $06)
 dw $0005            ; right -> screen 5
 dw $FFFF            ; left -> none
 dw $0009            ; up -> none
 dw $FFFF            ; down -> none
 dfb 17              ; bg filename length
 asc '/DDIIGS/MISSION17.PAK'

* Screen 7 (MISSION18)
screen7
 dfb $06             ; bg_bank
 dfb $80             ; bg_half (high half of bank $06)
 dw $FFFF            ; right -> none
 dw $0005            ; left -> screen 5
 dw $000A            ; up -> screen 10
 dw $FFFF            ; down -> none
 dfb 17              ; bg filename length
 asc '/DDIIGS/MISSION18.PAK'

* Screen 8 (MISSION19)
screen8
 dfb $07             ; bg_bank
 dfb $00             ; bg_half (low half of bank $07)
 dw $FFFF            ; right -> none
 dw $FFFF            ; left -> none
 dw $FFFF            ; up -> none
 dw $0005            ; down -> screen 5
 dfb 17              ; bg filename length
 asc '/DDIIGS/MISSION19.PAK'

* Screen 9 (MISSION110)
screen9
 dfb $07             ; bg_bank
 dfb $80             ; bg_half (high half of bank $07)
 dw $0008            ; right -> screen 8
 dw $FFFF            ; left -> none
 dw $0004            ; up -> screen 4
 dw $0006            ; down -> screen 6
 dfb 17              ; bg filename length
 asc '/DDIIGS/MISSION110.PAK'

* Screen 10 (MISSION111)
screen10
 dfb $08             ; bg_bank
 dfb $00             ; bg_half (low half of bank $08)
 dw $FFFF            ; right -> none
 dw $0009            ; left -> screen 9
 dw $FFFF            ; up -> none
 dw $0007            ; down -> none
 dfb 17              ; bg filename length
 asc '/DDIIGS/MISSION111.PAK'

*==========================================================
* Sprite table - null-terminated list of pointers to
* sprite info blocks. Order determines draw priority
* (first = behind, last = in front).
*==========================================================
sprite_table
 dw billy_sprite
 dw william_sprite
 dw william2_sprite
 dw $0000            ; terminator
 dw $0000            ; room for more
 dw $0000
 dw $0000
 dw $0000

sprite_table_copy
 dw $0000
 dw $0000
 dw $0000
 dw $0000
 dw $0000
 dw $0000
 dw $0000
 dw $0000

*==========================================================
* Animation descriptors
* Format: num_frames, max_width, flags, then per frame:
*         frame_x, frame_y, duration, frame_addr (2 bytes)
* Flags: bit 0 = advance position per VBL, bit 1 = loop
*==========================================================
anim_descs

anim_walk
 dfb 4               ; num_frames
 dfb $0B             ; max_width
 dfb $00             ; flags: none (key handler moves position)
 dfb $09,$28,5       ; IMAGE01
  da IMAGE01
 dfb $08,$28,5       ; IMAGE02
  da IMAGE02
 dfb $0B,$28,5       ; IMAGE03
  da IMAGE03
 dfb $08,$28,5       ; IMAGE02 (repeat)
  da IMAGE02

anim_jump
 dfb 3
 dfb $0F
 dfb $01             ; flags: advance position per VBL
 dfb $0A,$28,3       ; JUMP1
  da JUMP1
 dfb $0F,$2A,12      ; JUMP2
  da JUMP2
 dfb $0D,$20,3       ; JUMP3
  da JUMP3

anim_kick
 dfb 2
 dfb $14
 dfb $00
 dfb $09,$28,12      ; KICK1
  da KICK1
 dfb $14,$28,12      ; KICK2
  da KICK2

anim_punch1
 dfb 2
 dfb $10
 dfb $00
 dfb $0B,$28,6       ; PUNCH11
  da PUNCH11
 dfb $10,$28,6       ; PUNCH12
  da PUNCH12

anim_punch2
 dfb 2
 dfb $10
 dfb $00
 dfb $0A,$28,6       ; PUNCH21
  da PUNCH21
 dfb $10,$28,6       ; PUNCH22
  da PUNCH22

anim_bpunched
 dfb 1
 dfb $0B
 dfb $00
 dfb $0B,$28,5       ; BPUNCHED
  da BPUNCHED

anim_wpunched
 dfb 1
 dfb $09
 dfb $00
 dfb $09,$28,5       ; WPUNCHED
  da WPUNCHED

anim_wfall
 dfb 2
 dfb $14
 dfb $00
 dfb $14,$23,3       ; WFALL
  da WFALL
 dfb $12,$0F,30      ; WFALLEN
  da WFALLEN

anim_bfall
 dfb 1
 dfb $09
 dfb $00
 dfb $09,$28,33      ; IMAGE01 (placeholder)
  da IMAGE01

* Roper animations
anim_rpunched
 dfb 1
 dfb $09
 dfb $00
 dfb $09,$26,5       ; RPUNCHED: 9 wide, 38 tall, 5 VBLs
  da RPUNCHED

anim_rfall
 dfb 2
 dfb $10
 dfb $00
 dfb $10,$17,3       ; RFALL1: 16 wide, 23 tall, 3 VBLs
  da RFALL1
 dfb $10,$0F,60      ; RFALL2: 16 wide, 15 tall, 60 VBLs
  da RFALL2

* Linda Lash animations
anim_lpunched
 dfb 1
 dfb $09
 dfb $00
 dfb $08,$26,5       ; LPUNCHED: 8 wide, 38 tall, 5 VBLs
  da LPUNCHED

anim_lfall
 dfb 2
 dfb $11
 dfb $00
 dfb $10,$17,3       ; LFALL1: 16 wide, 23 tall, 3 VBLs
  da LFALL1
 dfb $11,$0F,60      ; LFALL2: 17 wide, 15 tall, 60 VBLs
  da LFALL2

*==========================================================
* Sprite info blocks
* See CLAUDE.md for full field layout (48+ bytes each)
*==========================================================

billy_sprite
 hex 6400             ; +0  ypos
 hex 0100             ; +2  xpos
 hex 0000             ; +4  mirror
 hex 0000             ; +6  (unused)
 hex 0500             ; +8  (unused)
 hex 0900             ; +10 frame_x (IMAGE01)
 hex 2800             ; +12 frame_y (IMAGE01)
  da IMAGE01           ; +14 frame_addr
 hex 6600             ; +16 mask
 hex 6000             ; +18 maskhi
 hex 0600             ; +20 masklo
 hex 0100             ; +22 controller (keyboard)
 hex 0000             ; +24 anim_ptr
 hex 0000             ; +26 anim_frame
 hex 0000             ; +28 anim_timer
 hex 0100             ; +30 dirty
 hex 6400             ; +32 prev_ypos
 hex 0100             ; +34 prev_xpos
 hex 0900             ; +36 prev_frame_x
 hex 2800             ; +38 prev_frame_y
 da anim_bpunched     ; +40 punched_anim
  da IMAGE01           ; +42 idle_addr
 hex 0900             ; +44 idle_x
 hex 2800             ; +46 idle_y
 hex 0000             ; +48 punch_count
 da anim_bfall        ; +50 fall_anim

william_sprite
 hex 5F00             ; +0  ypos
 hex 5800             ; +2  xpos
 hex 0100             ; +4  mirror
 hex 0000             ; +6  (unused)
 hex 0500             ; +8  (unused)
 hex 0900             ; +10 frame_x (WILLIAM1)
 hex 2800             ; +12 frame_y (WILLIAM1)
  da WILLIAM1          ; +14 frame_addr
 hex EE00             ; +16 mask
 hex E000             ; +18 maskhi
 hex 0E00             ; +20 masklo
 hex 0000             ; +22 controller (NPC)
 hex 0000             ; +24 anim_ptr
 hex 0000             ; +26 anim_frame
 hex 0000             ; +28 anim_timer
 hex 0100             ; +30 dirty
 hex 5F00             ; +32 prev_ypos
 hex 5800             ; +34 prev_xpos
 hex 0900             ; +36 prev_frame_x
 hex 2800             ; +38 prev_frame_y
 da anim_wpunched     ; +40 punched_anim
  da WILLIAM1          ; +42 idle_addr
 hex 0900             ; +44 idle_x
 hex 2800             ; +46 idle_y
 hex 0000             ; +48 punch_count
 da anim_wfall        ; +50 fall_anim

william2_sprite
 hex 8400             ; +0  ypos
 hex 5800             ; +2  xpos
 hex 0100             ; +4  mirror
 hex 0000             ; +6  (unused)
 hex 0500             ; +8  (unused)
 hex 0900             ; +10 frame_x (WILLIAM1)
 hex 2800             ; +12 frame_y (WILLIAM1)
  da WILLIAM1          ; +14 frame_addr
 hex EE00             ; +16 mask
 hex E000             ; +18 maskhi
 hex 0E00             ; +20 masklo
 hex 0000             ; +22 controller (NPC)
 hex 0000             ; +24 anim_ptr
 hex 0000             ; +26 anim_frame
 hex 0000             ; +28 anim_timer
 hex 0100             ; +30 dirty
 hex 8400             ; +32 prev_ypos
 hex 5800             ; +34 prev_xpos
 hex 0900             ; +36 prev_frame_x
 hex 2800             ; +38 prev_frame_y
 da anim_wpunched     ; +40 punched_anim
  da WILLIAM1          ; +42 idle_addr
 hex 0900             ; +44 idle_x
 hex 2800             ; +46 idle_y
 hex 0000             ; +48 punch_count
 da anim_wfall        ; +50 fall_anim

roper_sprite
 hex 5F00             ; +0  ypos
 hex 5800             ; +2  xpos
 hex 0100             ; +4  mirror
 hex 0000             ; +6  (unused/behavior)
 hex 0000             ; +8  (unused/behavior_state)
 hex 0900             ; +10 frame_x (ROPER1)
 hex 2700             ; +12 frame_y (ROPER1)
  da ROPER1            ; +14 frame_addr
 hex EE00             ; +16 mask
 hex E000             ; +18 maskhi
 hex 0E00             ; +20 masklo
 hex 0000             ; +22 controller (NPC)
 hex 0000             ; +24 anim_ptr
 hex 0000             ; +26 anim_frame
 hex 0000             ; +28 anim_timer
 hex 0100             ; +30 dirty
 hex 5F00             ; +32 prev_ypos
 hex 5800             ; +34 prev_xpos
 hex 0900             ; +36 prev_frame_x
 hex 2700             ; +38 prev_frame_y
 da anim_rpunched     ; +40 punched_anim
  da ROPER1            ; +42 idle_addr
 hex 0900             ; +44 idle_x
 hex 2700             ; +46 idle_y
 hex 0000             ; +48 punch_count
 da anim_rfall        ; +50 fall_anim

linda_sprite
 hex 5F00             ; +0  ypos
 hex 5800             ; +2  xpos
 hex 0100             ; +4  mirror
 hex 0000             ; +6  (unused/behavior)
 hex 0000             ; +8  (unused/behavior_state)
 hex 0900             ; +10 frame_x (LINDA1)
 hex 2800             ; +12 frame_y (LINDA1)
  da LINDA1            ; +14 frame_addr
 hex EE00             ; +16 mask
 hex E000             ; +18 maskhi
 hex 0E00             ; +20 masklo
 hex 0000             ; +22 controller (NPC)
 hex 0000             ; +24 anim_ptr
 hex 0000             ; +26 anim_frame
 hex 0000             ; +28 anim_timer
 hex 0100             ; +30 dirty
 hex 5F00             ; +32 prev_ypos
 hex 5800             ; +34 prev_xpos
 hex 0900             ; +36 prev_frame_x
 hex 2800             ; +38 prev_frame_y
 da anim_lpunched     ; +40 punched_anim
  da LINDA1            ; +42 idle_addr
 hex 0900             ; +44 idle_x
 hex 2800             ; +46 idle_y
 hex 0000             ; +48 punch_count
 da anim_lfall        ; +50 fall_anim

*-------------------------------
* Burnov (Mission 1 boss). Pixel data lives in bank $06
* (mission12.s), not $02, so the template's idle_addr (+42),
* frame_addr (+14), and the anim pointers (+40, +50) carry a
* sentinel value of $0000. script_spawn_npc detects this and
* substitutes the real bank-$19 addresses from the spr_bn*
* cache vars (populated by init_mission12), plus sets
* frame_bank (+56) to $0019.
* Mask color is $EE — the "$E" nibble surrounding Burnov's
* body in the bank-$19 sprite data.
*-------------------------------
burnov_sprite
 hex 5F00             ; +0  ypos
 hex 5800             ; +2  xpos
 hex 0100             ; +4  mirror
 hex 0000             ; +6  (unused/behavior)
 hex 0000             ; +8  (unused/behavior_state)
 hex 0D00             ; +10 frame_x = 13 (BNWALK1)
 hex 3000             ; +12 frame_y = 48 (BNWALK1)
 hex 0000             ; +14 frame_addr  (sentinel — patched runtime)
 hex EE00             ; +16 mask = $EE
 hex E000             ; +18 maskhi
 hex 0E00             ; +20 masklo
 hex 0000             ; +22 controller (NPC)
 hex 0000             ; +24 anim_ptr
 hex 0000             ; +26 anim_frame
 hex 0000             ; +28 anim_timer
 hex 0100             ; +30 dirty
 hex 5F00             ; +32 prev_ypos
 hex 5800             ; +34 prev_xpos
 hex 0D00             ; +36 prev_frame_x
 hex 3000             ; +38 prev_frame_y
 hex 0000             ; +40 punched_anim (sentinel — patched runtime)
 hex 0000             ; +42 idle_addr   (sentinel: $0000 = Burnov)
 hex 0D00             ; +44 idle_x
 hex 3000             ; +46 idle_y
 hex 0000             ; +48 punch_count
 hex 0000             ; +50 fall_anim   (sentinel — patched runtime)

*-------------------------------
* Linda with flail (mission12 / bank $19). Walks with LFWALK1-3
* and her attack is the LMACE1-3 mace-swing instead of a punch.
* Sentinel idle_addr = $0001 distinguishes her from Burnov ($0000)
* in script_spawn_npc's bank-$19 dispatch. Real bank-$02 sprite
* idle_addrs always have a non-zero high byte (mission1's data
* lives above $0100), so any low value with hi=0 is reserved for
* bank-$19 NPC sentinels.
* Mask color is $EE (regular Linda's mask, since the bank-$19
* sprite data uses the same $E surround as bank-$02 Linda).
*-------------------------------
linda_flail_sprite
 hex 5F00             ; +0  ypos
 hex 5800             ; +2  xpos
 hex 0100             ; +4  mirror
 hex 0000             ; +6
 hex 0000             ; +8
 hex 0900             ; +10 frame_x = 9 (LFWALK1)
 hex 2800             ; +12 frame_y = 40
 hex 0000             ; +14 frame_addr (sentinel — patched runtime)
 hex EE00             ; +16 mask = $EE
 hex E000             ; +18 maskhi
 hex 0E00             ; +20 masklo
 hex 0000             ; +22 controller (NPC)
 hex 0000             ; +24 anim_ptr
 hex 0000             ; +26 anim_frame
 hex 0000             ; +28 anim_timer
 hex 0100             ; +30 dirty
 hex 5F00             ; +32 prev_ypos
 hex 5800             ; +34 prev_xpos
 hex 0900             ; +36 prev_frame_x
 hex 2800             ; +38 prev_frame_y
 hex 0000             ; +40 punched_anim (sentinel — patched runtime)
 hex 0100             ; +42 idle_addr — sentinel: $0001 = linda_flail
 hex 0900             ; +44 idle_x
 hex 2800             ; +46 idle_y
 hex 0000             ; +48 punch_count
 hex 0000             ; +50 fall_anim (sentinel — patched runtime)

*==========================================================
* Ladder definitions (world-absolute byte coordinates)
* count byte, then per ladder:
*   x_left (2 bytes, world byte), x_right (2 bytes, world byte),
*   y_top (1 byte), y_bottom (1 byte) = 6 bytes per ladder
* World byte 1 = 2 pixels in 320 mode, so abs pixel 640 = byte 320.
*==========================================================
ladders dfb 3                   ; ladder count
* Ladder 1: Linda descends to screen 3 (lower level).
 dw 348                         ; x_left (world byte)
 dw 355                         ; x_right
 dfb 0,68                       ; y_top=0, y_bottom=68
* Ladder 2: screen 7 far right → screen 10 above.
* Screen 7 spans world bytes 440..549 (UP_X_ANCHOR=330 + 110 for
* screen 5, then +110 for its right neighbor screen 7). Best
* guess for "far right" = screen 7 bytes ~90..97 = world 530..537.
* Verify with draw_ladder_debug outline and adjust if needed.
 dw 453                         ; x_left (screen 7 byte 90)
 dw 460                         ; x_right
 dfb 0,59                       ; y_top=0, y_bottom=59
* Ladder 3: screen 12 → screen 10 above.
* Visible scr9 ladder art is centered at world ~321 (col 25 with
* wo=296). Bounds are asymmetric (319..331, width 12, center=325)
* so the snap formula center stays at 325 — formula gives
* 325-296-3 = 26, with -5 scr12 nudge → xpos=21 (Billy center
* col 25, on visible). x_left=319 widens the left side so
* check_ladder accepts swx=317 (xpos=21, with LADDER_TOL=2).
 dw 319                         ; x_left  (center=325, 12-byte wide bounds)
 dw 331                         ; x_right
 dfb 0,68                       ; y_top=0, y_bottom=68

*==========================================================
* Per-screen Y bounds tables
* 200 entries x 2 bytes (min_x, max_x) per screen.
* max_x=0 means the row is blocked.
*==========================================================
bounds_ptrs
 dw bounds_scr0
 dw bounds_scr1
 dw bounds_scr2
 dw bounds_scr3
 dw bounds_scr4
 dw bounds_scr5
 dw bounds_scr6
 dw bounds_scr7
 dw bounds_scr8
 dw bounds_scr9
 dw bounds_scr10
 dw bounds_scr11
 dw bounds_scr12
 dw bounds_scr13

* Screen 0: y<83 blocked, y=83-199 full playfield
bounds_scr0
 LUP 83
 dfb 0,0
 --^
 LUP 117
 dfb 0,109
 --^

* Screen 1: boxes form an isometric angle
bounds_scr1
 LUP 40
 dfb 0,0
 --^
 dfb $30,109
 dfb $2f,109
 dfb $2e,109
 dfb $2d,109
 dfb $2c,109
 dfb $2b,109
 dfb $2a,109
 dfb $29,109
 dfb $28,109
 dfb $27,109
 dfb $26,109
 dfb $25,109
 dfb $24,109
 dfb $23,109
 dfb $22,109
 dfb $21,109
 dfb $20,109
 dfb $1F,109
 dfb $1E,109
 dfb $1D,109
 dfb $1C,109
 dfb $1B,109
 dfb $1A,109
 dfb $19,109
 dfb $18,109
 dfb $17,109
 dfb $16,109
 dfb $15,109
 dfb $14,109
 dfb $13,109
 dfb $12,109
 dfb $11,109
 dfb $10,109
 dfb $0F,109
 dfb $0E,109
 dfb $0D,109
 dfb $0C,109
 dfb $0B,109
 dfb $0A,109
 dfb $09,109
 dfb $08,109
 dfb $07,109
 dfb $06,109
 dfb $05,109
 dfb $04,109
 dfb $03,109
 dfb $02,109
 dfb $01,109
 dfb $00,109
 LUP 111
 dfb 0,109
 --^

* Screen 2: rows 0-39 blocked, rows 40-68 a rising bmax staircase
* (bmax $30 → $4C, +1 per row), rows 69-199 fully walkable.
bounds_scr2
 LUP 40
 dfb 0,0
 --^
 dfb 0,$30
 dfb 0,$31
 dfb 0,$32
 dfb 0,$33
 dfb 0,$34
 dfb 0,$35
 dfb 0,$36
 dfb 0,$37
 dfb 0,$38
 dfb 0,$39
 dfb 0,$3A
 dfb 0,$3B
 dfb 0,$3C
 dfb 0,$3D
 dfb 0,$3E
 dfb 0,$3F
 dfb 0,$40
 dfb 0,$41
 dfb 0,$42
 dfb 0,$43
 dfb 0,$44
 dfb 0,$45
 dfb 0,$46
 dfb 0,$47
 dfb 0,$48
 dfb 0,$49
 dfb 0,$4A
 dfb 0,$4B
 dfb 0,$4C
 LUP 131
 dfb 0,109
 --^

* Screen 3: rows 0-68 blocked, rows 69-199 fully walkable.
bounds_scr3
 LUP 69
 dfb 0,0
 --^
 LUP 131
 dfb 0,109
 --^

* Screen 4: rows 0-68 blocked, rows 69-199 fully walkable.
bounds_scr4
 LUP 69
 dfb 0,0
 --^
 LUP 131
 dfb 0,109
 --^

* Screen 5 (upper level): purple platform at top of first ladder.
* Walkable ypos=53..130 (78 rows). Covers both the platform
* (ypos=53..87) and the ladder-top "landing" range so snap
* preserve-ypos logic doesn't fall back to the bottom of walkable
* and teleport Billy after the scroll.
* Screen 5:
*   y=$00-$29: blocked (0,0)
*   y=$2A-$3B: ($32,109) — right-side platform
*   y=$3C-$47: (0,109)   — full-width corridor
*   y=$48-$57: (0,$3C)   — left-side ledge w/ right wall (ends at $57)
*   y=$58-$C7: blocked (0,0)
bounds_scr5
 LUP 42
 dfb 0,0
 --^
 LUP 18
 dfb $32,109
 --^
 LUP 12
 dfb 0,109
 --^
 LUP 16
 dfb 0,$3C
 --^
 LUP 112
 dfb 0,0
 --^

* Screen 6: walkable band y=$2A-$47 only.
bounds_scr6
 LUP 42
 dfb 0,0
 --^
 LUP 30
 dfb 0,109
 --^
 LUP 128
 dfb 0,0
 --^

* Screen 7: same as screen6
bounds_scr7
 LUP 42
 dfb 0,0
 --^
 LUP 30
 dfb 0,109
 --^
 LUP 128
 dfb 0,0
 --^

* Screen 8: High platform, no Y movement
bounds_scr8
 LUP 47
 dfb 0,0
 --^
 LUP 1
 dfb 0,109
 --^
 LUP 152
 dfb 0,0
 --^

* Screen 9: High platform, no Y movement
bounds_scr9
 LUP 47
 dfb 0,0
 --^
 LUP 1
 dfb 0,109
 --^
 LUP 152
 dfb 0,0
 --^

* Screen 10: High platform, no Y movement
bounds_scr10
 LUP 47
 dfb 0,0
 --^
 LUP 1
 dfb 0,109
 --^
 LUP 152
 dfb 0,0
 --^

* Screens 11-13: Top of level
bounds_scr11
 LUP 52
 dfb 0,0
 --^
 LUP 28
 dfb 0,109
 --^
 LUP 120
 dfb 0,0
 --^

bounds_scr12
 LUP 52
 dfb 0,0
 --^
 LUP 28
 dfb 0,109
 --^
 LUP 120
 dfb 0,0
 --^

bounds_scr13
 LUP 32
 dfb 0,0
 --^
 LUP 48
 dfb 0,109
 --^
 LUP 120
 dfb 0,0
 --^

*==========================================================
* Sprite pixel data
*==========================================================
**
** BILLY sprites (note mask color is 6)
**

* Walk frames — compiled for AND/ORA pipeline (transparent nibble = $6).
* Generated via tools/compile_sprite.py. Old `IMAGE0N` references in
* dead descriptors (anim_walk, anim_bfall, mission1.s billy_sprite) are
* aliased to the _DATA arrays so they still resolve at assembly time.
IMAGE01 EQU IMAGE01_DATA
IMAGE02 EQU IMAGE02_DATA
IMAGE03 EQU IMAGE03_DATA

IMAGE01_X HEX 0900
IMAGE01_Y HEX 2800

IMAGE01_DATA
 HEX 0000000000FFFFFF00
 HEX 000000000FFFF2F2FF
 HEX 00000000FF0F0FFF2F
 HEX 00000000FF000F0FFF
 HEX 00000000FF0F000FF0
 HEX 00000000FF0F2F0000
 HEX 00000000F00F00F000
 HEX 00000000F0F22F2000
 HEX 0000000000F22F0000
 HEX 00000F2F000FFF0000
 HEX 0000F222F000000000
 HEX 00002222F000F22000
 HEX 00002222F00F222200
 HEX 0000F222000F222200
 HEX 0000F22F00FFF22200
 HEX 00000F202222FFF000
 HEX 000000222222000000
 HEX 00000022222F000000
 HEX 000000F22220A00000
 HEX 00000A0FFF0A000000
 HEX 0000000000AA000000
 HEX 000000AA999A000000
 HEX 00000AAA0AA0000000
 HEX 00000AAAA000000000
 HEX 00000AA99AA0000000
 HEX 00000AAA99A0000000
 HEX 000000AAA99A000000
 HEX 0000000AAA9A000000
 HEX 00000000AAAAA00000
 HEX 0000A0000AA9A00000
 HEX 0000AA000099A00000
 HEX 00000000000A000000
 HEX 000222200022F00000
 HEX 000222000022200000
 HEX 00F2200000F2200000
 HEX 00F200000002200000
 HEX 0F2F0000000FF00000
 HEX 0F2220000002220000
 HEX 00F222000002F22200
 HEX 000000000000000000

IMAGE01_MASK
 HEX FFFFFFFFF0000000FF
 HEX FFFFFFFF0000000000
 HEX FFFFFFFF0000000000
 HEX FFFFFFF00000000000
 HEX FFFFFFF0000000000F
 HEX FFFFFFF0000000000F
 HEX FFFFFFF000000000FF
 HEX FFFFFFF000000000FF
 HEX FFFFF00000000000FF
 HEX FFFF00000000000FFF
 HEX FFF000000000000FFF
 HEX FFF0000000000000FF
 HEX FFF00000000000000F
 HEX FFF00000000000000F
 HEX FFF00000000000000F
 HEX FFF0000000000000FF
 HEX FFFF0000000000FFFF
 HEX FFFF0000000000FFFF
 HEX FFFF0000000000FFFF
 HEX FFFF000000000FFFFF
 HEX FFFFF00000000FFFFF
 HEX FFFFF00000000FFFFF
 HEX FFFF0000000000FFFF
 HEX FFFF0000000000FFFF
 HEX FFFF000000000FFFFF
 HEX FFFF000000000FFFFF
 HEX FFFF000000000FFFFF
 HEX FFFF000000000FFFFF
 HEX FFF00000000000FFFF
 HEX FFF00000000000FFFF
 HEX FF000000F00000FFFF
 HEX FF000000F00000FFFF
 HEX FF000000F00000FFFF
 HEX FF00000FF00000FFFF
 HEX F00000FFF00000FFFF
 HEX F0000FFFFF0000FFFF
 HEX 00000FFFFF0000FFFF
 HEX 000000FFFF000000FF
 HEX F000000FFF0000000F
 HEX FF00000FFF0000000F

IMAGE01_DATA_MIRROR
 HEX 00FFFFFF0000000000
 HEX FF2F2FFFF000000000
 HEX F2FFF0F0FF00000000
 HEX FFF0F000FF00000000
 HEX 0FF000F0FF00000000
 HEX 0000F2F0FF00000000
 HEX 000F00F00F00000000
 HEX 0002F22F0F00000000
 HEX 0000F22F0000000000
 HEX 0000FFF000F2F00000
 HEX 000000000F222F0000
 HEX 00022F000F22220000
 HEX 002222F00F22220000
 HEX 002222F000222F0000
 HEX 00222FFF00F22F0000
 HEX 000FFF222202F00000
 HEX 000000222222000000
 HEX 000000F22222000000
 HEX 00000A02222F000000
 HEX 000000A0FFF0A00000
 HEX 000000AA0000000000
 HEX 000000A999AA000000
 HEX 0000000AA0AAA00000
 HEX 000000000AAAA00000
 HEX 0000000AA99AA00000
 HEX 0000000A99AAA00000
 HEX 000000A99AAA000000
 HEX 000000A9AAA0000000
 HEX 00000AAAAA00000000
 HEX 00000A9AA0000A0000
 HEX 00000A990000AA0000
 HEX 000000A00000000000
 HEX 00000F220002222000
 HEX 000002220000222000
 HEX 0000022F0000022F00
 HEX 000002200000002F00
 HEX 00000FF0000000F2F0
 HEX 0000222000000222F0
 HEX 00222F200000222F00
 HEX 000000000000000000

IMAGE01_MASK_MIRROR
 HEX FF0000000FFFFFFFFF
 HEX 0000000000FFFFFFFF
 HEX 0000000000FFFFFFFF
 HEX 00000000000FFFFFFF
 HEX F0000000000FFFFFFF
 HEX F0000000000FFFFFFF
 HEX FF000000000FFFFFFF
 HEX FF000000000FFFFFFF
 HEX FF00000000000FFFFF
 HEX FFF00000000000FFFF
 HEX FFF000000000000FFF
 HEX FF0000000000000FFF
 HEX F00000000000000FFF
 HEX F00000000000000FFF
 HEX F00000000000000FFF
 HEX FF0000000000000FFF
 HEX FFFF0000000000FFFF
 HEX FFFF0000000000FFFF
 HEX FFFF0000000000FFFF
 HEX FFFFF000000000FFFF
 HEX FFFFF00000000FFFFF
 HEX FFFFF00000000FFFFF
 HEX FFFF0000000000FFFF
 HEX FFFF0000000000FFFF
 HEX FFFFF000000000FFFF
 HEX FFFFF000000000FFFF
 HEX FFFFF000000000FFFF
 HEX FFFFF000000000FFFF
 HEX FFFF00000000000FFF
 HEX FFFF00000000000FFF
 HEX FFFF00000F000000FF
 HEX FFFF00000F000000FF
 HEX FFFF00000F000000FF
 HEX FFFF00000FF00000FF
 HEX FFFF00000FFF00000F
 HEX FFFF0000FFFFF0000F
 HEX FFFF0000FFFFF00000
 HEX FF000000FFFF000000
 HEX F0000000FFF000000F
 HEX F0000000FFF00000FF

IMAGE02_X HEX 0800
IMAGE02_Y HEX 2800

IMAGE02_DATA
 HEX 00000000FFFFFF00
 HEX 0000000FFFF2F2FF
 HEX 000000FF0F0FFF2F
 HEX 000000FF000F0FFF
 HEX 000000FF0F000FF0
 HEX 000000FF0F2F0000
 HEX 000000F00F00F000
 HEX 000000F0F22F2000
 HEX 00000000F22F0000
 HEX 000F2F000FFF0000
 HEX 00F222F000000000
 HEX 002222F000F22000
 HEX 002222F00F222200
 HEX 00F222000F222200
 HEX 00F22F00FFF22200
 HEX 000F202222FFF000
 HEX 0000222222000000
 HEX 000022222F000000
 HEX 0000F22220A00000
 HEX 000A0FFF0A000000
 HEX 00000000AA000000
 HEX 0000AA999A000000
 HEX 000AAA0AA0000000
 HEX 000AAAA00A000000
 HEX 000A99A00A000000
 HEX 000AA9900A000000
 HEX 000AA99A0A000000
 HEX 0000AA9A00000000
 HEX 0000AAAAA0000000
 HEX 000000A9A0000000
 HEX 00000A99A0000000
 HEX 0000000000000000
 HEX 0000222F00000000
 HEX 000022F000000000
 HEX 00022F0000000000
 HEX 00FF20F000000000
 HEX 0022F0F000000000
 HEX 00022F0200000000
 HEX 000022F020000000
 HEX 0000000000000000

IMAGE02_MASK
 HEX FFFFFFF0000000FF
 HEX FFFFFF0000000000
 HEX FFFFFF0000000000
 HEX FFFFF00000000000
 HEX FFFFF0000000000F
 HEX FFFFF0000000000F
 HEX FFFFF000000000FF
 HEX FFFFF000000000FF
 HEX FFF00000000000FF
 HEX FF00000000000FFF
 HEX F000000000000FFF
 HEX F0000000000000FF
 HEX F00000000000000F
 HEX F00000000000000F
 HEX F00000000000000F
 HEX F0000000000000FF
 HEX FF00000000000FFF
 HEX FF0000000000FFFF
 HEX FF0000000000FFFF
 HEX FF000000000FFFFF
 HEX FFF00000000FFFFF
 HEX FFF00000000FFFFF
 HEX FF000000000FFFFF
 HEX FF000000000FFFFF
 HEX FF000000000FFFFF
 HEX FF000000000FFFFF
 HEX FF000000000FFFFF
 HEX FF000000000FFFFF
 HEX FFF00000000FFFFF
 HEX FFF00000000FFFFF
 HEX FFFF0000000FFFFF
 HEX FFFF0000000FFFFF
 HEX FFF0000000FFFFFF
 HEX FFF000000FFFFFFF
 HEX FF000000FFFFFFFF
 HEX F0000000FFFFFFFF
 HEX F0000000FFFFFFFF
 HEX FF0000000FFFFFFF
 HEX FFF0000000FFFFFF
 HEX FFFF000000FFFFFF

IMAGE02_DATA_MIRROR
 HEX 00FFFFFF00000000
 HEX FF2F2FFFF0000000
 HEX F2FFF0F0FF000000
 HEX FFF0F000FF000000
 HEX 0FF000F0FF000000
 HEX 0000F2F0FF000000
 HEX 000F00F00F000000
 HEX 0002F22F0F000000
 HEX 0000F22F00000000
 HEX 0000FFF000F2F000
 HEX 000000000F222F00
 HEX 00022F000F222200
 HEX 002222F00F222200
 HEX 002222F000222F00
 HEX 00222FFF00F22F00
 HEX 000FFF222202F000
 HEX 0000002222220000
 HEX 000000F222220000
 HEX 00000A02222F0000
 HEX 000000A0FFF0A000
 HEX 000000AA00000000
 HEX 000000A999AA0000
 HEX 0000000AA0AAA000
 HEX 000000A00AAAA000
 HEX 000000A00A99A000
 HEX 000000A0099AA000
 HEX 000000A0A99AA000
 HEX 00000000A9AA0000
 HEX 0000000AAAAA0000
 HEX 0000000A9A000000
 HEX 0000000A99A00000
 HEX 0000000000000000
 HEX 00000000F2220000
 HEX 000000000F220000
 HEX 0000000000F22000
 HEX 000000000F02FF00
 HEX 000000000F0F2200
 HEX 0000000020F22000
 HEX 000000020F220000
 HEX 0000000000000000

IMAGE02_MASK_MIRROR
 HEX FF0000000FFFFFFF
 HEX 0000000000FFFFFF
 HEX 0000000000FFFFFF
 HEX 00000000000FFFFF
 HEX F0000000000FFFFF
 HEX F0000000000FFFFF
 HEX FF000000000FFFFF
 HEX FF000000000FFFFF
 HEX FF00000000000FFF
 HEX FFF00000000000FF
 HEX FFF000000000000F
 HEX FF0000000000000F
 HEX F00000000000000F
 HEX F00000000000000F
 HEX F00000000000000F
 HEX FF0000000000000F
 HEX FFF00000000000FF
 HEX FFFF0000000000FF
 HEX FFFF0000000000FF
 HEX FFFFF000000000FF
 HEX FFFFF00000000FFF
 HEX FFFFF00000000FFF
 HEX FFFFF000000000FF
 HEX FFFFF000000000FF
 HEX FFFFF000000000FF
 HEX FFFFF000000000FF
 HEX FFFFF000000000FF
 HEX FFFFF000000000FF
 HEX FFFFF00000000FFF
 HEX FFFFF00000000FFF
 HEX FFFFF0000000FFFF
 HEX FFFFF0000000FFFF
 HEX FFFFFF0000000FFF
 HEX FFFFFFF000000FFF
 HEX FFFFFFFF000000FF
 HEX FFFFFFFF0000000F
 HEX FFFFFFFF0000000F
 HEX FFFFFFF0000000FF
 HEX FFFFFF0000000FFF
 HEX FFFFFF000000FFFF

IMAGE03_X HEX 0B00
IMAGE03_Y HEX 2800

IMAGE03_DATA
 HEX 000000000000FFFFFF0000
 HEX 00000000000FFFF2F2FF00
 HEX 0000000000FF0F0FFF2F00
 HEX 0000000000FF000F0FFF00
 HEX 0000000000FF0F000FF000
 HEX 0000000000FF0F2F000000
 HEX 0000000000F00F00F00000
 HEX 0000000000F0F22F200000
 HEX 000000000000F22F000000
 HEX 0000000F2F000FFF000000
 HEX 000000F222F00000000000
 HEX 0000002222F000F2200000
 HEX 0000002222F00F22220000
 HEX 000000F222000F22220000
 HEX 000000F22F00FFF2220000
 HEX 0000000F202222FFF00000
 HEX 0000000022222200000000
 HEX 0000000022222F00000000
 HEX 00000000F22220A0000000
 HEX 0000000A0FFF0A00000000
 HEX 000000000000AA00000000
 HEX 00000000AA999A00000000
 HEX 0000000AAA0AA000000000
 HEX 0000000AAAA00000000000
 HEX 0000000A99A00A9A000000
 HEX 000000AA99A0AA99000000
 HEX 000000A99A000AA9A00000
 HEX 000000A99A0000AA900000
 HEX 000000AAA00000AAAA0000
 HEX 00000A99A000000A990000
 HEX 00000A9A0000000AAA0000
 HEX 0000000000000000A00000
 HEX 00002222000000022F0000
 HEX 0000222000000002220000
 HEX 000F22000000000F220000
 HEX 000F200000000000220000
 HEX 00F2F00000000000FF0000
 HEX 00F2220000000000222000
 HEX 000F2220000000002F2220
 HEX 0000000000000000000000

IMAGE03_MASK
 HEX FFFFFFFFFFF0000000FFFF
 HEX FFFFFFFFFF0000000000FF
 HEX FFFFFFFFFF0000000000FF
 HEX FFFFFFFFF00000000000FF
 HEX FFFFFFFFF0000000000FFF
 HEX FFFFFFFFF0000000000FFF
 HEX FFFFFFFFF000000000FFFF
 HEX FFFFFFFFF000000000FFFF
 HEX FFFFFFF00000000000FFFF
 HEX FFFFFF00000000000FFFFF
 HEX FFFFF000000000000FFFFF
 HEX FFFFF0000000000000FFFF
 HEX FFFFF00000000000000FFF
 HEX FFFFF00000000000000FFF
 HEX FFFFF00000000000000FFF
 HEX FFFFF0000000000000FFFF
 HEX FFFFFF0000000000FFFFFF
 HEX FFFFFF0000000000FFFFFF
 HEX FFFFFF0000000000FFFFFF
 HEX FFFFFF000000000FFFFFFF
 HEX FFFFFFF00000000FFFFFFF
 HEX FFFFFFF00000000FFFFFFF
 HEX FFFFFF0000000000FFFFFF
 HEX FFFFFF0000000000FFFFFF
 HEX FFFFF000000000000FFFFF
 HEX FFFFF000000000000FFFFF
 HEX FFFFF0000000000000FFFF
 HEX FFFFF000000F000000FFFF
 HEX FFFF000000FFF000000FFF
 HEX FFFF000000FFFF00000FFF
 HEX FFFF00000FFFFF00000FFF
 HEX FFFF00000FFFFF00000FFF
 HEX FFF000000FFFFF00000FFF
 HEX FFF00000FFFFFF00000FFF
 HEX FF00000FFFFFFF00000FFF
 HEX FF0000FFFFFFFFF0000FFF
 HEX F00000FFFFFFFFF0000FFF
 HEX F000000FFFFFFFF000000F
 HEX FF000000FFFFFFF0000000
 HEX FFF00000FFFFFFF0000000

IMAGE03_DATA_MIRROR
 HEX 0000FFFFFF000000000000
 HEX 00FF2F2FFFF00000000000
 HEX 00F2FFF0F0FF0000000000
 HEX 00FFF0F000FF0000000000
 HEX 000FF000F0FF0000000000
 HEX 000000F2F0FF0000000000
 HEX 00000F00F00F0000000000
 HEX 000002F22F0F0000000000
 HEX 000000F22F000000000000
 HEX 000000FFF000F2F0000000
 HEX 00000000000F222F000000
 HEX 0000022F000F2222000000
 HEX 00002222F00F2222000000
 HEX 00002222F000222F000000
 HEX 0000222FFF00F22F000000
 HEX 00000FFF222202F0000000
 HEX 0000000022222200000000
 HEX 00000000F2222200000000
 HEX 0000000A02222F00000000
 HEX 00000000A0FFF0A0000000
 HEX 00000000AA000000000000
 HEX 00000000A999AA00000000
 HEX 000000000AA0AAA0000000
 HEX 00000000000AAAA0000000
 HEX 000000A9A00A99A0000000
 HEX 00000099AA0A99AA000000
 HEX 00000A9AA000A99A000000
 HEX 000009AA0000A99A000000
 HEX 0000AAAA00000AAA000000
 HEX 000099A000000A99A00000
 HEX 0000AAA0000000A9A00000
 HEX 00000A0000000000000000
 HEX 0000F22000000022220000
 HEX 0000222000000002220000
 HEX 000022F00000000022F000
 HEX 000022000000000002F000
 HEX 0000FF00000000000F2F00
 HEX 0002220000000000222F00
 HEX 0222F2000000000222F000
 HEX 0000000000000000000000

IMAGE03_MASK_MIRROR
 HEX FFFF0000000FFFFFFFFFFF
 HEX FF0000000000FFFFFFFFFF
 HEX FF0000000000FFFFFFFFFF
 HEX FF00000000000FFFFFFFFF
 HEX FFF0000000000FFFFFFFFF
 HEX FFF0000000000FFFFFFFFF
 HEX FFFF000000000FFFFFFFFF
 HEX FFFF000000000FFFFFFFFF
 HEX FFFF00000000000FFFFFFF
 HEX FFFFF00000000000FFFFFF
 HEX FFFFF000000000000FFFFF
 HEX FFFF0000000000000FFFFF
 HEX FFF00000000000000FFFFF
 HEX FFF00000000000000FFFFF
 HEX FFF00000000000000FFFFF
 HEX FFFF0000000000000FFFFF
 HEX FFFFFF0000000000FFFFFF
 HEX FFFFFF0000000000FFFFFF
 HEX FFFFFF0000000000FFFFFF
 HEX FFFFFFF000000000FFFFFF
 HEX FFFFFFF00000000FFFFFFF
 HEX FFFFFFF00000000FFFFFFF
 HEX FFFFFF0000000000FFFFFF
 HEX FFFFFF0000000000FFFFFF
 HEX FFFFF000000000000FFFFF
 HEX FFFFF000000000000FFFFF
 HEX FFFF0000000000000FFFFF
 HEX FFFF000000F000000FFFFF
 HEX FFF000000FFF000000FFFF
 HEX FFF00000FFFF000000FFFF
 HEX FFF00000FFFFF00000FFFF
 HEX FFF00000FFFFF00000FFFF
 HEX FFF00000FFFFF000000FFF
 HEX FFF00000FFFFFF00000FFF
 HEX FFF00000FFFFFFF00000FF
 HEX FFF0000FFFFFFFFF0000FF
 HEX FFF0000FFFFFFFFF00000F
 HEX F000000FFFFFFFF000000F
 HEX 0000000FFFFFFF000000FF
 HEX 0000000FFFFFFF00000FFF

* Billy jump frames — compiled (transparent nibble = $6).
JUMP1 EQU JUMP1_DATA
JUMP2 EQU JUMP2_DATA
JUMP3 EQU JUMP3_DATA

JUMP1_Y HEX 2800
JUMP1_X HEX 0A00

JUMP1_DATA
 HEX 00000000000FFFFFF000
 HEX 0000000000FFFF2F2FF0
 HEX 000000000FF0F0FFF2F0
 HEX 000000000FF000F0FFF0
 HEX 000000000FF0F000FF00
 HEX 000000000FF0F2F00000
 HEX 000000000F00F00F0000
 HEX 000000000F0F22F20000
 HEX 00000000000F22F00000
 HEX 000000F2F000FFF00000
 HEX 00000F222F0000000000
 HEX 000002222F000F220000
 HEX 000002222F00F2222000
 HEX 00000F222000F2222000
 HEX 00000F22F00FFF222000
 HEX 000000F202222FFF0000
 HEX 00000002222220000000
 HEX 000000022222F0000000
 HEX 0000000F222200000000
 HEX 00000000FFF000000000
 HEX 000000AA0000AA900000
 HEX 000000AAA99A099A0000
 HEX 000000AA0000AAA9A000
 HEX 00000A99AA00AAA99A00
 HEX 00000A999A000AAA9A00
 HEX 00000A99AA0000AAAA00
 HEX 00000A99A000000AA000
 HEX 00000AAAA00000000000
 HEX 00000A99A00000000000
 HEX 0000AA9A009900000000
 HEX 0000AAA0000900000000
 HEX 00000000000000000000
 HEX 00022220000000000000
 HEX 00022200000000000000
 HEX 00F22000000000000000
 HEX 00F20000000000000000
 HEX 0F2F0000000000000000
 HEX 0F222000000000000000
 HEX 00F22200000000000000
 HEX 00000000000000000000

JUMP1_MASK
 HEX FFFFFFFFFF0000000FFF
 HEX FFFFFFFFF0000000000F
 HEX FFFFFFFFF0000000000F
 HEX FFFFFFFF00000000000F
 HEX FFFFFFFF0000000000FF
 HEX FFFFFFFF0000000000FF
 HEX FFFFFFFF000000000FFF
 HEX FFFFFFFF000000000FFF
 HEX FFFFFF00000000000FFF
 HEX FFFFF00000000000FFFF
 HEX FFFF000000000000FFFF
 HEX FFFF0000000000000FFF
 HEX FFFF00000000000000FF
 HEX FFFF00000000000000FF
 HEX FFFF00000000000000FF
 HEX FFFF0000000000000FFF
 HEX FFFFF0000000000FFFFF
 HEX FFFFF0000000000FFFFF
 HEX FFFFF0000000000FFFFF
 HEX FFFFF00000000000FFFF
 HEX FFFFF000000000000FFF
 HEX FFFFF0000000000000FF
 HEX FFFF00000000000000FF
 HEX FFFF000000000000000F
 HEX FFFF000000000000000F
 HEX FFFF000000000000000F
 HEX FFFF000000000000000F
 HEX FFFF00000000000000FF
 HEX FFF0000000000FFFFFFF
 HEX FFF0000000000FFFFFFF
 HEX FFF0000000000FFFFFFF
 HEX FFF000000FF00FFFFFFF
 HEX FF000000FFFFFFFFFFFF
 HEX FF00000FFFFFFFFFFFFF
 HEX F00000FFFFFFFFFFFFFF
 HEX F0000FFFFFFFFFFFFFFF
 HEX 00000FFFFFFFFFFFFFFF
 HEX 000000FFFFFFFFFFFFFF
 HEX F000000FFFFFFFFFFFFF
 HEX FF00000FFFFFFFFFFFFF

JUMP1_DATA_MIRROR
 HEX 000FFFFFF00000000000
 HEX 0FF2F2FFFF0000000000
 HEX 0F2FFF0F0FF000000000
 HEX 0FFF0F000FF000000000
 HEX 00FF000F0FF000000000
 HEX 00000F2F0FF000000000
 HEX 0000F00F00F000000000
 HEX 00002F22F0F000000000
 HEX 00000F22F00000000000
 HEX 00000FFF000F2F000000
 HEX 0000000000F222F00000
 HEX 000022F000F222200000
 HEX 0002222F00F222200000
 HEX 0002222F000222F00000
 HEX 000222FFF00F22F00000
 HEX 0000FFF222202F000000
 HEX 00000002222220000000
 HEX 0000000F222220000000
 HEX 000000002222F0000000
 HEX 000000000FFF00000000
 HEX 000009AA0000AA000000
 HEX 0000A990A99AAA000000
 HEX 000A9AAA0000AA000000
 HEX 00A99AAA00AA99A00000
 HEX 00A9AAA000A999A00000
 HEX 00AAAA0000AA99A00000
 HEX 000AA000000A99A00000
 HEX 00000000000AAAA00000
 HEX 00000000000A99A00000
 HEX 000000009900A9AA0000
 HEX 0000000090000AAA0000
 HEX 00000000000000000000
 HEX 00000000000002222000
 HEX 00000000000000222000
 HEX 00000000000000022F00
 HEX 00000000000000002F00
 HEX 0000000000000000F2F0
 HEX 000000000000000222F0
 HEX 00000000000000222F00
 HEX 00000000000000000000

JUMP1_MASK_MIRROR
 HEX FFF0000000FFFFFFFFFF
 HEX F0000000000FFFFFFFFF
 HEX F0000000000FFFFFFFFF
 HEX F00000000000FFFFFFFF
 HEX FF0000000000FFFFFFFF
 HEX FF0000000000FFFFFFFF
 HEX FFF000000000FFFFFFFF
 HEX FFF000000000FFFFFFFF
 HEX FFF00000000000FFFFFF
 HEX FFFF00000000000FFFFF
 HEX FFFF000000000000FFFF
 HEX FFF0000000000000FFFF
 HEX FF00000000000000FFFF
 HEX FF00000000000000FFFF
 HEX FF00000000000000FFFF
 HEX FFF0000000000000FFFF
 HEX FFFFF0000000000FFFFF
 HEX FFFFF0000000000FFFFF
 HEX FFFFF0000000000FFFFF
 HEX FFFF00000000000FFFFF
 HEX FFF000000000000FFFFF
 HEX FF0000000000000FFFFF
 HEX FF00000000000000FFFF
 HEX F000000000000000FFFF
 HEX F000000000000000FFFF
 HEX F000000000000000FFFF
 HEX F000000000000000FFFF
 HEX FF00000000000000FFFF
 HEX FFFFFFF0000000000FFF
 HEX FFFFFFF0000000000FFF
 HEX FFFFFFF0000000000FFF
 HEX FFFFFFF00FF000000FFF
 HEX FFFFFFFFFFFF000000FF
 HEX FFFFFFFFFFFFF00000FF
 HEX FFFFFFFFFFFFFF00000F
 HEX FFFFFFFFFFFFFFF0000F
 HEX FFFFFFFFFFFFFFF00000
 HEX FFFFFFFFFFFFFF000000
 HEX FFFFFFFFFFFFF000000F
 HEX FFFFFFFFFFFFF00000FF

JUMP2_Y HEX 1E00
JUMP2_X HEX 0F00

JUMP2_DATA
 HEX 000FFFFFF000000000000000000000
 HEX 00FFFF2F2FF0000000000000000000
 HEX 0FF0F0FFF2F0000000000000000000
 HEX 0FF000F0FFF0000000000000000000
 HEX 0FF0F000FF00000000000000000000
 HEX 0FF0F2F00000000000000000000000
 HEX 0F00F00F0000000000000000000000
 HEX 0F0F22F20000000000000000000000
 HEX 000F22F00000000000000000000000
 HEX 000FFF000F2F000000000000000000
 HEX 00000000F222F00000000000000000
 HEX 0022F000F222200000000000000000
 HEX 02222F00F222200000000000000000
 HEX 02222F000222F00000000000000000
 HEX 0222FFF00F22F00000000000000000
 HEX 00FFF222202F000000000000000000
 HEX 000002222220000000000000000000
 HEX 00000F222220000000000000000000
 HEX 0000002222F0A00000000000000000
 HEX 0020200FFF0AAAAA00000000000000
 HEX 00F020A000AA00999AA00000000000
 HEX 0020000AAAA00AA999AAAA00000000
 HEX 00FF00AA00000AAAAAA9A022F0F020
 HEX 00000FAAAA0000AAA0AAA0220FF020
 HEX 0000AA0000000000000AA02F0FF0F0
 HEX 0009AA022F0F0200000000000FF000
 HEX 00A9AA0220FF020000000000000000
 HEX 00AAAA02F0FF0F0000000000000000
 HEX 000AAA0000FF000000000000000000
 HEX 000000000000000000000000000000

JUMP2_MASK
 HEX FF0000000FFFFFFFFFFFFFFFFFFFFF
 HEX F0000000000FFFFFFFFFFFFFFFFFFF
 HEX F0000000000FFFFFFFFFFFFFFFFFFF
 HEX 00000000000FFFFFFFFFFFFFFFFFFF
 HEX 0000000000FFFFFFFFFFFFFFFFFFFF
 HEX 0000000000FFFFFFFFFFFFFFFFFFFF
 HEX 000000000FFFFFFFFFFFFFFFFFFFFF
 HEX 000000000FFFFFFFFFFFFFFFFFFFFF
 HEX F00000000000FFFFFFFFFFFFFFFFFF
 HEX FF00000000000FFFFFFFFFFFFFFFFF
 HEX FF000000000000FFFFFFFFFFFFFFFF
 HEX F0000000000000FFFFFFFFFFFFFFFF
 HEX 00000000000000FFFFFFFFFFFFFFFF
 HEX 00000000000000FFFFFFFFFFFFFFFF
 HEX 00000000000000FFFFFFFFFFFFFFFF
 HEX F0000000000000FFFFFFFFFFFFFFFF
 HEX FF00000000000FFFFFFFFFFFFFFFFF
 HEX FFF00000000000FFFFFFFFFFFFFFFF
 HEX FF00000000000000FFFFFFFFFFFFFF
 HEX F0000000000000000000FFFFFFFFFF
 HEX F000000000000000000000FFFFFFFF
 HEX F00000000000000000000000000000
 HEX F00000000000000000000000000000
 HEX FF0000000000000000000000000000
 HEX FF0000000000000000000000000000
 HEX F00000000000000FFF00000000000F
 HEX F00000000000000FFFFFFFFF000FFF
 HEX F00000000000000FFFFFFFFFFFFFFF
 HEX F0000000000000FFFFFFFFFFFFFFFF
 HEX FF00000FF000FFFFFFFFFFFFFFFFFF

JUMP2_DATA_MIRROR
 HEX 000000000000000000000FFFFFF000
 HEX 0000000000000000000FF2F2FFFF00
 HEX 0000000000000000000F2FFF0F0FF0
 HEX 0000000000000000000FFF0F000FF0
 HEX 00000000000000000000FF000F0FF0
 HEX 00000000000000000000000F2F0FF0
 HEX 0000000000000000000000F00F00F0
 HEX 00000000000000000000002F22F0F0
 HEX 00000000000000000000000F22F000
 HEX 000000000000000000F2F000FFF000
 HEX 00000000000000000F222F00000000
 HEX 000000000000000002222F000F2200
 HEX 000000000000000002222F00F22220
 HEX 00000000000000000F222000F22220
 HEX 00000000000000000F22F00FFF2220
 HEX 000000000000000000F202222FFF00
 HEX 000000000000000000022222200000
 HEX 000000000000000000022222F00000
 HEX 00000000000000000A0F2222000000
 HEX 00000000000000AAAAA0FFF0020200
 HEX 00000000000AA99900AA000A020F00
 HEX 00000000AAAA999AA00AAAA0000200
 HEX 020F0F220A9AAAAAA00000AA00FF00
 HEX 020FF0220AAA0AAA0000AAAAF00000
 HEX 0F0FF0F20AA0000000000000AA0000
 HEX 000FF0000000000020F0F220AA9000
 HEX 000000000000000020FF0220AA9A00
 HEX 0000000000000000F0FF0F20AAAA00
 HEX 000000000000000000FF0000AAA000
 HEX 000000000000000000000000000000

JUMP2_MASK_MIRROR
 HEX FFFFFFFFFFFFFFFFFFFFF0000000FF
 HEX FFFFFFFFFFFFFFFFFFF0000000000F
 HEX FFFFFFFFFFFFFFFFFFF0000000000F
 HEX FFFFFFFFFFFFFFFFFFF00000000000
 HEX FFFFFFFFFFFFFFFFFFFF0000000000
 HEX FFFFFFFFFFFFFFFFFFFF0000000000
 HEX FFFFFFFFFFFFFFFFFFFFF000000000
 HEX FFFFFFFFFFFFFFFFFFFFF000000000
 HEX FFFFFFFFFFFFFFFFFF00000000000F
 HEX FFFFFFFFFFFFFFFFF00000000000FF
 HEX FFFFFFFFFFFFFFFF000000000000FF
 HEX FFFFFFFFFFFFFFFF0000000000000F
 HEX FFFFFFFFFFFFFFFF00000000000000
 HEX FFFFFFFFFFFFFFFF00000000000000
 HEX FFFFFFFFFFFFFFFF00000000000000
 HEX FFFFFFFFFFFFFFFF0000000000000F
 HEX FFFFFFFFFFFFFFFFF00000000000FF
 HEX FFFFFFFFFFFFFFFF00000000000FFF
 HEX FFFFFFFFFFFFFF00000000000000FF
 HEX FFFFFFFFFF0000000000000000000F
 HEX FFFFFFFF000000000000000000000F
 HEX 00000000000000000000000000000F
 HEX 00000000000000000000000000000F
 HEX 0000000000000000000000000000FF
 HEX 0000000000000000000000000000FF
 HEX F00000000000FFF00000000000000F
 HEX FFF000FFFFFFFFF00000000000000F
 HEX FFFFFFFFFFFFFFF00000000000000F
 HEX FFFFFFFFFFFFFFFF0000000000000F
 HEX FFFFFFFFFFFFFFFFFF000FF00000FF

JUMP3_Y HEX 2000
JUMP3_X HEX 0D00

JUMP3_DATA
 HEX 000000000000000000FFFFFF00
 HEX 00000000000000000FFFF2F2FF
 HEX 0000000000000000FF0F0FFF2F
 HEX 0000000000000000FF000F0FFF
 HEX 0000000000000000FF0F000FF0
 HEX 0000000000000000FF0F2F0000
 HEX 0000000000000000F00F00F000
 HEX 0000000000000000F0F22F2000
 HEX 000000000000000000022F0000
 HEX 000000000000F2200F0F2F0000
 HEX 00000000000F22220000FF0000
 HEX 0000000000F222220F00000000
 HEX 000000000F22222202F0000000
 HEX 0000000002FF22F00220000000
 HEX 000000000F22F000F2F0000000
 HEX 000000000222F0002200000000
 HEX 00000000022220F00000000000
 HEX 000000000F22F0FF0000000000
 HEX 000000000FFF00000000000000
 HEX 000000000F222200099AAA0000
 HEX 000000000F202020AAAAA9A000
 HEX 0000000000202020AA0AA99000
 HEX 0000000000F0F0F00A0AA9A000
 HEX 0000000000000000000AAA0000
 HEX 000000000AAA00000000000000
 HEX 000000000A9A00000022200000
 HEX 000F20000A9AA0000F22000000
 HEX 00022F20AA9AA0000F2F000000
 HEX 00F22220AAAA00000FF0000000
 HEX 0F2F0F20AAAA00000222000000
 HEX 02F000000AA0000002F2220000
 HEX 00000000000000000000000000

JUMP3_MASK
 HEX FFFFFFFFFFFFFFFFF0000000FF
 HEX FFFFFFFFFFFFFFFF0000000000
 HEX FFFFFFFFFFFFFFFF0000000000
 HEX FFFFFFFFFFFFFFF00000000000
 HEX FFFFFFFFFFFFFFF0000000000F
 HEX FFFFFFFFFFFFFFF0000000000F
 HEX FFFFFFFFFFFFFFF000000000FF
 HEX FFFFFFFFFFFFFFF000000000FF
 HEX FFFFFFFFFFFF000000000000FF
 HEX FFFFFFFFFFF000000000000FFF
 HEX FFFFFFFFFF0000000000000FFF
 HEX FFFFFFFFF0000000000000FFFF
 HEX FFFFFFFF000000000000FFFFFF
 HEX FFFFFFFF000000000000FFFFFF
 HEX FFFFFFFF000000000000FFFFFF
 HEX FFFFFFFF00000000000FFFFFFF
 HEX FFFFFFFF0000000000FFFFFFFF
 HEX FFFFFFFF0000000000FFFFFFFF
 HEX FFFFFFFF00000000000000FFFF
 HEX FFFFFFFF000000000000000FFF
 HEX FFFFFFFF0000000000000000FF
 HEX FFFFFFFF0000000000000000FF
 HEX FFFFFFFF0000000000000000FF
 HEX FFFFFFFF0000000000000000FF
 HEX FFFFFFFF000000000000000FFF
 HEX FFF000FF0000000F000000FFFF
 HEX FF000000000000FF00000FFFFF
 HEX FF000000000000FF00000FFFFF
 HEX F000000000000FFF00000FFFFF
 HEX 0000000000000FFF000000FFFF
 HEX 0000000000000FFF0000000FFF
 HEX 000FFFF00000FFFF0000000FFF

JUMP3_DATA_MIRROR
 HEX 00FFFFFF000000000000000000
 HEX FF2F2FFFF00000000000000000
 HEX F2FFF0F0FF0000000000000000
 HEX FFF0F000FF0000000000000000
 HEX 0FF000F0FF0000000000000000
 HEX 0000F2F0FF0000000000000000
 HEX 000F00F00F0000000000000000
 HEX 0002F22F0F0000000000000000
 HEX 0000F220000000000000000000
 HEX 0000F2F0F0022F000000000000
 HEX 0000FF00002222F00000000000
 HEX 00000000F022222F0000000000
 HEX 0000000F20222222F000000000
 HEX 00000002200F22FF2000000000
 HEX 0000000F2F000F22F000000000
 HEX 0000000022000F222000000000
 HEX 00000000000F02222000000000
 HEX 0000000000FF0F22F000000000
 HEX 00000000000000FFF000000000
 HEX 0000AAA990002222F000000000
 HEX 000A9AAAAA020202F000000000
 HEX 00099AA0AA0202020000000000
 HEX 000A9AA0A00F0F0F0000000000
 HEX 0000AAA0000000000000000000
 HEX 00000000000000AAA000000000
 HEX 00000222000000A9A000000000
 HEX 00000022F0000AA9A00002F000
 HEX 000000F2F0000AA9AA02F22000
 HEX 0000000FF00000AAAA02222F00
 HEX 00000022200000AAAA02F0F2F0
 HEX 0000222F2000000AA000000F20
 HEX 00000000000000000000000000

JUMP3_MASK_MIRROR
 HEX FF0000000FFFFFFFFFFFFFFFFF
 HEX 0000000000FFFFFFFFFFFFFFFF
 HEX 0000000000FFFFFFFFFFFFFFFF
 HEX 00000000000FFFFFFFFFFFFFFF
 HEX F0000000000FFFFFFFFFFFFFFF
 HEX F0000000000FFFFFFFFFFFFFFF
 HEX FF000000000FFFFFFFFFFFFFFF
 HEX FF000000000FFFFFFFFFFFFFFF
 HEX FF000000000000FFFFFFFFFFFF
 HEX FFF000000000000FFFFFFFFFFF
 HEX FFF0000000000000FFFFFFFFFF
 HEX FFFF0000000000000FFFFFFFFF
 HEX FFFFFF000000000000FFFFFFFF
 HEX FFFFFF000000000000FFFFFFFF
 HEX FFFFFF000000000000FFFFFFFF
 HEX FFFFFFF00000000000FFFFFFFF
 HEX FFFFFFFF0000000000FFFFFFFF
 HEX FFFFFFFF0000000000FFFFFFFF
 HEX FFFF00000000000000FFFFFFFF
 HEX FFF000000000000000FFFFFFFF
 HEX FF0000000000000000FFFFFFFF
 HEX FF0000000000000000FFFFFFFF
 HEX FF0000000000000000FFFFFFFF
 HEX FF0000000000000000FFFFFFFF
 HEX FFF000000000000000FFFFFFFF
 HEX FFFF000000F0000000FF000FFF
 HEX FFFFF00000FF000000000000FF
 HEX FFFFF00000FF000000000000FF
 HEX FFFFF00000FFF000000000000F
 HEX FFFF000000FFF0000000000000
 HEX FFF0000000FFF0000000000000
 HEX FFF0000000FFFF00000FFFF000

* Billy kick frames — compiled (transparent nibble = $6).
KICK1 EQU KICK1_DATA
KICK2 EQU KICK2_DATA

KICK1_Y HEX 2800
KICK1_X HEX 0900

KICK1_DATA
 HEX 000000000FFFFFF000
 HEX 0000000FF2F2FFFF00
 HEX 0000000F2FFF0F0FF0
 HEX 0000000FFF0F000FF0
 HEX 00000000FF000F0FF0
 HEX 00000000000F2F0FF0
 HEX 0000000000F00F00F0
 HEX 00000000002F22F0F0
 HEX 0000000000F22F0000
 HEX 00000F2F000FFF0000
 HEX 0000F222F000000000
 HEX 00002222F000F22000
 HEX 00002222F00F222200
 HEX 0000F222000F222200
 HEX 0000F22F00FFF22200
 HEX 00000F202222FFF000
 HEX 000000222222000000
 HEX 00000022222F000000
 HEX 0000A0F22220000000
 HEX 0000A00FFF00000000
 HEX 0000000000A0000000
 HEX 00000AA999A0000000
 HEX 0000AAA0AA00000000
 HEX 0000AAAA00A0000000
 HEX 00000A99A00A000000
 HEX 000000A9900A000000
 HEX 022FF0A99A0A000000
 HEX 0F2220AA9A00000000
 HEX 022F20AAAAA0000000
 HEX 02F00000A9A0000000
 HEX 0108800A99A0000000
 HEX 020000000000000000
 HEX 000000022220000000
 HEX 000000022200000000
 HEX 000000F22000000000
 HEX 000000F20000000000
 HEX 00000F2F0000000000
 HEX 00000F222000000000
 HEX 000000F22200000000
 HEX 000000000000000000

KICK1_MASK
 HEX FFFFFFFFF0000000FF
 HEX FFFFFFF0000000000F
 HEX FFFFFFF0000000000F
 HEX FFFFFFF00000000000
 HEX FFFFFFFF0000000000
 HEX FFFFFFFF0000000000
 HEX FFFFFFFFF000000000
 HEX FFFFFFFFF000000000
 HEX FFFFF00000000000FF
 HEX FFFF00000000000FFF
 HEX FFF000000000000FFF
 HEX FFF0000000000000FF
 HEX FFF00000000000000F
 HEX FFF00000000000000F
 HEX FFF00000000000000F
 HEX FFF0000000000000FF
 HEX FFF00000000000FFFF
 HEX FFF0000000000FFFFF
 HEX FFF0000000000FFFFF
 HEX FFF000000000FFFFFF
 HEX FFFF00000000FFFFFF
 HEX FFFF00000000FFFFFF
 HEX FFF000000000FFFFFF
 HEX FFF000000000FFFFFF
 HEX FFFF000000000FFFFF
 HEX 0000000000000FFFFF
 HEX 0000000000000FFFFF
 HEX 0000000000000FFFFF
 HEX 0000000000000FFFFF
 HEX 0000000000000FFFFF
 HEX 0000000000000FFFFF
 HEX 000FFF0000000FFFFF
 HEX 00FFFF000000FFFFFF
 HEX FFFFFF00000FFFFFFF
 HEX FFFFF00000FFFFFFFF
 HEX FFFFF0000FFFFFFFFF
 HEX FFFF00000FFFFFFFFF
 HEX FFFF000000FFFFFFFF
 HEX FFFFF000000FFFFFFF
 HEX FFFFFF00000FFFFFFF

KICK1_DATA_MIRROR
 HEX 000FFFFFF000000000
 HEX 00FFFF2F2FF0000000
 HEX 0FF0F0FFF2F0000000
 HEX 0FF000F0FFF0000000
 HEX 0FF0F000FF00000000
 HEX 0FF0F2F00000000000
 HEX 0F00F00F0000000000
 HEX 0F0F22F20000000000
 HEX 0000F22F0000000000
 HEX 0000FFF000F2F00000
 HEX 000000000F222F0000
 HEX 00022F000F22220000
 HEX 002222F00F22220000
 HEX 002222F000222F0000
 HEX 00222FFF00F22F0000
 HEX 000FFF222202F00000
 HEX 000000222222000000
 HEX 000000F22222000000
 HEX 00000002222F0A0000
 HEX 00000000FFF00A0000
 HEX 0000000A0000000000
 HEX 0000000A999AA00000
 HEX 00000000AA0AAA0000
 HEX 0000000A00AAAA0000
 HEX 000000A00A99A00000
 HEX 000000A0099A000000
 HEX 000000A0A99A0FF220
 HEX 00000000A9AA0222F0
 HEX 0000000AAAAA02F220
 HEX 0000000A9A00000F20
 HEX 0000000A99A0088010
 HEX 000000000000000020
 HEX 000000022220000000
 HEX 000000002220000000
 HEX 00000000022F000000
 HEX 00000000002F000000
 HEX 0000000000F2F00000
 HEX 000000000222F00000
 HEX 00000000222F000000
 HEX 000000000000000000

KICK1_MASK_MIRROR
 HEX FF0000000FFFFFFFFF
 HEX F0000000000FFFFFFF
 HEX F0000000000FFFFFFF
 HEX 00000000000FFFFFFF
 HEX 0000000000FFFFFFFF
 HEX 0000000000FFFFFFFF
 HEX 000000000FFFFFFFFF
 HEX 000000000FFFFFFFFF
 HEX FF00000000000FFFFF
 HEX FFF00000000000FFFF
 HEX FFF000000000000FFF
 HEX FF0000000000000FFF
 HEX F00000000000000FFF
 HEX F00000000000000FFF
 HEX F00000000000000FFF
 HEX FF0000000000000FFF
 HEX FFFF00000000000FFF
 HEX FFFFF0000000000FFF
 HEX FFFFF0000000000FFF
 HEX FFFFFF000000000FFF
 HEX FFFFFF00000000FFFF
 HEX FFFFFF00000000FFFF
 HEX FFFFFF000000000FFF
 HEX FFFFFF000000000FFF
 HEX FFFFF000000000FFFF
 HEX FFFFF0000000000000
 HEX FFFFF0000000000000
 HEX FFFFF0000000000000
 HEX FFFFF0000000000000
 HEX FFFFF0000000000000
 HEX FFFFF0000000000000
 HEX FFFFF0000000FFF000
 HEX FFFFFF000000FFFF00
 HEX FFFFFFF00000FFFFFF
 HEX FFFFFFFF00000FFFFF
 HEX FFFFFFFFF0000FFFFF
 HEX FFFFFFFFF00000FFFF
 HEX FFFFFFFF000000FFFF
 HEX FFFFFFF000000FFFFF
 HEX FFFFFFF00000FFFFFF

KICK2_Y HEX 2200
KICK2_X HEX 1400

KICK2_DATA
 HEX 00000000000000000000000000000000FFFF0000
 HEX 0000000000000000000000000000000FFF2FF000
 HEX 00000000000000000000000000000000F2FFF000
 HEX 000000000000000000000000000000000F02F000
 HEX 0000000000000000000000000000000F000FFF00
 HEX 00000000000000000000000000F220FFF000FF00
 HEX 0000000000000000000000000F22220F2F00FF00
 HEX 00000000000000000000000A022222022F00FF00
 HEX 0000000000000000000000AA0222220FFF0F0000
 HEX 000000000000000000A000AA02FF2F0000000000
 HEX 020F0F220AA0000000A90AAA00222F00FF000000
 HEX 020FF0220AAA0AAA000AAAA00F2222FF22F00000
 HEX 0F0FF0F20A9AAAAAAA0000000F22222F22200000
 HEX 000FF000AAAA999AAAA000000F22222F22200000
 HEX 00000000000AA999A0A9AA0000F222FFF0F00000
 HEX 00000000000000AAAA0A9AA00000000000000000
 HEX 00000000000000000A00A9A00000000000000000
 HEX 00000000000000000AA0AAA00000000000000000
 HEX 000000000000000000A99A000000000000000000
 HEX 000000000000000000A99AA00000000000000000
 HEX 0000000000000000000A99A00000000000000000
 HEX 0000000000000000000A99A00000000000000000
 HEX 00000000000000000000AAA00000000000000000
 HEX 00000000000000000000A99A0000000000000000
 HEX 000000000000000000000A9A0000000000000000
 HEX 0000000000000000000000000000000000000000
 HEX 00000000000000000000022F0000000000000000
 HEX 0000000000000000000002220000000000000000
 HEX 000000000000000000000F220000000000000000
 HEX 0000000000000000000000220000000000000000
 HEX 0000000000000000000000FF0000000000000000
 HEX 0000000000000000000000222000000000000000
 HEX 00000000000000000000002F2220000000000000
 HEX 0000000000000000000000000000000000000000

KICK2_MASK
 HEX FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000FFFF
 HEX FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000000FFF
 HEX FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000FF
 HEX FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000FF
 HEX FFFFFFFFFFFFFFFFFFFFFFFFFF0000000000000F
 HEX FFFFFFFFFFFFFFFFFFFFFFFF000000000000000F
 HEX FFFFFFFFFFFFFFFFFFFFFFF0000000000000000F
 HEX FFFFFFFFFFFFFFFFFFFFFF00000000000000000F
 HEX FFFFFFFFFFFFFFFFFF000000000000000000000F
 HEX 000000000000FFFFF000000000000000000000FF
 HEX 0000000000000000000000000000000000000FFF
 HEX 000000000000000000000000000000000000FFFF
 HEX 000000000000000000000000000000000000FFFF
 HEX F00000000000000000000000000000000000FFFF
 HEX FFF000FF0000000000000000000000000000FFFF
 HEX FFFFFFFFFF0000000000000000000000000FFFFF
 HEX FFFFFFFFFFFFFF0000000000FFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFF00000000FFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFF0000000FFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFF0000000FFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFF0000000FFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFFF000000FFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFFFF000000FFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFFFF000000FFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFFFFF00000FFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFFFFF00000FFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFFFFF00000FFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFFFFF00000FFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFFFFF00000FFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFFFFFF000000FFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFFFFFF0000000FFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFFFFFFF0000000FFFFFFFFFFFF

KICK2_DATA_MIRROR
 HEX 0000FFFF00000000000000000000000000000000
 HEX 000FF2FFF0000000000000000000000000000000
 HEX 000FFF2F00000000000000000000000000000000
 HEX 000F20F000000000000000000000000000000000
 HEX 00FFF000F0000000000000000000000000000000
 HEX 00FF000FFF022F00000000000000000000000000
 HEX 00FF00F2F02222F0000000000000000000000000
 HEX 00FF00F220222220A00000000000000000000000
 HEX 0000F0FFF0222220AA0000000000000000000000
 HEX 0000000000F2FF20AA000A000000000000000000
 HEX 000000FF00F22200AAA09A0000000AA022F0F020
 HEX 00000F22FF2222F00AAAA000AAA0AAA0220FF020
 HEX 00000222F22222F0000000AAAAAAA9A02F0FF0F0
 HEX 00000222F22222F000000AAAA999AAAA000FF000
 HEX 00000F0FFF222F0000AA9A0A999AA00000000000
 HEX 00000000000000000AA9A0AAAA00000000000000
 HEX 00000000000000000A9A00A00000000000000000
 HEX 00000000000000000AAA0AA00000000000000000
 HEX 000000000000000000A99A000000000000000000
 HEX 00000000000000000AA99A000000000000000000
 HEX 00000000000000000A99A0000000000000000000
 HEX 00000000000000000A99A0000000000000000000
 HEX 00000000000000000AAA00000000000000000000
 HEX 0000000000000000A99A00000000000000000000
 HEX 0000000000000000A9A000000000000000000000
 HEX 0000000000000000000000000000000000000000
 HEX 0000000000000000F22000000000000000000000
 HEX 0000000000000000222000000000000000000000
 HEX 000000000000000022F000000000000000000000
 HEX 0000000000000000220000000000000000000000
 HEX 0000000000000000FF0000000000000000000000
 HEX 0000000000000002220000000000000000000000
 HEX 0000000000000222F20000000000000000000000
 HEX 0000000000000000000000000000000000000000

KICK2_MASK_MIRROR
 HEX FFFF00000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
 HEX FFF0000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
 HEX FF00000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
 HEX FF00000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
 HEX F0000000000000FFFFFFFFFFFFFFFFFFFFFFFFFF
 HEX F000000000000000FFFFFFFFFFFFFFFFFFFFFFFF
 HEX F0000000000000000FFFFFFFFFFFFFFFFFFFFFFF
 HEX F00000000000000000FFFFFFFFFFFFFFFFFFFFFF
 HEX F000000000000000000000FFFFFFFFFFFFFFFFFF
 HEX FF000000000000000000000FFFFF000000000000
 HEX FFF0000000000000000000000000000000000000
 HEX FFFF000000000000000000000000000000000000
 HEX FFFF000000000000000000000000000000000000
 HEX FFFF00000000000000000000000000000000000F
 HEX FFFF0000000000000000000000000000FF000FFF
 HEX FFFFF0000000000000000000000000FFFFFFFFFF
 HEX FFFFFFFFFFFFFFFF0000000000FFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFF00000000FFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFF0000000FFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFF0000000FFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFF0000000FFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFF000000FFFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFF000000FFFFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFF000000FFFFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFF00000FFFFFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFF00000FFFFFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFF00000FFFFFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFF00000FFFFFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFF00000FFFFFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFFF000000FFFFFFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFF0000000FFFFFFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFF0000000FFFFFFFFFFFFFFFFFFFFF

* Billy punch1 frames — compiled (transparent nibble = $6).
PUNCH11 EQU PUNCH11_DATA
PUNCH12 EQU PUNCH12_DATA

PUNCH11_Y HEX 2800
PUNCH11_X HEX 0B00

PUNCH11_DATA
 HEX 0000000000FFFFFF000000
 HEX 000000000FFFF2F2FF0000
 HEX 00000000FF0F0FFF2F0000
 HEX 00000000FF000F0FFF0000
 HEX 00000000FF0F000FF00000
 HEX 00000000FF0F2F00000000
 HEX 00000000F00F00F0000000
 HEX 00000000F0F22F20000000
 HEX 0000000000F22F00000000
 HEX 000000AA000FF000022200
 HEX 00000AAAF0000FF2F22220
 HEX 00000A9A1F0F2222F22220
 HEX 0000A99A0F222222F20F20
 HEX 0000A9AA0222222F00F200
 HEX 0000A9AA022222F0000000
 HEX 0000AAAA0F222F00000000
 HEX 000000AAA0FFF000000000
 HEX 0000A000AAA00000000000
 HEX 00AA9AAAAAA00000000000
 HEX 000AA99AAA000000000000
 HEX 0000000000000000000000
 HEX 00000000AA000000000000
 HEX 00000AAAAAA00000000000
 HEX 00000AAAAAA00000000000
 HEX 000000AA99AA0000000000
 HEX 000000AAA99A0000000000
 HEX 0000000AAA99A000000000
 HEX 00000000AAA9A000000000
 HEX 000000000AAAAA00000000
 HEX 00000A0000AA9A00000000
 HEX 00000AA000099A00000000
 HEX 000000000000A000000000
 HEX 0000222200022F00000000
 HEX 0000222000022200000000
 HEX 000F2200000F2200000000
 HEX 000F200000002200000000
 HEX 00F2F0000000FF00000000
 HEX 00F2220000002220000000
 HEX 000F222000002F22200000
 HEX 0000000000000000000000

PUNCH11_MASK
 HEX FFFFFFFFF0000000FFFFFF
 HEX FFFFFFFF0000000000FFFF
 HEX FFFFFFFF0000000000FFFF
 HEX FFFFFFF00000000000FFFF
 HEX FFFFFFF0000000000FFFFF
 HEX FFFFFFF0000000000FFFFF
 HEX FFFFFFF000000000FFFFFF
 HEX FFFFFFF000000000FFFFFF
 HEX FFFFFF0000000000000FFF
 HEX FFFFF0000000000000000F
 HEX FFFF000000000000000000
 HEX FFFF000000000000000000
 HEX FFF0000000000000000000
 HEX FFF000000000000000000F
 HEX FFF0000000000000F000FF
 HEX FF0000000000000FFFFFFF
 HEX FF000000000000FFFFFFFF
 HEX FF000000000000FFFFFFFF
 HEX F000000000000FFFFFFFFF
 HEX F00000000000FFFFFFFFFF
 HEX FF0000000000FFFFFFFFFF
 HEX FFF000000000FFFFFFFFFF
 HEX FFF000000000FFFFFFFFFF
 HEX FFF000000000FFFFFFFFFF
 HEX FFFFF000000000FFFFFFFF
 HEX FFFFF000000000FFFFFFFF
 HEX FFFFF000000000FFFFFFFF
 HEX FFFFF000000000FFFFFFFF
 HEX FFFF00000000000FFFFFFF
 HEX FFFF00000000000FFFFFFF
 HEX FFF000000F00000FFFFFFF
 HEX FFF000000F00000FFFFFFF
 HEX FFF000000F00000FFFFFFF
 HEX FFF00000FF00000FFFFFFF
 HEX FF00000FFF00000FFFFFFF
 HEX FF0000FFFFF0000FFFFFFF
 HEX F00000FFFFF0000FFFFFFF
 HEX F000000FFFF000000FFFFF
 HEX FF000000FFF0000000FFFF
 HEX FFF00000FFF0000000FFFF

PUNCH11_DATA_MIRROR
 HEX 000000FFFFFF0000000000
 HEX 0000FF2F2FFFF000000000
 HEX 0000F2FFF0F0FF00000000
 HEX 0000FFF0F000FF00000000
 HEX 00000FF000F0FF00000000
 HEX 00000000F2F0FF00000000
 HEX 0000000F00F00F00000000
 HEX 00000002F22F0F00000000
 HEX 00000000F22F0000000000
 HEX 002220000FF000AA000000
 HEX 02222F2FF0000FAAA00000
 HEX 02222F2222F0F1A9A00000
 HEX 02F02F222222F0A99A0000
 HEX 002F00F2222220AA9A0000
 HEX 0000000F222220AA9A0000
 HEX 00000000F222F0AAAA0000
 HEX 000000000FFF0AAA000000
 HEX 00000000000AAA000A0000
 HEX 00000000000AAAAAA9AA00
 HEX 000000000000AAA99AA000
 HEX 0000000000000000000000
 HEX 000000000000AA00000000
 HEX 00000000000AAAAAA00000
 HEX 00000000000AAAAAA00000
 HEX 0000000000AA99AA000000
 HEX 0000000000A99AAA000000
 HEX 000000000A99AAA0000000
 HEX 000000000A9AAA00000000
 HEX 00000000AAAAA000000000
 HEX 00000000A9AA0000A00000
 HEX 00000000A990000AA00000
 HEX 000000000A000000000000
 HEX 00000000F2200022220000
 HEX 0000000022200002220000
 HEX 0000000022F0000022F000
 HEX 000000002200000002F000
 HEX 00000000FF0000000F2F00
 HEX 0000000222000000222F00
 HEX 00000222F200000222F000
 HEX 0000000000000000000000

PUNCH11_MASK_MIRROR
 HEX FFFFFF0000000FFFFFFFFF
 HEX FFFF0000000000FFFFFFFF
 HEX FFFF0000000000FFFFFFFF
 HEX FFFF00000000000FFFFFFF
 HEX FFFFF0000000000FFFFFFF
 HEX FFFFF0000000000FFFFFFF
 HEX FFFFFF000000000FFFFFFF
 HEX FFFFFF000000000FFFFFFF
 HEX FFF0000000000000FFFFFF
 HEX F0000000000000000FFFFF
 HEX 000000000000000000FFFF
 HEX 000000000000000000FFFF
 HEX 0000000000000000000FFF
 HEX F000000000000000000FFF
 HEX FF000F0000000000000FFF
 HEX FFFFFFF0000000000000FF
 HEX FFFFFFFF000000000000FF
 HEX FFFFFFFF000000000000FF
 HEX FFFFFFFFF000000000000F
 HEX FFFFFFFFFF00000000000F
 HEX FFFFFFFFFF0000000000FF
 HEX FFFFFFFFFF000000000FFF
 HEX FFFFFFFFFF000000000FFF
 HEX FFFFFFFFFF000000000FFF
 HEX FFFFFFFF000000000FFFFF
 HEX FFFFFFFF000000000FFFFF
 HEX FFFFFFFF000000000FFFFF
 HEX FFFFFFFF000000000FFFFF
 HEX FFFFFFF00000000000FFFF
 HEX FFFFFFF00000000000FFFF
 HEX FFFFFFF00000F000000FFF
 HEX FFFFFFF00000F000000FFF
 HEX FFFFFFF00000F000000FFF
 HEX FFFFFFF00000FF00000FFF
 HEX FFFFFFF00000FFF00000FF
 HEX FFFFFFF0000FFFFF0000FF
 HEX FFFFFFF0000FFFFF00000F
 HEX FFFFF000000FFFF000000F
 HEX FFFF0000000FFF000000FF
 HEX FFFF0000000FFF00000FFF

PUNCH12_Y HEX 2800
PUNCH12_X HEX 1000

PUNCH12_DATA
 HEX 000000000000FFFFFF00000000000000
 HEX 00000000000FFFF2F2FF000000000000
 HEX 0000000000FF0F0FFF2F000000000000
 HEX 0000000000FF000F0FFF000000000000
 HEX 0000000000FF0F000FF0000000000000
 HEX 0000000000FF0F2F0000000000000000
 HEX 0000000000F00F00F000000000000000
 HEX 0000000000F0F22F0000000000000000
 HEX 00000000000000000FFFFFF22F022200
 HEX 0000000000AAAAA0F2222F2222F22220
 HEX 000000FF0AAAA9A02222222222F22220
 HEX 000002200AAA99A02222222222F20F20
 HEX 000022F0AAA099A0222222F2F000F200
 HEX 00002200AAA0A9A0F22FF00000000000
 HEX 00000F00AAA0AAA00000000000000000
 HEX 00000000AAA000AA0000000000000000
 HEX 00000000AAAAAAA00000000000000000
 HEX 000000A000AAA0000000000000000000
 HEX 0000AA9AAAAAA0000000000000000000
 HEX 00000AA99AAA00000000000000000000
 HEX 00000000000000000000000000000000
 HEX 0000000000AA00000000000000000000
 HEX 0000000AAAAAA0000000000000000000
 HEX 0000000AAAAAA0000000000000000000
 HEX 000000AA99AA00000000000000000000
 HEX 000000AAA99A00000000000000000000
 HEX 0000000AAA99A0000000000000000000
 HEX 00000000AAA9A0000000000000000000
 HEX 000000000AAAAA000000000000000000
 HEX 00000A0000AA9A000000000000000000
 HEX 00000AA000099A000000000000000000
 HEX 000000000000A0000000000000000000
 HEX 0000222200022F000000000000000000
 HEX 00002220000222000000000000000000
 HEX 000F2200000F22000000000000000000
 HEX 000F2000000022000000000000000000
 HEX 00F2F0000000FF000000000000000000
 HEX 00F22200000022200000000000000000
 HEX 000F222000002F222000000000000000
 HEX 00000000000000000000000000000000

PUNCH12_MASK
 HEX FFFFFFFFFFF0000000FFFFFFFFFFFFFF
 HEX FFFFFFFFFF0000000000FFFFFFFFFFFF
 HEX FFFFFFFFFF0000000000FFFFFFFFFFFF
 HEX FFFFFFFFF00000000000FFFFFFFFFFFF
 HEX FFFFFFFFF0000000000FFFFFFFFFFFFF
 HEX FFFFFFFFF0000000000FFFFFFFFFFFFF
 HEX FFFFFFFFF000000000FFFFFFFFFFFFFF
 HEX FFFFFFFFF00000000000000000000FFF
 HEX FFFFFFFF00000000000000000000000F
 HEX FFFFFFF0000000000000000000000000
 HEX FFFFF000000000000000000000000000
 HEX FFFF0000000000000000000000000000
 HEX FFF0000000000000000000000000000F
 HEX FFF000000000000000000000FFF000FF
 HEX FFFF00000000000000000FFFFFFFFFFF
 HEX FFFF000000000000FFFFFFFFFFFFFFFF
 HEX FFFF000000000000FFFFFFFFFFFFFFFF
 HEX FFFF000000000000FFFFFFFFFFFFFFFF
 HEX FFF000000000000FFFFFFFFFFFFFFFFF
 HEX FFF00000000000FFFFFFFFFFFFFFFFFF
 HEX FFFF0000000000FFFFFFFFFFFFFFFFFF
 HEX FFFFF000000000FFFFFFFFFFFFFFFFFF
 HEX FFFFF000000000FFFFFFFFFFFFFFFFFF
 HEX FFFFF000000000FFFFFFFFFFFFFFFFFF
 HEX FFFFF000000000FFFFFFFFFFFFFFFFFF
 HEX FFFFF000000000FFFFFFFFFFFFFFFFFF
 HEX FFFFF000000000FFFFFFFFFFFFFFFFFF
 HEX FFFFF000000000FFFFFFFFFFFFFFFFFF
 HEX FFFF00000000000FFFFFFFFFFFFFFFFF
 HEX FFFF00000000000FFFFFFFFFFFFFFFFF
 HEX FFF000000F00000FFFFFFFFFFFFFFFFF
 HEX FFF000000F00000FFFFFFFFFFFFFFFFF
 HEX FFF000000F00000FFFFFFFFFFFFFFFFF
 HEX FFF00000FF00000FFFFFFFFFFFFFFFFF
 HEX FF00000FFF00000FFFFFFFFFFFFFFFFF
 HEX FF0000FFFFF0000FFFFFFFFFFFFFFFFF
 HEX F00000FFFFF0000FFFFFFFFFFFFFFFFF
 HEX F000000FFFF000000FFFFFFFFFFFFFFF
 HEX FF000000FFF0000000FFFFFFFFFFFFFF
 HEX FFF00000FFF0000000FFFFFFFFFFFFFF

PUNCH12_DATA_MIRROR
 HEX 00000000000000FFFFFF000000000000
 HEX 000000000000FF2F2FFFF00000000000
 HEX 000000000000F2FFF0F0FF0000000000
 HEX 000000000000FFF0F000FF0000000000
 HEX 0000000000000FF000F0FF0000000000
 HEX 0000000000000000F2F0FF0000000000
 HEX 000000000000000F00F00F0000000000
 HEX 0000000000000000F22F0F0000000000
 HEX 002220F22FFFFFF00000000000000000
 HEX 02222F2222F2222F0AAAAA0000000000
 HEX 02222F22222222220A9AAAA0FF000000
 HEX 02F02F22222222220A99AAA002200000
 HEX 002F000F2F2222220A990AAA0F220000
 HEX 00000000000FF22F0A9A0AAA00220000
 HEX 00000000000000000AAA0AAA00F00000
 HEX 0000000000000000AA000AAA00000000
 HEX 00000000000000000AAAAAAA00000000
 HEX 0000000000000000000AAA000A000000
 HEX 0000000000000000000AAAAAA9AA0000
 HEX 00000000000000000000AAA99AA00000
 HEX 00000000000000000000000000000000
 HEX 00000000000000000000AA0000000000
 HEX 0000000000000000000AAAAAA0000000
 HEX 0000000000000000000AAAAAA0000000
 HEX 00000000000000000000AA99AA000000
 HEX 00000000000000000000A99AAA000000
 HEX 0000000000000000000A99AAA0000000
 HEX 0000000000000000000A9AAA00000000
 HEX 000000000000000000AAAAA000000000
 HEX 000000000000000000A9AA0000A00000
 HEX 000000000000000000A990000AA00000
 HEX 0000000000000000000A000000000000
 HEX 000000000000000000F2200022220000
 HEX 00000000000000000022200002220000
 HEX 00000000000000000022F0000022F000
 HEX 0000000000000000002200000002F000
 HEX 000000000000000000FF0000000F2F00
 HEX 00000000000000000222000000222F00
 HEX 000000000000000222F200000222F000
 HEX 00000000000000000000000000000000

PUNCH12_MASK_MIRROR
 HEX FFFFFFFFFFFFFF0000000FFFFFFFFFFF
 HEX FFFFFFFFFFFF0000000000FFFFFFFFFF
 HEX FFFFFFFFFFFF0000000000FFFFFFFFFF
 HEX FFFFFFFFFFFF00000000000FFFFFFFFF
 HEX FFFFFFFFFFFFF0000000000FFFFFFFFF
 HEX FFFFFFFFFFFFF0000000000FFFFFFFFF
 HEX FFFFFFFFFFFFFF000000000FFFFFFFFF
 HEX FFF00000000000000000000FFFFFFFFF
 HEX F00000000000000000000000FFFFFFFF
 HEX 0000000000000000000000000FFFFFFF
 HEX 000000000000000000000000000FFFFF
 HEX 0000000000000000000000000000FFFF
 HEX F0000000000000000000000000000FFF
 HEX FF000FFF000000000000000000000FFF
 HEX FFFFFFFFFFF00000000000000000FFFF
 HEX FFFFFFFFFFFFFFFF000000000000FFFF
 HEX FFFFFFFFFFFFFFFF000000000000FFFF
 HEX FFFFFFFFFFFFFFFF000000000000FFFF
 HEX FFFFFFFFFFFFFFFFF000000000000FFF
 HEX FFFFFFFFFFFFFFFFFF00000000000FFF
 HEX FFFFFFFFFFFFFFFFFF0000000000FFFF
 HEX FFFFFFFFFFFFFFFFFF000000000FFFFF
 HEX FFFFFFFFFFFFFFFFFF000000000FFFFF
 HEX FFFFFFFFFFFFFFFFFF000000000FFFFF
 HEX FFFFFFFFFFFFFFFFFF000000000FFFFF
 HEX FFFFFFFFFFFFFFFFFF000000000FFFFF
 HEX FFFFFFFFFFFFFFFFFF000000000FFFFF
 HEX FFFFFFFFFFFFFFFFFF000000000FFFFF
 HEX FFFFFFFFFFFFFFFFF00000000000FFFF
 HEX FFFFFFFFFFFFFFFFF00000000000FFFF
 HEX FFFFFFFFFFFFFFFFF00000F000000FFF
 HEX FFFFFFFFFFFFFFFFF00000F000000FFF
 HEX FFFFFFFFFFFFFFFFF00000F000000FFF
 HEX FFFFFFFFFFFFFFFFF00000FF00000FFF
 HEX FFFFFFFFFFFFFFFFF00000FFF00000FF
 HEX FFFFFFFFFFFFFFFFF0000FFFFF0000FF
 HEX FFFFFFFFFFFFFFFFF0000FFFFF00000F
 HEX FFFFFFFFFFFFFFF000000FFFF000000F
 HEX FFFFFFFFFFFFFF0000000FFF000000FF
 HEX FFFFFFFFFFFFFF0000000FFF00000FFF

* Billy punch2 frames — compiled (transparent nibble = $6).
PUNCH21 EQU PUNCH21_DATA
PUNCH22 EQU PUNCH22_DATA

PUNCH21_Y HEX 2800
PUNCH21_X HEX 0A00

PUNCH21_DATA
 HEX 000000000FFFFFF00000
 HEX 00000000FFFF2F2FF000
 HEX 0000000FF0F0FFF2F000
 HEX 0000000FF000F0FFF000
 HEX 0000000FF0F000FF0000
 HEX 0000000FF0F2F0002200
 HEX 0000000F00F00F022220
 HEX 0000000F0F22F202F220
 HEX 000000000F22F002FF20
 HEX 0000F2F000FFF0F22F00
 HEX 000F222F000000000000
 HEX 0002222F000F22000000
 HEX 0002222F00F222200000
 HEX 000F222000F222200000
 HEX 000F22F00FFF22200000
 HEX 0000F202222FFF000000
 HEX 0000002222220A000000
 HEX 00000022222F0A000000
 HEX 0000A0F222200A000000
 HEX 0000A00FFF0000000000
 HEX 00000000000000000000
 HEX 00000AA9AA0000000000
 HEX 0000AAA0AA0000000000
 HEX 0000AAAAAA0000000000
 HEX 00000AA99AA000000000
 HEX 00000AAA99A000000000
 HEX 000000AAA99A00000000
 HEX 0000000AAA9A00000000
 HEX 00000000AAAAA0000000
 HEX 0000A0000AA9A0000000
 HEX 0000AA000099A0000000
 HEX 00000000000A00000000
 HEX 000222200022F0000000
 HEX 00022200002220000000
 HEX 00F2200000F220000000
 HEX 00F20000000220000000
 HEX 0F2F0000000FF0000000
 HEX 0F222000000222000000
 HEX 00F222000002F2220000
 HEX 00000000000000000000

PUNCH21_MASK
 HEX FFFFFFFF0000000FFFFF
 HEX FFFFFFF0000000000FFF
 HEX FFFFFFF0000000000FFF
 HEX FFFFFF00000000000FFF
 HEX FFFFFF00000000000FFF
 HEX FFFFFF0000000000000F
 HEX FFFFFF00000000000000
 HEX FFFFFF00000000000000
 HEX FFFF0000000000000000
 HEX FFF0000000000000000F
 HEX FF000000000000F000FF
 HEX FF0000000000000FFFFF
 HEX FF00000000000000FFFF
 HEX FF00000000000000FFFF
 HEX FF00000000000000FFFF
 HEX FF0000000000000FFFFF
 HEX FFF000000000000FFFFF
 HEX FFF000000000000FFFFF
 HEX FFF000000000000FFFFF
 HEX FFF000000000000FFFFF
 HEX FFFF00000000F00FFFFF
 HEX FFFF00000000FFFFFFFF
 HEX FFF00000000FFFFFFFFF
 HEX FFF00000000FFFFFFFFF
 HEX FFFF000000000FFFFFFF
 HEX FFFF000000000FFFFFFF
 HEX FFFF000000000FFFFFFF
 HEX FFFF000000000FFFFFFF
 HEX FFF00000000000FFFFFF
 HEX FFF00000000000FFFFFF
 HEX FF000000F00000FFFFFF
 HEX FF000000F00000FFFFFF
 HEX FF000000F00000FFFFFF
 HEX FF00000FF00000FFFFFF
 HEX F00000FFF00000FFFFFF
 HEX F0000FFFFF0000FFFFFF
 HEX 00000FFFFF0000FFFFFF
 HEX 000000FFFF000000FFFF
 HEX F000000FFF0000000FFF
 HEX FF00000FFF0000000FFF

PUNCH21_DATA_MIRROR
 HEX 00000FFFFFF000000000
 HEX 000FF2F2FFFF00000000
 HEX 000F2FFF0F0FF0000000
 HEX 000FFF0F000FF0000000
 HEX 0000FF000F0FF0000000
 HEX 0022000F2F0FF0000000
 HEX 022220F00F00F0000000
 HEX 022F202F22F0F0000000
 HEX 02FF200F22F000000000
 HEX 00F22F0FFF000F2F0000
 HEX 000000000000F222F000
 HEX 00000022F000F2222000
 HEX 000002222F00F2222000
 HEX 000002222F000222F000
 HEX 00000222FFF00F22F000
 HEX 000000FFF222202F0000
 HEX 000000A0222222000000
 HEX 000000A0F22222000000
 HEX 000000A002222F0A0000
 HEX 0000000000FFF00A0000
 HEX 00000000000000000000
 HEX 0000000000AA9AA00000
 HEX 0000000000AA0AAA0000
 HEX 0000000000AAAAAA0000
 HEX 000000000AA99AA00000
 HEX 000000000A99AAA00000
 HEX 00000000A99AAA000000
 HEX 00000000A9AAA0000000
 HEX 0000000AAAAA00000000
 HEX 0000000A9AA0000A0000
 HEX 0000000A990000AA0000
 HEX 00000000A00000000000
 HEX 0000000F220002222000
 HEX 00000002220000222000
 HEX 000000022F0000022F00
 HEX 00000002200000002F00
 HEX 0000000FF0000000F2F0
 HEX 000000222000000222F0
 HEX 0000222F200000222F00
 HEX 00000000000000000000

PUNCH21_MASK_MIRROR
 HEX FFFFF0000000FFFFFFFF
 HEX FFF0000000000FFFFFFF
 HEX FFF0000000000FFFFFFF
 HEX FFF00000000000FFFFFF
 HEX FFF00000000000FFFFFF
 HEX F0000000000000FFFFFF
 HEX 00000000000000FFFFFF
 HEX 00000000000000FFFFFF
 HEX 0000000000000000FFFF
 HEX F0000000000000000FFF
 HEX FF000F000000000000FF
 HEX FFFFF0000000000000FF
 HEX FFFF00000000000000FF
 HEX FFFF00000000000000FF
 HEX FFFF00000000000000FF
 HEX FFFFF0000000000000FF
 HEX FFFFF000000000000FFF
 HEX FFFFF000000000000FFF
 HEX FFFFF000000000000FFF
 HEX FFFFF000000000000FFF
 HEX FFFFF00F00000000FFFF
 HEX FFFFFFFF00000000FFFF
 HEX FFFFFFFFF00000000FFF
 HEX FFFFFFFFF00000000FFF
 HEX FFFFFFF000000000FFFF
 HEX FFFFFFF000000000FFFF
 HEX FFFFFFF000000000FFFF
 HEX FFFFFFF000000000FFFF
 HEX FFFFFF00000000000FFF
 HEX FFFFFF00000000000FFF
 HEX FFFFFF00000F000000FF
 HEX FFFFFF00000F000000FF
 HEX FFFFFF00000F000000FF
 HEX FFFFFF00000FF00000FF
 HEX FFFFFF00000FFF00000F
 HEX FFFFFF0000FFFFF0000F
 HEX FFFFFF0000FFFFF00000
 HEX FFFF000000FFFF000000
 HEX FFF0000000FFF000000F
 HEX FFF0000000FFF00000FF

PUNCH22_Y HEX 2800
PUNCH22_X HEX 1000

PUNCH22_DATA
 HEX 00000000000FFFFFF000000000000000
 HEX 0000000000FFFF2F2FF0000000000000
 HEX 000000000FF0F0FFF2F0000000000000
 HEX 000000000FF000F0FFF0000000000000
 HEX 000000000FF0F000FF00000000000000
 HEX 000000000FF0F2F00000000000000000
 HEX 000000000F00F00F002000F222022200
 HEX 000000000F0F22F202222F2220222220
 HEX 00000000000F22F0022222222022F220
 HEX 000000F2F000FFF0F22222222022FF20
 HEX 00000F222F000000FF222022F0022F00
 HEX 000002222F000F220FFFFF0000000000
 HEX 000002222F00F2222000000000000000
 HEX 00000F222000F2222000000000000000
 HEX 00000F22F00FFF222000000000000000
 HEX 000000F202222FFF0000000000000000
 HEX 00000002222220A00000000000000000
 HEX 000000022222F0A00000000000000000
 HEX 00000A0F222200A00000000000000000
 HEX 00000A00FFF000000000000000000000
 HEX 00000000000000000000000000000000
 HEX 000000AA9AA000000000000000000000
 HEX 00000AAA0AA000000000000000000000
 HEX 00000AAAAAA000000000000000000000
 HEX 00000AA99AA000000000000000000000
 HEX 00000AAA99A000000000000000000000
 HEX 000000AAA99A00000000000000000000
 HEX 0000000AAA9A00000000000000000000
 HEX 00000000AAAAA0000000000000000000
 HEX 0000A0000AA9A0000000000000000000
 HEX 0000AA000099A0000000000000000000
 HEX 00000000000A00000000000000000000
 HEX 000222200022F0000000000000000000
 HEX 00022200002220000000000000000000
 HEX 00F2200000F220000000000000000000
 HEX 00F20000000220000000000000000000
 HEX 0F2F0000000FF0000000000000000000
 HEX 0F222000000222000000000000000000
 HEX 00F222000002F2220000000000000000
 HEX 00000000000000000000000000000000

PUNCH22_MASK
 HEX FFFFFFFFFF0000000FFFFFFFFFFFFFFF
 HEX FFFFFFFFF0000000000FFFFFFFFFFFFF
 HEX FFFFFFFFF0000000000FFFFFFFFFFFFF
 HEX FFFFFFFF00000000000FFFFFFFFFFFFF
 HEX FFFFFFFF0000000000FFFFFFFFFFFFFF
 HEX FFFFFFFF00000000000FFFFF00000FFF
 HEX FFFFFFFF00000000000000000000000F
 HEX FFFFFFFF000000000000000000000000
 HEX FFFFFF00000000000000000000000000
 HEX FFFFF000000000000000000000000000
 HEX FFFF000000000000000000000000000F
 HEX FFFF00000000000000000000FFF000FF
 HEX FFFF000000000000000000FFFFFFFFFF
 HEX FFFF00000000000000FFFFFFFFFFFFFF
 HEX FFFF00000000000000FFFFFFFFFFFFFF
 HEX FFFF00000000000000FFFFFFFFFFFFFF
 HEX FFFF000000000000FFFFFFFFFFFFFFFF
 HEX FFFF000000000000FFFFFFFFFFFFFFFF
 HEX FFFF000000000000FFFFFFFFFFFFFFFF
 HEX FFFF000000000000FFFFFFFFFFFFFFFF
 HEX FFFFF00000000F00FFFFFFFFFFFFFFFF
 HEX FFFFF00000000FFFFFFFFFFFFFFFFFFF
 HEX FFFF00000000FFFFFFFFFFFFFFFFFFFF
 HEX FFFF00000000FFFFFFFFFFFFFFFFFFFF
 HEX FFFF000000000FFFFFFFFFFFFFFFFFFF
 HEX FFFF000000000FFFFFFFFFFFFFFFFFFF
 HEX FFFF000000000FFFFFFFFFFFFFFFFFFF
 HEX FFFF000000000FFFFFFFFFFFFFFFFFFF
 HEX FFF00000000000FFFFFFFFFFFFFFFFFF
 HEX FFF00000000000FFFFFFFFFFFFFFFFFF
 HEX FF000000F00000FFFFFFFFFFFFFFFFFF
 HEX FF000000F00000FFFFFFFFFFFFFFFFFF
 HEX FF000000F00000FFFFFFFFFFFFFFFFFF
 HEX FF00000FF00000FFFFFFFFFFFFFFFFFF
 HEX F00000FFF00000FFFFFFFFFFFFFFFFFF
 HEX F0000FFFFF0000FFFFFFFFFFFFFFFFFF
 HEX 00000FFFFF0000FFFFFFFFFFFFFFFFFF
 HEX 000000FFFF000000FFFFFFFFFFFFFFFF
 HEX F000000FFF0000000FFFFFFFFFFFFFFF
 HEX FF00000FFF0000000FFFFFFFFFFFFFFF

PUNCH22_DATA_MIRROR
 HEX 000000000000000FFFFFF00000000000
 HEX 0000000000000FF2F2FFFF0000000000
 HEX 0000000000000F2FFF0F0FF000000000
 HEX 0000000000000FFF0F000FF000000000
 HEX 00000000000000FF000F0FF000000000
 HEX 00000000000000000F2F0FF000000000
 HEX 002220222F000200F00F00F000000000
 HEX 0222220222F222202F22F0F000000000
 HEX 022F2202222222200F22F00000000000
 HEX 02FF22022222222F0FFF000F2F000000
 HEX 00F2200F220222FF000000F222F00000
 HEX 0000000000FFFFF022F000F222200000
 HEX 0000000000000002222F00F222200000
 HEX 0000000000000002222F000222F00000
 HEX 000000000000000222FFF00F22F00000
 HEX 0000000000000000FFF222202F000000
 HEX 00000000000000000A02222220000000
 HEX 00000000000000000A0F222220000000
 HEX 00000000000000000A002222F0A00000
 HEX 000000000000000000000FFF00A00000
 HEX 00000000000000000000000000000000
 HEX 000000000000000000000AA9AA000000
 HEX 000000000000000000000AA0AAA00000
 HEX 000000000000000000000AAAAAA00000
 HEX 000000000000000000000AA99AA00000
 HEX 000000000000000000000A99AAA00000
 HEX 00000000000000000000A99AAA000000
 HEX 00000000000000000000A9AAA0000000
 HEX 0000000000000000000AAAAA00000000
 HEX 0000000000000000000A9AA0000A0000
 HEX 0000000000000000000A990000AA0000
 HEX 00000000000000000000A00000000000
 HEX 0000000000000000000F220002222000
 HEX 00000000000000000002220000222000
 HEX 000000000000000000022F0000022F00
 HEX 00000000000000000002200000002F00
 HEX 0000000000000000000FF0000000F2F0
 HEX 000000000000000000222000000222F0
 HEX 0000000000000000222F200000222F00
 HEX 00000000000000000000000000000000

PUNCH22_MASK_MIRROR
 HEX FFFFFFFFFFFFFFF0000000FFFFFFFFFF
 HEX FFFFFFFFFFFFF0000000000FFFFFFFFF
 HEX FFFFFFFFFFFFF0000000000FFFFFFFFF
 HEX FFFFFFFFFFFFF00000000000FFFFFFFF
 HEX FFFFFFFFFFFFFF0000000000FFFFFFFF
 HEX FFF00000FFFFF00000000000FFFFFFFF
 HEX F00000000000000000000000FFFFFFFF
 HEX 000000000000000000000000FFFFFFFF
 HEX 00000000000000000000000000FFFFFF
 HEX 000000000000000000000000000FFFFF
 HEX F000000000000000000000000000FFFF
 HEX FF000FFF00000000000000000000FFFF
 HEX FFFFFFFFFF000000000000000000FFFF
 HEX FFFFFFFFFFFFFF00000000000000FFFF
 HEX FFFFFFFFFFFFFF00000000000000FFFF
 HEX FFFFFFFFFFFFFF00000000000000FFFF
 HEX FFFFFFFFFFFFFFFF000000000000FFFF
 HEX FFFFFFFFFFFFFFFF000000000000FFFF
 HEX FFFFFFFFFFFFFFFF000000000000FFFF
 HEX FFFFFFFFFFFFFFFF000000000000FFFF
 HEX FFFFFFFFFFFFFFFF00F00000000FFFFF
 HEX FFFFFFFFFFFFFFFFFFF00000000FFFFF
 HEX FFFFFFFFFFFFFFFFFFFF00000000FFFF
 HEX FFFFFFFFFFFFFFFFFFFF00000000FFFF
 HEX FFFFFFFFFFFFFFFFFFF000000000FFFF
 HEX FFFFFFFFFFFFFFFFFFF000000000FFFF
 HEX FFFFFFFFFFFFFFFFFFF000000000FFFF
 HEX FFFFFFFFFFFFFFFFFFF000000000FFFF
 HEX FFFFFFFFFFFFFFFFFF00000000000FFF
 HEX FFFFFFFFFFFFFFFFFF00000000000FFF
 HEX FFFFFFFFFFFFFFFFFF00000F000000FF
 HEX FFFFFFFFFFFFFFFFFF00000F000000FF
 HEX FFFFFFFFFFFFFFFFFF00000F000000FF
 HEX FFFFFFFFFFFFFFFFFF00000FF00000FF
 HEX FFFFFFFFFFFFFFFFFF00000FFF00000F
 HEX FFFFFFFFFFFFFFFFFF0000FFFFF0000F
 HEX FFFFFFFFFFFFFFFFFF0000FFFFF00000
 HEX FFFFFFFFFFFFFFFF000000FFFF000000
 HEX FFFFFFFFFFFFFFF0000000FFF000000F
 HEX FFFFFFFFFFFFFFF0000000FFF00000FF

* Billy hit-reaction frame — compiled (transparent nibble = $6).
BPUNCHED EQU BPUNCHED_DATA

BPUNCHED_Y HEX 2800
BPUNCHED_X HEX 0B00

BPUNCHED_DATA
 HEX 0000000000000000000000
 HEX 0000FFFFFF000000000000
 HEX 000FFF2FFFFF0000000000
 HEX 00FF2FF000FF0000000000
 HEX 00FF2F0000000000000000
 HEX 000FFF000F002000000000
 HEX 0000F0022FF02000000000
 HEX 000000F200FF0000000000
 HEX 000000000002F000000000
 HEX 000000000202F000000000
 HEX 0000000000220000000000
 HEX 0000F2F000000000000000
 HEX 000F222F02F0F000000000
 HEX 00022222022F2200000000
 HEX 000222220222F2F0000000
 HEX 000F22220F220220000000
 HEX 0000222000FF00F0000000
 HEX 0000F2FFF0000000000000
 HEX 0000F2222F000222000000
 HEX 0000022222F0220F200000
 HEX 00000F222F022220F00000
 HEX 0000000FFF0F20F2000000
 HEX 0000000000000000000000
 HEX 0000000000000000000000
 HEX 00000000CCBBCC00000000
 HEX 00000000CCCBBC00000000
 HEX 000000000CCCBBC0000000
 HEX 0000000000CCCBC0000000
 HEX 00000000000CCCCC000000
 HEX 8888880C0000CCBC088888
 HEX 0000000CC0000BBC000000
 HEX 00000000000000C0000000
 HEX 0000000000000022F00000
 HEX 0000002220000022200000
 HEX 00000F22000000F2200000
 HEX 00000F2F00000002200000
 HEX 00000FF00000000FF00000
 HEX 0000022200000002220000
 HEX 000002F222000002F22200
 HEX 0000000000000000000000

BPUNCHED_MASK
 HEX FFFFFFF000FFFFFFFFFFFF
 HEX FFFF0000000FFFFFFFFFFF
 HEX FFF0000000000FFFFFFFFF
 HEX FF00000000000FFFFFFFFF
 HEX FF000000000000FFFFFFFF
 HEX FF000000000000FFFFFFFF
 HEX FFF00000000000FFFFFFFF
 HEX FFFF0000000000FFFFFFFF
 HEX FFFFFF00000000FFFFFFFF
 HEX FFFFFF00000000FFFFFFFF
 HEX FFFF0000000000FFFFFFFF
 HEX FFF00000000000FFFFFFFF
 HEX FF0000000000000FFFFFFF
 HEX FF0000000000000FFFFFFF
 HEX FF00000000000000FFFFFF
 HEX FF00000000000000FFFFFF
 HEX FFF0000000000000FFFFFF
 HEX FFF00000000000000FFFFF
 HEX FFF000000000000000FFFF
 HEX FFFF00000000000000FFFF
 HEX FFFF00000000000000FFFF
 HEX FFFFF000000000000FFFFF
 HEX FFFFFF0000000000FFFFFF
 HEX FFFFFFF00000000FFFFFFF
 HEX FFFFFFF000000000FFFFFF
 HEX FFFFFFF000000000FFFFFF
 HEX FFFFFFF000000000FFFFFF
 HEX FFFFFFF000000000FFFFFF
 HEX FFFFFF00000000000FFFFF
 HEX 0000000000000000000000
 HEX FFFFF000000F00000FFFFF
 HEX FFFFF000000F00000FFFFF
 HEX FFFF0000000FF00000FFFF
 HEX FFFF000000FFF00000FFFF
 HEX FFFF00000FFFF00000FFFF
 HEX FFFF00000FFFFF0000FFFF
 HEX FFFF00000FFFFF0000FFFF
 HEX FFFF000000FFFF000000FF
 HEX FFFF0000000FFF0000000F
 HEX FFFF0000000FFF0000000F

BPUNCHED_DATA_MIRROR
 HEX 0000000000000000000000
 HEX 000000000000FFFFFF0000
 HEX 0000000000FFFFF2FFF000
 HEX 0000000000FF000FF2FF00
 HEX 0000000000000000F2FF00
 HEX 000000000200F000FFF000
 HEX 00000000020FF2200F0000
 HEX 0000000000FF002F000000
 HEX 000000000F200000000000
 HEX 000000000F202000000000
 HEX 0000000000220000000000
 HEX 000000000000000F2F0000
 HEX 000000000F0F20F222F000
 HEX 0000000022F22022222000
 HEX 0000000F2F222022222000
 HEX 000000022022F02222F000
 HEX 0000000F00FF0002220000
 HEX 0000000000000FFF2F0000
 HEX 000000222000F2222F0000
 HEX 000002F0220F2222200000
 HEX 00000F022220F222F00000
 HEX 0000002F02F0FFF0000000
 HEX 0000000000000000000000
 HEX 0000000000000000000000
 HEX 00000000CCBBCC00000000
 HEX 00000000CBBCCC00000000
 HEX 0000000CBBCCC000000000
 HEX 0000000CBCCC0000000000
 HEX 000000CCCCC00000000000
 HEX 888880CBCC0000C0888888
 HEX 000000CBB0000CC0000000
 HEX 0000000C00000000000000
 HEX 00000F2200000000000000
 HEX 0000022200000222000000
 HEX 0000022F00000022F00000
 HEX 00000220000000F2F00000
 HEX 00000FF00000000FF00000
 HEX 0000222000000022200000
 HEX 00222F200000222F200000
 HEX 0000000000000000000000

BPUNCHED_MASK_MIRROR
 HEX FFFFFFFFFFFF000FFFFFFF
 HEX FFFFFFFFFFF0000000FFFF
 HEX FFFFFFFFF0000000000FFF
 HEX FFFFFFFFF00000000000FF
 HEX FFFFFFFF000000000000FF
 HEX FFFFFFFF000000000000FF
 HEX FFFFFFFF00000000000FFF
 HEX FFFFFFFF0000000000FFFF
 HEX FFFFFFFF00000000FFFFFF
 HEX FFFFFFFF00000000FFFFFF
 HEX FFFFFFFF0000000000FFFF
 HEX FFFFFFFF00000000000FFF
 HEX FFFFFFF0000000000000FF
 HEX FFFFFFF0000000000000FF
 HEX FFFFFF00000000000000FF
 HEX FFFFFF00000000000000FF
 HEX FFFFFF0000000000000FFF
 HEX FFFFF00000000000000FFF
 HEX FFFF000000000000000FFF
 HEX FFFF00000000000000FFFF
 HEX FFFF00000000000000FFFF
 HEX FFFFF000000000000FFFFF
 HEX FFFFFF0000000000FFFFFF
 HEX FFFFFFF00000000FFFFFFF
 HEX FFFFFF000000000FFFFFFF
 HEX FFFFFF000000000FFFFFFF
 HEX FFFFFF000000000FFFFFFF
 HEX FFFFFF000000000FFFFFFF
 HEX FFFFF00000000000FFFFFF
 HEX 0000000000000000000000
 HEX FFFFF00000F000000FFFFF
 HEX FFFFF00000F000000FFFFF
 HEX FFFF00000FF0000000FFFF
 HEX FFFF00000FFF000000FFFF
 HEX FFFF00000FFFF00000FFFF
 HEX FFFF0000FFFFF00000FFFF
 HEX FFFF0000FFFFF00000FFFF
 HEX FF000000FFFF000000FFFF
 HEX F0000000FFF0000000FFFF
 HEX F0000000FFF0000000FFFF

* Billy climb frames — compiled (transparent nibble = $6).
BCLIMB1 EQU BCLIMB1_DATA
BCLIMB2 EQU BCLIMB2_DATA

BCLIMB1_Y HEX 2800
BCLIMB1_X HEX 0800

BCLIMB1_DATA
 HEX 000000FFF0022000
 HEX 00000F222F002200
 HEX 0000F22F2FF00000
 HEX 0000FF2FFFF02200
 HEX 0000FFFFFFF02220
 HEX 00000FFFFFF02220
 HEX 00000FF0FF000222
 HEX 0020000000002222
 HEX 02000AAAAA000020
 HEX 2020A99AAAAA0202
 HEX 0220A9AAAA9A0220
 HEX 0220AAAAAA9A0220
 HEX 0220AAAAAAAA0220
 HEX 0020AA0AAAAA0200
 HEX 0000A00AA0AA0000
 HEX 000000AAAA000000
 HEX 0000AAAAAAAA0000
 HEX 0000AAAAAAAA0000
 HEX 000000AAAAAA0000
 HEX 000A000000000000
 HEX 0A99AAAAAAAAA000
 HEX 0AAA0AAAAAAAA000
 HEX 00AAA00AAAAAA000
 HEX 000000000000A000
 HEX 0022200000AA9000
 HEX 00F22F0000A99000
 HEX 00022F0000A9A000
 HEX 000F2F000AAAA000
 HEX 00002F000AAA0000
 HEX 00F2000000A90000
 HEX 000F22000AAA0000
 HEX 0000000000000000
 HEX 0000000002220000
 HEX 00000000F22F0000
 HEX 00000000F2200000
 HEX 00000000F2F00000
 HEX 00000000F2000000
 HEX 00000000002F0000
 HEX 0000000022F00000
 HEX 0000000000000000

BCLIMB1_MASK
 HEX FFFFF000000000FF
 HEX FFFF00000000000F
 HEX FFF000000000000F
 HEX FFF000000000000F
 HEX FFF0000000000000
 HEX FFF0000000000000
 HEX FF00000000000000
 HEX F000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX F00000000000000F
 HEX FF000000000000FF
 HEX FFF0000000000FFF
 HEX FFF0000000000FFF
 HEX FFF0000000000FFF
 HEX FFF0000000000FFF
 HEX F0000000000000FF
 HEX 00000000000000FF
 HEX 00000000000000FF
 HEX F0000000000000FF
 HEX F0000000000000FF
 HEX F0000000000000FF
 HEX F000000F000000FF
 HEX FF00000F000000FF
 HEX FF00000F000000FF
 HEX FF00000F000000FF
 HEX F000000F00000FFF
 HEX FF00000F00000FFF
 HEX FFF0000F00000FFF
 HEX FFFFFFF000000FFF
 HEX FFFFFFF000000FFF
 HEX FFFFFFF00000FFFF
 HEX FFFFFFF00000FFFF
 HEX FFFFFFF00000FFFF
 HEX FFFFFFF000000FFF
 HEX FFFFFFF00000FFFF
 HEX FFFFFFFF000FFFFF

BCLIMB1_DATA_MIRROR
 HEX 0002200FFF000000
 HEX 002200F222F00000
 HEX 00000FF2F22F0000
 HEX 00220FFFF2FF0000
 HEX 02220FFFFFFF0000
 HEX 02220FFFFFF00000
 HEX 222000FF0FF00000
 HEX 2222000000000200
 HEX 020000AAAAA00020
 HEX 2020AAAAA99A0202
 HEX 0220A9AAAA9A0220
 HEX 0220A9AAAAAA0220
 HEX 0220AAAAAAAA0220
 HEX 0020AAAAA0AA0200
 HEX 0000AA0AA00A0000
 HEX 000000AAAA000000
 HEX 0000AAAAAAAA0000
 HEX 0000AAAAAAAA0000
 HEX 0000AAAAAA000000
 HEX 000000000000A000
 HEX 000AAAAAAAAA99A0
 HEX 000AAAAAAAA0AAA0
 HEX 000AAAAAA00AAA00
 HEX 000A000000000000
 HEX 0009AA0000022200
 HEX 00099A0000F22F00
 HEX 000A9A0000F22000
 HEX 000AAAA000F2F000
 HEX 0000AAA000F20000
 HEX 00009A0000002F00
 HEX 0000AAA00022F000
 HEX 0000000000000000
 HEX 0000222000000000
 HEX 0000F22F00000000
 HEX 0000022F00000000
 HEX 00000F2F00000000
 HEX 0000002F00000000
 HEX 0000F20000000000
 HEX 00000F2200000000
 HEX 0000000000000000

BCLIMB1_MASK_MIRROR
 HEX FF000000000FFFFF
 HEX F00000000000FFFF
 HEX F000000000000FFF
 HEX F000000000000FFF
 HEX 0000000000000FFF
 HEX 0000000000000FFF
 HEX 00000000000000FF
 HEX 000000000000000F
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX F00000000000000F
 HEX FF000000000000FF
 HEX FFF0000000000FFF
 HEX FFF0000000000FFF
 HEX FFF0000000000FFF
 HEX FFF0000000000FFF
 HEX FF0000000000000F
 HEX FF00000000000000
 HEX FF00000000000000
 HEX FF0000000000000F
 HEX FF0000000000000F
 HEX FF0000000000000F
 HEX FF000000F000000F
 HEX FF000000F00000FF
 HEX FF000000F00000FF
 HEX FF000000F00000FF
 HEX FFF00000F000000F
 HEX FFF00000F00000FF
 HEX FFF00000F0000FFF
 HEX FFF000000FFFFFFF
 HEX FFF000000FFFFFFF
 HEX FFFF00000FFFFFFF
 HEX FFFF00000FFFFFFF
 HEX FFFF00000FFFFFFF
 HEX FFF000000FFFFFFF
 HEX FFFF00000FFFFFFF
 HEX FFFFF000FFFFFFFF

BCLIMB2_Y HEX 2800
BCLIMB2_X HEX 0800

BCLIMB2_DATA
 HEX 0002200FFF000000
 HEX 002200F222F00000
 HEX 00000FF2F22F0000
 HEX 00220FFFF2FF0000
 HEX 02220FFFFFFF0000
 HEX 02220FFFFFF00000
 HEX 222000FF0FF00000
 HEX 2222000000000200
 HEX 020000AAAAA00020
 HEX 2020AAAAA99A0202
 HEX 0220A9AAAA9A0220
 HEX 0220A9AAAAAA0220
 HEX 0220AAAAAAAA0220
 HEX 0020AAAAA0AA0200
 HEX 0000AA0AA00A0000
 HEX 000000AAAA000000
 HEX 0000AAAAAAAA0000
 HEX 0000AAAAAAAA0000
 HEX 0000AAAAAA000000
 HEX 000000000000A000
 HEX 000AAAAAAAAA99A0
 HEX 000AAAAAAAA0AAA0
 HEX 000AAAAAA00AAA00
 HEX 000A000000000000
 HEX 0009AA0000022200
 HEX 00099A0000F22F00
 HEX 000A9A0000F22000
 HEX 000AAAA000F2F000
 HEX 0000AAA000F20000
 HEX 00009A0000002F00
 HEX 0000AAA00022F000
 HEX 0000000000000000
 HEX 0000222000000000
 HEX 0000F22F00000000
 HEX 0000022F00000000
 HEX 00000F2F00000000
 HEX 0000002F00000000
 HEX 0000F20000000000
 HEX 00000F2200000000
 HEX 0000000000000000

BCLIMB2_MASK
 HEX FF000000000FFFFF
 HEX F00000000000FFFF
 HEX F000000000000FFF
 HEX F000000000000FFF
 HEX 0000000000000FFF
 HEX 0000000000000FFF
 HEX 00000000000000FF
 HEX 000000000000000F
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX F00000000000000F
 HEX FF000000000000FF
 HEX FFF00000000000FF
 HEX FFF0000000000FFF
 HEX FFF00000000000FF
 HEX FFF00000000000FF
 HEX FFF000000000000F
 HEX FF00000000000000
 HEX FF00000000000000
 HEX FF0000000000000F
 HEX FF0000000000000F
 HEX FF0000000000000F
 HEX FF0000000000000F
 HEX FF000000F00000FF
 HEX FF000000F00000FF
 HEX FF000000F00000FF
 HEX FFF00000F000000F
 HEX FFF00000F00000FF
 HEX FFF00000F0000FFF
 HEX FFF000000FFFFFFF
 HEX FFF000000FFFFFFF
 HEX FFFF00000FFFFFFF
 HEX FFFF00000FFFFFFF
 HEX FFFF00000FFFFFFF
 HEX FFF000000FFFFFFF
 HEX FFFF00000FFFFFFF
 HEX FFFFF000FFFFFFFF

BCLIMB2_DATA_MIRROR
 HEX 000000FFF0022000
 HEX 00000F222F002200
 HEX 0000F22F2FF00000
 HEX 0000FF2FFFF02200
 HEX 0000FFFFFFF02220
 HEX 00000FFFFFF02220
 HEX 00000FF0FF000222
 HEX 0020000000002222
 HEX 02000AAAAA000020
 HEX 2020A99AAAAA0202
 HEX 0220A9AAAA9A0220
 HEX 0220AAAAAA9A0220
 HEX 0220AAAAAAAA0220
 HEX 0020AA0AAAAA0200
 HEX 0000A00AA0AA0000
 HEX 000000AAAA000000
 HEX 0000AAAAAAAA0000
 HEX 0000AAAAAAAA0000
 HEX 000000AAAAAA0000
 HEX 000A000000000000
 HEX 0A99AAAAAAAAA000
 HEX 0AAA0AAAAAAAA000
 HEX 00AAA00AAAAAA000
 HEX 000000000000A000
 HEX 0022200000AA9000
 HEX 00F22F0000A99000
 HEX 00022F0000A9A000
 HEX 000F2F000AAAA000
 HEX 00002F000AAA0000
 HEX 00F2000000A90000
 HEX 000F22000AAA0000
 HEX 0000000000000000
 HEX 0000000002220000
 HEX 00000000F22F0000
 HEX 00000000F2200000
 HEX 00000000F2F00000
 HEX 00000000F2000000
 HEX 00000000002F0000
 HEX 0000000022F00000
 HEX 0000000000000000

BCLIMB2_MASK_MIRROR
 HEX FFFFF000000000FF
 HEX FFFF00000000000F
 HEX FFF000000000000F
 HEX FFF000000000000F
 HEX FFF0000000000000
 HEX FFF0000000000000
 HEX FF00000000000000
 HEX F000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX F00000000000000F
 HEX FF000000000000FF
 HEX FF00000000000FFF
 HEX FFF0000000000FFF
 HEX FF00000000000FFF
 HEX FF00000000000FFF
 HEX F000000000000FFF
 HEX 00000000000000FF
 HEX 00000000000000FF
 HEX F0000000000000FF
 HEX F0000000000000FF
 HEX F0000000000000FF
 HEX F0000000000000FF
 HEX FF00000F000000FF
 HEX FF00000F000000FF
 HEX FF00000F000000FF
 HEX F000000F00000FFF
 HEX FF00000F00000FFF
 HEX FFF0000F00000FFF
 HEX FFFFFFF000000FFF
 HEX FFFFFFF000000FFF
 HEX FFFFFFF00000FFFF
 HEX FFFFFFF00000FFFF
 HEX FFFFFFF00000FFFF
 HEX FFFFFFF000000FFF
 HEX FFFFFFF00000FFFF
 HEX FFFFFFFF000FFFFF

BSPIN1_Y HEX 2800
BSPIN1_X HEX 0F00
BSPIN1
 HEX 6666666666FFFFFF06666666666666
 HEX 66666666FF2F2FFFF0666666666666
 HEX 66666666F2FFF0F0FF666666666666
 HEX 66666666FFF0F000FF066666666666
 HEX 666666666FF000F0FF066666666666
 HEX 666666666000F2F0FF066666666666
 HEX 66666666660F00F00F066666666666
 HEX 666666666602F22F0F066666666666
 HEX 666666666600F22F00000066666666
 HEX 666666666000FFF00F022F00066666
 HEX 6666666602F00F00F022F220000066
 HEX 666666602F02000F202F2202222206
 HEX 66666602F20200F2202F2202020206
 HEX 6666660F2FF000F220F02200000206
 HEX 66666600FF00F0F2F000FF022F0206
 HEX 666666600000000000000000000066
 HEX 6666666666600000AA9AA006666666
 HEX 66666666660000000AA99A06666666
 HEX 66666666000AAAAA000AAA06666666
 HEX 66660000AA9A9999A0000066666666
 HEX 0000F22F0A9AAA999A006666666666
 HEX 0F2F22220AAA0AAAAA006666666666
 HEX 0F2F22220AA00AAAA0006666666666
 HEX 0F2FFFFF0000000000066666666666
 HEX 0FF00000660AAA0000666666666666
 HEX 00006666660A9A0006666666666666
 HEX 66666666660A9AA066666666666666
 HEX 6666666666AA9AA066666666666666
 HEX 6666666666AAAA0666666666666666
 HEX 6666666666AAAA0666666666666666
 HEX 66666666660AA00666666666666666
 HEX 666666666600006666666666666666
 HEX 6666666660F2206666666666666666
 HEX 666666666022206666666666666666
 HEX 666666666022F06666666666666666
 HEX 666666666022066666666666666666
 HEX 6666666660FF066666666666666666
 HEX 666666600222066666666666666666
 HEX 6666660222F2066666666666666666
 HEX 666666000000066666666666666666

BSPIN2_Y HEX 2800
BSPIN2_X HEX 0F00
BSPIN2
 HEX 666666666666666666FFFFF0066666
 HEX 6666666666666666FF2F2FFFF06666
 HEX 6666666666666666F2FF0F0FFF6666
 HEX 6666666666666666FF0F000FFF0666
 HEX 66666666666666666F00000FFF0666
 HEX 666666666666666666000F00FF0666
 HEX 6666666666666666602FFF020F0666
 HEX 6666666666666600600F22F20F0666
 HEX 66666666666660F000000000066666
 HEX 666666666666600F22222F00A06666
 HEX 66666666666660F2222222F0AA0666
 HEX 66666666666660F2222222209A0666
 HEX 66666666666660F22222222099A066
 HEX 666666666666660F222222F0A9A066
 HEX 666666666666666000F22F00A9A066
 HEX 666666666666666600000000AAA006
 HEX 6666666666666666000000AAAAAA00
 HEX 66666666666666000AAAA00AAA0006
 HEX 66666666660000AAAAA9AA00000666
 HEX 66666666000AA999A0AA9AA0066666
 HEX 66660000AAAA999AA00AAAA0066666
 HEX 0000F22F0A9AAAAAAA0AAAA0066666
 HEX 0F2F22220AAA0AAAA00AAA00666666
 HEX 0F2F22220AA0000000000000666666
 HEX 0F2FFFFF000066660AAA0000666666
 HEX 0FF00000666666660A9A0006666666
 HEX 00006666666666660A9AA066666666
 HEX 6666666666666666AA9AA066666666
 HEX 6666666666666666AAAA0666666666
 HEX 6666666666666666AAAA0666666666
 HEX 66666666666666660AA00666666666
 HEX 666666666666666600006666666666
 HEX 6666666666666660F2206666666666
 HEX 666666666666666022206666666666
 HEX 666666666666666022F06666666666
 HEX 666666666666666022066666666666
 HEX 6666666666666660FF066666666666
 HEX 666666666666600222066666666666
 HEX 6666666666660222F2066666666666
 HEX 666666666666000000066666666666

BSPIN3_Y HEX 2800
BSPIN3_X HEX 0F00
BSPIN3
 HEX 6666600FFFFF666666666666666666
 HEX 66660FFFF2F2FF6666666666666666
 HEX 6666FFF0F0FF2F6666666666666666
 HEX 6660FFF000F0FF6666666666666666
 HEX 6660FFF00000F66666666666666666
 HEX 6660FF00F000666666666666666666
 HEX 6660F020FFF2066666666666666666
 HEX 6660F02F22F0060066666666666666
 HEX 666660000000000F06666666666666
 HEX 66660A00F22222F006666666666666
 HEX 6660AA0F2222222F06666666666666
 HEX 6660A9022222222F06666666666666
 HEX 660A99022222222F06666666666666
 HEX 660A9A0F222222F066666666666666
 HEX 660A9A00F22F000666666666666666
 HEX 600AAA000000006666666666666666
 HEX 00AAAAAA0000006666666666666666
 HEX 6000AAA00AAAA00066666666666666
 HEX 66600000AA9AAAAA00006666666666
 HEX 6666600AA9AA0A999AA00066666666
 HEX 6666600AAAA00AA999AAAA00006666
 HEX 6666600AAAA0AAAAAAA9A0F22F0000
 HEX 66666600AAA00AAAA0AAA02222F2F0
 HEX 6666660000000000000AA02222F2F0
 HEX 6666660000AAA066660000FFFFF2F0
 HEX 6666666000A9A06666666600000FF0
 HEX 666666660AA9A06666666666660000
 HEX 666666660AA9AA6666666666666666
 HEX 6666666660AAAA6666666666666666
 HEX 6666666660AAAA6666666666666666
 HEX 66666666600AA06666666666666666
 HEX 666666666600006666666666666666
 HEX 6666666666022F0666666666666666
 HEX 666666666602220666666666666666
 HEX 66666666660F220666666666666666
 HEX 666666666660220666666666666666
 HEX 666666666660FF0666666666666666
 HEX 666666666660222006666666666666
 HEX 6666666666602F2220666666666666
 HEX 666666666660000000666666666666

BUPPER1_Y HEX 2500
BUPPER1_X HEX 0C00
BUPPER1
 HEX 6666666666660FFFFFF66666
 HEX 666666666660FFFF2F2FF666
 HEX 66666666666FF0F0FFF2F666
 HEX 66666666660FF000F0FFF666
 HEX 66666666660FF0F000FF6666
 HEX 66666666660FF0F2F0006666
 HEX 66666666660F00F00F066666
 HEX 66666666660F0F22F2066666
 HEX 6666600000000FF220666666
 HEX 66660F220AAF000FF0666666
 HEX 666F2220AAAF000006666666
 HEX 66022220A9A00F2206666666
 HEX 60F2220A99A0F222F0666666
 HEX 60F2220A9AA0222220666666
 HEX 660FFF0A9AA022222F066666
 HEX 6660000AAAA022222F066666
 HEX 66660000AAA0222220F66666
 HEX 666600A000A02FF2F0000066
 HEX 6660AA9AAAA00222F0022F06
 HEX 66600AA99AA0F2222FF2FF20
 HEX 666600000000F22222F2F220
 HEX 666660000000F22222F22220
 HEX 666660AA99000F222FF22206
 HEX 666660AAA900000000000666
 HEX 6666600AAA099AAA06666666
 HEX 66666000AAAAAAA9A0666666
 HEX 666600000AAA0AA990666666
 HEX 66660A00000A0AA9A0666666
 HEX 66600AA006000AAA00666666
 HEX 666022220660000000666666
 HEX 666022206660022206666666
 HEX 660F22066660F22066666666
 HEX 660F20666660F2F066666666
 HEX 60F2F0666660FF0066666666
 HEX 60F222066660222006666666
 HEX 660F222066602F2220666666
 HEX 666000006660000000666666

BUPPER2_Y HEX 2300
BUPPER2_X HEX 0F00
BUPPER2
 HEX 66666666666660FFFFFF6666666666
 HEX 6666666666660FFFF2F2FF66666666
 HEX 666666666666FF0F0FFF2F66666666
 HEX 666666666660FF000F0FFF66000006
 HEX 666666666660FF0F000FF660F222F0
 HEX 666666666660FF0F2F000660202220
 HEX 666666666660F00F00F06660022220
 HEX 666666666660F0F22F2066660F22F0
 HEX 666666666000000222F0006660FFF0
 HEX 666666660F2F000222F00006602220
 HEX 66666660F222F0022FFF00200F2220
 HEX 666666602222F00FF222F02F022220
 HEX 666666602222F0F0F2222022F22220
 HEX 66666660F22200F0F2222022222206
 HEX 66666660F22F00FF0F2F00F2222F06
 HEX 6666660AAAA022FFF0000000FFF066
 HEX 66666000A022222200666666000666
 HEX 66660AA0A022222F00666666666666
 HEX 666600AAA0F22220A0666666666666
 HEX 66666000000FFF0000666666666666
 HEX 666660AA9900000600666666666666
 HEX 666660AAA900000666666666666666
 HEX 6666600AAA99AAA066666666666666
 HEX 66666000AAAAAA9A06666666666666
 HEX 666600000AA0AA9906666666666666
 HEX 66660A0000A0AA9A06666666666666
 HEX 66600AA00000AAA006666666666666
 HEX 660222200600000006666666666666
 HEX 660222066600222066666666666666
 HEX 60F22066660F220666666666666666
 HEX 60F20666660F2F0666666666666666
 HEX 0F2F0666660FF00666666666666666
 HEX 0F2220666602220066666666666666
 HEX 60F222066602F22206666666666666
 HEX 660000066600000006666666666666

BUPPER3_Y HEX 2D00
BUPPER3_X HEX 0D00
BUPPER3
 HEX 66666666666666666660000066
 HEX 6666666666666666660F222F06
 HEX 66666666666666666602022206
 HEX 66666666666666666600222206
 HEX 66666666666666666660222206
 HEX 66666666660FFFFFF666000006
 HEX 6666666660FFFF2F2FF6022F06
 HEX 666666666FF0F0FFF2F6022F06
 HEX 666666660FF000F0FFF0F22F06
 HEX 666666660FF0F000FF00222F06
 HEX 666666660FF0F2F00000222F06
 HEX 666666660F00F00F00FF22F066
 HEX 666666660F0F22F200F2FFF066
 HEX 666666000000222F000222F066
 HEX 666660F2F000222F00022F0666
 HEX 66660F222F0022FFF0022F0666
 HEX 666602222F00FF222F02F06666
 HEX 666602222F0F0F22220F006666
 HEX 66660F22200F0F222200066666
 HEX 66660F22F00FF0F2F000666666
 HEX 666600F2022FFF000006666666
 HEX 666000002222220A0666666666
 HEX 66600A0022222F0A0666666666
 HEX 660AA9A0F222200A0666666666
 HEX 6600AA990FFF00000666666666
 HEX 66600000000000600666666666
 HEX 666600000AAA00666666666666
 HEX 666600AAAAAA06666666666666
 HEX 666600AAAAAA06666666666666
 HEX 666660AA99AA00666666666666
 HEX 666660AAA99A00666666666666
 HEX 6666600AAA99A0666666666666
 HEX 66666000AAA9A0666666666666
 HEX 666600000AAAAA066666666666
 HEX 66660A0000AA9A066666666666
 HEX 66600AA006099A066666666666
 HEX 666000000600A0066666666666
 HEX 66022220666022F06666666666
 HEX 66022206666022206666666666
 HEX 60F220666660F2206666666666
 HEX 60F20666666602206666666666
 HEX 0F2F066666660FF06666666666
 HEX 0F222066666602220066666666
 HEX 60F22206666602F22206666666
 HEX 66000006666600000006666666

BELBOW1_Y HEX 2C00
BELBOW1_X HEX 0D00
BELBOW1 HEX 66666666666600066666666666
 HEX 66666666666020F06666666666
 HEX 66666666666020220066666666
 HEX 66666666666000000006666666
 HEX 6666666666660FFFFFF6666666
 HEX 666666666660FFFF2F2F206666
 HEX 66666666666FF0F0FFF0220666
 HEX 66666666660FF000F0F0222066
 HEX 66666666660FF0F000F0222066
 HEX 66666666660FF0F2F00022F066
 HEX 66666666660F00F00F00FF0666
 HEX 66666666660F0F22F200F06666
 HEX 6666666660000FF2206F066666
 HEX 666666660AAF000FF066666666
 HEX 66666660AAAF00000666666666
 HEX 66666660A9A00F220666666666
 HEX 6666660A99A0F222F066666666
 HEX 6666660A9AA022222066666666
 HEX 6666660A9AA022222F06666666
 HEX 6666600AAAA022222F06666666
 HEX 66660000AAA0F2222266666666
 HEX 666600A000A002222266666666
 HEX 6660AA9AAAA00022F22F066666
 HEX 66600AA99AA00A0FF222F06666
 HEX 6666000000000A00F222200066
 HEX 6666600000AAAA060F222F2206
 HEX 6666600AAAA99A066002F222F0
 HEX 6666600AAAAAA0006660F22220
 HEX 666600A99A00A9A066660F2206
 HEX 66660AA99A0AA9906666600066
 HEX 66660A99A000AA9A0666666666
 HEX 66660A99A0600AA90666666666
 HEX 66600AAA06660AAAA066666666
 HEX 6660A99A066660A99066666666
 HEX 6660A9A0666660AAA066666666
 HEX 666000006666600A0066666666
 HEX 6602222066666022F066666666
 HEX 66022206666660222066666666
 HEX 60F22066666660F22066666666
 HEX 60F20666666666022066666666
 HEX 0F2F06666666660FF066666666
 HEX 0F222066666666022200666666
 HEX 60F2220666666602F222066666
 HEX 66000006666666000000066666

BELBOW2_Y HEX 2400
BELBOW2_X HEX 0E00
BELBOW2 HEX 666666666666600FFFFF66666666
 HEX 6666666666660FFFF2F2FF666666
 HEX 666666666666FFF0F0FF2F666666
 HEX 666666666660FFF000F0FF666666
 HEX 666666666660FFFF0000F0000066
 HEX 666666666660F020F0000F222F06
 HEX 666666666660F020F2F202202206
 HEX 6666666666000000022000F02206
 HEX 6666666660AA0FFF002060022206
 HEX 666666660AAAF222F000000F2206
 HEX 666666660A9A2222200FF0000F06
 HEX 66666660A99A2222200FF0F22206
 HEX 66666660A9A02222200FF0222206
 HEX 66666000AAA02222200F00002206
 HEX 666600A000A0F222F0000F220F06
 HEX 6660AA9AAAA0F22222F0F2F00006
 HEX 66600AA99AA0F2222220F2222066
 HEX 666600000000F2222220F22FF066
 HEX 6666600000A00FFFF0000F220666
 HEX 6666600AAAA00000006600006666
 HEX 666600A99A00A9A0666666666666
 HEX 66660AA99A0AA990666666666666
 HEX 66660A99A000AA9A066666666666
 HEX 66660A99A0600AA9066666666666
 HEX 66600AAA06660AAAA06666666666
 HEX 6660A99A066660A9906666666666
 HEX 6660A9A0666660AAA06666666666
 HEX 666000006666600A006666666666
 HEX 6602222066660222206666666666
 HEX 6602220666660222066666666666
 HEX 60F220666660F220666666666666
 HEX 60F206666660F206666666666666
 HEX 0F2F0666660F2F06666666666666
 HEX 0F222066660F2220666666666666
 HEX 60F222066660F222066666666666
 HEX 6600000666660000066666666666

BGRAB1_Y HEX 2800
BGRAB1_X HEX 0E00
BGRAB1 HEX 66666666660FFFFFF66666666666
 HEX 6666666660FFFF2F2FF666666666
 HEX 666666666FF0F0FFF2F666000006
 HEX 666666660FF000F0FFF660F222F0
 HEX 666666660FF0F000FF6660222020
 HEX 666666660FF0F2F0006660222206
 HEX 666666660F00F00F066660F22F06
 HEX 666666660F0F22F2066660FFF066
 HEX 666666660000000000000F22F066
 HEX 66666660AA00F22222F0222F0666
 HEX 6666660AAA0F222222F2222F0666
 HEX 6666660A9A022222222222F06666
 HEX 666660A99A022222222222F06666
 HEX 666660A9AA0F22222222F0066666
 HEX 666660A9AA00F22F000006666666
 HEX 666600AAAA000000666666666666
 HEX 660000AAAAAAA066666666666666
 HEX 6600A000AAA00066666666666666
 HEX 60AA9AAAAAA00666666666666666
 HEX 600AA99AAA006666666666666666
 HEX 6600000000006666666666666666
 HEX 66600000AA006666666666666666
 HEX 66600AAAAAA06666666666666666
 HEX 66600AAAAAA06666666666666666
 HEX 66660A99A00A0666666666666666
 HEX 66660AA9900A0666666666666666
 HEX 66660AA99A0A0666666666666666
 HEX 666600AA9A000666666666666666
 HEX 666660AAAAA00666666666666666
 HEX 66666000A9A00666666666666666
 HEX 6666660A99A00666666666666666
 HEX 6666660000000666666666666666
 HEX 666660222F006666666666666666
 HEX 66666022F0066666666666666666
 HEX 6666022F00666666666666666666
 HEX 6660FF20F0666666666666666666
 HEX 666022F0F0666666666666666666
 HEX 6666022F02066666666666666666
 HEX 66666022F0206666666666666666
 HEX 6666660000006666666666666666

BGRAB2_Y HEX 2800
BGRAB2_X HEX 0D00
BGRAB2 HEX 6666666666660FFFFFF6666666
 HEX 666666666660FFFF2F2FF66666
 HEX 66666666666FF0F0FFF2F66666
 HEX 66666666660FF000F0FFF66666
 HEX 66666666660FF0F000FF666666
 HEX 66666666660FF0F2F000666666
 HEX 66666666660F00F00F06666666
 HEX 66666666660F0F22F206666666
 HEX 6666666660000FF22066666666
 HEX 666666660AAF000FF066666666
 HEX 66666660AAAF00000666666666
 HEX 66666660A9A00F220666666666
 HEX 6666660A99A0F222F066666666
 HEX 6666660A9AA022222066666666
 HEX 6666660A9AA022222F06666666
 HEX 6666600AAAA0F2222206666666
 HEX 6660000AAAAA02222266666666
 HEX 66600A000AAA0022F22F066666
 HEX 660AA9AAAAAA000FF222F06666
 HEX 6600AA99AAA00660F222200066
 HEX 66600000000006660F222F2206
 HEX 666600000AA006666002F222F0
 HEX 666600AAAAAA06666600F22220
 HEX 666600AAAAAA066666660F2206
 HEX 666660AA99AA00666666600066
 HEX 666660AAA99A00666666666666
 HEX 6666600AAA99A0666666666666
 HEX 66666000AAA9A0666666666666
 HEX 666600000AAAAA066666666666
 HEX 66660A0000AA9A066666666666
 HEX 66600AA006099A066666666666
 HEX 666000000600A0066666666666
 HEX 66022220000000066666666666
 HEX 66022206002220666666666666
 HEX 60F220660F2206666666666666
 HEX 60F206660F2F06666666666666
 HEX 0F2F06660FF006666666666666
 HEX 0F222066022200666666666666
 HEX 60F2220602F222066666666666
 HEX 66000006000000066666666666

BKNEE_Y HEX 2800
BKNEE_X HEX 0A00
BKNEE HEX 66666660FFFFFF666666
 HEX 6666660FFFF2F2FF6666
 HEX 666666FF0F0FFF2F6666
 HEX 666660FF000F0FFF6666
 HEX 666660FF0F000FF66666
 HEX 666660FF0F2F00066666
 HEX 666660F00F00F0666666
 HEX 666660F0F22F20666666
 HEX 66666000FF2206666666
 HEX 66660AA000FF06666666
 HEX 6660AAA0000066666666
 HEX 6660A9A0F22006666666
 HEX 660A99AF222F06666666
 HEX 660A9AA2222206666666
 HEX 660A9AA22222F0666666
 HEX 600AAAA22222F0666666
 HEX 60000AAA22220F226666
 HEX 600A000AFF2F002F0006
 HEX 0AA9AAAA222F000022F0
 HEX 00AA99AA2222FF02F000
 HEX 6000000022222F022220
 HEX 6600000A22222FF22220
 HEX 6600AAAAF222FFFF22F0
 HEX 6600AAAA000000000006
 HEX 66609AA000000F222F66
 HEX 666099A00000F222F066
 HEX 6660A9A0000F2FF00666
 HEX 6660AAAA060222066666
 HEX 66600AAA060F22066666
 HEX 666609A00660F2066666
 HEX 66660AAA06660F206666
 HEX 66660000066660006666
 HEX 66000000066666666666
 HEX 66002220666666666666
 HEX 660F2206666666666666
 HEX 660F2F06666666666666
 HEX 660FF006666666666666
 HEX 66022200666666666666
 HEX 6602F222066666666666
 HEX 66000000066666666666

**
** WILLIAM sprites (note William's mask color is E not 6)
**

WILLIAM1_Y HEX 2800
WILLIAM1_X HEX 0900
WILLIAM1
 HEX EEEEEEEE000E0E0E0E
 HEX EEEEEEE0F0F0F0F0F0
 HEX EEEEEEE0FFFFFFFFF0
 HEX EEEEEEE0FF00FFFF00
 HEX EEEEEEE0FF0F00F00E
 HEX EEEEEEE0FF022F000E
 HEX EEEEEEE0F00222220E
 HEX EEEEEEE000FF22F20E
 HEX EEEEEEE0000000F0EE
 HEX EEEEEEE00FF22F20EE
 HEX EEEEE00000F22F00EE
 HEX EEEE0FFF00F20000EE
 HEX EEE02222F00F220F0E
 HEX EEE0222220F000020E
 HEX EEEF222220FF22020E
 HEX EE022222F00FF00F0E
 HEX E02222FF000000000E
 HEX E02F00F0000002F20E
 HEX EF22F00000000FF20E
 HEX EF22020F2F0002220E
 HEX EF2F0022220000000E
 HEX E0F02022220000220E
 HEX EE0000F22F0000002E
 HEX EEEE0200000000EEEE
 HEX EEEE0666999660EEEE
 HEX EEEE06600000660EEE
 HEX EEE006996066990EEE
 HEX EEE069996006990EEE
 HEX EEE0999600066960EE
 HEX EE0099960E006990EE
 HEX EE069960EEE069960E
 HEX EE066660EEE006660E
 HEX E000000EEEE000000E
 HEX E0A9990EEEE0A990EE
 HEX E0A990EEEEE0A990EE
 HEX E0A990EEEEE0A90EEE
 HEX E0AA00EEEEE0AA0EEE
 HEX E0A9900EEEE09900EE
 HEX E0A99990EEE099990E
 HEX E0000000EEE000000E

WILLIAM2_Y HEX 2800
WILLIAM2_X HEX 0900
WILLIAM2
 HEX EEEEEEEE000E0E0E0E
 HEX EEEEEEE0F0F0F0F0F0
 HEX EEEEEEE0FFFFFFFFF0
 HEX EEEEEEE0FF00FFFF00
 HEX EEEEEEE0FF0F00F000
 HEX EEEEEEE0FF022F000E
 HEX EEEEEEE0F00222220E
 HEX EEEEEEE000FF22F20E
 HEX EEEEEEE0000000F0EE
 HEX EEEEEEE00FF22F20EE
 HEX EEEEE00000F22F00EE
 HEX EEEE0FFF00F20000EE
 HEX EEE02222F00F220F0E
 HEX EEE0222220F000020E
 HEX EEEF222220FF22020E
 HEX EE022222F00FF00F0E
 HEX E02222FF000000000E
 HEX E02F00F0000002F20E
 HEX EF22F00000000FF20E
 HEX EF22020F2F0002220E
 HEX EF2F0022220000000E
 HEX E0F02022220000220E
 HEX EE0000F22F000000EE
 HEX EEEE0200000000EEEE
 HEX EEEEE066660060EEEE
 HEX EEEEE069990060EEEE
 HEX EEEEE069996060EEEE
 HEX EEEEE006999000EEEE
 HEX EEEEEE06699600EEEE
 HEX EEEEEE00069900EEEE
 HEX EEEEEEE0669900EEEE
 HEX EEEEEEE0066600EEEE
 HEX EEEEEE0A90000EEEEE
 HEX EEEEEE099900EEEEEE
 HEX EEEEE0A9900EEEEEEE
 HEX EEEE0AAA000EEEEEEE
 HEX EEEE0A99000EEEEEEE
 HEX EEEE0A99A000EEEEEE
 HEX EEEEE0099A000EEEEE
 HEX EEEEEEE000000EEEEE

WILLIAM3_Y HEX 2800
WILLIAM3_X HEX 0900
WILLIAM3
 HEX EEEEEEE000E0E0E0EE
 HEX EEEEEE0F0F0F0F0F0E
 HEX EEEEEE0FFFFFFFFF0E
 HEX EEEEEE0FF00FFFF00E
 HEX EEEEEE0FF0F00F00EE
 HEX EEEEEE0FF022F000EE
 HEX EEEEEE0F00222220EE
 HEX EEEEEE000FF22F20EE
 HEX EEEEEE0000000F0EEE
 HEX EEEEEE00FF22F20EEE
 HEX EEEE00000F22F00EEE
 HEX EEE0FFF00F20000EEE
 HEX EE02222F00F220F0EE
 HEX EE0222220F000020EE
 HEX EEF222220FF22020EE
 HEX E022222F00FF00F0EE
 HEX 02222FF000000000EE
 HEX 02F00F0000002F20EE
 HEX F22F00000000FF20EE
 HEX F22020F2F0002220EE
 HEX F2F0022220000000EE
 HEX 0F02022220000220EE
 HEX E0000F22F000000EEE
 HEX EEE0200000000EEEEE
 HEX EEEE000666660EEEEE
 HEX EEEE000669960EEEEE
 HEX EEE00000699960EEEE
 HEX EEE06000069960EEEE
 HEX EE006000069960EEEE
 HEX EE066600E069960EEE
 HEX EE066600E009960EEE
 HEX E066600EE066660EEE
 HEX 000000EEE000000EEE
 HEX 0A9990EEE0A990EEEE
 HEX 0A990EEEE0A990EEEE
 HEX 0A990EEEE0A90EEEEE
 HEX 0AA00EEEE0AA0EEEEE
 HEX 0A9900EEE09900EEEE
 HEX 0A99990EE099990EEE
 HEX 0000000EE000000EEE

WPUNCH1_Y HEX 2800
WPUNCH1_X HEX 0B00
WPUNCH1
 HEX EEEEEEEEEE000E0E0E00EE
 HEX EEEEEEEEE0F0F0F0F0F0EE
 HEX EEEEEEEEE0FFFFFFFFF0EE
 HEX EEEEEEEEE0FF00FFFF00EE
 HEX EEEEEEEEE0FF0F00F00EEE
 HEX EEEEEEEEE0FF022F000EEE
 HEX EEEEEEEEE0F00222220EEE
 HEX EEEEEEEEE000FF22F20EEE
 HEX EEEEEEEE0F0000F00000EE
 HEX EEEEEE00000000000F220E
 HEX EEEEE0F000222020F222F0
 HEX EEEE0F000022200022F220
 HEX EEE0F2000022202022FF20
 HEX EE0F20000022F000022F0E
 HEX EE02200000FF00002000EE
 HEX EE02F00000000000EEEEEE
 HEX EE0F000000000000EEEEEE
 HEX EE0000000000000EEEEEEE
 HEX EEE00000000000EEEEEEEE
 HEX EEEE000000000EEEEEEEEE
 HEX EEEE000000000EEEEEEEEE
 HEX EEEE00000000EEEEEEEEEE
 HEX EEEE00000000EEEEEEEEEE
 HEX EEEE00000000EEEEEEEEEE
 HEX EEEE000666660EEEEEEEEE
 HEX EEEE000668860EEEEEEEEE
 HEX EEE00000688860EEEEEEEE
 HEX EEE06000068860EEEEEEEE
 HEX EE006000068860EEEEEEEE
 HEX EE066600E068860EEEEEEE
 HEX EE066600E008860EEEEEEE
 HEX E066600EE066660EEEEEEE
 HEX 000000EEE000000EEEEEEE
 HEX 0A9990EEE0A990EEEEEEEE
 HEX 0A990EEEE0A990EEEEEEEE
 HEX 0A990EEEE0A90EEEEEEEEE
 HEX 0AA00EEEE0AA0EEEEEEEEE
 HEX 0A9900EEE09900EEEEEEEE
 HEX 0A99990EE099990EEEEEEE
 HEX 0000000EE000000EEEEEEE

WPUNCH2_Y HEX 2800
WPUNCH2_X HEX 1100
WPUNCH2
 HEX EEEEEEEEEEE000E0E0E00EEEEEEEEEEEEE
 HEX EEEEEEEEEE0F0F0F0F0F0EEEEEEEEEEEEE
 HEX EEEEEEEEEE0FFFFFFFFF0EEEEEEEEEEEEE
 HEX EEEEEEEEEE0FF00FFFF00EEEEEEEEEEEEE
 HEX EEEEEEEEEE0FF0F00F00EEEEEEEEEEEEEE
 HEX EEEEEEEEEE0FF022F000EEEEEEEEEEEEEE
 HEX EEEEEEEEEE0F00222220EEEEEEEEEEEEEE
 HEX EEEEEEEEEE000FF22F2022220F20000EEE
 HEX EEEEEEEEE0F00000000000000000F220EE
 HEX EEEEEEE00000000F22FF2222020F222F0E
 HEX EEEEEE0F000000F2222F222200022F220E
 HEX EEEEE0F000000022222F222202022FF20E
 HEX EEEE0F2000000022222F222F000022F0EE
 HEX EEE0F200000000F222F0FFF00F22000EEE
 HEX EEE022000000000F2F00000EEEEEEEEEEE
 HEX EEE02F0000000000000EEEEEEEEEEEEEEE
 HEX EEE0F000000000000EEEEEEEEEEEEEEEEE
 HEX EEE0000000000000EEEEEEEEEEEEEEEEEE
 HEX EEEE00000000000EEEEEEEEEEEEEEEEEEE
 HEX EEEEE000000000EEEEEEEEEEEEEEEEEEEE
 HEX EEEEE000000000EEEEEEEEEEEEEEEEEEEE
 HEX EEEEE00000000EEEEEEEEEEEEEEEEEEEEE
 HEX EEEEE00000000EEEEEEEEEEEEEEEEEEEEE
 HEX EEEEE00000000EEEEEEEEEEEEEEEEEEEEE
 HEX EEEE000666660EEEEEEEEEEEEEEEEEEEEE
 HEX EEEE000668860EEEEEEEEEEEEEEEEEEEEE
 HEX EEE00000688860EEEEEEEEEEEEEEEEEEEE
 HEX EEE06000068860EEEEEEEEEEEEEEEEEEEE
 HEX EE006000068860EEEEEEEEEEEEEEEEEEEE
 HEX EE066600E068860EEEEEEEEEEEEEEEEEEE
 HEX EE066600E008860EEEEEEEEEEEEEEEEEEE
 HEX E066600EE066660EEEEEEEEEEEEEEEEEEE
 HEX 000000EEE000000EEEEEEEEEEEEEEEEEEE
 HEX 0A9990EEE0A990EEEEEEEEEEEEEEEEEEEE
 HEX 0A990EEEE0A990EEEEEEEEEEEEEEEEEEEE
 HEX 0A990EEEE0A90EEEEEEEEEEEEEEEEEEEEE
 HEX 0AA00EEEE0AA0EEEEEEEEEEEEEEEEEEEEE
 HEX 0A9900EEE09900EEEEEEEEEEEEEEEEEEEE
 HEX 0A99990EE099990EEEEEEEEEEEEEEEEEEE
 HEX 0000000EE000000EEEEEEEEEEEEEEEEEEE

WPUNCHED_Y HEX 2800
WPUNCHED_X HEX 0900
WPUNCHED
 HEX EEEEEE0E0000EEEEEE
 HEX EE00E0F0FFFF0EEEEE
 HEX EE0F0FFFF0FFF0EEEE
 HEX EEE0FFFF000FF0EEEE
 HEX EEE0FFFF0F20FF0EEE
 HEX EEEE00F0F2220F0EEE
 HEX EEEEE00F22FFF00EEE
 HEX EEEEE0FFF0022020EE
 HEX EEEEEE000F222020EE
 HEX EEEEEE00F0002F00EE
 HEX EEEE00000F00020EEE
 HEX EEE0FFF000200F00EE
 HEX EE02222F000F20F0EE
 HEX EE0222220F000020EE
 HEX E0F222220FF22020EE
 HEX E022222F00FF00F0EE
 HEX E022222FF000000000
 HEX E022F00F0000002F20
 HEX E0F22F00000000FF20
 HEX E0F22020F2F0002220
 HEX E0F2F0022220000000
 HEX EE0F02022220000220
 HEX EEE0000F22F000000E
 HEX EEEEE0200000000EEE
 HEX EEEEEE066660060EEE
 HEX EEEEEE069990060EEE
 HEX EEEEEE069996060EEE
 HEX EEEEEE006999000EEE
 HEX EEEEEEE06699600EEE
 HEX EEEEEEE00069900EEE
 HEX EEEEEEEE0669900EEE
 HEX EEEEEEEE0066600EEE
 HEX EEEEEEEE0A90000EEE
 HEX EEEEEEEE099900EEEE
 HEX EEEEEEE0A9900EEEEE
 HEX EEEEEE0AAA000EEEEE
 HEX EEEEEE0A99000EEEEE
 HEX EEEEEE0A99A000EEEE
 HEX EEEEEEE0099A000EEE
 HEX EEEEEEEEE000000EEE
WPUNCHEDLEN EQU *-WPUNCHED

WFALL_Y HEX 2100
WFALL_X HEX 1300
WFALL
 HEX EEE00E0000EEEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX 0000F0FFFF0EEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX 0F0FFFF0FFF0EEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX 00FFFF000FF0EEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX E0FFFF0F20FF0EEEEEEEEEEEEEEEEEEEEEEEEE
 HEX E000F0F2220F0EEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EE000F22FFF000EEEEEEEEEEEEEEEEEEEEEEEE
 HEX EEE0FFF0022020EEEEEEEEEEEEEEEEEEEEEEEE
 HEX EEEEE0FF222020EE0000EEEEEEEEEEEEEEEEEE
 HEX EEEEE0F0002F000002020EEEEEEEEEEEEEEEEE
 HEX EEEEEE0F0002000F0F0F0EEEEEEEEEEEEEEEEE
 HEX EEEEEE00200F00020FFF0EEEEEEEEEEEEEEEEE
 HEX EEEEEEE00F200F02F2220EEEEEEEEEEEEEEEEE
 HEX EEEEEEEE0000F200F2200EEEEEEEEEEEEEEEEE
 HEX EEEEEEEE00000F0000000EEEEEEEEEEEEEEEEE
 HEX EEEEEEE00FFF0002020F0EEEEEEEEEEEEEEEEE
 HEX EEEEEEE0F222F00000000EEEEEEEEEEEEEEEEE
 HEX EEEEEEE02222200F22F000000000E0EEEEE00E
 HEX EEEEEEE0F22220F222F000669996090EEE090E
 HEX EEEEEEEE0FF2202222F0000000060990009A0E
 HEX EEEEEEEEE000FF2222F0069999600A99A990EE
 HEX EEEEEEEEEEEE00F22F00099999990AAAA990EE
 HEX EEEEEEEEEEEEEE0000000999669900000AA0EE
 HEX EEEEEEEEEEEEEEEEE000066609960EEEE000EE
 HEX EEEEEEEEEEEEEEEEEEEEE00006660EEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEE000000EEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEE0A990EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEE0A990EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEE0A90EEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEE0AA0EEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEE09900EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEE099990EEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEE000000EEEEEEEEE

WFALLEN_Y HEX 0D00
WFALLEN_X HEX 1000
WFALLEN
 HEX 00000000EEEEEEEEEEEE0000EEEEEEEE
 HEX FFFFFFF00000EEEEEEE066600EEEEEEE
 HEX 0FFFF000000000EEEE06000000EEEEEE
 HEX FFF000000FF0000EE00069999A0EEEEE
 HEX 0FF00F20022F000000069996A00EEEEE
 HEX FFF0022F00F000000069966600A0EEEE
 HEX 0000F20000000000069996600A9A0000
 HEX 0FF000000FFF000066996600A99900A9
 HEX F22000FF0022F000699966000A99AA9A
 HEX 222020222F22F0006996600000AA99A0
 HEX 222000222222F0006666000000099A00
 HEX F2F0F0FF222F00000660E0000000A00E
 HEX 0000000000000000000EEEEEE00000EE

WSOMER1_Y HEX 1800
WSOMER1_X HEX 1400
WSOMER1 HEX EEEEEEEEEEEEEEEEEE0000000F0FFF0F0EEEEEEE
 HEX EEEEEEEEEEEEEEEE0000000000000FFFFFEFEEEE
 HEX EEEEEEEEEEEEEEE0000000000000200FF4F0EEEE
 HEX EEEEEEEEEEEEEE0000000000F44F0F20FF04FEEE
 HEX EEEEEEEEEEEEEE000000F00F4444F000FFFF0EEE
 HEX EEEEEEEEEEEEE0000000F00444444000FF00EEEE
 HEX EEEEEEEEEEEEE0000000F00444444400FFFEEEEE
 HEX EEEEEEEEEEEEE0000000000F444444F00F0FEEEE
 HEX E000EEEEEEE066666600000FFFF0F44040F0FEEE
 HEX E0AA00000E066660066666000F0F44440EEEEEEE
 HEX E099AAAA0006666600666660000FF444F00EEEEE
 HEX E099A99A00666666000066600000FF4000F0EEEE
 HEX 0A900099066666600066666600000F0040000EEE
 HEX 090EEE0906666600E0066666000F000000FFF0EE
 HEX 00EEEEE0066660EEEE00066600FF0E0E0F444F0E
 HEX EEEEEEEEE0000EEEEE0666660FFF0EEE0F0404F0
 HEX EEEEEEEEEEEEEEEEE000000000000EEEE0E0E0E0
 HEX EEEEEEEEEEEEEEEEE0A99900F040F0EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEE0A990B0000000EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEE0A990BB0F440EEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEE0AA00B000FF40EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEE0A99000F00FF40EEEEEEEEE
 HEX EEEEEEEEEEEEEEEEE0A999900000000EEEEEEEEE
 HEX EEEEEEEEEEEEEEEEE0000000EEEEEEEEEEEEEEEE

WSOMER2_Y HEX 2D00
WSOMER2_X HEX 0D00
WSOMER2 HEX 0000000EEEEEEEEEEEE0000000
 HEX 0999990EEEEEEEEEEEE0999990
 HEX E00A990EEEEEEEEEEEE099A00E
 HEX EEE0AA0EEEEEEEEEEEE0AA0EEE
 HEX EEE099A0EEEEEEEEEE0A990EEE
 HEX EEE09990EEEEEEEEEE09990EEE
 HEX EEE09990EEEEEEEEEE09990EEE
 HEX EEE099A0EEEEEEEEEE0A990EEE
 HEX EEE000000EEEEEEEE000000EEE
 HEX EEEE066660EEEEEE066660EEEE
 HEX EEEE066660EEEEEE066660EEEE
 HEX EEEE0066660EEEE0666600EEEE
 HEX EEEEE0666660EE0666660EEEEE
 HEX EEEEEE06666600666660EEEEEE
 HEX EEEEEE06666600666660EEEEEE
 HEX EEEEEEE066606606660EEEEEEE
 HEX EEEEEEEE0606666060EEEEEEEE
 HEX EEEEEEEE0666666660EEEEEEEE
 HEX EEEEEEEE0066666600EEEEEEEE
 HEX EEEEEEEE0000000000EEEEEEEE
 HEX EEEEEEEE0000000000EEEEEEEE
 HEX EEEEEEE000000000000EEEEEEE
 HEX EEEEEEE000000000000EEEEEEE
 HEX EEEEEEE0000000000000EEEEEE
 HEX EEEEEEE0000000000000EEEEEE
 HEX EEEEEE00000FFFFF00000EEEEE
 HEX EEEEEE0F00F44F44F00F0EEEEE
 HEX EEEEE00FF0F44F44F0FF00EEEE
 HEX EEEEE0F440FF000FF044F0EEEE
 HEX EEEEE0444F000000004440EEEE
 HEX EEEE0F444F00FFF000444F0EEE
 HEX EEEE0F44F00F444F00F44F0EEE
 HEX EEEE0FFFF004000400FFFF0EEE
 HEX EEEE044000F004000F00440EEE
 HEX EEE0F44F00FF0000FF0F44F0EE
 HEX EEE0F44F00FFFFFFFF0F44F0EE
 HEX EEE0F4F0000FF0F0FF00F4F0EE
 HEX EEE0FFF0E0F0F0F00F00FFF0EE
 HEX EEE0FFF0E0F0F00F00E0FFF0EE
 HEX EEE0FFF0E00E00E000E0FFF0EE
 HEX EEE00000EEEEEEEEEEE00000EE
 HEX EEE044F0EEEEEEEEEEE0F440EE
 HEX EE04FF000EEEEEEEEE000FF40E
 HEX E04FF00F0EEEEEEEEE0F00FF40
 HEX E00000000EEEEEEEEE00000000

WSOMER3_Y HEX 2C00
WSOMER3_X HEX 1500
WSOMER3 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE000EEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE00AAA0EEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE0AA99A0EEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE0AA99A0EEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEE0A9A9A0EEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEE0A99AA0EEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEE0A999A0EEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEE0AAAAA0EEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEE00000AA00EEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEE0AAA00A0EEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEE06666600EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEE06666660EEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEE06666660EEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEE06666660EEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEE06666660EEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEE066666600EEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEE066666000EEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEE06666666600EEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEE0000666666660EEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEE0000006606666600EEEEEEEEE
 HEX EEEEEEEEEEEEEEEE00000000006666666EEEEEEEEE
 HEX EEEEEEEEEEEEEEE0000000000E0666666000EEEEEE
 HEX EEEEEEEEEEEEE00000000000EEE0666660AA0000EE
 HEX EEEEEEEEEEEE000000000000EEEE066660999990EE
 HEX EEEEEEEEEEE0FFF000000000EEEEE0066099AA9A0E
 HEX EEEEEEEEEE0F44FF00000000EEEEEEE000000A990E
 HEX EEEEEEEEEE04444F00000000EEEEEEEEEEEEE0A90E
 HEX EEEEEEEEE0F4444F0F4F0000EEEEEEEEEEEEEE090E
 HEX EEEEEEEE0F4444F0F44F00F0EEEEEEEEEEEEEEE00E
 HEX EEEEEEEE0F44FF000FF00FF0EEEEEEEEEEEEEEEEEE
 HEX EEEEEEE0F444F0040000F4F0EEEEEEEEEEEEEEEEEE
 HEX EEEEEEE0F44F00444000F440EEEEEEEEEEEEEEEEEE
 HEX EEEEE00F0FF000444440F440EEEEEEEEEEEEEEEEEE
 HEX EEEE0F000F0000040400F440EEEEEEEEEEEEEEEEEE
 HEX EEE00004000FF00000F0F440EEEEEEEEEEEEEEEEEE
 HEX EE0FFF000E0FFFFFFFF0F440EEEEEEEEEEEEEEEEEE
 HEX E0F444F0EE0F0F00F000F4F0EEEEEEEEEEEEEEEEEE
 HEX 0F4040F0EEE000EE00EF0000EEEEEEEEEEEEEEEEEE
 HEX 0E0E0E0EEEEEEEEEEEE00F0EEEEEEEEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEE0000EEEEEEEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEE00FFF0EEEEEEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEE0F444F0EEEEEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEE0F0404F0EEEEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEE0E0E0E0EEEEEEEEEEEEEEE

WHELD1_Y HEX 1800
WHELD1_X HEX 0F00
WHELD1 HEX EEEEEEEEEEE00000000EEEEEEEEEEE
 HEX EEEEEEEE000000000000000000000E
 HEX EEEEEEE0000000FFFFF000FFFFFFFE
 HEX EEEEEE0000000F44444F0FFFFFFF0E
 HEX EEEEEE000000F4440F44000000FFFE
 HEX EEEEE0000000F444F0F4000FF0FF0E
 HEX EEEEE0000000F44F00F00F2200FFFE
 HEX EEEE000000000FF000000F220FFF0E
 HEX EEE0666666660000400F00F00FFF0E
 HEX EEE066000006600F00FEF0000EEEEE
 HEX EE006666066660E00FEEEEEEEEEEEE
 HEX EE066666006660EE0EEEFEEEEEEEEE
 HEX EE0666600066660EE0EF0EEEEEEEEE
 HEX E0066660E006660EEE00EEEEEEEEEE
 HEX E066660EEE066660EEEEEEEEEEEEEE
 HEX E066660EEE006660EEEEEEEEEEEEEE
 HEX 000000EEEE000000EEEEEEEEEEEEEE
 HEX 0A9990EEEE0A990EEEEEEEEEEEEEEE
 HEX 0A990EEEEE0A990EEEEEEEEEEEEEEE
 HEX 0A990EEEEE0A90EEEEEEEEEEEEEEEE
 HEX 0AA00EEEEE0AA0EEEEEEEEEEEEEEEE
 HEX 0A9900EEEE09900EEEEEEEEEEEEEEE
 HEX 0A99990EEE099990EEEEEEEEEEEEEE
 HEX 0000000EEE000000EEEEEEEEEEEEEE

WHELD2_Y HEX 1800
WHELD2_X HEX 0E00
WHELD2 HEX EEEEEEEEE00000000EEEEEEEEEEE
 HEX EEEEEE000000000000EEEEEEEEEE
 HEX EEEEE0000000FFFFF00EEEEEEEEE
 HEX EEEE0000000F44444F000000000E
 HEX EEEE000000F4440F4400FFFFFFFE
 HEX EEE0000000F444F0F40FFFFFFF0E
 HEX EEE0000000F44F00F0000000FFFE
 HEX EEE00000000FF00000000FF0FF0E
 HEX EE066660060000400F0F2200FFFE
 HEX EE066660060E0F00F4FF220FFF0E
 HEX EE066666060EE00F4440F00FFF0E
 HEX EE006666000EEE0444F0000EEEEE
 HEX EEE06666600EEEE04F0EEEEEEEEE
 HEX EEE00066600EEEEE00EEEEEEEEEE
 HEX EEEE0666600EEEEEEEEEEEEEEEEE
 HEX EEEE0066600EEEEEEEEEEEEEEEEE
 HEX EE0A90000EEEEEEEEEEEEEEEEEEE
 HEX EE099900EEEEEEEEEEEEEEEEEEEE
 HEX E0A9900EEEEEEEEEEEEEEEEEEEEE
 HEX 0AAA000EEEEEEEEEEEEEEEEEEEEE
 HEX 0A99000EEEEEEEEEEEEEEEEEEEEE
 HEX 0A99A000EEEEEEEEEEEEEEEEEEEE
 HEX E0099A000EEEEEEEEEEEEEEEEEEE
 HEX EEE000000EEEEEEEEEEEEEEEEEEE

* pointy fingers — compiled for AND/ORA pipeline.
* DATA holds opaque colors (transparent slots zeroed); MASK has $F nibbles
* where the source was transparent (so AND preserves the screen there) and
* $0 nibbles where opaque (so AND zeroes the screen ready for ORA data).
* Generated via tools/compile_sprite.py with transparent nibble = $7.
POINT_RIGHT_Y HEX 1000
POINT_RIGHT_X HEX 0C00

POINT_RIGHT_DATA
 HEX 00000000CCC0CCCCCCCCC000
 HEX 00000C09BBBC9BBBBBBB9000
 HEX 00000AB1111BC1111BB11900
 HEX 0008AB11B111CB111BB11900
 HEX 00009B11B11109BBBBBBBC00
 HEX 800AB11B9B118CACAAAAC000
 HEX C9C911B9CBB10A99C0808000
 HEX 0B691B9AC9BB0B1BA0000000
 HEX 0159BBC00899911BC0000000
 HEX 0159BB59C00099A000000000
 HEX 81BA9B11BAC0C55AC0000000
 HEX 0BBA99B1B906B11BA0000000
 HEX 091BAABBB901111150000000
 HEX 6091BA0A998BB1BA00000000
 HEX 0009B90CCC0CC0C000000000
 HEX 0006C8060000000000000000

POINT_RIGHT_MASK
 HEX FFFFFF0000000000000000FF
 HEX FFFFF000000000000000000F
 HEX FFFF0000000000000000000F
 HEX FFF00000000000000000000F
 HEX FFF000000000F0000000000F
 HEX 0000000000000000000000FF
 HEX 000000000000F00000000FFF
 HEX 00000000000000000FFFFFFF
 HEX 00000000000000000FFFFFFF
 HEX 00000000000000000FFFFFFF
 HEX 00000000000000000FFFFFFF
 HEX 00000000000000000FFFFFFF
 HEX F000000000F000000FFFFFFF
 HEX 00000000000000000FFFFFFF
 HEX FF00000000000F00FFFFFFFF
 HEX FFF00000FFFFFFFFFFFFFFFF

POINT_RIGHT_DATA_MIRROR
 HEX 000CCCCCCCCC0CCC00000000
 HEX 0009BBBBBBB9CBBB90C00000
 HEX 00911BB1111CB1111BA00000
 HEX 00911BB111BC111B11BA8000
 HEX 00CBBBBBBB90111B11B90000
 HEX 000CAAAACAC811B9B11BA008
 HEX 0008080C99A01BBC9B119C9C
 HEX 0000000AB1B0BB9CA9B196B0
 HEX 0000000CB11999800CBB9510
 HEX 000000000A99000C95BB9510
 HEX 0000000CA55C0CAB11B9AB18
 HEX 0000000AB11B609B1B99ABB0
 HEX 000000051111109BBBAAB190
 HEX 00000000AB1BB899A0AB1906
 HEX 000000000C0CC0CCC09B9000
 HEX 0000000000000000608C6000

POINT_RIGHT_MASK_MIRROR
 HEX FF0000000000000000FFFFFF
 HEX F000000000000000000FFFFF
 HEX F0000000000000000000FFFF
 HEX F00000000000000000000FFF
 HEX F0000000000F000000000FFF
 HEX FF0000000000000000000000
 HEX FFF00000000F000000000000
 HEX FFFFFFF00000000000000000
 HEX FFFFFFF00000000000000000
 HEX FFFFFFF00000000000000000
 HEX FFFFFFF00000000000000000
 HEX FFFFFFF00000000000000000
 HEX FFFFFFF000000F000000000F
 HEX FFFFFFF00000000000000000
 HEX FFFFFFFF00F00000000000FF
 HEX FFFFFFFFFFFFFFFF00000FFF

* POINT_UP — rotated 90° CCW from POINT_RIGHT, then compiled.
POINT_UP_Y HEX 1800
POINT_UP_X HEX 0800

POINT_UP_DATA
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 0099C00000000000
 HEX C911BC8000000000
 HEX CB11BA0000000000
 HEX CBBBBA8000000000
 HEX CBBBBA0000000000
 HEX CB11BACAC0CA5000
 HEX CB11BC9BB0AB1A00
 HEX CB11BA911A511BC0
 HEX CB1B9CAB19511100
 HEX C9CC080099CB1BC0
 HEX 0CB1111B90061BC0
 HEX CB1111BB90C00800
 HEX CB111BB980A999C0
 HEX CB1BB9CC0CBBB9C0
 HEX 09111B9A0911BAC6
 HEX 00B111B9C51BB000
 HEX 0CABB11BBBB9AA98
 HEX 000A9B11BB99ABBC
 HEX 00080A9999AAB196
 HEX 000000C655BB1900
 HEX 0000009B111B9000
 HEX 000008C000800600

POINT_UP_MASK
 HEX FFFFFFFFFFFFFFFF
 HEX F0000FFFFFFFFFFF
 HEX 000000FFFFFFFFFF
 HEX 0000000FFFFFFFFF
 HEX 0000000FFFFFFFFF
 HEX 0000000FFFFFFFFF
 HEX 0000000FFFFFFFFF
 HEX 00000000000000FF
 HEX 000000000000000F
 HEX 000000000000000F
 HEX 00000000000000FF
 HEX 0000F0F00000000F
 HEX 000000000000000F
 HEX 000000000000F00F
 HEX 000000000000000F
 HEX 000000000000000F
 HEX 0000000000000000
 HEX 0000000000000000
 HEX F000000000000000
 HEX FF00000000000000
 HEX FFF0000000000000
 HEX FFFFF0000000000F
 HEX FFFFF000000000FF
 HEX FFFFF0000000F0FF

POINT_UP_DATA_MIRROR
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 00000000000C9900
 HEX 0000000008CB119C
 HEX 0000000000AB11BC
 HEX 0000000008ABBBBC
 HEX 0000000000ABBBBC
 HEX 0005AC0CACAB11BC
 HEX 00A1BA0BB9CB11BC
 HEX 0CB115A119AB11BC
 HEX 00111591BAC9B1BC
 HEX 0CB1BC990080CC9C
 HEX 0CB16009B1111BC0
 HEX 00800C09BB1111BC
 HEX 0C999A089BB111BC
 HEX 0C9BBBC0CC9BB1BC
 HEX 6CAB1190A9B11190
 HEX 000BB15C9B111B00
 HEX 89AA9BBBB11BBAC0
 HEX CBBA99BB11B9A000
 HEX 691BAA9999A08000
 HEX 0091BB556C000000
 HEX 0009B111B9000000
 HEX 006008000C800000

POINT_UP_MASK_MIRROR
 HEX FFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFF0000F
 HEX FFFFFFFFFF000000
 HEX FFFFFFFFF0000000
 HEX FFFFFFFFF0000000
 HEX FFFFFFFFF0000000
 HEX FFFFFFFFF0000000
 HEX FF00000000000000
 HEX F000000000000000
 HEX F000000000000000
 HEX FF00000000000000
 HEX F00000000F0F0000
 HEX F000000000000000
 HEX F00F000000000000
 HEX F000000000000000
 HEX F000000000000000
 HEX 0000000000000000
 HEX 0000000000000000
 HEX 000000000000000F
 HEX 00000000000000FF
 HEX 0000000000000FFF
 HEX F0000000000FFFFF
 HEX FF000000000FFFFF
 HEX FF0F0000000FFFFF

* roper
ROPER1_Y HEX 2700
ROPER1_X HEX 0900
ROPER1
 HEX EEEEEEEEE0000000EE
 HEX EEEEEEEE0FFFFFFF0E
 HEX EEEEEEE0FFFF00000E
 HEX EEEEEEE000F0F2220E
 HEX EEEEEE0F0000220F0E
 HEX EEEE0E00F00F00020E
 HEX E0E020020F0F22F20E
 HEX 020402020020F2F00E
 HEX E02000000200F2F0EE
 HEX EE00F22F00F00000EE
 HEX EE0F2222F022F0020E
 HEX EE022222F0222F00EE
 HEX EE022222F0222F0EEE
 HEX E0F2222F00222F0EEE
 HEX E0F222FF00F2FF0EEE
 HEX 0F2FF00000FFF0EEEE
 HEX 0F222F00F22F00EEEE
 HEX 0F2222F00000000EEE
 HEX 0F222222F22002F0EE
 HEX E00F222F22220220EE
 HEX EE000FFF22220220EE
 HEX EEE0000FF22002F0EE
 HEX EEE000000000000EEE
 HEX EEE00555500550EEEE
 HEX EEE054450054450EEE
 HEX EE0554450055440EEE
 HEX EE05445000054450EE
 HEX EE054450E0055440EE
 HEX E005450EEE005540EE
 HEX E000550EEE000550EE
 HEX 005000EEEE054450EE
 HEX 05550EEEEE054450EE
 HEX 05450EEEE005550EEE
 HEX 0550EEEEE055550EEE
 HEX 0000EEEEE05450EEEE
 HEX 05450EEEE00000EEEE
 HEX 055440EEE054500EEE
 HEX 000000EEE0554400EE
 HEX EEEEEEEEE0000000EE

ROPER2_Y HEX 2600
ROPER2_X HEX 0900
ROPER2
 HEX EEEEEEEEEE0000000E
 HEX EEEEEEEEE0FFFFFFF0
 HEX EEEEEEEE0FFFF00000
 HEX EEEEEEEE000F0F2220
 HEX EEEEEEE0F0000220F0
 HEX EEEEE0E00F00F00020
 HEX EE0E020020F0F22F20
 HEX E020402020020F2F00
 HEX EE02000000200F2F0E
 HEX EEE00F22F00F00000E
 HEX EEE0F2222F022F0020
 HEX EEE022222F0222F00E
 HEX EEE022222F0222F0EE
 HEX EE0F2222F00222F0EE
 HEX EE0F222FF00F2FF0EE
 HEX E0F2FF00000FFF0EEE
 HEX E0F222F00F22F00EEE
 HEX E0F2222F00000000EE
 HEX E0F222222F22002F0E
 HEX EE00F222F22220220E
 HEX EEE000FFF22220220E
 HEX EEEE0000FF22002F0E
 HEX EEEE000000000000EE
 HEX EEEEE0054450050EEE
 HEX EEEEE0544450550EEE
 HEX EEEEE0544450540EEE
 HEX EEEEE0554450540EEE
 HEX EEEEE0055450550EEE
 HEX EEEEE0505550050EEE
 HEX EEEE0555550050EEEE
 HEX EEEE0544500550EEEE
 HEX EEEE054550050EEEEE
 HEX EEEE055500550EEEEE
 HEX EEEE05550050EEEEEE
 HEX EEEE00000000EEEEEE
 HEX EEEE004400540EEEEE
 HEX EEEE0055400000EEEE
 HEX EEEEEE00000EEEEEEE

ROPER3_Y HEX 2700
ROPER3_X HEX 0900
ROPER3
 HEX EEEEEEEEEE0000000E
 HEX EEEEEEEEE0FFFFFFF0
 HEX EEEEEEEE0FFFF00000
 HEX EEEEEEEE000F0F2220
 HEX EEEEEEE0F0000220F0
 HEX EEEEE0E00F00F00020
 HEX EE0E020020F0F22F20
 HEX E020402020020F2F00
 HEX EE02000000200F2F0E
 HEX EEE00F22F00F00000E
 HEX EEE0F2222F022F0020
 HEX EEE022222F0222F00E
 HEX EEE022222F0222F0EE
 HEX EE0F2222F00222F0EE
 HEX EE0F222FF00F2FF0EE
 HEX E0F2FF00000FFF0EEE
 HEX E0F222F00F22F00EEE
 HEX E0F2222F00000000EE
 HEX E0F222222F22002F0E
 HEX EE00F222F22220220E
 HEX EEE000FFF22220220E
 HEX EEEE0000FF22002F0E
 HEX EEEE000000000000EE
 HEX EEEEE000555550EEEE
 HEX EEEEE0005544450EEE
 HEX EEEE00005554440EEE
 HEX EEEE050005554450EE
 HEX EEE0050000555440EE
 HEX EEE0555000055540EE
 HEX EEE055500E000550EE
 HEX EE055550EE055550EE
 HEX E05550EEEE054450EE
 HEX E05450EEE005550EEE
 HEX E0550EEEE055550EEE
 HEX E0000EEEE05450EEEE
 HEX E05450EEE00000EEEE
 HEX E055440EE054500EEE
 HEX E000000EE0554400EE
 HEX EEEEEEEEE0000000EE

RPUNCH1_Y HEX 2700
RPUNCH1_X HEX 0B00
RPUNCH1
 HEX EEEEEEEE0000000EEEEEEE
 HEX EEEEEEE0FFFFFFF0EEEEEE
 HEX EEEEEE0FFFF00000EEEEEE
 HEX EEEEEE000F0F2220EEEEEE
 HEX EEEEE0F0000220F00000EE
 HEX EEE0E00F00F0002022220E
 HEX EE020020F0F22F202222F0
 HEX 20402020020F2F000F2FF0
 HEX 02000000200F2F0000FF0E
 HEX E00F22F00F0000F00F00EE
 HEX E0F2222F022F0F20E00EEE
 HEX E022222F02220220EEEEEE
 HEX E022222F02220220EEEEEE
 HEX 0F2222F0022202F0EEEEEE
 HEX 0F222FF00220FF0EEEEEEE
 HEX 0F2FF00000FFF00EEEEEEE
 HEX 0F222F00F22F00EEEEEEEE
 HEX 0F2222F000000EEEEEEEEE
 HEX 0F222222F220EEEEEEEEEE
 HEX E00F222F22220EEEEEEEEE
 HEX EE000FFF22220EEEEEEEEE
 HEX EEE0000FF220EEEEEEEEEE
 HEX EEE0000000000EEEEEEEEE
 HEX EEEE000555550EEEEEEEEE
 HEX EEEE0005544450EEEEEEEE
 HEX EEE00005554440EEEEEEEE
 HEX EEE050005554450EEEEEEE
 HEX EE0050000555440EEEEEEE
 HEX EE0555000055540EEEEEEE
 HEX EE055500E000550EEEEEEE
 HEX E055550EE055550EEEEEEE
 HEX 05550EEEE054450EEEEEEE
 HEX 05450EEE005550EEEEEEEE
 HEX 0550EEEE055550EEEEEEEE
 HEX 0000EEEE05450EEEEEEEEE
 HEX 05450EEE00000EEEEEEEEE
 HEX 055440EE054500EEEEEEEE
 HEX 000000EE0554400EEEEEEE
 HEX EEEEEEEE0000000EEEEEEE

RPUNCH2_Y HEX 2700
RPUNCH2_X HEX 1000
RPUNCH2
 HEX EEEEEEEEEE0000000EEEEEEEEEEEEEEE
 HEX EEEEEEEEE0FFFFFFF0EEEEEEEEEEEEEE
 HEX EEEEEEEE0FFFF00000EEEEEEEEEEEEEE
 HEX EEEEEEEE000F0F2220EEEEEEEEEEEEEE
 HEX EEEEEEE0F0000220F0EEEEEEEEEEEEEE
 HEX EEEEE0E00F00F0002000EEEEEEEEEEEE
 HEX EEEE020020F0F22F20F20000EEEEEEEE
 HEX EE20402020020F2F0022222F000000EE
 HEX EE02000000200F2F0022F2222F22220E
 HEX EEE00F22F00F0000F0F2F222FF2222F0
 HEX EEE0F2222F022F0F20FFFF22F00F2FF0
 HEX EEE022222F022202200000000000FF0E
 HEX EEE022222F02220220EEEEEEEE0F00EE
 HEX EE0F2222F0022202F0EEEEEEEEE00EEE
 HEX EE0F222FF00220FF0EEEEEEEEEEEEEEE
 HEX E0F2FF00000FFF00EEEEEEEEEEEEEEEE
 HEX E0F222F00F22F00EEEEEEEEEEEEEEEEE
 HEX E0F2222F000000EEEEEEEEEEEEEEEEEE
 HEX E0F222222F220EEEEEEEEEEEEEEEEEEE
 HEX EE00F222F22220EEEEEEEEEEEEEEEEEE
 HEX EEE000FFF22220EEEEEEEEEEEEEEEEEE
 HEX EEEE0000FF220EEEEEEEEEEEEEEEEEEE
 HEX EEEE0000000000EEEEEEEEEEEEEEEEEE
 HEX EEEE000555550EEEEEEEEEEEEEEEEEEE
 HEX EEEE0005544450EEEEEEEEEEEEEEEEEE
 HEX EEE00005554440EEEEEEEEEEEEEEEEEE
 HEX EEE050005554450EEEEEEEEEEEEEEEEE
 HEX EE0050000555440EEEEEEEEEEEEEEEEE
 HEX EE0555000055540EEEEEEEEEEEEEEEEE
 HEX EE055500E000550EEEEEEEEEEEEEEEEE
 HEX E055550EE055550EEEEEEEEEEEEEEEEE
 HEX 05550EEEE054450EEEEEEEEEEEEEEEEE
 HEX 05450EEE005550EEEEEEEEEEEEEEEEEE
 HEX 0550EEEE055550EEEEEEEEEEEEEEEEEE
 HEX 0000EEEE05450EEEEEEEEEEEEEEEEEEE
 HEX 05450EEE00000EEEEEEEEEEEEEEEEEEE
 HEX 055440EE054500EEEEEEEEEEEEEEEEEE
 HEX 000000EE0554400EEEEEEEEEEEEEEEEE
 HEX EEEEEEEE0000000EEEEEEEEEEEEEEEEE

RFALL1_Y HEX 1700
RFALL1_X HEX 1000
RFALL1
 HEX EEEEEEEEEEE00000EEEEEEEEEEEEEEEE
 HEX EEEEEEEEEE0F2222EEEEEEEEEEEEEEEE
 HEX EEEEEEEEE0F22F00EEEEEEEEEEEEEEEE
 HEX EEE000000F222020EEEEEEEEEEEEEEEE
 HEX EE0FFF000F22F00EEEEEEEEEEEEEEEEE
 HEX E0FFF00F2FF00EEEEEEEEEEEEEEEEEEE
 HEX 000020F222200000EEEEEEEEEEEEEEEE
 HEX 02000F222200222000000000EEEEEEEE
 HEX E020FF2245044400055444450EEEEE00
 HEX 000F2FFF400000000000005450EEE040
 HEX 20F22222000550055555550545500440
 HEX 00F2222F005550544445440055500450
 HEX E0F2222F05545054444544000550540E
 HEX 020F22F0554450554455550E0000550E
 HEX 20E00000005550005005550EEEEE000E
 HEX 0EEEEEEE000000EEE054450EEEEEEEEE
 HEX EEEEEEEEEEEEEEEE005550EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEE055550EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEE05450EEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEE00000EEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEE054500EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEE0554400EEEEEEEEE
 HEX EEEEEEEEEEEEEEEE0000000EEEEEEEEE

RFALL2_Y HEX 0F00
RFALL2_X HEX 1000
RFALL2
 HEX E000EE00000EEEEEEEEEEEEEEEEEEEEE
 HEX 0F2F00F22FF0EEEEEEEEEEEEEEEEEEEE
 HEX F222000F222F0EEEEEEEE0000EEEEEEE
 HEX F2000000F0000EEEEEEE055540EEEE00
 HEX F0FF02200F2220EEEEE05454450EE040
 HEX 0FF000FF00FFFF00000545055450E040
 HEX 0FF0F2220F22F02F0505550055400450
 HEX 0FF02200000044000400000005505500
 HEX 0F0020F2440500440400555550005040
 HEX 00000000044055000054444545000040
 HEX 022F0FF2404054500544455544500540
 HEX F222F222444054450544555054450450
 HEX 2222F222445055440554550555450400
 HEX 0F220F22450005500055500055500550
 HEX 00000000000000000000000000000000

RPUNCHED_Y HEX 2600
RPUNCHED_X HEX 0900
RPUNCHED
 HEX EEEEEEEE0000000EEE
 HEX EEEEEEE0FFFFFFF0EE
 HEX EEEEEE0FFFF00000EE
 HEX EEEEEE000F0F2220EE
 HEX EEEEE0F0000220F0EE
 HEX EEE0E00F00F00020EE
 HEX EE020020F0F22F20EE
 HEX 20402020020F2F00EE
 HEX 02000000200F200EEE
 HEX E00F22F00F00200EEE
 HEX E0F2222F02F0F20EEE
 HEX E022222F022F00EEEE
 HEX E022222F0222F0EEEE
 HEX 0F2222F00222F0EEEE
 HEX 0F222FF00F2FF0EEEE
 HEX E0F2FF00000FFF0EEE
 HEX E0F222F00F22F00EEE
 HEX E0F2222F00000000EE
 HEX E0F222222F22002F0E
 HEX EE00F222F22220220E
 HEX EEE000FFF22220220E
 HEX EEEE0000FF22002F0E
 HEX EEEE000000000000EE
 HEX EEEEE0054450050EEE
 HEX EEEEE0544450550EEE
 HEX EEEEE0544450540EEE
 HEX EEEEE0554450540EEE
 HEX EEEEE0055450550EEE
 HEX EEEEE0505550050EEE
 HEX EEEE0555550050EEEE
 HEX EEEE0544500550EEEE
 HEX EEEE054550050EEEEE
 HEX EEEE055500550EEEEE
 HEX EEEE05550050EEEEEE
 HEX EEEE00000000EEEEEE
 HEX EEEE004400540EEEEE
 HEX EEEE0055400000EEEE
 HEX EEEEEE00000EEEEEEE

RHELD1_Y HEX 1700
RHELD1_X HEX 0E00
RHELD1 HEX EEEEEE066500000060000FE0000E
 HEX EEEEE0455005455060040F0FFFF0
 HEX EEEEE04505445000004000FFFFFF
 HEX EEEE005504450444450000000FFF
 HEX EEEE000554504444044022F000FF
 HEX EEEE05005540444440400002F0FF
 HEX EEEE0500005044444040F220000F
 HEX EEE045500000044440000F20F20F
 HEX EE0054450054402FFFF0EEEEEEEE
 HEX EE0554450055400F222FEEEEEEEE
 HEX EE054450000544022222EEEEEEEE
 HEX EE054450E005540F2220EEEEEEEE
 HEX E005450EEE005540F20EEEEEEEEE
 HEX E000550EEE00055000EEEEEEEEEE
 HEX 005000EEEE054450EEEEEEEEEEEE
 HEX 05550EEEEE054450EEEEEEEEEEEE
 HEX 05450EEEE005550EEEEEEEEEEEEE
 HEX 0550EEEEE055550EEEEEEEEEEEEE
 HEX 0000EEEEE05450EEEEEEEEEEEEEE
 HEX 05450EEEE00000EEEEEEEEEEEEEE
 HEX 055440EEE054500EEEEEEEEEEEEE
 HEX 000000EEE0554400EEEEEEEEEEEE
 HEX EEEEEEEEE0000000EEEEEEEEEEEE

RHELD2_Y HEX 1700
RHELD2_X HEX 0E00
RHELD2 HEX EEEEEE06650000006000EEEEEEEE
 HEX EEEEE04550054550600EEEEEEEEE
 HEX EEEEE0450544500000400FE0000E
 HEX EEEE00550445044445000F0FFFF0
 HEX EEEE000554504444044000FFFFFF
 HEX EEEE050055404444404000000FFF
 HEX EEEE050000504444404022F000FF
 HEX EEEE04500000044440000002F0FF
 HEX EEE005445005002FFFF0F220000F
 HEX EEE054445055000F222F0F20F20F
 HEX EEE0544450540E022222EEEEEEEE
 HEX EEE0554450540E0F2220EEEEEEEE
 HEX EEE0055450550EE0F20EEEEEEEEE
 HEX EEE0505550050EEE00EEEEEEEEEE
 HEX EE0555550050EEEEEEEEEEEEEEEE
 HEX EE0544500550EEEEEEEEEEEEEEEE
 HEX E054550050EEEEEEEEEEEEEEEEEE
 HEX E055500550EEEEEEEEEEEEEEEEEE
 HEX E05550050EEEEEEEEEEEEEEEEEEE
 HEX E00000000EEEEEEEEEEEEEEEEEEE
 HEX E004400540EEEEEEEEEEEEEEEEEE
 HEX E0055400000EEEEEEEEEEEEEEEEE
 HEX EEE00000EEEEEEEEEEEEEEEEEEEE

* linda lash

LINDA1_Y HEX 2800
LINDA1_X HEX 0900
LINDA1
 HEX EEEEEEEE0E0EE0E0EE
 HEX EEEEEEE0F0F00F0F0E
 HEX EEEEEE00F0F0F0F0EE
 HEX EEEEE00F00000F0EEE
 HEX EEEEE0F00F22F0EEEE
 HEX EEEEE0F0F22F20EEEE
 HEX EEEEE002FF0020EEEE
 HEX EEEEEE02F22F20EEEE
 HEX EEEEEEE00F2200EEEE
 HEX EEEEEEE0F0220EEEEE
 HEX EEEE000F2F00EEEEEE
 HEX EEE0F22FF200EEEEEE
 HEX EE02222222F20EEEEE
 HEX E0F2222F2222F0EEEE
 HEX 2F2222F022FF20EEEE
 HEX 2F222F00000000EEEE
 HEX 22F0000DDDD0D0EEEE
 HEX 222F0200DD00D0EEEE
 HEX F22F2002000000EEEE
 HEX 0F22222200D00EEEEE
 HEX E00F22220DD0EEEEEE
 HEX EEE0022F0DD0EEEEEE
 HEX EEEE0000DDD0EEEEEE
 HEX EEEE000DDDDD0EEEEE
 HEX EEEE0DDDD0DD0EEEEE
 HEX EEE0DDDD00DDD0EEEE
 HEX EEE0DDDD00DDD0EEEE
 HEX EEE0DDD0000DD0EEEE
 HEX EE0DDDD0E00DDD0EEE
 HEX EE0DDD0EEE00DD0EEE
 HEX E00DD00EEE0DDD0EEE
 HEX E00000EEEE00000EEE
 HEX 0F220EEEEE02220EEE
 HEX 0F2F0EEEEE022F0EEE
 HEX 0F20EEEEEE0220EEEE
 HEX 0FF0EEEEEE0220EEEE
 HEX 0F220EEEEE0FF0EEEE
 HEX 02F220EEEE0F220EEE
 HEX E00000EEEE020220EE
 HEX EEEEEEEEEEE00000EE

LINDA2_Y HEX 2700
LINDA2_X HEX 0900
LINDA2
 HEX EEEEEEEEE0E0EE0E0E
 HEX EEEEEEEE0F0F00F0F0
 HEX EEEEEEE00F0F0F0F0E
 HEX EEEEEE00F00000F0EE
 HEX EEEEEE0F00F22F0EEE
 HEX EEEEEE0F0F22F20EEE
 HEX EEEEEE002FF0020EEE
 HEX EEEEEEE02F22F20EEE
 HEX EEEEEEE000F2200EEE
 HEX EEEEEEEE0F0220EEEE
 HEX EEEEE000F2F00EEEEE
 HEX EEEE0F22FF200EEEEE
 HEX EEE02222222F20EEEE
 HEX EE0F2222F2222F0EEE
 HEX E0F2222F022FF20EEE
 HEX E0F222F00000000EEE
 HEX 022F0000DDDD0D0EEE
 HEX 0222F0200DD00D0EEE
 HEX 0F22F2002000000EEE
 HEX E0F22222200D00EEEE
 HEX EE00F22220DD0EEEEE
 HEX EEEE0022F0DD0EEEEE
 HEX EEEEE0000DDD0EEEEE
 HEX EEEEE000DDDDD0EEEE
 HEX EEEEE0DDDD00D0EEEE
 HEX EEEEE0DDDD00D0EEEE
 HEX EEEEE0DDDD00D0EEEE
 HEX EEEEEE0DDD00D0EEEE
 HEX EEEEEE0DDDD0D0EEEE
 HEX EEEEEE00DDD000EEEE
 HEX EEEEEE0DDDD000EEEE
 HEX EEEEEE00000000EEEE
 HEX EEEEEE0222F0F0EEEE
 HEX EEEEEE022F0F0EEEEE
 HEX EEEEEE02200F0EEEEE
 HEX EEEEEE0FF00F00EEEE
 HEX EEEEEE0F2200200EEE
 HEX EEEEEE020220000EEE
 HEX EEEEEE000000EEEEEE

LINDA3_Y HEX 2800
LINDA3_X HEX 0900
LINDA3
 HEX EEEEEEEEE0E0EE0E0E
 HEX EEEEEEEE0F0F00F0F0
 HEX EEEEEEEE0F0F0F0F0E
 HEX EEEEEEE0F00000F0EE
 HEX EEEEEE0F00F22F0EEE
 HEX EEEEEE0F0F22F20EEE
 HEX EEEEEE002FF0020EEE
 HEX EEEEEEE02F22F20EEE
 HEX EEEEEEE000F2200EEE
 HEX EEEEEEEE0F0220EEEE
 HEX EEEEE000F2F00EEEEE
 HEX EEEE0F22FF200EEEEE
 HEX EEE02222222F20EEEE
 HEX EE0F2222F2222F0EEE
 HEX E0F2222F022FF20EEE
 HEX E0F222F00000000EEE
 HEX 022F0000DDDD0D0EEE
 HEX 0222F0200DD00D0EEE
 HEX 0F22F2002000000EEE
 HEX E0F22222200D00EEEE
 HEX EE00F22220DD0EEEEE
 HEX EEEE0022F0DD0EEEEE
 HEX EEEEE0000DDD0EEEEE
 HEX EEEEE000DDDDD0EEEE
 HEX EEEEE00DDDD00EEEEE
 HEX EEEE0000DDDD0EEEEE
 HEX EEEE0000DDDDD0EEEE
 HEX EEEE0D000DDDD0EEEE
 HEX EEE00D0000DDDD0EEE
 HEX EEE0DDD0E00DDD0EEE
 HEX EE0DDD00E0DDDD0EEE
 HEX EE00000EE000000EEE
 HEX 0F220EEEE02220EEEE
 HEX 0F2F0EEEE022F0EEEE
 HEX 0F200EEEE02200EEEE
 HEX 0FF0EEEEE0220EEEEE
 HEX 0F2200EEE0FF00EEEE
 HEX 02F220EEE0F220EEEE
 HEX E00000EEE020220EEE
 HEX EEEEEEEEEE00000EEE

LPUNCH1_Y HEX 2800
LPUNCH1_X HEX 0B00
LPUNCH1
 HEX EEEEEEEE0E0EE0E0EEEEEE
 HEX EEEEEEE0F0F00F0F0EEEEE
 HEX EEEEEE00F0F0F0F0EEEEEE
 HEX EEEEE00F00000F0EEEEEEE
 HEX EEEEE0F00F22F0EEEEEEEE
 HEX EEEEE0F0F22F20EEEEEEEE
 HEX EEEEE002FF0020EEEEEEEE
 HEX EEEEEE02F22F20EEEEEEEE
 HEX EEEEEEE00F22000000000E
 HEX EEEEEEE0F0220022222200
 HEX EEEE000F2F000F222222F0
 HEX EEE0F22FF2000F2220F220
 HEX EE02222222F2F0F22F22F0
 HEX E0F2222F22222F0000000E
 HEX 2F2222F0222FF20EEEEEEE
 HEX 2F222F000000000EEEEEEE
 HEX 222F0000FFD0FD0EEEEEEE
 HEX 2222F0200D00D0EEEEEEEE
 HEX 2F22F200200000EEEEEEEE
 HEX E0F2222220D00EEEEEEEEE
 HEX EE00F22220DD0EEEEEEEEE
 HEX EEEE0022D0DD0EEEEEEEEE
 HEX EEEEE0000DD00EEEEEEEEE
 HEX EEEEE000D00000EEEEEEEE
 HEX EEEEEE00DDDD000EEEEEEE
 HEX EEEEE0000DDDD00EEEEEEE
 HEX EEEEE0000DDDDD0EEEEEEE
 HEX EEEEE0D000DDDD00EEEEEE
 HEX EEEE00D0000DDDD0EEEEEE
 HEX EEEE0DDD0E00DDD0EEEEEE
 HEX EEE0DDD00E0DDDD0EEEEEE
 HEX EEE00000EE000000EEEEEE
 HEX E0F220EEEE02220EEEEEEE
 HEX E0F2F0EEEE022F0EEEEEEE
 HEX E0F20EEEEE0220EEEEEEEE
 HEX E0FF0EEEEE0220EEEEEEEE
 HEX E0F220EEEE0FF0EEEEEEEE
 HEX E02F220EEE0F220EEEEEEE
 HEX EE00000EEE020220EEEEEE
 HEX EEEEEEEEEEE00000EEEEEE

LPUNCH2_Y HEX 2800
LPUNCH2_X HEX 0E00
LPUNCH2
 HEX EEEEEEEEEE0E0EE0E0EEEEEEEEEE
 HEX EEEEEEEEE0F0F00F0F0EEEEEEEEE
 HEX EEEEEEEEE0F0F0F0F0EEEEEEEEEE
 HEX EEEEEEEE0F00000F0EEEEEEEEEEE
 HEX EEEEEEE0F00F22F0EEEEEEEEEEEE
 HEX EEEEEEE0F0F22F20EEEEEEEEEEEE
 HEX EEEEEEE002FF0020EEEEEEEEEEEE
 HEX EEEEEEEE02F22F20EEEEEEEEEEEE
 HEX EEEEEEEE000F2200EEEEEEEEEEEE
 HEX EEEEEEEEE0F022000000EEEEEEEE
 HEX EEEEEE000F2F0022222F000000EE
 HEX EEEEE0F22FF2002222222F22220E
 HEX EEEE02222222F202F2222F2222F0
 HEX EEE0F2222F2222F00F222020F220
 HEX EE0F2222F022FF200000000F22F0
 HEX EE0F222F00000000EEEEEEE0000E
 HEX E022F0000FDFD0F0EEEEEEEEEEEE
 HEX E0222F0200DD00D0EEEEEEEEEEEE
 HEX E0F22F2002000000EEEEEEEEEEEE
 HEX EE0F22222200D00EEEEEEEEEEEEE
 HEX EEE00F22220DD0EEEEEEEEEEEEEE
 HEX EEEEE0022D0DD0EEEEEEEEEEEEEE
 HEX EEEEEE0000DDDDEEEEEEEEEEEEEE
 HEX EEEEEE000DDDDD0EEEEEEEEEEEEE
 HEX EEEEEE00DDDD00EEEEEEEEEEEEEE
 HEX EEEEE0000DDDD0EEEEEEEEEEEEEE
 HEX EEEEE0000DDDDD0EEEEEEEEEEEEE
 HEX EEEEE0D000DDDD0EEEEEEEEEEEEE
 HEX EEEE00D0000DDDD0EEEEEEEEEEEE
 HEX EEEE0DDD0E00DDD0EEEEEEEEEEEE
 HEX EEE0DDD00E0DDDD0EEEEEEEEEEEE
 HEX EEE00000EE000000EEEEEEEEEEEE
 HEX E0F220EEEE02220EEEEEEEEEEEEE
 HEX E0F2F0EEEE022F0EEEEEEEEEEEEE
 HEX E0F200EEEE02200EEEEEEEEEEEEE
 HEX E0FF0EEEEE0220EEEEEEEEEEEEEE
 HEX E0F2200EEE0FF00EEEEEEEEEEEEE
 HEX E02F220EEE0F220EEEEEEEEEEEEE
 HEX EE00000EEE020220EEEEEEEEEEEE
 HEX EEEEEEEEEEE00000EEEEEEEEEEEE

LCLIMB1_Y HEX 2700
LCLIMB1_X HEX 0900
LCLIMB1
 HEX EEEE00000EEEEEEEEE
 HEX EEE022F0F0EEEEEEEE
 HEX EE022F00FF0EEEEEEE
 HEX EE022020FF20EEEEEE
 HEX E0FF2020FF20EEEEEE
 HEX E022F020FF20EEEEEE
 HEX E022F020F020EEEEEE
 HEX 0F2F00F2F2F0EEEEEE
 HEX 0F22F00202F00000EE
 HEX 0F222F00F00FF02F0E
 HEX 0F22F222F2222F020E
 HEX E0222222222222200E
 HEX EE02F2222222F2220E
 HEX EEE0F2222222F222F0
 HEX EEEE0F22F22F0F2F0E
 HEX EEEE000000000000EE
 HEX EEEE0DDDDDDD0EEEEE
 HEX EEEEE0DDDDDD0EEEEE
 HEX EEEEE0DDDDD00EEEEE
 HEX EEEEE00DDDD000EEEE
 HEX EEEEE0DDDDDD00EEEE
 HEX EEEE0DDDDDDDD00EEE
 HEX EEEE0DDDDDDDDD0EEE
 HEX EEE0DDD0000DDD0EEE
 HEX EEE0DDDD0E00000EEE
 HEX EEE0DDDD0E0DDD0EEE
 HEX EEE0DDD00E0DD0EEEE
 HEX EEE0DDD0EE0DD00EEE
 HEX EEEE0DD0EE000D0EEE
 HEX EEEE0DDD0E0DD0EEEE
 HEX EEEEE0DD0E000EEEEE
 HEX EEEEE0DD0EEEEEEEEE
 HEX EEEEE0000EEEEEEEEE
 HEX EEEEED220EEEEEEEEE
 HEX EEEEE0220EEEEEEEEE
 HEX EEEE00D20EEEEEEEEE
 HEX EEEE02000EEEEEEEEE
 HEX EEEEE02D0EEEEEEEEE
 HEX EEEEEE000EEEEEEEEE

LCLIMB2_Y HEX 2700
LCLIMB2_X HEX 0900
LCLIMB2
 HEX EEEEEEEEE0E000EEEE
 HEX EEEEEEEE0F0F220EEE
 HEX EEEEEEE0FF00F220EE
 HEX EEEEEE02FF020220EE
 HEX EEEEEE02FF0202FF0E
 HEX EEEEEE02FF020F220E
 HEX EEEEEE020F020F220E
 HEX EEEEEE0F2F2F00F2F0
 HEX EE00E00F20200F22F0
 HEX E0F20FF00F00F222F0
 HEX E020F2222F222F22F0
 HEX EE022222222222220E
 HEX E0222F2222222F20EE
 HEX 0F222F2222222F0EEE
 HEX E0F2F0F22F22F0EEEE
 HEX EE000000000000EEEE
 HEX EEEEE0DDDDDDD0EEEE
 HEX EEEEE0DDDDDD0EEEEE
 HEX EEEEEE0DDDDD0EEEEE
 HEX EEEEE00DDDD00EEEEE
 HEX EEEE00DDDDDD0EEEEE
 HEX EEE00DDDDDDDD0EEEE
 HEX EEE0DDDDDDDDD0EEEE
 HEX EEE0DDD0000DDD0EEE
 HEX EEE00000E0DDDD0EEE
 HEX EEE0DDD0E0DDDD0EEE
 HEX EEEE0DD0EE0DDD0EEE
 HEX EEE00DD0EE0DDD0EEE
 HEX EEE0D000E00DD0EEEE
 HEX EEEE0DD0E0DDD0EEEE
 HEX EEEEE000E0DD0EEEEE
 HEX EEEEEEEEE0DD00EEEE
 HEX EEEEEEEEE00000EEEE
 HEX EEEEEEEEE022D0EEEE
 HEX EEEEEEEEE0220EEEEE
 HEX EEEEEEEEE02D00EEEE
 HEX EEEEEEEEE00020EEEE
 HEX EEEEEEEEE0D20EEEEE
 HEX EEEEEEEEE0000EEEEE

LFALL1_Y HEX 1700
LFALL1_X HEX 1000
LFALL1
 HEX EEEEEEEEE000EEEEEEEEEEEEEEEEEEEE
 HEX EEEF0F0E0F2F0EEEEEEEEEEEEEEEEEEE
 HEX EF0F0F0E022200EEEEEEEEEEEEEEEEEE
 HEX 0F0F0F0E02220F0EEEEEEEEEEEEEEEEE
 HEX 0FF0000EE0000200EEEEEEEEEEEEEEEE
 HEX 00000F20EE0F22F0EEEEEEEEEEEEEEEE
 HEX 0FF0F2220E0000F0EEEEEEEEEEEEEEEE
 HEX 0000000F00DDDDD0EEEE00000EEEEEEE
 HEX 0F0F22F000D000D00000DDDD000EE000
 HEX E0F22220020D2000D00000DD0D0EE020
 HEX E022222D00D2220000DDDD00D2D00020
 HEX EE0222DD00222220DDDDDD00D222D2D0
 HEX EE0D2D222D222200DDD0DDD000D2D20E
 HEX EEE0D22222D2D000DD00DDD0EE0D2D0E
 HEX EEEE0D2222D000000000000EEEE0000E
 HEX EEEEE0D22D0EEEEEE02220EEEEEEEEEE
 HEX EEEEEE0000EEEEEEE022D0EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEE0220EEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEE0220EEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEE0DD0EEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEE0D220EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEE020220EEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEE00000EEEEEEEEE

LFALL2_Y HEX 0F00
LFALL2_X HEX 1100
LFALL2
 HEX EEEEEEEEEEEEEEEEEEEEEEE000EEEEEEEE
 HEX EEEEEF0F0EEEEEEEEEEEEE0DDD0EEEEEEE
 HEX EEEF0F0F0EEEEEEEEEEEE000DDD0EEEEEE
 HEX EE0F0F0F0EEEEEEEEEEE00000DD0EEEEEE
 HEX EE0FF00000EE000EEEE00DDD00D0EEEEEE
 HEX EE00000F20E0DDD0EEE0DDDDD000EEEEEE
 HEX EE0FF0FF220DDDDD0E00DDDDDD00EEEEEE
 HEX EE000000200DDDDD000DDDDDDD000EEEEE
 HEX EE0FF0F20DDDDDD000DDD0DDD00000EE0E
 HEX EE00000000DDDD00DDDDD00DD00DD00020
 HEX E0F22F00D2D00000DDDDDD0000D22D0020
 HEX 002222FF22DDD00DD0DDDDD0000222D2D0
 HEX 0022222222DDD00DD0DDDD00000022D20E
 HEX E0F222F222DDDD0D00DDD00000000D2D0E
 HEX EE0000000000000000000000EE0000000E

LPUNCHED_Y HEX 2600
LPUNCHED_X HEX 0800
LPUNCHED
 HEX EEF0F00F000EEEEE
 HEX EE0F0F0F0F0EEEEE
 HEX EEE0FF0000F00EEE
 HEX EEEE0002200F0EEE
 HEX EEEE0F22F20000EE
 HEX EEEE00F000F020EE
 HEX EEEEE02F22FF20EE
 HEX EEEEEE00F22F0EEE
 HEX EEEEEE0F0F2F0EEE
 HEX EEE000F202F0EEEE
 HEX EE0F22FF0000EEEE
 HEX E02222222F200EEE
 HEX 0F2222F2222F00EE
 HEX F2222F022FF2F0EE
 HEX F222F000000000EE
 HEX 222F0000FDFD0F0E
 HEX 2222F0200DD00D0E
 HEX EF22F2002000000E
 HEX E0F22222200D00EE
 HEX EE00F22220DF0EEE
 HEX EEEE0022F0FD0EEE
 HEX EEEEE0000DDD0EEE
 HEX EEEEE000DDDDD0EE
 HEX EEEEE0DDDD00D0EE
 HEX EEEEE0DDDD00D0EE
 HEX EEEEE0DDDD00D0EE
 HEX EEEEEE0DDD00D0EE
 HEX EEEEEE0DDDD0D0EE
 HEX EEEEEE00DDD000EE
 HEX EEEEEE0DDDD000EE
 HEX EEEEEE00000000EE
 HEX EEEEEEE0222F0F0E
 HEX EEEEEEE022F0F0EE
 HEX EEEEEEE02200F0EE
 HEX EEEEEEE0FF00F00E
 HEX EEEEEEE0F2200200
 HEX EEEEEEE020220000
 HEX EEEEEEE000000EEE

LHELD1_Y HEX 1600
LHELD1_X HEX 1000
LHELD1 HEX EEEEEEEEEEEE0000000000EEEEEEEEEE
 HEX EEEEEEEEEE000DDDF0F44F0EEE0F0FEE
 HEX EEEEEEEEE00DFFFDF00000F0E000FF0E
 HEX EEEEEEEE00DDDFFD0F444F00004F00F0
 HEX EEEEEEE00DFD0DF0F44404F004000000
 HEX EEEEEEE00DFF0DD04444F040F44F00FF
 HEX EEEEEE00DDFD0000F44440F0444FF00F
 HEX EEEEE0000DFFD0000F4440000044F0F0
 HEX EEEEE0000DDFFD0000F4FFF0E0000000
 HEX EEEEE0D000DDFD00E00FF44FEEEEEEEE
 HEX EEEE00D0000DDDD0EE044444EEEEEEEE
 HEX EEEE0DDD0E00DFD0EE0F4440EEEEEEEE
 HEX EEE0DDD00E0DDDD0EEE0F40EEEEEEEEE
 HEX EEE00000EE000000EEEE00EEEEEEEEEE
 HEX E0F440EEEE04440EEEEEEEEEEEEEEEEE
 HEX E0F4F0EEEE044F0EEEEEEEEEEEEEEEEE
 HEX E0F40EEEEE0440EEEEEEEEEEEEEEEEEE
 HEX E0FF0EEEEE0440EEEEEEEEEEEEEEEEEE
 HEX E0F440EEEE0FF0EEEEEEEEEEEEEEEEEE
 HEX E04F440EEE0F440EEEEEEEEEEEEEEEEE
 HEX EE00000EEE040440EEEEEEEEEEEEEEEE
 HEX EEEEEEEEEEE00000EEEEEEEEEEEEEEEE

LHELD2_Y HEX 1700
LHELD2_X HEX 0D00
LHELD2 HEX EEEEE0000000000EEEEEEEEEEE
 HEX EEE000DDDF0F44F0EEEEEEEEEE
 HEX EE00DFFFDF00000F0EE0F0FEEE
 HEX E00DDDFFD0F444F00E000FF0EE
 HEX E0DFD0DF0F44404F0004F00F0E
 HEX E0DFF0DD04444F04004000000E
 HEX E0DFD00D0F44440F0F44F00FFE
 HEX E0DFD00000F444000444FF00FE
 HEX 0DFFD00D000F4FFF00044F0F0E
 HEX 0DDFD00D0E00FF44FE0000000E
 HEX 0DDFF00D0EE044444EEEEEEEEE
 HEX E0DFF00D0EE0F4440EEEEEEEEE
 HEX E0DDDD0D0EEE0F40EEEEEEEEEE
 HEX E00DFD000EEEE00EEEEEEEEEEE
 HEX E0DDDD000EEEEEEEEEEEEEEEEE
 HEX E00000000EEEEEEEEEEEEEEEEE
 HEX 0444F0F0EEEEEEEEEEEEEEEEEE
 HEX 044F0F0EEEEEEEEEEEEEEEEEEE
 HEX 04400F0EEEEEEEEEEEEEEEEEEE
 HEX 0FF00F00EEEEEEEEEEEEEEEEEE
 HEX 0F4400400EEEEEEEEEEEEEEEEE
 HEX 040440000EEEEEEEEEEEEEEEEE
 HEX 000000EEEEEEEEEEEEEEEEEEEE
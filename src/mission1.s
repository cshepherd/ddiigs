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
; HUD overlays
spr_pointright dw POINT_RIGHT
; Billy climb frames
spr_bclimb1    dw BCLIMB1
spr_bclimb2    dw BCLIMB2
; Linda climb frames
spr_lclimb1    dw LCLIMB1
spr_lclimb2    dw LCLIMB2

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
    db $01,$84,$00,BEHAV_NONE     ; xpos, ypos, orientation, behavior
    db OP_WAITCLR
    db OP_RIGHT,1       ; connect screen 0 to screen 1 on the right

; screen 2
    db OP_WAITX
    dw 400              ; wait for player abs X >= 400
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
     dw 640              ; wait for player abs X >= 600
     db OP_SCRLOCK
     db OP_NPC           ; Linda Lash descending ladder
     dw linda_sprite
     db $00,$00,$01,BEHAV_LADDER  ; xpos/ypos snapped by behavior
;     db OP_NPC           ; Linda Lash on ladder
;     dw linda_sprite
;     db 160,$3f,$02
;     db OP_WAITNPC,$01
;     db OP_NPC           ; Linda Lash on ladder
;     db OP_END           ; placeholder until the rest of mission 1 is built
;    dw linda_sprite
;    db 160,$5f,$02
;    db OP_WAITCLR
;    db OP_NPC           ; William from right
;    dw william_sprite
;    db $58,$5f,$01
;    db OP_NPC           ; William from left
;    dw william_sprite
;    db $01,$5f,$00
;    db OP_WAITNPC,$01
;    db OP_NPC           ; William from right
;    dw william_sprite
;    db $58,$5f,$01
    db OP_UP,5,6,7      ; Up to screen 5, left=screen 6, right=screen 7

; upper level (screen 5)
    db OP_SCRLOCK       ; lock scrolling on upper level
    db OP_NPC           ; William on upper level
    dw william_sprite
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
    db OP_UP,10,8,$ff     ; Up to screen 8, left=screen 9, right=none

    db OP_WAITXREV
    dw $02E0              ; wait for player to descend back to abs_x <= 718
    db OP_LEFT,9          ; enable leftward scroll to screen 9 (narrow, 102px)
    db OP_UP,12,$FF,11    ; enable climb on ladder 3 (scr12→scr10, scr11 rfill)

    db OP_WAITX
    dw 660              ; wait for player abs X >= 600

    db OP_RIGHT,13        ; enable right-scroll → scr13 after scr11

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
* Positioned at world byte 344..351 (spacebar showed world_x
* $0158 = 344 at the visible ladder art). check_ladder compares
* against world_offset+xpos, not abs_x. Shifted to track
* scroll_up_anchor 328 → 325 (see game.s :op_up_notscr10).
 dw 362                         ; x_left
 dw 369                         ; x_right
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

* Screen 0: y<80 blocked, y=80-199 full playfield
bounds_scr0
 LUP 80
 dfb 0,0
 --^
 LUP 120
 dfb 0,109
 --^

* Screen 1: same as screen 0
bounds_scr1
 LUP 80
 dfb 0,0
 --^
 LUP 120
 dfb 0,109
 --^

* Screen 2: walkable y=60-199 (extends to y=60 to connect with ladder y_bottom=59)
bounds_scr2
 LUP 60
 dfb 0,0
 --^
 LUP 140
 dfb 0,109
 --^

* Screen 3: same as screen 0
bounds_scr3
 LUP 80
 dfb 0,0
 --^
 LUP 120
 dfb 0,109
 --^

* Screen 4: walkable y=60-199 (extends to y=60 to connect with ladder y_bottom=59)
bounds_scr4
 LUP 60
 dfb 0,0
 --^
 LUP 140
 dfb 0,109
 --^

* Screen 5 (upper level): purple platform at top of first ladder.
* Walkable ypos=53..130 (78 rows). Covers both the platform
* (ypos=53..87) and the ladder-top "landing" range so snap
* preserve-ypos logic doesn't fall back to the bottom of walkable
* and teleport Billy after the scroll.
bounds_scr5
 LUP 53
 dfb 0,0
 --^
 LUP 78
 dfb 0,109
 --^
 LUP 69
 dfb 0,0
 --^

* Screen 6: same default
bounds_scr6
 LUP 80
 dfb 0,0
 --^
 LUP 120
 dfb 0,109
 --^

* Screen 7 (upper level): walkable band matches screen 5's
* upper road (y=40-59). Player transitions in from screen 5
* at this y band. Ladder at world byte 530..537 extends from
* y=0..59 (overlaps walkable) so up-climb moves out of the
* band once scroll_up is enabled.
bounds_scr7
 LUP 40
 dfb 0,0
 --^
 LUP 20
 dfb 0,109
 --^
 LUP 140
 dfb 0,0
 --^

* Screen 8: same default
bounds_scr8
 LUP 80
 dfb 0,0
 --^
 LUP 120
 dfb 0,109
 --^

* Screen 9: same default
bounds_scr9
 LUP 80
 dfb 0,0
 --^
 LUP 120
 dfb 0,109
 --^

* Screen 10: narrow upper-level platform at top of second ladder.
* Walkable ypos=27..47 (21 rows). snap_transition's fallback scan
* places Billy at ypos=47 (landing at the platform).
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

*==========================================================
* Sprite pixel data
*==========================================================
**
** BILLY sprites (note mask color is 6)
**

IMAGE01_X HEX 0900
IMAGE01_Y HEX 2800
IMAGE01
 HEX 6666666660FFFFFF66
 HEX 666666660FFFF2F2FF
 HEX 66666666FF0F0FFF2F
 HEX 66666660FF000F0FFF
 HEX 66666660FF0F000FF6
 HEX 66666660FF0F2F0006
 HEX 66666660F00F00F066
 HEX 66666660F0F22F2066
 HEX 6666600000F22F0066
 HEX 66660F2F000FFF0666
 HEX 6660F222F000000666
 HEX 66602222F000F22066
 HEX 66602222F00F222206
 HEX 6660F222000F222206
 HEX 6660F22F00FFF22206
 HEX 66600F202222FFF066
 HEX 666600222222006666
 HEX 66660022222F006666
 HEX 666600F22220A06666
 HEX 66660A0FFF0A066666
 HEX 6666600000AA066666
 HEX 666660AA999A066666
 HEX 66660AAA0AA0006666
 HEX 66660AAAA000006666
 HEX 66660AA99AA0066666
 HEX 66660AAA99A0066666
 HEX 666600AAA99A066666
 HEX 6666000AAA9A066666
 HEX 66600000AAAAA06666
 HEX 6660A0000AA9A06666
 HEX 6600AA006099A06666
 HEX 66000000600A006666
 HEX 660222206022F06666
 HEX 660222066022206666
 HEX 60F2206660F2206666
 HEX 60F206666602206666
 HEX 0F2F0666660FF06666
 HEX 0F2220666602220066
 HEX 60F222066602F22206
 HEX 660000066600000006

IMAGE02_X HEX 0800
IMAGE02_Y HEX 2800
IMAGE02
 HEX 66666660FFFFFF66
 HEX 6666660FFFF2F2FF
 HEX 666666FF0F0FFF2F
 HEX 666660FF000F0FFF
 HEX 666660FF0F000FF6
 HEX 666660FF0F2F0006
 HEX 666660F00F00F066
 HEX 666660F0F22F2066
 HEX 66600000F22F0066
 HEX 660F2F000FFF0666
 HEX 60F222F000000666
 HEX 602222F000F22066
 HEX 602222F00F222206
 HEX 60F222000F222206
 HEX 60F22F00FFF22206
 HEX 600F202222FFF066
 HEX 6600222222000666
 HEX 660022222F006666
 HEX 6600F22220A06666
 HEX 660A0FFF0A066666
 HEX 66600000AA066666
 HEX 6660AA999A066666
 HEX 660AAA0AA0066666
 HEX 660AAAA00A066666
 HEX 660A99A00A066666
 HEX 660AA9900A066666
 HEX 660AA99A0A066666
 HEX 6600AA9A00066666
 HEX 6660AAAAA0066666
 HEX 666000A9A0066666
 HEX 66660A99A0066666
 HEX 6666000000066666
 HEX 6660222F00666666
 HEX 666022F006666666
 HEX 66022F0066666666
 HEX 60FF20F066666666
 HEX 6022F0F066666666
 HEX 66022F0206666666
 HEX 666022F020666666
 HEX 6666000000666666

IMAGE03_X HEX 0B00
IMAGE03_Y HEX 2800
IMAGE03
 HEX 666666666660FFFFFF6666
 HEX 66666666660FFFF2F2FF66
 HEX 6666666666FF0F0FFF2F66
 HEX 6666666660FF000F0FFF66
 HEX 6666666660FF0F000FF666
 HEX 6666666660FF0F2F000666
 HEX 6666666660F00F00F06666
 HEX 6666666660F0F22F206666
 HEX 666666600000F22F006666
 HEX 6666660F2F000FFF066666
 HEX 666660F222F00000066666
 HEX 6666602222F000F2206666
 HEX 6666602222F00F22220666
 HEX 666660F222000F22220666
 HEX 666660F22F00FFF2220666
 HEX 6666600F202222FFF06666
 HEX 6666660022222200666666
 HEX 6666660022222F00666666
 HEX 66666600F22220A0666666
 HEX 6666660A0FFF0A06666666
 HEX 666666600000AA06666666
 HEX 66666660AA999A06666666
 HEX 6666660AAA0AA000666666
 HEX 6666660AAAA00000666666
 HEX 6666600A99A00A9A066666
 HEX 666660AA99A0AA99066666
 HEX 666660A99A000AA9A06666
 HEX 666660A99A0600AA906666
 HEX 666600AAA06660AAAA0666
 HEX 66660A99A066660A990666
 HEX 66660A9A0666660AAA0666
 HEX 6666000006666600A00666
 HEX 66602222066666022F0666
 HEX 6660222066666602220666
 HEX 660F22066666660F220666
 HEX 660F206666666660220666
 HEX 60F2F06666666660FF0666
 HEX 60F2220666666660222006
 HEX 660F2220666666602F2220
 HEX 6660000066666660000000

JUMP1_Y HEX 2800
JUMP1_X HEX 0A00
JUMP1
 HEX 66666666660FFFFFF666
 HEX 6666666660FFFF2F2FF6
 HEX 666666666FF0F0FFF2F6
 HEX 666666660FF000F0FFF6
 HEX 666666660FF0F000FF66
 HEX 666666660FF0F2F00066
 HEX 666666660F00F00F0666
 HEX 666666660F0F22F20666
 HEX 66666600000F22F00666
 HEX 666660F2F000FFF06666
 HEX 66660F222F0000006666
 HEX 666602222F000F220666
 HEX 666602222F00F2222066
 HEX 66660F222000F2222066
 HEX 66660F22F00FFF222066
 HEX 666600F202222FFF0666
 HEX 66666002222220066666
 HEX 666660022222F0066666
 HEX 6666600F222200066666
 HEX 66666000FFF000006666
 HEX 666660AA0000AA900666
 HEX 666660AAA99A099A0066
 HEX 666600AA0000AAA9A066
 HEX 66660A99AA00AAA99A06
 HEX 66660A999A000AAA9A06
 HEX 66660A99AA0000AAAA06
 HEX 66660A99A000000AA006
 HEX 66660AAAA00000000066
 HEX 66600A99A00006666666
 HEX 6660AA9A009906666666
 HEX 6660AAA0000906666666
 HEX 66600000066006666666
 HEX 66022220666666666666
 HEX 66022206666666666666
 HEX 60F22066666666666666
 HEX 60F20666666666666666
 HEX 0F2F0666666666666666
 HEX 0F222066666666666666
 HEX 60F22206666666666666
 HEX 66000006666666666666

JUMP2_Y HEX 1E00
JUMP2_X HEX 0F00
JUMP2
 HEX 660FFFFFF666666666666666666666
 HEX 60FFFF2F2FF6666666666666666666
 HEX 6FF0F0FFF2F6666666666666666666
 HEX 0FF000F0FFF6666666666666666666
 HEX 0FF0F000FF66666666666666666666
 HEX 0FF0F2F00066666666666666666666
 HEX 0F00F00F0666666666666666666666
 HEX 0F0F22F20666666666666666666666
 HEX 600F22F00000666666666666666666
 HEX 660FFF000F2F066666666666666666
 HEX 66000000F222F06666666666666666
 HEX 6022F000F222206666666666666666
 HEX 02222F00F222206666666666666666
 HEX 02222F000222F06666666666666666
 HEX 0222FFF00F22F06666666666666666
 HEX 60FFF222202F006666666666666666
 HEX 660002222220066666666666666666
 HEX 66600F222220006666666666666666
 HEX 6600002222F0A00066666666666666
 HEX 6020200FFF0AAAAA00006666666666
 HEX 60F020A000AA00999AA00066666666
 HEX 6020000AAAA00AA999AAAA00000000
 HEX 60FF00AA00000AAAAAA9A022F0F020
 HEX 66000FAAAA0000AAA0AAA0220FF020
 HEX 6600AA0000000000000AA02F0FF0F0
 HEX 6009AA022F0F0206660000000FF006
 HEX 60A9AA0220FF020666666666000666
 HEX 60AAAA02F0FF0F0666666666666666
 HEX 600AAA0000FF006666666666666666
 HEX 660000066000666666666666666666

JUMP3_Y HEX 2000
JUMP3_X HEX 0D00
JUMP3
 HEX 666666666666666660FFFFFF66
 HEX 66666666666666660FFFF2F2FF
 HEX 6666666666666666FF0F0FFF2F
 HEX 6666666666666660FF000F0FFF
 HEX 6666666666666660FF0F000FF6
 HEX 6666666666666660FF0F2F0006
 HEX 6666666666666660F00F00F066
 HEX 6666666666666660F0F22F2066
 HEX 666666666666000000022F0066
 HEX 666666666660F2200F0F2F0666
 HEX 66666666660F22220000FF0666
 HEX 6666666660F222220F00006666
 HEX 666666660F22222202F0666666
 HEX 6666666602FF22F00220666666
 HEX 666666660F22F000F2F0666666
 HEX 666666660222F0002206666666
 HEX 66666666022220F00066666666
 HEX 666666660F22F0FF0066666666
 HEX 666666660FFF00000000006666
 HEX 666666660F222200099AAA0666
 HEX 666666660F202020AAAAA9A066
 HEX 6666666600202020AA0AA99066
 HEX 6666666600F0F0F00A0AA9A066
 HEX 6666666600000000000AAA0066
 HEX 666666660AAA00000000000666
 HEX 666000660A9A00060022206666
 HEX 660F20000A9AA0660F22066666
 HEX 66022F20AA9AA0660F2F066666
 HEX 60F22220AAAA06660FF0066666
 HEX 0F2F0F20AAAA06660222006666
 HEX 02F000000AA0066602F2220666
 HEX 00066660000066660000000666

KICK1_Y HEX 2800
KICK1_X HEX 0900
KICK1
 HEX 666666666FFFFFF066
 HEX 6666666FF2F2FFFF06
 HEX 6666666F2FFF0F0FF6
 HEX 6666666FFF0F000FF0
 HEX 66666666FF000F0FF0
 HEX 66666666000F2F0FF0
 HEX 6666666660F00F00F0
 HEX 66666666602F22F0F0
 HEX 6666600000F22F0066
 HEX 66660F2F000FFF0666
 HEX 6660F222F000000666
 HEX 66602222F000F22066
 HEX 66602222F00F222206
 HEX 6660F222000F222206
 HEX 6660F22F00FFF22206
 HEX 66600F202222FFF066
 HEX 666000222222006666
 HEX 66600022222F066666
 HEX 6660A0F22220066666
 HEX 6660A00FFF00666666
 HEX 6666000000A0666666
 HEX 66660AA999A0666666
 HEX 6660AAA0AA00666666
 HEX 6660AAAA00A0666666
 HEX 66660A99A00A066666
 HEX 000000A9900A066666
 HEX 022FF0A99A0A066666
 HEX 0F2220AA9A00066666
 HEX 022F20AAAAA0066666
 HEX 02F00000A9A0066666
 HEX 0108800A99A0066666
 HEX 020666000000066666
 HEX 006666022220666666
 HEX 666666022206666666
 HEX 666660F22066666666
 HEX 666660F20666666666
 HEX 66660F2F0666666666
 HEX 66660F222066666666
 HEX 666660F22206666666
 HEX 666666000006666666

KICK2_Y HEX 2200
KICK2_X HEX 1400
KICK2 
 HEX 66666666666666666666666666666660FFFF6666
 HEX 6666666666666666666666666666660FFF2FF666
 HEX 66666666666666666666666666666600F2FFF066
 HEX 666666666666666666666666666666000F02F066
 HEX 6666666666666666666666666600000F000FFF06
 HEX 66666666666666666666666600F220FFF000FF06
 HEX 6666666666666666666666600F22220F2F00FF06
 HEX 66666666666666666666660A022222022F00FF06
 HEX 6666666666666666660000AA0222220FFF0F0006
 HEX 000000000000666660A000AA02FF2F0000000066
 HEX 020F0F220AA0000000A90AAA00222F00FF000666
 HEX 020FF0220AAA0AAA000AAAA00F2222FF22F06666
 HEX 0F0FF0F20A9AAAAAAA0000000F22222F22206666
 HEX 600FF000AAAA999AAAA000000F22222F22206666
 HEX 66600066000AA999A0A9AA0000F222FFF0F06666
 HEX 66666666660000AAAA0A9AA00000000000066666
 HEX 66666666666666000A00A9A06666666666666666
 HEX 66666666666666660AA0AAA06666666666666666
 HEX 666666666666666660A99A006666666666666666
 HEX 666666666666666660A99AA06666666666666666
 HEX 6666666666666666600A99A06666666666666666
 HEX 6666666666666666660A99A06666666666666666
 HEX 66666666666666666660AAA00666666666666666
 HEX 66666666666666666660A99A0666666666666666
 HEX 666666666666666666660A9A0666666666666666
 HEX 6666666666666666666600000666666666666666
 HEX 66666666666666666666022F0666666666666666
 HEX 6666666666666666666602220666666666666666
 HEX 666666666666666666660F220666666666666666
 HEX 6666666666666666666660220666666666666666
 HEX 6666666666666666666660FF0666666666666666
 HEX 6666666666666666666660222006666666666666
 HEX 66666666666666666666602F2220666666666666
 HEX 6666666666666666666660000000666666666666

PUNCH11_Y HEX 2800
PUNCH11_X HEX 0B00
PUNCH11
 HEX 6666666660FFFFFF666666
 HEX 666666660FFFF2F2FF6666
 HEX 66666666FF0F0FFF2F6666
 HEX 66666660FF000F0FFF6666
 HEX 66666660FF0F000FF66666
 HEX 66666660FF0F2F00066666
 HEX 66666660F00F00F0666666
 HEX 66666660F0F22F20666666
 HEX 6666660000F22F00000666
 HEX 666660AA000FF000022206
 HEX 66660AAAF0000FF2F22220
 HEX 66660A9A1F0F2222F22220
 HEX 6660A99A0F222222F20F20
 HEX 6660A9AA0222222F00F206
 HEX 6660A9AA022222F0600066
 HEX 6600AAAA0F222F06666666
 HEX 660000AAA0FFF066666666
 HEX 6600A000AAA00066666666
 HEX 60AA9AAAAAA00666666666
 HEX 600AA99AAA006666666666
 HEX 6600000000006666666666
 HEX 66600000AA006666666666
 HEX 66600AAAAAA06666666666
 HEX 66600AAAAAA06666666666
 HEX 666660AA99AA0066666666
 HEX 666660AAA99A0066666666
 HEX 6666600AAA99A066666666
 HEX 66666000AAA9A066666666
 HEX 666600000AAAAA06666666
 HEX 66660A0000AA9A06666666
 HEX 66600AA006099A06666666
 HEX 666000000600A006666666
 HEX 6660222206022F06666666
 HEX 6660222066022206666666
 HEX 660F2206660F2206666666
 HEX 660F206666602206666666
 HEX 60F2F0666660FF06666666
 HEX 60F2220666602220066666
 HEX 660F222066602F22206666
 HEX 6660000066600000006666

PUNCH12_Y HEX 2800
PUNCH12_X HEX 1000
PUNCH12
 HEX 666666666660FFFFFF66666666666666
 HEX 66666666660FFFF2F2FF666666666666
 HEX 6666666666FF0F0FFF2F666666666666
 HEX 6666666660FF000F0FFF666666666666
 HEX 6666666660FF0F000FF6666666666666
 HEX 6666666660FF0F2F0006666666666666
 HEX 6666666660F00F00F066666666666666
 HEX 6666666660F0F22F0000000000000666
 HEX 66666666000000000FFFFFF22F022206
 HEX 6666666000AAAAA0F2222F2222F22220
 HEX 666660FF0AAAA9A02222222222F22220
 HEX 666602200AAA99A02222222222F20F20
 HEX 666022F0AAA099A0222222F2F000F206
 HEX 66602200AAA0A9A0F22FF00066600066
 HEX 66660F00AAA0AAA00000066666666666
 HEX 66660000AAA000AA6666666666666666
 HEX 66660000AAAAAAA06666666666666666
 HEX 666600A000AAA0006666666666666666
 HEX 6660AA9AAAAAA0066666666666666666
 HEX 66600AA99AAA00666666666666666666
 HEX 66660000000000666666666666666666
 HEX 6666600000AA00666666666666666666
 HEX 6666600AAAAAA0666666666666666666
 HEX 6666600AAAAAA0666666666666666666
 HEX 666660AA99AA00666666666666666666
 HEX 666660AAA99A00666666666666666666
 HEX 6666600AAA99A0666666666666666666
 HEX 66666000AAA9A0666666666666666666
 HEX 666600000AAAAA066666666666666666
 HEX 66660A0000AA9A066666666666666666
 HEX 66600AA006099A066666666666666666
 HEX 666000000600A0066666666666666666
 HEX 6660222206022F066666666666666666
 HEX 66602220660222066666666666666666
 HEX 660F2206660F22066666666666666666
 HEX 660F2066666022066666666666666666
 HEX 60F2F0666660FF066666666666666666
 HEX 60F22206666022200666666666666666
 HEX 660F222066602F222066666666666666
 HEX 66600000666000000066666666666666

PUNCH21_Y HEX 2800
PUNCH21_X HEX 0A00
PUNCH21
 HEX 666666660FFFFFF66666
 HEX 66666660FFFF2F2FF666
 HEX 6666666FF0F0FFF2F666
 HEX 6666660FF000F0FFF666
 HEX 6666660FF0F000FF0666
 HEX 6666660FF0F2F0002206
 HEX 6666660F00F00F022220
 HEX 6666660F0F22F202F220
 HEX 666600000F22F002FF20
 HEX 6660F2F000FFF0F22F06
 HEX 660F222F000000600066
 HEX 6602222F000F22066666
 HEX 6602222F00F222206666
 HEX 660F222000F222206666
 HEX 660F22F00FFF22206666
 HEX 6600F202222FFF066666
 HEX 6660002222220A066666
 HEX 66600022222F0A066666
 HEX 6660A0F222200A066666
 HEX 6660A00FFF0000066666
 HEX 66660000000060066666
 HEX 66660AA9AA0066666666
 HEX 6660AAA0AA0666666666
 HEX 6660AAAAAA0666666666
 HEX 66660AA99AA006666666
 HEX 66660AAA99A006666666
 HEX 666600AAA99A06666666
 HEX 6666000AAA9A06666666
 HEX 66600000AAAAA0666666
 HEX 6660A0000AA9A0666666
 HEX 6600AA006099A0666666
 HEX 66000000600A00666666
 HEX 660222206022F0666666
 HEX 66022206602220666666
 HEX 60F2206660F220666666
 HEX 60F20666660220666666
 HEX 0F2F0666660FF0666666
 HEX 0F222066660222006666
 HEX 60F222066602F2220666
 HEX 66000006660000000666
PUNCH21LEN EQU *-PUNCH21

PUNCH22_Y HEX 2800
PUNCH22_X HEX 1000
PUNCH22
 HEX 66666666660FFFFFF666666666666666
 HEX 6666666660FFFF2F2FF6666666666666
 HEX 666666666FF0F0FFF2F6666666666666
 HEX 666666660FF000F0FFF6666666666666
 HEX 666666660FF0F000FF66666666666666
 HEX 666666660FF0F2F00006666600000666
 HEX 666666660F00F00F002000F222022206
 HEX 666666660F0F22F202222F2220222220
 HEX 66666600000F22F0022222222022F220
 HEX 666660F2F000FFF0F22222222022FF20
 HEX 66660F222F000000FF222022F0022F06
 HEX 666602222F000F220FFFFF0066600066
 HEX 666602222F00F2222000006666666666
 HEX 66660F222000F2222066666666666666
 HEX 66660F22F00FFF222066666666666666
 HEX 666600F202222FFF0066666666666666
 HEX 66660002222220A06666666666666666
 HEX 666600022222F0A06666666666666666
 HEX 66660A0F222200A06666666666666666
 HEX 66660A00FFF000006666666666666666
 HEX 66666000000006006666666666666666
 HEX 666660AA9AA006666666666666666666
 HEX 66660AAA0AA066666666666666666666
 HEX 66660AAAAAA066666666666666666666
 HEX 66660AA99AA006666666666666666666
 HEX 66660AAA99A006666666666666666666
 HEX 666600AAA99A06666666666666666666
 HEX 6666000AAA9A06666666666666666666
 HEX 66600000AAAAA0666666666666666666
 HEX 6660A0000AA9A0666666666666666666
 HEX 6600AA006099A0666666666666666666
 HEX 66000000600A00666666666666666666
 HEX 660222206022F0666666666666666666
 HEX 66022206602220666666666666666666
 HEX 60F2206660F220666666666666666666
 HEX 60F20666660220666666666666666666
 HEX 0F2F0666660FF0666666666666666666
 HEX 0F222066660222006666666666666666
 HEX 60F222066602F2220666666666666666
 HEX 66000006660000000666666666666666

BPUNCHED_Y HEX 2800
BPUNCHED_X HEX 0B00
BPUNCHED
 HEX 6666666000666666666666
 HEX 6666FFFFFF066666666666
 HEX 666FFF2FFFFF0666666666
 HEX 66FF2FF000FF0666666666
 HEX 66FF2F0000000066666666
 HEX 660FFF000F002066666666
 HEX 6660F0022FF02066666666
 HEX 666600F200FF0066666666
 HEX 666666000002F066666666
 HEX 666666000202F066666666
 HEX 6666000000220066666666
 HEX 6660F2F000000066666666
 HEX 660F222F02F0F006666666
 HEX 66022222022F2206666666
 HEX 660222220222F2F0666666
 HEX 660F22220F220220666666
 HEX 6660222000FF00F0666666
 HEX 6660F2FFF0000000066666
 HEX 6660F2222F000222006666
 HEX 6666022222F0220F206666
 HEX 66660F222F022220F06666
 HEX 6666600FFF0F20F2066666
 HEX 6666660000000000666666
 HEX 6666666000000006666666
 HEX 66666660CCBBCC00666666
 HEX 66666660CCCBBC00666666
 HEX 666666600CCCBBC0666666
 HEX 6666666000CCCBC0666666
 HEX 66666600000CCCCC066666
 HEX 8888880C0000CCBC088888
 HEX 6666600CC0060BBC066666
 HEX 66666000000600C0066666
 HEX 6666000000066022F06666
 HEX 6666002220666022206666
 HEX 66660F22066660F2206666
 HEX 66660F2F06666602206666
 HEX 66660FF00666660FF06666
 HEX 6666022200666602220066
 HEX 666602F222066602F22206
 HEX 6666000000066600000006

BCLIMB1_Y HEX 2800
BCLIMB1_X HEX 0800
BCLIMB1
 HEX 666660FFF0022066
 HEX 66660F222F002206
 HEX 6660F22F2FF00006
 HEX 6660FF2FFFF02206
 HEX 6660FFFFFFF02220
 HEX 66600FFFFFF02220
 HEX 66000FF0FF000222
 HEX 6020000000002222
 HEX 02000AAAAA000020
 HEX 2020A99AAAAA0202
 HEX 0220A9AAAA9A0220
 HEX 0220AAAAAA9A0220
 HEX 0220AAAAAAAA0220
 HEX 6020AA0AAAAA0206
 HEX 6600A00AA0AA0066
 HEX 666000AAAA000666
 HEX 6660AAAAAAAA0666
 HEX 6660AAAAAAAA0666
 HEX 666000AAAAAA0666
 HEX 600A000000000066
 HEX 0A99AAAAAAAAA066
 HEX 0AAA0AAAAAAAA066
 HEX 60AAA00AAAAAA066
 HEX 600000000000A066
 HEX 6022200000AA9066
 HEX 60F22F0600A99066
 HEX 66022F0600A9A066
 HEX 660F2F060AAAA066
 HEX 66002F060AAA0066
 HEX 60F2000600A90666
 HEX 660F22060AAA0666
 HEX 6660000600000666
 HEX 6666666002220666
 HEX 66666660F22F0666
 HEX 66666660F2206666
 HEX 66666660F2F06666
 HEX 66666660F2006666
 HEX 66666660002F0666
 HEX 6666666022F06666
 HEX 6666666600066666

BCLIMB2_Y HEX 2800
BCLIMB2_X HEX 0800
BCLIMB2
 HEX 6602200FFF066666
 HEX 602200F222F06666
 HEX 60000FF2F22F0666
 HEX 60220FFFF2FF0666
 HEX 02220FFFFFFF0666
 HEX 02220FFFFFF00666
 HEX 222000FF0FF00066
 HEX 2222000000000206
 HEX 020000AAAAA00020
 HEX 2020AAAAA99A0202
 HEX 0220A9AAAA9A0220
 HEX 0220A9AAAAAA0220
 HEX 0220AAAAAAAA0220
 HEX 6020AAAAA0AA0206
 HEX 6600AA0AA00A0066
 HEX 666000AAAA000066
 HEX 6660AAAAAAAA0666
 HEX 6660AAAAAAAA0066
 HEX 6660AAAAAA000066
 HEX 666000000000A006
 HEX 660AAAAAAAAA99A0
 HEX 660AAAAAAAA0AAA0
 HEX 660AAAAAA00AAA06
 HEX 660A000000000006
 HEX 6609AA0000022206
 HEX 66099A0000F22F06
 HEX 660A9A0060F22066
 HEX 660AAAA060F2F066
 HEX 6600AAA060F20066
 HEX 66609A0060002F06
 HEX 6660AAA06022F066
 HEX 6660000060000666
 HEX 6660222006666666
 HEX 6660F22F06666666
 HEX 6666022F06666666
 HEX 66660F2F06666666
 HEX 6666002F06666666
 HEX 6660F20006666666
 HEX 66660F2206666666
 HEX 6666600066666666

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

* pointy fingers
POINT_RIGHT_Y HEX 1000
POINT_RIGHT_X HEX 0C00
POINT_RIGHT
 HEX 77777700CCC0CCCCCCCCC077
 HEX 77777C09BBBC9BBBBBBB9007
 HEX 77770AB1111BC1111BB11907
 HEX 7778AB11B111CB111BB11907
 HEX 77709B11B11179BBBBBBBC07
 HEX 800AB11B9B118CACAAAAC077
 HEX C9C911B9CBB17A99C0808777
 HEX 0B691B9AC9BB0B1BA7777777
 HEX 0159BBC00899911BC7777777
 HEX 0159BB59C00099A007777777
 HEX 81BA9B11BAC0C55AC7777777
 HEX 0BBA99B1B906B11BA7777777
 HEX 791BAABBB971111157777777
 HEX 6091BA0A998BB1BA07777777
 HEX 7709B90CCC0CC7C077777777
 HEX 7776C8067777777777777777

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
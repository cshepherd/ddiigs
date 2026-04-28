*----------------------------------------------------------
* DDIIGS
* Mission 1, toolbox init, sprite display
*----------------------------------------------------------
    org $2000

NinjaTrackerPlus        =   $110000
NTPprepare              =   NinjaTrackerPlus
NTPplay                 =   NinjaTrackerPlus+3
NTPstop                 =   NinjaTrackerPlus+6
NTPgetvuptr             =   NinjaTrackerPlus+9
NTPgete8ptr             =   NinjaTrackerPlus+12
NTPforcesongpos         =   NinjaTrackerPlus+15
NTPgetsongpos           =   NinjaTrackerPlus+18
NTPsetplayvolume        =   NinjaTrackerPlus+21
NTPstreamsound          =   NinjaTrackerPlus+24

]IOBUF = $8200        ; 1024-byte ProDOS I/O buffer (page-aligned)
]RDBUF = $8600         ; 4KB read buffer

* Clear text screen so diagnostic prints start on a fresh page.
 jsr $FC58

* Initialize IIgs Toolbox
 jsr toolbox_init

* Enable SHR shadowing (bank $01 -> $E1) before loading
 clc
 xce
 sep $20
 ldal $C035
 and #$F7             ; clear bit 3
 stal $C035
 ldal $C034
 and #$F0
 stal $C034
 sec
 xce                   ; back to emulation for ProDOS calls

* Load MISSION1 level data to bank $02
 lda #<mission1_path
 sta ntp_open+1
 lda #>mission1_path
 sta ntp_open+2
 lda #$02
 sta ntp_bank
 jsr load_ntp_file

* Initialize level from bank $02 data
 jsr init_level

* Load NTPPLAYER to bank $11 starting at $11/0000 (moved from
* $0F to make room for MISSION112/113/114 at $0E/$0F/$10).
 lda #<ntpp_path
 sta ntp_open+1
 lda #>ntpp_path
 sta ntp_open+2
 lda #$11
 sta ntp_bank
 jsr load_ntp_file

* Load MISSION1.NTP to banks $12+ starting at $12/0000 (moved
* from $10 to clear room for the new scr13 load).
 lda #<m1ntp_path
 sta ntp_open+1
 lda #>m1ntp_path
 sta ntp_open+2
 lda #$12
 sta ntp_bank
 jsr load_ntp_file

* Load MISSION11.PAK -> $17, unpack to $03 (screen 0)
 lda #$03
 sta unpack_bank
 jsr load_and_unpack
* Copy $03/2000 -> $18/2000 (playfield shadow), then $18 -> $01
 jsr copy_03_to_50
 jsr copy_50_to_01

* Load MISSION12.PAK -> $04 (screen 1)
 lda #<path12
 sta p_open+1
 lda #>path12
 sta p_open+2
 lda #$04
 sta unpack_bank
 jsr load_and_unpack

* Load MISSION13.PAK -> $05 (screen 2)
 lda #<path13
 sta p_open+1
 lda #>path13
 sta p_open+2
 lda #$05
 sta unpack_bank
 jsr load_and_unpack

* Load MISSION14.PAK -> $06 (screen 3)
 lda #<path14
 sta p_open+1
 lda #>path14
 sta p_open+2
 lda #$06
 sta unpack_bank
 jsr load_and_unpack

* Load MISSION15.PAK -> $07 (screen 4)
 lda #<path15
 sta p_open+1
 lda #>path15
 sta p_open+2
 lda #$07
 sta unpack_bank
 jsr load_and_unpack

* Load MISSION16.PAK -> $08 (screen 5)
 lda #<path16
 sta p_open+1
 lda #>path16
 sta p_open+2
 lda #$08
 sta unpack_bank
 jsr load_and_unpack

* Load MISSION17.PAK -> $09 (screen 6)
 lda #<path17
 sta p_open+1
 lda #>path17
 sta p_open+2
 lda #$09
 sta unpack_bank
 jsr load_and_unpack

* Load MISSION18.PAK -> $0A (screen 7)
 lda #<path18
 sta p_open+1
 lda #>path18
 sta p_open+2
 lda #$0A
 sta unpack_bank
 jsr load_and_unpack

* Load MISSION19.PAK -> $0B (screen 8)
 lda #<path19
 sta p_open+1
 lda #>path19
 sta p_open+2
 lda #$0B
 sta unpack_bank
 jsr load_and_unpack

* Load MISSION110.PAK -> $0C (screen 9)
 lda #<path110
 sta p_open+1
 lda #>path110
 sta p_open+2
 lda #$0C
 sta unpack_bank
 jsr load_and_unpack

* Load MISSION111.PAK -> $0D (screen 10)
 lda #<path111
 sta p_open+1
 lda #>path111
 sta p_open+2
 lda #$0D
 sta unpack_bank
 jsr load_and_unpack

* Load MISSION112.PAK -> $0E (screen 11)
 lda #<path112
 sta p_open+1
 lda #>path112
 sta p_open+2
 lda #$0E
 sta unpack_bank
 jsr load_and_unpack

* Load MISSION113.PAK -> $0F (screen 12)
 lda #<path113
 sta p_open+1
 lda #>path113
 sta p_open+2
 lda #$0F
 sta unpack_bank
 jsr load_and_unpack

* Load MISSION114.PAK -> $10 (screen 13)
 lda #<path114
 sta p_open+1
 lda #>path114
 sta p_open+2
 lda #$10
 sta unpack_bank
 jsr load_and_unpack

* Enable SHR mode
 lda #$c1
 sta $e0c029

 clc
 xce
 rep $30

  ldy #$12              ; music banks start at $12
  ldx #$00
  txa
  jsl NTPprepare

  lda #00
  jsl NTPplay

 lda #225
 pha
 lda #20
 pha
 ldx #$3a04         ; MoveTo
 jsl $E10000

 pea #$0001
 ldx #$A004
 jsl $E10000        ; SetForeColor

 pea #$0000
 ldx #$A204
  jsl $E10000        ; SetBackColor

 lda #3
 pha
 lda #195
 pha
 ldx #$3a04         ; MoveTo
 jsl $E10000

 pea #$0001         ; bit 1 = bold
 ldx #$9A04
 jsl $E10000        ; SetTextFace

 pea ^string5
 pea string5
 ldx #$A604
 jsl $E10000        ; DrawCString

 sec
 xce
 sep #$30

 bra over1

string5 ASC 'PLAYER 1: 0000000       PLAYER 2: 0000000',00

over1
* Initial draw of all sprites
 jsr draw_all

*==========================================================
* Main game loop
*==========================================================
game_loop
 jsr check_pause       ; ESC tap toggles paused
 jsr check_debug_xy    ; 'd' tap toggles hex xpos/ypos readout
 lda paused
 bne :gl_paused_idle   ; frozen: skip all per-frame work
 jsr update_overlay
 jsr process_input
 jsr run_script
 jsr update_npcs       ; runs behavior state machines
 jsr update_anims
* Invariant check: abs_x must equal world_offset + IMAGE01_XPOS.
* Placed after every position-mutating pass (process_input walks
* and scrolls; update_anims advances xpos per VBL for jumps).
 jsr assert_abs_x
* Art-alignment checks: scroll_src_off / scroll_lsrc_off should
* be derivable from world_offset + screen_origin_x. Drift in
* these accumulators is the usual cause of late-level art
* offsets. Skipped for screens whose origin is $FFFF in the
* table (fill in as values become known).
 jsr assert_scroll_src_off
 jsr assert_scroll_lsrc_off
* Align $01-write burst to VBL: state work above ran during the
* previous frame's scan period (CPU was idle anyway); now wait
* for vertical blanking so erase/draw start at the very top of
* the next frame's window, well before scan reaches their rows.
 jsr wait_for_vbl
 jsr erase_all
 jsr draw_all
 jsr draw_overlay
 jsr draw_p1_score
 jsr draw_debug_xy
; jsr draw_ladder_debug   ; outline ladders for debug
 bra game_loop
:gl_paused_idle
 jsr wait_for_vbl       ; pace pause-detection at 60Hz
 bra game_loop

*----------------------------------------------------------
* run_script - Execute level script bytecode from bank $02.
* Called each frame. Executes immediate opcodes until hitting
* a blocking op (WAITX, WAITY, WAITCLR) or END.
* When blocked, checks condition each frame until satisfied.
*----------------------------------------------------------
run_script
 lda script_state
 cmp #SCRIPT_DONE
 beq :rs_rts           ; level ended, nothing to do

* Check if we're waiting on a condition
 cmp #SCRIPT_WAITX
 bne :nwx
 jmp :check_waitx
:nwx cmp #SCRIPT_WAITY
 bne :nwy
 jmp :check_waity
:nwy cmp #SCRIPT_WAITCLR
 bne :nwc
 jmp :check_waitclr
:nwc cmp #SCRIPT_WAITNPC
 bne :nwn
 jmp :check_waitnpc
:nwn cmp #SCRIPT_WAITUP
 bne :nwu
 jmp :check_waitup
:nwu cmp #SCRIPT_WAITXREV
 bne :nwxr
 jmp :check_waitxrev
:nwxr

* SCRIPT_RUN — execute opcodes
:exec_loop
 ldy #0
 lda [script_pc],y     ; read opcode byte
 and #$FF              ; mask to 8-bit (emulation mode load is already 8-bit)

 cmp #OP_END
 bne :not_end
 lda #SCRIPT_DONE
 sta script_state
:rs_rts rts

:not_end
 cmp #OP_SCREEN
 bne :not_screen
* OP_SCREEN: param = 1 byte screen index
 ldy #1
 lda [script_pc],y     ; screen index
 jsr script_set_screen
 lda script_pc
 clc
 adc #2                ; opcode(1) + param(1)
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 jmp :exec_loop

:not_screen
 cmp #OP_NPC
 bne :not_npc
* OP_NPC: params = dw sprite_ptr(2), db xpos(1), db ypos(1), db orient(1), db behavior(1)
 ldy #1
 lda [script_pc],y     ; sprite_ptr low
 sta sc_npc_ptr
 iny
 lda [script_pc],y     ; sprite_ptr high
 sta sc_npc_ptr+1
 ldy #3
 lda [script_pc],y     ; xpos
 sta sc_npc_x
 ldy #4
 lda [script_pc],y     ; ypos
 sta sc_npc_y
 ldy #5
 lda [script_pc],y     ; orientation (mirror)
 sta sc_npc_orient
 ldy #6
 lda [script_pc],y     ; behavior
 sta sc_npc_behavior
 jsr script_spawn_npc
 lda script_pc
 clc
 adc #7                ; opcode(1) + ptr(2) + x(1) + y(1) + orient(1) + behavior(1)
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 jmp :exec_loop

:not_npc
 cmp #OP_RIGHT
 bne :not_right
* OP_RIGHT: param = 1 byte screen index
 ldy #1
 lda [script_pc],y
 sta scroll_right_screen
* scroll_src_bank represents "next content to bring in on right
* scroll". Each screen N is loaded into bank $03+N.
*
* Three cases for scroll_src_bank at this point:
*   a) Already = target bank → previous wrap left us here; keep
*      scroll_src_off so no revealed content is repeated.
*   b) Pointing at current_screen's bank → still have unseen
*      bytes of the current screen to scroll through (typical
*      after OP_UP in :neg alignment); leave scroll_src alone
*      so we finish the current screen first. The wrap at
*      scroll_src_off=110 will transition to target via the
*      scroll_right_screen+3 logic in :fn_wrap.
*   c) Stale (pointing at unrelated bank) → override with
*      target and restart at off=0.
 clc
 adc #$03
 cmp scroll_src_bank
 beq :rt_same_bank
 pha                   ; save target bank
 lda current_screen
 clc
 adc #$03
 cmp scroll_src_bank
 bne :rt_check_midscroll
 pla                   ; scroll_src on current screen — keep off
 bra :rt_same_bank
:rt_check_midscroll
* scroll_src isn't on current or on target. If we're mid-scroll
* (scroll_src_off != 0), keep scroll_src alone — this preserves
* ongoing rneighbor content (e.g. scr11 after OP_UP,12,$FF,11)
* so scrolling right finishes revealing it before the eventual
* wrap jumps to scroll_right_screen. Only override if scr_src
* is genuinely stale (off = 0).
 lda scroll_src_off
 bne :rt_keep_midscroll
 pla                   ; off = 0 → truly stale, override
 sta scroll_src_bank
 stz scroll_src_off
 bra :rt_same_bank
:rt_keep_midscroll
 pla                   ; discard target, keep scroll_src
:rt_same_bank
 lda #1
 sta scroll_right_enabled
* Show POINT_RIGHT overlay (right side, arrow points right) for 180 frames
 jsr clear_active_overlay
 lda #180
 sta overlay_timer
 lda #100
 sta overlay_x
 lda #120
 sta overlay_y
 lda #$0C
 sta overlay_w
 lda #$10
 sta overlay_h
 stz overlay_mirror
 lda spr_pointright
 sta overlay_addr
 lda spr_pointright+1
 sta overlay_addr+1
 lda spr_pointright_mask
 sta overlay_mask
 lda spr_pointright_mask+1
 sta overlay_mask+1
 lda script_pc
 clc
 adc #2
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 jmp :exec_loop

:not_right
 cmp #OP_LEFT
 bne :not_left
 ldy #1
 lda [script_pc],y
 sta scroll_left_screen
* Configure left source: bank of target screen, offset starts at
* rightmost byte (109) so first fill pulls real pixels. scr9 is
* now full-width art so the previous narrow special-case is gone.
* Special case: if the target bank already matches scroll_lsrc_bank
* (e.g., snap_transition pre-set lsrc to OP_UP's lbank, and we're
* enabling left-scroll into that same screen), preserve
* scroll_lsrc_off so the scroll continues from where the lgap fill
* left off without a visible jump.
 clc
 adc #$03
 cmp scroll_lsrc_bank
 beq :op_left_keep_off
 sta scroll_lsrc_bank
 lda #109
 sta scroll_lsrc_off
 bra :op_left_off_done
:op_left_keep_off
 sta scroll_lsrc_bank
:op_left_off_done
 lda #1
 sta scroll_left_enabled
* Show POINT_RIGHT overlay on the left side (using pre-mirrored sprite)
 jsr clear_active_overlay
 lda #180
 sta overlay_timer
 lda #0
 sta overlay_x
 lda #120
 sta overlay_y
 lda #$0C
 sta overlay_w
 lda #$10
 sta overlay_h
 lda #1
 sta overlay_mirror               ; legacy flag (informational only)
 lda spr_pointright_data_mirror
 sta overlay_addr
 lda spr_pointright_data_mirror+1
 sta overlay_addr+1
 lda spr_pointright_mask_mirror
 sta overlay_mask
 lda spr_pointright_mask_mirror+1
 sta overlay_mask+1
 lda script_pc
 clc
 adc #2
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 jmp :exec_loop

:not_left
 cmp #OP_UP
 beq :do_op_up
 jmp :not_up_op        ; inverted — target moved out of branch range
:do_op_up
* DEBUG: 'UP WO=wwww AX=aaaa' — world_offset and abs_x at the
* moment OP_UP fires. Narrow-target UP scroll compensation
* (+15 pin / +7 ladder / +10 snap xpos) is calibrated for a
* specific wo at this point; compare across runs to see whether
* wo varies (which would confirm the compensation is fragile).
 lda #$D5              ; 'U'
 jsr dbg_print_char
 lda #$D0              ; 'P'
 jsr dbg_print_char
 lda #$A0              ; ' '
 jsr dbg_print_char
 lda #$D7              ; 'W'
 jsr dbg_print_char
 lda #$CF              ; 'O'
 jsr dbg_print_char
 lda #$BD              ; '='
 jsr dbg_print_char
 lda world_offset+1
 jsr dbg_print_hex8
 lda world_offset
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$C1              ; 'A'
 jsr dbg_print_char
 lda #$D8              ; 'X'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 lda abs_x+1
 jsr dbg_print_hex8
 lda abs_x
 jsr dbg_print_hex8
 jsr dbg_print_nl
* OP_UP: param1=target, param2=left-neighbor, param3=right-neighbor.
* $FF in any neighbor slot = no fill on that side.
 ldy #1
 lda [script_pc],y     ; target screen index
 sta scroll_up_screen
 clc
 adc #$03
 sta scroll_up_bank
 ldy #2
 lda [script_pc],y     ; left-neighbor screen index
 cmp #$FF
 beq :op_up_no_lbank
 clc
 adc #$03
 sta scroll_up_lbank
 bra :op_up_lbank_done
:op_up_no_lbank
 stz scroll_up_lbank   ; sentinel: skip left-gap fill
:op_up_lbank_done
 ldy #3
 lda [script_pc],y     ; right-neighbor screen index
 cmp #$FF
 beq :op_up_no_rbank
 clc
 adc #$03
 sta scroll_up_rbank
 bra :op_up_rbank_done
:op_up_no_rbank
 stz scroll_up_rbank   ; sentinel: skip right-gap fill
:op_up_rbank_done
* Per-target anchor and content width. scroll_up_anchor is
* the target's left-edge world byte, which compute_up_align
* subtracts from world_offset. scroll_up_twidth is the target
* content width (for narrow upper screens). Default is screen
* 5 over screen 3 (anchor=330, full width 110).
*
* scr10 anchor differs by source:
*   rneighbor=$FF (ladder 2 from scr7): anchor=440, scr10 shares
*     scr7's world range.
*   rneighbor=11   (ladder 3 from scr12): anchor=302, placing
*     scr10 so its ladder art lines up with ladder[2] at world 315.
 stz scroll_up_twidth+1
 lda scroll_up_screen
 cmp #10
 bne :op_up_notscr10
* scr10 target — pick anchor by rneighbor (pre-wrap raw param):
*   $FF (ladder 2 from scr7)  → anchor=440
*   11   (ladder 3 from scr12) → anchor=302
 ldy #3
 lda [script_pc],y
 cmp #$FF
 bne :op_up_anchor_scr12
 lda #<440
 sta scroll_up_anchor
 lda #>440
 sta scroll_up_anchor+1
 bra :op_up_anchor_width10
:op_up_anchor_scr12
 lda #<302
 sta scroll_up_anchor
 lda #>302
 sta scroll_up_anchor+1
:op_up_anchor_width10
 lda #67
 sta scroll_up_twidth
 bra :op_up_anchor_done
:op_up_notscr10
* scr12 anchor=221 with wo=296 (the OP_SCRMIN/MAX-locked ladder3
* entry position) places scr12 byte 75 at playfield col 0. This
* shifts scr12 art 7 bytes (14px) left in the playfield relative
* to a naive anchor=228, compensating for a right-bias in the
* scr12 source art so its visible content lines up with scr9
* below at the seam.
* scr11/13 (still narrow, 52 bytes) keep anchor=329. Other
* OP_UP targets use the default anchor=330.
 cmp #12
 bne :op_up_check_scr1113
 lda #<221
 sta scroll_up_anchor
 lda #>221
 sta scroll_up_anchor+1
 lda #110
 sta scroll_up_twidth
 bra :op_up_anchor_done
:op_up_check_scr1113
 cmp #11
 bcc :op_up_anchor_default
 cmp #14
 bcs :op_up_anchor_default
* scr11/13: 103px wide (52 bytes), anchor=329.
 lda #<329
 sta scroll_up_anchor
 lda #>329
 sta scroll_up_anchor+1
 lda #52
 sta scroll_up_twidth
 bra :op_up_anchor_done
:op_up_anchor_default
 lda #<330
 sta scroll_up_anchor
 lda #>330
 sta scroll_up_anchor+1
 lda #110
 sta scroll_up_twidth
:op_up_anchor_done
* Per-left-neighbor width: how wide the left neighbor's
* content is (used by the lgap fill to read its rightmost
* bytes into the playfield left gap). 16-bit store so the
* 16-bit adc in the fill math reads a clean value.
 stz scroll_up_lwidth+1
 ldy #2
 lda [script_pc],y     ; raw left-neighbor index (pre-wrap)
 cmp #6
 bne :op_up_lw_default
 lda #52               ; screen 6 is 104px (52 bytes) wide
 sta scroll_up_lwidth
 bra :op_up_lw_done
:op_up_lw_default
 lda #110              ; full-width default
 sta scroll_up_lwidth
:op_up_lw_done
* Initial scroll_up_off. Default 182 covers the full 183-row
* playfield. Targets scr11/12/13 are only 113 lines tall (their
* bank has content in rows 0..112 and empty rows 113..199). Each
* frame copies 4 rows starting at ufill_top = scroll_up_off - 3
* and advancing downward, so ufill_top + 3 must stay ≤ 112 for
* all 4 source rows to be valid. scroll_up_off = 112 → ufill_top
* = 109, first frame reads rows 109..112 (all valid).
* Also set snap_copy_rows so snap_transition only copies the 113
* valid rows, leaving rows 113..182 as the pre-scroll content that
* shifted down during the incremental scroll.
 ldy #1
 lda [script_pc],y     ; target
 cmp #11
 bcc :op_up_off_std    ; target < 11 → full-height
 cmp #14
 bcs :op_up_off_std    ; target >= 14 → full-height
 lda #112
 sta scroll_up_off
 lda #113
 sta snap_copy_rows
 stz snap_copy_rows+1
 bra :op_up_off_done
:op_up_off_std
 lda #182
 sta scroll_up_off
 lda #183
 sta snap_copy_rows
 stz snap_copy_rows+1
:op_up_off_done
 stz climb_started     ; reset one-time setup flag for this climb
* Show POINT_UP overlay (centered, top of playfield) for 180 frames.
* Playfield is 110 bytes; POINT_UP is 8 bytes wide → x = (110-8)/2 = 51.
 jsr clear_active_overlay
 lda #180
 sta overlay_timer
 lda #51
 sta overlay_x
 lda #0
 sta overlay_y
 lda #$08
 sta overlay_w
 lda #$18
 sta overlay_h
 stz overlay_mirror
 lda spr_pointup
 sta overlay_addr
 lda spr_pointup+1
 sta overlay_addr+1
 lda spr_pointup_mask
 sta overlay_mask
 lda spr_pointup_mask+1
 sta overlay_mask+1
 lda #1
 sta scroll_up_enabled
 lda #SCRIPT_WAITUP
 sta script_state
 lda script_pc
 clc
 adc #4                ; opcode + 3 params
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 rts                   ; yield — wait for scroll to complete

:not_up_op
 cmp #OP_SCRLOCK
 bne :not_scrlock
 stz scroll_right_enabled
 stz scroll_left_enabled
 stz scroll_up_enabled
 lda script_pc          ; opcode only, no params (16-bit advance)
 clc
 adc #1
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 jmp :exec_loop

:not_scrlock
 cmp #OP_WAITX
 bne :not_waitx
* OP_WAITX: param = 2-byte absolute X threshold (low, high)
 ldy #1
 lda [script_pc],y
 sta script_wait_val
 ldy #2
 lda [script_pc],y
 sta script_wait_val+1
 lda #SCRIPT_WAITX
 sta script_state
 lda script_pc
 clc
 adc #3                ; advance past opcode + 2-byte param
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 rts                   ; yield until condition met

:not_waitx
 cmp #OP_WAITXREV
 bne :not_waitxrev
* OP_WAITXREV: param = 2-byte absolute X threshold (low, high)
 ldy #1
 lda [script_pc],y
 sta script_wait_val
 ldy #2
 lda [script_pc],y
 sta script_wait_val+1
 lda #SCRIPT_WAITXREV
 sta script_state
 lda script_pc
 clc
 adc #3                ; opcode + 2-byte param
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 rts

:not_waitxrev
 cmp #OP_SCRMIN
 bne :not_scrmin
* OP_SCRMIN: 2-byte param = new minimum world_offset.
* Left-scrolling further will be blocked once wo hits this.
 ldy #1
 lda [script_pc],y
 sta scroll_min_wo
 ldy #2
 lda [script_pc],y
 sta scroll_min_wo+1
 lda script_pc
 clc
 adc #3
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 jmp :exec_loop
:not_scrmin
 cmp #OP_SCRMAX
 bne :not_scrmax
* OP_SCRMAX: 2-byte param = new maximum world_offset.
* Right-scrolling further will be blocked once wo hits this.
 ldy #1
 lda [script_pc],y
 sta scroll_max_wo
 ldy #2
 lda [script_pc],y
 sta scroll_max_wo+1
 lda script_pc
 clc
 adc #3
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 jmp :exec_loop
:not_scrmax
 cmp #OP_SNAPSTATE
 beq :do_snapstate
 jmp :not_snapstate
:do_snapstate
* OP_SNAPSTATE: copy 17-byte inline payload into engine state
* vars. Used to restore a "golden" state recorded via the 'g'
* debug key. Place at script positions where canonical state is
* desired (e.g., right before OP_UP for pre-climb golden, and
* immediately after OP_UP for post-climb golden).
 ldy #1
 lda [script_pc],y     ; world_offset low
 sta world_offset
 ldy #2
 lda [script_pc],y     ; world_offset high
 sta world_offset+1
 ldy #3
 lda [script_pc],y     ; abs_x low
 sta abs_x
 ldy #4
 lda [script_pc],y     ; abs_x high
 sta abs_x+1
 ldy #5
 lda [script_pc],y     ; IMAGE01_XPOS
 sta IMAGE01_XPOS
 sta billy_sprite+2
 sta billy_sprite+34   ; prev_xpos = new xpos (no stale erase)
 ldy #6
 lda [script_pc],y     ; current_screen
 sta current_screen
 ldy #7
 lda [script_pc],y     ; scroll_src_bank
 sta scroll_src_bank
 ldy #8
 lda [script_pc],y     ; scroll_src_off
 sta scroll_src_off
 ldy #9
 lda [script_pc],y     ; scroll_lsrc_bank
 sta scroll_lsrc_bank
 ldy #10
 lda [script_pc],y     ; scroll_lsrc_off
 sta scroll_lsrc_off
 ldy #11
 lda [script_pc],y     ; scroll_up_anchor low
 sta scroll_up_anchor
 ldy #12
 lda [script_pc],y     ; scroll_up_anchor high
 sta scroll_up_anchor+1
 ldy #13
 lda [script_pc],y     ; scroll_up_off
 sta scroll_up_off
 ldy #14
 lda [script_pc],y     ; scroll_min_wo low
 sta scroll_min_wo
 ldy #15
 lda [script_pc],y     ; scroll_min_wo high
 sta scroll_min_wo+1
 ldy #16
 lda [script_pc],y     ; scroll_max_wo low
 sta scroll_max_wo
 ldy #17
 lda [script_pc],y     ; scroll_max_wo high
 sta scroll_max_wo+1
* Reload the new screen's bounds table since current_screen may
* have changed.
 lda current_screen
 jsr load_screen_bounds
* Advance script_pc by 18 (opcode + 17 data bytes).
 lda script_pc
 clc
 adc #18
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 jmp :exec_loop
:not_snapstate
 cmp #OP_SNAPSTATE_DEFER
 beq :do_snapstate_defer
 jmp :not_snapstate_defer
:do_snapstate_defer
* OP_SNAPSTATE_DEFER: copy 25-byte inline payload (= bytes 1..25,
* skipping the opcode at offset 0) to pending_snap_buf, set flag.
* scroll_up's :su_normal applies state + repaints on first call.
 ldx #0
 ldy #1
:dsd_loop
 lda [script_pc],y
 sta pending_snap_buf,x
 iny
 inx
 cpx #25
 bne :dsd_loop
 lda #1
 sta pending_snap_flag
 lda script_pc
 clc
 adc #26
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 jmp :exec_loop
:not_snapstate_defer
 cmp #OP_WAITY
 bne :not_waity
 ldy #1
 lda [script_pc],y
 sta script_wait_val
 lda #SCRIPT_WAITY
 sta script_state
 lda script_pc
 clc
 adc #2
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 rts

:not_waity
 cmp #OP_WAITCLR
 bne :not_waitclr
 lda #SCRIPT_WAITCLR
 sta script_state
 lda script_pc          ; opcode only (16-bit advance)
 clc
 adc #1
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 rts

:not_waitclr
 cmp #OP_WAITNPC
 bne :not_waitnpc
* OP_WAITNPC: param = 1 byte NPC count threshold
 ldy #1
 lda [script_pc],y
 sta script_wait_val   ; reuse low byte for NPC count
 lda #SCRIPT_WAITNPC
 sta script_state
 lda script_pc
 clc
 adc #2                ; opcode + 1 byte param
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 rts

:not_waitnpc
* OP_NONE — skip 1 byte and continue
 cmp #OP_NONE
 bne :unknown_op
 lda script_pc          ; 16-bit advance
 clc
 adc #1
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 jmp :exec_loop
:unknown_op
* Unknown opcode — halt the script rather than march forward
* into adjacent data (which spawns garbage NPCs).
 lda #SCRIPT_DONE
 sta script_state
 rts

*--- Wait condition checks ---

* Local rts for the waitx/waitxrev paths: the debug prints pushed
* :rs_rts2 out of 8-bit branch range, so branch to this local one.
:wx_wait_rts rts

:check_waitx
* Check if player absolute X >= threshold (16-bit compare)
 lda abs_x+1
 cmp script_wait_val+1
 bcc :wx_wait_rts       ; not yet (high byte less)
 bne :waitx_done        ; high byte greater — done
 lda abs_x
 cmp script_wait_val
 bcc :wx_wait_rts       ; low byte less
:waitx_done
* DEBUG: 'WX xxxx=tttt' — abs_x vs threshold at the moment the op fires.
 lda #$D7              ; 'W'
 jsr dbg_print_char
 lda #$D8              ; 'X'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda abs_x+1
 jsr dbg_print_hex8
 lda abs_x
 jsr dbg_print_hex8
 lda #$BD              ; '='
 jsr dbg_print_char
 lda script_wait_val+1
 jsr dbg_print_hex8
 lda script_wait_val
 jsr dbg_print_hex8
 jsr dbg_print_nl
 lda #SCRIPT_RUN
 sta script_state
 jmp :exec_loop         ; condition met, resume executing

:check_waitxrev
* Check if player absolute X <= threshold (16-bit compare)
 lda script_wait_val+1
 cmp abs_x+1
 bcc :wx_wait_rts       ; threshold_hi < abs_hi → abs still greater
 bne :waitxrev_done     ; threshold_hi > abs_hi → done
 lda script_wait_val
 cmp abs_x
 bcc :wx_wait_rts       ; threshold_lo < abs_lo → still greater
:waitxrev_done
* DEBUG: 'WR xxxx=tttt' — abs_x vs threshold at the moment the op fires.
 lda #$D7              ; 'W'
 jsr dbg_print_char
 lda #$D2              ; 'R'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda abs_x+1
 jsr dbg_print_hex8
 lda abs_x
 jsr dbg_print_hex8
 lda #$BD              ; '='
 jsr dbg_print_char
 lda script_wait_val+1
 jsr dbg_print_hex8
 lda script_wait_val
 jsr dbg_print_hex8
 jsr dbg_print_nl
 lda #SCRIPT_RUN
 sta script_state
 jmp :exec_loop

:check_waity
 lda IMAGE01_YPOS
 cmp script_wait_val
 bcc :rs_rts2
 lda #SCRIPT_RUN
 sta script_state
 jmp :exec_loop

:check_waitclr
* Check if all NPCs are defeated (no controller=$00 sprites in table)
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:clr_loop
 ldy #0
 lda (spr_ptr),y
 sta info_ptr
 iny
 lda (spr_ptr),y
 sta info_ptr+1
 ora info_ptr
 beq :all_clear         ; end of table, no NPCs found
 ldy #22
 lda (info_ptr),y       ; controller
 beq :npc_alive         ; found an NPC, not clear yet
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :clr_loop
 inc spr_ptr+1
 bra :clr_loop
:npc_alive
:rs_rts2 rts
:all_clear
 lda #SCRIPT_RUN
 sta script_state
 jmp :exec_loop

:check_waitnpc
* Check if NPC count <= threshold in script_wait_val.
* Count controller=$00 sprites in table.
 lda #0
 sta :npc_count
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:wnpc_loop
 ldy #0
 lda (spr_ptr),y
 sta info_ptr
 iny
 lda (spr_ptr),y
 sta info_ptr+1
 ora info_ptr
 beq :wnpc_done        ; end of table
 ldy #22
 lda (info_ptr),y       ; controller
 bne :wnpc_next         ; skip player
 inc :npc_count
:wnpc_next
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :wnpc_loop
 inc spr_ptr+1
 bra :wnpc_loop
:wnpc_done
 lda :npc_count
 cmp script_wait_val
 bcc :wnpc_met          ; count < threshold — condition met
 beq :wnpc_met          ; count == threshold — condition met
 rts                    ; count > threshold — wait
:wnpc_met
 lda #SCRIPT_RUN
 sta script_state
 jmp :exec_loop
:npc_count dfb 0

:check_waitup
* Wait for scroll_up_enabled to return to 0 (snap completed)
 lda scroll_up_enabled
 bne :wu_rts            ; still scrolling, wait
 lda #SCRIPT_RUN
 sta script_state
 jmp :exec_loop         ; scroll done, resume script
:wu_rts rts

*--- Script helper: set screen ---
script_set_screen
* A = screen index. Update current screen and load its bounds.
 sta current_screen
 jsr load_screen_bounds
 rts

*--- Script helper: spawn NPC ---
script_spawn_npc
* Copy sprite info block template from bank $02 to a free
* slot in bank $00, set position/orientation, add to sprite_table.
* sc_npc_ptr = bank $02 sprite block address
* sc_npc_x, sc_npc_y, sc_npc_orient = spawn params
*
* Find first null entry in sprite_table
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:find_slot
 ldy #0
 lda (spr_ptr),y
 iny
 ora (spr_ptr),y
 beq :found_slot
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :find_slot
 inc spr_ptr+1
 bra :find_slot
:found_slot
* Bounds-check npc_buf_next before allocating. If it has reached
* npc_buffers_end, the buffer is exhausted — silently drop the
* spawn rather than corrupt code that follows npc_buffers in the
* binary. (Increase NPC_BUFFER_SLOTS if levels need more.)
 lda npc_buf_next+1
 cmp #>npc_buffers_end
 bcc :buf_ok
 bne :buf_full
 lda npc_buf_next
 cmp #<npc_buffers_end
 bcc :buf_ok
:buf_full
 rts
:buf_ok
* Allocate next NPC buffer
 lda npc_buf_next
 sta info_ptr
 lda npc_buf_next+1
 sta info_ptr+1
* Copy 52 bytes from bank $02 template to bank $00 buffer
 clc
 xce                   ; native mode
 rep $30
 mx %00
 lda sc_npc_ptr
 sta $F0
 sep $20
 lda #$02
 sta $F2               ; source: bank $02
 rep $20
 ldy #0
:copy_blk
 lda [$F0],y
 sta (info_ptr),y
 iny
 iny
 cpy #52
 bcc :copy_blk
 sec
 xce                   ; back to emulation mode
* Set position and orientation
 ldy #0
 lda sc_npc_y
 sta (info_ptr),y      ; +0 ypos
 ldy #2
 lda sc_npc_x
 sta (info_ptr),y      ; +2 xpos
 ldy #4
 lda sc_npc_orient
 sta (info_ptr),y      ; +4 mirror
* Store behavior at +6, behavior_state at +7 (init 0)
 ldy #6
 lda sc_npc_behavior
 sta (info_ptr),y      ; +6 behavior
 ldy #7
 lda #0
 sta (info_ptr),y      ; +7 behavior_state (FO_APPROACH)
 ldy #8
 sta (info_ptr),y      ; +8 behavior_timer low
 ldy #9
 sta (info_ptr),y      ; +9 behavior_timer high
* Patch animation pointers to bank $00 versions.
* Template has bank $02 DA addresses which can't be read
* via (dp),Y. Determine NPC type from idle_addr (+42),
* then patch punched_anim (+40) and fall_anim (+50) with
* the correct bank $00 animation descriptor addresses.
 ldy #42
 lda (info_ptr),y      ; idle_addr low (bank $02 addr)
 sta :id_lo
 ldy #43
 lda (info_ptr),y      ; idle_addr high
 sta :id_hi
* Check Roper
 lda :id_lo
 cmp spr_roper1
 bne :not_roper
 lda :id_hi
 cmp spr_roper1+1
 bne :not_roper
 lda #<anim_rpunched
 sta :punch_lo
 lda #>anim_rpunched
 sta :punch_hi
 lda #<anim_rfall
 sta :fall_lo
 lda #>anim_rfall
 sta :fall_hi
 lda #<anim_rwalk
 sta :walk_lo
 lda #>anim_rwalk
 sta :walk_hi
 lda #<anim_rpunch
 sta :atk_lo
 lda #>anim_rpunch
 sta :atk_hi
 bra :do_patch
:not_roper
* Check Linda
 lda :id_lo
 cmp spr_linda1
 bne :not_linda
 lda :id_hi
 cmp spr_linda1+1
 bne :not_linda
 lda #<anim_lpunched
 sta :punch_lo
 lda #>anim_lpunched
 sta :punch_hi
 lda #<anim_lfall
 sta :fall_lo
 lda #>anim_lfall
 sta :fall_hi
 lda #<anim_lwalk
 sta :walk_lo
 lda #>anim_lwalk
 sta :walk_hi
 lda #<anim_lpunch
 sta :atk_lo
 lda #>anim_lpunch
 sta :atk_hi
 bra :do_patch
:not_linda
* Default: William
 lda #<anim_wpunched
 sta :punch_lo
 lda #>anim_wpunched
 sta :punch_hi
 lda #<anim_wfall
 sta :fall_lo
 lda #>anim_wfall
 sta :fall_hi
 lda #<anim_wwalk
 sta :walk_lo
 lda #>anim_wwalk
 sta :walk_hi
 lda #<anim_wpunch
 sta :atk_lo
 lda #>anim_wpunch
 sta :atk_hi
:do_patch
 ldy #40
 lda :punch_lo
 sta (info_ptr),y      ; +40 punched_anim low
 iny
 lda :punch_hi
 sta (info_ptr),y      ; +41 punched_anim high
 ldy #50
 lda :fall_lo
 sta (info_ptr),y      ; +50 fall_anim low
 iny
 lda :fall_hi
 sta (info_ptr),y      ; +51 fall_anim high
* Set per-NPC walk_anim (+52) and atk_anim (+54)
 ldy #52
 lda :walk_lo
 sta (info_ptr),y
 iny
 lda :walk_hi
 sta (info_ptr),y      ; +53
 ldy #54
 lda :atk_lo
 sta (info_ptr),y
 iny
 lda :atk_hi
 sta (info_ptr),y      ; +55
* Set dirty = draw only (bit 0)
 ldy #30
 lda #$01
 sta (info_ptr),y
* Copy prev to match current
 ldy #0
 lda (info_ptr),y
 ldy #32
 sta (info_ptr),y      ; prev_ypos
 ldy #2
 lda (info_ptr),y
 ldy #34
 sta (info_ptr),y      ; prev_xpos
* Write pointer into sprite_table
 ldy #0
 lda info_ptr
 sta (spr_ptr),y
 iny
 lda info_ptr+1
 sta (spr_ptr),y
* Advance NPC buffer pointer (56 bytes per block)
 lda npc_buf_next
 clc
 adc #56
 sta npc_buf_next
 lda npc_buf_next+1
 adc #0
 sta npc_buf_next+1
 rts

sc_npc_ptr   ds 2
sc_npc_x     dfb 0
sc_npc_y     dfb 0
sc_npc_orient dfb 0
sc_npc_behavior dfb 0
:id_lo       dfb 0
:id_hi       dfb 0
:punch_lo    dfb 0
:punch_hi    dfb 0
:fall_lo     dfb 0
:fall_hi     dfb 0
:walk_lo     dfb 0
:walk_hi     dfb 0
:atk_lo      dfb 0
:atk_hi      dfb 0

*-------------------------------
* Script state variables
*-------------------------------
current_screen dfb 0
scroll_right_enabled dfb 0
scroll_left_enabled dfb 0
scroll_up_enabled    dfb 0
scroll_right_screen dfb 0
scroll_left_screen dfb 0
scroll_up_screen     dfb 0
scroll_up_bank       dfb $03
scroll_up_off        dfb 0
climb_started        dfb 0       ; one-time flag for scr12 climb's scr8
                                  ; right-fill setup. Set by scroll_up on
                                  ; first call after OP_UP, cleared at
                                  ; OP_UP fire so each climb runs setup
                                  ; exactly once.
scroll_up_lbank      dfb $03     ; bank of upper screen's left neighbor
                                  ; (0 = sentinel, skip left-gap fill)
scroll_up_rbank      dfb $03     ; bank of upper screen's right neighbor
                                  ; (0 = sentinel, skip right-gap fill)
scroll_up_anchor     dw 330       ; world byte position of target's left edge
                                  ; (= UP_X_ANCHOR default for screen 5)
scroll_up_lwidth     dw 52        ; left-neighbor content width in bytes
                                  ; (declared 16-bit for use with adc in
                                  ; the lgap fill's row-address math)
scroll_up_twidth     dw 110       ; target content width in bytes (full-
                                  ; width default). compute_up_align
                                  ; clamps up_count against this so the
                                  ; fill never reads past the target's
                                  ; real content.
op_up_align_delta    dw 0         ; OP_UP narrow-target: world_offset
                                  ; delta from anchor, used to shift
                                  ; Billy's xpos when pre-aligning.
scr8_src_off         dw 0         ; scroll_right lower-fill offset into
                                  ; scr8's bank. Initialized at narrow-
                                  ; target snap; advances 4 per scroll_
                                  ; right so rows 113..182 track scr8.
snap_copy_rows       dw 183       ; row count for snap_transition copies
                                  ; (source, lgap, rgap). 183 = default;
                                  ; narrow-height targets (scr11/12/13)
                                  ; set it to 113 so the bottom 70 rows
                                  ; keep their pre-scroll shifted content.
npc_buf_next dw npc_buffers   ; next free NPC buffer address

* Cheat: invincibility toggle
god_mode       dfb 0          ; 0 = normal, 1 = invincible

* Alternates between punch1 and punch2 each time 'p' is pressed
punch_toggle   dfb 0

*----------------------------------------------------------
* Y-axis movement bounds table. 200 entries (one per
* scanline), 2 bytes each: min_x, max_x.
* max_x=0 means the row is completely blocked.
* Checked when player or NPC changes Y position.
*----------------------------------------------------------
* Split into two 200-byte arrays so Y can index directly
* without needing Y*2 (which overflows at Y>=128 in 8-bit).
bounds_tbl_lo                  ; min_x per scanline
 LUP 80
 dfb 0
 --^
 LUP 120
 dfb 0
 --^
bounds_tbl_hi                  ; max_x per scanline (0=blocked)
 LUP 80
 dfb 0
 --^
 LUP 120
 dfb 109
 --^

*----------------------------------------------------------
* check_y_bounds - Test if a sprite at X position chk_xpos
* is allowed at the proposed Y in A.
* Input: A = proposed Y, chk_xpos = sprite's X
* Output: C=1 blocked, C=0 allowed. Trashes A/X.
*----------------------------------------------------------
*----------------------------------------------------------
* check_x_bounds - Test if a proposed X is allowed at the
* sprite's current Y_top (IMAGE01_YPOS). Used by walk-right
* and walk-left so horizontal movement honors per-row X bounds
* the same way check_y_bounds honors them for vertical movement.
* No ladder fallback — ladders are vertical-only.
*
* Input: A = proposed X. Uses IMAGE01_YPOS as the row to query.
* Output: C=1 blocked, C=0 allowed. Trashes A/X.
*----------------------------------------------------------
check_x_bounds
 sta :cxb_x
 lda IMAGE01_YPOS
 tax
 lda bounds_tbl_lo,x
 sta :cxb_min
 lda bounds_tbl_hi,x
 beq :cxb_blocked     ; row marked blocked (hi=0) — no walk allowed
 sta :cxb_max
 lda :cxb_x
 cmp :cxb_min
 bcc :cxb_blocked
 cmp :cxb_max
 beq :cxb_ok
 bcs :cxb_blocked
:cxb_ok clc
 rts
:cxb_blocked sec
 rts
:cxb_x dfb 0
:cxb_min dfb 0
:cxb_max dfb 0

check_y_bounds
 stz via_ladder
 sta :proposed
* Block if the sprite's bottom row would drop out of the playfield.
* bottom = proposed + FRAME_Y - 1, must be <= 182 (last playfield row);
* equivalently proposed + FRAME_Y <= 183, i.e., A < 184.
 clc
 adc FRAME_Y
 cmp #184
 bcs :blocked
 lda :proposed
 tax
 lda bounds_tbl_lo,x
 sta :bmin
 lda bounds_tbl_hi,x
 beq :try_ladder       ; row blocked, check ladders
 sta :bmax
 lda chk_xpos
 cmp :bmin
 bcc :try_ladder
 cmp :bmax
 beq :ok
 bcs :try_ladder
:ok clc
 rts
:try_ladder
 lda :proposed
 jsr check_ladder      ; C=0 if on ladder
 bcs :blocked
 lda #1
 sta via_ladder
 clc
 rts
:blocked sec
 rts
:proposed dfb 0
:bmin dfb 0
via_ladder dfb 0
:bmax dfb 0
chk_xpos dfb 0
bounds_base ds 2              ; bank $02 address of bounds_ptrs
ladder_base ds 2              ; bank $02 address of global ladder list

* Global ladder buffer (bank $00). Up to 4 ladders.
* Each entry is 6 bytes: x_left(w), x_right(w), y_top(b), y_bottom(b)
* x_left/x_right are world-absolute byte coordinates.
ladder_count dfb 0
ladder_buf   ds 24             ; 4 ladders × 6 bytes

* World byte offset of the playfield's left edge.
* Increases by 4 per scroll_right call.
world_offset dw 0

* Per-script scroll clamps. scroll_right blocks when wo+4 would
* exceed scroll_max_wo; scroll_left blocks when wo-4 would fall
* below scroll_min_wo. Sentinels ($0000 for min, $FFFF for max)
* mean "no limit". Set by OP_SCRMIN/OP_SCRMAX, reset at level init.
scroll_min_wo dw $0000
scroll_max_wo dw $FFFF

* Pending golden state for OP_SNAPSTATE_DEFER. The op stores its
* 25-byte payload here and sets pending_snap_flag; scroll_up's
* :su_normal entry applies state and runs repaints on first call.
* Buffer layout:
*   +0..+16: 17 bytes of engine state (matches OP_SNAPSTATE).
*   +17:  region 1 repaint bank (0 = skip region 1).
*   +18:  region 1 repaint source byte offset.
*   +19:  region 1 repaint count (8-bit).
*   +20:  region 1 repaint destination column.
*   +21:  region 2 repaint bank (0 = skip region 2).
*   +22:  region 2 repaint source byte offset.
*   +23:  region 2 repaint count (8-bit).
*   +24:  region 2 repaint destination column.
pending_snap_flag dfb 0
pending_snap_buf  ds 25

*----------------------------------------------------------
* load_screen_bounds - Copy bounds table (400 bytes) and
* ladder data from bank $02 to bank $00 for the given screen.
* A = screen index (0-4). Called in emulation mode.
*----------------------------------------------------------
*----------------------------------------------------------
* sync_current_screen - After scrolling, derive the player's
* current screen index from scroll_src_bank and reload bounds
* if it changed. Mapping: current_screen = scroll_src_bank - $51.
* Called in emulation mode.
*----------------------------------------------------------
sync_current_screen
* A right-scroll wrap sets transition_pending. Consume it here:
* current_screen becomes whatever OP_RIGHT last targeted
* (scroll_right_screen), not a linear derivation from
* scroll_src_bank — which would be wrong whenever the script
* skips screens (e.g. screen 5 -> 7).
 lda transition_pending
 beq :no_change
 stz transition_pending
 lda scroll_right_screen
 cmp current_screen
 beq :no_change
 sta current_screen
 jsr inc_border             ; new screen scrolled in
:apply
* Update scroll_lsrc_bank = bank of left-neighbor screen.
* Linear assumption ($03 + (current_screen - 1)); OP_LEFT
* should override this when screens are skipped going back.
 lda current_screen
 beq :no_left
 clc
 adc #$02              ; $03 + (current_screen - 1)
 sta scroll_lsrc_bank
 lda #109
 sta scroll_lsrc_off
 bra :loaded
:no_left
 lda #$03
 sta scroll_lsrc_bank
 stz scroll_lsrc_off
:loaded
 lda current_screen    ; reload before calling — A had been clobbered
 jsr load_screen_bounds
:no_change rts

*----------------------------------------------------------
* sync_current_screen_left - Variant called after a LEFT
* scroll. When scroll_lsrc_bank decrements past a boundary,
* current_screen-- and re-derive scroll_src_bank/off.
*----------------------------------------------------------
sync_current_screen_left
* After a left scroll, transition current_screen to whatever
* OP_LEFT explicitly targeted (scroll_left_screen). OP_LEFT is
* required to enable left-scroll at all, so scroll_left_screen
* always holds the intended destination.
 lda current_screen
 beq :scl_done
 lda scroll_left_screen
 cmp current_screen
 beq :scl_done
 sta current_screen
 jsr inc_border             ; new screen scrolled in
 lda current_screen
 clc
 adc #$03              ; scroll_src_bank = $03 + new current_screen
 sta scroll_src_bank   ; so scroll_right starts by re-showing us
 stz scroll_src_off
 lda current_screen
 jsr load_screen_bounds
:scl_done rts

load_screen_bounds
 sta :scr_idx
 clc
 xce                   ; native mode
 rep $30
 mx %00
* --- Copy bounds table (de-interleave into lo/hi arrays) ---
 lda :scr_idx
 and #$00FF
 asl
 clc
 adc bounds_base
 sta $F0
 sep $20
 lda #$02
 sta $F2
 rep $20
 ldy #0
 lda [$F0],y
 sta $F0               ; $F0 = bank $02 addr of interleaved table
 sep $20
 lda #$02
 sta $F2
 rep $20
 ldy #0                ; source index (interleaved pairs)
 ldx #0                ; dest index (0-199)
:bcopy sep $20
 lda [$F0],y           ; min_x
 sta bounds_tbl_lo,x
 rep $20
 iny
 sep $20
 lda [$F0],y           ; max_x
 sta bounds_tbl_hi,x
 rep $20
 iny
 inx
 cpx #200
 bcc :bcopy

 sec
 xce                   ; back to emulation mode
 rts
:scr_idx ds 2

*----------------------------------------------------------
* load_ladders - Copy the global ladder list from bank $02
* into ladder_buf. Called once at init_level.
*----------------------------------------------------------
load_ladders
 clc
 xce                   ; native mode
 rep $30
 mx %00
 lda ladder_base
 sta $F0
 sep $20
 lda #$02
 sta $F2
 rep $20
 sep $20
 mx %10
 ldy #0
 lda [$F0],y           ; count byte
 sta ladder_count
 beq :ll_done
 rep $20
 mx %00
 lda ladder_count
 and #$00FF
 sta :tmp              ; A = count
 asl
 clc
 adc :tmp              ; A = count * 3
 asl                   ; A = count * 6
 sta :llen
 ldy #1                ; source offset past count byte
 ldx #0                ; dest offset
:lcopy sep $20
 lda [$F0],y
 sta ladder_buf,x
 rep $20
 iny
 inx
 cpx :llen
 bcc :lcopy
:ll_done
 sec
 xce                   ; back to emulation mode
 rts
:tmp ds 2
:llen ds 2

*----------------------------------------------------------
* check_ladder - Test if sprite at chk_xpos / proposed Y
* is on a ladder. Returns C=0 if on ladder, C=1 if not.
* A = proposed Y. Preserves A on return.
*----------------------------------------------------------
check_ladder
 sta :prop_y
 lda ladder_count
 bne :cl_have
 jmp :cl_no
:cl_have
* Compute sprite_world_x = world_offset + chk_xpos (16-bit)
 lda chk_xpos
 sta :swx
 stz :swx+1
 lda :swx
 clc
 adc world_offset
 sta :swx
 lda :swx+1
 adc world_offset+1
 sta :swx+1
* Precompute tolerance-shifted values so ladder entry is forgiving
* by LADDER_TOL bytes (2 bytes = 4px) on each side. swx_l is used
* for the x_left compare (swx+TOL must be >= x_left → effective
* lenient by TOL on the left). swx_r is used for x_right compare
* (swx-TOL <= x_right → lenient by TOL on the right).
 clc
 lda :swx
 adc #LADDER_TOL
 sta :swx_l
 lda :swx+1
 adc #0
 sta :swx_l+1
 sec
 lda :swx
 sbc #LADDER_TOL
 sta :swx_r
 lda :swx+1
 sbc #0
 sta :swx_r+1
 lda #0
 sta :cl_idx
:cl_scan
 ldx :cl_idx
* sprite_world_x + TOL >= x_left? (compare :swx_l vs ladder_buf[x])
 lda :swx_l+1
 cmp ladder_buf+1,x    ; x_left high
 bcc :cl_next          ; too far left
 bne :ge_left
 lda :swx_l
 cmp ladder_buf,x      ; x_left low
 bcc :cl_next
:ge_left
* sprite_world_x - TOL <= x_right? (compare :swx_r vs ladder_buf[x+2])
 lda ladder_buf+3,x    ; x_right high
 cmp :swx_r+1
 bcc :cl_next          ; too far right
 bne :le_right
 lda ladder_buf+2,x    ; x_right low
 cmp :swx_r
 bcc :cl_next
:le_right
* y_top <= proposed_y <= y_bottom?
 lda :prop_y
 cmp ladder_buf+4,x    ; y_top
 bcc :cl_next
 lda ladder_buf+5,x    ; y_bottom
 cmp :prop_y
 bcc :cl_next
* On ladder
 lda :prop_y
 clc
 rts
:cl_next
 lda :cl_idx
 clc
 adc #6                ; 6 bytes per ladder entry
 sta :cl_idx
* compare /6 to ladder_count: easier to compare to count*6
 lda ladder_count
 sta :tmp
 asl
 clc
 adc :tmp              ; A = count * 3
 asl                   ; A = count * 6
 cmp :cl_idx
 beq :cl_no
 bcs :cl_scan
:cl_no
 lda :prop_y
 sec
 rts
:prop_y dfb 0
:cl_idx dfb 0
:swx    ds 2
:swx_l  ds 2         ; swx + LADDER_TOL (lenient left bound)
:swx_r  ds 2         ; swx - LADDER_TOL (lenient right bound)
:tmp    dfb 0

LADDER_TOL = 2        ; ±2 bytes (±4px) tolerance for ladder entry

* Overlay state — populated by OP_RIGHT / OP_LEFT / OP_UP, drawn by
* draw_overlay each frame, erased by update_overlay when timer hits 0.
* All position/size/sprite fields are written by the activating opcode
* so the same draw/erase code services every direction.
overlay_timer  dfb 0          ; frames remaining (0 = inactive)
overlay_x      dfb 0          ; IMAGE01_XPOS (screen byte)
overlay_y      dfb 0          ; IMAGE01_YPOS (scanline)
overlay_w      dfb 0          ; FRAME_X (width in bytes)
overlay_h      dfb 0          ; FRAME_Y (height in rows)
overlay_mirror dfb 0          ; 0 = normal, 1 = flipped (legacy; unused
                              ; under compiled pipeline — mirror is baked
                              ; into pre-rotated _DATA_MIRROR / _MASK_MIRROR)
overlay_addr   ds 2           ; pointer to sprite DATA (bank $02)
overlay_mask   ds 2           ; pointer to inverse MASK (bank $02)

* Pause state — toggled by ESC tap in check_pause. When paused,
* game_loop skips update_overlay/process_input/update_anims/etc.,
* leaving the screen frozen until the next ESC tap.
paused dfb 0                  ; 0 = running, 1 = paused

* PAUSED text geometry. QuickDraw uses pixel coords; erase uses
* the byte/row coords (1 byte = 2 pixels in 320 mode). Erase rect
* is sized generously to fully cover the rendered glyphs.
PAUSE_TEXT_X = 87            ; QuickDraw MoveTo h (pixels)
PAUSE_TEXT_Y = 100            ; QuickDraw MoveTo v (baseline)
PAUSE_BX     = 41             ; erase rect left (bytes; pixel 82)
PAUSE_BY     = 88             ; erase rect top  (rows)
PAUSE_BW     = 26             ; erase rect width  (bytes = 52 px)
PAUSE_BH     = 16             ; erase rect height (rows)

pause_str ASC 'PAUSED',00

*----------------------------------------------------------
* check_pause - If ESC is in the keyboard register, toggle the
* paused flag, consume the keystroke, and draw or erase the
* "PAUSED" overlay at the screen's center. Other keys are left
* in the strobe so process_input picks them up on the next
* unpaused frame.
*----------------------------------------------------------
check_pause
 lda $c000
 bpl :cp_done           ; bit 7 clear → no key waiting
 and #$7f
 cmp #$1B               ; ESC
 bne :cp_done           ; some other key — leave for process_input
 sta $c010              ; consume the strobe (write clears it)
 lda paused
 eor #$01               ; toggle 0↔1
 sta paused
 beq :cp_unpaused
 jsr draw_pause_text    ; just paused — render label
 rts
:cp_unpaused
 jsr erase_pause_text   ; just unpaused — restore playfield rect
:cp_done rts

*----------------------------------------------------------
* draw_pause_text - Draw "PAUSED" via QuickDraw II _DrawCString.
* Mirrors the startup HUD draw pattern (MoveTo, SetForeColor,
* SetBackColor, DrawCString). Switches to native mode, restores
* emulation before returning.
*----------------------------------------------------------
draw_pause_text
 clc
 xce                    ; native mode
 rep $30
* MoveTo(h, v)
 lda #PAUSE_TEXT_X
 pha
 lda #PAUSE_TEXT_Y
 pha
 ldx #$3a04
 jsl $E10000
* SetForeColor
 pea #$0001
 ldx #$A004
 jsl $E10000
* SetBackColor
 pea #$0000
 ldx #$A204
 jsl $E10000
 pea #$0000         ; normal text style
 ldx #$9A04
 jsl $E10000        ; SetTextFace
* DrawCString
 pea ^pause_str
 pea pause_str
 ldx #$A604
 jsl $E10000
 pea #$0001         ; restore bold style for score updates
 ldx #$9A04
 jsl $E10000        ; SetTextFace
 sec
 xce                    ; back to emulation
 rts

*----------------------------------------------------------
* erase_pause_text - Restore the rect under the PAUSED label by
* copying clean playfield bytes from $18 back to $01 via the
* standard erase routine.
*----------------------------------------------------------
erase_pause_text
 lda #PAUSE_BY
 sta IMAGE01_YPOS
 lda #PAUSE_BX
 sta IMAGE01_XPOS
 lda #PAUSE_BW
 sta FRAME_X
 lda #PAUSE_BH
 sta FRAME_Y
 jmp erase

* Player 1 score HUD position. Drawn over the "0000000" digits
* in the static HUD line at startup-MoveTo (3, 195) using the
* same bold face SetTextFace left enabled.
P1_SCORE_X   = 80             ; pixel x (just past "PLAYER 1: ")
P1_SCORE_Y   = 195            ; pixel baseline (matches HUD line)
P1_SCORE_LEN = 7              ; digit width (matches "0000000")

*----------------------------------------------------------
* draw_p1_score - If p1_score_dirty is non-zero, draw the
* p1_score C-string directly via _DrawCString over the
* static HUD digits, and clear the dirty flag. p1_score is
* maintained as live ASCII by the incp1s_* carry ladder, so
* no binary→decimal conversion is needed at draw time.
*----------------------------------------------------------
draw_p1_score
 lda p1_score_dirty
 bne :do_draw
 rts
:do_draw

 clc
 xce                    ; native mode
 rep $30

* MoveTo(P1_SCORE_X, P1_SCORE_Y)
 pea #P1_SCORE_X
 pea #P1_SCORE_Y
 ldx #$3a04
 jsl $E10000

* _DrawCString(pointer-to-string at p1_score)
 pea #$0000
 pea p1_score
 ldx #$A604
 jsl $E10000

* Clear dirty flag (16-bit stz wipes both bytes)
 stz p1_score_dirty

 sec
 xce                    ; back to emulation
 sep #$30
 rts

*----------------------------------------------------------
* Debug overlay: tap 'd' to toggle a hex readout of Billy's
* IMAGE01_XPOS and IMAGE01_YPOS at (225,40)/(225,50). Useful
* for tuning bounds tables. Also see inc_border below — it
* steps the SHR border color each time current_screen advances.
*----------------------------------------------------------
debug_xy_flag dfb 0
dbg_xy_buf    dfb 0,0,0           ; 2 hex chars + null terminator
dbg_xy_blank  ASC '   ',00         ; 3 spaces — overwrites any 2-char label

DBG_XY_X      = 225
DBG_XY_Y_X    = 40
DBG_XY_Y_Y    = 50

*----------------------------------------------------------
* check_debug_xy - 'd' tap toggles debug_xy_flag. On toggle
* OFF we wipe the labels (QuickDraw drew them straight to $E1,
* nothing else will overwrite that area otherwise).
*----------------------------------------------------------
check_debug_xy
 lda $c000
 bpl :cdx_done
 and #$7f
 cmp #'d'
 bne :cdx_done
 sta $c010                ; consume strobe
 lda debug_xy_flag
 eor #$01
 sta debug_xy_flag
 bne :cdx_done            ; turned ON — let draw_debug_xy paint
 jsr clear_debug_xy       ; turned OFF — wipe the labels
:cdx_done rts

*----------------------------------------------------------
* draw_debug_xy - Format Billy's xpos/ypos as 2 hex chars and
* draw via _DrawCString. No-op if flag is off.
*----------------------------------------------------------
draw_debug_xy
 lda debug_xy_flag
 bne :ddx_active
 rts
:ddx_active
 clc
 xce                      ; native mode
 rep $30

* X readout — read directly from billy_sprite block. The
* IMAGE01_XPOS global holds whatever sprite was loaded last
* by erase_all/draw_all, which is the last sprite in the
* Y-sorted table — usually an NPC, not Billy.
 sep $20
 lda billy_sprite+2
 jsr fmt_hex8_to_xy_buf
 rep $20
 pea #DBG_XY_X
 pea #DBG_XY_Y_X
 ldx #$3a04               ; MoveTo
 jsl $E10000
 pea #$0000
 pea dbg_xy_buf
 ldx #$A604               ; DrawCString
 jsl $E10000

* Y readout — billy_sprite[+0] = ypos
 sep $20
 lda billy_sprite
 jsr fmt_hex8_to_xy_buf
 rep $20
 pea #DBG_XY_X
 pea #DBG_XY_Y_Y
 ldx #$3a04
 jsl $E10000
 pea #$0000
 pea dbg_xy_buf
 ldx #$A604
 jsl $E10000

 sec
 xce                      ; back to emulation
 sep #$30
 rts

*----------------------------------------------------------
* clear_debug_xy - Overwrite the readout area with spaces.
* Called by check_debug_xy when the flag toggles OFF.
*----------------------------------------------------------
clear_debug_xy
 clc
 xce
 rep $30

 pea #DBG_XY_X
 pea #DBG_XY_Y_X
 ldx #$3a04
 jsl $E10000
 pea #$0000
 pea dbg_xy_blank
 ldx #$A604
 jsl $E10000

 pea #DBG_XY_X
 pea #DBG_XY_Y_Y
 ldx #$3a04
 jsl $E10000
 pea #$0000
 pea dbg_xy_blank
 ldx #$A604
 jsl $E10000

 sec
 xce
 sep #$30
 rts

*----------------------------------------------------------
* fmt_hex8_to_xy_buf - 8-bit A → 2 hex chars at dbg_xy_buf.
* Caller in 8-bit M. Trashes A.
*----------------------------------------------------------
fmt_hex8_to_xy_buf
 pha
 lsr
 lsr
 lsr
 lsr
 jsr :fhx_nib
 sta dbg_xy_buf
 pla
 and #$0F
 jsr :fhx_nib
 sta dbg_xy_buf+1
 rts
:fhx_nib
 cmp #10
 bcc :fhx_digit
 clc
 adc #'A'-10
 rts
:fhx_digit
 clc
 adc #'0'
 rts

*----------------------------------------------------------
* inc_border - Step SHR border color (low nibble of $C034)
* by 1, wrapping within $0-$F. Preserves the high nibble
* (text background). Hooked at every current_screen update
* site — flashes a visual marker each time a screen finishes
* scrolling in. No-op when the debug overlay is off so the
* border only flickers when the developer wants it to.
*----------------------------------------------------------
inc_border
 php
 sep #$20
 lda debug_xy_flag
 beq :ib_done            ; debug off → leave border alone
 ldal $C034
 sta :ib_saved
 and #$0F
 clc
 adc #1
 and #$0F
 sta :ib_nib
 lda :ib_saved
 and #$F0
 ora :ib_nib
 stal $C034
:ib_done
 plp
 rts
:ib_saved dfb 0
:ib_nib   dfb 0

*----------------------------------------------------------
* update_overlay - Decrement overlay timer. When it expires,
* erase the overlay rect from the $18 shadow.
*----------------------------------------------------------
update_overlay
 lda overlay_timer
 beq :done
 sec
 sbc #1
 sta overlay_timer
 bne :done
 jsr erase_overlay_rect
:done rts

*----------------------------------------------------------
* clear_active_overlay - if overlay_timer != 0, immediately
* erase the current overlay rect and force timer to 0.
* Called by OP_RIGHT/LEFT/UP before they overwrite overlay state
* so the previous overlay's pixels are removed from the playfield
* (otherwise the erase rect would point at the new position when
* the timer eventually expired, leaving the old pixels on screen).
*----------------------------------------------------------
clear_active_overlay
 lda overlay_timer
 beq :cao_done
 jsr erase_overlay_rect
 stz overlay_timer
:cao_done rts

*----------------------------------------------------------
* erase_overlay_rect - erase the rect described by current
* overlay_x/y/w/h via the standard erase routine.
*----------------------------------------------------------
erase_overlay_rect
 lda overlay_y
 sta IMAGE01_YPOS
 lda overlay_x
 sta IMAGE01_XPOS
 lda overlay_w
 sta FRAME_X
 lda overlay_h
 sta FRAME_Y
 jmp erase

*----------------------------------------------------------
* draw_overlay - If overlay is active, render the cached
* overlay sprite via draw_sprite_compiled (AND/ORA pipeline).
* Saves and restores the engine's draw globals so the call
* doesn't disturb gameplay sprites mid-frame.
*----------------------------------------------------------
draw_overlay
 lda overlay_timer
 bne :active
 rts
:active
* Save current globals
 lda IMAGE01_YPOS
 pha
 lda IMAGE01_XPOS
 pha
 lda FRAME_X
 pha
 lda FRAME_Y
 pha
 lda FRAME_ADDR
 pha
 lda FRAME_ADDR+1
 pha
 lda MASK_ADDR
 pha
 lda MASK_ADDR+1
 pha
* Set overlay globals from cached state
 lda overlay_y
 sta IMAGE01_YPOS
 lda overlay_x
 sta IMAGE01_XPOS
 lda overlay_w
 sta FRAME_X
 lda overlay_h
 sta FRAME_Y
 lda overlay_addr
 sta FRAME_ADDR
 lda overlay_addr+1
 sta FRAME_ADDR+1
 lda overlay_mask
 sta MASK_ADDR
 lda overlay_mask+1
 sta MASK_ADDR+1
 jsr draw_sprite_compiled
* Restore globals
 pla
 sta MASK_ADDR+1
 pla
 sta MASK_ADDR
 pla
 sta FRAME_ADDR+1
 pla
 sta FRAME_ADDR
 pla
 sta FRAME_Y
 pla
 sta FRAME_X
 pla
 sta IMAGE01_XPOS
 pla
 sta IMAGE01_YPOS
:done rts

*----------------------------------------------------------
* draw_ladder_debug - For each ladder in ladder_buf, draw
* vertical lines in color 0 at x_left and x_right from
* y_top to y_bottom. Visualizes ladder bounds for debugging.
*----------------------------------------------------------
draw_ladder_debug
 lda ladder_count
 bne :have
 rts
:have
 clc
 xce                   ; native mode
 rep $20               ; 16-bit A
 sep $10               ; 8-bit X/Y
 mx %01
* Bank byte for [$F0] = $01
 sep $20
 mx %11
 lda #$01
 sta $F2
 rep $20
 mx %01
 ldx #0
 stx :ld_idx
:next_ladder
 ldx :ld_idx
* Compute screen byte = ladder_x_left (16-bit) - world_offset
 lda ladder_buf,x      ; 16-bit read of x_left
 sec
 sbc world_offset
 sta :sxl
 lda ladder_buf+2,x    ; 16-bit read of x_right
 sec
 sbc world_offset
 sta :sxr
 sep $20
 mx %11
 lda ladder_buf+4,x
 sta :yt
 lda ladder_buf+5,x
 sta :yb
 rep $20
 mx %01

* If both endpoints are off-screen on the same side, skip
 lda :sxl
 bmi :ld_skip          ; sxl negative (>=$8000)
 cmp #110
 bcs :try_xr_only      ; sxl off right; check x_right
 jmp :draw_loop
:try_xr_only
 lda :sxr
 bmi :ld_skip
 cmp #110
 bcs :ld_skip          ; both off-screen
:draw_loop
 ldx :yt
:row
 stx :yc
* base = $2000 + y * 160
 txa
 and #$00FF
 sta :tmp
 asl
 asl                   ; y*4
 clc
 adc :tmp              ; y*5
 asl
 asl
 asl
 asl
 asl                   ; y*160
 clc
 adc #$2000
 sta :base
* Draw at sxl if visible
 lda :sxl
 bmi :skip_xl
 cmp #110
 bcs :skip_xl
 clc
 adc :base
 sta $F0
 sep $20
 mx %11
 lda #$F0
 sta [$F0]
 rep $20
 mx %01
:skip_xl
* Draw at sxr if visible
 lda :sxr
 bmi :skip_xr
 cmp #110
 bcs :skip_xr
 clc
 adc :base
 sta $F0
 sep $20
 mx %11
 lda #$F0
 sta [$F0]
 rep $20
 mx %01
:skip_xr
* Next scanline
 ldx :yc
 inx
 cpx :yb
 bcc :row
 beq :row
:ld_skip
* Advance ladder index by 6 bytes
 sep $20
 mx %11
 lda :ld_idx
 clc
 adc #6
 sta :ld_idx
* compare /6 to ladder_count
 lda ladder_count
 sta :tmp
 asl
 clc
 adc :tmp              ; *3
 asl                   ; *6
 cmp :ld_idx
 rep $20
 mx %01
 bcc :ld_done
 beq :ld_done
 jmp :next_ladder
:ld_done
 rep $30
 sec
 xce
 rts
:ld_idx dfb 0
:sxl    ds 2          ; signed 16-bit screen byte position (left edge)
:sxr    ds 2          ; signed 16-bit screen byte position (right edge)
:yt    dfb 0
:yb    dfb 0
:yc    dfb 0
:tmp   dfb 0
:base  ds 2


* NPC sprite block buffers
* IMPORTANT: script_spawn_npc does NOT bounds-check npc_buf_next,
* so overflowing this buffer silently corrupts whatever follows
* it in the binary — typically code. Each slot is 56 bytes.
* Ensure size covers the maximum total NPCs spawned over the
* level's lifetime (not just concurrent), since npc_buf_next
* only advances, never reuses slots of defeated NPCs.
NPC_BUFFER_SLOTS = 16
npc_buffers ds NPC_BUFFER_SLOTS*56
npc_buffers_end

*----------------------------------------------------------
* update_npcs - Iterate sprite_table, dispatch each NPC's
* behavior. Called each frame by the game loop.
*----------------------------------------------------------
update_npcs
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:loop
 ldy #0
 lda (spr_ptr),y
 sta info_ptr
 iny
 lda (spr_ptr),y
 sta info_ptr+1
 ora info_ptr
 beq :done            ; null terminator
 ldy #22
 lda (info_ptr),y     ; controller
 bne :skip            ; non-zero = player, skip
* Dispatch by behavior at offset +6
 ldy #6
 lda (info_ptr),y
 cmp #BEHAV_FACEOFF
 bne :nbf
 jsr behav_faceoff
 bra :skip
:nbf
 cmp #BEHAV_FLANK
 bne :nbfl
 jsr behav_flank
 bra :skip
:nbfl
 cmp #BEHAV_LADDER
 bne :nbld
 jsr behav_ladder
 bra :skip
:nbld
* BEHAV_NONE or unknown — do nothing
:skip
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :loop
 inc spr_ptr+1
 bra :loop
:done rts

*----------------------------------------------------------
* behav_faceoff - Face-Off behavior state machine.
* info_ptr points to NPC's sprite block.
*
* States (at info_ptr+7):
*   FO_APPROACH - walk toward player until within 5 pixels
*                 along the player's facing axis
*   FO_PUNCH    - throw a punch animation
*   FO_COOLDOWN - wait N frames after punch finishes
*----------------------------------------------------------
* xpos byte-units; 100 bytes = 200 pixels in 320 mode.
SCROLL_THRESH = 80    ; player xpos at/over which walking scrolls right
LEFT_SCROLL_THRESH = 30 ; player xpos at/under which walking scrolls left
UP_SCROLL_THRESH = 90 ; player ypos at/under which walking-up scrolls
KICK_BACK_EXT = 10     ; bytes to extend kick hit box opposite Billy's
                       ; facing so the foot reaches enemies behind him
PLAYFIELD_EDGE = 109   ; rightmost byte position in the 110-byte playfield
PLAYER_MAX_X = 98      ; rightmost xpos the player can walk to — ~22px inset
                       ; from PLAYFIELD_EDGE so Billy doesn't walk into the
                       ; black area past the playable background.
* Upper screen alignment: world byte position of screen 5's
* leftmost pixel. Originally screen 5 was placed at world
* byte 4*110 = 440 (above screen 4); the user's art has it
* offset +18 from there → 458. Adjust if the upper screen
* needs to slide left or right relative to the lower world.
UP_X_ANCHOR = 330       ; world byte position of upper-screen left edge
UP_LEFT_FILL = 20       ; bytes to always fill from left neighbor on upper screen
UP_LEFT_WIDTH = 52      ; screen 6's content width in bytes (104 pixels)
FO_RANGE   = 4         ; pixels — engage punching at this distance
FO_CD_TIME = 90        ; cooldown frames after a punch

behav_faceoff
 ldy #7
 lda (info_ptr),y      ; behavior_state
 cmp #FO_PUNCH
 beq :st_punch
 cmp #FO_COOLDOWN
 beq :st_cooldown
* default: FO_APPROACH
 jmp fo_approach

:st_punch
 jmp fo_punch
:st_cooldown
 jmp fo_cooldown

*----------------------------------------------------------
* fo_find_player - Locate the keyboard-controlled player
* sprite. Returns its position/facing in fo_plr_x/y/facing.
* Returns Z=0 if found, Z=1 if not.
*----------------------------------------------------------
fo_find_player
 lda spr_ptr
 sta fo_save_spr
 lda spr_ptr+1
 sta fo_save_spr+1
 lda info_ptr
 sta fo_save_info
 lda info_ptr+1
 sta fo_save_info+1

 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:fpl
 ldy #0
 lda (spr_ptr),y
 sta info_ptr
 iny
 lda (spr_ptr),y
 sta info_ptr+1
 ora info_ptr
 beq :notfound
 ldy #22
 lda (info_ptr),y      ; controller
 cmp #$01
 beq :found
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :fpl
 inc spr_ptr+1
 bra :fpl
:found
 ldy #0
 lda (info_ptr),y
 sta fo_plr_y
 ldy #2
 lda (info_ptr),y
 sta fo_plr_x
 ldy #4
 lda (info_ptr),y
 sta fo_plr_facing
 ldy #10
 lda (info_ptr),y
 sta fo_plr_w
* Restore caller's pointers, return Z=0
 lda fo_save_spr
 sta spr_ptr
 lda fo_save_spr+1
 sta spr_ptr+1
 lda fo_save_info
 sta info_ptr
 lda fo_save_info+1
 sta info_ptr+1
 lda #$01              ; non-zero: found
 rts
:notfound
 lda fo_save_spr
 sta spr_ptr
 lda fo_save_spr+1
 sta spr_ptr+1
 lda fo_save_info
 sta info_ptr
 lda fo_save_info+1
 sta info_ptr+1
 lda #0                ; Z=1: not found
 rts

*----------------------------------------------------------
* fo_approach - Walk toward player. When within FO_RANGE
* of the player's facing edge, transition to FO_PUNCH.
*----------------------------------------------------------
fo_approach
* If a stun/action animation is playing (not idle and not
* anim_wwalk), don't advance behavior — let it finish.
* Otherwise we'd transition to PUNCH mid-fall and clobber
* the fall, preventing the death sentinel from firing.
 jsr npc_behavior_blocked
 beq :not_blocked
 rts
:not_blocked
 jsr fo_find_player
 bne :have_player
 jmp :no_action
:have_player
 jsr npc_ensure_walking

* Compute target X based on player's facing:
*   If player faces right (mirror=0): target = player_x + player_w + FO_RANGE
*   If player faces left  (mirror=1): target = player_x - FO_RANGE - npc_w
 lda fo_plr_facing
 bne :plr_left

* Player faces right — target is to the right of player
 lda fo_plr_x
 clc
 adc fo_plr_w
 clc
 adc #FO_RANGE
 sta fo_target_x
* NPC should face LEFT (mirror=1) to face the player
 ldy #4
 lda #$01
 sta (info_ptr),y
 bra :do_move

:plr_left
* Player faces left — target is to the left of player
 lda fo_plr_x
 sec
 sbc #FO_RANGE
 ldy #10
 sec
 sbc (info_ptr),y      ; subtract NPC width
 sta fo_target_x
* NPC should face RIGHT (mirror=0) to face the player
 ldy #4
 lda #$00
 sta (info_ptr),y

:do_move
* Snapshot current pos/size to prev fields before modifying
* (so erase_all knows where to erase last frame's drawing)
 ldy #0
 lda (info_ptr),y      ; current ypos
 ldy #32
 sta (info_ptr),y      ; -> prev_ypos
 ldy #2
 lda (info_ptr),y      ; current xpos
 ldy #34
 sta (info_ptr),y      ; -> prev_xpos
 ldy #10
 lda (info_ptr),y      ; current frame_x
 ldy #36
 sta (info_ptr),y      ; -> prev_frame_x
 ldy #12
 lda (info_ptr),y      ; current frame_y
 ldy #38
 sta (info_ptr),y      ; -> prev_frame_y

* Compare NPC X to target X. Move 1 pixel toward target, but
* only commit if the proposed X is still inside the row's
* walkable bounds (keeps NPCs from walking off the playfield).
* Mirror is updated unconditionally so the NPC still faces the
* player when blocked.
 ldy #2
 lda (info_ptr),y      ; current xpos
 cmp fo_target_x
 beq :x_at_target
 bcs :x_decrement
* xpos < target, try xpos + 1. Check the RIGHT edge
* (xpos + frame_x) against bounds so wider frames can't
* extend past bmax.
 ldy #4
 lda #$00
 sta (info_ptr),y      ; mirror = 0 (facing right)
 ldy #2
 lda (info_ptr),y      ; current xpos
 ldy #10
 clc
 adc (info_ptr),y      ; + frame_x = new right edge
 sta chk_xpos
 ldy #0
 lda (info_ptr),y      ; current ypos
 jsr check_y_bounds
 bcs :x_at_target      ; blocked by row bounds
 ldy #2
 lda (info_ptr),y
 clc
 adc #1
 sta (info_ptr),y
 bra :move_y
:x_decrement
* Try xpos - 1. Left-edge check is sufficient since the
* sprite extends only to the right of xpos.
 ldy #4
 lda #$01
 sta (info_ptr),y      ; mirror = 1 (facing left)
 ldy #2
 lda (info_ptr),y
 sec
 sbc #1
 sta chk_xpos
 ldy #0
 lda (info_ptr),y      ; current ypos
 jsr check_y_bounds
 bcs :x_at_target
 ldy #2
 lda chk_xpos
 sta (info_ptr),y
:x_at_target

:move_y
* Move toward player Y at 1 pixel/frame (bounds-checked).
* The row-bounds table encodes where the sprite's TOP can sit
* (so the same table works for both lower-level bands like
* y=80-199 and narrow upper-level bands like y=40-59), so we
* check the proposed top row. We also bail if the proposed
* bottom (top + frame_y) would exceed 200 — that stops tall
* sprites from walking their feet off the bottom of the screen
* in the wide lower-level bands.
 ldy #2
 lda (info_ptr),y
 sta chk_xpos          ; NPC's current X
 ldy #0
 lda (info_ptr),y      ; current ypos
 cmp fo_plr_y
 beq :y_at_target
 bcs :y_decrement
* Try Y + 1 — proposed top = ypos+1
 clc
 adc #1
* Also check proposed bottom < 200 so feet stay on-screen.
 sta :yp_proposed
 ldy #12
 clc
 adc (info_ptr),y      ; A = proposed_top + frame_y = proposed_bottom
 cmp #200
 bcs :y_at_target
 lda :yp_proposed
 jsr check_y_bounds
 bcs :y_at_target      ; blocked, skip Y move
 ldy #0
 lda (info_ptr),y
 clc
 adc #1
 sta (info_ptr),y
 bra :check_range
:y_decrement
* Try Y - 1. Top-row check alone — decrementing can only push
* the bottom up, so the 200-clamp above isn't needed here.
 sec
 sbc #1
 jsr check_y_bounds
 bcs :y_at_target      ; blocked
 ldy #0
 lda (info_ptr),y
 sec
 sbc #1
 sta (info_ptr),y
:y_at_target

:check_range
* If we're close to target X and player Y, transition to PUNCH
 ldy #2
 lda (info_ptr),y
 cmp fo_target_x
 bne :still_moving     ; not in X position yet
 ldy #0
 lda (info_ptr),y
 cmp fo_plr_y
 bne :still_moving     ; not in Y position yet
* Reached target — start punch
 ldy #7
 lda #FO_PUNCH
 sta (info_ptr),y
 lda #FO_CD_TIME
 ldy #8
 sta (info_ptr),y      ; behavior_timer
 ldy #9
 lda #0
 sta (info_ptr),y
* Start the punch1 animation on this NPC
 jsr fo_start_punch
 jmp :commit

:still_moving
:commit
* Mark dirty (position changed)
 ldy #30
 lda #$03
 sta (info_ptr),y
:no_action
 rts

:yp_proposed dfb 0

*----------------------------------------------------------
* fo_start_punch - Trigger anim_wpunch on the NPC (William's
* punch). Replicates start_anim's setup but stays on the NPC.
*----------------------------------------------------------
fo_start_punch
* DEBUG: log fo_start_punch with info_ptr low (block identifier)
 lda #$C6              ; 'F'
 jsr dbg_print_char
 lda #$D0              ; 'P'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda info_ptr
 jsr dbg_print_hex8
 jsr dbg_print_nl
* Read per-NPC atk_anim from +54/+55 into anim_ptr ZP
 ldy #54
 lda (info_ptr),y
 sta anim_ptr
 ldy #55
 lda (info_ptr),y
 sta anim_ptr+1
* Install into sprite block
 ldy #24
 lda anim_ptr
 sta (info_ptr),y
 iny
 lda anim_ptr+1
 sta (info_ptr),y
 ldy #26
 lda #0
 sta (info_ptr),y      ; anim_frame = 0
* Load frame 0's data from the descriptor so it shows now.
* Descriptor header = 3 bytes, then frame_x(1), frame_y(1),
* dur(1), addr(2). Frame 0 data at offsets +3..+7.
 ldy #5
 lda (anim_ptr),y      ; duration
 ldy #28
 sta (info_ptr),y      ; anim_timer
 ldy #3
 lda (anim_ptr),y      ; frame_x
 ldy #10
 sta (info_ptr),y
 ldy #4
 lda (anim_ptr),y      ; frame_y
 ldy #12
 sta (info_ptr),y
 ldy #6
 lda (anim_ptr),y      ; frame_addr low
 ldy #14
 sta (info_ptr),y
 ldy #7
 lda (anim_ptr),y      ; frame_addr high
 ldy #15
 sta (info_ptr),y
 rts

*----------------------------------------------------------
* fo_punch - Wait for the punch animation to finish.
* When anim_ptr returns to 0 (animation terminated),
* transition to COOLDOWN.
*----------------------------------------------------------
fo_punch
 ldy #24
 lda (info_ptr),y
 iny
 ora (info_ptr),y
 bne :still_punching
* Animation done — go to cooldown
 ldy #7
 lda #FO_COOLDOWN
 sta (info_ptr),y
 lda #FO_CD_TIME
 ldy #8
 sta (info_ptr),y
 ldy #9
 lda #0
 sta (info_ptr),y
:still_punching
 rts

*----------------------------------------------------------
* fo_cooldown - Decrement timer. When zero, return to APPROACH.
*----------------------------------------------------------
fo_cooldown
 ldy #8
 lda (info_ptr),y
 beq :expired         ; safety: if already 0, expire
 sec
 sbc #1
 sta (info_ptr),y
 bne :wait_more
:expired
* Timer expired — back to approach
 ldy #7
 lda #FO_APPROACH
 sta (info_ptr),y
:wait_more
 rts

*----------------------------------------------------------
* npc_ensure_walking - If NPC's anim_ptr is not anim_wwalk,
* install it. anim_frame=$FF + timer=1 makes update_anims
* advance to (and load) frame 0 this same frame.
*----------------------------------------------------------
*----------------------------------------------------------
* npc_behavior_blocked - Returns A=1 (Z=0) if a stun or
* attack animation is playing (anim_ptr != 0 and != anim_wwalk).
* Returns A=0 (Z=1) if behavior is free to advance.
*----------------------------------------------------------
npc_behavior_blocked
 ldy #24
 lda (info_ptr),y
 sta :tmp
 ldy #25
 lda (info_ptr),y
 ora :tmp
 beq :free            ; anim_ptr == 0 — idle, free to advance
* Non-zero anim_ptr — check if it matches walk_anim (+52)
 ldy #24
 lda (info_ptr),y
 ldy #52
 cmp (info_ptr),y     ; walk_anim low
 bne :blocked
 ldy #25
 lda (info_ptr),y
 ldy #53
 cmp (info_ptr),y     ; walk_anim high
 bne :blocked
:free
 lda #0
 rts
:blocked
 lda #1
 rts
:tmp dfb 0

npc_ensure_walking
* Only install walk anim if no animation is currently
* active (anim_ptr == 0). Reads per-NPC walk_anim from +52.
 ldy #24
 lda (info_ptr),y
 sta :tmp
 ldy #25
 lda (info_ptr),y
 ora :tmp
 beq :install
 rts
:install
 ldy #52
 lda (info_ptr),y      ; walk_anim low
 ldy #24
 sta (info_ptr),y      ; anim_ptr low
 ldy #53
 lda (info_ptr),y      ; walk_anim high
 ldy #25
 sta (info_ptr),y      ; anim_ptr high
 ldy #26
 lda #$FF
 sta (info_ptr),y      ; anim_frame = $FF (so +1 wraps to 0)
 ldy #28
 lda #1
 sta (info_ptr),y      ; anim_timer = 1 (expires this frame)
 rts
:tmp dfb 0

* Face-off scratch variables
fo_plr_x dfb 0
fo_plr_y dfb 0
fo_plr_facing dfb 0
fo_plr_w dfb 0
fo_target_x dfb 0
fo_save_spr ds 2
fo_save_info ds 2

*----------------------------------------------------------
* behav_flank - Flank behavior state machine.
* Flanker arcs around to a target X on the OPPOSITE side
* of the player from FACEOFF (behind the player), then
* closes in and punches.
*
* States (at info_ptr+7):
*   FL_ARC      - move toward (target_x, corner_y)
*   FL_CLOSE    - move toward (target_x, player_y)
*   FL_PUNCH    - punch animation in progress
*   FL_COOLDOWN - countdown before next attempt
*
* Storage:
*   +7 state, +8 timer, +9 corner_y (0 = uninitialized)
*----------------------------------------------------------
FL_RANGE      = 4         ; pixels behind player to punch
FL_CD_TIME    = 90
FL_ARC_OFFSET = 14        ; vertical detour distance

behav_flank
 ldy #7
 lda (info_ptr),y
 cmp #FL_CLOSE
 beq :st_close
 cmp #FL_PUNCH
 beq :st_punch
 cmp #FL_COOLDOWN
 beq :st_cd
* default: FL_ARC
 jmp fl_arc
:st_close
 jmp fl_close
:st_punch
 jmp fl_punch
:st_cd
 jmp fl_cooldown

*----------------------------------------------------------
* behav_ladder - NPC descends the first ladder, then
* converts itself to BEHAV_FACEOFF on reaching the bottom.
*
* States (at info+7):
*   LD_INIT     - snap NPC X/Y to ladder top, init climb_tog
*   LD_DESCEND  - step Y by 1 each frame, alternate climb frames
*
* Stash:
*   info+8 = climb_tog (0/1)
*   info+9 = ladder y_bottom (cached)
*----------------------------------------------------------
behav_ladder
 ldy #7
 lda (info_ptr),y
 cmp #LD_DESCEND
 beq :ld_descend
* LD_INIT: snap to ladder top
 lda ladder_count
 bne :have_ladder
 rts
:have_ladder
* Snapshot current (spawn) pos/size to prev before changing
 ldy #0
 lda (info_ptr),y
 ldy #32
 sta (info_ptr),y       ; prev_ypos = old ypos
 ldy #2
 lda (info_ptr),y
 ldy #34
 sta (info_ptr),y       ; prev_xpos = old xpos
 ldy #10
 lda (info_ptr),y
 ldy #36
 sta (info_ptr),y       ; prev_frame_x
 ldy #12
 lda (info_ptr),y
 ldy #38
 sta (info_ptr),y       ; prev_frame_y
* New X: ladder.x_left (low byte) - world_offset
 lda ladder_buf
 sec
 sbc world_offset
 ldy #2
 sta (info_ptr),y
* New Y: ladder.y_top
 lda ladder_buf+4
 ldy #0
 sta (info_ptr),y
* Descent target: one row below the ladder's y_bottom, so
* Linda lands on the first walkable row beneath the ladder
* (ladder y_bottom is the last on-ladder row; y_bottom+1 is
* the first row where she can walk freely).
 lda ladder_buf+5
 clc
 adc #1
 ldy #9
 sta (info_ptr),y      ; cache target Y at +9
* Mirror = 0
 ldy #4
 lda #$00
 sta (info_ptr),y
* Reset climb toggle at +8
 ldy #8
 lda #0
 sta (info_ptr),y
* Frame: LCLIMB1 (9 wide × 39 tall)
 jsr ld_set_frame
* Mark dirty (erase + draw)
 ldy #30
 lda #$03
 sta (info_ptr),y
* Transition to LD_DESCEND
 ldy #7
 lda #LD_DESCEND
 sta (info_ptr),y
 rts

:ld_descend
* Step counter at info+8: only descend every 4th frame
* (4 px/16 frames at 60Hz ≈ 15 px/sec). Bit 2 of counter
* selects LCLIMB1 vs LCLIMB2 → frame swaps every 8 frames.
 ldy #8
 lda (info_ptr),y
 clc
 adc #1
 sta (info_ptr),y
 and #$03
 beq :do_step
 rts
:do_step
* Snapshot prev fields before mutating
 ldy #0
 lda (info_ptr),y
 ldy #32
 sta (info_ptr),y       ; prev_ypos
 ldy #2
 lda (info_ptr),y
 ldy #34
 sta (info_ptr),y       ; prev_xpos
 ldy #10
 lda (info_ptr),y
 ldy #36
 sta (info_ptr),y
 ldy #12
 lda (info_ptr),y
 ldy #38
 sta (info_ptr),y
* Have we reached y_bottom?
 ldy #0
 lda (info_ptr),y
 ldy #9
 cmp (info_ptr),y
 bcc :step
* Reached bottom — convert behavior to FACEOFF
 ldy #6
 lda #BEHAV_FACEOFF
 sta (info_ptr),y
 ldy #7
 lda #0
 sta (info_ptr),y
 rts
:step
* Increment Y by 1
 ldy #0
 lda (info_ptr),y
 clc
 adc #1
 sta (info_ptr),y
 jsr ld_set_frame
 ldy #30
 lda #$03
 sta (info_ptr),y
 rts

*----------------------------------------------------------
* ld_set_frame - Write LCLIMB1 or LCLIMB2 frame data into
* the NPC's info block based on info+8 toggle.
*----------------------------------------------------------
ld_set_frame
 ldy #10
 lda #$09               ; frame_x
 sta (info_ptr),y
 ldy #12
 lda #$27               ; frame_y
 sta (info_ptr),y
* Frame select: bit 2 of step counter (info+8)
 ldy #8
 lda (info_ptr),y
 and #$04
 beq :use_l1
 lda spr_lclimb2
 ldy #14
 sta (info_ptr),y
 lda spr_lclimb2+1
 ldy #15
 sta (info_ptr),y
 rts
:use_l1
 lda spr_lclimb1
 ldy #14
 sta (info_ptr),y
 lda spr_lclimb1+1
 ldy #15
 sta (info_ptr),y
 rts

*----------------------------------------------------------
* fl_compute_target - Sets fo_target_x to the back-side
* punch X for flanker, and writes NPC mirror to face player.
* Requires fo_find_player to have been called first.
* Trashes A.
*----------------------------------------------------------
fl_compute_target
 lda fo_plr_facing
 bne :pf_left
* Player faces right: flanker target is to the LEFT of player
 lda fo_plr_x
 sec
 sbc #FL_RANGE
 ldy #10
 sec
 sbc (info_ptr),y      ; subtract NPC width
 sta fo_target_x
* NPC faces RIGHT (mirror=0) toward player's back
 ldy #4
 lda #$00
 sta (info_ptr),y
 rts
:pf_left
* Player faces left: flanker target is to the RIGHT of player
 lda fo_plr_x
 clc
 adc fo_plr_w
 clc
 adc #FL_RANGE
 sta fo_target_x
* NPC faces LEFT (mirror=1)
 ldy #4
 lda #$01
 sta (info_ptr),y
 rts

*----------------------------------------------------------
* fl_snapshot_prev - Snapshot pos/size to prev fields so
* erase_all knows where to erase last frame's drawing.
*----------------------------------------------------------
fl_snapshot_prev
 ldy #0
 lda (info_ptr),y
 ldy #32
 sta (info_ptr),y
 ldy #2
 lda (info_ptr),y
 ldy #34
 sta (info_ptr),y
 ldy #10
 lda (info_ptr),y
 ldy #36
 sta (info_ptr),y
 ldy #12
 lda (info_ptr),y
 ldy #38
 sta (info_ptr),y
 rts

*----------------------------------------------------------
* fl_step_x - Move xpos one toward fo_target_x.
* Returns Z=1 if reached.
*----------------------------------------------------------
fl_step_x
 ldy #2
 lda (info_ptr),y
 cmp fo_target_x
 beq :done
 bcs :dec
 clc
 adc #1
 sta (info_ptr),y
 ldy #4
 lda #$00
 sta (info_ptr),y      ; mirror = 0 (facing right)
 lda #1                ; not at target
 rts
:dec
 sec
 sbc #1
 sta (info_ptr),y
 ldy #4
 lda #$01
 sta (info_ptr),y      ; mirror = 1 (facing left)
 lda #1
 rts
:done
 lda #0
 rts

*----------------------------------------------------------
* fl_step_y_to - Move ypos one toward value in A.
* Returns Z=1 if reached.
*----------------------------------------------------------
fl_step_y_to
 sta fl_y_target
* Set chk_xpos from NPC's current X
 ldy #2
 lda (info_ptr),y
 sta chk_xpos
 ldy #0
 lda (info_ptr),y
 cmp fl_y_target
 beq :done
 bcs :dec
* Try Y + 1
 clc
 adc #1
 jsr check_y_bounds
 bcs :done            ; blocked
 ldy #0
 lda (info_ptr),y
 clc
 adc #1
 sta (info_ptr),y
 lda #1
 rts
:dec
* Try Y - 1
 sec
 sbc #1
 jsr check_y_bounds
 bcs :done            ; blocked
 ldy #0
 lda (info_ptr),y
 sec
 sbc #1
 sta (info_ptr),y
 lda #1
 rts
:done
 lda #0
 rts

*----------------------------------------------------------
* fl_arc - Arc to a corner behind the player.
* Computes corner_y on first entry: detour above or below
* depending on which side of player_y the NPC starts on.
*----------------------------------------------------------
fl_arc
 jsr npc_behavior_blocked
 beq :not_blocked
 rts
:not_blocked
 jsr fo_find_player
 bne :have_player
 jmp :no_action
:have_player
 jsr npc_ensure_walking

 jsr fl_compute_target

* Lazy init corner_y if zero
 ldy #9
 lda (info_ptr),y
 bne :have_corner
* Compute corner_y based on NPC's current Y vs player Y
 ldy #0
 lda (info_ptr),y      ; npc ypos
 cmp fo_plr_y
 bcs :below
* npc_y < player_y → detour above (smaller Y)
 lda fo_plr_y
 sec
 sbc #FL_ARC_OFFSET
 bra :store_corner
:below
 lda fo_plr_y
 clc
 adc #FL_ARC_OFFSET
:store_corner
 ora #$01              ; ensure non-zero sentinel safety
 ldy #9
 sta (info_ptr),y
:have_corner

 jsr fl_snapshot_prev
 jsr fl_step_x
 sta fl_x_done         ; 0 if reached
 ldy #9
 lda (info_ptr),y
 jsr fl_step_y_to
 sta fl_y_done

* Mark dirty (position changed)
 ldy #30
 lda #$03
 sta (info_ptr),y

* If both axes at corner, transition to FL_CLOSE
 lda fl_x_done
 ora fl_y_done
 bne :no_action
 ldy #7
 lda #FL_CLOSE
 sta (info_ptr),y
:no_action
 rts

*----------------------------------------------------------
* fl_close - Move from corner to back-side punch X at
* player_y. When reached, start punch.
*----------------------------------------------------------
fl_close
 jsr npc_behavior_blocked
 beq :not_blocked
 rts
:not_blocked
 jsr fo_find_player
 bne :have_player
 jmp :no_action
:have_player
 jsr npc_ensure_walking

 jsr fl_compute_target
 jsr fl_snapshot_prev
 jsr fl_step_x
 sta fl_x_done
 lda fo_plr_y
 jsr fl_step_y_to
 sta fl_y_done

 ldy #30
 lda #$03
 sta (info_ptr),y

 lda fl_x_done
 ora fl_y_done
 bne :no_action
* In position — only strike if no other live NPCs remain.
 jsr fl_others_alive
 bne :no_action
* Reached back-side punch position — punch
 ldy #7
 lda #FL_PUNCH
 sta (info_ptr),y
 jsr fo_start_punch
:no_action
 rts

*----------------------------------------------------------
* fl_others_alive - Returns A=1 (Z=0) if any OTHER live
* NPC exists in the sprite table (excluding self and the
* keyboard player). Returns A=0 (Z=1) if this flanker is
* the only NPC left.
* Preserves spr_ptr/info_ptr.
*----------------------------------------------------------
fl_others_alive
 lda spr_ptr
 sta fl_save_spr
 lda spr_ptr+1
 sta fl_save_spr+1
 lda info_ptr
 sta fl_save_info
 lda info_ptr+1
 sta fl_save_info+1
 lda info_ptr
 sta fl_self
 lda info_ptr+1
 sta fl_self+1

 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:loop
 ldy #0
 lda (spr_ptr),y
 sta info_ptr
 iny
 lda (spr_ptr),y
 sta info_ptr+1
 ora info_ptr
 beq :nope            ; end of table — no others found
* Skip self
 lda info_ptr
 cmp fl_self
 bne :check
 lda info_ptr+1
 cmp fl_self+1
 beq :next
:check
* Skip the player (controller=$01)
 ldy #22
 lda (info_ptr),y
 cmp #$01
 beq :next
* Skip if this NPC is already dying ($FFFF sentinel)
 ldy #24
 lda (info_ptr),y
 cmp #$FF
 bne :alive
 ldy #25
 lda (info_ptr),y
 cmp #$FF
 beq :next
:alive
 jmp :yes
:next
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :loop
 inc spr_ptr+1
 bra :loop
:yes
 lda fl_save_spr
 sta spr_ptr
 lda fl_save_spr+1
 sta spr_ptr+1
 lda fl_save_info
 sta info_ptr
 lda fl_save_info+1
 sta info_ptr+1
 lda #1
 rts
:nope
 lda fl_save_spr
 sta spr_ptr
 lda fl_save_spr+1
 sta spr_ptr+1
 lda fl_save_info
 sta info_ptr
 lda fl_save_info+1
 sta info_ptr+1
 lda #0
 rts

*----------------------------------------------------------
* fl_punch - Wait for punch animation to terminate, then
* go to cooldown.
*----------------------------------------------------------
fl_punch
 ldy #24
 lda (info_ptr),y
 iny
 ora (info_ptr),y
 bne :still
 ldy #7
 lda #FL_COOLDOWN
 sta (info_ptr),y
 lda #FL_CD_TIME
 ldy #8
 sta (info_ptr),y
:still
 rts

*----------------------------------------------------------
* fl_cooldown - Decrement timer. When zero, clear corner_y
* and return to FL_ARC for another approach.
*----------------------------------------------------------
fl_cooldown
 ldy #8
 lda (info_ptr),y
 beq :expired
 sec
 sbc #1
 sta (info_ptr),y
 bne :wait
:expired
 ldy #7
 lda #FL_ARC
 sta (info_ptr),y
 ldy #9
 lda #0
 sta (info_ptr),y      ; recompute corner next time
:wait
 rts

* Flank scratch variables
fl_x_done   dfb 0
fl_y_done   dfb 0
fl_y_target dfb 0
fl_self     ds 2
fl_anim     ds 2
fl_save_spr ds 2
fl_save_info ds 2

*----------------------------------------------------------
* erase_all - Iterate sprite_table, load each sprite,
* use max_width from animation descriptor if active, erase.
*----------------------------------------------------------
erase_all
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:loop jsr load_sprite
 bcc :not_end
 jmp :done
:not_end
* Check for death sentinel ($FFFF)
 ldy #24
 lda (info_ptr),y     ; anim_ptr low
 cmp #$FF
 bne :not_dead
 iny
 lda (info_ptr),y     ; anim_ptr high
 cmp #$FF
 bne :not_dead
* Death: erase at prev position, then remove from table.
* DEBUG: log death-erase with prev rect.
 lda #$D2              ; 'R'
 jsr dbg_print_char
 lda #$CD              ; 'M'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 ldy #32
 lda (info_ptr),y
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 ldy #34
 lda (info_ptr),y
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 ldy #36
 lda (info_ptr),y
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 ldy #38
 lda (info_ptr),y
 jsr dbg_print_hex8
 jsr dbg_print_nl
 ldy #32
 lda (info_ptr),y
 sta IMAGE01_YPOS
 ldy #34
 lda (info_ptr),y
 sta IMAGE01_XPOS
 ldy #36
 lda (info_ptr),y
 sta FRAME_X
 ldy #38
 lda (info_ptr),y
 sta FRAME_Y
 jsr erase
* Mark any still-living sprites whose drawn area overlaps the
* just-erased rect as needs_draw — otherwise if the dying
* enemy was drawn on top of (later Y than) the player, the
* erase wipes part of the player and no one redraws it.
 jsr mark_overlapping
 jsr remove_from_sprite_table
 bra :loop            ; don't advance spr_ptr — entries shifted down
:not_dead
* Erase if bit 1 set (needs_erase)
 ldy #30
 lda (info_ptr),y
 and #$02
 bne :do_erase
 jmp :skip_erase
:do_erase
* Compute the erase rect. It must cover both the prev-drawn
* pixels (so no ghost) and the area the new frame will draw
* (so transparent pixels in a grown/shifted frame don't reveal
* stale content). Full prev∪current rect is the correct bound.
* mark_overlapping runs with the SAME union rect since that's
* what actually gets wiped — using just the prev rect under-
* flagged neighboring sprites (e.g. ones adjacent on the side
* the sprite is moving toward) and left visible artifacts.
*
* left = min(prev_xpos, xpos)
 ldy #34
 lda (info_ptr),y     ; prev_xpos
 ldy #2
 cmp (info_ptr),y
 bcc :left_prev
 lda (info_ptr),y
 bra :left_set
:left_prev
 ldy #34
 lda (info_ptr),y
:left_set
 sta IMAGE01_XPOS
* right = max(prev_xpos + prev_frame_x, xpos + frame_x)
 ldy #34
 lda (info_ptr),y
 ldy #36
 clc
 adc (info_ptr),y
 sta :ea_tmp
 ldy #2
 lda (info_ptr),y
 ldy #10
 clc
 adc (info_ptr),y
 cmp :ea_tmp
 bcc :rkeep
 sta :ea_tmp
:rkeep
 lda :ea_tmp
 sec
 sbc IMAGE01_XPOS
 sta FRAME_X
* top = min(prev_ypos, ypos)
 ldy #32
 lda (info_ptr),y
 ldy #0
 cmp (info_ptr),y
 bcc :top_prev
 lda (info_ptr),y
 bra :top_set
:top_prev
 ldy #32
 lda (info_ptr),y
:top_set
 sta IMAGE01_YPOS
* bottom = max(prev_ypos + prev_frame_y, ypos + frame_y)
 ldy #32
 lda (info_ptr),y
 ldy #38
 clc
 adc (info_ptr),y
 sta :ea_tmp
 ldy #0
 lda (info_ptr),y
 ldy #12
 clc
 adc (info_ptr),y
 cmp :ea_tmp
 bcc :bkeep
 sta :ea_tmp
:bkeep
 lda :ea_tmp
 sec
 sbc IMAGE01_YPOS
 sta FRAME_Y
* DEBUG: log erase rect ONLY if the erase bottom reaches y=180+
* (where the HUD lives). This filters out normal gameplay erases.
 lda IMAGE01_YPOS
 clc
 adc FRAME_Y
 cmp #180
 bcc :skip_er_debug
 lda #$C5              ; 'E'
 jsr dbg_print_char
 lda #$D2              ; 'R'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda IMAGE01_YPOS
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda IMAGE01_XPOS
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda FRAME_X
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda FRAME_Y
 jsr dbg_print_hex8
 jsr dbg_print_nl
:skip_er_debug
 jsr mark_overlapping    ; flag other sprites whose prev drawn rect
                          ; intersects the union we're about to erase
 jsr erase
* Sync prev_* to current_* so subsequent frames' union erases don't
* compound stale prev values. The erase above just cleaned up the
* old-rect region based on prev, and draw_all will repaint at current.
* Without this, a :normal_end unbump that deliberately sets
* prev_ypos=bumped for one frame's erase leaks forward: a later
* save_anim_state updates prev_frame_y=40 but leaves prev_ypos at
* the bumped value, producing a union 64 rows tall that reaches
* into the HUD at y=180+.
 ldy #0
 lda (info_ptr),y
 ldy #32
 sta (info_ptr),y     ; prev_ypos <- current ypos
 ldy #2
 lda (info_ptr),y
 ldy #34
 sta (info_ptr),y     ; prev_xpos <- current xpos
 ldy #10
 lda (info_ptr),y
 ldy #36
 sta (info_ptr),y     ; prev_frame_x <- current frame_x
 ldy #12
 lda (info_ptr),y
 ldy #38
 sta (info_ptr),y     ; prev_frame_y <- current frame_y
* Clear bit 1 (needs_erase), set bit 0 (needs_draw) so sprite is redrawn
 ldy #30
 lda (info_ptr),y
 and #$FD             ; clear bit 1
 ora #$01             ; set bit 0
 sta (info_ptr),y
:skip_erase
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :jloop
 inc spr_ptr+1
:jloop jmp :loop
:done rts

:ea_tmp dfb 0

*----------------------------------------------------------
* draw_all - Iterate sprite_table, load each sprite, draw.
*----------------------------------------------------------
draw_all
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:loop jsr load_sprite
 bcs :done
* Draw if bit 0 set (needs_draw)
 ldy #30
 lda (info_ptr),y
 and #$01
 beq :skip_draw
* Dispatch: compiled (AND/ORA) path when MASK_ADDR != 0 and the
* sprite is the keyboard player (Billy). MASK_ADDR is the live
* signal "current FRAME_ADDR points at compiled DATA"; advance_walk
* and :anim_done idle-restore set it, while start_anim and
* advance_climb clear it (their frames are uncompiled, must go
* through legacy). NPCs always use legacy (controller != 1).
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :da_legacy
 lda MASK_ADDR
 ora MASK_ADDR+1
 beq :da_legacy
 jsr draw_sprite_compiled
 bra :da_drawn
:da_legacy
 jsr draw_sprite
:da_drawn
* Clear bit 0 (needs_draw)
 ldy #30
 lda (info_ptr),y
 and #$FE
 sta (info_ptr),y
:skip_draw
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :loop
 inc spr_ptr+1
 bra :loop
:done rts

*----------------------------------------------------------
* load_sprite - Load sprite info from the table entry at
* spr_ptr into globals. Sets info_ptr. Carry set = end.
*----------------------------------------------------------
load_sprite
 ldy #0
 lda (spr_ptr),y
 sta info_ptr
 iny
 lda (spr_ptr),y
 sta info_ptr+1
 ora info_ptr
 beq :null

 ldy #0
 lda (info_ptr),y     ; +0 ypos
 sta IMAGE01_YPOS
 ldy #2
 lda (info_ptr),y     ; +2 xpos
 sta IMAGE01_XPOS
 ldy #4
 lda (info_ptr),y     ; +4 mirror
 sta IMAGE01_MIRROR
 ldy #10
 lda (info_ptr),y     ; +10 frame_x
 sta FRAME_X
 ldy #12
 lda (info_ptr),y     ; +12 frame_y
 sta FRAME_Y
 ldy #14
 lda (info_ptr),y     ; +14 frame_addr low
 sta FRAME_ADDR
 iny
 lda (info_ptr),y     ; +15 frame_addr high
 sta FRAME_ADDR+1
 ldy #16
 lda (info_ptr),y     ; +16 mask
 sta MASK
 ldy #18
 lda (info_ptr),y     ; +18 maskhi
 sta MASKHI
 ldy #20
 lda (info_ptr),y     ; +20 masklo
 sta MASKLO
 ldy #52
 lda (info_ptr),y     ; +52 mask_addr low (compiled-pipeline mask;
                      ;     for NPC slots this is walk_anim — dispatch
                      ;     in draw_all gates on controller==1, so this
                      ;     value is harmless when the legacy path runs)
 sta MASK_ADDR
 iny
 lda (info_ptr),y
 sta MASK_ADDR+1
 clc
 rts
:null sec
 rts

*----------------------------------------------------------
* save_sprite - Save globals back to sprite info block.
* info_ptr must already be set (by load_sprite).
*----------------------------------------------------------
save_sprite
* Copy current block values to prev before overwriting
 ldy #0
 lda (info_ptr),y     ; current ypos
 ldy #32
 sta (info_ptr),y     ; -> prev_ypos
 ldy #2
 lda (info_ptr),y     ; current xpos
 ldy #34
 sta (info_ptr),y     ; -> prev_xpos
 ldy #10
 lda (info_ptr),y     ; current frame_x
 ldy #36
 sta (info_ptr),y     ; -> prev_frame_x
 ldy #12
 lda (info_ptr),y     ; current frame_y
 ldy #38
 sta (info_ptr),y     ; -> prev_frame_y
* Now write new values
 ldy #0
 lda IMAGE01_YPOS
 sta (info_ptr),y     ; +0 ypos
 ldy #2
 lda IMAGE01_XPOS
 sta (info_ptr),y     ; +2 xpos
 ldy #4
 lda IMAGE01_MIRROR
 sta (info_ptr),y     ; +4 mirror
 ldy #10
 lda FRAME_X
 sta (info_ptr),y     ; +10 frame_x
 ldy #12
 lda FRAME_Y
 sta (info_ptr),y     ; +12 frame_y
 ldy #14
 lda FRAME_ADDR
 sta (info_ptr),y     ; +14 frame_addr low
 iny
 lda FRAME_ADDR+1
 sta (info_ptr),y     ; +15 frame_addr high
* For Billy (keyboard player), also persist MASK_ADDR → +52 so
* load_sprite picks up the matching inverse-mask next frame. NPC
* slots use +52 as walk_anim, so we skip the write for them.
 ldy #22
 lda (info_ptr),y     ; +22 controller
 cmp #$01
 bne :ss_skip_mask
 ldy #52
 lda MASK_ADDR
 sta (info_ptr),y
 iny
 lda MASK_ADDR+1
 sta (info_ptr),y
:ss_skip_mask
* Mark sprite as dirty (bit0=needs_draw, bit1=needs_erase)
 ldy #30
 lda #$03
 sta (info_ptr),y
 rts

*----------------------------------------------------------
* save_anim_state - Save only frame-related fields back to
* sprite info block. Used by update_anims so we don't clobber
* prev_xpos/prev_ypos that NPC behaviors (fo_approach etc.)
* set before update_anims runs. Those behaviors write the new
* xpos/ypos directly into the block AFTER correctly snapshotting
* prev_*; if save_sprite runs here, it would re-snapshot prev
* from the now-modified block, copying the NEW position into
* prev and leaving last frame's position un-erased (artifacts).
* info_ptr must already be set (by load_sprite).
*----------------------------------------------------------
save_anim_state
* Snapshot prev_frame_x/prev_frame_y from current block fields
 ldy #10
 lda (info_ptr),y     ; current frame_x
 ldy #36
 sta (info_ptr),y     ; -> prev_frame_x
 ldy #12
 lda (info_ptr),y     ; current frame_y
 ldy #38
 sta (info_ptr),y     ; -> prev_frame_y
* Write new frame values from globals
 ldy #10
 lda FRAME_X
 sta (info_ptr),y
 ldy #12
 lda FRAME_Y
 sta (info_ptr),y
 ldy #14
 lda FRAME_ADDR
 sta (info_ptr),y
 iny
 lda FRAME_ADDR+1
 sta (info_ptr),y
* Persist MASK_ADDR → +52 for Billy only (see save_sprite note).
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :sas_skip_mask
 ldy #52
 lda MASK_ADDR
 sta (info_ptr),y
 iny
 lda MASK_ADDR+1
 sta (info_ptr),y
:sas_skip_mask
* Mark dirty (bit0=needs_draw, bit1=needs_erase)
 ldy #30
 lda #$03
 sta (info_ptr),y
 rts

spr_ptr = $E0         ; ZP pointer into sprite_table
info_ptr = $E2        ; ZP pointer to current sprite info block
anim_ptr = $E4        ; ZP pointer to animation descriptor (3 bytes: addr + bank at $E6)
script_pc = $EA       ; 3-byte ZP pointer to current level script position (bank $02)

* Level script opcodes (must match mission1.s definitions)
OP_NONE     = 0
OP_SCREEN   = 1
OP_WAITX    = 2
OP_NPC      = 3
OP_RIGHT    = 4
OP_LEFT     = 5
OP_UP       = 6
OP_DOWN     = 7
OP_SCRLOCK  = 8
OP_END      = 9
OP_WAITY    = 10
OP_WAITCLR  = 11
OP_WAITNPC  = 12
OP_WAITXREV = 13      ; wait for player X to descend to <= threshold
OP_SCRMIN   = 14      ; set minimum world_offset (left-scroll clamp)
OP_SCRMAX   = 15      ; set maximum world_offset (right-scroll clamp)
OP_SNAPSTATE = 16     ; restore engine to a recorded "golden" state.
                      ; 17-byte inline payload: wo(2), abs_x(2),
                      ; xpos(1), current_screen(1), scroll_src_bank(1),
                      ; scroll_src_off(1), scroll_lsrc_bank(1),
                      ; scroll_lsrc_off(1), scroll_up_anchor(2),
                      ; scroll_up_off(1), scroll_min_wo(2), scroll_max_wo(2).
OP_SNAPSTATE_DEFER = 17 ; like OP_SNAPSTATE but applied at next
                      ; scroll_up call (= after climb has begun).
                      ; Payload extends to 25 bytes: 17 bytes of
                      ; engine state, then 8 bytes of repaint config
                      ; (two regions of 4 bytes each):
                      ;   db bank, db byte, db count, db dst (region 1)
                      ;   db bank, db byte, db count, db dst (region 2)
                      ; Engine repaints 183 rows from bank/byte+row*$A0
                      ; to $18/(dst + row*$A0). Bank=0 skips that region.

* Script interpreter state
SCRIPT_RUN  = 0       ; executing opcodes
SCRIPT_WAITX = 1      ; waiting for player X threshold
SCRIPT_WAITY = 2      ; waiting for player Y threshold
SCRIPT_WAITCLR = 3    ; waiting for all NPCs defeated
SCRIPT_DONE = 4       ; level ended
SCRIPT_WAITNPC = 5    ; waiting for NPC count <= threshold
SCRIPT_WAITUP  = 6    ; waiting for vertical scroll to complete
SCRIPT_WAITXREV = 7   ; waiting for abs_x <= threshold

* NPC behaviors (must match mission1.s definitions)
BEHAV_NONE    = 0
BEHAV_FACEOFF = 1
BEHAV_FLANK   = 2
BEHAV_LURK    = 3
BEHAV_LADDER  = 4

* Ladder sub-states (stored at info_block+7)
LD_INIT      = 0      ; first frame: snap to ladder top
LD_DESCEND   = 1      ; climbing down

* Face-off sub-states (stored at info_block+7)
FO_APPROACH = 0       ; walking toward player
FO_PUNCH    = 1       ; throwing a punch
FO_COOLDOWN = 2       ; waiting after punch

* Flank sub-states (stored at info_block+7)
FL_ARC      = 0       ; arc to a corner behind player
FL_CLOSE    = 1       ; close in to back-side punch range
FL_PUNCH    = 2       ; throw a punch
FL_COOLDOWN = 3       ; waiting after punch

*----------------------------------------------------------
* process_input - Read keyboard, update Billy's state.
* If an action animation is playing, ignore all input.
*----------------------------------------------------------
process_input
* Find the keyboard-controlled sprite (controller = $01)
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:find_player
 jsr load_sprite
 bcs :no_key           ; end of table, no player found
 ldy #22
 lda (info_ptr),y      ; controller
 cmp #$01
 beq :found_player
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :find_player
 inc spr_ptr+1
 bra :find_player
:found_player
* Check if action animation is active (block input)
 ldy #24
 lda (info_ptr),y     ; anim_ptr low
 sta anim_ptr
 iny
 lda (info_ptr),y     ; anim_ptr high
 sta anim_ptr+1
 ora anim_ptr
 beq :accept_input    ; no animation, accept input
* Animation active — is it walk? (walk = ok to interrupt)
 lda anim_ptr
 cmp #<anim_walk
 bne :blocked
 lda anim_ptr+1
 cmp #>anim_walk
 beq :accept_input    ; walk animation, allow input
:blocked rts           ; action animation, block all input

:accept_input
 bit $c000
 bmi :has_key
:no_key rts

:has_key
 lda $c010
 and #$7f
 cmp #'r'
 bne :not_scroll
 jsr save_sprite
 jsr scroll_right
 jsr load_sprite
 jsr sync_current_screen
* world_offset += 4 (4 bytes scrolled into the world)
 lda world_offset
 clc
 adc #4
 sta world_offset
 lda world_offset+1
 adc #0
 sta world_offset+1
* Player advanced 4 bytes through the world
 lda abs_x
 clc
 adc #4
 sta abs_x
 lda abs_x+1
 adc #0
 sta abs_x+1
 rts
:not_scroll
 cmp #'8'
 beq :do_up
 cmp #'g'
 bne :ns_not_g
* Golden state capture: prints a 3-line snapshot of all state
* relevant to ladder alignment & drift detection. Press the
* 'g' key just below a ladder (pre-climb) and again just above
* it (post-climb) to record before/after state. Comparing
* across plays surfaces drift; comparing before-vs-after across
* a single climb characterizes what the climb commits.
 jsr dbg_golden_state
 rts
:ns_not_g
 cmp #' '
 bne :ns_not_space
* Debug: print abs_x and Billy's world-byte x (world_offset+xpos).
 lda #$D8              ; 'X' (high bit set for text screen)
 jsr dbg_print_char
 lda #$BA              ; ':'
 jsr dbg_print_char
 lda abs_x+1
 jsr dbg_print_hex8
 lda abs_x
 jsr dbg_print_hex8
 lda #$A0              ; ' '
 jsr dbg_print_char
 lda #$D7              ; 'W'
 jsr dbg_print_char
 lda #$BA              ; ':'
 jsr dbg_print_char
* world_x = world_offset + IMAGE01_XPOS (both bytes)
 lda IMAGE01_XPOS
 clc
 adc world_offset
 sta :dbg_wx
 lda #0
 adc world_offset+1
 jsr dbg_print_hex8
 lda :dbg_wx
 jsr dbg_print_hex8
 jsr dbg_print_nl
 rts
:dbg_wx dfb 0
:ns_not_space
 jmp :not_up              ; inverted — :not_up moved out of range
:do_up
* If scroll_up enabled AND on a ladder AND near top, scroll up.
* Inverted branches + jmp because :up_walk moved out of 8-bit range
* when the ladder-center snap code was added below.
 lda scroll_up_enabled
 bne :do_up_enabled
 jmp :up_walk
:do_up_enabled
 lda IMAGE01_YPOS
 cmp #UP_SCROLL_THRESH
 bcc :do_up_under_thresh
 jmp :up_walk
:do_up_under_thresh
* Check if player is on a ladder
 lda IMAGE01_XPOS
 sta chk_xpos
 lda IMAGE01_YPOS
 jsr check_ladder
 bcc :do_up_on_ladder   ; on ladder — continue
 jmp :up_walk           ; not on ladder — normal walk
:do_up_on_ladder
* DEBUG: 'US' = up-scroll fired at current ypos
 lda #$D5              ; 'U'
 jsr dbg_print_char
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda IMAGE01_YPOS
 jsr dbg_print_hex8
 jsr dbg_print_nl
* Snap to ladder center for any climb. Scans ladder_buf for the
* ladder Billy's currently on, computes its world-x center, and
* pins world_offset = scroll_up_anchor while setting IMAGE01_XPOS
* = center - anchor. This guarantees Billy always lands on the
* ladder's horizontal midpoint regardless of approach, making
* every climb visually consistent.
* Idempotent: subsequent climb frames reach the same values.
 lda ladder_count
 bne :sn_have_ladders
 jmp :sn_done
:sn_have_ladders
 sta :sn_cnt
 clc
 lda IMAGE01_XPOS
 adc world_offset
 sta :sn_wx
 lda #0
 adc world_offset+1
 sta :sn_wx+1
 ldx #0
:sn_scan
 bra :sn_scan_body
:sn_next_tramp
 jmp :sn_next
:sn_scan_body
 lda :sn_wx+1
 cmp ladder_buf+1,x
 bcc :sn_next_tramp
 bne :sn_ge_lf
 lda :sn_wx
 cmp ladder_buf,x
 bcc :sn_next_tramp
:sn_ge_lf
 lda ladder_buf+3,x
 cmp :sn_wx+1
 bcc :sn_next_tramp
 bne :sn_le_rt
 lda ladder_buf+2,x
 cmp :sn_wx
 bcc :sn_next_tramp
:sn_le_rt
* Found the ladder. Compute center = (x_left + x_right) / 2.
 clc
 lda ladder_buf,x
 adc ladder_buf+2,x
 sta :sn_ctr
 lda ladder_buf+1,x
 adc ladder_buf+3,x
 sta :sn_ctr+1
 lsr :sn_ctr+1
 ror :sn_ctr
* Always center Billy on the ladder: xpos = center - world_offset
* - 3. The -3 shifts Billy's 8-byte-wide sprite left so its visual
* midpoint lands on the ladder center instead of its left edge.
* world_offset stays at its current (approach-dependent) value,
* so the teleport is at most half the ladder width. For scr12
* climbs, the ladder data is now centered at world 369 to match
* scr12's visible art at byte 95, so the snap aligns Billy with
* the climb-time ladder rendering.
 lda :sn_ctr
 sec
 sbc world_offset
 sec
 sbc #3
 sta IMAGE01_XPOS
 ldy #2
 sta (info_ptr),y
* scr12 (ladder3) nudge: -5 to xpos to land Billy on scr9's
* visible ladder art. Snap formula gives 28; -5 brings it to 23.
 lda scroll_up_screen
 cmp #12
 bne :sn_no_scr12_inc
 lda IMAGE01_XPOS
 sec
 sbc #5
 sta IMAGE01_XPOS
 ldy #2
 sta (info_ptr),y
:sn_no_scr12_inc
* Narrow-target override: the incremental pin now uses anchor
* (no +N), so scr12 renders at playfield[0..51] during climb and
* post-snap alike. Billy's xpos formula collapses to:
*   xpos = ladder_center - anchor - 4
*        = scr12_byte_of_ladder_center - sprite_half (BCLIMB=8)
* Same form as post-snap (which uses sprite_half=4 too). Delta
* math below still updates abs_x correctly so the invariant
* holds. Engine wo_actual differs from the renderer's view by
* (wo_actual - anchor) bytes — LADDER_TOL is widened to absorb
* that offset so check_ladder collision still fires.
 lda scroll_up_twidth
 cmp #52
 bne :sn_post_snap
 sec
 lda :sn_ctr
 sbc scroll_up_anchor
 sec
 sbc #4
 sta IMAGE01_XPOS
 ldy #2
 sta (info_ptr),y
:sn_post_snap
* Update abs_x to reflect the world_x change from the snap so it
* stays deterministic. delta = new_world_x - old_world_x
* (:sn_wx was saved at scan start). 2's-complement subtract and
* 16-bit add; abs_x tracks the signed delta correctly.
 clc
 lda IMAGE01_XPOS
 adc world_offset
 sta :sn_new_wx
 lda #0
 adc world_offset+1
 sta :sn_new_wx+1
 sec
 lda :sn_new_wx
 sbc :sn_wx
 sta :sn_new_wx
 lda :sn_new_wx+1
 sbc :sn_wx+1
 sta :sn_new_wx+1
 clc
 lda abs_x
 adc :sn_new_wx
 sta abs_x
 lda abs_x+1
 adc :sn_new_wx+1
 sta abs_x+1
 bra :sn_done
:sn_next
 txa
 clc
 adc #6
 tax
 dec :sn_cnt
 beq :sn_done
 jmp :sn_scan
:sn_done
* Scroll world up by 4 rows with climbing animation
 jsr advance_climb
 jsr save_sprite
 jsr scroll_up
 jsr load_sprite
 rts
:sn_wx     ds 2
:sn_cnt    dfb 0
:sn_ctr    ds 2
:sn_new_wx ds 2
:up_walk
 lda IMAGE01_XPOS
 sta chk_xpos
 lda IMAGE01_YPOS
 sec
 sbc #1               ; proposed Y
 jsr check_y_bounds
 bcs :up_blocked_bounds
* If this upward step is only permitted by the ladder (proposed
* row is blocked but falls within ladder Y range), also require
* scroll_up to be enabled. Otherwise Billy would "climb" off the
* top of a walkable surface via phantom ladder rows when there's
* no screen above to scroll to.
 lda via_ladder
 beq :up_do_move
 lda scroll_up_enabled
 beq :up_blocked_ladder
:up_do_move
* DEBUG: 'UC' = via-ladder climb allowed; 'UW' = normal walk up
 pha
 lda via_ladder
 beq :up_dbg_walk
 lda #$D5              ; 'U'
 jsr dbg_print_char
 lda #$C3              ; 'C'
 jsr dbg_print_char
 bra :up_dbg_tail
:up_dbg_walk
 lda #$D5              ; 'U'
 jsr dbg_print_char
 lda #$D7              ; 'W'
 jsr dbg_print_char
:up_dbg_tail
 lda #$A0
 jsr dbg_print_char
 lda IMAGE01_YPOS
 jsr dbg_print_hex8
 jsr dbg_print_nl
 pla
 dec IMAGE01_YPOS
 lda via_ladder
 beq :up_walkframe
 jsr advance_climb
 bra :up_after_anim
:up_walkframe
 jsr advance_walk        ; vertical walk — cycle walk frames
:up_after_anim
 jsr save_sprite
 jsr resort_sprite_table
 rts
:up_blocked_bounds
* DEBUG: 'UX' = climb blocked by bounds (and not on ladder)
 lda #$D5
 jsr dbg_print_char
 lda #$D8              ; 'X'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda IMAGE01_YPOS
 jsr dbg_print_hex8
 jsr dbg_print_nl
:skip_up rts
:up_blocked_ladder
* DEBUG: 'UL' = climb on ladder but scroll_up disabled
 lda #$D5
 jsr dbg_print_char
 lda #$CC              ; 'L'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda IMAGE01_YPOS
 jsr dbg_print_hex8
 jsr dbg_print_nl
 rts
:not_up cmp #'2'
 bne :not_down
 lda IMAGE01_XPOS
 sta chk_xpos
 lda IMAGE01_YPOS
 clc
 adc #1               ; proposed Y
 jsr check_y_bounds
 bcs :skip_down       ; blocked
 inc IMAGE01_YPOS
 lda via_ladder
 beq :down_walkframe
 jsr advance_climb
 bra :down_after_anim
:down_walkframe
 jsr advance_walk       ; vertical walk — cycle walk frames
:down_after_anim
 jsr save_sprite
 jsr resort_sprite_table
:skip_down rts
:not_down cmp #'4'
 beq :do_left          ; '4' → handle left below
 jmp :not_left         ; far jump (out of branch range after walk_x bounds added)
:do_left
* If at left scroll threshold AND scroll_left enabled AND
* there's a screen to the left, scroll. Otherwise walk.
 lda scroll_left_enabled
 beq :left_walk
 lda current_screen
 beq :left_walk        ; on screen 0, no left source
 lda IMAGE01_XPOS
 cmp #LEFT_SCROLL_THRESH
 bcs :left_walk        ; xpos > threshold, walk
* Script clamp: reject scroll when wo-4 would fall below
* scroll_min_wo. 16-bit compare: (wo - 4) vs scroll_min_wo.
 lda world_offset
 sec
 sbc #4
 tax                   ; low byte of (wo-4) in X
 lda world_offset+1
 sbc #0                ; high byte of (wo-4) in A
 cmp scroll_min_wo+1
 bcc :left_walk        ; (wo-4) < min → walk instead
 bne :left_scroll_ok   ; (wo-4) high > min high → scroll ok
 cpx scroll_min_wo
 bcc :left_walk        ; (wo-4) low < min low → walk
:left_scroll_ok
* Scroll world LEFT by 4 bytes
 jsr save_sprite
 jsr scroll_left
 jsr load_sprite
 jsr sync_current_screen_left
* abs_x retreats by 4 bytes — matches world_offset -= 4 so abs_x
* represents the player's cumulative byte-displacement through
* the world (1 per walk press, 4 per scroll, 1 per VBL of jump).
 lda abs_x
 sec
 sbc #4
 sta abs_x
 lda abs_x+1
 sbc #0
 sta abs_x+1
* world_offset retreats by 4 bytes
 lda world_offset
 sec
 sbc #4
 sta world_offset
 lda world_offset+1
 sbc #0
 sta world_offset+1
 bra :finish_left
:left_walk
 lda IMAGE01_XPOS
 cmp #2
 bcc :skip_left        ; already at minimum (1)
 sec
 sbc #1                ; proposed new xpos
 jsr check_x_bounds
 bcs :skip_left        ; bounds at current Y_top reject this X
 dec IMAGE01_XPOS
* Decrement absolute X (16-bit)
 lda abs_x
 bne :dec_lo
 dec abs_x+1
:dec_lo
 dec abs_x
:skip_left
:finish_left
 lda #$01
 sta IMAGE01_MIRROR
 jsr advance_walk
 jsr save_sprite
 rts
:not_left cmp #'6'
 bne :not_jump
* If at scroll threshold AND scrolling enabled, scroll world.
* If scroll disabled, walk normally up to the playfield edge.
 lda scroll_right_enabled
 beq :walk_right       ; scroll disabled — walk to edge
 lda IMAGE01_XPOS
 cmp #SCROLL_THRESH
 bcc :walk_right       ; xpos < threshold, walk
* Script clamp: reject scroll when wo+4 would exceed scroll_max_wo.
* 16-bit compare: scroll_max_wo vs (wo + 4).
 lda world_offset
 clc
 adc #4
 tax                   ; low byte of (wo+4) in X
 lda world_offset+1
 adc #0                ; high byte of (wo+4) in A
 cmp scroll_max_wo+1
 bcc :right_scroll_ok  ; (wo+4) high < max high → scroll ok
 bne :walk_right       ; (wo+4) high > max → walk
 cpx scroll_max_wo
 bcc :right_scroll_ok  ; (wo+4) low < max low → ok
 beq :right_scroll_ok  ; equal → ok (reaching exactly max)
 bcs :walk_right       ; (wo+4) low > max low → walk
:right_scroll_ok
* Scroll world right by 4 bytes (8 pixels = 2 words)
 jsr save_sprite
 jsr scroll_right
 jsr load_sprite
 jsr sync_current_screen
* world_offset += 4 (4 bytes scrolled into the world)
 lda world_offset
 clc
 adc #4
 sta world_offset
 lda world_offset+1
 adc #0
 sta world_offset+1
* abs_x advances by 4 bytes — matches world_offset += 4 so abs_x
* represents the player's cumulative byte-displacement through
* the world (1 per walk press, 4 per scroll, 1 per VBL of jump).
 lda abs_x
 clc
 adc #4
 sta abs_x
 lda abs_x+1
 adc #0
 sta abs_x+1
 bra :finish_right
:walk_right
 lda IMAGE01_XPOS
 cmp #PLAYER_MAX_X
 bcs :clamp_right      ; at right edge of playfield
 clc
 adc #1                ; proposed new xpos
 jsr check_x_bounds
 bcs :clamp_right      ; bounds at current Y_top reject this X
 inc IMAGE01_XPOS
 inc abs_x
 bne :finish_right
 inc abs_x+1
 bra :finish_right
:clamp_right
* At edge — just face right, no movement
:finish_right
 stz IMAGE01_MIRROR
 jsr advance_walk
 jsr save_sprite
 rts
:not_jump cmp #'j'
 bne :not_kick
 lda #<anim_jump
 ldx #>anim_jump
 jsr start_anim
 rts
:not_kick cmp #'k'
 bne :not_punch
 lda #<anim_kick
 ldx #>anim_kick
 jsr start_anim
 rts
:not_punch cmp #'p'
 bne :not_invuln
* Alternate between punch1 and punch2 each press
 lda punch_toggle
 eor #$01
 sta punch_toggle
 bne :use_punch2
 lda #<anim_punch1
 ldx #>anim_punch1
 jsr start_anim
 rts
:use_punch2
 lda #<anim_punch2
 ldx #>anim_punch2
 jsr start_anim
 rts
:not_invuln cmp #'i'
 bne :no_key2
* Toggle invincibility
 lda god_mode
 eor #$01
 sta god_mode
 beq :god_off
 lda #$0F              ; white border = invincible
 bra :god_set
:god_off
 lda #$00              ; black border = normal
:god_set
 stal $E0C034
:no_key2 rts

*----------------------------------------------------------
* advance_walk - Advance one walk frame. Cycles through
* IMAGE01 -> IMAGE02 -> IMAGE03 -> IMAGE02 -> repeat.
* Does not use the animation system — just sets the globals.
*----------------------------------------------------------
advance_walk
* Only change animation frame every 2nd call
 lda walk_toggle
 eor #$01
 sta walk_toggle
 beq :do_advance       ; toggle hit 0, advance frame
 rts                   ; odd call, skip frame change
:do_advance
 inc walk_step
 lda walk_step
 cmp #4
 bcc :ok
 stz walk_step
 lda #0
:ok tax
 lda walk_x_tbl,x
 sta FRAME_X
 lda walk_y_tbl,x
 sta FRAME_Y
 txa
 asl
 tax
* Pick data + mask table pair based on Billy's mirror flag.
* walk_addr_tbl/walk_mask_tbl  for forward (mirror=0).
* walk_addr_tbl_mirror/walk_mask_tbl_mirror for left-facing (mirror=1).
 lda IMAGE01_MIRROR
 bne :aw_mirror
 lda walk_addr_tbl,x
 sta FRAME_ADDR
 lda walk_addr_tbl+1,x
 sta FRAME_ADDR+1
 lda walk_mask_tbl,x
 sta MASK_ADDR
 lda walk_mask_tbl+1,x
 sta MASK_ADDR+1
 rts
:aw_mirror
 lda walk_addr_tbl_mirror,x
 sta FRAME_ADDR
 lda walk_addr_tbl_mirror+1,x
 sta FRAME_ADDR+1
 lda walk_mask_tbl_mirror,x
 sta MASK_ADDR
 lda walk_mask_tbl_mirror+1,x
 sta MASK_ADDR+1
 rts

walk_step dfb 0
walk_toggle dfb 0

*----------------------------------------------------------
* advance_climb - Set climbing frame (BCLIMB1/BCLIMB2),
* alternating each call. Sets FRAME_X/Y/ADDR globals.
*----------------------------------------------------------
advance_climb
 lda climb_toggle
 eor #$01
 sta climb_toggle
 lda #$08              ; BCLIMB1/2 width
 sta FRAME_X
 lda #$28              ; height
 sta FRAME_Y
* Pick BCLIMB1 vs BCLIMB2 (toggle), then non-mirror vs mirror data
* + mask pair from IMAGE01_MIRROR. Compiled pipeline — both data
* and mask pointers must be set in lockstep so dispatch in draw_all
* routes to draw_sprite_compiled with matching arrays.
 lda climb_toggle
 beq :use_b1
* BCLIMB2 branch
 lda IMAGE01_MIRROR
 bne :ac_b2_mirror
 lda spr_bclimb2
 sta FRAME_ADDR
 lda spr_bclimb2+1
 sta FRAME_ADDR+1
 lda spr_bclimb2_mask
 sta MASK_ADDR
 lda spr_bclimb2_mask+1
 sta MASK_ADDR+1
 rts
:ac_b2_mirror
 lda spr_bclimb2_data_mirror
 sta FRAME_ADDR
 lda spr_bclimb2_data_mirror+1
 sta FRAME_ADDR+1
 lda spr_bclimb2_mask_mirror
 sta MASK_ADDR
 lda spr_bclimb2_mask_mirror+1
 sta MASK_ADDR+1
 rts
:use_b1
* BCLIMB1 branch
 lda IMAGE01_MIRROR
 bne :ac_b1_mirror
 lda spr_bclimb1
 sta FRAME_ADDR
 lda spr_bclimb1+1
 sta FRAME_ADDR+1
 lda spr_bclimb1_mask
 sta MASK_ADDR
 lda spr_bclimb1_mask+1
 sta MASK_ADDR+1
 rts
:ac_b1_mirror
 lda spr_bclimb1_data_mirror
 sta FRAME_ADDR
 lda spr_bclimb1_data_mirror+1
 sta FRAME_ADDR+1
 lda spr_bclimb1_mask_mirror
 sta MASK_ADDR
 lda spr_bclimb1_mask_mirror+1
 sta MASK_ADDR+1
 rts
climb_toggle dfb 0

walk_x_tbl dfb $09,$08,$0B,$08
walk_y_tbl dfb $28,$28,$28,$28
walk_addr_tbl        ds 8  ; patched by init_level (IMAGE01,IMAGE02,IMAGE03,IMAGE02)
walk_mask_tbl        ds 8  ; companion mask addresses (compiled pipeline)
walk_addr_tbl_mirror ds 8  ; mirror-baked data addresses
walk_mask_tbl_mirror ds 8  ; mirror-baked mask addresses

*----------------------------------------------------------
* resort_sprite_table - Rebuild sprite_table sorted by ypos.
* info_ptr must point to the sprite that just moved.
* Iterates sprite_table, skips self, insertion-sorts self
* into sprite_table_copy by ypos (lowest first), then
* copies sprite_table_copy back to sprite_table.
*----------------------------------------------------------
sort_src = $E6        ; ZP: read pointer into sprite_table
sort_dst = $E8        ; ZP: write pointer into sprite_table_copy

resort_sprite_table
* Save our sprite's pointer (info_ptr low/high)
 lda info_ptr
 sta :our_ptr
 lda info_ptr+1
 sta :our_ptr+1
* Get our ypos
 ldy #0
 lda (info_ptr),y
 sta :our_y

* Init src = sprite_table, dst = sprite_table_copy
 lda #<sprite_table
 sta sort_src
 lda #>sprite_table
 sta sort_src+1
 lda #<sprite_table_copy
 sta sort_dst
 lda #>sprite_table_copy
 sta sort_dst+1
 lda #0
 sta :inserted         ; flag: have we inserted ourselves yet?

:loop
* Read next entry from sprite_table
 ldy #0
 lda (sort_src),y
 sta :cur_lo
 iny
 lda (sort_src),y
 sta :cur_hi
* Check for null terminator
 ora :cur_lo
 beq :end_of_table

* Skip our own entry
 lda :cur_lo
 cmp :our_ptr
 bne :not_self
 lda :cur_hi
 cmp :our_ptr+1
 beq :skip_self
:not_self

* Get this sprite's ypos
 lda :cur_lo
 sta info_ptr
 lda :cur_hi
 sta info_ptr+1
 ldy #0
 lda (info_ptr),y     ; other sprite's ypos

* If other ypos > our ypos AND we haven't been inserted yet,
* insert ourselves first
 cmp :our_y
 bcc :copy_other       ; other < ours, copy other first
 beq :copy_other       ; other == ours, copy other first
* Other > ours — insert ourselves if not already done
 lda :inserted
 bne :copy_other       ; already inserted
* Insert our pointer
 ldy #0
 lda :our_ptr
 sta (sort_dst),y
 iny
 lda :our_ptr+1
 sta (sort_dst),y
 lda #1
 sta :inserted
* Advance dst
 lda sort_dst
 clc
 adc #2
 sta sort_dst
 bcc :copy_other
 inc sort_dst+1

:copy_other
* Copy current entry to dst
 ldy #0
 lda :cur_lo
 sta (sort_dst),y
 iny
 lda :cur_hi
 sta (sort_dst),y
* Advance dst
 lda sort_dst
 clc
 adc #2
 sta sort_dst
 bcc :skip_self
 inc sort_dst+1

:skip_self
* Advance src
 lda sort_src
 clc
 adc #2
 sta sort_src
 bcc :loop
 inc sort_src+1
 bra :loop

:end_of_table
* If we haven't inserted ourselves yet, do it now
 lda :inserted
 bne :write_term
 ldy #0
 lda :our_ptr
 sta (sort_dst),y
 iny
 lda :our_ptr+1
 sta (sort_dst),y
 lda sort_dst
 clc
 adc #2
 sta sort_dst
 bcc :write_term
 inc sort_dst+1
:write_term
* Write null terminator
 ldy #0
 lda #0
 sta (sort_dst),y
 iny
 sta (sort_dst),y

* Copy sprite_table_copy back to sprite_table
 lda #<sprite_table_copy
 sta sort_src
 lda #>sprite_table_copy
 sta sort_src+1
 lda #<sprite_table
 sta sort_dst
 lda #>sprite_table
 sta sort_dst+1
:copy_back
 ldy #0
 lda (sort_src),y
 sta (sort_dst),y
 iny
 lda (sort_src),y
 sta (sort_dst),y
* Check if we just copied the null terminator
 ora (sort_dst),y
 dey
 ora (sort_dst),y
 beq :resort_done
* Advance both
 lda sort_src
 clc
 adc #2
 sta sort_src
 bcc :cb2
 inc sort_src+1
:cb2 lda sort_dst
 clc
 adc #2
 sta sort_dst
 bcc :copy_back
 inc sort_dst+1
 bra :copy_back
:resort_done
* Restore info_ptr to our sprite
 lda :our_ptr
 sta info_ptr
 lda :our_ptr+1
 sta info_ptr+1
 rts

:our_ptr ds 2
:our_y dfb 0
:cur_lo dfb 0
:cur_hi dfb 0
:inserted dfb 0

*----------------------------------------------------------
* start_anim - Start animation. A=desc low, X=desc high.
* Sets anim_ptr, frame=0, loads first frame, sets timer.
* info_ptr must be set to current sprite block.
*----------------------------------------------------------
start_anim
 sta anim_ptr
 stx anim_ptr+1
 ldy #24
 sta (info_ptr),y     ; store anim_ptr low
 iny
 txa
 sta (info_ptr),y     ; store anim_ptr high
 ldy #26
 lda #0
 sta (info_ptr),y     ; anim_frame = 0
* Detect compiled-format flag (bit 7 of header flags byte at +2).
 ldy #2
 lda (anim_ptr),y
 and #$80
 bne :sa_compiled
* === Legacy 5-byte stride: frame 0 at +3..+7 ===
* Reached only by NPC animations (anim_wpunched, anim_wfall, etc.)
* — every Billy animation is compiled (flag bit 7 set). The Billy-
* specific MASK_ADDR clear that lived here in A1/A2.2 is now dead
* code and was removed in A3.
 ldy #3
 lda (anim_ptr),y     ; frame_x
 sta FRAME_X
 iny
 lda (anim_ptr),y     ; frame_y
 sta FRAME_Y
 iny
 lda (anim_ptr),y     ; duration
 ldy #28
 sta (info_ptr),y     ; anim_timer
 ldy #6               ; frame_addr low
 lda (anim_ptr),y
 sta FRAME_ADDR
 iny
 lda (anim_ptr),y
 sta FRAME_ADDR+1
 bra :sa_write_block

:sa_compiled
* === Compiled 11-byte stride: frame 0 at +3..+13 ===
* +3 frame_x, +4 frame_y, +5 duration, +6..+9 data+mask,
* +10..+13 dmir+mmir.
 ldy #3
 lda (anim_ptr),y     ; frame_x
 sta FRAME_X
 iny
 lda (anim_ptr),y     ; frame_y
 sta FRAME_Y
 iny
 lda (anim_ptr),y     ; duration
 ldy #28
 sta (info_ptr),y     ; anim_timer
 lda IMAGE01_MIRROR
 bne :sa_compiled_mirror
 ldy #6
 lda (anim_ptr),y     ; data low
 sta FRAME_ADDR
 iny
 lda (anim_ptr),y     ; data high
 sta FRAME_ADDR+1
 iny
 lda (anim_ptr),y     ; mask low
 sta MASK_ADDR
 iny
 lda (anim_ptr),y     ; mask high
 sta MASK_ADDR+1
 bra :sa_compiled_persist
:sa_compiled_mirror
 ldy #10              ; dmir_lo (past data + mask)
 lda (anim_ptr),y
 sta FRAME_ADDR
 iny
 lda (anim_ptr),y
 sta FRAME_ADDR+1
 iny
 lda (anim_ptr),y     ; mmir low
 sta MASK_ADDR
 iny
 lda (anim_ptr),y
 sta MASK_ADDR+1
:sa_compiled_persist
* For Billy: persist MASK_ADDR → info+52 so load_sprite picks it
* up next frame. NPCs would never run a compiled animation under
* the current model — but if one does, we'd corrupt walk_anim, so
* gate on controller==1.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :sa_write_block
 ldy #52
 lda MASK_ADDR
 sta (info_ptr),y
 iny
 lda MASK_ADDR+1
 sta (info_ptr),y

:sa_write_block
* Write FRAME_X/Y/ADDR back to block. DON'T snapshot prev_xpos/ypos
* — when check_punch_hit triggers this mid-frame on an NPC that
* fo_approach already moved, save_sprite would clobber the prev
* snapshot fo_approach took, and erase_all would erase at the (new)
* current position, leaving the old sprite drawn last frame un-
* erased. prev_frame_x/y stay at the last drawn frame's size, which
* the union erase in erase_all accounts for.
 ldy #10
 lda FRAME_X
 sta (info_ptr),y
 ldy #12
 lda FRAME_Y
 sta (info_ptr),y
 ldy #14
 lda FRAME_ADDR
 sta (info_ptr),y
 iny
 lda FRAME_ADDR+1
 sta (info_ptr),y
 ldy #30
 lda #$03
 sta (info_ptr),y
 rts

* Fallen-pose vertical offset. The frame 1 ("fallen") pose of
* the enemy fall animations is much shorter than their standing
* pose, so drawn at the same ypos the body appears up where the
* head used to be. We bump ypos by this amount on entry to the
* fallen frame and un-bump on animation end / death.
FALL_Y_OFFSET = 24

*----------------------------------------------------------
* update_anims - Iterate sprite_table, advance animation
* timers, update frames.
*----------------------------------------------------------
update_anims
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:loop jsr load_sprite
 bcc :active
 jmp :done
:active
* Check if animation is active
 ldy #24
 lda (info_ptr),y
 sta anim_ptr
 iny
 lda (info_ptr),y
 sta anim_ptr+1
 ora anim_ptr
 bne :has_anim
 jmp :next            ; no animation, skip
:has_anim
* Check flags bit 0: advance position per VBL
 ldy #2
 lda (anim_ptr),y     ; flags
 and #$01
 beq :no_advance
* Snapshot current xpos/ypos/frame_x/frame_y into prev_* BEFORE
* modifying xpos. Without this, each VBL the advance-position
* code clobbers xpos but leaves prev_xpos stale at the pre-
* animation value, so the NEXT frame's erase_all erases at the
* wrong spot (typically a no-op on clean background) and the
* previous frame's drawing stays on screen as an artifact trail.
* This mirrors what save_sprite does for walk: walk goes through
* save_sprite inside process_input, which snapshots prev from
* the old block values before writing new ones. The position-
* advance path here bypasses save_sprite entirely, so it has to
* do the snapshot itself.
 ldy #2
 lda (info_ptr),y
 ldy #34
 sta (info_ptr),y     ; prev_xpos <- current xpos
 ldy #0
 lda (info_ptr),y
 ldy #32
 sta (info_ptr),y     ; prev_ypos <- current ypos
 ldy #10
 lda (info_ptr),y
 ldy #36
 sta (info_ptr),y     ; prev_frame_x <- current frame_x
 ldy #12
 lda (info_ptr),y
 ldy #38
 sta (info_ptr),y     ; prev_frame_y <- current frame_y
 lda IMAGE01_MIRROR
 bne :adv_left
* Jumping right — clamp at PLAYER_MAX_X so Billy's feet stay
* inside the playfield instead of walking past the right edge.
 lda IMAGE01_XPOS
 cmp #PLAYER_MAX_X
 bcs :adv_done
 inc IMAGE01_XPOS
* If player (controller=1 at info+22), also advance abs_x so
* jumps contribute to world-position tracking the same as walks.
* Without this, OP_WAITX thresholds fire at different times
* depending on how much the player jumped.
 ldy #22
 lda (info_ptr),y
 cmp #1
 bne :adv_done
 inc abs_x
 bne :adv_done
 inc abs_x+1
 bra :adv_done
:adv_left
* Jumping left — clamp at xpos=1 so the sprite's left edge
* doesn't cross the playfield's left boundary.
 lda IMAGE01_XPOS
 cmp #2
 bcc :adv_done
 dec IMAGE01_XPOS
 ldy #22
 lda (info_ptr),y
 cmp #1
 bne :adv_done
 lda abs_x
 bne :adv_absx_lo
 dec abs_x+1
:adv_absx_lo
 dec abs_x
:adv_done
 ldy #2
 lda IMAGE01_XPOS
 sta (info_ptr),y     ; save xpos back
 ldy #30
 lda #$03
 sta (info_ptr),y     ; mark dirty (bit0=draw, bit1=erase)
* Decrement timer
:no_advance
 ldy #28
 lda (info_ptr),y     ; anim_timer
 sec
 sbc #1
 sta (info_ptr),y
 beq :timer_exp
 jmp :next            ; timer not zero, continue
:timer_exp
* Timer expired — advance to next frame
 ldy #26
 lda (info_ptr),y     ; anim_frame
 clc
 adc #1
 sta (info_ptr),y     ; anim_frame++
* Compare with num_frames
 ldy #0
 cmp (anim_ptr),y     ; num_frames
 bcs :past_last_frame ; inverted — :load_frame is now out of range
 jmp :load_frame
:past_last_frame
* Animation complete — check for loop
 ldy #2
 lda (anim_ptr),y     ; flags
 and #$02             ; bit 1 = loop
 beq :anim_done       ; not looping, terminate
* Loop: reset to frame 0
 ldy #26
 lda #0
 sta (info_ptr),y     ; anim_frame = 0
 jmp :load_frame
:anim_done
* Check if this was a fall_anim and punch_count >= 6 (death)
 ldy #50
 lda (info_ptr),y     ; fall_anim low
 cmp anim_ptr
 bne :normal_end
 iny
 lda (info_ptr),y     ; fall_anim high
 cmp anim_ptr+1
 bne :normal_end
 ldy #48
 lda (info_ptr),y     ; punch_count
 cmp #6
 bcc :normal_end
* Death: set $FFFF sentinel, mark dirty for erase+removal.
*
* For a fall-anim death, the sprite has a history of drawings
* at different rects at this xpos: walking/wpunched at ypos-24
* (40 tall), wfall frame 0 also around ypos-24 (33 tall), and
* wfall frame 1 (WFALLEN 13 tall) at the bumped ypos. The
* death erase needs to cover ALL of these because intermediate
* transitions might not have fully cleaned them (e.g., rapid
* punches where save_anim_state races the erase). Set prev to
* a generous rect that envelops every pre-bump position: start
* at ypos-FALL_Y_OFFSET and extend 40 rows down (reaching past
* WFALLEN), width 20 (covers WFALL's 19).
* DEBUG: log death entry with current ypos/xpos
 lda #$C4              ; 'D'
 jsr dbg_print_char
 lda #$C4              ; 'D'
 jsr dbg_print_char
 lda #$A0              ; ' '
 jsr dbg_print_char
 ldy #0
 lda (info_ptr),y
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 ldy #2
 lda (info_ptr),y
 jsr dbg_print_hex8
 jsr dbg_print_nl
 ldy #0
 lda (info_ptr),y
 sec
 sbc #FALL_Y_OFFSET
 ldy #32
 sta (info_ptr),y     ; prev_ypos <- ypos - FALL_Y_OFFSET (pre-bump)
 ldy #2
 lda (info_ptr),y
 ldy #34
 sta (info_ptr),y     ; prev_xpos <- current xpos
 lda #20
 ldy #36
 sta (info_ptr),y     ; prev_frame_x <- 20 (covers WFALL/WPUNCH)
* Cap height so erase doesn't extend into the HUD at y=180+.
* prev_frame_y = min(40, 180 - prev_ypos)
 lda #180
 ldy #32
 sec
 sbc (info_ptr),y     ; A = 180 - prev_ypos
 cmp #40
 bcc :dd_use_capped
 lda #40
:dd_use_capped
 ldy #38
 sta (info_ptr),y     ; prev_frame_y
 ldy #24
 lda #$FF
 sta (info_ptr),y     ; anim_ptr = $FFFF
 iny
 sta (info_ptr),y
 ldy #30
 lda #$03
 sta (info_ptr),y     ; dirty = erase+draw
 jmp :next

:normal_end
* If the anim that just ended was a multi-frame fall_anim (so
* we bumped ypos on entry to the fallen frame), un-bump now:
* snapshot prev_ypos from the bumped current so erase_all clears
* the fallen sprite at its drawn position, then subtract the
* offset so the restored idle frame draws at the logical height.
* anim_bfall is a 1-frame placeholder, so num_frames<2 skips.
* DEBUG: log entry to :normal_end with anim_ptr low byte.
 lda #$CE              ; 'N'
 jsr dbg_print_char
 lda #$C5              ; 'E'
 jsr dbg_print_char
 lda #$A0              ; ' '
 jsr dbg_print_char
 lda anim_ptr
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 ldy #50
 lda (info_ptr),y
 jsr dbg_print_hex8
 jsr dbg_print_nl
 ldy #50
 lda (info_ptr),y
 cmp anim_ptr
 bne :ne_no_unbump
 ldy #51
 lda (info_ptr),y
 cmp anim_ptr+1
 bne :ne_no_unbump
 ldy #0
 lda (anim_ptr),y     ; num_frames
 cmp #2
 bcc :ne_no_unbump
* DEBUG: log unbump with pre-unbump ypos
 lda #$D5              ; 'U'
 jsr dbg_print_char
 lda #$C2              ; 'B'
 jsr dbg_print_char
 lda #$A0              ; ' '
 jsr dbg_print_char
 ldy #0
 lda (info_ptr),y
 jsr dbg_print_hex8
 jsr dbg_print_nl
 ldy #0
 lda (info_ptr),y     ; current ypos (bumped)
 ldy #32
 sta (info_ptr),y     ; prev_ypos <- bumped
 ldy #0
 lda (info_ptr),y
 sec
 sbc #FALL_Y_OFFSET
 sta (info_ptr),y     ; ypos -= FALL_Y_OFFSET
:ne_no_unbump
* Clamp ypos so the sprite's bottom stays on-screen
* (ypos + frame_y <= 200). NPCs drift below the walkable floor
* after repeated hit-reactions when the un-bump above misses —
* this keeps them inside the playfield and hittable by Billy.
 ldy #12
 lda (info_ptr),y     ; frame_y
 sta :ne_tmp
 lda #200
 sec
 sbc :ne_tmp          ; A = 200 - frame_y = max ypos
 sta :ne_tmp
 ldy #0
 lda (info_ptr),y     ; current ypos
 cmp :ne_tmp
 bcc :ne_no_clamp
 beq :ne_no_clamp
 lda :ne_tmp
 sta (info_ptr),y     ; ypos = max ypos
 ldy #32
 sta (info_ptr),y     ; prev_ypos = clamped (erase anchor)
:ne_no_clamp
* Terminate animation, restore idle frame
 ldy #24
 lda #0
 sta (info_ptr),y     ; clear anim_ptr low
 iny
 sta (info_ptr),y     ; clear anim_ptr high
 ldy #26
 sta (info_ptr),y     ; clear anim_frame
* Restore idle frame from sprite block
 ldy #42
 lda (info_ptr),y     ; idle_addr low
 sta FRAME_ADDR
 iny
 lda (info_ptr),y     ; idle_addr high
 sta FRAME_ADDR+1
 ldy #44
 lda (info_ptr),y     ; idle_x
 sta FRAME_X
 ldy #46
 lda (info_ptr),y     ; idle_y
 sta FRAME_Y
* For Billy (controller=$01): pick compiled idle data + mask whose
* orientation matches IMAGE01_MIRROR. Mirror is baked into the
* pre-rotated arrays — draw_sprite_compiled has no mirror branch.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :ne_no_billy_mask
 lda IMAGE01_MIRROR
 bne :ne_billy_mirror
* mirror=0: FRAME_ADDR is already idle_addr = IMAGE01_DATA. Just set MASK.
 lda spr_image01_mask
 sta MASK_ADDR
 lda spr_image01_mask+1
 sta MASK_ADDR+1
 bra :ne_no_billy_mask
:ne_billy_mirror
* mirror=1: swap FRAME_ADDR + MASK_ADDR for the pre-mirrored versions.
 lda spr_image01_data_mirror
 sta FRAME_ADDR
 lda spr_image01_data_mirror+1
 sta FRAME_ADDR+1
 lda spr_image01_mask_mirror
 sta MASK_ADDR
 lda spr_image01_mask_mirror+1
 sta MASK_ADDR+1
:ne_no_billy_mask
 jsr save_anim_state
 jmp :next

:load_frame
* Load frame data from descriptor. Dispatch on flags bit 7:
*   bit 7 set  → compiled (11-byte stride, data + mask + dmir + mmir)
*   bit 7 clear → legacy (5-byte stride, single frame_addr)
 ldy #2
 lda (anim_ptr),y     ; flags
 and #$80
 bne :lf_compiled

* === Legacy 5-byte stride: frame_offset = 3 + anim_frame * 5 ===
 ldy #26
 lda (info_ptr),y     ; anim_frame
 sta :frm
 asl                  ; *2
 asl                  ; *4
 clc
 adc :frm             ; *5
 clc
 adc #3               ; +3 (header size)
 tay
 lda (anim_ptr),y     ; frame_x
 sta FRAME_X
 iny
 lda (anim_ptr),y     ; frame_y
 sta FRAME_Y
 iny
 lda (anim_ptr),y     ; duration
 pha
 iny
 lda (anim_ptr),y     ; frame_addr low
 sta FRAME_ADDR
 iny
 lda (anim_ptr),y     ; frame_addr high
 sta FRAME_ADDR+1
 pla
 ldy #28
 sta (info_ptr),y     ; anim_timer = duration
* Legacy frames are reached only by NPC animations now. The Billy-
* specific MASK_ADDR clear that lived here in A1/A2 is dead code
* (every Billy animation is compiled) and was removed in A3.
 jmp :lf_load_done

:lf_compiled
* === Compiled 11-byte stride: frame_offset = 3 + anim_frame * 11 ===
 ldy #26
 lda (info_ptr),y     ; anim_frame
 sta :frm
 asl                  ; *2
 sta :lf_tmp
 asl                  ; *4
 asl                  ; *8
 clc
 adc :lf_tmp          ; *10
 clc
 adc :frm             ; *11
 clc
 adc #3               ; +3 (header size)
 tay
 lda (anim_ptr),y     ; frame_x
 sta FRAME_X
 iny
 lda (anim_ptr),y     ; frame_y
 sta FRAME_Y
 iny
 lda (anim_ptr),y     ; duration
 pha
 iny                  ; Y now points at +3 (data low) within frame
 lda IMAGE01_MIRROR
 bne :lf_compiled_mirror
* Non-mirror: data at +3..+4, mask at +5..+6
 lda (anim_ptr),y
 sta FRAME_ADDR
 iny
 lda (anim_ptr),y
 sta FRAME_ADDR+1
 iny
 lda (anim_ptr),y
 sta MASK_ADDR
 iny
 lda (anim_ptr),y
 sta MASK_ADDR+1
 bra :lf_compiled_persist
:lf_compiled_mirror
* Mirror: skip data + mask (4 bytes), read dmir at +7..+8, mmir at +9..+10
 iny
 iny
 iny
 iny
 lda (anim_ptr),y
 sta FRAME_ADDR
 iny
 lda (anim_ptr),y
 sta FRAME_ADDR+1
 iny
 lda (anim_ptr),y
 sta MASK_ADDR
 iny
 lda (anim_ptr),y
 sta MASK_ADDR+1
:lf_compiled_persist
 pla
 ldy #28
 sta (info_ptr),y     ; anim_timer = duration
* For Billy: persist MASK_ADDR → info+52 so load_sprite next frame
* picks up the matching mask (since save_anim_state hasn't run yet
* for this frame).
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :lf_load_done
 ldy #52
 lda MASK_ADDR
 sta (info_ptr),y
 iny
 lda MASK_ADDR+1
 sta (info_ptr),y

:lf_load_done
* Check for punch hit (frame 1 of any punch animation)
 ldy #26
 lda (info_ptr),y     ; anim_frame
 cmp #1
 beq :maybe_punch
 jmp :no_punch_hit
:maybe_punch
 lda anim_ptr
 cmp #<anim_punch1
 bne :try_p2
 lda anim_ptr+1
 cmp #>anim_punch1
 bne :try_p2
 jmp :do_hit_now
:try_p2
 lda anim_ptr
 cmp #<anim_punch2
 bne :try_wp
 lda anim_ptr+1
 cmp #>anim_punch2
 bne :try_wp
 jmp :do_hit_now
:try_wp
 lda anim_ptr
 cmp #<anim_wpunch
 bne :try_rp
 lda anim_ptr+1
 cmp #>anim_wpunch
 bne :try_rp
 jmp :do_hit_now
:try_rp
 lda anim_ptr
 cmp #<anim_rpunch
 bne :try_lp
 lda anim_ptr+1
 cmp #>anim_rpunch
 bne :try_lp
 jmp :do_hit_now
:try_lp
 lda anim_ptr
 cmp #<anim_lpunch
 bne :try_kick
 lda anim_ptr+1
 cmp #>anim_lpunch
 bne :try_kick
 jmp :do_hit_now
:try_kick
 lda anim_ptr
 cmp #<anim_kick
 bne :no_punch_hit
 lda anim_ptr+1
 cmp #>anim_kick
 bne :no_punch_hit
* Back-kick: KICK2 renders Billy's foot opposite his facing so
* the sprite's natural bounding box doesn't cover enemies behind
* him. Extend the hit box by KICK_BACK_EXT bytes in the opposite
* direction before calling the standard punch-hit path, then
* restore IMAGE01_XPOS / FRAME_X / FRAME_Y afterward. Override
* FRAME_Y to walk-height (40) so the vertical tolerance in
* check_punch_hit isn't thrown off by KICK2's shorter 34-row box.
 lda IMAGE01_XPOS
 sta :kick_saved_xpos
 lda FRAME_X
 sta :kick_saved_fx
 lda FRAME_Y
 sta :kick_saved_fy
 lda #40
 sta FRAME_Y
 lda IMAGE01_MIRROR
 bne :kick_extend_right
* Mirror=0 (facing right): foot reaches LEFT. Shift xpos left and
* widen FRAME_X so the box covers xpos-EXT..xpos+FRAME_X.
 lda IMAGE01_XPOS
 sec
 sbc #KICK_BACK_EXT
 bcs :kick_xl_ok
 lda #0
:kick_xl_ok
 sta IMAGE01_XPOS
 lda FRAME_X
 clc
 adc #KICK_BACK_EXT
 sta FRAME_X
 bra :kick_do_hit
:kick_extend_right
* Mirror=1 (facing left): foot reaches RIGHT. Just widen FRAME_X.
 lda FRAME_X
 clc
 adc #KICK_BACK_EXT
 sta FRAME_X
:kick_do_hit
 jsr check_punch_hit
 lda :kick_saved_xpos
 sta IMAGE01_XPOS
 lda :kick_saved_fx
 sta FRAME_X
 lda :kick_saved_fy
 sta FRAME_Y
 jmp :no_punch_hit
:do_hit_now
 jsr check_punch_hit
:no_punch_hit
 jsr save_anim_state
* If this was the 0→1 transition of the sprite's fall_anim, bump
* ypos by FALL_Y_OFFSET so the shorter "fallen" frame draws at
* feet level instead of the standing sprite's head level.
* prev_ypos is intentionally left alone — erase_all needs it to
* clear the previous (standing-height) frame this same VBL.
 ldy #26
 lda (info_ptr),y
 cmp #1
 bne :no_fall_bump
 ldy #50
 lda (info_ptr),y
 cmp anim_ptr
 bne :no_fall_bump
 ldy #51
 lda (info_ptr),y
 cmp anim_ptr+1
 bne :no_fall_bump
* DEBUG: log bump with pre-bump ypos
 lda #$C2              ; 'B'
 jsr dbg_print_char
 lda #$D0              ; 'P'
 jsr dbg_print_char
 lda #$A0              ; ' '
 jsr dbg_print_char
 ldy #0
 lda (info_ptr),y
 jsr dbg_print_hex8
 jsr dbg_print_nl
 ldy #0
 lda (info_ptr),y
 clc
 adc #FALL_Y_OFFSET
 sta (info_ptr),y
:no_fall_bump

:next
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :jloop
 inc spr_ptr+1
:jloop jmp :loop
:done rts

:frm dfb 0
:ne_tmp dfb 0
:lf_tmp dfb 0
:kick_saved_xpos dfb 0
:kick_saved_fx   dfb 0
:kick_saved_fy   dfb 0

*----------------------------------------------------------
* toolbox_init - Start IIgs Toolbox tools
* (So we can have DrawCString)
* TL, MT, MM, then allocate DP for QD and start QD.
*----------------------------------------------------------
errorspot
  hex 00000000
  hex 00000000

toolbox_init
 clc
 xce                   ; native mode
 rep $30               ; 16-bit A, X/Y

* _TLStartup
 ldx #$0201
 jsl $E10000
 bcs errorspot

* _MTStartup
 ldx #$0203
 jsl $E10000
 bcs errorspot+2

* _GetNewID
 pha
 pea $1000
 ldx #$2003
 jsl $E10000
 pla
 sta myID

* Allocate ourselves
 pha                   ; result space (handle high)
 pha                   ; result space (handle low)
 pea $0000             ; size high word
 pea $2000             ; size low word (8KB)
 lda myID
 pha                   ; userID
 pea $C003             ; attributes (locked, bank 0, not page-aligned)
 pea $0000
 pea $2000             ; preferred address ($8000-$FFFF, but ignored if page-aligned)
 ldx #$0902            ; _NewHandle
 jsl $E10000
 bcs errorspot+3
 pla                   ; handle low word
 pla                   ; handle high word

* Allocate 3 pages of direct page for QuickDraw II
 pha                   ; result space (handle high)
 pha                   ; result space (handle low)
 pea $0000             ; size high word
 pea $0300             ; size low word (3 pages)
 lda myID
 pha                   ; userID
 pea $C003             ; attributes (locked, bank 0, not page-aligned)
 pea $0000
 pea $8000             ; preferred address ($8000-$FFFF, but ignored if page-aligned)
 ldx #$0902            ; _NewHandle
 jsl $E10000
 bcs errorspot+4
 pla                   ; handle low word
 sta $00
 pla                   ; handle high word
 sta $02
 lda [$00]             ; dereference handle to get DP address
 sta qdDP

* _QDStartup
* NOTE we are hardwiring this buffer address
* but we did request it and receive it already
 pea $8000             ; dpAddress (still in A from above)
 pea $0000             ; master SCB (320 mode)
 pea $00A0             ; max width (160 bytes)
 lda myID
 pha                   ; userID
 ldx #$0204            ; _QDStartup
 jsl $E10000
 bcs errorspot2

 ldx #$020B            ; IMStartUp (Integer Math Tools)
 jsl $E10000

 sec
 xce                   ; back to emulation mode
 rts

myID ds 2
qdDP ds 2

errorspot2
  hex 00000000

*----------------------------------------------------------
* load_to_bank - Load a file into a single bank.
* Set p_open pathname pointer and load_bank before calling.
* Reuses the same ProDOS parameter blocks as load_background.
*----------------------------------------------------------
load_to_bank
 jsr $BF00
 dfb $C8              ; OPEN
 da p_open
 bcs :err
 lda o_refnum
 sta r_refnum
 sta c_refnum
 sta eof_refnum
* Get file size (for UnPackBytes source length)
 jsr $BF00
 dfb $D1              ; GET_EOF
 da p_get_eof
 lda eof_size
 sta file_size
 lda eof_size+1
 sta file_size+1

 lda #$00
 sta dest
 lda #$20
 sta dest+1            ; destination starts at $2000
 lda #8
 sta :count            ; 8 chunks x 4KB = 32KB

:readlp
 jsr $BF00
 dfb $CA              ; READ
 da p_read
 bcs :close

 jsr copy_to_bank

* Advance destination by $1000
 lda dest+1
 clc
 adc #$10
 sta dest+1

 dec :count
 bne :readlp

:close
 php
 jsr $BF00
 dfb $CC              ; CLOSE
 da p_close
 plp
:err rts

:count dfb 0

load_bank dfb 0        ; destination bank for load_to_bank

*----------------------------------------------------------
* copy_to_bank - Copy 4KB from ]RDBUF to load_bank/dest
* Uses ZP $F0-$F2 for indirect long pointer.
*----------------------------------------------------------
copy_to_bank
 clc
 xce                   ; native mode
 rep $30

 lda dest
 sta $F0               ; destination low/high
 sep $20
 lda load_bank
 sta $F2               ; bank byte

 rep $30
 ldy #$0000
 ldx #$0800            ; $1000/2 = $0800 word copies

:loop lda ]RDBUF,y
 sta [$F0],y
 iny
 iny
 dex
 bne :loop

 sec
 xce                   ; back to emulation mode
 rts

*----------------------------------------------------------
* load_and_unpack - Load a .PAK file to bank $4F via ProDOS,
* then use UnPackBytes to decompress to unpack_bank/$2000.
* p_open pathname pointer must be set before calling.
* unpack_bank must be set to the target bank.
*----------------------------------------------------------
load_and_unpack
* Load PAK file to bank $17 (temp scratch — between music data
* at $12-$13 and the playfield shadow at $18). Was $4F; moved
* down so the engine fits in 2MB IIgs configurations.
 lda #$17
 sta load_bank
 jsr load_to_bank

 clc
 xce                   ; native mode
 rep $30

 lda #$ffff             ; NOTE _UnPackBytes will alter this data
 sta unpack_size        ; so rewrite it before each call
 lda #$2000
 sta unpack_addr

 pha                    ; space for result

 pea $0017             ; src bank (high word)
 pea $2000             ; src addr (low word)

 lda file_size
 pha

 lda unpack_bank
 and #$00FF
 sta unpack_addr+2
 pea #0000
 pea #unpack_addr

 pea #0000
 pea #unpack_size

 ldx #$2703            ; _UnPackBytes
 jsl $E10000
 pla                    ; discard result (live dangerously)
 sec
 xce                   ; back to emulation mode
 rts

unpack_bank dfb 0      ; target bank for unpacking
unpack_size hex ffff     ; size of unpacked data (set by UnPackBytes)
unpack_addr hex 0020E100 ; unpacking destination address (bank/2000)

*----------------------------------------------------------
* copy_50_to_01 - Copy 32KB from $18/2000 to $01/2000
* (for initial screen display via shadowing).
*----------------------------------------------------------
copy_50_to_01
 clc
 xce                   ; native mode
 rep $30

 lda #$2000
 sta $F0               ; src addr
 sta $F3               ; dst addr
 sep $20
 lda #$18
 sta $F2               ; src bank
 lda #$01
 sta $F5               ; dst bank
 rep $30

 ldy #$0000
 ldx #$4000

:loop lda [$F0],y
 sta [$F3],y
 iny
 iny
 dex
 bne :loop

 sec
 xce                   ; back to emulation mode
 rts

*----------------------------------------------------------
* copy_03_to_50 - Copy 32KB from $03/2000 (screen 0 bg)
* to $18/2000 (playfield shadow).
*----------------------------------------------------------
copy_03_to_50
 clc
 xce
 rep $30
 lda #$2000
 sta $F0
 sta $F3
 sep $20
 lda #$03
 sta $F2
 lda #$18
 sta $F5
 rep $30
 ldy #$0000
 ldx #$4000
:loop lda [$F0],y
 sta [$F3],y
 iny
 iny
 dex
 bne :loop
 sec
 xce
 rts

*----------------------------------------------------------
* load_ntp_file - Load a file to ntp_bank+ via ProDOS 8
* in 4KB chunks. Bank increments when address wraps.
*----------------------------------------------------------
* init_level - Read level data header from bank $02 and
* patch engine structures with bank $02 sprite addresses.
* Call after loading mission1 binary to bank $02.
*----------------------------------------------------------
 mx %11
init_level
 clc
 xce                   ; native mode
 rep $30
 mx %00

* Read sprite address table from bank $02 header
* Header layout: 24 bytes of header, then sprite address table
* Each entry is a 2-byte bank $02 address
* Table order: IMAGE01, IMAGE02, IMAGE03, JUMP1-3, KICK1-2,
* PUNCH11-12, PUNCH21-22, BPUNCHED, WILLIAM1, WPUNCHED, WFALL, WFALLEN

* Read bounds pointer table offset from header field at $02/0014
 lda #$0014
 sta $F0
 sep $20
 lda #$02
 sta $F2
 rep $20
 ldy #0
 lda [$F0],y
 sta bounds_base       ; bank $02 address of bounds_ptrs

* Read ladder pointer table offset from header field at $02/0016
 lda #$0016
 sta $F0
 sep $20
 lda #$02
 sta $F2
 rep $20
 ldy #0
 lda [$F0],y
 sta ladder_base       ; bank $02 address of ladder_ptrs

* Read sprite address table offset from header field at $02/0012
 lda #$0012
 sta $F0
 sep $20
 lda #$02
 sta $F2              ; $F0 = $02/0012
 rep $20
 ldy #0
 lda [$F0],y          ; read spr_addr_off value from header
 sta $F0              ; now $F0 points to the actual sprite address table

* Read each sprite address and patch the engine's DA references
* IMAGE01 (table offset +0)
 ldy #0
 lda [$F0],y          ; bank $02 addr of IMAGE01
 sta spr_img01

* IMAGE02 (table offset +2)
 ldy #2
 lda [$F0],y
 sta spr_img02

* IMAGE03 (table offset +4)
 ldy #4
 lda [$F0],y
 sta spr_img03

* JUMP1-3 (offsets +6, +8, +10)
 ldy #6
 lda [$F0],y
 sta spr_jump1
 ldy #8
 lda [$F0],y
 sta spr_jump2
 ldy #10
 lda [$F0],y
 sta spr_jump3

* KICK1-2 (offsets +12, +14)
 ldy #12
 lda [$F0],y
 sta spr_kick1
 ldy #14
 lda [$F0],y
 sta spr_kick2

* PUNCH11-12 (offsets +16, +18)
 ldy #16
 lda [$F0],y
 sta spr_punch11
 ldy #18
 lda [$F0],y
 sta spr_punch12

* PUNCH21-22 (offsets +20, +22)
 ldy #20
 lda [$F0],y
 sta spr_punch21
 ldy #22
 lda [$F0],y
 sta spr_punch22

* BPUNCHED (offset +24)
 ldy #24
 lda [$F0],y
 sta spr_bpunched

* WILLIAM1 (offset +26)
 ldy #26
 lda [$F0],y
 sta spr_william1

* WPUNCHED (offset +28)
 ldy #28
 lda [$F0],y
 sta spr_wpunched

* WFALL (offset +30)
 ldy #30
 lda [$F0],y
 sta spr_wfall

* WFALLEN (offset +32)
 ldy #32
 lda [$F0],y
 sta spr_wfallen

* WILLIAM2 (offset +34)
 ldy #34
 lda [$F0],y
 sta spr_william2

* WILLIAM3 (offset +36)
 ldy #36
 lda [$F0],y
 sta spr_william3

* WPUNCH1 (offset +38)
 ldy #38
 lda [$F0],y
 sta spr_wpunch1

* WPUNCH2 (offset +40)
 ldy #40
 lda [$F0],y
 sta spr_wpunch2

* ROPER1-3 (offsets +42, +44, +46)
 ldy #42
 lda [$F0],y
 sta spr_roper1
 ldy #44
 lda [$F0],y
 sta spr_roper2
 ldy #46
 lda [$F0],y
 sta spr_roper3

* RPUNCH1-2 (offsets +48, +50)
 ldy #48
 lda [$F0],y
 sta spr_rpunch1
 ldy #50
 lda [$F0],y
 sta spr_rpunch2

* RPUNCHED (offset +52)
 ldy #52
 lda [$F0],y
 sta spr_rpunched

* RFALL1-2 (offsets +54, +56)
 ldy #54
 lda [$F0],y
 sta spr_rfall1
 ldy #56
 lda [$F0],y
 sta spr_rfall2

* LINDA1-3 (offsets +58, +60, +62)
 ldy #58
 lda [$F0],y
 sta spr_linda1
 ldy #60
 lda [$F0],y
 sta spr_linda2
 ldy #62
 lda [$F0],y
 sta spr_linda3

* LPUNCH1-2 (offsets +64, +66)
 ldy #64
 lda [$F0],y
 sta spr_lpunch1
 ldy #66
 lda [$F0],y
 sta spr_lpunch2

* LPUNCHED (offset +68)
 ldy #68
 lda [$F0],y
 sta spr_lpunched

* LFALL1-2 (offsets +70, +72)
 ldy #70
 lda [$F0],y
 sta spr_lfall1
 ldy #72
 lda [$F0],y
 sta spr_lfall2

* POINT_RIGHT (offset +74)
 ldy #74
 lda [$F0],y
 sta spr_pointright

* POINT_UP (offset +76)
 ldy #76
 lda [$F0],y
 sta spr_pointup

* BCLIMB1 (offset +78)
 ldy #78
 lda [$F0],y
 sta spr_bclimb1

* BCLIMB2 (offset +80)
 ldy #80
 lda [$F0],y
 sta spr_bclimb2

* LCLIMB1 (offset +82)
 ldy #82
 lda [$F0],y
 sta spr_lclimb1

* LCLIMB2 (offset +84)
 ldy #84
 lda [$F0],y
 sta spr_lclimb2

* Compiled-sprite extras (offsets +86..+96)
 ldy #86
 lda [$F0],y
 sta spr_pointright_mask
 ldy #88
 lda [$F0],y
 sta spr_pointright_data_mirror
 ldy #90
 lda [$F0],y
 sta spr_pointright_mask_mirror
 ldy #92
 lda [$F0],y
 sta spr_pointup_mask
 ldy #94
 lda [$F0],y
 sta spr_pointup_data_mirror
 ldy #96
 lda [$F0],y
 sta spr_pointup_mask_mirror

* Billy walk-frame compiled extras (offsets +98..+114)
 ldy #98
 lda [$F0],y
 sta spr_image01_mask
 ldy #100
 lda [$F0],y
 sta spr_image01_data_mirror
 ldy #102
 lda [$F0],y
 sta spr_image01_mask_mirror
 ldy #104
 lda [$F0],y
 sta spr_image02_mask
 ldy #106
 lda [$F0],y
 sta spr_image02_data_mirror
 ldy #108
 lda [$F0],y
 sta spr_image02_mask_mirror
 ldy #110
 lda [$F0],y
 sta spr_image03_mask
 ldy #112
 lda [$F0],y
 sta spr_image03_data_mirror
 ldy #114
 lda [$F0],y
 sta spr_image03_mask_mirror

* Billy climb frames (offsets +116..+126)
 ldy #116
 lda [$F0],y
 sta spr_bclimb1_mask
 ldy #118
 lda [$F0],y
 sta spr_bclimb1_data_mirror
 ldy #120
 lda [$F0],y
 sta spr_bclimb1_mask_mirror
 ldy #122
 lda [$F0],y
 sta spr_bclimb2_mask
 ldy #124
 lda [$F0],y
 sta spr_bclimb2_data_mirror
 ldy #126
 lda [$F0],y
 sta spr_bclimb2_mask_mirror

* Billy punch1 frames (offsets +128..+138)
 ldy #128
 lda [$F0],y
 sta spr_punch11_mask
 ldy #130
 lda [$F0],y
 sta spr_punch11_data_mirror
 ldy #132
 lda [$F0],y
 sta spr_punch11_mask_mirror
 ldy #134
 lda [$F0],y
 sta spr_punch12_mask
 ldy #136
 lda [$F0],y
 sta spr_punch12_data_mirror
 ldy #138
 lda [$F0],y
 sta spr_punch12_mask_mirror

* Billy punch2 frames (offsets +140..+150)
 ldy #140
 lda [$F0],y
 sta spr_punch21_mask
 ldy #142
 lda [$F0],y
 sta spr_punch21_data_mirror
 ldy #144
 lda [$F0],y
 sta spr_punch21_mask_mirror
 ldy #146
 lda [$F0],y
 sta spr_punch22_mask
 ldy #148
 lda [$F0],y
 sta spr_punch22_data_mirror
 ldy #150
 lda [$F0],y
 sta spr_punch22_mask_mirror

* Billy kick frames (offsets +152..+162)
 ldy #152
 lda [$F0],y
 sta spr_kick1_mask
 ldy #154
 lda [$F0],y
 sta spr_kick1_data_mirror
 ldy #156
 lda [$F0],y
 sta spr_kick1_mask_mirror
 ldy #158
 lda [$F0],y
 sta spr_kick2_mask
 ldy #160
 lda [$F0],y
 sta spr_kick2_data_mirror
 ldy #162
 lda [$F0],y
 sta spr_kick2_mask_mirror

* Billy jump frames (offsets +164..+180)
 ldy #164
 lda [$F0],y
 sta spr_jump1_mask
 ldy #166
 lda [$F0],y
 sta spr_jump1_data_mirror
 ldy #168
 lda [$F0],y
 sta spr_jump1_mask_mirror
 ldy #170
 lda [$F0],y
 sta spr_jump2_mask
 ldy #172
 lda [$F0],y
 sta spr_jump2_data_mirror
 ldy #174
 lda [$F0],y
 sta spr_jump2_mask_mirror
 ldy #176
 lda [$F0],y
 sta spr_jump3_mask
 ldy #178
 lda [$F0],y
 sta spr_jump3_data_mirror
 ldy #180
 lda [$F0],y
 sta spr_jump3_mask_mirror

* Billy hit-reaction frame (offsets +182..+186)
 ldy #182
 lda [$F0],y
 sta spr_bpunched_mask
 ldy #184
 lda [$F0],y
 sta spr_bpunched_data_mirror
 ldy #186
 lda [$F0],y
 sta spr_bpunched_mask_mirror

* Now patch all DA references in animation descriptors
* and sprite info blocks with bank $02 addresses.
* Each anim frame has: dfb x,y,dur, DA addr (5 bytes per frame)
* Frame addr is at offset +3 within each frame (header is 3 bytes)

* Patch anim_walk: 4 frames at offsets 3,8,13,18 from anim_walk+3
 lda spr_img01
 sta anim_walk+3+3     ; frame 0 addr (IMAGE01)
 lda spr_img02
 sta anim_walk+3+8     ; frame 1 addr (IMAGE02)
 lda spr_img03
 sta anim_walk+3+13    ; frame 2 addr (IMAGE03)
 lda spr_img02
 sta anim_walk+3+18    ; frame 3 addr (IMAGE02)

* Patch anim_jump: 3 compiled frames (11-byte stride). Frames at
* +6/+8/+10/+12, +17/+19/+21/+23, +28/+30/+32/+34.
 lda spr_jump1
 sta anim_jump+6
 lda spr_jump1_mask
 sta anim_jump+8
 lda spr_jump1_data_mirror
 sta anim_jump+10
 lda spr_jump1_mask_mirror
 sta anim_jump+12
 lda spr_jump2
 sta anim_jump+17
 lda spr_jump2_mask
 sta anim_jump+19
 lda spr_jump2_data_mirror
 sta anim_jump+21
 lda spr_jump2_mask_mirror
 sta anim_jump+23
 lda spr_jump3
 sta anim_jump+28
 lda spr_jump3_mask
 sta anim_jump+30
 lda spr_jump3_data_mirror
 sta anim_jump+32
 lda spr_jump3_mask_mirror
 sta anim_jump+34

* Patch anim_kick: 2 compiled frames (11-byte stride)
 lda spr_kick1
 sta anim_kick+6
 lda spr_kick1_mask
 sta anim_kick+8
 lda spr_kick1_data_mirror
 sta anim_kick+10
 lda spr_kick1_mask_mirror
 sta anim_kick+12
 lda spr_kick2
 sta anim_kick+17
 lda spr_kick2_mask
 sta anim_kick+19
 lda spr_kick2_data_mirror
 sta anim_kick+21
 lda spr_kick2_mask_mirror
 sta anim_kick+23

* Patch anim_punch1: 2 compiled frames (11-byte stride). Frame 0
* pointers at +6/+8/+10/+12, frame 1 at +17/+19/+21/+23.
 lda spr_punch11
 sta anim_punch1+6        ; frame 0 data
 lda spr_punch11_mask
 sta anim_punch1+8        ; frame 0 mask
 lda spr_punch11_data_mirror
 sta anim_punch1+10       ; frame 0 dmir
 lda spr_punch11_mask_mirror
 sta anim_punch1+12       ; frame 0 mmir
 lda spr_punch12
 sta anim_punch1+17       ; frame 1 data
 lda spr_punch12_mask
 sta anim_punch1+19       ; frame 1 mask
 lda spr_punch12_data_mirror
 sta anim_punch1+21       ; frame 1 dmir
 lda spr_punch12_mask_mirror
 sta anim_punch1+23       ; frame 1 mmir

* Patch anim_punch2: 2 compiled frames (11-byte stride)
 lda spr_punch21
 sta anim_punch2+6
 lda spr_punch21_mask
 sta anim_punch2+8
 lda spr_punch21_data_mirror
 sta anim_punch2+10
 lda spr_punch21_mask_mirror
 sta anim_punch2+12
 lda spr_punch22
 sta anim_punch2+17
 lda spr_punch22_mask
 sta anim_punch2+19
 lda spr_punch22_data_mirror
 sta anim_punch2+21
 lda spr_punch22_mask_mirror
 sta anim_punch2+23

* Patch anim_bpunched: 1 compiled frame (11-byte stride)
 lda spr_bpunched
 sta anim_bpunched+6
 lda spr_bpunched_mask
 sta anim_bpunched+8
 lda spr_bpunched_data_mirror
 sta anim_bpunched+10
 lda spr_bpunched_mask_mirror
 sta anim_bpunched+12

* Patch anim_wpunched: 1 frame
 lda spr_wpunched
 sta anim_wpunched+3+3

* Patch anim_wfall: 2 frames
 lda spr_wfall
 sta anim_wfall+3+3
 lda spr_wfallen
 sta anim_wfall+3+8

* Patch anim_bfall: 1 compiled frame (placeholder uses IMAGE01)
 lda spr_img01
 sta anim_bfall+6
 lda spr_image01_mask
 sta anim_bfall+8
 lda spr_image01_data_mirror
 sta anim_bfall+10
 lda spr_image01_mask_mirror
 sta anim_bfall+12

* Patch anim_wwalk: 4 frames (WILLIAM1, WILLIAM2, WILLIAM3, WILLIAM2)
 lda spr_william1
 sta anim_wwalk+3+3
 lda spr_william2
 sta anim_wwalk+3+8
 lda spr_william3
 sta anim_wwalk+3+13
 lda spr_william2
 sta anim_wwalk+3+18

* Patch anim_wpunch: 2 frames (WPUNCH1, WPUNCH2)
 lda spr_wpunch1
 sta anim_wpunch+3+3
 lda spr_wpunch2
 sta anim_wpunch+3+8

* Patch anim_rwalk: 4 frames (ROPER1, ROPER2, ROPER3, ROPER2)
 lda spr_roper1
 sta anim_rwalk+3+3
 lda spr_roper2
 sta anim_rwalk+3+8
 lda spr_roper3
 sta anim_rwalk+3+13
 lda spr_roper2
 sta anim_rwalk+3+18

* Patch anim_rpunch: 2 frames
 lda spr_rpunch1
 sta anim_rpunch+3+3
 lda spr_rpunch2
 sta anim_rpunch+3+8

* Patch anim_rpunched: 1 frame
 lda spr_rpunched
 sta anim_rpunched+3+3

* Patch anim_rfall: 2 frames
 lda spr_rfall1
 sta anim_rfall+3+3
 lda spr_rfall2
 sta anim_rfall+3+8

* Patch anim_lwalk: 4 frames (LINDA1, LINDA2, LINDA3, LINDA2)
 lda spr_linda1
 sta anim_lwalk+3+3
 lda spr_linda2
 sta anim_lwalk+3+8
 lda spr_linda3
 sta anim_lwalk+3+13
 lda spr_linda2
 sta anim_lwalk+3+18

* Patch anim_lpunch: 2 frames
 lda spr_lpunch1
 sta anim_lpunch+3+3
 lda spr_lpunch2
 sta anim_lpunch+3+8

* Patch anim_lpunched: 1 frame
 lda spr_lpunched
 sta anim_lpunched+3+3

* Patch anim_lfall: 2 frames
 lda spr_lfall1
 sta anim_lfall+3+3
 lda spr_lfall2
 sta anim_lfall+3+8

* Patch billy_sprite frame_addr (+14), idle_addr (+42), and the
* compiled inverse-mask address (+52). Also seed MASK_ADDR so the
* very first draw_all (before any advance_walk) renders correctly.
 lda spr_img01
 sta billy_sprite+14
 sta billy_sprite+42
 lda spr_image01_mask
 sta billy_sprite+52
 sta MASK_ADDR

* Patch william_sprite frame_addr and idle_addr
 lda spr_william1
 sta william_sprite+14
 sta william_sprite+42

* Patch william2_sprite frame_addr and idle_addr
 lda spr_william1
 sta william2_sprite+14
 sta william2_sprite+42

* Patch walk_addr_tbl (data) and walk_mask_tbl (parallel mask)
 lda spr_img01
 sta walk_addr_tbl
 lda spr_img02
 sta walk_addr_tbl+2
 lda spr_img03
 sta walk_addr_tbl+4
 lda spr_img02
 sta walk_addr_tbl+6

 lda spr_image01_mask
 sta walk_mask_tbl
 lda spr_image02_mask
 sta walk_mask_tbl+2
 lda spr_image03_mask
 sta walk_mask_tbl+4
 lda spr_image02_mask
 sta walk_mask_tbl+6

* Patch mirror-baked walk tables
 lda spr_image01_data_mirror
 sta walk_addr_tbl_mirror
 lda spr_image02_data_mirror
 sta walk_addr_tbl_mirror+2
 lda spr_image03_data_mirror
 sta walk_addr_tbl_mirror+4
 lda spr_image02_data_mirror
 sta walk_addr_tbl_mirror+6

 lda spr_image01_mask_mirror
 sta walk_mask_tbl_mirror
 lda spr_image02_mask_mirror
 sta walk_mask_tbl_mirror+2
 lda spr_image03_mask_mirror
 sta walk_mask_tbl_mirror+4
 lda spr_image02_mask_mirror
 sta walk_mask_tbl_mirror+6

* Read player_spawn_x/y from header ($02/0002, $02/0003)
* and apply to billy_sprite xpos/ypos (+ prev fields).
 sep $20
 mx %10
 lda #$02
 sta $F2
 rep $20
 mx %00
 lda #$0002
 sta $F0
 sep $20
 mx %10
 ldy #0
 lda [$F0],y           ; player_spawn_x
 sta billy_sprite+2
 sta billy_sprite+34
 sta abs_x             ; initialize absolute X
 stz abs_x+1
 ldy #1
 lda [$F0],y           ; player_spawn_y
 sta billy_sprite
 sta billy_sprite+32
 rep $20
 mx %00

* Set sprite bank
 lda #$0002
 sta sprite_bank

* Initialize level script pointer from header
* level_scr_off is at offset $0E in the header
 lda #$000E
 sta $F0
 sep $20
 lda #$02
 sta $F2
 rep $20
 ldy #0
 lda [$F0],y           ; read level_script address from header
 sta script_pc
 sep $20
 lda #$02
 sta script_pc+2       ; bank $02
 lda #SCRIPT_RUN
 sta script_state
 rep $20

 sec
 xce                   ; back to emulation mode

* Load initial screen's bounds table
 lda #0                ; initial_screen = 0
 jsr load_screen_bounds
* Load global ladder list (once)
 jsr load_ladders
* Reset world scroll offset
 stz world_offset
 stz world_offset+1
* Reset script scroll clamps to no-limit sentinels.
 stz scroll_min_wo
 stz scroll_min_wo+1
 lda #$FF
 sta scroll_max_wo
 sta scroll_max_wo+1
 rts

*-------------------------------
* Sprite address cache (bank $02 addresses, set by init_level)
*-------------------------------
spr_img01    ds 2
spr_img02    ds 2
spr_img03    ds 2
spr_jump1    ds 2
spr_jump2    ds 2
spr_jump3    ds 2
spr_kick1    ds 2
spr_kick2    ds 2
spr_punch11  ds 2
spr_punch12  ds 2
spr_punch21  ds 2
spr_punch22  ds 2
spr_bpunched ds 2
spr_william1 ds 2
spr_wpunched ds 2
spr_wfall    ds 2
spr_wfallen  ds 2
spr_william2 ds 2
spr_william3 ds 2
spr_wpunch1  ds 2
spr_wpunch2  ds 2
; Roper
spr_roper1   ds 2
spr_roper2   ds 2
spr_roper3   ds 2
spr_rpunch1  ds 2
spr_rpunch2  ds 2
spr_rpunched ds 2
spr_rfall1   ds 2
spr_rfall2   ds 2
; Linda Lash
spr_linda1   ds 2
spr_linda2   ds 2
spr_linda3   ds 2
spr_lpunch1  ds 2
spr_lpunch2  ds 2
spr_lpunched ds 2
spr_lfall1   ds 2
spr_lfall2   ds 2
spr_pointright ds 2
spr_pointup    ds 2
spr_bclimb1    ds 2
spr_bclimb2    ds 2
spr_lclimb1    ds 2
spr_lclimb2    ds 2
* Compiled-sprite extras for AND/ORA pipeline overlay path
spr_pointright_mask        ds 2
spr_pointright_data_mirror ds 2
spr_pointright_mask_mirror ds 2
spr_pointup_mask           ds 2
spr_pointup_data_mirror    ds 2
spr_pointup_mask_mirror    ds 2
* Billy walk frames — compiled
spr_image01_mask           ds 2
spr_image01_data_mirror    ds 2
spr_image01_mask_mirror    ds 2
spr_image02_mask           ds 2
spr_image02_data_mirror    ds 2
spr_image02_mask_mirror    ds 2
spr_image03_mask           ds 2
spr_image03_data_mirror    ds 2
spr_image03_mask_mirror    ds 2
* Billy climb frames — compiled
spr_bclimb1_mask           ds 2
spr_bclimb1_data_mirror    ds 2
spr_bclimb1_mask_mirror    ds 2
spr_bclimb2_mask           ds 2
spr_bclimb2_data_mirror    ds 2
spr_bclimb2_mask_mirror    ds 2
* Billy punch1 frames — compiled
spr_punch11_mask           ds 2
spr_punch11_data_mirror    ds 2
spr_punch11_mask_mirror    ds 2
spr_punch12_mask           ds 2
spr_punch12_data_mirror    ds 2
spr_punch12_mask_mirror    ds 2
* Billy punch2 frames — compiled
spr_punch21_mask           ds 2
spr_punch21_data_mirror    ds 2
spr_punch21_mask_mirror    ds 2
spr_punch22_mask           ds 2
spr_punch22_data_mirror    ds 2
spr_punch22_mask_mirror    ds 2
* Billy kick frames — compiled
spr_kick1_mask             ds 2
spr_kick1_data_mirror      ds 2
spr_kick1_mask_mirror      ds 2
spr_kick2_mask             ds 2
spr_kick2_data_mirror      ds 2
spr_kick2_mask_mirror      ds 2
* Billy jump frames — compiled
spr_jump1_mask             ds 2
spr_jump1_data_mirror      ds 2
spr_jump1_mask_mirror      ds 2
spr_jump2_mask             ds 2
spr_jump2_data_mirror      ds 2
spr_jump2_mask_mirror      ds 2
spr_jump3_mask             ds 2
spr_jump3_data_mirror      ds 2
spr_jump3_mask_mirror      ds 2
* Billy hit-reaction frame — compiled
spr_bpunched_mask          ds 2
spr_bpunched_data_mirror   ds 2
spr_bpunched_mask_mirror   ds 2

*----------------------------------------------------------
* Set ntp_open pathname pointer and ntp_bank before calling.
* First call uses default pathname (NTPPLAYER) and bank $0F.
*----------------------------------------------------------
 mx %11                ; emulation mode
load_ntp_file
 jsr $BF00
 dfb $C8              ; OPEN
 da ntp_open
 bcs :err
 lda ntp_oref
 sta ntp_rref
 sta ntp_cref

 lda #$00
 sta ntp_dest
 sta ntp_dest+1

:readlp
 jsr $BF00
 dfb $CA              ; READ
 da ntp_read
 bcs :close

 jsr ntp_copy_chunk

* Advance destination by $1000
 lda ntp_dest+1
 clc
 adc #$10
 sta ntp_dest+1
 bcc :readlp
* Address wrapped — next bank
 lda #$00
 sta ntp_dest+1
 inc ntp_bank
 bra :readlp

:close
 php
 jsr $BF00
 dfb $CC              ; CLOSE
 da ntp_close
 plp
:err rts

*----------------------------------------------------------
* ntp_copy_chunk - Copy 4KB from ]RDBUF to ntp_bank/ntp_dest
*----------------------------------------------------------
ntp_copy_chunk
 clc
 xce                   ; native mode
 rep $30
 mx %00                ; tell Merlin: 16-bit A and index

 lda ntp_dest
 sta $F0
 sep $20
 lda ntp_bank
 sta $F2
 rep $30

 ldy #$0000
 ldx #$0800            ; $1000/2 = $0800 word copies

:loop lda ]RDBUF,y
 sta [$F0],y
 iny
 iny
 dex
 bne :loop

 sec
 xce                   ; back to emulation mode
 rts

*----------------------------------------------------------
* NTP loader ProDOS 8 parameter blocks
*----------------------------------------------------------
ntp_dest ds 2
ntp_bank dfb $11       ; default bank (NTPPLAYER)

ntp_open dfb 3
 da ntpp_path          ; default pathname (NTPPLAYER)
 da ]IOBUF
ntp_oref dfb 0

ntp_read dfb 4
ntp_rref dfb 0
 da ]RDBUF
 da $1000
 ds 2                  ; transfer count

ntp_close dfb 1
ntp_cref dfb 0

ntpp_path dfb 17
 asc '/DDIIGS/NTPPLAYER'

m1ntp_path dfb 20
 asc '/DDIIGS/MISSION1.NTP'

mission1_path dfb 16
 asc '/DDIIGS/MISSION1'

*----------------------------------------------------------
* scroll_right - Scroll playfield 1 byte (2 pixels) right.
* 1) Shift bytes 1-110 left by one in bank $18 for 183 lines
* 2) Fill right edge from bank $51 (x_scroll_idx bytes)
* 3) Blit 110-byte wide playfield from $18 to $E1
* 4) Redraw sprite
*----------------------------------------------------------
scroll_right
* Scroll playfield 4 bytes (2 words, 8 pixels) to the left.
* Coarse NES-style scroll: shift in 16-bit mode, then fill
* the rightmost 4 bytes from the next screen's background.
*
* Phase 2 pipeline: turn shadowing OFF, stage the new playfield
* + sprite + overlay on $01 (without paying shadow tax on every
* byte), then turn shadowing ON and atomically propagate to $E1
* via push_band. $E1 keeps showing the previous frame's content
* throughout the staging window — no flicker-cover sprite redraw
* needed because $E1 is decoupled from $01 while shadow is off.
 jsr shadow_off

 lda x_scroll_idx
 clc
 adc #4
 sta x_scroll_idx

 clc
 xce                   ; native mode
 rep $30               ; 16-bit A, X, Y
 mx %00

* Step 1: Shift each scanline 4 bytes left in bank $18.
* Copy words from offset+4 to offset, 53 words (106 bytes).
 lda #$2004
 sta $F0               ; src = line_start + 4
 lda #$2000
 sta $F3               ; dst = line_start
 sep $20
 lda #$18
 sta $F2
 sta $F5
 rep $20

 ldx #183
:shift_line
 ldy #0
:shift_word
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy #106              ; 110 - 4 = 106 bytes to move
 bcc :shift_word

 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :shift_line

* Step 2: Fill rightmost 4 bytes (offsets 106-109) from
* the scroll source background in scroll_src_bank.
* off=108 → split via the proven :fill_split (2+2).
* off ∈ {107,109} → :fill_split_general (3+1 / 1+3) so we never
* read past byte 109 of the active 110-byte source window;
* without this, an odd scroll_src_off (e.g. 75 from a post-climb
* GS where up_count is odd) cycles to 107 and pulls a sidebar
* byte into playfield col 109 — visible as a 2px black column
* at the bank transition.
 sep $20
 mx %10
 lda scroll_src_off
 cmp #107
 beq :fsg_dispatch
 cmp #109
 beq :fsg_dispatch
 cmp #108
 bcc :fill_normal
 bne :fill_normal       ; src_off > 109 shouldn't happen, treat as normal
 jmp :fill_split        ; off == 108 → existing 2+2 split
:fsg_dispatch
 jmp :fill_split_general
:fill_normal
 rep $20
 mx %00
 lda scroll_src_off
 and #$00FF
 clc
 adc #$2000
 sta $F0               ; src = scroll_src_bank/(2000 + scroll_src_off)
 lda #$206A            ; dst = $18/(2000 + 106)
 sta $F3
 sep $20
 lda scroll_src_bank
 sta $F2
 lda #$18
 sta $F5
 rep $20

 ldy #0
 ldx #183
:fill_4
 lda [$F0],y           ; first word
 sta [$F3],y
 iny
 iny
 lda [$F0],y           ; second word
 sta [$F3],y
 ldy #0
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :fill_4

* Advance scroll source offset by 4 bytes
 sep $20
 mx %10
 lda scroll_src_off
 clc
 adc #4
 sta scroll_src_off
 cmp #110
* :fill_done is now out of range for a short branch, so invert
* the branch and use JMP for both paths.
 bcs :fn_wrap
 jmp :fill_done
:fn_wrap
 stz scroll_src_off
* Wrap cases:
*   a) scroll_src == current's bank — finished scrolling through
*      the current screen's own content; jump to scroll_right_
*      screen's bank.
*   b) scroll_src is some other bank (typically an rneighbor fill
*      from OP_UP :pos) AND scroll_right_screen points at a non-
*      adjacent screen — jump to scroll_right_screen's bank so
*      the narrow-target flow (e.g. scr12+scr11 → scr13) reaches
*      the intended next screen instead of falling into the bank
*      that happens to come after scroll_src numerically.
*   c) Otherwise (plain linear cascade) — inc scroll_src_bank.
 lda current_screen
 clc
 adc #$03
 cmp scroll_src_bank
 beq :fw_to_right_screen       ; case a
 lda scroll_right_screen
 beq :fw_linear                 ; no explicit target
 cmp current_screen
 beq :fw_linear                 ; target = current (no transition)
 clc
 adc #$03
 cmp scroll_src_bank
 beq :fw_linear                 ; already at target bank
 sta scroll_src_bank            ; case b: non-linear override
 bra :fw_wrap_done
:fw_to_right_screen
 lda scroll_right_screen
 clc
 adc #$03
 sta scroll_src_bank
 bra :fw_wrap_done
:fw_linear
 inc scroll_src_bank
:fw_wrap_done
 lda #1
 sta transition_pending     ; signal sync_current_screen
 jmp :fill_done

* Split fill: 2 bytes from current bank (offset 108-109),
* 2 bytes from next bank (offset 0-1).
:fill_split
 rep $20
 mx %00
* First pass: fill bytes 106-107 from current bank offset 108
 lda #$2000+108
 sta $F0
 lda #$206A            ; dst = $18/(2000+106)
 sta $F3
 sep $20
 lda scroll_src_bank
 sta $F2
 lda #$18
 sta $F5
 rep $20
 ldy #0
 ldx #183
:split_1
 lda [$F0],y
 sta [$F3],y
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :split_1
* Second pass: fill bytes 108-109 from NEXT bank offset 0.
* Same conditional as :fn_wrap — if scroll_src was on the
* current screen, transition to scroll_right_screen's bank;
* otherwise linear inc to the next screen.
 lda #$2000
 sta $F0
 lda #$206C            ; dst = $18/(2000+108)
 sta $F3
 sep $20
 lda current_screen
 clc
 adc #$03
 cmp scroll_src_bank
 bne :split_linear
 lda scroll_right_screen
 clc
 adc #$03
 sta scroll_src_bank
 bra :split_bank_done
:split_linear
 inc scroll_src_bank
:split_bank_done
 lda #1
 sta transition_pending     ; signal sync_current_screen
 lda scroll_src_bank
 sta $F2
 lda #$18
 sta $F5
 rep $20
 ldy #0
 ldx #183
:split_2
 lda [$F0],y
 sta [$F3],y
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :split_2
* Reset scroll source to offset 2 in the new bank
 sep $20
 mx %10
 lda #2
 sta scroll_src_off
 jmp :fill_done

* Generalized split for off ∈ {107, 109} only (108 uses the
* faster word-aligned :fill_split above). count_curr = 110-off
* (3 or 1) bytes from current bank starting at off, then
* count_next = 4-count_curr (1 or 3) bytes from the next bank
* starting at offset 0. Inner loop uses a dec-counter (`:fsg_curr`)
* so Y's width is irrelevant. Entry: 8-bit A/M, X 16-bit.
:fill_split_general
 lda scroll_src_off
 sta :fsg_off
 lda #110
 sec
 sbc :fsg_off
 sta :fsg_count1       ; count_curr (1 or 3)
 lda #4
 sec
 sbc :fsg_count1
 sta :fsg_count2       ; count_next (3 or 1)
* --- Phase 1 setup ---
 rep $20
 mx %00
 lda :fsg_off
 and #$00FF
 clc
 adc #$2000
 sta $F0               ; src = current_bank/(2000+off)
 lda #$206A            ; dst = $18/(2000+106)
 sta $F3
 sep $20
 mx %10
 lda scroll_src_bank
 sta $F2
 lda #$18
 sta $F5
 ldx #183
:fsg_p1_row
 lda :fsg_count1
 sta :fsg_curr
 ldy #0
:fsg_p1_byte
 lda [$F0],y
 sta [$F3],y
 iny
 dec :fsg_curr
 bne :fsg_p1_byte
 rep $20
 mx %00
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 sep $20
 mx %10
 dex
 bne :fsg_p1_row
* --- Advance bank (mirrors :fn_wrap: handles linear, scr_right
* target, and non-linear override cases) ---
 lda current_screen
 clc
 adc #$03
 cmp scroll_src_bank
 beq :fsg_to_right
 lda scroll_right_screen
 beq :fsg_linear
 cmp current_screen
 beq :fsg_linear
 clc
 adc #$03
 cmp scroll_src_bank
 beq :fsg_linear
 sta scroll_src_bank          ; non-linear override
 bra :fsg_bank_done
:fsg_to_right
 lda scroll_right_screen
 clc
 adc #$03
 sta scroll_src_bank
 bra :fsg_bank_done
:fsg_linear
 inc scroll_src_bank
:fsg_bank_done
 lda #1
 sta transition_pending
* --- Phase 2 setup: dst F3 = $18/(2000 + 106 + count_curr) ---
 lda #$6A
 clc
 adc :fsg_count1
 sta $F3
 lda #$20
 adc #0
 sta $F3+1
 rep $20
 mx %00
 lda #$2000
 sta $F0               ; src = new_bank/2000
 sep $20
 mx %10
 lda scroll_src_bank
 sta $F2
 lda #$18
 sta $F5
 ldx #183
:fsg_p2_row
 lda :fsg_count2
 sta :fsg_curr
 ldy #0
:fsg_p2_byte
 lda [$F0],y
 sta [$F3],y
 iny
 dec :fsg_curr
 bne :fsg_p2_byte
 rep $20
 mx %00
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 sep $20
 mx %10
 dex
 bne :fsg_p2_row
* scroll_src_off = count_next (next byte to pull in new bank).
 lda :fsg_count2
 sta scroll_src_off

:fill_done
 rep $20
 mx %00
* Lower-screen fill: for narrow-target scrolling (scr11/12/13),
* overwrite the rightmost 4 bytes of playfield rows 113..182
* with scr8 ($0B) content tracked by scr8_src_off. This keeps
* scr8 visible below the upper level as the player scrolls right.
 sep $20
 mx %10
 lda current_screen
 cmp #11
 bcc :sr_lower_skip
 cmp #14
 bcs :sr_lower_skip
 rep $20
 mx %00
 lda scr8_src_off
 cmp #107
 bcc :sr_lower_run      ; off <= 106 → 4-byte read stays in 0..109
 sec
 sbc #107               ; off >= 107 → would read past byte 109
 sta scr8_src_off       ; (invalid). Wrap to 0..106 so every read
                        ; is within scr8's valid byte range.
:sr_lower_run
 and #$00FF
 clc
 adc #$2000
 sta $F0                ; src = scr8/(2000 + scr8_src_off)
 lda #$670A             ; dst = $18/(2000 + 113*160 + 106)
 sta $F3
 sep $20
 mx %10
 lda #$0B               ; scr8 bank
 sta $F2
 lda #$18
 sta $F5
 rep $20
 mx %00
 ldx #70
:sr_lower_row
 ldy #0
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 lda [$F0],y
 sta [$F3],y
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :sr_lower_row
 sep $20
 mx %10
 lda scr8_src_off
 clc
 adc #4
 sta scr8_src_off
 lda scr8_src_off+1
 adc #0
 sta scr8_src_off+1
 rep $20
 mx %00
 bra :sr_lower_done
:sr_lower_skip
 rep $20
 mx %00
:sr_lower_done

* Step 3: Copy shifted playfield $18 -> $01. Shadow is OFF, so
* writes don't propagate to $E1 yet.
 jsr fast_blit_18_01

 sec
 xce                   ; back to emulation mode

* Step 4: Composite sprite + overlay directly on $01 (shadow off,
* no per-write tax).
 jsr draw_active_sprite
 jsr draw_overlay

* Step 5: Re-enable shadow and propagate the staged $01 to $E1
* via push_band over the full playfield (rows 0..182). Shadow
* stays ON after we return so game_loop's erase/draw operations
* propagate to $E1 in the normal way.
 clc
 xce                   ; native mode
 rep $30
 jsr shadow_on
 lda #0
 sep $20
 sta push_ymin
 lda #182
 sta push_ymax
 rep $20
 jsr push_band

 sec
 xce                   ; back to emulation mode
 rts

:fsg_off    ds 1        ; fill_split_general: saved scroll_src_off
:fsg_count1 ds 1        ; fill_split_general: count from current bank
:fsg_count2 ds 1        ; fill_split_general: count from next bank
:fsg_curr   ds 1        ; fill_split_general: per-row dec counter

*----------------------------------------------------------
* scroll_left - Mirror of scroll_right.
* Shift each scanline 4 bytes RIGHT in bank $18, then fill
* the leftmost 4 bytes (offsets 0-3) from the previous
* screen's source bank.
*----------------------------------------------------------
scroll_left
* Entry gate for narrow scr9:
*  - If current_screen=9 AND lsrc_off<4: Billy's already at scr9's
*    left edge, block further scroll (no loop, no bank-$0B pull).
*  - If current_screen != 9 AND lsrc_off<4: Billy just re-entered
*    scr9-left-scroll range (e.g. from scr8). Reset lsrc_off to 50
*    so the scroll pulls scr9's right edge again.
 lda scroll_left_screen
 cmp #9
 bne :sl_proceed
 lda scroll_lsrc_off
 cmp #4
 bcs :sl_proceed
 lda current_screen
 cmp #9
 bne :sl_reset_off
 rts
:sl_reset_off
 lda #50
 sta scroll_lsrc_off
:sl_proceed
* Phase 2 pipeline: shadow off while we stage on $01, then
* shadow on + push_band to atomically propagate to $E1. No
* flicker-cover needed because $E1 keeps showing the previous
* frame's content throughout the staging window.
 jsr shadow_off

 clc
 xce
 rep $30
 mx %00

* Step 1: Shift each scanline 4 bytes right in bank $18.
* Copy 53 words from offset 0..104 to offset 4..108.
* Iterate Y from 104 DOWN to 0 — negative Y would add ~$FFFE to
* the 24-bit pointer (lda [dp],y doesn't wrap within bank), so
* we keep Y non-negative and hold F0/F3 at the line's left edge.
 lda #$2000             ; src base = line_start + 0
 sta $F0
 lda #$2004             ; dst base = line_start + 4
 sta $F3
 sep $20
 lda #$18
 sta $F2
 sta $F5
 rep $20

 ldx #183
:lshift_line
 ldy #104               ; read offset 104 first, work down to 0
:lshift_word
 lda [$F0],y
 sta [$F3],y
 dey
 dey
 bpl :lshift_word       ; Y>=0 keeps looping; exits when Y=-2

 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :lshift_line

* Step 2: Fill leftmost 4 bytes (offsets 0-3) from the
* previous screen's source. Save old lsrc_off so state
* update at end can use it.
 sep $20
 mx %10
 lda scroll_lsrc_off
 sta :old_lo
 cmp #3
 bcc :lfill_split_jmp
 jmp :lfill_normal
:lfill_split_jmp

* ----- SPLIT FILL: old lsrc_off in {0, 1, 2} -----
* bytes_from_prev = 3 - old   (3, 2, 1)
* bytes_from_curr = 1 + old   (1, 2, 3)
* prev offset start = 110 - bytes_from_prev (107, 108, 109)
 lda #3
 sec
 sbc :old_lo
 sta :nfp
 lda #1
 clc
 adc :old_lo
 sta :nfc
 lda #110
 sec
 sbc :nfp
 sta :prev_start

* --- Split pass 1: copy nfp bytes from (lsrc_bank-1) ---
 rep $20
 mx %00
 lda :prev_start
 and #$00FF
 clc
 adc #$2000
 sta $F0
 lda #$2000
 sta $F3
 sep $30
 mx %11
 lda scroll_lsrc_bank
 sec
 sbc #1
 sta $F2
 lda #$18
 sta $F5
 ldx #183
:lspl_p_line
 ldy #0
:lspl_p_byte
 lda [$F0],y
 sta [$F3],y
 iny
 cpy :nfp
 bcc :lspl_p_byte
 rep $20
 mx %01
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 sep $20
 mx %11
 dex
 bne :lspl_p_line

* --- Split pass 2: copy nfc bytes from lsrc_bank to dest+nfp ---
 rep $20
 mx %01
 lda #$2000
 sta $F0
 lda :nfp
 and #$00FF
 clc
 adc #$2000
 sta $F3
 sep $20
 mx %11
 lda scroll_lsrc_bank
 sta $F2
 lda #$18
 sta $F5
 ldx #183
:lspl_c_line
 ldy #0
:lspl_c_byte
 lda [$F0],y
 sta [$F3],y
 iny
 cpy :nfc
 bcc :lspl_c_byte
 rep $20
 mx %01
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 sep $20
 mx %11
 dex
 bne :lspl_c_line

* State after split: lsrc_bank--, lsrc_off = old + 106
 dec scroll_lsrc_bank
 lda :old_lo
 clc
 adc #106
 sta scroll_lsrc_off
 rep $30
 mx %00
 jmp :lfill_done

* ----- NORMAL FILL: 4 bytes all in one bank -----
:lfill_normal
 rep $20
 mx %00
 lda scroll_lsrc_off
 and #$00FF
 sec
 sbc #3
 clc
 adc #$2000
 sta $F0
 lda #$2000
 sta $F3
 sep $20
 lda scroll_lsrc_bank
 sta $F2
 lda #$18
 sta $F5
 rep $20
 ldy #0
 ldx #183
:lfill_line
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 lda [$F0],y
 sta [$F3],y
 ldy #0
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :lfill_line

* State update: lsrc_off -= 4. Borrow handling:
*  - For narrow targets with no further left-neighbor (scr9),
*    disable scroll_left_enabled so the scroll stops cleanly
*    instead of falling into adjacent-bank garbage.
*  - For wide targets, wrap to 109 and decrement bank.
 sep $20
 mx %10
 lda scroll_lsrc_off
 sec
 sbc #4
 bcs :lno_under
 lda scroll_left_screen
 cmp #9
 bne :lunder_wide
* Narrow scr9 underflow: clamp off at 0 but leave
* scroll_left_enabled=1 so left-scroll from adjacent screens
* (e.g. scr8 → scr9) still works. The entry gate in scroll_left
* skips the shift when off<4, so no visual corruption.
 stz scroll_lsrc_off
 bra :lfill_done
:lunder_wide
 lda #109
 sta scroll_lsrc_off
 dec scroll_lsrc_bank
 bra :lfill_done
:lno_under
 sta scroll_lsrc_off

:lfill_done
 rep $30
 mx %00

* Steps 3-5: Phase 2 pipeline — same as scroll_right.
 jsr fast_blit_18_01
 sec
 xce
 jsr draw_active_sprite
 jsr draw_overlay
 clc
 xce
 rep $30
 jsr shadow_on
 lda #0
 sep $20
 sta push_ymin
 lda #182
 sta push_ymax
 rep $20
 jsr push_band
 sec
 xce
 rts

* scroll_left scratch
:old_lo     dfb 0
:nfp        dfb 0
:nfc        dfb 0
:prev_start dfb 0

*----------------------------------------------------------
* scroll_up - Vertical scroll: shift all rows DOWN by 4 in
* bank $18, then fill the top 4 rows from scroll_up_bank
* (the screen ABOVE) at scroll_up_off (counts down from 182).
* When scroll_up_off would go below 3, snap-transition: copy
* the entire source bank to $18 and update current_screen.
*----------------------------------------------------------
scroll_up
* Phase 2 pipeline: shadow off while we stage on $01. Both the
* incremental (:su_normal) and :snap_transition paths end with
* shadow_on + push_band to atomically propagate to $E1.
 jsr shadow_off

 lda scroll_up_off
 cmp #30              ; fire snap early so the last ~28 rows of
 bcs :su_normal       ; scroll don't show an invisible ladder gap
 jmp :snap_transition ; above the scr5 ladder-top art
:su_normal
* Apply pending golden state if OP_SNAPSTATE_DEFER queued one.
* Runs in emulation 8-bit mode (the inherited mode) so byte
* stores and load_screen_bounds work. Switches to native 16-bit
* afterward for the rest of :su_normal.
 lda pending_snap_flag
 bne :do_pending_snap
 jmp :no_pending_snap
:do_pending_snap
 lda pending_snap_buf+0
 sta world_offset
 lda pending_snap_buf+1
 sta world_offset+1
 lda pending_snap_buf+2
 sta abs_x
 lda pending_snap_buf+3
 sta abs_x+1
 lda pending_snap_buf+4
 sta IMAGE01_XPOS
 sta billy_sprite+2
 sta billy_sprite+34   ; prev_xpos = new xpos
 lda pending_snap_buf+5
 sta current_screen
 lda pending_snap_buf+6
 sta scroll_src_bank
 lda pending_snap_buf+7
 sta scroll_src_off
 lda pending_snap_buf+8
 sta scroll_lsrc_bank
 lda pending_snap_buf+9
 sta scroll_lsrc_off
 lda pending_snap_buf+10
 sta scroll_up_anchor
 lda pending_snap_buf+11
 sta scroll_up_anchor+1
 lda pending_snap_buf+12
 sta scroll_up_off
 lda pending_snap_buf+13
 sta scroll_min_wo
 lda pending_snap_buf+14
 sta scroll_min_wo+1
 lda pending_snap_buf+15
 sta scroll_max_wo
 lda pending_snap_buf+16
 sta scroll_max_wo+1
 lda current_screen
 jsr load_screen_bounds
* Repaint lower art so the visible playfield matches the canonical
* engine state. Two regions; each with its own bank/byte/count/dst.
* Region with bank=0 is skipped. Both regions paint 183 rows.
* Writes only to bank $18 (the playfield base); the
* fast_blit_18_01 + frame-end push_band at the end of scroll_up
* pushes $18→$01→$E1 atomically.
* --- Region 1 (offsets +17/+18/+19/+20) ---
 lda pending_snap_buf+17
 beq :skip_region1
 clc
 xce
 rep $30
 mx %00
 lda pending_snap_buf+18
 and #$00FF
 clc
 adc #$2000
 sta $F0
 lda pending_snap_buf+20
 and #$00FF
 clc
 adc #$2000
 sta $F3
 sep $20
 mx %10
 lda pending_snap_buf+17
 sta $F2
 lda #$18
 sta $F5
 lda pending_snap_buf+19
 sta :rg1_count
 rep $20
 mx %00
 ldx #183
:rg1_row
 ldy #0
:rg1_word
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy :rg1_count
 bcc :rg1_word
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :rg1_row
 sec
 xce
 mx %11
:skip_region1
* --- Region 2 (offsets +21/+22/+23/+24) ---
 lda pending_snap_buf+21
 beq :skip_region2
 clc
 xce
 rep $30
 mx %00
 lda pending_snap_buf+22
 and #$00FF
 clc
 adc #$2000
 sta $F0
 lda pending_snap_buf+24
 and #$00FF
 clc
 adc #$2000
 sta $F3
 sep $20
 mx %10
 lda pending_snap_buf+21
 sta $F2
 lda #$18
 sta $F5
 lda pending_snap_buf+23
 sta :rg2_count
 rep $20
 mx %00
 ldx #183
:rg2_row
 ldy #0
:rg2_word
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy :rg2_count
 bcc :rg2_word
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :rg2_row
 sec
 xce
 mx %11
:skip_region2
 stz pending_snap_flag
 bra :continue_pending
:rg1_count dw 0
:rg2_count dw 0
:continue_pending
:no_pending_snap
 clc
 xce
 rep $30
 mx %00

* First-call setup for scr12 climb: paint the FULL post-snap
* lower layout (scr9 right portion + all of scr8) across all 183
* rows, BEFORE Step 1's shift. Replaces pre-climb scr9+scr10
* with scr9[82..109] at cols [up_dst_start..up_dst_start+
* up_count-1] and scr8[0..81] at cols [up_dst_start+up_count..
* 109]. Mirrors snap_transition's lower-fill but for all rows so
* the climb animation shows the post-snap layout throughout.
* Cost ~100ms one-time at climb start.
 lda climb_started
 and #$00FF
 beq :ffs_check_screen
 jmp :ffs_done
:ffs_check_screen
 lda scroll_up_screen
 and #$00FF
 cmp #12
 beq :ffs_do
 jmp :ffs_done
:ffs_do
 sep $20
 lda #1
 sta climb_started
 rep $20
* compute_up_align populates up_src_start, up_count, up_dst_start
* from world_offset and scroll_up_anchor. Step 2 will call it
* again with the same inputs (no narrow pin for scr12 wide).
 jsr compute_up_align
 lda up_count
 bne :ffs_paint
 jmp :ffs_done
:ffs_paint
* --- scr9 fill: geometric position, NOT anchor-derived. scr9 covers
* world 220..329; for wo, scr9 byte (wo-220) sits at playfield col 0,
* and scr9 fills through col (329-wo) inclusive (= 330-wo bytes).
* This decouples the lower band from scr12's anchor so the relative
* alignment between scr12 (upper) and scr8/scr9 (lower) reflects the
* true world geometry rather than scr12's source-byte offset.
 lda world_offset
 sec
 sbc #220
 clc
 adc #$2000
 sta $F0                ; src = scr9 byte (wo-220)
 lda #$2000
 sta $F3                ; dst = col 0
 lda #330
 sec
 sbc world_offset
 sta :ffs_s9_count      ; count = 330 - wo (= scr9 visible bytes)
 sep $20
 lda #$0C               ; scr9 bank
 sta $F2
 lda #$18
 sta $F5
 rep $20
 ldx #183
:ffs_s9_row ldy #0
:ffs_s9_wrd lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy :ffs_s9_count
 bcc :ffs_s9_wrd
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :ffs_s9_row
* --- scr8 fill: scr8 covers world 330..439; for wo, scr8 byte 0
* sits at playfield col (330-wo), filling through col 109 (= wo-220
* bytes total, mirroring scr9's count). ---
 lda world_offset
 sec
 sbc #220
 sta :ffs_count         ; count = wo - 220 (= scr8 visible bytes)
 beq :ffs_s8_jmp_done
 lda #$2000
 sta $F0                ; src = scr8 byte 0
 lda #330
 sec
 sbc world_offset
 clc
 adc #$2000
 sta $F3                ; dst = col (330 - wo)
 sep $20
 lda #$0B               ; scr8 bank
 sta $F2
 lda #$18
 sta $F5
 rep $20
 ldx #183
:ffs_s8_row ldy #0
:ffs_s8_wrd lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy :ffs_count
 bcc :ffs_s8_wrd
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :ffs_s8_row
 bra :ffs_done
:ffs_s8_jmp_done
 jmp :ffs_done
:ffs_done

* Step 1: shift rows down by 4 in $18.
* Iterate from row 178 down to row 0, copying to row+4.
* Source addr starts at row 178: $2000 + 178*$A0 = $8F40
* Dest addr starts at row 182: $2000 + 182*$A0 = $91C0
 lda #$8F40
 sta $F0
 lda #$91C0
 sta $F3
 sep $20
 lda #$18
 sta $F2
 sta $F5
 rep $20

 ldx #179               ; row count: 179 rows to shift
:ushift_row
 ldy #0
:ushift_word
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy #110
 bcc :ushift_word

 lda $F0
 sec
 sbc #$00A0
 sta $F0
 lda $F3
 sec
 sbc #$00A0
 sta $F3
 dex
 bne :ushift_row

* Step 2: fill rows 0-3 from source (above) screen at off-3..off
 sep $20
 mx %10
 lda scroll_up_off
 sec
 sbc #3
 sta :ufill_top
 rep $20
 mx %00

* Compute src addr = $2000 + ufill_top * $A0
 lda :ufill_top
 and #$00FF
 sta :utmp
 asl
 asl                    ; *4
 clc
 adc :utmp              ; *5
 asl
 asl
 asl
 asl
 asl                    ; *160 = $A0
 clc
 adc #$2000
 sta $F0                ; F0 = scroll_up_bank/(2000 + (off-3)*$A0)
* Dynamic align: compute per-row offsets from world_offset.
* For narrow targets, temporarily pin world_offset to anchor (no
* +N offset) so the incremental fill renders scr12[0..51] at
* playfield[0..51] — same visual position as snap_transition.
* This matches what compute_up_align produces post-snap, so Billy
* sees the ladder art at the same playfield column throughout the
* climb and after. Engine wo_actual stays at its pre-climb value
* (so abs_x bookkeeping is preserved); the renderer just temporar-
* ily uses anchor as its world reference. The resulting 11-byte
* offset between engine_world_x and visual world_x is absorbed by
* a wider LADDER_TOL so collision still fires.
 lda scroll_up_twidth
 cmp #52
 bne :no_climb_pin
 lda world_offset
 sta :snap_wo_delta
 lda scroll_up_anchor
 sta world_offset
 jsr compute_up_align
 lda :snap_wo_delta
 sta world_offset
 bra :ufill_compute_done
:no_climb_pin
 jsr compute_up_align
:ufill_compute_done
 lda up_count
 beq :ufill_skip        ; no overlap — skip fill entirely
* Add up_src_start to F0
 lda $F0
 clc
 adc up_src_start
 sta $F0
* Set F3 = $18/(2000 + up_dst_start)
 lda #$2000
 clc
 adc up_dst_start
 sta $F3
 sep $20
 lda scroll_up_bank
 sta $F2
 lda #$18
 sta $F5
 rep $20

 ldx #4
:ufill_row
 ldy #0
:ufill_word
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy up_count
 bcc :ufill_word

 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :ufill_row
:ufill_skip

* Only fill the left gap if up_dst_start > 0 (target doesn't
* cover the leftmost bytes) AND a left-neighbor bank is set
* (scroll_up_lbank=0 is the sentinel for "$FF in OP_UP" =
* skip left fill).
 lda scroll_up_lbank
 and #$00FF
 beq :lgap_done
 lda up_dst_start
 beq :lgap_done
 lda :ufill_top
 and #$00FF
 sta :utmp
 asl
 asl
 clc
 adc :utmp
 asl
 asl
 asl
 asl
 asl                    ; row * 160
 clc
 adc #$2000
 clc
 adc scroll_up_lwidth
 sec
 sbc up_dst_start
 sta $F0                ; src = lbank/(2000 + row*$A0 + width - gap)
 lda #$2000
 sta $F3                ; dst = $18/$2000 (playfield row 0, byte 0)
 sep $20
 lda scroll_up_lbank
 sta $F2
 lda #$18
 sta $F5
 rep $20

 ldx #4
:lgap_row
 ldy #0
:lgap_word
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy up_dst_start
 bcc :lgap_word
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :lgap_row
:lgap_done

* Fill right gap from upper screen's right neighbor.
* If up_dst_start + up_count < 110, fill the remaining bytes
* from scroll_up_rbank's leftmost columns. Skip entirely if
* scroll_up_rbank=0 ($FF sentinel from OP_UP = no right fill).
 lda scroll_up_rbank
 and #$00FF
 beq :rgap_done
 lda up_dst_start
 clc
 adc up_count
 sta :rgap_start        ; first unfilled byte on right
 cmp #110
 bcs :rgap_done         ; no gap (filled to edge)
 lda #110
 sec
 sbc :rgap_start
 sta :rgap_count        ; bytes to fill from right neighbor
* Source: rbank/(2000 + (off-3)*$A0 + 0) — leftmost bytes
 lda :ufill_top
 and #$00FF
 sta :utmp
 asl
 asl
 clc
 adc :utmp
 asl
 asl
 asl
 asl
 asl
 clc
 adc #$2000
 sta $F0                ; src = rbank/(2000 + row*$A0)
* Dest: $18/(2000 + rgap_start)
 lda #$2000
 clc
 adc :rgap_start
 sta $F3
 sep $20
 lda scroll_up_rbank
 sta $F2
 lda #$18
 sta $F5
 rep $20
 ldx #4
:rgap_row
 ldy #0
:rgap_word
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy :rgap_count
 bcc :rgap_word
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :rgap_row
:rgap_done

* Decrement scroll_up_off by 4
 sep $20
 mx %10
 lda scroll_up_off
 sec
 sbc #4
 sta scroll_up_off
 rep $30
 mx %00

* Phase 2 pipeline: blit, composite on $01, push to $E1.
 jsr fast_blit_18_01
 sec
 xce
 jsr draw_active_sprite
 jsr draw_overlay
 clc
 xce
 rep $30
 jsr shadow_on
 lda #0
 sep $20
 sta push_ymin
 lda #182
 sta push_ymax
 rep $20
 jsr push_band
 sec
 xce
 rts

*----------------------------------------------------------
* :snap_transition - End of vertical scroll: copy source
* screen entirely to $18 and update current_screen.
*----------------------------------------------------------
:snap_transition
* DEBUG: 'SN WO=wwww AX=aaaa' — world_offset and abs_x at snap
* entry, before compute_up_align pins or xpos fix runs. Paired
* with the 'UP' print to show (a) wo at OP_UP time, (b) wo at
* snap time; they should be identical (no input during climb)
* and they should match what the compensation constants assume.
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$CE              ; 'N'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda #$D7              ; 'W'
 jsr dbg_print_char
 lda #$CF              ; 'O'
 jsr dbg_print_char
 lda #$BD              ; '='
 jsr dbg_print_char
 lda world_offset+1
 jsr dbg_print_hex8
 lda world_offset
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$C1              ; 'A'
 jsr dbg_print_char
 lda #$D8              ; 'X'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 lda abs_x+1
 jsr dbg_print_hex8
 lda abs_x
 jsr dbg_print_hex8
 jsr dbg_print_nl
 clc
 xce
 rep $30
 mx %00
* For narrow targets (scr11/12/13): temporarily pin world_offset
* to scroll_up_anchor around the compute call, then restore.
* src_start=0 shifts snap art 1 byte right of its previous
* position (+1 pin), addressing "2px left at snap".
* We're in mx %00 (16-bit A), so a single sta writes both bytes.
 lda scroll_up_twidth
 cmp #52
 bne :snap_no_pin
 lda world_offset
 sta :snap_wo_delta
 lda scroll_up_anchor
 sta world_offset
 jsr compute_up_align
 lda :snap_wo_delta
 sta world_offset
 bra :snap_compute_done
:snap_no_pin
 jsr compute_up_align
:snap_compute_done
* DEBUG: one-line dump of world_offset / anchor / up_dst_start at
* snap time so we can see whether the post-snap position drifts
* run-to-run. Switch to emulation to use ROM COUT, then restore
* native 16-bit mode for the rest of snap_transition.
 sec
 xce
 mx %11
 lda #$D7              ; 'W'
 jsr dbg_print_char
 lda #$CF              ; 'O'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda world_offset+1
 jsr dbg_print_hex8
 lda world_offset
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$C1              ; 'A'
 jsr dbg_print_char
 lda #$CE              ; 'N'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda scroll_up_anchor+1
 jsr dbg_print_hex8
 lda scroll_up_anchor
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$C4              ; 'D'
 jsr dbg_print_char
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda up_dst_start+1
 jsr dbg_print_hex8
 lda up_dst_start
 jsr dbg_print_hex8
 jsr dbg_print_nl
 clc
 xce
 rep $30
 mx %00
* Clear the left gap (cols 0..up_dst_start-1) at rows 0..snap_copy_rows-1
* to zero, so stale shifted-down pre-climb content doesn't show through
* in the area exposed by the nudge. Only when lbank=0 (no left neighbor)
* and up_dst_start > 0. The following scr12 copy will overwrite any
* odd-byte overshoot (we write words) at col up_dst_start.
 lda scroll_up_lbank
 and #$00FF
 bne :snap_clr_done
 lda up_dst_start
 beq :snap_clr_done
 lda #$2000
 sta $F3
 sep $20
 lda #$18
 sta $F5
 rep $20
 ldx snap_copy_rows
:snap_clr_row
 ldy #0
 lda #$0000
:snap_clr_word
 sta [$F3],y
 iny
 iny
 cpy up_dst_start
 bcc :snap_clr_word
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :snap_clr_row
:snap_clr_done
 lda up_count
 beq :snap_skip_copy
* Setup pointers (apply offsets)
 lda #$2000
 clc
 adc up_src_start
 sta $F0                ; src = scroll_up_bank/(2000 + up_src_start)
 lda #$2000
 clc
 adc up_dst_start
 sta $F3                ; dst = $18/(2000 + up_dst_start)
 sep $20
 lda scroll_up_bank
 sta $F2
 lda #$18
 sta $F5
 rep $20
 ldx snap_copy_rows   ; 183 default, 113 for narrow targets
:srow ldy #0
:swrd lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy up_count
 bcc :swrd
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :srow
:snap_skip_copy

* Only fill left gap in snap if up_dst_start > 0 AND an lbank
* is set (scroll_up_lbank=0 sentinel skips).
 lda scroll_up_lbank
 and #$00FF
 beq :snap_lgap_done
 lda up_dst_start
 beq :snap_lgap_done
 lda #$2000
 clc
 adc scroll_up_lwidth
 sec
 sbc up_dst_start       ; src = lbank/(2000 + width - gap)
 sta $F0
 lda #$2000
 sta $F3                ; dst = $18/2000
 sep $20
 lda scroll_up_lbank
 sta $F2
 lda #$18
 sta $F5
 rep $20
 ldx snap_copy_rows
:snap_lgrow ldy #0
:snap_lgwrd lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy up_dst_start
 bcc :snap_lgwrd
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :snap_lgrow
:snap_lgap_done

* Fill right gap in snap from upper screen's right neighbor.
* Skip entirely if scroll_up_rbank=0 ($FF sentinel).
 lda scroll_up_rbank
 and #$00FF
 beq :snap_rgap_done
 lda up_dst_start
 clc
 adc up_count
 sta :rgap_start
 cmp #110
 bcs :snap_rgap_done
 lda #110
 sec
 sbc :rgap_start
 sta :rgap_count
 lda #$2000
 sta $F0                ; src = rbank/(2000) — leftmost bytes
 lda #$2000
 clc
 adc :rgap_start
 sta $F3
 sep $20
 lda scroll_up_rbank
 sta $F2
 lda #$18
 sta $F5
 rep $20
 ldx snap_copy_rows
:snap_rgrow ldy #0
:snap_rgwrd lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy :rgap_count
 bcc :snap_rgwrd
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :snap_rgrow
:snap_rgap_done

* Lower-screen fill: after a short (113-row-tall) target copy,
* fill the remaining 70 playfield rows (113..182) from scr9 + scr8,
* using GEOMETRIC per-screen world origins (mirrors FFS during-climb).
* scr9 covers world 220..329; scr8 covers world 330..439. For wo=296,
* scr9 byte 76 lands at col 0 (count 34), scr8 byte 0 lands at col 34
* (count 76). Decoupling from scr12's anchor keeps the lower band
* aligned across the during-climb / post-snap boundary.
 lda scroll_up_screen
 and #$00FF
 cmp #12
 beq :snap_lower_go
 jmp :snap_lower_done
:snap_lower_go
* scr9 fill — src = scr9 byte (wo-220), dst = col 0,
* count = 330 - wo (visible scr9 bytes).
 lda world_offset
 sec
 sbc #220
 clc
 adc #$2000
 sta $F0               ; src = scr9 byte (wo-220)
 lda #$66A0
 sta $F3               ; dst = $18/(row 113, col 0)
 lda #330
 sec
 sbc world_offset
 sta :snap_lo_s9_count ; count = 330 - wo
 beq :snap_lo_s9_done
 sep $20
 lda #$0C              ; scr9 bank
 sta $F2
 lda #$18
 sta $F5
 rep $20
 ldx #70
:snap_drow ldy #0
:snap_dwrd lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy :snap_lo_s9_count
 bcc :snap_dwrd
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :snap_drow
:snap_lo_s9_done
* scr8 lower fill — src = scr8 byte 0, dst = col (330-wo),
* count = wo - 220 (visible scr8 bytes).
 lda world_offset
 sec
 sbc #220
 sta :lower_rgap_count ; count = wo - 220
 beq :no_scr8_fill
 lda #$2000
 sta $F0               ; src = scr8 byte 0
 lda #330
 sec
 sbc world_offset
 clc
 adc #$66A0
 sta $F3               ; dst = $18/(row 113, col 330-wo)
 sep $20
 lda #$0B               ; scr8 bank
 sta $F2
 lda #$18
 sta $F5
 rep $20
 ldx #70
:snap_dr_row ldy #0
:snap_dr_wrd lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy :lower_rgap_count
 bcc :snap_dr_wrd
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :snap_dr_row
* Initialize scr8_src_off so subsequent scroll_right lower-fill
* picks up where this snap left off.
 lda :lower_rgap_count
 sta scr8_src_off
 stz scr8_src_off+1
 bra :snap_lower_done
:no_scr8_fill
 stz scr8_src_off
 stz scr8_src_off+1
:snap_lower_done

 sec
 xce
* Update current_screen and bank state.
* scroll_src must reflect what's NEXT to bring in on right-scroll:
*
* :pos case (up_dst_start=0, up_src_start>0): the snap already
* filled the rightmost up_src_start bytes of the playfield with
* scroll_up_rbank bytes 0..up_src_start-1 (rgap fill). The next
* byte to pull is scroll_up_rbank[up_src_start] — so scroll_src
* points at the right-neighbor bank continuing from where the
* rgap left off.
*
* :neg case (up_dst_start>0, up_src_start=0): the playfield's
* right portion shows scroll_up_bank bytes 0..up_count-1. There
* are still (110 - up_count) unseen bytes of the current upper
* screen to scroll through before we should transition to the
* right neighbor. scroll_src must point at scroll_up_bank with
* off=up_count so scroll_right continues revealing the upper
* screen first. The wrap at scroll_src_off=110 will then pick
* up scroll_right_screen's bank (via the scroll_right_screen+3
* wrap logic) for the eventual transition to the right neighbor.
 lda scroll_up_screen
 sta current_screen
 stz scroll_up_enabled
 jsr load_screen_bounds     ; needs A = screen index — call before inc_border
 jsr inc_border             ; new screen scrolled in (vertical)
 lda up_dst_start
 beq :snap_pos_src       ; dst_start=0 means :pos or :no_overlap
 lda scroll_up_bank
 sta scroll_src_bank
 lda up_count
 sta scroll_src_off
 bra :snap_src_done
:snap_pos_src
* rgap just filled scroll_up_rbank bytes 0..(110-up_count-1) at
* playfield's right. Next byte to pull on scroll_right is byte
* (110 - up_count) of rbank.
 lda scroll_up_rbank
 sta scroll_src_bank
 lda #110
 sec
 sbc up_count
 sta scroll_src_off
:snap_src_done
 lda current_screen
 beq :snap_no_left
 clc
 adc #$02              ; lsrc = $03 + (cs-1) = $02 + cs
 sta scroll_lsrc_bank
 lda #109
 sta scroll_lsrc_off
 bra :snap_lsrc_check_lbank
:snap_no_left
 lda #$03
 sta scroll_lsrc_bank
 stz scroll_lsrc_off
:snap_lsrc_check_lbank
* If OP_UP supplied an explicit left-neighbor (scroll_up_lbank
* set, sentinel 0 = no lbank), use it instead of the linear
* fallback. The lgap fill above just painted lbank bytes
* (lwidth - up_dst_start)..(lwidth - 1) at cols 0..(up_dst_start-1),
* so set lsrc_off = lwidth - up_dst_start - 1: the next byte to
* pull on left-scroll continues seamlessly from the lgap.
* CPU is in emulation 8-bit here (sec/xce above + load_screen_bounds
* returns in emul); no mode switching needed.
 lda scroll_up_lbank
 beq :snap_loaded         ; sentinel 0 = no lbank, keep linear
 ldx up_dst_start
 beq :snap_loaded         ; no lgap painted → keep linear
 sta scroll_lsrc_bank
 lda scroll_up_lwidth
 sec
 sbc up_dst_start
 sec
 sbc #1
 sta scroll_lsrc_off
:snap_loaded
* Reposition player to the upper screen's walkable area.
* Prefer Billy's current ypos (his climb-end position during
* scroll); bump by 16 to compensate for the BCLIMB→IMAGE01
* anchor shift. Only apply the bump if both the original ypos
* and the bumped ypos land in walkable rows on the new screen.
* Otherwise fall back to scanning from the bottom without a bump.
 lda IMAGE01_YPOS
 tax
 lda bounds_tbl_hi,x
 beq :sl_scan           ; current ypos blocked → scan
 txa
 clc
 adc #16                ; tentative bumped ypos
 tax
 lda bounds_tbl_hi,x
 bne :found_floor       ; bumped ypos still walkable → use it
:sl_scan
 ldx #199
:find_floor
 lda bounds_tbl_hi,x   ; max_x for row X
 bne :found_floor       ; non-zero = walkable
 dex
 bne :find_floor
:found_floor
 txa
 sta IMAGE01_YPOS       ; update global for draw_sprite
* Also write to sprite info block so it persists after load_sprite
 ldy #0
 sta (info_ptr),y       ; +0 ypos
 ldy #32
 sta (info_ptr),y       ; +32 prev_ypos
 ldy #30
 lda #$03
 sta (info_ptr),y       ; dirty = erase+draw
* Reset Billy out of the climb animation into idle (IMAGE01).
* Copy idle_addr/idle_x/idle_y (info+42/44/46) into
* frame_addr/frame_x/frame_y (info+14/10/12) and sync globals.
 ldy #42
 lda (info_ptr),y       ; idle_addr low
 sta FRAME_ADDR
 ldy #14
 sta (info_ptr),y
 ldy #43
 lda (info_ptr),y       ; idle_addr high
 sta FRAME_ADDR+1
 ldy #15
 sta (info_ptr),y
 ldy #44
 lda (info_ptr),y       ; idle_x
 sta FRAME_X
 ldy #10
 sta (info_ptr),y
 ldy #46
 lda (info_ptr),y       ; idle_y
 sta FRAME_Y
 ldy #12
 sta (info_ptr),y
* Restore compiled MASK_ADDR + override FRAME_ADDR with the mirror
* variant if Billy is facing left. Without this, FRAME_ADDR is the
* compiled IMAGE01_DATA but MASK_ADDR was cleared by advance_climb,
* so dispatch routes to legacy and the $00 transparency slots in
* the compiled data render as opaque black ("box around Billy" at
* the top of the ladder).
 lda IMAGE01_MIRROR
 bne :st_mirror
 lda spr_image01_mask
 sta MASK_ADDR
 sta billy_sprite+52
 lda spr_image01_mask+1
 sta MASK_ADDR+1
 sta billy_sprite+53
 bra :st_mask_done
:st_mirror
 lda spr_image01_data_mirror
 sta FRAME_ADDR
 sta billy_sprite+14
 lda spr_image01_data_mirror+1
 sta FRAME_ADDR+1
 sta billy_sprite+15
 lda spr_image01_mask_mirror
 sta MASK_ADDR
 sta billy_sprite+52
 lda spr_image01_mask_mirror+1
 sta MASK_ADDR+1
 sta billy_sprite+53
:st_mask_done
 stz climb_toggle       ; next climb starts on BCLIMB1
* Disable the ladder Billy just climbed by locating it from his
* current world_x and setting y_top=255 so check_ladder fails
* for any proposed y. Prevents re-climbing "invisible" after snap.
 lda ladder_count
 bne :dl_have
 jmp :dl_done          ; no ladders — skip scan; far branch
:dl_have
 sta :dl_cnt
 clc
 lda IMAGE01_XPOS
 adc world_offset
 sta :dl_wx
 lda #0
 adc world_offset+1
 sta :dl_wx+1
 ldx #0
:dl_scan
 lda :dl_wx+1
 cmp ladder_buf+1,x    ; x_left high
 bcc :dl_next
 bne :dl_ge_lf
 lda :dl_wx
 cmp ladder_buf,x      ; x_left low
 bcc :dl_next
:dl_ge_lf
 lda ladder_buf+3,x    ; x_right high
 cmp :dl_wx+1
 bcc :dl_next
 bne :dl_le_rt
 lda ladder_buf+2,x    ; x_right low
 cmp :dl_wx
 bcc :dl_next
:dl_le_rt
 lda #255
 sta ladder_buf+4,x    ; y_top = 255 → ladder disabled
* Narrow-target canonicalization: the snap's compute_up_align
* above pinned wo=scroll_up_anchor, so scr12 was drawn starting
* at playfield[0]. The engine must also believe wo=anchor for
* the drawn art to agree with future scrolls. Snap wo to anchor
* and teleport Billy to the ladder's world-x center; keep
* abs_x consistent (abs_x := ladder_center).
*
* Supersedes the old +10 xpos fix and all wo-dependence in the
* post-snap state. Result is deterministic regardless of the
* player's approach path on the source screen: after a narrow-
* target ladder climb, wo, xpos, and abs_x always land on the
* same values computed from the ladder's own world coords.
*
* X currently indexes the matched ladder in ladder_buf.
 lda scroll_up_twidth
 cmp #52
 bne :dl_done
* ladder_center = (x_left + x_right) / 2, 16-bit
 clc
 lda ladder_buf,x       ; x_left low
 adc ladder_buf+2,x     ; x_right low
 sta :ldr_ctr
 lda ladder_buf+1,x     ; x_left high
 adc ladder_buf+3,x     ; x_right high
 sta :ldr_ctr+1
 lsr :ldr_ctr+1
 ror :ldr_ctr
* world_offset := scroll_up_anchor
 lda scroll_up_anchor
 sta world_offset
 lda scroll_up_anchor+1
 sta world_offset+1
* IMAGE01_XPOS := ladder_center - anchor - 4 (sprite half-width
* compensation so Billy's visual center sits on scr12_center,
* matching the mid-climb formula).
 sec
 lda :ldr_ctr
 sbc scroll_up_anchor
 sec
 sbc #4
 sta IMAGE01_XPOS
 ldy #2
 sta (info_ptr),y       ; billy_sprite+2
 ldy #34
 sta (info_ptr),y       ; prev_xpos = new xpos → no ghost erase
* abs_x := ladder_center - 4 (== world_offset + IMAGE01_XPOS)
 sec
 lda :ldr_ctr
 sbc #4
 sta abs_x
 lda :ldr_ctr+1
 sbc #0
 sta abs_x+1
 bra :dl_done
:dl_next
 txa
 clc
 adc #6
 tax
 dec :dl_cnt
 beq :dl_done
 jmp :dl_scan          ; far branch — :dl_le_rt block now too large
:dl_done
* scr12 (ladder3) post-snap nudge removed. The old +2 was
* calibrated for ladder_buf center=373; with center=362 the
* ladder data is now aligned to Billy's natural xpos, and the
* climb-snap is skipped above, so no post-climb adjustment is
* needed. Any nudge here would be a visible teleport.

* Phase 2 pipeline: blit, composite on $01, push to $E1.
 clc
 xce
 rep $30
 mx %00
 jsr fast_blit_18_01
 sec
 xce
 jsr draw_active_sprite
 jsr draw_overlay
 clc
 xce
 rep $30
 jsr shadow_on
 lda #0
 sep $20
 sta push_ymin
 lda #182
 sta push_ymax
 rep $20
 jsr push_band
 sec
 xce
 rts

* scroll_up scratch — must be 2 bytes since 16-bit stores
* land here.
:ufill_top ds 2
:utmp      ds 2
:rgap_start ds 2
:rgap_count ds 2
:lgap_base  ds 2
:dl_wx     ds 2         ; disable-ladder: Billy's world_x at snap
:dl_cnt    ds 1         ; disable-ladder: iteration counter
:ldr_ctr   ds 2         ; narrow-target snap: matched ladder's center
:lower_rgap_count ds 2  ; lower-fill scr8: bytes-per-row count
:snap_lo_s9_count ds 2  ; snap_lower scr9: bytes-per-row count (geometric)
:ffs_count ds 2         ; first-fill scr8 (scr10 region) byte count
:ffs_dst   ds 2         ; first-fill scr8 (scr10 region) dst column
:ffs_s9_count ds 2      ; first-fill scr9 byte count (geometric)
:snap_wo_delta ds 2     ; narrow-target snap: world_offset - anchor

up_src_start ds 2       ; source byte offset within upper screen scanline
up_dst_start ds 2       ; dest byte offset within playfield scanline
up_count     ds 2       ; bytes per row to copy (0 = skip)

*----------------------------------------------------------
* compute_up_align - Compute src/dst/count for upper-screen
* fill based on world_offset. Sets up_src_start, up_dst_start,
* up_count. Call in native mode 16-bit A.
*
*   src_byte(P) = world_offset + P - UP_X_ANCHOR
*
* If src_byte < 0 at P=0:  src_start=0, dst_start=-src_byte
* If src_byte > 109 at P=0: count=0 (off the right edge)
* Else: src_start=src_byte, dst_start=0
* count = min(110-src_start, 110-dst_start)
*----------------------------------------------------------
compute_up_align
 mx %00                 ; tell Merlin: 16-bit A on entry
* Dynamic placement: compute src/dst/count from world_offset vs
* scroll_up_anchor so the target screen (incl. scr10) tracks
* horizontal scroll and keeps its ladder art aligned with the
* source screen's ladder regardless of world_offset.
:cua_compute
 lda world_offset
 sec
 sbc scroll_up_anchor
 sta up_src_start       ; signed 16-bit
 bpl :pos
* Negative src_start: dst_start = -src_start, src_start = 0
 eor #$FFFF
 inc                    ; A = -A
 sta up_dst_start
 cmp #110
 bcs :no_overlap        ; player too far left of target
 stz up_src_start
* count = min(twidth, 110 - dst_start): fill to playfield's
* right edge, but no further than the target's real width.
 lda #110
 sec
 sbc up_dst_start
 cmp scroll_up_twidth
 bcc :neg_set           ; 110-dst_start < twidth
 lda scroll_up_twidth
:neg_set
 sta up_count
 rts
:pos
* src_start >= 0. cmp twidth: if src_start >= twidth, we've
* scrolled past the target's content entirely.
 cmp scroll_up_twidth
 bcs :no_overlap
 stz up_dst_start
* count = twidth - src_start (= remaining target bytes).
 lda scroll_up_twidth
 sec
 sbc up_src_start
 sta up_count
 rts
:no_overlap
 stz up_count
 rts
 mx %11                 ; restore default for following code

*----------------------------------------------------------
* push_ymin / push_ymax - Inputs to push_band, naming the
* inclusive row range it operates on. Set before each call.
push_ymin dfb 0
push_ymax dfb 0

*----------------------------------------------------------
* push_band - Atomically propagate rows [push_ymin..push_ymax]
* of bank $01 to $E1 by re-writing the rows onto themselves
* through the WrCardRAM-redirected stack. Shadowing must be ON
* at entry; the PHA writes go to bank $01 (via the redirect)
* and the shadow engine mirrors them to $E1.
*
* Same PHA-blit trick used historically by stack_blit_55_e1, but
* the source is $01 (which the caller has staged with shadow OFF
* before calling shadow_on + push_band).
*
* Entry: native mode, REP $30 (16-bit A/X/Y).
* Trashes A/X/Y; SP restored.
*----------------------------------------------------------
push_band
 rep $30
 tsc
 sta :pb_save_s

* Compute X = push_ymin * $A0 and Y = row count BEFORE enabling
* WrCardRAM. Once $C005 is set, ANY bank-$00 store in $0200-$BFFF
* gets redirected to bank $01 — so :pb_tmp would corrupt the SHR
* display at $5FCC (row 102, bytes 12-13) and the read-back would
* return stale bank-$00 data, throwing off the row offset entirely.
 sep $20
 lda push_ymin
 rep $20
 and #$00FF
 asl
 asl
 asl
 asl
 asl                   ; *32
 sta :pb_tmp
 asl
 asl                   ; *128
 clc
 adc :pb_tmp           ; *160
 tax

 sep $20
 lda push_ymax
 sec
 sbc push_ymin
 clc
 adc #1
 rep $20
 and #$00FF
 tay

* Now safe to enable WrCardRAM — no more bank-$00 stores until restore.
 sei
 sep $20
 sta $C005             ; WrCardRAM: bank-$00 stack writes → $01
 rep $20

:pb_line
 txa
 clc
 adc #$206D            ; S = $2000 + line_offset + 109
 tcs

]idx = 108
 LUP 55
 LDAL $012000+]idx,x
 pha
]idx = ]idx-2
 --^

 txa
 clc
 adc #$00A0
 tax
 dey
 beq :pb_done
 jmp :pb_line

:pb_done
 sep $20
 sta $C004             ; WrMainRAM: restore
 rep $20

 lda :pb_save_s
 tcs
 cli
 rts

:pb_save_s ds 2
:pb_tmp    ds 2

*----------------------------------------------------------
* fast_blit_18_01 - Unrolled blit from $18 to $01. Caller must
* have shadowing OFF before calling (otherwise each STAL pays
* the shadow tax, ~3-4× slowdown). 110 bytes × 183 lines.
* Entry: native mode, REP $30 (16-bit A/X/Y).
*----------------------------------------------------------
fast_blit_18_01
 rep $30
 ldx #0
 ldy #183

:f1801_line
]idx = 108
 LUP 55
 LDAL $182000+]idx,x
 STAL $012000+]idx,x
]idx = ]idx-2
 --^

 txa
 clc
 adc #$00A0
 tax
 dey
 beq :f1801_done
 jmp :f1801_line
:f1801_done rts

*----------------------------------------------------------
* shadow_off - Disable SHR shadowing ($01 → $E1 mirror) so writes
* to bank $01 don't pay the ~6-cycle slow-RAM tax that the shadow
* engine adds. Pair with shadow_on + push_band to atomically
* propagate the staged $01 to $E1 at end of frame / scroll.
*
* Saves and restores the M flag so the helper is safe to call
* from either 8-bit or 16-bit accumulator contexts. The X flag
* is left alone (we never touch X/Y here).
*----------------------------------------------------------
shadow_off
 php                   ; preserve M
 sep #$20              ; force 8-bit A
 ldal $C035
 ora #$08              ; set bit 3 → shadowing OFF
 stal $C035
 plp                   ; restore M
 rts

*----------------------------------------------------------
* shadow_on - Re-enable SHR shadowing.
*----------------------------------------------------------
shadow_on
 php
 sep #$20
 ldal $C035
 and #$F7              ; clear bit 3 → shadowing ON
 stal $C035
 plp
 rts

 mx %11                ; following routines run in emulation mode (8-bit)

*----------------------------------------------------------
* Text-screen diagnostic helpers (use Apple //e ROM routines
* via JSR $FDED/$FC58). Text screen persists behind SHR so
* KEGS "Copy Text Screen" can capture these messages.
* All helpers preserve A/X/Y. Caller must be in emulation
* mode with 8-bit A/X/Y.
*----------------------------------------------------------
dbg_print_char
 pha
 phx
 phy
 jsr $FDED
 ply
 plx
 pla
 rts

dbg_print_nl
 pha
 lda #$8D
 jsr $FDED
 pla
 rts

* Print nibble in low 4 bits of A as hex char with hi bit set.
dbg_print_nib
 and #$0F
 cmp #$0A
 bcc :dpn_digit
 clc
 adc #$B7            ; 10→'A' ($C1), 15→'F' ($C6)
 bra :dpn_out
:dpn_digit
 clc
 adc #$B0            ; 0→'0' ($B0), 9→'9' ($B9)
:dpn_out
 jsr $FDED
 rts

* Print byte in A as two hex digits. Preserves A/X/Y.
dbg_print_hex8
 pha
 phx
 phy
 pha
 lsr
 lsr
 lsr
 lsr
 jsr dbg_print_nib
 pla
 jsr dbg_print_nib
 ply
 plx
 pla
 rts

*----------------------------------------------------------
* dbg_golden_state - Print 3-line state snapshot for ladder
* alignment / drift debugging. Triggered by 'g' key in
* process_input. Captures all state needed to characterize
* a position before/after a ladder climb:
*
*   Line 1 (world position):  GS1 wo aa xp cs
*     wo = world_offset (16-bit)
*     aa = abs_x (16-bit)
*     xp = IMAGE01_XPOS (8-bit)
*     cs = current_screen (8-bit)
*
*   Line 2 (scroll source state):  GS2 sb so lb lo
*     sb = scroll_src_bank (8-bit) — next bank for right-scroll
*     so = scroll_src_off (8-bit)  — next offset within sb
*     lb = scroll_lsrc_bank (8-bit) — left-scroll bank
*     lo = scroll_lsrc_off (8-bit)  — left-scroll offset
*
*   Line 3 (up-scroll + script clamps):  GS3 ua uo mn mx
*     ua = scroll_up_anchor (16-bit) — last OP_UP target's anchor
*     uo = scroll_up_off (8-bit)
*     mn = scroll_min_wo (16-bit)
*     mx = scroll_max_wo (16-bit)
*
* Emulation mode, 8-bit A/X/Y. Preserves no state (just dumps).
*----------------------------------------------------------
dbg_golden_state
* --- Line 1: GS1 wo=WWWW ax=AAAA xp=XX cs=CC ---
 lda #$C7              ; 'G'
 jsr dbg_print_char
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$B1              ; '1'
 jsr dbg_print_char
 lda #$A0              ; ' '
 jsr dbg_print_char
 lda world_offset+1
 jsr dbg_print_hex8
 lda world_offset
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda abs_x+1
 jsr dbg_print_hex8
 lda abs_x
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda IMAGE01_XPOS
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda current_screen
 jsr dbg_print_hex8
 jsr dbg_print_nl
* --- Line 2: GS2 sb=BB so=OO lb=BB lo=OO ---
 lda #$C7              ; 'G'
 jsr dbg_print_char
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$B2              ; '2'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda scroll_src_bank
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda scroll_src_off
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda scroll_lsrc_bank
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda scroll_lsrc_off
 jsr dbg_print_hex8
 jsr dbg_print_nl
* --- Line 3: GS3 ua=AAAA uo=OO mn=NNNN mx=XXXX ---
 lda #$C7              ; 'G'
 jsr dbg_print_char
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$B3              ; '3'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda scroll_up_anchor+1
 jsr dbg_print_hex8
 lda scroll_up_anchor
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda scroll_up_off
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda scroll_min_wo+1
 jsr dbg_print_hex8
 lda scroll_min_wo
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda scroll_max_wo+1
 jsr dbg_print_hex8
 lda scroll_max_wo
 jsr dbg_print_hex8
 jsr dbg_print_nl
 rts

*----------------------------------------------------------
* assert_abs_x - Verify abs_x == world_offset + billy_sprite.xpos.
* Reads xpos directly from billy_sprite+2, NOT the global
* IMAGE01_XPOS. update_anims iterates sprite_table through
* load_sprite and leaves IMAGE01_XPOS holding whichever sprite
* was last loaded (typically an NPC). billy_sprite+2 is the
* player's canonical xpos; all mutating paths write it through
* save_sprite when info_ptr is the player block.
* Halts with a text-screen diagnostic if the invariant breaks.
* Emulation mode, 8-bit A/X/Y.
*----------------------------------------------------------
assert_abs_x
 clc
 lda billy_sprite+2
 adc world_offset
 sta :ax_lo
 lda #0
 adc world_offset+1
 sta :ax_hi
 lda :ax_hi
 cmp abs_x+1
 bne :ax_fail
 lda :ax_lo
 cmp abs_x
 bne :ax_fail
 rts
:ax_fail
* 'AX! aaaa=eeee wo=wwww xp=xx' — abs_x vs expected,
* plus world_offset and IMAGE01_XPOS so the failing inputs
* are visible in the text-screen capture.
 lda #$C1              ; 'A'
 jsr dbg_print_char
 lda #$D8              ; 'X'
 jsr dbg_print_char
 lda #$A1              ; '!'
 jsr dbg_print_char
 lda #$A0              ; ' '
 jsr dbg_print_char
 lda abs_x+1
 jsr dbg_print_hex8
 lda abs_x
 jsr dbg_print_hex8
 lda #$BD              ; '='
 jsr dbg_print_char
 lda :ax_hi
 jsr dbg_print_hex8
 lda :ax_lo
 jsr dbg_print_hex8
 lda #$A0              ; ' '
 jsr dbg_print_char
 lda #$D7              ; 'W'
 jsr dbg_print_char
 lda #$CF              ; 'O'
 jsr dbg_print_char
 lda #$BD              ; '='
 jsr dbg_print_char
 lda world_offset+1
 jsr dbg_print_hex8
 lda world_offset
 jsr dbg_print_hex8
 lda #$A0              ; ' '
 jsr dbg_print_char
 lda #$D8              ; 'X'
 jsr dbg_print_char
 lda #$D0              ; 'P'
 jsr dbg_print_char
 lda #$BD              ; '='
 jsr dbg_print_char
 lda billy_sprite+2
 jsr dbg_print_hex8
 jsr dbg_print_nl
:ax_halt
 bra :ax_halt
:ax_lo dfb 0
:ax_hi dfb 0

*----------------------------------------------------------
* screen_origin_x - World-byte origin (left edge) of each
* screen's horizontal content. $FFFF = not yet determined or
* dynamic (scr10..13 choose anchor at runtime via
* scroll_up_anchor); the assertions below skip $FFFF entries
* rather than false-fail.
*
* Derived from mission1's level_script:
*   scr0..3: linear ground-floor chain, 110 bytes apart
*   scr5:    OP_UP from scr3, default anchor 330 (= scr3 origin)
*   scr7:    OP_RIGHT from scr5
*   others:  fill in when drift is observed and the true
*            world-x of that screen's left edge is measured
*----------------------------------------------------------
screen_origin_x
 dw 0          ; scr0 — spawn
 dw 110        ; scr1 — OP_RIGHT from scr0
 dw 220        ; scr2 — OP_RIGHT from scr1
 dw 330        ; scr3 — OP_RIGHT from scr2
 dw $FFFF      ; scr4 — unused
 dw 330        ; scr5 — OP_UP default anchor (game.s op_up_anchor_default)
 dw $FFFF      ; scr6 — scr5 left-neighbor (w=52); speculative 278
 dw 440        ; scr7 — OP_RIGHT from scr5 (330 + 110)
 dw $FFFF      ; scr8 — scr10 left-neighbor (w=58); speculative 382
 dw $FFFF      ; scr9 — narrow left-neighbor (w=51); speculative 389
 dw $FFFF      ; scr10 — dynamic (scroll_up_anchor: 440 or 302)
 dw $FFFF      ; scr11 — right-neighbor of scr12 narrow layout
 dw $FFFF      ; scr12 — dynamic (scroll_up_anchor=329)
 dw $FFFF      ; scr13 — OP_RIGHT from scr11, narrow layout
 dw $FFFF      ; scr14 — unused
 dw $FFFF      ; scr15 — unused

*----------------------------------------------------------
* assert_scroll_src_off - Verify the right-scroll source
* offset matches what's derivable from world_offset.
* Invariant (steady state, horizontal scroll):
*   screen_origin_x[scroll_src_bank - $03] + scroll_src_off
*     == world_offset + 110
* (the byte next to pull from the source bank is the byte that
* will enter the playfield's right edge, which lives one past
* the current playfield's right.)
* Skipped when the source screen's origin is $FFFF or when the
* computed expected is out of [0, 109] (transition windows).
*----------------------------------------------------------
assert_scroll_src_off
* Skip-rts at top keeps all short branches in range for a long
* diagnostic tail. Every "skip this check" path branches here.
:as_skip rts
 lda scroll_src_bank
 sec
 sbc #$03
 bmi :as_skip          ; bank < $03 (uninitialized/weird)
 cmp #16
 bcs :as_skip          ; screen index out of table
 asl                   ; *2 for 2-byte entries
 tax
 lda screen_origin_x,x
 sta :as_orig
 lda screen_origin_x+1,x
 sta :as_orig+1
* Skip sentinel ($FFFF)
 cmp #$FF
 bne :as_check
 lda :as_orig
 cmp #$FF
 beq :as_skip
:as_check
* expected = (world_offset + 110) - origin   (16-bit)
 clc
 lda world_offset
 adc #110
 sta :as_exp
 lda world_offset+1
 adc #0
 sta :as_exp+1
 sec
 lda :as_exp
 sbc :as_orig
 sta :as_exp
 lda :as_exp+1
 sbc :as_orig+1
 sta :as_exp+1
* If expected is negative or >= 110, we're in a weird
* transition window (scroll_src just wrapped / script mid-
* reconfig). Skip rather than false-fail.
 lda :as_exp+1
 bne :as_skip
 lda :as_exp
 cmp #110
 bcs :as_skip
* Compare to scroll_src_off (1-byte)
 cmp scroll_src_off
 beq :as_skip
* Mismatch — 'SS! aa=ee B=bb WO=wwww CS=cs'
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$A1              ; '!'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda scroll_src_off
 jsr dbg_print_hex8
 lda #$BD              ; '='
 jsr dbg_print_char
 lda :as_exp
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$C2              ; 'B'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 lda scroll_src_bank
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$D7              ; 'W'
 jsr dbg_print_char
 lda #$CF              ; 'O'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 lda world_offset+1
 jsr dbg_print_hex8
 lda world_offset
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$C3              ; 'C'
 jsr dbg_print_char
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 lda current_screen
 jsr dbg_print_hex8
 jsr dbg_print_nl
:as_halt
 bra :as_halt
:as_orig ds 2
:as_exp  ds 2

*----------------------------------------------------------
* assert_scroll_lsrc_off - Verify the left-scroll source
* offset matches what's derivable from world_offset.
* Invariant (steady state, horizontal scroll):
*   screen_origin_x[scroll_lsrc_bank - $03] + scroll_lsrc_off
*     == world_offset - 1
* (the byte next to pull is the one that lands at playfield[0]
* after a left scroll, which corresponds to world byte wo-1
* relative to the current playfield's left.)
* Skipped when: left-neighbor screen's origin is $FFFF; when
* lsrc bank == current_screen's bank (no left neighbor, e.g.
* scr0); or when expected is out of the neighbor's valid range.
*----------------------------------------------------------
assert_scroll_lsrc_off
:al_skip rts
 lda scroll_lsrc_bank
 sec
 sbc #$03
 bmi :al_skip
 cmp #16
 bcs :al_skip
* Skip if lsrc screen == current_screen (means "no left nbr")
 cmp current_screen
 beq :al_skip
 asl
 tax
 lda screen_origin_x,x
 sta :al_orig
 lda screen_origin_x+1,x
 sta :al_orig+1
 cmp #$FF
 bne :al_check
 lda :al_orig
 cmp #$FF
 beq :al_skip
:al_check
* expected = (world_offset - 1) - origin   (16-bit)
 sec
 lda world_offset
 sbc #1
 sta :al_exp
 lda world_offset+1
 sbc #0
 sta :al_exp+1
 sec
 lda :al_exp
 sbc :al_orig
 sta :al_exp
 lda :al_exp+1
 sbc :al_orig+1
 sta :al_exp+1
* Expected must be in [0, 109] for standard-width neighbor;
* skip if out of range (narrow neighbor or transition window).
 lda :al_exp+1
 bne :al_skip
 lda :al_exp
 cmp #110
 bcs :al_skip
 cmp scroll_lsrc_off
 beq :al_skip
* Mismatch — 'LS! aa=ee B=bb WO=wwww CS=cs'
 lda #$CC              ; 'L'
 jsr dbg_print_char
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$A1              ; '!'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda scroll_lsrc_off
 jsr dbg_print_hex8
 lda #$BD
 jsr dbg_print_char
 lda :al_exp
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$C2              ; 'B'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 lda scroll_lsrc_bank
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$D7              ; 'W'
 jsr dbg_print_char
 lda #$CF              ; 'O'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 lda world_offset+1
 jsr dbg_print_hex8
 lda world_offset
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$C3              ; 'C'
 jsr dbg_print_char
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 lda current_screen
 jsr dbg_print_hex8
 jsr dbg_print_nl
:al_halt
 bra :al_halt
:al_orig ds 2
:al_exp  ds 2

*----------------------------------------------------------
* Animation Descriptors
* Format: num_frames, max_width, flags, then per frame:
*         frame_x, frame_y, duration, frame_addr (2 bytes)
* Flags: bit 0 = advance position per VBL, bit 1 = loop
*----------------------------------------------------------

anim_walk
 dfb 4               ; num_frames
 dfb $0B             ; max_width (IMAGE03 is widest walk frame)
 dfb $00             ; flags: none (key handler moves position)
 dfb $09,$28,5       ; IMAGE01: 9 wide, 40 tall, 5 VBLs
  hex 0000             ; patched: IMAGE01
 dfb $08,$28,5       ; IMAGE02
  hex 0000             ; patched: IMAGE02
 dfb $0B,$28,5       ; IMAGE03
  hex 0000             ; patched: IMAGE03
 dfb $08,$28,5       ; IMAGE02
  hex 0000             ; patched: IMAGE02

anim_jump
 dfb 3               ; num_frames
 dfb $0F             ; max_width (JUMP2 is widest)
 dfb $81             ; flags: bit 7 = compiled, bit 0 = advance position
 dfb $0A,$28,3       ; JUMP1: x, y, dur
  hex 0000             ; +6  patched: JUMP1_DATA
  hex 0000             ; +8  patched: JUMP1_MASK
  hex 0000             ; +10 patched: JUMP1_DATA_MIRROR
  hex 0000             ; +12 patched: JUMP1_MASK_MIRROR
 dfb $0F,$1E,12      ; JUMP2: x, y, dur
  hex 0000             ; +17 patched: JUMP2_DATA
  hex 0000             ; +19 patched: JUMP2_MASK
  hex 0000             ; +21 patched: JUMP2_DATA_MIRROR
  hex 0000             ; +23 patched: JUMP2_MASK_MIRROR
 dfb $0D,$20,3       ; JUMP3: x, y, dur
  hex 0000             ; +28 patched: JUMP3_DATA
  hex 0000             ; +30 patched: JUMP3_MASK
  hex 0000             ; +32 patched: JUMP3_DATA_MIRROR
  hex 0000             ; +34 patched: JUMP3_MASK_MIRROR

anim_kick
 dfb 2               ; num_frames
 dfb $14             ; max_width (KICK2 is widest)
 dfb $80             ; flags: bit 7 = compiled
 dfb $09,$28,12      ; KICK1: x, y, dur
  hex 0000             ; +6  patched: KICK1_DATA
  hex 0000             ; +8  patched: KICK1_MASK
  hex 0000             ; +10 patched: KICK1_DATA_MIRROR
  hex 0000             ; +12 patched: KICK1_MASK_MIRROR
 dfb $14,$22,12      ; KICK2: x, y, dur
  hex 0000             ; +17 patched: KICK2_DATA
  hex 0000             ; +19 patched: KICK2_MASK
  hex 0000             ; +21 patched: KICK2_DATA_MIRROR
  hex 0000             ; +23 patched: KICK2_MASK_MIRROR

anim_punch1
 dfb 2               ; num_frames
 dfb $10             ; max_width (PUNCH12 is widest)
 dfb $80             ; flags: bit 7 = compiled (11-byte frame stride)
 dfb $0B,$28,6       ; PUNCH11: x, y, dur
  hex 0000             ; +6  patched: PUNCH11_DATA
  hex 0000             ; +8  patched: PUNCH11_MASK
  hex 0000             ; +10 patched: PUNCH11_DATA_MIRROR
  hex 0000             ; +12 patched: PUNCH11_MASK_MIRROR
 dfb $10,$28,6       ; PUNCH12: x, y, dur
  hex 0000             ; +17 patched: PUNCH12_DATA
  hex 0000             ; +19 patched: PUNCH12_MASK
  hex 0000             ; +21 patched: PUNCH12_DATA_MIRROR
  hex 0000             ; +23 patched: PUNCH12_MASK_MIRROR

anim_punch2
 dfb 2               ; num_frames
 dfb $10             ; max_width (PUNCH22 is widest)
 dfb $80             ; flags: bit 7 = compiled
 dfb $0A,$28,6       ; PUNCH21: x, y, dur
  hex 0000             ; +6  patched: PUNCH21_DATA
  hex 0000             ; +8  patched: PUNCH21_MASK
  hex 0000             ; +10 patched: PUNCH21_DATA_MIRROR
  hex 0000             ; +12 patched: PUNCH21_MASK_MIRROR
 dfb $10,$28,6       ; PUNCH22: x, y, dur
  hex 0000             ; +17 patched: PUNCH22_DATA
  hex 0000             ; +19 patched: PUNCH22_MASK
  hex 0000             ; +21 patched: PUNCH22_DATA_MIRROR
  hex 0000             ; +23 patched: PUNCH22_MASK_MIRROR

anim_bpunched
 dfb 1               ; num_frames
 dfb $0B             ; max_width
 dfb $80             ; flags: bit 7 = compiled
 dfb $0B,$28,5       ; BPUNCHED: x, y, dur
  hex 0000             ; +6  patched: BPUNCHED_DATA
  hex 0000             ; +8  patched: BPUNCHED_MASK
  hex 0000             ; +10 patched: BPUNCHED_DATA_MIRROR
  hex 0000             ; +12 patched: BPUNCHED_MASK_MIRROR

anim_wpunched
 dfb 1               ; num_frames
 dfb $09             ; max_width
 dfb $00             ; flags: none (one-shot)
 dfb $09,$28,5       ; WPUNCHED: 9 wide, 40 tall, 5 VBLs
  hex 0000             ; patched: WPUNCHED

anim_wfall
 dfb 2               ; num_frames
 dfb $13             ; max_width (WFALL is widest at $13)
 dfb $00             ; flags: none (one-shot)
 dfb $13,$21,3       ; WFALL: 19 wide, 33 tall, 3 VBLs
  hex 0000             ; patched: WFALL
 dfb $10,$0D,60      ; WFALLEN: 16 wide, 13 tall, 60 VBLs
  hex 0000             ; patched: WFALLEN

anim_bfall
 dfb 1               ; num_frames
 dfb $09             ; max_width (IMAGE01)
 dfb $80             ; flags: bit 7 = compiled (placeholder uses IMAGE01)
 dfb $09,$28,33      ; IMAGE01: x, y, dur
  hex 0000             ; +6  patched: IMAGE01_DATA
  hex 0000             ; +8  patched: IMAGE01_MASK
  hex 0000             ; +10 patched: IMAGE01_DATA_MIRROR
  hex 0000             ; +12 patched: IMAGE01_MASK_MIRROR

* William walking cycle (WILLIAM1, 2, 3, 2). Looping, no
* auto-advance — behavior code controls position.
anim_wwalk
 dfb 4               ; num_frames
 dfb $09             ; max_width
 dfb $02             ; flags: loop
 dfb $09,$28,5       ; WILLIAM1
  hex 0000             ; patched: WILLIAM1
 dfb $09,$28,5       ; WILLIAM2
  hex 0000             ; patched: WILLIAM2
 dfb $09,$28,5       ; WILLIAM3
  hex 0000             ; patched: WILLIAM3
 dfb $09,$28,5       ; WILLIAM2
  hex 0000             ; patched: WILLIAM2

* William's offensive punch (NPC). 2 frames, non-looping.
anim_wpunch
 dfb 2               ; num_frames
 dfb $11             ; max_width (WPUNCH2 is widest)
 dfb $00             ; flags: none (one-shot)
 dfb $0B,$28,6       ; WPUNCH1
  hex 0000             ; patched: WPUNCH1
 dfb $11,$28,6       ; WPUNCH2
  hex 0000             ; patched: WPUNCH2

* Roper walk (ROPER1, 2, 3, 2). Looping, no auto-advance.
anim_rwalk
 dfb 4
 dfb $09
 dfb $02             ; flags: loop
 dfb $09,$27,5       ; ROPER1
  hex 0000             ; patched
 dfb $09,$26,5       ; ROPER2
  hex 0000             ; patched
 dfb $09,$27,5       ; ROPER3
  hex 0000             ; patched
 dfb $09,$26,5       ; ROPER2
  hex 0000             ; patched

* Roper punch. 2 frames, one-shot.
anim_rpunch
 dfb 2
 dfb $10             ; max_width (RPUNCH2)
 dfb $00
 dfb $0B,$27,6       ; RPUNCH1
  hex 0000             ; patched
 dfb $10,$27,6       ; RPUNCH2
  hex 0000             ; patched

* Roper punched reaction. 1 frame, one-shot.
anim_rpunched
 dfb 1
 dfb $09
 dfb $00
 dfb $09,$26,5       ; RPUNCHED
  hex 0000             ; patched

* Roper fall. 2 frames, one-shot.
anim_rfall
 dfb 2
 dfb $10
 dfb $00
 dfb $10,$17,3       ; RFALL1
  hex 0000             ; patched
 dfb $10,$0F,60      ; RFALL2
  hex 0000             ; patched

* Linda walk (LINDA1, 2, 3, 2). Looping, no auto-advance.
anim_lwalk
 dfb 4
 dfb $09
 dfb $02             ; flags: loop
 dfb $09,$28,5       ; LINDA1
  hex 0000             ; patched
 dfb $09,$27,5       ; LINDA2
  hex 0000             ; patched
 dfb $09,$28,5       ; LINDA3
  hex 0000             ; patched
 dfb $09,$27,5       ; LINDA2
  hex 0000             ; patched

* Linda punch. 2 frames, one-shot.
anim_lpunch
 dfb 2
 dfb $0E             ; max_width (LPUNCH2)
 dfb $00
 dfb $0B,$28,6       ; LPUNCH1
  hex 0000             ; patched
 dfb $0E,$28,6       ; LPUNCH2
  hex 0000             ; patched

* Linda punched reaction. 1 frame, one-shot.
anim_lpunched
 dfb 1
 dfb $09
 dfb $00
 dfb $08,$26,5       ; LPUNCHED
  hex 0000             ; patched

* Linda fall. 2 frames, one-shot.
anim_lfall
 dfb 2
 dfb $11
 dfb $00
 dfb $10,$17,3       ; LFALL1
  hex 0000             ; patched
 dfb $11,$0F,60      ; LFALL2
  hex 0000             ; patched

*----------------------------------------------------------
* check_punch_hit - Check if the punching sprite (whose
* state is in globals) hit any other sprite in the table.
* Iterates sprite_table, skips self, checks bounding box.
*----------------------------------------------------------
* npc_seek_player - Move an NPC sprite one step toward the
* keyboard-controlled player using Bresenham-style stepping.
*
* Call with info_ptr pointing to the NPC's sprite block.
* Finds the player by scanning sprite_table for controller=$01.
* Computes dx = player_x - npc_x, dy = player_y - npc_y,
* then steps along the longer axis each call, accumulating
* error on the shorter axis (standard Bresenham line).
*
* Each call moves the NPC by 0 or 1 in each axis.
* Call once per frame (or every N frames) for smooth movement.
* Calls save_sprite to commit the new position.
*
* Uses ZP $E6-$E9 as scratch (sort_src/sort_dst).
*----------------------------------------------------------
npc_seek_player
* Save NPC's info_ptr
 lda info_ptr
 sta :npc_lo
 lda info_ptr+1
 sta :npc_hi
* Read NPC position
 ldy #0
 lda (info_ptr),y     ; npc ypos
 sta :npc_y
 ldy #2
 lda (info_ptr),y     ; npc xpos
 sta :npc_x

* Find player sprite (controller=$01)
 lda spr_ptr
 pha
 lda spr_ptr+1
 pha
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:find
 ldy #0
 lda (spr_ptr),y
 sta info_ptr
 iny
 lda (spr_ptr),y
 sta info_ptr+1
 ora info_ptr
 bne :not_end
 jmp :no_player       ; end of table, no player found
:not_end
 ldy #22
 lda (info_ptr),y     ; controller
 cmp #$01
 beq :found
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :find
 inc spr_ptr+1
 bra :find

:found
* Read player position
 ldy #0
 lda (info_ptr),y     ; player ypos
 sta :plr_y
 ldy #2
 lda (info_ptr),y     ; player xpos
 sta :plr_x

* Restore spr_ptr
 pla
 sta spr_ptr+1
 pla
 sta spr_ptr
* Restore NPC info_ptr
 lda :npc_lo
 sta info_ptr
 lda :npc_hi
 sta info_ptr+1

* Compute dx = abs(player_x - npc_x), sx = sign
 lda :plr_x
 sec
 sbc :npc_x
 bcs :dx_pos
* dx negative
 eor #$FF
 clc
 adc #1              ; abs(dx)
 sta :dx
 lda #$FF
 sta :sx              ; sx = -1
 bra :do_dy
:dx_pos
 sta :dx
 lda #$01
 sta :sx              ; sx = +1
:do_dy
* Compute dy = abs(player_y - npc_y), sy = sign
 lda :plr_y
 sec
 sbc :npc_y
 bcs :dy_pos
* dy negative
 eor #$FF
 clc
 adc #1
 sta :dy
 lda #$FF
 sta :sy              ; sy = -1
 bra :bresenham
:dy_pos
 sta :dy
 lda #$01
 sta :sy              ; sy = +1

:bresenham
* If dx==0 and dy==0, already at player — do nothing
 lda :dx
 ora :dy
 bne :do_step
 jmp :seek_done
:do_step

* Bresenham: step along major axis, accumulate error on minor
* if dx >= dy: major=X, error accumulates dy
* else:        major=Y, error accumulates dx
 lda :dx
 cmp :dy
 bcs :major_x

* Major axis = Y
 lda :npc_y
 clc
 adc :sy
 sta :npc_y           ; always step Y
* Accumulate error
 lda :err
 clc
 adc :dx
 sta :err
* Check if error >= dy (step X too)
 cmp :dy
 bcc :step_done
* Error overflow — step X, subtract dy
 lda :npc_x
 clc
 adc :sx
 sta :npc_x
 lda :err
 sec
 sbc :dy
 sta :err
 bra :step_done

:major_x
* Major axis = X
 lda :npc_x
 clc
 adc :sx
 sta :npc_x           ; always step X
* Accumulate error
 lda :err
 clc
 adc :dy
 sta :err
* Check if error >= dx (step Y too)
 cmp :dx
 bcc :step_done
* Error overflow — step Y, subtract dx
 lda :npc_y
 clc
 adc :sy
 sta :npc_y
 lda :err
 sec
 sbc :dx
 sta :err

:step_done
* Write new position to NPC sprite block
 ldy #0
 lda :npc_y
 sta (info_ptr),y     ; +0 ypos
 sta IMAGE01_YPOS
 ldy #2
 lda :npc_x
 sta (info_ptr),y     ; +2 xpos
 sta IMAGE01_XPOS
* Load remaining globals for save_sprite
 ldy #4
 lda (info_ptr),y
 sta IMAGE01_MIRROR
 ldy #10
 lda (info_ptr),y
 sta FRAME_X
 ldy #12
 lda (info_ptr),y
 sta FRAME_Y
 ldy #14
 lda (info_ptr),y
 sta FRAME_ADDR
 iny
 lda (info_ptr),y
 sta FRAME_ADDR+1
 jsr save_sprite
:seek_done
 rts

:no_player
* No player found — restore and return
 pla
 sta spr_ptr+1
 pla
 sta spr_ptr
 lda :npc_lo
 sta info_ptr
 lda :npc_hi
 sta info_ptr+1
 rts

:npc_lo dfb 0
:npc_hi dfb 0
:npc_x dfb 0
:npc_y dfb 0
:plr_x dfb 0
:plr_y dfb 0
:dx dfb 0
:dy dfb 0
:sx dfb 0             ; +1 or -1 ($01 or $FF)
:sy dfb 0
:err dfb 0            ; Bresenham error accumulator (persists between calls)

*----------------------------------------------------------
* mark_overlapping - After erasing a sprite, check if the
* erased rectangle overlaps any other sprite's on-screen
* position (prev). If so, mark that sprite for redraw.
*----------------------------------------------------------
* remove_from_sprite_table - Remove the entry at spr_ptr
* by shifting all subsequent entries down by 2 bytes.
* spr_ptr is left pointing at the same position (now the
* next entry, or the null terminator).
*----------------------------------------------------------
remove_from_sprite_table
* Use sort_src as read pointer (spr_ptr + 2),
* sort_dst as write pointer (spr_ptr)
 lda spr_ptr
 sta sort_dst
 clc
 adc #2
 sta sort_src
 lda spr_ptr+1
 sta sort_dst+1
 adc #0
 sta sort_src+1
:shift
 ldy #0
 lda (sort_src),y
 sta (sort_dst),y
 iny
 lda (sort_src),y
 sta (sort_dst),y
* Check if we just copied the null terminator
 dey
 ora (sort_dst),y
 beq :rm_done
 lda sort_src
 clc
 adc #2
 sta sort_src
 bcc :s2
 inc sort_src+1
:s2 lda sort_dst
 clc
 adc #2
 sta sort_dst
 bcc :shift
 inc sort_dst+1
 bra :shift
:rm_done rts

*----------------------------------------------------------
* Erased rect is in IMAGE01_XPOS/YPOS/FRAME_X/FRAME_Y.
* Saves/restores spr_ptr and info_ptr.
*----------------------------------------------------------
mark_overlapping
 lda spr_ptr
 pha
 lda spr_ptr+1
 pha
 lda info_ptr
 pha
 lda info_ptr+1
 pha
* Save erased sprite's info_ptr to skip self
 lda info_ptr
 sta :self_lo
 lda info_ptr+1
 sta :self_hi
* Precompute erased rect edges
 lda IMAGE01_XPOS
 clc
 adc FRAME_X
 sta :erase_right      ; erase right = xpos + width
 lda IMAGE01_YPOS
 clc
 adc FRAME_Y
 sta :erase_bottom     ; erase bottom = ypos + height

 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1

:loop
 ldy #0
 lda (spr_ptr),y
 sta info_ptr
 iny
 lda (spr_ptr),y
 sta info_ptr+1
 ora info_ptr
 bne :not_null
 jmp :mo_done
:not_null
* Skip self
 lda info_ptr
 cmp :self_lo
 bne :not_self
 lda info_ptr+1
 cmp :self_hi
 beq :mo_advance
:not_self
* Read other sprite's prev position (what's on screen)
 ldy #32
 lda (info_ptr),y     ; prev_ypos
 sta :oth_y
 ldy #34
 lda (info_ptr),y     ; prev_xpos
 sta :oth_x
 ldy #36
 lda (info_ptr),y     ; prev_frame_x
 sta :oth_w
 ldy #38
 lda (info_ptr),y     ; prev_frame_y
 sta :oth_h

* Horizontal overlap: erase_left < oth_right AND erase_right > oth_left
 lda :oth_x
 clc
 adc :oth_w            ; oth_right
 cmp IMAGE01_XPOS
 bcc :mo_advance       ; oth_right <= erase_left, no overlap
 beq :mo_advance
 lda :erase_right
 cmp :oth_x
 bcc :mo_advance       ; erase_right <= oth_left, no overlap
 beq :mo_advance

* Vertical overlap: erase_top < oth_bottom AND erase_bottom > oth_top
 lda :oth_y
 clc
 adc :oth_h            ; oth_bottom
 cmp IMAGE01_YPOS
 bcc :mo_advance       ; oth_bottom <= erase_top, no overlap
 beq :mo_advance
 lda :erase_bottom
 cmp :oth_y
 bcc :mo_advance       ; erase_bottom <= oth_top, no overlap
 beq :mo_advance

* Overlap detected — mark for redraw (set bit 0)
 ldy #30
 lda (info_ptr),y
 ora #$01
 sta (info_ptr),y

:mo_advance
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :jloop
 inc spr_ptr+1
:jloop jmp :loop

:mo_done
 pla
 sta info_ptr+1
 pla
 sta info_ptr
 pla
 sta spr_ptr+1
 pla
 sta spr_ptr
 rts

:self_lo dfb 0
:self_hi dfb 0
:erase_right dfb 0
:erase_bottom dfb 0
:oth_x dfb 0
:oth_y dfb 0
:oth_w dfb 0
:oth_h dfb 0

*----------------------------------------------------------
* On hit: increment low nibble of border color at $E0C034.
* Saves/restores spr_ptr and info_ptr.
*----------------------------------------------------------
check_punch_hit
* Save caller's spr_ptr, info_ptr, and anim_ptr. The iteration
* below overwrites anim_ptr ZP for each target it checks, so
* returning without restoring leaves the puncher's update_anims
* continuation (specifically the fall-bump check) reading a
* random target's anim_ptr — which can spuriously match the
* puncher's fall_anim when puncher and target are the same
* NPC type and bump ypos on a non-fall sprite.
 lda spr_ptr
 pha
 lda spr_ptr+1
 pha
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 lda anim_ptr
 pha
 lda anim_ptr+1
 pha
* Save puncher's info_ptr to identify self
 lda info_ptr
 sta :self_lo
 lda info_ptr+1
 sta :self_hi
* Precompute puncher's bottom and right edge
 lda IMAGE01_YPOS
 clc
 adc FRAME_Y
 sec
 sbc #1
 sta :punch_bottom    ; puncher bottom = ypos + height - 1
 lda IMAGE01_XPOS
 clc
 adc FRAME_X
 sta :punch_right     ; puncher right = xpos + width

* Iterate sprite_table
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1

:loop
 ldy #0
 lda (spr_ptr),y
 sta info_ptr
 iny
 lda (spr_ptr),y
 sta info_ptr+1
 ora info_ptr
 bne :not_null
 jmp :done            ; null terminator
:not_null

* Skip self
 lda info_ptr
 cmp :self_lo
 bne :not_self
 lda info_ptr+1
 cmp :self_hi
 bne :not_self
 jmp :advance
:not_self
* If target is player and god_mode active, skip
 lda god_mode
 beq :not_god
 ldy #22
 lda (info_ptr),y      ; controller
 cmp #$01
 bne :not_god
 jmp :advance          ; player is invincible
:not_god
* Check if target is immune (fall_anim active)
 ldy #24
 lda (info_ptr),y     ; anim_ptr low
 sta anim_ptr
 iny
 lda (info_ptr),y     ; anim_ptr high
 sta anim_ptr+1
 ora anim_ptr
 beq :not_immune      ; no animation, punchable
* Check if active animation is the fall_anim
 ldy #50
 lda (info_ptr),y     ; fall_anim low
 cmp anim_ptr
 bne :not_immune
 iny
 lda (info_ptr),y     ; fall_anim high
 cmp anim_ptr+1
 bne :not_immune
 jmp :advance         ; fall_anim active, immune
:not_immune

* Read target's ypos, xpos, frame_x, frame_y
 ldy #0
 lda (info_ptr),y     ; target ypos
 sta :tgt_y
 ldy #2
 lda (info_ptr),y     ; target xpos
 sta :tgt_x
 ldy #10
 lda (info_ptr),y     ; target frame_x
 sta :tgt_w
 ldy #12
 lda (info_ptr),y     ; target frame_y
 sta :tgt_h

* Vertical check: puncher bottom within 5 of target bottom
 lda :tgt_y
 clc
 adc :tgt_h
 sec
 sbc #1              ; target bottom
 sta :tgt_bottom
 lda :punch_bottom
 cmp :tgt_bottom
 bcs :check_below
* punch_bottom < tgt_bottom — check distance
 lda :tgt_bottom
 sec
 sbc :punch_bottom
 cmp #6              ; > 5 away?
 bcc :not_far_above
 jmp :advance        ; too far above
:not_far_above
 bra :h_check
:check_below
* punch_bottom >= tgt_bottom
 lda :punch_bottom
 sec
 sbc :tgt_bottom
 cmp #11             ; > 10 away?
 bcc :h_check
 jmp :advance        ; too far below

:h_check
* Horizontal check: overlap or within 2 bytes
* punch_right - 2 >= tgt_x
 lda :punch_right
 sec
 sbc #2
 cmp :tgt_x
 bcs :h_check2
 jmp :advance        ; punch too far left
:h_check2
* tgt_right + 2 >= punch_x
 lda :tgt_x
 clc
 adc :tgt_w
 clc
 adc #2              ; tgt_right + 2
 cmp IMAGE01_XPOS
 bcs :hit
 jmp :advance        ; target too far left
:hit

* Hit! Increment target's punch count
 ldy #48
 lda (info_ptr),y
 clc
 adc #1
 sta (info_ptr),y
* Award 100 points to player 1 and mark score for redraw.
 jsr incp1s_hundreds
* Increment low nibble of border color
; ldal $E0C034
; clc
; adc #1
; and #$0F
; sta :tmp
; ldal $E0C034
; and #$F0
; ora :tmp
; stal $E0C034
* Check if punch_count triggers a fall (3 or 6)
 ldy #48
 lda (info_ptr),y     ; punch_count
 cmp #3
 beq :use_fall
 cmp #6
 beq :use_fall
* Normal punch — use punched_anim
 ldy #40
 lda (info_ptr),y     ; punched_anim low
 sta anim_ptr
 iny
 lda (info_ptr),y     ; punched_anim high
 sta anim_ptr+1
 ora anim_ptr
 bne :do_punched
 jmp :advance
:use_fall
* Fall — use fall_anim
 ldy #50
 lda (info_ptr),y     ; fall_anim low
 sta anim_ptr
 iny
 lda (info_ptr),y     ; fall_anim high
 sta anim_ptr+1
 ora anim_ptr
 bne :do_punched
 jmp :advance
:do_punched
* Save puncher's globals before overwriting with target's
 lda IMAGE01_YPOS
 pha
 lda IMAGE01_XPOS
 pha
 lda IMAGE01_MIRROR
 pha
 lda FRAME_X
 pha
 lda FRAME_Y
 pha
 lda FRAME_ADDR
 pha
 lda FRAME_ADDR+1
 pha
* Load target sprite globals for start_anim
 ldy #0
 lda (info_ptr),y
 sta IMAGE01_YPOS
 ldy #2
 lda (info_ptr),y
 sta IMAGE01_XPOS
 ldy #4
 lda (info_ptr),y
 sta IMAGE01_MIRROR
 ldy #10
 lda (info_ptr),y
 sta FRAME_X
 ldy #12
 lda (info_ptr),y
 sta FRAME_Y
 ldy #14
 lda (info_ptr),y
 sta FRAME_ADDR
 iny
 lda (info_ptr),y
 sta FRAME_ADDR+1
 lda anim_ptr
 ldx anim_ptr+1
 jsr start_anim
* Restore puncher's globals
 pla
 sta FRAME_ADDR+1
 pla
 sta FRAME_ADDR
 pla
 sta FRAME_Y
 pla
 sta FRAME_X
 pla
 sta IMAGE01_MIRROR
 pla
 sta IMAGE01_XPOS
 pla
 sta IMAGE01_YPOS

:advance
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :jloop
 inc spr_ptr+1
:jloop jmp :loop

:done
* Restore caller's anim_ptr, info_ptr, and spr_ptr (reverse order)
 pla
 sta anim_ptr+1
 pla
 sta anim_ptr
 pla
 sta info_ptr+1
 pla
 sta info_ptr
 pla
 sta spr_ptr+1
 pla
 sta spr_ptr
 rts

:self_lo dfb 0
:self_hi dfb 0
:punch_bottom dfb 0
:punch_right dfb 0
:tgt_y dfb 0
:tgt_x dfb 0
:tgt_w dfb 0
:tgt_h dfb 0
:tgt_bottom dfb 0
:tmp dfb 0

* (advance_frame removed — animation now data-driven via update_anims)

  mx %11
incp1s_hundreds
  lda p1_score+4
  inc
  sta p1_score+4
  cmp #$3a         ; Carry
  blt incp1s_ret
  lda #$30
  sta p1_score+4
incp1s_thousands
  lda p1_score+3
  inc
  sta p1_score+3
  cmp #$3a
  blt incp1s_ret
  lda #$30
  sta p1_score+3
incp1s_tenthousands
  lda p1_score+2
  inc
  sta p1_score+2
  cmp #$3a
  blt incp1s_ret
  lda #$30
  sta p1_score+2
incp1s_hundredthousands
  lda p1_score+1
  inc
  sta p1_score+1
  cmp #$3a
  blt incp1s_ret
  lda #$30
  sta p1_score+1
incp1s_millions
  lda p1_score
  inc
  sta p1_score
  cmp #$3a           ; millions carry = wrap to all-zeroes lol
  blt incp1s_ret
  lda #$30
  sta p1_score
  sta p1_score+1
  sta p1_score+2
  sta p1_score+3
  sta p1_score+4
  sta p1_score+5
  sta p1_score+6
incp1s_ret
  inc p1_score_dirty
  rts

*----------------------------------------------------------
* erase - Restore the background behind the sprite
* Copies the rectangle at the sprite's current position
* from the clean background in bank $18 back to the screen
* in bank $E1. Uses FRAME_X/FRAME_Y for dimensions.
*----------------------------------------------------------
erase    PHB
 PHP
 CLC
 XCE
 PHP
 PHK
 PLB
 REP $30
 TSC
 SEC
 SBC #10
 TCS
 PHD
 TSC
 CLC
 ADC #3
 TCD
 SEP $20
 LDAL $E0C029
 ORA #%01000000
 STAL $E0C029
 REP $20
* Set up destination pointer (screen at $01/2000, shadowed to $E1) in DP 0-2
 LDA #$01
 STA 2
 lda IMAGE01_YPOS
 asl
 asl
 asl
 asl
 asl
 sta 8
 asl
 asl
 clc
 adc 8
 clc
 adc #$2000
 sta 0
* Set up source pointer (background copy at $18/2000) in DP 4-6
 LDA #$18
 STA 6
 LDA 0              ; same offset as screen
 STA 4
 SEP $30
 LDA FRAME_X
 CLC
 ADC IMAGE01_XPOS
 STA IMAGE01_XTEMP
 LDX FRAME_Y        ; number of lines
]ELOOP1 LDY IMAGE01_XPOS
]ELOOP LDA [4],Y       ; read from background copy
 STA [0],Y          ; write to screen
 INY
 CPY IMAGE01_XTEMP
 BCC ]ELOOP
 DEX
 BEQ :FINDONE
 REP $20
 LDA 0
 CLC
 ADC #$A0
 STA 0
 LDA 4
 CLC
 ADC #$A0
 STA 4
 SEP $20
 BRA ]ELOOP1
:FINDONE REP $30
 PLD
 TSC
 CLC
 ADC #10
 TCS
 PLP
 XCE
 PLP
 PLB
 RTS

*----------------------------------------------------------
* draw_sprite - Plot the current frame to screen
* Uses FRAME_X, FRAME_Y, FRAME_ADDR for the active frame.
*----------------------------------------------------------
draw_sprite PHB
 PHP
 CLC
 XCE
 PHP
 PHK
 PLB
 REP $30
 TSC
 SEC
 SBC #10
 TCS
 PHD
 TSC
 CLC
 ADC #3
 TCD
 SEP $20
 LDAL $E0C029
 ORA #%01000000
 STAL $E0C029
 REP $20
 LDA #$0001            ; destination bank $01 (shadowed to $E1)
 STA 2
 lda IMAGE01_YPOS  ; do our own multiplication by $a0 because address won't always be hardcoded
 asl
 asl
 asl
 asl
 asl
 sta 8
 asl
 asl
 clc
 adc 8
 clc
 adc #$2000
 sta 0
 LDA sprite_bank
 STA 6
 LDA FRAME_ADDR
 STA 4
 SEP $30
 LDA FRAME_X
 CLC
 ADC IMAGE01_XPOS
 STA IMAGE01_XTEMP
 LDX FRAME_Y       ;Number of lines
 LDA IMAGE01_MIRROR
 BNE :MIRROR
 JMP :NORMAL
:MIRROR
*----------------------------------------------------------
* Mirrored draw path - read sprite bytes in reverse order
* per line, swapping nibbles of each byte. Swapped byte
* is held in DP 9 so masking logic can reference it.
*----------------------------------------------------------
 REP $20            ; advance [4] to last byte of first line
 LDA 4
 CLC
 ADC FRAME_X
 SEC
 SBC #1
 STA 4
 SEP $30
]MLOOP1 LDY IMAGE01_XPOS
]MLOOP LDA [4]           ; read sprite byte (reversed)
* Swap nibbles: high->low, low->high
 STA 9
 LSR
 LSR
 LSR
 LSR                     ; old high nibble now in low
 STA 8
 LDA 9
 ASL
 ASL
 ASL
 ASL                     ; old low nibble now in high
 ORA 8
 STA 9                   ; DP 9 = nibble-swapped byte
 CMP MASK
 BEQ MSKIP
 AND #$F0
 CMP MASKHI
 BEQ MDOMASKHI
 LDA 9
 AND #$0F
 CMP MASKLO
 BEQ MDOMASKLO
 BRA MNOMASK
MDOMASKHI LDA [0],Y
 AND #$F0
 STA 8
 LDA 9
 AND #$0F
 ORA 8
 STA [0],Y
 BRA MSKIP
MDOMASKLO LDA [0],Y
 AND #$0F
 STA 8
 LDA 9
 AND #$F0
 ORA 8
 STA [0],Y
 BRA MSKIP
MNOMASK LDA 9
 STA [0],Y
MSKIP REP $20
 DEC 4                   ; move sprite pointer backward
 SEP $20
 INY
 CPY IMAGE01_XTEMP
 BCC ]MLOOP
 DEX
 BEQ :FINDUMP
 REP $20
 LDA 0                   ; next screen line
 CLC
 ADC #$A0
 STA 0
 LDA FRAME_X             ; advance sprite ptr by 2*width
 ASL                     ; (we went back width, need forward width to next line end)
 CLC
 ADC 4
 STA 4
 SEP $20
 BRA ]MLOOP1
*----------------------------------------------------------
* Normal (non-mirrored) draw path
*----------------------------------------------------------
:NORMAL
]LOOP1 LDY IMAGE01_XPOS
]LOOP LDA [4]
  CMP MASK
  BEQ SKIP
  AND #$F0
  CMP MASKHI
  BEQ DOMASKHI
  LDA [4]
  AND #$0F
  CMP MASKLO
  BEQ DOMASKLO
  BRA NOMASK
DOMASKHI LDA [0],Y
 AND #$F0
 STA 8
 LDA [4]
 AND #$0F
 ORA 8
 STA [0],Y
 BRA SKIP
DOMASKLO LDA [0],Y
 AND #$0F
 STA 8
 LDA [4]
 AND #$F0
 ORA 8
 STA [0],Y
 BRA SKIP
NOMASK  LDA [4]
 STA [0],Y
SKIP REP $20
 INC 4
 SEP $20
 INY
 CPY IMAGE01_XTEMP
 BCC ]LOOP
 DEX
 BEQ :FINDUMP
 REP $20
 LDA 0
 CLC
 ADC #$A0
 STA 0
 SEP $20
 BRA ]LOOP1
:FINDUMP REP $30
 PLD
 TSC
 CLC
 ADC #10
 TCS
 PLP
 XCE
 PLP
 PLB
 RTS

*----------------------------------------------------------
* draw_active_sprite - Draw the player sprite using whichever
* pipeline matches its current frame data. Dispatches on
* MASK_ADDR: when non-zero, FRAME_ADDR points at compiled DATA
* and we use draw_sprite_compiled; when zero, FRAME_ADDR is raw
* (animation, climb, etc.) and we use legacy draw_sprite.
*----------------------------------------------------------
draw_active_sprite
 lda MASK_ADDR
 ora MASK_ADDR+1
 bne :das_compiled
 jmp draw_sprite
:das_compiled
 jmp draw_sprite_compiled

*----------------------------------------------------------
* draw_sprite_compiled - AND/ORA pipeline draw for sprites
* compiled via tools/compile_sprite.py. Inputs:
*   IMAGE01_XPOS / IMAGE01_YPOS  destination
*   FRAME_X / FRAME_Y            sprite size (bytes / rows)
*   FRAME_ADDR                   pointer to *_DATA  array (bank $02)
*   MASK_ADDR                    pointer to *_MASK  array (bank $02)
*   sprite_bank                  bank holding _DATA / _MASK ($02)
* Destination is hardcoded to bank $01 (shadowed to $E1).
*
* Inner loop (per byte) is branchless:
*   LDA [scr],Y / AND [mask],Y / ORA [data],Y / STA [scr],Y
* Mirror sprites use pre-computed _DATA_MIRROR / _MASK_MIRROR
* arrays — there is no separate mirror branch here.
*
* DP layout after the 11-byte stack carve-out:
*   DP 0-2  screen long pointer (offset 0-1, bank 2)
*   DP 4-6  data   long pointer (offset 4-5, bank 6)
*   DP 7-9  mask   long pointer (offset 7-8, bank 9)
*   DP A    end_x  (= IMAGE01_XPOS + FRAME_X)
*----------------------------------------------------------
draw_sprite_compiled
 PHB
 PHP
 CLC
 XCE
 PHP
 PHK
 PLB
 REP $30
 TSC
 SEC
 SBC #11
 TCS
 PHD
 TSC
 CLC
 ADC #3
 TCD
 SEP $20
 LDAL $E0C029
 ORA #%01000000
 STAL $E0C029

* Bank bytes (8-bit stores so they don't clobber adjacent DP bytes
* that the 16-bit offset writes below will overwrite anyway).
 LDA #$01              ; destination bank $01 (shadowed to $E1)
 STA 2                 ; DP 2 = screen bank
 LDA sprite_bank
 STA 6                 ; DP 6 = data bank
 STA 9                 ; DP 9 = mask bank

 REP $20

* DP 0-1 = ypos * $A0 + $2000 + IMAGE01_XPOS
* (Pre-adding IMAGE01_XPOS lets the inner loop use Y as a sprite-byte
*  index from 0..FRAME_X-1 against all three pointers in lockstep.)
 LDA IMAGE01_YPOS
 ASL
 ASL
 ASL
 ASL
 ASL
 STA IMAGE01_XTEMP     ; absolute scratch (DP space is tight)
 ASL
 ASL
 CLC
 ADC IMAGE01_XTEMP
 CLC
 ADC #$2000
 CLC
 ADC IMAGE01_XPOS      ; 16-bit add of IMAGE01_XPOS (low byte = column,
                       ; high byte must be 0 — IMAGE01_XPOS is stored as
                       ; HEX nn00 so the 16-bit load gives that)
 STA 0

 LDA FRAME_ADDR
 STA 4                 ; DP 4-5 = data offset
 LDA MASK_ADDR
 STA 7                 ; DP 7-8 = mask offset

 SEP $30
 LDA FRAME_X
 STA $0A               ; DP $0A = byte width (loop bound, Y < FRAME_X)
 LDX FRAME_Y           ; X = row counter

:dsc_row
 LDY #0                ; sprite-byte index, runs 0..FRAME_X-1
:dsc_byte
 LDA [0],Y
 AND [7],Y
 ORA [4],Y
 STA [0],Y
 INY
 CPY $0A
 BCC :dsc_byte

 DEX
 BEQ :dsc_done

* Advance pointers to next row (16-bit math)
 REP $20
 LDA 0
 CLC
 ADC #$00A0
 STA 0
 LDA 4
 CLC
 ADC FRAME_X
 STA 4
 LDA 7
 CLC
 ADC FRAME_X
 STA 7
 SEP $20
 BRA :dsc_row

:dsc_done
 REP $30
 PLD
 TSC
 CLC
 ADC #11
 TCS
 PLP
 XCE
 PLP
 PLB
 RTS

wait_for_vbl
:lp1 bit $c019
 bmi :lp1 ; wait for current VBL to end
:lp2 bit $c019
 bpl :lp2 ; wait for next VBL to start
 rts

; scores (hex, starting at 0)
p1_score asc '0000000',00
p1_score_dirty dw 0
p2_score asc '0000000',00
p2_score_dirty dw 0

*-------------------------------
* ProDOS 8 parameter blocks
*-------------------------------
dest ds 2              ; current destination offset (advances per chunk)

p_open dfb 3           ; param count
 da pathname          ; pathname pointer
 da ]IOBUF            ; I/O buffer (1024 bytes, page-aligned)
o_refnum dfb 0        ; ref_num (returned by OPEN)

p_read dfb 4           ; param count
r_refnum dfb 0        ; ref_num
 da ]RDBUF            ; data buffer
 da $1000             ; request count (4KB)
 ds 2                 ; transfer count (returned)

p_close dfb 1          ; param count
c_refnum dfb 0        ; ref_num

p_get_eof dfb 2        ; param count
eof_refnum dfb 0       ; ref_num
eof_size ds 3          ; 3-byte EOF (file size)

file_size ds 3        ; 24-bit file size (for UnPackBytes)

pathname dfb 21
 asc '/DDIIGS/MISSION11.PAK'

path12 dfb 21
 asc '/DDIIGS/MISSION12.PAK'

path13 dfb 21
 asc '/DDIIGS/MISSION13.PAK'

path14 dfb 21
 asc '/DDIIGS/MISSION14.PAK'

path15 dfb 21
 asc '/DDIIGS/MISSION15.PAK'

path16 dfb 21
 asc '/DDIIGS/MISSION16.PAK'

path17 dfb 21
 asc '/DDIIGS/MISSION17.PAK'

path18 dfb 21
 asc '/DDIIGS/MISSION18.PAK'

path19 dfb 21
 asc '/DDIIGS/MISSION19.PAK'

path110 dfb 22
 asc '/DDIIGS/MISSION110.PAK'

path111 dfb 22
 asc '/DDIIGS/MISSION111.PAK'

path112 dfb 22
 asc '/DDIIGS/MISSION112.PAK'

path113 dfb 22
 asc '/DDIIGS/MISSION113.PAK'

path114 dfb 22
 asc '/DDIIGS/MISSION114.PAK'

* master sprite table
sprite_table
  dw billy_sprite       ; player (always first)
  hex 0000              ; NPC slots (populated by level script)
  hex 0000
  hex 0000
  hex 0000
  hex 0000
  hex 0000
  hex 0000
  hex 0000 ; room for more sprites

sprite_table_copy
  hex 0000
  hex 0000
  hex 0000
  hex 0000
  hex 0000
  hex 0000
  hex 0000
  hex 0000

**
** BILLY sprites
**

billy_sprite
  hex 6400 ; +0  ypos
  hex 0100 ; +2  xpos
  hex 0000 ; +4  mirror (0 or 1)
  hex 0000 ; +6  anim_step (unused in new system)
  hex 0500 ; +8  anim_count (unused in new system)
  hex 0900 ; +10 frame width (init to IMAGE01)
  hex 2800 ; +12 frame height (init to IMAGE01)
  hex 0000 ; +14 frame data (patched by init_level)
  hex 6600 ; +16 mask (color 6)
  hex 6000 ; +18 maskhi
  hex 0600 ; +20 masklo
  hex 0100 ; +22 controller (01 = keyboard)
  hex 0000 ; +24 anim_ptr low/high ($0000 = no animation)
  hex 0000 ; +26 anim_frame
  hex 0000 ; +28 anim_timer
  hex 0100 ; +30 dirty (bit0=needs_draw, bit1=needs_erase)
  hex 6400 ; +32 prev_ypos (init same as ypos)
  hex 0100 ; +34 prev_xpos (init same as xpos)
  hex 0900 ; +36 prev_frame_x (init same as frame_x)
  hex 2800 ; +38 prev_frame_y (init same as frame_y)
  da anim_bpunched ; +40 punched_anim pointer
  hex 0000         ; +42 idle_addr (patched by init_level)
  hex 0900         ; +44 idle_x
  hex 2800         ; +46 idle_y
  hex 0000         ; +48 punch_count
  da anim_bfall    ; +50 fall_anim pointer
  hex 0000         ; +52 mask_addr (compiled inverse-mask companion to
                   ;     +14 frame_addr; patched by init_level, kept in
                   ;     sync by advance_walk and :anim_done. NPC slots
                   ;     use +52/+54 as walk_anim/atk_anim — compiled
                   ;     dispatch in draw_all gates on controller==1 so
                   ;     the meaning of +52 stays sprite-type-specific)

*-------------------------------
* Globals (used by erase/draw_sprite)
*-------------------------------
FRAME_X  HEX 0900         ; current frame width
FRAME_Y  HEX 2800         ; current frame height
FRAME_ADDR ds 2            ; current frame data address (set at runtime)
MASK_ADDR  ds 2            ; companion inverse-mask address for compiled
                           ; AND/ORA draw path; consumed by draw_sprite_compiled

*-------------------------------
* Sprite state
*-------------------------------
IMAGE01_XTEMP HEX 0000
IMAGE01_XPOS HEX 0100
IMAGE01_YPOS HEX 6400
IMAGE01_MIRROR HEX 0000
x_scroll_idx HEX 0000
scroll_src_bank dfb $04    ; current source bank for right scroll (= $03 + scroll_right_screen after OP_RIGHT)
transition_pending dfb 0   ; set by scroll_right on wrap, consumed by sync_current_screen
scroll_lsrc_bank dfb $03   ; current source bank for left scroll (= $03 + current_screen - 1, invalid until cs>0)
scroll_lsrc_off dfb 0      ; offset (counts down from 109 toward 0)
sprite_bank da $0002       ; bank where sprite pixel data lives (16-bit for REP $20 load)
scroll_src_off HEX 0000   ; byte offset within source bank scanline
MASKHI HEX 60
MASKLO HEX 06
MASK HEX 66

*-------------------------------
* Level script state
*-------------------------------
script_state dfb SCRIPT_RUN
script_wait_val ds 2          ; 16-bit threshold for WAITX (1 byte for WAITY)
abs_x           ds 2          ; player's absolute X across all screens


**
** WILLIAM sprite info blocks (note William's mask color is E not 6)
**

william_sprite
  hex 5F00 ; +0  ypos
  hex 5800 ; +2  xpos
  hex 0100 ; +4  mirror (0 or 1)
  hex 0000 ; +6  (unused)
  hex 0500 ; +8  (unused)
  hex 0900 ; +10 frame width (init to WILLIAM1)
  hex 2800 ; +12 frame height (init to WILLIAM1)
  hex 0000 ; +14 frame data (patched by init_level)
  hex EE00 ; +16 mask
  hex E000 ; +18 maskhi
  hex 0E00 ; +20 masklo
  hex 0000 ; +22 controller (00 = none)
  hex 0000 ; +24 anim_ptr
  hex 0000 ; +26 anim_frame
  hex 0000 ; +28 anim_timer
  hex 0100 ; +30 dirty
  hex 5F00 ; +32 prev_ypos
  hex 5800 ; +34 prev_xpos
  hex 0900 ; +36 prev_frame_x
  hex 2800 ; +38 prev_frame_y
  da anim_wpunched ; +40 punched_anim
  hex 0000         ; +42 idle_addr (patched by init_level)
  hex 0900         ; +44 idle_x
  hex 2800         ; +46 idle_y
  hex 0000         ; +48 punch_count
  da anim_wfall    ; +50 fall_anim

william2_sprite
  hex 8400 ; +0  ypos
  hex 5800 ; +2  xpos
  hex 0100 ; +4  mirror (0 or 1)
  hex 0000 ; +6  (unused)
  hex 0500 ; +8  (unused)
  hex 0900 ; +10 frame width (init to WILLIAM1)
  hex 2800 ; +12 frame height (init to WILLIAM1)
  hex 0000 ; +14 frame data (patched by init_level)
  hex EE00 ; +16 mask
  hex E000 ; +18 maskhi
  hex 0E00 ; +20 masklo
  hex 0000 ; +22 controller (00 = none)
  hex 0000 ; +24 anim_ptr
  hex 0000 ; +26 anim_frame
  hex 0000 ; +28 anim_timer
  hex 0100 ; +30 dirty
  hex 8400 ; +32 prev_ypos
  hex 5800 ; +34 prev_xpos
  hex 0900 ; +36 prev_frame_x
  hex 2800 ; +38 prev_frame_y
  da anim_wpunched ; +40 punched_anim
  hex 0000         ; +42 idle_addr (patched by init_level)
  hex 0900         ; +44 idle_x
  hex 2800         ; +46 idle_y
  hex 0000         ; +48 punch_count
  da anim_wfall    ; +50 fall_anim

*-------------------------------
* Read JoyX,Y every 11cyc on avg
* Return: X=JoyX, Y=JoyY
* thx: jbrooks BSI
GetJoyXY
  php ;Save irq & mx reg size
  sep #$34 ;sei & 8-bit mx
  phd ;Save DPage
  pea #$C000 ;DP to I/O
  pld ;DP=$C000

  bit $70 ;Start X,Y timers. ~16c to 1st read
  cyc on
  lsr $36 ;5: Force 1MHz
  ldx #1 ;2: Init dual X,Y ctr
  xba ;3: Wait
  xba ;3: Wait
:DualXY0
  lda $64 ;3: Chk JoyX. 10c to DualXY1
  cyc on
  and $65 ;3: Chk JoyY
  bpl :ToSolo ;2/3
  inx ;2: Inc XY
:DualXY1
  lda $64 ;3: Chk JoyX. 10c to DualXY2
  cyc on
  and $65 ;3: Chk JoyY
  bpl :ToSolo ;2/3
  inx ;2: Inc XY
:DualXY2
  lda $64 ;3: Chk JoyX. 13c to DualXY0
  cyc on
  and $65 ;3: Chk JoyY
  bpl :ToSolo ;3
  inx ;2: Inc XY
  bne :DualXY0
:DualXY3
  lda $64 ;3: Chk JoyX and $65 ;3: Chk JoyY
  bmi :SameXY ;3
  dex ;#$FE
:SameXY
  dex ;#$FF
  txy
  bra :Exit

:SoloX
  bit $64 ;3: Chk JoyX
  bmi :SoloXOk ;2/3
  dey ;2
  bra :Exit
:SoloXOk
  inx ;2
  bne :SoloX ;2/3
;#$FF. Fall into dex & Exit

:SoloY
  bit $65 ;3: Chk JoyY
  bmi :SoloYOk ;2/3
  dex ;2
  bra :Exit
:ToSolo
  txy ;2
  bit $64 ;3
  bmi :SoloXOk ;2/3
  bit $65 ;3
  bpl :SameXY ;2/3
:SoloYOk
  iny ;2
  bne :SoloY ;2/3
  dey ;#$FF. Fall into Exit

:Exit
  rol $36 ;Restore CPU speed

  pld ;Restore dpage
  plp ;Restore m,x size & interrupt enable
  rts ;Returns X=JoyX $00-$FF, Y=JoyY $00-$FF

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

]IOBUF = $6C00        ; 1024-byte ProDOS I/O buffer (page-aligned)
]RDBUF = $7000         ; 4KB read buffer

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

* Load MISSION11.PAK -> $4F, unpack to $03 (screen 0)
 lda #$03
 sta unpack_bank
 jsr load_and_unpack
* Copy $03/2000 -> $50/2000 (playfield shadow), then $50 -> $01
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

 pea ^string1
 pea string1
 ldx #$A604
 jsl $E10000        ; DrawCString

 lda #225
 pha
 lda #30
 pha
 ldx #$3a04         ; MoveTo
 jsl $E10000

 pea ^string2
 pea string2
 ldx #$A604
 jsl $E10000        ; DrawCString

 lda #225
 pha
 lda #40
 pha
 ldx #$3a04         ; MoveTo
 jsl $E10000

 pea ^string3
 pea string3
 ldx #$A604
 jsl $E10000        ; DrawCString

 lda #225
 pha
 lda #50
 pha
 ldx #$3a04         ; MoveTo
 jsl $E10000

 pea ^string4
 pea string4
 ldx #$A604
 jsl $E10000        ; DrawCString

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

string1 ASC '   dd II GS',00
string2 ASC '  2026 [cCc]',00
string3 ASC '  Devel/Eval',00
string4 ASC ' Purpose Only',00
string5 ASC 'PLAYER 1: 0000000       PLAYER 2: 0000000',00

over1
* Initial draw of all sprites
 jsr draw_all

*==========================================================
* Main game loop
*==========================================================
game_loop
 jsr wait_for_vbl
 jsr update_overlay
 jsr process_input
 jsr run_script
 jsr update_npcs       ; runs behavior state machines
 jsr update_anims
* erase and draw run back-to-back at the end of the frame so
* sprites are never left in an "erased but not yet redrawn"
* state while the CPU is doing per-frame work. With SHR
* shadowing continuously enabled, any gap here is visible on
* screen as flicker — especially on moving enemies.
 jsr erase_all
 jsr draw_all
 jsr draw_overlay
 jsr draw_ladder_debug  ; outline ladders for debug
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
 bne :rt_override
 pla                   ; scroll_src on current screen — discard
 bra :rt_same_bank     ;   target, don't touch off
:rt_override
 pla                   ; retrieve target bank
 sta scroll_src_bank
 stz scroll_src_off
:rt_same_bank
 lda #1
 sta scroll_right_enabled
* Show POINT_RIGHT overlay for 180 frames
 lda #180
 sta overlay_timer
 lda script_pc
 clc
 adc #2
 sta script_pc
 jmp :exec_loop

:not_right
 cmp #OP_LEFT
 bne :not_left
 ldy #1
 lda [script_pc],y
 sta scroll_left_screen
* Configure left source: bank of target screen, offset starts at
* rightmost valid content byte so first fill pulls real pixels.
* Narrow targets (scr9 = 51 bytes wide, 102px) start at 50;
* full-width targets start at 109.
 clc
 adc #$03
 sta scroll_lsrc_bank
 lda scroll_left_screen
 cmp #9
 bne :opl_wide
 lda #50                   ; scr9 content width = 51 bytes (0..50)
 bra :opl_off_set
:opl_wide
 lda #109
:opl_off_set
 sta scroll_lsrc_off
 lda #1
 sta scroll_left_enabled
 lda script_pc
 clc
 adc #2
 sta script_pc
 jmp :exec_loop

:not_left
 cmp #OP_UP
 beq :do_op_up
 jmp :not_up_op        ; inverted — target moved out of branch range
:do_op_up
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
 cmp #11
 bcc :op_up_anchor_default
 cmp #14
 bcs :op_up_anchor_default
* scr11/12/13: 103px wide (52 bytes). anchor=307 places scr12's
* ladder art (at scr12 byte 37) at world 344 — matching ladder[2].
 lda #<307
 sta scroll_up_anchor
 lda #>307
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
* bank has content in rows 0..112 and empty rows 113..199). Start
* scroll with ufill_top=112 so the fill pulls valid content from
* the first iteration. scroll_up_off = ufill_top + 3 = 115.
* Also set snap_copy_rows so snap_transition only copies the 113
* valid rows, leaving rows 113..182 as the pre-scroll content that
* shifted down during the incremental scroll.
 ldy #1
 lda [script_pc],y     ; target
 cmp #11
 bcc :op_up_off_std    ; target < 11 → full-height
 cmp #14
 bcs :op_up_off_std    ; target >= 14 → full-height
 lda #115
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
 lda #1
 sta scroll_up_enabled
 lda #SCRIPT_WAITUP
 sta script_state
 lda script_pc
 clc
 adc #4                ; opcode + 3 params
 sta script_pc
 rts                   ; yield — wait for scroll to complete

:not_up_op
 cmp #OP_SCRLOCK
 bne :not_scrlock
 stz scroll_right_enabled
 stz scroll_left_enabled
 stz scroll_up_enabled
 inc script_pc          ; opcode only, no params
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
 rts

:not_waitxrev
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
 rts

:not_waity
 cmp #OP_WAITCLR
 bne :not_waitclr
 lda #SCRIPT_WAITCLR
 sta script_state
 inc script_pc          ; opcode only
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
 rts

:not_waitnpc
* OP_NONE — skip 1 byte and continue
 cmp #OP_NONE
 bne :unknown_op
 inc script_pc
 jmp :exec_loop
:unknown_op
* Unknown opcode — halt the script rather than march forward
* into adjacent data (which spawns garbage NPCs).
 lda #SCRIPT_DONE
 sta script_state
 rts

*--- Wait condition checks ---

:check_waitx
* Check if player absolute X >= threshold (16-bit compare)
 lda abs_x+1
 cmp script_wait_val+1
 bcc :rs_rts2           ; not yet (high byte less)
 bne :waitx_done        ; high byte greater — done
 lda abs_x
 cmp script_wait_val
 bcc :rs_rts2           ; low byte less
:waitx_done
 lda #SCRIPT_RUN
 sta script_state
 jmp :exec_loop         ; condition met, resume executing

:check_waitxrev
* Check if player absolute X <= threshold (16-bit compare)
 lda script_wait_val+1
 cmp abs_x+1
 bcc :rs_rts2           ; threshold_hi < abs_hi → abs still greater
 bne :waitxrev_done     ; threshold_hi > abs_hi → done
 lda script_wait_val
 cmp abs_x
 bcc :rs_rts2           ; threshold_lo < abs_lo → still greater
:waitxrev_done
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
check_y_bounds
 stz via_ladder
 cmp #200
 bcs :blocked          ; off-screen Y
 sta :proposed
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
 beq :cl_no
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
 lda #0
 sta :cl_idx
:cl_scan
 ldx :cl_idx
* sprite_world_x >= x_left?
* Compare 16-bit: :swx vs ladder_buf[x..x+1] (low,high)
 lda :swx+1
 cmp ladder_buf+1,x    ; x_left high
 bcc :cl_next          ; swx_hi < xl_hi → too far left
 bne :ge_left          ; swx_hi > xl_hi → ge
 lda :swx
 cmp ladder_buf,x      ; x_left low
 bcc :cl_next          ; swx_lo < xl_lo → too far left
:ge_left
* sprite_world_x <= x_right?
 lda ladder_buf+3,x    ; x_right high
 cmp :swx+1
 bcc :cl_next          ; xr_hi < swx_hi → too far right
 bne :le_right
 lda ladder_buf+2,x    ; x_right low
 cmp :swx
 bcc :cl_next          ; xr_lo < swx_lo → too far right
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
:tmp    dfb 0

* Overlay state (POINT_RIGHT arrow shown on OP_RIGHT)
overlay_timer  dfb 0          ; frames remaining (0 = inactive)
OVERLAY_X      = 100          ; screen byte position (200 pixels / 2)
OVERLAY_Y      = 120          ; screen scanline
OVERLAY_W      = $0C          ; POINT_RIGHT width in bytes
OVERLAY_H      = $10          ; POINT_RIGHT height in rows
OVERLAY_MASK   = $77          ; transparent byte for POINT_RIGHT

*----------------------------------------------------------
* update_overlay - Decrement overlay timer. When it expires,
* erase the overlay rect from the $50 shadow.
*----------------------------------------------------------
update_overlay
 lda overlay_timer
 beq :done
 sec
 sbc #1
 sta overlay_timer
 bne :done
* Timer just hit 0 — erase overlay from screen
 lda #OVERLAY_Y
 sta IMAGE01_YPOS
 lda #OVERLAY_X
 sta IMAGE01_XPOS
 lda #OVERLAY_W
 sta FRAME_X
 lda #OVERLAY_H
 sta FRAME_Y
 jsr erase
:done rts

*----------------------------------------------------------
* draw_overlay - If overlay is active, draw POINT_RIGHT
* at fixed screen position. Uses draw_sprite globals.
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
 lda MASK
 pha
 lda MASKHI
 pha
 lda MASKLO
 pha
* Set overlay globals
 lda #OVERLAY_Y
 sta IMAGE01_YPOS
 lda #OVERLAY_X
 sta IMAGE01_XPOS
 lda #0
 sta IMAGE01_MIRROR
 lda #OVERLAY_W
 sta FRAME_X
 lda #OVERLAY_H
 sta FRAME_Y
 lda spr_pointright
 sta FRAME_ADDR
 lda spr_pointright+1
 sta FRAME_ADDR+1
 lda #OVERLAY_MASK
 sta MASK
 lda #$70
 sta MASKHI
 lda #$07
 sta MASKLO
 jsr draw_sprite
* Restore globals
 pla
 sta MASKLO
 pla
 sta MASKHI
 pla
 sta MASK
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
 jsr draw_sprite
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
* Player advanced 4 bytes (8 pixels) through the world
 lda abs_x
 clc
 adc #8
 sta abs_x
 lda abs_x+1
 adc #0
 sta abs_x+1
 rts
:not_scroll
 cmp #'8'
 beq :do_up
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
* If scroll_up enabled AND on a ladder AND near top, scroll up
 lda scroll_up_enabled
 beq :up_walk
 lda IMAGE01_YPOS
 cmp #UP_SCROLL_THRESH
 bcs :up_walk
* Check if player is on a ladder
 lda IMAGE01_XPOS
 sta chk_xpos
 lda IMAGE01_YPOS
 jsr check_ladder
 bcs :up_walk           ; not on ladder — normal walk
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
* Scroll world up by 4 rows with climbing animation
 jsr advance_climb
 jsr save_sprite
 jsr scroll_up
 jsr load_sprite
 rts
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
 bne :not_left
* If at left scroll threshold AND scroll_left enabled AND
* there's a screen to the left, scroll. Otherwise walk.
 lda scroll_left_enabled
 beq :left_walk
 lda current_screen
 beq :left_walk        ; on screen 0, no left source
 lda IMAGE01_XPOS
 cmp #LEFT_SCROLL_THRESH
 bcs :left_walk        ; xpos > threshold, walk
* Scroll world LEFT by 4 bytes
 jsr save_sprite
 jsr scroll_left
 jsr load_sprite
 jsr sync_current_screen_left
* abs_x retreats by 8 pixels through the world
 lda abs_x
 sec
 sbc #8
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
* abs_x advances by 8 pixels through the world
 lda abs_x
 clc
 adc #8
 sta abs_x
 lda abs_x+1
 adc #0
 sta abs_x+1
 bra :finish_right
:walk_right
 lda IMAGE01_XPOS
 cmp #PLAYER_MAX_X
 bcs :clamp_right      ; at right edge of playfield
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
 lda walk_addr_tbl,x
 sta FRAME_ADDR
 lda walk_addr_tbl+1,x
 sta FRAME_ADDR+1
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
 lda climb_toggle
 beq :use_b1
 lda spr_bclimb2
 sta FRAME_ADDR
 lda spr_bclimb2+1
 sta FRAME_ADDR+1
 rts
:use_b1
 lda spr_bclimb1
 sta FRAME_ADDR
 lda spr_bclimb1+1
 sta FRAME_ADDR+1
 rts
climb_toggle dfb 0

walk_x_tbl dfb $09,$08,$0B,$08
walk_y_tbl dfb $28,$28,$28,$28
walk_addr_tbl ds 8         ; patched by init_level (IMAGE01,IMAGE02,IMAGE03,IMAGE02)

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
* Load first frame from descriptor
 ldy #3               ; offset to first frame in descriptor
 lda (anim_ptr),y     ; frame_x
 sta FRAME_X
 iny
 lda (anim_ptr),y     ; frame_y
 sta FRAME_Y
 iny
 lda (anim_ptr),y     ; duration
 ldy #28
 sta (info_ptr),y     ; anim_timer
 ldy #6               ; frame_addr low in descriptor
 lda (anim_ptr),y
 sta FRAME_ADDR
 iny
 lda (anim_ptr),y     ; frame_addr high
 sta FRAME_ADDR+1
* Write frame data to block and mark dirty, but DON'T snapshot
* prev_xpos/ypos — when check_punch_hit triggers this mid-frame
* on an NPC that fo_approach already moved, save_sprite would
* clobber the prev snapshot fo_approach took, and erase_all
* would erase at the (new) current position, leaving the old
* sprite drawn last frame un-erased. prev_frame_x/y stay at the
* last drawn frame's size, which the union erase in erase_all
* accounts for.
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
 inc IMAGE01_XPOS
 bra :adv_done
:adv_left
 dec IMAGE01_XPOS
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
 jsr save_anim_state
 jmp :next

:load_frame
* Load frame data from descriptor
* Frame offset = 3 + anim_frame * 5
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
 beq :do_hit_now
 bra :try_p2
:try_p2
 lda anim_ptr
 cmp #<anim_punch2
 bne :try_wp
 lda anim_ptr+1
 cmp #>anim_punch2
 beq :do_hit_now
:try_wp
 lda anim_ptr
 cmp #<anim_wpunch
 bne :try_rp
 lda anim_ptr+1
 cmp #>anim_wpunch
 beq :do_hit_now
:try_rp
 lda anim_ptr
 cmp #<anim_rpunch
 bne :try_lp
 lda anim_ptr+1
 cmp #>anim_rpunch
 beq :do_hit_now
:try_lp
 lda anim_ptr
 cmp #<anim_lpunch
 bne :no_punch_hit
 lda anim_ptr+1
 cmp #>anim_lpunch
 bne :no_punch_hit
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
* Load PAK file to bank $4F
 lda #$4F
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

 pea $004F             ; src bank (high word)
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
* copy_50_to_01 - Copy 32KB from $50/2000 to $01/2000
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
 lda #$50
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
* to $50/2000 (playfield shadow).
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
 lda #$50
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

* BCLIMB1 (offset +76)
 ldy #76
 lda [$F0],y
 sta spr_bclimb1

* BCLIMB2 (offset +78)
 ldy #78
 lda [$F0],y
 sta spr_bclimb2

* LCLIMB1 (offset +80)
 ldy #80
 lda [$F0],y
 sta spr_lclimb1

* LCLIMB2 (offset +82)
 ldy #82
 lda [$F0],y
 sta spr_lclimb2

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

* Patch anim_jump: 3 frames
 lda spr_jump1
 sta anim_jump+3+3
 lda spr_jump2
 sta anim_jump+3+8
 lda spr_jump3
 sta anim_jump+3+13

* Patch anim_kick: 2 frames
 lda spr_kick1
 sta anim_kick+3+3
 lda spr_kick2
 sta anim_kick+3+8

* Patch anim_punch1: 2 frames
 lda spr_punch11
 sta anim_punch1+3+3
 lda spr_punch12
 sta anim_punch1+3+8

* Patch anim_punch2: 2 frames
 lda spr_punch21
 sta anim_punch2+3+3
 lda spr_punch22
 sta anim_punch2+3+8

* Patch anim_bpunched: 1 frame
 lda spr_bpunched
 sta anim_bpunched+3+3

* Patch anim_wpunched: 1 frame
 lda spr_wpunched
 sta anim_wpunched+3+3

* Patch anim_wfall: 2 frames
 lda spr_wfall
 sta anim_wfall+3+3
 lda spr_wfallen
 sta anim_wfall+3+8

* Patch anim_bfall: 1 frame
 lda spr_img01
 sta anim_bfall+3+3

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

* Patch billy_sprite frame_addr (+14) and idle_addr (+42)
 lda spr_img01
 sta billy_sprite+14
 sta billy_sprite+42

* Patch william_sprite frame_addr and idle_addr
 lda spr_william1
 sta william_sprite+14
 sta william_sprite+42

* Patch william2_sprite frame_addr and idle_addr
 lda spr_william1
 sta william2_sprite+14
 sta william2_sprite+42

* Patch walk_addr_tbl
 lda spr_img01
 sta walk_addr_tbl
 lda spr_img02
 sta walk_addr_tbl+2
 lda spr_img03
 sta walk_addr_tbl+4
 lda spr_img02
 sta walk_addr_tbl+6

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
spr_bclimb1    ds 2
spr_bclimb2    ds 2
spr_lclimb1    ds 2
spr_lclimb2    ds 2

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
* 1) Shift bytes 1-110 left by one in bank $50 for 183 lines
* 2) Fill right edge from bank $51 (x_scroll_idx bytes)
* 3) Blit 110-byte wide playfield from $50 to $E1
* 4) Redraw sprite
*----------------------------------------------------------
scroll_right
* Scroll playfield 4 bytes (2 words, 8 pixels) to the left.
* Coarse NES-style scroll: shift in 16-bit mode, then fill
* the rightmost 4 bytes from the next screen's background.
*
* Flicker-cover: erase_all at top of the frame has already
* wiped the player sprite off $01/$E1. The scroll composite
* pipeline (fast_blit_50_55 / draw on $55 / stack_blit to $E1)
* takes several ms and races the video beam, so the sprite
* would be visibly absent until the stack_blit catches up.
* Redraw the sprite on $01 now (shadowed to $E1) so it stays
* visible at its current screen position while we work. The
* final stack_blit replaces everything atomically at the end.
 jsr draw_sprite

 lda x_scroll_idx
 clc
 adc #4
 sta x_scroll_idx

 clc
 xce                   ; native mode
 rep $30               ; 16-bit A, X, Y
 mx %00

* Step 1: Shift each scanline 4 bytes left in bank $50.
* Copy words from offset+4 to offset, 53 words (106 bytes).
 lda #$2004
 sta $F0               ; src = line_start + 4
 lda #$2000
 sta $F3               ; dst = line_start
 sep $20
 lda #$50
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
* If scroll_src_off is near the screen boundary (108),
* fill 2 bytes from this bank and 2 from the next.
 sep $20
 mx %10
 lda scroll_src_off
 cmp #108
 bcc :fill_normal
 beq :fill_split
* src_off > 108 shouldn't happen, but treat as normal
:fill_normal
 rep $20
 mx %00
 lda scroll_src_off
 and #$00FF
 clc
 adc #$2000
 sta $F0               ; src = scroll_src_bank/(2000 + scroll_src_off)
 lda #$206A            ; dst = $50/(2000 + 106)
 sta $F3
 sep $20
 lda scroll_src_bank
 sta $F2
 lda #$50
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
* If scroll_src was pulling from the CURRENT screen's bank, we
* were scrolling through the current screen itself (e.g. after
* OP_UP :neg set scroll_src to the upper screen + up_count) and
* now need to transition to scroll_right_screen's bank.
* Otherwise we were already pulling from scroll_right_screen's
* bank (typical linear scroll completing a transition), so the
* next source is the linear successor — just inc.
 lda current_screen
 clc
 adc #$03
 cmp scroll_src_bank
 bne :fw_linear
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
 lda #$206A            ; dst = $50/(2000+106)
 sta $F3
 sep $20
 lda scroll_src_bank
 sta $F2
 lda #$50
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
 lda #$206C            ; dst = $50/(2000+108)
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
 lda #$50
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

:fill_done
 rep $20
 mx %00

* Step 3: Fast unrolled blit $50 -> $55 (back buffer)
 jsr fast_blit_50_55

 sec
 xce                   ; back to emulation mode

* Step 4: Draw sprite onto back buffer $55
 lda #$55
 sta draw_bank
 lda #$00
 sta draw_bank+1
 jsr draw_sprite
* Composite the HUD overlay (if active) onto $55 too, so the
* stack_blit preserves it. Otherwise the scrolled $55 overwrites
* the overlay on $E1 and it flickers until draw_overlay redraws
* it at the end of the frame.
 jsr draw_overlay

* Step 5: Stack-blit $55 -> $E1 (screen) for flicker-free update
 clc
 xce                   ; native mode
 rep $30
 jsr stack_blit_55_e1

 sec
 xce                   ; back to emulation mode

* Restore draw_bank for normal (non-scroll) draw_sprite calls
 lda #$01
 sta draw_bank
 lda #$00
 sta draw_bank+1
* Brief delay after stack blit's CLI so pending sound
* interrupts (NTP) can fire before we return to the caller.
 ldx #0
:irq_wait
 nop
 dex
 bne :irq_wait
 ldx #0
:irq_wait2
 nop
 dex
 bne :irq_wait2
 rts

*----------------------------------------------------------
* scroll_left - Mirror of scroll_right.
* Shift each scanline 4 bytes RIGHT in bank $50, then fill
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
* Flicker-cover: see scroll_right for rationale. Re-draw the
* player on $01 (shadowed to $E1) before the scroll composite
* pipeline, so the sprite doesn't visibly vanish in the gap
* between erase_all and the final stack_blit.
 jsr draw_sprite

 clc
 xce
 rep $30
 mx %00

* Step 1: Shift each scanline 4 bytes right in bank $50.
* Copy 53 words from offset 0..104 to offset 4..108.
* Iterate Y from 104 DOWN to 0 — negative Y would add ~$FFFE to
* the 24-bit pointer (lda [dp],y doesn't wrap within bank), so
* we keep Y non-negative and hold F0/F3 at the line's left edge.
 lda #$2000             ; src base = line_start + 0
 sta $F0
 lda #$2004             ; dst base = line_start + 4
 sta $F3
 sep $20
 lda #$50
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
 lda #$50
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
 lda #$50
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
 lda #$50
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

* Steps 3-5: same blit/draw/blit pipeline as scroll_right
 jsr fast_blit_50_55
 sec
 xce
 lda #$55
 sta draw_bank
 lda #$00
 sta draw_bank+1
 jsr draw_sprite
 jsr draw_overlay      ; composite HUD onto $55
 clc
 xce
 rep $30
 jsr stack_blit_55_e1
 sec
 xce
 lda #$01
 sta draw_bank
 lda #$00
 sta draw_bank+1
 ldx #0
:lirq_wait
 nop
 dex
 bne :lirq_wait
 ldx #0
:lirq_wait2
 nop
 dex
 bne :lirq_wait2
 rts

* scroll_left scratch
:old_lo     dfb 0
:nfp        dfb 0
:nfc        dfb 0
:prev_start dfb 0

*----------------------------------------------------------
* scroll_up - Vertical scroll: shift all rows DOWN by 4 in
* bank $50, then fill the top 4 rows from scroll_up_bank
* (the screen ABOVE) at scroll_up_off (counts down from 182).
* When scroll_up_off would go below 3, snap-transition: copy
* the entire source bank to $50 and update current_screen.
*----------------------------------------------------------
scroll_up
* Flicker-cover: see scroll_right for rationale. Re-draw the
* player on $01 (shadowed to $E1) before the scroll composite
* pipeline. Covers both the incremental (:su_normal) path and
* the :snap_transition path.
 jsr draw_sprite

 lda scroll_up_off
 cmp #30              ; fire snap early so the last ~28 rows of
 bcs :su_normal       ; scroll don't show an invisible ladder gap
 jmp :snap_transition ; above the scr5 ladder-top art
:su_normal
 clc
 xce
 rep $30
 mx %00

* Step 1: shift rows down by 4 in $50.
* Iterate from row 178 down to row 0, copying to row+4.
* Source addr starts at row 178: $2000 + 178*$A0 = $8F40
* Dest addr starts at row 182: $2000 + 182*$A0 = $91C0
 lda #$8F40
 sta $F0
 lda #$91C0
 sta $F3
 sep $20
 lda #$50
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
* Dynamic align: compute per-row offsets from world_offset
 jsr compute_up_align
 lda up_count
 beq :ufill_skip        ; no overlap — skip fill entirely
* Add up_src_start to F0
 lda $F0
 clc
 adc up_src_start
 sta $F0
* Set F3 = $50/(2000 + up_dst_start)
 lda #$2000
 clc
 adc up_dst_start
 sta $F3
 sep $20
 lda scroll_up_bank
 sta $F2
 lda #$50
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
 sta $F3                ; dst = $50/$2000 (playfield row 0, byte 0)
 sep $20
 lda scroll_up_lbank
 sta $F2
 lda #$50
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
* Dest: $50/(2000 + rgap_start)
 lda #$2000
 clc
 adc :rgap_start
 sta $F3
 sep $20
 lda scroll_up_rbank
 sta $F2
 lda #$50
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

* Pipeline: blit, draw, blit
 jsr fast_blit_50_55
 sec
 xce
 lda #$55
 sta draw_bank
 lda #$00
 sta draw_bank+1
 jsr draw_sprite
 jsr draw_overlay      ; composite HUD onto $55
 clc
 xce
 rep $30
 jsr stack_blit_55_e1
 sec
 xce
 lda #$01
 sta draw_bank
 lda #$00
 sta draw_bank+1
 ldx #0
:uirq_wait
 nop
 dex
 bne :uirq_wait
 ldx #0
:uirq_wait2
 nop
 dex
 bne :uirq_wait2
 rts

*----------------------------------------------------------
* :snap_transition - End of vertical scroll: copy source
* screen entirely to $50 and update current_screen.
*----------------------------------------------------------
:snap_transition
 clc
 xce
 rep $30
 mx %00
* Copy source screen to $50 row-by-row with dynamic horizontal
* align (computed from world_offset vs UP_X_ANCHOR).
 jsr compute_up_align
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
 sta $F3                ; dst = $50/(2000 + up_dst_start)
 sep $20
 lda scroll_up_bank
 sta $F2
 lda #$50
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
 sta $F3                ; dst = $50/2000
 sep $20
 lda scroll_up_lbank
 sta $F2
 lda #$50
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
 lda #$50
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

* Lower-screen fill: after a narrow-height target (scr11/12/13)
* copy, fill the remaining 70 playfield rows (113..182) from the
* lower screens. Their horizontal placement is independent of
* the target's: scr9 is left-aligned (playfield 0..51, 52 bytes),
* scr8 fills the rest to the right (playfield 52..109, 58 bytes).
* Pull rows 0..69 so the top of each lower screen lines up with
* playfield row 113.
 lda scroll_up_screen
 and #$00FF
 cmp #12
 beq :snap_lower_go
 jmp :snap_lower_done
:snap_lower_go
* scr9 fill — playfield bytes 0..51, rows 113..182.
 lda #$2000
 sta $F0               ; src = scr9/$2000 (row 0, byte 0)
 lda #$66A0            ; dst = $50/$66A0 (row 113, byte 0)
 sta $F3
 sep $20
 lda #$0C              ; scr9 bank
 sta $F2
 lda #$50
 sta $F5
 rep $20
 ldx #70
:snap_drow ldy #0
:snap_dwrd lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy #52               ; scr9 content width
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
* scr8 fill — playfield bytes 52..109 (58 bytes), rows 113..182.
 lda #$2000
 sta $F0               ; src = scr8/$2000 (row 0, byte 0)
 lda #$66D4            ; dst = $50/$66A0 + 52 (row 113, byte 52)
 sta $F3
 sep $20
 lda #$0B              ; scr8 bank
 sta $F2
 lda #$50
 sta $F5
 rep $20
 ldx #70
:snap_dr_row ldy #0
:snap_dr_wrd lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy #58               ; playfield bytes 52..109 = 58 bytes
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
 jsr load_screen_bounds
 lda up_dst_start
 beq :snap_pos_src       ; dst_start=0 means :pos or :no_overlap
 lda scroll_up_bank
 sta scroll_src_bank
 lda up_count
 sta scroll_src_off
 bra :snap_src_done
:snap_pos_src
 lda scroll_up_rbank
 sta scroll_src_bank
 lda up_src_start
 sta scroll_src_off
:snap_src_done
 lda current_screen
 beq :snap_no_left
 clc
 adc #$02              ; lsrc = $03 + (cs-1) = $02 + cs
 sta scroll_lsrc_bank
 lda #109
 sta scroll_lsrc_off
 bra :snap_loaded
:snap_no_left
 lda #$03
 sta scroll_lsrc_bank
 stz scroll_lsrc_off
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
 stz climb_toggle       ; next climb starts on BCLIMB1
* Disable the ladder Billy just climbed by locating it from his
* current world_x and setting y_top=255 so check_ladder fails
* for any proposed y. Prevents re-climbing "invisible" after snap.
 lda ladder_count
 beq :dl_done
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
 bra :dl_done
:dl_next
 txa
 clc
 adc #6
 tax
 dec :dl_cnt
 bne :dl_scan
:dl_done

* Blit the new playfield to screen
 clc
 xce
 rep $30
 mx %00
 jsr fast_blit_50_55
 sec
 xce
 lda #$55
 sta draw_bank
 lda #$00
 sta draw_bank+1
 jsr draw_sprite
 jsr draw_overlay      ; composite HUD onto $55
 clc
 xce
 rep $30
 jsr stack_blit_55_e1
 sec
 xce
 lda #$01
 sta draw_bank
 lda #$00
 sta draw_bank+1
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
* fast_blit_50_55 - Unrolled blit from bank $50 to bank $55
* 110 bytes (55 words) wide, 183 lines.
* Entry: native mode, REP $30 (16-bit A/X/Y).
*----------------------------------------------------------
fast_blit_50_55
 rep $30               ; assert 16-bit A/X/Y for assembler MX tracking
 ldx #0                ; line offset from $xx2000
 ldy #183              ; line counter

:line
]idx = 108
 LUP 55
 LDAL $502000+]idx,x
 STAL $552000+]idx,x
]idx = ]idx-2
 --^

 txa
 clc
 adc #$00A0
 tax
 dey
 beq :done
 jmp :line
:done rts

*----------------------------------------------------------
* stack_blit_55_e1 - Stack-based blit from $55 to screen via bank $01
* SHR shadow is already enabled ($01->$E1). Maps stack writes to
* bank $01 via WrCardRAM, then uses PHA to write each word.
* 110 bytes wide, 183 lines.
* Entry: native mode, REP $30. Trashes A/X/Y/S (S restored).
*----------------------------------------------------------
stack_blit_55_e1
 rep $30               ; assert 16-bit A/X/Y for assembler MX tracking
 tsc
 sta :save_s           ; save stack pointer

 sei                   ; no interrupts while stack is remapped
 sep $20
 sta $C005             ; WrCardRAM: writes to bank $00 -> bank $01
 rep $20

 ldx #0                ; source line offset
 ldy #183              ; line counter

:line txa
 clc
 adc #$206D            ; S = $2000 + line_offset + 109
 tcs

]idx = 108
 LUP 55
 LDAL $552000+]idx,x
 pha
]idx = ]idx-2
 --^

 txa
 clc
 adc #$00A0
 tax
 dey
 beq :done
 jmp :line
:done
 sep $20
 sta $C004             ; WrMainRAM: restore normal writes
 rep $20

 lda :save_s
 tcs                   ; restore stack pointer
 cli                   ; re-enable interrupts
 rts

:save_s ds 2

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
 dfb $01             ; flags: advance position
 dfb $0A,$28,3       ; JUMP1
  hex 0000             ; patched: JUMP1
 dfb $0F,$1E,12      ; JUMP2
  hex 0000             ; patched: JUMP2
 dfb $0D,$20,3       ; JUMP3
  hex 0000             ; patched: JUMP3

anim_kick
 dfb 2               ; num_frames
 dfb $14             ; max_width (KICK2 is widest)
 dfb $00             ; flags: none
 dfb $09,$28,12      ; KICK1
  hex 0000             ; patched: KICK1
 dfb $14,$22,12      ; KICK2
  hex 0000             ; patched: KICK2

anim_punch1
 dfb 2               ; num_frames
 dfb $10             ; max_width (PUNCH12 is widest)
 dfb $00             ; flags: none
 dfb $0B,$28,6       ; PUNCH11
  hex 0000             ; patched: PUNCH11
 dfb $10,$28,6       ; PUNCH12
  hex 0000             ; patched: PUNCH12

anim_punch2
 dfb 2               ; num_frames
 dfb $10             ; max_width (PUNCH22 is widest)
 dfb $00             ; flags: none
 dfb $0A,$28,6       ; PUNCH21
  hex 0000             ; patched: PUNCH21
 dfb $10,$28,6       ; PUNCH22
  hex 0000             ; patched: PUNCH22

anim_bpunched
 dfb 1               ; num_frames
 dfb $0B             ; max_width
 dfb $00             ; flags: none (one-shot)
 dfb $0B,$28,5       ; BPUNCHED: 11 wide, 40 tall, 5 VBLs
  hex 0000             ; patched: BPUNCHED

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
 dfb $00             ; flags: none (one-shot, placeholder)
 dfb $09,$28,33      ; IMAGE01: 9 wide, 40 tall, 33 VBLs
  hex 0000             ; patched: IMAGE01

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

*----------------------------------------------------------
* erase - Restore the background behind the sprite
* Copies the rectangle at the sprite's current position
* from the clean background in bank $50 back to the screen
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
* Set up source pointer (background copy at $50/2000) in DP 4-6
 LDA #$50
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
 LDA draw_bank
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

wait_for_vbl
:lp1 bit $c019
 bmi :lp1 ; wait for current VBL to end
:lp2 bit $c019
 bpl :lp2 ; wait for next VBL to start
 rts

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

*-------------------------------
* Globals (used by erase/draw_sprite)
*-------------------------------
FRAME_X  HEX 0900         ; current frame width
FRAME_Y  HEX 2800         ; current frame height
FRAME_ADDR ds 2            ; current frame data address (set at runtime)

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
draw_bank da $0001         ; bank for draw_sprite destination (default $01, shadowed to $E1)
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

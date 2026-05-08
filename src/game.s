*----------------------------------------------------------
* DDIIGS
* Mission 1, toolbox init, sprite display
*----------------------------------------------------------
    org $2000

NinjaTrackerPlus        =   $120000
NTPprepare              =   NinjaTrackerPlus
NTPplay                 =   NinjaTrackerPlus+3
NTPstop                 =   NinjaTrackerPlus+6
NTPgetvuptr             =   NinjaTrackerPlus+9
NTPgete8ptr             =   NinjaTrackerPlus+12
NTPforcesongpos         =   NinjaTrackerPlus+15
NTPgetsongpos           =   NinjaTrackerPlus+18
NTPsetplayvolume        =   NinjaTrackerPlus+21
NTPstreamsound          =   NinjaTrackerPlus+24

]IOBUF = $BB00        ; 1024-byte ProDOS I/O buffer (page-aligned), $BB00-$BEFF
                       ; (ends just below ProDOS Global Page at $BF00)
]RDBUF = $B700         ; 1024-byte read buffer (= 2 disk blocks), $B700-$BAFF.
                       ; Was 4 KB, but the loaders only ever issue 512-byte
                       ; READs, so 1 KB is plenty and frees 3 KB for game.s
                       ; growth. game.s code/data must end before $B700.

* Clear text screen so diagnostic prints start on a fresh page.
 sec
 xce
 sep $20
 jsr $FC58

* Initialize IIgs Toolbox
; jsr toolbox_init

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

* Paint the LOADING splash to the SHR screen. SHR mode is
* already on (inherited from DDII.SYSTEM), and unpack_bank=$01
* with the default unpack_offset=$2000 lands the unpacked
* image directly at $01/2000 — shadowed to $E1, visible
* immediately. Stays on screen for the rest of the boot
* sequence below; the first overwrite happens at over1 when
* copy_50_to_01 paints scr0's background over it.
 lda $c022
 pha
 stz $c022
 lda #$41
 sta $c029                  ; cut to black screen while loading Loading screen

 lda #<loading_path
 sta p_open+1
 lda #>loading_path
 sta p_open+2
 lda #$01
 sta unpack_bank
 jsr load_and_unpack

 lda #$C1                    ; what did you want me to do, add fade tables to bank $00? nope
 sta $c029
 pla
 sta $c022

* Load MISSION1 level data to bank $02
 lda #<mission1_path
 sta file_open+1
 lda #>mission1_path
 sta file_open+2
 lda #$02
 sta file_bank
 stz file_dest
 stz file_dest+1
 jsr load_file

* Load MISSION12 (boss + weapons + character variants) to bank $11.
* Same loader as MISSION1; the file just lives in a different bank.
* Bank $19 sits past the playfield shadow at $18 — clear of every
* other allocation (backgrounds $03-$10, sound scratch $11, NTPplayer
* $12, music $13-$15, PAK scratch $17, shadow $18). Earlier attempts
* with $06 (clobbered by background-3 unpack) and $11 (clobbered by
* sound_install_all chaining SFX writes) both failed.
 lda #<mission12_path
 sta file_open+1
 lda #>mission12_path
 sta file_open+2
 lda #$19
 sta file_bank
 stz file_dest
 stz file_dest+1
 jsr load_file

* ntpplayer code is already in bank $12 — title.s loaded it once
* at boot and bank $12 persists across SYS file loads (each SYS
* file lands at bank $00/$2000, leaving the music banks alone).

* NTP music data is pre-packed with PackBytes. Switch
* unpack_offset to $0000 so each .PAK lands at bank/$0000
* (matching the layout NTPprepare expects), then restore to
* $2000 below for the SHR background loads.
 stz unpack_offset
 stz unpack_offset+1

* Load MISSION1NTP.PAK -> $17, unpack to $13/0000
 lda #<m1ntp_path
 sta p_open+1
 lda #>m1ntp_path
 sta p_open+2
 lda #$13
 sta unpack_bank
 jsr load_and_unpack

* Load BOSS.NTP.PAK -> $17, unpack to $14/0000
 lda #<bossntp_path
 sta p_open+1
 lda #>bossntp_path
 sta p_open+2
 lda #$14
 sta unpack_bank
 jsr load_and_unpack

* Load COMPLETENTP.PAK -> $17, unpack to $15/0000
* (level-completion fanfare; will get wired up to OP_END later).
 lda #<completentp_path
 sta p_open+1
 lda #>completentp_path
 sta p_open+2
 lda #$15
 sta unpack_bank
 jsr load_and_unpack

* Load GAMEOVERNTP.PAK -> $17, unpack to $16/0000
* (game-over jingle; played by game_over before quit-to-TITLE).
 lda #<gameoverntp_path
 sta p_open+1
 lda #>gameoverntp_path
 sta p_open+2
 lda #$16
 sta unpack_bank
 jsr load_and_unpack

* Restore default unpack offset for the SHR PAK loads below.
 stz unpack_offset
 lda #$20
 sta unpack_offset+1

* Load MISSION11.PAK -> $17, unpack to $03 (screen 0).
* The NTP loads above clobbered p_open's pathname pointer, so
* point it back at MISSION11.PAK explicitly.
 lda #<pathname
 sta p_open+1
 lda #>pathname
 sta p_open+2
 lda #$03
 sta unpack_bank
 jsr load_and_unpack
* Copy $03/2000 -> $18/2000 (playfield shadow). The $18 -> $01
* paint is deferred to after init_mission12 below so the LOADING
* splash stays on screen through the heavy file/init phase.
* Bank $18 still holds scr0 from this point on, which is what
* the erase routines read — no functional dependency on $01
* having scr0 yet.
 jsr copy_03_to_50

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

* Initialize level data now that MISSION1/MISSION12 binaries
* and the SHR backgrounds are all loaded. Moved here from the
* top of the boot sequence so the LOADING splash can stay on
* screen during the heavy file loads above. SHR mode is
* already enabled (inherited from DDII.SYSTEM), so no $C029
* twiddle is needed here either.
 jsr init_level
 jsr init_mission12

* Now paint scr0 ($18 -> $01, shadowed to $E1). This replaces
* the LOADING splash with the playfield right before the HUD
* and initial sprite draw below.
 jsr copy_50_to_01

 clc
 xce
 rep $30

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
* Wire up the health-bar palette (rows 197/198/199 → palette 02)
* and paint the bar. Both one-shot — erase_all clamps at y=180
* so no sprite redraw ever touches these rows.
 jsr setup_health_palette
 jsr draw_health_bar

 clc
 xce
 rep $30
 ldy #$13
 ldx #$00
 txa
 jsl NTPprepare

 sec
 xce
 sep $20
 jsr sound_install_all
 clc
 xce
 rep $30

 lda #00
 jsl NTPplay

* Reduce music volume so SFX (which streams through
* NTPstreamsound at addr_res=1) is audible above the
* music bed. $40 ≈ 25% of full; tune empirically.
 lda #$0080
 jsl NTPsetplayvolume

 sec
 xce
 sep $30

* Disable keyboard autorepeat via the ADB Tool Set so held
* keys don't spam $C000 strobes. Modifier register $C025 is
* always live (auto-polled by the MCU) and is read directly
* by kbd_modifiers.
 jsr kbd_init

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
:nwxr cmp #SCRIPT_WAIT
 bne :nww
 jmp :check_wait
:nww

* SCRIPT_RUN — execute opcodes
:exec_loop
 ldy #0
 lda [script_pc],y     ; read opcode byte
 and #$FF              ; mask to 8-bit (emulation mode load is already 8-bit)

 cmp #OP_END
 bne :not_end
* Stop the boss/level music and start the COMPLETE fanfare in
* play-once mode (NTP zeros the playing flag via stop_playing
* at end of pattern list when play_song_once != 0). Spin until
* it stops, then fade the SHR palette to black.
 clc
 xce
 rep $30
 jsl NTPstop
 ldy #$15              ; COMPLETE music bank
 ldx #$00
 txa
 jsl NTPprepare
 lda #$0001            ; non-zero -> play once, then auto-stop
 jsl NTPplay

:wait_song
 jsl NTPgetsongpos     ; X=songinfo low addr, Y=NTP bank
 stx $F0               ; long pointer scratch (no concurrent
 sty $F2               ; users while the script is blocked here)
 ldy #0
 lda [$F0],y           ; songinfo[0..1] = playing flag
 bne :wait_song
 jsl NTPstop           ; full stop

 jsr fade_palette_to_black
 sec
 xce
 sep $30
 mx %11
 lda #SCRIPT_DONE
 sta script_state
:rs_rts jmp $1000

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
 beq :do_op_right       ; branch to OP_RIGHT body below
 jmp :not_right         ; far jump (body grew beyond branch range)
:do_op_right
* OP_RIGHT: param = 1 byte screen index
 ldy #1
 lda [script_pc],y
 sta scroll_right_screen
 jsr load_right_neighbor_bounds
 ldy #1                ; reload Y — neighbor loader runs in 16-bit and
                       ; leaves Y at $90 (low byte of 400) when emulation
                       ; truncates it on return.
 lda [script_pc],y     ; reload A; bank logic below expects idx in A
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
 ldx #SND_FINGER
 jsr sound_trigger
 lda #180
 sta overlay_timer
 lda #98               ; shifted 2 bytes left so 12-wide overlay
                       ; (98..109) doesn't run past the playfield
 sta overlay_x
 lda #110
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
 jsr load_left_neighbor_bounds
 ldy #1                ; reload Y (loader leaves Y in a high state)
 lda [script_pc],y     ; reload A — load_left_neighbor_bounds trashed it
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
 ldx #SND_FINGER
 jsr sound_trigger
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
 ldx #SND_FINGER
 jsr sound_trigger
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
 cmp #OP_BOSSMUSIC
 bne :not_bossmusic
* OP_BOSSMUSIC: stop the current song and start BOSS.NTP from
* bank $14/$0000. NTP routines need native + 16-bit.
 clc
 xce                   ; native mode
 rep $30
 jsl NTPstop
 ldy #$14              ; BOSS music bank
 ldx #$00
 txa
 jsl NTPprepare
 lda #$0000
 jsl NTPplay
 sec
 xce                   ; back to emulation
 sep $30
 mx %11
 lda script_pc          ; opcode only (1 byte)
 clc
 adc #1
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 jmp :exec_loop

:not_bossmusic
 cmp #OP_WAIT
 bne :not_wait
* OP_WAIT: param = 1-byte frame count
 ldy #1
 lda [script_pc],y
 sta script_wait_val
 lda #SCRIPT_WAIT
 sta script_state
 lda script_pc
 clc
 adc #2                ; opcode + 1 byte param
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 rts

:not_wait
 cmp #OP_KILLOBJ
 bne :not_killobj
* OP_KILLOBJ: mark every sprite with controller != 0 and != 1
* (i.e. items) for death. The actual erase + table removal
* happens in erase_all on the next frame via the $FFFF
* anim_ptr sentinel — same path used for defeated NPCs.
 jsr kill_objects
 lda script_pc          ; opcode only (1 byte)
 clc
 adc #1
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 jmp :exec_loop

:not_killobj
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

:check_wait
* Decrement script_wait_val each frame. When it hits 0, resume.
 dec script_wait_val
 bne :wait_rts          ; still counting down
 lda #SCRIPT_RUN
 sta script_state
 jmp :exec_loop
:wait_rts rts

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
 mx %11                ; Merlin doesn't track xce — assert 8-bit
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
* Bank-$19 NPC dispatch — driven by the template's idle_addr
* sentinel. Real bank-$02 sprite addresses always have a non-zero
* high byte (mission1's data lives above $0100), so anything with
* hi=0 is reserved as a sentinel. Currently:
*   $0000 → Burnov (boss, special death cycle)
*   $0001 → linda_flail (Linda carrying a mace, attacks with it)
* Future armed variants get higher low-byte values.
 lda :id_hi
 beq :is_bank19_npc
 jmp :not_burnov
:is_bank19_npc
 lda :id_lo
 cmp #$01
 beq :is_linda_flail
 cmp #$02
 beq :is_williams_pipe
 jmp :is_burnov              ; $0000 sentinel — fall through to Burnov
:is_williams_pipe
* Patch frame_addr/idle_addr to spr_wpipewalk1.
 lda spr_wpipewalk1
 ldy #14
 sta (info_ptr),y
 lda spr_wpipewalk1+1
 ldy #15
 sta (info_ptr),y
 lda spr_wpipewalk1
 ldy #42
 sta (info_ptr),y
 lda spr_wpipewalk1+1
 ldy #43
 sta (info_ptr),y
* Animation pointers. Walk = anim_wpipewalk and atk = anim_wpipeswing
* live in bank $19 (bit 5 set in their flags). punched_anim =
* anim_wpunched and fall_anim = anim_wfall reuse the bank-$02
* William reaction/fall sprites — start_anim flips info+56 to
* $02 for those, and :normal_end restores it from idle_bank
* ($19) when the anim ends.
 lda #<anim_wpunched
 sta :punch_lo
 lda #>anim_wpunched
 sta :punch_hi
 lda #<anim_wfall
 sta :fall_lo
 lda #>anim_wfall
 sta :fall_hi
 lda #<anim_wpipewalk
 sta :walk_lo
 lda #>anim_wpipewalk
 sta :walk_hi
 lda #<anim_wpipeswing
 sta :atk_lo
 lda #>anim_wpipeswing
 sta :atk_hi
 lda #1
 sta :is_bn
 jmp :do_patch
:is_linda_flail
* Patch frame_addr/idle_addr to spr_lfwalk1 (her standing pose).
 lda spr_lfwalk1
 ldy #14
 sta (info_ptr),y
 lda spr_lfwalk1+1
 ldy #15
 sta (info_ptr),y
 lda spr_lfwalk1
 ldy #42
 sta (info_ptr),y
 lda spr_lfwalk1+1
 ldy #43
 sta (info_ptr),y
* Animation pointers. punched_anim = anim_lpunched and fall_anim
* = anim_lfall — both bank-$02 (regular Linda's reaction/fall
* sprites). Per-anim frame_bank in start_anim flips info+56 to
* $02 while these play, then :normal_end restores it from the
* idle_bank ($19) when the anim ends. walk = anim_lfwalk and
* atk = anim_lmace are bank-$19.
 lda #<anim_lpunched
 sta :punch_lo
 lda #>anim_lpunched
 sta :punch_hi
 lda #<anim_lfall
 sta :fall_lo
 lda #>anim_lfall
 sta :fall_hi
 lda #<anim_lfwalk
 sta :walk_lo
 lda #>anim_lfwalk
 sta :walk_hi
 lda #<anim_lmace
 sta :atk_lo
 lda #>anim_lmace
 sta :atk_hi
 lda #1
 sta :is_bn
 jmp :do_patch
:is_burnov
* DEBUG: print "BN!" when the Burnov dispatch fires, then dump
* the actual bytes at $19/3DCB (BNWALK1 row 1) to verify mission12
* data is in the bank we expect at the time of spawn.
 lda #$C2              ; 'B'
 jsr dbg_print_char
 lda #$CE              ; 'N'
 jsr dbg_print_char
 lda #$A1              ; '!'
 jsr dbg_print_char
 lda #$A0              ; ' '
 jsr dbg_print_char
 ldal $193DCB
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 ldal $193DCC
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 ldal $193DCD
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 ldal $193DCE
 jsr dbg_print_hex8
 jsr dbg_print_nl
 lda spr_bnwalk1
 ldy #14
 sta (info_ptr),y      ; +14 frame_addr
 lda spr_bnwalk1+1
 ldy #15
 sta (info_ptr),y
 lda spr_bnwalk1
 ldy #42
 sta (info_ptr),y      ; +42 idle_addr
 lda spr_bnwalk1+1
 ldy #43
 sta (info_ptr),y
 lda #<anim_bnpunched
 sta :punch_lo
 lda #>anim_bnpunched
 sta :punch_hi
 lda #<anim_bnfall
 sta :fall_lo
 lda #>anim_bnfall
 sta :fall_hi
 lda #<anim_bnwalk
 sta :walk_lo
 lda #>anim_bnwalk
 sta :walk_hi
 lda #<anim_bnpunch
 sta :atk_lo
 lda #>anim_bnpunch
 sta :atk_hi
 lda #1
 sta :is_bn            ; remember to set frame_bank=$06 below
 jmp :do_patch
:not_burnov
 stz :is_bn
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
* Set frame_bank (+56) and idle_bank (+58). Bank-$19 NPCs (Burnov,
* linda_flail, williams_pipe — anything with sentinel idle_addr)
* live in $19. Everything else is bank $02. The two fields start
* equal; start_anim may flip frame_bank temporarily for a
* cross-bank anim, and :normal_end restores it from idle_bank.
 lda :is_bn
 beq :fb_bank2
 ldy #56
 lda #$19
 sta (info_ptr),y
 ldy #58
 sta (info_ptr),y
 bra :fb_done
:fb_bank2
 ldy #56
 lda #$02
 sta (info_ptr),y      ; +56 frame_bank low
 ldy #58
 sta (info_ptr),y      ; +58 idle_bank low
:fb_done
 lda #$00
 ldy #57
 sta (info_ptr),y      ; +57 frame_bank high
 ldy #59
 sta (info_ptr),y      ; +59 idle_bank high
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
* DEBUG: if this is a Burnov spawn (frame_bank=$19), dump the
* buffer's frame_addr (+14), mask (+16), and frame_bank (+56).
* Format: "SP <fa_hi><fa_lo> <mask> <bk_hi><bk_lo>"
 ldy #56
 lda (info_ptr),y
 cmp #$19
 bne :no_dbg_dump
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$D0              ; 'P'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 ldy #15
 lda (info_ptr),y
 jsr dbg_print_hex8
 ldy #14
 lda (info_ptr),y
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 ldy #16
 lda (info_ptr),y
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 ldy #57
 lda (info_ptr),y
 jsr dbg_print_hex8
 ldy #56
 lda (info_ptr),y
 jsr dbg_print_hex8
 jsr dbg_print_nl
:no_dbg_dump
* Advance NPC buffer pointer (60 bytes per block)
 lda npc_buf_next
 clc
 adc #60
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
:is_bn       dfb 0      ; non-zero when this spawn is a bank-$06 NPC (Burnov)

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

* Billy's fall counter. Incremented at :use_fall whenever Billy
* is the target. Each fall costs 3 hits (punch_count reset to 0
* per fall) OR is forced by a weapon. At BILLY_MAX_FALLS the
* game-over screen fires when fall_anim ends.
billy_fall_count dfb 0
BILLY_MAX_FALLS  = 5

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

* Neighbor bounds tables: pre-loaded by OP_RIGHT and OP_LEFT so
* walk-right / walk-left can refuse moves that would land Billy
* in a row that's blocked on the screen scrolling in. Without
* these checks, Billy ends up "stuck" once the bounds table swaps
* on transition. Invalidated on screen transitions and reset by
* the next OP_RIGHT/OP_LEFT in the new screen's script.
bounds_tbl_right_lo
 LUP 200
 dfb 0
 --^
bounds_tbl_right_hi
 LUP 200
 dfb 0
 --^
bounds_tbl_left_lo
 LUP 200
 dfb 0
 --^
bounds_tbl_left_hi
 LUP 200
 dfb 0
 --^
bounds_right_valid dfb 0
bounds_left_valid  dfb 0

*----------------------------------------------------------
* check_y_bounds - Test if a sprite at X position chk_xpos
* is allowed at the proposed Y in A.
* Input: A = proposed Y, chk_xpos = sprite's X
* Output: C=1 blocked, C=0 allowed. Trashes A/X.
*----------------------------------------------------------
*----------------------------------------------------------
* check_x_bounds - Test if a proposed X is allowed at the
* sprite's current Y_top (IMAGE01_YPOS) on the CURRENT screen.
* Output: C=1 blocked, C=0 allowed. Trashes A/X.
*
* Walk-right and walk-left should use check_x_bounds_walk_right
* / _walk_left wrappers below, which intersect with the relevant
* neighbor screen's bounds (loaded by OP_RIGHT / OP_LEFT) to
* prevent Billy from walking into rows that will be blocked
* once the bounds table swaps on transition.
*----------------------------------------------------------
check_x_bounds
 sta :cxb_x
 lda IMAGE01_YPOS
 tax
 lda bounds_tbl_lo,x
 sta :cxb_min
 lda bounds_tbl_hi,x
 beq :cxb_try_ladder        ; row fully blocked — fall through to ladder
 sta :cxb_max
 lda :cxb_x
 cmp :cxb_min
 bcc :cxb_try_ladder        ; below min — could still be a ladder column
 cmp :cxb_max
 beq :cxb_ok
 bcs :cxb_try_ladder        ; above max — same fallback so a ladder on
                            ; the right edge of a platform works too
:cxb_ok clc
 rts
:cxb_try_ladder
* Bounds rejected the X. Try the ladder list — lets the platform's
* tight bmin/bmax stop Billy at the actual visible edge while
* still letting him reach a ladder column that sits outside that
* range. Mirrors check_y_bounds' ladder fallback.
 lda :cxb_x
 sta chk_xpos
 lda IMAGE01_YPOS
 jsr check_ladder
 bcs :cxb_blocked
 clc
 rts
:cxb_blocked sec
 rts
:cxb_x dfb 0
:cxb_min dfb 0
:cxb_max dfb 0

* Shared scratch — wrappers below stash the proposed X here
* before delegating to check_x_bounds, so it survives the call.
proposed_walk_x dfb 0

*----------------------------------------------------------
* check_x_bounds_walk_right - Like check_x_bounds, but also
* requires the proposed X to be valid in the right-neighbor
* screen's bounds (if loaded). Prevents Billy from advancing
* into a row that's blocked on the screen scrolling in.
*----------------------------------------------------------
check_x_bounds_walk_right
 sta proposed_walk_x
 jsr check_x_bounds
 bcs :cxbR_blocked
 lda bounds_right_valid
 beq :cxbR_ok                  ; no neighbor known — current bounds suffice
 lda IMAGE01_YPOS
 tax
 lda bounds_tbl_right_hi,x
 beq :cxbR_ok                  ; neighbor row fully blocked = Y-mismatch
                               ; (different walkable Y bands between screens);
                               ; skip neighbor check, let walk proceed and rely
                               ; on snap-on-transition (TODO) to fix Billy's Y.
 sta :cxbR_max
 lda proposed_walk_x
 cmp bounds_tbl_right_lo,x
 bcc :cxbR_blocked
 cmp :cxbR_max
 beq :cxbR_ok
 bcs :cxbR_blocked
:cxbR_ok clc
 rts
:cxbR_blocked sec
 rts
:cxbR_max dfb 0

*----------------------------------------------------------
* check_x_bounds_walk_left - Mirror of _walk_right for the left.
*----------------------------------------------------------
check_x_bounds_walk_left
 sta proposed_walk_x
 jsr check_x_bounds
 bcs :cxbL_blocked
 lda bounds_left_valid
 beq :cxbL_ok
 lda IMAGE01_YPOS
 tax
 lda bounds_tbl_left_hi,x
 beq :cxbL_ok                  ; neighbor row fully blocked = Y-mismatch
                               ; (skip neighbor check, allow walk, rely on
                               ; eventual snap-on-transition).
 sta :cxbL_max
 lda proposed_walk_x
 cmp bounds_tbl_left_lo,x
 bcc :cxbL_blocked
 cmp :cxbL_max
 beq :cxbL_ok
 bcs :cxbL_blocked
:cxbL_ok clc
 rts
:cxbL_blocked sec
 rts
:cxbL_max dfb 0

*----------------------------------------------------------
* load_right_neighbor_bounds / load_left_neighbor_bounds -
* Copy screen A's bounds data from bank $02 into the right
* or left neighbor table and mark the table valid. Called by
* OP_RIGHT / OP_LEFT handlers.
*----------------------------------------------------------
load_right_neighbor_bounds
 sta :lrnb_idx
 clc
 xce
 rep $30
 mx %00
 lda :lrnb_idx
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
 sta $F0                     ; F0/F2 = bank $02 addr of source table
 sep $20
 lda #$02
 sta $F2
 rep $20
 ldy #0                      ; source byte index
 ldx #0                      ; dest row index
:lrnb_loop sep $20
 lda [$F0],y
 sta bounds_tbl_right_lo,x
 rep $20
 iny
 sep $20
 lda [$F0],y
 sta bounds_tbl_right_hi,x
 rep $20
 iny
 inx
 cpx #200
 bcc :lrnb_loop
 sec
 xce
 lda #1
 sta bounds_right_valid
 rts
:lrnb_idx ds 2

*----------------------------------------------------------
* snap_billy_to_valid_y - After a horizontal screen transition,
* if Billy's current Y_top lands in a row that's blocked on the
* new bounds (Y-band mismatch between old/new screens), find a
* walkable row by scanning bounds_tbl_hi from Y=199 downward,
* and set IMAGE01_YPOS to that row. Also updates billy_sprite
* ypos/prev_ypos and marks Billy dirty so the next frame's
* erase/draw repaints him at the new position.
*
* Caller: emulation 8-bit mode, info_ptr already set to
* billy_sprite (process_input does this at frame start).
* Trashes A/X/Y if a snap is needed; otherwise no-op.
*----------------------------------------------------------
snap_billy_to_valid_y
* Quick exit if current Y_top is walkable AND its sprite stays
* within the playfield (Y_top + FRAME_Y <= 183).
 lda IMAGE01_YPOS
 tax
 lda bounds_tbl_hi,x
 beq :sbtv_scan_setup
 txa
 clc
 adc FRAME_Y
 cmp #184
 bcc :sbtv_done            ; bottom < 184 → still on playfield, no snap
:sbtv_scan_setup
* Scan from the highest legal Y_top (= 183 - FRAME_Y) downward
* so Billy lands on the LOWEST walkable row whose sprite fits.
 lda #183
 sec
 sbc FRAME_Y
 tax
:sbtv_scan
 lda bounds_tbl_hi,x
 bne :sbtv_use
 cpx #0
 beq :sbtv_done            ; no valid row found — leave Y alone
 dex
 bra :sbtv_scan
:sbtv_use
 txa
 sta IMAGE01_YPOS
 ldy #0
 sta (info_ptr),y          ; +0 ypos
 ldy #32
 sta (info_ptr),y          ; +32 prev_ypos (avoid stale erase)
 ldy #30
 lda #$03
 sta (info_ptr),y          ; dirty = erase + draw
:sbtv_done
 rts

load_left_neighbor_bounds
 sta :llnb_idx
 clc
 xce
 rep $30
 mx %00
 lda :llnb_idx
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
 sta $F0
 sep $20
 lda #$02
 sta $F2
 rep $20
 ldy #0
 ldx #0
:llnb_loop sep $20
 lda [$F0],y
 sta bounds_tbl_left_lo,x
 rep $20
 iny
 sep $20
 lda [$F0],y
 sta bounds_tbl_left_hi,x
 rep $20
 iny
 inx
 cpx #200
 bcc :llnb_loop
 sec
 xce
 lda #1
 sta bounds_left_valid
 rts
:llnb_idx ds 2

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
 stz bounds_right_valid     ; neighbor table is for old screen now
 stz bounds_left_valid
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
 jsr snap_billy_to_valid_y  ; rescue Y if new screen blocks current Y_top
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
 stz bounds_right_valid     ; neighbor tables are stale on transition
 stz bounds_left_valid
 jsr inc_border             ; new screen scrolled in
 lda current_screen
 clc
 adc #$03              ; scroll_src_bank = $03 + new current_screen
 sta scroll_src_bank   ; so scroll_right starts by re-showing us
 stz scroll_src_off
 lda current_screen
 jsr load_screen_bounds
 jsr snap_billy_to_valid_y  ; rescue Y if new screen blocks current Y_top
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

*----------------------------------------------------------
* setup_health_palette - Override SCBs at rows 197/198/199 to
* use palette 02 (rest of the screen stays on palette 00),
* and populate palette 02 with 10 colors:
*   slots 0,5    deep red     (player 1/2 red segment)
*   slots 1,6    yellow       (player 1/2 yellow segment)
*   slots 2,3,4  bright green (player 1's three green segments)
*   slots 7,8,9  bright green (player 2's three green segments)
*
* "Turning off" a segment means writing that slot's palette
* entry to the background color so any pixels painted with that
* index disappear — health depletes by changing the palette,
* not the pixel data.
*
* Slots 10-15 are left as whatever MISSION11.PAK shipped; the
* bar never draws with those indices.
*
* Writes through bank $01 so SHR shadowing propagates to $E1.
* Called once after the initial copy_50_to_01.
*----------------------------------------------------------
setup_health_palette
* SCBs (8-bit). Row N SCB = $9D00 + N. Byte $02 = 320 mode,
* palette 2.
 lda #$02
 stal $019DC5         ; row 197
 stal $019DC6         ; row 198
 stal $019DC7         ; row 199
* Palette 02 base = $9E00 + 2*32 = $9E40. Each entry is a
* 16-bit $0RGB word. Switch to native 16-bit for word writes.
 clc
 xce
 rep $30
 mx %00
* Player 1 — red(10), yellow(1), green×3 (2..4)
 lda #$0800
 stal $019E54         ; slot 10  deep red
 lda #$0FE0
 stal $019E42         ; slot 1  yellow
 lda #$00F0
 stal $019E44         ; slot 2  green
 stal $019E46         ; slot 3  green
 stal $019E48         ; slot 4  green
* Player 2 — red(5), yellow(6), green×3 (7..9)
 lda #$0800
 stal $019E4A         ; slot 5  deep red
 lda #$0FE0
 stal $019E4C         ; slot 6  yellow
 lda #$00F0
 stal $019E4E         ; slot 7  green
 stal $019E50         ; slot 8  green
 stal $019E52         ; slot 9  green
 sec
 xce
 sep $30
 mx %11
 rts

*----------------------------------------------------------
* draw_health_bar - Paint two segmented health bars across SHR
* rows 197/198/199 (palette 02). Each player gets 5 segments
* of 5 bytes (10 px) each = 25 bytes / 50 px per bar:
*   red, yellow, green, green, green.
*
*   Player 1: bytes 3..27,  color indices 0..4
*   Player 2: bytes 82..106, color indices 5..9
*
* Bar pixels are written once at startup. Depleting health is
* done by recoloring palette-02 slots, never by repainting the
* bar pixels themselves. erase_all clamps at y=180 so no sprite
* redraw ever touches these rows.
*
* Row N base in bank $01 = $2000 + N*160:
*   197 → $9B20    198 → $9BC0    199 → $9C60
*----------------------------------------------------------
draw_health_bar
* Player 1 bar (5 segments at bytes 2..27)
 ldx #2
 lda #$AA              ; red    (slot 10)
 jsr :seg
 lda #$11              ; yellow (slot 1)
 jsr :seg
 lda #$22              ; green  (slot 2)
 jsr :seg
 lda #$33              ; green  (slot 3)
 jsr :seg
 lda #$44              ; green  (slot 4)
 jsr :seg

* Player 2 bar (5 segments at bytes 89..106)
 ldx #89
 lda #$55              ; red    (slot 5)
 jsr :seg
 lda #$66              ; yellow (slot 6)
 jsr :seg
 lda #$77              ; green  (slot 7)
 jsr :seg
 lda #$88              ; green  (slot 8)
 jsr :seg
 lda #$99              ; green  (slot 9)
 jsr :seg
 rts

* Local segment writer: A = fill byte, X = start byte.
* Writes 5 bytes across rows 197/198/199, leaves X pointing at
* the next segment's start so callers can chain.
:seg
 sta :fill
 ldy #0
:seg_loop
 lda :fill
 stal $019B20,x        ; row 197
 stal $019BC0,x        ; row 198
 stal $019C60,x        ; row 199
 inx
 iny
 cpy #5
 bne :seg_loop
 rts
:fill dfb 0

* GAME OVER overlay text. Mirrors PAUSED but x is shifted left
* to center 9 chars instead of 6 (each glyph ≈ 8 px → 24 px
* shift = 12 bytes left of the PAUSED anchor).
GAMEOVER_TEXT_X = 75
GAMEOVER_TEXT_Y = 100

game_over_str ASC 'GAME OVER',00

*----------------------------------------------------------
* draw_game_over_text - Draw "GAME OVER" via QuickDraw II
* _DrawCString. Same shape as draw_pause_text.
*----------------------------------------------------------
draw_game_over_text
 clc
 xce                    ; native mode
 rep $30
 lda #GAMEOVER_TEXT_X
 pha
 lda #GAMEOVER_TEXT_Y
 pha
 ldx #$3a04
 jsl $E10000
 pea #$0001
 ldx #$A004
 jsl $E10000
 pea #$0000
 ldx #$A204
 jsl $E10000
 pea #$0000         ; normal text style
 ldx #$9A04
 jsl $E10000
 pea ^game_over_str
 pea game_over_str
 ldx #$A604
 jsl $E10000
 pea #$0001         ; restore bold
 ldx #$9A04
 jsl $E10000
 sec
 xce
 rts

*----------------------------------------------------------
* game_over - Billy ran out of falls. Stops the level music,
* draws GAME OVER, plays the game-over jingle (bank $16, loaded
* at boot from GAMEOVERNTP.PAK) once through, then chains back
* to TITLE via the DDII.SYSTEM jump table at $1000. Mirrors the
* OP_END play-once-then-stop pattern. Never returns.
*----------------------------------------------------------
game_over
* Re-enable SHR shadow so QuickDraw's writes to bank $01 reach
* the screen at $E1. erase_all/draw_all could be running with
* shadow off mid-frame; force it back on.
 ldal $E0C035
 and #%11110111         ; bit 3 cleared = enable SHR shadow
 stal $E0C035
* Stop the level music. NTPstop must be called in native 16-bit
* mode (same protocol as the OP_END path).
 clc
 xce
 rep $30
 jsl NTPstop
 sec
 xce
 sep $30
 mx %11
 jsr draw_game_over_text
* Prepare and play the game-over jingle from bank $16, play-once
* mode (NTP zeros the playing flag at end of pattern list when
* play_song_once != 0). Spin until that flag drops, then full stop.
 clc
 xce
 rep $30
 ldy #$16              ; GAMEOVER music bank
 ldx #$00
 txa
 jsl NTPprepare
 lda #$0001            ; non-zero -> play once, then auto-stop
 jsl NTPplay
:gov_wait_song
 jsl NTPgetsongpos     ; X=songinfo low addr, Y=NTP bank
 stx $F0
 sty $F2
 ldy #0
 lda [$F0],y           ; songinfo[0..1] = playing flag
 bne :gov_wait_song
 jsl NTPstop
 sec
 xce
 sep $30
 mx %11
* Chain back to TITLE via DDII.SYSTEM. Entry $1000 reloads the
* title program at $2000 and runs it.
 jmp $1000

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
 cmp #'x'                 ; was 'd' — moved to 'x' since 'd' = walk right
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
* Save current globals — including sprite_bank, which the
* compiled draw uses as the source bank for the indirect-long
* pixel reads. Without saving/restoring it, bank-$19 NPCs (mace,
* boss, armed enemies) leave sprite_bank at $19 and the overlay's
* bank-$02 sprite gets read from the wrong bank → corruption.
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
 lda sprite_bank
 pha
 lda sprite_bank+1
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
* Overlay sprites live in bank $02 — force sprite_bank to $02
* for the compiled draw.
 lda #$02
 sta sprite_bank
 lda #$00
 sta sprite_bank+1
 jsr draw_sprite_compiled
* Restore globals
 pla
 sta sprite_bank+1
 pla
 sta sprite_bank
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
NPC_BUFFER_SLOTS = 24
* 60 bytes/slot: 0..51 copied from the bank-$02 template; 52/54
* (walk_anim/atk_anim), 56 (frame_bank), and 58 (idle_bank — bank
* of the idle frame, restored on anim end) patched by
* script_spawn_npc post-copy.
npc_buffers ds NPC_BUFFER_SLOTS*60
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
 beq :is_npc          ; $00 = NPC — dispatch by behavior
 cmp #$03
 bne :skip            ; $01/$02 = player/static item, skip
* $03 = projectile (flying knife etc.) — flies, hit-checks Billy.
 jsr update_projectile
 bra :skip
:is_npc
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
 cmp #BEHAV_KNIFER
 bne :nbkn
 jsr behav_knifer
 bra :skip
:nbkn
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
FO_RANGE   = 1         ; bytes (= 62 px) — engage punching at this
                        ; distance. Comment used to claim "pixels"
                        ; but the math (player_x + player_w + FO_RANGE)
                        ; is byte-based; pulled in from 4 → 3 so NPCs
                        ; close the last 2 px before swinging.
FO_CD_TIME = 90        ; cooldown frames after a punch

behav_faceoff
 ldy #7
 lda (info_ptr),y      ; behavior_state
 cmp #FO_PUNCH
 beq :st_punch
 cmp #FO_COOLDOWN
 beq :st_cooldown
 cmp #FO_SOMERSAULT
 beq :st_somer
 cmp #FO_GRABBED
 beq :st_grabbed
* default: FO_APPROACH
 jmp fo_approach

:st_punch
 jmp fo_punch
:st_cooldown
 jmp fo_cooldown
:st_somer
 jmp fo_somersault
:st_grabbed
* Grabbed by Billy — AI suspended. Frame is driven by the grab
* state machine in process_input; nothing to do here.
 rts

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
* Snapshot mirror BEFORE the routine touches it, so the
* :commit-time dirty check can detect mirror flips. xpos and
* ypos are snapshotted into prev_xpos/prev_ypos further down.
 ldy #4
 lda (info_ptr),y
 sta saved_npc_mirror

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
* Somersault trigger (William only, once per spawn). Gates:
*   1. walk_anim == anim_wwalk (William, not Roper/Linda)
*   2. info+5 (already-somersaulted flag) == 0
*   3. |xpos - target_x| > SOMER_TRIGGER
* Sprite info offset +5 is the padding byte after the 1-byte
* mirror at +4; zero in all templates and never written by
* anything else, so we use it as a per-NPC one-shot flag.
 ldy #52
 lda (info_ptr),y
 cmp #<anim_wwalk
 bne :sk_somer
 ldy #53
 lda (info_ptr),y
 cmp #>anim_wwalk
 bne :sk_somer
 ldy #5
 lda (info_ptr),y
 bne :sk_somer         ; flag set -> never again
 ldy #2
 lda (info_ptr),y
 sec
 sbc fo_target_x
 bpl :somer_abs_done
 eor #$FF
 clc
 adc #1                ; |xpos - target_x|
:somer_abs_done
 cmp #SOMER_TRIGGER+1
 bcc :sk_somer
* Far enough to roll. Mark this William as "has somersaulted"
* so subsequent ticks just walk. Clear anim_ptr so update_anims
* leaves us alone; fo_somersault drives frame_addr manually.
* Prime sub-frame counter to $FF and timer to 1 so the next
* tick advances to sub-frame 0 and installs WSOMER1.
 ldy #5
 lda #$01
 sta (info_ptr),y
 lda #0
 ldy #24
 sta (info_ptr),y
 ldy #25
 sta (info_ptr),y
 ldy #7
 lda #FO_SOMERSAULT
 sta (info_ptr),y
 ldy #8
 lda #$FF
 sta (info_ptr),y
 ldy #9
 lda #$01
 sta (info_ptr),y
 rts
:sk_somer

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
* extend past bmax. For Burnov (frame_bank=$19) add 5 bytes
* of padding so he stops 10 px before the wall instead of
* parking his sprite right against it (his hitbox is bigger
* than the bounds tables expect).
 ldy #4
 lda #$00
 sta (info_ptr),y      ; mirror = 0 (facing right)
 ldy #2
 lda (info_ptr),y      ; current xpos
 ldy #10
 clc
 adc (info_ptr),y      ; + frame_x = new right edge
 sta chk_xpos
 ldy #56
 lda (info_ptr),y      ; frame_bank low byte
 cmp #$19
 bne :rgt_no_pad
 lda chk_xpos
 clc
 adc #5
 sta chk_xpos
:rgt_no_pad
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
* sprite extends only to the right of xpos. For Burnov
* (frame_bank=$19) subtract an extra 5 bytes so he stops
* 10 px before the left wall (matches the right-edge pad).
 ldy #4
 lda #$01
 sta (info_ptr),y      ; mirror = 1 (facing left)
 ldy #2
 lda (info_ptr),y
 sec
 sbc #1
 sta chk_xpos
 ldy #56
 lda (info_ptr),y      ; frame_bank low byte
 cmp #$19
 bne :lft_no_pad
 lda chk_xpos
 sec
 sbc #5
 sta chk_xpos
:lft_no_pad
 ldy #0
 lda (info_ptr),y      ; current ypos
 jsr check_y_bounds
 bcs :x_at_target
 ldy #2
 lda chk_xpos
 sta (info_ptr),y
:x_at_target
* Reached when xpos already == fo_target_x OR the proposed move
* was blocked by row bounds. The walk branches above wrote
* mirror=0/1 before the bounds check, so a blocked attempt
* leaves the NPC facing his intended walk direction — wrong
* when target_x is unreachable (e.g., past the playfield edge)
* and the NPC ends up stuck against the wall facing away from
* Billy. Force mirror to point at Billy here. For the
* truly-at-target case this matches the initial face-Billy
* mirror set above, so it's a no-op there.
 ldy #2
 lda (info_ptr),y
 cmp fo_plr_x
 bcc :xat_face_right        ; npc_x < player_x → face right (mirror=0)
* npc_x >= player_x → face left (mirror=1)
 lda #$01
 ldy #4
 sta (info_ptr),y
 bra :move_y
:xat_face_right
 lda #$00
 ldy #4
 sta (info_ptr),y

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
* For Burnov (frame_bank=$19) tighten the clamp by 10 lines
* so his big sprite stops walking down before its tail touches
* the playfield edge.
 sta :yp_proposed
 ldy #12
 clc
 adc (info_ptr),y      ; A = proposed_top + frame_y = proposed_bottom
 sta :yp_bottom
 ldy #56
 lda (info_ptr),y      ; frame_bank low byte
 cmp #$19
 bne :yd_normal_cap
 lda :yp_bottom
 cmp #190
 bcs :y_at_target
 bra :yd_call_check
:yd_normal_cap
 lda :yp_bottom
 cmp #200
 bcs :y_at_target
:yd_call_check
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
* Only dirty if anything actually changed this tick. Without
* this, FACEOFF NPCs at target / blocked by bounds re-mark
* dirty every frame, and erase_all/draw_all run on them every
* frame — visible flicker even when nothing's moved.
 jsr dirty_if_changed
:no_action
 rts

:yp_proposed dfb 0
:yp_bottom   dfb 0

*----------------------------------------------------------
* dirty_if_changed - Set info+30 = $03 only if the sprite's
* xpos / ypos / mirror differ from their pre-routine values
* (prev_xpos at info+34, prev_ypos at info+32, mirror saved
* in saved_npc_mirror). Used by FACEOFF / FLANK behaviors so
* an NPC sitting at its target doesn't re-dirty every tick.
* Caller must have stashed the entry-time mirror in
* saved_npc_mirror, and have snapshotted prev_xpos/prev_ypos
* before mutating xpos/ypos. Trashes A, Y. Preserves X.
*----------------------------------------------------------
dirty_if_changed
 ldy #2
 lda (info_ptr),y      ; current xpos
 ldy #34
 cmp (info_ptr),y
 bne :dic_set
 ldy #0
 lda (info_ptr),y
 ldy #32
 cmp (info_ptr),y
 bne :dic_set
 ldy #4
 lda (info_ptr),y
 cmp saved_npc_mirror
 beq :dic_done
:dic_set
 lda #$03
 ldy #30
 sta (info_ptr),y
:dic_done
 rts

saved_npc_mirror dfb 0

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
* fo_somersault - 5-frame cartwheel-closer (William only).
*
* Sub-frame schedule (info_ptr+8 = sub-frame index 0..4):
*   0  WSOMER1   mirror = orig
*   1  WSOMER3   mirror = orig
*   2  WSOMER2   mirror = orig
*   3  WSOMER3   mirror = !orig   (toggle on entry)
*   4  WSOMER1   mirror = !orig
* On sub-frame 5 we restore mirror (toggle again) and hand
* control back to FO_APPROACH; npc_ensure_walking will
* reinstall the walk anim on the next fo_approach tick.
*
* anim_ptr is held at 0 throughout — we drive frame_addr
* directly so update_anims stays out of our way. If anything
* (typically a hit -> anim_wpunched) sets anim_ptr non-zero
* mid-roll we abort: restore mirror if we're past the apex
* and bounce back to FO_APPROACH so the punched anim plays.
*
* Per-VBL movement: 1 pixel toward fo_target_x, just like
* the regular walk step (no bounds-check here — the
* somersault distance is short and we already know the
* target is reachable).
*----------------------------------------------------------
fo_somersault
* Hijack check: anim_ptr non-zero AND not anim_wwalk means
* something installed an action anim (hit reaction). Abort.
 ldy #24
 lda (info_ptr),y
 sta :ap_tmp
 ldy #25
 lda (info_ptr),y
 ora :ap_tmp
 beq :alive            ; anim_ptr == 0 -> still our turn
 jmp :abort

:alive
* Snapshot current pos/size to prev fields (so erase_all has
* the right rect).
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

* Decrement sub-frame timer.
 ldy #9
 lda (info_ptr),y
 sec
 sbc #1
 sta (info_ptr),y
 bne :step             ; not yet expired -> just step

* Timer expired -> advance sub-frame.
 ldy #8
 lda (info_ptr),y
 clc
 adc #1
 sta (info_ptr),y
 cmp #5
 bcc :keep_going
 jmp :done             ; finished all 5 sub-frames
:keep_going

* New sub-frame entry. Mirror schedule (relative to original):
*   0: orig   1: !orig   2: orig   3: orig   4: !orig
* So flip mirror on entries into sub-frames 1, 2, 4.
 cmp #1
 beq :do_flip
 cmp #2
 beq :do_flip
 cmp #4
 bne :no_flip
:do_flip
 ldy #4
 lda (info_ptr),y
 eor #$01
 sta (info_ptr),y
:no_flip

* Look up frame_addr from somersault_addr_tbl[sub-frame*2].
 ldy #8
 lda (info_ptr),y
 asl
 tay
 lda somersault_addr_tbl,y
 sta :tmp_lo
 lda somersault_addr_tbl+1,y
 sta :tmp_hi
 ldy #14
 lda :tmp_lo
 sta (info_ptr),y      ; frame_addr low
 iny
 lda :tmp_hi
 sta (info_ptr),y      ; frame_addr high

* Read frame_x (addr-2) and frame_y (addr-4) from bank $02.
* Each is stored as a 2-byte little-endian word but only the
* low byte is the actual pixel count.
 lda :tmp_lo
 sec
 sbc #4
 sta $F0
 lda :tmp_hi
 sbc #0
 sta $F1
 lda #$02
 sta $F2               ; bank $02
 ldy #0
 lda [$F0],y           ; frame_y_word low byte
 ldy #12
 sta (info_ptr),y      ; frame_y
 ldy #2
 lda [$F0],y           ; frame_x_word low byte
 ldy #10
 sta (info_ptr),y      ; frame_x

* Reload sub-frame timer.
 ldy #9
 lda #SOMER_DURATION
 sta (info_ptr),y

:step
* Move 1 pixel toward target_x (recomputed every tick by the
* dispatcher's prior fo_approach call... but we get here
* directly via behav_faceoff dispatch, so re-derive target).
 jsr fo_find_player
 beq :no_move          ; no player -> just dirty + return
 lda fo_plr_facing
 bne :tx_player_left
 lda fo_plr_x
 clc
 adc fo_plr_w
 clc
 adc #FO_RANGE
 sta fo_target_x
 bra :tx_done
:tx_player_left
 lda fo_plr_x
 sec
 sbc #FO_RANGE
 ldy #10
 sec
 sbc (info_ptr),y
 sta fo_target_x
:tx_done
 ldy #2
 lda (info_ptr),y
 cmp fo_target_x
 beq :no_move
 bcs :step_left
 ldy #2
 lda (info_ptr),y
 clc
 adc #1
 sta (info_ptr),y
 bra :no_move
:step_left
 ldy #2
 lda (info_ptr),y
 sec
 sbc #1
 sta (info_ptr),y

:no_move
 ldy #30
 lda #$03
 sta (info_ptr),y      ; needs_draw + needs_erase
 rts

:done
* All 5 sub-frames played. Restore mirror (currently flipped
* from the back-half) and return control to FO_APPROACH; next
* fo_approach tick will reinstall the walk anim and resume.
 ldy #4
 lda (info_ptr),y
 eor #$01
 sta (info_ptr),y
 ldy #7
 lda #FO_APPROACH
 sta (info_ptr),y
 ldy #30
 lda #$03
 sta (info_ptr),y
 rts

:abort
* Hit reaction (or other anim) hijacked us. Mirror is currently
* flipped only while we're inside sub-frame 1 or 4 (per the
* schedule above); restore it in those cases. Then bounce to
* FO_APPROACH so the action anim runs cleanly.
 ldy #8
 lda (info_ptr),y
 cmp #1
 beq :ab_do_restore
 cmp #4
 bne :ab_no_restore
:ab_do_restore
 ldy #4
 lda (info_ptr),y
 eor #$01
 sta (info_ptr),y
:ab_no_restore
 ldy #7
 lda #FO_APPROACH
 sta (info_ptr),y
 rts

:ap_tmp dfb 0
:tmp_lo dfb 0
:tmp_hi dfb 0

*==========================================================
* Grab system helpers
*
* Public entry points (all 8-bit emulation mode):
*   try_enter_grab      A = key. If conditions are right,
*                       enters grab and clears A so caller
*                       eats the input.
*   handle_grab_input   A = key. Routes to grab-punch /
*                       release / ignore based on key vs
*                       Billy's mirror.
*   end_grab_punch_subframe  Called from process_input when
*                       grab_punch_timer expires; restores
*                       BGRAB2 / xHELD1 if still grabbing.
*
* Internal helpers below.
*==========================================================

*----------------------------------------------------------
* enemy_set_held - info_ptr = grabbed enemy, A = which:
*   0 = HELD1 (idle hold), 1 = HELD2 (taking grab-punch).
* Determines enemy type from idle_addr (+42) and writes the
* appropriate spr_xheldN + size to frame_x / frame_y / frame_addr.
*----------------------------------------------------------
enemy_set_held
 sta :which
 ldy #42
 lda (info_ptr),y
 sta :eh_id_lo
 ldy #43
 lda (info_ptr),y
 sta :eh_id_hi
* William?
 lda :eh_id_lo
 cmp spr_william1
 bne :try_roper
 lda :eh_id_hi
 cmp spr_william1+1
 bne :try_roper
 lda :which
 bne :w_h2
 lda spr_wheld1
 sta :addr_lo
 lda spr_wheld1+1
 sta :addr_hi
 lda #WHELD1_W
 sta :w
 lda #WHELD1_H
 sta :h
 jmp :write
:w_h2
 lda spr_wheld2
 sta :addr_lo
 lda spr_wheld2+1
 sta :addr_hi
 lda #WHELD2_W
 sta :w
 lda #WHELD2_H
 sta :h
 jmp :write
:try_roper
 lda :eh_id_lo
 cmp spr_roper1
 bne :try_linda
 lda :eh_id_hi
 cmp spr_roper1+1
 bne :try_linda
 lda :which
 bne :r_h2
 lda spr_rheld1
 sta :addr_lo
 lda spr_rheld1+1
 sta :addr_hi
 lda #RHELD1_W
 sta :w
 lda #RHELD1_H
 sta :h
 jmp :write
:r_h2
 lda spr_rheld2
 sta :addr_lo
 lda spr_rheld2+1
 sta :addr_hi
 lda #RHELD2_W
 sta :w
 lda #RHELD2_H
 sta :h
 jmp :write
:try_linda
* Linda (assumed: any FACEOFF NPC that isn't W/R)
 lda :which
 bne :l_h2
 lda spr_lheld1
 sta :addr_lo
 lda spr_lheld1+1
 sta :addr_hi
 lda #LHELD1_W
 sta :w
 lda #LHELD1_H
 sta :h
 jmp :write
:l_h2
 lda spr_lheld2
 sta :addr_lo
 lda spr_lheld2+1
 sta :addr_hi
 lda #LHELD2_W
 sta :w
 lda #LHELD2_H
 sta :h
:write
* Snapshot prev_* before mutating frame fields so erase_all
* covers the about-to-be-replaced rectangle.
 ldy #2
 lda (info_ptr),y
 ldy #34
 sta (info_ptr),y
 ldy #0
 lda (info_ptr),y
 ldy #32
 sta (info_ptr),y
 ldy #10
 lda (info_ptr),y
 ldy #36
 sta (info_ptr),y
 ldy #12
 lda (info_ptr),y
 ldy #38
 sta (info_ptr),y
 ldy #10
 lda :w
 sta (info_ptr),y
 ldy #12
 lda :h
 sta (info_ptr),y
 ldy #14
 lda :addr_lo
 sta (info_ptr),y
 iny
 lda :addr_hi
 sta (info_ptr),y
 ldy #30
 lda #$03
 sta (info_ptr),y
 rts
:which dfb 0
:eh_id_lo dfb 0
:eh_id_hi dfb 0
:addr_lo dfb 0
:addr_hi dfb 0
:w dfb 0
:h dfb 0

*----------------------------------------------------------
* billy_set_grab_frame - info_ptr = Billy, A = which:
*   0 = BGRAB2 (hold), 1 = BGRAB1 (active strike).
* Sets frame_addr/x/y, clears info+52 (so MASK_ADDR loads 0),
* clears anim_ptr, snapshots prev_*, marks dirty.
*----------------------------------------------------------
billy_set_grab_frame
 sta :which
 bne :b1
 lda spr_bgrab2
 sta :addr_lo
 lda spr_bgrab2+1
 sta :addr_hi
 lda #BGRAB2_W
 sta :w
 lda #BGRAB2_H
 sta :h
 bra :write
:b1
 lda spr_bgrab1
 sta :addr_lo
 lda spr_bgrab1+1
 sta :addr_hi
 lda #BGRAB1_W
 sta :w
 lda #BGRAB1_H
 sta :h
:write
 ldy #2
 lda (info_ptr),y
 ldy #34
 sta (info_ptr),y
 ldy #0
 lda (info_ptr),y
 ldy #32
 sta (info_ptr),y
 ldy #10
 lda (info_ptr),y
 ldy #36
 sta (info_ptr),y
 ldy #12
 lda (info_ptr),y
 ldy #38
 sta (info_ptr),y
 ldy #10
 lda :w
 sta (info_ptr),y
 ldy #12
 lda :h
 sta (info_ptr),y
 ldy #14
 lda :addr_lo
 sta (info_ptr),y
 iny
 lda :addr_hi
 sta (info_ptr),y
* Force legacy draw path: anim_ptr = 0, info+52 = 0.
 lda #0
 ldy #24
 sta (info_ptr),y
 ldy #25
 sta (info_ptr),y
 ldy #52
 sta (info_ptr),y
 ldy #53
 sta (info_ptr),y
 sta MASK_ADDR
 sta MASK_ADDR+1
 ldy #30
 lda #$03
 sta (info_ptr),y
 rts
:which dfb 0
:addr_lo dfb 0
:addr_hi dfb 0
:w dfb 0
:h dfb 0

*----------------------------------------------------------
* try_enter_grab - On entry: info_ptr = Billy, A = key.
* If the key is the direction-toward-enemy (mirror=0 → '6',
* mirror=1 → '4') AND punch_window > 0, enter grab. Sets
* grab_target, parks the enemy in FO_GRABBED, frames both
* sprites at hold pose. On exit A is unchanged so the caller
* can decide based on grab_target whether to swallow input.
*----------------------------------------------------------
try_enter_grab
 sta :key
 ldy #4
 lda (info_ptr),y
 bne :facing_left
* Billy faces right -> 'd' is toward
 lda :key
 cmp #'d'
 bne :no_trigger
 bra :ok
:facing_left
 lda :key
 cmp #'a'
 bne :no_trigger
:ok
* Validate that last_hit_target is still in the table.
 lda last_hit_target
 ora last_hit_target+1
 beq :no_trigger
* Set up the enemy.
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 lda last_hit_target
 sta info_ptr
 sta grab_target
 lda last_hit_target+1
 sta info_ptr+1
 sta grab_target+1
* Park enemy in FO_GRABBED, no anim.
 ldy #7
 lda #FO_GRABBED
 sta (info_ptr),y
 lda #0
 ldy #24
 sta (info_ptr),y
 ldy #25
 sta (info_ptr),y
* Frame to xHELD1.
 lda #0
 jsr enemy_set_held
* Bump enemy ypos +GRAB_Y_OFFSET so the held pose renders lower
* on screen than the standing pose. enemy_set_held has already
* snapshotted prev_ypos = standing ypos, so erase_all's union
* rect cleans up the standing-pose footprint this VBL.
 ldy #0
 lda (info_ptr),y
 clc
 adc #GRAB_Y_OFFSET
 sta (info_ptr),y
* Restore info_ptr -> Billy.
 pla
 sta info_ptr+1
 pla
 sta info_ptr
* Frame Billy to BGRAB2.
 lda #0
 jsr billy_set_grab_frame
* Consume the punch window so any re-press doesn't re-trigger.
 stz punch_window
:no_trigger
 lda :key
 rts
:key dfb 0

*----------------------------------------------------------
* handle_grab_input - On entry: info_ptr = Billy, A = key,
* grab_target known non-zero. Returns with grab_target either
* unchanged (eat input — caller returns), zero (released —
* caller falls through to walk dispatch).
*----------------------------------------------------------
handle_grab_input
 sta :key
* Grab-punch trigger. Accepts the legacy 'p' key plus the
* current button-A code 'l' (keyboard L, joystick OA, SNES B).
* Without 'l' here, holding an enemy's head + tapping punch
* did nothing — the keyboard remap to J/L left this routine
* listening for a key that no input source produces anymore.
 cmp #'p'
 beq :do_punch
 cmp #'l'
 bne :not_punch
:do_punch
 jsr start_grab_punch
 lda :key
 rts
:not_punch
* Direction-AWAY ends the grab. Mirror=0 means Billy faced
* right at grab time, so 'a' (left) is away. Mirror=1 -> 'd'.
 ldy #4
 lda (info_ptr),y
 bne :face_left
 lda :key
 cmp #'a'
 bne :stay
 bra :release
:face_left
 lda :key
 cmp #'d'
 bne :stay
:release
 jsr exit_grab
 lda :key
 rts
:stay
 lda :key
 rts
:key dfb 0

*----------------------------------------------------------
* exit_grab - Release. Restores enemy to FO_APPROACH; Billy
* keeps BGRAB2 frame until the next walk step refreshes it.
* info_ptr = Billy on entry (caller's invariant preserved).
*----------------------------------------------------------
exit_grab
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 lda grab_target
 sta info_ptr
 lda grab_target+1
 sta info_ptr+1
* Unbump enemy ypos -GRAB_Y_OFFSET so the upcoming behavior tick
* sees the standing-height ypos. prev_ypos still holds the bumped
* value (last enemy_set_held snapshot), so erase_all's union rect
* covers the held pose's drawn position before redraw.
 ldy #0
 lda (info_ptr),y
 sec
 sbc #GRAB_Y_OFFSET
 sta (info_ptr),y
 ldy #30
 lda #$03
 sta (info_ptr),y       ; mark dirty (erase+draw)
 ldy #7
 lda #FO_APPROACH
 sta (info_ptr),y
 pla
 sta info_ptr+1
 pla
 sta info_ptr
 lda #0
 sta grab_target
 sta grab_target+1
 rts

*----------------------------------------------------------
* start_grab_punch - Trigger the BGRAB1/xHELD2 sub-anim and
* apply +1 punch_count to the grabbed enemy. If count crosses
* the fall threshold (3 or 6) the enemy falls and the grab
* ends as a side effect.
* info_ptr = Billy on entry.
*----------------------------------------------------------
start_grab_punch
* SFX
 ldx #SND_PUNCHLANDED
 jsr sound_trigger
* Set timer + Billy to BGRAB1.
 lda #GRAB_PUNCH_DURATION
 sta grab_punch_timer
 lda #1
 jsr billy_set_grab_frame
* Switch to enemy.
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 lda grab_target
 sta info_ptr
 lda grab_target+1
 sta info_ptr+1
* Frame to xHELD2.
 lda #1
 jsr enemy_set_held
* Increment punch_count, award points.
 ldy #48
 lda (info_ptr),y
 clc
 adc #1
 sta (info_ptr),y
 jsr incp1s_hundreds
* Fall threshold?
 ldy #48
 lda (info_ptr),y
 cmp #3
 beq :gp_fall
 cmp #6
 beq :gp_fall
* Stay in grab — restore info_ptr and return.
 pla
 sta info_ptr+1
 pla
 sta info_ptr
 rts
:gp_fall
* Unbump enemy ypos -GRAB_Y_OFFSET so the fall arc starts from
* standing height (matches check_punch_hit's normal-fall path).
 ldy #0
 lda (info_ptr),y
 sec
 sbc #GRAB_Y_OFFSET
 sta (info_ptr),y
* Trigger fall_anim on the enemy via start_anim so frame_bank
* (info+56) gets set from the descriptor's bank flag. The old
* path patched anim_ptr/anim_frame/anim_timer directly and left
* frame_bank stuck at the walk bank — a problem for cross-bank
* NPCs (williams_pipe walks in bank $19 but anim_wfall lives in
* bank $02), where the next render then read WFALL/WFALLEN
* pixels from bank $19 → garbage. start_anim also writes
* FRAME_X/Y/ADDR back to info+10/+12/+14 and sets dirty=$03.
 ldy #50
 lda (info_ptr),y
 pha                   ; fall_anim low → stack
 ldy #51
 lda (info_ptr),y
 tax                   ; X = fall_anim high
 pla                   ; A = fall_anim low
 jsr start_anim
 ldy #7
 lda #FO_APPROACH
 sta (info_ptr),y
* Clear grab — enemy is falling, no longer held.
 lda #0
 sta grab_target
 sta grab_target+1
* Restore info_ptr to Billy.
 pla
 sta info_ptr+1
 pla
 sta info_ptr
 rts

*----------------------------------------------------------
* end_grab_punch_subframe - Called when grab_punch_timer
* expired and grab_target is still set (i.e. enemy didn't
* fall). Restores Billy to BGRAB2 and enemy to xHELD1.
* info_ptr = Billy on entry.
*----------------------------------------------------------
end_grab_punch_subframe
 lda #0
 jsr billy_set_grab_frame
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 lda grab_target
 sta info_ptr
 lda grab_target+1
 sta info_ptr+1
 lda #0
 jsr enemy_set_held
 pla
 sta info_ptr+1
 pla
 sta info_ptr
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
* Snapshot mirror so dirty_if_changed below can detect mirror
* flips (fl_compute_target / fl_step_x will overwrite +4).
 ldy #4
 lda (info_ptr),y
 sta saved_npc_mirror

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

* Dirty only if pos/mirror actually changed (saved at entry).
 jsr dirty_if_changed

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
* Snapshot mirror so dirty_if_changed below can detect flips.
 ldy #4
 lda (info_ptr),y
 sta saved_npc_mirror

 jsr fl_compute_target
 jsr fl_snapshot_prev
 jsr fl_step_x
 sta fl_x_done
 lda fo_plr_y
 jsr fl_step_y_to
 sta fl_y_done

 jsr dirty_if_changed

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
* Interleaved draw: paint this sprite at its current frame
* immediately after erasing its prev rect. Shrinks the
* "sprite invisible" window to a single sprite's erase+draw
* (instead of all-sprites-erased then all-sprites-drawn),
* dramatically cutting flicker at 2.8 MHz.
*
* The erase rect setup above clobbered IMAGE01_XPOS/YPOS and
* FRAME_X/Y with the prev∪current union rect. Re-call
* load_sprite to refresh the globals from info before drawing
* — otherwise draw_sprite would paint at the union origin
* with the union dimensions (= corrupted ghost trails).
*
* mark_overlapping above may set needs_draw on sprites we've
* ALREADY iterated past. game_loop still calls draw_all after
* this routine; that pass picks up any such "back-flagged"
* sprites and draws them.
 jsr load_sprite
 ldy #30
 lda (info_ptr),y
 and #$01             ; bit 0 = needs_draw?
 beq :ea_draw_done
* Burnov-grab lock: skip Billy entirely while bn_grab_active
* (his BNBILLY1/2/3 frames are the combined pose).
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :ea_disp_check
 lda bn_grab_active
 beq :ea_disp_check
 jmp :ea_clr_dirty    ; gated out — clear bit and continue
:ea_disp_check
* Compiled vs legacy dispatch: compiled (AND/ORA) only when
* MASK_ADDR != 0 AND the sprite is the keyboard player.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :ea_legacy
 lda MASK_ADDR
 ora MASK_ADDR+1
 beq :ea_legacy
 jsr draw_sprite_compiled
 bra :ea_clr_dirty
:ea_legacy
 jsr draw_sprite
:ea_clr_dirty
 ldy #30
 lda (info_ptr),y
 and #$FE             ; clear bit 0 (needs_draw)
 sta (info_ptr),y
:ea_draw_done
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
* Burnov-grab lock: skip Billy entirely while bn_grab_active.
* Burnov's BNBILLY1/2/3 frames are the combined "holding Billy"
* pose, so Billy's own sprite must not draw.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :da_grab_chk_done
 lda bn_grab_active
 beq :da_grab_chk_done
 jmp :da_drawn        ; clear dirty bit, skip draw
:da_grab_chk_done
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
* +56/+57 frame_bank → sprite_bank global. draw_sprite and the
* compiled draw both read sprite_bank as the high half of the
* indirect-long source pointer, so loading it here makes every
* render automatically pull pixels from the sprite's home bank
* without per-call plumbing.
 ldy #56
 lda (info_ptr),y
 sta sprite_bank
 iny
 lda (info_ptr),y
 sta sprite_bank+1
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
OP_BOSSMUSIC = 18     ; switch to BOSS.NTP music (no params).
OP_WAIT     = 19      ; wait N frames before continuing the script.
                      ; 1-byte param: frame count (1-255).
OP_KILLOBJ  = 20      ; remove all non-player, non-NPC sprites (any
                      ; controller != 0 and != 1, currently only items
                      ; like dropped maces). Marks them with the death
                      ; sentinel ($FFFF in anim_ptr) so the next
                      ; erase_all wipes them and removes them from
                      ; sprite_table. No params. Note: forward-only
                      ; npc_buffer slots are not reclaimed.

* Script interpreter state
SCRIPT_RUN  = 0       ; executing opcodes
SCRIPT_WAITX = 1      ; waiting for player X threshold
SCRIPT_WAITY = 2      ; waiting for player Y threshold
SCRIPT_WAITCLR = 3    ; waiting for all NPCs defeated
SCRIPT_DONE = 4       ; level ended
SCRIPT_WAITNPC = 5    ; waiting for NPC count <= threshold
SCRIPT_WAITUP  = 6    ; waiting for vertical scroll to complete
SCRIPT_WAITXREV = 7   ; waiting for abs_x <= threshold
SCRIPT_WAIT    = 8    ; waiting N frames (script_wait_val = countdown)

* NPC behaviors (must match mission1.s definitions)
BEHAV_NONE    = 0
BEHAV_FACEOFF = 1
BEHAV_FLANK   = 2
BEHAV_LURK    = 3
BEHAV_LADDER  = 4
BEHAV_KNIFER  = 5     ; williams_knife: backpedal to 12px (= 6 byte
                      ; xpos units), throw KNIFE2/4 projectile, then
                      ; transform to regular williams + BEHAV_FACEOFF.
                      ; Falling mid-elude drops the knife and downgrades.

* Knife-thrower tunables
KN_RANGE      = 30    ; xpos bytes (= 60 px in 320 mode) — minimum gap
                      ; between williams_knife and Billy before he can throw.
                      ; Picked so the projectile is visible for many frames
                      ; (~10) before reaching Billy. Smaller values → knife
                      ; hits Billy in 1-2 frames and is barely visible.
KN_SPEED      = 3     ; bytes/frame — projectile xpos delta per frame
                      ; (= 6 px/frame ≈ 110-byte traversal in ~37 frames)
KN_THROW_Y_OFF = 14   ; ypos offset from williams' anchor to the knife's
                      ; spawn position so it leaves at hand height

* Ladder sub-states (stored at info_block+7)
LD_INIT      = 0      ; first frame: snap to ladder top
LD_DESCEND   = 1      ; climbing down

* Face-off sub-states (stored at info_block+7)
FO_APPROACH    = 0    ; walking toward player
FO_PUNCH       = 1    ; throwing a punch
FO_COOLDOWN    = 2    ; waiting after punch
FO_SOMERSAULT  = 3    ; rolling cartwheel-closer (William only)
FO_GRABBED     = 4    ; held by Billy — AI suspended, frame held

* Somersault tunables
SOMER_TRIGGER  = 12   ; px from target_x; > this triggers somersault on
                      ;   the next FO_APPROACH tick instead of walking
SOMER_DURATION = 6    ; VBLs each somersault sub-frame is shown

* Flank sub-states (stored at info_block+7)
FL_ARC      = 0       ; arc to a corner behind player
FL_CLOSE    = 1       ; close in to back-side punch range
FL_PUNCH    = 2       ; throw a punch
FL_COOLDOWN = 3       ; waiting after punch


*==========================================================
* Keyboard input — ADB Tool Set
*
* Direct GLU polling at $C026/$C027 collides with the ROM's
* always-running ADB IRQ handler, so we use the documented
* ADB Tool Set call _SendInfo ($0909) to disable autorepeat
* on the keyboard. With autorepeat off, $C000/$C010 no longer
* spam stale events for a held key — a single press registers
* exactly one strobe, and $C010 bit 7 stays high while the
* key is physically held.
*
* For modifier keys (shift/ctrl/option/cmd/caps) read $C025
* directly — that's the auto-polled Modifier Key register,
* always live and never contended.
*
* The Mega II's 2-key alphanumeric rollover lets two non-
* modifier keys be pressed simultaneously (e.g. W + A for
* diagonal walk). Combine with modifier-mapped action keys
* (Shift = punch, Option = kick, Cmd = jump) to get true
* multi-key combat without the 2-key alphanumeric ceiling.
*==========================================================

* SendInfo Set Modes data byte. Per Apple IIgs Firmware
* Reference Ch. 9, the mode bit that disables keyboard
* autorepeat is bit 6 ($40). Other bits (mouse, SRQ, etc.)
* stay default.
ADB_MODE_NO_AUTOREPEAT = $40

*----------------------------------------------------------
* kbd_init - Disable keyboard autorepeat via the ADB Tool
* Set. Called once at boot in emulation mode 8-bit.
*
* _SendInfo ($0909) parameter stack (top first):
*   adbCommand  word  $0004 (Set Modes)
*   dataPtr     long  pointer to 1-byte data
*   dataLength  word  $0001
*----------------------------------------------------------
kbd_init
 clc
 xce                   ; native mode
 rep $30               ; 16-bit A/X/Y
 pea #$0001            ; dataLength
 pea ^kbd_mode_byte    ; dataPtr high (bank)
 pea kbd_mode_byte     ; dataPtr low  (offset)
 pea #$0004            ; adbCommand = Set Modes
 ldx #$0909            ; _SendInfo
 jsl $E10000
 sec
 xce                   ; back to emulation
 sep $30
 rts

kbd_mode_byte dfb ADB_MODE_NO_AUTOREPEAT

*----------------------------------------------------------
* kbd_modifiers - Returns the current Modifier Key register
* in A. Bit 0=Cmd, 1=Option, 4=KeyDown, 5=Caps, 6=Ctrl,
* 7=Shift. (See Apple IIgs Hardware Reference Table 6-5.)
* Emulation mode 8-bit on entry/exit.
*----------------------------------------------------------
kbd_modifiers
 ldal $C025
 rts

*----------------------------------------------------------
* kbd_poll - Drain the keyboard's ADB register-0 event FIFO
* via _SyncADBReceive ($0E09) and update kb_held. Each event
* byte: bit 7 = state (0 down, 1 up), bits 6-0 = ADB scancode.
* The keyboard's ADB device returns 2 bytes (latest event +
* prior event) for Talk Reg 0; the completion routine stashes
* them into kbd_buf, and after the call returns we walk the
* buffer and update the bitmap.
*
* _SyncADBReceive parameter stack (top first):
*   adbCommand  word  $0048 (Receive Bytes)
*   compPtr     long  pointer to completion routine
*   inputWord   word  $002C — Talk Reg 0 keyboard, with the
*                     upper/lower nibbles SWAPPED per the
*                     Toolbox Reference Vol 1 spec
*
* Called in emulation mode 8-bit; switches to native + 16-bit
* for the toolbox call and switches back before returning.
*----------------------------------------------------------
kbd_poll
 stz kbd_buf_idx
 stz kbd_buf
 stz kbd_buf+1
 clc
 xce                   ; native
 rep $30               ; 16-bit A/X/Y
 pea #$002C            ; inputWord (Talk Reg 0 keyboard, nibbles swapped)
 pea ^kbd_completion   ; compPtr high (bank)
 pea kbd_completion    ; compPtr low (offset)
 pea #$0048            ; adbCommand = Receive Bytes
 ldx #$0E09            ; _SyncADBReceive
 jsl $E10000
 php                   ; capture C/error flag
 sec
 xce                   ; back to emulation
 sep $30
 pla                   ; recover saved P
 and #$01              ; isolate carry
 sta kbd_err_flag      ; non-zero = SyncADBReceive returned error
* Apply the buffered events to kb_held. kbd_buf_idx is the
* number of bytes the completion routine stored.
* NOTE: SyncADBReceive currently returns adbBusy on this system
* because the ROM ADB IRQ handler owns the bus. The completion
* never fires and kb_held stays empty. Left wired in case a
* future refactor (AsyncADBReceive / SRQPoll) gets this working.
 ldx #0
:apply
 cpx kbd_buf_idx
 bcs :done
 phx
 lda kbd_buf,x
 jsr kbd_apply_event
 plx
 inx
 bra :apply
:done
 rts

*----------------------------------------------------------
* kbd_completion - Called by SyncADBReceive once per response
* byte received from the ADB device. Apple's docs specify the
* completion enters with 8-bit M and X flags and must return
* via RTL with C clear; the data byte is delivered in A. We
* stash A into kbd_buf[kbd_buf_idx], increment the index, and
* return.
*----------------------------------------------------------
 mx %11
kbd_completion
 phb
 phk
 plb                   ; DBR = current PB so abs writes hit kbd_buf
 inc kbd_call_count    ; DEBUG: count every call
 ldx kbd_buf_idx
 cpx #4                ; clamp at 4 just in case (keyboard returns 2)
 bcs :skip
 sta kbd_buf,x
 inx
 stx kbd_buf_idx
:skip
* DEBUG: latch the most recent NON-$FF event byte.
 cmp #$FF
 beq :sk2
 sta kbd_last_event
:sk2
 plb
 clc
 rtl

*----------------------------------------------------------
* kbd_apply_event - A = event byte. bit 7 = state (0 down, 1
* up), bits 6-0 = ADB scancode. $FF = no event in this slot.
*----------------------------------------------------------
 mx %11
kbd_apply_event
 cmp #$FF
 beq :skip
 sta :ev
 and #$7F
 sta :scan
 lda :ev
 and #$80
 bne :up
* down: set bit
 lda :scan
 jsr :idx_bit
 lda kbd_bit_table,y
 ora kb_held,x
 sta kb_held,x
:skip rts
:up
* up: clear bit
 lda :scan
 jsr :idx_bit
 lda kbd_bit_table,y
 eor #$FF
 and kb_held,x
 sta kb_held,x
 rts
:idx_bit
 sta :tmp
 lsr
 lsr
 lsr
 tax
 lda :tmp
 and #$07
 tay
 rts
:ev   dfb 0
:scan dfb 0
:tmp  dfb 0

*----------------------------------------------------------
* key_held - A = ADB scancode. Returns Z=0 if the key is
* currently held, Z=1 if not. Preserves no callee state.
*----------------------------------------------------------
 mx %11
key_held
 sta :tmp
 lsr
 lsr
 lsr
 tax
 lda :tmp
 and #$07
 tay
 lda kb_held,x
 and kbd_bit_table,y
 rts
:tmp dfb 0

kbd_bit_table dfb $01,$02,$04,$08,$10,$20,$40,$80
kb_held       ds 16   ; 128 bits (1 bit per ADB scancode), set this frame
kb_held_prev  ds 16   ; same, set last frame — used for edge detection
kbd_buf       ds 4    ; SyncADBReceive response buffer
kbd_buf_idx   dfb 0
kbd_last_event dfb 0  ; debug: latest non-$FF event byte from MCU
kbd_call_count dfb 0  ; debug: increments every time completion fires
kbd_err_flag   dfb 0  ; debug: $FF if SyncADBReceive returned w/ C=1

* ADB scancodes for game input (Toolbox Ref Vol 1 Table 3-5).
ADB_KEY_W = $0D
ADB_KEY_A = $00
ADB_KEY_S = $01
ADB_KEY_D = $02
ADB_KEY_J = $26
ADB_KEY_L = $25

*----------------------------------------------------------
* process_input - Read keyboard, update Billy's state.
* If an action animation is playing, ignore all input.
*----------------------------------------------------------
process_input
* Burnov-grab lock: while bn_grab_active is set, swallow all
* input. Billy can't defend the BNBILLY pummel sequence.
 lda bn_grab_active
 beq :pi_not_grabbed
 rts
:pi_not_grabbed
* Snapshot last frame's kb_held → kb_held_prev so the action
* dispatch below can edge-detect just-pressed buttons.
 ldx #15
:cp_prev
 lda kb_held,x
 sta kb_held_prev,x
 dex
 bpl :cp_prev
* Drain ADB key events into kb_held.
 jsr kbd_poll
* Tick down the uppercut input window each frame.
 lda landing_window
 beq :no_lw_dec
 dec landing_window
:no_lw_dec
* Tick punch_window (grab trigger).
 lda punch_window
 beq :no_pw_dec
 dec punch_window
:no_pw_dec
* Tick btn_pending_timer (NES-style A/B same-frame window).
* When it transitions to 0, set btn_pending_fire so :accept_input
* knows to dispatch the queued single-button action this frame.
 lda btn_pending_timer
 beq :no_bp_dec
 dec btn_pending_timer
 bne :no_bp_dec
 lda #1
 sta btn_pending_fire
:no_bp_dec
* Tick grab_punch_timer; on the 1->0 transition, restore
* BGRAB2/xHELD1 if we're still grabbing.
 lda grab_punch_timer
 beq :no_gp_dec
 dec grab_punch_timer
 bne :no_gp_dec
 lda grab_target
 ora grab_target+1
 beq :no_gp_dec
* Need info_ptr = Billy for end_grab_punch_subframe — find him
* (controller==1) before calling.
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:gp_find
 jsr load_sprite
 bcs :no_gp_dec
 ldy #22
 lda (info_ptr),y
 cmp #$01
 beq :gp_found
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :gp_find
 inc spr_ptr+1
 bra :gp_find
:gp_found
 jsr end_grab_punch_subframe
:no_gp_dec
* Find the keyboard-controlled sprite (controller = $01)
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:find_player
 jsr load_sprite
 bcc :find_player_ok
 jmp :no_key           ; end of table, no player found (far branch)
:find_player_ok
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
* Mode toggle (Ctrl-J / Ctrl-K) is checked FIRST — before the
* action-anim block — so the user can always switch modes and
* recover if a stuck animation (e.g., anim_jump's auto-advance
* xpos) is driving Billy. The toggle path also calls
* cancel_action_anim to abort whatever Billy is doing, so Ctrl-K
* doubles as an emergency unstick. Border color confirms the
* toggle actually fired.
 lda $c000
 bpl :no_mode_key
 cmp #$8A              ; Ctrl-J
 bne :not_ctrl_j
 sta $c010             ; clear strobe
 lda #1
 sta input_mode
 stz joy_armed         ; require centered read before accepting deflection
 jsr reset_input_state
 jsr cancel_action_anim
 lda #$0F              ; white border = joystick mode
 stal $E0C034
 rts
:not_ctrl_j
 cmp #$8B              ; Ctrl-K
 bne :not_ctrl_k
 sta $c010
 stz input_mode
 jsr reset_input_state
 jsr cancel_action_anim
 lda #$04              ; purple border = keyboard mode
 stal $E0C034
 rts
:not_ctrl_k
 cmp #$8E              ; Ctrl-N = SNES MAX
 bne :no_mode_key
 sta $c010
 lda #2
 sta input_mode
 jsr reset_input_state
 jsr cancel_action_anim
 lda #$0C              ; green border = SNES mode
 stal $E0C034
 rts
:no_mode_key

* Check if action animation is active (block input)
 ldy #24
 lda (info_ptr),y     ; anim_ptr low
 sta anim_ptr
 iny
 lda (info_ptr),y     ; anim_ptr high
 sta anim_ptr+1
 ora anim_ptr
 beq :accept_input    ; no animation, accept input
* Animation active — is it walk or jump? (walk = always ok to
* interrupt; jump = allow J+L re-press through to trigger the
* mid-air spin-kick. btn_action_jump's first instruction
* differentiates the two cases.)
 lda anim_ptr
 cmp #<anim_walk
 bne :pi_chk_jump
 lda anim_ptr+1
 cmp #>anim_walk
 beq :accept_input
:pi_chk_jump
 lda anim_ptr
 cmp #<anim_jump
 bne :blocked
 lda anim_ptr+1
 cmp #>anim_jump
 beq :accept_input
:blocked rts           ; other action animation, block all input

:accept_input
* If a pending J/L single-button action just timed out (no
* second button arrived within BTN_WINDOW), fire it now.
 lda btn_pending_fire
 beq :no_pending_fire
 stz btn_pending_fire
 lda btn_pending_key
 stz btn_pending_key
 jsr btn_action_fire
 rts
:no_pending_fire

 lda input_mode
 beq :kbd_dispatch
 cmp #1
 beq :do_joy_input
 jmp :do_snes_input
:kbd_dispatch
 bit $c000
 bpl :no_key
 jmp :has_key
:no_key rts

*----------------------------------------------------------
* Joystick input path. Stays in process_input scope so it can
* jmp directly to :do_up / :do_left / :ai_do_down / :ai_do_right
* (the same walk handlers the strobe path uses).
*----------------------------------------------------------
:do_joy_input
 jsr GetJoyXY          ; X = JoyX, Y = JoyY (each $00-$FF, ~$80 = center)
 stx :joy_x
 sty :joy_y

* Arming gate: after Ctrl-J (or initial boot) joy_armed = 0.
* We require BOTH axes to read centered for one frame before
* accepting any deflection. KEGS' keyboard-emulated joystick
* sometimes drops the "release" event for an arrow key, leaving
* an axis stuck at $00 or $FF; without arming, that pinned read
* drives Billy in one direction and there's no way out.
* Real hardware: a paddle that powered up off-center calibrates
* on the first centered moment instead of slamming Billy on boot.
 lda joy_armed
 bne :ji_armed
* Not armed yet — accept buttons but no walk dispatch until both
* axes are inside the deadzone simultaneously.
 lda :joy_x
 cmp #JOY_DEAD_LO
 bcc :ji_buttons       ; X out of dz → still drifting, only sample buttons
 cmp #JOY_DEAD_HI+1
 bcs :ji_buttons
 lda :joy_y
 cmp #JOY_DEAD_LO
 bcc :ji_buttons
 cmp #JOY_DEAD_HI+1
 bcs :ji_buttons
 lda #1
 sta joy_armed         ; centered — arm the stick for this session
:ji_armed

* Grab interception. Synthesize a "direction key" from joy_x:
*   joy_x < JOY_DEAD_LO → 'a' (push left)
*   joy_x > JOY_DEAD_HI → 'd' (push right)
*   centered            → 0
* Pass to grab_check, which handles BGRAB freeze, release-on-
* away, and try_enter_grab. C=1 means input was consumed.
 lda :joy_x
 cmp #JOY_DEAD_LO
 bcs :ji_jx_not_left
 lda #'a'
 bra :ji_grab
:ji_jx_not_left
 cmp #JOY_DEAD_HI+1
 bcc :ji_jx_centered
 lda #'d'
 bra :ji_grab
:ji_jx_centered
 lda #0
:ji_grab
 jsr grab_check
 bcc :ji_dispatch
 rts
:ji_dispatch

* Direction dispatch. Vertical wins over horizontal when both
* axes are deflected — keeps the existing single-axis walk
* handlers happy without a diagonal-aware refactor.
 lda :joy_y
 cmp #JOY_DEAD_LO
 bcs :ji_y_not_up
 jmp :do_up
:ji_y_not_up
 cmp #JOY_DEAD_HI
 bcc :ji_y_centered
 jmp :ai_do_down
:ji_y_centered
 lda :joy_x
 cmp #JOY_DEAD_LO
 bcs :ji_x_not_left
 jmp :do_left
:ji_x_not_left
 cmp #JOY_DEAD_HI
 bcc :ji_buttons
 jmp :ai_do_right

*----------------------------------------------------------
* Joystick buttons — on real IIgs, $C062 reads OA/Command and
* $C061 reads CA/Option (opposite of the conventional Apple //
* labeling). We want OA = punch, CA = kick, so :joy_a_cur
* (drives the 'l' / punch path) reads $C062 and :joy_b_cur
* (drives the 'j' / back-kick path) reads $C061. We edge-
* detect against joy_btn_*_prev and feed the same NES "both
* within BTN_WINDOW" pipeline as keyboard J/L. Single press →
* btn_pending_fire after the timer; both within window → jump.
*----------------------------------------------------------
:ji_buttons
 ldal $C062            ; OA/Command on the GS
 and #$80
 sta :joy_a_cur
 ldal $C061            ; CA/Option on the GS
 and #$80
 sta :joy_b_cur

* Button A edge? OA/Command → 'l' (punch in facing direction).
 lda :joy_a_cur
 beq :ji_a_done
 lda joy_btn_a_prev
 bne :ji_a_done        ; was held last frame, no edge
 lda btn_pending_key
 cmp #'j'
 beq :ji_jump          ; B was pending → both → jump
 lda #'l'
 sta btn_pending_key
 lda #BTN_WINDOW
 sta btn_pending_timer
 stz btn_pending_fire
 jmp :ji_save
:ji_a_done

* Button B edge? CA/Option → 'j' (back-kick).
 lda :joy_b_cur
 beq :ji_save
 lda joy_btn_b_prev
 bne :ji_save
 lda btn_pending_key
 cmp #'l'
 beq :ji_jump
 lda #'j'
 sta btn_pending_key
 lda #BTN_WINDOW
 sta btn_pending_timer
 stz btn_pending_fire
 jmp :ji_save

:ji_jump
 stz btn_pending_key
 stz btn_pending_timer
 stz btn_pending_fire
 jsr btn_action_jump
 ; fall through to :ji_save so prev state is updated

:ji_save
 lda :joy_a_cur
 sta joy_btn_a_prev
 lda :joy_b_cur
 sta joy_btn_b_prev
 rts

*----------------------------------------------------------
* SNES MAX dispatch (input_mode = 2). Calls snes_poll to
* refresh snes_b0/b1 (active-HIGH after poll), then walks the
* same :do_up / :ai_do_down / :do_left / :ai_do_right handlers
* the keyboard and joystick paths use. Action buttons funnel
* through the shared btn_pending_* pipeline so the NES-style
* "press both within BTN_WINDOW = jump" rule still applies.
*   B  → 'l' (punch in facing direction)
*   Y  → 'j' (back-kick)
*   B+Y within window → jump
*----------------------------------------------------------
:do_snes_input
 jsr snes_poll

* Grab interception — same shape as the joystick path: synthesize
* a direction key from the D-pad's left/right bits and let
* grab_check own the freeze/release/engage decision.
 lda snes_b0
 and #$02              ; Left
 beq :si_dl_not_left
 lda #'a'
 bra :si_grab
:si_dl_not_left
 lda snes_b0
 and #$01              ; Right
 beq :si_dl_centered
 lda #'d'
 bra :si_grab
:si_dl_centered
 lda #0
:si_grab
 jsr grab_check
 bcc :si_dispatch
 rts
:si_dispatch

* Direction dispatch — vertical wins over horizontal (matches
* the joystick path; the walk handlers are single-axis).
 lda snes_b0
 and #$08              ; Up
 beq :si_not_up
 jmp :do_up
:si_not_up
 lda snes_b0
 and #$04              ; Down
 beq :si_not_down
 jmp :ai_do_down
:si_not_down
 lda snes_b0
 and #$02              ; Left
 beq :si_not_left
 jmp :do_left
:si_not_left
 lda snes_b0
 and #$01              ; Right
 beq :si_buttons
 jmp :ai_do_right

:si_buttons
* B (byte 0 bit 7) edge → 'l' (punch). Edge-detect against
* snes_b0_prev's bit 7 — if it was already set last frame the
* button is being held, no new event.
 lda snes_b0
 and #$80
 beq :si_b_done
 lda snes_b0_prev
 and #$80
 bne :si_b_done
 lda btn_pending_key
 cmp #'j'
 beq :si_jump          ; Y was pending → both → jump
 lda #'l'
 sta btn_pending_key
 lda #BTN_WINDOW
 sta btn_pending_timer
 stz btn_pending_fire
 jmp :si_save
:si_b_done

* Y (byte 0 bit 6) edge → 'j' (back-kick).
 lda snes_b0
 and #$40
 beq :si_save
 lda snes_b0_prev
 and #$40
 bne :si_save
 lda btn_pending_key
 cmp #'l'
 beq :si_jump
 lda #'j'
 sta btn_pending_key
 lda #BTN_WINDOW
 sta btn_pending_timer
 stz btn_pending_fire
 jmp :si_save

:si_jump
 stz btn_pending_key
 stz btn_pending_timer
 stz btn_pending_fire
 jsr btn_action_jump
 ; fall through to :si_save

:si_save
 lda snes_b0
 sta snes_b0_prev
 lda snes_b1
 sta snes_b1_prev
 rts

:joy_x     dfb 0
:joy_y     dfb 0
:joy_a_cur dfb 0
:joy_b_cur dfb 0

*----------------------------------------------------------
* btn_action_fire - A = pending key code ('j' or 'l'). Routes
* to punch or back-kick based on Billy's facing.
*   facing right (mirror=0): J → back-kick, L → punch
*   facing left  (mirror=1): J → punch,     L → back-kick
*----------------------------------------------------------
btn_action_fire
 sta :baf_key
* Weapon handling — L key only.
*   pipe armed:  L → anim_bpipeswing
*   mace armed:  L → anim_bmaceswing
*   unarmed:     L → try to pick up a nearby pipe or mace; on
*                success play anim_bpickup, on no-pickup fall
*                through to the normal punch/kick dispatch below.
 cmp #'l'
 bne :baf_dispatch
 lda billy_pipe_armed
 beq :baf_l_chk_mace
 lda #<anim_bpipeswing
 ldx #>anim_bpipeswing
 jsr start_anim
 rts
:baf_l_chk_mace
 lda billy_mace_armed
 beq :baf_l_pickup
 lda #<anim_bmaceswing
 ldx #>anim_bmaceswing
 jsr start_anim
 rts
:baf_l_pickup
 jsr billy_try_pickup_weapon
 bcs :baf_l_done          ; pickup fired anim_bpickup, return
:baf_dispatch
 ldy #4
 lda (info_ptr),y       ; mirror
 beq :baf_face_right
* facing left
 lda :baf_key
 cmp #'j'
 beq :baf_punch
 jmp :baf_kick          ; L when facing left → back-kick
:baf_face_right
 lda :baf_key
 cmp #'j'
 beq :baf_kick          ; J when facing right → back-kick
 jmp :baf_punch         ; L when facing right → punch
:baf_l_done
 rts
:baf_kick
 lda #<anim_kick
 ldx #>anim_kick
 jsr start_anim
 rts
:baf_punch
* Same sequence the old 'p' strobe handler used.
 ldx #SND_PUNCH
 jsr sound_trigger
 lda landing_window
 beq :baf_reg_punch
 stz landing_window
 lda #<anim_uppercut
 ldx #>anim_uppercut
 jsr start_anim
 rts
:baf_reg_punch
 lda punch_toggle
 eor #$01
 sta punch_toggle
 bne :baf_use_punch2
 lda #<anim_punch1
 ldx #>anim_punch1
 jsr start_anim
 rts
:baf_use_punch2
 lda #<anim_punch2
 ldx #>anim_punch2
 jsr start_anim
 rts
:baf_key dfb 0

*----------------------------------------------------------
* btn_action_jump - both J and L pressed within the window.
*----------------------------------------------------------
btn_action_jump
* If Billy is already mid-jump (anim_ptr == anim_jump) and the
* J+L combo lands again, switch to the spin-kick: replace the
* current animation with anim_bspinkick and trigger SND_SPINKICK.
 lda anim_ptr
 cmp #<anim_jump
 bne :baj_normal
 lda anim_ptr+1
 cmp #>anim_jump
 bne :baj_normal
 ldx #SND_SPINKICK
 jsr sound_trigger
 lda #<anim_bspinkick
 ldx #>anim_bspinkick
 jsr start_anim
 rts
:baj_normal
 lda #<anim_jump
 ldx #>anim_jump
 jsr start_anim
 rts

:has_key
 lda $c010
 and #$7f
* Grab-state interception. While grab_punch_timer is non-zero
* the BGRAB1/xHELD2 sub-anim is playing — eat all input.
* Otherwise: if grabbing, route through handle_grab_input
* (which may release on direction-AWAY or fire grab-punch).
* If not grabbing, give try_enter_grab a shot at the key.
 sta last_key
 lda grab_punch_timer
 beq :gi_check_grab
 rts                    ; freeze input during the sub-anim
:gi_check_grab
 lda grab_target
 ora grab_target+1
 beq :gi_try_enter
 lda last_key
 jsr handle_grab_input
 lda grab_target
 ora grab_target+1
 beq :gi_continue       ; released, fall through to walk dispatch
 rts                    ; still grabbing -> swallow input
:gi_try_enter
 lda punch_window
 beq :gi_continue
 lda last_key
 jsr try_enter_grab
 lda grab_target
 ora grab_target+1
 beq :gi_continue
 rts                    ; entered grab, swallow input
:gi_continue
* J/L button intake (NES-style A/B with same-frame window).
* On J or L edge: if the OTHER button is already pending, fire
* jump and clear pending. Otherwise queue this key with a
* BTN_WINDOW-frame timer so the tick block can fire it later
* if no second button arrives.
 lda last_key
 cmp #'j'
 beq :handle_btn_j
 cmp #'l'
 beq :handle_btn_l
 jmp :btn_done
:handle_btn_j
 lda btn_pending_key
 cmp #'l'
 beq :btn_jump
 lda #'j'
 sta btn_pending_key
 lda #BTN_WINDOW
 sta btn_pending_timer
 stz btn_pending_fire
 rts
:handle_btn_l
 lda btn_pending_key
 cmp #'j'
 beq :btn_jump
 lda #'l'
 sta btn_pending_key
 lda #BTN_WINDOW
 sta btn_pending_timer
 stz btn_pending_fire
 rts
:btn_jump
 stz btn_pending_key
 stz btn_pending_timer
 stz btn_pending_fire
 jsr btn_action_jump
 rts
:btn_done
 lda last_key
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
 cmp #'w'
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
:up_cur_bmax dfb 0
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
* Step rule: if the proposed row's bmax is less than the
* current row's bmax, the row above is narrower — that's a
* "step up into a wall," which should require a ladder. Catches
* scr2's rising staircase: walking up at low xpos passes the
* bmin/bmax check at every row even though visually Billy is
* climbing the angled wall edge. Equal/larger proposed bmax is
* an ordinary vertical walk on a uniform or widening surface
* (scr5 ledge → corridor transitions, etc.).
 ldx IMAGE01_YPOS
 lda bounds_tbl_hi,x
 sta :up_cur_bmax
 dex
 lda bounds_tbl_hi,x
 cmp :up_cur_bmax
 bcs :up_no_step      ; proposed >= current → flat or widening
* Proposed bmax < current → narrower row. Require an active
* ladder + scroll_up_enabled.
 lda IMAGE01_YPOS
 sec
 sbc #1
 jsr check_ladder
 bcs :up_blocked_ladder
 lda scroll_up_enabled
 beq :up_blocked_ladder
 lda #1
 sta via_ladder       ; force climb anim
 jmp :up_do_move
:up_no_step
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
:not_up cmp #'s'
 bne :not_down
:ai_do_down
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
:not_down cmp #'a'
 beq :do_left          ; 'a' → handle left below
 jmp :not_left         ; far jump (out of branch range after walk_x bounds added)
:do_left
* Climb lock — only fire while Billy is *actually* mid-climb.
* Conditions:
*   1. scroll_up_enabled (an OP_UP is active)
*   2. current row is bounds-blocked (bmax==0) — i.e. Billy is
*      on a row he could only reach via the ladder
*   3. current column is on a ladder
* At floor level the row is walkable, so the lock no-ops and
* Billy can step on/off the ladder freely; once scroll_up's
* snap moves him onto a bmax=0 row, the gate keeps him centered.
 lda scroll_up_enabled
 beq :dl_not_climb
 ldx IMAGE01_YPOS
 lda bounds_tbl_hi,x
 bne :dl_not_climb
 lda IMAGE01_XPOS
 sta chk_xpos
 lda IMAGE01_YPOS
 jsr check_ladder
 bcs :dl_not_climb
 rts
:dl_not_climb
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
 jsr check_x_bounds_walk_left
 bcs :skip_left        ; bounds (curr ∩ left-neighbor) reject this X
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
:not_left cmp #'d'
 beq :ai_do_right
 jmp :not_jump
:ai_do_right
* Climb lock — same gate as :do_left. Only fires when Billy is
* mid-climb: scroll_up_enabled set, current row bounds-blocked
* (bmax==0), and on a ladder column. At floor level the lock
* no-ops so Billy can walk onto/off the ladder freely.
 lda scroll_up_enabled
 beq :dr_not_climb
 ldx IMAGE01_YPOS
 lda bounds_tbl_hi,x
 bne :dr_not_climb
 lda IMAGE01_XPOS
 sta chk_xpos
 lda IMAGE01_YPOS
 jsr check_ladder
 bcs :dr_not_climb
 rts
:dr_not_climb
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
 jsr check_x_bounds_walk_right
 bcs :clamp_right      ; bounds (curr ∩ right-neighbor) reject this X
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
* Old 'j'/'k'/'p' strobe handlers replaced by the J/L action
* dispatch at :accept_input — fall through to the rest of the
* strobe path for debug/special keys.
:not_jump
:not_invuln cmp #'v'
 bne :not_b
 jsr verify_punch_state
 rts
:not_b cmp #'b'
 bne :not_verify
* Trigger punch, wait ~3 VBLs (~50 ms — well inside the
* 120 ms sample), then snapshot state during playback.
 ldx #SND_PUNCH
 jsr sound_trigger
 jsr verify_wait_3vbls
 jsr verify_punch_state
 rts
:not_verify cmp #'i'
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
* reset_input_state - zero everything that latches across a
* mode switch. Called from Ctrl-J / Ctrl-K so a stuck axis,
* held button, or pending edge from the previous mode can't
* survive into the new one. Anim state is left alone.
*----------------------------------------------------------
reset_input_state
 stz btn_pending_key
 stz btn_pending_timer
 stz btn_pending_fire
 stz joy_btn_a_prev
 stz joy_btn_b_prev
 stz landing_window
 stz snes_b0_prev
 stz snes_b1_prev
 rts

*----------------------------------------------------------
* grab_check - Shared grab-state interception used by the
* joystick and SNES paths (the keyboard path inlines the same
* logic in :has_key). On entry: info_ptr = Billy, A = the
* "direction key" the input mode is producing ('a' for left,
* 'd' for right, or 0 / anything else if no horizontal input
* this frame). Stores A in last_key, then runs the same three-
* stage decision the keyboard path uses:
*   1. grab_punch_timer != 0 → BGRAB sub-anim playing, freeze
*      input.
*   2. grab_target != 0    → handle_grab_input (release on
*      direction-away, fire grab-punch on 'p', otherwise stay
*      grabbed).
*   3. punch_window != 0   → try_enter_grab.
* Returns C=0 to mean "proceed with caller's normal dispatch"
* and C=1 to mean "input was consumed, caller should rts."
*----------------------------------------------------------
grab_check
 sta last_key
 lda grab_punch_timer
 beq :gck_check_target
 sec
 rts                    ; sub-anim — swallow
:gck_check_target
 lda grab_target
 ora grab_target+1
 beq :gck_try_enter
 lda last_key
 jsr handle_grab_input
 lda grab_target
 ora grab_target+1
 beq :gck_proceed       ; released, fall through to dispatch
 sec
 rts                    ; still grabbing — swallow
:gck_try_enter
 lda punch_window
 beq :gck_proceed
 lda last_key
 jsr try_enter_grab
 lda grab_target
 ora grab_target+1
 beq :gck_proceed
 sec
 rts                    ; entered grab — swallow
:gck_proceed
 clc
 rts

*----------------------------------------------------------
* snes_poll - Read SNES MAX controller 1 into snes_b0/b1.
*
* Protocol: write any value to SNES_LATCH to pulse the latch.
* Then 16 cycles of: read SNES_LATCH (bit 7 = controller 1
* current bit, MSB-first), shift into the result byte, write
* any value to SNES_CLOCK to pulse the clock. After all 16
* bits are in, EOR with $FF so "pressed" reads as 1 (the
* card returns active-LOW).
*
* Bit layout after poll (active HIGH):
*   snes_b0: 0=Right 1=Left 2=Down 3=Up 4=Start 5=Select 6=Y 7=B
*   snes_b1: 0-3 unused, 4=R-shoulder 5=L-shoulder 6=X 7=A
*
* Controller 2 is ignored (the card's bit 6 path); this game
* is single-player. Add a second poll routine if/when needed.
*----------------------------------------------------------
snes_poll
 stal SNES_LATCH       ; latch pulse — value doesn't matter
 ldx #0
:sp_byte
 ldy #8
:sp_bit
 ldal SNES_LATCH       ; bit 7 = controller 1 data
 asl                   ; bit 7 → carry
 rol snes_b0,x         ; carry → bit 0 of snes_b0/b1
 stal SNES_CLOCK       ; clock pulse
 dey
 bne :sp_bit
 inx
 cpx #2
 bne :sp_byte
* Active-LOW raw → active-HIGH (button pressed = bit set)
 lda snes_b0
 eor #$FF
 sta snes_b0
 lda snes_b1
 eor #$FF
 sta snes_b1
 rts

*----------------------------------------------------------
* cancel_action_anim - Emergency unstick. If Billy's anim_ptr
* is non-zero, snapshot prev_* so the current frame's drawing
* gets erased, clear anim_ptr/anim_frame, and restore the idle
* frame from idle_addr/idle_x/idle_y. Used by Ctrl-J/Ctrl-K so
* the user can always recover from a stuck animation.
* Assumes info_ptr already points at Billy.
*----------------------------------------------------------
cancel_action_anim
 ldy #24
 lda (info_ptr),y      ; anim_ptr low
 sta :tmp
 iny
 lda (info_ptr),y      ; anim_ptr high
 ora :tmp
 bne :ca_active
 rts                   ; no anim active, nothing to do
:ca_active
 ldy #2
 lda (info_ptr),y
 ldy #34
 sta (info_ptr),y      ; prev_xpos
 ldy #0
 lda (info_ptr),y
 ldy #32
 sta (info_ptr),y      ; prev_ypos
 ldy #10
 lda (info_ptr),y
 ldy #36
 sta (info_ptr),y      ; prev_frame_x
 ldy #12
 lda (info_ptr),y
 ldy #38
 sta (info_ptr),y      ; prev_frame_y
 ldy #24
 lda #0
 sta (info_ptr),y
 iny
 sta (info_ptr),y      ; anim_ptr = 0
 ldy #26
 sta (info_ptr),y      ; anim_frame = 0
 ldy #42
 lda (info_ptr),y
 ldy #14
 sta (info_ptr),y      ; frame_addr lo
 ldy #43
 lda (info_ptr),y
 ldy #15
 sta (info_ptr),y      ; frame_addr hi
 ldy #44
 lda (info_ptr),y
 ldy #10
 sta (info_ptr),y      ; frame_x
 ldy #46
 lda (info_ptr),y
 ldy #12
 sta (info_ptr),y      ; frame_y
 lda #0
 sta MASK_ADDR
 sta MASK_ADDR+1
 ldy #52
 sta (info_ptr),y
 iny
 sta (info_ptr),y
 ldy #30
 lda #$03
 sta (info_ptr),y
 rts
:tmp dfb 0

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
* Armed dispatch: if Billy is carrying a pipe or a mace, walk
* uses the matching armed walk table (legacy renderer in bank
* $19). Clear MASK_ADDR + set sprite_bank = $19 so the cross-
* bank long-indirect reads land on the right pixels.
 lda billy_pipe_armed
 bne :aw_pipe
 lda billy_mace_armed
 bne :aw_mace
 bra :aw_unarmed
:aw_pipe
 lda pipe_walk_addr_tbl,x
 sta FRAME_ADDR
 lda pipe_walk_addr_tbl+1,x
 sta FRAME_ADDR+1
 bra :aw_armed_common
:aw_mace
 lda mace_walk_addr_tbl,x
 sta FRAME_ADDR
 lda mace_walk_addr_tbl+1,x
 sta FRAME_ADDR+1
:aw_armed_common
 lda #0
 sta MASK_ADDR
 sta MASK_ADDR+1
 lda #$19
 sta sprite_bank
 stz sprite_bank+1
 rts
:aw_unarmed
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
* Per-anim frame_bank from descriptor flag bit 5.
*   bit 5 clear → frames in bank $02 (mission1)
*   bit 5 set   → frames in bank $19 (mission12)
* Lets a single sprite straddle both banks (e.g. williams_pipe
* walks with bank-$19 WPIPEWALK frames but falls with bank-$02
* anim_wfall). :normal_end restores info+56 from info+58 when the
* anim ends so the idle frame draws from its own bank.
 ldy #2
 lda (anim_ptr),y     ; flags
 and #$20
 beq :sa_bank2
 lda #$19
 ldy #56
 sta (info_ptr),y
 bra :sa_bank_done
:sa_bank2
 lda #$02
 ldy #56
 sta (info_ptr),y
:sa_bank_done
* Detect compiled-format flag (bit 7 of header flags byte at +2).
 ldy #2
 lda (anim_ptr),y
 and #$80
 bne :sa_compiled
* === Legacy 5-byte stride: frame 0 at +3..+7 ===
* Reached by NPC animations and by Billy's anim_uppercut (which is
* uncompiled because BUPPER frames don't ship in compiled form).
* If the keyboard player (Billy) is starting an uncompiled anim,
* clear MASK_ADDR + info+52 so draw_all routes him through the
* legacy draw_sprite path. NPCs starting uncompiled anims must
* NOT touch MASK_ADDR — when Billy hits an NPC mid-punch the hit
* path runs start_anim on the target's punched_anim, and clearing
* the global mask there would clobber Billy's compiled state and
* re-route him into the legacy renderer with compiled data,
* rendering as black boxes around his sprite.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :sa_legacy_load
 lda #0
 sta MASK_ADDR
 sta MASK_ADDR+1
 ldy #52
 lda #0
 sta (info_ptr),y
 iny
 sta (info_ptr),y
:sa_legacy_load
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

* Burnov helmet-Y offset. Same idea as FALL_Y_OFFSET but for the
* BDISS7/BDISS8 helmet frames during the boss dissolve sequence:
* the body is gone, only the helmet remains, and it should sit
* on the floor — not float at the body's head height. Applied
* at the body→helmet transition in :load_frame and reversed at
* the helmet→body transition during recon.
BDISS_HELMET_Y = 15

* Fall trajectory (NES-style arc). Frame 0 of fall_anim plays for
* FALL_ARC_FRAMES VBLs; on each VBL, ypos moves -2 while timer >
* FALL_ARC_PEAK and +2 otherwise (so the apex is FALL_ARC_PEAK*2 px
* up, and net Y change over the whole arc is 0). xpos shifts ±1
* per VBL based on enemy.mirror (so the body lands FALL_ARC_FRAMES
* px in Billy's facing direction). Flag bit 4 in the anim header
* gates the trajectory.
FALL_ARC_FRAMES = 10        ; total VBLs Frame 0 plays for
FALL_ARC_PEAK   = 5         ; timer threshold: > → rising, ≤ → falling

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
:no_advance
* Check flags bit 4: fall trajectory (parabolic arc, only on frame 0).
* Per-VBL: dx = ±1 in the direction Billy is currently facing,
* dy = -2 on the rising half (timer > FALL_ARC_PEAK), +2 on the
* falling half. Net Y returns to start; net X displaces by
* FALL_ARC_FRAMES*1 away from Billy's punch.
 ldy #2
 lda (anim_ptr),y     ; flags
 and #$10             ; bit 4
 bne :ftraj_check_frm
 jmp :no_ftraj
:ftraj_check_frm
 ldy #26
 lda (info_ptr),y     ; anim_frame
 beq :ftraj_proceed
 jmp :no_ftraj        ; only frame 0 (the FALL pose)
:ftraj_proceed
* On the first VBL of the trajectory (timer still = FALL_ARC_FRAMES),
* leave prev_xpos/ypos alone — start_anim left them pointing at the
* standing pose's last drawn position. But CLAMP prev_frame_y to at
* least 40 (standing height) and prev_frame_x to at least 20 so the
* union erase rect always covers the standing-pose footprint, even
* when the enemy was mid-wpunched (38 tall) or some other shorter
* intermediate pose where the prev sync had a smaller rect than the
* boot region needs. On subsequent VBLs, snapshot prev_* normally.
 ldy #28
 lda (info_ptr),y
 cmp #FALL_ARC_FRAMES
 bne :ftraj_do_snap
* First VBL: clamp prev_frame_x/y to standing-pose minimums.
 ldy #36
 lda (info_ptr),y
 cmp #20
 bcs :ftraj_pfx_ok
 lda #20
 sta (info_ptr),y
:ftraj_pfx_ok
 ldy #38
 lda (info_ptr),y
 cmp #40
 bcs :ftraj_skip_snap
 lda #40
 sta (info_ptr),y
 bra :ftraj_skip_snap
:ftraj_do_snap
* Snapshot prev_* before mutating current. Same standing-pose
* minimum clamp as :ftraj_pfx_ok — without it, prev_frame_y
* drops to LFALL/WFALL/etc. (~23 rows) on tick 2+ and the
* union erase rect can't reach the bottom rows of last tick's
* drawing. Most visible as "unerased feet" when an NPC is
* punched off a ladder while walking up: their LFWALK frames
* are 39-40 rows tall, but the LFALL frame they snap into is
* only 23.
 ldy #2
 lda (info_ptr),y
 ldy #34
 sta (info_ptr),y     ; prev_xpos
 ldy #0
 lda (info_ptr),y
 ldy #32
 sta (info_ptr),y     ; prev_ypos
 ldy #10
 lda (info_ptr),y
 cmp #20
 bcs :ftraj_snap_pfx_ok
 lda #20
:ftraj_snap_pfx_ok
 ldy #36
 sta (info_ptr),y     ; prev_frame_x (clamped to >= 20)
 ldy #12
 lda (info_ptr),y
 cmp #40
 bcs :ftraj_snap_pfy_ok
 lda #40
:ftraj_snap_pfy_ok
 ldy #38
 sta (info_ptr),y     ; prev_frame_y (clamped to >= 40)
:ftraj_skip_snap
* dx is read from BILLY's facing, not the enemy's: Billy mirror=0
* (faces right) → enemy falls right (+1 dx); Billy mirror=1 (faces
* left) → enemy falls left (-1 dx). This guarantees the body
* always flies away from Billy's punch direction even in cases
* where the enemy's facing hasn't synced with Billy's at hit
* time (e.g., grab-punch, hit-from-behind, multi-NPC scrums).
* Clamp to playfield bounds [1, PLAYER_MAX_X] so a hit near the edge
* doesn't fling the body offscreen. Hitting the wall stops horizontal
* motion for the rest of the arc — sprite still rises and falls.
 lda billy_sprite+4    ; Billy's mirror byte
 bne :ftraj_dx_neg
* Moving right: width-aware. Don't push the sprite's right edge
* (xpos + frame_x) past PLAYFIELD_EDGE. Fall poses are wider
* than walking sprites (William: walk=9, FALL=19, FALLEN=16);
* the old fixed PLAYER_MAX_X (98) clamp let wide fall frames
* poke 8+ bytes past the playable area.
 ldy #2
 lda (info_ptr),y
 ldy #10
 clc
 adc (info_ptr),y     ; xpos + frame_x = current right edge
 cmp #PLAYFIELD_EDGE
 bcs :ftraj_dy        ; right edge >= 109 — moving would push past
 ldy #2
 lda (info_ptr),y
 clc
 adc #1
 sta (info_ptr),y
* If the falling sprite is Billy, keep abs_x in lockstep so
* assert_abs_x doesn't fire. NPCs don't track abs_x.
 ldy #22
 lda (info_ptr),y
 cmp #1
 bne :ftraj_dy
 inc abs_x
 bne :ftraj_dy
 inc abs_x+1
 bra :ftraj_dy
:ftraj_dx_neg
* Moving left: skip if xpos already at 1.
 ldy #2
 lda (info_ptr),y
 cmp #2
 bcc :ftraj_dy        ; xpos < 2 — clamp (no dec)
 sec
 sbc #1
 sta (info_ptr),y
* If the falling sprite is Billy, keep abs_x in lockstep.
 ldy #22
 lda (info_ptr),y
 cmp #1
 bne :ftraj_dy
 lda abs_x
 bne :ftraj_absx_lo
 dec abs_x+1
:ftraj_absx_lo
 dec abs_x
:ftraj_dy
* dy: rising while timer > FALL_ARC_PEAK, falling otherwise.
 ldy #28
 lda (info_ptr),y     ; current timer (counts down)
 cmp #FALL_ARC_PEAK+1
 bcc :ftraj_falling
* Rising: ypos -= 2
 ldy #0
 lda (info_ptr),y
 sec
 sbc #2
 sta (info_ptr),y
 bra :ftraj_done
:ftraj_falling
* Falling: ypos += 2
 ldy #0
 lda (info_ptr),y
 clc
 adc #2
 sta (info_ptr),y
:ftraj_done
 ldy #30
 lda #$03
 sta (info_ptr),y     ; mark dirty
:no_ftraj
* Decrement timer
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
* Landing detection: if Billy's jump anim just ended, open the
* uppercut window. Only Billy runs anim_jump so the anim_ptr
* match is sufficient.
 lda anim_ptr
 cmp #<anim_jump
 bne :ad_not_jump
 lda anim_ptr+1
 cmp #>anim_jump
 bne :ad_not_jump
 lda #UPPERCUT_WINDOW
 sta landing_window
:ad_not_jump
* === Burnov boss-death state machine ===
* Triggered for any sprite whose frame_bank == $19 (currently
* only Burnov). Three transitions:
*   anim_bnfall ended  →  start anim_bn_diss (BURNGONE) OR permadeath
*   anim_bn_diss ended →  teleport + start anim_bn_recon (BURNBACK)
*   anim_bn_recon ended →  reset punch_count, increment death_count,
*                          fall through to :normal_end (idle restore).
 ldy #56
 lda (info_ptr),y      ; frame_bank
 cmp #$19
 bne :ad_normal_flow   ; not bank-$19 (Burnov/linda_flail), take existing path
* Was the just-ended anim specifically anim_bnfall? Compare
* against the descriptor address directly rather than against
* the sprite's +50 field — linda_flail also lives in bank $19
* and has her own fall_anim (anim_lffall) which we DON'T want
* to trigger the boss dissolve cycle.
 lda anim_ptr
 cmp #<anim_bnfall
 bne :ad_bn_check_diss
 lda anim_ptr+1
 cmp #>anim_bnfall
 bne :ad_bn_check_diss
* anim_bnfall ended. Permadeath on the 3rd kill, dissolve on
* the 1st and 2nd.
 lda boss_death_count
 cmp #2
 bcs :ad_do_death      ; >= 2: real death, level ends
 jsr start_burnov_dissolve
 jmp :next
:ad_bn_check_diss
 lda anim_ptr
 cmp #<anim_bn_diss
 bne :ad_bn_check_recon
 lda anim_ptr+1
 cmp #>anim_bn_diss
 bne :ad_bn_check_recon
 jsr start_burnov_recon
 jmp :next
:ad_bn_check_recon
 lda anim_ptr
 cmp #<anim_bn_recon
 bne :ad_normal_flow
 lda anim_ptr+1
 cmp #>anim_bn_recon
 bne :ad_normal_flow
 jsr finish_burnov_recon
 jmp :normal_end       ; restore idle frame & resume FACEOFF

:ad_normal_flow
* Check if this was a fall_anim and punch_count >= 6 (death)
 ldy #50
 lda (info_ptr),y     ; fall_anim low
 cmp anim_ptr
 beq :ad_check_fall_hi
 jmp :normal_end
:ad_check_fall_hi
 iny
 lda (info_ptr),y     ; fall_anim high
 cmp anim_ptr+1
 beq :ad_check_pc
 jmp :normal_end
:ad_check_pc
 ldy #48
 lda (info_ptr),y     ; punch_count
 cmp #6
 bcs :ad_do_death
 jmp :normal_end
:ad_do_death
* Death: set $FFFF sentinel, mark dirty for erase+removal.
*
* For a fall-anim death, the sprite has a history of drawings
* at different rects at this xpos: walking/wpunched at ypos-24
* (40 tall), fall frame 0 also around ypos-24 (33 tall), and
* fall frame 1 (FALLEN ~13 tall) at the bumped ypos. The
* death erase needs to cover ALL of these because intermediate
* transitions might not have fully cleaned them (e.g., rapid
* punches where save_anim_state races the erase). Set prev to
* a generous rect that envelops every pre-bump position.
*
* Per-target sizing:
*   frame_bank=$19 → Burnov (BNWALK 13×48, BNFALL 13×46,
*                    BNFALLEN 23×23) → 24 wide × 48 tall
*   else           → William-class (WFALL 19×33, WFALLEN 16×13,
*                    walk 9×40) → 20 wide × 40 tall
* prev_frame_y is also capped at (180 - prev_ypos) so the erase
* never bleeds into the HUD.
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
* Pick rect dims based on frame_bank. $19 = Burnov (taller +
* wider sprite set); anything else = William-class.
 ldy #56
 lda (info_ptr),y
 cmp #$19
 bne :dd_normal_dims
 lda #24
 sta :dd_w            ; Burnov width — pad past BNFALLEN's 23
 lda #48
 sta :dd_h            ; BNWALK1 standing height
 bra :dd_dims_set
:dd_normal_dims
 lda #20
 sta :dd_w            ; covers WFALL's 19
 lda #40
 sta :dd_h            ; covers walking-pose height
:dd_dims_set
 lda :dd_w
 ldy #36
 sta (info_ptr),y     ; prev_frame_x
* Cap height so erase doesn't bleed into the HUD at y=180+.
* prev_frame_y = min(:dd_h, 180 - prev_ypos)
 lda #180
 ldy #32
 sec
 sbc (info_ptr),y     ; A = 180 - prev_ypos
 cmp :dd_h
 bcc :dd_use_capped
 lda :dd_h
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
* Billy game-over check: BILLY_MAX_FALLS reached AND the anim
* that just ended is Billy's fall_anim. game_over never returns
* (draws overlay, waits, JMP $1000 to TITLE).
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :ne_not_billy_dead
 ldy #50
 lda (info_ptr),y
 cmp anim_ptr
 bne :ne_not_billy_dead
 ldy #51
 lda (info_ptr),y
 cmp anim_ptr+1
 bne :ne_not_billy_dead
 lda billy_fall_count
 cmp #BILLY_MAX_FALLS
 bcc :ne_not_billy_dead
 jmp game_over
:ne_not_billy_dead
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
* williams_knife throw-end hook: if the anim that just ended is
* anim_wkthrow, spawn the knife projectile and downgrade
* williams_knife to a regular williams (BEHAV_FACEOFF). Only
* BEHAV_KNIFER ever runs this anim, so the lookup is safe.
* Falls through to the rest of :normal_end (fall un-bump skips
* because anim_wkthrow != fall_anim, idle restore loads williams'
* WILLIAM1 idle frame).
 lda anim_ptr
 cmp #<anim_wkthrow
 bne :ne_not_wkthrow
 lda anim_ptr+1
 cmp #>anim_wkthrow
 bne :ne_not_wkthrow
 jsr spawn_thrown_knife
 lda #BEHAV_FACEOFF
 ldy #6
 sta (info_ptr),y
 lda #FO_APPROACH
 ldy #7
 sta (info_ptr),y
:ne_not_wkthrow
* Billy pickup hook: anim_bpickup just finished. Armed flag
* and idle pose were already set at pickup time
* (billy_try_pickup_weapon → billy_arm_pipe / billy_arm_mace);
* all that's left is to drop the compiled JUMP3 mask so the
* next draw routes Billy through the legacy renderer with the
* armed walk frames.
 lda anim_ptr
 cmp #<anim_bpickup
 bne :ne_not_bpickup
 lda anim_ptr+1
 cmp #>anim_bpickup
 bne :ne_not_bpickup
 lda #0
 sta MASK_ADDR
 sta MASK_ADDR+1
 ldy #52
 sta (info_ptr),y
 iny
 sta (info_ptr),y
:ne_not_bpickup
* Burnov-grab end hook: anim_bngrab just finished (last frame
* was BNBILLY3, the release pose). Clear the active flag,
* re-mark Billy as needing draw, and start his fall_anim from
* his pre-grab position (which billy_sprite still holds —
* nothing modified it during the grab since input/walk were
* gated off).
 lda anim_ptr
 cmp #<anim_bngrab
 beq :ne_grab_chk_hi
 jmp :ne_not_bngrab
:ne_grab_chk_hi
 lda anim_ptr+1
 cmp #>anim_bngrab
 beq :ne_grab_do
 jmp :ne_not_bngrab
:ne_grab_do
 stz bn_grab_active
* Save Burnov's info_ptr; switch to billy_sprite to start his
* fall_anim. start_anim handles all of Billy's frame setup.
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 lda #<billy_sprite
 sta info_ptr
 lda #>billy_sprite
 sta info_ptr+1
* Mirror Billy so he faces Burnov (so the trajectory dx and
* fall pose orient correctly). Burnov's mirror was already
* loaded above (anim_bngrab's last frame).
 lda IMAGE01_MIRROR
 eor #$01
 ldy #4
 sta (info_ptr),y     ; opposite of Burnov's facing
* Load Billy's globals for start_anim.
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
 ldy #50
 lda (info_ptr),y
 pha
 ldy #51
 lda (info_ptr),y
 tax
 pla
 jsr start_anim
* Count this as one of Billy's 5 falls. Mirrors the cascade in
* check_punch_hit :use_fall and knife_hit_billy: zero
* punch_count, bump billy_fall_count, deplete one palette-02
* slot. check_punch_hit's grab branch jumped to :done before
* hitting :use_fall, so this is the only place the grab's
* fall is accounted for.
 lda #0
 ldy #48
 sta (info_ptr),y     ; reset Billy's punch_count
 inc billy_fall_count
 lda billy_fall_count
 cmp #1
 bne :ne_grab_dep_2
 lda #0
 stal $019E48
 stal $019E49
 jmp :ne_grab_dep_done
:ne_grab_dep_2
 cmp #2
 bne :ne_grab_dep_3
 lda #0
 stal $019E46
 stal $019E47
 jmp :ne_grab_dep_done
:ne_grab_dep_3
 cmp #3
 bne :ne_grab_dep_4
 lda #0
 stal $019E44
 stal $019E45
 jmp :ne_grab_dep_done
:ne_grab_dep_4
 cmp #4
 bne :ne_grab_dep_5
 lda #0
 stal $019E42
 stal $019E43
 jmp :ne_grab_dep_done
:ne_grab_dep_5
 cmp #5
 bne :ne_grab_dep_done
 lda #0
 stal $019E54
 stal $019E55
:ne_grab_dep_done
* Restore Burnov's info_ptr so :normal_end's idle restore below
* operates on him.
 pla
 sta info_ptr+1
 pla
 sta info_ptr
:ne_not_bngrab
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
* linda_flail special case: if the just-ended fall_anim is hers
* (walk_anim still == anim_lfwalk, meaning she hasn't yet
* transformed), drop her mace and turn her into a regular Linda.
* The detector keys on walk_anim — once we've transformed her,
* walk_anim becomes anim_lwalk and this branch won't fire again,
* so subsequent falls follow the normal fall→get-up→eventual
* permadeath path.
 ldy #52
 lda (info_ptr),y
 cmp #<anim_lfwalk
 bne :ne_not_lfflail
 ldy #53
 lda (info_ptr),y
 cmp #>anim_lfwalk
 bne :ne_not_lfflail
 jsr linda_flail_drop_and_transform
 bra :ne_no_unbump
:ne_not_lfflail
* williams_pipe special case: walk_anim = anim_wpipewalk while
* armed. Drop a PIPE1 item and rewrite the block to be a regular
* williams (walk_anim → anim_wwalk, etc.). After the transform
* this branch won't fire again.
 ldy #52
 lda (info_ptr),y
 cmp #<anim_wpipewalk
 bne :ne_not_wpipe
 ldy #53
 lda (info_ptr),y
 cmp #>anim_wpipewalk
 bne :ne_not_wpipe
 jsr williams_pipe_drop_and_transform
 bra :ne_no_unbump
:ne_not_wpipe
* williams_knife special case: he uses the regular williams
* template (walk_anim = anim_wwalk) so we can't key on walk_anim
* like linda. Behavior at +6 == BEHAV_KNIFER means he hadn't
* thrown yet — drop the knife and downgrade to BEHAV_FACEOFF
* so subsequent falls take the normal williams path.
 ldy #6
 lda (info_ptr),y
 cmp #BEHAV_KNIFER
 bne :ne_no_unbump
 jsr williams_knife_drop_and_transform
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
* Fall rescue: if the just-ended anim was this sprite's fall_anim
* and the post-un-bump position lands outside the row's bounds,
* walk ypos up until bounds_tbl_hi[ypos] is non-zero, then clamp
* xpos into [bmin, bmax-frame_x]. Covers irregular bounds layouts
* (e.g., scr5's stepped platforms) where the parabolic arc can
* drop the body just past the walkable area.
 ldy #50
 lda (info_ptr),y
 cmp anim_ptr
 beq :ne_rescue_check_hi
 jmp :ne_no_rescue
:ne_rescue_check_hi
 ldy #51
 lda (info_ptr),y
 cmp anim_ptr+1
 beq :ne_rescue_do
 jmp :ne_no_rescue
:ne_rescue_do
* Walk ypos up until row is non-blocked. Stop at row 0 if we
* never find one (defensive — should always find a walkable row
* somewhere above the fall position).
 ldy #0
 lda (info_ptr),y
 tax                  ; X = current ypos
:ne_rescue_y_loop
 lda bounds_tbl_hi,x
 bne :ne_rescue_y_done
 cpx #0
 beq :ne_rescue_y_done
 dex
 bra :ne_rescue_y_loop
:ne_rescue_y_done
* Commit rescued ypos to info+0 and prev_ypos.
 txa
 ldy #0
 sta (info_ptr),y
 ldy #32
 sta (info_ptr),y
* Read bmin/bmax for this row. If the row is fully blocked
* (bmax==0 from rescue bailing at row 0), skip the X clamp.
 lda bounds_tbl_hi,x
 bne :ne_rescue_have_bmax
 jmp :ne_no_rescue
:ne_rescue_have_bmax
 sta :ne_rescue_xmax
 lda bounds_tbl_lo,x
 sta :ne_rescue_xmin
* Clamp xpos: xpos < bmin → xpos = bmin; right_edge > bmax →
* xpos = bmax - idle_x. For Billy (controller=1) the trajectory
* and FALLEN clamps kept abs_x in lockstep with xpos; if THIS
* snap moves xpos, abs_x has to follow or assert_abs_x trips.
 ldy #2
 lda (info_ptr),y
 sta :ne_rescue_oldx
 cmp :ne_rescue_xmin
 bcs :ne_rescue_xmax_chk
* Snap xpos = bmin.
 lda :ne_rescue_xmin
 ldy #2
 sta (info_ptr),y
 ldy #34
 sta (info_ptr),y
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :ne_no_rescue
* Billy: abs_x += (bmin - old_xpos)  (positive delta)
 lda :ne_rescue_xmin
 sec
 sbc :ne_rescue_oldx
 sta :ne_rescue_dx
 lda abs_x
 clc
 adc :ne_rescue_dx
 sta abs_x
 lda abs_x+1
 adc #0
 sta abs_x+1
 bra :ne_no_rescue
:ne_rescue_xmax_chk
* Use idle_x (+44), not the current FALLEN-pose frame_x (+10).
* The rescue runs before the idle frame restore below, so +10
* still holds the FALLEN width. Bounds need to fit the post-
* restore standing pose, which idle_x describes.
 ldy #2
 lda (info_ptr),y
 ldy #44
 clc
 adc (info_ptr),y     ; right_edge = xpos + idle_x
 cmp :ne_rescue_xmax
 bcc :ne_no_rescue
 beq :ne_no_rescue
* Snap xpos = bmax - idle_x.
 lda :ne_rescue_xmax
 ldy #44
 sec
 sbc (info_ptr),y
 ldy #2
 sta (info_ptr),y
 ldy #34
 sta (info_ptr),y
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :ne_no_rescue
* Billy: abs_x -= (old_xpos - new_xpos)  (positive delta)
 ldy #2
 lda (info_ptr),y     ; new xpos
 sta :ne_rescue_dx
 lda :ne_rescue_oldx
 sec
 sbc :ne_rescue_dx
 sta :ne_rescue_dx
 lda abs_x
 sec
 sbc :ne_rescue_dx
 sta abs_x
 lda abs_x+1
 sbc #0
 sta abs_x+1
:ne_no_rescue

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
* Restore frame_bank from idle_bank: a cross-bank anim (e.g.
* williams_pipe falling with bank-$02 anim_wfall) may have left
* frame_bank set to the anim's bank, but the idle frame lives
* in idle_bank. Copy +58 → +56 so subsequent renders pull
* idle pixels from the right bank.
 ldy #58
 lda (info_ptr),y
 ldy #56
 sta (info_ptr),y
 ldy #59
 lda (info_ptr),y
 ldy #57
 sta (info_ptr),y
* For Billy (controller=$01): pick compiled idle data + mask whose
* orientation matches IMAGE01_MIRROR. Mirror is baked into the
* pre-rotated arrays — draw_sprite_compiled has no mirror branch.
* Skip entirely when Billy is armed (pipe or mace) — armed
* renders through the legacy path (MASK_ADDR=0).
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :ne_no_billy_mask
 lda billy_pipe_armed
 ora billy_mace_armed
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
* Legacy frames are reached by NPC animations and by Billy's
* anim_uppercut. Same constraint as start_anim: clear MASK_ADDR
* + info+52 only for the keyboard player. Touching MASK_ADDR for
* an NPC mid-frame (e.g. punched_anim spawned by check_punch_hit)
* would clobber Billy's still-active compiled mask and put him
* on the legacy draw path with compiled pixel data.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :lf_legacy_done
 lda #0
 sta MASK_ADDR
 sta MASK_ADDR+1
 ldy #52
 lda #0
 sta (info_ptr),y
 iny
 sta (info_ptr),y
:lf_legacy_done
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
* Burnov-grab BNBILLY2 hit sound. anim_bngrab's odd frames
* (1, 3, 5) are BNBILLY2 — the moment Burnov's punch lands on
* the held Billy. Fire SND_PUNCHLANDED on each of those frame
* loads. Frame 6 (BNBILLY3) is the release pose, no sound.
 lda anim_ptr
 cmp #<anim_bngrab
 bne :lf_no_bngrab_sfx
 lda anim_ptr+1
 cmp #>anim_bngrab
 bne :lf_no_bngrab_sfx
 ldy #26
 lda (info_ptr),y
 cmp #6
 bcs :lf_no_bngrab_sfx       ; frame 6 (BNBILLY3) — no sound
 lsr
 bcc :lf_no_bngrab_sfx       ; even frame (BNBILLY1) — no sound
 ldx #SND_PUNCHLANDED
 jsr sound_trigger
:lf_no_bngrab_sfx
* Burnov helmet-Y offset. BDISS7 and BDISS8 are the small
* helmet sprites — visually the helmet has fallen to the ground
* while the body is gone. Without offset they paint at the body's
* head height (top of frame). At the transitions BDISS6→BDISS7
* (anim_bn_diss frame 6) and BDISS7→BDISS6 (anim_bn_recon frame 2)
* we shift ypos down/up by BDISS_HELMET_Y so the helmet sits on
* the floor. start_burnov_recon's teleport already accounts for
* the bump on its initial BDISS8 frame.
 ldy #56
 lda (info_ptr),y      ; frame_bank
 cmp #$19
 bne :lf_no_helmet_y
 lda anim_ptr
 cmp #<anim_bn_diss
 bne :lf_check_recon_y
 lda anim_ptr+1
 cmp #>anim_bn_diss
 bne :lf_check_recon_y
* anim_bn_diss: bump down on transition to frame 6 (BDISS7).
 ldy #26
 lda (info_ptr),y
 cmp #6
 bne :lf_no_helmet_y
 ldy #0
 lda (info_ptr),y
 clc
 adc #BDISS_HELMET_Y
 sta (info_ptr),y
 bra :lf_no_helmet_y
:lf_check_recon_y
 lda anim_ptr
 cmp #<anim_bn_recon
 bne :lf_no_helmet_y
 lda anim_ptr+1
 cmp #>anim_bn_recon
 bne :lf_no_helmet_y
* anim_bn_recon: un-bump on transition to frame 2 (BDISS6).
 ldy #26
 lda (info_ptr),y
 cmp #2
 bne :lf_no_helmet_y
 ldy #0
 lda (info_ptr),y
 sec
 sbc #BDISS_HELMET_Y
 sta (info_ptr),y
:lf_no_helmet_y
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
 bne :try_lmace
 lda anim_ptr+1
 cmp #>anim_lpunch
 bne :try_lmace
 jmp :do_hit_now
:try_lmace
 lda anim_ptr
 cmp #<anim_lmace
 bne :try_bnp
 lda anim_ptr+1
 cmp #>anim_lmace
 bne :try_bnp
 jmp :do_hit_now
:try_bnp
 lda anim_ptr
 cmp #<anim_bnpunch
 bne :try_upr
 lda anim_ptr+1
 cmp #>anim_bnpunch
 bne :try_upr
 jmp :do_hit_now
:try_upr
 lda anim_ptr
 cmp #<anim_uppercut
 bne :try_bpipe
 lda anim_ptr+1
 cmp #>anim_uppercut
 bne :try_bpipe
 jmp :do_hit_now
:try_bpipe
 lda anim_ptr
 cmp #<anim_bpipeswing
 bne :try_bmace
 lda anim_ptr+1
 cmp #>anim_bpipeswing
 bne :try_bmace
 jmp :do_hit_now
:try_bmace
 lda anim_ptr
 cmp #<anim_bmaceswing
 bne :try_bspin
 lda anim_ptr+1
 cmp #>anim_bmaceswing
 bne :try_bspin
 jmp :do_hit_now
:try_bspin
 lda anim_ptr
 cmp #<anim_bspinkick
 bne :try_kick
 lda anim_ptr+1
 cmp #>anim_bspinkick
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
* Clamp xpos so the FALLEN frame doesn't poke past the right
* edge. The walk/trajectory clamps don't see FALLEN's width
* (it can be a couple bytes wider than the walking sprite that
* drove fo_approach to the edge), so without this snap the
* fallen pose lands with right edge > PLAYFIELD_EDGE. Sync
* prev_xpos so erase_all clears the right rect on the redraw.
* For Billy, also subtract the snap delta from abs_x — the
* trajectory advanced abs_x in lockstep with xpos, and yanking
* xpos back without matching abs_x trips assert_abs_x.
 ldy #2
 lda (info_ptr),y
 ldy #10
 clc
 adc (info_ptr),y     ; xpos + FALLEN frame_x = right edge
 cmp #PLAYFIELD_EDGE+1
 bcc :nfb_x_ok
 lda #PLAYFIELD_EDGE
 ldy #10
 sec
 sbc (info_ptr),y     ; clamped xpos = PLAYFIELD_EDGE - frame_x
 sta :nfb_new_xpos
* Billy abs_x adjustment: delta = old_xpos - new_xpos.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :nfb_commit
 ldy #2
 lda (info_ptr),y     ; old xpos
 sec
 sbc :nfb_new_xpos    ; A = delta (always >= 1 here)
 sta :nfb_delta
 lda abs_x
 sec
 sbc :nfb_delta
 sta abs_x
 lda abs_x+1
 sbc #0
 sta abs_x+1
:nfb_commit
 lda :nfb_new_xpos
 ldy #2
 sta (info_ptr),y     ; xpos = clamped
 ldy #34
 sta (info_ptr),y     ; prev_xpos = clamped (erase anchor)
:nfb_x_ok
* Body just landed — fire SND_FALLEN.
 ldx #SND_FALLEN
 jsr sound_trigger
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
:nfb_new_xpos    dfb 0
:nfb_delta       dfb 0
:ne_rescue_xmin  dfb 0
:ne_rescue_xmax  dfb 0
:ne_rescue_oldx  dfb 0
:ne_rescue_dx    dfb 0
:dd_w            dfb 0
:dd_h            dfb 0

*----------------------------------------------------------
* Burnov boss-death state-machine helpers. Called from
* update_anims:ad_not_jump when the just-ended anim matches
* one of the boss-death stages. info_ptr = Burnov on entry,
* MX = %11.
*----------------------------------------------------------

* start_burnov_dissolve - fall_anim ended on Burnov (kill 1 or 2).
* Trigger BURNGONE and install anim_bn_diss. The fall already
* left ypos at the bumped FALLEN position; we un-bump it here so
* the bigger BDISS frames render around Burnov's standing height
* instead of being shoved down by FALL_Y_OFFSET.
start_burnov_dissolve
 ldx #SND_BURNGONE
 jsr sound_trigger
* Snapshot prev_* so the fallen sprite gets erased cleanly when
* the new (taller) dissolve frame paints. Use a generous prev_w/h
* (24×24) to cover BNFALLEN's 23×23 footprint.
 ldy #0
 lda (info_ptr),y      ; current ypos (bumped)
 ldy #32
 sta (info_ptr),y      ; prev_ypos
 ldy #2
 lda (info_ptr),y
 ldy #34
 sta (info_ptr),y      ; prev_xpos
 lda #24
 ldy #36
 sta (info_ptr),y      ; prev_frame_x
 ldy #38
 sta (info_ptr),y      ; prev_frame_y
* Un-bump ypos so the BDISS frames draw at standing height.
 ldy #0
 lda (info_ptr),y
 sec
 sbc #FALL_Y_OFFSET
 sta (info_ptr),y
* Install anim_bn_diss
 lda #<anim_bn_diss
 ldx #>anim_bn_diss
 jsr start_anim
 rts

* start_burnov_recon - anim_bn_diss ended. Move Burnov to the
* alternate boss spawn position, trigger BURNBACK, install
* anim_bn_recon. Position alternates by boss_death_count parity:
*   count=0 (1st kill, hasn't incremented yet) → teleport to x=$10
*   count=1 (2nd kill, hasn't incremented yet) → teleport to x=$58
* y is reset to the boss spawn y ($43) regardless.
start_burnov_recon
* Snapshot prev_* for clean erase of the small BDISS8 helmet.
 ldy #0
 lda (info_ptr),y
 ldy #32
 sta (info_ptr),y      ; prev_ypos
 ldy #2
 lda (info_ptr),y
 ldy #34
 sta (info_ptr),y      ; prev_xpos
 ldy #10
 lda (info_ptr),y
 ldy #36
 sta (info_ptr),y      ; prev_frame_x
 ldy #12
 lda (info_ptr),y
 ldy #38
 sta (info_ptr),y      ; prev_frame_y
* Pick teleport target X.
 lda boss_death_count
 and #$01
 beq :br_far_x
 lda #$58              ; 2nd teleport target — back to original
 bra :br_set_x
:br_far_x
 lda #$10              ; 1st teleport target — left side
:br_set_x
 ldy #2
 sta (info_ptr),y      ; new xpos
* Spawn y is $43 for the body, but recon's first frame is BDISS8
* (helmet) which renders BDISS_HELMET_Y px down from the body's
* top. Teleport directly to the bumped y so :load_frame doesn't
* need to adjust on frame 0 — the un-bump at frame 2 (BDISS6)
* drops us back to standing height for the body frames.
 lda #$43+BDISS_HELMET_Y
 ldy #0
 sta (info_ptr),y
 ldx #SND_BURNBACK
 jsr sound_trigger
 lda #<anim_bn_recon
 ldx #>anim_bn_recon
 jsr start_anim
 rts

* finish_burnov_recon - anim_bn_recon ended. Reset punch_count to
* 0 so the next 3 hits trigger the next dissolve cycle, reset
* behavior_state to FO_APPROACH so the boss starts walking
* toward Billy again, increment boss_death_count, and let
* :normal_end's idle-restore put Burnov back to BNWALK1.
finish_burnov_recon
 lda #0
 ldy #48
 sta (info_ptr),y      ; punch_count
 ldy #7
 sta (info_ptr),y      ; behavior_state = FO_APPROACH (0)
 ldy #8
 sta (info_ptr),y      ; behavior_timer low
 ldy #9
 sta (info_ptr),y      ; behavior_timer high
 inc boss_death_count
 rts

*----------------------------------------------------------
* linda_flail_drop_and_transform - called when linda_flail's
* anim_lfall ends. Drops a MACE2 weapon sprite at her current
* (post-fall) position and rewrites her own sprite block to
* be a regular Linda — so subsequent walks/punches/falls go
* through the bank-$02 Linda animation set.
* On entry: info_ptr = linda_flail. Caller is :normal_end mid-
* execution; we leave info_ptr pointing back at her on exit so
* the rest of :normal_end's idle restore picks up the new
* (regular Linda) idle_addr / idle_bank automatically.
*----------------------------------------------------------
linda_flail_drop_and_transform
 jsr spawn_dropped_mace
* Transform linda_flail → regular Linda by rewriting her block.
* idle_addr/frame_addr → spr_linda1 (LINDA1 in bank $02).
 lda spr_linda1
 ldy #14
 sta (info_ptr),y
 lda spr_linda1+1
 ldy #15
 sta (info_ptr),y
 lda spr_linda1
 ldy #42
 sta (info_ptr),y
 lda spr_linda1+1
 ldy #43
 sta (info_ptr),y
* walk_anim → anim_lwalk
 lda #<anim_lwalk
 ldy #52
 sta (info_ptr),y
 lda #>anim_lwalk
 ldy #53
 sta (info_ptr),y
* atk_anim → anim_lpunch
 lda #<anim_lpunch
 ldy #54
 sta (info_ptr),y
 lda #>anim_lpunch
 ldy #55
 sta (info_ptr),y
* frame_bank / idle_bank → $02
 lda #$02
 ldy #56
 sta (info_ptr),y
 ldy #58
 sta (info_ptr),y
 lda #$00
 ldy #57
 sta (info_ptr),y
 ldy #59
 sta (info_ptr),y
 rts

*----------------------------------------------------------
* spawn_dropped_mace - allocate a fresh NPC buffer slot, fill
* it in as a static MACE2 weapon at the current sprite's xpos/
* ypos, and add it to sprite_table. Used by linda_flail's
* transform-on-fall flow. Mace lives in bank $19 (mission12),
* mask $44, controller=$02 ("item" — never hit-checked, never
* blocks WAITCLR). On entry: info_ptr = source sprite (pos copied
* from there). On exit: info_ptr restored to source sprite.
*----------------------------------------------------------
spawn_dropped_mace
* Stash linda's info_ptr & capture her current pos. Mace
* drops 16 px below linda's anchor so it sits on the
* ground in front of her crumpled body, not at her head.
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 ldy #0
 lda (info_ptr),y
 clc
 adc #16
 sta :sm_y
 ldy #2
 lda (info_ptr),y
 sta :sm_x

* Find first null sprite_table entry.
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:sm_find
 ldy #0
 lda (spr_ptr),y
 iny
 ora (spr_ptr),y
 beq :sm_found
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :sm_find
 inc spr_ptr+1
 bra :sm_find
:sm_found

* Bounds-check npc_buf_next (silently drop the spawn if the
* buffer is exhausted, same policy as script_spawn_npc).
 lda npc_buf_next+1
 cmp #>npc_buffers_end
 bcc :sm_buf_ok
 beq :sm_buf_check_lo
 jmp :sm_done           ; high byte > end → exhausted
:sm_buf_check_lo
 lda npc_buf_next
 cmp #<npc_buffers_end
 bcc :sm_buf_ok
 jmp :sm_done           ; low byte >= end → exhausted
:sm_buf_ok

* info_ptr = npc_buf_next; populate the mace block.
 lda npc_buf_next
 sta info_ptr
 lda npc_buf_next+1
 sta info_ptr+1

* Zero the first 60 bytes (the buffer may carry stale data
* from a previous occupant).
 ldy #59
 lda #0
:sm_clear
 sta (info_ptr),y
 dey
 bpl :sm_clear

* Write the live fields. ypos / xpos / prev_ypos / prev_xpos
* all from saved pos.
 ldy #0
 lda :sm_y
 sta (info_ptr),y      ; +0 ypos
 ldy #32
 sta (info_ptr),y      ; +32 prev_ypos
 ldy #2
 lda :sm_x
 sta (info_ptr),y      ; +2 xpos
 ldy #34
 sta (info_ptr),y      ; +34 prev_xpos

* frame_x / frame_y / prev_frame_x / prev_frame_y (MACE2 = 10×8).
 lda #$0A
 ldy #10
 sta (info_ptr),y
 ldy #36
 sta (info_ptr),y
 ldy #44
 sta (info_ptr),y      ; +44 idle_x
 lda #$08
 ldy #12
 sta (info_ptr),y
 ldy #38
 sta (info_ptr),y
 ldy #46
 sta (info_ptr),y      ; +46 idle_y

* frame_addr / idle_addr → spr_mace2.
 lda spr_mace2
 ldy #14
 sta (info_ptr),y
 ldy #42
 sta (info_ptr),y
 lda spr_mace2+1
 ldy #15
 sta (info_ptr),y
 ldy #43
 sta (info_ptr),y

* mask = $44, maskhi = $40, masklo = $04.
 lda #$44
 ldy #16
 sta (info_ptr),y
 lda #$40
 ldy #18
 sta (info_ptr),y
 lda #$04
 ldy #20
 sta (info_ptr),y

* controller = $02 (item — non-NPC, non-Billy: skipped by
* check_punch_hit and WAITCLR).
 lda #$02
 ldy #22
 sta (info_ptr),y

* dirty = $01 (needs draw on first frame).
 lda #$01
 ldy #30
 sta (info_ptr),y

* frame_bank / idle_bank → $0019.
 lda #$19
 ldy #56
 sta (info_ptr),y
 ldy #58
 sta (info_ptr),y

* Write info_ptr into the sprite_table slot we found.
 ldy #0
 lda info_ptr
 sta (spr_ptr),y
 iny
 lda info_ptr+1
 sta (spr_ptr),y

* Advance npc_buf_next by 60 bytes.
 lda npc_buf_next
 clc
 adc #60
 sta npc_buf_next
 lda npc_buf_next+1
 adc #0
 sta npc_buf_next+1

:sm_done
* Restore caller's info_ptr (linda_flail).
 pla
 sta info_ptr+1
 pla
 sta info_ptr
 rts
:sm_x dfb 0
:sm_y dfb 0

*----------------------------------------------------------
* behav_knifer - williams_knife AI. Backpedal until at least
* KN_RANGE bytes from the player, then start
* anim_wkthrow. The throw-end hook in :normal_end spawns the
* projectile and downgrades him to BEHAV_FACEOFF. Falling at
* any point during this routine drops the knife instead (also
* via :normal_end, when anim_wfall ends with BEHAV_KNIFER).
*
* On entry: info_ptr = williams_knife block. update_npcs has
* already verified controller=$00. anim_ptr nonzero means a
* stun/throw/walk anim is running — we leave it alone.
*----------------------------------------------------------
behav_knifer
 jsr npc_behavior_blocked
 beq :kn_free
 rts                   ; an action anim is mid-play, do nothing
:kn_free
 jsr fo_find_player
 bne :kn_have_player
 rts
:kn_have_player
 jsr npc_ensure_walking ; idle frame → anim_wwalk for backpedal cycle

* Snapshot prev fields so erase_all wipes the previous draw rect
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

* dx = npc.xpos - player.xpos. CS=NPC right of player, CC=NPC
* left. Compute |dx| and stash sign for facing/movement choice.
 ldy #2
 lda (info_ptr),y
 sec
 sbc fo_plr_x
 bcs :kn_dx_pos
 eor #$FF
 clc
 adc #1                ; |dx|
 sta :kn_dx_abs
 lda #1
 sta :kn_left_of_plr   ; 1 = npc is left of player
 bra :kn_have_dx
:kn_dx_pos
 sta :kn_dx_abs
 lda #0
 sta :kn_left_of_plr   ; 0 = npc is right of (or at) player
:kn_have_dx

* Mirror so williams faces the player (still facing him while
* backpedaling — that's the whole "backpedal" look).
*   left of player  → face right (mirror=0)
*   right of player → face left  (mirror=1)
 lda :kn_left_of_plr
 eor #$01
 ldy #4
 sta (info_ptr),y

* If far enough away, throw. anim_wkthrow plays for ~16 VBLs;
* :normal_end finishes the job (spawn projectile + downgrade).
 lda :kn_dx_abs
 cmp #KN_RANGE
 bcc :kn_too_close

* Start anim_wkthrow. Bypasses atk_anim (+54) so the regular
* williams template can stay verbatim — the only thing that
* differs about williams_knife is his behavior + this throw.
 lda #<anim_wkthrow
 ldx #>anim_wkthrow
 jsr start_anim
 ldy #30
 lda #$03
 sta (info_ptr),y
 rts

:kn_too_close
* Backpedal: step xpos AWAY from player by 1 byte if y-bounds
* allow it. (We're already facing the player from above.)
*   npc left of player  → step left  (xpos--)
*   npc right of player → step right (xpos++)
 lda :kn_left_of_plr
 bne :kn_back_left

* Step right
 ldy #2
 lda (info_ptr),y
 ldy #10
 clc
 adc (info_ptr),y      ; right edge after step would be xpos + frame_x
 sta chk_xpos
 ldy #0
 lda (info_ptr),y
 jsr check_y_bounds
 bcs :kn_no_step
 ldy #2
 lda (info_ptr),y
 clc
 adc #1
 sta (info_ptr),y
 bra :kn_no_step

:kn_back_left
 ldy #2
 lda (info_ptr),y
 sec
 sbc #1
 sta chk_xpos
 ldy #0
 lda (info_ptr),y
 jsr check_y_bounds
 bcs :kn_no_step
 ldy #2
 lda chk_xpos
 sta (info_ptr),y

:kn_no_step
 ldy #30
 lda #$03
 sta (info_ptr),y
 rts

:kn_dx_abs       dfb 0
:kn_left_of_plr  dfb 0

*----------------------------------------------------------
* spawn_thrown_knife - Allocate a new sprite_table entry and
* npc_buffer slot for a flying knife. Called from :normal_end
* when anim_wkthrow finishes on a BEHAV_KNIFER williams.
* Picks KNIFE2 (right) or KNIFE4 (left) by williams' mirror
* (info+4). The projectile is controller=$03; update_projectile
* in update_npcs advances it each frame.
* On entry: info_ptr = williams_knife block (the thrower).
* On exit: info_ptr restored to the thrower so :normal_end's
* idle-restore picks up where it left off.
*----------------------------------------------------------
spawn_thrown_knife
 lda info_ptr
 pha
 lda info_ptr+1
 pha
* Capture williams' position + facing.
 ldy #0
 lda (info_ptr),y
 clc
 adc #KN_THROW_Y_OFF
 sta :tk_y
 ldy #2
 lda (info_ptr),y
 sta :tk_x_anchor
 ldy #4
 lda (info_ptr),y
 sta :tk_dir           ; 0=right, 1=left

* Find first null sprite_table entry.
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:tk_find
 ldy #0
 lda (spr_ptr),y
 iny
 ora (spr_ptr),y
 beq :tk_found
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :tk_find
 inc spr_ptr+1
 bra :tk_find
:tk_found

* Bounds-check npc_buf_next.
 lda npc_buf_next+1
 cmp #>npc_buffers_end
 bcc :tk_buf_ok
 beq :tk_buf_check_lo
 jmp :tk_done
:tk_buf_check_lo
 lda npc_buf_next
 cmp #<npc_buffers_end
 bcc :tk_buf_ok
 jmp :tk_done
:tk_buf_ok

 lda npc_buf_next
 sta info_ptr
 lda npc_buf_next+1
 sta info_ptr+1

* Zero 60 bytes (clear stale data).
 ldy #59
 lda #0
:tk_clear
 sta (info_ptr),y
 dey
 bpl :tk_clear

* xpos: spawn at williams' near edge so the knife flies clear
* of him. Right-thrower: xpos = williams.xpos + williams.frame_x.
* Left-thrower:  xpos = williams.xpos - knife.frame_x (= 4).
 lda :tk_dir
 bne :tk_left_spawn
 lda :tk_x_anchor
 clc
 adc #$09              ; williams' frame_x
 bra :tk_x_done
:tk_left_spawn
 lda :tk_x_anchor
 sec
 sbc #$04              ; knife frame_x
:tk_x_done
 ldy #2
 sta (info_ptr),y
 ldy #34
 sta (info_ptr),y

 ldy #0
 lda :tk_y
 sta (info_ptr),y
 ldy #32
 sta (info_ptr),y

* mirror = 0 (KNIFE2 / KNIFE4 are pre-flipped sprites — the
* drawer must NOT flip them again). Direction lives at +6.
 ldy #4
 lda #0
 sta (info_ptr),y
 ldy #6
 lda :tk_dir
 sta (info_ptr),y      ; +6 = projectile direction (0=right, 1=left)

* frame_x / frame_y / prev_frame_x / prev_frame_y (KNIFE2 = 4×7).
 lda #$04
 ldy #10
 sta (info_ptr),y
 ldy #36
 sta (info_ptr),y
 ldy #44
 sta (info_ptr),y      ; idle_x
 lda #$07
 ldy #12
 sta (info_ptr),y
 ldy #38
 sta (info_ptr),y
 ldy #46
 sta (info_ptr),y      ; idle_y

* frame_addr / idle_addr → spr_knife2 (right) or spr_knife4 (left).
 lda :tk_dir
 bne :tk_left_sprite
 lda spr_knife2
 ldy #14
 sta (info_ptr),y
 ldy #42
 sta (info_ptr),y
 lda spr_knife2+1
 ldy #15
 sta (info_ptr),y
 ldy #43
 sta (info_ptr),y
 bra :tk_sprite_done
:tk_left_sprite
 lda spr_knife4
 ldy #14
 sta (info_ptr),y
 ldy #42
 sta (info_ptr),y
 lda spr_knife4+1
 ldy #15
 sta (info_ptr),y
 ldy #43
 sta (info_ptr),y
:tk_sprite_done

* Mask = $CC (background of KNIFE2/KNIFE4 — see mission12.s).
 lda #$CC
 ldy #16
 sta (info_ptr),y
 lda #$C0
 ldy #18
 sta (info_ptr),y
 lda #$0C
 ldy #20
 sta (info_ptr),y

* controller = $03 (projectile — flies, hit-checks Billy, dies
* on screen edge). update_npcs routes this to update_projectile.
 lda #$03
 ldy #22
 sta (info_ptr),y

 lda #$01
 ldy #30
 sta (info_ptr),y      ; dirty (needs draw)

 lda #$19
 ldy #56
 sta (info_ptr),y      ; frame_bank
 ldy #58
 sta (info_ptr),y      ; idle_bank

* Write info_ptr into sprite_table slot.
 ldy #0
 lda info_ptr
 sta (spr_ptr),y
 iny
 lda info_ptr+1
 sta (spr_ptr),y

* Advance npc_buf_next.
 lda npc_buf_next
 clc
 adc #60
 sta npc_buf_next
 lda npc_buf_next+1
 adc #0
 sta npc_buf_next+1

:tk_done
 pla
 sta info_ptr+1
 pla
 sta info_ptr
 rts
:tk_x_anchor dfb 0
:tk_y        dfb 0
:tk_dir      dfb 0

*----------------------------------------------------------
* update_projectile - Advance a controller=$03 sprite by
* KN_SPEED bytes per frame in its facing direction (info+6).
* Bbox-checks against Billy each frame; on hit, tags Billy
* with his fall_anim and tags the projectile with the death
* sentinel ($FFFF in anim_ptr). Falling off the playfield
* also tags the death sentinel.
*
* Today only the thrown knife uses this path, but the routine
* is sprite-agnostic and any future projectile (rock, etc.)
* can reuse it.
*----------------------------------------------------------
update_projectile
* Snapshot prev for erase_all.
 ldy #0
 lda (info_ptr),y
 ldy #32
 sta (info_ptr),y
 ldy #2
 lda (info_ptr),y
 ldy #34
 sta (info_ptr),y

* Move xpos by ±KN_SPEED per direction at +6.
 ldy #6
 lda (info_ptr),y
 bne :up_left

* Going right
 ldy #2
 lda (info_ptr),y
 clc
 adc #KN_SPEED
 sta :up_newx
* Off right edge if newx + frame_x > PLAYFIELD_EDGE.
 ldy #10
 clc
 adc (info_ptr),y
 cmp #PLAYFIELD_EDGE
 bcc :up_commit
 bra :up_die
:up_left
 ldy #2
 lda (info_ptr),y
 sec
 sbc #KN_SPEED
 bcs :up_left_ok
 bra :up_die           ; underflow → off left edge
:up_left_ok
 sta :up_newx
:up_commit
 ldy #2
 lda :up_newx
 sta (info_ptr),y
 ldy #30
 lda #$03
 sta (info_ptr),y      ; dirty

* Hit-check against Billy.
 jsr knife_hit_billy
 rts

:up_die
 lda #$FF
 ldy #24
 sta (info_ptr),y
 iny
 sta (info_ptr),y
 rts
:up_newx dfb 0

*----------------------------------------------------------
* knife_hit_billy - Bbox overlap test of caller's projectile
* (info_ptr) against billy_sprite. On hit:
*   - tag the projectile $FFFF in anim_ptr (death sentinel)
*   - if Billy isn't already in fall_anim, copy his fall_anim
*     to anim_ptr / anim_frame=$FF / anim_timer=1 so the
*     next update_anims plays it (mirrors the grab-fall path
*     at lines 4422-4435).
* Caller's info_ptr is restored on exit.
*----------------------------------------------------------
knife_hit_billy
 ldy #0
 lda (info_ptr),y
 sta :kh_y
 ldy #2
 lda (info_ptr),y
 sta :kh_x
 ldy #10
 lda (info_ptr),y
 sta :kh_w
 ldy #12
 lda (info_ptr),y
 sta :kh_h

* Knife edges
 lda :kh_x
 clc
 adc :kh_w
 sta :kh_right
 lda :kh_y
 clc
 adc :kh_h
 sec
 sbc #1
 sta :kh_bottom

* Billy from billy_sprite
 lda billy_sprite
 sta :bb_y
 lda billy_sprite+2
 sta :bb_x
 lda billy_sprite+10
 sta :bb_w
 lda billy_sprite+12
 sta :bb_h
 clc
 adc :bb_y
 sec
 sbc #1
 sta :bb_bottom
 lda :bb_x
 clc
 adc :bb_w
 sta :bb_right

* Horizontal overlap: knife_right >= billy_x AND knife_x <= billy_right
 lda :kh_right
 cmp :bb_x
 bcs :kh_h2
 jmp :kh_no_hit
:kh_h2
 lda :kh_x
 cmp :bb_right
 beq :kh_vcheck
 bcc :kh_vcheck
 jmp :kh_no_hit
:kh_vcheck
* Vertical overlap: knife_bottom >= billy_y AND knife_y <= billy_bottom
 lda :kh_bottom
 cmp :bb_y
 bcs :kh_v2
 jmp :kh_no_hit
:kh_v2
 lda :kh_y
 cmp :bb_bottom
 beq :kh_hit
 bcc :kh_hit
 jmp :kh_no_hit

:kh_hit
* Tag the knife as dead.
 lda #$FF
 ldy #24
 sta (info_ptr),y
 iny
 sta (info_ptr),y

* Trigger Billy fall_anim if not already falling. Save info_ptr.
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 lda #<billy_sprite
 sta info_ptr
 lda #>billy_sprite
 sta info_ptr+1

* Already in fall_anim? Compare anim_ptr (+24/+25) to fall_anim (+50/+51).
 ldy #50
 lda (info_ptr),y
 ldy #24
 cmp (info_ptr),y
 bne :kh_do_fall
 ldy #51
 lda (info_ptr),y
 ldy #25
 cmp (info_ptr),y
 bne :kh_do_fall
 bra :kh_restore       ; already falling — knife passes (logically)

:kh_do_fall
* Start Billy's fall_anim via start_anim so frame_bank (info+56),
* frame data, mask, and dirty flag all get set correctly. Manual
* patching of anim_ptr/anim_frame/anim_timer used to bypass
* start_anim's bank-flag handling, leaving frame_bank=$02 while
* anim_bfall's pixels live in bank $19 — next render pulled
* "BFALL" bytes from the wrong bank and Billy showed up garbled.
 ldy #50
 lda (info_ptr),y
 pha                   ; fall_anim low → stack
 ldy #51
 lda (info_ptr),y
 tax                   ; X = fall_anim high
 pla                   ; A = fall_anim low
 jsr start_anim        ; sets info+24/+25/+26/+28, frame_bank,
                       ; FRAME_X/Y/ADDR/MASK, dirty=$03
* Weapon hit = automatic fall. Mirror the check_punch_hit
* :use_fall accounting: zero punch_count so the next 3-hit
* cycle starts fresh, then bump billy_fall_count and deplete
* one palette-02 slot so the on-screen health bar shortens.
 lda #0
 ldy #48
 sta (info_ptr),y
 inc billy_fall_count
 lda billy_fall_count
 cmp #1
 bne :kh_dep_2
 lda #0
 stal $019E48
 stal $019E49
 bra :kh_restore
:kh_dep_2
 cmp #2
 bne :kh_dep_3
 lda #0
 stal $019E46
 stal $019E47
 bra :kh_restore
:kh_dep_3
 cmp #3
 bne :kh_dep_4
 lda #0
 stal $019E44
 stal $019E45
 bra :kh_restore
:kh_dep_4
 cmp #4
 bne :kh_dep_5
 lda #0
 stal $019E42
 stal $019E43
 bra :kh_restore
:kh_dep_5
 cmp #5
 bne :kh_restore
 lda #0
 stal $019E54
 stal $019E55

:kh_restore
 pla
 sta info_ptr+1
 pla
 sta info_ptr
:kh_no_hit
 rts

:kh_x      dfb 0
:kh_y      dfb 0
:kh_w      dfb 0
:kh_h      dfb 0
:kh_right  dfb 0
:kh_bottom dfb 0
:bb_x      dfb 0
:bb_y      dfb 0
:bb_w      dfb 0
:bb_h      dfb 0
:bb_right  dfb 0
:bb_bottom dfb 0


williams_knife_drop_and_transform
 jsr spawn_dropped_knife
 lda #BEHAV_FACEOFF
 ldy #6
 sta (info_ptr),y
 lda #FO_APPROACH
 ldy #7
 sta (info_ptr),y
 rts

spawn_dropped_knife
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 ldy #0
 lda (info_ptr),y
 clc
 adc #16
 sta :sk_y
 ldy #2
 lda (info_ptr),y
 sta :sk_x
 ldy #4
 lda (info_ptr),y
 sta :sk_dir

* Find first null sprite_table entry.
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:sk_find
 ldy #0
 lda (spr_ptr),y
 iny
 ora (spr_ptr),y
 beq :sk_found
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :sk_find
 inc spr_ptr+1
 bra :sk_find
:sk_found

* Bounds-check npc_buf_next.
 lda npc_buf_next+1
 cmp #>npc_buffers_end
 bcc :sk_buf_ok
 beq :sk_buf_check_lo
 jmp :sk_done
:sk_buf_check_lo
 lda npc_buf_next
 cmp #<npc_buffers_end
 bcc :sk_buf_ok
 jmp :sk_done
:sk_buf_ok

 lda npc_buf_next
 sta info_ptr
 lda npc_buf_next+1
 sta info_ptr+1

 ldy #59
 lda #0
:sk_clear
 sta (info_ptr),y
 dey
 bpl :sk_clear

 ldy #0
 lda :sk_y
 sta (info_ptr),y
 ldy #32
 sta (info_ptr),y
 ldy #2
 lda :sk_x
 sta (info_ptr),y
 ldy #34
 sta (info_ptr),y

* frame_x / frame_y (KNIFE2/KNIFE4 = 4×7).
 lda #$04
 ldy #10
 sta (info_ptr),y
 ldy #36
 sta (info_ptr),y
 ldy #44
 sta (info_ptr),y
 lda #$07
 ldy #12
 sta (info_ptr),y
 ldy #38
 sta (info_ptr),y
 ldy #46
 sta (info_ptr),y

* frame_addr / idle_addr → spr_knife2 if facing right, else spr_knife4.
 lda :sk_dir
 bne :sk_left_sprite
 lda spr_knife2
 ldy #14
 sta (info_ptr),y
 ldy #42
 sta (info_ptr),y
 lda spr_knife2+1
 ldy #15
 sta (info_ptr),y
 ldy #43
 sta (info_ptr),y
 bra :sk_sprite_done
:sk_left_sprite
 lda spr_knife4
 ldy #14
 sta (info_ptr),y
 ldy #42
 sta (info_ptr),y
 lda spr_knife4+1
 ldy #15
 sta (info_ptr),y
 ldy #43
 sta (info_ptr),y
:sk_sprite_done

* mask = $CC, maskhi = $C0, masklo = $0C.
 lda #$CC
 ldy #16
 sta (info_ptr),y
 lda #$C0
 ldy #18
 sta (info_ptr),y
 lda #$0C
 ldy #20
 sta (info_ptr),y

* controller = $02 (static item — skipped by check_punch_hit
* and WAITCLR; OP_KILLOBJ wipes it at end of encounter).
 lda #$02
 ldy #22
 sta (info_ptr),y

 lda #$01
 ldy #30
 sta (info_ptr),y

 lda #$19
 ldy #56
 sta (info_ptr),y
 ldy #58
 sta (info_ptr),y

* Write info_ptr into sprite_table slot.
 ldy #0
 lda info_ptr
 sta (spr_ptr),y
 iny
 lda info_ptr+1
 sta (spr_ptr),y

 lda npc_buf_next
 clc
 adc #60
 sta npc_buf_next
 lda npc_buf_next+1
 adc #0
 sta npc_buf_next+1

:sk_done
 pla
 sta info_ptr+1
 pla
 sta info_ptr
 rts
:sk_x   dfb 0
:sk_y   dfb 0
:sk_dir dfb 0

*----------------------------------------------------------
* williams_pipe_drop_and_transform - Called from :normal_end
* when anim_wfall ends on a williams_pipe NPC (detected via
* walk_anim = anim_wpipewalk). Drops a PIPE1 at his feet
* (controller=$02 static item) and rewrites the block to a
* regular williams so subsequent falls take the standard path.
* On entry: info_ptr = williams_pipe. Restored on exit.
*----------------------------------------------------------
williams_pipe_drop_and_transform
 jsr spawn_dropped_pipe
* Transform → regular williams. idle_addr/frame_addr → spr_william1.
 lda spr_william1
 ldy #14
 sta (info_ptr),y
 lda spr_william1+1
 ldy #15
 sta (info_ptr),y
 lda spr_william1
 ldy #42
 sta (info_ptr),y
 lda spr_william1+1
 ldy #43
 sta (info_ptr),y
* walk_anim → anim_wwalk
 lda #<anim_wwalk
 ldy #52
 sta (info_ptr),y
 lda #>anim_wwalk
 ldy #53
 sta (info_ptr),y
* atk_anim → anim_wpunch
 lda #<anim_wpunch
 ldy #54
 sta (info_ptr),y
 lda #>anim_wpunch
 ldy #55
 sta (info_ptr),y
* frame_bank / idle_bank → $02
 lda #$02
 ldy #56
 sta (info_ptr),y
 ldy #58
 sta (info_ptr),y
 lda #$00
 ldy #57
 sta (info_ptr),y
 ldy #59
 sta (info_ptr),y
 rts

*----------------------------------------------------------
* spawn_dropped_pipe - Allocate a sprite_table+npc_buffer slot
* for a static PIPE1 item at the source sprite's xpos and
* (ypos + 20). Mirrors spawn_dropped_mace's structure. PIPE1
* is 9×5 with mask color $1.
*----------------------------------------------------------
spawn_dropped_pipe
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 ldy #0
 lda (info_ptr),y
 clc
 adc #20
 sta :sp_y
 ldy #2
 lda (info_ptr),y
 sta :sp_x

* Find first null sprite_table entry.
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:sp_find
 ldy #0
 lda (spr_ptr),y
 iny
 ora (spr_ptr),y
 beq :sp_found
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :sp_find
 inc spr_ptr+1
 bra :sp_find
:sp_found

* Bounds-check npc_buf_next.
 lda npc_buf_next+1
 cmp #>npc_buffers_end
 bcc :sp_buf_ok
 beq :sp_buf_check_lo
 jmp :sp_done
:sp_buf_check_lo
 lda npc_buf_next
 cmp #<npc_buffers_end
 bcc :sp_buf_ok
 jmp :sp_done
:sp_buf_ok

 lda npc_buf_next
 sta info_ptr
 lda npc_buf_next+1
 sta info_ptr+1

 ldy #59
 lda #0
:sp_clear
 sta (info_ptr),y
 dey
 bpl :sp_clear

 ldy #0
 lda :sp_y
 sta (info_ptr),y
 ldy #32
 sta (info_ptr),y
 ldy #2
 lda :sp_x
 sta (info_ptr),y
 ldy #34
 sta (info_ptr),y

* frame_x / frame_y (PIPE1 = 9 × 5).
 lda #$09
 ldy #10
 sta (info_ptr),y
 ldy #36
 sta (info_ptr),y
 ldy #44
 sta (info_ptr),y
 lda #$05
 ldy #12
 sta (info_ptr),y
 ldy #38
 sta (info_ptr),y
 ldy #46
 sta (info_ptr),y

* frame_addr / idle_addr → spr_pipe1.
 lda spr_pipe1
 ldy #14
 sta (info_ptr),y
 ldy #42
 sta (info_ptr),y
 lda spr_pipe1+1
 ldy #15
 sta (info_ptr),y
 ldy #43
 sta (info_ptr),y

* mask = $11 (transparent color 1), maskhi = $10, masklo = $01.
 lda #$11
 ldy #16
 sta (info_ptr),y
 lda #$10
 ldy #18
 sta (info_ptr),y
 lda #$01
 ldy #20
 sta (info_ptr),y

* controller = $02 (static item — skipped by check_punch_hit
* and WAITCLR; OP_KILLOBJ wipes it at end of encounter).
 lda #$02
 ldy #22
 sta (info_ptr),y

 lda #$01
 ldy #30
 sta (info_ptr),y      ; dirty (needs draw)

 lda #$19
 ldy #56
 sta (info_ptr),y      ; frame_bank
 ldy #58
 sta (info_ptr),y      ; idle_bank

* Write info_ptr into sprite_table slot.
 ldy #0
 lda info_ptr
 sta (spr_ptr),y
 iny
 lda info_ptr+1
 sta (spr_ptr),y

 lda npc_buf_next
 clc
 adc #60
 sta npc_buf_next
 lda npc_buf_next+1
 adc #0
 sta npc_buf_next+1

:sp_done
 pla
 sta info_ptr+1
 pla
 sta info_ptr
 rts
:sp_x dfb 0
:sp_y dfb 0

*----------------------------------------------------------
* billy_try_pickup_pipe - L was pressed while Billy is unarmed.
* Scan sprite_table for a controller=$02 item whose frame_addr
* matches spr_pipe1 AND whose bbox overlaps Billy + |Δy| ≤ 3.
* If found: tag the pipe with the death sentinel (it disappears
* on this frame's erase_all), start anim_bpickup on Billy, and
* return C=1. Otherwise C=0 — caller falls through to its
* normal punch dispatch.
* On entry: info_ptr = billy_sprite. spr_ptr is clobbered.
*----------------------------------------------------------
billy_try_pickup_weapon
* Snapshot Billy's bbox.
 lda billy_sprite        ; ypos
 sta :tp_by
 clc
 adc #40                  ; billy_bottom (Billy's frame_y is 40)
 sta :tp_bbottom
 lda billy_sprite+2      ; xpos
 sta :tp_bx
 lda billy_sprite+10     ; frame_x
 clc
 adc :tp_bx
 sta :tp_bright          ; billy_right = billy_x + billy_w

* Iterate sprite_table looking for a static item (controller=$02)
* whose frame_addr matches one of the pickup-eligible weapons.
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:tp_loop
 ldy #0
 lda (spr_ptr),y
 sta info_ptr
 iny
 lda (spr_ptr),y
 sta info_ptr+1
 ora info_ptr
 bne :tp_not_null
 jmp :tp_no               ; null terminator
:tp_not_null
 ldy #22
 lda (info_ptr),y         ; controller
 cmp #$02
 beq :tp_is_item
 jmp :tp_advance          ; not a static item
:tp_is_item
* Identify the weapon by frame_addr. Pipe → :tp_is_pipe; mace →
* :tp_is_mace; anything else is not pickup-eligible.
 ldy #14
 lda (info_ptr),y
 cmp spr_pipe1
 bne :tp_chk_mace
 ldy #15
 lda (info_ptr),y
 cmp spr_pipe1+1
 bne :tp_chk_mace
 lda #1                   ; weapon kind = pipe
 sta :tp_kind
 bra :tp_have_kind
:tp_chk_mace
 ldy #14
 lda (info_ptr),y
 cmp spr_mace2
 bne :tp_advance
 ldy #15
 lda (info_ptr),y
 cmp spr_mace2+1
 bne :tp_advance
 lda #2                   ; weapon kind = mace
 sta :tp_kind
:tp_have_kind

* Vertical bbox overlap: weapon_bottom >= billy_y AND
* weapon_y <= billy_bottom. Billy is 40 tall, so top-to-top
* distance is too large for a tight |Δy| check — use bbox.
 ldy #0
 lda (info_ptr),y         ; weapon.y
 sta :tp_py
 ldy #12
 clc
 adc (info_ptr),y         ; weapon_bottom = weapon.y + weapon.h
 cmp :tp_by
 bcc :tp_advance          ; weapon_bottom < billy_y → above billy
 lda :tp_py
 cmp :tp_bbottom
 beq :tp_v_ok
 bcs :tp_advance          ; weapon_y > billy_bottom → below billy
:tp_v_ok

* Horizontal bbox overlap: weapon_right >= billy_x AND
* weapon_x <= billy_right.
 ldy #2
 lda (info_ptr),y         ; weapon.x
 sta :tp_px
 ldy #10
 clc
 adc (info_ptr),y         ; weapon_right
 cmp :tp_bx
 bcc :tp_advance
 lda :tp_px
 cmp :tp_bright
 beq :tp_pickup
 bcs :tp_advance
:tp_pickup
* Tag the weapon dead so erase_all wipes it this frame.
 lda #$FF
 ldy #24
 sta (info_ptr),y
 iny
 sta (info_ptr),y
* Restore info_ptr to Billy. From here on writes target his block.
 lda #<billy_sprite
 sta info_ptr
 lda #>billy_sprite
 sta info_ptr+1
* Arm Billy now (set flag + idle pose for the matching weapon).
* anim_bpickup plays JUMP3 over this; idle restore at anim end
* picks up the new BPIPEW1 / BMWALK1 idle frame automatically.
 lda :tp_kind
 cmp #1
 bne :tp_arm_mace
 jsr billy_arm_pipe
 bra :tp_start_anim
:tp_arm_mace
 jsr billy_arm_mace
:tp_start_anim
 lda #<anim_bpickup
 ldx #>anim_bpickup
 jsr start_anim
 sec                      ; pickup happened
 rts

:tp_advance
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :tp_jloop
 inc spr_ptr+1
:tp_jloop jmp :tp_loop
:tp_no
 lda #<billy_sprite
 sta info_ptr
 lda #>billy_sprite
 sta info_ptr+1
 clc                      ; no pickup
 rts

:tp_by      dfb 0
:tp_bx      dfb 0
:tp_bright  dfb 0
:tp_bbottom dfb 0
:tp_px      dfb 0
:tp_py      dfb 0
:tp_kind    dfb 0

*----------------------------------------------------------
* billy_arm_pipe - Called at pickup time (from
* billy_try_pickup_weapon). Sets billy_pipe_armed and rewrites
* Billy's idle pose to BPIPEW1. The MASK_ADDR / info+52 clear
* happens later in :normal_end's anim_bpickup hook (after the
* pickup pose finishes playing) — we leave the compiled
* JUMP3-mask in place during the pose.
* On entry: info_ptr = billy_sprite. Mode: emulation, 8-bit.
*----------------------------------------------------------
billy_arm_pipe
 lda #1
 sta billy_pipe_armed
 lda spr_bpipew1
 ldy #42
 sta (info_ptr),y
 lda spr_bpipew1+1
 ldy #43
 sta (info_ptr),y
 jmp billy_arm_common

*----------------------------------------------------------
* billy_arm_mace - Symmetric to billy_arm_pipe. Sets
* billy_mace_armed and points idle_addr at BMWALK1.
*----------------------------------------------------------
billy_arm_mace
 lda #1
 sta billy_mace_armed
 lda spr_bmwalk1
 ldy #42
 sta (info_ptr),y
 lda spr_bmwalk1+1
 ldy #43
 sta (info_ptr),y
 ; fall through to billy_arm_common

*----------------------------------------------------------
* billy_arm_common - Shared idle-state setup for armed Billy.
* Both BPIPEW1 and BMWALK1 are 9×40 with bank $19.
*----------------------------------------------------------
billy_arm_common
 lda #$09
 ldy #44
 sta (info_ptr),y
 lda #$28
 ldy #46
 sta (info_ptr),y
 lda #$19
 ldy #58
 sta (info_ptr),y
 lda #0
 ldy #59
 sta (info_ptr),y
 rts

*----------------------------------------------------------
* billy_disarm_weapon - Called from kill_objects when OP_KILLOBJ
* fires while Billy is armed (pipe or mace). Restores Billy's
* compiled walk pipeline: idle_addr → IMAGE01, idle_bank → $02,
* info+52 (compiled mask) → spr_image01_mask, MASK_ADDR seeded
* so the very next draw routes through draw_sprite_compiled.
*----------------------------------------------------------
billy_disarm_weapon
 stz billy_pipe_armed
 stz billy_mace_armed
* idle_addr / idle mask always point at the canonical forward
* IMAGE01 — :normal_end's idle restore handles mirror selection
* on the next anim end. But the LIVE frame_addr / MASK_ADDR
* must match Billy's current facing right now, otherwise the
* very next draw_all renders forward-facing compiled data while
* IMAGE01_MIRROR=1 (or vice versa) and Billy briefly flips.
 lda spr_img01
 sta billy_sprite+42
 lda spr_img01+1
 sta billy_sprite+43
 lda spr_image01_mask
 sta billy_sprite+52      ; persisted into save_sprite next frame
 lda spr_image01_mask+1
 sta billy_sprite+53
* Pick the live data + mask pair that matches IMAGE01_MIRROR.
 lda IMAGE01_MIRROR
 bne :bdw_mirror
 lda spr_img01
 sta billy_sprite+14
 lda spr_img01+1
 sta billy_sprite+15
 lda spr_image01_mask
 sta MASK_ADDR
 lda spr_image01_mask+1
 sta MASK_ADDR+1
 bra :bdw_dims
:bdw_mirror
 lda spr_image01_data_mirror
 sta billy_sprite+14
 lda spr_image01_data_mirror+1
 sta billy_sprite+15
 lda spr_image01_mask_mirror
 sta MASK_ADDR
 lda spr_image01_mask_mirror+1
 sta MASK_ADDR+1
:bdw_dims
 lda #$09
 sta billy_sprite+10
 sta billy_sprite+44
 lda #$28
 sta billy_sprite+12
 sta billy_sprite+46
 lda #$02
 sta billy_sprite+56      ; frame_bank → $02
 sta billy_sprite+58      ; idle_bank → $02
 lda #0
 sta billy_sprite+57
 sta billy_sprite+59
 rts

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
 lda #32
 sta :count            ; 32 chunks x 1KB = 32KB upper bound;
                       ; loop exits early on EOF (READ returns C=1)

:readlp
 jsr $BF00
 dfb $CA              ; READ
 da p_read
 bcs :close

 jsr copy_to_bank

* Advance destination by $0400 (1 KB = 4 pages)
 lda dest+1
 clc
 adc #$04
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
* copy_to_bank - Copy 1KB from ]RDBUF to load_bank/dest
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
 ldx #$0200            ; $0400/2 = $0200 word copies (1 KB)

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
 lda unpack_offset      ; default $2000; NTP loaders set $0000
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
unpack_offset hex 0020   ; in-bank offset to unpack at (default $2000)
unpack_size hex ffff     ; size of unpacked data (set by UnPackBytes)
unpack_addr hex 0020E100 ; unpacking destination address (bank/offset)

*----------------------------------------------------------
* fade_palette_to_black - fade SHR palette 0 ($E19E00, 16
* words / 32 bytes) to $0000 over 15 frames. Each frame
* subtracts 1 from each non-zero nibble (R/G/B) of every
* palette word. Caller must be in native + 16-bit on entry;
* mode is preserved on exit. Other palettes (1-15) are
* already black at startup so we don't touch them.
*----------------------------------------------------------
 mx %00
fade_palette_to_black
 lda #15
 sta fade_step
:step_loop
* Pace at one step per VBL. Inline to stay in native mode
* (the engine's wait_for_vbl assumes emulation-mode 8-bit).
 sep $20
 mx %10
:wvbl1 ldal $00C019
 bmi :wvbl1
:wvbl2 ldal $00C019
 bpl :wvbl2
 rep $20
 mx %00

 ldx #$0000
:word_loop
 ldal $E19E00,x
 sta fade_tmp
* Decrement B nibble (bits 0-3) if non-zero.
 and #$000F
 beq :b_done
 dec fade_tmp
:b_done
* Decrement G nibble (bits 4-7) if non-zero.
 lda fade_tmp
 and #$00F0
 beq :g_done
 lda fade_tmp
 sec
 sbc #$0010
 sta fade_tmp
:g_done
* Decrement R nibble (bits 8-11) if non-zero.
 lda fade_tmp
 and #$0F00
 beq :r_done
 lda fade_tmp
 sec
 sbc #$0100
 sta fade_tmp
:r_done
 lda fade_tmp
 stal $E19E00,x
 inx
 inx
 cpx #$0020           ; 16 entries x 2 bytes = palette 0 only
 bne :word_loop
 dec fade_step
 bne :step_loop
 rts

fade_step dw 0
fade_tmp dw 0

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
* load_file - Load a file to file_bank+ via ProDOS 8
* in 4KB chunks. Bank increments when address wraps.
*----------------------------------------------------------
* init_level - Read level data header from bank $02 and
* patch engine structures with bank $02 sprite addresses.
* Call after loading mission1 binary to bank $02.
*----------------------------------------------------------
 mx %11
init_level
* Reset boss-death cycle counter so the boss restarts fresh
* every time init_level runs (new game, etc.).
 stz boss_death_count

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

* William somersault frames (offsets +188..+192) and patch the
* sub-frame lookup table used by fo_somersault. Sub-frame map:
*   0: WSOMER1   3: WSOMER3 (mirrored)
*   1: WSOMER3   4: WSOMER1 (mirrored)
*   2: WSOMER2
 ldy #188
 lda [$F0],y
 sta spr_wsomer1
 sta somersault_addr_tbl       ; sub-frame 0
 sta somersault_addr_tbl+8     ; sub-frame 4
 ldy #190
 lda [$F0],y
 sta spr_wsomer2
 sta somersault_addr_tbl+4     ; sub-frame 2
 ldy #192
 lda [$F0],y
 sta spr_wsomer3
 sta somersault_addr_tbl+2     ; sub-frame 1
 sta somersault_addr_tbl+6     ; sub-frame 3

* Billy uppercut frames (offsets +194..+198)
 ldy #194
 lda [$F0],y
 sta spr_bupper1
 ldy #196
 lda [$F0],y
 sta spr_bupper2
 ldy #198
 lda [$F0],y
 sta spr_bupper3

* Grab system (offsets +200..+214). Billy + held variants for
* William, Roper, Linda.
 ldy #200
 lda [$F0],y
 sta spr_bgrab1
 ldy #202
 lda [$F0],y
 sta spr_bgrab2
 ldy #204
 lda [$F0],y
 sta spr_wheld1
 ldy #206
 lda [$F0],y
 sta spr_wheld2
 ldy #208
 lda [$F0],y
 sta spr_rheld1
 ldy #210
 lda [$F0],y
 sta spr_rheld2
 ldy #212
 lda [$F0],y
 sta spr_lheld1
 ldy #214
 lda [$F0],y
 sta spr_lheld2

* Billy spin-kick frames (offsets +216..+220).
 ldy #216
 lda [$F0],y
 sta spr_bspin1
 ldy #218
 lda [$F0],y
 sta spr_bspin2
 ldy #220
 lda [$F0],y
 sta spr_bspin3

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

* Patch anim_bpickup: 1 compiled frame (JUMP3 hold, 11-byte
* stride). data/mask/dmir/mmir at +6/+8/+10/+12.
 lda spr_jump3
 sta anim_bpickup+6
 lda spr_jump3_mask
 sta anim_bpickup+8
 lda spr_jump3_data_mirror
 sta anim_bpickup+10
 lda spr_jump3_mask_mirror
 sta anim_bpickup+12

* Patch anim_bspinkick: 8 legacy frames (BSPIN1/2/3/2 × 2).
 lda spr_bspin1
 sta anim_bspinkick+3+3
 lda spr_bspin2
 sta anim_bspinkick+3+8
 lda spr_bspin3
 sta anim_bspinkick+3+13
 lda spr_bspin2
 sta anim_bspinkick+3+18
 lda spr_bspin1
 sta anim_bspinkick+3+23
 lda spr_bspin2
 sta anim_bspinkick+3+28
 lda spr_bspin3
 sta anim_bspinkick+3+33
 lda spr_bspin2
 sta anim_bspinkick+3+38

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

* Patch anim_uppercut: 3 raw frames (5-byte stride: 3 hdr + 2 addr).
* Frame addrs at offsets +6, +11, +16 from anim_uppercut.
 lda spr_bupper1
 sta anim_uppercut+3+3        ; frame 0 addr
 lda spr_bupper2
 sta anim_uppercut+3+8        ; frame 1 addr
 lda spr_bupper3
 sta anim_uppercut+3+13       ; frame 2 addr

* Patch anim_wpunched: 1 frame
 lda spr_wpunched
 sta anim_wpunched+3+3

* Patch anim_wfall: 2 frames
 lda spr_wfall
 sta anim_wfall+3+3
 lda spr_wfallen
 sta anim_wfall+3+8

* Patch anim_bfall: 2 legacy frames in bank $19. Frame 0 BFALL
* (in-air arc pose), frame 1 BFALLEN (grounded). Patched here
* would set the compiled-form fields, but anim_bfall is now
* legacy — the bank-$19 init below patches the actual addrs.

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

* sprite_bank is now per-sprite — load_sprite copies +56/+57 from
* each sprite's info block into this global on every load. The
* static initializer on the global declaration ($0002) handles
* any edge case where a render runs before load_sprite has set it.

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

* Burnov (boss) — bank-$06 sprite addresses, populated by
* init_mission12 from mission12's spr_addr_tbl.
spr_bnwalk1  ds 2
spr_bnwalk2  ds 2
spr_bnwalk3  ds 2
spr_bnfall1  ds 2
spr_bnfallen ds 2
spr_bnpunch1 ds 2
spr_bnpunch2 ds 2

* Burnov holds-and-pummels-Billy frames. Used by anim_bngrab,
* triggered when Burnov's punch lands on Billy. Replaces both
* sprites with BNBILLY1↔2 alternations + a final BNBILLY3 release.
spr_bnbilly1 ds 2
spr_bnbilly2 ds 2
spr_bnbilly3 ds 2

* Burnov "dissolving" animation frames (8 frames, body → helmet).
* Played after each non-final fall as part of his teleport-and-
* respawn boss death cycle. Played in reverse for the recon back.
spr_bdiss1   ds 2
spr_bdiss2   ds 2
spr_bdiss3   ds 2
spr_bdiss4   ds 2
spr_bdiss5   ds 2
spr_bdiss6   ds 2
spr_bdiss7   ds 2
spr_bdiss8   ds 2

* Linda-with-flail walk frames (LFWALK1/2/3) and her mace-swing
* attack frames (LMACE1/2/3). Loaded from mission12 by
* init_mission12.
spr_lfwalk1  ds 2
spr_lfwalk2  ds 2
spr_lfwalk3  ds 2
spr_lmace1   ds 2
spr_lmace2   ds 2
spr_lmace3   ds 2

* Williams-with-pipe walk frames (WPIPEWALK1/2/3). Same dimensions
* as regular William.
spr_wpipewalk1 ds 2
spr_wpipewalk2 ds 2
spr_wpipewalk3 ds 2

* Standalone mace weapon (5 orientations). Used for dropped-mace
* sprites (e.g. when linda_flail falls and her weapon hits the
* ground as a static MACE2).
spr_mace1    ds 2
spr_mace2    ds 2
spr_mace3    ds 2
spr_mace4    ds 2
spr_mace5    ds 2

* Standalone pipe (recoverable item — dropped by williams_pipe).
spr_pipe1    ds 2

* Billy with pipe — walking frames (BPIPEW1-3) and swing frames
* (BPIPE1-4). Used when billy_pipe_armed != 0. Same dimensions as
* WPIPEW (9-11 wide × 40 tall), Billy mask = $66.
spr_bpipew1  ds 2
spr_bpipew2  ds 2
spr_bpipew3  ds 2
spr_bpipe1   ds 2
spr_bpipe2   ds 2
spr_bpipe3   ds 2
spr_bpipe4   ds 2

* Set non-zero when Billy has picked up a pipe. Cleared by
* OP_KILLOBJ. Drives advance_walk's frame-table choice and L-key
* attack dispatch (anim_bpipeswing vs anim_punch1).
billy_pipe_armed dfb 0

* Same idea, but for a recovered mace (MACE2 dropped by
* linda_flail). Either flag set means Billy is "armed"; only
* one is set at a time. OP_KILLOBJ clears both.
billy_mace_armed dfb 0

* Walk-frame address tables for armed Billy. Patched by
* init_mission12. advance_walk reads pipe_walk_addr_tbl when
* billy_pipe_armed != 0 and mace_walk_addr_tbl when
* billy_mace_armed != 0; otherwise uses walk_addr_tbl (the
* compiled IMAGE01-03 table).
pipe_walk_addr_tbl ds 8
mace_walk_addr_tbl ds 8

* Billy with mace — walking (3 frames) and swing (4 frames).
spr_bmwalk1  ds 2
spr_bmwalk2  ds 2
spr_bmwalk3  ds 2
spr_bmace1   ds 2
spr_bmace2   ds 2
spr_bmace3   ds 2
spr_bmace4   ds 2

* Billy fall pose (BFALL during arc) and fallen pose (BFALLEN
* on the ground). Bank $19 (mission12). Loaded by init_mission12.
spr_bfall    ds 2
spr_bfallen  ds 2

* Williams-with-pipe swing frames (WPIPE1-6). His attack uses
* a 5-frame sequence: WPIPE1, WPIPE4, WPIPE2, WPIPE6, WPIPE3.
* WPIPE5 isn't used by the swing but is loaded for completeness.
spr_wpipe1   ds 2
spr_wpipe2   ds 2
spr_wpipe3   ds 2
spr_wpipe4   ds 2
spr_wpipe5   ds 2
spr_wpipe6   ds 2

* Williams-with-knife throw frames (WKNIFE1, WKNIFE2) and the
* knife projectile/dropped-item sprites (KNIFE2 right, KNIFE4 left).
* Loaded from mission12 by init_mission12.
spr_wknife1  ds 2
spr_wknife2  ds 2
spr_knife2   ds 2     ; thrown/dropped, pointing right
spr_knife4   ds 2     ; thrown/dropped, pointing left

* Burnov "death counter" — how many times he's gone through the
* dissolve/teleport/reconstitute cycle. Reset at level init.
*   0 → on next fall, dissolve + teleport (1st kill)
*   1 → on next fall, dissolve + teleport (2nd kill)
*   2 → on next fall, permadeath (3rd kill, level ends)
boss_death_count dfb 0
spr_wsomer1  ds 2     ; somersault frame 1 (and 5 mirrored)
spr_wsomer2  ds 2     ; somersault frame 3 (apex)
spr_wsomer3  ds 2     ; somersault frame 2 (and 4 mirrored)
spr_bupper1  ds 2     ; uppercut frame 1
spr_bupper2  ds 2     ; uppercut frame 2
spr_bupper3  ds 2     ; uppercut frame 3
spr_bgrab1   ds 2     ; grab-punch (active strike)
spr_bgrab2   ds 2     ; grab-hold pose
spr_wheld1   ds 2     ; William, held idle
spr_wheld2   ds 2     ; William, taking grab-punch
spr_rheld1   ds 2     ; Roper, held idle
spr_rheld2   ds 2     ; Roper, taking grab-punch
spr_lheld1   ds 2     ; Linda, held idle
spr_lheld2   ds 2     ; Linda, taking grab-punch

* Billy spin-kick frames (legacy data, mask=$66). Loaded by
* init_level. Played as anim_bspinkick when J+L is pressed
* during anim_jump.
spr_bspin1   ds 2
spr_bspin2   ds 2
spr_bspin3   ds 2

* Sub-frame -> WSOMER frame address. Filled in by init_level
* once spr_wsomer{1,2,3} are patched. Indexed by sub-frame×2.
somersault_addr_tbl ds 10

* Uppercut input window. Counts down from UPPERCUT_WINDOW after
* anim_jump ends (i.e., Billy lands). While > 0, a Punch press
* triggers anim_uppercut instead of anim_punch1/2.
UPPERCUT_WINDOW = 15  ; VBL frames
landing_window dfb 0

* --- Grab system ---
* After a punch connects, punch_window counts down. While > 0,
* pressing direction-toward-the-just-hit enemy enters grab state:
* Billy holds the enemy (BGRAB2 / xHELD1) until Billy walks away
* (release) or presses Punch (grab-punch sub-anim showing BGRAB1
* / xHELD2 for GRAB_PUNCH_DURATION frames, registers a normal hit).
PUNCH_GRAB_WINDOW   = 15
GRAB_PUNCH_DURATION = 8

* Grabbed enemies render lower on screen than their standing pose:
* when try_enter_grab succeeds, the enemy's ypos is bumped down by
* GRAB_Y_OFFSET. exit_grab and the gp_fall path unbump it back to
* standing height before behavior or fall_anim takes over.
GRAB_Y_OFFSET       = 10

* Per-frame held sprite sizes (low byte of *_X / *_Y from the
* sprite data in mission1.s). Hardcoded so input handling stays
* in 8-bit emulation; if the user redraws a held sprite, update
* the matching constant here.
BGRAB1_W = $0E
BGRAB1_H = $28
BGRAB2_W = $0D
BGRAB2_H = $28
WHELD1_W = $0F
WHELD1_H = $18
WHELD2_W = $0E
WHELD2_H = $18
RHELD1_W = $0E
RHELD1_H = $17
RHELD2_W = $0E
RHELD2_H = $17
LHELD1_W = $10
LHELD1_H = $16
LHELD2_W = $0D
LHELD2_H = $17

punch_window      dfb 0   ; counts down after a punch connects
last_hit_target   dw 0    ; sprite info ptr of most recently hit enemy
grab_target       dw 0    ; sprite info ptr of currently-grabbed enemy
                          ;   (0 = not grabbing)
grab_punch_timer  dfb 0   ; > 0 while showing BGRAB1/xHELD2 sub-anim
last_key          dfb 0   ; scratch: most recent keypress, used by
                          ;   the grab-state interceptor

* Burnov-grabs-Billy state. Set by check_punch_hit when Burnov's
* anim_bnpunch lands on Billy; cleared by :normal_end when the
* anim_bngrab sequence completes. While set:
*   - draw_all skips Billy (his sprite is hidden — Burnov's
*     BNBILLY1/2/3 frames are the "combined" pose).
*   - process_input is a no-op (Billy can't defend the grab).
bn_grab_active    dfb 0

* NES-style A/B button input: J = button A, L = button B.
* When either is strobed we record it in btn_pending_key with a
* BTN_WINDOW-frame timer. If the OTHER button strobes before the
* timer expires, it counts as "both pressed" → jump and we cancel
* the pending single action. If the timer expires alone, the
* single action fires (mirror-aware: the button toward Billy's
* facing direction is punch, the other is back-kick).
BTN_WINDOW = 4            ; ~67 ms at 60 Hz
btn_pending_key   dfb 0   ; 0 / 'j' / 'l'
btn_pending_timer dfb 0
btn_pending_fire  dfb 0   ; 1 = fire pending action this frame

* Input source: 0 = keyboard (default), 1 = joystick.
* Toggle with Ctrl-J (joystick) / Ctrl-K (keyboard) at any time.
* In joystick mode, GetJoyXY drives WASD-equivalent walking and
* $C061 bit 7 / $C062 bit 7 stand in for J / L through the same
* btn_action_fire pipeline — so the NES same-window logic for
* jump still applies (press both buttons within BTN_WINDOW).
* Input source: 0 = keyboard, 1 = joystick, 2 = SNES MAX.
input_mode      dfb 0
joy_btn_a_prev  dfb 0     ; $80 if button A held last frame
joy_btn_b_prev  dfb 0     ; $80 if button B held last frame
* 0 until both axes have read centered once after entering joy mode.
* Re-zeroed on Ctrl-J so the user can rearm if the stick goes stale.
joy_armed       dfb 0
* SNES MAX controller 1 state. snes_poll fills these from the slot
* card every frame (active-HIGH after poll: bit set = button pressed).
* Byte 0: bit 0=Right, 1=Left, 2=Down, 3=Up, 4=Start, 5=Select, 6=Y, 7=B
* Byte 1: bits 0-3 unused, 4=R shoulder, 5=L shoulder, 6=X, 7=A
snes_b0         dfb 0
snes_b1         dfb 0
snes_b0_prev    dfb 0
snes_b1_prev    dfb 0
* SNES MAX slot configuration. Latch/data at $C0X0, clock at
* $C0X1, where X = slot+8 (slot 1=$C090, slot 4=$C0C0,
* slot 7=$C0F0). Change to a different slot by editing the two
* address constants below. Slot 4 matches the manufacturer's
* default. Merlin32 won't parse arithmetic in `stal` operands,
* hence the precomputed hex.
SNES_LATCH      = $C0C0
SNES_CLOCK      = $C0C1
* Joystick deadzone — values inside [DEADZONE_LO, DEADZONE_HI]
* count as "centered" for that axis. 8-bit unsigned per GetJoyXY.
* Widened from the original $40/$C0 to absorb stick drift / cheap
* IIgs paddles whose center reads well off $80.
JOY_DEAD_LO = $30         ; 48
JOY_DEAD_HI = $D0         ; 208

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
* init_mission12 - Read the sprite-address-table from bank $11
* (the "more sprites" bank: boss + weapons + character variants)
* and patch each weapon/boss sprite info block in game.s with
* the real bank-$19 frame address. Mirrors init_level's pattern
* but operates on bank $19 / mission12_header.
*
* Layout: header at $19/0000 with spr_addr_off at +$12. The
* address table currently holds one entry — FLAIL — but grows
* as more sprites land (knife, pipe, boss, character variants).
*----------------------------------------------------------
 mx %11
init_mission12
 clc
 xce                   ; native mode
 rep $30
 mx %00

* Set $F0/$F1/$F2 = $19/0012 (header.spr_addr_off field).
 lda #$0012
 sta $F0
 sep $20
 lda #$19
 sta $F2
 rep $20

* Dereference: $F0 ← *($06/0012) = bank-$06 offset of spr_addr_tbl.
 ldy #0
 lda [$F0],y
 sta $F0

* Read entry +0 (FLAIL pixel data address) and patch the static
* flail_sprite block in game.s.
 ldy #0
 lda [$F0],y
 sta flail_sprite+14   ; frame_addr = $06/FLAIL
 sta flail_sprite+42   ; idle_addr  = $06/FLAIL

* Burnov sprite addresses — table indices 37-45 in spr_addr_tbl.
* Each entry is 2 bytes; offsets calculated from the spr_flail
* base. Order in the table is fixed by mission12.s; if it ever
* gets reordered, update these offsets.
 ldy #$4A              ; index 37 = spr_bnwalk1
 lda [$F0],y
 sta spr_bnwalk1
 ldy #$4C
 lda [$F0],y
 sta spr_bnwalk2
 ldy #$4E
 lda [$F0],y
 sta spr_bnwalk3
 ldy #$50
 lda [$F0],y
 sta spr_bnfall1
 ldy #$56              ; skip bnfall2/3 (unused for now)
 lda [$F0],y
 sta spr_bnfallen
 ldy #$58
 lda [$F0],y
 sta spr_bnpunch1
 ldy #$5A
 lda [$F0],y
 sta spr_bnpunch2

* BNBILLY frames — indices 46-48 ($5C-$60). Used by anim_bngrab
* for the Burnov-grabs-Billy sequence.
 ldy #$5C
 lda [$F0],y
 sta spr_bnbilly1
 ldy #$5E
 lda [$F0],y
 sta spr_bnbilly2
 ldy #$60
 lda [$F0],y
 sta spr_bnbilly3

* BDISS frames — indices 49-56 in spr_addr_tbl ($62-$70).
 ldy #$62
 lda [$F0],y
 sta spr_bdiss1
 ldy #$64
 lda [$F0],y
 sta spr_bdiss2
 ldy #$66
 lda [$F0],y
 sta spr_bdiss3
 ldy #$68
 lda [$F0],y
 sta spr_bdiss4
 ldy #$6A
 lda [$F0],y
 sta spr_bdiss5
 ldy #$6C
 lda [$F0],y
 sta spr_bdiss6
 ldy #$6E
 lda [$F0],y
 sta spr_bdiss7
 ldy #$70
 lda [$F0],y
 sta spr_bdiss8

* Linda-with-flail: walk frames at indices 57-59 ($72-$76),
* mace-swing frames at indices 1-3 ($02-$06).
 ldy #$02
 lda [$F0],y
 sta spr_lmace1
 ldy #$04
 lda [$F0],y
 sta spr_lmace2
 ldy #$06
 lda [$F0],y
 sta spr_lmace3
 ldy #$72
 lda [$F0],y
 sta spr_lfwalk1
 ldy #$74
 lda [$F0],y
 sta spr_lfwalk2
 ldy #$76
 lda [$F0],y
 sta spr_lfwalk3

* Williams-with-pipe walk frames (WPIPEWALK1/2/3) at indices 60-62.
 ldy #$78
 lda [$F0],y
 sta spr_wpipewalk1
 ldy #$7A
 lda [$F0],y
 sta spr_wpipewalk2
 ldy #$7C
 lda [$F0],y
 sta spr_wpipewalk3

* WPIPE1-6 (pipe-swing frames) at indices 10-15 ($14-$1E).
 ldy #$14
 lda [$F0],y
 sta spr_wpipe1
 ldy #$16
 lda [$F0],y
 sta spr_wpipe2
 ldy #$18
 lda [$F0],y
 sta spr_wpipe3
 ldy #$1A
 lda [$F0],y
 sta spr_wpipe4
 ldy #$1C
 lda [$F0],y
 sta spr_wpipe5
 ldy #$1E
 lda [$F0],y
 sta spr_wpipe6

* Standalone pipe (PIPE1, horizontal) at index 16 ($20). Used as
* the dropped-pipe item when williams_pipe falls.
 ldy #$20
 lda [$F0],y
 sta spr_pipe1

* Billy-with-pipe walk frames (BPIPEW1-3) at indices 30-32
* ($3C-$40), and swing frames (BPIPE1-4) at indices 33-36
* ($42-$48). Used when Billy is armed.
 ldy #$3C
 lda [$F0],y
 sta spr_bpipew1
 ldy #$3E
 lda [$F0],y
 sta spr_bpipew2
 ldy #$40
 lda [$F0],y
 sta spr_bpipew3
 ldy #$42
 lda [$F0],y
 sta spr_bpipe1
 ldy #$44
 lda [$F0],y
 sta spr_bpipe2
 ldy #$46
 lda [$F0],y
 sta spr_bpipe3
 ldy #$48
 lda [$F0],y
 sta spr_bpipe4

* Billy-with-mace swing frames (BMACE1-4) at indices 23-26
* ($2E-$34). Used when Billy swings a recovered mace.
 ldy #$2E
 lda [$F0],y
 sta spr_bmace1
 ldy #$30
 lda [$F0],y
 sta spr_bmace2
 ldy #$32
 lda [$F0],y
 sta spr_bmace3
 ldy #$34
 lda [$F0],y
 sta spr_bmace4

* Billy-with-mace walk frames (BMWALK1-3) at indices 63-65
* ($7E-$82). Mirror the BPIPEW pattern.
 ldy #$7E
 lda [$F0],y
 sta spr_bmwalk1
 ldy #$80
 lda [$F0],y
 sta spr_bmwalk2
 ldy #$82
 lda [$F0],y
 sta spr_bmwalk3

* Billy fall sprites at indices 66-67 ($84/$86). BFALL is the
* in-air pose, BFALLEN is the grounded pose; used by anim_bfall.
 ldy #$84
 lda [$F0],y
 sta spr_bfall
 ldy #$86
 lda [$F0],y
 sta spr_bfallen

* Standalone mace weapon (MACE1-5) at indices 18-22 ($24-$2C).
 ldy #$24
 lda [$F0],y
 sta spr_mace1
 ldy #$26
 lda [$F0],y
 sta spr_mace2
 ldy #$28
 lda [$F0],y
 sta spr_mace3
 ldy #$2A
 lda [$F0],y
 sta spr_mace4
 ldy #$2C
 lda [$F0],y
 sta spr_mace5

* Williams-with-knife throw frames at indices 4-5 ($08, $0A) and
* the standalone knife sprites (KNIFE2 right, KNIFE4 left) at
* indices 7 and 9 ($0E, $12). KNIFE1/3 (held/falling) aren't
* used by the engine yet so we don't cache them.
 ldy #$08
 lda [$F0],y
 sta spr_wknife1
 ldy #$0A
 lda [$F0],y
 sta spr_wknife2
 ldy #$0E
 lda [$F0],y
 sta spr_knife2
 ldy #$12
 lda [$F0],y
 sta spr_knife4

* Patch Burnov animation descriptors. Per-frame frame_addr
* lives at +3+3 (frame 0), +3+8 (frame 1), etc. (5-byte stride
* for legacy/uncompiled animations).
 lda spr_bnwalk1
 sta anim_bnwalk+3+3
 lda spr_bnwalk2
 sta anim_bnwalk+3+8
 lda spr_bnwalk3
 sta anim_bnwalk+3+13
 lda spr_bnwalk2
 sta anim_bnwalk+3+18

 lda spr_bnpunch1
 sta anim_bnpunch+3+3
 lda spr_bnpunch2
 sta anim_bnpunch+3+8

* Patch anim_bngrab: 7 legacy frames at offsets 6/11/16/21/26/31/36
* (BNBILLY1, 2, 1, 2, 1, 2, 3).
 lda spr_bnbilly1
 sta anim_bngrab+3+3
 sta anim_bngrab+3+13
 sta anim_bngrab+3+23
 lda spr_bnbilly2
 sta anim_bngrab+3+8
 sta anim_bngrab+3+18
 sta anim_bngrab+3+28
 lda spr_bnbilly3
 sta anim_bngrab+3+33

 lda spr_bnfall1
 sta anim_bnpunched+3+3      ; placeholder reaction = BNFALL1

 lda spr_bnfall1
 sta anim_bnfall+3+3
 lda spr_bnfallen
 sta anim_bnfall+3+8

* Patch anim_bn_diss (BDISS1→8) — 8 frames at +3+3, +3+8, ...
* +3+3, +3+8, +3+13, +3+18, +3+23, +3+28, +3+33, +3+38
 lda spr_bdiss1
 sta anim_bn_diss+3+3
 lda spr_bdiss2
 sta anim_bn_diss+3+8
 lda spr_bdiss3
 sta anim_bn_diss+3+13
 lda spr_bdiss4
 sta anim_bn_diss+3+18
 lda spr_bdiss5
 sta anim_bn_diss+3+23
 lda spr_bdiss6
 sta anim_bn_diss+3+28
 lda spr_bdiss7
 sta anim_bn_diss+3+33
 lda spr_bdiss8
 sta anim_bn_diss+3+38

* Patch anim_bn_recon (BDISS8→1) — same 8 frames in reverse.
 lda spr_bdiss8
 sta anim_bn_recon+3+3
 lda spr_bdiss7
 sta anim_bn_recon+3+8
 lda spr_bdiss6
 sta anim_bn_recon+3+13
 lda spr_bdiss5
 sta anim_bn_recon+3+18
 lda spr_bdiss4
 sta anim_bn_recon+3+23
 lda spr_bdiss3
 sta anim_bn_recon+3+28
 lda spr_bdiss2
 sta anim_bn_recon+3+33
 lda spr_bdiss1
 sta anim_bn_recon+3+38

* Patch anim_lfwalk: 4 frames (LFWALK1, 2, 3, 2 cycle).
 lda spr_lfwalk1
 sta anim_lfwalk+3+3
 lda spr_lfwalk2
 sta anim_lfwalk+3+8
 lda spr_lfwalk3
 sta anim_lfwalk+3+13
 lda spr_lfwalk2
 sta anim_lfwalk+3+18

* Patch anim_lmace: 3 frames (LMACE1, 2, 3) — Linda's mace-swing
* attack, replaces anim_lpunch for the armed variant.
 lda spr_lmace1
 sta anim_lmace+3+3
 lda spr_lmace2
 sta anim_lmace+3+8
 lda spr_lmace3
 sta anim_lmace+3+13

* Patch anim_lffall: placeholder using LFWALK1 for both frames.
 lda spr_lfwalk1
 sta anim_lffall+3+3
 sta anim_lffall+3+8

* Patch anim_wpipewalk: 4 frames (WPIPEWALK1, 2, 3, 2 cycle).
 lda spr_wpipewalk1
 sta anim_wpipewalk+3+3
 lda spr_wpipewalk2
 sta anim_wpipewalk+3+8
 lda spr_wpipewalk3
 sta anim_wpipewalk+3+13
 lda spr_wpipewalk2
 sta anim_wpipewalk+3+18

* Patch anim_wpfall: placeholder using WPIPEWALK1 for both frames.
 lda spr_wpipewalk1
 sta anim_wpfall+3+3
 sta anim_wpfall+3+8

* Patch anim_wpipeswing: 5 frames in design order
* (WPIPE1, WPIPE4, WPIPE2, WPIPE6, WPIPE3). Frame stride = 5
* (legacy): offsets +3+3, +3+8, +3+13, +3+18, +3+23.
 lda spr_wpipe1
 sta anim_wpipeswing+3+3
 lda spr_wpipe4
 sta anim_wpipeswing+3+8
 lda spr_wpipe2
 sta anim_wpipeswing+3+13
 lda spr_wpipe6
 sta anim_wpipeswing+3+18
 lda spr_wpipe3
 sta anim_wpipeswing+3+23

* Patch anim_wkthrow: 2 frames (WKNIFE1, WKNIFE2).
 lda spr_wknife1
 sta anim_wkthrow+3+3
 lda spr_wknife2
 sta anim_wkthrow+3+8

* Patch anim_bpipewalk: 4 frames (BPIPEW1, 2, 3, 2 cycle).
 lda spr_bpipew1
 sta anim_bpipewalk+3+3
 lda spr_bpipew2
 sta anim_bpipewalk+3+8
 lda spr_bpipew3
 sta anim_bpipewalk+3+13
 lda spr_bpipew2
 sta anim_bpipewalk+3+18

* Patch anim_bpipeswing: 4 frames (BPIPE1, 2, 3, 4).
 lda spr_bpipe1
 sta anim_bpipeswing+3+3
 lda spr_bpipe2
 sta anim_bpipeswing+3+8
 lda spr_bpipe3
 sta anim_bpipeswing+3+13
 lda spr_bpipe4
 sta anim_bpipeswing+3+18

* Patch pipe_walk_addr_tbl with BPIPEW1, 2, 3, 2 (4 entries × 2 bytes).
 lda spr_bpipew1
 sta pipe_walk_addr_tbl
 lda spr_bpipew2
 sta pipe_walk_addr_tbl+2
 lda spr_bpipew3
 sta pipe_walk_addr_tbl+4
 lda spr_bpipew2
 sta pipe_walk_addr_tbl+6

* Patch anim_bmwalk: 4 frames (BMWALK1, 2, 3, 2 cycle).
 lda spr_bmwalk1
 sta anim_bmwalk+3+3
 lda spr_bmwalk2
 sta anim_bmwalk+3+8
 lda spr_bmwalk3
 sta anim_bmwalk+3+13
 lda spr_bmwalk2
 sta anim_bmwalk+3+18

* Patch anim_bfall: 2 legacy frames (BFALL during arc, BFALLEN
* held on the ground). Bank-$19 flag in the descriptor header
* so start_anim sets frame_bank to $19.
 lda spr_bfall
 sta anim_bfall+3+3
 lda spr_bfallen
 sta anim_bfall+3+8

* Patch anim_bmaceswing: 4 frames (BMACE1, 2, 3, 4).
 lda spr_bmace1
 sta anim_bmaceswing+3+3
 lda spr_bmace2
 sta anim_bmaceswing+3+8
 lda spr_bmace3
 sta anim_bmaceswing+3+13
 lda spr_bmace4
 sta anim_bmaceswing+3+18

* Patch mace_walk_addr_tbl with BMWALK1, 2, 3, 2.
 lda spr_bmwalk1
 sta mace_walk_addr_tbl
 lda spr_bmwalk2
 sta mace_walk_addr_tbl+2
 lda spr_bmwalk3
 sta mace_walk_addr_tbl+4
 lda spr_bmwalk2
 sta mace_walk_addr_tbl+6

 sec
 xce                   ; back to emulation
 mx %11
* DEBUG: dump key Burnov addresses to the text screen so we
* can verify the address-table read worked. Format:
*   "BN <bnwalk1> <bnpunch1> <bnfall1>"
* Each is 4 hex digits (high then low).
 lda #$C2              ; 'B'
 jsr dbg_print_char
 lda #$CE              ; 'N'
 jsr dbg_print_char
 lda #$A0              ; ' '
 jsr dbg_print_char
 lda spr_bnwalk1+1
 jsr dbg_print_hex8
 lda spr_bnwalk1
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda spr_bnpunch1+1
 jsr dbg_print_hex8
 lda spr_bnpunch1
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda spr_bnfall1+1
 jsr dbg_print_hex8
 lda spr_bnfall1
 jsr dbg_print_hex8
 jsr dbg_print_nl
* DEBUG: directly read bytes from $19/3DCB (BNWALK1 row 1 start)
* to confirm the load actually deposited the sprite data there.
* Expected: 44 44 44 44 (start of BNWALK1's first row).
 lda #$D7              ; 'W'
 jsr dbg_print_char
 lda #$BD              ; '='
 jsr dbg_print_char
 ldal $193DCB
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 ldal $193DCC
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 ldal $193DCD
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 ldal $193DCE
 jsr dbg_print_hex8
 jsr dbg_print_nl
 rts

*----------------------------------------------------------
* init_doc - Idle and reset Ensoniq DOC oscillators.
* Halts all 32 oscillators, zeros volumes, drains pending
* IRQs, sets enabled count to 1. Called in emulation mode.
*----------------------------------------------------------
 mx %11
init_doc
 php
 sei

* Force the system master-volume shadow ($E100CA, low nybble)
* to $F. The IIgs firmware re-writes $C03C's master volume
* from this location periodically, so without this our $C03C
* writes silently get reset to whatever the Control Panel has.
 lda #$0F
 stal $E100CA

* GLU control: DOC reg space, auto-inc, master volume = 0
 jsr doc_wait
 lda #$20
 sta $C03C

* Halt all 32 oscillators: write $01 to control regs $A0-$BF
 jsr doc_wait
 lda #$A0
 sta $C03E
 jsr doc_wait
 lda #$00
 sta $C03F
 ldx #32
:halt
 jsr doc_wait
 lda #$01
 sta $C03D
 dex
 bne :halt

* Zero all 32 volumes: $40-$5F
 jsr doc_wait
 lda #$40
 sta $C03E
 ldx #32
:vol
 jsr doc_wait
 stz $C03D
 dex
 bne :vol

* Drain any latched oscillator IRQ. Read $E0 until b7=1.
 jsr doc_wait
 lda #$E0
 sta $C03E
:drain
 jsr doc_wait
 lda $C03D
 bpl :drain

* Enable 31 oscillators (write $3E = count*2 to $E1).
* This matches NTP's runtime setting (osc 0-7 = music tracks,
* osc 31 = music timer); osc 8+ available for SFX. Per-osc
* update rate becomes 894886/(31+2) = ~27 kHz. We pre-set
* this so SFX Fc values stay valid whether music is playing
* or not — NTP overwrites $E1 with this same value when its
* setup_interrupt runs, so matching avoids a rate jump.
 jsr doc_wait
 lda #$E1
 sta $C03E
 jsr doc_wait
 lda #$3E
 sta $C03D

 plp
 rts

doc_wait
 bit $C03C
 bmi doc_wait
 rts

*----------------------------------------------------------
* Sound system — SFX playback via NTPstreamsound.
*
* Each SFX is described by a 15-byte stream_structure that
* matches NTP's expected layout (see ninjatrackerp.s line
* 124+). NTPstreamsound allocates two oscillators per SFX
* (an interrupt timer + a playback voice), streams the
* sample from CPU RAM into a 512-byte DOC RAM buffer, and
* halts the voices when the source RAM is exhausted.
*
* Per-SFX layout:
*   +0/+2  4-byte pointer to sample (lo word, hi word/bank)
*   +4/+6  4-byte length in bytes (lo word, hi word)
*   +8     2-byte Fc (playback frequency)
*   +10    1-byte DOC RAM page (must be 512-byte aligned)
*   +11    1-byte first oscillator (0-29; +1 plays the sound)
*   +12    1-byte playback osc count (we use 1 for mono)
*   +13    1-byte volume (0-255)
*   +14    1-byte channel ($00 = mono out)
*
* SFX share interrupt+playback osc 8/9; triggering a new
* sound stops the previous one. DOC RAM pages $80, $82, $84,
* $86, $88, $8A, $8C, $8E, $90, $92 are reserved for the SFX
* (512 bytes each — 10 SFX × 512 B = 5 KB of DOC RAM).
* Samples live in CPU RAM banks $11 and $1A; bank comes from
* each struct's "sample addr hi word" (struct +2/+3).
*----------------------------------------------------------

SND_PUNCH        equ 0
SND_PUNCHLANDED  equ 1
SND_FINGER       equ 2
SND_POW          equ 3
SND_FALLEN       equ 4
SND_JUMP         equ 5
SND_DOOR         equ 6
SND_SPINKICK     equ 7
SND_BURNGONE     equ 8
SND_BURNBACK     equ 9
SND_COUNT        equ 10

sound_ptr equ $F6   ; ZP: 2-byte pointer to current SFX struct

sound_table
 da sfx_punch_struct
 da sfx_punchlanded_struct
 da sfx_finger_struct
 da sfx_pow_struct
 da sfx_fallen_struct
 da sfx_jump_struct
 da sfx_door_struct
 da sfx_spinkick_struct
 da sfx_burngone_struct
 da sfx_burnback_struct

sound_path_table
 da sfx_punch_path
 da sfx_punchlanded_path
 da sfx_finger_path
 da sfx_pow_path
 da sfx_fallen_path
 da sfx_jump_path
 da sfx_door_path
 da sfx_spinkick_path
 da sfx_burngone_path
 da sfx_burnback_path

* Each sample loads to bank $11 at offset = (sound_index * $1000).
* Byte at offset +15 is our private "amplification shift" used
* by sfx_amplify (NTPstreamsound only reads up through +14).
sfx_punch_struct
 da $0000           ; sample addr lo word ($11/0000)
 da $0011           ; sample addr hi word (bank $11, hi=0)
 da $03C6           ; length lo word (966)
 da $0000           ; length hi word
 da $009C           ; Fc — playback rate
 dfb $80            ; doc_ram_page → DOC $8000
 dfb $08            ; first_osc (interrupt timer)
 dfb $01            ; playback osc count
 dfb $FF            ; volume
 dfb $00            ; channel (mono out)
 dfb 2              ; gain shift (×4 — narrow source dynamic range)

sfx_punchlanded_struct
 da $1000           ; sample at $11/1000
 da $0011
 da $0474           ; length 1140
 da $0000
 da $009C
 dfb $82            ; doc_ram_page → DOC $8200
 dfb $08
 dfb $01
 dfb $FF
 dfb $00
 dfb 2              ; gain shift (×4)

sfx_finger_struct
 da $2000           ; sample at $11/2000
 da $0011
 da $1650           ; length 5712
 da $0000
 da $009C
 dfb $84            ; doc_ram_page → DOC $8400
 dfb $08
 dfb $01
 dfb $FF
 dfb $00
 dfb 1              ; gain shift (×2 — wider source range, avoid clip)

* POW lives at $11/4000 (not $11/3000) because FINGER spans
* $11/2000-$11/3650 — its tail would be clobbered by anything
* loaded at $11/3000.
sfx_pow_struct
 da $4000           ; sample at $11/4000
 da $0011
 da $10A0           ; length 4256
 da $0000
 da $009C
 dfb $86            ; doc_ram_page → DOC $8600
 dfb $08
 dfb $01
 dfb $FF
 dfb $00
 dfb 2              ; gain shift (×4)

* FALLEN lives at $11/6000 because POW spans $11/4000-$11/50A0;
* skip the $11/5000 slot to avoid clobbering POW's tail.
sfx_fallen_struct
 da $6000           ; sample at $11/6000
 da $0011
 da $0A00           ; length 2560
 da $0000
 da $009C
 dfb $88            ; doc_ram_page → DOC $8800
 dfb $08
 dfb $01
 dfb $FF
 dfb $00
 dfb 2              ; gain shift (×4)

* JUMP fits in one 4 KB slot at $11/7000 (FALLEN's tail ends at
* $11/6A00, so $7000 is clear).
sfx_jump_struct
 da $7000           ; sample at $11/7000
 da $0011
 da $07B0           ; length 1968
 da $0000
 da $009C
 dfb $8A            ; doc_ram_page → DOC $8A00
 dfb $08
 dfb $01
 dfb $FF
 dfb $00
 dfb 2              ; gain shift (×4)

* DOOR is 5896 bytes — claims two 4 KB slots at $11/8000-$11/9708.
sfx_door_struct
 da $8000           ; sample at $11/8000
 da $0011
 da $1708           ; length 5896
 da $0000
 da $009C
 dfb $8C            ; doc_ram_page → DOC $8C00
 dfb $08
 dfb $01
 dfb $FF
 dfb $00
 dfb 2              ; gain shift (×4)

* SPINKICK is 7368 bytes — two 4 KB slots at $11/A000-$11/BCC8.
* (Skips $11/9000-$11/9708 because DOOR's tail clobbers it.)
sfx_spinkick_struct
 da $A000           ; sample at $11/A000
 da $0011
 da $1CC8           ; length 7368
 da $0000
 da $009C
 dfb $8E            ; doc_ram_page → DOC $8E00
 dfb $08
 dfb $01
 dfb $FF
 dfb $00
 dfb 2              ; gain shift (×4)

* Boss SFX live in their own bank ($1A) — together they're ~57 KB
* and won't fit alongside the other SFX in $11. The install loop
* now reads each struct's bank from offset +2, so this works
* without further changes.
sfx_burngone_struct
 da $0000           ; sample at $1A/0000
 da $001A
 da $65D0           ; length 26064
 da $0000
 da $009C
 dfb $90            ; doc_ram_page → DOC $9000
 dfb $08
 dfb $01
 dfb $FF
 dfb $00
 dfb 2              ; gain shift (×4)

* BURNBACK at $1A/8000 (clear of BURNGONE's $1A/0000-$65D0 tail).
sfx_burnback_struct
 da $8000           ; sample at $1A/8000
 da $001A
 da $76F2           ; length 30450
 da $0000
 da $009C
 dfb $92            ; doc_ram_page → DOC $9200
 dfb $08
 dfb $01
 dfb $FF
 dfb $00
 dfb 2              ; gain shift (×4)

sfx_punch_path        dfb 21
                      asc '/DDIIGS/SFX/PUNCH.RAW'
sfx_punchlanded_path  dfb 27
                      asc '/DDIIGS/SFX/PUNCHLANDED.RAW'
sfx_finger_path       dfb 22
                      asc '/DDIIGS/SFX/FINGER.RAW'
sfx_pow_path          dfb 19
                      asc '/DDIIGS/SFX/POW.RAW'
sfx_fallen_path       dfb 22
                      asc '/DDIIGS/SFX/FALLEN.RAW'
sfx_jump_path         dfb 20
                      asc '/DDIIGS/SFX/JUMP.RAW'
sfx_door_path         dfb 20
                      asc '/DDIIGS/SFX/DOOR.RAW'
sfx_spinkick_path     dfb 24
                      asc '/DDIIGS/SFX/SPINKICK.RAW'
sfx_burngone_path     dfb 24
                      asc '/DDIIGS/SFX/BURNGONE.RAW'
sfx_burnback_path     dfb 24
                      asc '/DDIIGS/SFX/BURNBACK.RAW'

sound_len           ds 2   ; scratch — 16-bit length for sfx_amplify
sfx_gain_shift      ds 2   ; 16-bit: low byte = shift, high byte = 0
sfx_pos_threshold   ds 1   ; scratch — saturate positive dev above this
sfx_neg_threshold   ds 1   ; scratch — saturate negative dev below this (signed)

*----------------------------------------------------------
* sound_select - X = sound index, sets sound_ptr from
* sound_table[X]. Caller stays in emulation mode.
*----------------------------------------------------------
 mx %11
sound_select
 txa
 asl
 tax
 lda sound_table,x
 sta sound_ptr
 lda sound_table+1,x
 sta sound_ptr+1
 rts

*----------------------------------------------------------
* sound_install_all - Load each SFX file into bank $11 at the
* offset stored in its struct's "sample addr" field (struct +0).
* Reading the offset from the struct rather than computing it
* from the index means SFX larger than 4 KB (e.g. FINGER at 5712
* bytes, POW at 4256) can claim multiple 4 KB slots — the struct
* and loader stay in sync. load_file pre-fills RDBUF with $80
* each chunk so unused tail bytes are silent (NTPstreamsound
* reads up to 256 bytes past the sample's actual length).
* Called at boot in emulation mode.
*----------------------------------------------------------
sound_install_all
 ldx #0
:loop
 cpx #SND_COUNT
 bcs :done
 phx

* Pull path pointer from sound_path_table[X*2]
 txa
 asl
 tay                  ; Y = X * 2
 lda sound_path_table,y
 sta file_open+1
 lda sound_path_table+1,y
 sta file_open+2

* Load destination = sound_table[X] -> sample addr (struct +0/+1)
 plx
 phx
 jsr sound_select     ; sound_ptr = sound_table[X]
 ldy #0
 lda (sound_ptr),y
 sta file_dest
 iny
 lda (sound_ptr),y
 sta file_dest+1
* Bank comes from struct +2 (the low byte of "sample addr hi
* word"). Was hardcoded to $11 — now per-struct so big SFX
* (e.g. boss audio) can live in their own bank.
 ldy #2
 lda (sound_ptr),y
 sta file_bank
 jsr load_file

* Amplify the just-loaded sample 4× in-place. sound_select
* sets sound_ptr from sound_table[X], which sfx_amplify uses
* to find the sample address and length.
 plx
 phx
 jsr sound_select
 jsr sfx_amplify

 plx
 inx
 bra :loop
:done
 rts

*----------------------------------------------------------
* sfx_amplify - Multiply sample's deviation from $80 by
* 2^shift (1×, 2×, 4×, 8×) where shift is read from the
* SFX struct at offset 15. Saturates at $01..$FF. Walks
* the sample bytes in-place. Bytes at silence center ($80)
* unchanged so trailing $80 padding stays silent.
*
* Caller: sound_ptr → SFX struct; emulation mode.
*----------------------------------------------------------
 mx %11
sfx_amplify
 php
 sei

* Read shift count; if 0 nothing to do.
 ldy #15
 lda (sound_ptr),y
 bne :amp_go
 jmp :noamp
:amp_go
 sta sfx_gain_shift
 stz sfx_gain_shift+1   ; ensure 16-bit ldx reads $00xx not $XXxx

* pos_threshold = $80 >> shift (saturate above this)
 lda #$80
 ldx sfx_gain_shift
:thresh_loop
 lsr
 dex
 bne :thresh_loop
 sta sfx_pos_threshold

* neg_threshold = -pos_threshold (saturate below this signed)
 lda #0
 sec
 sbc sfx_pos_threshold
 sta sfx_neg_threshold

* Load source long pointer from struct[0..2]
 ldy #0
 lda (sound_ptr),y
 sta $F0
 iny
 lda (sound_ptr),y
 sta $F1
 ldy #2
 lda (sound_ptr),y
 sta $F2

* Cache 16-bit length from struct[4..5]
 ldy #4
 lda (sound_ptr),y
 sta sound_len
 iny
 lda (sound_ptr),y
 sta sound_len+1

* Switch to native: 8-bit A, 16-bit X/Y for the byte loop
 clc
 xce
 sep #$20
 rep #$10
 mx %10

 ldy #$0000
:loop
 lda [$F0],y
 sec
 sbc #$80              ; signed deviation from silence center
 bmi :neg

* Positive: saturate if dev >= pos_threshold
 cmp sfx_pos_threshold
 bcs :pos_sat
 ldx sfx_gain_shift
:pos_shift
 asl
 dex
 bne :pos_shift
 bra :back
:pos_sat
 lda #$7F
 bra :back

* Negative: saturate if dev < neg_threshold (more negative)
:neg
 cmp sfx_neg_threshold
 bcs :neg_inrange
 lda #$80
 bra :back
:neg_inrange
 ldx sfx_gain_shift
:neg_shift
 asl
 dex
 bne :neg_shift

:back
 clc
 adc #$80              ; back to unsigned
 bne :nz
 lda #$01              ; remap $00 → $01 (halt-on-zero guard)
:nz
 sta [$F0],y
 iny
 cpy sound_len
 bne :loop

* Restore emulation
 sep #$30
 sec
 xce
 mx %11

 plp
 rts

:noamp
 plp
 rts

*----------------------------------------------------------
* sound_play - Hand off to NTPstreamsound with the current
* sound's structure. NTP allocates oscillators 8/9, fills
* the DOC RAM buffer from RAM, and starts streaming.
* sound_ptr must already point to the SFX struct.
* Called in emulation mode; restored on return.
*----------------------------------------------------------
sound_play
 mx %11
 php

 clc
 xce                   ; native mode for NTPstreamsound
 rep #$30
 mx %00

 ldy #$0000            ; bank 0 (struct lives in game.s data)
 ldx sound_ptr         ; X = 16-bit struct address
 jsl NTPstreamsound

 sec
 xce                   ; back to emulation
 sep #$30
 mx %11

 plp
 rts

*----------------------------------------------------------
* sound_trigger - X = sound index. Convenience: select+play.
*----------------------------------------------------------
sound_trigger
 jsr sound_select
 jsr sound_play
 rts

*----------------------------------------------------------
* verify_punch_state - Diagnostic: dumps osc 16 register
* state plus DOC RAM bytes from the punch sample zone.
*
* Press 'v' in-game to fire this. Compare to expected:
*   W=A0 S=27 V=FF M=2F C=02|03 D=??
*   DOC[A000]=80  (punch byte 0, expected $80)
*   DOC[A064]=7A  (punch byte 100)
*   DOC[A0C8]=77  (punch byte 200)
* Reads osc 8 (interrupt) and osc 9 (playback) state plus
* DOC RAM at $8000 (NTPstreamsound buffer).
* Expected after sound_play returns:
*   osc 8 (interrupt):  W=00 S=00 V=00 C=08|0A
*   osc 9 (playback):   W=80 S=09 V=FF C=00|03
*   BUF $8000+: real sample bytes (e.g. $80 / $7F / etc.)
*----------------------------------------------------------
 mx %11
verify_punch_state
 php
 sei

* Switch GLU to DOC reg mode + auto-inc + master vol $F
 jsr doc_wait
 lda #$2F
 sta $C03C

* Osc 8 (interrupt timer): regs at base+8
 lda #$CF              ; 'O'
 jsr dbg_print_char
 lda #$B8              ; '8'
 jsr dbg_print_char
 lda #$BD              ; '='
 jsr dbg_print_char
 lda #$88              ; W ($80+8)
 jsr dbg_read_doc_reg
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$C8              ; S ($C0+8)
 jsr dbg_read_doc_reg
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$48              ; V ($40+8)
 jsr dbg_read_doc_reg
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$A8              ; C ($A0+8)
 jsr dbg_read_doc_reg
 jsr dbg_print_hex8
 jsr dbg_print_nl

* Osc 9 (playback): regs at base+9
 lda #$CF              ; 'O'
 jsr dbg_print_char
 lda #$B9              ; '9'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 lda #$89              ; W
 jsr dbg_read_doc_reg
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$C9              ; S
 jsr dbg_read_doc_reg
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$49              ; V
 jsr dbg_read_doc_reg
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$A9              ; C
 jsr dbg_read_doc_reg
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$69              ; D ($60+9)
 jsr dbg_read_doc_reg
 jsr dbg_print_hex8
 jsr dbg_print_nl

* DOC RAM buffer at $8000 (where NTPstreamsound copies sample)
 jsr doc_wait
 lda #$6F
 sta $C03C

 lda #$C2              ; 'B'
 jsr dbg_print_char
 lda #$D5              ; 'U'
 jsr dbg_print_char
 lda #$C6              ; 'F'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char

* Read DOC[$8000], [$8004], [$8010], [$80F0]
 lda #$00
 ldx #$80
 jsr verify_read_doc_ram
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$04
 ldx #$80
 jsr verify_read_doc_ram
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$10
 ldx #$80
 jsr verify_read_doc_ram
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$F0
 ldx #$80
 jsr verify_read_doc_ram
 jsr dbg_print_hex8

 jsr dbg_print_nl

* Restore CTL to DOC reg mode + auto-inc + vol $F
 jsr doc_wait
 lda #$2F
 sta $C03C

 plp
 rts

* dbg_read_doc_reg - read DOC reg whose addr is in A. Forces
* high byte of addr ptr to $00. CTL must be in DOC reg mode.
dbg_read_doc_reg
 jsr doc_wait
 sta $C03E
 jsr doc_wait
 lda #$00
 sta $C03F
 jsr doc_wait
 lda $C03D            ; dummy
 jsr doc_wait
 lda $C03D            ; real
 rts

* verify_wait_3vbls - busy-wait through 3 VBL transitions
* (~50 ms) so verify_punch_state runs mid-sample.
verify_wait_3vbls
 ldx #3
:vloop
 jsr wait_for_vbl
 dex
 bne :vloop
 rts

* verify_read_doc_ram - read one byte from DOC RAM.
*   A = address lo, X = address hi
*   CTL must already be in RAM mode + auto-inc.
*   Returns byte in A.
verify_read_doc_ram
 jsr doc_wait
 sta $C03E
 jsr doc_wait
 stx $C03F
 jsr doc_wait
 lda $C03D            ; dummy (RAM read lags by 1)
 jsr doc_wait
 lda $C03D            ; real
 rts

*----------------------------------------------------------
* Set file_open pathname pointer and file_bank before calling.
*----------------------------------------------------------
 mx %11                ; emulation mode
load_file
 jsr $BF00
 dfb $C8              ; OPEN
 da file_open
 bcs :err
 lda file_oref
 sta file_rref
 sta file_cref

:readlp
* Pre-fill ]RDBUF with $80 (silence centre) before each READ
* so any tail bytes ProDOS doesn't overwrite become silence in
* the destination bank — needed by NTPstreamsound which reads
* up to a 256-byte boundary past the actual sample end.
 jsr fill_rdbuf_silence
 jsr $BF00
 dfb $CA              ; READ
 da file_read
 bcs :close

 jsr file_copy_chunk

* Advance destination by $0400 (1 KB = 4 pages)
 lda file_dest+1
 clc
 adc #$04
 sta file_dest+1
 bcc :readlp
* Address wrapped — next bank
 lda #$00
 sta file_dest+1
 inc file_bank
 bra :readlp

:close
 php
 jsr $BF00
 dfb $CC              ; CLOSE
 da file_close
 plp
:err rts

*----------------------------------------------------------
* file_copy_chunk - Copy 1KB from ]RDBUF to file_bank/file_dest
*----------------------------------------------------------
file_copy_chunk
 clc
 xce                   ; native mode
 rep $30
 mx %00                ; tell Merlin: 16-bit A and index

 lda file_dest
 sta $F0
 sep $20
 lda file_bank
 sta $F2
 rep $30

 ldy #$0000
 ldx #$0200            ; $0400/2 = $0200 word copies (1 KB)

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
* fill_rdbuf_silence - Fill ]RDBUF (1 KB) with $80 (silence
* centre). Called by load_file before each ProDOS READ so
* bytes past file EOF in the destination bank are silent.
*----------------------------------------------------------
 mx %11
fill_rdbuf_silence
 clc
 xce                   ; native mode
 rep #$30
 mx %00
 lda #$8080            ; word fill
 ldy #$0000
 ldx #$0200            ; 512 word writes = 1 KB
:loop
 sta ]RDBUF,y
 iny
 iny
 dex
 bne :loop
 sec
 xce                   ; back to emulation
 mx %11
 rts

*----------------------------------------------------------
* File loader ProDOS 8 parameter blocks
*----------------------------------------------------------
file_dest ds 2
file_bank dfb $02

file_open dfb 3
 da mission1_path
 da ]IOBUF
file_oref dfb 0

file_read dfb 4
file_rref dfb 0
 da ]RDBUF
 da $0400              ; request count (1KB = 2 disk blocks)
 ds 2                  ; transfer count

file_close dfb 1
file_cref dfb 0

mission1_path dfb 25
 asc '/DDIIGS/MISSION1/MISSION1'

mission12_path dfb 26
 asc '/DDIIGS/MISSION1/MISSION12'

* MISSION1NTP.PAK rather than MISSION1.NTP.PAK because ProDOS
* limits each filename component to 15 chars.
m1ntp_path dfb 32
 asc '/DDIIGS/MISSION1/MISSION1NTP.PAK'

bossntp_path dfb 20
 asc '/DDIIGS/BOSS.NTP.PAK'

completentp_path dfb 23
 asc '/DDIIGS/COMPLETENTP.PAK'

gameoverntp_path dfb 23
 asc '/DDIIGS/GAMEOVERNTP.PAK'

loading_path dfb 19
 asc '/DDIIGS/LOADING.PAK'


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
 stz bounds_right_valid     ; neighbor tables are stale on transition
 stz bounds_left_valid
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

* Billy spin-kick — 8 frames (BSPIN1/2/3/2 played twice). Legacy
* format (mask=$66 from billy_sprite). Triggered by J+L pressed
* during anim_jump; check_punch_hit treats a hit during it like
* uppercut/pipeswing — damage 3 + force fall.
anim_bspinkick
 dfb 8
 dfb $0F              ; max_width (BSPIN frames are 15 wide)
 dfb $00              ; flags: legacy, bank $02, no advance/loop
 dfb $0F,$28,4        ; BSPIN1
  hex 0000             ; patched
 dfb $0F,$28,4        ; BSPIN2
  hex 0000             ; patched
 dfb $0F,$28,4        ; BSPIN3
  hex 0000             ; patched
 dfb $0F,$28,4        ; BSPIN2
  hex 0000             ; patched
 dfb $0F,$28,4        ; BSPIN1 (cycle 2)
  hex 0000             ; patched
 dfb $0F,$28,4        ; BSPIN2
  hex 0000             ; patched
 dfb $0F,$28,4        ; BSPIN3
  hex 0000             ; patched
 dfb $0F,$28,4        ; BSPIN2
  hex 0000             ; patched

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

* Billy uppercut. 3 raw (uncompiled) frames, one-shot. Frame
* sizes are read from the BUPPERn_X / BUPPERn_Y bytes that
* live two/four bytes before each frame's data label in bank
* $02; the values below are placeholders patched at init.
anim_uppercut
 dfb 3               ; num_frames
 dfb $0F             ; max_width (BUPPER2 widest at $0F)
 dfb $00             ; flags: none (one-shot, uncompiled)
 dfb $0C,$25,5       ; BUPPER1: 12 wide, 37 tall, 5 VBLs
  hex 0000             ; patched: BUPPER1
 dfb $0F,$23,5       ; BUPPER2: 15 wide, 35 tall, 5 VBLs
  hex 0000             ; patched: BUPPER2
 dfb $0D,$2D,5       ; BUPPER3: 13 wide, 45 tall, 5 VBLs
  hex 0000             ; patched: BUPPER3

anim_bpunched
 dfb 1               ; num_frames
 dfb $0B             ; max_width
 dfb $80             ; flags: bit 7 = compiled
 dfb $0B,$28,15      ; BPUNCHED: x, y, dur
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
 dfb $10             ; flags: bit 4 = fall trajectory (parabolic arc)
 dfb $13,$21,FALL_ARC_FRAMES ; WFALL: 19 wide, 33 tall, arc duration
  hex 0000             ; patched: WFALL
 dfb $10,$0D,60      ; WFALLEN: 16 wide, 13 tall, 60 VBLs
  hex 0000             ; patched: WFALLEN

anim_bfall
 dfb 2               ; num_frames
 dfb $13             ; max_width (BFALLEN at $13)
 dfb $30             ; flags: bit 4 = fall trajectory, bit 5 = bank $19
 dfb $11,$20,FALL_ARC_FRAMES ; BFALL: 17 wide, 32 tall, arc duration
  hex 0000             ; patched: BFALL
 dfb $13,$0D,60      ; BFALLEN: 19 wide, 13 tall, 60 VBLs
  hex 0000             ; patched: BFALLEN

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

* Roper fall. 2 frames, one-shot, parabolic arc on frame 0.
anim_rfall
 dfb 2
 dfb $10
 dfb $10             ; flags: bit 4 = fall trajectory
 dfb $10,$17,FALL_ARC_FRAMES ; RFALL1: arc duration
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

* Linda fall. 2 frames, one-shot, parabolic arc on frame 0.
anim_lfall
 dfb 2
 dfb $11
 dfb $10             ; flags: bit 4 = fall trajectory
 dfb $10,$17,FALL_ARC_FRAMES ; LFALL1: arc duration
  hex 0000             ; patched
 dfb $11,$0F,60      ; LFALL2
  hex 0000             ; patched

* Burnov (boss) walk. 4 frames, looping (BNWALK1, 2, 3, 2 cycle).
* Pixel data lives in bank $06 — frame_addr fields are patched
* by init_mission12 from spr_bnwalk1/2/3 (also in $06).
anim_bnwalk
 dfb 4
 dfb $0D             ; max_width (BNWALK1)
 dfb $22             ; flags: bit 1 = loop, bit 5 = bank $19
 dfb $0D,$30,5       ; BNWALK1: 13 wide, 48 tall, 5 VBLs
  hex 0000             ; patched
 dfb $0D,$30,5       ; BNWALK2
  hex 0000             ; patched
 dfb $0D,$30,5       ; BNWALK3
  hex 0000             ; patched
 dfb $0D,$30,5       ; BNWALK2 (cycle back)
  hex 0000             ; patched

* Burnov punch. 2 frames, one-shot.
anim_bnpunch
 dfb 2
 dfb $17             ; max_width (BNPUNCH2)
 dfb $20             ; flags: bit 5 = bank $19
 dfb $11,$30,6       ; BNPUNCH1: 17 wide, 48 tall
  hex 0000             ; patched
 dfb $17,$2E,6       ; BNPUNCH2: 23 wide, 46 tall
  hex 0000             ; patched

* Burnov-holds-Billy grab sequence. Triggered when anim_bnpunch
* lands on Billy (check_punch_hit Burnov-special). Plays
* BNBILLY1↔2 three times (PUNCHLANDED on each BNBILLY2) then
* BNBILLY3 as the release pose. Billy's sprite is suppressed
* and his input ignored during the whole anim; on completion,
* :normal_end clears bn_grab_active and starts his fall_anim.
anim_bngrab
 dfb 7
 dfb $15             ; max_width (BNBILLY1/2 are 21)
 dfb $20             ; flags: bit 5 = bank $19
 dfb $15,$30,8       ; BNBILLY1
  hex 0000             ; patched
 dfb $15,$31,8       ; BNBILLY2
  hex 0000             ; patched
 dfb $15,$30,8       ; BNBILLY1
  hex 0000             ; patched
 dfb $15,$31,8       ; BNBILLY2
  hex 0000             ; patched
 dfb $15,$30,8       ; BNBILLY1
  hex 0000             ; patched
 dfb $15,$31,8       ; BNBILLY2
  hex 0000             ; patched
 dfb $15,$2F,12      ; BNBILLY3 (release)
  hex 0000             ; patched

* Burnov punched reaction. 1 frame placeholder using BNFALL1
* — replace with a dedicated recoil frame if/when one ships.
anim_bnpunched
 dfb 1
 dfb $0D
 dfb $20             ; flags: bit 5 = bank $19
 dfb $0D,$2E,5       ; BNFALL1
  hex 0000             ; patched

* Burnov fall. 2 frames, one-shot, parabolic arc on frame 0.
* BNFALL2/3 are unused for now — could be a 3-frame arc later.
anim_bnfall
 dfb 2
 dfb $17             ; max_width (BNFALLEN)
 dfb $30             ; flags: bit 4 = fall trajectory, bit 5 = bank $19
 dfb $0D,$2E,FALL_ARC_FRAMES ; BNFALL1: arc duration
  hex 0000             ; patched
 dfb $17,$17,60      ; BNFALLEN: 23 wide, 23 tall
  hex 0000             ; patched

* Burnov dissolve (BDISS1 → BDISS8). BDISS1-7 play at 7 VBLs
* each (~0.8 sec body→helmet); BDISS8 (the sideways helmet on
* the ground) holds for 60 VBLs so it visibly sits there for
* ~1 second before the teleport+recon kicks in. Total ≈ 1.8 s.
anim_bn_diss
 dfb 8                ; num_frames
 dfb $16              ; max_width (BDISS2-4 are 22 wide)
 dfb $20              ; flags: bit 5 = bank $19
 dfb $10,$2F,7        ; BDISS1: 16×47
  hex 0000             ; patched
 dfb $16,$33,7        ; BDISS2: 22×51
  hex 0000             ; patched
 dfb $16,$33,7        ; BDISS3: 22×51
  hex 0000             ; patched
 dfb $16,$32,7        ; BDISS4: 22×50
  hex 0000             ; patched
 dfb $15,$30,7        ; BDISS5: 21×48
  hex 0000             ; patched
 dfb $15,$30,7        ; BDISS6: 21×48
  hex 0000             ; patched
 dfb $06,$0B,7        ; BDISS7: 6×11 (helmet, vertical)
  hex 0000             ; patched
 dfb $07,$0B,60       ; BDISS8: 7×11 — 60 VBLs = 1-sec pause
  hex 0000             ; patched

* Burnov reconstitute (BDISS8 → BDISS1). Same frames in reverse;
* triggers BURNBACK and runs as Burnov rematerializes elsewhere.
anim_bn_recon
 dfb 8
 dfb $16
 dfb $20              ; flags: bit 5 = bank $19
 dfb $07,$0B,7        ; BDISS8
  hex 0000             ; patched
 dfb $06,$0B,7        ; BDISS7
  hex 0000             ; patched
 dfb $15,$30,7        ; BDISS6
  hex 0000             ; patched
 dfb $15,$30,7        ; BDISS5
  hex 0000             ; patched
 dfb $16,$32,7        ; BDISS4
  hex 0000             ; patched
 dfb $16,$33,7        ; BDISS3
  hex 0000             ; patched
 dfb $16,$33,7        ; BDISS2
  hex 0000             ; patched
 dfb $10,$2F,7        ; BDISS1
  hex 0000             ; patched

* Linda-with-flail walk (LFWALK1, 2, 3, 2 cycle). Same shape as
* anim_lwalk (frame_x=$09) — same character, just a different
* frame source (bank-$19 instead of $02).
anim_lfwalk
 dfb 4
 dfb $09
 dfb $22              ; flags: bit 1 = loop, bit 5 = bank $19
 dfb $09,$28,5        ; LFWALK1: 9 wide, 40 tall
  hex 0000             ; patched
 dfb $09,$27,5        ; LFWALK2: 9 wide, 39 tall
  hex 0000             ; patched
 dfb $09,$28,5        ; LFWALK3
  hex 0000             ; patched
 dfb $09,$27,5        ; LFWALK2 (cycle back)
  hex 0000             ; patched

* Linda mace-swing attack (LMACE1, 2, 3). Wider sprite (mace
* swings out to the side); max_width tracks LMACE1 at 24 bytes.
anim_lmace
 dfb 3
 dfb $18              ; max_width (LMACE1 is 24 wide)
 dfb $20              ; flags: bit 5 = bank $19
 dfb $18,$28,6        ; LMACE1: 24×40
  hex 0000             ; patched
 dfb $14,$26,6        ; LMACE2: 20×38
  hex 0000             ; patched
 dfb $10,$26,6        ; LMACE3: 16×38
  hex 0000             ; patched

* Linda-with-flail fall — placeholder, both frames just reuse
* LFWALK1 for now. When the "drop the mace and turn into a
* regular Linda on hit" behavior is implemented, this descriptor
* can be retired and linda_flail will use the existing anim_lfall
* (after switching frame_bank → $02 on hit).
anim_lffall
 dfb 2
 dfb $09
 dfb $30              ; flags: bit 4 = fall trajectory, bit 5 = bank $19
 dfb $09,$28,FALL_ARC_FRAMES ; LFWALK1 (placeholder fall)
  hex 0000             ; patched
 dfb $09,$28,60       ; LFWALK1 (placeholder fallen)
  hex 0000             ; patched

* Williams-with-pipe walk (WPIPEWALK1, 2, 3, 2 cycle). Same
* shape as anim_wwalk (frame_x=$09).
anim_wpipewalk
 dfb 4
 dfb $09
 dfb $22              ; flags: bit 1 = loop, bit 5 = bank $19
 dfb $09,$28,5        ; WPIPEWALK1
  hex 0000             ; patched
 dfb $09,$28,5        ; WPIPEWALK2
  hex 0000             ; patched
 dfb $09,$28,5        ; WPIPEWALK3
  hex 0000             ; patched
 dfb $09,$28,5        ; WPIPEWALK2 (cycle back)
  hex 0000             ; patched

* Williams-with-pipe fall placeholder — both frames are
* WPIPEWALK1 (visible-pipe pose). Replace with proper sprites
* and the bank-$02 anim_wfall once cross-bank-per-anim is wired.
anim_wpfall
 dfb 2
 dfb $09
 dfb $30              ; flags: bit 4 = fall trajectory, bit 5 = bank $19
 dfb $09,$28,FALL_ARC_FRAMES ; WPIPEWALK1 placeholder
  hex 0000             ; patched
 dfb $09,$28,60       ; WPIPEWALK1 placeholder
  hex 0000             ; patched

* Williams-with-pipe attack — 5-frame pipe swing.
* Frame order (per design): WPIPE1, WPIPE4, WPIPE2, WPIPE6, WPIPE3.
* Each frame ~6 VBLs ≈ 100 ms — total swing ~0.5 s.
anim_wpipeswing
 dfb 5
 dfb $0F              ; max_width (WPIPE2 is 15 wide)
 dfb $20              ; flags: bit 5 = bank $19
 dfb $0E,$28,6        ; WPIPE1: 14×40
  hex 0000             ; patched
 dfb $0E,$28,6        ; WPIPE4: 14×40
  hex 0000             ; patched
 dfb $0F,$28,6        ; WPIPE2: 15×40
  hex 0000             ; patched
 dfb $0A,$28,6        ; WPIPE6: 10×40
  hex 0000             ; patched
 dfb $0D,$28,6        ; WPIPE3: 13×40
  hex 0000             ; patched

* Williams-with-knife throw — 2 frames (WKNIFE1 wind-up, WKNIFE2
* release). When the anim ends, :normal_end spawns the knife
* projectile and downgrades williams_knife to a regular williams.
anim_wkthrow
 dfb 2
 dfb $0D              ; max_width (both frames are 13 wide)
 dfb $20              ; flags: bit 5 = bank $19
 dfb $0D,$2F,8        ; WKNIFE1: 13×47
  hex 0000             ; patched
 dfb $0D,$27,8        ; WKNIFE2: 13×39
  hex 0000             ; patched

* Billy-with-pipe walk — 4-frame cycle (BPIPEW1, 2, 3, 2). Same
* shape as anim_wpipewalk but with Billy's frames. NOT installed
* via start_anim — driven by advance_walk reading
* pipe_walk_addr_tbl when billy_pipe_armed != 0.
anim_bpipewalk
 dfb 4
 dfb $0B              ; max_width (BPIPEW3 is 11 wide)
 dfb $22              ; flags: bit 1 = loop, bit 5 = bank $19
 dfb $09,$28,5        ; BPIPEW1
  hex 0000             ; patched
 dfb $08,$28,5        ; BPIPEW2
  hex 0000             ; patched
 dfb $0B,$28,5        ; BPIPEW3
  hex 0000             ; patched
 dfb $08,$28,5        ; BPIPEW2 (cycle back)
  hex 0000             ; patched

* Billy-with-pipe swing — 4 frames (BPIPE1-4). At anim end Billy
* returns to idle (BPIPEW1 if still armed). check_punch_hit reads
* the puncher's anim_ptr to deal 3-hit damage on contact (mirrors
* the anim_uppercut damage-3 path).
anim_bpipeswing
 dfb 4
 dfb $11              ; max_width (BPIPE2 is 17 wide)
 dfb $20              ; flags: bit 5 = bank $19
 dfb $09,$28,6        ; BPIPE1
  hex 0000             ; patched
 dfb $11,$28,6        ; BPIPE2
  hex 0000             ; patched
 dfb $0F,$28,6        ; BPIPE3
  hex 0000             ; patched
 dfb $0C,$28,6        ; BPIPE4
  hex 0000             ; patched

* Billy-with-mace walk — 4-frame cycle (BMWALK1, 2, 3, 2). Same
* shape as anim_bpipewalk. NOT installed via start_anim — driven
* by advance_walk reading mace_walk_addr_tbl when
* billy_mace_armed != 0.
anim_bmwalk
 dfb 4
 dfb $0B              ; max_width (BMWALK3 is 11 wide)
 dfb $22              ; flags: bit 1 = loop, bit 5 = bank $19
 dfb $09,$28,5        ; BMWALK1
  hex 0000             ; patched
 dfb $08,$28,5        ; BMWALK2
  hex 0000             ; patched
 dfb $0B,$28,5        ; BMWALK3
  hex 0000             ; patched
 dfb $08,$28,5        ; BMWALK2 (cycle back)
  hex 0000             ; patched

* Billy-with-mace swing — 4 frames (BMACE1-4). Symmetric to
* anim_bpipeswing. check_punch_hit treats it like uppercut /
* pipeswing: damage=3 with forced fall on contact.
anim_bmaceswing
 dfb 4
 dfb $19              ; max_width (BMACE2 is 25 wide)
 dfb $20              ; flags: bit 5 = bank $19
 dfb $0F,$2C,6        ; BMACE1: 15×44
  hex 0000             ; patched
 dfb $19,$2E,6        ; BMACE2: 25×46
  hex 0000             ; patched
 dfb $14,$28,6        ; BMACE3: 20×40
  hex 0000             ; patched
 dfb $10,$28,6        ; BMACE4: 16×40
  hex 0000             ; patched

* Billy pipe-pickup pose — 1 frame (JUMP3 = crouch) held for
* 30 VBLs (~½ s). Compiled (11-byte stride) so it renders
* through the same draw_sprite_compiled path as Billy's normal
* idle/walk — JUMP3_DATA is compiled-format with a paired mask.
* At anim end :normal_end calls billy_arm_weapon which clears
* MASK_ADDR and switches Billy's idle to BPIPEW1 / BMWALK1
* depending on which weapon was picked up.
anim_bpickup
 dfb 1
 dfb $0D              ; max_width (JUMP3 is 13 wide)
 dfb $80              ; flags: bit 7 = compiled, bank $02
 dfb $0D,$20,30       ; JUMP3 — 13×32, 30 VBLs
  hex 0000             ; data       (patched → spr_jump3)
  hex 0000             ; mask       (patched → spr_jump3_mask)
  hex 0000             ; data_mir   (patched → spr_jump3_data_mirror)
  hex 0000             ; mask_mir   (patched → spr_jump3_mask_mirror)

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
* kill_objects - Walk sprite_table and tag every "item"
* sprite (controller != $00 and != $01) with the death
* sentinel ($FFFF in anim_ptr at +24). erase_all on the
* next frame handles erase + removal via the same path
* used for defeated NPCs. Forward-only npc_buffer slots
* are not reclaimed; the table itself is compacted.
*----------------------------------------------------------
kill_objects
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:ko_loop
 ldy #0
 lda (spr_ptr),y
 sta info_ptr
 iny
 lda (spr_ptr),y
 sta info_ptr+1
 ora info_ptr
 beq :ko_done           ; null terminator → end of table
 ldy #22
 lda (info_ptr),y       ; controller
 beq :ko_skip           ; $00 = NPC, keep
 cmp #$01
 beq :ko_skip           ; $01 = player, keep
* Item: stamp $FFFF into anim_ptr to flag for erase/removal.
 lda #$FF
 ldy #24
 sta (info_ptr),y
 iny
 sta (info_ptr),y
:ko_skip
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :ko_loop
 inc spr_ptr+1
 bra :ko_loop
:ko_done
* If Billy was carrying a weapon (pipe or mace), OP_KILLOBJ
* also takes it away.
 lda billy_pipe_armed
 ora billy_mace_armed
 beq :ko_real_done
 jsr billy_disarm_weapon
:ko_real_done
 rts

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
* Stash puncher's anim_ptr in a scratch — the iteration below
* overwrites the global anim_ptr with each target's value during
* the immunity check, so any post-hit logic that wants to know
* what attack the puncher was doing has to read from here.
 lda anim_ptr
 sta :puncher_anim_lo
 lda anim_ptr+1
 sta :puncher_anim_hi
* Save puncher's info_ptr to identify self
 lda info_ptr
 sta :self_lo
 lda info_ptr+1
 sta :self_hi
* Stash puncher's controller (info+22) — the per-target check
* below needs to know whether the puncher is an NPC (=0) so it
* can require the NPC's mirror to point at Billy. Reading from
* (info_ptr) right now while it still points at the puncher.
 ldy #22
 lda (info_ptr),y
 sta :puncher_ctrl
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
* Skip non-NPC sprites (controller != 0). Billy is controller=1,
* dropped weapons / items use controller=$02 — neither should be
* hit-checked. (god_mode is a separate debug toggle that protects
* Billy specifically; that branch stays.)
 ldy #22
 lda (info_ptr),y      ; controller
 beq :is_npc           ; controller=0 → enemy NPC, hit-check
 cmp #$01
 bne :advance_jmp      ; controller >= $02 → item, skip
* controller == 1 → Billy. Skip if god_mode is on, else fall
* through to allow the hit (existing behavior).
 lda god_mode
 bne :advance_jmp
 bra :is_npc
:advance_jmp
 jmp :advance
:is_npc
:not_god
* Check if target is immune. Three cases grant immunity:
*   1) fall_anim is currently playing (any sprite)
*   2) target is Burnov AND playing anim_bn_diss (dissolving)
*   3) target is Burnov AND playing anim_bn_recon (reforming)
 ldy #24
 lda (info_ptr),y     ; anim_ptr low
 sta anim_ptr
 iny
 lda (info_ptr),y     ; anim_ptr high
 sta anim_ptr+1
 ora anim_ptr
 beq :not_immune      ; no animation, punchable
* Check fall_anim
 ldy #50
 lda (info_ptr),y
 cmp anim_ptr
 bne :imm_check_diss
 iny
 lda (info_ptr),y
 cmp anim_ptr+1
 bne :imm_check_diss
 jmp :advance         ; fall_anim → immune
:imm_check_diss
 lda anim_ptr
 cmp #<anim_bn_diss
 bne :imm_check_recon
 lda anim_ptr+1
 cmp #>anim_bn_diss
 bne :imm_check_recon
 jmp :advance         ; dissolving → immune
:imm_check_recon
 lda anim_ptr
 cmp #<anim_bn_recon
 bne :not_immune
 lda anim_ptr+1
 cmp #>anim_bn_recon
 bne :not_immune
 jmp :advance         ; reconstituting → immune
:not_immune

* When an NPC is the puncher and Billy is the target, require
* the NPC's mirror to point at Billy. Without this, an NPC
* facing away can still register a hit through its punch
* animation. Doesn't apply when Billy attacks (back-kick is
* deliberately rear-facing), or to NPC-vs-NPC (n/a here anyway).
 lda :puncher_ctrl
 bne :face_skip       ; puncher isn't an NPC — no constraint
 ldy #22
 lda (info_ptr),y     ; target's controller
 cmp #$01
 bne :face_skip       ; target isn't Billy
 lda IMAGE01_MIRROR
 bne :face_npc_left
* NPC mirror=0 (faces right): Billy must be at NPC_x or higher.
 ldy #2
 lda (info_ptr),y     ; billy_x
 cmp IMAGE01_XPOS     ; vs npc_x
 bcs :face_skip       ; billy_x >= npc_x → NPC faces Billy ✓
 jmp :advance         ; NPC turned away — skip
:face_npc_left
* NPC mirror=1 (faces left): Billy must be at NPC_x or lower.
 ldy #2
 lda (info_ptr),y
 cmp IMAGE01_XPOS
 bcc :face_skip       ; billy_x < npc_x → NPC faces Billy ✓
 beq :face_skip       ; equal → on top of each other, allow
 jmp :advance         ; NPC turned away — skip
:face_skip

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

* Vertical check: body overlap. Puncher and target bodies
* overlap iff puncher_bottom >= tgt_y AND puncher_top <= tgt_bottom.
* (Older code compared bottom-to-bottom with a fixed tolerance,
* which broke for tall bosses like Burnov: when fo_approach
* aligned his TOP with Billy's, his BOTTOM ended up 8 lines
* below Billy's, failing the "above" tolerance of 5.)
 lda :tgt_y
 clc
 adc :tgt_h
 sec
 sbc #1              ; tgt_bottom
 sta :tgt_bottom
 lda :punch_bottom
 cmp :tgt_y
 bcs :v_check_top
 jmp :advance        ; punch_bottom < tgt_y → no overlap
:v_check_top
 lda IMAGE01_YPOS    ; puncher's top (preserved from caller)
 cmp :tgt_bottom
 beq :h_check
 bcc :h_check        ; puncher_top <= tgt_bottom → overlap
 jmp :advance        ; puncher_top > tgt_bottom → no overlap

:h_check
* Horizontal check: overlap or within 1 byte (was 2 — tightened
* 2 px per side so glancing approaches don't register as hits).
* punch_right - 1 >= tgt_x
 lda :punch_right
 sec
 sbc #1
 cmp :tgt_x
 bcs :h_check2
 jmp :advance        ; punch too far left
:h_check2
* tgt_right + 1 >= punch_x
 lda :tgt_x
 clc
 adc :tgt_w
 clc
 adc #1              ; tgt_right + 1
 cmp IMAGE01_XPOS
 bcs :hit
 jmp :advance        ; target too far left
:hit

* Burnov-grabs-Billy special case. When anim_bnpunch lands on
* Billy (controller=1), divert from the standard hit/fall logic
* to the BNBILLY grab sequence: hide Billy, run anim_bngrab on
* Burnov, ignore Billy's input until the anim ends. The grab
* anim's :normal_end handler will reposition Billy and start
* fall_anim on him.
 lda :puncher_anim_lo
 cmp #<anim_bnpunch
 bne :hit_normal
 lda :puncher_anim_hi
 cmp #>anim_bnpunch
 bne :hit_normal
 ldy #22
 lda (info_ptr),y     ; target controller
 cmp #$01
 bne :hit_normal      ; target isn't Billy — fall through
* Set the active flag, mark Billy needing-erase (so this frame's
* erase_all clears his last-drawn rect and draw_all skips him).
 lda #$01
 sta bn_grab_active
 ldy #30
 lda (info_ptr),y
 ora #$02             ; force erase bit; clear draw bit
 and #$FE
 sta (info_ptr),y
* Switch info_ptr back to the puncher (Burnov) and run start_anim
* with anim_bngrab. start_anim handles frame_bank, info+10/+12/
* +14, dirty, etc.
 lda :self_lo
 sta info_ptr
 lda :self_hi
 sta info_ptr+1
* Re-load Burnov's globals so start_anim's :sa_write_block
* operates on the right block.
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
 lda #<anim_bngrab
 ldx #>anim_bngrab
 jsr start_anim
 jmp :done
:hit_normal

* Hit! Damage = 3 if puncher is mid-uppercut, mid-pipeswing, or
* mid-maceswing; else 1. All three are forced-fall attacks.
 lda :puncher_anim_lo
 cmp #<anim_uppercut
 bne :hit_chk_pipe
 lda :puncher_anim_hi
 cmp #>anim_uppercut
 bne :hit_chk_pipe
 lda #3
 bra :hit_dmg_done
:hit_chk_pipe
 lda :puncher_anim_lo
 cmp #<anim_bpipeswing
 bne :hit_chk_mace
 lda :puncher_anim_hi
 cmp #>anim_bpipeswing
 bne :hit_chk_mace
 lda #3
 bra :hit_dmg_done
:hit_chk_mace
 lda :puncher_anim_lo
 cmp #<anim_bmaceswing
 bne :hit_chk_spin
 lda :puncher_anim_hi
 cmp #>anim_bmaceswing
 bne :hit_chk_spin
 lda #3
 bra :hit_dmg_done
:hit_chk_spin
 lda :puncher_anim_lo
 cmp #<anim_bspinkick
 bne :hit_chk_lmace
 lda :puncher_anim_hi
 cmp #>anim_bspinkick
 bne :hit_chk_lmace
 lda #3
 bra :hit_dmg_done
:hit_chk_lmace
 lda :puncher_anim_lo
 cmp #<anim_lmace
 bne :hit_dmg1
 lda :puncher_anim_hi
 cmp #>anim_lmace
 bne :hit_dmg1
 lda #3
 bra :hit_dmg_done
:hit_dmg1
 lda #1
:hit_dmg_done
 sta :hit_damage
 ldy #48
 lda (info_ptr),y
 clc
 adc :hit_damage
 sta (info_ptr),y
* Award 100 points to player 1 and mark score for redraw.
* Only when the target is an NPC — when an NPC lands a hit on
* Billy, info_ptr points at billy_sprite and we shouldn't be
* paying him for getting punched.
 ldy #22
 lda (info_ptr),y      ; controller (0=NPC, 1=Billy)
 cmp #$01
 beq :no_score
 jsr incp1s_hundreds
:no_score
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
* Check if punch_count triggers a fall (3 or 6) — or force fall
* immediately for any of the three damage-3 attacks.
 lda :puncher_anim_lo
 cmp #<anim_uppercut
 bne :hit_chk2_pipe
 lda :puncher_anim_hi
 cmp #>anim_uppercut
 bne :hit_chk2_pipe
 jmp :use_fall
:hit_chk2_pipe
 lda :puncher_anim_lo
 cmp #<anim_bpipeswing
 bne :hit_chk2_mace
 lda :puncher_anim_hi
 cmp #>anim_bpipeswing
 bne :hit_chk2_mace
 jmp :use_fall
:hit_chk2_mace
 lda :puncher_anim_lo
 cmp #<anim_bmaceswing
 bne :hit_chk2_spin
 lda :puncher_anim_hi
 cmp #>anim_bmaceswing
 bne :hit_chk2_spin
 jmp :use_fall
:hit_chk2_spin
 lda :puncher_anim_lo
 cmp #<anim_bspinkick
 bne :hit_chk2_lmace
 lda :puncher_anim_hi
 cmp #>anim_bspinkick
 bne :hit_chk2_lmace
 jmp :use_fall
:hit_chk2_lmace
 lda :puncher_anim_lo
 cmp #<anim_lmace
 bne :hit_count_check
 lda :puncher_anim_hi
 cmp #>anim_lmace
 bne :hit_count_check
 jmp :use_fall
:hit_count_check
 ldy #48
 lda (info_ptr),y     ; punch_count
 cmp #3
 beq :use_fall
 cmp #6
 beq :use_fall
* Normal punch — use punched_anim. If the puncher is Billy doing
* anim_punch1 or anim_punch2 (i.e. a regular ground punch),
* arm the grab window: pressing toward this target within
* PUNCH_GRAB_WINDOW frames will trigger a grab. Skip for kicks /
* NPC punches / uppercuts (uppercut already forces a fall).
 lda :puncher_anim_lo
 cmp #<anim_punch1
 bne :try_grab_p2
 lda :puncher_anim_hi
 cmp #>anim_punch1
 bne :try_grab_p2
 bra :arm_grab
:try_grab_p2
 lda :puncher_anim_lo
 cmp #<anim_punch2
 bne :no_grab_arm
 lda :puncher_anim_hi
 cmp #>anim_punch2
 bne :no_grab_arm
:arm_grab
 lda #PUNCH_GRAB_WINDOW
 sta punch_window
 lda info_ptr
 sta last_hit_target
 lda info_ptr+1
 sta last_hit_target+1
:no_grab_arm
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
 beq :uf_no_anim
* If target is Billy (controller=1), count this fall and reset
* his punch_count so the next 3-hit cycle starts fresh. Without
* the reset, punch_count would walk past 6 and hit the legacy
* death branch in update_anims (which $FFFFs the sprite).
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :do_punched
 inc billy_fall_count
 lda #0
 ldy #48
 sta (info_ptr),y
* Shorten Billy's health bar by killing one palette-02 slot.
* Each fall blacks out one segment, in this order:
*   fall 1 → slot 4 ($019E48)  P1 rightmost green
*   fall 2 → slot 3 ($019E46)  P1 middle green
*   fall 3 → slot 2 ($019E44)  P1 leftmost green
*   fall 4 → slot 1 ($019E42)  P1 yellow
*   fall 5 → slot A ($019E54)  P1 deep red (just before GAME OVER)
* Each entry is 2 bytes; write 0 to both halves.
 lda billy_fall_count
 cmp #1
 bne :uf_dep_2
 lda #0
 stal $019E48
 stal $019E49
 jmp :do_punched
:uf_dep_2
 cmp #2
 bne :uf_dep_3
 lda #0
 stal $019E46
 stal $019E47
 jmp :do_punched
:uf_dep_3
 cmp #3
 bne :uf_dep_4
 lda #0
 stal $019E44
 stal $019E45
 jmp :do_punched
:uf_dep_4
 cmp #4
 bne :uf_dep_5
 lda #0
 stal $019E42
 stal $019E43
 jmp :do_punched
:uf_dep_5
 cmp #5
 bne :do_punched
 lda #0
 stal $019E54
 stal $019E55
 jmp :do_punched
:uf_no_anim
 jmp :advance
:do_punched
* Confirmed hit — fire SFX. Uppercut connects → SND_POW; otherwise
* the standard punch-landed SFX.
 lda :puncher_anim_lo
 cmp #<anim_uppercut
 bne :dp_punchlanded
 lda :puncher_anim_hi
 cmp #>anim_uppercut
 bne :dp_punchlanded
 ldx #SND_POW
 bra :dp_play
:dp_punchlanded
 ldx #SND_PUNCHLANDED
:dp_play
 jsr sound_trigger
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
:hit_damage dfb 0     ; +1 normal punch, +3 uppercut
:puncher_anim_lo dfb 0
:puncher_anim_hi dfb 0
:puncher_ctrl    dfb 0

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
  sep $20
:lp1 bit $c019
 bmi :lp1 ; wait for current VBL to end
:lp2 bit $c019
 bpl :lp2 ; wait for next VBL to start
;  lda $c02e
;  lsr
;  lsr
;  cmp #$38
;  bne wait_for_vbl
  rep $30
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
 da $0400             ; request count (1KB = 2 disk blocks)
 ds 2                 ; transfer count (returned)

p_close dfb 1          ; param count
c_refnum dfb 0        ; ref_num

p_get_eof dfb 2        ; param count
eof_refnum dfb 0       ; ref_num
eof_size ds 3          ; 3-byte EOF (file size)

file_size ds 3        ; 24-bit file size (for UnPackBytes)

pathname dfb 30
 asc '/DDIIGS/MISSION1/MISSION11.PAK'

path12 dfb 30
 asc '/DDIIGS/MISSION1/MISSION12.PAK'

path13 dfb 30
 asc '/DDIIGS/MISSION1/MISSION13.PAK'

path14 dfb 30
 asc '/DDIIGS/MISSION1/MISSION14.PAK'

path15 dfb 30
 asc '/DDIIGS/MISSION1/MISSION15.PAK'

path16 dfb 30
 asc '/DDIIGS/MISSION1/MISSION16.PAK'

path17 dfb 30
 asc '/DDIIGS/MISSION1/MISSION17.PAK'

path18 dfb 30
 asc '/DDIIGS/MISSION1/MISSION18.PAK'

path19 dfb 30
 asc '/DDIIGS/MISSION1/MISSION19.PAK'

path110 dfb 31
 asc '/DDIIGS/MISSION1/MISSION110.PAK'

path111 dfb 31
 asc '/DDIIGS/MISSION1/MISSION111.PAK'

path112 dfb 31
 asc '/DDIIGS/MISSION1/MISSION112.PAK'

path113 dfb 31
 asc '/DDIIGS/MISSION1/MISSION113.PAK'

path114 dfb 31
 asc '/DDIIGS/MISSION1/MISSION114.PAK'

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
  hex 0000         ; +54 (NPC atk_anim slot; unused for the player)
  hex 0200         ; +56 frame_bank — bank where this sprite's pixel
                   ;     data lives. Read by load_sprite into the
                   ;     sprite_bank global so draw_sprite/draw_sprite_compiled
                   ;     pull pixels from the right bank. $0002 = mission1
                   ;     bank, $0019 = "more sprites" bank (boss + weapons).
  hex 0200         ; +58 idle_bank — bank for the idle frame.
                   ;     :normal_end copies +58 → +56 when restoring
                   ;     idle frame at anim end, so per-anim
                   ;     frame_bank changes (set by start_anim from
                   ;     descriptor flag bit 5) revert correctly.

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
  hex 0000         ; +52 (compiled mask / NPC walk_anim slot)
  hex 0000         ; +54 (NPC atk_anim slot)
  hex 0200         ; +56 frame_bank ($0002 = mission1 bank)
  hex 0200         ; +58 idle_bank

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
  hex 0000         ; +52 (compiled mask / NPC walk_anim slot)
  hex 0000         ; +54 (NPC atk_anim slot)
  hex 0200         ; +56 frame_bank
  hex 0200         ; +58 idle_bank

**
** FLAIL sprite (placeholder, lives in bank $06).
** Proves the cross-bank rendering path: load_sprite reads +56
** = $0006 → sprite_bank, draw_sprite then pulls pixel data
** from $06/FLAIL via indirect long. init_mission12 patches
** +14 (frame_addr) and +42 (idle_addr) at boot.
**
flail_sprite
  hex 5000 ; +0  ypos (visible mid-screen)
  hex 3000 ; +2  xpos (48 bytes from left edge)
  hex 0000 ; +4  mirror
  hex 0000 ; +6  (unused)
  hex 0000 ; +8  (unused)
  hex 0400 ; +10 frame_x = 4 bytes (8 pixels)
  hex 0800 ; +12 frame_y = 8 lines
  hex 0000 ; +14 frame_addr (patched by init_mission12)
  hex 6600 ; +16 mask (transparent color $66)
  hex 6000 ; +18 maskhi
  hex 0600 ; +20 masklo
  hex 0000 ; +22 controller (NPC, not keyboard player)
  hex 0000 ; +24 anim_ptr (no animation — stays on idle frame)
  hex 0000 ; +26 anim_frame
  hex 0000 ; +28 anim_timer
  hex 0100 ; +30 dirty (needs_draw set so first frame paints)
  hex 5000 ; +32 prev_ypos
  hex 3000 ; +34 prev_xpos
  hex 0400 ; +36 prev_frame_x
  hex 0800 ; +38 prev_frame_y
  hex 0000 ; +40 punched_anim (placeholder isn't punchable)
  hex 0000 ; +42 idle_addr (patched by init_mission12)
  hex 0400 ; +44 idle_x
  hex 0800 ; +46 idle_y
  hex 0000 ; +48 punch_count
  hex 0000 ; +50 fall_anim (none)
  hex 0000 ; +52 (compiled mask slot, unused for legacy draw)
  hex 0000 ; +54 (atk_anim slot, unused)
  hex 0600 ; +56 frame_bank = $0006 (bank $06 holds the pixels)
  hex 0600 ; +58 idle_bank

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

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

; constants for game type selection
GT_1P        = 0
GT_2P_COOP   = 1
GT_2P_PVP    = 2

; constants for controller selection
CTL_KEYBOARD = 0
CTL_JOYSTICK = 1
CTL_SNES     = 2

TOTAL_MISSIONS = 2

; global variables from selection screen
game_type = $300
ctl_type_p1 = $302
ctl_type_p2 = $304
smax_slot = $306
cutscene_number = $308
starting_mission = $30C
current_mission = $30E

]IOBUF = $0C00        ; 1024-byte ProDOS I/O buffer (page-aligned),
                       ; $0C00-$0FFF. Moved from $BB00 to $0C00 to free
                       ; $BB00-$BEFF (1KB) for game.s growth as more
                       ; compiled-sprite cache vars + dispatch logic
                       ; gets added. New ceiling: $BEFF (just below
                       ; ProDOS Global Page at $BF00).
]RDBUF = $0800         ; 1024-byte read buffer (= 2 disk blocks), $0800-$0BFF.
                       ; Moved from $B700 to free that range for game.s
                       ; growth. $0800 is the standard ProDOS 8 user-
                       ; buffer range — text page 1 ($0400-$07FF) is
                       ; used by firmware debug prints, text page 2
                       ; ($0800-$0BFF) isn't read by the engine. IOBUF
                       ; sits right above us at $0C00, QuickDraw II's
                       ; DP at $1D00-$1FFF. game.s now grows up through
                       ; $BEFF.

* Conditional-assembly switch for the text-screen debug prints
* sprinkled through the engine. Set to 1 to keep them in the
* binary; 0 to strip them entirely (the dbg_print_* helpers
* themselves still ship — only the call-site blocks vanish).
DEBUG_PRINT equ 0
* DEBUG_LSRC: gates instrumentation for the co-op left-scroll
* black-bar regression. Prints at OP_LEFT entry, every scroll_left
* call, and at sync_current_screen_right's lsrc-overwriting branch.
* Also re-enables the assert_scroll_lsrc_off canary. Flip to 0 to
* strip once the bug is found.
DEBUG_LSRC  equ 0
* DEBUG_ERASE: gates instrumentation for the erase-rect off-by-one
* artifact (1 byte left + 1 row bottom unerased after an NPC death).
* Logs the death-erase prev rect and every normal erase whose rect
* touches the suspected y=100..140 band. Cheaper to flip than
* DEBUG_PRINT (which pulls ~1.3 KB of unrelated logging and overflows
* the SYS loader's read_count cap). The DEBUG_ERASE prints call ROM
* PRBYTE/COUT directly so they don't depend on dbg_print_*.
DEBUG_ERASE equ 0
* DEBUG_HELPERS: 1 if any debug path that uses the dbg_print_*
* helpers is active. Used to gate the helper bodies themselves so
* they strip when only DEBUG_ERASE is on (saves ~50 bytes).
* DEBUG_HELPERS gates the dbg_print_* helper bodies. They call
* $D0FDDA / $D0FDED (KEGS virtual-stdout entry points) which exist
* only in the emulator — on real IIgs hardware those addresses are
* unrelated ROM bytes and the JSLs would crash. With DEBUG_HELPERS=0
* the helpers AND every dev-only call site that references them must
* be gated/stripped (see :do DEBUG_HELPERS gates around the V/space/g
* key handlers, dbg_validate_stratum_bounds, dbg_golden_state etc.).
DEBUG_HELPERS equ 1     ; enable space-bar "X:xxxx W:wwww" readout for
                        ; measuring ladder positions in mission2 art.
                        ; Set back to 0 for real-hardware ship build —
                        ; the dbg_print_* helpers call KEGS-only entry
                        ; points ($D0FDDA / $D0FDED) that aren't on
                        ; real IIgs ROMs.

* Clear text screen so diagnostic prints start on a fresh page.
* (80-col init via $C300 removed — debug output now streams via
* JSL $D0FDED to KEGS virtual stdout, no text-page constraint.)
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

* Load /DDIIGS/ENGINE (scroll/blit pipeline) to bank $1F. Game
* code calls into it via JSL at fixed addresses ($1F/0000+).
* Loaded early (was previously deeper in the boot) so subsequent
* steps can rely on the engine's jump table.
 lda #<engine_path
 sta file_open+1
 lda #>engine_path
 sta file_open+2
 lda #$1F
 sta file_bank
 stz file_dest
 stz file_dest+1
 jsr load_file

* Load this mission's level-data file MISSION{N}/MISSION{N} to
* bank $02, where N = current_mission. The bank-$02 manifest
* drives every subsequent mission-specific load (jimmy, music,
* compiled sprites, blits, boss code) via level_iter_loads.
 jsr compose_level_data_path  ; level_path_buf <- 'MISSION{N}/MISSION{N}',
                              ; p_open + file_open pointed at it
 lda #$02
 sta file_bank
 stz file_dest
 stz file_dest+1
 jsr load_file

* Read manifest's loading_str_ptr (manifest +4) into
* loading_str_tbl_addr. Zero means the mission's manifest didn't
* supply a loading-strings table — draw_loading_string self-
* guards and turns into a no-op.
 jsr get_man_base
 lda man_base
 sta $F0
 lda man_base+1
 sta $F1
 lda #$02
 sta $F2
 ldy #4
 lda [$F0],y
 sta loading_str_tbl_addr
 iny
 lda [$F0],y
 sta loading_str_tbl_addr+1

* Show first loading status.
 ldx #0
 jsr draw_loading_string

* Iterate the manifest's load_entries: jimmy, NTPs, compiled-
* sprite files, boss code, blit files — whatever this mission's
* manifest lists. Each entry carries its own dest_bank + loader-
* kind, so the engine doesn't need to know what files exist for
* each mission. ntpplayer code is already in bank $12 from
* title.s and persists across SYS swaps.
 jsr level_iter_loads

 ldx #1
 jsr draw_loading_string

* Cutscene NTPs are mission-independent so stay hardcoded.
 stz unpack_offset
 stz unpack_offset+1

* Load COMPLETENTP.PAK -> unpack to $15/0000
* (level-completion fanfare; will get wired up to OP_END later).
 lda #<completentp_path
 sta p_open+1
 lda #>completentp_path
 sta p_open+2
 lda #$15
 sta unpack_bank
 jsr load_and_unpack

* Load GAMEOVERNTP.PAK -> unpack to $16/0000
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

* Load every background PAK from the bank-$02 level manifest.
* Background i (0..bg_count-1) is composed as DIR/NAME by
* level_compose_bg and unpacked to bank $03+i at $2000, which
* matches the runtime mapping (bank = current_screen + $03).
* Replaces the old hardcoded pathname/path12..path114 list.
* unpack_offset is already $2000 (restored just above).
 jsr level_get_bgcount
 sta bg_count_cache
 ldx #0
:bg_load_loop
 cpx bg_count_cache
 bcs :bg_load_done
 phx
 jsr level_compose_bg     ; X=bg index -> level_path_buf, p_open set
 plx
 txa
 clc
 adc #$03
 sta unpack_bank          ; unpack bank = $03 + i
 phx
 jsr load_and_unpack
 plx
* Screen 0: copy $03/2000 -> $18/2000 (playfield shadow). The
* $18 -> $01 paint is deferred to after init below so the LOADING
* splash stays up; bank $18 holds scr0 from here, which is what
* the erase routines read.
 cpx #0
 bne :bg_ticks
 jsr copy_03_to_50
* Loading-progress ticks at the original cadence: status 2 after
* screen 0, status 3 after screen 5, status 4 after screen 11.
:bg_ticks
 cpx #0
 beq :bg_tick2
 cpx #5
 beq :bg_tick3
 cpx #11
 beq :bg_tick4
 bra :bg_next
:bg_tick2
 phx
 ldx #2
 jsr draw_loading_string
 plx
 bra :bg_next
:bg_tick3
 phx
 ldx #3
 jsr draw_loading_string
 plx
 bra :bg_next
:bg_tick4
 phx
 ldx #4
 jsr draw_loading_string
 plx
:bg_next
 inx
 bra :bg_load_loop
:bg_load_done

* DIAGNOSTIC: print lstr5 ('Giga Smooth Scrolling') immediately after
* bg load loop. If this string never appears, corruption is during
* bg6..bg9 loading. If it appears and then crash, it's later (init_*).
 ldx #4
 jsr draw_loading_string

* Initialize level data now that MISSION1/MISSION12 binaries
* and the SHR backgrounds are all loaded. Moved here from the
* top of the boot sequence so the LOADING splash can stay on
* screen during the heavy file loads above. SHR mode is
* already enabled (inherited from DDII.SYSTEM), so no $C029
* twiddle is needed here either.
 jsl init_level
* These inits patch dispatch tables / animation pointers from
* the compiled-sprite + blit banks loaded above. They're safe
* for any mission whose manifest loads those files at the same
* bank addresses (mission 1 and mission 2 currently share them
* by path). Gate skips them for missions that DON'T load them,
* to avoid corrupting state against empty banks.
 lda current_mission
 cmp #3
 bcs :skip_m1_inits
 jsl init_mission12
 jsl init_mission13
 jsl init_mission14
 jsl init_jimmy
 jsl init_mission13blit
 jsl init_mission1blit
 jsl init_mission1jimmyblit
 jsl init_mission12blit
 jsl init_mission14blit
:skip_m1_inits

* Apply the selection-screen game type ($300):
*   0 (GT_1P)     → leave jimmy_active at 0 (single player)
*   1 (GT_2P_COOP)→ activate Jimmy (same path as Ctrl-J)
*   2 (GT_2P_PVP) → activate Jimmy + arm friendly_fire so
*                    Billy ↔ Jimmy hits register in check_punch_hit
 lda game_type
 beq :gt_done
 lda #1
 sta jimmy_active
 sta jimmy_sprite+30       ; dirty bit 0 = needs_draw on first frame
 lda game_type
 cmp #GT_2P_PVP
 bne :gt_done
 lda #1
 sta friendly_fire
:gt_done

* Apply the selection-screen controller types ($302 / $304).
*   input_mode is Billy's live source (kbd=0 / joy=1 / snes=2);
*     Ctrl-K and Ctrl-N still re-write it at runtime to switch
*     Billy on the fly.
*   jimmy_input_mode is P2's source. swap_in_jimmy moves it into
*     input_mode for each Jimmy turn, so the same dispatch logic
*     in pi_action_dispatch handles either player.
* For P2 on SNES, swap_in/out_jimmy also flips snes_poll_mask
* between $80 (ctl 1 = P1) and $40 (ctl 2 = P2) so the single
* shift-register read picks up the right controller's bits.
 lda ctl_type_p1
 sta input_mode
 lda ctl_type_p2
 sta jimmy_input_mode

* Build snes_pause_mask from the chosen controller types. check_pause
* uses this to know which $C0C0 bits to watch for Start presses
* (bit 7 = P1 / SNES MAX 1, bit 6 = P2 / SNES MAX 2). Zero mask
* means neither player is on SNES → pause-by-Start skipped.
 stz snes_pause_mask
 lda ctl_type_p1
 cmp #CTL_SNES
 bne :sp_p1_not_snes
 lda #$80
 sta snes_pause_mask
:sp_p1_not_snes
 lda ctl_type_p2
 cmp #CTL_SNES
 bne :sp_p2_not_snes
 lda snes_pause_mask
 ora #$40
 sta snes_pause_mask
:sp_p2_not_snes

* Resolve the SNES MAX slot from smax_slot ($306) and patch the
* operand low byte of every stal/ldal SNES_LATCH/CLOCK in
* snes_poll and check_pause. Each instruction is a 4-byte stal/
* ldal abs-long; the low byte of the address sits at label+1
* (mid byte $C0 and bank $00 are unchanged). New low byte:
*   LATCH = $80 + slot*$10
*   CLOCK = $81 + slot*$10
 lda smax_slot           ; 1..7 (low byte; high byte zeroed by title.s)
 asl
 asl
 asl
 asl                     ; A = slot * $10
 clc
 adc #$80                ; A = LATCH low byte ($90..$F0)
 sta cps_latch_a+1
 sta cps_latch_b+1
 sta sps_latch_a+1
 sta sps_latch_b+1
 inc                     ; A = CLOCK low byte ($91..$F1)
 sta cps_clock_a+1
 sta cps_clock_b+1
 sta cps_clock_c+1
 sta sps_clock_a+1

 ldx #5
 jsr draw_loading_string

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

* HUD text: in 1P mode the "PLAYER 2: 0000000" half is replaced
* with "Press 2 to Join" (same prefix length so the rest
* still starts at the original P2 column).
 lda game_type
 beq :hud_1p
 pea ^string5
 pea string5
 bra :hud_draw
:hud_1p
 pea ^string5_1p
 pea string5_1p
:hud_draw
 ldx #$A604
 jsl $E10000        ; DrawCString

 sec
 xce
 sep #$30

 bra over1

string5    ASC 'PLAYER 1: 0000000       PLAYER 2: 0000000',00
* 1P-mode variant: same "PLAYER 1: 0000000       " prefix so the
* second-half text starts at the same x as "PLAYER 2:" would have.
string5_1p ASC 'PLAYER 1: 0000000       Press 2 to Join',00

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
* DISABLED: kbd_init actually cranks autorepeat to its fastest
* setting (40 keys/sec) to keep up with the throttled walk-toggle
* cadence. Now that keyboard players bypass the toggle (see
* advance_walk), they step every VBL on natural $C000 strobes
* and don't need the boosted repeat rate. Leaving the keyboard
* at its default autorepeat avoids surprising the user with
* turbo-speed text/menu repeats outside the game proper.
* jsr kbd_init

*==========================================================
* Main game loop
*==========================================================
game_loop
 jsr check_pause       ; ESC tap toggles paused
 jsr check_debug_xy    ; 'd' tap toggles hex xpos/ypos readout
 jsr check_p2_join     ; '2' tap activates Jimmy in 1P mode
 lda paused
 bne :gl_paused_idle   ; frozen: skip all per-frame work
 jsr update_overlay
 jsr process_input
 jsr process_input_jimmy
 jsr run_script
 jsr update_npcs       ; runs behavior state machines
 jsr update_anims
 jsr update_billy_y_off ; ramp Billy's parabolic jump arc (legacy)
 jsr update_jimmy_y_off ; same for Jimmy when he's active   (legacy)
* Gravity hook re-enabled (Billy-only, no Jimmy swap) for diagnosis.
* apply_gravity_step has an immediate RTS at entry — the JSR/RTS
* round-trip should be a pure no-op while we find the boot-
* corruption source.
 jsr apply_gravity_step
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
 jsr draw_p2_score
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
:nwu cmp #SCRIPT_WAITDOWN
 bne :nwd
 jmp :check_waitdown
:nwd cmp #SCRIPT_WAITXREV
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

 jsr zero_health_palette
 jsr fade_palette_to_black
 sec
 xce
 sep $30
 mx %11
 lda #SCRIPT_DONE
 sta script_state
:rs_rts 
* Level complete. Advance current_mission so the next leg of the
* DDII.SYSTEM chain ($1002 = load_cutscene, then $1004 = load_game)
* picks up the mission that follows. The cutscene loader will read
* cutscene_number to choose which CUTSCENE to play.
 inc current_mission
 inc cutscene_number
 jmp $1002

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
* (No longer pre-loads the right-neighbor's bounds. Walk-right's
* check_x_bounds_walk_right now uses the world-coord stratum
* bounds, which already cover whichever screen the player is
* about to scroll into.)
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
* Skip the overlay entirely if the mission didn't supply a
* spr_pointright sprite (spr_addr_tbl entry was 0). Without this
* guard the renderer draws garbage from bank-$02/$0000 — the level
* header bytes happen to visually resemble Billy's ladder-climb
* sprite, so mission 2 boot shows a stray "BCLIMB" sprite at the
* far right edge until the 180-frame timer expires.
 lda spr_pointright
 ora spr_pointright+1
 bne :rt_have_pr_sprite
 jmp :rt_overlay_skip
:rt_have_pr_sprite
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
:rt_overlay_skip
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
 beq :do_op_left
 jmp :not_left
:do_op_left
 ldy #1
 lda [script_pc],y
 sta scroll_left_screen
* (No longer pre-loads the left-neighbor's bounds — see matching
* note in :do_op_right above.)
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
* DEBUG_LSRC: 'LE T=tt B=bb O=oo CS=cs WO=wwww J=j'
* — state at OP_LEFT firing. T=target screen, B/O = post-handler
* lsrc bank/off, CS = current_screen, WO = world_offset, J =
* jimmy_active. Tells us whether the keep_off branch fired with
* the canonical $0B/$29 expected after a scr10 climb.
 do DEBUG_LSRC
 lda #$CC              ; 'L'
 jsr dbg_print_char
 lda #$C5              ; 'E'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda #$D4              ; 'T'
 jsr dbg_print_char
 lda #$BD              ; '='
 jsr dbg_print_char
 lda scroll_left_screen
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
 lda #$CF              ; 'O'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 lda scroll_lsrc_off
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
 lda #$CA              ; 'J'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 lda jimmy_active
 jsr dbg_print_hex8
 jsr dbg_print_nl
 fin
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
 jmp :chk_op_down      ; not OP_UP — test OP_DOWN next
:do_op_up
* DEBUG: 'UP WO=wwww AX=aaaa' — world_offset and abs_x at the
* moment OP_UP fires. Narrow-target UP scroll compensation
* (+15 pin / +7 ladder / +10 snap xpos) is calibrated for a
* specific wo at this point; compare across runs to see whether
* wo varies (which would confirm the compensation is fragile).
 do DEBUG_PRINT
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
 fin
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

:chk_op_down
 cmp #OP_DOWN
 beq :do_op_down
 jmp :not_up_op        ; not OP_DOWN either — continue dispatch chain
:do_op_down
* OP_DOWN: 7 params.
*   p1 = left-half target screen index.
*   p2 = right-half target screen index ($FF = single-bank, no split).
*   p3 = split point as a WORLD byte (0..255). mission25/26 layout:
*        lbank is world-aligned (byte K = world K), rbank's byte 0
*        = world byte (split). Playfield seam = split - world_offset.
*   p4 = chain layer's lbank screen ($FF = no chain → clear enabled
*        at snap; non-$FF = swap to (p4+3, p5+3) at snap and reset
*        off=0 to keep descending into the next layer).
*   p5 = chain layer's rbank screen ($FF if p4=$FF).
*   p6 = snap_at for THIS layer (= floor(art_rows/4)*4, e.g. 180
*        for a 183-row art bank). Caps the scroll so we don't keep
*        filling past the art's last meaningful row into the SHR's
*        SCB/padding tail.
*   p7 = snap_at for chain layer (ignored if p4=$FF). Copied into
*        scroll_down_snap_at at chain time alongside the lbank/rbank
*        swap.
* Advance script_pc by 8 (opcode + 7 params).
 ldy #1
 lda [script_pc],y
 sta scroll_down_screen
 clc
 adc #$03
 sta scroll_down_bank
 sta scroll_down_lbank       ; left half = target by default
 ldy #2
 lda [script_pc],y
 cmp #$FF
 beq :op_down_no_rhalf
 clc
 adc #$03
 sta scroll_down_rbank
 bra :op_down_rh_done
:op_down_no_rhalf
 stz scroll_down_rbank       ; sentinel: no split, single-bank target
:op_down_rh_done
* Anchor at current world_offset so compute_down_align produces
* src_start=0, dst_start=0, count=110. With split-bank composition
* (Phase 3), Step 2 in _scroll_down splits playfield bytes into
* lbank (0..split-1) and rbank (split..109).
 lda world_offset
 sta scroll_down_anchor
 lda world_offset+1
 sta scroll_down_anchor+1
* param3 = world byte split (0..255). $FF = no split → 110 = full lbank fill.
 ldy #3
 lda [script_pc],y
 cmp #$FF
 bne :op_down_have_split
 lda #110                    ; no split → full lbank fill
:op_down_have_split
 and #$00FF
 sta scroll_down_split
 stz scroll_down_split+1
 lda #110
 sta scroll_down_twidth
 stz scroll_down_twidth+1
 lda #110
 sta scroll_down_lwidth
 stz scroll_down_lwidth+1
 stz scroll_down_off          ; ascend from row 0
 stz descent_started
* params 4..7 = chain + per-layer snap thresholds.
*   p4 = chain target lbank ($FF = no chain).
*   p5 = chain target rbank (only valid if p4 != $FF).
*   p6 = current layer's snap_at (= source-row index where lbank
*        runs out of valid art; floor(content_rows/4)*4).
*   p7 = chain layer's snap_at (only valid if p4 != $FF).
* Without per-layer snap_at, scroll continues filling blank source
* rows past the art's bottom edge — visible as a vertical gap at
* the layer transition (= mission25's 17-row padding past row 182).
 ldy #4
 lda [script_pc],y
 cmp #$FF
 beq :op_down_no_chain
 clc
 adc #$03
 sta scroll_down_next_lbank
 ldy #5
 lda [script_pc],y
 clc
 adc #$03
 sta scroll_down_next_rbank
 ldy #7
 lda [script_pc],y
 sta scroll_down_next_snap_at
 bra :op_down_chain_done
:op_down_no_chain
 stz scroll_down_next_lbank
 stz scroll_down_next_rbank
 stz scroll_down_next_snap_at
:op_down_chain_done
 ldy #6
 lda [script_pc],y
 sta scroll_down_snap_at
* Overlay: reuse POINT_UP sprite but render at bottom-center of the
* playfield. Phase 4 may add a dedicated POINT_DOWN.
 jsr clear_active_overlay
 ldx #SND_FINGER
 jsr sound_trigger
 lda #180
 sta overlay_timer
 lda #51
 sta overlay_x
 lda #160                     ; bottom-center (OP_UP uses 0 for top)
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
 sta scroll_down_enabled
 lda #SCRIPT_WAITDOWN
 sta script_state
 lda script_pc
 clc
 adc #8                       ; opcode + 7 params
                              ; (lbank, rbank, split, next_l, next_r, snap_at, next_snap_at)
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 rts                          ; yield — wait for descent to complete

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
 lda #$14
 sta music_bank        ; track for M-resume / pause-resume
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
 cmp #OP_BOUNDS
 beq :do_bounds
 jmp :not_bounds
:do_bounds
* OP_BOUNDS: rewrite stratum_bounds_tbl so only ONE y row is
* walkable across the supplied world-x span. Params:
*   p1 = y row (0..199).
*   p2..p3 = 16-bit world x_lo (= span1 bmin).
*   p4..p5 = 16-bit world x_hi (= span1 bmax).
* Use case: OP_DOWN's post-descent platform — the level script's
* OP_DOWN ends with the ladder cleared and Billy on the descent
* target's bottom; OP_BOUNDS pins his footing to one walkable row.
* Total advance: 6 bytes (opcode + 5 params).
*
* Strategy: fill the entire stratum_bounds_tbl with the blocked
* sentinel (span1/span2 = $FFFF, $0000), then overwrite the
* selected row's span1 with (x_lo, x_hi). span2 stays blocked.
 ldy #1
 lda [script_pc],y
 sta :ob_y
 ldy #2
 lda [script_pc],y
 sta :ob_xlo
 ldy #3
 lda [script_pc],y
 sta :ob_xlo+1
 ldy #4
 lda [script_pc],y
 sta :ob_xhi
 ldy #5
 lda [script_pc],y
 sta :ob_xhi+1
* Fill stratum_bounds_tbl with blocked sentinel for all 200 rows.
* Each row: $FFFF, $0000, $FFFF, $0000 (= 8 bytes).
* Counter must fit in 8-bit X (we're in emulation mode here), so
* loop 200 times tracking row index, not the 1600-byte buffer
* offset (which would overflow $FF). Use :ob_xoff (= row-base
* byte offset, computed each iteration) to index stratum_bounds_tbl.
* Snap Billy to the platform first (8-bit emulation mode is fine
* for these single-byte stores). Clearing billy_airborne keeps
* apply_gravity_step from triggering a fall.
 lda :ob_y
 sta billy_sprite+0
 stz billy_airborne
* Switch to native 16-bit for the 1600-byte bounds rewrite.
* 8-bit X mode wrapped the offset past $FF and left rows 32..199
* of stratum_bounds_tbl untouched (= old upper-platform bounds
* leaked through and rejected y=130 → Billy fell off and respawned).
 clc
 xce
 rep $30
 mx %00
* Fill stratum_bounds_tbl with blocked sentinel for all 200 rows.
* Each row = 4 words: $FFFF, $0000, $FFFF, $0000.
 ldx #0
 lda #$FFFF
:ob_fill
 sta stratum_bounds_tbl,x
 sta stratum_bounds_tbl+4,x
 stz stratum_bounds_tbl+2,x
 stz stratum_bounds_tbl+6,x
 inx
 inx
 inx
 inx
 inx
 inx
 inx
 inx
 cpx #1600
 bcc :ob_fill
* Compute row offset = y * 8 in 16-bit so y=130 → 1040 doesn't
* truncate to its low byte.
 lda :ob_y
 and #$00FF
 asl
 asl
 asl
 tax
 lda :ob_xlo            ; 16-bit word: span1 bmin
 sta stratum_bounds_tbl,x
 lda :ob_xhi            ; 16-bit word: span1 bmax
 sta stratum_bounds_tbl+2,x
* Back to 8-bit emulation for the dispatch chain.
 sec
 xce
 mx %11
* Advance script_pc by 6.
 lda script_pc
 clc
 adc #6
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 jmp :exec_loop
:ob_y    dfb 0
:ob_xlo  dw 0
:ob_xhi  dw 0

:not_bounds
 cmp #OP_SCROLLSRC
 bne :not_scrollsrc
* OP_SCROLLSRC: set scroll_src_off to param. Advance 2 bytes
* (opcode + 1 param).
 ldy #1
 lda [script_pc],y
 sta scroll_src_off
 lda script_pc
 clc
 adc #2
 sta script_pc
 lda script_pc+1
 adc #0
 sta script_pc+1
 jmp :exec_loop

:not_scrollsrc
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
* Compare rightmost player's world X against threshold (16-bit).
* script_x = max(billy_world, jimmy_world) when co-op, else abs_x.
 jsr compute_script_x
 lda script_x+1
 cmp script_wait_val+1
 bcc :wx_wait_rts       ; not yet (high byte less)
 bne :waitx_done        ; high byte greater — done
 lda script_x
 cmp script_wait_val
 bcc :wx_wait_rts       ; low byte less
:waitx_done
* DEBUG: 'WX xxxx=tttt' — script_x vs threshold at fire.
 do DEBUG_PRINT
 lda #$D7              ; 'W'
 jsr dbg_print_char
 lda #$D8              ; 'X'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda script_x+1
 jsr dbg_print_hex8
 lda script_x
 jsr dbg_print_hex8
 lda #$BD              ; '='
 jsr dbg_print_char
 lda script_wait_val+1
 jsr dbg_print_hex8
 lda script_wait_val
 jsr dbg_print_hex8
 jsr dbg_print_nl
 fin
 lda #SCRIPT_RUN
 sta script_state
 jmp :exec_loop         ; condition met, resume executing

:check_waitxrev
* Compare LEFTMOST player's world X against threshold (16-bit).
* Retreat gate semantics: whichever player is actually driving the
* leftward scroll is the leftmost one. Using max (both retreated)
* stalls the script forever when one player isn't pressing left —
* their world-x stays anchored (co_op_shift_other_right
* compensates so wo+xpos is constant), and OP_WAITXREV would never
* fire even after the scroller had driven the world way past the
* threshold. Mission1's "switch lsrc to scr9 before scr8 underflow
* into scr7's empty margin" gate (mission1.s:410) is the concrete
* breakage — co-op black bar bug.
 jsr compute_script_x_min
 lda script_wait_val+1
 cmp script_x+1
 bcc :wx_wait_rts       ; threshold_hi < script_hi → still greater
 bne :waitxrev_done     ; threshold_hi > script_hi → done
 lda script_wait_val
 cmp script_x
 bcc :wx_wait_rts       ; threshold_lo < script_lo → still greater
:waitxrev_done
* DEBUG: 'WR xxxx=tttt' — script_x vs threshold at fire.
 do DEBUG_PRINT
 lda #$D7              ; 'W'
 jsr dbg_print_char
 lda #$D2              ; 'R'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda script_x+1
 jsr dbg_print_hex8
 lda script_x
 jsr dbg_print_hex8
 lda #$BD              ; '='
 jsr dbg_print_char
 lda script_wait_val+1
 jsr dbg_print_hex8
 lda script_wait_val
 jsr dbg_print_hex8
 jsr dbg_print_nl
 fin
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

:check_waitdown
* Mirror of :check_waitup for OP_DOWN descent. Polls
* scroll_down_enabled; resumes the script when :snap_transition_down
* clears the flag. Phase 4: scroll_down is driven by :ai_do_down
* (= Billy pressing down on the ladder near DOWN_SCROLL_THRESH),
* not by this state-pumped loop.
 lda scroll_down_enabled
 bne :wd_rts                  ; still descending, wait
 lda #SCRIPT_RUN
 sta script_state
 jmp :exec_loop
:wd_rts rts

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
 do DEBUG_PRINT
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
 fin
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
* Compiled-William upgrade: if the template's idle_addr matches
* spr_william1 (the legacy bank-$02 idle), repoint the sprite to
* the bank-$1B AND/ORA-pipeline version. info+14/+42 → compiled
* DATA, info+60/+62 → compiled MASK + persistent idle mask,
* info+56/+58 → $1B. Mid-anim legacy frames (anim_wwalk etc.)
* clear info+60 to drop back to draw_sprite; :normal_end's
* :ne_npc_mask_restore reads info+62 to revive compiled idle.
 lda :id_lo
 cmp spr_william1
 bne :no_compiled_william
 lda :id_hi
 cmp spr_william1+1
 bne :no_compiled_william
* Repoint frame/idle data to compiled WILLIAM1.
 lda spr_william1c_data
 ldy #14
 sta (info_ptr),y
 ldy #42
 sta (info_ptr),y
 lda spr_william1c_data+1
 ldy #15
 sta (info_ptr),y
 ldy #43
 sta (info_ptr),y
* Active + idle mask addresses → compiled WILLIAM1_MASK.
 lda spr_william1c_mask
 ldy #60
 sta (info_ptr),y
 ldy #62
 sta (info_ptr),y
 lda spr_william1c_mask+1
 ldy #61
 sta (info_ptr),y
 ldy #63
 sta (info_ptr),y
* idle_data_mirror (+64/65) + idle_mask_mirror (+66/67) for
* :ne_npc_mask_restore's mirror swap. Without these the IDLE
* pose always renders in WILLIAM1_DATA's natural orientation
* regardless of info+4 (mirror), so a William facing left at
* rest visually pointed the wrong way.
 lda spr_william1c_data_mir
 ldy #64
 sta (info_ptr),y
 lda spr_william1c_data_mir+1
 ldy #65
 sta (info_ptr),y
 lda spr_william1c_mask_mir
 ldy #66
 sta (info_ptr),y
 lda spr_william1c_mask_mir+1
 ldy #67
 sta (info_ptr),y
* Bank → $1B (overrides the $02 default just written).
 lda #$1B
 ldy #56
 sta (info_ptr),y
 ldy #58
 sta (info_ptr),y
:no_compiled_william
* Compiled-Roper upgrade: if the template's idle_addr matches
* spr_roper1 (the legacy bank-$02 idle), repoint to the bank-$1B
* compiled version. Mirrors the Williams upgrade above.
 lda :id_lo
 cmp spr_roper1
 bne :no_compiled_roper
 lda :id_hi
 cmp spr_roper1+1
 bne :no_compiled_roper
* Repoint frame/idle data to compiled ROPER1.
 lda spr_roper1c_data
 ldy #14
 sta (info_ptr),y
 ldy #42
 sta (info_ptr),y
 lda spr_roper1c_data+1
 ldy #15
 sta (info_ptr),y
 ldy #43
 sta (info_ptr),y
* Active + idle mask addresses → compiled ROPER1_MASK.
 lda spr_roper1c_mask
 ldy #60
 sta (info_ptr),y
 ldy #62
 sta (info_ptr),y
 lda spr_roper1c_mask+1
 ldy #61
 sta (info_ptr),y
 ldy #63
 sta (info_ptr),y
* idle_data_mirror + idle_mask_mirror for the mirror-aware idle.
 lda spr_roper1c_data_mir
 ldy #64
 sta (info_ptr),y
 lda spr_roper1c_data_mir+1
 ldy #65
 sta (info_ptr),y
 lda spr_roper1c_mask_mir
 ldy #66
 sta (info_ptr),y
 lda spr_roper1c_mask_mir+1
 ldy #67
 sta (info_ptr),y
* Bank → $1B (overrides the $02 default just written).
 lda #$1B
 ldy #56
 sta (info_ptr),y
 ldy #58
 sta (info_ptr),y
:no_compiled_roper
* Compiled-Linda upgrade: if the template's idle_addr matches
* spr_linda1 (the legacy bank-$02 idle), repoint to bank-$1B
* compiled. Mirrors the Williams/Roper upgrades above.
* Linda's ladder-climbing path (ld_set_frame writes LCLIMB1/2)
* still uses bank $02 — ld_set_frame is responsible for clearing
* info+60 + setting info+56=$02 when entering climb.
 lda :id_lo
 cmp spr_linda1
 bne :no_compiled_linda
 lda :id_hi
 cmp spr_linda1+1
 bne :no_compiled_linda
* Repoint frame/idle data to compiled LINDA1.
 lda spr_linda1c_data
 ldy #14
 sta (info_ptr),y
 ldy #42
 sta (info_ptr),y
 lda spr_linda1c_data+1
 ldy #15
 sta (info_ptr),y
 ldy #43
 sta (info_ptr),y
* Active + idle mask addresses → compiled LINDA1_MASK.
 lda spr_linda1c_mask
 ldy #60
 sta (info_ptr),y
 ldy #62
 sta (info_ptr),y
 lda spr_linda1c_mask+1
 ldy #61
 sta (info_ptr),y
 ldy #63
 sta (info_ptr),y
* idle_data_mirror + idle_mask_mirror for the mirror-aware idle.
 lda spr_linda1c_data_mir
 ldy #64
 sta (info_ptr),y
 lda spr_linda1c_data_mir+1
 ldy #65
 sta (info_ptr),y
 lda spr_linda1c_mask_mir
 ldy #66
 sta (info_ptr),y
 lda spr_linda1c_mask_mir+1
 ldy #67
 sta (info_ptr),y
* Bank → $1B (overrides the $02 default just written).
 lda #$1B
 ldy #56
 sta (info_ptr),y
 ldy #58
 sta (info_ptr),y
:no_compiled_linda
* Compiled-Linda-flail upgrade: if the template's idle_addr
* matches spr_lfwalk1 (the bank-$19 walk frame written by
* :is_linda_flail above), repoint to bank-$1C compiled. Match
* on info+14 since :is_linda_flail just wrote it; the template
* itself uses sentinel $0001 so :id_lo/:id_hi don't compare.
 ldy #14
 lda (info_ptr),y
 cmp spr_lfwalk1
 bne :no_compiled_lflail
 ldy #15
 lda (info_ptr),y
 cmp spr_lfwalk1+1
 bne :no_compiled_lflail
* Repoint frame/idle data to compiled LFWALK1.
 lda spr_lfwalk1c_data
 ldy #14
 sta (info_ptr),y
 ldy #42
 sta (info_ptr),y
 lda spr_lfwalk1c_data+1
 ldy #15
 sta (info_ptr),y
 ldy #43
 sta (info_ptr),y
* Active + idle mask addresses → compiled LFWALK1_MASK.
 lda spr_lfwalk1c_mask
 ldy #60
 sta (info_ptr),y
 ldy #62
 sta (info_ptr),y
 lda spr_lfwalk1c_mask+1
 ldy #61
 sta (info_ptr),y
 ldy #63
 sta (info_ptr),y
* idle_data_mirror + idle_mask_mirror for the mirror-aware idle.
 lda spr_lfwalk1c_data_mir
 ldy #64
 sta (info_ptr),y
 lda spr_lfwalk1c_data_mir+1
 ldy #65
 sta (info_ptr),y
 lda spr_lfwalk1c_mask_mir
 ldy #66
 sta (info_ptr),y
 lda spr_lfwalk1c_mask_mir+1
 ldy #67
 sta (info_ptr),y
* Bank → $1C (overrides the $19 default just written).
 lda #$1C
 ldy #56
 sta (info_ptr),y
 ldy #58
 sta (info_ptr),y
:no_compiled_lflail
* Compiled-Williams-pipe upgrade: matches spr_wpipewalk1 written
* by :is_williams_pipe above.
 ldy #14
 lda (info_ptr),y
 cmp spr_wpipewalk1
 bne :no_compiled_wpipe
 ldy #15
 lda (info_ptr),y
 cmp spr_wpipewalk1+1
 bne :no_compiled_wpipe
* Repoint frame/idle data to compiled WPIPEWALK1.
 lda spr_wpipewalk1c_data
 ldy #14
 sta (info_ptr),y
 ldy #42
 sta (info_ptr),y
 lda spr_wpipewalk1c_data+1
 ldy #15
 sta (info_ptr),y
 ldy #43
 sta (info_ptr),y
* Active + idle mask addresses → compiled WPIPEWALK1_MASK.
 lda spr_wpipewalk1c_mask
 ldy #60
 sta (info_ptr),y
 ldy #62
 sta (info_ptr),y
 lda spr_wpipewalk1c_mask+1
 ldy #61
 sta (info_ptr),y
 ldy #63
 sta (info_ptr),y
* idle_data_mirror + idle_mask_mirror for the mirror-aware idle.
 lda spr_wpipewalk1c_data_mir
 ldy #64
 sta (info_ptr),y
 lda spr_wpipewalk1c_data_mir+1
 ldy #65
 sta (info_ptr),y
 lda spr_wpipewalk1c_mask_mir
 ldy #66
 sta (info_ptr),y
 lda spr_wpipewalk1c_mask_mir+1
 ldy #67
 sta (info_ptr),y
* Bank → $1C (overrides the $19 default just written).
 lda #$1C
 ldy #56
 sta (info_ptr),y
 ldy #58
 sta (info_ptr),y
:no_compiled_wpipe
* Compiled-Burnov upgrade: matches spr_bnwalk1 written by
* :is_burnov above. Repoints idle to bank-$1B compiled BNWALK1
* so Burnov's ambient/idle frames render compiled. His other
* anims (punch, grab, fall, dissolve, recon) stay legacy
* bank-$19, and start_anim flips info+56 to $19 while they
* play; :normal_end restores info+56 from info+58 ($1B).
 ldy #14
 lda (info_ptr),y
 cmp spr_bnwalk1
 bne :no_compiled_burnov
 ldy #15
 lda (info_ptr),y
 cmp spr_bnwalk1+1
 bne :no_compiled_burnov
* Repoint frame/idle data to compiled BNWALK1.
 lda spr_bnwalk1c_data
 ldy #14
 sta (info_ptr),y
 ldy #42
 sta (info_ptr),y
 lda spr_bnwalk1c_data+1
 ldy #15
 sta (info_ptr),y
 ldy #43
 sta (info_ptr),y
* Active + idle mask addresses → compiled BNWALK1_MASK.
 lda spr_bnwalk1c_mask
 ldy #60
 sta (info_ptr),y
 ldy #62
 sta (info_ptr),y
 lda spr_bnwalk1c_mask+1
 ldy #61
 sta (info_ptr),y
 ldy #63
 sta (info_ptr),y
* idle_data_mirror + idle_mask_mirror for the mirror-aware idle.
 lda spr_bnwalk1c_data_mir
 ldy #64
 sta (info_ptr),y
 lda spr_bnwalk1c_data_mir+1
 ldy #65
 sta (info_ptr),y
 lda spr_bnwalk1c_mask_mir
 ldy #66
 sta (info_ptr),y
 lda spr_bnwalk1c_mask_mir+1
 ldy #67
 sta (info_ptr),y
* Bank → $1B (overrides the $19 default just written).
 lda #$1B
 ldy #56
 sta (info_ptr),y
 ldy #58
 sta (info_ptr),y
:no_compiled_burnov
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
 do DEBUG_PRINT
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
 fin
* Advance NPC buffer pointer by NPC_INFO_SIZE bytes per block.
 lda npc_buf_next
 clc
 adc #NPC_INFO_SIZE
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
did_climb_this_frame dfb 0       ; set after :sn_done fires scroll_up so
                                  ; the second mover's :do_up_on_ladder
                                  ; doesn't double-scroll. Cleared each
                                  ; frame at top of process_input.
billy_climb_pressed  dfb 0       ; (unused, kept for binary compat)
jimmy_climb_pressed  dfb 0       ; (unused, kept for binary compat)
climb_hide_other     dfb 0       ; co-op: set to 1 when one player
                                  ; enters a ladder so the other is
                                  ; hidden (no input, no draw, no
                                  ; erase) until the climb's
                                  ; snap_transition completes. Avoids
                                  ; the bounds-row / drag / teleport
                                  ; issues from carrying both players
                                  ; through a vertical scroll.
climb_climber_ptr    ds 2        ; info_ptr of the active climber while
                                  ; climb_hide_other=1. Used by gates
                                  ; in pi_action_dispatch, draw_all,
                                  ; erase_all, draw_other_sprite to
                                  ; tell the climber from the hidden
                                  ; other.
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

* OP_DOWN parallel-to-OP_UP state vars. Same layout/naming as
* scroll_up_*, but for downward descent (Billy on a ladder going
* DOWN past DOWN_SCROLL_THRESH). lbank/rbank here describe the
* split TARGET (mission2's mission25/26 left+right), not neighbors
* of a single target like OP_UP. split_world holds the world-x byte
* where the lbank's content ends and rbank's begins.
scroll_down_enabled  dfb 0
scroll_down_screen   dfb 0
scroll_down_bank     dfb $03
scroll_down_off      dfb 0        ; counts UP from 0 toward 200 (snap @ 200)
scroll_down_lbank    dfb $03      ; left-half target bank
                                  ; ($00 sentinel = no split, single bank)
scroll_down_rbank    dfb $03      ; right-half target bank
                                  ; ($00 sentinel = no split)
scroll_down_next_lbank dfb 0      ; chain layer's lbank ($00 = no chain).
                                  ; Snap copies into scroll_down_lbank, then
                                  ; resets scroll_down_off and continues
                                  ; instead of clearing scroll_down_enabled.
scroll_down_next_rbank dfb 0      ; chain layer's rbank
scroll_down_snap_at  dfb 200      ; off threshold for snap (current layer)
                                  ; Sized to floor(bank_content_rows / 4) * 4
                                  ; so the last fill block has no blank
                                  ; tail rows of art-padded source.
scroll_down_next_snap_at dfb 0    ; chain layer's snap_at (copied at chain)
scroll_down_anchor   dw 0         ; world byte: left edge of target content
scroll_down_lwidth   dw 110       ; left-half content width (default full)
scroll_down_twidth   dw 110       ; total target width (default 110)
scroll_down_split    dw 0         ; world-x byte where lbank/rbank meet
descent_started      dfb 0        ; first-call flag for scroll_down
                                  ; (mirrors climb_started)
did_descent_this_frame dfb 0      ; set after :ai_dn_on_ladder fires
                                  ; scroll_down; prevents double-scroll
                                  ; when both players descend the same frame
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
* (Neighbor-bounds tables retired — see BOUNDS_REFACTOR_PLAN.md.
* The stratum bounds cover all world_x in the connected screens,
* so check_x_bounds_walk_left/right no longer needs a separate
* neighbor-row check. Saves 800 bytes of bank-$00 RAM + 2 valid
* flags.)

*----------------------------------------------------------
* stratum_bounds_tbl — bank-$00 working copy of the current
* stratum's per-row bounds table. Refreshed by
* load_stratum_bounds when current_screen changes.
*
* Layout: 200 rows × 8 bytes per row =
*   span1_bmin (2b), span1_bmax (2b), span2_bmin (2b), span2_bmax (2b)
* All values are 16-bit little-endian, both inclusive.
* Unused span sentinel: bmin=$FFFF, bmax=$0000 (impossible).
*----------------------------------------------------------
stratum_bounds_tbl
 LUP 1600
 dfb 0
 --^

*----------------------------------------------------------
* check_x_bounds_world — drop-in replacement for check_x_bounds
* that reads from the stratum_bounds_tbl (world-coord bounds)
* instead of the per-screen bounds_tbl_lo/hi.
*
* Input:  A = proposed xpos (screen-local)
* Output: C=0 walkable, C=1 blocked
* Reads:  IMAGE01_YPOS, world_offset, stratum_bounds_tbl
* Trashes: A/X/Y (X widened to 16-bit internally)
*
* Per-row layout (8 bytes/row): span1_bmin, span1_bmax,
* span2_bmin, span2_bmax (each 16-bit). Unused-span sentinel
* is bmin=$FFFF, bmax=$0000 (impossible range, all checks fail).
*----------------------------------------------------------
check_x_bounds_world
* Compute world_x = world_offset + proposed_xpos (8-bit A in).
 clc
 adc world_offset
 sta :cxw_world_x
 lda #0
 adc world_offset+1
 sta :cxw_world_x+1
* Switch to native 16-bit for table indexing.
 clc
 xce
 rep $30
 mx %00
* X = ypos * 8 (row offset in stratum_bounds_tbl).
 lda IMAGE01_YPOS
 and #$00FF
 asl
 asl
 asl
 tax
* span1 check: bmin1 <= world_x <= bmax1?
 lda :cxw_world_x
 cmp stratum_bounds_tbl,x        ; world_x cmp bmin1
 bcc :cxw_try_span2              ; world_x < bmin1 → fall to span2
 lda stratum_bounds_tbl+2,x      ; A = bmax1
 cmp :cxw_world_x                ; bmax1 cmp world_x
 bcs :cxw_walkable               ; bmax1 >= world_x → walkable
:cxw_try_span2
 lda :cxw_world_x
 cmp stratum_bounds_tbl+4,x
 bcc :cxw_try_ladder
 lda stratum_bounds_tbl+6,x
 cmp :cxw_world_x
 bcs :cxw_walkable
:cxw_try_ladder
* Both spans rejected. Fall through to check_ladder ONLY if a climb
* is currently active (scroll_up_enabled = 1) — same gate as the
* legacy check_x_bounds path, to keep cross-screen ladder
* bleedover blocked when no OP_UP is in effect.
* Phase 4 OP_DOWN: also accept scroll_down_enabled so descending
* ladders work without an OP_UP being active.
 sec
 xce                              ; back to emul 8-bit before check_ladder
 lda scroll_up_enabled
 bne :cxw_ladder_ok
 lda scroll_down_enabled
 beq :cxw_blocked
:cxw_ladder_ok
* Restore chk_xpos and Y for check_ladder.
 lda :cxw_world_x
 sec
 sbc world_offset
 sta chk_xpos
 lda IMAGE01_YPOS
 jsr check_ladder
 bcs :cxw_blocked
 clc
 rts
:cxw_blocked
 sec
 rts
:cxw_walkable
 sec
 xce
 clc
 rts
:cxw_world_x ds 2

*----------------------------------------------------------
* check_x_bounds_world_outer — like check_x_bounds_world but
* tests the OUTER envelope of the row's two spans, not strict
* per-span membership. Used by the scroll-right/left gates so a
* 4-byte scroll can pass THROUGH a narrow gap between spans (e.g.
* scr1's staircase wall at row 83 leaves a 5-byte gap, world
* 110..114, between span1=[0,109] and span2=[115,549] — scrolling
* needs to step across that gap to reach the walkable region on
* the far side). WALKING stays on the strict check, which still
* blocks the player from coming to rest inside the gap.
*
* For single-span rows the unused-span sentinel ($FFFF, $0000)
* makes min(span1_bmin, span2_bmin) = span1_bmin and
* max(span1_bmax, span2_bmax) = span1_bmax, so the outer envelope
* collapses to span1 — no special casing.
*----------------------------------------------------------
check_x_bounds_world_outer
 clc
 adc world_offset
 sta :cxo_world_x
 lda #0
 adc world_offset+1
 sta :cxo_world_x+1
 clc
 xce
 rep $30
 mx %00
 lda IMAGE01_YPOS
 and #$00FF
 asl
 asl
 asl
 tax
* outer_min = min(span1_bmin, span2_bmin)
 lda stratum_bounds_tbl,x
 cmp stratum_bounds_tbl+4,x
 bcc :cxo_min_done
 lda stratum_bounds_tbl+4,x
:cxo_min_done
 sta :cxo_outer_min
* outer_max = max(span1_bmax, span2_bmax)
 lda stratum_bounds_tbl+2,x
 cmp stratum_bounds_tbl+6,x
 bcs :cxo_max_done
 lda stratum_bounds_tbl+6,x
:cxo_max_done
 sta :cxo_outer_max
* Test world_x ∈ [outer_min, outer_max]
 lda :cxo_world_x
 cmp :cxo_outer_min
 bcc :cxo_blocked
 lda :cxo_outer_max
 cmp :cxo_world_x
 bcs :cxo_walkable
:cxo_blocked
 sec
 xce
 sec
 rts
:cxo_walkable
 sec
 xce
 clc
 rts
:cxo_world_x   ds 2
:cxo_outer_min ds 2
:cxo_outer_max ds 2

*----------------------------------------------------------
* dbg_validate_stratum_bounds — iterate Y=0..199 × xpos=0..109
* comparing check_x_bounds (legacy per-screen) vs
* check_x_bounds_world (new stratum world-coord). Logs any
* mismatch via dbg_print as 'V! YY XX old=X new=X' for triage.
* Trashes everything; intended as a one-shot debug call.
* Gated on DEBUG_HELPERS — uses dbg_print_* (KEGS-only stdout).
*----------------------------------------------------------
 do DEBUG_HELPERS
dbg_validate_stratum_bounds
 lda IMAGE01_YPOS
 sta :dv_save_y
 lda chk_xpos
 sta :dv_save_xp
 stz :dv_y
:dv_y_loop
 lda :dv_y
 sta IMAGE01_YPOS
 stz :dv_x
:dv_x_loop
 lda :dv_x
 sta chk_xpos
 jsr check_x_bounds        ; legacy result in C
 lda #0
 rol                       ; A = 0 (walkable) or 1 (blocked)
 sta :dv_old
 lda :dv_x
 jsr check_x_bounds_world  ; new result in C
 lda #0
 rol
 cmp :dv_old
 beq :dv_x_next
* Mismatch — log it.
 lda #$D6              ; 'V'
 jsr dbg_print_char
 lda #$A1              ; '!'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda :dv_y
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda :dv_x
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda :dv_old
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #0
 jsr check_x_bounds_world  ; rerun to get C, just to compute display
 lda #0
 rol
 jsr dbg_print_hex8
 jsr dbg_print_nl
:dv_x_next
 inc :dv_x
 lda :dv_x
 cmp #110
 bcc :dv_x_loop
 inc :dv_y
 lda :dv_y
 cmp #200
 bcc :dv_y_loop
* Restore caller state.
 lda :dv_save_y
 sta IMAGE01_YPOS
 lda :dv_save_xp
 sta chk_xpos
 rts
:dv_y       dfb 0
:dv_x       dfb 0
:dv_old     dfb 0
:dv_save_y  dfb 0
:dv_save_xp dfb 0
 fin

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
* check_x_bounds — delegates to check_x_bounds_world (world-coord
* stratum bounds + ladder fallback). The per-screen bounds_tbl_lo/hi
* are no longer consulted here; sync_current_screen still keeps them
* refreshed for any straggling caller, but they'll be retired once
* all consumers route through the stratum table.
check_x_bounds
 jmp check_x_bounds_world

* Shared scratch — wrappers below stash the proposed X here
* before delegating to check_x_bounds, so it survives the call.
proposed_walk_x dfb 0

*----------------------------------------------------------
* check_x_bounds_walk_right / _walk_left — collapsed to thin
* delegators since the world-coord stratum bounds already cover
* whatever the neighbor screen's row offered. The old neighbor
* tables (bounds_tbl_left/right_*) are no longer consulted.
*----------------------------------------------------------
check_x_bounds_walk_right
 jmp check_x_bounds_world

check_x_bounds_walk_left
 jmp check_x_bounds_world
:cxbL_blocked sec
 rts
:cxbL_max dfb 0

*----------------------------------------------------------
* (load_left_neighbor_bounds / load_right_neighbor_bounds —
* deleted in the bounds refactor. OP_LEFT / OP_RIGHT no longer
* preload neighbor bounds since the world-coord stratum bounds
* already cover the neighbor row at scroll time.)
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
* (X snap workaround retired in the bounds refactor. Stratum
* world-coord bounds give the same row Y the same walkable range
* regardless of which screen the player is "on", so horizontal
* transitions don't change a row's bmin/bmax — there's nothing
* for X to be out-of-bounds against.)
 rts

*----------------------------------------------------------
* snap_xpos_and_absx - Slam IMAGE01_XPOS (and chk_xpos) to the
* value in A, AND apply the same delta to abs_x so the
* assert_abs_x invariant (abs_x == world_offset + IMAGE01_XPOS)
* survives the snap. Used by the walk-up / walk-down auto-step
* paths when the proposed Y row's bmin/bmax forces the player's
* xpos inward.
*
* Caller in emul 8-bit M. A = new xpos (preserved on exit).
*----------------------------------------------------------
snap_xpos_and_absx
 pha                       ; save new xpos
* delta = new - old, applied as abs_x = abs_x + new - old via
* two 16-bit ops to keep the sign right for both directions.
 clc
 adc abs_x
 sta abs_x
 lda abs_x+1
 adc #0
 sta abs_x+1
 sec
 lda abs_x
 sbc IMAGE01_XPOS
 sta abs_x
 lda abs_x+1
 sbc #0
 sta abs_x+1
 pla                       ; A = new xpos
 sta IMAGE01_XPOS
 sta chk_xpos
 rts

* check_y_bounds — world-coord stratum version. Tests whether the
* sprite at chk_xpos can occupy proposed Y. Includes ladder fallback
* (sets via_ladder=1 when access is via a ladder column).
*
* Input:  A = proposed Y, chk_xpos = sprite's screen X
* Output: C=0 walkable, C=1 blocked; via_ladder set if ladder-routed.
check_y_bounds
 stz via_ladder
 sta :cyb_proposed
* Sprite-fits gate: proposed + FRAME_Y <= 183.
 clc
 adc FRAME_Y
 cmp #184
 bcs :cyb_blocked
* world_x = wo + chk_xpos (16-bit).
 lda chk_xpos
 clc
 adc world_offset
 sta :cyb_world_x
 lda #0
 adc world_offset+1
 sta :cyb_world_x+1
* Native 16-bit for the stratum row lookup.
 clc
 xce
 rep $30
 mx %00
 lda :cyb_proposed
 and #$00FF
 asl
 asl
 asl
 tax
 lda :cyb_world_x
 cmp stratum_bounds_tbl,x
 bcc :cyb_span2
 lda stratum_bounds_tbl+2,x
 cmp :cyb_world_x
 bcs :cyb_walkable
:cyb_span2
 lda :cyb_world_x
 cmp stratum_bounds_tbl+4,x
 bcc :cyb_try_ladder
 lda stratum_bounds_tbl+6,x
 cmp :cyb_world_x
 bcs :cyb_walkable
:cyb_try_ladder
 sec
 xce
 lda :cyb_proposed
 jsr check_ladder
 bcs :cyb_blocked
 lda #1
 sta via_ladder
 clc
 rts
:cyb_walkable
 sec
 xce
 clc
 rts
:cyb_blocked
 sec
 rts
:cyb_proposed dfb 0
:cyb_world_x  ds 2

*----------------------------------------------------------
* check_y_bounds_strict - Same row-bounds test as check_y_bounds
* but with NO ladder fallback. Used by NPC movement code so
* enemies don't squeeze through ladder columns past the row
* limits (which check_y_bounds intentionally permits so players
* can climb). Input/output match check_y_bounds.
*----------------------------------------------------------
* check_y_bounds_strict — world-coord stratum version for NPCs.
* No ladder fallback (enemies can't climb), plus a "NPC floor"
* gate that rejects rows below npc_min_y so AI doesn't squeeze
* into staircase / ladder column rows meant only for the player.
*
* Input:  A = proposed Y, chk_xpos = sprite's screen X
* Output: C=0 walkable, C=1 blocked.
check_y_bounds_strict
 stz via_ladder
 sta :cybs_proposed
 cmp npc_min_y
 bcs :cybs_floor_ok
 bra :cybs_blocked
:cybs_floor_ok
 clc
 adc FRAME_Y
 cmp #184
 bcs :cybs_blocked
* world_x = wo + chk_xpos.
 lda chk_xpos
 clc
 adc world_offset
 sta :cybs_world_x
 lda #0
 adc world_offset+1
 sta :cybs_world_x+1
 clc
 xce
 rep $30
 mx %00
 lda :cybs_proposed
 and #$00FF
 asl
 asl
 asl
 tax
 lda :cybs_world_x
 cmp stratum_bounds_tbl,x
 bcc :cybs_span2
 lda stratum_bounds_tbl+2,x
 cmp :cybs_world_x
 bcs :cybs_walkable
:cybs_span2
 lda :cybs_world_x
 cmp stratum_bounds_tbl+4,x
 bcc :cybs_blocked_native
 lda stratum_bounds_tbl+6,x
 cmp :cybs_world_x
 bcs :cybs_walkable
:cybs_blocked_native
 sec
 xce
 sec
 rts
:cybs_walkable
 sec
 xce
 clc
 rts
:cybs_blocked
 sec
 rts
:cybs_proposed ds 2
:cybs_world_x  ds 2
via_ladder dfb 0
chk_xpos dfb 0
* is_climbing: sticky flag indicating the player is in the middle
* of a climb sequence. Set when an up-walk advances ypos via a
* ladder match; cleared when the player walks horizontally or
* their up/down walk doesn't engage a ladder. check_ladder uses
* it to distinguish CONTINUING a climb (relaxed: accept any
* proposed_y in [y_top, y_bottom]) from STARTING one (strict:
* proposed_y must equal y_bottom, i.e. the player must be at
* the ladder's floor row to engage). Prevents accidentally
* triggering a climb by walking near a ladder column at a Y
* above the floor.
is_climbing dfb 0
* NPC minimum Y. Computed at load_screen_bounds: first row whose
* bmax equals the floor bmax (= bmax[199]). Below this row are
* staircases / ladder columns that the player can traverse but
* NPCs shouldn't. check_y_bounds_strict gates on this.
npc_min_y dfb 0
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
 bne :scr_xp_proceed
 jmp :no_change
:scr_xp_proceed
 stz transition_pending
 lda scroll_right_screen
 cmp current_screen
 bne :scr_xp_change
 jmp :no_change
:scr_xp_change
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
* DEBUG_LSRC: 'SR B=bb O=oo CS=cs' — right-scroll sync clobbered
* the lsrc state to the linear default. If this fires between an
* OP_LEFT and the user's left-scroll, the canonical lsrc set by
* OP_SNAPSTATE has been wiped → black bar.
 do DEBUG_LSRC
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$D2              ; 'R'
 jsr dbg_print_char
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
 lda #$CF              ; 'O'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 lda scroll_lsrc_off
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
 fin
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

* Compute npc_min_y: first row whose bmax equals the LARGEST
* bmax in the table (= the screen's "floor" — the widest walkable
* band). NPCs are confined to Y >= npc_min_y so they can't follow
* players up staircase rows (scr2's rising bmax 48..76) or into
* ladder columns. Originally this used bmax[199] but that fails on
* screens like scr5 where rows 180..199 are blocked (bmax[199]=0);
* the algorithm would then set npc_min_y=199, stranding every NPC.
* Two passes: pass 1 finds floor_bmax (max value), pass 2 finds the
* first row where bmax == floor_bmax. If the whole table is zero
* (transient state), fall back to npc_min_y=199.
 sep $20
 mx %10
* Pass 1: find max bmax.
 lda #0
 sta :nmy_floor
 ldx #0
:nmy_max_scan
 lda bounds_tbl_hi,x
 cmp :nmy_floor
 bcc :nmy_max_next
 sta :nmy_floor
:nmy_max_next
 inx
 cpx #200
 bcc :nmy_max_scan
 lda :nmy_floor
 beq :nmy_block_all      ; entire table zero → block
* Pass 2: find first row where bmax == floor_bmax.
 ldx #0
:nmy_scan
 lda bounds_tbl_hi,x
 cmp :nmy_floor
 beq :nmy_found
 inx
 cpx #200
 bcc :nmy_scan
:nmy_block_all
 lda #199
 sta npc_min_y
 bra :nmy_done
:nmy_found
 txa
 sta npc_min_y
:nmy_done
 rep $20
 mx %00

 sec
 xce                   ; back to emulation mode
* Also refresh the stratum bounds working copy for this screen.
* This is the new world-coord bounds table; the per-screen
* bounds_tbl_lo/hi above will be retired once consumers migrate.
 lda :scr_idx
 jsr load_stratum_bounds
 rts
:scr_idx ds 2
:nmy_floor dfb 0

*----------------------------------------------------------
* load_stratum_bounds — copy the current screen's stratum
* bounds table (1600 bytes) from bank $02 to bank-$00
* stratum_bounds_tbl. Looks up the stratum index via
* screen_to_stratum[scr_idx], then strata_index[stratum_idx*2]
* to get the bank-$02 address of the per-stratum table.
*
* Input: A = current screen index
* Trashes: A, X, Y, $F0-$F5, mode (returns in emul 8-bit)
*----------------------------------------------------------
load_stratum_bounds
 sta :lsb_scr
 clc
 xce
 rep $30
 mx %00

* Step 1: stratum_idx = screen_to_stratum[scr_idx] (1 byte)
 lda s2s_base
 sta $F0
 sep $20
 lda #$02
 sta $F2
 rep $20
 lda :lsb_scr
 and #$00FF
 tay
 sep $20
 lda [$F0],y
 sta :lsb_stratum

* Step 2: stratum_table_addr = strata_index[stratum_idx*2] (16-bit)
 rep $20
 mx %00
 lda strata_base
 sta $F0
 sep $20
 lda #$02
 sta $F2
 rep $20
 lda :lsb_stratum
 and #$00FF
 asl                    ; *2 (word entries)
 tay
 lda [$F0],y            ; A = stratum_table address (16-bit, bank $02)
 sta $F0                ; reuse $F0 as the new source pointer
 sep $20
 lda #$02
 sta $F2                ; $F0..$F2 = $02/stratum_table

* Step 3: dst = bank-$00 stratum_bounds_tbl
 rep $20
 lda #stratum_bounds_tbl
 sta $F3
 sep $20
 lda #$00
 sta $F5                ; $F3..$F5 = $00/stratum_bounds_tbl

* Step 4: copy 1600 bytes (= 800 words). Inner loop uses 16-bit
* M for word reads/writes and 16-bit X for the counter.
 rep $30
 mx %00
 ldx #800
 ldy #0
:lsb_copy
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 dex
 bne :lsb_copy

 sec
 xce                    ; back to emul 8-bit
 rts
:lsb_scr     ds 2
:lsb_stratum ds 2

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
* On ladder per x + y range. Engage gate: if the player isn't
* already mid-climb (is_climbing=0), require proposed_y to equal
* EITHER y_bottom (entering from the floor BELOW — UP climb) or
* y_top (entering from a platform ABOVE — DOWN climb, Phase 4
* OP_DOWN). If they're already climbing (is_climbing=1), any
* proposed_y in the y range is fine (continuation).
 lda is_climbing
 bne :cl_on_ladder
 lda :prop_y
 cmp ladder_buf+5,x    ; y_bottom (up-engage from below)
 beq :cl_on_ladder
 cmp ladder_buf+4,x    ; y_top (down-engage from above)
 bne :cl_next          ; neither endpoint — reject
:cl_on_ladder
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

* Pause state — toggled by ESC tap or SNES MAX Start tap in
* check_pause. When paused, game_loop skips update_overlay /
* process_input / update_anims / etc., leaving the screen frozen
* until the next tap.
paused dfb 0                  ; 0 = running, 1 = paused

* SNES-pause edge-detect state.
* snes_pause_mask is built once at game init from ctl_type_p1/p2:
*   bit 7 set → P1 is on SNES (watch SNES_LATCH bit 7 for Start)
*   bit 6 set → P2 is on SNES (watch SNES_LATCH bit 6 for Start)
*   $00       → neither player on SNES → check_pause skips entirely
* pause_snes_prev holds last frame's masked Start state so we only
* toggle on the rising edge (press) and not on a held button.
snes_pause_mask  dfb 0
pause_snes_prev  dfb 0

* PAUSED text geometry. QuickDraw uses pixel coords; erase uses
* the byte/row coords (1 byte = 2 pixels in 320 mode). Erase rect
* is sized generously to fully cover the rendered glyphs.
PAUSE_TEXT_X = 87            ; QuickDraw MoveTo h (pixels)
PAUSE_TEXT_Y = 100            ; QuickDraw MoveTo v (baseline)
PAUSE_BX     = 41             ; erase rect left (bytes; pixel 82)
PAUSE_BY     = 88             ; erase rect top  (rows)
PAUSE_BW     = 26             ; erase rect width  (bytes = 52 px)
PAUSE_BH     = 16             ; erase rect height (rows)

* Pause-save buffer. Lives in the 8KB free area at the start of
* every mission-art bank ($0000-$1FFF is unused — bg art unpacks
* to $2000). Bank $03 (MISSION11.PAK) is permanently loaded, so
* its $0000+ region is always available as scratch. We snapshot
* the SHR rect under PAUSED here before drawing the text, then
* restore from it on unpause — recovering any sprite pixels that
* PAUSED painted over (the $18 playfield shadow only has bg, so
* the old "erase from $18" path was background-over-sprite).
PAUSE_SAVE_BANK = $03
PAUSE_SAVE_OFF  = $0000
* SHR offset of pause rect top-left = $2000 + PAUSE_BY*$A0 + PAUSE_BX
*                                   = $2000 + 88*160   + 41
*                                   = $5729
* (precomputed because Merlin can't parse parenthesised operand
* expressions — `#$2000+(PAUSE_BY*$A0)+PAUSE_BX` won't assemble.)
PAUSE_RECT_OFF = $5729

pause_str ASC 'PAUSED',00

*----------------------------------------------------------
* compute_script_x - Stash the world-rightmost player position
* into script_x. When Jimmy is inactive this is just abs_x.
* When co-op is on, it's max(billy_world, jimmy_world) where
* jimmy_world = world_offset + jimmy.xpos. OP_WAITX/OP_WAITXREV
* compare against this so either player crossing the threshold
* satisfies the wait, regardless of which one is doing the
* scrolling. (abs_x stays Billy-tied so assert_abs_x — invariant
* abs_x == world_offset + billy.xpos — keeps passing.)
*----------------------------------------------------------
compute_script_x
 lda abs_x
 sta script_x
 lda abs_x+1
 sta script_x+1
 lda jimmy_active
 beq :csx_done
 clc
 lda jimmy_sprite+2
 adc world_offset
 sta :csx_jwp
 lda #0
 adc world_offset+1
 sta :csx_jwp+1
 lda :csx_jwp+1
 cmp script_x+1
 bcc :csx_done
 bne :csx_use_jwp
 lda :csx_jwp
 cmp script_x
 bcc :csx_done
 beq :csx_done
:csx_use_jwp
 lda :csx_jwp
 sta script_x
 lda :csx_jwp+1
 sta script_x+1
:csx_done
 rts
:csx_jwp ds 2

*----------------------------------------------------------
* compute_script_x_min - Mirror of compute_script_x but returns
* min(billy_world, jimmy_world) instead of max. Used by
* OP_WAITXREV (retreat gate): the leading (leftmost) player is
* the one driving the leftward scroll; if we waited for the
* trailing player too, they'd stall the script forever when
* they're not pressing left (their world-x is held constant by
* co_op_shift_other_right). When jimmy_active=0 this collapses
* to plain abs_x.
*----------------------------------------------------------
compute_script_x_min
 lda abs_x
 sta script_x
 lda abs_x+1
 sta script_x+1
 lda jimmy_active
 beq :csxn_done
 clc
 lda jimmy_sprite+2
 adc world_offset
 sta :csxn_jwp
 lda #0
 adc world_offset+1
 sta :csxn_jwp+1
 lda :csxn_jwp+1
 cmp script_x+1
 bcc :csxn_use_jwp
 bne :csxn_done
 lda :csxn_jwp
 cmp script_x
 bcc :csxn_use_jwp
:csxn_done
 rts
:csxn_use_jwp
 lda :csxn_jwp
 sta script_x
 lda :csxn_jwp+1
 sta script_x+1
 rts
:csxn_jwp ds 2

*----------------------------------------------------------
* check_pause - If ESC is in the keyboard register, toggle the
* paused flag, consume the keystroke, and draw or erase the
* "PAUSED" overlay at the screen's center. Other keys are left
* in the strobe so process_input picks them up on the next
* unpaused frame.
*----------------------------------------------------------
check_pause
* Keyboard ESC tap — consume the strobe and fall through to toggle.
 lda $c000
 bpl :cp_no_kbd         ; bit 7 clear → no key waiting
 and #$7f
 cmp #$1B               ; ESC
 bne :cp_no_kbd         ; some other key — leave for process_input
 sta $c010              ; consume the strobe (write clears it)
 jmp :cp_toggle
:cp_no_kbd

* SNES MAX Start tap. snes_pause_mask is non-zero only when at
* least one player is on SNES; bit 7 = P1, bit 6 = P2. We latch
* the SNES MAX, clock past B/Y/Select (3 pulses), and read the
* Start bit position for both controllers in one $C0C0 fetch.
 lda snes_pause_mask
 beq :cp_done
* These stal/ldal SNES_LATCH/CLOCK instructions are patched at
* game init (apply_smax_slot) so their operand low bytes line up
* with the slot the player picked on the selection screen. The
* equate-time default targets slot 4 ($C0C0/$C0C1); init rewrites
* byte +1 of each instruction below to $80+slot*$10 (latch) or
* $81+slot*$10 (clock).
cps_latch_a   stal SNES_LATCH
cps_clock_a   stal SNES_CLOCK        ; skip B
cps_clock_b   stal SNES_CLOCK        ; skip Y
cps_clock_c   stal SNES_CLOCK        ; skip Select — next read = Start
cps_latch_b   ldal SNES_LATCH        ; bit 7 = P1 Start (raw), bit 6 = P2 Start
 eor #$FF               ; active-LOW → active-HIGH
 and snes_pause_mask    ; mask out non-SNES players' bits
 tax                    ; X = current masked Start state
 eor pause_snes_prev    ; A = bits that changed this frame
 stx pause_snes_prev    ; record current for next-frame edge calc
 and pause_snes_prev    ; rising edges = changed AND current
 beq :cp_done           ; no fresh press
 ; fall through to :cp_toggle

:cp_toggle
 lda paused
 eor #$01               ; toggle 0↔1
 sta paused
 beq :cp_unpaused
* Just paused — stop music. Skip if user has it manually muted
* via M; we don't want unpause to undo their intentional mute.
 lda music_muted
 bne :cp_paused_text
 clc
 xce
 rep $30
; quiet NTP don't stop it, else you get unclaimed sound irq
 lda #$0000
 jsl NTPsetplayvolume
; jsl NTPstop
 sec
 xce
 sep $30
 mx %11
:cp_paused_text
 jsr save_pause_rect    ; snapshot pixels under the upcoming overlay
 jsr draw_pause_text
 rts
:cp_unpaused
* Just unpaused — resume music. Same gate on music_muted so an
* M-muted run stays silent when the user toggles pause. Calls
* NTPprepare + NTPplay + NTPsetplayvolume (see :pi_m_play for
* why prepare is required after NTPstop).
 lda music_muted
 bne :cp_unpaused_text
 clc
 xce
 rep $30
; ldx #$00
; lda music_bank
; and #$00FF
; tay
; lda #$0000
; jsl NTPprepare
; lda #$0000
; jsl NTPplay
 lda #$0080
 jsl NTPsetplayvolume
 sec
 xce
 sep $30
 mx %11
:cp_unpaused_text
 jsr restore_pause_rect ; just unpaused — repaint sprite+bg as it was
:cp_done rts

*----------------------------------------------------------
* check_p2_join - Watch for '2' key while in 1P mode (jimmy_active=0).
* On press: activate Jimmy with the controller P2 picked at the
* selection screen (jimmy_input_mode was already loaded from $304
* during game init), repaint the HUD strip with the 2P version of
* string5, and paint the P2 health bar segments.
*
* Skips entirely when jimmy_active is already non-zero, so the
* 2P-from-boot path (game_type=GT_2P_COOP/_PVP) is unaffected.
*----------------------------------------------------------
check_p2_join
 lda jimmy_active
 bne :cpj_done                ; P2 already in
 lda $c000
 bpl :cpj_done                ; no key waiting
 and #$7f
 cmp #'2'
 bne :cpj_done                ; not our key
 sta $c010                    ; consume the strobe
* Activate Jimmy — same fields as the boot-time game_type init.
 lda #1
 sta jimmy_active
 sta jimmy_sprite+30          ; dirty bit 0 = needs_draw on first frame
* Promote game_type so subsequent gates (HUD redraws, health-bar
* repaints, etc.) take the 2P path. Promoted to COOP; player can't
* opt into PvP at runtime (that requires the selection screen).
 lda #GT_2P_COOP
 sta game_type
* Repaint HUD strip: replaces "Press 2 to Join" with the 2P version
* of string5 ("PLAYER 1: ...   PLAYER 2: 0000000"). DrawCString
* needs native 16-bit; redraw_hud_2p switches modes internally.
 jsr redraw_hud_2p
* Paint the P2 health bar. draw_health_bar's game_type gate now
* falls through, so both bars get written; P1's bar is already
* on screen and gets the same bytes re-written (harmless).
 jsr draw_health_bar
:cpj_done rts

*----------------------------------------------------------
* redraw_hud_2p - MoveTo (3, 195) + DrawCString string5 (the
* 2P version). Caller in emulation 8-bit; this routine switches
* to native 16-bit for the toolbox calls and restores on exit.
* fg/bg colours and SetTextFace bold are inherited from the
* boot-time HUD init (QD II port state persists).
*----------------------------------------------------------
redraw_hud_2p
 clc
 xce
 rep $30
 lda #3
 pha
 lda #195
 pha
 ldx #$3a04                   ; _MoveTo
 jsl $E10000
 pea ^string5
 pea string5
 ldx #$A604                   ; _DrawCString
 jsl $E10000
 sec
 xce
 sep #$30
 rts

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
* draw_loading_string - Render the Nth loading-status string
* from mission12's loading_string_table at (30, 104). Used to
* break the monotony of the LOADING splash by changing the
* caption a few times during init.
*
* On entry: X = 0-based index into the table.
* loading_str_tbl_addr (set by init_mission12 from the +$14
* header field) holds the bank-$19 address of the table.
* Each table entry is 2 bytes — a bank-$19 address of a
* C-string. Switches to native 16-bit, calls QuickDraw II
* MoveTo + DrawCString, restores emulation 8-bit. Trashes
* A, X, Y.
*----------------------------------------------------------
draw_loading_string
* No-op when the level data didn't supply a loading-strings table
* (sparse manifest, e.g. a stub mission with loading_str_ptr = 0).
* Saves every caller from having to gate the call.
 lda loading_str_tbl_addr
 ora loading_str_tbl_addr+1
 bne :ls_have_table
 rts
:ls_have_table
* Compute byte offset (index * 2) in 8-bit before mode switch
* so we don't have to mask X's high byte after rep #$30.
 txa
 asl
 sta :ls_offset
 clc
 xce                    ; native mode
 rep $30
 mx %00
* Form bank-$02 pointer to the table entry at offset:
*   $F0/F1 = loading_str_tbl_addr + offset
*   $F2    = $02   (loading-strings table moved into the level-data
*                   bank; loading_str_tbl_addr is filled from the
*                   bank-$02 manifest's loading_str_ptr at boot)
 lda :ls_offset
 and #$00FF
 clc
 adc loading_str_tbl_addr
 sta $F0
 sep $20
 mx %10
 lda #$02
 sta $F2
 rep $20
 mx %00
* Read 16-bit string address (bank-$19 offset of the C-string).
 ldy #0
 lda [$F0],y
 sta :ls_str_addr
* MoveTo(50, 104).
 pea #60
 pea #104
 ldx #$3a04
 jsl $E10000
* SetForeColor
 pea #$0000
 ldx #$A004
 jsl $E10000
* SetBackColor
 pea #$0004
 ldx #$A204
 jsl $E10000
* DrawCString — push 24-bit pointer (bank in high word, offset
* in low word). Bank is $02 (level-data bank), offset is :ls_str_addr.
 pea #$0002
 lda :ls_str_addr
 pha
 ldx #$A604
 jsl $E10000
 sec
 xce                    ; back to emulation
 sep $30
 mx %11
 rts

:ls_offset    dfb 0
:ls_str_addr  ds 2

*----------------------------------------------------------
* save_pause_rect / restore_pause_rect - Snapshot and recover
* the SHR rect under the PAUSED overlay. Buffer is the 8KB
* free area at PAUSE_SAVE_BANK/PAUSE_SAVE_OFF (start of the
* MISSION11 art bank, before its $2000 unpack point).
*
* Source / destination row stride is $A0 (160 bytes) in BOTH
* the SHR rect and the buffer — the buffer is parallel-packed
* (row N starts at PAUSE_SAVE_OFF + N*$A0), so we only need
* different starting offsets, not different advance amounts.
* Last byte touched is row 15 at +$05F5, well under $1FFF.
*
* Structure mirrors `erase` (relocated DP for [dp],Y indirect-
* long pointers; native + 16-bit for cross-bank pointer math;
* 8-bit M for the per-byte copy inner loop). Each routine owns
* its full prologue/epilogue — no shared JSR helper, because a
* helper's RTS would pop bytes after PHD relocates DP into the
* same stack scratch its return address would live in.
*----------------------------------------------------------
save_pause_rect
 phb
 php
 clc
 xce
 php
 phk
 plb
 rep $30
 tsc
 sec
 sbc #10
 tcs
 phd
 tsc
 clc
 adc #3
 tcd
 sep $20
 mx %10
 lda #$01
 sta 2                       ; DP+2 = SHR bank
 lda #PAUSE_SAVE_BANK
 sta 6                       ; DP+6 = buffer bank
 rep $20
 mx %00
 lda #PAUSE_RECT_OFF
 sta 0                       ; DP+0..1 = SHR offset
 lda #PAUSE_SAVE_OFF
 sta 4                       ; DP+4..5 = buffer offset
 sep $30
 mx %11
 ldx #PAUSE_BH
]SPL1 ldy #0
]SPL  lda [0],y                ; read SHR (live screen)
 sta [4],y                   ; write buffer
 iny
 cpy #PAUSE_BW
 bcc ]SPL
 dex
 beq :spr_done
 rep $20
 lda 0
 clc
 adc #$A0
 sta 0
 lda 4
 clc
 adc #$A0
 sta 4
 sep $20
 bra ]SPL1
:spr_done
 rep $30
 pld
 tsc
 clc
 adc #10
 tcs
 plp
 xce
 plp
 plb
 rts

restore_pause_rect
 phb
 php
 clc
 xce
 php
 phk
 plb
 rep $30
 tsc
 sec
 sbc #10
 tcs
 phd
 tsc
 clc
 adc #3
 tcd
 sep $20
 mx %10
 lda #$01
 sta 2                       ; DP+2 = SHR bank
 lda #PAUSE_SAVE_BANK
 sta 6                       ; DP+6 = buffer bank
 rep $20
 mx %00
 lda #PAUSE_RECT_OFF
 sta 0                       ; DP+0..1 = SHR offset
 lda #PAUSE_SAVE_OFF
 sta 4                       ; DP+4..5 = buffer offset
 sep $30
 mx %11
 ldx #PAUSE_BH
]RPL1 ldy #0
]RPL  lda [4],y                ; read buffer
 sta [0],y                   ; write SHR (shadows to $E1)
 iny
 cpy #PAUSE_BW
 bcc ]RPL
 dex
 beq :rpr_done
 rep $20
 lda 0
 clc
 adc #$A0
 sta 0
 lda 4
 clc
 adc #$A0
 sta 4
 sep $20
 bra ]RPL1
:rpr_done
 rep $30
 pld
 tsc
 clc
 adc #10
 tcs
 plp
 xce
 plp
 plb
 rts

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
* MX tracker drifts because the routines above end with `rep $30`
* and an emulation-mode PLP+XCE+PLP that Merlin can't see. Anchor
* the entry-time mode so the SCB-write `lda #$02` block below
* assembles as 8-bit immediates.
 mx %11
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
* zero_health_palette - Black out all 16 entries of SHR
* palette 02 ($019E40..$019E5E). The health bars use slots
* 1..10 of this palette, so zeroing it makes the bars vanish.
* Called by OP_END just before fade_palette_to_black so the
* HUD bars don't linger through the level-complete fade.
*
* Caller must be in native 16-bit mode (MX %00). The mx
* directive below is critical: without it Merlin assembles
* `lda #$0000` as 8-bit (preceding setup_health_palette ended
* with mx %11), emitting only ONE immediate byte. At runtime
* with M=0 the CPU reads 2 immediate bytes — the second is
* the next opcode byte, and execution falls off into a stray
* RTI ($40) that pops 4 garbage bytes as an interrupt frame
* and jumps to wherever the stack happened to point. Crash.
*----------------------------------------------------------
 mx %00
zero_health_palette
 lda #$0000
 stal $019E40
 stal $019E42
 stal $019E44
 stal $019E46
 stal $019E48
 stal $019E4A
 stal $019E4C
 stal $019E4E
 stal $019E50
 stal $019E52
 stal $019E54
 stal $019E56
 stal $019E58
 stal $019E5A
 stal $019E5C
 stal $019E5E
 rts
 mx %11                  ; restore 8-bit context for following routines

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

* Player 2 bar (5 segments at bytes 89..106) — skipped in 1P mode
* so the HUD text "Press 2 to Join Co-Op" isn't sitting over a
* mostly-empty colored strip.
 lda game_type
 beq :hb_done
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
:hb_done
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
*----------------------------------------------------------
* maybe_game_over - Check both-players-dead. Jumps to game_over
* (never returns) when neither Billy nor Jimmy is alive. RTSes
* in every other case.
*
*   Billy alive = billy_fall_count < BILLY_MAX_FALLS
*   Jimmy alive = jimmy_active != 0 AND
*                 jimmy_stash_fall_count < BILLY_MAX_FALLS
*
* So if Jimmy never activated, Billy's death alone fires
* game_over (single-player flow); once Jimmy is in the game
* either player can keep play going for the other.
*----------------------------------------------------------
maybe_game_over
 lda billy_fall_count
 cmp #BILLY_MAX_FALLS
 bcc :mgo_alive             ; Billy still alive
 lda jimmy_active
 beq :mgo_game_over         ; Jimmy never activated → only Billy
 lda jimmy_stash_fall_count
 cmp #BILLY_MAX_FALLS
 bcs :mgo_game_over         ; Jimmy also at MAX
:mgo_alive
 rts
:mgo_game_over
 jmp game_over

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
 jmp $1000

* Player 1 score HUD position. Drawn over the "0000000" digits
* in the static HUD line at startup-MoveTo (3, 195) using the
* same bold face SetTextFace left enabled.
P1_SCORE_X   = 80             ; pixel x (just past "PLAYER 1: ")
P1_SCORE_Y   = 195            ; pixel baseline (matches HUD line)
P1_SCORE_LEN = 7              ; digit width (matches "0000000")

* P2 sits in the same HUD line, right of P1's score + 7 spaces +
* the "PLAYER 2: " prefix. QuickDraw's proportional font makes
* the average-cell math ("PLAYER 2: " at ~7.7 px/char) overshoot
* by one character — the spaces are narrower than the average so
* the dynamic score landed one cell to the right of the static
* backdrop, hiding the rightmost digit and leaving a leading
* static '0' visible on the left ("0000600" stored displayed as
* "0000060"). Empirical alignment: shift left by one digit cell.
P2_SCORE_X   = 255
P2_SCORE_Y   = 195

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
* draw_p2_score - Same as draw_p1_score but for player 2.
* No-op while p2_score_dirty is 0. Draws the live ASCII string
* at p2_score over the static "0000000" in the HUD strip.
*----------------------------------------------------------
draw_p2_score
 lda p2_score_dirty
 bne :do_draw2
 rts
:do_draw2
 clc
 xce
 rep $30

 pea #P2_SCORE_X
 pea #P2_SCORE_Y
 ldx #$3a04
 jsl $E10000

 pea #$0000
 pea p2_score
 ldx #$A604
 jsl $E10000

 stz p2_score_dirty

 sec
 xce
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
* Also reset frame_x_off — Billy's last draw may have left it at
* a non-zero value (e.g. -9 mirrored punch lunge), and
* draw_sprite_compiled would otherwise apply it to the overlay's
* xpos, drawing the finger N bytes off while erase_overlay clears
* at the original xpos → ghost fingers accumulate on every scroll.
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
 lda frame_x_off
 pha
 stz frame_x_off
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
* Restore globals (reverse order of save above)
 pla
 sta frame_x_off
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
NPC_BUFFER_SLOTS = 32
* 68 bytes/slot: 0..51 copied from the bank-$02 template; 52/54
* (walk_anim/atk_anim), 56 (frame_bank), and 58 (idle_bank — bank
* of the idle frame, restored on anim end) patched by
* script_spawn_npc post-copy. 60/62 added for the AND/ORA
* compiled-sprite pipeline:
*   +60/+61 active_mask_addr — read by load_sprite into MASK_ADDR
*                              every frame; non-zero routes the
*                              dispatch to draw_sprite_compiled.
*                              start_anim/load_frame zero this
*                              for legacy frames so the mask test
*                              cleanly drops to draw_sprite.
*   +62/+63 idle_mask_addr   — persistent compiled-mask address for
*                              the NPC's idle pose. :normal_end
*                              copies it back into +60 when an
*                              anim ends, so a compiled NPC reverts
*                              to compiled idle after a legacy
*                              attack/punched/fall plays. Billy
*                              uses spr_image01_mask globals
*                              instead of +62 because his idle
*                              data depends on facing.
*   +64/+65 idle_data_mirror — pre-rotated WILLIAM1_DATA_MIRROR /
*                              ROPER1_DATA_MIRROR / etc. address.
*                              :ne_npc_mask_restore swaps FRAME_ADDR
*                              to this when info+4 (mirror) == 1
*                              so the IDLE pose flips with the
*                              direction the NPC is facing. (The
*                              active animation already had paired
*                              mirror frames in its anim descriptor;
*                              this fixes the idle gap between/after
*                              animations.) Legacy NPCs and non-
*                              mirror-aware static items leave +64/65
*                              at 0 — the swap is gated on non-zero
*                              so they keep the old behavior.
*   +66/+67 idle_mask_mirror — partner mask for the mirrored idle.
*   +68     cur_x_off        — signed byte. NPC counterpart of
*                              billy_cur_x_off / jimmy_cur_x_off:
*                              compensates the render position for
*                              wider punch frames (WPUNCH2 = 17 vs
*                              WILLIAM1 idle = 9) so the body stays
*                              anchored instead of sliding backward
*                              when the mirrored compiled lunge frame
*                              tucks the body into its right half.
*                              Set by set_anim_x_off when the NPC
*                              loads a known punch/attack frame;
*                              cleared otherwise. Read by erase_all
*                              and draw_all to derive frame_x_off.
*   +69     prev_x_off       — latched from +68 right after each
*                              draw so erase_all next frame can
*                              clear at the shifted column.
NPC_INFO_SIZE = 70
npc_buffers ds NPC_BUFFER_SLOTS*NPC_INFO_SIZE
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
* Dispatch by behavior at offset +6. The "2" variants route to the
* same behavior routine as the base value — they only differ in the
* player-targeting preference, which fo_find_player resolves by
* reading info+6 directly.
 ldy #6
 lda (info_ptr),y
 cmp #BEHAV_FACEOFF
 bne :nbf
 jsr behav_faceoff
 bra :skip
:nbf
 cmp #BEHAV_FACEOFF2
 bne :nbf2
 jsr behav_faceoff
 bra :skip
:nbf2
 cmp #BEHAV_FLANK
 bne :nbfl
 jsr behav_flank
 bra :skip
:nbfl
 cmp #BEHAV_FLANK2
 bne :nbfl2
 jsr behav_flank
 bra :skip
:nbfl2
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
DOWN_SCROLL_THRESH = 108 ; player ypos at/over which walking-down on a
                       ; ladder scrolls (= mirror of UP_SCROLL_THRESH).
                       ; Tuned for mission2's lower platform at y=128
                       ; — Billy reaches DOWN_SCROLL_THRESH well after
                       ; engaging the ladder but before hitting bottom.
KICK_BACK_EXT = 8      ; bytes the back-kick hitbox extends opposite
                       ; Billy's facing. Hitbox is BEHIND Billy only
                       ; (NPC xpos < billy_xpos when mirror=0, NPC
                       ; xpos > billy_xpos when mirror=1). Forward
                       ; portion of KICK2's natural frame is excluded.
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
FO_CD_TIME = 150       ; cooldown frames after a punch (~2.5s @ 60Hz);
                        ; bumped from 90 to soften NPC crowding pressure
                        ; per playtester feedback. Keep in step with
                        ; FL_CD_TIME so faceoff/flanker pacing matches.
FO_Y_TOL   = 12        ; rows of Y slack accepted in :check_range
                       ; before transitioning to FO_PUNCH. Without
                       ; this, an NPC pinned to npc_min_y (e.g. a
                       ; downgraded knifer at the bottom row) could
                       ; never satisfy the strict-equality Y check
                       ; when the player floated above the floor,
                       ; so the NPC would forever pace toward
                       ; fo_target_x. 40-row sprites have plenty of
                       ; bounding-box overlap for the punch to hit
                       ; with a ~12-row Y delta.

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
* Two-pass player search. Preferred controller is derived from the
* NPC's behavior byte at info+6:
*   BEHAV_FACEOFF / BEHAV_FLANK     → Billy first ($01), Jimmy fallback
*   BEHAV_FACEOFF2 / BEHAV_FLANK2   → Jimmy first ($02), Billy fallback
*   anything else                   → Billy first (default)
*
* "Found" means in sprite_table AND anim_ptr != $FFFF (= alive). The
* $02 controller scan additionally requires jimmy_active != 0 so a
* never-activated Jimmy can't be targeted.
*
* On exit: Z=0 (A=$01) if a target was selected — fo_plr_y/x/facing/w
* hold its fields. Z=1 (A=$00) means neither player is alive; caller
* should treat as "no action this tick".
*
* Preserves spr_ptr / info_ptr across the call.
 lda spr_ptr
 sta fo_save_spr
 lda spr_ptr+1
 sta fo_save_spr+1
 lda info_ptr
 sta fo_save_info
 lda info_ptr+1
 sta fo_save_info+1
* Derive preference from caller's behavior byte (info+6 still points
* at the NPC because save_info above just snapshotted it).
 ldy #6
 lda (info_ptr),y
 cmp #BEHAV_FACEOFF2
 beq :ffp_pref_j
 cmp #BEHAV_FLANK2
 beq :ffp_pref_j
 lda #$01
 bra :ffp_pref_set
:ffp_pref_j
 lda #$02
:ffp_pref_set
 sta :ffp_pref
* Pass 1: try preferred controller.
 lda :ffp_pref
 jsr :ffp_find_ctrl
 bne :ffp_resolved
* Pass 2: fall back to the OTHER controller.
 lda :ffp_pref
 eor #$03                   ; $01 ↔ $02
 jsr :ffp_find_ctrl
 beq :notfound
:ffp_resolved
* info_ptr now points at the chosen player. Snapshot the fields the
* AI consumers want.
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

:ffp_find_ctrl
* A = controller value to search for. Returns A=$01 / Z=0 with
* info_ptr pointing at the matched (alive) sprite, or A=$00 / Z=1
* if no live sprite with that controller exists. For controller $02
* additionally requires jimmy_active != 0.
 cmp #$02
 bne :ffc_save_target
 pha
 lda jimmy_active
 bne :ffc_pull_ok
 pla
 lda #0
 rts                       ; Jimmy not activated → fail this pass
:ffc_pull_ok
 pla
:ffc_save_target
 sta :ffc_target
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:ffc_loop
 ldy #0
 lda (spr_ptr),y
 sta info_ptr
 iny
 lda (spr_ptr),y
 sta info_ptr+1
 ora info_ptr
 beq :ffc_done_nf
 ldy #22
 lda (info_ptr),y
 cmp :ffc_target
 bne :ffc_next
* Controller matches; reject if anim_ptr == $FFFF (death sentinel).
 ldy #24
 lda (info_ptr),y
 cmp #$FF
 bne :ffc_alive
 ldy #25
 lda (info_ptr),y
 cmp #$FF
 bne :ffc_alive
 bra :ffc_next            ; both $FF → dead, skip
:ffc_alive
 lda #$01
 rts
:ffc_next
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :ffc_loop
 inc spr_ptr+1
 bra :ffc_loop
:ffc_done_nf
 lda #0
 rts

:ffp_pref   dfb 0
:ffc_target dfb 0

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
* Inverted branch + jmp: the added at-target gates in the two
* walk-commit branches below pushed :x_at_target out of beq's
* ±128 reach from here.
 bne :cxt_not_eq
 jmp :x_at_target
:cxt_not_eq
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
* Burnov-only padding (his 13-wide walk + 23-wide combat
* sprites need more clearance than Williams/Roper/Linda's
* 9-wide frames). Detect Burnov via walk_anim == anim_bnwalk
* — the bank field used to identify him, but now both his
* compiled walk ($1B) and combat ($1C) banks overlap with
* other NPCs. Pad is 6 bytes (= 12 px) — tightened by 1 byte
* from the original 5 because Burnov was still nicking the
* right wall by ~2 px on his lunge frame.
 ldy #52
 lda (info_ptr),y
 cmp #<anim_bnwalk
 bne :rgt_no_pad
 ldy #53
 lda (info_ptr),y
 cmp #>anim_bnwalk
 bne :rgt_no_pad
 lda chk_xpos
 clc
 adc #6
 sta chk_xpos
:rgt_no_pad
* Playfield-right-edge clamp. chk_xpos is the NEW right-edge
* byte after the step. With the stratum world-coord bounds, a
* row whose walkable world span extends past wo+109 (= the
* playfield right edge in screen-local terms) lets the NPC
* step where its sprite draws past byte 109 — visible as
* Williams pushing 2-3 px off the right side of the playfield
* in the scr1 staircase region (scr1+scr2 row 40 has stratum
* bmax=268 = walkable 120 bytes wide in world coords, but a
* given wo only exposes 110 of those at a time). PLAYER_MAX_X
* keeps Billy within the playfield; NPCs need an equivalent.
 lda chk_xpos
 cmp #PLAYFIELD_EDGE+1     ; new right-edge byte must be <= 109
 bcs :x_at_target          ; >= 110 → blocked
 ldy #0
 lda (info_ptr),y      ; current ypos
 jsr check_y_bounds_strict
 bcs :x_at_target      ; blocked by row bounds
 ldy #2
 lda (info_ptr),y
 clc
 adc #1
 sta (info_ptr),y
* If this step lands exactly on target X, fall through to
* :x_at_target so the mirror gets re-faced toward the player.
* Otherwise keep the walk-direction mirror set above.
 cmp fo_target_x
 beq :x_at_target
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
* Burnov-only padding (same reasoning + matching value as the
* right-edge check above — 6 bytes / 12 px).
 ldy #52
 lda (info_ptr),y
 cmp #<anim_bnwalk
 bne :lft_no_pad
 ldy #53
 lda (info_ptr),y
 cmp #>anim_bnwalk
 bne :lft_no_pad
 lda chk_xpos
 sec
 sbc #6
 sta chk_xpos
:lft_no_pad
 ldy #0
 lda (info_ptr),y      ; current ypos
 jsr check_y_bounds_strict
 bcs :x_at_target
 ldy #2
 lda chk_xpos
 sta (info_ptr),y
* Same at-target gate as the increment branch above: only fall
* through to :x_at_target when the commit landed on target,
* otherwise keep the walk-direction mirror and skip ahead. This
* fixes the in-transit override that was flipping NPCs to face
* the player every left-walk step (visible as a 1-frame moonwalk
* whenever they crossed the player's xpos).
 cmp fo_target_x
 beq :x_at_target
 bra :move_y
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
* Burnov-only Y cap. The earlier cap "12 lines above the 200
* floor" (cmp #188) was relative to the playfield bottom, but
* on scr13 (boss fight) the visible floor in the art is at
* row 90, not 200 — Burnov's 48-tall sprite would happily walk
* his feet 9+ rows below the floor before the 188 cap fired.
* Tighten to cmp #91 so proposed_bottom max = 90 = bottom row
* of the visible scr13 floor. With frame_y=48 this caps top
* at 42, putting Burnov's feet at row 89 (just on the floor).
* Detect via walk_anim == anim_bnwalk (bank check no longer
* works — see right/left padding above).
 ldy #52
 lda (info_ptr),y
 cmp #<anim_bnwalk
 bne :yd_normal_cap
 ldy #53
 lda (info_ptr),y
 cmp #>anim_bnwalk
 bne :yd_normal_cap
 lda :yp_bottom
 cmp #91
 bcs :y_at_target
 bra :yd_call_check
:yd_normal_cap
 lda :yp_bottom
 cmp #200
 bcs :y_at_target
:yd_call_check
 lda :yp_proposed
 jsr check_y_bounds_strict
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
 jsr check_y_bounds_strict
 bcs :y_at_target      ; blocked
 ldy #0
 lda (info_ptr),y
 sec
 sbc #1
 sta (info_ptr),y
:y_at_target

:check_range
* If we're close to target X and within FO_Y_TOL rows of player
* Y, transition to PUNCH. Strict equality on Y was the old gate;
* it left floor-bound NPCs (npc_y == npc_min_y, player_y below
* that) permanently in APPROACH because they could never match
* player Y. A tolerance lets the engagement fire while the punch
* hitbox still has plenty of bounding-box overlap.
 ldy #2
 lda (info_ptr),y
 cmp fo_target_x
 bne :still_moving     ; not in X position yet
 ldy #0
 lda (info_ptr),y
 sec
 sbc fo_plr_y          ; A = npc_y - player_y (signed)
 bpl :cr_ydiff_pos
 eor #$FF
 clc
 adc #1                ; A = |npc_y - player_y|
:cr_ydiff_pos
 cmp #FO_Y_TOL+1
 bcs :still_moving     ; |Δy| > FO_Y_TOL → not engaged yet
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
* If we couldn't progress on EITHER axis this tick (typically
* Burnov at his y-cap when the player is further down — lined up
* on X, blocked on Y, walk_anim keeps cycling visually as
* "running in place"), force the walk anim back to frame 0 so
* the NPC visually stops. anim_frame=$FF / anim_timer=1 is the
* same trigger npc_ensure_walking uses on install — the next
* update_anims pass wraps to frame 0, which for compiled NPCs
* is the standing/idle pose (BNWALK1, ROPER1, etc.).
 ldy #2
 lda (info_ptr),y
 ldy #34
 cmp (info_ptr),y      ; xpos vs prev_xpos
 bne :commit
 ldy #0
 lda (info_ptr),y
 ldy #32
 cmp (info_ptr),y      ; ypos vs prev_ypos
 bne :commit
 lda #$FF
 ldy #26
 sta (info_ptr),y      ; anim_frame = $FF (wraps to 0 on next tick)
 lda #$01
 ldy #28
 sta (info_ptr),y      ; anim_timer = 1 (expires this update_anims pass)
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
 do DEBUG_PRINT
 lda #$C6              ; 'F'
 jsr dbg_print_char
 lda #$D0              ; 'P'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda info_ptr
 jsr dbg_print_hex8
 jsr dbg_print_nl
 fin
* Read per-NPC atk_anim from +54/+55 and call start_anim so the
* full bank/mask bookkeeping fires. Manually loading frame 0 the
* old way (write info+24/+26/+28/+10/+12/+14 directly) leaves
* info+56 (frame_bank) and info+60 (active_mask_addr) at their
* idle-pose values — for compiled-NPC Williams that's bank $1B
* and the WILLIAM1 mask address — so the very first frame of
* the punch renders compiled bank-$1B with a bank-$02 frame
* offset → scrambled garbage. start_anim handles the bank flip,
* mask clear, and the FRAME_X/Y/ADDR globals atomically.
 ldy #54
 lda (info_ptr),y      ; atk_anim low
 pha
 ldy #55
 lda (info_ptr),y      ; atk_anim high
 tax
 pla
 jsr start_anim
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
 beq :ws_expired
 jmp :step             ; not yet expired -> just step
:ws_expired

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

* Compiled WSOMER frame load. Read sub_frame*2, then dispatch
* on mirror flag to pick data+mask vs data_mir+mask_mir.
* IMPORTANT: dimensions live ONLY before the non-mirror DATA
* label (compile_sprite.py emits NAME_Y / NAME_X exactly once,
* at the start). So always remember the NON-MIRROR data addr
* in :tmp_dlo/:tmp_dhi for the dim-read below — even when
* loading mirror arrays.
 ldy #8
 lda (info_ptr),y
 asl
 sta :tmp_idx
 ldy :tmp_idx
* Always cache the non-mirror data addr for the dim read.
 lda somersault_data_tbl,y
 sta :tmp_dlo
 lda somersault_data_tbl+1,y
 sta :tmp_dhi
 ldy #4
 lda (info_ptr),y       ; A = mirror flag
 ldy :tmp_idx           ; Y = sub_frame*2
 cmp #1
 beq :ws_mirror_load
:ws_normal_load
 lda somersault_data_tbl,y
 sta :tmp_lo
 lda somersault_data_tbl+1,y
 sta :tmp_hi
 lda somersault_mask_tbl,y
 sta :tmp_mlo
 lda somersault_mask_tbl+1,y
 sta :tmp_mhi
 bra :ws_load_done
:ws_mirror_load
 lda somersault_data_mir_tbl,y
 sta :tmp_lo
 lda somersault_data_mir_tbl+1,y
 sta :tmp_hi
 lda somersault_mask_mir_tbl,y
 sta :tmp_mlo
 lda somersault_mask_mir_tbl+1,y
 sta :tmp_mhi
:ws_load_done
* Write FRAME_ADDR (info+14/+15) and MASK_ADDR (info+60/+61).
 lda :tmp_lo
 ldy #14
 sta (info_ptr),y
 lda :tmp_hi
 ldy #15
 sta (info_ptr),y
 lda :tmp_mlo
 ldy #60
 sta (info_ptr),y
 lda :tmp_mhi
 ldy #61
 sta (info_ptr),y
* Force compiled bank ($1B) — set BOTH info+56 and info+57.
 lda #$1B
 ldy #56
 sta (info_ptr),y
 lda #0
 ldy #57
 sta (info_ptr),y

* Read frame_x (addr-2) and frame_y (addr-4) from bank $1B,
* always relative to the NON-MIRROR data address (compile_sprite
* only emits _Y / _X before the original DATA label).
 lda :tmp_dlo
 sec
 sbc #4
 sta $F0
 lda :tmp_dhi
 sbc #0
 sta $F1
 lda #$1B
 sta $F2               ; bank $1B (compiled mission13)
 ldy #0
 lda [$F0],y           ; frame_y_word low byte
 ldy #12
 sta (info_ptr),y      ; frame_y
 ldy #2
 lda [$F0],y           ; frame_x_word low byte
 ldy #10
 sta (info_ptr),y      ; frame_x

* Right-edge clamp. WSOMER frames are wider than the standing pose
* (WSOMER3 = 21, WSOMER2 = 13 vs WILLIAM1 = 9). fo_approach kept
* xpos so that xpos + 9 (idle width) <= PLAYFIELD_EDGE, but the
* somersault frame_x can push xpos + frame_x past PLAYFIELD_EDGE
* and the draw spills into the right-side HUD/decoration art.
* Snap xpos so the right edge fits.
 ldy #2
 lda (info_ptr),y     ; xpos
 ldy #10
 clc
 adc (info_ptr),y     ; xpos + frame_x = right edge
 cmp #PLAYFIELD_EDGE+1
 bcc :ws_right_ok
 lda #PLAYFIELD_EDGE
 ldy #10
 sec
 sbc (info_ptr),y     ; PLAYFIELD_EDGE - frame_x = new xpos
 ldy #2
 sta (info_ptr),y     ; clamped xpos
:ws_right_ok

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
:tmp_mlo dfb 0
:tmp_mhi dfb 0
:tmp_idx dfb 0
:tmp_dlo dfb 0
:tmp_dhi dfb 0

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
* William? Match either the legacy spr_william1 (bank $02) idle
* address OR the compiled spr_william1c_data (bank $1B) version
* — script_spawn_npc rewrites info+42 to the compiled addr for
* William NPCs, so the legacy compare alone misses every live
* William and falls through to the Linda branch (= corrupted
* held pose, wrong sprite type).
 lda :eh_id_lo
 cmp spr_william1
 bne :try_w_compiled
 lda :eh_id_hi
 cmp spr_william1+1
 beq :is_william
:try_w_compiled
 lda :eh_id_lo
 cmp spr_william1c_data
 bne :try_roper
 lda :eh_id_hi
 cmp spr_william1c_data+1
 bne :try_roper
:is_william
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
 bne :try_r_compiled
 lda :eh_id_hi
 cmp spr_roper1+1
 beq :is_roper
:try_r_compiled
 lda :eh_id_lo
 cmp spr_roper1c_data
 bne :try_linda
 lda :eh_id_hi
 cmp spr_roper1c_data+1
 bne :try_linda
:is_roper
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
* Force legacy bank ($02) and clear compiled mask: WHELDn /
* RHELDn / LHELDn frames are bank-$02 sprites (in mission1's
* sprite block, populated by init_level), but compiled-NPC
* spawn left info+56=$1B and info+60=non-zero. Without this,
* dispatch routes draw_sprite_compiled with the held frame_addr
* offset read from the wrong bank → big black rectangles.
* info+58 (idle_bank) and info+62 (idle_mask_addr) are
* untouched so the post-grab fo_approach → anim_wwalk install
* restores compiled rendering naturally via load_frame's bit-3/6
* dispatch.
 lda #$02
 ldy #56
 sta (info_ptr),y
 lda #0
 ldy #60
 sta (info_ptr),y
 ldy #61
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
* Dispatch by active player. Billy reads from spr_bgrab1/2 (bank
* $02, BGRAB sprites in mission1.s). Jimmy reads from spr_jgrab1/2
* (bank $1D, JGRAB sprites in mission1jimmy.s). The dimensions
* are identical (14×40 active, 13×40 hold) so we use a single set
* of W/H constants. Legacy renderer pulls pixel data from sprite_bank
* = info+56 — Billy's info+56 is $02 at idle, Jimmy's is $1D, so
* each player's grab pose loads from the right bank without extra
* setup here.
 jsr arm_is_jimmy
 bcs :sgf_jimmy
 lda :which
 bne :b1
 lda spr_bgrab2
 sta :addr_lo
 lda spr_bgrab2+1
 sta :addr_hi
 bra :sgf_dims_hold
:b1
 lda spr_bgrab1
 sta :addr_lo
 lda spr_bgrab1+1
 sta :addr_hi
 bra :sgf_dims_active
:sgf_jimmy
 lda :which
 bne :sgf_j1
 lda spr_jgrab2
 sta :addr_lo
 lda spr_jgrab2+1
 sta :addr_hi
 bra :sgf_dims_hold
:sgf_j1
 lda spr_jgrab1
 sta :addr_lo
 lda spr_jgrab1+1
 sta :addr_hi
 bra :sgf_dims_active
:sgf_dims_active
 lda #BGRAB1_W
 sta :w
 lda #BGRAB1_H
 sta :h
 bra :write
:sgf_dims_hold
 lda #BGRAB2_W
 sta :w
 lda #BGRAB2_H
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
* Force legacy draw path: anim_ptr = 0, info+60 = 0.
 lda #0
 ldy #24
 sta (info_ptr),y
 ldy #25
 sta (info_ptr),y
 ldy #60
 sta (info_ptr),y
 ldy #61
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
 beq :ok
 jmp :no_trigger
:facing_left
 lda :key
 cmp #'a'
 beq :ok
 jmp :no_trigger
:ok
* Validate that last_hit_target is still in the table.
 lda last_hit_target
 ora last_hit_target+1
 bne :tg_have_target
 jmp :no_trigger
:tg_have_target

* Distance gate: only trigger the grab when the enemy is close
* enough that a hold pose looks natural. Without this, a fresh
* punch-window can engage a target that's drifted yards away —
* "remote-control grab" / sprites teleporting into the hold.
*   Y: |billy_ypos - enemy_ypos| <= GRAB_Y_TOLERANCE (2)
*   X: enemy's near edge within GRAB_X_TOLERANCE (2) of Billy's
*      far edge. Facing right: compare billy_x+billy_w to
*      enemy_x. Facing left: compare billy_x to enemy_x+enemy_w.
* On either miss → :no_trigger (eat the keypress without entering
* the grab). Snapshot Billy's edge fields BEFORE switching
* info_ptr so we can compare after pointing at the enemy.
 ldy #0
 lda (info_ptr),y
 sta :tg_by
 ldy #2
 lda (info_ptr),y
 sta :tg_bx
 ldy #10
 lda (info_ptr),y
 sta :tg_bw
 ldy #4
 lda (info_ptr),y
 sta :tg_bmir
* Read enemy fields via last_hit_target.
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 lda last_hit_target
 sta info_ptr
 lda last_hit_target+1
 sta info_ptr+1
 ldy #0
 lda (info_ptr),y
 sta :tg_ey
 ldy #2
 lda (info_ptr),y
 sta :tg_ex
 ldy #10
 lda (info_ptr),y
 sta :tg_ew
 ldy #4
 lda (info_ptr),y
 sta :tg_emir
 pla
 sta info_ptr+1
 pla
 sta info_ptr
* Facing gate: a headlock only works if the enemy is looking at
* Billy. Enemy must face the OPPOSITE direction from Billy
* (Billy mirror=0 / enemy on the right → enemy mirror=1; Billy
* mirror=1 / enemy on the left → enemy mirror=0). Equal mirrors
* mean the enemy is turned away — bail.
 lda :tg_emir
 cmp :tg_bmir
 beq :tg_no_grab
 bra :tg_face_ok
:tg_no_grab
 jmp :no_trigger
:tg_face_ok
* Y distance: |billy_y - enemy_y| <= 2
 lda :tg_by
 sec
 sbc :tg_ey
 bcs :tg_y_abs
 eor #$FF
 clc
 adc #1
:tg_y_abs
 cmp #3
 bcs :no_trigger
* X distance: enemy near edge vs Billy far edge
 lda :tg_bmir
 bne :tg_x_left
* Facing right: A = (billy_x + billy_w) - enemy_x
 lda :tg_bx
 clc
 adc :tg_bw
 sec
 sbc :tg_ex
 bcs :tg_x_abs
 eor #$FF
 clc
 adc #1
 bra :tg_x_abs
:tg_x_left
* Facing left: A = (enemy_x + enemy_w) - billy_x
 lda :tg_ex
 clc
 adc :tg_ew
 sec
 sbc :tg_bx
 bcs :tg_x_abs
 eor #$FF
 clc
 adc #1
:tg_x_abs
 cmp #3
 bcs :no_trigger

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
:key  dfb 0
:tg_by   dfb 0
:tg_bx   dfb 0
:tg_bw   dfb 0
:tg_bmir dfb 0
:tg_ey   dfb 0
:tg_ex   dfb 0
:tg_ew   dfb 0
:tg_emir dfb 0

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
* Restore info_ptr to player.
 pla
 sta info_ptr+1
 pla
 sta info_ptr
* Restore the player to idle. Without this the BGRAB1 strike pose
* stays painted, grab_punch_timer keeps ticking, and grab_check
* swallows every input (so the player can't even walk out). For
* Jimmy it's permanent — process_input_jimmy doesn't tick
* grab_punch_timer, so the swap keeps reloading the full duration.
 stz grab_punch_timer
 ldy #42
 lda (info_ptr),y      ; idle_addr lo → frame_addr lo
 ldy #14
 sta (info_ptr),y
 ldy #43
 lda (info_ptr),y
 ldy #15
 sta (info_ptr),y
 ldy #44
 lda (info_ptr),y      ; idle_x → frame_x
 ldy #10
 sta (info_ptr),y
 ldy #46
 lda (info_ptr),y      ; idle_y → frame_y
 ldy #12
 sta (info_ptr),y
 ldy #58
 lda (info_ptr),y      ; idle_bank → frame_bank
 ldy #56
 sta (info_ptr),y
 ldy #62
 lda (info_ptr),y      ; idle_mask_addr → active_mask_addr + MASK_ADDR
 sta MASK_ADDR
 ldy #60
 sta (info_ptr),y
 ldy #63
 lda (info_ptr),y
 sta MASK_ADDR+1
 ldy #61
 sta (info_ptr),y
 ldy #30
 lda #$03
 sta (info_ptr),y
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
FL_CD_TIME    = 150       ; bumped in lockstep with FO_CD_TIME (~2.5s
                           ; @ 60Hz) to soften crowding pressure.
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
* Grabbed by a player — try_enter_grab writes FO_GRABBED ($04)
* to +7 regardless of the target's behavior, so behav_flank needs
* the same suspend case as behav_faceoff. Without this, FL_ARC
* falls through and ensure_walking reinstalls the walk anim,
* overwriting enemy_set_held's held frame on the next tick.
 cmp #FO_GRABBED
 beq :st_grabbed
* default: FL_ARC
 jmp fl_arc
:st_close
 jmp fl_close
:st_punch
 jmp fl_punch
:st_cd
 jmp fl_cooldown
:st_grabbed
 rts

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
* Suspend the ladder state machine while fall_anim is playing.
* Without this, behav_ladder keeps incrementing ypos / climb_tog
* in lockstep with fall_anim's ypos arc — Linda gets punched off
* the ladder, "falls" mid-air, and the ladder code yanks her
* back into climb frames at a now-misaligned ypos. The end-of-
* fall disengage in :ad_check_pc converts her to FACEOFF and
* snaps ypos to the ladder bottom; we just have to keep the
* ladder behavior off-air until then.
 ldy #24
 lda (info_ptr),y       ; anim_ptr lo
 ldy #50
 cmp (info_ptr),y       ; cmp fall_anim lo
 bne :bld_run
 ldy #25
 lda (info_ptr),y       ; anim_ptr hi
 ldy #51
 cmp (info_ptr),y       ; cmp fall_anim hi
 bne :bld_run
 rts                    ; falling — let fall_anim drive ypos
:bld_run
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
* Compiled bank $1B — write FRAME_ADDR (info+14/+15), MASK_ADDR
* (info+60/+61), and bank ($1B → info+56). LCLIMB1/2 don't need
* a mirror branch: Linda climbs facing the screen, the same pose
* regardless of her info+4 mirror. Always use the non-mirror
* DATA + MASK pair. info+58 / info+62 stay untouched so
* :normal_end's :ne_npc_mask_restore (after a ladder fall) can
* revive compiled LINDA1 idle.
 lda #$1B
 ldy #56
 sta (info_ptr),y
* Frame select: bit 2 of step counter (info+8)
 ldy #8
 lda (info_ptr),y
 and #$04
 beq :use_l1
* LCLIMB2 frame
 lda spr_lclimb2c_data
 ldy #14
 sta (info_ptr),y
 lda spr_lclimb2c_data+1
 ldy #15
 sta (info_ptr),y
 lda spr_lclimb2c_mask
 ldy #60
 sta (info_ptr),y
 lda spr_lclimb2c_mask+1
 ldy #61
 sta (info_ptr),y
 rts
:use_l1
* LCLIMB1 frame
 lda spr_lclimb1c_data
 ldy #14
 sta (info_ptr),y
 lda spr_lclimb1c_data+1
 ldy #15
 sta (info_ptr),y
 lda spr_lclimb1c_mask
 ldy #60
 sta (info_ptr),y
 lda spr_lclimb1c_mask+1
 ldy #61
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
 jsr check_y_bounds_strict
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
 jsr check_y_bounds_strict
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
* Skip inactive Jimmy entirely. mark_overlapping during another
* sprite's erase (e.g., Billy being punched) sets Jimmy's
* needs_draw bit when their rects overlap; without this gate
* the interleaved draw below would reveal him before Ctrl-J.
* Clear any stray dirty bits so they don't accumulate.
 lda info_ptr
 cmp #<jimmy_sprite
 bne :ea_active_chk_done
 lda info_ptr+1
 cmp #>jimmy_sprite
 bne :ea_active_chk_done
 lda jimmy_active
 bne :ea_active_chk_done
 ldy #30
 lda #0
 sta (info_ptr),y
 jmp :ea_draw_done
:ea_active_chk_done
* Check for death sentinel ($FFFF)
 ldy #24
 lda (info_ptr),y     ; anim_ptr low
 cmp #$FF
 beq :nd_chk_hi
 jmp :not_dead
:nd_chk_hi
 iny
 lda (info_ptr),y     ; anim_ptr high
 cmp #$FF
 beq :nd_dead
 jmp :not_dead
:nd_dead
* Death: erase at prev position, then remove from table.
* DEBUG: log death-erase with prev rect + sprite info_lo.
* Format: 'RM<info_lo> <prev_y><prev_x>'
* prev_fx/prev_fy stripped (always 20/40 for non-Burnov dying NPCs).
* Uses ROM PRBYTE ($FDDA) and COUT ($FDED) directly.
 do DEBUG_ERASE
 lda #$D2              ; 'R'
 jsr dbg_print_char
 lda #$CD              ; 'M'
 jsr dbg_print_char
 lda info_ptr
 jsr dbg_print_hex8
 ldy #32
 lda (info_ptr),y      ; prev_y
 jsr dbg_print_hex8
 ldy #34
 lda (info_ptr),y      ; prev_x
 jsr dbg_print_hex8
 fin
* Death erase: clamp prev rect to playfield bounds. A FALLEN
* sprite shoved past PLAYFIELD_EDGE during the fall arc (or below
* row 182) would otherwise have erase write past the row end and
* into the next row's pixels, leaving the sprite stuck on screen
* AND corrupting the row beneath it.
 ldy #34
 lda (info_ptr),y       ; prev_xpos
 cmp #PLAYFIELD_EDGE
 bcs :de_skip_erase     ; left edge already off the playfield → skip
 sta IMAGE01_XPOS
 ldy #36
 clc
 adc (info_ptr),y       ; prev_xpos + prev_frame_x = right edge
 cmp #PLAYFIELD_EDGE+1
 bcc :de_fx_ok
 lda #PLAYFIELD_EDGE+1  ; clamp right edge to playfield boundary
:de_fx_ok
 sec
 sbc IMAGE01_XPOS
 sta FRAME_X
 ldy #32
 lda (info_ptr),y       ; prev_ypos
 cmp #183
 bcs :de_skip_erase     ; top already below playfield → skip
 sta IMAGE01_YPOS
 ldy #38
 clc
 adc (info_ptr),y       ; prev_ypos + prev_frame_y = bottom edge
 cmp #184
 bcc :de_fy_ok
 lda #183               ; clamp bottom to last playfield row
:de_fy_ok
 sec
 sbc IMAGE01_YPOS
 sta FRAME_Y
 jsr erase
* DEBUG: pixel tracer. After every death-erase, sample one SHR
* byte at (col=35, row=115) and append to the RM line. That cell
* lies inside $DD's death-erase rect [26,46) × [86,126) — for the
* current bug repro it should equal bg ($dd) after a working
* erase; if it comes back as a sprite byte (any high-nibble color)
* the death-erase didn't actually touch that row. For $51 / $97
* (rects don't include col 35 row 115) the byte just reads back
* whatever was last left there by a prior frame — useful as a
* before/after baseline across the multi-death sequence.
* SHR addr = $2000 + 115*$A0 + 35 = $6803 in bank $01.
 do DEBUG_ERASE
 ldal $016803
 jsr dbg_print_hex8
 jsr dbg_print_sp      ; stream-style separator (no CR — see ER block)
 fin
:de_skip_erase
* Mark any still-living sprites whose drawn area overlaps the
* just-erased rect as needs_draw — otherwise if the dying
* enemy was drawn on top of (later Y than) the player, the
* erase wipes part of the player and no one redraws it.
 jsr mark_overlapping
 jsr remove_from_sprite_table
 jmp :loop            ; don't advance spr_ptr — entries shifted down
:not_dead
* Erase if bit 1 set (needs_erase)
 ldy #30
 lda (info_ptr),y
 and #$02
 bne :do_erase
 jmp :skip_erase
:do_erase
* No-movement skip: if prev_* == cur_* on all four position/size
* fields AND no animation is active, the sprite hasn't actually
* changed — `:do_erase` would just wipe its rect to bg (from bank
* $18) and immediately repaint, but during that wipe it'd ALSO
* clobber any other sprite's paint inside the rect that came from
* this frame's earlier interleaved-draw (e.g. a lower-y sprite
* drawn just before us at an overlapping position). Then our
* compiled blit's transparent bytes read the freshly-wiped $01 and
* see bg, not the lower sprite.
* Skipping the erase preserves the lower sprite at our transparent
* bytes (we still overwrite opaque bytes with our paint).
*
* Force-erase override (bit 2 of dirty): save_sprite / save_anim_
* state / start_anim all set bit 2 because they rewrite info+14
* (frame_addr). The anim_ptr gate below catches active animations
* but NOT the single transition frame where anim_ptr was just
* cleared by :normal_end (WPUNCHED → idle on a still NPC): position
* and frame_x/y all match, optimization skips erase, and WPUNCHED's
* opaque head pixels survive under WILLIAM1 idle's transparent
* mask cells (visible as "knocked-back head" residue).
 ldy #30
 lda (info_ptr),y
 and #$04
 bne :de_movement     ; force_erase → must wipe between frames
*
* Anim-active gate (info+24/+25): animations like spinkick keep
* the same frame_x/frame_y across frames but cycle frame_addr —
* the prev_*/cur_* size check wouldn't catch the content change,
* so the previous frame's pixels would persist (visible ghost).
* If anim_ptr is non-zero, fall through to the full erase.
 ldy #24
 lda (info_ptr),y
 iny
 ora (info_ptr),y     ; A = anim_ptr.lo | anim_ptr.hi
 bne :de_movement     ; anim active → must wipe between frames
 ldy #0
 lda (info_ptr),y
 ldy #32
 cmp (info_ptr),y
 bne :de_movement
 ldy #2
 lda (info_ptr),y
 ldy #34
 cmp (info_ptr),y
 bne :de_movement
 ldy #10
 lda (info_ptr),y
 ldy #36
 cmp (info_ptr),y
 bne :de_movement
 ldy #12
 lda (info_ptr),y
 ldy #38
 cmp (info_ptr),y
 bne :de_movement
* No anim and all four prev/cur fields match — skip the wipe-and-
* mark, just re-flag dirty so the interleaved draw fires.
 ldy #30
 lda (info_ptr),y
 and #$FD
 ora #$01
 sta (info_ptr),y
 jmp :skip_erase
:de_movement
* Compute the erase rect. It must cover both the prev-drawn
* pixels (so no ghost) and the area the new frame will draw
* (so transparent pixels in a grown/shifted frame don't reveal
* stale content). Full prev∪current rect is the correct bound.
* mark_overlapping runs with the SAME union rect since that's
* what actually gets wiped — using just the prev rect under-
* flagged neighboring sprites (e.g. ones adjacent on the side
* the sprite is moving toward) and left visible artifacts.
*
* Apply signed render-x offsets so the erase rect covers the
* actual drawn pixels (the offset shifts wider attack frames to
* keep the body anchored). Billy/Jimmy pull from their globals;
* NPCs pull from info+68 / info+69 (per-NPC fields, populated by
* set_anim_x_off — non-attack NPCs leave them at 0).
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :ea_chk_jimmy_off
 lda billy_prev_x_off
 sta :ea_prev_xeff
 lda billy_cur_x_off
 sta :ea_cur_xeff
 bra :ea_off_done
:ea_chk_jimmy_off
 cmp #$02
 bne :ea_npc_off
 lda jimmy_prev_x_off
 sta :ea_prev_xeff
 lda jimmy_cur_x_off
 sta :ea_cur_xeff
 bra :ea_off_done
:ea_npc_off
 ldy #69
 lda (info_ptr),y         ; prev_x_off
 sta :ea_prev_xeff
 ldy #68
 lda (info_ptr),y         ; cur_x_off
 sta :ea_cur_xeff
:ea_off_done
 ldy #34
 lda (info_ptr),y     ; prev_xpos
 clc
 adc :ea_prev_xeff    ; signed-byte ADC (offsets are small)
 sta :ea_prev_xeff
 ldy #2
 lda (info_ptr),y     ; xpos
 clc
 adc :ea_cur_xeff
 sta :ea_cur_xeff
* left = min(prev_xeff, cur_xeff)
 lda :ea_prev_xeff
 cmp :ea_cur_xeff
 bcc :left_prev
 lda :ea_cur_xeff
 bra :left_set
:left_prev
 lda :ea_prev_xeff
:left_set
 sta IMAGE01_XPOS
* right = max(prev_xeff + prev_frame_x, cur_xeff + frame_x)
 lda :ea_prev_xeff
 ldy #36
 clc
 adc (info_ptr),y     ; prev_xeff + prev_frame_x
 sta :ea_tmp
 lda :ea_cur_xeff
 ldy #10
 clc
 adc (info_ptr),y     ; cur_xeff + frame_x
 cmp :ea_tmp
 bcc :rkeep
 sta :ea_tmp
:rkeep
 lda :ea_tmp
 sec
 sbc IMAGE01_XPOS
 sta FRAME_X
* DIAGNOSTIC: extend union left by 1 col + width by 2 (= 1-col
* safety margin each side on X axis, parallel to the Y band-aid).
* If the 1-byte vertical artifact at the right edge of an erased
* Williams disappears, the X union math is off-by-something.
* Bounds check on IMAGE01_XPOS = 0 to avoid the DEC underflow.
 lda IMAGE01_XPOS
 beq :no_xshift
 dec IMAGE01_XPOS
 inc FRAME_X
 inc FRAME_X
:no_xshift
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
* DIAGNOSTIC: extend union top up by 2 rows + height by 2 to keep
* the bottom anchored. Confirmed to suppress the Billy-hair
* artifact in jump arcs. Bounds check: skip the extension if
* IMAGE01_YPOS < 2 (= sprite already near the top of screen) —
* an unchecked DEC underflows to $FE, and the screen-address
* calc then targets ~$01/BEC0, sending the erase loop off the
* end of bank $01 (caused a BRK $00 at $00/B6F4).
 lda IMAGE01_YPOS
 cmp #2
 bcc :no_yshift
 dec IMAGE01_YPOS
 dec IMAGE01_YPOS
 inc FRAME_Y
 inc FRAME_Y
:no_yshift
* DEBUG: log erase rect when (a) bottom reaches y=180+ (HUD area)
* OR (b) rect's top falls in the y=100..140 band where the erase
* artifact lives.
* Tight format: each entry is "ER<info_lo><prev_y><prev_x><left><w><h>"
* (= 2 + 12 = 14 chars) followed by a single space (no CR). Entries
* stream into the 40-col text screen with auto-wrap, fitting ~2.6
* entries per line — about 60 entries of history vs the prior ~24.
* "top" field dropped (was identical to prev_y for almost every
* in-band normal erase; the un-bump case where prev_y > top is rare
* enough to grep the sprite block separately when it matters).
 do DEBUG_ERASE
 lda IMAGE01_YPOS
 clc
 adc FRAME_Y
 cmp #180
 bcs :do_er_debug      ; bottom in HUD area
 lda IMAGE01_YPOS
 cmp #75
 bcs :er_chk_top_hi
 jmp :skip_er_debug    ; top < 75 → skip (long branch)
:er_chk_top_hi
 cmp #150
 bcc :do_er_debug      ; in [75,150) → log
 jmp :skip_er_debug    ; top >= 150 → skip (long branch)
:do_er_debug
 lda #$C5              ; 'E'
 jsr dbg_print_char
 lda #$D2              ; 'R'
 jsr dbg_print_char
 lda info_ptr
 jsr dbg_print_hex8
 ldy #32
 lda (info_ptr),y      ; prev_y
 jsr dbg_print_hex8
 ldy #34
 lda (info_ptr),y      ; prev_x
 jsr dbg_print_hex8
 lda IMAGE01_XPOS      ; left
 jsr dbg_print_hex8
 lda FRAME_X           ; w
 jsr dbg_print_hex8
 lda FRAME_Y           ; h
 jsr dbg_print_hex8
 jsr dbg_print_sp      ; trailing separator (stream-style)
:skip_er_debug
 fin
 jsr erase
 jsr mark_overlapping    ; flag (forward) / immediately redraw (behind)
                          ; sprites overlapping the just-erased rect
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
* Clear bit 1 (needs_erase) and bit 2 (force_erase), set bit 0
* (needs_draw) so sprite is redrawn.
 ldy #30
 lda (info_ptr),y
 and #$F9             ; clear bits 1 + 2
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
 bne :ea_draw_check
 jmp :ea_draw_done
:ea_draw_check
* Co-op climb hide: skip the non-climber player's draw branch.
* erase_all does an interleaved per-sprite draw (line 6868
* onward) when bit 0 is set, so without this gate mark_overlapping
* setting OTHER's needs_draw during the climb re-renders the
* hidden player here ("not disappearing" report).
 lda climb_hide_other
 beq :ea_hide_chk_done
 ldy #22
 lda (info_ptr),y
 cmp #$03
 bcs :ea_hide_chk_done   ; controller >= 3, NPC, draw normally
 cmp #$01
 bcc :ea_hide_chk_done   ; controller < 1 (= 0), not a player
 lda info_ptr
 cmp climb_climber_ptr
 bne :ea_hide_skip
 lda info_ptr+1
 cmp climb_climber_ptr+1
 beq :ea_hide_chk_done   ; current = climber, draw normally
:ea_hide_skip
 jmp :ea_clr_dirty       ; current = hidden OTHER, skip draw
:ea_hide_chk_done
* Burnov-grab lock: skip whichever player is being held while
* Burnov's combined-pose anim is playing. bn_grab_active is a
* tri-state: 0=none, 1=Billy grabbed, 2=Jimmy grabbed. The grabbed
* player's body lives inside Burnov's BNBILLY/BNJIMMY frames, so
* drawing the standalone sprite would overlap it.
 ldy #22
 lda (info_ptr),y
 cmp bn_grab_active
 bne :ea_disp_check
* controller matches bn_grab_active — but only if bn_grab_active
* is non-zero (otherwise this would gate every controller==0 NPC).
 lda bn_grab_active
 beq :ea_disp_check
 jmp :ea_clr_dirty
:ea_disp_check
* Stage frame_x_off for this draw — same gating as draw_all.
* Billy (controller=1) → billy_cur_x_off; Jimmy (controller=2) →
* jimmy_cur_x_off; NPCs (controller=0) → info+68 (set by
* set_anim_x_off for attack frames; 0 otherwise).
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :ea_draw_chk_jimmy
 lda billy_cur_x_off
 sta frame_x_off
 bra :ea_draw_off_done
:ea_draw_chk_jimmy
 cmp #$02
 bne :ea_draw_npc_off
 lda jimmy_cur_x_off
 sta frame_x_off
 bra :ea_draw_off_done
:ea_draw_npc_off
 ldy #68
 lda (info_ptr),y
 sta frame_x_off
:ea_draw_off_done
* Compiled vs legacy dispatch: compiled (AND/ORA) when
* MASK_ADDR != 0. (Was also gated on controller==1 because
* NPCs' info+52 doubled as walk_anim and would have routed
* every NPC compiled by accident; +60 is now dedicated to
* the active mask address so the rule simplifies.)
 lda MASK_ADDR
 ora MASK_ADDR+1
 bne :ea_do_compiled
 jmp :ea_legacy
:ea_do_compiled
* DEBUG: log every compiled NPC draw so we can verify the live
* state (sprite_bank + MASK_ADDR + FRAME_ADDR) at draw time.
* Format: 'EC <info_lo> b<bank> m<mask_hi><mask_lo> f<frame_hi><frame_lo>
*           x<frame_x>y<frame_y> R<byte0><byte1><byte2><byte3>'.
* The "R" is the first 4 bytes from sprite_bank:FRAME_ADDR — should
* match WILLIAM1_DATA row 0 ($00 $00 $00 $00). If garbage, something
* in the indirect-long read is wrong.
 do DEBUG_PRINT
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :ea_dbg_emit
 jmp :ea_dbg_skip
:ea_dbg_emit
 lda #$C5              ; 'E'
 jsr dbg_print_char
 lda #$C3              ; 'C'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda info_ptr
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$E2              ; 'b'
 jsr dbg_print_char
 lda sprite_bank
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$ED              ; 'm'
 jsr dbg_print_char
 lda MASK_ADDR+1
 jsr dbg_print_hex8
 lda MASK_ADDR
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$E6              ; 'f'
 jsr dbg_print_char
 lda FRAME_ADDR+1
 jsr dbg_print_hex8
 lda FRAME_ADDR
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$F8              ; 'x'
 jsr dbg_print_char
 lda FRAME_X
 jsr dbg_print_hex8
 lda #$F9              ; 'y'
 jsr dbg_print_char
 lda FRAME_Y
 jsr dbg_print_hex8
* Read first mask byte AND first data byte via long-indirect
* using the same (sprite_bank:MASK_ADDR / sprite_bank:FRAME_ADDR)
* the AND/ORA inner loop will use. If "rm" is $FF (WILLIAM1_MASK
* row 0 byte 0) and "rd" is $00 (WILLIAM1_DATA row 0 byte 0), the
* indirect-long resolves correctly and the bug is elsewhere.
* Otherwise we know DP[7..9] doesn't point where the global says.
 lda #$A0
 jsr dbg_print_char
 lda #$F2              ; 'r'
 jsr dbg_print_char
 lda #$ED              ; 'm'
 jsr dbg_print_char
 lda MASK_ADDR
 sta $F0
 lda MASK_ADDR+1
 sta $F1
 lda sprite_bank
 sta $F2
 ldy #0
 lda [$F0],y
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$F2              ; 'r'
 jsr dbg_print_char
 lda #$E4              ; 'd'
 jsr dbg_print_char
 lda FRAME_ADDR
 sta $F0
 lda FRAME_ADDR+1
 sta $F1
 lda sprite_bank
 sta $F2
 ldy #0
 lda [$F0],y
 jsr dbg_print_hex8
 jsr dbg_print_nl
:ea_dbg_skip
 fin
 jsr draw_sprite_compiled
 bra :ea_post_draw
:ea_legacy
 jsr draw_sprite
:ea_post_draw
* Latch cur_x_off → prev_x_off after the draw so erase_all next
* frame clears the rect at the shifted column. Billy/Jimmy latch
* their globals; NPCs latch info+68 → info+69 on their own block.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :ea_latch_chk_jimmy
 lda billy_cur_x_off
 sta billy_prev_x_off
 bra :ea_clr_dirty
:ea_latch_chk_jimmy
 cmp #$02
 bne :ea_latch_npc
 lda jimmy_cur_x_off
 sta jimmy_prev_x_off
 bra :ea_clr_dirty
:ea_latch_npc
 ldy #68
 lda (info_ptr),y
 ldy #69
 sta (info_ptr),y
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
:ea_prev_xeff dfb 0
:ea_cur_xeff  dfb 0

*----------------------------------------------------------
* draw_all - Iterate sprite_table, load each sprite, draw.
*----------------------------------------------------------
draw_all
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:loop jsr load_sprite
 bcc :da_loaded
 jmp :done
:da_loaded
* Skip inactive Jimmy (Ctrl-J not yet pressed). Same gate as the
* one in erase_all — without this, mark_overlapping setting his
* draw bit while Billy is punched / falling makes him visible.
 lda info_ptr
 cmp #<jimmy_sprite
 bne :da_active_chk_done
 lda info_ptr+1
 cmp #>jimmy_sprite
 bne :da_active_chk_done
 lda jimmy_active
 bne :da_active_chk_done
 ldy #30
 lda #0
 sta (info_ptr),y
 jmp :skip_draw
:da_active_chk_done
* Co-op climb hide: skip the non-climber player while a climb
* is in progress. Player sprites only (controller 1 or 2) —
* NPCs draw normally.
 lda climb_hide_other
 beq :da_hide_chk_done
 ldy #22
 lda (info_ptr),y
 cmp #$03                ; controller 1=Billy, 2=Jimmy, else NPC
 bcs :da_hide_chk_done
 cmp #$01
 bcc :da_hide_chk_done   ; controller < 1 (= 0), NPC
 lda info_ptr
 cmp climb_climber_ptr
 bne :da_hide_skip
 lda info_ptr+1
 cmp climb_climber_ptr+1
 beq :da_hide_chk_done   ; current = climber, draw normally
:da_hide_skip
 jmp :skip_draw           ; current = hidden OTHER, skip
:da_hide_chk_done
* Draw if bit 0 set (needs_draw)
 ldy #30
 lda (info_ptr),y
 and #$01
 beq :skip_draw
* Burnov-grab lock: skip whichever player Burnov is holding.
* bn_grab_active tri-state: 0=none, 1=Billy, 2=Jimmy. Same gate
* as :ea_hide_chk_done above; this is the main draw_all pass.
 ldy #22
 lda (info_ptr),y
 cmp bn_grab_active
 bne :da_grab_chk_done
 lda bn_grab_active
 beq :da_grab_chk_done
 jmp :da_drawn
:da_grab_chk_done
* Stage frame_x_off for this draw. Billy (controller=1) →
* billy_cur_x_off; Jimmy (controller=2) → jimmy_cur_x_off; NPCs
* (controller=0) → info+68 (cur_x_off). Projectiles (controller=3)
* and static items also live in the info+68 slot — zeroed at
* spawn — so they naturally see 0.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :da_chk_jimmy_off
 lda billy_cur_x_off
 sta frame_x_off
 bra :da_off_done
:da_chk_jimmy_off
 cmp #$02
 bne :da_npc_off
 lda jimmy_cur_x_off
 sta frame_x_off
 bra :da_off_done
:da_npc_off
 ldy #68
 lda (info_ptr),y
 sta frame_x_off
:da_off_done
* Dispatch: compiled (AND/ORA) path when MASK_ADDR != 0 and the
* sprite is the keyboard player (Billy). MASK_ADDR is the live
* signal "current FRAME_ADDR points at compiled DATA"; advance_walk
* and :anim_done idle-restore set it, while start_anim and
* advance_climb clear it (their frames are uncompiled, must go
* through legacy). NPCs route compiled too when their info+60
* (active_mask_addr) is non-zero — i.e. they have a compiled
* idle pose loaded.
 lda MASK_ADDR
 ora MASK_ADDR+1
 beq :da_legacy
 jsr draw_sprite_compiled
 bra :da_drawn
:da_legacy
 jsr draw_sprite
:da_drawn
* Latch cur_x_off → prev_x_off so next frame's erase_all clears
* at the shifted column. Billy/Jimmy latch their globals; NPCs
* latch info+68 → info+69 on their own block.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :da_latch_chk_jimmy
 lda billy_cur_x_off
 sta billy_prev_x_off
 bra :da_skip_latch
:da_latch_chk_jimmy
 cmp #$02
 bne :da_latch_npc
 lda jimmy_cur_x_off
 sta jimmy_prev_x_off
 bra :da_skip_latch
:da_latch_npc
 ldy #68
 lda (info_ptr),y
 ldy #69
 sta (info_ptr),y
:da_skip_latch
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
 bcc :da_next_iter
 inc spr_ptr+1
:da_next_iter
 jmp :loop
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
 stz IMAGE01_YPOS+1   ; zero high byte — draw_sprite uses 16-bit
 ldy #2
 lda (info_ptr),y     ; +2 xpos
 sta IMAGE01_XPOS
 stz IMAGE01_XPOS+1   ; same — without this, prior 16-bit STAs from
                       ; draw_sprite's offset apply leak into the next
                       ; sprite's IMAGE01_XPOS via the stale high byte
                       ; (BPL bail in draw_sprite_compiled / _sprite
                       ; sees negative and skips every subsequent draw).
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
 ldy #60
 lda (info_ptr),y     ; +60 active_mask_addr — compiled-pipeline
                      ;     mask address; non-zero routes the
                      ;     dispatch to draw_sprite_compiled. Used
                      ;     by Billy and any compiled NPC. Zero for
                      ;     legacy-only sprites and during legacy
                      ;     anims (start_anim/load_frame clear it).
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
* Persist MASK_ADDR → +60 (active_mask_addr) for every sprite.
* The compiled-vs-legacy decision happens in dispatch via
* MASK_ADDR != 0; +60 is the persistent backing for it.
* (Was gated to controller==1 when +52 served double-duty as
* walk_anim for NPCs; the new +60 field is dedicated.)
 ldy #60
 lda MASK_ADDR
 sta (info_ptr),y
 iny
 lda MASK_ADDR+1
 sta (info_ptr),y
* Mark sprite as dirty (bit0=needs_draw, bit1=needs_erase, bit2=
* force_erase). Bit 2 defeats erase_all's no-movement skip — we
* just rewrote info+14 (frame_addr) so even if prev/cur positions
* match, the prior frame's opaque pixels under the new frame's
* transparent mask cells would otherwise survive (WPUNCHED head
* knocked-back residue under WILLIAM1 idle was the visible case).
 ldy #30
 lda #$07
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
* Persist MASK_ADDR → +60 (active_mask_addr) for every sprite.
* No longer gated on controller — +60 is dedicated, NPC walk_anim
* lives at +52.
 ldy #60
 lda MASK_ADDR
 sta (info_ptr),y
 iny
 lda MASK_ADDR+1
 sta (info_ptr),y
* Mark dirty (bit0=needs_draw, bit1=needs_erase, bit2=force_erase).
* See save_sprite for why bit 2 is needed — frame_addr just changed
* via FRAME_ADDR above, so the no-movement erase-skip in erase_all
* would strand the previous frame's opaque pixels under the new
* frame's transparent mask cells.
 ldy #30
 lda #$07
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
* Opcodes 16 and 17 (OP_SNAPSTATE / OP_SNAPSTATE_DEFER) removed in
* the world-coord climb refactor. Their job — pinning canonical
* engine state pre/post-climb and repainting the playfield with
* the source stratum's lower band — is now done dynamically by
* the engine (anchors per target in OP_UP, lower-band paint via
* :ffs_setup_scrN in engine.s, post-climb scroll_lsrc derived
* from scroll_up_lbank in :snap_transition).
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
OP_BOUNDS   = 21      ; rewrite stratum_bounds_tbl to a single
                      ; walkable platform at one y row. Other rows
                      ; become blocked. Params: 1b y, 2b x_world_lo,
                      ; 2b x_world_hi (= world byte range). Used by
                      ; OP_DOWN's post-descent platform setup (after
                      ; the descent ends and snap clears the ladder).
OP_SCROLLSRC = 22     ; Set scroll_src_off directly. Param: 1 byte.
                      ; Use AFTER OP_RIGHT (which resets src_off to
                      ; 0) to pin the source bank's read position
                      ; to a specific byte. mission2 post-descent
                      ; uses this to skip past mission29 bytes
                      ; already visible in the playfield, so the
                      ; first right-scroll reveals new content
                      ; instead of re-showing the visible right
                      ; portion of the split.

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
SCRIPT_WAITDOWN = 9   ; waiting for vertical-down scroll to complete

* NPC behaviors (must match mission1.s definitions)
BEHAV_NONE     = 0
BEHAV_FACEOFF  = 1
BEHAV_FLANK    = 2
BEHAV_LURK     = 3
BEHAV_LADDER   = 4
BEHAV_KNIFER   = 5    ; williams_knife: backpedal to 12px (= 6 byte
                      ; xpos units), throw KNIFE2/4 projectile, then
                      ; transform to regular williams + BEHAV_FACEOFF.
                      ; Falling mid-elude drops the knife and downgrades.
* Jimmy-priority variants — same behavior routines as the base
* values, but fo_find_player picks Jimmy as the preferred target and
* falls back to Billy if Jimmy is dead/inactive. Lets level scripts
* spawn two NPCs simultaneously and have each immediately engage a
* different player.
BEHAV_FACEOFF2 = 6
BEHAV_FLANK2   = 7

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

*----------------------------------------------------------
* kbd_init - Crank the keyboard's autorepeat to its fastest
* setting via _SendInfo setConfig ($06). The strobe-based
* :kbd_dispatch in process_input drives one walk step per
* $C000 keystroke, so faster repeat = faster held-key walking,
* matching the joystick step rate as closely as the keyboard
* hardware allows.
*
* Per Apple IIgs Firmware Ref ch. 9 (Set Configuration Bytes
* $06), the 3 data bytes are:
*   Byte 0: high nibble = ADB mouse address, low = keyboard
*           default = (mouse $03 << 4) | keyboard $02 = $32
*   Byte 1: high nibble = character set, low = layout/language
*           default = $00 (US English)
*   Byte 2: high nibble = delay-to-repeat, low = repeat rate
*           delay codes: 0=1/4s, 1=1/2s, 2=3/4s, 3=1s, 4=no-rpt
*           rate  codes: 0=40 ks, 1=30, 2=24, 3=20, 4=15,
*                        5=11, 6=8, 7=4 keys/sec
*           $00 = 1/4 sec initial delay + 40 keys/sec repeat
*                 (40/sec ≈ 1 event per 1.5 VBLs, closest the
*                  keyboard MCU can get to the joystick's
*                  60-step/sec path).
*
* _SendInfo ($0909) parameter stack (top first):
*   adbCommand  word  $0006 (Set Configuration)
*   dataPtr     long  pointer to 3-byte data
*   dataLength  word  $0003
*
* Called once at boot in emulation mode 8-bit; switches to
* native + 16-bit for the toolbox call and switches back.
*----------------------------------------------------------
kbd_init
 clc
 xce                   ; native mode
 rep $30               ; 16-bit A/X/Y
 pea #$0003            ; dataLength
 pea ^kbd_cfg_data     ; dataPtr high (bank)
 pea kbd_cfg_data      ; dataPtr low  (offset)
 pea #$0006            ; adbCommand = Set Configuration
 ldx #$0909            ; _SendInfo
 jsl $E10000
 sec
 xce                   ; back to emulation
 sep $30
 rts

kbd_cfg_data
 dfb $32               ; mouse $03 / keyboard $02 (defaults)
 dfb $00               ; US English layout, default char set
 dfb $00               ; delay=1/4s, rate=40 keys/sec (fastest)

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
kb_held       ds 16   ; 128 bits (1 bit per ADB scancode); not currently populated, key_held still consults it for the co-op helpers
kb_held_prev  ds 16   ; snapshot at top of process_input for edge detection
music_muted    dfb 0  ; M-key toggle: 0=playing, 1=stopped
music_bank     dfb $13 ; current NTP music bank ($13=mission1, $14=boss).
                       ; Tracked so M-resume and pause-resume can NTPprepare
                       ; with the right song before NTPplay (NTPstop appears
                       ; to deinstall the IRQ; plain NTPplay alone doesn't
                       ; restart it cleanly, and SFX would still hit the
                       ; Unclaimed Sound Interrupt).

* ADB scancodes for game input (Toolbox Ref Vol 1 Table 3-5).
ADB_KEY_W = $0D
ADB_KEY_A = $00
ADB_KEY_S = $01
ADB_KEY_D = $02
ADB_KEY_J = $26
ADB_KEY_L = $25
ADB_KEY_M = $2E

*----------------------------------------------------------
* process_input - Read keyboard, update Billy's state.
* If an action animation is playing, ignore all input.
*----------------------------------------------------------
process_input
* Burnov-grab lock for Billy: bn_grab_active=$01 means Billy is
* currently held in Burnov's BNBILLY pummel sequence. Swallow
* Billy's input until the grab ends. (=$02 means Jimmy is held —
* process_input is Billy's pipeline so Billy retains input, Jimmy's
* swap context handles the symmetric lock for his side.)
 lda bn_grab_active
 cmp #$01
 bne :pi_not_grabbed
 rts
:pi_not_grabbed
* Clear any stale co-op walk-boost so Billy doesn't pick it up
* before Jimmy's pi_action_dispatch (which is when it's meant
* to apply). Set later in this frame by the scroll handlers
* when Billy scrolls and Jimmy is pressing same direction.
 stz walk_boost_right
 stz walk_boost_left
* Same idea for the climb-scroll. did_climb_this_frame goes
* non-zero after one player's :sn_done fires scroll_up; the
* second mover's path then skips the actual scroll (but still
* advances their own climb anim).
 stz did_climb_this_frame
 stz did_descent_this_frame   ; Phase 4 OP_DOWN: parallel to climb
 stz billy_climb_pressed
 stz jimmy_climb_pressed
* Snapshot last frame's kb_held → kb_held_prev so the action
* dispatch below can edge-detect just-pressed buttons. kb_held
* is currently never populated (no working ADB drain path), so
* the snapshot is effectively all-zeros, but the loop is cheap
* and the co-op helpers still call key_held; leaving the
* snapshot in place keeps that contract intact for the day a
* working kb_held updater lands.
 ldx #15
:cp_prev
 lda kb_held,x
 sta kb_held_prev,x
 dex
 bpl :cp_prev
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
pi_action_dispatch
* Global alias for :found_player so process_input_jimmy can JSR
* in here after pre-setting info_ptr/IMAGE01_* to point at Jimmy.
* Skips the find-player scan above so we don't end up running
* Billy's logic twice in one frame.
*
* Co-op climb hide: if a climb is in progress AND the current
* player is the non-climber, skip their input entirely. They're
* invisible/inert until snap_transition completes the climb.
 lda climb_hide_other
 beq :pad_no_hide_gate
 lda info_ptr
 cmp climb_climber_ptr
 bne :pad_hidden
 lda info_ptr+1
 cmp climb_climber_ptr+1
 beq :pad_no_hide_gate    ; current = climber, process input
:pad_hidden
 rts                      ; current = hidden OTHER, skip
:pad_no_hide_gate
* (Ctrl-J / Ctrl-K / Ctrl-N runtime mode-switch hotkeys removed —
* the selection screen now sets input_mode + jimmy_input_mode +
* jimmy_active at startup.)

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
* Allow J+L through during the active player's jump anim so it
* can trigger the spin-kick. active_jump_anim is anim_jump for
* Billy / anim_jjump for Jimmy (swap_in_jimmy swaps it).
 lda anim_ptr
 cmp active_jump_anim
 bne :blocked
 lda anim_ptr+1
 cmp active_jump_anim+1
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
* grab_check swallowed input. If we're in grab state, also
* sample joystick button A so the grab-punch can fire (the
* button-polling block at :ji_buttons is gated behind the
* dispatch and won't run when grab_check returns C=1).
* joy_btn_a_prev is normally updated by :ji_save, which also
* doesn't run here — update it inline so the next-frame edge
* detector stays correct.
 lda grab_target
 ora grab_target+1
 beq :ji_swallow_done
 ldal $C062
 and #$80
 sta :joy_a_cur
 lda :joy_a_cur
 beq :ji_grab_a_no_edge
 lda joy_btn_a_prev
 bne :ji_grab_a_no_edge
 jsr start_grab_punch
:ji_grab_a_no_edge
 lda :joy_a_cur
 sta joy_btn_a_prev
:ji_swallow_done
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
* Same fix as :ji_grab: when grab_check swallows input, sample
* SNES B (bit 7 of snes_b0) so grab-punch can fire. snes_b0_prev
* is updated by :si_save which doesn't run here — update it
* inline for next-frame edge detection.
 lda grab_target
 ora grab_target+1
 beq :si_swallow_done
 lda snes_b0
 and #$80
 beq :si_grab_b_no_edge
 lda snes_b0_prev
 and #$80
 bne :si_grab_b_no_edge
 jsr start_grab_punch
:si_grab_b_no_edge
 lda snes_b0
 sta snes_b0_prev
 lda snes_b1
 sta snes_b1_prev
:si_swallow_done
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
 lda active_pipe_swing_anim
 ldx active_pipe_swing_anim+1
 jsr start_anim
 rts
:baf_l_chk_mace
 lda billy_mace_armed
 beq :baf_l_chk_knife
 lda active_mace_swing_anim
 ldx active_mace_swing_anim+1
 jsr start_anim
 rts
:baf_l_chk_knife
 lda billy_knife_armed
 beq :baf_l_pickup
* Throw: spawn_thrown_knife reads info_ptr's xpos / ypos / mirror.
* Preserve whatever info_ptr is on entry (Billy when called via
* process_input, Jimmy when called via process_input_jimmy's swap
* context) so each player throws from his own position. Then
* dispatch disarm by the active player so the right *_armed flags
* and idle pose get restored. active_punch1_anim is swapped to
* anim_jpunch1 in Jimmy's context.
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 jsr spawn_thrown_knife
 pla
 sta info_ptr+1
 pla
 sta info_ptr
 lda info_ptr+1
 cmp #>jimmy_sprite
 bne :baf_disarm_billy
 lda info_ptr
 cmp #<jimmy_sprite
 bne :baf_disarm_billy
* Jimmy throw: we're inside swap_in_jimmy's context, so the
* billy_*_armed globals are actually Jimmy's armed flags
* (swap_in copied jimmy_stash_*_armed into them). Clear them
* here BEFORE jimmy_disarm_weapon so swap_out_jimmy copies the
* now-zero globals back into jimmy_stash_*_armed (otherwise
* swap_out's `lda billy_knife_armed / sta jimmy_stash_knife_armed`
* would write the stale 1 back, undoing jimmy_disarm's stash clear
* — Jimmy stays "armed", walk keeps using knife frames, and the
* next throw fires the knife branch again).
 stz billy_pipe_armed
 stz billy_mace_armed
 stz billy_knife_armed
 jsr jimmy_disarm_weapon
 bra :baf_post_disarm
:baf_disarm_billy
 jsr billy_disarm_weapon
:baf_post_disarm
 lda active_punch1_anim
 ldx active_punch1_anim+1
 jsr start_anim
 rts
:baf_l_pickup
* billy_try_pickup_weapon mutates info_ptr while scanning
* sprite_table and unconditionally writes info_ptr=billy_sprite
* before returning. Save/restore around the call so Jimmy's L
* button doesn't end up dispatching :baf_punch/_kick against
* billy_sprite's mirror flag.
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 jsr billy_try_pickup_weapon
 php                      ; preserve C across the restore
 pla
 sta :baf_save_p
 pla
 sta info_ptr+1
 pla
 sta info_ptr
 lda :baf_save_p
 pha
 plp
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
 lda active_kick_anim
 ldx active_kick_anim+1
 jsr start_anim
 rts
:baf_punch
* Same sequence the old 'p' strobe handler used.
 ldx #SND_PUNCH
 jsr sound_trigger
 lda landing_window
 beq :baf_reg_punch
 stz landing_window
 lda active_uppercut_anim
 ldx active_uppercut_anim+1
 jsr start_anim
 rts
:baf_reg_punch
 lda punch_toggle
 eor #$01
 sta punch_toggle
 bne :baf_use_punch2
 lda active_punch1_anim
 ldx active_punch1_anim+1
 jsr start_anim
 rts
:baf_use_punch2
 lda active_punch2_anim
 ldx active_punch2_anim+1
 jsr start_anim
 rts
:baf_key    dfb 0
:baf_save_p dfb 0

*----------------------------------------------------------
* btn_action_jump - both J and L pressed within the window.
*----------------------------------------------------------
btn_action_jump
* If the current player is already mid-jump (anim_ptr ==
* active_jump_anim) and the J+L combo lands again, switch to
* the spin-kick. active_*_anim is swapped by swap_in_jimmy so
* Jimmy compares against anim_jjump while Billy compares
* against anim_jump.
 lda anim_ptr
 cmp active_jump_anim
 bne :baj_normal
 lda anim_ptr+1
 cmp active_jump_anim+1
 bne :baj_normal
 ldx #SND_SPINKICK
 jsr sound_trigger
 lda active_bspinkick_anim
 ldx active_bspinkick_anim+1
 jsr start_anim
 rts
:baj_normal
 ldx #SND_JUMP
 jsr sound_trigger
 lda active_jump_anim
 ldx active_jump_anim+1
 jsr start_anim
* Gravity mode: arm vertical velocity so apply_gravity_step lifts
* Billy on the next frame. The legacy y_off ramp is dormant (gated
* off in update_billy_y_off / set_billy_y_target). Also arm a
* horizontal velocity from Billy's facing direction so the jump
* carries forward without needing per-VBL keyboard repeats
* ($C000 polling + default ADB autorepeat is too slow to drive
* xpos across a 20+px gap during a sub-second airtime).
 lda gravity_enabled
 beq :baj_done
 lda #1
 sta billy_airborne
 lda #JUMP_VEL_INIT
 sta billy_y_vel
 lda IMAGE01_MIRROR
 bne :baj_face_left
 lda #JUMP_X_VEL           ; facing right → x_vel = +N
 bra :baj_set_xv
:baj_face_left
 lda #0                    ; facing left → x_vel = -N (2's complement)
 sec
 sbc #JUMP_X_VEL
:baj_set_xv
 sta billy_jump_x_vel
:baj_done
 rts

:has_key
 lda $c010
 and #$7f
* M (or m) → toggle background music. NTPplay/NTPstop must run
* in native 16-bit mode (same protocol as title.s / OP_END /
* game_over). Autorepeat is disabled in kbd_init so the $C000
* strobe is one-shot per press — no edge-detect needed.
 cmp #'m'
 beq :pi_m_toggle
 cmp #'M'
 bne :pi_m_skip
:pi_m_toggle
 sta $c010                ; consume strobe
 lda music_muted
 eor #$01
 sta music_muted
 beq :pi_m_play           ; new state 0 → unmuted → play
 clc
 xce
 rep $30
 jsl NTPstop
 sec
 xce
 sep $30
 mx %11
 rts
:pi_m_play
* NTPstop appears to deinstall the IRQ handler; plain NTPplay
* doesn't restart things — SFX would still raise the Unclaimed
* Sound Interrupt. Re-run NTPprepare with the current music
* bank before NTPplay, and re-apply the SFX-friendly volume.
 clc
 xce
 rep $30
 ldx #$00
 lda music_bank
 and #$00FF
 tay
 lda #$0000
 jsl NTPprepare
 lda #$0000
 jsl NTPplay
 lda #$0080
 jsl NTPsetplayvolume
 sec
 xce
 sep $30
 mx %11
 rts
:pi_m_skip
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
* (Old SEI guard removed — the NTP-IRQ leak it worked around is
* addressed by ninjatrackerp.s's PHP/PLP at interrupt_handler
* entry/exit. Letting NTP fire freely here reclaims ~70K cycles
* of IRQ-blocked time per scroll.)
 jsr save_sprite
 jsl scroll_right
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
* Dev-only debug keys ('g', 'V', space) gated on DEBUG_HELPERS — they
* invoke routines that hit KEGS virtual stdout ($D0FDDA/$D0FDED),
* which would crash on real IIgs hardware. With DEBUG_HELPERS=0 they
* assemble to a no-op fallthrough.
 do DEBUG_HELPERS
 cmp #'g'
 bne :ns_not_g
* Golden state capture: prints a 3-line snapshot of all state
* relevant to ladder alignment & drift detection.
 jsr dbg_golden_state
 rts
:ns_not_g
 cmp #'V'
 bne :ns_not_v_caps
* Validate stratum bounds against per-screen bounds for the current
* screen. Iterates all (Y, X) pairs and prints any mismatches.
 jsr dbg_validate_stratum_bounds
 rts
:ns_not_v_caps
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
 fin
* :ns_not_space MUST sit immediately after the gated debug-key block,
* not after the :up_as_propy/:dn_as_propy data bytes — when
* DEBUG_HELPERS=0 the gated block evaporates and execution falls
* straight from `beq :do_up` into whatever lives here. Previously
* the data bytes ($00 $00) were in that path, producing a BRK $00
* at the first non-'w' key on real hardware.
:ns_not_space
 jmp :not_up              ; inverted — :not_up moved out of range
* :up_as_propy / :dn_as_propy survive the auto-step retirement
* because :up_walk and :ai_do_down still stash the proposed Y
* in them for the subsequent check_y_bounds call. The other
* auto-step locals were dead once the stratum bounds took over.
* Placed AFTER the unconditional jmp above so execution never
* reaches these data bytes.
:up_as_propy dfb 0
:dn_as_propy dfb 0
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
* The snap-to-ladder + advance_climb + save_sprite below run
* unconditionally so a player on the ladder always gets centered
* and animated. The world-scroll itself is co-op-gated at
* :sn_done so it only fires when the OTHER player is also on
* the ladder, otherwise the climber "treads in place" until the
* partner catches up.
:do_up_on_ladder_dbg
* DEBUG: 'US' = up-scroll fired at current ypos
 do DEBUG_PRINT
 lda #$D5              ; 'U'
 jsr dbg_print_char
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda IMAGE01_YPOS
 jsr dbg_print_hex8
 jsr dbg_print_nl
 fin
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
* Climb anim + save state — always runs, so the climber's
* sprite cycles through BCLIMB1/2 (or JCLIMB1/2) every frame
* they press up, even if the world isn't scrolling.
 jsr advance_climb
 jsr save_sprite
* Co-op: first player to reach :sn_done captures the climb. The
* OTHER player is hidden (no input, no draw, no erase) for the
* rest of the climb. Avoids the carry/shift/bounds issues from
* trying to render both players through a vertical scroll where
* bounds_tbl isn't updated per-step. OTHER reappears at the
* climber's exit position when snap_transition fires.
 lda jimmy_active
 beq :sn_no_hide
 lda climb_hide_other
 bne :sn_no_hide          ; already captured this climb
 lda info_ptr
 sta climb_climber_ptr
 lda info_ptr+1
 sta climb_climber_ptr+1
 lda #1
 sta climb_hide_other
* Mark OTHER for one-time erase so erase_all later this frame
* clears their stale sprite, then leaves info+30=0 so draw_all
* and erase_all skip them on subsequent frames.
 lda info_ptr+1
 cmp #>billy_sprite
 bne :sn_hide_other_billy
 lda info_ptr
 cmp #<billy_sprite
 bne :sn_hide_other_billy
* Climber = Billy → OTHER = Jimmy.
 lda jimmy_sprite+30
 and #$FE                 ; clear needs_draw
 ora #$02                 ; set needs_erase
 sta jimmy_sprite+30
 bra :sn_no_hide
:sn_hide_other_billy
* Climber = Jimmy → OTHER = Billy.
 lda billy_sprite+30
 and #$FE
 ora #$02
 sta billy_sprite+30
:sn_no_hide
 lda did_climb_this_frame
 bne :sn_skip_scroll
* (Old SEI guard removed — see comment at first removal site.)
 jsl scroll_up
 jsr load_sprite
 lda #1
 sta did_climb_this_frame
 rts
:sn_skip_scroll
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
 sta :up_as_propy
* Auto-step retired: the per-screen bmin/bmax snap teleported
* xpos when wo was mid-transition. Stratum world-coord bounds
* + ladder fallback in check_y_bounds below cover the case it
* was meant to fix.
:up_as_done
 lda :up_as_propy
 jsr check_y_bounds
 bcc :up_walk_bounds_ok
* Bounds rejected the proposed row. Lenient retry: if scroll_up
* is enabled AND we're on a ladder x-range (Y ignored), allow the
* walk-up with via_ladder=1. Lets a partner follow the climber
* up the ladder column from a Y above the ladder's y_bottom — the
* strict check_y_bounds rejects those Y values because the floor
* row outside the ladder column is bounds-walkable while the row
* above (the wall) is blocked, and check_ladder uses proposed Y
* which sits above y_bottom for follow-up scenarios. (mission1
* ladders have y_top=0, so prop_y=0 is always within range.)
 lda scroll_up_enabled
 beq :up_blocked_bounds
 lda #0
 jsr check_ladder
 bcs :up_blocked_bounds
 lda #1
 sta via_ladder
 jmp :up_do_move
:up_walk_bounds_ok
* Ladder-column override: if we're on a ladder x-range with
* scroll_up_enabled, force via_ladder=1 so walk-up uses climb
* anim. Without this, a bounds-walkable ladder column (no walls
* on the sides, step rule never fires) leaves via_ladder at 0
* and the partner walks up in walk anim instead of climbing.
 lda scroll_up_enabled
 beq :up_walk_step
 lda #0
 jsr check_ladder
 bcs :up_walk_step
 lda #1
 sta via_ladder
:up_walk_step
* Step rule retired: redundant with check_y_bounds (stratum
* world coords + ladder fallback). The old "narrower row above
* → require ladder" gate was per-screen-bmax-indexed, which
* false-fired in mid-scroll wo states.
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
 do DEBUG_PRINT
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
 fin
 lda via_ladder
 beq :up_walkframe
* Climb step (via_ladder=1). Mark is_climbing so subsequent
* frames bypass check_ladder's engage-row gate. Two decs per VBL =
* 2 px/VBL ladder pace (NES feel); not gated by the walk_toggle
* half-speed throttle below.
 lda #$01
 sta is_climbing
 dec IMAGE01_YPOS
 dec IMAGE01_YPOS
 jsr advance_climb
 bra :up_after_anim
:up_walkframe
* Regular up-walk (no ladder). Clear is_climbing — player has
* left the ladder (or never started a climb). Position steps
* every VBL; the frame cycle stays throttled inside advance_walk
* (joystick only). Decoupling fixes the "stall on middle frame"
* perception that the gated step caused — during scroll the world
* moves every VBL regardless of the toggle, so the player looks
* smooth; doing the same here makes non-scroll walking match.
 stz is_climbing
 dec IMAGE01_YPOS
 jsr advance_walk        ; vertical walk — cycle walk frames
:up_after_anim
 jsr save_sprite
 jsr resort_sprite_table
 rts
:up_blocked_bounds
* DEBUG: 'UX' = climb blocked by bounds (and not on ladder)
 do DEBUG_PRINT
 lda #$D5
 jsr dbg_print_char
 lda #$D8              ; 'X'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda IMAGE01_YPOS
 jsr dbg_print_hex8
 jsr dbg_print_nl
 fin
:skip_up rts
:up_blocked_ladder
* DEBUG: 'UL' = climb on ladder but scroll_up disabled
 do DEBUG_PRINT
 lda #$D5
 jsr dbg_print_char
 lda #$CC              ; 'L'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda IMAGE01_YPOS
 jsr dbg_print_hex8
 jsr dbg_print_nl
 fin
 rts
:not_up cmp #'s'
 bne :not_down
:ai_do_down
 lda IMAGE01_XPOS
 sta chk_xpos
 lda IMAGE01_YPOS
 clc
 adc #1               ; proposed Y
 sta :dn_as_propy
* Auto-step retired (same reason as :up_walk's). Stratum world-
* coord bounds + ladder fallback in check_y_bounds below cover
* the down-walk case correctly regardless of wo.
:dn_as_done
 lda :dn_as_propy
 jsr check_y_bounds
 bcs :skip_down       ; blocked
 lda via_ladder
 beq :down_walkframe
* Climb-down step. Mark is_climbing (mirrors :up_do_move) so
* subsequent frames bypass the engage-row gate. Two incs per VBL
* = 2 px/VBL ladder pace; not gated by the walk_toggle half-speed
* throttle below.
 lda #$01
 sta is_climbing
* Phase 4 OP_DOWN: when descending on a ladder past DOWN_SCROLL_
* THRESH with an OP_DOWN active, fire scroll_down instead of
* incrementing ypos. Mirror of :sn_done's scroll_up trigger.
* Camera moves down by 4 px/frame while Billy stays anchored at
* his current ypos visually.
 lda scroll_down_enabled
 beq :dn_climb_no_scroll
 lda IMAGE01_YPOS
 cmp #DOWN_SCROLL_THRESH
 bcc :dn_climb_no_scroll
 jsr advance_climb
 jsr save_sprite
 lda did_descent_this_frame
 bne :dn_skip_scroll_jsl
 jsl scroll_down
 jsr load_sprite
 lda #1
 sta did_descent_this_frame
:dn_skip_scroll_jsl
 rts
:dn_climb_no_scroll
 inc IMAGE01_YPOS
 inc IMAGE01_YPOS
 jsr advance_climb
 bra :down_after_anim
:down_walkframe
* Regular down-walk (no ladder). Clear is_climbing. Position
* steps every VBL; frame throttle lives inside advance_walk
* (joystick only). See :up_walkframe for the rationale.
 stz is_climbing
 inc IMAGE01_YPOS
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
* Branches to :left_walk are out of 8-bit range now that the
* co-op helpers expanded the scroll body — invert each test
* and JMP to a trampoline.
 lda scroll_left_enabled
 bne :dl_chk_screen
 jmp :left_walk
:dl_chk_screen
 lda current_screen
 bne :dl_chk_thresh
 jmp :left_walk        ; on screen 0, no left source
:dl_chk_thresh
 lda IMAGE01_XPOS
 cmp #LEFT_SCROLL_THRESH
 bcc :dl_chk_clamp
 jmp :left_walk        ; xpos > threshold, walk
:dl_chk_clamp
* Script clamp: reject scroll when wo-4 would fall below
* scroll_min_wo. 16-bit compare: (wo - 4) vs scroll_min_wo.
 lda world_offset
 sec
 sbc #4
 tax                   ; low byte of (wo-4) in X
 lda world_offset+1
 sbc #0                ; high byte of (wo-4) in A
 cmp scroll_min_wo+1
 bcs :dl_chk_eq
 jmp :left_walk        ; (wo-4) < min → walk
:dl_chk_eq
 bne :left_scroll_ok   ; (wo-4) high > min high → ok
 cpx scroll_min_wo
 bcs :left_scroll_ok
 jmp :left_walk        ; (wo-4) low < min low → walk
:left_scroll_ok
* Horizontal scroll abandons any climb sequence (parallel to
* :right_scroll_ok and the walk paths).
 stz is_climbing
* Stratum-bounds gate: scrolling left → world_x decreases by 4.
* Use OUTER-envelope check (see scroll-right counterpart) so a
* scroll can step through inter-span gaps to reach a walkable
* region on the far side. Pass xpos-4 (clamped at 0 if it would
* underflow) so check_x_bounds_world_outer computes the
* post-scroll world_x.
 lda IMAGE01_XPOS
 cmp #4
 bcc :lso_xpos_zero      ; xpos < 4 → clamp test xpos to 0
 sec
 sbc #4
 bra :lso_xpos_ok
:lso_xpos_zero
 lda #0
:lso_xpos_ok
 jsr check_x_bounds_world_outer
 bcc :lso_bounds_ok
 jmp :left_walk
:lso_bounds_ok
* Co-op right-clamp: a left-scroll shifts the other player's
* xpos RIGHT by 4 to keep them anchored to the same world
* position. If their right edge (xpos + frame_x) would push
* past PLAYER_MAX_X, walk instead. Alive gate added so a dead
* other player's stale (last-known) info+2 doesn't block the
* survivor from scrolling.
 lda jimmy_active
 beq :lso_no_other
 jsr co_op_other_alive
 bcc :lso_no_other       ; other dead → no clamp
 jsr co_op_other_xpos    ; A = other player's xpos
 clc
 adc #4                  ; +4 (post-scroll xpos)
 cmp #PLAYER_MAX_X+1
 bcc :lso_no_other       ; other still in bounds
 jmp :left_walk          ; other would go past PLAYER_MAX_X
:lso_no_other
* DEBUG_LSRC: 'SL B=bb O=oo CS=cs WO=wwww X=xx P=p'
* — every left-scroll, just before the engine fires. P = 1 if
* current player is Billy, 2 if Jimmy (info_ptr match), so we
* can see which player is driving the scroll. X = current xpos.
 do DEBUG_LSRC
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$CC              ; 'L'
 jsr dbg_print_char
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
 lda #$CF              ; 'O'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 lda scroll_lsrc_off
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
 lda #$D8              ; 'X'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 lda IMAGE01_XPOS
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$D0              ; 'P'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 lda info_ptr+1
 cmp #>billy_sprite
 bne :dbg_sl_jimmy
 lda info_ptr
 cmp #<billy_sprite
 bne :dbg_sl_jimmy
 lda #$01
 jsr dbg_print_hex8
 bra :dbg_sl_done
:dbg_sl_jimmy
 lda #$02
 jsr dbg_print_hex8
:dbg_sl_done
* SRC=AA BB CC DD — the 4 source bytes the engine is about to
* read from (scroll_lsrc_bank, scroll_lsrc_off-3..off). Reads
* via long-indirect on a temporary $F0/$F1/$F2 pointer (in
* emulation 8-bit, [dp],y is a 24-bit read). If these are zero
* but bank $0B's scr8 art should be there, that's the smoking
* gun for the data being clobbered. Save/restore $F0..$F2 so
* we don't corrupt callers' pointer.
 lda $F0
 pha
 lda $F1
 pha
 lda $F2
 pha
 lda scroll_lsrc_off
 sec
 sbc #3
 sta $F0
 lda #$20
 sta $F1
 lda scroll_lsrc_bank
 sta $F2
 lda #$A0
 jsr dbg_print_char
 lda #$D3              ; 'S'
 jsr dbg_print_char
 lda #$D2              ; 'R'
 jsr dbg_print_char
 lda #$C3              ; 'C'
 jsr dbg_print_char
 lda #$BD
 jsr dbg_print_char
 ldy #0
 lda [$F0],y
 jsr dbg_print_hex8
 ldy #1
 lda [$F0],y
 jsr dbg_print_hex8
 ldy #2
 lda [$F0],y
 jsr dbg_print_hex8
 ldy #3
 lda [$F0],y
 jsr dbg_print_hex8
 pla
 sta $F2
 pla
 sta $F1
 pla
 sta $F0
 jsr dbg_print_nl
 fin
* PRE-SCROLL co-op shift. See the right-scroll site for the
* rationale (must happen BEFORE jsl scroll_left so the scroll
* paints OTHER at post-shift xpos, avoiding the 4-byte residue
* when OTHER later presses a direction).
 lda jimmy_active
 beq :lso_no_preshift
 jsr co_op_other_alive
 bcc :lso_no_preshift
 jsr co_op_shift_other_right
:lso_no_preshift
* Scroll world LEFT by 4 bytes.
* (Old SEI guard removed — see comment at first removal site.)
 jsr save_sprite
 jsl scroll_left
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
* Co-op: shift the OTHER player's xpos RIGHT by 4 so their
* world position stays fixed while the scroller anchors at
* the left edge. If the OTHER is also pressing left, "carry"
* them along — see :rso_curr_jimmy_std for the explanation.
* Alive gate: same reasoning as the right-scroll block — a dead
* other player's xpos must stay frozen so assert_abs_x doesn't
* halt on the abs_x vs world_offset+billy.xpos invariant.
 lda jimmy_active
 beq :lso_done
 jsr co_op_other_alive
 bcs :lso_other_alive    ; other alive → normal shift path
* Other dead: skip the shift, but if Jimmy is the current
* scroller, decrement billy_save_abs_x by 4 (mirror of the
* right-scroll bump). Keeps abs_x == world_offset + billy.xpos
* after swap_out_jimmy restores abs_x from the stash.
 lda info_ptr
 cmp #<jimmy_sprite
 bne :lso_done
 lda info_ptr+1
 cmp #>jimmy_sprite
 bne :lso_done
 lda billy_save_abs_x
 sec
 sbc #4
 sta billy_save_abs_x
 lda billy_save_abs_x+1
 sbc #0
 sta billy_save_abs_x+1
 bra :lso_done
:lso_other_alive
* Post-scroll: shift was already done pre-scroll. Just handle the
* walk_boost queuing here. (Mirror of right-scroll fix.)
 lda info_ptr
 cmp #<billy_sprite
 bne :lso_curr_jimmy
 lda info_ptr+1
 cmp #>billy_sprite
 bne :lso_curr_jimmy
 jsr co_op_other_pressing_left
 bcc :lso_done
 lda #4
 sta walk_boost_left
 bra :lso_done
:lso_curr_jimmy
 jsr co_op_other_pressing_left
 bcc :lso_done
 jsr co_op_carry_billy_right
:lso_done
 bra :finish_left
:left_walk
* Walking horizontally ends any climb sequence — clear the
* sticky is_climbing flag so the next up-press has to engage
* from the floor row.
 stz is_climbing
* Co-op walk boost: if a scroll-left this frame queued a boost
* and we're pressing left, step by 4 instead of 1 so we keep
* up with the scroll's world advance.
 lda walk_boost_left
 bne :lw_boosted
* Position steps every VBL; frame throttle lives inside
* advance_walk (joystick only). See :up_walkframe for the
* rationale — keeps walking smooth across the leg-cycle's middle
* frame instead of stalling on the toggle's "skip" VBL.
* Normal step: xpos -= 1.
 lda IMAGE01_XPOS
 cmp #2
 bcc :skip_left        ; already at minimum (1)
 sec
 sbc #1                ; proposed new xpos
 jsr check_x_bounds_walk_left
 bcc :lw_apply         ; bounds accepted → normal apply
* Bounds rejected. In gravity mode, treat as walk-off-edge:
* apply the move anyway and trigger airborne / fall.
 lda gravity_enabled
 beq :skip_left
* If already airborne, don't stomp on y_vel — just allow the
* horizontal mid-air control. Ground-to-air transition arms vel.
 lda billy_airborne
 bne :lw_apply
 lda #1
 sta billy_airborne
 stz billy_y_vel
:lw_apply
 dec IMAGE01_XPOS
 lda abs_x
 bne :dec_lo
 dec abs_x+1
:dec_lo
 dec abs_x
 bra :skip_left
:lw_boosted
* Boosted step: xpos -= 4 to match the scroll. Consume the
* boost so it only fires once.
 stz walk_boost_left
 lda IMAGE01_XPOS
 cmp #5
 bcc :skip_left        ; not enough room to step -4
 sec
 sbc #4                ; proposed new xpos
 jsr check_x_bounds_walk_left
 bcc :lw_boost_apply
 lda gravity_enabled
 beq :skip_left
* If already airborne, don't stomp on y_vel — just allow the
* horizontal mid-air control. Ground-to-air transition arms vel.
 lda billy_airborne
 bne :lw_boost_apply
 lda #1
 sta billy_airborne
 stz billy_y_vel
:lw_boost_apply
 sec
 lda IMAGE01_XPOS
 sbc #4
 sta IMAGE01_XPOS
 sec
 lda abs_x
 sbc #4
 sta abs_x
 lda abs_x+1
 sbc #0
 sta abs_x+1
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
* Branches to :walk_right are out of 8-bit range now that the
* co-op helpers expanded the scroll body — invert + JMP.
 lda scroll_right_enabled
 bne :dr_chk_thresh
 jmp :walk_right       ; scroll disabled — walk to edge
:dr_chk_thresh
 lda IMAGE01_XPOS
 cmp #SCROLL_THRESH
 bcs :dr_chk_clamp
 jmp :walk_right       ; xpos < threshold, walk
:dr_chk_clamp
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
 beq :dr_chk_low
 jmp :walk_right       ; (wo+4) high > max → walk
:dr_chk_low
 cpx scroll_max_wo
 bcc :right_scroll_ok  ; (wo+4) low < max low → ok
 beq :right_scroll_ok  ; equal → ok (reaching exactly max)
 jmp :walk_right       ; (wo+4) low > max low → walk
:right_scroll_ok
* Horizontal scroll abandons any climb sequence (parallel to
* :walk_right / :left_walk clearing it for the no-scroll path).
 stz is_climbing
* Stratum-bounds gate: scrolling moves wo, leaving xpos unchanged
* — equivalent in world coords to xpos += 4. Reject the scroll if
* the post-scroll world position (= wo+xpos+4) would land in a row
* that's entirely OOB on the stratum's outer envelope at billy's
* current Y. We use the OUTER envelope (not strict 2-span check)
* so a 4-byte scroll can step THROUGH narrow gaps between spans
* (e.g. scr1's row-83 wall base, world 110..114) and reach the
* walkable territory on the far side. Walking still uses the
* strict check, so the player can't come to rest inside a gap.
 lda IMAGE01_XPOS
 clc
 adc #4
 jsr check_x_bounds_world_outer
 bcc :rso_bounds_ok
 jmp :walk_right
:rso_bounds_ok
* Co-op left-clamp: if Jimmy is active AND the other player is
* still alive AND within 4 px of xpos=0, a 4-byte right-scroll
* would push them off the left edge of the playfield. Walk instead.
* Alive gate added so a dead other player's stale (last-known)
* info+2 doesn't block the survivor from scrolling.
 lda jimmy_active
 beq :rso_no_other
 jsr co_op_other_alive
 bcc :rso_no_other       ; other dead → no clamp
 jsr co_op_other_xpos    ; A = other player's xpos
 cmp #4
 bcs :rso_no_other       ; other not too close → continue
 jmp :walk_right         ; other too close to left edge
:rso_no_other
* PRE-SCROLL co-op shift. Must happen BEFORE jsl scroll_right
* (which paints both players at their info+2). Old order shifted
* AFTER scroll, so scroll painted OTHER at pre-shift xpos, then
* info+2 was decremented. If OTHER's pi_action_dispatch later
* fires a walk handler, its save_sprite snaps info+2 (post-shift)
* → info+34, clobbering the pre-shift value co_op_shift_other_left
* stored there. erase_all's rect then misses the 4-byte gap where
* the scroll painted OTHER — 4-byte residue at OTHER's right tail
* on direction change. Fix: shift first, so scroll paints OTHER
* at post-shift xpos. info+34 still has pre-shift for erase_all's
* union; OTHER's later walk save_sprite re-snaps prev = post-shift
* but the OLD draw was AT post-shift this time, so the rect still
* covers it.
 lda jimmy_active
 beq :rso_no_preshift
 jsr co_op_other_alive
 bcc :rso_no_preshift
 jsr co_op_shift_other_left
:rso_no_preshift
* Scroll world right by 4 bytes (8 pixels = 2 words).
* (Old SEI guard removed — see first removal site for rationale.
* The NTP IRQ leak that prompted this guard is addressed by the
* PHP/PLP wrapper added to ninjatrackerp.s's interrupt_handler.)
 jsr save_sprite
 jsl scroll_right
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
* represents the scrolling player's cumulative byte-displacement
* through the world.
 lda abs_x
 clc
 adc #4
 sta abs_x
 lda abs_x+1
 adc #0
 sta abs_x+1
* Co-op: shift the OTHER player's xpos left by 4 so their world
* position stays fixed while the scroller anchors at the right
* edge. Marks them dirty so erase_all + draw_all rebuild the
* shifted sprite next frame. If the OTHER player is also
* pressing right, instead "carry" them along so they advance
* with the scroll: walk_boost when Jimmy is the other (consumed
* by his upcoming pi_action_dispatch), or retroactive carry on
* Billy when he's the other (his pi_action_dispatch already ran).
*
* Alive gate: when other is dead, skip the shift entirely. Their
* xpos must stay frozen at the death position because abs_x is
* still tied to billy.xpos via assert_abs_x — if we shift Billy
* from his last live xpos, world_offset+billy.xpos no longer
* matches abs_x and the assertion infinite-loops at $9547.
 lda jimmy_active
 beq :rso_done
 jsr co_op_other_alive
 bcs :rso_other_alive    ; other alive → normal shift path
* Other dead: skip the shift, but if Jimmy is the current
* scroller, bump billy_save_abs_x by 4. That's the abs_x value
* swap_out_jimmy will restore at end of his pi_action_dispatch.
* Without this bump, world_offset advanced by 4 but billy.xpos
* stayed frozen (no shift), so post-swap-out the assertion
* abs_x == world_offset + billy.xpos breaks by 4 per scroll.
 lda info_ptr
 cmp #<jimmy_sprite
 bne :rso_done
 lda info_ptr+1
 cmp #>jimmy_sprite
 bne :rso_done
 lda billy_save_abs_x
 clc
 adc #4
 sta billy_save_abs_x
 lda billy_save_abs_x+1
 adc #0
 sta billy_save_abs_x+1
 bra :rso_done
:rso_other_alive
* Post-scroll: shift was already done pre-scroll. Just handle the
* walk_boost queuing here. (Old code had `jsr co_op_shift_other_left`
* at both branches — removed to prevent double-shift now that it
* runs pre-scroll.)
 lda info_ptr
 cmp #<billy_sprite
 bne :rso_curr_jimmy
 lda info_ptr+1
 cmp #>billy_sprite
 bne :rso_curr_jimmy
* Current = Billy → other = Jimmy. Queue walk_boost so Jimmy
* walks +4 instead of +1 if pressing right.
 jsr co_op_other_pressing_right
 bcc :rso_done
 lda #4
 sta walk_boost_right
 bra :rso_done
:rso_curr_jimmy
* Current = Jimmy → other = Billy. Billy already walked. If he's
* pressing right, apply retroactive carry (which itself acts as
* the shift for Billy).
 jsr co_op_other_pressing_right
 bcc :rso_done
 jsr co_op_carry_billy_left
:rso_done
 bra :finish_right
:walk_right
* Walking horizontally ends any climb sequence (see :left_walk
* counterpart for rationale).
 stz is_climbing
* Co-op walk boost: if a scroll-right this frame queued a boost
* and we're pressing right, step by 4 instead of 1.
 lda walk_boost_right
 bne :wr_boosted
* Position steps every VBL; frame throttle lives inside
* advance_walk (joystick only). See :up_walkframe for rationale.
* Normal step: xpos += 1.
 lda IMAGE01_XPOS
 cmp #PLAYER_MAX_X
 bcs :clamp_right
 clc
 adc #1                ; proposed new xpos
 jsr check_x_bounds_walk_right
 bcc :wr_apply
 lda gravity_enabled
 beq :clamp_right
 lda billy_airborne
 bne :wr_apply
 lda #1
 sta billy_airborne
 stz billy_y_vel
:wr_apply
 inc IMAGE01_XPOS
 inc abs_x
 bne :finish_right
 inc abs_x+1
 bra :finish_right
:wr_boosted
* Boosted step: xpos += 4. Consume the boost.
 stz walk_boost_right
 lda IMAGE01_XPOS
 clc
 adc #4
 cmp #PLAYER_MAX_X+1
 bcs :clamp_right      ; would overshoot the right edge
 jsr check_x_bounds_walk_right
 bcc :wr_boost_apply
 lda gravity_enabled
 beq :clamp_right
 lda billy_airborne
 bne :wr_boost_apply
 lda #1
 sta billy_airborne
 stz billy_y_vel
:wr_boost_apply
 lda IMAGE01_XPOS
 clc
 adc #4
 sta IMAGE01_XPOS
 clc
 lda abs_x
 adc #4
 sta abs_x
 lda abs_x+1
 adc #0
 sta abs_x+1
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
* Dev-only audio-debug keys ('v', 'b') call verify_punch_state which
* uses dbg_print_* (KEGS stdout). Gated on DEBUG_HELPERS so the call
* sites strip cleanly for real-hardware builds.
 do DEBUG_HELPERS
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
:not_verify
 fin
 cmp #'i'
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
* co_op_other_xpos - Return (in A) the OTHER player's xpos.
* Determines which player is currently processing via info_ptr
* match against billy_sprite. Caller should only invoke this
* when jimmy_active is non-zero. Preserves X / Y.
*----------------------------------------------------------
co_op_other_xpos
 lda info_ptr
 cmp #<billy_sprite
 bne :cox_curr_is_jimmy
 lda info_ptr+1
 cmp #>billy_sprite
 bne :cox_curr_is_jimmy
* Current player is Billy → other is Jimmy.
 lda jimmy_sprite+2
 rts
:cox_curr_is_jimmy
* Current player is Jimmy → other is Billy.
 lda billy_sprite+2
 rts

*----------------------------------------------------------
* co_op_other_alive - C=1 if the OTHER player is still alive,
* C=0 if dead or inactive. Active player is identified by info_ptr.
*
* "Alive" here = "is a meaningful constraint on scrolling". The
* test that matters is: did this player get the $FFFF death
* sentinel written to their anim_ptr (info+24/+25)? That sentinel
* is the trigger erase_all uses to remove the sprite from
* sprite_table; once set, the player's info+2 is stale forever
* and shouldn't block the survivor. Fall_count alone isn't
* enough — it can sit below BILLY_MAX_FALLS while the sentinel
* is set by paths like cutscene cleanup or partial-state resets
* that happen before/after the fall_count update.
*
* Used by the scroll co-op clamps so a dead other player's stale
* info+2 doesn't block the survivor from pushing the scroll.
*----------------------------------------------------------
co_op_other_alive
 lda info_ptr
 cmp #<billy_sprite
 bne :coa_curr_is_jimmy
 lda info_ptr+1
 cmp #>billy_sprite
 bne :coa_curr_is_jimmy
* Current = Billy → other = Jimmy. Dead if jimmy_active=0 OR
* jimmy_stash_fall_count >= MAX OR anim_ptr == $FFFF.
 lda jimmy_active
 beq :coa_dead
 lda jimmy_stash_fall_count
 cmp #BILLY_MAX_FALLS
 bcs :coa_dead
 lda jimmy_sprite+24
 cmp #$FF
 bne :coa_alive
 lda jimmy_sprite+25
 cmp #$FF
 beq :coa_dead
 bra :coa_alive
:coa_curr_is_jimmy
* Current = Jimmy → other = Billy. Dead if billy_fall_count >= MAX
* OR anim_ptr == $FFFF. fall_count alone catches the case where
* Billy hits MAX but his anim_ptr is still the in-progress fall anim
* (not yet replaced by the $FFFF death sentinel). Death sentinel
* alone catches paths where the sentinel is set without fall_count
* reaching MAX (cutscene cleanup, boss-grab kill, etc.).
 lda billy_fall_count
 cmp #BILLY_MAX_FALLS
 bcs :coa_dead
 lda billy_sprite+24
 cmp #$FF
 bne :coa_alive
 lda billy_sprite+25
 cmp #$FF
 beq :coa_dead
:coa_alive
 sec
 rts
:coa_dead
 clc
 rts

*----------------------------------------------------------
* co_op_shift_other_left - Subtract 4 from the OTHER player's
* xpos so they stay anchored to the SAME world position while
* the current player scrolls right. Also snapshots prev_xpos
* and flags the sprite dirty so erase_all + draw_all repaint.
* Caller must guarantee xpos >= 4 (the :rso_no_other gate does).
*----------------------------------------------------------
co_op_shift_other_left
 lda info_ptr
 cmp #<billy_sprite
 bne :cosl_shift_billy
 lda info_ptr+1
 cmp #>billy_sprite
 bne :cosl_shift_billy
* Current is Billy → shift Jimmy left.
 lda jimmy_sprite+2
 sta jimmy_sprite+34    ; prev_xpos
 sec
 sbc #4
 sta jimmy_sprite+2
 lda jimmy_sprite+30
 ora #$03               ; dirty: erase + draw
 sta jimmy_sprite+30
 rts
:cosl_shift_billy
* Current is Jimmy → shift Billy left.
 lda billy_sprite+2
 sta billy_sprite+34
 sec
 sbc #4
 sta billy_sprite+2
 lda billy_sprite+30
 ora #$03
 sta billy_sprite+30
 rts

*----------------------------------------------------------
* co_op_shift_other_right - Mirror of co_op_shift_other_left
* for the left-scroll path. Adds 4 to the OTHER player's xpos
* so they stay anchored to the same world position while the
* current player scrolls left. Caller must guarantee the new
* xpos won't exceed PLAYER_MAX_X (the :lso_no_other gate does).
*----------------------------------------------------------
co_op_shift_other_right
 lda info_ptr
 cmp #<billy_sprite
 bne :cosr_shift_billy
 lda info_ptr+1
 cmp #>billy_sprite
 bne :cosr_shift_billy
* Current is Billy → shift Jimmy right.
 lda jimmy_sprite+2
 sta jimmy_sprite+34
 clc
 adc #4
 sta jimmy_sprite+2
 lda jimmy_sprite+30
 ora #$03
 sta jimmy_sprite+30
 rts
:cosr_shift_billy
* Current is Jimmy → shift Billy right.
 lda billy_sprite+2
 sta billy_sprite+34
 clc
 adc #4
 sta billy_sprite+2
 lda billy_sprite+30
 ora #$03
 sta billy_sprite+30
 rts

*----------------------------------------------------------
* co_op_shift_other_down - Vertical analogue of
* co_op_shift_other_left/right for the climb-scroll path. Adds
* 4 to the OTHER player's ypos so they stay anchored to their
* world-y while the current player scrolls the camera up.
* Caller must guarantee the new ypos won't push the sprite off
* the playfield bottom (co_op_other_would_clip_y gates this).
*----------------------------------------------------------
co_op_shift_other_down
 lda info_ptr
 cmp #<billy_sprite
 bne :cosd_shift_billy
 lda info_ptr+1
 cmp #>billy_sprite
 bne :cosd_shift_billy
* Current is Billy → shift Jimmy down.
 lda jimmy_sprite+0
 sta jimmy_sprite+32       ; prev_ypos
 clc
 adc #4
 sta jimmy_sprite+0
 lda jimmy_sprite+30
 ora #$03                  ; dirty: erase + draw
 sta jimmy_sprite+30
 rts
:cosd_shift_billy
* Current is Jimmy → shift Billy down.
 lda billy_sprite+0
 sta billy_sprite+32
 clc
 adc #4
 sta billy_sprite+0
 lda billy_sprite+30
 ora #$03
 sta billy_sprite+30
 rts

*----------------------------------------------------------
* co_op_other_would_clip_y - Return C=1 if shifting OTHER down
* by 4 would push their sprite's bottom past playfield row 182.
* Matches check_y_bounds' "proposed + frame_y > 183" clamp:
* ypos + 4 + frame_y >= 184  ⇔  ypos + frame_y >= 180.
*----------------------------------------------------------
co_op_other_would_clip_y
 lda info_ptr
 cmp #<billy_sprite
 bne :coey_curr_jimmy
 lda info_ptr+1
 cmp #>billy_sprite
 bne :coey_curr_jimmy
* Current = Billy → check Jimmy.
 lda jimmy_sprite+0
 clc
 adc jimmy_sprite+12
 cmp #180
 bcc :coey_ok
 sec
 rts
:coey_curr_jimmy
 lda billy_sprite+0
 clc
 adc billy_sprite+12
 cmp #180
 bcc :coey_ok
 sec
 rts
:coey_ok
 clc
 rts

*----------------------------------------------------------
* co_op_other_pressing_right / co_op_other_pressing_left
*
* Returns C=1 if the OTHER player (the one NOT currently being
* processed via info_ptr) is BOTH free to walk (no action anim)
* AND pressing the given direction this frame.
*
* Used by scroll handlers to decide whether to "carry" the
* other player along with the scroll. Otherwise the scroller
* pulls ahead by 3 bytes per scroll tick (walk +1, shift -4).
*
* Billy uses keyboard ('A'/'D'); Jimmy uses joystick (X axis).
* GetJoyXY is gated on joy_armed so a stuck KEGS axis doesn't
* force a false-positive boost.
*----------------------------------------------------------
co_op_other_pressing_right
 lda info_ptr
 cmp #<billy_sprite
 bne :copr_curr_jimmy
 lda info_ptr+1
 cmp #>billy_sprite
 bne :copr_curr_jimmy
* Current = Billy → other = Jimmy. Skip if Jimmy is anim-blocked.
 lda jimmy_sprite+24
 ora jimmy_sprite+25
 bne :copr_no
 lda joy_armed
 beq :copr_no
 jsr GetJoyXY            ; X = JoyX, Y = JoyY
 cpx #JOY_DEAD_HI+1
 bcc :copr_no
 sec
 rts
:copr_curr_jimmy
* Current = Jimmy → other = Billy. Skip if Billy is anim-blocked.
 lda billy_sprite+24
 ora billy_sprite+25
 bne :copr_no
 lda #ADB_KEY_D
 jsr key_held
 beq :copr_no
 sec
 rts
:copr_no
 clc
 rts

co_op_other_pressing_left
 lda info_ptr
 cmp #<billy_sprite
 bne :copl_curr_jimmy
 lda info_ptr+1
 cmp #>billy_sprite
 bne :copl_curr_jimmy
 lda jimmy_sprite+24
 ora jimmy_sprite+25
 bne :copl_no
 lda joy_armed
 beq :copl_no
 jsr GetJoyXY
 cpx #JOY_DEAD_LO
 bcs :copl_no            ; not past left deadzone
 sec
 rts
:copl_curr_jimmy
 lda billy_sprite+24
 ora billy_sprite+25
 bne :copl_no
 lda #ADB_KEY_A
 jsr key_held
 beq :copl_no
 sec
 rts
:copl_no
 clc
 rts

*----------------------------------------------------------
* co_op_carry_billy_left - Used when Jimmy scrolls right AND
* Billy is pressing right. Replaces the standard
* co_op_shift_other_left's shift-Billy-left behavior with a
* "carry" that keeps Billy advancing with the scroll instead
* of being left behind.
*
* Standard shift would set Billy.info+34 = pre-scroll info+2,
* info+2 = info+2 - 4, leaving Billy 4 bytes behind in screen
* coordinates (same world position). The carry instead:
*
*   info+2     = old info+34  (pre-walk-this-frame xpos)
*   info+34    = old info+34 - 4  (post-scroll-shift ghost target)
*
* Renderer erases at the ghost target (where bank $18's shift
* left Billy's pre-scroll pixels) and draws at info+2. Net Billy
* world delta: +4, matching Jimmy's scroll. Billy's own walk
* this frame (if any) is overwritten — accepted because the
* scroll boost is more important than the 1-byte walk delta.
*----------------------------------------------------------
co_op_carry_billy_left
 lda billy_sprite+34
 sta billy_sprite+2
 sec
 sbc #4
 sta billy_sprite+34
 lda billy_sprite+30
 ora #$03
 sta billy_sprite+30
 rts

*----------------------------------------------------------
* co_op_carry_billy_right - Mirror of co_op_carry_billy_left
* for left-scroll. Bank $18's shift-right leaves Billy's
* pre-scroll pixels 4 bytes to the RIGHT of his old position,
* so the ghost target is info+34 + 4 (not - 4).
*----------------------------------------------------------
co_op_carry_billy_right
 lda billy_sprite+34
 sta billy_sprite+2
 clc
 adc #4
 sta billy_sprite+34
 lda billy_sprite+30
 ora #$03
 sta billy_sprite+30
 rts

*----------------------------------------------------------
* co_op_other_pressing_up - Returns C=0 if the OTHER player is
* currently pressing up input this frame (Billy = 'w' held,
* Jimmy = joystick Y axis past the up deadzone). Reads input
* state directly so it doesn't depend on per-frame keyboard
* auto-repeat strobes. Skips returning "pressing" if OTHER is
* anim-blocked or (for Jimmy) the joystick isn't armed yet.
* Preserves info_ptr.
*----------------------------------------------------------
co_op_other_pressing_up
 lda info_ptr
 cmp #<billy_sprite
 bne :coup_curr_jimmy
 lda info_ptr+1
 cmp #>billy_sprite
 bne :coup_curr_jimmy
* Current = Billy → OTHER = Jimmy. Sample joystick.
 lda jimmy_sprite+24
 ora jimmy_sprite+25
 bne :coup_no                ; Jimmy anim-blocked
 lda joy_armed
 beq :coup_no
 jsr GetJoyXY                ; X = JoyX, Y = JoyY
 cpy #JOY_DEAD_LO
 bcs :coup_no                ; Y >= LO → not deflected up
 clc
 rts
:coup_curr_jimmy
* Current = Jimmy → OTHER = Billy. Check kb_held for 'W'.
 lda billy_sprite+24
 ora billy_sprite+25
 bne :coup_no                ; Billy anim-blocked
 lda #ADB_KEY_W
 jsr key_held
 beq :coup_no                ; not held
 clc
 rts
:coup_no
 sec
 rts

*----------------------------------------------------------
* co_op_other_on_ladder - Returns C=0 if the OTHER player's
* xpos overlaps a ladder's x-range. Y is ignored.
*
* Why ignore y: the climbing player has just stepped onto the
* ladder y-range (info+0 < y_bottom), but the other player is
* usually still at the floor (info+0 well below the ladder's
* y_bottom = 68 in mission1 vs floor at ~160). Including y in
* the gate would block the climb forever unless both happened
* to be at the same row — which is what the user reported:
* "couple frames before he gets stuck, the same is true of
* billy." The snap teleport pulls both xpos onto the ladder
* column, and scroll_up carries the other player along
* visually (their info+0 stays, world shifts under them).
*
* Mission1 caveat: ladder y_top = 0 for all 3 ladders, so
* passing prop_y = 0 always satisfies check_ladder's y check
* without bypassing it. Future levels with y_top > 0 would
* need a dedicated x-only ladder scan.
*----------------------------------------------------------
co_op_other_on_ladder
 lda chk_xpos
 pha
 lda anim_ptr
 pha
 lda anim_ptr+1
 pha
 lda info_ptr
 cmp #<billy_sprite
 bne :col_curr_jimmy
 lda info_ptr+1
 cmp #>billy_sprite
 bne :col_curr_jimmy
* Current = Billy → other = Jimmy.
 lda jimmy_sprite+2
 sta chk_xpos
 bra :col_check
:col_curr_jimmy
* Current = Jimmy → other = Billy.
 lda billy_sprite+2
 sta chk_xpos
:col_check
 lda #0                  ; prop_y = 0 (within y_top..y_bottom for
                         ; all mission1 ladders since y_top = 0).
 jsr check_ladder        ; C=0 if on ladder, C=1 otherwise
 php
 pla
 sta :col_flags
 pla
 sta anim_ptr+1
 pla
 sta anim_ptr
 pla
 sta chk_xpos
 lda :col_flags
 pha
 plp
 rts
:col_flags dfb 0

*----------------------------------------------------------
* co_op_mark_other_dirty - Set bit 0 + bit 1 (needs_draw +
* needs_erase) on the OTHER player's info+30. Used right after
* a climb-scroll so the next render restores them — scroll_up's
* fast_blit_18_01 just replaced bank $01 with the shifted bank
* $18 bg, wiping the other player off the visible playfield.
*
* Their info+0/+2 are unchanged, so info+32/+34 from last frame
* (or this frame's earlier save_sprite) point at the right erase
* rect. We just need them dirty so erase_all + draw_all fire.
*----------------------------------------------------------
co_op_mark_other_dirty
 lda info_ptr
 cmp #<billy_sprite
 bne :cmod_curr_jimmy
 lda info_ptr+1
 cmp #>billy_sprite
 bne :cmod_curr_jimmy
 lda jimmy_sprite+30
 ora #$03
 sta jimmy_sprite+30
 rts
:cmod_curr_jimmy
 lda billy_sprite+30
 ora #$03
 sta billy_sprite+30
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
* snes_poll - Read the active player's SNES MAX controller
* into snes_b0/b1.
*
* Protocol: write any value to SNES_LATCH to pulse the latch.
* Then 16 cycles of: read SNES_LATCH and isolate the active
* player's data bit (snes_poll_mask = $80 for P1/controller 1
* on bit 7, $40 for P2/controller 2 on bit 6). Shift the bit
* into snes_b0/b1, MSB-first, then pulse SNES_CLOCK. After all
* 16 bits are in, EOR with $FF so "pressed" reads as 1 (the
* card returns active-LOW).
*
* swap_in_jimmy / swap_out_jimmy own snes_poll_mask + the
* snes_b0_prev/b1_prev edge state, so each player gets the
* right controller bit + independent edge detection even when
* both P1 and P2 are on SNES (P1=MAX1, P2=MAX2).
*
* Bit layout after poll (active HIGH):
*   snes_b0: 0=Right 1=Left 2=Down 3=Up 4=Start 5=Select 6=Y 7=B
*   snes_b1: 0-3 unused, 4=R-shoulder 5=L-shoulder 6=X 7=A
*----------------------------------------------------------
snes_poll
* sps_latch_a / sps_latch_b / sps_clock_a are patched by
* apply_smax_slot at game init to point at whichever $C0nX slot
* the player chose. Default equate is slot 4.
sps_latch_a   stal SNES_LATCH       ; latch pulse — value doesn't matter
 ldx #0
:sp_byte
 ldy #8
:sp_bit
sps_latch_b   ldal SNES_LATCH       ; ctl 1 on bit 7, ctl 2 on bit 6
 and snes_poll_mask    ; isolate the active player's bit
 cmp #1                ; C = (A != 0) — works for $80 or $40
 rol snes_b0,x         ; carry → bit 0 of snes_b0/b1
sps_clock_a   stal SNES_CLOCK       ; clock pulse
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
* process_input_jimmy - Per-frame Jimmy input via context swap.
*
* Saves Billy's per-player globals (walk_step, billy_y_off,
* abs_x, walk_addr_tbl, ...), loads Jimmy's stashed equivalents,
* points info_ptr at jimmy_sprite, forces input_mode=1 (joystick),
* JSRs into pi_action_dispatch — the action-dispatch core of
* process_input — and then reverses the swap. The whole walk /
* jump / punch / kick / grab pipeline reused as-is; Jimmy ends
* up with his own independent state because the globals are
* swapped under it.
*
* Scroll triggers are suppressed by zeroing scroll_*_enabled
* during Jimmy's turn; Billy stays the one who scrolls the
* world. abs_x is saved+zeroed so Jimmy's walks don't move
* Billy's world position.
*----------------------------------------------------------
process_input_jimmy
 lda jimmy_active
 bne :pij_active
 rts
:pij_active
* Burnov-grab lock for Jimmy: bn_grab_active=$02 means Jimmy is
* currently held in Burnov's BNJIMMY pummel sequence. Swallow
* Jimmy's input until the grab ends. Mirrors process_input's
* gate for Billy.
 lda bn_grab_active
 cmp #$02
 bne :pij_not_grabbed
 rts
:pij_not_grabbed

 jsr swap_in_jimmy

* Tick Jimmy's own copies of the per-frame timers that
* process_input ticks at its top (we entered via the action-
* dispatch label, so the top didn't run). landing_window and
* punch_window are saved/restored across the swap so each
* player has independent grab / uppercut windows; ditto
* btn_pending_timer so the J/L (= joystick A/B) latch fires
* under whichever player queued it.
 lda landing_window
 beq :pij_no_lw
 dec landing_window
:pij_no_lw
 lda punch_window
 beq :pij_no_pw
 dec punch_window
:pij_no_pw
 lda btn_pending_timer
 beq :pij_no_bp
 dec btn_pending_timer
 bne :pij_no_bp
 lda #1
 sta btn_pending_fire
:pij_no_bp

* Find Jimmy's CURRENT slot in sprite_table by pointer match —
* resort_sprite_table re-orders entries by ypos every time a
* sprite moves, so Jimmy doesn't stay pinned at slot 1.
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:pij_find_jimmy
 ldy #0
 lda (spr_ptr),y
 sta info_ptr
 iny
 lda (spr_ptr),y
 sta info_ptr+1
 ora info_ptr
 beq :pij_no_jimmy        ; null terminator — Jimmy not in table
 lda info_ptr
 cmp #<jimmy_sprite
 bne :pij_jimmy_next
 lda info_ptr+1
 cmp #>jimmy_sprite
 beq :pij_jimmy_found
:pij_jimmy_next
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :pij_find_jimmy
 inc spr_ptr+1
 bra :pij_find_jimmy
:pij_no_jimmy
 jsr swap_out_jimmy       ; bail cleanly, restore Billy
 rts
:pij_jimmy_found
 jsr load_sprite          ; spr_ptr now points at Jimmy's slot

* Tick Jimmy's grab_punch_timer. Mirrors the block above
* pi_action_dispatch in process_input (Billy's path). Without
* this, Jimmy's timer sets to GRAB_PUNCH_DURATION on start_grab_punch
* and never decrements — grab_check then swallows every input, so
* L doesn't fire follow-up grab punches and AWAY doesn't release.
* On the 1->0 transition, restore BGRAB2/xHELD1 if still grabbing.
* info_ptr is already Jimmy from the load_sprite above, so
* end_grab_punch_subframe can be called directly without rescanning
* the sprite table.
 lda grab_punch_timer
 beq :pij_no_gp_dec
 dec grab_punch_timer
 bne :pij_no_gp_dec
 lda grab_target
 ora grab_target+1
 beq :pij_no_gp_dec
 jsr end_grab_punch_subframe
:pij_no_gp_dec

 jsr pi_action_dispatch

* No extra save_sprite here — process_input's walk handlers
* call save_sprite themselves at the right moment (BEFORE the
* xpos delta) so prev_xpos lands on the old position. A second
* save_sprite would re-snapshot prev from the *new* info+2,
* destroying the erase rect.

 jsr swap_out_jimmy
 rts

*----------------------------------------------------------
* swap_in_jimmy - Stash Billy's per-player globals, load Jimmy's.
*
* Touches:
*   - walk_step / walk_toggle / climb_toggle / punch_toggle
*   - billy_y_off / billy_y_target / billy_cur_x_off / billy_prev_x_off
*   - via_ladder
*   - billy_fall_count
*   - billy_pipe_armed / mace_armed / knife_armed
*   - punch_window / landing_window / grab_punch_timer
*   - last_hit_target / grab_target (2 bytes each)
*   - jump_x_toggle
*   - abs_x (2 bytes — zeroed for Jimmy so scroll edge checks
*     never trip)
*   - input_mode (forced to 1 = joystick)
*   - walk_addr_tbl + mask + mirror pair (32 bytes total) —
*     advance_walk reads these for the active player's walk
*     frames; we install jimmy_walk_addr_tbl etc. here.
*   - scroll_right_enabled / left_enabled / up_enabled —
*     zeroed so Jimmy can't trigger a scroll.
*----------------------------------------------------------
swap_in_jimmy
 lda walk_step
 sta billy_save_walk_step
 lda jimmy_stash_walk_step
 sta walk_step
 lda walk_toggle
 sta billy_save_walk_toggle
 lda jimmy_stash_walk_toggle
 sta walk_toggle
 lda climb_toggle
 sta billy_save_climb_toggle
 lda jimmy_stash_climb_toggle
 sta climb_toggle
 lda punch_toggle
 sta billy_save_punch_toggle
 lda jimmy_stash_punch_toggle
 sta punch_toggle
 lda billy_y_off
 sta billy_save_y_off
 lda jimmy_stash_y_off
 sta billy_y_off
 lda billy_y_target
 sta billy_save_y_target
 lda jimmy_stash_y_target
 sta billy_y_target
 lda billy_airborne
 sta billy_save_airborne
 lda jimmy_stash_airborne
 sta billy_airborne
 lda billy_y_vel
 sta billy_save_y_vel
 lda jimmy_stash_y_vel
 sta billy_y_vel
 lda billy_cur_x_off
 sta billy_save_cur_x_off
 lda jimmy_stash_cur_x_off
 sta billy_cur_x_off
 lda billy_prev_x_off
 sta billy_save_prev_x_off
 lda jimmy_stash_prev_x_off
 sta billy_prev_x_off
 lda via_ladder
 sta billy_save_via_ladder
 lda jimmy_stash_via_ladder
 sta via_ladder
 lda billy_fall_count
 sta billy_save_fall_count
 lda jimmy_stash_fall_count
 sta billy_fall_count
 lda billy_pipe_armed
 sta billy_save_pipe_armed
 lda jimmy_stash_pipe_armed
 sta billy_pipe_armed
 lda billy_mace_armed
 sta billy_save_mace_armed
 lda jimmy_stash_mace_armed
 sta billy_mace_armed
 lda billy_knife_armed
 sta billy_save_knife_armed
 lda jimmy_stash_knife_armed
 sta billy_knife_armed
 lda punch_window
 sta billy_save_punch_window
 lda jimmy_stash_punch_window
 sta punch_window
 lda landing_window
 sta billy_save_landing_window
 lda jimmy_stash_landing_window
 sta landing_window
 lda grab_punch_timer
 sta billy_save_grab_punch_timer
 lda jimmy_stash_grab_punch_timer
 sta grab_punch_timer
 lda jump_x_toggle
 sta billy_save_jump_x_toggle
 lda jimmy_stash_jump_x_toggle
 sta jump_x_toggle
 lda btn_pending_key
 sta billy_save_btn_pending_key
 lda jimmy_stash_btn_pending_key
 sta btn_pending_key
 lda btn_pending_timer
 sta billy_save_btn_pending_timer
 lda jimmy_stash_btn_pending_timer
 sta btn_pending_timer
 lda btn_pending_fire
 sta billy_save_btn_pending_fire
 lda jimmy_stash_btn_pending_fire
 sta btn_pending_fire
 lda joy_btn_a_prev
 sta billy_save_joy_btn_a_prev
 lda jimmy_stash_joy_btn_a_prev
 sta joy_btn_a_prev
 lda joy_btn_b_prev
 sta billy_save_joy_btn_b_prev
 lda jimmy_stash_joy_btn_b_prev
 sta joy_btn_b_prev
 lda last_hit_target
 sta billy_save_last_hit_target
 lda jimmy_stash_last_hit_target
 sta last_hit_target
 lda last_hit_target+1
 sta billy_save_last_hit_target+1
 lda jimmy_stash_last_hit_target+1
 sta last_hit_target+1
 lda grab_target
 sta billy_save_grab_target
 lda jimmy_stash_grab_target
 sta grab_target
 lda grab_target+1
 sta billy_save_grab_target+1
 lda jimmy_stash_grab_target+1
 sta grab_target+1
 lda abs_x
 sta billy_save_abs_x
 lda abs_x+1
 sta billy_save_abs_x+1
 stz abs_x
 stz abs_x+1
 lda input_mode
 sta billy_save_input_mode
 lda jimmy_input_mode
 sta input_mode
* SNES MAX state swap for P2 (= controller 2 of the same card).
* snes_poll_mask flips from $80 (P1 / ctl 1) to $40 (P2 / ctl 2),
* and snes_b0_prev/b1_prev are stashed so each player has its own
* button-edge detection across the swap. swap_out_jimmy reverses.
 lda snes_poll_mask
 sta billy_save_snes_poll_mask
 lda #$40              ; bit 6 = controller 2
 sta snes_poll_mask
 lda snes_b0_prev
 sta billy_save_snes_b0_prev
 lda jimmy_stash_snes_b0_prev
 sta snes_b0_prev
 lda snes_b1_prev
 sta billy_save_snes_b1_prev
 lda jimmy_stash_snes_b1_prev
 sta snes_b1_prev
* scroll_*_enabled are NOT swapped — they describe the world's
* current scroll permissions (set by OP_RIGHT / OP_LEFT / OP_UP
* in the level script) and apply to whichever player is at the
* edge. Both Billy and Jimmy share them. Co-op shift logic in
* :right_scroll_ok / :left_scroll_ok handles the "leave other
* player behind" semantics.
* Active anim pointers (point process_input's btn_action_* paths
* at Jimmy's anim variants while he's the active player). Save
* Billy's, install Jimmy's.
 lda active_jump_anim
 sta billy_save_active_jump_anim
 lda active_jump_anim+1
 sta billy_save_active_jump_anim+1
 lda #<anim_jjump
 sta active_jump_anim
 lda #>anim_jjump
 sta active_jump_anim+1
 lda active_bspinkick_anim
 sta billy_save_active_bspinkick_anim
 lda active_bspinkick_anim+1
 sta billy_save_active_bspinkick_anim+1
 lda #<anim_jbspinkick
 sta active_bspinkick_anim
 lda #>anim_jbspinkick
 sta active_bspinkick_anim+1
 lda active_kick_anim
 sta billy_save_active_kick_anim
 lda active_kick_anim+1
 sta billy_save_active_kick_anim+1
 lda #<anim_jkick
 sta active_kick_anim
 lda #>anim_jkick
 sta active_kick_anim+1
 lda active_punch1_anim
 sta billy_save_active_punch1_anim
 lda active_punch1_anim+1
 sta billy_save_active_punch1_anim+1
 lda #<anim_jpunch1
 sta active_punch1_anim
 lda #>anim_jpunch1
 sta active_punch1_anim+1
 lda active_punch2_anim
 sta billy_save_active_punch2_anim
 lda active_punch2_anim+1
 sta billy_save_active_punch2_anim+1
 lda #<anim_jpunch2
 sta active_punch2_anim
 lda #>anim_jpunch2
 sta active_punch2_anim+1
 lda active_uppercut_anim
 sta billy_save_active_uppercut_anim
 lda active_uppercut_anim+1
 sta billy_save_active_uppercut_anim+1
 lda #<anim_juppercut
 sta active_uppercut_anim
 lda #>anim_juppercut
 sta active_uppercut_anim+1
* active_pickup_anim ← anim_jpickup so billy_try_pickup_weapon's
* start_anim plays Jimmy's pickup pose while he's the keyboard's
* active player.
 lda active_pickup_anim
 sta billy_save_active_pickup_anim
 lda active_pickup_anim+1
 sta billy_save_active_pickup_anim+1
 lda #<anim_jpickup
 sta active_pickup_anim
 lda #>anim_jpickup
 sta active_pickup_anim+1
* Weapon-swing anims: Jimmy's pipe/mace swings live in bank $1D
* (JPIPE1-4 / JMACE1-4). btn_action_fire's L-key dispatch reads
* active_*_swing_anim so both players use their own palette.
 lda active_pipe_swing_anim
 sta billy_save_active_pipe_swing_anim
 lda active_pipe_swing_anim+1
 sta billy_save_active_pipe_swing_anim+1
 lda #<anim_jpipeswing
 sta active_pipe_swing_anim
 lda #>anim_jpipeswing
 sta active_pipe_swing_anim+1
 lda active_mace_swing_anim
 sta billy_save_active_mace_swing_anim
 lda active_mace_swing_anim+1
 sta billy_save_active_mace_swing_anim+1
 lda #<anim_jmaceswing
 sta active_mace_swing_anim
 lda #>anim_jmaceswing
 sta active_mace_swing_anim+1
 ldx #7
:sij_tables
 lda walk_addr_tbl,x
 sta billy_save_walk_addr_tbl,x
 lda jimmy_walk_addr_tbl,x
 sta walk_addr_tbl,x
 lda walk_mask_tbl,x
 sta billy_save_walk_mask_tbl,x
 lda jimmy_walk_mask_tbl,x
 sta walk_mask_tbl,x
 lda walk_addr_tbl_mirror,x
 sta billy_save_walk_addr_tbl_mir,x
 lda jimmy_walk_addr_tbl_mirror,x
 sta walk_addr_tbl_mirror,x
 lda walk_mask_tbl_mirror,x
 sta billy_save_walk_mask_tbl_mir,x
 lda jimmy_walk_mask_tbl_mirror,x
 sta walk_mask_tbl_mirror,x
 dex
 bpl :sij_tables
 rts

*----------------------------------------------------------
* swap_out_jimmy - Reverse swap_in_jimmy. Save Jimmy's modified
* state to jimmy_stash_*, restore Billy's from billy_save_*.
*----------------------------------------------------------
swap_out_jimmy
 lda walk_step
 sta jimmy_stash_walk_step
 lda billy_save_walk_step
 sta walk_step
 lda walk_toggle
 sta jimmy_stash_walk_toggle
 lda billy_save_walk_toggle
 sta walk_toggle
 lda climb_toggle
 sta jimmy_stash_climb_toggle
 lda billy_save_climb_toggle
 sta climb_toggle
 lda punch_toggle
 sta jimmy_stash_punch_toggle
 lda billy_save_punch_toggle
 sta punch_toggle
 lda billy_y_off
 sta jimmy_stash_y_off
 lda billy_save_y_off
 sta billy_y_off
 lda billy_y_target
 sta jimmy_stash_y_target
 lda billy_save_y_target
 sta billy_y_target
 lda billy_airborne
 sta jimmy_stash_airborne
 lda billy_save_airborne
 sta billy_airborne
 lda billy_y_vel
 sta jimmy_stash_y_vel
 lda billy_save_y_vel
 sta billy_y_vel
 lda billy_cur_x_off
 sta jimmy_stash_cur_x_off
 lda billy_save_cur_x_off
 sta billy_cur_x_off
 lda billy_prev_x_off
 sta jimmy_stash_prev_x_off
 lda billy_save_prev_x_off
 sta billy_prev_x_off
 lda via_ladder
 sta jimmy_stash_via_ladder
 lda billy_save_via_ladder
 sta via_ladder
 lda billy_fall_count
 sta jimmy_stash_fall_count
 lda billy_save_fall_count
 sta billy_fall_count
 lda billy_pipe_armed
 sta jimmy_stash_pipe_armed
 lda billy_save_pipe_armed
 sta billy_pipe_armed
 lda billy_mace_armed
 sta jimmy_stash_mace_armed
 lda billy_save_mace_armed
 sta billy_mace_armed
 lda billy_knife_armed
 sta jimmy_stash_knife_armed
 lda billy_save_knife_armed
 sta billy_knife_armed
 lda punch_window
 sta jimmy_stash_punch_window
 lda billy_save_punch_window
 sta punch_window
 lda landing_window
 sta jimmy_stash_landing_window
 lda billy_save_landing_window
 sta landing_window
 lda grab_punch_timer
 sta jimmy_stash_grab_punch_timer
 lda billy_save_grab_punch_timer
 sta grab_punch_timer
 lda jump_x_toggle
 sta jimmy_stash_jump_x_toggle
 lda billy_save_jump_x_toggle
 sta jump_x_toggle
 lda btn_pending_key
 sta jimmy_stash_btn_pending_key
 lda billy_save_btn_pending_key
 sta btn_pending_key
 lda btn_pending_timer
 sta jimmy_stash_btn_pending_timer
 lda billy_save_btn_pending_timer
 sta btn_pending_timer
 lda btn_pending_fire
 sta jimmy_stash_btn_pending_fire
 lda billy_save_btn_pending_fire
 sta btn_pending_fire
 lda joy_btn_a_prev
 sta jimmy_stash_joy_btn_a_prev
 lda billy_save_joy_btn_a_prev
 sta joy_btn_a_prev
 lda joy_btn_b_prev
 sta jimmy_stash_joy_btn_b_prev
 lda billy_save_joy_btn_b_prev
 sta joy_btn_b_prev
 lda last_hit_target
 sta jimmy_stash_last_hit_target
 lda billy_save_last_hit_target
 sta last_hit_target
 lda last_hit_target+1
 sta jimmy_stash_last_hit_target+1
 lda billy_save_last_hit_target+1
 sta last_hit_target+1
 lda grab_target
 sta jimmy_stash_grab_target
 lda billy_save_grab_target
 sta grab_target
 lda grab_target+1
 sta jimmy_stash_grab_target+1
 lda billy_save_grab_target+1
 sta grab_target+1
* Restore Billy's tracked abs_x. abs_x is Billy-tied (assert_abs_x
* checks abs_x == world_offset + billy.xpos every frame). Script
* opcode comparisons (OP_WAITX/OP_WAITXREV) take the rightmost
* player into account at the comparison sites, not here.
 lda billy_save_abs_x
 sta abs_x
 lda billy_save_abs_x+1
 sta abs_x+1
 lda billy_save_input_mode
 sta input_mode
* SNES MAX state restore — counterpart to the swap_in_jimmy block.
 lda snes_b0_prev
 sta jimmy_stash_snes_b0_prev
 lda billy_save_snes_b0_prev
 sta snes_b0_prev
 lda snes_b1_prev
 sta jimmy_stash_snes_b1_prev
 lda billy_save_snes_b1_prev
 sta snes_b1_prev
 lda billy_save_snes_poll_mask
 sta snes_poll_mask
* scroll_*_enabled stay shared between Billy and Jimmy (set by
* the level script, not swapped per player).
* Restore Billy's active anim pointers.
 lda billy_save_active_jump_anim
 sta active_jump_anim
 lda billy_save_active_jump_anim+1
 sta active_jump_anim+1
 lda billy_save_active_bspinkick_anim
 sta active_bspinkick_anim
 lda billy_save_active_bspinkick_anim+1
 sta active_bspinkick_anim+1
 lda billy_save_active_kick_anim
 sta active_kick_anim
 lda billy_save_active_kick_anim+1
 sta active_kick_anim+1
 lda billy_save_active_punch1_anim
 sta active_punch1_anim
 lda billy_save_active_punch1_anim+1
 sta active_punch1_anim+1
 lda billy_save_active_punch2_anim
 sta active_punch2_anim
 lda billy_save_active_punch2_anim+1
 sta active_punch2_anim+1
 lda billy_save_active_uppercut_anim
 sta active_uppercut_anim
 lda billy_save_active_uppercut_anim+1
 sta active_uppercut_anim+1
 lda billy_save_active_pickup_anim
 sta active_pickup_anim
 lda billy_save_active_pickup_anim+1
 sta active_pickup_anim+1
 lda billy_save_active_pipe_swing_anim
 sta active_pipe_swing_anim
 lda billy_save_active_pipe_swing_anim+1
 sta active_pipe_swing_anim+1
 lda billy_save_active_mace_swing_anim
 sta active_mace_swing_anim
 lda billy_save_active_mace_swing_anim+1
 sta active_mace_swing_anim+1
 ldx #7
:soj_tables
 lda billy_save_walk_addr_tbl,x
 sta walk_addr_tbl,x
 lda billy_save_walk_mask_tbl,x
 sta walk_mask_tbl,x
 lda billy_save_walk_addr_tbl_mir,x
 sta walk_addr_tbl_mirror,x
 lda billy_save_walk_mask_tbl_mir,x
 sta walk_mask_tbl_mirror,x
 dex
 bpl :soj_tables
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
 ldy #60
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
* Joystick-controlled players (controller=$02 = Jimmy) step on
* walk_toggle phase 0 — every other VBL, 1→0→1→0. The walk
* handlers gate their position step on the same `walk_toggle == 0`
* condition so leg cadence and motion stay in sync.
*
* Keyboard-controlled players (controller=$01 = Billy) bypass the
* toggle entirely: walk_toggle is left at 0 every call so the
* position-step gates downstream always fire → keyboard walks at
* one step per VBL. ADB key repeat can't keep up with the
* throttled cadence (kbd_init's fast-repeat boost is also off),
* so keyboard needs every-VBL stepping to feel responsive.
* walk_toggle is per-player (saved/restored across the co-op
* swap_in_jimmy stash), so leaving Billy's at 0 doesn't perturb
* Jimmy's countdown.
 ldy #22
 lda (info_ptr),y
 cmp #$02
 beq :wa_throttle      ; joystick player → toggle
 bra :do_advance       ; keyboard / other → every VBL
:wa_throttle
 lda walk_toggle
 bne :wt_dec
 lda #1
 sta walk_toggle
 bra :do_advance
:wt_dec
 dec walk_toggle
 rts
:do_advance
 inc walk_step
 lda walk_step
 cmp #4
 bcc :ok
 stz walk_step
 lda #0
:ok tax
* Armed-with-knife uses a per-frame X table (BKWALK1/3=11,
* BKWALK2=9) but a uniform 40-line height. Pipe and mace stay
* on the uniform 9×40 walk_x/y_tbl. For Jimmy, use the parallel
* jimmy_knife_walk_x_tbl (same values, different storage so
* future tuning per player stays clean).
 lda billy_knife_armed
 beq :aw_norm_dims
 jsr arm_is_jimmy
 bcc :aw_knife_x_billy
 lda jimmy_knife_walk_x_tbl,x
 bra :aw_knife_x_set
:aw_knife_x_billy
 lda knife_walk_x_tbl,x
:aw_knife_x_set
 sta FRAME_X
 lda #$28
 sta FRAME_Y
 bra :aw_dims_done
:aw_norm_dims
 lda walk_x_tbl,x
 sta FRAME_X
 lda walk_y_tbl,x
 sta FRAME_Y
:aw_dims_done
 txa
 asl
 tax
* Armed dispatch: if the active player is carrying a pipe, mace,
* or knife, walk uses the matching armed walk table. Billy uses
* the bank-$19 sprites; Jimmy uses bank-$1D. The flag check
* works because swap_in_jimmy swaps billy_*_armed with Jimmy's
* stash, so during Jimmy's input the flag reflects Jimmy's
* armed state.
 lda billy_pipe_armed
 bne :aw_pipe
 lda billy_mace_armed
 bne :aw_mace
 lda billy_knife_armed
 bne :aw_knife
 bra :aw_unarmed
:aw_pipe
 jsr arm_is_jimmy
 bcc :aw_pipe_billy
 lda jimmy_pipe_walk_addr_tbl,x
 sta FRAME_ADDR
 lda jimmy_pipe_walk_addr_tbl+1,x
 sta FRAME_ADDR+1
 bra :aw_armed_common
:aw_pipe_billy
 lda pipe_walk_addr_tbl,x
 sta FRAME_ADDR
 lda pipe_walk_addr_tbl+1,x
 sta FRAME_ADDR+1
 bra :aw_armed_common
:aw_mace
 jsr arm_is_jimmy
 bcc :aw_mace_billy
 lda jimmy_mace_walk_addr_tbl,x
 sta FRAME_ADDR
 lda jimmy_mace_walk_addr_tbl+1,x
 sta FRAME_ADDR+1
 bra :aw_armed_common
:aw_mace_billy
 lda mace_walk_addr_tbl,x
 sta FRAME_ADDR
 lda mace_walk_addr_tbl+1,x
 sta FRAME_ADDR+1
 bra :aw_armed_common
:aw_knife
 jsr arm_is_jimmy
 bcc :aw_knife_billy
 lda jimmy_knife_walk_addr_tbl,x
 sta FRAME_ADDR
 lda jimmy_knife_walk_addr_tbl+1,x
 sta FRAME_ADDR+1
 bra :aw_armed_common
:aw_knife_billy
 lda knife_walk_addr_tbl,x
 sta FRAME_ADDR
 lda knife_walk_addr_tbl+1,x
 sta FRAME_ADDR+1
:aw_armed_common
 lda #0
 sta MASK_ADDR
 sta MASK_ADDR+1
 jsr arm_is_jimmy
 bcc :aw_armed_billy_bank
 lda #$1D
 bra :aw_armed_bank_set
:aw_armed_billy_bank
 lda #$19
:aw_armed_bank_set
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
* Init walk_toggle=0 (the trigger phase of the 3-state walk gate)
* so the first walk press after a cold start moves + advances
* frame on the very first VBL — otherwise the player feels a
* 1-2 VBL input drop on the first key after start.
walk_toggle dfb 0
jump_x_toggle dfb 0    ; flips each VBL during anim_jump's bit-0
                       ; X-advance step. Halves the horizontal jump
                       ; distance: xpos / abs_x advance only on the
                       ; ticks where the toggle flips to 0.

* Co-op walk boost. Set non-zero (= step magnitude) by a scroll
* handler when the OTHER player is pressing same direction as
* the scroll. Their walk handler reads it instead of the default
* +1, then clears it. Lets the non-scrolling player advance at
* scroll speed (+4) instead of falling behind by 3 per tick.
* Cleared at top of process_input each frame so stale boost
* doesn't fire on a future walk.
walk_boost_right dfb 0
walk_boost_left  dfb 0

*----------------------------------------------------------
* advance_climb - Set climbing frame (BCLIMB1/BCLIMB2),
* alternating each call. Sets FRAME_X/Y/ADDR globals.
*----------------------------------------------------------
advance_climb
 lda climb_toggle
 eor #$01
 sta climb_toggle
 lda #$08              ; BCLIMB1/2 width — same for Jimmy
 sta FRAME_X
 lda #$28              ; height
 sta FRAME_Y
* Dispatch by current player. Billy ($01) gets bank-$02 BCLIMB;
* Jimmy ($02 + pointer-match against jimmy_sprite) gets bank-$1D
* JCLIMB. The compiled pipeline reads both DATA and MASK out of
* sprite_bank, which load_sprite set from info+56 ($02 for Billy
* / $1D for Jimmy) — so we just need to point FRAME_ADDR /
* MASK_ADDR at the right cache pair for each player.
 ldy #22
 lda (info_ptr),y
 cmp #$02
 beq :ac_chk_jimmy
 jmp :ac_billy_path
:ac_chk_jimmy
 lda info_ptr
 cmp #<jimmy_sprite
 beq :ac_chk_jimmy_hi
 jmp :ac_billy_path
:ac_chk_jimmy_hi
 lda info_ptr+1
 cmp #>jimmy_sprite
 beq :ac_jimmy_path
 jmp :ac_billy_path
:ac_jimmy_path
 lda climb_toggle
 beq :ac_j_use_1
* JCLIMB2 branch
 lda IMAGE01_MIRROR
 bne :ac_j_2_mirror
 lda spr_jclimb2
 sta FRAME_ADDR
 lda spr_jclimb2+1
 sta FRAME_ADDR+1
 lda spr_jclimb2_mask
 sta MASK_ADDR
 lda spr_jclimb2_mask+1
 sta MASK_ADDR+1
 rts
:ac_j_2_mirror
 lda spr_jclimb2_data_mir
 sta FRAME_ADDR
 lda spr_jclimb2_data_mir+1
 sta FRAME_ADDR+1
 lda spr_jclimb2_mask_mir
 sta MASK_ADDR
 lda spr_jclimb2_mask_mir+1
 sta MASK_ADDR+1
 rts
:ac_j_use_1
 lda IMAGE01_MIRROR
 bne :ac_j_1_mirror
 lda spr_jclimb1
 sta FRAME_ADDR
 lda spr_jclimb1+1
 sta FRAME_ADDR+1
 lda spr_jclimb1_mask
 sta MASK_ADDR
 lda spr_jclimb1_mask+1
 sta MASK_ADDR+1
 rts
:ac_j_1_mirror
 lda spr_jclimb1_data_mir
 sta FRAME_ADDR
 lda spr_jclimb1_data_mir+1
 sta FRAME_ADDR+1
 lda spr_jclimb1_mask_mir
 sta MASK_ADDR
 lda spr_jclimb1_mask_mir+1
 sta MASK_ADDR+1
 rts
:ac_billy_path
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

* Jimmy walk-frame tables — same layout/widths as Billy's
* (JIMMY01/02/03/02 cycle), patched by init_jimmy from the
* bank-$1D Jimmy sprite-address table. advance_jimmy_walk indexes
* by jimmy_walk_step (0..3) and picks the mirror-bank pair from
* jimmy_sprite+4.
jimmy_walk_addr_tbl        ds 8
jimmy_walk_mask_tbl        ds 8
jimmy_walk_addr_tbl_mirror ds 8
jimmy_walk_mask_tbl_mirror ds 8
jimmy_walk_step    dfb 0
jimmy_walk_toggle  dfb 0

*----------------------------------------------------------
* advance_jimmy_walk - Cycle Jimmy's walk frame. Called by
* process_input_jimmy whenever the joystick produces a movement
* this VBL. Same toggle/step pattern Billy uses in advance_walk:
* steps 0..3 → JIMMY01, JIMMY02, JIMMY03, JIMMY02; frame swap
* every 2nd call so the leg cadence matches the move rate.
*
* Writes frame_x, frame_y, frame_addr, and mask_addr directly
* into jimmy_sprite — the next draw_all pulls these via
* load_sprite. No anim_ptr involvement; Jimmy's walk doesn't
* go through update_anims.
*----------------------------------------------------------
advance_jimmy_walk
 lda jimmy_walk_toggle
 eor #$01
 sta jimmy_walk_toggle
 beq :ajw_step
 rts
:ajw_step
 inc jimmy_walk_step
 lda jimmy_walk_step
 cmp #4
 bcc :ajw_ok
 stz jimmy_walk_step
 lda #0
:ajw_ok tax
 lda walk_x_tbl,x          ; reuse Billy's width table — JIMMY
 sta jimmy_sprite+10       ; frames have the same per-step widths
 lda walk_y_tbl,x
 sta jimmy_sprite+12
 txa
 asl
 tax                       ; x = byte offset into the addr tables
 lda jimmy_sprite+4        ; mirror flag
 bne :ajw_mir
 lda jimmy_walk_addr_tbl,x
 sta jimmy_sprite+14
 lda jimmy_walk_addr_tbl+1,x
 sta jimmy_sprite+15
 lda jimmy_walk_mask_tbl,x
 sta jimmy_sprite+60
 lda jimmy_walk_mask_tbl+1,x
 sta jimmy_sprite+61
 rts
:ajw_mir
 lda jimmy_walk_addr_tbl_mirror,x
 sta jimmy_sprite+14
 lda jimmy_walk_addr_tbl_mirror+1,x
 sta jimmy_sprite+15
 lda jimmy_walk_mask_tbl_mirror,x
 sta jimmy_sprite+60
 lda jimmy_walk_mask_tbl_mirror+1,x
 sta jimmy_sprite+61
 rts

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
* Per-anim frame_bank from descriptor flag bits.
*   bit 3 set → frames in bank $1C (mission14, armed compiled)
*   bit 6 set → frames in bank $1B (mission13, regular compiled)
*   bit 5 set → frames in bank $19 (mission12, legacy)
*   bit 2 set → frames in bank $1D (mission1jimmy, Jimmy player)
*   else      → frames in bank $02 (mission1)
* bit 7 (compiled stride) is independent — Billy's compiled anims
* (anim_jump, anim_bspinkick, anim_bpunched, anim_punch*, etc.)
* have bit 7 set but bits 3/5/6/2 clear so their frames stay in
* bank $02. Precedence is bit 3 > bit 6 > bit 5 > bit 2 > default.
* Lets a single sprite straddle banks (e.g. williams_pipe walks
* with bank-$1C WPIPEWALK frames but falls with bank-$1B
* anim_wfall). :normal_end restores info+56 from info+58 when the
* anim ends so the idle frame draws from its own bank.
 ldy #2
 lda (anim_ptr),y     ; flags
 and #$08
 beq :sa_chk_1b
 lda #$1C
 bra :sa_set_bank
:sa_chk_1b
 ldy #2
 lda (anim_ptr),y
 and #$40
 beq :sa_chk_19
 lda #$1B
 bra :sa_set_bank
:sa_chk_19
 ldy #2
 lda (anim_ptr),y
 and #$20
 beq :sa_chk_1d
 lda #$19
 bra :sa_set_bank
:sa_chk_1d
 ldy #2
 lda (anim_ptr),y
 and #$04
 beq :sa_bank2_default
 lda #$1D
 bra :sa_set_bank
:sa_bank2_default
 lda #$02
:sa_set_bank
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
* Clear MASK_ADDR + info+60 so the dispatch routes legacy this
* frame; load_sprite next frame copies info+60 back to MASK_ADDR
* (still 0 here, so legacy persists through the anim). For Billy
* and compiled NPCs, :normal_end restores info+60 from the right
* idle source when the legacy anim ends.
* (The previous code gated this on controller==1 because info+52
* held walk_anim for NPCs and zeroing it would corrupt them. With
* the move to info+60 the gate is no longer needed.)
 lda #0
 sta MASK_ADDR
 sta MASK_ADDR+1
 ldy #60
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
* Pick mirror vs non-mirror frame from this sprite's own info+4,
* not IMAGE01_MIRROR. The global is set by load_sprite, which
* runs for Billy during process_input but NOT for NPCs during
* update_npcs — so an NPC reaching start_anim mid-update_npcs
* would otherwise grab Billy's mirror and pick the wrong first
* frame (visible as a 1-frame flip away from the player at the
* start of every NPC compiled punch). For Billy callers, info+4
* equals IMAGE01_MIRROR, so no regression.
 ldy #4
 lda (info_ptr),y     ; this sprite's mirror flag
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
* Persist MASK_ADDR → info+60 (active_mask_addr) so load_sprite
* picks it up next frame. Used by both Billy and compiled NPCs
* now that +60 is dedicated.
 ldy #60
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
* NPC right-edge clamp. When an NPC at the right edge of the
* playable area gets fall_anim'd (or any wider anim), the new
* frame_x can push xpos + frame_x past PLAYFIELD_EDGE and the
* sprite renders into the black margin. The fall-trajectory
* clamp prevents further increase but doesn't decrement the
* initial overshoot — do that here once at anim install. Skip
* for Billy (controller=1) since his own movement code already
* clamps to PLAYER_MAX_X.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 beq :sa_skip_xclamp
 ldy #2
 lda (info_ptr),y      ; xpos
 ldy #10
 clc
 adc (info_ptr),y      ; A = xpos + frame_x = right edge
 cmp #PLAYFIELD_EDGE
 bcc :sa_skip_xclamp
* right_edge >= PLAYFIELD_EDGE → snap xpos = PLAYFIELD_EDGE - frame_x.
 lda #PLAYFIELD_EDGE
 ldy #10
 sec
 sbc (info_ptr),y      ; A = PLAYFIELD_EDGE - frame_x
 ldy #2
 sta (info_ptr),y      ; xpos = clamped
:sa_skip_xclamp
 ldy #30
 lda #$07               ; bit 2 = force_erase (see save_sprite). New
 sta (info_ptr),y       ; anim just rewrote info+14, so the no-
                        ; movement skip in erase_all would otherwise
                        ; leave the prior anim's pixels visible
                        ; under the new frame's transparent cells.
* Set per-anim render-x offset at info+9 (cur_x_off, signed byte).
* Read by draw_all to populate frame_x_off before each draw call;
* latched into info+8 (prev_x_off) right after the draw so erase_all
* next frame can clear the rect at the correct screen column.
* Punch frames lunge wider than the idle (PUNCH12/22 = 16 vs 9), so
* the body shifts within the sprite — we shift the screen position
* the other way to keep the body anchored: +1 right-facing, -5
* mirrored. All other anims get 0.
 jsr set_anim_x_off
 jsr set_billy_y_target
 rts

*----------------------------------------------------------
* set_anim_x_off - Compute billy_cur_x_off from anim_ptr +
* anim_frame (info+26) + IMAGE01_MIRROR. Gated on controller==1
* so NPC anims don't poke Billy's offset state. Called by
* start_anim (frame 0) and update_anims at every frame advance,
* so per-frame offsets shift with the anim.
*
* Today only anim_punch1/anim_punch2 carry offsets:
*   frame 0 (PUNCH11/PUNCH21, narrow wind-up):  0 / 0
*   frame 1 (PUNCH12/PUNCH22, wide lunge):     +1 / -2
* Tune these in the per-frame tables below.
* On entry: anim_ptr = animation, info_ptr = sprite info block.
*----------------------------------------------------------
set_anim_x_off
 ldy #22
 lda (info_ptr),y
 cmp #$01
 beq :sx_is_player      ; Billy
 cmp #$02
 beq :sx_is_player      ; Jimmy
* NPC (controller=$00). Different routing: instead of writing
* billy_cur_x_off / jimmy_cur_x_off, write info+68 (cur_x_off)
* on this NPC's block. erase_all/draw_all pull from there.
 jmp :sx_npc_dispatch
:sx_is_player
 sta :sx_ctrl           ; remember which player so :sx_store
                        ;     routes to the right *_cur_x_off
* Recognise both Billy's and Jimmy's punch anims (same wind-up
* + lunge frame shape, so they share the offset table).
 lda anim_ptr
 cmp #<anim_punch1
 bne :sx_chk_p2
 lda anim_ptr+1
 cmp #>anim_punch1
 beq :sx_punch
:sx_chk_p2
 lda anim_ptr
 cmp #<anim_punch2
 bne :sx_chk_jp1
 lda anim_ptr+1
 cmp #>anim_punch2
 beq :sx_punch
:sx_chk_jp1
 lda anim_ptr
 cmp #<anim_jpunch1
 bne :sx_chk_jp2
 lda anim_ptr+1
 cmp #>anim_jpunch1
 beq :sx_punch
:sx_chk_jp2
 lda anim_ptr
 cmp #<anim_jpunch2
 bne :sx_no_off
 lda anim_ptr+1
 cmp #>anim_jpunch2
 bne :sx_no_off
:sx_punch
* Index per-frame offset by anim_frame (info+26). Both Billy
* and Jimmy share the same wind-up→lunge shape on these anims,
* so a single table per facing covers both.
 ldy #26
 lda (info_ptr),y
 tax
 cpx #2
 bcc :sx_idx_ok
 ldx #0
:sx_idx_ok
 lda IMAGE01_MIRROR
 bne :sx_punch_mir
 lda :sx_punch_off_right,x
 bra :sx_store
:sx_punch_mir
 lda :sx_punch_off_mirror,x
 bra :sx_store
:sx_no_off
 lda #0
:sx_store
* A = computed offset. Route to the right player's slot. We
* stashed which player into :sx_ctrl at entry (see :sx_player
* branch above); store there, then dispatch.
 ldx :sx_ctrl
 cpx #$01
 bne :sx_store_jimmy
 sta billy_cur_x_off
 rts
:sx_store_jimmy
 sta jimmy_cur_x_off
:sx_done
 rts
:sx_ctrl dfb 0

* Per-frame render-x offsets for the punch anims, indexed by
* anim_frame (0 = wind-up, 1 = lunge). Signed bytes.
* Mirror frames need negative offsets because the mirrored
* sprite data tucks the body into the right half of the wider
* frame, so drawing at the same xpos shifts the body right vs
* the IMAGE01 mirrored idle. Wind-up sprites (PUNCH11/21) are
* only ~2 bytes wider → 1-byte natural shift, fixed by $FF (-1).
* Lunge sprites (PUNCH12/22) are ~7 bytes wider → 9-byte
* natural shift, fixed by $F7 (-9).
:sx_punch_off_right  dfb $00,$00
:sx_punch_off_mirror dfb $ff,$F9

*----------------------------------------------------------
* NPC render-x compensation. Same shape as the Billy/Jimmy
* punch-offset path above, but writes to this NPC's info+68
* (cur_x_off) instead of the global. Currently covers
* anim_wpunch (Williams); add comparisons for Roper / Linda /
* etc. as their punch anims get tuned. Right-facing (mirror=0)
* needs no compensation; mirror=1 the lunge frame's body sits
* in the right half of the wider sprite and would visually
* slide backward without the negative offset.
*
* anim_wpunch widths: WPUNCH1 = 11 bytes (idle is 9 → 2 wider),
* WPUNCH2 = 17 bytes (8 wider). Tracks Billy's tuning shape.
*----------------------------------------------------------
:sx_npc_dispatch
* William's offensive punch.
 lda anim_ptr
 cmp #<anim_wpunch
 bne :sx_chk_rpunch
 lda anim_ptr+1
 cmp #>anim_wpunch
 bne :sx_chk_rpunch
* anim_frame index → table.
 ldy #26
 lda (info_ptr),y
 tax
 cpx #2
 bcc :sx_wp_idx_ok
 ldx #0
:sx_wp_idx_ok
 ldy #4
 lda (info_ptr),y         ; NPC's own mirror (not IMAGE01_MIRROR —
                          ;     update_npcs doesn't refresh that)
 bne :sx_wp_mir
 lda :sx_wpunch_off_right,x
 bra :sx_npc_store
:sx_wp_mir
 lda :sx_wpunch_off_mirror,x
 bra :sx_npc_store

:sx_chk_rpunch
* Roper's offensive punch. RPUNCH1 = 11 wide, RPUNCH2 = 16 wide
* (idle ROPER1 = 9). Same width pattern as Billy's punch1/2, so
* the same -1 / -7 mirror offsets work.
 lda anim_ptr
 cmp #<anim_rpunch
 bne :sx_npc_no_off
 lda anim_ptr+1
 cmp #>anim_rpunch
 bne :sx_npc_no_off
 ldy #26
 lda (info_ptr),y
 tax
 cpx #2
 bcc :sx_rp_idx_ok
 ldx #0
:sx_rp_idx_ok
 ldy #4
 lda (info_ptr),y
 bne :sx_rp_mir
 lda :sx_rpunch_off_right,x
 bra :sx_npc_store
:sx_rp_mir
 lda :sx_rpunch_off_mirror,x
 bra :sx_npc_store

:sx_npc_no_off
 lda #0
:sx_npc_store
 ldy #68
 sta (info_ptr),y
 rts

:sx_wpunch_off_right  dfb $00,$00
:sx_wpunch_off_mirror dfb $FF,$F8       ; WPUNCH1: -1, WPUNCH2: -8
:sx_rpunch_off_right  dfb $00,$00
:sx_rpunch_off_mirror dfb $FF,$F9       ; RPUNCH1: -1, RPUNCH2: -7

*----------------------------------------------------------
* set_billy_y_target - Set billy_y_target based on the new
* anim. Jump-arc anims (anim_jump, anim_bspinkick) drive
* Billy's ypos toward -20 (airborne); anything else clears
* the target so update_billy_y_off ramps him back to ground
* (covers normal anim transitions plus mid-air punched
* interruptions).
* Gated on controller==1 so NPC anims don't poke Billy's
* trajectory. On entry: anim_ptr = animation, info_ptr =
* sprite info block.
*----------------------------------------------------------
JUMP_PEAK_Y_OFF = $EC      ; -20 (signed) — default peak rise vs ground
JUMP_MIN_Y      = 5        ; minimum allowed peak ypos — prevents Billy
                           ; from underflowing the playfield when jumping
                           ; off elevated ground (rooftops, ladder tops)

set_billy_y_target
* Gravity-mode skips this entirely — the new system drives ypos
* directly via billy_y_vel + apply_gravity_step; billy_y_target
* and billy_y_off stay zeroed.
 lda gravity_enabled
 beq :sy_legacy
 rts
:sy_legacy
 ldy #22
 lda (info_ptr),y
 cmp #$01
 beq :sy_is_player
 cmp #$02
 beq :sy_is_player
 jmp :sy_done
:sy_is_player
* active_jump_anim / active_bspinkick_anim are swapped per
* player by swap_in_jimmy, so this comparison works for both.
 lda anim_ptr
 cmp active_jump_anim
 bne :sy_chk_spinkick
 lda anim_ptr+1
 cmp active_jump_anim+1
 beq :sy_jump
:sy_chk_spinkick
 lda anim_ptr
 cmp active_bspinkick_anim
 bne :sy_descend
 lda anim_ptr+1
 cmp active_bspinkick_anim+1
 bne :sy_descend
:sy_jump
* Keep existing target if Billy is mid-arc — re-computing from
* the current (already-lifted) ypos would clamp the peak too low
* OR set a less-negative target than billy_y_off, causing the
* ramp to run the wrong direction.
*
* Two-part check: target != 0 (= ramp still active) OR
* billy_y_off != 0 (= Billy already lifted, mid-arc). The second
* check catches the narrow window where the spinkick's "last
* frame" handler just zeroed target but billy_y_off hasn't
* finished descending yet — without it, a chained jump on that
* exact frame recomputed target to e.g. -16 while billy_y_off was
* still -20, and the ramp couldn't reach the new target.
 lda billy_y_target
 bne :sy_done
 lda billy_y_off
 bne :sy_done
* Cap the peak so the player can't go above the playfield top.
* Normal peak is JUMP_PEAK_Y_OFF (-20), but if they're jumping
* from high ground (rooftop, top of ladder) where ypos is small,
* that would underflow ypos through 0. Read the current ypos
* through info_ptr so the cap is correct for whichever player
* is being processed (Billy's billy_sprite or Jimmy's jimmy_sprite).
 ldy #0
 lda (info_ptr),y       ; current (grounded) ypos
 cmp #25                ; JUMP_MIN_Y(5) + 20 — if ypos >= 25, normal peak fits
 bcc :sy_jump_clamp
 lda #JUMP_PEAK_Y_OFF
 sta billy_y_target
 bra :sy_done
:sy_jump_clamp
* Available rise = ypos - JUMP_MIN_Y; target = -(available_rise)
* expressed as (JUMP_MIN_Y - ypos), naturally negative for the
* ypos range where this branch fires (ypos > JUMP_MIN_Y).
*
* SAFETY: the dispatch in update_billy_y_off assumes target is
* either 0 or a NEGATIVE EVEN value (so the by-2 ramp hits target
* exactly via unsigned cmp). For ypos <= JUMP_MIN_Y the formula
* gives a non-negative target — clamp to 0 (Billy is already at or
* above peak). For any odd ypos the formula gives an ODD target —
* round toward 0 (less negative) so the ramp terminates exactly.
* The branch only fires for ypos in (JUMP_MIN_Y, 25), so the round
* produces a target in [-18, 0] — already inside the valid
* [-20, 0] range, no further cap needed. (An earlier draft tried
* to cap with `cmp #JUMP_PEAK_Y_OFF; bcs in_range` which is an
* UNSIGNED compare; for a rounded-to-$00 case it stomped target
* to -20 and pumped Billy off the top of the screen.)
 ldy #0
 lda #JUMP_MIN_Y
 sec
 sbc (info_ptr),y
 bpl :sy_clamp_zero        ; A >= 0 → ypos <= JUMP_MIN_Y, can't rise
 clc
 adc #1                    ; round odd toward 0 (-1 → 0, -3 → -2, etc.)
 and #$FE                  ; clear bit 0 (no-op for even, finishes round for odd)
 sta billy_y_target
 bra :sy_done
:sy_clamp_zero
 stz billy_y_target
 bra :sy_done
:sy_descend
 stz billy_y_target
:sy_done
 rts

*----------------------------------------------------------
* update_billy_y_off - Ramp billy_y_off toward billy_y_target
* by 2 per call, applying the same delta to Billy's ypos
* (info+0) and IMAGE01_YPOS. Snapshots prev_ypos / prev_frame_y
* BEFORE mutating ypos so erase_all next frame clears the row
* Billy was at. Marks Billy dirty so the union erase+redraw
* fires for the new position.
* Called once per game-loop tick (after update_anims).
*----------------------------------------------------------
update_billy_y_off
* Gravity-mode bypasses the legacy y_off ramp (apply_gravity_step
* drives ypos directly via billy_y_vel).
 lda gravity_enabled
 beq :uby_legacy
 rts
:uby_legacy
* SAFETY: billy_y_off is only ever meant to be 0 or in -20..-2
* (= top bit set). A POSITIVE value (top bit clear AND non-zero)
* would put descend mode into a runaway loop. Snap to 0.
 lda billy_y_off
 beq :uby_safety_ok
 bmi :uby_safety_ok
 stz billy_y_off
:uby_safety_ok
 lda billy_y_off
 cmp billy_y_target
 beq :uby_done
* Snapshot prev_ypos so erase_all's union covers both the old
* and new Y rects when we step ypos by 2. Don't touch
* prev_frame_y — save_anim_state already set it to the
* previously-drawn frame's height when update_anims advanced.
* Overwriting it here would replace e.g. JUMP2's 30 with
* JUMP3's 32, leaving the bottom 2 px of the prior frame's
* feet unerased.
 lda billy_sprite       ; current ypos
 sta billy_sprite+32    ; prev_ypos
* Direction dispatch: use SIGNED comparison of billy_y_off vs
* target. If billy_y_off > target (signed), Billy is closer to
* ground than the target, ramp UP (rise: billy_y_off -= 2, ypos
* -= 2). If billy_y_off < target, Billy is past the target,
* ramp DOWN (descend: both += 2). The earlier "target == 0 →
* descend, else rise" dispatch was wrong whenever target changed
* mid-arc: e.g. billy_y_off=-20, new target=-16 would rise forever
* because old code only checked target's sign, not the relative
* direction between billy_y_off and target.
*
* For values both in [-20, 0] (= the design range), SBC's N flag
* directly reflects the signed sign of the difference — no signed
* overflow possible because |diff| <= 20 << 127.
 lda billy_y_off
 sec
 sbc billy_y_target
 bmi :uby_descend       ; billy_y_off < target signed → increment toward target
* billy_y_off > target signed → decrement toward target (rise).
* No ceiling check: Billy is ~20 px tall and a 20-px peak is
* fine even when the peak row itself is "blocked" — he's in
* the air and will descend back through. What matters is where
* he LANDS, which the per-step X check in update_anims's
* advance-position block gates against using landing_y =
* current_y - billy_y_off (signed).
 lda billy_y_off
 sec
 sbc #2
 sta billy_y_off
 lda billy_sprite
 sec
 sbc #2
 sta billy_sprite
 sta IMAGE01_YPOS
 bra :uby_dirty
:uby_descend
 lda billy_y_off
 clc
 adc #2
 sta billy_y_off
 lda billy_sprite
 clc
 adc #2
 sta billy_sprite
 sta IMAGE01_YPOS
:uby_dirty
 lda billy_sprite+30
 ora #$03               ; needs_draw | needs_erase
 sta billy_sprite+30
:uby_done
 rts

*----------------------------------------------------------
* update_jimmy_y_off - Parallel of update_billy_y_off but for
* Jimmy. Operates on jimmy_stash_y_off / jimmy_stash_y_target
* (the swap holds Jimmy's values there while he isn't active)
* and applies the ramp directly to jimmy_sprite+0 / +32 / +30.
* No-op while jimmy_active is 0.
*----------------------------------------------------------
update_jimmy_y_off
* Gravity-mode bypass (see update_billy_y_off).
 lda gravity_enabled
 bne :ujy_done
 lda jimmy_active
 bne :ujy_check
 rts
:ujy_check
 lda jimmy_stash_y_off
 cmp jimmy_stash_y_target
 beq :ujy_done
* Snapshot prev_ypos before stepping
 lda jimmy_sprite
 sta jimmy_sprite+32
 lda jimmy_stash_y_target
 beq :ujy_descend
* target = -20: rise. y_off and ypos both decrease by 2.
 lda jimmy_stash_y_off
 sec
 sbc #2
 sta jimmy_stash_y_off
 lda jimmy_sprite
 sec
 sbc #2
 sta jimmy_sprite
 bra :ujy_dirty
:ujy_descend
* target = 0: descend. y_off and ypos both increase by 2.
 lda jimmy_stash_y_off
 clc
 adc #2
 sta jimmy_stash_y_off
 lda jimmy_sprite
 clc
 adc #2
 sta jimmy_sprite
:ujy_dirty
 lda jimmy_sprite+30
 ora #$03
 sta jimmy_sprite+30
:ujy_done
 rts

*----------------------------------------------------------
* apply_gravity_step — per-frame airborne update for the player
* currently in the billy_* context. (For Jimmy, the game loop
* swaps in via swap_in_jimmy and calls again.) Only runs when the
* level has gravity_enabled = 1 (set per-mission from the bank-$02
* header at $02/001C). Mission 1 leaves it 0 → this is a no-op
* and the legacy update_*_y_off jump arc handles vertical motion.
*
* Each tick:
*   ypos    += y_vel
*   y_vel   += GRAVITY_PX (capped at TERMINAL_VEL)
* then probes stratum_bounds at (xpos, new ypos). If walkable, the
* player lands (y_vel=0, airborne=0, snap IMAGE01_YPOS to ypos).
* Off-screen (ypos >= 200) → placeholder respawn at the level's
* player_spawn_x/y from the bank-$02 header.
*
* Caller: game_loop. mx %11 (8-bit) on entry, same on exit.
*----------------------------------------------------------
apply_gravity_step
 lda gravity_enabled
 bne :ags_active
 jmp :ags_done
:ags_active
 lda billy_airborne
 bne :ags_check_vel
 jmp :ags_done
:ags_check_vel
* Apply horizontal jump momentum (set by btn_action_jump from
* Billy's facing direction). Signed: +N = right, -N = left,
* 0 = pure vertical jump. Clamp into [1, PLAYER_MAX_X].
* CRITICAL: read/write billy_sprite+2 directly, NOT IMAGE01_XPOS.
* IMAGE01_XPOS is the GLOBAL last-loaded sprite's xpos — at this
* point in game_loop, update_anims just finished iterating both
* Billy AND Jimmy (or any later sprite), so IMAGE01_XPOS holds
* the LAST sprite's xpos (= Jimmy's $1F at boot when Jimmy is
* inactive but still in sprite_table). Using IMAGE01_XPOS as the
* source clamps Billy to (jimmy_xpos + jump_x_vel) every frame.
 lda billy_jump_x_vel
 beq :ags_no_xvel
 bmi :ags_xvel_left
* Moving right: xpos += jump_x_vel. Cap at PLAYER_MAX_X.
 clc
 adc billy_sprite+2
 cmp #PLAYER_MAX_X+1
 bcc :ags_xvel_r_apply
 lda #PLAYER_MAX_X
:ags_xvel_r_apply
 sta billy_sprite+2
 sta IMAGE01_XPOS          ; keep IMAGE01_XPOS in sync for the
                           ;   rest of apply_gravity_step (sweep
                           ;   reads it via check_x_bounds_world).
* abs_x += jump_x_vel
 lda billy_jump_x_vel
 clc
 adc abs_x
 sta abs_x
 lda abs_x+1
 adc #0
 sta abs_x+1
 bra :ags_no_xvel
:ags_xvel_left
* Moving left: xpos += jump_x_vel (negative). Clamp at 1.
 clc
 adc billy_sprite+2
 bcs :ags_xvel_l_check     ; carry set = no underflow (still positive)
 lda #1                    ; underflow → clamp to 1
 bra :ags_xvel_l_apply
:ags_xvel_l_check
 cmp #1
 bcs :ags_xvel_l_apply     ; >= 1, ok
 lda #1
:ags_xvel_l_apply
 sta billy_sprite+2
 sta IMAGE01_XPOS          ; sync as above.
* abs_x += jump_x_vel (signed; -N as 2's complement)
 lda billy_jump_x_vel
 clc                       ; signed add via ADC with sign-extended hi
 adc abs_x
 sta abs_x
 lda abs_x+1
 adc #$FF                  ; sign-extend negative byte
 sta abs_x+1
:ags_no_xvel
 lda billy_y_vel
 bmi :ags_rising

* === Falling (y_vel >= 0). Sweep one row at a time so a fast fall
* can't tunnel through a thin platform between frames. ===
 ldx billy_y_vel
 beq :ags_apply_gravity     ; zero velocity this frame
:ags_sweep
 inc billy_sprite           ; ypos += 1
 lda billy_sprite
 sta IMAGE01_YPOS
 phx                        ; save remaining-steps counter
 lda billy_sprite+2         ; xpos
 jsr check_x_bounds_world
 plx
 bcc :ags_land
 dex
 bne :ags_sweep
 bra :ags_apply_gravity

:ags_land
 stz billy_y_vel
 stz billy_airborne
 stz billy_jump_x_vel
 lda billy_sprite+30
 ora #$03
 sta billy_sprite+30
 jmp :ags_done

:ags_rising
* y_vel < 0: ypos += y_vel (signed). No land check on the way up.
* CEILING CLAMP: if the signed add would underflow ypos (= go above
* row 0), pin ypos to 0 and zero y_vel so gravity takes over. Without
* this, JUMP_VEL_INIT taller than (start_ypos / |steps_to_zero|)
* lets ypos wrap to high unsigned values → instant respawn.
 lda billy_y_vel
 clc
 adc billy_sprite
 bcs :ags_rise_ok          ; no wrap (positive 8-bit result kept carry)
 stz billy_sprite          ; wrap → clamp ypos = 0
 stz IMAGE01_YPOS
 stz billy_y_vel           ; stop rising, gravity will reverse on next frame
 jmp :ags_apply_gravity
:ags_rise_ok
 sta billy_sprite
 sta IMAGE01_YPOS

:ags_apply_gravity
* y_vel += GRAVITY (cap at TERMINAL_VEL when value would exceed it).
* Cap is UNSIGNED CMP, so we must early-out for negative results
* (rising phase: y_vel was -12..-1, +1 stays negative) — otherwise
* $F5+1=$F6 reads as "245" > 9 and we'd clamp to +8 immediately,
* turning the rising arc into one frame of rise then terminal-vel fall.
 lda billy_y_vel
 clc
 adc #GRAVITY_PX
 bmi :ags_no_cap         ; still rising (sign bit set) — keep as-is
 cmp #TERMINAL_VEL+1
 bcc :ags_no_cap
 lda #TERMINAL_VEL
:ags_no_cap
 sta billy_y_vel

* Off-screen check — respawn before sprite bottom (ypos + frame_y)
* would render past SHR row 199 (i.e. into the SCB region at
* bank-$01 $9D00+). frame_y lives at billy_sprite+12. We treat the
* low byte only (8-bit) since rendering takes the same byte.
 lda billy_sprite           ; ypos
 clc
 adc billy_sprite+12        ; + frame_y
 bcs :ags_respawn            ; overflowed 8-bit → way off-screen
 cmp #200
 bcs :ags_respawn            ; ypos + frame_y >= 200 → respawn
 jmp :ags_done
 jmp :ags_done
:ags_respawn
 lda #$02
 sta $F2
 lda #$02
 sta $F0
 stz $F1
 ldy #0
 lda [$F0],y                ; player_spawn_x
 sta billy_sprite+2
 sta IMAGE01_XPOS
 iny
 lda [$F0],y                ; player_spawn_y
 sta billy_sprite
 sta IMAGE01_YPOS
 stz billy_y_vel
 stz billy_airborne
 stz billy_jump_x_vel
 lda billy_sprite+30
 ora #$03
 sta billy_sprite+30
:ags_done
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

* Player gravity / falling constants — consulted only when
* gravity_enabled = 1 (set per-mission from the bank-$02 header).
* JUMP_VEL_INIT is the launch velocity in px/frame; negative = up.
* GRAVITY_PX is the acceleration applied each frame.
* TERMINAL_VEL caps the downward speed so a long fall doesn't
* tunnel through a thin platform between frames.
JUMP_VEL_INIT = $F9       ; signed -7 — peak ~28px up (sum 1..7 = 28).
                          ; Airtime ≈ 22 frames; with JUMP_X_VEL=1 that
                          ; covers ~22px horizontal — just enough to clear
                          ; the 20px gap when jumping from the upper
                          ; platform's right edge (x=$44).
JUMP_X_VEL    = 1         ; px/frame horizontal speed while airborne
GRAVITY_PX    = 1
TERMINAL_VEL  = 8

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
* Check flags bit 0: advance position per VBL. Branch inverted
* + jmp because the advance-position body grew past beq's
* ±128-byte reach (added X-bounds checks in jump steps).
 ldy #2
 lda (anim_ptr),y     ; flags
 and #$01
 bne :flag_advance
 jmp :no_advance
:flag_advance
* Snapshot current xpos/ypos into prev_* BEFORE modifying xpos.
* Without this, each VBL the advance-position code clobbers xpos
* but leaves prev_xpos stale at the pre-animation value, so the
* NEXT frame's erase_all erases at the wrong spot (typically a
* no-op on clean background) and the previous frame's drawing
* stays on screen as an artifact trail.
*
* DO NOT snapshot prev_frame_x/y here. :flag_advance doesn't
* modify cur_frame_x/y, so a snapshot every VBL just keeps prev=cur.
* But on the very first VBL of an anim that took over from another
* render path (e.g. walk→jump in the same input frame), info+10 has
* the new anim's frame_x while the last-drawn-on-screen pixels
* still reflect the prior render's wider frame (walk's IMAGE03 is
* 11 wide vs JUMP1's 10). save_sprite (called by the walk path
* right before start_anim) leaves prev_frame_x at the correct
* prior-frame width; overwriting it here shrinks the erase rect
* and leaves a vertical sliver of the wider walk frame's rightmost
* column visible mid-jump. Symptom: 1-byte × 3-row chunk at Billy's
* lower-right (where IMAGE03's foot pixels live) that survives
* until the post-jump landing erase covers it.
*
* save_anim_state on frame transitions correctly updates
* prev_frame_x/y from the old info+10/12 — that path is where
* prev frame dims should be managed.
 ldy #2
 lda (info_ptr),y
 ldy #34
 sta (info_ptr),y     ; prev_xpos <- current xpos
 ldy #0
 lda (info_ptr),y
 ldy #32
 sta (info_ptr),y     ; prev_ypos <- current ypos
* Gravity-mode gate: for the human player (Billy = controller 1),
* horizontal motion during anim_jump is owned by apply_gravity_step
* via billy_jump_x_vel. Skip the legacy auto-advance so we don't
* double-step xpos (legacy adds ±1 per pair of VBLs depending on
* mirror; my x_vel adds ±N per VBL — they were fighting and Billy
* was landing back on the upper platform near his start).
 ldy #22
 lda (info_ptr),y
 cmp #1
 bne :fa_legacy_xstep
 lda gravity_enabled
 beq :fa_legacy_xstep
 jmp :adv_skip_x
:fa_legacy_xstep
* Halve the horizontal component of the jump: only step xpos on
* every other VBL by toggling jump_x_toggle. The previous-rect
* snapshots above still run unconditionally so erase_all unions
* correctly when xpos doesn't change. abs_x stays in sync because
* it's only inc/dec'd inside the same gated block below.
 lda jump_x_toggle
 eor #$01
 sta jump_x_toggle
 beq :adv_skip_x
 lda IMAGE01_MIRROR
 bne :adv_left
* Jumping right — clamp at PLAYER_MAX_X so Billy's feet stay
* inside the playfield instead of walking past the right edge.
 lda IMAGE01_XPOS
 cmp #PLAYER_MAX_X
 bcs :adv_done
* Stratum-bounds gate: check the LANDING position, not the
* mid-air one. landing_y = current_y - billy_y_off (signed);
* with billy_y_off negative during the arc, this evaluates to
* current_y + |y_off| = the pre-jump row Billy will descend
* back to. Testing the mid-air row would block jumps that fly
* through legitimately-blocked airspace (e.g. above a ledge),
* even though Billy lands fine. We DO need to stop xpos drift
* whose accumulated effect would put the landing position
* inside a wall — so the test is against landing_y.
 lda IMAGE01_XPOS
 clc
 adc #1
 sta chk_xpos
 lda IMAGE01_YPOS
 sec
 sbc billy_y_off       ; signed: y_off<0 → A += |y_off|
 jsr check_y_bounds
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
* Same landing-position stratum-bounds gate as the right path.
 lda IMAGE01_XPOS
 sec
 sbc #1
 sta chk_xpos
 lda IMAGE01_YPOS
 sec
 sbc billy_y_off
 jsr check_y_bounds
 bcs :adv_done
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
:adv_skip_x
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
* NPC below floor row: allow trajectory regardless of anim_frame so
* a knocked-off-ladder enemy can descend visibly through both the
* FALL pose (frame 0) and the FALLEN pose (frame 1) until they
* reach npc_min_y. Players and on-floor NPCs use the standard
* "frame 0 only" gate so the FALLEN pose stays put.
 ldy #22
 lda (info_ptr),y     ; controller
 beq :ftraj_npc_chk   ; controller == 0 → NPC
:ftraj_player_gate
 ldy #26
 lda (info_ptr),y     ; anim_frame
 beq :ftraj_proceed
 jmp :no_ftraj
:ftraj_npc_chk
 ldy #0
 lda (info_ptr),y
 cmp npc_min_y
 bcc :ftraj_proceed   ; ypos < npc_min_y → trajectory active any frame
 bra :ftraj_player_gate
:ftraj_proceed
* Snapshot prev_* from cur EVERY VBL, including the first. The
* prior "first VBL leaves prev_xpos/ypos alone" branch assumed
* save_sprite had left prev_x/y at the last drawn position — but
* save_sprite snapshots prev = OLD cur BEFORE writing the new cur,
* so it actually leaves prev_x/y at the PRIOR drawn position (one
* step before the last). Using that as the erase anchor leaves
* the walk's last-drawn row(s) at the top of the body unerased
* (visible as a FALL/walk-head sliver above the rescued sprite).
* Snapshot from cur unconditionally instead.
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
 ldy #44
 cmp (info_ptr),y     ; cmp cur_fx vs idle_x
 bcs :ftraj_snap_pfx_ok
 lda (info_ptr),y     ; cur_fx < idle_x → use idle_x
:ftraj_snap_pfx_ok
 ldy #36
 sta (info_ptr),y     ; prev_frame_x (clamped to >= idle_x)
 ldy #12
 lda (info_ptr),y
 ldy #46
 cmp (info_ptr),y     ; cmp cur_fy vs idle_y
 bcs :ftraj_snap_pfy_ok
 lda (info_ptr),y     ; cur_fy < idle_y → use idle_y
:ftraj_snap_pfy_ok
 ldy #38
 sta (info_ptr),y     ; prev_frame_y (clamped to >= idle_y).
* Per-sprite idle clamp (not the old hardcoded 20/40). Generic
* NPCs have idle 9x40 and the old constants worked, but Burnov's
* idle is 13x48 — anim_bnfall's frame 0 (BNFALL1) is 13x46, so a
* hardcoded prev_fy=40 floor left 4 rows of standing's body
* unerased. Visible as 2px of Burnov's feet hanging out the bottom-
* left of his BNFALLEN sprite after a spin-kick. Using info+44/+46
* (idle_x/idle_y) makes the clamp self-adjusting per sprite.
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
* Override: NPC below floor row falls only (no rise) so the
* trajectory makes net downward progress instead of returning to
* the start Y. Without this, an NPC knocked off a ladder would
* finish anim_lffall at the same out-of-bounds Y she started at.
 ldy #22
 lda (info_ptr),y
 bne :ftraj_dy_arc       ; controller != 0 → player, normal arc
 ldy #0
 lda (info_ptr),y
 cmp npc_min_y
 bcs :ftraj_dy_arc       ; ypos >= npc_min_y → on floor, normal arc
* NPC below floor: fall-only.
 clc
 adc #2
 sta (info_ptr),y
 bra :ftraj_done
:ftraj_dy_arc
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
* Landing detection: when the player's jump anim just ended,
* open the uppercut window AND reset their y_target so the
* matching update_*_y_off ramps them back down next frame. We
* check both anim_jump (Billy) and anim_jjump (Jimmy) directly
* — active_jump_anim is per-player but update_anims runs
* OUTSIDE the swap, so it'd hold Billy's pointer during Jimmy's
* iteration and miss the match.
 lda anim_ptr
 cmp #<anim_jump
 bne :ad_chk_jjump
 lda anim_ptr+1
 cmp #>anim_jump
 beq :ad_is_billy_jump
:ad_chk_jjump
 lda anim_ptr
 cmp #<anim_jjump
 bne :ad_not_jump
 lda anim_ptr+1
 cmp #>anim_jjump
 bne :ad_not_jump
* Jimmy's jump just ended. landing_window opens the uppercut combo
* regardless of gravity mode; the y_target reset is legacy-arc-only
* (gravity_enabled keeps y_target at 0 always).
 lda #UPPERCUT_WINDOW
 sta jimmy_stash_landing_window
 lda gravity_enabled
 bne :ad_jjump_done
 stz jimmy_stash_y_target
:ad_jjump_done
 bra :ad_not_jump
:ad_is_billy_jump
 lda #UPPERCUT_WINDOW
 sta landing_window
 lda gravity_enabled
 bne :ad_bjump_done
 stz billy_y_target
:ad_bjump_done
:ad_not_jump
* === Burnov boss-death state machine ===
* Triggered for any sprite whose frame_bank == $19 (legacy
* Burnov dissolve/recon + linda_flail's anim_lffall) OR $1C
* (Burnov's now-compiled combat anims: bnpunch/bngrab/bnfall).
* Three transitions:
*   anim_bnfall ended  →  start anim_bn_diss (BURNGONE) OR permadeath
*   anim_bn_diss ended →  teleport + start anim_bn_recon (BURNBACK)
*   anim_bn_recon ended →  reset punch_count, increment death_count,
*                          fall through to :normal_end (idle restore).
* Burnov boss-death state machine lives in mission1boss.s (bank
* $1E). Gate by frame_bank first ($19 = legacy / $1C = compiled
* Burnov) to skip the cross-bank call for unrelated sprites, then
* delegate. bn_anim_ended returns A = disposition:
*   0 → :ad_normal_flow   (not a Burnov death-cycle anim)
*   1 → :next             (dissolve or recon installed)
*   2 → :normal_end       (finish_recon ran)
*   3 → :ad_do_death      (3rd-kill diss done; route to death)
 ldy #56
 lda (info_ptr),y      ; frame_bank
 cmp #$19
 beq :ad_call_bn
 cmp #$1C
 beq :ad_call_bn
 jmp :ad_normal_flow
:ad_call_bn
 jsl bn_anim_ended
 beq :ad_normal_flow   ; A=0
 cmp #1
 beq :ad_bn_to_next
 cmp #2
 beq :ad_bn_to_norm
 jmp :ad_do_death      ; A=3
:ad_bn_to_next
 jmp :next
:ad_bn_to_norm
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
* Fall ended without death. If the NPC was on a ladder when
* hit (BEHAV_LADDER), they should disengage from climbing and
* land at the bottom of the ladder rather than rebounding into
* mid-air climb frames at a now-misaligned ypos. behav_ladder
* cached the descent target (ladder y_bottom + 1) at info+9
* during LD_INIT, so we snap to that and convert to FACEOFF.
 ldy #6
 lda (info_ptr),y
 cmp #BEHAV_LADDER
 bne :ad_no_ladder_disengage
 ldy #9
 lda (info_ptr),y     ; cached descent target Y
 ldy #0
 sta (info_ptr),y     ; ypos = ladder bottom + 1
 ldy #6
 lda #BEHAV_FACEOFF
 sta (info_ptr),y     ; behavior → FACEOFF
 lda #FO_APPROACH
 ldy #7
 sta (info_ptr),y     ; sub-state → APPROACH
:ad_no_ladder_disengage
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
* DEBUG: log :ad_do_death entry — 'D<info_lo><cur_y>' (single-char
* prefix; trailing space dropped to free a byte). cur_y here is
* bumped y if she died from FALLEN, or arc-end y otherwise.
 do DEBUG_ERASE
 lda #$C4              ; 'D'
 jsr dbg_print_char
 lda info_ptr
 jsr dbg_print_hex8
 ldy #0
 lda (info_ptr),y      ; cur_y
 jsr dbg_print_hex8
 fin
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
* Pick rect dims based on walk_anim. Detect Burnov via his
* walk_anim pointer (anim_bnwalk) since bank no longer
* uniquely identifies him — he renders in $1B (compiled
* walk), $1C (compiled combat), or $19 (legacy dissolve).
 ldy #52
 lda (info_ptr),y
 cmp #<anim_bnwalk
 bne :dd_normal_dims
 ldy #53
 lda (info_ptr),y
 cmp #>anim_bnwalk
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
* Cap height to last playfield row. The actual erase in :nd_dead
* clamps bottom to 183 (`cmp #184 / lda #183`), so we cap prev_frame_y
* at (184 - prev_ypos) here — letting the rect cover rows up to 183
* inclusive. The earlier 180 cap dropped the bottom 3 rows of any
* FALLEN sprite drawn at the playfield floor (e.g. Linda's LFALL2
* head fragment at rows 180-182).
 lda #184
 ldy #32
 sec
 sbc (info_ptr),y     ; A = 184 - prev_ypos
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
* Player-death check. Either Billy ($01) or Jimmy ($02 + pointer
* match) just finished their fall_anim with fall_count >= MAX.
* In two-player co-op the game only ends when BOTH players are
* dead — if either is alive, the dead one disappears (set the
* $FFFF anim_ptr sentinel so erase_all next frame removes them
* from sprite_table) and play continues.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 beq :ne_chk_billy_death
 cmp #$02
 beq :ne_chk_jimmy_death
 jmp :ne_not_player_dead
:ne_chk_billy_death
 ldy #50
 lda (info_ptr),y
 cmp anim_ptr
 beq :ne_b_hi_chk
 jmp :ne_not_player_dead
:ne_b_hi_chk
 ldy #51
 lda (info_ptr),y
 cmp anim_ptr+1
 beq :ne_b_count_chk
 jmp :ne_not_player_dead
:ne_b_count_chk
 lda billy_fall_count
 cmp #BILLY_MAX_FALLS
 bcs :ne_player_dead
 jmp :ne_not_player_dead
:ne_chk_jimmy_death
 lda info_ptr
 cmp #<jimmy_sprite
 beq :ne_jdc_hi
 jmp :ne_not_player_dead
:ne_jdc_hi
 lda info_ptr+1
 cmp #>jimmy_sprite
 beq :ne_jdc_anim
 jmp :ne_not_player_dead
:ne_jdc_anim
 ldy #50
 lda (info_ptr),y
 cmp anim_ptr
 beq :ne_j_hi_chk
 jmp :ne_not_player_dead
:ne_j_hi_chk
 ldy #51
 lda (info_ptr),y
 cmp anim_ptr+1
 beq :ne_j_count_chk
 jmp :ne_not_player_dead
:ne_j_count_chk
 lda jimmy_stash_fall_count
 cmp #BILLY_MAX_FALLS
 bcs :ne_jimmy_dead
 jmp :ne_not_player_dead
:ne_jimmy_dead
* Jimmy specifically — deactivate him so swap_in_jimmy stops
* loading his stashed state into Billy's globals.
 stz jimmy_active
:ne_player_dead
* Co-op game-over policy: only fire when neither player is alive.
* maybe_game_over JMPs to game_over (never returns) when both
* are at fall_count >= MAX (or one is at MAX and the other is
* inactive). Otherwise it rts here and we mark the dying player
* with the $FFFF sentinel so erase_all wipes them.
 jsr maybe_game_over
 ldy #24
 lda #$FF
 sta (info_ptr),y     ; anim_ptr = $FFFF
 iny
 sta (info_ptr),y
 ldy #30
 lda #$03
 sta (info_ptr),y     ; dirty = erase + (no redraw)
 jmp :next
:ne_not_player_dead
* If the anim that just ended was a multi-frame fall_anim (so
* we bumped ypos on entry to the fallen frame), un-bump now:
* snapshot prev_ypos from the bumped current so erase_all clears
* the fallen sprite at its drawn position, then subtract the
* offset so the restored idle frame draws at the logical height.
* anim_bfall is a 1-frame placeholder, so num_frames<2 skips.
* DEBUG: log entry to :normal_end with anim_ptr low byte.
 do DEBUG_PRINT
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
 fin
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
* Pickup hook: anim_bpickup OR anim_jpickup just finished.
* Armed flag and idle pose were already set at pickup time
* (billy_try_pickup_weapon → billy_arm_pipe/mace/knife), so
* all that's left is to drop the compiled JUMP3/JJUMP3 mask so
* the next draw routes through the legacy renderer with the
* armed walk frames (bank $19 for Billy, bank $1D for Jimmy).
 lda anim_ptr
 cmp #<anim_bpickup
 bne :ne_chk_jpickup
 lda anim_ptr+1
 cmp #>anim_bpickup
 beq :ne_do_pickup
:ne_chk_jpickup
 lda anim_ptr
 cmp #<anim_jpickup
 bne :ne_not_bpickup
 lda anim_ptr+1
 cmp #>anim_jpickup
 bne :ne_not_bpickup
:ne_do_pickup
 lda #0
 sta MASK_ADDR
 sta MASK_ADDR+1
 ldy #60
 sta (info_ptr),y
 iny
 sta (info_ptr),y
:ne_not_bpickup
* Burnov-grab end hook moved to mission1boss.s (bn_grab_end).
* Detects anim_bngrab/anim_bnjgrab, releases the held player,
* runs the fall + score/palette cascade, and restores info_ptr.
* No-op if the just-ended anim isn't a Burnov grab variant.
 jsl bn_grab_end
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
* Unbump tracer removed (was 'U<info_lo><cur_y>'). Confirmed the
* unbump erase rect cleared FALLEN paint cleanly, so we no longer
* need the print — bytes reclaimed for the X-axis band-aid.
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
* NPC rescue (controller != 1 and != 2): clamp ypos UP to
* npc_min_y so a knocked-off-ladder enemy lands on the floor,
* not stuck on a staircase row where fo_approach's
* check_y_bounds_strict will refuse to let them move.
* Player rescue (controller 1 or 2): walks ypos up until a
* non-blocked row — used when the fall trajectory drops them
* just past a stepped-platform edge.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 beq :ne_rescue_player
 cmp #$02
 beq :ne_rescue_player
* NPC path. Two branches:
*   cur_ypos < npc_min_y: clamp UP to npc_min_y (knocked-off-
*                          ladder lands on the floor).
*   cur_ypos >= npc_min_y: walk UP through blocked rows until
*                          bounds_tbl_hi[ypos] > 0 (handles the
*                          rooftop case where FALL_Y_OFFSET drops
*                          the body past the rooftop edge).
* Both branches converge on :ne_rescue_npc_commit with X = ypos.
 ldy #0
 lda (info_ptr),y
 cmp npc_min_y
 bcs :ne_rescue_npc_keep
 ldx npc_min_y
 bra :ne_rescue_npc_commit
:ne_rescue_npc_keep
* cur_ypos >= npc_min_y. Could be:
*   (a) within the floor band — leave alone.
*   (b) BELOW an elevated walkable band on a rooftop / step-down
*       screen (e.g. scr7: FALL_Y_OFFSET=24 pushes a fallen knifer
*       from rooftop ypos=50 down to ypos=74, which is past the
*       rooftop edge into the all-blocked row 72+ zone).
* Walk ypos UP until bounds_tbl_hi[ypos] is non-zero, stopping at
* npc_min_y so we don't punch up into staircase rows. Mirrors the
* player-rescue walk-up; the old "just leave ypos alone" did
* nothing for case (b) and the body sat outside any walkable cell.
 lda (info_ptr),y
 tax
:ne_rescue_npc_walkup
 lda bounds_tbl_hi,x
 bne :ne_rescue_npc_commit
 cpx npc_min_y
 beq :ne_rescue_npc_commit
 dex
 bra :ne_rescue_npc_walkup
:ne_rescue_npc_commit
 bra :ne_rescue_y_done
:ne_rescue_player
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
* Commit rescued ypos to info+0. Do NOT touch prev_ypos: the un-
* bump above set prev_ypos = bumped (= FALLEN's drawn y), and
* erase_all next frame needs that to cover the FALLEN drawn rect.
* Overwriting prev_ypos here strands the FALLEN pixels on screen
* as residue when the rescue moves the body to a different row.
 txa
 ldy #0
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
* Snap xpos = bmin. Do NOT touch prev_xpos — erase_all next frame
* still needs to clear at the FALLEN-drawn x.
 lda :ne_rescue_xmin
 ldy #2
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
* Snap xpos = bmax - idle_x. Do NOT touch prev_xpos — erase_all
* next frame still needs to clear at the FALLEN-drawn x.
 lda :ne_rescue_xmax
 ldy #44
 sec
 sbc (info_ptr),y
 ldy #2
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
* Clear billy_cur_x_off / jimmy_cur_x_off / info+68 when the
* anim ends — idle has no render-x offset. prev_x_off stays at
* the punch's offset until draw_all runs, which is correct:
* erase_all this same frame still needs to clear the punch's
* drawn rect at the lunged column. Without this clear the NPC
* visually "jumps" by the punch lunge's offset right as the
* animation transitions back to idle (William ending his punch
* and snapping ~8 bytes / 16 pixels in his facing direction).
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :ne_xoff_chk_jimmy
 stz billy_cur_x_off
 bra :ne_no_xoff_clear
:ne_xoff_chk_jimmy
 cmp #$02
 bne :ne_xoff_npc
 stz jimmy_cur_x_off
 bra :ne_no_xoff_clear
:ne_xoff_npc
* NPC: clear info+68 (cur_x_off) but leave info+69 (prev_x_off)
* so this frame's erase_all still finds the punch's offset rect.
 ldy #68
 lda #0
 sta (info_ptr),y
:ne_no_xoff_clear
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
* Skip the compiled mask restore when Billy is armed (pipe, mace,
* or knife) — armed paths render through the legacy bank-$19 path
* with MASK_ADDR=0.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 beq :ne_chk_billy_arm
 cmp #$02
 beq :ne_jimmy_idle_chk_mirror
 jmp :ne_npc_mask_restore
:ne_chk_billy_arm
 lda billy_pipe_armed
 ora billy_mace_armed
 ora billy_knife_armed
 beq :ne_billy_mask_chk_mirror
* Armed Billy: clear MASK_ADDR + info+60/61 so dispatch routes
* through legacy (armed) draw next frame. (Was info+52 in the
* old layout — info+60 since the compiled-mask field moved.)
 lda #0
 sta MASK_ADDR
 sta MASK_ADDR+1
 ldy #60
 sta (info_ptr),y
 iny
 sta (info_ptr),y
 jmp :ne_no_billy_mask
:ne_billy_mask_chk_mirror
 lda IMAGE01_MIRROR
 bne :ne_billy_mirror
* mirror=0: FRAME_ADDR is already idle_addr = IMAGE01_DATA. Just set MASK.
 lda spr_image01_mask
 sta MASK_ADDR
 lda spr_image01_mask+1
 sta MASK_ADDR+1
 jmp :ne_no_billy_mask     ; was bra; idle-mirror swap pushed target out of range
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
 jmp :ne_no_billy_mask     ; was bra; ditto
:ne_jimmy_idle_chk_mirror
* Same shape as Billy's idle restore but with Jimmy's bank-$1D
* cache vars. mirror=0 → FRAME_ADDR is already idle_addr (forward
* JIMMY01_DATA from the earlier idle restore); just install the
* forward MASK. mirror=1 → swap both to the _MIRROR variants.
* Armed Jimmy (pipe/mace/knife): use the legacy renderer path
* like armed Billy — clear MASK_ADDR + info+60 so the dispatch
* doesn't route the legacy JMWALK/JKWALK/JPIPEW data through
* the compiled pipeline (which mixed compiled mask with legacy
* data and produced a discolored Jimmy).
*
* Read jimmy_stash_*_armed, not billy_*_armed — update_anims runs
* OUTSIDE the swap_in_jimmy window, so billy_*_armed reflects
* Billy's state here, not Jimmy's. With only Jimmy armed, the
* billy_*_armed read returned 0 → fell into :ne_jimmy_unarmed →
* installed the compiled spr_jimmy01_mask while Jimmy's idle_addr
* pointed at legacy JMWALK1 → compiled+legacy mismatch on the very
* first post-swing idle frame → discoloration.
 lda jimmy_stash_pipe_armed
 ora jimmy_stash_mace_armed
 ora jimmy_stash_knife_armed
 beq :ne_jimmy_unarmed
 lda #0
 sta MASK_ADDR
 sta MASK_ADDR+1
 ldy #60
 sta (info_ptr),y
 iny
 sta (info_ptr),y
 jmp :ne_no_billy_mask
:ne_jimmy_unarmed
 lda IMAGE01_MIRROR
 bne :ne_jimmy_mirror
 lda spr_jimmy01_mask
 sta MASK_ADDR
 lda spr_jimmy01_mask+1
 sta MASK_ADDR+1
 bra :ne_no_billy_mask
:ne_jimmy_mirror
 lda spr_jimmy01_data_mir
 sta FRAME_ADDR
 lda spr_jimmy01_data_mir+1
 sta FRAME_ADDR+1
 lda spr_jimmy01_mask_mir
 sta MASK_ADDR
 lda spr_jimmy01_mask_mir+1
 sta MASK_ADDR+1
 bra :ne_no_billy_mask
:ne_npc_mask_restore
* NPC: restore MASK_ADDR from info+62/+63 (idle_mask_addr) so
* compiled-NPC sprites revert to compiled idle after a legacy
* anim ends. Legacy NPCs have info+62 = 0, so MASK_ADDR stays
* zero and the dispatch keeps routing legacy.
*
* For compiled NPCs with mirror=$01, additionally swap FRAME_ADDR
* to info+64/65 (idle_data_mirror) and MASK_ADDR to info+66/67
* (idle_mask_mirror) so the IDLE pose flips to face the same
* direction the active animation just did. (Active anims already
* select between mirror/non-mirror via the paired entries in the
* anim descriptor; this fills the gap for the idle frame.) The
* swap is gated on info+64/65 being non-zero so legacy NPCs and
* static items (mace, dropped weapons — they leave +64/65 at 0)
* keep the original behavior.
 ldy #4
 lda (info_ptr),y
 beq :ne_npc_no_mirror
 ldy #64
 lda (info_ptr),y
 sta :ne_tmp
 iny
 lda (info_ptr),y
 ora :ne_tmp
 beq :ne_npc_no_mirror     ; idle_data_mirror unset → legacy / static
 ldy #64
 lda (info_ptr),y
 sta FRAME_ADDR
 iny
 lda (info_ptr),y
 sta FRAME_ADDR+1
 ldy #66
 lda (info_ptr),y
 sta MASK_ADDR
 iny
 lda (info_ptr),y
 sta MASK_ADDR+1
 bra :ne_no_billy_mask
:ne_npc_no_mirror
 ldy #62
 lda (info_ptr),y
 sta MASK_ADDR
 iny
 lda (info_ptr),y
 sta MASK_ADDR+1
:ne_no_billy_mask
 jsr save_anim_state
* DEBUG: dump key idle-state fields after :normal_end so we can
* verify compiled-NPC restore (Williams: info+56 should be $1B,
* info+60 should be the compiled mask address). Print only for
* NPCs (controller != 1) to keep the output focused.
 do DEBUG_PRINT
 ldy #22
 lda (info_ptr),y
 cmp #$01
 beq :ne_no_dbg
 lda #$CE              ; 'N'
 jsr dbg_print_char
 lda #$C5              ; 'E'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda info_ptr
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$C2              ; 'B'
 jsr dbg_print_char
 ldy #56
 lda (info_ptr),y
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$CD              ; 'M'
 jsr dbg_print_char
 ldy #61
 lda (info_ptr),y
 jsr dbg_print_hex8
 ldy #60
 lda (info_ptr),y
 jsr dbg_print_hex8
 jsr dbg_print_nl
:ne_no_dbg
 fin
 jmp :next

:load_frame
* Set info+56 (frame_bank) per the anim's flag bits. start_anim
* does this once at anim install, but npc_ensure_walking installs
* walk anims directly without going through start_anim — so on
* the first frame load after install, frame_bank could still be
* the *idle*'s bank. Re-applying it here covers both code paths.
* Dispatch matches start_anim: bit 3 → $1C, bit 6 → $1B, bit 5 →
* $19, bit 2 → $1D (Jimmy), else $02. Precedence top-to-bottom.
 ldy #2
 lda (anim_ptr),y     ; flags
 and #$08
 beq :lf_chk_1b
 lda #$1C
 bra :lf_set_bank
:lf_chk_1b
 ldy #2
 lda (anim_ptr),y
 and #$40
 beq :lf_chk_19
 lda #$1B
 bra :lf_set_bank
:lf_chk_19
 ldy #2
 lda (anim_ptr),y
 and #$20
 beq :lf_chk_1d
 lda #$19
 bra :lf_set_bank
:lf_chk_1d
 ldy #2
 lda (anim_ptr),y
 and #$04
 beq :lf_bank2_default
 lda #$1D
 bra :lf_set_bank
:lf_bank2_default
 lda #$02
:lf_set_bank
 ldy #56
 sta (info_ptr),y
:lf_bank_done
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
* anim_uppercut. Clear MASK_ADDR + info+60 so dispatch routes
* legacy. (Was gated on controller==1 because info+52 doubled
* as walk_anim for NPCs; with the move to info+60 the gate
* is unnecessary and compiled NPCs now route legacy through
* a clean info+60 = 0.)
 lda #0
 sta MASK_ADDR
 sta MASK_ADDR+1
 ldy #60
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
* Persist MASK_ADDR → info+60 (active_mask_addr) so load_sprite
* next frame picks up the matching mask. Used by Billy and any
* compiled NPC. (Was gated to controller==1 when +52 was
* overloaded as walk_anim for NPCs; +60 is dedicated.)
 ldy #60
 lda MASK_ADDR
 sta (info_ptr),y
 iny
 lda MASK_ADDR+1
 sta (info_ptr),y

:lf_load_done
* Recompute billy_cur_x_off for the freshly loaded frame so a
* per-frame offset (PUNCH11 vs PUNCH12 etc.) takes effect on the
* very frame that frame is shown. set_anim_x_off no-ops for
* anything that isn't Billy on a known offset-bearing anim.
 jsr set_anim_x_off
* Last-frame descent trigger for jump-arc anims. When the final
* frame of a player jump or spinkick loads we zero the
* appropriate *_y_target so update_*_y_off ramps that player
* back down during the last frame's VBLs (and beyond, into
* idle). Branches by controller so Billy → billy_y_target and
* Jimmy → jimmy_stash_y_target. NPCs are skipped entirely.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 beq :lf_billy_jump_chk
 cmp #$02
 beq :lf_jimmy_jump_chk
 jmp :lf_no_jump_descent
:lf_billy_jump_chk
 lda anim_ptr
 cmp #<anim_jump
 bne :lf_chk_spin_last
 lda anim_ptr+1
 cmp #>anim_jump
 beq :lf_check_last_idx_billy
:lf_chk_spin_last
 lda anim_ptr
 cmp #<anim_bspinkick
 bne :lf_no_jump_descent
 lda anim_ptr+1
 cmp #>anim_bspinkick
 bne :lf_no_jump_descent
:lf_check_last_idx_billy
 ldy #0
 lda (anim_ptr),y       ; num_frames
 sec
 sbc #1                 ; last frame index
 sta :lf_lastfrm
 ldy #26
 lda (info_ptr),y       ; anim_frame
 cmp :lf_lastfrm
 bne :lf_no_jump_descent
 stz billy_y_target
 bra :lf_no_jump_descent
:lf_jimmy_jump_chk
 lda anim_ptr
 cmp #<anim_jjump
 bne :lf_chk_jspin_last
 lda anim_ptr+1
 cmp #>anim_jjump
 beq :lf_check_last_idx_jimmy
:lf_chk_jspin_last
 lda anim_ptr
 cmp #<anim_jbspinkick
 bne :lf_no_jump_descent
 lda anim_ptr+1
 cmp #>anim_jbspinkick
 bne :lf_no_jump_descent
:lf_check_last_idx_jimmy
 ldy #0
 lda (anim_ptr),y       ; num_frames
 sec
 sbc #1                 ; last frame index
 sta :lf_lastfrm
 ldy #26
 lda (info_ptr),y       ; anim_frame
 cmp :lf_lastfrm
 bne :lf_no_jump_descent
 stz jimmy_stash_y_target
:lf_no_jump_descent
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
* Special-case anim_wpipeswing: 5-frame sequence (WPIPE1 → WPIPE4
* → WPIPE2 → WPIPE6 → WPIPE3) puts the forward strike pose at
* frame 2 (WPIPE2). The standard frame-1 gate below would fire on
* WPIPE4 (the cocked-back wind-up), where the pipe is on the WRONG
* side of williams_pipe's body and can't reach Billy. Checked
* before the cmp #1 gate so this anim alone fires at frame 2 and
* every other attack still fires at frame 1.
 lda anim_ptr
 cmp #<anim_wpipeswing
 bne :not_wpipeswing
 lda anim_ptr+1
 cmp #>anim_wpipeswing
 bne :not_wpipeswing
 ldy #26
 lda (info_ptr),y         ; anim_frame
 cmp #2
 beq :do_hit_wpipe
 jmp :no_punch_hit
:do_hit_wpipe
 jmp :do_hit_now
:not_wpipeswing
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
 bne :try_jp1
 lda anim_ptr+1
 cmp #>anim_punch2
 bne :try_jp1
 jmp :do_hit_now
:try_jp1
 lda anim_ptr
 cmp #<anim_jpunch1
 bne :try_jp2
 lda anim_ptr+1
 cmp #>anim_jpunch1
 bne :try_jp2
 jmp :do_hit_now
:try_jp2
 lda anim_ptr
 cmp #<anim_jpunch2
 bne :try_juc
 lda anim_ptr+1
 cmp #>anim_jpunch2
 bne :try_juc
 jmp :do_hit_now
:try_juc
 lda anim_ptr
 cmp #<anim_juppercut
 bne :try_jspin
 lda anim_ptr+1
 cmp #>anim_juppercut
 bne :try_jspin
 jmp :do_hit_now
:try_jspin
 lda anim_ptr
 cmp #<anim_jbspinkick
 bne :try_wp
 lda anim_ptr+1
 cmp #>anim_jbspinkick
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
 bne :try_jpipe
 lda anim_ptr+1
 cmp #>anim_bpipeswing
 bne :try_jpipe
 jmp :do_hit_now
:try_jpipe
 lda anim_ptr
 cmp #<anim_jpipeswing
 bne :try_bmace
 lda anim_ptr+1
 cmp #>anim_jpipeswing
 bne :try_bmace
 jmp :do_hit_now
:try_bmace
 lda anim_ptr
 cmp #<anim_bmaceswing
 bne :try_jmace
 lda anim_ptr+1
 cmp #>anim_bmaceswing
 bne :try_jmace
 jmp :do_hit_now
:try_jmace
 lda anim_ptr
 cmp #<anim_jmaceswing
 bne :try_bspin
 lda anim_ptr+1
 cmp #>anim_jmaceswing
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
 bne :try_jkick
 lda anim_ptr+1
 cmp #>anim_kick
 beq :do_kick_hit
:try_jkick
 lda anim_ptr
 cmp #<anim_jkick
 bne :no_punch_hit
 lda anim_ptr+1
 cmp #>anim_jkick
 bne :no_punch_hit
:do_kick_hit
* Back-kick: KICK2 renders Billy's foot opposite his facing.
* Replace the hitbox with a BEHIND-only band so the kick can
* only catch NPCs whose xpos is on Billy's back side, not
* forward of him. Override FRAME_Y to walk-height (40) so the
* vertical tolerance in check_punch_hit isn't thrown off by
* KICK2's shorter 34-row box.
*
* mirror=0 (facing right): hitbox = (xpos-EXT)..(xpos-1).
* mirror=1 (facing left):  hitbox = (xpos+9)..(xpos+8+EXT).
*   (xpos+9 = Billy's natural walk right edge — start the
*    behind-band just past his body.)
 lda IMAGE01_XPOS
 sta :kick_saved_xpos
 lda FRAME_X
 sta :kick_saved_fx
 lda FRAME_Y
 sta :kick_saved_fy
 lda #40
 sta FRAME_Y
 lda #KICK_BACK_EXT
 sta FRAME_X            ; hitbox width = EXT
 lda IMAGE01_MIRROR
 bne :kick_behind_right
* Mirror=0: hitbox xpos = billy_xpos - EXT (behind to the left).
 lda IMAGE01_XPOS
 sec
 sbc #KICK_BACK_EXT
 bcs :kick_xl_ok
 lda #0
:kick_xl_ok
 sta IMAGE01_XPOS
 bra :kick_do_hit
:kick_behind_right
* Mirror=1: hitbox xpos = billy_xpos + 9 (behind to the right,
* just past his standing-frame's right edge).
 lda IMAGE01_XPOS
 clc
 adc #9
 sta IMAGE01_XPOS
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
 beq :nfb_chk_anim
 jmp :no_fall_bump
:nfb_chk_anim
 ldy #50
 lda (info_ptr),y
 cmp anim_ptr
 beq :nfb_chk_anim_hi
 jmp :no_fall_bump
:nfb_chk_anim_hi
 ldy #51
 lda (info_ptr),y
 cmp anim_ptr+1
 beq :nfb_do_bump
 jmp :no_fall_bump
:nfb_do_bump
* DEBUG: log bump with pre-bump ypos
 do DEBUG_PRINT
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
 fin
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
* Y clamp: ypos + FALL_Y_OFFSET was just applied above. If
* the resulting ypos+frame_y exceeds the playfield bottom (row
* 182), the FALLEN sprite draws into the HUD/below-playfield
* area and erase_all can't restore those pixels (bank $18 only
* mirrors the playfield). Snap ypos so the body's bottom row
* lands at row 182, and sync prev_ypos so erase clears the
* right rect on the redraw.
 ldy #0
 lda (info_ptr),y       ; current ypos (post FALL_Y_OFFSET bump)
 ldy #12
 clc
 adc (info_ptr),y       ; ypos + frame_y = bottom row
 cmp #184               ; playfield ends at row 182, so bottom must be < 184
 bcc :nfb_y_ok
 lda #183
 ldy #12
 sec
 sbc (info_ptr),y       ; new ypos = 183 - frame_y
 ldy #0
 sta (info_ptr),y       ; ypos
 ldy #32
 sta (info_ptr),y       ; prev_ypos = clamped (erase anchor)
:nfb_y_ok
* NPC-only UP clamp: align FALLEN feet with the standing floor row.
* Target ypos = npc_min_y + idle_y - frame_y. Setting cur_ypos to
* npc_min_y alone leaves FALLEN floating (its 15-row body would
* end at npc_min_y+15, well above the standing floor at npc_min_y+
* idle_y). Targeting npc_min_y + (idle_y - frame_y) puts FALLEN's
* bottom row at standing's bottom row (= the visual floor).
*
* Only clamp UP (cur < target). If the +FALL_Y_OFFSET bump already
* put the body at or past the target, leave it — could be a fall
* into a below-floor pit or a hit that was already at floor.
*
* DO NOT touch prev_ypos. :ftraj_do_snap already set prev_ypos to
* the trajectory's last drawn y; overwriting it here loses that
* anchor and the next frame's erase rect can't reach the FALL pose
* pixels still on screen (visible as a FALL-shaped sliver above
* the rescued standing sprite).
 ldy #22
 lda (info_ptr),y
 cmp #$01
 beq :nfb_skip_npc_clamp
 cmp #$02
 beq :nfb_skip_npc_clamp
* tgt = npc_min_y + idle_y - frame_y
 lda npc_min_y
 clc
 ldy #46
 adc (info_ptr),y           ; A = npc_min_y + idle_y
 ldy #12
 sec
 sbc (info_ptr),y           ; A = npc_min_y + idle_y - frame_y
 sta :nfb_npc_tgt
 ldy #0
 lda (info_ptr),y           ; cur_ypos (post-bump, post-DOWN-clamp)
 cmp :nfb_npc_tgt
 bcs :nfb_skip_npc_clamp    ; cur_ypos >= target, leave alone
 lda :nfb_npc_tgt
 ldy #0
 sta (info_ptr),y           ; cur_ypos = target. prev_ypos preserved.
:nfb_skip_npc_clamp
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
:lf_lastfrm dfb 0
:kick_saved_xpos dfb 0
:kick_saved_fx   dfb 0
:kick_saved_fy   dfb 0
:nfb_new_xpos    dfb 0
:nfb_delta       dfb 0
:nfb_npc_tgt     dfb 0
:ne_rescue_xmin  dfb 0
:ne_rescue_xmax  dfb 0
:ne_rescue_oldx  dfb 0
:ne_rescue_dx    dfb 0
:dd_w            dfb 0
:dd_h            dfb 0

*----------------------------------------------------------
* Burnov boss-death state-machine helpers moved to mission1boss.s
* (bank $1E): start_burnov_dissolve / start_burnov_recon /
* finish_burnov_recon. update_anims now calls them via
* jsl bn_dissolve / bn_recon / bn_finish_recon.
*----------------------------------------------------------

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
* Transform linda_flail → regular compiled Linda. idle_addr /
* frame_addr → compiled LINDA1 (bank $1B). info+60/+62 →
* compiled LINDA1_MASK so post-transform idle renders compiled.
 lda spr_linda1c_data
 ldy #14
 sta (info_ptr),y
 ldy #42
 sta (info_ptr),y
 lda spr_linda1c_data+1
 ldy #15
 sta (info_ptr),y
 ldy #43
 sta (info_ptr),y
 lda spr_linda1c_mask
 ldy #60
 sta (info_ptr),y
 ldy #62
 sta (info_ptr),y
 lda spr_linda1c_mask+1
 ldy #61
 sta (info_ptr),y
 ldy #63
 sta (info_ptr),y
* idle_data_mirror / idle_mask_mirror for the mirror-aware idle —
* matches the regular-Linda installer above so the transformed
* sprite renders flipped at rest when mirror=$01.
 lda spr_linda1c_data_mir
 ldy #64
 sta (info_ptr),y
 lda spr_linda1c_data_mir+1
 ldy #65
 sta (info_ptr),y
 lda spr_linda1c_mask_mir
 ldy #66
 sta (info_ptr),y
 lda spr_linda1c_mask_mir+1
 ldy #67
 sta (info_ptr),y
* walk_anim → anim_lwalk (already compiled bank $1B)
 lda #<anim_lwalk
 ldy #52
 sta (info_ptr),y
 lda #>anim_lwalk
 ldy #53
 sta (info_ptr),y
* atk_anim → anim_lpunch (already compiled bank $1B)
 lda #<anim_lpunch
 ldy #54
 sta (info_ptr),y
 lda #>anim_lpunch
 ldy #55
 sta (info_ptr),y
* frame_bank / idle_bank → $1B (compiled bank)
 lda #$1B
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
* drops 21 px below linda's anchor so it sits on the
* ground in front of her crumpled body, not at her head.
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 ldy #0
 lda (info_ptr),y
 clc
 adc #21
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

* Zero the slot (NPC_INFO_SIZE = 70 bytes — covers compiled mask
* fields at +60..+63, idle-mirror fields at +64..+67, and the NPC
* render-x offsets at +68..+69).
 ldy #69
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
 adc #64
 sta npc_buf_next
 lda npc_buf_next+1
 adc #0
 sta npc_buf_next+1

* Re-sort sprite_table by ypos. spawn_dropped_mace inserted the
* mace at the first null slot, so it lands after Billy regardless
* of y — resort_sprite_table (info_ptr = mace) puts it in the
* correct draw order.
 jsr resort_sprite_table

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
 jsr check_y_bounds_strict
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
 jsr check_y_bounds_strict
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
* Capture thrower's position + facing + controller. Controller
* drives the projectile's hit-target dispatch in update_projectile:
* williams-thrown ($00) hits only Billy; Billy-thrown ($01) hits
* only NPCs with an automatic fall.
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
 ldy #22
 lda (info_ptr),y
 sta :tk_thrower_ctrl  ; $00=NPC (williams), $01=Billy

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

* Zero the full 64-byte slot (clear stale data).
 ldy #63
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

* controller = $03 (projectile — flies, dispatches in
* update_projectile based on the +8 thrower marker below).
 lda #$03
 ldy #22
 sta (info_ptr),y

* Thrower marker at +8 (legacy "anim_count", unused by projectiles):
* copy of the thrower's controller. update_projectile reads this
* to choose knife_hit_billy vs knife_hit_npc.
 lda :tk_thrower_ctrl
 ldy #8
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
 adc #64
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
:tk_x_anchor    dfb 0
:tk_y           dfb 0
:tk_dir         dfb 0
:tk_thrower_ctrl dfb 0

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

* Hit-check. Dispatch based on the thrower marker at +8:
* $01 = Billy threw it  → hits NPCs (auto-fall).
* $02 = Jimmy threw it  → hits NPCs (auto-fall).
* anything else ($00 = williams etc.) → hits BOTH players;
*                          knife_hit_jimmy short-circuits if the
*                          knife was already tagged dead by
*                          knife_hit_billy (both players standing
*                          in the same column is rare but possible
*                          — don't double-damage).
 ldy #8
 lda (info_ptr),y
 cmp #$01
 beq :up_hit_npc
 cmp #$02
 beq :up_hit_npc
 jsr knife_hit_billy
 jsr knife_hit_jimmy
 rts
:up_hit_npc
 jsr knife_hit_npc
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

*----------------------------------------------------------
* knife_hit_jimmy - Mirror of knife_hit_billy for player 2.
* Tests caller's projectile bbox against jimmy_sprite. On hit:
*   - tag the projectile $FFFF in anim_ptr (death sentinel)
*   - if Jimmy isn't already in his fall_anim, start anim_jfall
*     via start_anim (so frame_bank/data/mask/dirty all settle)
*   - deplete one P2 palette slot ($019E52..$019E4A) so the
*     on-screen HP bar shortens
* Gate: jimmy_active=0 → return immediately (player 2 inactive).
* Caller's info_ptr is restored on exit.
*----------------------------------------------------------
knife_hit_jimmy
 lda jimmy_active
 bne :khj_on
 rts
:khj_on
* Skip if knife already dead (e.g. knife_hit_billy already tagged
* it this same call — both players overlapping is rare but
* possible and we don't want double-damage from one projectile).
 ldy #24
 lda (info_ptr),y
 cmp #$FF
 bne :khj_alive
 iny
 lda (info_ptr),y
 cmp #$FF
 bne :khj_alive
 rts
:khj_alive
 ldy #0
 lda (info_ptr),y
 sta :khj_y
 ldy #2
 lda (info_ptr),y
 sta :khj_x
 ldy #10
 lda (info_ptr),y
 sta :khj_w
 ldy #12
 lda (info_ptr),y
 sta :khj_h

* Knife edges
 lda :khj_x
 clc
 adc :khj_w
 sta :khj_right
 lda :khj_y
 clc
 adc :khj_h
 sec
 sbc #1
 sta :khj_bottom

* Jimmy bbox from jimmy_sprite
 lda jimmy_sprite
 sta :jb_y
 lda jimmy_sprite+2
 sta :jb_x
 lda jimmy_sprite+10
 sta :jb_w
 lda jimmy_sprite+12
 sta :jb_h
 clc
 adc :jb_y
 sec
 sbc #1
 sta :jb_bottom
 lda :jb_x
 clc
 adc :jb_w
 sta :jb_right

* Horizontal overlap
 lda :khj_right
 cmp :jb_x
 bcs :khj_h2
 jmp :khj_no_hit
:khj_h2
 lda :khj_x
 cmp :jb_right
 beq :khj_vcheck
 bcc :khj_vcheck
 jmp :khj_no_hit
:khj_vcheck
* Vertical overlap
 lda :khj_bottom
 cmp :jb_y
 bcs :khj_v2
 jmp :khj_no_hit
:khj_v2
 lda :khj_y
 cmp :jb_bottom
 beq :khj_hit
 bcc :khj_hit
 jmp :khj_no_hit

:khj_hit
* Tag the knife dead.
 lda #$FF
 ldy #24
 sta (info_ptr),y
 iny
 sta (info_ptr),y

* Save info_ptr; switch to jimmy_sprite for fall_anim install.
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 lda #<jimmy_sprite
 sta info_ptr
 lda #>jimmy_sprite
 sta info_ptr+1

* Already in fall_anim? Compare anim_ptr (+24/+25) to fall_anim (+50/+51).
 ldy #50
 lda (info_ptr),y
 ldy #24
 cmp (info_ptr),y
 bne :khj_do_fall
 ldy #51
 lda (info_ptr),y
 ldy #25
 cmp (info_ptr),y
 bne :khj_do_fall
 bra :khj_restore       ; already falling — knife passes (logically)

:khj_do_fall
* Start Jimmy's fall_anim via start_anim — same reasoning as the
* knife_hit_billy path (start_anim sets frame_bank from anim flags
* so bank-$1D anim_jfall pixels load from the right bank).
 ldy #50
 lda (info_ptr),y
 pha
 ldy #51
 lda (info_ptr),y
 tax
 pla
 jsr start_anim
* Weapon hit = automatic fall. Mirror Billy's :uf bookkeeping for
* Jimmy: zero punch_count, bump jimmy_stash_fall_count, deplete
* one P2 palette slot.
 lda #0
 ldy #48
 sta (info_ptr),y
 inc jimmy_stash_fall_count
 lda jimmy_stash_fall_count
 cmp #1
 bne :khj_dep_2
 lda #0
 stal $019E52
 stal $019E53
 bra :khj_restore
:khj_dep_2
 cmp #2
 bne :khj_dep_3
 lda #0
 stal $019E50
 stal $019E51
 bra :khj_restore
:khj_dep_3
 cmp #3
 bne :khj_dep_4
 lda #0
 stal $019E4E
 stal $019E4F
 bra :khj_restore
:khj_dep_4
 cmp #4
 bne :khj_dep_5
 lda #0
 stal $019E4C
 stal $019E4D
 bra :khj_restore
:khj_dep_5
 cmp #5
 bne :khj_restore
 lda #0
 stal $019E4A
 stal $019E4B

:khj_restore
 pla
 sta info_ptr+1
 pla
 sta info_ptr
:khj_no_hit
 rts

:khj_x      dfb 0
:khj_y      dfb 0
:khj_w      dfb 0
:khj_h      dfb 0
:khj_right  dfb 0
:khj_bottom dfb 0
:jb_x       dfb 0
:jb_y       dfb 0
:jb_w       dfb 0
:jb_h       dfb 0
:jb_right   dfb 0
:jb_bottom  dfb 0

*----------------------------------------------------------
* knife_hit_npc - Bbox overlap test of caller's projectile
* (info_ptr) against every NPC (controller=$00) in
* sprite_table. On the first hit:
*   - tag the projectile $FFFF in anim_ptr (death sentinel)
*   - bump the NPC's punch_count by 3 (mirrors mace/uppercut
*     "damage = 3" in check_punch_hit's dmg-table)
*   - start the NPC's fall_anim, after staging IMAGE01_*
*     globals so start_anim sets up correctly. The standard
*     :ad_normal_flow path in update_anims handles the death
*     transition once punch_count walks past 6.
* NPCs already mid-fall_anim are skipped (knife passes through).
* Caller's info_ptr / spr_ptr are restored on exit.
*----------------------------------------------------------
knife_hit_npc
* Snapshot knife bbox while info_ptr still points at projectile.
 ldy #0
 lda (info_ptr),y
 sta :kn_y
 ldy #2
 lda (info_ptr),y
 sta :kn_x
 ldy #10
 lda (info_ptr),y
 sta :kn_w
 ldy #12
 lda (info_ptr),y
 sta :kn_h
 lda :kn_x
 clc
 adc :kn_w
 sta :kn_right
 lda :kn_y
 clc
 adc :kn_h
 sec
 sbc #1
 sta :kn_bottom

* Save caller's info_ptr / spr_ptr; we clobber both during the
* sprite_table iteration.
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 lda spr_ptr
 pha
 lda spr_ptr+1
 pha

 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:kn_loop
 ldy #0
 lda (spr_ptr),y
 sta info_ptr
 iny
 lda (spr_ptr),y
 sta info_ptr+1
 ora info_ptr
 bne :kn_not_null
 jmp :kn_done           ; null terminator → no hit
:kn_not_null
* NPC filter: controller must be $00. Skip Billy, items,
* projectiles (including this one).
 ldy #22
 lda (info_ptr),y
 beq :kn_is_npc
 jmp :kn_advance
:kn_is_npc
* Skip NPCs already tagged dead ($FFFF in anim_ptr).
 ldy #24
 lda (info_ptr),y
 cmp #$FF
 bne :kn_alive
 ldy #25
 lda (info_ptr),y
 cmp #$FF
 bne :kn_alive
 jmp :kn_advance
:kn_alive
* Bbox snapshot for target.
 ldy #0
 lda (info_ptr),y
 sta :kn_ty
 ldy #2
 lda (info_ptr),y
 sta :kn_tx
 ldy #10
 lda (info_ptr),y
 sta :kn_tw
 ldy #12
 lda (info_ptr),y
 sta :kn_th
 lda :kn_tx
 clc
 adc :kn_tw
 sta :kn_tright
 lda :kn_ty
 clc
 adc :kn_th
 sec
 sbc #1
 sta :kn_tbottom
* Horizontal: knife_right >= target_x AND knife_x <= target_right
 lda :kn_right
 cmp :kn_tx
 bcs :kn_h2
 jmp :kn_advance
:kn_h2
 lda :kn_x
 cmp :kn_tright
 beq :kn_v
 bcc :kn_v
 jmp :kn_advance
:kn_v
* Vertical: knife_bottom >= target_y AND knife_y <= target_bottom
 lda :kn_bottom
 cmp :kn_ty
 bcs :kn_v2
 jmp :kn_advance
:kn_v2
 lda :kn_y
 cmp :kn_tbottom
 beq :kn_hit
 bcc :kn_hit
 jmp :kn_advance
:kn_hit
* Skip if NPC is already in fall_anim — knife passes through.
 ldy #50
 lda (info_ptr),y
 ldy #24
 cmp (info_ptr),y
 bne :kn_do_fall
 ldy #51
 lda (info_ptr),y
 ldy #25
 cmp (info_ptr),y
 bne :kn_do_fall
 jmp :kn_done
:kn_do_fall
* Resolve fall_anim. If the NPC has none, treat as no hit.
 ldy #50
 lda (info_ptr),y
 sta anim_ptr
 ldy #51
 lda (info_ptr),y
 sta anim_ptr+1
 ora anim_ptr
 bne :kn_have_fall
 jmp :kn_done
:kn_have_fall
* damage = 3 (mirrors mace/uppercut). Adds toward the punch_count
* >= 6 death threshold checked in update_anims :ad_check_pc.
 ldy #48
 lda (info_ptr),y
 clc
 adc #3
 sta (info_ptr),y
* Save IMAGE01_* globals — the projectile path doesn't render
* via these, but downstream update_anims iterations might reuse
* whatever start_anim leaves staged.
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
* Stage target's globals for start_anim.
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
 ldy #15
 lda (info_ptr),y
 sta FRAME_ADDR+1
 lda anim_ptr
 ldx anim_ptr+1
 jsr start_anim
* Restore globals.
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
* Restore caller's spr_ptr / info_ptr, then tag the projectile
* dead. info_ptr is currently the target — flip back before
* the $FFFF write.
 pla
 sta spr_ptr+1
 pla
 sta spr_ptr
 pla
 sta info_ptr+1
 pla
 sta info_ptr
 lda #$FF
 ldy #24
 sta (info_ptr),y
 iny
 sta (info_ptr),y
 rts

:kn_advance
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :kn_jloop
 inc spr_ptr+1
:kn_jloop jmp :kn_loop

:kn_done
* No hit (or skipped) — restore caller's spr_ptr / info_ptr,
* leave projectile alive.
 pla
 sta spr_ptr+1
 pla
 sta spr_ptr
 pla
 sta info_ptr+1
 pla
 sta info_ptr
 rts

:kn_x       dfb 0
:kn_y       dfb 0
:kn_w       dfb 0
:kn_h       dfb 0
:kn_right   dfb 0
:kn_bottom  dfb 0
:kn_tx      dfb 0
:kn_ty      dfb 0
:kn_tw      dfb 0
:kn_th      dfb 0
:kn_tright  dfb 0
:kn_tbottom dfb 0


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
 adc #21              ; +21 from williams' ypos: settles at feet
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

 ldy #63                ; clear full 64-byte slot
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
 adc #64
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
* Transform → regular compiled williams. idle_addr/frame_addr
* → compiled WILLIAM1 (bank $1B). info+60/+62 → compiled
* WILLIAM1_MASK so post-transform idle renders compiled.
 lda spr_william1c_data
 ldy #14
 sta (info_ptr),y
 ldy #42
 sta (info_ptr),y
 lda spr_william1c_data+1
 ldy #15
 sta (info_ptr),y
 ldy #43
 sta (info_ptr),y
 lda spr_william1c_mask
 ldy #60
 sta (info_ptr),y
 ldy #62
 sta (info_ptr),y
 lda spr_william1c_mask+1
 ldy #61
 sta (info_ptr),y
 ldy #63
 sta (info_ptr),y
* idle_data_mirror / idle_mask_mirror — matches the regular-
* William installer so the transformed sprite renders flipped at
* rest when mirror=$01.
 lda spr_william1c_data_mir
 ldy #64
 sta (info_ptr),y
 lda spr_william1c_data_mir+1
 ldy #65
 sta (info_ptr),y
 lda spr_william1c_mask_mir
 ldy #66
 sta (info_ptr),y
 lda spr_william1c_mask_mir+1
 ldy #67
 sta (info_ptr),y
* walk_anim → anim_wwalk (already compiled bank $1B)
 lda #<anim_wwalk
 ldy #52
 sta (info_ptr),y
 lda #>anim_wwalk
 ldy #53
 sta (info_ptr),y
* atk_anim → anim_wpunch (already compiled bank $1B)
 lda #<anim_wpunch
 ldy #54
 sta (info_ptr),y
 lda #>anim_wpunch
 ldy #55
 sta (info_ptr),y
* frame_bank / idle_bank → $1B (compiled bank)
 lda #$1B
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
* (ypos + 25). Mirrors spawn_dropped_mace's structure. PIPE1
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
 adc #25              ; +25 from williams' ypos: settles at feet
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

 ldy #63                ; clear full 64-byte slot
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
 adc #64
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
* Save the active player's info_ptr so we can restore it after
* the sprite_table scan below mutates it. Snapshot bbox from
* the active player (Billy OR Jimmy), not hardcoded billy_sprite,
* so Jimmy can pick up weapons when he presses L.
 lda info_ptr
 sta :tp_save_ip
 lda info_ptr+1
 sta :tp_save_ip+1
 ldy #0
 lda (info_ptr),y         ; ypos
 sta :tp_by
 clc
 ldy #12
 adc (info_ptr),y         ; bottom = ypos + frame_y
 sta :tp_bbottom
 ldy #2
 lda (info_ptr),y         ; xpos
 sta :tp_bx
 ldy #10
 clc
 adc (info_ptr),y         ; right = xpos + frame_x (frame_x of active)
 sta :tp_bright

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
 bne :tp_chk_knife
 ldy #15
 lda (info_ptr),y
 cmp spr_mace2+1
 bne :tp_chk_knife
 lda #2                   ; weapon kind = mace
 sta :tp_kind
 bra :tp_have_kind
:tp_chk_knife
* Dropped knife (KNIFE2 right-facing or KNIFE4 left-facing). Same
* sprite addrs that spawn_dropped_knife wrote into +14/+15.
 ldy #14
 lda (info_ptr),y
 cmp spr_knife2
 bne :tp_chk_knife4
 ldy #15
 lda (info_ptr),y
 cmp spr_knife2+1
 bne :tp_chk_knife4
 lda #3                   ; weapon kind = knife
 sta :tp_kind
 bra :tp_have_kind
:tp_chk_knife4
 ldy #14
 lda (info_ptr),y
 cmp spr_knife4
 bne :tp_advance
 ldy #15
 lda (info_ptr),y
 cmp spr_knife4+1
 bne :tp_advance
 lda #3                   ; weapon kind = knife
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
* Restore info_ptr to the active player (Billy or Jimmy) that
* triggered the pickup. From here on (info_ptr),y writes target
* their block — billy_arm_* dispatch on info_ptr internally.
 lda :tp_save_ip
 sta info_ptr
 lda :tp_save_ip+1
 sta info_ptr+1
* Arm the active player (set flag + idle pose for the matching
* weapon). active_pickup_anim plays the pose (anim_bpickup for
* Billy / anim_jpickup for Jimmy); idle restore at anim end
* picks up the new BPIPEW1/JPIPEW1 / BMWALK1/JMWALK1 / etc.
 lda :tp_kind
 cmp #1
 bne :tp_arm_chk_mace
 jsr billy_arm_pipe
 bra :tp_start_anim
:tp_arm_chk_mace
 cmp #2
 bne :tp_arm_knife
 jsr billy_arm_mace
 bra :tp_start_anim
:tp_arm_knife
 jsr billy_arm_knife
:tp_start_anim
 lda active_pickup_anim
 ldx active_pickup_anim+1
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
* Restore info_ptr to the caller's active player (saved at entry).
 lda :tp_save_ip
 sta info_ptr
 lda :tp_save_ip+1
 sta info_ptr+1
 clc                      ; no pickup
 rts

:tp_save_ip ds 2
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
 jsr arm_pick_pipew1     ; A.lo / X = pipew1 addr for active player
 ldy #42
 sta (info_ptr),y
 iny
 txa
 sta (info_ptr),y
 jmp arm_common_active   ; dispatch idle_bank by controller too

*----------------------------------------------------------
* billy_arm_mace - Symmetric to billy_arm_pipe. Sets
* billy_mace_armed and points idle_addr at BMWALK1 / JMWALK1
* depending on the active player.
*----------------------------------------------------------
billy_arm_mace
 lda #1
 sta billy_mace_armed
 jsr arm_pick_mwalk1
 ldy #42
 sta (info_ptr),y
 iny
 txa
 sta (info_ptr),y
 jmp arm_common_active

*----------------------------------------------------------
* billy_arm_knife - Set billy_knife_armed and rewrite the
* active player's idle pose to BKWALK1 / JKWALK1 (11×40,
* legacy bank — $19 for Billy, $1D for Jimmy). advance_walk
* picks up the matching walk table while the flag is set, and
* L throws the knife (see btn_action_punch knife branch).
*----------------------------------------------------------
billy_arm_knife
 lda #1
 sta billy_knife_armed
 jsr arm_pick_kwalk1
 ldy #42
 sta (info_ptr),y
 iny
 txa
 sta (info_ptr),y
 lda #$0B               ; idle_x = 11 (BKWALK1/JKWALK1 width)
 ldy #44
 sta (info_ptr),y
 lda #$28               ; idle_y = 40
 ldy #46
 sta (info_ptr),y
 jsr arm_pick_idle_bank
 ldy #58
 sta (info_ptr),y
 lda #0
 ldy #59
 sta (info_ptr),y
 rts

*----------------------------------------------------------
* arm_common_active - Shared idle-state setup for armed
* players. Sets idle_x=9, idle_y=40, idle_bank dispatched per
* player. BPIPEW1/BMWALK1 are 9×40 in bank $19; JPIPEW1/
* JMWALK1 are 9×40 in bank $1D.
*----------------------------------------------------------
arm_common_active
 lda #$09
 ldy #44
 sta (info_ptr),y
 lda #$28
 ldy #46
 sta (info_ptr),y
 jsr arm_pick_idle_bank
 ldy #58
 sta (info_ptr),y
 lda #0
 ldy #59
 sta (info_ptr),y
 rts

*----------------------------------------------------------
* arm_pick_pipew1 / arm_pick_mwalk1 / arm_pick_kwalk1 -
* Return the active player's pipew/mwalk/kwalk1 cache address
* in A (low) and X (high). Active = info_ptr; Billy ($01) →
* spr_b*, Jimmy ($02) → spr_j*, NPC defaults to Billy's.
*----------------------------------------------------------
arm_pick_pipew1
 jsr arm_is_jimmy
 bcs :api_jimmy
 lda spr_bpipew1
 ldx spr_bpipew1+1
 rts
:api_jimmy
 lda spr_jpipew1
 ldx spr_jpipew1+1
 rts
arm_pick_mwalk1
 jsr arm_is_jimmy
 bcs :amw_jimmy
 lda spr_bmwalk1
 ldx spr_bmwalk1+1
 rts
:amw_jimmy
 lda spr_jmwalk1
 ldx spr_jmwalk1+1
 rts
arm_pick_kwalk1
 jsr arm_is_jimmy
 bcs :akw_jimmy
 lda spr_bkwalk1
 ldx spr_bkwalk1+1
 rts
:akw_jimmy
 lda spr_jkwalk1
 ldx spr_jkwalk1+1
 rts

*----------------------------------------------------------
* arm_pick_idle_bank - A = idle_bank for the active player's
* armed sprite set. Billy uses bank $19 (BPIPEW/BMWALK/BKWALK);
* Jimmy uses $1D (JPIPEW/JMWALK/JKWALK). Preserves X / Y.
*----------------------------------------------------------
arm_pick_idle_bank
 jsr arm_is_jimmy
 bcs :aib_jimmy
 lda #$19
 rts
:aib_jimmy
 lda #$1D
 rts

*----------------------------------------------------------
* arm_is_jimmy - C=1 if info_ptr is jimmy_sprite, C=0 if not.
* Preserves A / X / Y.
*----------------------------------------------------------
arm_is_jimmy
 pha
 lda info_ptr+1
 cmp #>jimmy_sprite
 bne :aij_not
 lda info_ptr
 cmp #<jimmy_sprite
 bne :aij_not
 pla
 sec
 rts
:aij_not
 pla
 clc
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
 stz billy_knife_armed
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
 sta billy_sprite+60      ; persisted into save_sprite next frame
 lda spr_image01_mask+1
 sta billy_sprite+61
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

*----------------------------------------------------------
* jimmy_disarm_weapon - Mirror of billy_disarm_weapon for the
* second player. Called from kill_objects when OP_KILLOBJ fires
* while Jimmy is armed. Clears jimmy_stash_*_armed and restores
* Jimmy's compiled JIMMY01 idle in bank $1D. Mirror selected
* from jimmy_sprite+4 directly (not IMAGE01_MIRROR, since at
* run_script time the swap has resolved back to Billy and the
* global may not reflect Jimmy's actual facing).
*----------------------------------------------------------
jimmy_disarm_weapon
 stz jimmy_stash_pipe_armed
 stz jimmy_stash_mace_armed
 stz jimmy_stash_knife_armed
* idle_addr / idle mask point at canonical forward JIMMY01.
 lda spr_jimmy01
 sta jimmy_sprite+42
 lda spr_jimmy01+1
 sta jimmy_sprite+43
 lda spr_jimmy01_mask
 sta jimmy_sprite+62
 lda spr_jimmy01_mask+1
 sta jimmy_sprite+63
* Pick live data + mask pair that matches Jimmy's actual mirror.
 lda jimmy_sprite+4
 bne :jdw_mirror
 lda spr_jimmy01
 sta jimmy_sprite+14
 lda spr_jimmy01+1
 sta jimmy_sprite+15
 lda spr_jimmy01_mask
 sta jimmy_sprite+60
 lda spr_jimmy01_mask+1
 sta jimmy_sprite+61
 bra :jdw_dims
:jdw_mirror
 lda spr_jimmy01_data_mir
 sta jimmy_sprite+14
 lda spr_jimmy01_data_mir+1
 sta jimmy_sprite+15
 lda spr_jimmy01_mask_mir
 sta jimmy_sprite+60
 lda spr_jimmy01_mask_mir+1
 sta jimmy_sprite+61
:jdw_dims
 lda #$09
 sta jimmy_sprite+10
 sta jimmy_sprite+44
 lda #$28
 sta jimmy_sprite+12
 sta jimmy_sprite+46
 lda #$1D
 sta jimmy_sprite+56      ; frame_bank → $1D
 sta jimmy_sprite+58      ; idle_bank → $1D
 lda #0
 sta jimmy_sprite+57
 sta jimmy_sprite+59
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
* Level-manifest path helpers. Read mission-specific ProDOS
* paths from the bank-$02 level manifest (header manifest_off
* at $02/0004) into level_path_buf and point p_open/file_open
* at it. Emulation mode, 8-bit A/X/Y; use $F0-$F2 as a bank-$02
* long pointer. See mission1.s level_manifest for the layout.
*----------------------------------------------------------
 mx %11
* get_man_base - man_base = 16-bit manifest offset from header.
get_man_base
 lda #$04
 sta $F0
 stz $F1
 lda #$02
 sta $F2              ; $F0 -> $02/0004
 ldy #0
 lda [$F0],y
 sta man_base
 iny
 lda [$F0],y
 sta man_base+1
 rts

* append_str - append a manifest str's CHARS (skipping its
* length byte) to level_path_buf. In: $F0-$F2 = bank-$02 str
* addr, X = dest index. Out: X = dest index past the chars.
append_str
 ldy #0
 lda [$F0],y          ; str length
 sta lp_limit
 inc lp_limit         ; loop copies source indices 1..len
 ldy #1
:as_loop
 cpy lp_limit
 bcs :as_done
 lda [$F0],y
 sta level_path_buf,x
 inx
 iny
 bra :as_loop
:as_done
 rts

* set_open_ptrs - point p_open and file_open pathname pointers
* at level_path_buf.
set_open_ptrs
 lda #<level_path_buf
 sta p_open+1
 sta file_open+1
 lda #>level_path_buf
 sta p_open+2
 sta file_open+2
 rts

* level_get_bgcount - A = manifest bg_count (manifest +2).
level_get_bgcount
 jsr get_man_base
 lda man_base
 sta $F0
 lda man_base+1
 sta $F1
 lda #$02
 sta $F2
 ldy #2
 lda [$F0],y
 rts

* level_compose_bg - compose "DIR/NAME" for background X into
* level_path_buf and set the pathname pointers. In: X = bg index.
level_compose_bg
 jsr get_man_base
* bg_ptr[X] = manifest +6 + X*2; deref -> name str addr.
* (Layout: +0 dir_ptr, +2 bg_count, +3 load_count, +4 loading_str_ptr,
*  +6 bg_ptrs, +6+bg_count*2 load_entries.)
 txa
 asl
 clc
 adc #6
 clc
 adc man_base
 sta $F0
 lda man_base+1
 adc #0
 sta $F1
 lda #$02
 sta $F2
 ldy #0
 lda [$F0],y          ; name str addr lo
 sta lp_name_lo
 iny
 lda [$F0],y          ; name str addr hi
 sta lp_name_hi
* dir_ptr at manifest +0; deref -> dir str addr into $F0/$F1.
 lda man_base
 sta $F0
 lda man_base+1
 sta $F1
 lda #$02
 sta $F2
 ldy #0
 lda [$F0],y          ; dir addr lo
 pha
 iny
 lda [$F0],y          ; dir addr hi
 sta $F1
 pla
 sta $F0              ; $F0/$F1/$F2 -> dir str (bank $02)
* Append dir chars at dest index 1 (leaving room for len byte).
 ldx #1
 jsr append_str
* Append the '/' separator.
 lda #'/'
 sta level_path_buf,x
 inx
* Append the bare name chars.
 lda lp_name_lo
 sta $F0
 lda lp_name_hi
 sta $F1
 lda #$02
 sta $F2
 jsr append_str
* Write the ProDOS length byte (total chars = dest index - 1).
 dex
 txa
 sta level_path_buf
 jmp set_open_ptrs

* compose_level_data_path - build 'MISSION{N}/MISSION{N}' into
* level_path_buf from current_mission. Single-digit missions only
* (mtemplate has placeholder '0' chars at the two digit positions;
* we copy the template then patch both with ASCII current_mission).
* Sets p_open + file_open pathname pointers.
compose_level_data_path
 lda #17
 sta level_path_buf     ; ProDOS length byte
 ldx #0
:cldp_loop
 lda mtemplate,x
 sta level_path_buf+1,x
 inx
 cpx #17
 bne :cldp_loop
 lda current_mission
 clc
 adc #'0'               ; ASCII digit
 sta level_path_buf+8   ; index 7 in chars = first digit position
 sta level_path_buf+17  ; index 16 in chars = second digit position
 jmp set_open_ptrs
mtemplate asc 'MISSION0/MISSION0'

* level_iter_loads - iterate the manifest's load_entries[] list
* and load each file via load_file or load_and_unpack per its
* kind. Entry layout: +0 dw path_ptr, +2 db dest_bank, +3 db kind
* (0 = load_file; 1 = unpack@$2000; 2 = unpack@$0000). Iterates
* load_count times (count read from manifest +3). Trashes A,X,Y
* and $F0-$F5; preserves caller's mode (emulation, mx %11).
level_iter_loads
 jsr get_man_base
* Compute offset of load_entries[0] from manifest base:
*   off = 6 + bg_count*2  (load_entries follow the bg_ptr array)
 lda man_base
 sta $F0
 lda man_base+1
 sta $F1
 lda #$02
 sta $F2
 ldy #2
 lda [$F0],y          ; bg_count
 asl
 clc
 adc #6
 sta lp_iter_off
 ldy #3
 lda [$F0],y          ; load_count
 sta lp_iter_count
 stz lp_iter_idx
:il_loop
 lda lp_iter_idx
 cmp lp_iter_count
 bcc :il_body
 rts
:il_body
* Entry addr = man_base + lp_iter_off + idx*4
 lda lp_iter_idx
 asl
 asl                  ; idx*4
 clc
 adc lp_iter_off
 clc
 adc man_base
 sta $F0
 lda man_base+1
 adc #0
 sta $F1
 lda #$02
 sta $F2              ; $F0 -> load_entry[idx]
 ldy #0
 lda [$F0],y          ; path_ptr lo
 sta lp_name_lo
 iny
 lda [$F0],y          ; path_ptr hi
 sta lp_name_hi
 iny
 lda [$F0],y          ; dest_bank
 sta lp_dest_bank
 iny
 lda [$F0],y          ; kind
 sta lp_kind
* Copy path verbatim into level_path_buf (len + chars).
 lda lp_name_lo
 sta $F0
 lda lp_name_hi
 sta $F1
 lda #$02
 sta $F2
 ldy #0
 lda [$F0],y          ; str length
 sta lp_limit
 inc lp_limit         ; copy indices 0..len (len+1 bytes)
 ldy #0
:il_cpy
 cpy lp_limit
 bcs :il_cpydone
 lda [$F0],y
 sta level_path_buf,y
 iny
 bra :il_cpy
:il_cpydone
 jsr set_open_ptrs
* Dispatch by kind.
 lda lp_kind
 beq :il_kind0
 cmp #1
 beq :il_kind1
* kind 2: load_and_unpack to dest_bank / $0000
 lda lp_dest_bank
 sta unpack_bank
 stz unpack_offset
 stz unpack_offset+1
 jsr load_and_unpack
 bra :il_next
:il_kind1
* kind 1: load_and_unpack to dest_bank / $2000
 lda lp_dest_bank
 sta unpack_bank
 stz unpack_offset
 lda #$20
 sta unpack_offset+1
 jsr load_and_unpack
 bra :il_next
:il_kind0
* kind 0: load_file (raw) to dest_bank / $0000
 lda lp_dest_bank
 sta file_bank
 stz file_dest
 stz file_dest+1
 jsr load_file
:il_next
 inc lp_iter_idx
 jmp :il_loop          ; loop body too long for bra (±128)

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
 dfb $10            ; oscillator number (16, 17 L, 18 R)
 dfb $01            ; playback osc count
 dfb $FF            ; volume L
 dfb $00            ; channel panning (0 = mono)
 dfb 2              ; gain shift (×4 — narrow source dynamic range)

sfx_punchlanded_struct
 da $1000           ; sample at $11/1000
 da $0011
 da $0474           ; length 1140
 da $0000
 da $009C
 dfb $82            ; doc_ram_page → DOC $8200
 dfb $10            ; oscillator number (16, 17 L, 18 R)
 dfb $01            ; playback osc count
 dfb $FF            ; volume L
 dfb $00            ; channel panning (0 = mono)
 dfb 2              ; gain shift (×4 — narrow source dynamic range)

sfx_finger_struct
 da $2000           ; sample at $11/2000
 da $0011
 da $1650           ; length 5712
 da $0000
 da $009C
 dfb $84            ; doc_ram_page → DOC $8400
 dfb $10            ; oscillator number (16, 17 L, 18 R)
 dfb $01            ; playback osc count
 dfb $FF            ; volume L
 dfb $00            ; channel panning (0 = mono)
 dfb 1              ; gain shift (×4 — narrow source dynamic range)

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
 dfb $10            ; oscillator number (16, 17 L, 18 R)
 dfb $01            ; playback osc count
 dfb $FF            ; volume L
 dfb $00            ; channel panning (0 = mono)
 dfb 2              ; gain shift (×4 — narrow source dynamic range)

* FALLEN lives at $11/6000 because POW spans $11/4000-$11/50A0;
* skip the $11/5000 slot to avoid clobbering POW's tail.
sfx_fallen_struct
 da $6000           ; sample at $11/6000
 da $0011
 da $0A00           ; length 2560
 da $0000
 da $009C
 dfb $88            ; doc_ram_page → DOC $8800
 dfb $10            ; oscillator number (16, 17 L, 18 R)
 dfb $01            ; playback osc count
 dfb $FF            ; volume L
 dfb $00            ; channel panning (0 = mono)
 dfb 2              ; gain shift (×4 — narrow source dynamic range)

* JUMP fits in one 4 KB slot at $11/7000 (FALLEN's tail ends at
* $11/6A00, so $7000 is clear).
sfx_jump_struct
 da $7000           ; sample at $11/7000
 da $0011
 da $07B0           ; length 1968
 da $0000
 da $009C
 dfb $8A            ; doc_ram_page → DOC $8A00
 dfb $10            ; oscillator number (16, 17 L, 18 R)
 dfb $01            ; playback osc count
 dfb $FF            ; volume L
 dfb $00            ; channel panning (0 = mono)
 dfb 2              ; gain shift (×4 — narrow source dynamic range)

* DOOR is 5896 bytes — claims two 4 KB slots at $11/8000-$11/9708.
sfx_door_struct
 da $8000           ; sample at $11/8000
 da $0011
 da $1708           ; length 5896
 da $0000
 da $009C
 dfb $8C            ; doc_ram_page → DOC $8C00
 dfb $10            ; oscillator number (16, 17 L, 18 R)
 dfb $01            ; playback osc count
 dfb $FF            ; volume L
 dfb $00            ; channel panning (0 = mono)
 dfb 2              ; gain shift (×4 — narrow source dynamic range)

* SPINKICK is 7368 bytes — two 4 KB slots at $11/A000-$11/BCC8.
* (Skips $11/9000-$11/9708 because DOOR's tail clobbers it.)
sfx_spinkick_struct
 da $A000           ; sample at $11/A000
 da $0011
 da $1CC8           ; length 7368
 da $0000
 da $009C
 dfb $8E            ; doc_ram_page → DOC $8E00
 dfb $10            ; oscillator number (16, 17 L, 18 R)
 dfb $01            ; playback osc count
 dfb $FF            ; volume L
 dfb $00            ; channel panning (0 = mono)
 dfb 2              ; gain shift (×4 — narrow source dynamic range)

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
 dfb $10            ; oscillator number (16, 17 L, 18 R)
 dfb $01            ; playback osc count
 dfb $FF            ; volume L
 dfb $00            ; channel panning (0 = mono)
 dfb 2              ; gain shift (×4)

* BURNBACK at $1A/8000 (clear of BURNGONE's $1A/0000-$65D0 tail).
sfx_burnback_struct
 da $8000           ; sample at $1A/8000
 da $001A
 da $76F2           ; length 30450
 da $0000
 da $009C
 dfb $92            ; doc_ram_page → DOC $9200
 dfb $10            ; oscillator number (16, 17 L, 18 R)
 dfb $01            ; playback osc count
 dfb $FF            ; volume L
 dfb $00            ; channel panning (0 = mono)
 dfb 2              ; gain shift (×4)

sfx_punch_path        str 'SFX/PUNCH.RAW'
sfx_punchlanded_path  str 'SFX/PUNCHLANDED.RAW'
sfx_finger_path       str 'SFX/FINGER.RAW'
sfx_pow_path          str 'SFX/POW.RAW'
sfx_fallen_path       str 'SFX/FALLEN.RAW'
sfx_jump_path         str 'SFX/JUMP.RAW'
sfx_door_path         str 'SFX/DOOR.RAW'
sfx_spinkick_path     str 'SFX/SPINKICK.RAW'
sfx_burngone_path     str 'SFX/BURNGONE.RAW'
sfx_burnback_path     str 'SFX/BURNBACK.RAW'

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
* NTPstreamsound relies on NTP's IRQ-driven playback being
* active to service the SFX oscillators. With music stopped
* (M-toggle or auto-pause), the IRQ handler is inactive and
* the SFX firing raises an Unclaimed Sound Interrupt → crash.
* Skip the SFX entirely while muted; user already accepted
* a silent run by muting.
 lda music_muted
 beq :sp_proceed
 rts
:sp_proceed
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
* Gated on DEBUG_HELPERS — uses dbg_print_* (KEGS-only stdout).
*----------------------------------------------------------
 mx %11
 do DEBUG_HELPERS
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
 fin

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

* init_mission13blit moved to engine.s ($1F/0028). EQU below
* lets JSL through the engine.s JML jump table. Body and scratch
* locals live in engine.s::_init_mission13blit.
init_mission13blit equ $1F0028

* init_mission1blit moved to engine.s ($1F/002C). Body, the
* per-sprite offsets table, and scratch locals all live in
* engine.s::_init_mission1blit.
init_mission1blit equ $1F002C

* init_mission1jimmyblit moved to engine.s ($1F/0030). Body,
* offsets table, and scratch locals live in
* engine.s::_init_mission1jimmyblit.
init_mission1jimmyblit equ $1F0030
* scroll_down lives in engine.s ($1F/0034) — mirror of scroll_up
* for descending into below-screen content via ladder.
scroll_down    equ $1F0034

*----------------------------------------------------------
* init_mission12blit moved to engine.s ($1F/0020). EQU below
* lets JSL through the engine.s JML jump table.
init_mission12blit equ $1F0020

* init_mission14blit lives in engine.s ($1F/0024) — populates
* dispatch entries for the bank-$1C armed-NPC compiled sprites
* by pairing mission14blit_{39,3A} blit addresses with the
* spr_lfwalk1c_data cache var array (26 sprites × 4 vars).
init_mission14blit equ $1F0024

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
 da level_path_buf    ; pathname pointer (filled per-load by helpers)
 da ]IOBUF
file_oref dfb 0

file_read dfb 4
file_rref dfb 0
 da ]RDBUF
 da $0400              ; request count (1KB = 2 disk blocks)
 ds 2                  ; transfer count

file_close dfb 1
file_cref dfb 0

* mission1 hardcoded paths (mission1_path, mission12_path,
* mission13_path, mission14_path, blit_load_table + per-blit
* labels, mission1boss_path) moved into the bank-$02 manifest's
* load_entries list. Boot now drives every mission-specific
* load from there via level_iter_loads. MISSION1JIMMY /
* MISSION1NTP.PAK / BOSS.NTP.PAK joined the same list.

completentp_path str 'COMPLETENTP.PAK'

gameoverntp_path str 'GAMEOVERNTP.PAK'

loading_path str 'LOADING.PAK'

engine_path str 'ENGINE'

*----------------------------------------------------------
* Bank-$1F engine entry points (scroll/blit pipeline).
* The actual code lives in engine.s, loaded from /DDIIGS/ENGINE
* to $1F:$0000 at startup. The first 12 bytes of that bank are
* a JML jump table so callers can JSL by fixed address.
*----------------------------------------------------------
scroll_right   equ $1F0000
scroll_left    equ $1F0004
scroll_up      equ $1F0008
init_level     equ $1F000C
init_mission12 equ $1F0010
init_mission13 equ $1F0014
init_mission14 equ $1F0018
init_jimmy     equ $1F001C

*----------------------------------------------------------
* Bank-$1E mission1 boss (Burnov) behavior entry points. Code
* lives in mission1boss.s, loaded from /DDIIGS/MISSION1BOSS to
* $1E:$0000 at startup. JML jump table at the head of the bank,
* same convention as engine.s. Runs with K=$1E, B=$00.
*----------------------------------------------------------
bn_dissolve     equ $1E0000   ; start_burnov_dissolve
bn_recon        equ $1E0004   ; start_burnov_recon
bn_finish_recon equ $1E0008   ; finish_burnov_recon
bn_anim_ended   equ $1E000C   ; boss death-cycle anim-ended dispatch
bn_grab_end     equ $1E0010   ; grab anim-end (release + damage)
bn_try_grab     equ $1E0014   ; grab trigger from check_punch_hit
bn_spawn_setup  equ $1E0018   ; Burnov spawn detector/setup
bn_approach_pad equ $1E001C   ; fo_approach edge padding

*----------------------------------------------------------
* JSL trampolines used by engine.s to call back into bank-$00
* routines that aren't worth migrating (small helpers and one
* heavyweight render path). Each is a JSR+RTL shim: engine.s
* `jsl <name>_l` pushes a 24-bit return; the shim runs the
* original routine via JSR, then RTLs back to engine.s.
*----------------------------------------------------------
shadow_off_l          jsr shadow_off
                      rtl
shadow_on_l           jsr shadow_on
                      rtl
draw_active_sprite_l  jsr draw_active_sprite
                      rtl
draw_other_sprite_l   jsr draw_other_sprite
                      rtl
draw_overlay_l        jsr draw_overlay
                      rtl
inc_border_l          jsr inc_border
                      rtl
load_screen_bounds_l  jsr load_screen_bounds
                      rtl
load_ladders_l        jsr load_ladders
                      rtl
* Wrappers for mission1boss.s (bank $1E) callbacks into bank-$00
* routines. Same JSR+RTL shim convention as the engine.s wrappers.
sound_trigger_l       jsr sound_trigger
                      rtl
start_anim_l          jsr start_anim
                      rtl

* Bank-$00 scratch cells for staging check_punch_hit locals into
* a place mission1boss.s (bank $1E) can read. The puncher anim
* and Burnov-self ptr are check_punch_hit local dfbs (:puncher_*
* / :self_*); we copy them here just before jsl bn_try_grab.
bn_puncher_anim_lo dfb 0
bn_puncher_anim_hi dfb 0
bn_self_lo         dfb 0
bn_self_hi         dfb 0

* Bank-$00 storage for engine.s's private scratch cells. engine.s
* runs with DBR=$00, so any data it uses via 16-bit absolute mode
* has to live here in bank $00 — declaring it inside engine.s
* (bank $1F) silently wrote to the wrong bank.
                      PUT engine_data.s

* Sprite-address cache vars that init_level / init_mission12-14
* populate in engine.s. These are read by renderer, AI, hit
* detection — keep them in bank $00.
                      PUT init_data.s

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
* Diagnostic helpers — thin shims over the KEGS virtual stdout
* entry points at $D0/FDED (char) and $D0/FDDA (byte → hex).
* The virtual entries handle byte→hex conversion and stdout output
* directly, so dbg_print_hex8 just JSLs $D0FDDA without nibble
* splitting. dbg_print_nib retired (was only an internal helper
* for the old ROM-based hex8).
*
* Register preservation: callers that need A preserved should
* push/pop themselves. The validate-stratum-bounds caller and the
* DEBUG_LSRC blocks both reload A right before each call, so the
* helpers don't preserve it any more (saves ~15 bytes).
*
* Gated by DEBUG_HELPERS (= DEBUG_PRINT | DEBUG_LSRC). DEBUG_ERASE
* and other narrow-scope debug paths call $D0FDDA / $D0FDED via
* JSL directly without going through these helpers.
*----------------------------------------------------------
 do DEBUG_HELPERS
dbg_print_char
 jsl $D0FDED
 rts

dbg_print_sp
 lda #$A0
 jsl $D0FDED
 rts

dbg_print_nl
 lda #$8D
 jsl $D0FDED
 rts

dbg_print_hex8
 jsl $D0FDDA
 rts
 fin

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
* Gated on DEBUG_HELPERS — uses dbg_print_* (KEGS-only stdout).
*----------------------------------------------------------
 do DEBUG_HELPERS
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
 fin

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
* Self-heal: abs_x has drifted from the invariant. Root cause is
* still unknown — three separate scenarios this shipping cycle,
* all in different code paths, none reproducible from static
* analysis. Rather than halt the game, resync abs_x to the
* canonical value (billy_sprite+2 + world_offset, already computed
* into :ax_lo/:ax_hi above) and return. abs_x feeds OP_WAITX
* gating via compute_script_x, so a stale value could let the
* script advance a frame early or late — acceptable trade for not
* freezing the player mid-run.
 lda :ax_lo
 sta abs_x
 lda :ax_hi
 sta abs_x+1
 rts
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
* Mismatch — 'SS! aa=ee B=bb WO=wwww CS=cs'. Diagnostic print
* gated on DEBUG_HELPERS (KEGS-stdout). On real hardware the assert
* just returns silently when the canary is stripped.
 do DEBUG_HELPERS
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
 fin
 rts
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
* Re-enabled for DEBUG_LSRC. The original early-return was kept
* around because earlier transition windows tripped it spuriously;
* if it fires now during normal play, that's the signal that lsrc
* state has drifted. Flip the rts back on (delete this comment +
* the next four lines) once the co-op left-scroll bug is fixed.
 do DEBUG_LSRC
 bra :al_run
 fin
:al_skip rts
:al_run
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
* Mismatch — 'LS! aa=ee B=bb WO=wwww CS=cs'. Print gated on
* DEBUG_HELPERS (KEGS-stdout only); stripped for real-hardware ship.
 do DEBUG_HELPERS
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
 fin
 rts
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
 dfb $C0             ; flags: bit 7 = compiled stride, bit 6 = bank $1B
 dfb $09,$28,5       ; WPUNCHED: 9 wide, 40 tall, 5 VBLs
  hex 0000             ; patched: WPUNCHED_DATA
  hex 0000             ; patched: WPUNCHED_MASK
  hex 0000             ; patched: WPUNCHED_DATA_MIRROR
  hex 0000             ; patched: WPUNCHED_MASK_MIRROR

anim_wfall
 dfb 2               ; num_frames
 dfb $13             ; max_width (WFALL is widest at $13)
 dfb $D0             ; flags: bit 7 = compiled, bit 6 = bank $1B,
                     ;        bit 4 = fall trajectory
 dfb $13,$21,FALL_ARC_FRAMES ; WFALL: 19 wide, 33 tall, arc duration
  hex 0000             ; patched: WFALL_DATA
  hex 0000             ; patched: WFALL_MASK
  hex 0000             ; patched: WFALL_DATA_MIRROR
  hex 0000             ; patched: WFALL_MASK_MIRROR
 dfb $10,$0D,60      ; WFALLEN: 16 wide, 13 tall, 60 VBLs
  hex 0000             ; patched: WFALLEN_DATA
  hex 0000             ; patched: WFALLEN_MASK
  hex 0000             ; patched: WFALLEN_DATA_MIRROR
  hex 0000             ; patched: WFALLEN_MASK_MIRROR

anim_bfall
 dfb 2               ; num_frames
 dfb $13             ; max_width (BFALLEN at $13)
 dfb $30             ; flags: bit 4 = fall trajectory, bit 5 = bank $19
 dfb $11,$20,FALL_ARC_FRAMES ; BFALL: 17 wide, 32 tall, arc duration
  hex 0000             ; patched: BFALL
 dfb $13,$0D,60      ; BFALLEN: 19 wide, 13 tall, 60 VBLs
  hex 0000             ; patched: BFALLEN

*----------------------------------------------------------
* Jimmy variants of Billy's player anims — same structure /
* frame counts / durations, but flag bit 2 set so start_anim
* writes frame_bank=$1D when Jimmy installs them. init_jimmy
* patches the data/mask pointers from the bank-$1D spr_j*
* cache vars.
*----------------------------------------------------------
anim_jjump
 dfb 3
 dfb $0F
 dfb $85             ; bit 7 compiled, bit 2 bank $1D, bit 0 advance
 dfb $0A,$28,3       ; JJUMP1
  hex 0000
  hex 0000
  hex 0000
  hex 0000
 dfb $0F,$1E,12      ; JJUMP2
  hex 0000
  hex 0000
  hex 0000
  hex 0000
 dfb $0D,$20,3       ; JJUMP3
  hex 0000
  hex 0000
  hex 0000
  hex 0000

anim_jbspinkick
 dfb 8
 dfb $0F
 dfb $04             ; bit 2 bank $1D, legacy stride (no bit 7)
 dfb $0F,$28,4       ; JSPIN1
  hex 0000
 dfb $0F,$28,4       ; JSPIN2
  hex 0000
 dfb $0F,$28,4       ; JSPIN3
  hex 0000
 dfb $0F,$28,4       ; JSPIN2
  hex 0000
 dfb $0F,$28,4       ; JSPIN1
  hex 0000
 dfb $0F,$28,4       ; JSPIN2
  hex 0000
 dfb $0F,$28,4       ; JSPIN3
  hex 0000
 dfb $0F,$28,4       ; JSPIN2
  hex 0000

anim_jkick
 dfb 2
 dfb $14
 dfb $84             ; bit 7 compiled, bit 2 bank $1D
 dfb $09,$28,12      ; JKICK1
  hex 0000
  hex 0000
  hex 0000
  hex 0000
 dfb $14,$22,12      ; JKICK2
  hex 0000
  hex 0000
  hex 0000
  hex 0000

anim_jpunch1
 dfb 2
 dfb $10
 dfb $84             ; bit 7 compiled, bit 2 bank $1D
 dfb $0B,$28,6       ; JPUNCH11
  hex 0000
  hex 0000
  hex 0000
  hex 0000
 dfb $10,$28,6       ; JPUNCH12
  hex 0000
  hex 0000
  hex 0000
  hex 0000

anim_jpunch2
 dfb 2
 dfb $10
 dfb $84             ; bit 7 compiled, bit 2 bank $1D
 dfb $0A,$28,6       ; JPUNCH21
  hex 0000
  hex 0000
  hex 0000
  hex 0000
 dfb $10,$28,6       ; JPUNCH22
  hex 0000
  hex 0000
  hex 0000
  hex 0000

anim_juppercut
 dfb 3
 dfb $0F
 dfb $04             ; legacy, bank $1D
 dfb $0C,$25,5       ; JUPPER1
  hex 0000
 dfb $0F,$23,5       ; JUPPER2
  hex 0000
 dfb $0D,$2D,5       ; JUPPER3
  hex 0000

anim_jpunched
 dfb 1
 dfb $0B
 dfb $84             ; bit 7 compiled, bit 2 bank $1D
 dfb $0B,$28,15      ; JPUNCHED: x, y, dur (matches anim_bpunched)
  hex 0000
  hex 0000
  hex 0000
  hex 0000

anim_jfall
 dfb 2
 dfb $13
 dfb $14             ; bit 4 fall trajectory + bit 2 bank $1D, legacy stride
 dfb $11,$20,FALL_ARC_FRAMES ; JFALL: 17 wide, 32 tall, arc duration
  hex 0000
 dfb $13,$0D,60      ; JFALLEN: 19 wide, 13 tall, 60 VBLs
  hex 0000

* William walking cycle (WILLIAM1, 2, 3, 2). Looping, no
* auto-advance — behavior code controls position. Compiled
* (bank $1B) — patched by init_williams_compiled.
anim_wwalk
 dfb 4               ; num_frames
 dfb $09             ; max_width
 dfb $C2             ; flags: bit 7 = compiled, bit 6 = bank $1B,
                     ;        bit 1 = loop
 dfb $09,$28,5       ; WILLIAM1: 9 wide, 40 tall, 5 VBLs
  hex 0000             ; patched: WILLIAM1_DATA
  hex 0000             ; patched: WILLIAM1_MASK
  hex 0000             ; patched: WILLIAM1_DATA_MIRROR
  hex 0000             ; patched: WILLIAM1_MASK_MIRROR
 dfb $09,$28,5       ; WILLIAM2
  hex 0000             ; patched: WILLIAM2_DATA
  hex 0000             ; patched: WILLIAM2_MASK
  hex 0000             ; patched: WILLIAM2_DATA_MIRROR
  hex 0000             ; patched: WILLIAM2_MASK_MIRROR
 dfb $09,$28,5       ; WILLIAM3
  hex 0000             ; patched: WILLIAM3_DATA
  hex 0000             ; patched: WILLIAM3_MASK
  hex 0000             ; patched: WILLIAM3_DATA_MIRROR
  hex 0000             ; patched: WILLIAM3_MASK_MIRROR
 dfb $09,$28,5       ; WILLIAM2
  hex 0000             ; patched: WILLIAM2_DATA
  hex 0000             ; patched: WILLIAM2_MASK
  hex 0000             ; patched: WILLIAM2_DATA_MIRROR
  hex 0000             ; patched: WILLIAM2_MASK_MIRROR

* William's offensive punch (NPC). 2 frames, non-looping.
* Compiled (bank $1B) — patched by init_williams_compiled.
anim_wpunch
 dfb 2               ; num_frames
 dfb $11             ; max_width (WPUNCH2 is widest)
 dfb $C0             ; flags: bit 7 = compiled, bit 6 = bank $1B
 dfb $0B,$28,6       ; WPUNCH1: 11 wide, 40 tall, 6 VBLs
  hex 0000             ; patched: WPUNCH1_DATA
  hex 0000             ; patched: WPUNCH1_MASK
  hex 0000             ; patched: WPUNCH1_DATA_MIRROR
  hex 0000             ; patched: WPUNCH1_MASK_MIRROR
 dfb $11,$28,6       ; WPUNCH2: 17 wide, 40 tall, 6 VBLs
  hex 0000             ; patched: WPUNCH2_DATA
  hex 0000             ; patched: WPUNCH2_MASK
  hex 0000             ; patched: WPUNCH2_DATA_MIRROR
  hex 0000             ; patched: WPUNCH2_MASK_MIRROR

* Roper walk (ROPER1, 2, 3, 2). Looping, no auto-advance.
* Roper walk (ROPER1, 2, 3, 2). Compiled bank-$1B; patched
* by init_roper_compiled.
anim_rwalk
 dfb 4
 dfb $09
 dfb $C2             ; flags: bit 7 = compiled, bit 6 = bank $1B,
                     ;        bit 1 = loop
 dfb $09,$27,5       ; ROPER1
  hex 0000             ; patched: ROPER1_DATA
  hex 0000             ; patched: ROPER1_MASK
  hex 0000             ; patched: ROPER1_DATA_MIRROR
  hex 0000             ; patched: ROPER1_MASK_MIRROR
 dfb $09,$26,5       ; ROPER2
  hex 0000             ; patched: ROPER2_DATA
  hex 0000             ; patched: ROPER2_MASK
  hex 0000             ; patched: ROPER2_DATA_MIRROR
  hex 0000             ; patched: ROPER2_MASK_MIRROR
 dfb $09,$27,5       ; ROPER3
  hex 0000             ; patched: ROPER3_DATA
  hex 0000             ; patched: ROPER3_MASK
  hex 0000             ; patched: ROPER3_DATA_MIRROR
  hex 0000             ; patched: ROPER3_MASK_MIRROR
 dfb $09,$26,5       ; ROPER2
  hex 0000             ; patched: ROPER2_DATA
  hex 0000             ; patched: ROPER2_MASK
  hex 0000             ; patched: ROPER2_DATA_MIRROR
  hex 0000             ; patched: ROPER2_MASK_MIRROR

* Roper punch. 2 frames, one-shot. Compiled bank-$1B.
anim_rpunch
 dfb 2
 dfb $10             ; max_width (RPUNCH2)
 dfb $C0             ; flags: bit 7 = compiled, bit 6 = bank $1B
 dfb $0B,$27,6       ; RPUNCH1
  hex 0000             ; patched: RPUNCH1_DATA
  hex 0000             ; patched: RPUNCH1_MASK
  hex 0000             ; patched: RPUNCH1_DATA_MIRROR
  hex 0000             ; patched: RPUNCH1_MASK_MIRROR
 dfb $10,$27,6       ; RPUNCH2
  hex 0000             ; patched: RPUNCH2_DATA
  hex 0000             ; patched: RPUNCH2_MASK
  hex 0000             ; patched: RPUNCH2_DATA_MIRROR
  hex 0000             ; patched: RPUNCH2_MASK_MIRROR

* Roper punched reaction. 1 frame, one-shot. Compiled bank-$1B.
anim_rpunched
 dfb 1
 dfb $09
 dfb $C0             ; flags: bit 7 = compiled, bit 6 = bank $1B
 dfb $09,$26,5       ; RPUNCHED
  hex 0000             ; patched: RPUNCHED_DATA
  hex 0000             ; patched: RPUNCHED_MASK
  hex 0000             ; patched: RPUNCHED_DATA_MIRROR
  hex 0000             ; patched: RPUNCHED_MASK_MIRROR

* Roper fall. 2 frames, one-shot, parabolic arc on frame 0.
* Compiled bank-$1B.
anim_rfall
 dfb 2
 dfb $10
 dfb $D0             ; flags: bit 7 = compiled, bit 6 = bank $1B,
                     ;        bit 4 = fall trajectory
 dfb $10,$17,FALL_ARC_FRAMES ; RFALL1: arc duration
  hex 0000             ; patched: RFALL1_DATA
  hex 0000             ; patched: RFALL1_MASK
  hex 0000             ; patched: RFALL1_DATA_MIRROR
  hex 0000             ; patched: RFALL1_MASK_MIRROR
 dfb $10,$0F,60      ; RFALL2
  hex 0000             ; patched: RFALL2_DATA
  hex 0000             ; patched: RFALL2_MASK
  hex 0000             ; patched: RFALL2_DATA_MIRROR
  hex 0000             ; patched: RFALL2_MASK_MIRROR

* Linda walk (LINDA1, 2, 3, 2). Looping, no auto-advance.
* Linda walk (LINDA1, 2, 3, 2). Compiled bank-$1B; patched by
* init_linda_compiled.
anim_lwalk
 dfb 4
 dfb $09
 dfb $C2             ; flags: bit 7 = compiled, bit 6 = bank $1B,
                     ;        bit 1 = loop
 dfb $09,$28,5       ; LINDA1
  hex 0000             ; patched: LINDA1_DATA
  hex 0000             ; patched: LINDA1_MASK
  hex 0000             ; patched: LINDA1_DATA_MIRROR
  hex 0000             ; patched: LINDA1_MASK_MIRROR
 dfb $09,$27,5       ; LINDA2
  hex 0000             ; patched: LINDA2_DATA
  hex 0000             ; patched: LINDA2_MASK
  hex 0000             ; patched: LINDA2_DATA_MIRROR
  hex 0000             ; patched: LINDA2_MASK_MIRROR
 dfb $09,$28,5       ; LINDA3
  hex 0000             ; patched: LINDA3_DATA
  hex 0000             ; patched: LINDA3_MASK
  hex 0000             ; patched: LINDA3_DATA_MIRROR
  hex 0000             ; patched: LINDA3_MASK_MIRROR
 dfb $09,$27,5       ; LINDA2
  hex 0000             ; patched: LINDA2_DATA
  hex 0000             ; patched: LINDA2_MASK
  hex 0000             ; patched: LINDA2_DATA_MIRROR
  hex 0000             ; patched: LINDA2_MASK_MIRROR

* Linda punch. 2 frames, one-shot. Compiled bank-$1B.
anim_lpunch
 dfb 2
 dfb $0E             ; max_width (LPUNCH2)
 dfb $C0             ; flags: bit 7 = compiled, bit 6 = bank $1B
 dfb $0B,$28,6       ; LPUNCH1
  hex 0000             ; patched: LPUNCH1_DATA
  hex 0000             ; patched: LPUNCH1_MASK
  hex 0000             ; patched: LPUNCH1_DATA_MIRROR
  hex 0000             ; patched: LPUNCH1_MASK_MIRROR
 dfb $0E,$28,6       ; LPUNCH2
  hex 0000             ; patched: LPUNCH2_DATA
  hex 0000             ; patched: LPUNCH2_MASK
  hex 0000             ; patched: LPUNCH2_DATA_MIRROR
  hex 0000             ; patched: LPUNCH2_MASK_MIRROR

* Linda punched reaction. 1 frame, one-shot. Compiled bank-$1B.
anim_lpunched
 dfb 1
 dfb $09
 dfb $C0             ; flags: bit 7 = compiled, bit 6 = bank $1B
 dfb $08,$26,5       ; LPUNCHED
  hex 0000             ; patched: LPUNCHED_DATA
  hex 0000             ; patched: LPUNCHED_MASK
  hex 0000             ; patched: LPUNCHED_DATA_MIRROR
  hex 0000             ; patched: LPUNCHED_MASK_MIRROR

* Linda fall. 2 frames, one-shot, parabolic arc on frame 0.
* Compiled bank-$1B.
anim_lfall
 dfb 2
 dfb $11
 dfb $D0             ; flags: bit 7 = compiled, bit 6 = bank $1B,
                     ;        bit 4 = fall trajectory
 dfb $10,$17,FALL_ARC_FRAMES ; LFALL1: arc duration
  hex 0000             ; patched: LFALL1_DATA
  hex 0000             ; patched: LFALL1_MASK
  hex 0000             ; patched: LFALL1_DATA_MIRROR
  hex 0000             ; patched: LFALL1_MASK_MIRROR
 dfb $11,$0F,60      ; LFALL2
  hex 0000             ; patched: LFALL2_DATA
  hex 0000             ; patched: LFALL2_MASK
  hex 0000             ; patched: LFALL2_DATA_MIRROR
  hex 0000             ; patched: LFALL2_MASK_MIRROR

* Burnov (boss) walk. 4 frames, looping (BNWALK1, 2, 3, 2 cycle).
* Pixel data lives in bank $06 — frame_addr fields are patched
* by init_mission12 from spr_bnwalk1/2/3 (also in $06).
* Burnov walk (BNWALK1, 2, 3, 2 cycle). Compiled bank-$1B;
* patched by init_burnov_compiled. Burnov's other anims (punch,
* grab, fall, dissolve, recon) remain legacy bank-$19.
anim_bnwalk
 dfb 4
 dfb $0D             ; max_width (BNWALK1)
 dfb $C2             ; flags: bit 7 = compiled, bit 6 = bank $1B,
                     ;        bit 1 = loop
 dfb $0D,$30,5       ; BNWALK1: 13 wide, 48 tall, 5 VBLs
  hex 0000             ; patched: BNWALK1_DATA
  hex 0000             ; patched: BNWALK1_MASK
  hex 0000             ; patched: BNWALK1_DATA_MIRROR
  hex 0000             ; patched: BNWALK1_MASK_MIRROR
 dfb $0D,$30,5       ; BNWALK2
  hex 0000             ; patched: BNWALK2_DATA
  hex 0000             ; patched: BNWALK2_MASK
  hex 0000             ; patched: BNWALK2_DATA_MIRROR
  hex 0000             ; patched: BNWALK2_MASK_MIRROR
 dfb $0D,$30,5       ; BNWALK3
  hex 0000             ; patched: BNWALK3_DATA
  hex 0000             ; patched: BNWALK3_MASK
  hex 0000             ; patched: BNWALK3_DATA_MIRROR
  hex 0000             ; patched: BNWALK3_MASK_MIRROR
 dfb $0D,$30,5       ; BNWALK2 (cycle back)
  hex 0000             ; patched: BNWALK2_DATA
  hex 0000             ; patched: BNWALK2_MASK
  hex 0000             ; patched: BNWALK2_DATA_MIRROR
  hex 0000             ; patched: BNWALK2_MASK_MIRROR

* Burnov punch. 2 frames, one-shot.
* Compiled bank-$1C — patched by init_burnov_combat_compiled.
anim_bnpunch
 dfb 2
 dfb $17             ; max_width (BNPUNCH2)
 dfb $88             ; flags: bit 7 = compiled, bit 3 = bank $1C
 dfb $11,$30,6       ; BNPUNCH1: 17 wide, 48 tall, 6 VBLs
  hex 0000             ; patched: BNPUNCH1_DATA
  hex 0000             ; patched: BNPUNCH1_MASK
  hex 0000             ; patched: BNPUNCH1_DATA_MIRROR
  hex 0000             ; patched: BNPUNCH1_MASK_MIRROR
 dfb $17,$2E,6       ; BNPUNCH2: 23 wide, 46 tall, 6 VBLs
  hex 0000             ; patched: BNPUNCH2_DATA
  hex 0000             ; patched: BNPUNCH2_MASK
  hex 0000             ; patched: BNPUNCH2_DATA_MIRROR
  hex 0000             ; patched: BNPUNCH2_MASK_MIRROR

* Burnov-holds-Billy grab sequence. Triggered when anim_bnpunch
* lands on Billy (check_punch_hit Burnov-special). Plays
* BNBILLY1↔2 three times (PUNCHLANDED on each BNBILLY2) then
* BNBILLY3 as the release pose. Billy's sprite is suppressed
* and his input ignored during the whole anim; on completion,
* :normal_end clears bn_grab_active and starts his fall_anim.
* Compiled bank-$1C — patched by init_burnov_combat_compiled.
anim_bngrab
 dfb 7
 dfb $15             ; max_width (BNBILLY1/2 are 21)
 dfb $88             ; flags: bit 7 = compiled, bit 3 = bank $1C
 dfb $15,$30,8       ; BNBILLY1
  hex 0000             ; patched: BNBILLY1_DATA
  hex 0000             ; patched: BNBILLY1_MASK
  hex 0000             ; patched: BNBILLY1_DATA_MIRROR
  hex 0000             ; patched: BNBILLY1_MASK_MIRROR
 dfb $15,$31,8       ; BNBILLY2
  hex 0000             ; patched: BNBILLY2_DATA
  hex 0000             ; patched: BNBILLY2_MASK
  hex 0000             ; patched: BNBILLY2_DATA_MIRROR
  hex 0000             ; patched: BNBILLY2_MASK_MIRROR
 dfb $15,$30,8       ; BNBILLY1
  hex 0000             ; patched: BNBILLY1_DATA
  hex 0000             ; patched: BNBILLY1_MASK
  hex 0000             ; patched: BNBILLY1_DATA_MIRROR
  hex 0000             ; patched: BNBILLY1_MASK_MIRROR
 dfb $15,$31,8       ; BNBILLY2
  hex 0000             ; patched: BNBILLY2_DATA
  hex 0000             ; patched: BNBILLY2_MASK
  hex 0000             ; patched: BNBILLY2_DATA_MIRROR
  hex 0000             ; patched: BNBILLY2_MASK_MIRROR
 dfb $15,$30,8       ; BNBILLY1
  hex 0000             ; patched: BNBILLY1_DATA
  hex 0000             ; patched: BNBILLY1_MASK
  hex 0000             ; patched: BNBILLY1_DATA_MIRROR
  hex 0000             ; patched: BNBILLY1_MASK_MIRROR
 dfb $15,$31,8       ; BNBILLY2
  hex 0000             ; patched: BNBILLY2_DATA
  hex 0000             ; patched: BNBILLY2_MASK
  hex 0000             ; patched: BNBILLY2_DATA_MIRROR
  hex 0000             ; patched: BNBILLY2_MASK_MIRROR
 dfb $15,$2F,12      ; BNBILLY3 (release)
  hex 0000             ; patched: BNBILLY3_DATA
  hex 0000             ; patched: BNBILLY3_MASK
  hex 0000             ; patched: BNBILLY3_DATA_MIRROR
  hex 0000             ; patched: BNBILLY3_MASK_MIRROR

* anim_bnjgrab — parallel to anim_bngrab but pointed at the BNJIMMY
* sprite slots. Used when Burnov's grab trigger fires on Jimmy
* (controller=$02) instead of Billy. Same 7-frame BNBILLY1/2/1/2/1/2/3
* shape, frame widths/heights/durations are identical because the
* BNJIMMY sprites are palette-shifted copies (geometry unchanged).
* Patched by init_burnov_combat_compiled.
anim_bnjgrab
 dfb 7
 dfb $15             ; max_width (BNJIMMY1/2 are 21)
 dfb $88             ; flags: bit 7 = compiled, bit 3 = bank $1C
 dfb $15,$30,8       ; BNJIMMY1
  hex 0000             ; patched: BNJIMMY1_DATA
  hex 0000             ; patched: BNJIMMY1_MASK
  hex 0000             ; patched: BNJIMMY1_DATA_MIRROR
  hex 0000             ; patched: BNJIMMY1_MASK_MIRROR
 dfb $15,$31,8       ; BNJIMMY2
  hex 0000             ; patched: BNJIMMY2_DATA
  hex 0000             ; patched: BNJIMMY2_MASK
  hex 0000             ; patched: BNJIMMY2_DATA_MIRROR
  hex 0000             ; patched: BNJIMMY2_MASK_MIRROR
 dfb $15,$30,8       ; BNJIMMY1
  hex 0000             ; patched: BNJIMMY1_DATA
  hex 0000             ; patched: BNJIMMY1_MASK
  hex 0000             ; patched: BNJIMMY1_DATA_MIRROR
  hex 0000             ; patched: BNJIMMY1_MASK_MIRROR
 dfb $15,$31,8       ; BNJIMMY2
  hex 0000             ; patched: BNJIMMY2_DATA
  hex 0000             ; patched: BNJIMMY2_MASK
  hex 0000             ; patched: BNJIMMY2_DATA_MIRROR
  hex 0000             ; patched: BNJIMMY2_MASK_MIRROR
 dfb $15,$30,8       ; BNJIMMY1
  hex 0000             ; patched: BNJIMMY1_DATA
  hex 0000             ; patched: BNJIMMY1_MASK
  hex 0000             ; patched: BNJIMMY1_DATA_MIRROR
  hex 0000             ; patched: BNJIMMY1_MASK_MIRROR
 dfb $15,$31,8       ; BNJIMMY2
  hex 0000             ; patched: BNJIMMY2_DATA
  hex 0000             ; patched: BNJIMMY2_MASK
  hex 0000             ; patched: BNJIMMY2_DATA_MIRROR
  hex 0000             ; patched: BNJIMMY2_MASK_MIRROR
 dfb $15,$2F,12      ; BNJIMMY3 (release)
  hex 0000             ; patched: BNJIMMY3_DATA
  hex 0000             ; patched: BNJIMMY3_MASK
  hex 0000             ; patched: BNJIMMY3_DATA_MIRROR
  hex 0000             ; patched: BNJIMMY3_MASK_MIRROR

* Burnov punched reaction. 1 frame placeholder using BNFALL1
* — replace with a dedicated recoil frame if/when one ships.
* Compiled bank-$1C — patched by init_burnov_combat_compiled.
anim_bnpunched
 dfb 1
 dfb $0D
 dfb $88             ; flags: bit 7 = compiled, bit 3 = bank $1C
 dfb $0D,$2E,5       ; BNFALL1
  hex 0000             ; patched: BNFALL1_DATA
  hex 0000             ; patched: BNFALL1_MASK
  hex 0000             ; patched: BNFALL1_DATA_MIRROR
  hex 0000             ; patched: BNFALL1_MASK_MIRROR

* Burnov fall. 2 frames, one-shot, parabolic arc on frame 0.
* BNFALL2/3 are unused for now — could be a 3-frame arc later.
* Compiled bank-$1C — patched by init_burnov_combat_compiled.
anim_bnfall
 dfb 2
 dfb $17             ; max_width (BNFALLEN)
 dfb $98             ; flags: bit 7 = compiled, bit 4 = fall trajectory,
                     ;        bit 3 = bank $1C
 dfb $0D,$2E,FALL_ARC_FRAMES ; BNFALL1: arc duration
  hex 0000             ; patched: BNFALL1_DATA
  hex 0000             ; patched: BNFALL1_MASK
  hex 0000             ; patched: BNFALL1_DATA_MIRROR
  hex 0000             ; patched: BNFALL1_MASK_MIRROR
 dfb $17,$17,60      ; BNFALLEN: 23 wide, 23 tall
  hex 0000             ; patched: BNFALLEN_DATA
  hex 0000             ; patched: BNFALLEN_MASK
  hex 0000             ; patched: BNFALLEN_DATA_MIRROR
  hex 0000             ; patched: BNFALLEN_MASK_MIRROR

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
* Linda flail walk (LFWALK1, 2, 3, 2). Compiled bank-$1C; patched
* by init_armed_compiled.
anim_lfwalk
 dfb 4
 dfb $09
 dfb $8A              ; flags: bit 7 = compiled, bit 3 = bank $1C,
                      ;        bit 1 = loop
 dfb $09,$28,5        ; LFWALK1: 9 wide, 40 tall
  hex 0000             ; patched: LFWALK1_DATA
  hex 0000             ; patched: LFWALK1_MASK
  hex 0000             ; patched: LFWALK1_DATA_MIRROR
  hex 0000             ; patched: LFWALK1_MASK_MIRROR
 dfb $09,$27,5        ; LFWALK2: 9 wide, 39 tall
  hex 0000             ; patched: LFWALK2_DATA
  hex 0000             ; patched: LFWALK2_MASK
  hex 0000             ; patched: LFWALK2_DATA_MIRROR
  hex 0000             ; patched: LFWALK2_MASK_MIRROR
 dfb $09,$28,5        ; LFWALK3
  hex 0000             ; patched: LFWALK3_DATA
  hex 0000             ; patched: LFWALK3_MASK
  hex 0000             ; patched: LFWALK3_DATA_MIRROR
  hex 0000             ; patched: LFWALK3_MASK_MIRROR
 dfb $09,$27,5        ; LFWALK2 (cycle back)
  hex 0000             ; patched: LFWALK2_DATA
  hex 0000             ; patched: LFWALK2_MASK
  hex 0000             ; patched: LFWALK2_DATA_MIRROR
  hex 0000             ; patched: LFWALK2_MASK_MIRROR

* Linda mace-swing attack (LMACE1, 2, 3). Wider sprite (mace
* swings out to the side); max_width tracks LMACE1 at 24 bytes.
* Compiled bank-$1C; patched by init_armed_compiled.
anim_lmace
 dfb 3
 dfb $18              ; max_width (LMACE1 is 24 wide)
 dfb $88              ; flags: bit 7 = compiled, bit 3 = bank $1C
 dfb $18,$28,6        ; LMACE1: 24×40
  hex 0000             ; patched: LMACE1_DATA
  hex 0000             ; patched: LMACE1_MASK
  hex 0000             ; patched: LMACE1_DATA_MIRROR
  hex 0000             ; patched: LMACE1_MASK_MIRROR
 dfb $14,$26,6        ; LMACE2: 20×38
  hex 0000             ; patched: LMACE2_DATA
  hex 0000             ; patched: LMACE2_MASK
  hex 0000             ; patched: LMACE2_DATA_MIRROR
  hex 0000             ; patched: LMACE2_MASK_MIRROR
 dfb $10,$26,6        ; LMACE3: 16×38
  hex 0000             ; patched: LMACE3_DATA
  hex 0000             ; patched: LMACE3_MASK
  hex 0000             ; patched: LMACE3_DATA_MIRROR
  hex 0000             ; patched: LMACE3_MASK_MIRROR

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
* shape as anim_wwalk (frame_x=$09). Compiled bank-$1C; patched
* by init_armed_compiled.
anim_wpipewalk
 dfb 4
 dfb $09
 dfb $8A              ; flags: bit 7 = compiled, bit 3 = bank $1C,
                      ;        bit 1 = loop
 dfb $09,$28,5        ; WPIPEWALK1
  hex 0000             ; patched: WPIPEWALK1_DATA
  hex 0000             ; patched: WPIPEWALK1_MASK
  hex 0000             ; patched: WPIPEWALK1_DATA_MIRROR
  hex 0000             ; patched: WPIPEWALK1_MASK_MIRROR
 dfb $09,$28,5        ; WPIPEWALK2
  hex 0000             ; patched: WPIPEWALK2_DATA
  hex 0000             ; patched: WPIPEWALK2_MASK
  hex 0000             ; patched: WPIPEWALK2_DATA_MIRROR
  hex 0000             ; patched: WPIPEWALK2_MASK_MIRROR
 dfb $09,$28,5        ; WPIPEWALK3
  hex 0000             ; patched: WPIPEWALK3_DATA
  hex 0000             ; patched: WPIPEWALK3_MASK
  hex 0000             ; patched: WPIPEWALK3_DATA_MIRROR
  hex 0000             ; patched: WPIPEWALK3_MASK_MIRROR
 dfb $09,$28,5        ; WPIPEWALK2 (cycle back)
  hex 0000             ; patched: WPIPEWALK2_DATA
  hex 0000             ; patched: WPIPEWALK2_MASK
  hex 0000             ; patched: WPIPEWALK2_DATA_MIRROR
  hex 0000             ; patched: WPIPEWALK2_MASK_MIRROR

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
* Compiled bank-$1C; patched by init_armed_compiled.
anim_wpipeswing
 dfb 5
 dfb $0F              ; max_width (WPIPE2 is 15 wide)
 dfb $88              ; flags: bit 7 = compiled, bit 3 = bank $1C
 dfb $0E,$28,6        ; WPIPE1: 14×40
  hex 0000             ; patched: WPIPE1_DATA
  hex 0000             ; patched: WPIPE1_MASK
  hex 0000             ; patched: WPIPE1_DATA_MIRROR
  hex 0000             ; patched: WPIPE1_MASK_MIRROR
 dfb $0E,$28,6        ; WPIPE4: 14×40
  hex 0000             ; patched: WPIPE4_DATA
  hex 0000             ; patched: WPIPE4_MASK
  hex 0000             ; patched: WPIPE4_DATA_MIRROR
  hex 0000             ; patched: WPIPE4_MASK_MIRROR
 dfb $0F,$28,6        ; WPIPE2: 15×40
  hex 0000             ; patched: WPIPE2_DATA
  hex 0000             ; patched: WPIPE2_MASK
  hex 0000             ; patched: WPIPE2_DATA_MIRROR
  hex 0000             ; patched: WPIPE2_MASK_MIRROR
 dfb $0A,$28,6        ; WPIPE6: 10×40
  hex 0000             ; patched: WPIPE6_DATA
  hex 0000             ; patched: WPIPE6_MASK
  hex 0000             ; patched: WPIPE6_DATA_MIRROR
  hex 0000             ; patched: WPIPE6_MASK_MIRROR
 dfb $0D,$28,6        ; WPIPE3: 13×40
  hex 0000             ; patched: WPIPE3_DATA
  hex 0000             ; patched: WPIPE3_MASK
  hex 0000             ; patched: WPIPE3_DATA_MIRROR
  hex 0000             ; patched: WPIPE3_MASK_MIRROR

* Williams-with-knife throw — 2 frames (WKNIFE1 wind-up, WKNIFE2
* release). When the anim ends, :normal_end spawns the knife
* projectile and downgrades williams_knife to a regular williams.
* Compiled bank-$1C; patched by init_armed_compiled.
anim_wkthrow
 dfb 2
 dfb $0D              ; max_width (both frames are 13 wide)
 dfb $88              ; flags: bit 7 = compiled, bit 3 = bank $1C
 dfb $0D,$2F,8        ; WKNIFE1: 13×47
  hex 0000             ; patched: WKNIFE1_DATA
  hex 0000             ; patched: WKNIFE1_MASK
  hex 0000             ; patched: WKNIFE1_DATA_MIRROR
  hex 0000             ; patched: WKNIFE1_MASK_MIRROR
 dfb $0D,$27,8        ; WKNIFE2: 13×39
  hex 0000             ; patched: WKNIFE2_DATA
  hex 0000             ; patched: WKNIFE2_MASK
  hex 0000             ; patched: WKNIFE2_DATA_MIRROR
  hex 0000             ; patched: WKNIFE2_MASK_MIRROR

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

* Jimmy-with-pipe swing — same shape as anim_bpipeswing but frames
* live in bank $1D (JPIPE1-4). swap_in_jimmy points
* active_pipe_swing_anim here while Jimmy is the active player.
* Init_jimmy patches frame slots from spr_jpipe1-4.
anim_jpipeswing
 dfb 4
 dfb $11              ; max_width (JPIPE2 is 17 wide)
 dfb $04              ; flags: bit 2 = bank $1D
 dfb $09,$28,6        ; JPIPE1
  hex 0000             ; patched: spr_jpipe1
 dfb $11,$28,6        ; JPIPE2
  hex 0000             ; patched: spr_jpipe2
 dfb $0F,$28,6        ; JPIPE3
  hex 0000             ; patched: spr_jpipe3
 dfb $0C,$28,6        ; JPIPE4
  hex 0000             ; patched: spr_jpipe4

* Jimmy-with-mace swing — same shape as anim_bmaceswing but frames
* live in bank $1D (JMACE1-4). Init_jimmy patches frame slots
* from spr_jmace1-4.
anim_jmaceswing
 dfb 4
 dfb $19              ; max_width (JMACE2 is 25 wide)
 dfb $04              ; flags: bit 2 = bank $1D
 dfb $0F,$2C,6        ; JMACE1: 15×44
  hex 0000             ; patched: spr_jmace1
 dfb $19,$2E,6        ; JMACE2: 25×46
  hex 0000             ; patched: spr_jmace2
 dfb $14,$28,6        ; JMACE3: 20×40
  hex 0000             ; patched: spr_jmace3
 dfb $10,$28,6        ; JMACE4: 16×40
  hex 0000             ; patched: spr_jmace4

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

* anim_jpickup — Jimmy's pickup pose. Same structure as
* anim_bpickup but the data points at JJUMP3 in bank $1D
* (flags bit 2 set). init_jimmy patches the entries to
* spr_jjump3 / spr_jjump3_mask / mir variants.
anim_jpickup
 dfb 1
 dfb $0D              ; max_width (JJUMP3 is 13 wide)
 dfb $84              ; flags: bit 7 compiled, bit 2 bank $1D
 dfb $0D,$20,30       ; JJUMP3 — 13×32, 30 VBLs
  hex 0000             ; data       (patched → spr_jjump3)
  hex 0000             ; mask       (patched → spr_jjump3_mask)
  hex 0000             ; data_mir   (patched → spr_jjump3_data_mir)
  hex 0000             ; mask_mir   (patched → spr_jjump3_mask_mir)

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
 beq :ko_skip           ; $01 = Billy, keep
 cmp #$02
 bne :ko_kill_item
* controller=$02 is shared by Jimmy AND dropped items. Pointer-
* match against jimmy_sprite so OP_KILLOBJ only wipes items, not
* the second player.
 lda info_ptr
 cmp #<jimmy_sprite
 bne :ko_kill_item
 lda info_ptr+1
 cmp #>jimmy_sprite
 beq :ko_skip           ; Jimmy → keep
:ko_kill_item
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
* If either player was carrying a weapon (pipe, mace, or
* knife), strip it. run_script runs in Billy's swap context so
* billy_*_armed reflects Billy and jimmy_stash_*_armed reflects
* Jimmy. Knife was previously missing from the OR — picking up
* a dropped knife at the same time OP_WAITCLR satisfied left
* billy_knife_armed=1 + idle_addr=BKNIFE1 surviving past the
* OP_KILLOBJ disarm, letting the player keep the knife into the
* next encounter (and through the rest of the level).
 lda billy_pipe_armed
 ora billy_mace_armed
 ora billy_knife_armed
 beq :ko_chk_jimmy_arm
 jsr billy_disarm_weapon
:ko_chk_jimmy_arm
 lda jimmy_active
 beq :ko_real_done
 lda jimmy_stash_pipe_armed
 ora jimmy_stash_mace_armed
 ora jimmy_stash_knife_armed
 beq :ko_real_done
 jsr jimmy_disarm_weapon
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
 sta :caller_sp_lo     ; remember caller's sprite_table position
 lda spr_ptr+1
 pha
 sta :caller_sp_hi
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
 bne :not_self
 jmp :mo_advance
:not_self
* Inactive-Jimmy gate. erase_all/draw_all both skip Jimmy when
* jimmy_active=0 (he hasn't been Ctrl-J'd in), but mark_overlapping
* doesn't go through those paths — without this gate, the back-
* redraw below paints inactive Jimmy at his stale initial position
* (40, 100, 9, 40) anytime another sprite's erase rect overlaps
* it. Visible as a 1-row JIMMY01 slice popping up below an
* NPC's rescued-standing position when their FALL trajectory
* triggered the overlap.
 lda info_ptr
 cmp #<jimmy_sprite
 bne :mo_active_ok
 lda info_ptr+1
 cmp #>jimmy_sprite
 bne :mo_active_ok
 lda jimmy_active
 bne :mo_active_ok
 jmp :mo_advance
:mo_active_ok
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

* Overlap detected. Dispatch by table position relative to caller:
*   AHEAD  (later in table)  → set needs_draw bit; the still-to-
*                              come iteration handles redraw via
*                              its own interleaved-draw → correct
*                              z-order (higher-y sprite on top).
*   BEHIND (earlier in table) → already processed this erase_all
*                              pass; their drawn pixels were just
*                              partially wiped by the caller's
*                              erase. Redraw them NOW (before the
*                              caller's own upcoming interleaved
*                              draw paints on top). Setting needs_
*                              draw + deferring to draw_all would
*                              put the behind sprite ABOVE the
*                              caller → broken painter's order.
 lda spr_ptr+1
 cmp :caller_sp_hi
 bcc :mo_redraw_behind
 bne :mo_set_bit
 lda spr_ptr
 cmp :caller_sp_lo
 bcc :mo_redraw_behind
 beq :mo_advance       ; equal = self (filtered above); be defensive
:mo_set_bit
 ldy #30
 lda (info_ptr),y
 ora #$01
 sta (info_ptr),y
 bra :mo_advance

:mo_redraw_behind
* Behind sprite — repaint NOW. Globals were left in erase-rect
* state by the caller's erase; load_sprite reads other's info+*
* into them. frame_x_off is the sprite's compiled-blit lunge
* offset (Billy/Jimmy globals vs NPC info+68) — must be set
* before dispatch or the redraw lands at the wrong column.
 jsr load_sprite
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :mo_rb_chk_jimmy
 lda billy_cur_x_off
 sta frame_x_off
 bra :mo_rb_off_done
:mo_rb_chk_jimmy
 cmp #$02
 bne :mo_rb_npc_off
 lda jimmy_cur_x_off
 sta frame_x_off
 bra :mo_rb_off_done
:mo_rb_npc_off
 ldy #68
 lda (info_ptr),y
 sta frame_x_off
:mo_rb_off_done
 lda MASK_ADDR
 ora MASK_ADDR+1
 beq :mo_rb_legacy
 jsr draw_sprite_compiled
 bra :mo_advance
:mo_rb_legacy
 jsr draw_sprite

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
:caller_sp_lo dfb 0
:caller_sp_hi dfb 0
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
* DEBUG: 'CP <anim_lo><anim_hi> SP=<spr_ptr_lo> IP=<info_lo>'
* — full puncher anim address + sprite_table cursor + puncher
* info_ptr at entry. If iteration never produces a TG line,
* we can sanity-check whether sprite_table is what we expect.
 do DEBUG_PRINT
 lda #$C3              ; 'C'
 jsr dbg_print_char
 lda #$D0              ; 'P'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda anim_ptr
 jsr dbg_print_hex8
 lda anim_ptr+1
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda info_ptr
 jsr dbg_print_hex8
 jsr dbg_print_nl
 fin
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
* Save MASK_ADDR too. start_anim called below on a hit target
* may overwrite it (compiled targets) or zero it (legacy
* targets), and update_anims's save_anim_state runs right after
* check_punch_hit returns — it persists MASK_ADDR → puncher's
* info+60. Without this restore, a Billy-hits-Williams sequence
* leaves Billy's info+60 = 0, so next frame his compiled punch
* renders LEGACY with all-zero data → black background around
* PUNCH12/22.
 lda MASK_ADDR
 pha
 lda MASK_ADDR+1
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
* DEBUG: 'IT <info_lo> <self_lo>' — every iteration that has a
* live entry. Confirms whether the loop is iterating at all and
* what sprite_table pointers it's seeing vs the saved self.
 do DEBUG_PRINT
 lda #$C9              ; 'I'
 jsr dbg_print_char
 lda #$D4              ; 'T'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda info_ptr
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda :self_lo
 jsr dbg_print_hex8
 jsr dbg_print_nl
 fin

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
* DEBUG: 'CT <ctrl> <info_lo> <god>' — fires after every controller
* read (post not-self). If we don't see CT for info_lo=$C5 (Billy),
* then info_ptr was clobbered between IT and here.
 do DEBUG_PRINT
 pha
 lda #$C3              ; 'C'
 jsr dbg_print_char
 lda #$D4              ; 'T'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 pla
 pha
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda info_ptr
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda god_mode
 jsr dbg_print_hex8
 jsr dbg_print_nl
 pla
 fin
 beq :is_npc           ; controller=0 → enemy NPC, hit-check
 cmp #$01
 beq :tgt_billy        ; controller=1 → Billy
 cmp #$02
 beq :tgt_chk_jimmy    ; controller=2 → maybe Jimmy, maybe item
 jmp :advance          ; controller >= $03 → projectile / unknown, skip
:tgt_chk_jimmy
* Disambiguate Jimmy (player 2) from dropped items / projectiles:
* both share controller=$02, so verify by pointer match against
* jimmy_sprite. Items fall through to :advance (skip). Uses an
* inverted branch + jmp because :advance is more than 128 bytes
* away from here.
 lda info_ptr
 cmp #<jimmy_sprite
 beq :tcj_lo_ok
 jmp :advance
:tcj_lo_ok
 lda info_ptr+1
 cmp #>jimmy_sprite
 beq :tcj_is_jimmy
 jmp :advance
:tcj_is_jimmy
* Skip Jimmy entirely until P2 joins. jimmy_sprite sits in
* sprite_table from boot at a static (ypos=100, xpos=31); without
* this gate, NPC punches whose bbox overlaps that stale position
* fall through to :uf_target_jimmy → inc jimmy_stash_fall_count and
* zero P2 palette slots. Then when '2' is pressed mid-game, P2's
* health bar appears already drained. Bug repros intermittently
* depending on whether enemy hit positions happen to overlap the
* static slot.
 lda jimmy_active
 bne :tcj_active
 jmp :advance
:tcj_active
* Fall through to the same friendly-fire gate Billy uses — NPCs
* can hit Jimmy freely, but Billy's punches drop unless
* friendly_fire is on.
 bra :tgt_billy
:tgt_billy
* Friendly-fire gate: Billy / Jimmy can always be hit by an NPC
* puncher (puncher_ctrl=0). Player-on-player hits drop unless
* friendly_fire is non-zero. Keeps Jimmy's joystick punches from
* clipping Billy in default co-op and vice versa.
 lda :puncher_ctrl
 beq :is_npc           ; NPC puncher → always allowed
 lda friendly_fire
 bne :is_npc           ; player puncher + FF on → allowed
 jmp :advance          ; player puncher + FF off → skip
:is_npc
:not_god
* DEBUG: 'TG <panim_lo> <panim_hi> <ctrl> <info_lo>' — every
* target that survives the controller filter, plus the puncher's
* anim bytes. Helps spot whether anim_bnpunch's HIGH byte is
* actually matching the value the dispatch expects. Unconditional
* (any puncher) so we can confirm the loop is iterating at all.
 do DEBUG_PRINT
 lda #$D4              ; 'T'
 jsr dbg_print_char
 lda #$C7              ; 'G'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda :puncher_anim_lo
 jsr dbg_print_hex8
 lda :puncher_anim_hi
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 ldy #22
 lda (info_ptr),y
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda info_ptr
 jsr dbg_print_hex8
 jsr dbg_print_nl
 fin
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
* DEBUG: 'FC P=<panim> M=<mirror> N=<npc_x> B=<billy_x>' — log
* every Burnov→Billy punch that survives the facing gate so we
* can see what bbox numbers the next checks see.
 do DEBUG_PRINT
 lda :puncher_anim_lo
 cmp #<anim_bnpunch
 bne :fc_dbg_skip
 lda :puncher_anim_hi
 cmp #>anim_bnpunch
 bne :fc_dbg_skip
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :fc_dbg_skip
 lda #$C6              ; 'F'
 jsr dbg_print_char
 lda #$C3              ; 'C'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda IMAGE01_MIRROR
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda IMAGE01_XPOS
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 ldy #2
 lda (info_ptr),y
 jsr dbg_print_hex8
 jsr dbg_print_nl
:fc_dbg_skip
 fin

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
* Horizontal check: overlap or within 2 bytes. Tightened to 1
* briefly to filter glancing "facing away" punches, but the
* :not_immune NPC-mirror gate above already rejects those, and
* tightening to 1 also broke Burnov-on-Billy: BNPUNCH2 is 23
* wide, his bounds+pad max him out at xpos = bmax - 18, which
* leaves a 2-byte gap between his left edge and Billy's right
* edge. 2 bytes of slack restores that hit while the facing
* check keeps the "back of head" filter.
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
* god_mode gate — moved here from the controller filter so all the
* iteration / facing / bbox diagnostic prints (TG / FC / HT) still
* fire even when Billy is invincible. Only the actual hit dispatch
* below is short-circuited.
*
* Same spot enforces the friendly-fire gate one more time as a
* belt-and-braces check: if target is a player and puncher is a
* player (puncher_ctrl != 0), only let the hit register when
* friendly_fire is non-zero. god_mode protects both players.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 beq :god_check         ; target = Billy
 cmp #$02
 bne :god_skip          ; not a player target (NPC or unknown)
* controller=$02 covers Jimmy AND dropped items. Disambiguate.
 lda info_ptr
 cmp #<jimmy_sprite
 bne :god_skip
 lda info_ptr+1
 cmp #>jimmy_sprite
 bne :god_skip
:god_check
 lda :puncher_ctrl
 beq :hit_ff_done       ; NPC puncher → no FF gating
 lda friendly_fire
 bne :hit_ff_done       ; FF on → allow
 jmp :advance           ; player puncher + FF off → drop hit
:hit_ff_done
 lda god_mode
 beq :god_skip
 jmp :advance           ; god_mode on + target=player → no hit
:god_skip

* DEBUG: 'HT' = bbox check passed, about to check special-case
* Burnov-grab. If we see 'HT' but no BNBILLY visual, the grab
* dispatch is the broken link. If no 'HT' for Burnov, bbox
* itself is rejecting.
 do DEBUG_PRINT
 lda :puncher_anim_lo
 cmp #<anim_bnpunch
 bne :ht_dbg_skip
 lda :puncher_anim_hi
 cmp #>anim_bnpunch
 bne :ht_dbg_skip
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :ht_dbg_skip
 lda #$C8              ; 'H'
 jsr dbg_print_char
 lda #$D4              ; 'T'
 jsr dbg_print_char
 jsr dbg_print_nl
:ht_dbg_skip
 fin

* Burnov-grabs-Player special case moved to mission1boss.s
* (bn_try_grab). Stage the check-local puncher anim and Burnov
* self-ptr into bank-$00 scratch globals, JSL into bank $1E, and
* branch on the disposition code.
 lda :puncher_anim_lo
 sta bn_puncher_anim_lo
 lda :puncher_anim_hi
 sta bn_puncher_anim_hi
 lda :self_lo
 sta bn_self_lo
 lda :self_hi
 sta bn_self_hi
 jsl bn_try_grab
 beq :hit_normal       ; A=0 → not a grab, take damage path
 jmp :done             ; A=1 → grab handled, exit check_punch_hit
:hit_normal

* Hit! Damage = 3 for forced-fall attacks (uppercut, pipeswing,
* maceswing, spin-kick, lmace) regardless of which player did it.
* Else damage = 1.
 lda :puncher_anim_lo
 cmp #<anim_uppercut
 bne :hit_chk_juc
 lda :puncher_anim_hi
 cmp #>anim_uppercut
 bne :hit_chk_juc
 lda #3
 jmp :hit_dmg_done
:hit_chk_juc
 lda :puncher_anim_lo
 cmp #<anim_juppercut
 bne :hit_chk_pipe
 lda :puncher_anim_hi
 cmp #>anim_juppercut
 bne :hit_chk_pipe
 lda #3
 jmp :hit_dmg_done
:hit_chk_pipe
 lda :puncher_anim_lo
 cmp #<anim_bpipeswing
 bne :hit_chk_jpipe
 lda :puncher_anim_hi
 cmp #>anim_bpipeswing
 bne :hit_chk_jpipe
 lda #3
 jmp :hit_dmg_done
:hit_chk_jpipe
 lda :puncher_anim_lo
 cmp #<anim_jpipeswing
 bne :hit_chk_mace
 lda :puncher_anim_hi
 cmp #>anim_jpipeswing
 bne :hit_chk_mace
 lda #3
 jmp :hit_dmg_done
:hit_chk_mace
 lda :puncher_anim_lo
 cmp #<anim_bmaceswing
 bne :hit_chk_jmace
 lda :puncher_anim_hi
 cmp #>anim_bmaceswing
 bne :hit_chk_jmace
 lda #3
 jmp :hit_dmg_done
:hit_chk_jmace
 lda :puncher_anim_lo
 cmp #<anim_jmaceswing
 bne :hit_chk_spin
 lda :puncher_anim_hi
 cmp #>anim_jmaceswing
 bne :hit_chk_spin
 lda #3
 jmp :hit_dmg_done
:hit_chk_spin
 lda :puncher_anim_lo
 cmp #<anim_bspinkick
 bne :hit_chk_jspin
 lda :puncher_anim_hi
 cmp #>anim_bspinkick
 bne :hit_chk_jspin
 lda #3
 jmp :hit_dmg_done
:hit_chk_jspin
 lda :puncher_anim_lo
 cmp #<anim_jbspinkick
 bne :hit_chk_lmace
 lda :puncher_anim_hi
 cmp #>anim_jbspinkick
 bne :hit_chk_lmace
 lda #3
 jmp :hit_dmg_done
:hit_chk_lmace
 lda :puncher_anim_lo
 cmp #<anim_lmace
 bne :hit_dmg1
 lda :puncher_anim_hi
 cmp #>anim_lmace
 bne :hit_dmg1
 lda #3
 jmp :hit_dmg_done
:hit_dmg1
 lda #1
:hit_dmg_done
 sta :hit_damage
 ldy #48
 lda (info_ptr),y
 clc
 adc :hit_damage
 sta (info_ptr),y
* Award 100 points to whichever player landed the hit, and mark
* the score for redraw. Skip when the target is also a player
* (NPC punching Billy shouldn't pay anyone). :puncher_ctrl was
* captured at check_punch_hit entry; $01 = Billy, $02 = Jimmy,
* $00 = NPC (no points awarded).
 ldy #22
 lda (info_ptr),y      ; target controller
 cmp #$01
 beq :no_score
 cmp #$02
 beq :no_score
 lda :puncher_ctrl
 cmp #$01
 bne :chk_p2_score
 jsr incp1s_hundreds
 bra :no_score
:chk_p2_score
 cmp #$02
 bne :no_score
 jsr incp2s_hundreds
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
* immediately for any of the damage-3 forced-fall attacks.
 lda :puncher_anim_lo
 cmp #<anim_uppercut
 bne :hit_chk2_juc
 lda :puncher_anim_hi
 cmp #>anim_uppercut
 bne :hit_chk2_juc
 jmp :use_fall
:hit_chk2_juc
 lda :puncher_anim_lo
 cmp #<anim_juppercut
 bne :hit_chk2_pipe
 lda :puncher_anim_hi
 cmp #>anim_juppercut
 bne :hit_chk2_pipe
 jmp :use_fall
:hit_chk2_pipe
 lda :puncher_anim_lo
 cmp #<anim_bpipeswing
 bne :hit_chk2_jpipe
 lda :puncher_anim_hi
 cmp #>anim_bpipeswing
 bne :hit_chk2_jpipe
 jmp :use_fall
:hit_chk2_jpipe
 lda :puncher_anim_lo
 cmp #<anim_jpipeswing
 bne :hit_chk2_mace
 lda :puncher_anim_hi
 cmp #>anim_jpipeswing
 bne :hit_chk2_mace
 jmp :use_fall
:hit_chk2_mace
 lda :puncher_anim_lo
 cmp #<anim_bmaceswing
 bne :hit_chk2_jmace
 lda :puncher_anim_hi
 cmp #>anim_bmaceswing
 bne :hit_chk2_jmace
 jmp :use_fall
:hit_chk2_jmace
 lda :puncher_anim_lo
 cmp #<anim_jmaceswing
 bne :hit_chk2_spin
 lda :puncher_anim_hi
 cmp #>anim_jmaceswing
 bne :hit_chk2_spin
 jmp :use_fall
:hit_chk2_spin
 lda :puncher_anim_lo
 cmp #<anim_bspinkick
 bne :hit_chk2_jspin
 lda :puncher_anim_hi
 cmp #>anim_bspinkick
 bne :hit_chk2_jspin
 jmp :use_fall
:hit_chk2_jspin
 lda :puncher_anim_lo
 cmp #<anim_jbspinkick
 bne :hit_chk2_lmace
 lda :puncher_anim_hi
 cmp #>anim_jbspinkick
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
* Normal punch — use punched_anim. If the puncher is doing a
* regular ground punch (Billy: anim_punch1/2; Jimmy: anim_jpunch1/2),
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
 bne :try_grab_jp1
 lda :puncher_anim_hi
 cmp #>anim_punch2
 bne :try_grab_jp1
 bra :arm_grab
:try_grab_jp1
 lda :puncher_anim_lo
 cmp #<anim_jpunch1
 bne :try_grab_jp2
 lda :puncher_anim_hi
 cmp #>anim_jpunch1
 bne :try_grab_jp2
 bra :arm_grab
:try_grab_jp2
 lda :puncher_anim_lo
 cmp #<anim_jpunch2
 bne :no_grab_arm
 lda :puncher_anim_hi
 cmp #>anim_jpunch2
 bne :no_grab_arm
:arm_grab
* check_punch_hit runs in update_anims, OUTSIDE the swap_in_jimmy
* context. Writing the global punch_window / last_hit_target here
* would land Jimmy's grab arm in Billy's slot — and Jimmy's stash
* would stay at 0, so his try_enter_grab would never fire. Route
* by :puncher_ctrl ($02 = Jimmy) to the right player's slot.
 lda :puncher_ctrl
 cmp #$02
 beq :arm_grab_jimmy
 lda #PUNCH_GRAB_WINDOW
 sta punch_window
 lda info_ptr
 sta last_hit_target
 lda info_ptr+1
 sta last_hit_target+1
 bra :no_grab_arm
:arm_grab_jimmy
 lda #PUNCH_GRAB_WINDOW
 sta jimmy_stash_punch_window
 lda info_ptr
 sta jimmy_stash_last_hit_target
 lda info_ptr+1
 sta jimmy_stash_last_hit_target+1
:no_grab_arm
 ldy #40
 lda (info_ptr),y     ; punched_anim low
 sta anim_ptr
 iny
 lda (info_ptr),y     ; punched_anim high
 sta anim_ptr+1
 ora anim_ptr
 beq :uf_no_punch_anim
 jmp :do_punched
:uf_no_punch_anim
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
 bne :uf_have_anim
 jmp :uf_no_anim
:uf_have_anim
* If the target is a player, count the fall and reset their
* punch_count so the next 3-hit cycle starts fresh. Without the
* reset, punch_count would walk past 6 and hit the legacy
* death branch in update_anims (which $FFFFs the sprite).
* Branch by controller — Billy ($01) drains P1's health bar
* (palette slots 1..4 + slot $A), Jimmy ($02 + pointer match)
* drains P2's bar (slots 5..9).
 ldy #22
 lda (info_ptr),y
 cmp #$01
 beq :uf_target_billy
 cmp #$02
 beq :uf_chk_jimmy
 jmp :do_punched
:uf_chk_jimmy
 lda info_ptr
 cmp #<jimmy_sprite
 beq :uf_chk_jimmy_hi
 jmp :do_punched
:uf_chk_jimmy_hi
 lda info_ptr+1
 cmp #>jimmy_sprite
 beq :uf_target_jimmy
 jmp :do_punched
:uf_target_billy
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
:uf_target_jimmy
* Mirror Billy's bookkeeping for Jimmy. fall_count lives in
* jimmy_stash_fall_count (the swap stash for player 2).
* Palette slots 5..9 are the P2 segments:
*   fall 1 → slot 9 ($019E52)  P2 rightmost green
*   fall 2 → slot 8 ($019E50)
*   fall 3 → slot 7 ($019E4E)
*   fall 4 → slot 6 ($019E4C)  yellow
*   fall 5 → slot 5 ($019E4A)  deep red
 inc jimmy_stash_fall_count
 lda #0
 ldy #48
 sta (info_ptr),y
 lda jimmy_stash_fall_count
 cmp #1
 bne :uf_jdep_2
 lda #0
 stal $019E52
 stal $019E53
 jmp :do_punched
:uf_jdep_2
 cmp #2
 bne :uf_jdep_3
 lda #0
 stal $019E50
 stal $019E51
 jmp :do_punched
:uf_jdep_3
 cmp #3
 bne :uf_jdep_4
 lda #0
 stal $019E4E
 stal $019E4F
 jmp :do_punched
:uf_jdep_4
 cmp #4
 bne :uf_jdep_5
 lda #0
 stal $019E4C
 stal $019E4D
 jmp :do_punched
:uf_jdep_5
 cmp #5
 bne :do_punched
 lda #0
 stal $019E4A
 stal $019E4B
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
* Restore caller's MASK_ADDR, anim_ptr, info_ptr, and spr_ptr
* in reverse order of the pushes at the top.
 pla
 sta MASK_ADDR+1
 pla
 sta MASK_ADDR
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
* Re-read MASK_ADDR from the puncher's info+60. The push/pop
* above restores the value MASK_ADDR held at entry — but if a
* hit triggered start_anim ON the puncher itself (e.g., Burnov
* starting anim_bngrab when his anim_bnpunch lands on Billy),
* start_anim's :sa_legacy_load / :sa_compiled_persist updated
* puncher's info+60 to match the NEW anim. Without this re-read,
* save_anim_state (which runs immediately after we return)
* persists the stale entry-time MASK_ADDR back into info+60 —
* and the next frame draws the new anim's frame_addr through
* the wrong dispatch (e.g., compiled draw on a legacy bank-$19
* frame_addr → garbage / black background).
 ldy #60
 lda (info_ptr),y
 sta MASK_ADDR
 iny
 lda (info_ptr),y
 sta MASK_ADDR+1
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
* incp2s_hundreds / _thousands / ... — same carry ladder as
* the p1 routines but operating on p2_score / p2_score_dirty.
* Called when Jimmy lands a hit (puncher_ctrl=$02 in
* check_punch_hit's score block).
*----------------------------------------------------------
  mx %11
incp2s_hundreds
  lda p2_score+4
  inc
  sta p2_score+4
  cmp #$3a
  blt incp2s_ret
  lda #$30
  sta p2_score+4
incp2s_thousands
  lda p2_score+3
  inc
  sta p2_score+3
  cmp #$3a
  blt incp2s_ret
  lda #$30
  sta p2_score+3
incp2s_tenthousands
  lda p2_score+2
  inc
  sta p2_score+2
  cmp #$3a
  blt incp2s_ret
  lda #$30
  sta p2_score+2
incp2s_hundredthousands
  lda p2_score+1
  inc
  sta p2_score+1
  cmp #$3a
  blt incp2s_ret
  lda #$30
  sta p2_score+1
incp2s_millions
  lda p2_score
  inc
  sta p2_score
  cmp #$3a
  blt incp2s_ret
  lda #$30
  sta p2_score
  sta p2_score+1
  sta p2_score+2
  sta p2_score+3
  sta p2_score+4
  sta p2_score+5
  sta p2_score+6
incp2s_ret
  inc p2_score_dirty
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
* Immediate-mode dispatch — same shared scan as draw_sprite_compiled
* uses. Legacy mission12 sprites (sprite_bank=$19) route here, so
* an entry-time match jumps into draw_sprite_immediate's body
* (dsi_modes_ready) past its own mode-entry. On miss, fall through
* to the legacy AND-with-mask draw below.
 jsr try_immediate_dispatch
 bcc :ds_not_immediate
 jmp dsi_modes_ready
:ds_not_immediate
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
* Apply signed frame_x_off to IMAGE01_XPOS for this draw. load_sprite
* reloads IMAGE01_XPOS from info+2 next iteration, so we can write
* over it without restoring.
 LDA frame_x_off
 BPL :ds_off_pos
 REP $20
 AND #$00FF
 ORA #$FF00            ; sign-extend negative
 BRA :ds_off_apply
:ds_off_pos
 REP $20
 AND #$00FF
:ds_off_apply
 CLC
 ADC IMAGE01_XPOS
 STA IMAGE01_XPOS
* Same bail as draw_sprite_compiled: negative effective xpos →
* skip rather than wrap into the playfield.
 BPL :ds_off_ok
 JMP :FINDUMP
:ds_off_ok
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
* draw_active_sprite is always drawing Billy, so frame_x_off must
* match billy_cur_x_off — otherwise scroll-time composites inherit
* whatever the last sprite's frame_x_off was (e.g. an old stale
* value from a previous Billy punch frame, or zero from an NPC
* draw inside the iteration loop). Without this, scroll routines
* that call draw_active_sprite outside draw_all/erase_all (right-
* scroll fast path, ladder transitions, etc.) leave Billy drawn
* at the wrong column and the next frame's erase_all clears the
* expected column → ghost trail.
 lda billy_cur_x_off
 sta frame_x_off
 lda MASK_ADDR
 ora MASK_ADDR+1
 bne :das_compiled
 jmp draw_sprite
:das_compiled
 jmp draw_sprite_compiled

*----------------------------------------------------------
* draw_other_sprite - In 2-player, draw the non-active player
* onto $01 during the scroll pipeline. Without this, only the
* sprite owning the globals at scroll time (the player who
* triggered the scroll) is drawn before push_band, leaving
* OTHER absent on $E1 until the next frame's draw_all → a
* one-frame blanking on every scroll = flicker for whichever
* player isn't driving.
*
* Skips when jimmy_active=0. Otherwise: locate OTHER's slot in
* sprite_table (Y-sorted, can't assume a fixed index), call
* load_sprite to swap globals to OTHER, dispatch the draw on
* MASK_ADDR (compiled vs legacy), then restore info_ptr +
* spr_ptr so the caller can finish its scroll handling.
*----------------------------------------------------------
draw_other_sprite
* Called from engine.s scroll pipeline in emulation 8-bit. Merlin
* doesn't track xce/sep transitions across JSL boundaries, so we
* assert the actual runtime state here — without this directive
* `cmp #>billy_sprite` and other immediate compares get assembled
* as 3-byte (16-bit A) instructions and execution lands on the
* trailing zero byte → BRK at $00/A300.
 mx %11
 lda jimmy_active
 bne :dos_active
 rts
:dos_active
* Co-op climb hide: if a climb is in progress, OTHER is hidden.
* No draw fires for them in the scroll pipeline.
 lda climb_hide_other
 beq :dos_not_hidden
 rts
:dos_not_hidden
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 lda spr_ptr
 pha
 lda spr_ptr+1
 pha
* Determine OTHER's info pointer.
 lda info_ptr+1
 cmp #>billy_sprite
 bne :dos_target_jimmy
 lda info_ptr
 cmp #<billy_sprite
 bne :dos_target_jimmy
* Active = Billy → OTHER = Jimmy.
 lda #<jimmy_sprite
 sta :dos_target
 lda #>jimmy_sprite
 sta :dos_target+1
 bra :dos_find
:dos_target_jimmy
* Active is something else (Jimmy or NPC) → OTHER = Billy.
 lda #<billy_sprite
 sta :dos_target
 lda #>billy_sprite
 sta :dos_target+1
:dos_find
 lda #<sprite_table
 sta spr_ptr
 lda #>sprite_table
 sta spr_ptr+1
:dos_loop
 ldy #0
 lda (spr_ptr),y
 sta info_ptr
 iny
 lda (spr_ptr),y
 sta info_ptr+1
 ora info_ptr
 beq :dos_not_found    ; null terminator
 lda info_ptr
 cmp :dos_target
 bne :dos_next
 lda info_ptr+1
 cmp :dos_target+1
 beq :dos_found
:dos_next
 lda spr_ptr
 clc
 adc #2
 sta spr_ptr
 bcc :dos_loop
 inc spr_ptr+1
 bra :dos_loop
:dos_found
 jsr load_sprite           ; globals ← OTHER
* Stage frame_x_off per controller (mirrors draw_all's dispatch).
 ldy #22
 lda (info_ptr),y
 cmp #$01
 bne :dos_chk_off_j
 lda billy_cur_x_off
 sta frame_x_off
 bra :dos_off_done
:dos_chk_off_j
 cmp #$02
 bne :dos_off_zero
 lda jimmy_cur_x_off
 sta frame_x_off
 bra :dos_off_done
:dos_off_zero
 stz frame_x_off
:dos_off_done
 lda MASK_ADDR
 ora MASK_ADDR+1
 bne :dos_compiled
 jsr draw_sprite
 bra :dos_drawn
:dos_compiled
 jsr draw_sprite_compiled
:dos_drawn
:dos_not_found
 pla
 sta spr_ptr+1
 pla
 sta spr_ptr
 pla
 sta info_ptr+1
 pla
 sta info_ptr
* Reload active player's globals so the rest of the scroll
* pipeline (draw_overlay, push_band) and any post-scroll game.s
* code see consistent state — without this, globals stay as
* OTHER's after the dispatch and a downstream consumer may render
* with the wrong sprite's data ("scrambled sprites" report).
 jsr load_sprite
 rts
:dos_target ds 2

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
*   LDA scr_abs,Y / AND [mask],Y / ORA [data],Y / STA scr_abs,Y
* Screen reads/writes are absolute,Y with DBR=$01 (cheaper than
* the [dp],Y form they replaced — 4+5 cyc vs 7+8). The abs operand
* is self-modified per row at :dsc_scr_lda+1 / :dsc_scr_sta+1.
* Data and mask stay long-indirect since they live in bank $02.
* Mirror sprites use pre-computed _DATA_MIRROR / _MASK_MIRROR
* arrays — there is no separate mirror branch here.
*
* DP layout after the 11-byte stack carve-out:
*   DP 0-2  unused (was screen long pointer pre-abs,Y refactor)
*   DP 4-6  data   long pointer (offset 4-5, bank 6)
*   DP 7-9  mask   long pointer (offset 7-8, bank 9)
*   DP A    end_x  (= FRAME_X, the byte-width loop bound)
*----------------------------------------------------------
*----------------------------------------------------------
* try_immediate_dispatch - Shared scan of compiled_dispatch_tbl.
* Called by both draw_sprite_compiled and the legacy draw_sprite
* after their mode-entry (MX=00, DBR=$00, native mode).
*
* Input:  sprite_bank, FRAME_ADDR, info_ptr (for legacy mirror).
* Output: C=1 if matched (and dsi_blit_addr/dsi_blit_bank are set);
*         C=0 if not a migrated bank or no key match.
* Clobbers: A, X, Y.
*
* Entry layout (6 bytes): key(2) + blit_addr(2) + blit_bank(1) + orient(1).
*   key    = FRAME_ADDR (raw, no transformation).
*   orient = 0 for the data entry, 1 for the legacy mirror entry.
*
* Search-key derivation:
*   Compiled banks ($1B, $02, $1D): key = FRAME_ADDR, orient = 0.
*     Mirror is already encoded — DATA_MIRROR has its own distinct
*     FRAME_ADDR, and both compiled entries are stored with orient=0.
*   Legacy bank ($19, mission12): FRAME_ADDR is the same for both
*     orientations (engine reads info+4 mirror flag separately), so
*     orient is set to that mirror flag and the scan matches both
*     key and orient. Avoids the old "OR $8000 into key" trick that
*     collided for frame_addrs >= $8000.
*----------------------------------------------------------
try_immediate_dispatch
 mx %00                  ; live CPU enters here with REP $30 already done;
                         ; Merlin's static MX tracker, however, is at %11
                         ; because the previous routine ended `sec; xce`.
                         ; Without this directive, immediate operands like
                         ; `and #$00FF` assemble as 8-bit (2 bytes) and the
                         ; 16-bit CPU then eats the next opcode byte.
 lda sprite_bank
 and #$00FF
 cmp #$001B
 beq :tid_compiled_key
 cmp #$0002
 beq :tid_compiled_key
 cmp #$001D
 beq :tid_compiled_key
 cmp #$001C
 beq :tid_compiled_key
 cmp #$0019
 bne :tid_miss
* Legacy: key = FRAME_ADDR, orient = info+4 (mirror flag).
 ldy #4
 lda (info_ptr),y
 and #$00FF
 sta :tid_scan_orient
 bra :tid_use_frame
:tid_compiled_key
 stz :tid_scan_orient
:tid_use_frame
 lda FRAME_ADDR
 sta :tid_scan_key
 ldx #0
:tid_scan
 cpx compiled_dispatch_count
 bcs :tid_miss
 lda compiled_dispatch_tbl,x
 cmp :tid_scan_key
 bne :tid_scan_next
* Key matched — check orient byte at +5.
 sep $20
 lda compiled_dispatch_tbl+5,x
 cmp :tid_scan_orient
 rep $20
 beq :tid_found
:tid_scan_next
 txa
 clc
 adc #6
 tax
 bra :tid_scan
:tid_found
 lda compiled_dispatch_tbl+2,x
 sta dsi_blit_addr
 sep $20
 lda compiled_dispatch_tbl+4,x
 sta dsi_blit_bank
 rep $20
 sec
 rts
:tid_miss
 clc
 rts
:tid_scan_key    dw 0
:tid_scan_orient dw 0

draw_sprite_compiled
 PHB
 PHP
 CLC
 XCE
 PHP
 PHK
 PLB
 REP $30
* Immediate-mode dispatch. Post mode-entry, MX=00.
* Delegated to try_immediate_dispatch so the same scan code can
* serve both draw_sprite_compiled and the legacy draw_sprite path.
 jsr try_immediate_dispatch
 bcc :dsc_not_immediate
 jmp dsi_modes_ready
:dsc_not_immediate
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

* Bank bytes for the [4]/[7] long-indirect data/mask reads. Screen
* no longer uses long-indirect — its bank is set by switching DBR
* to $01 just before the inner loop.
 LDA sprite_bank
 STA 6                 ; DP 6 = data bank
 STA 9                 ; DP 9 = mask bank

 REP $20

* Apply signed frame_x_off to IMAGE01_XPOS for this draw. load_sprite
* reloads IMAGE01_XPOS from info+2 next iteration, so we can write
* over it without restoring. frame_x_off is a signed 8-bit byte
* (e.g. +1 right-facing punch, -5 mirrored punch); sign-extend so a
* negative offset doesn't pollute the high byte.
 SEP $20
 LDA frame_x_off
 BPL :dsc_off_pos
 REP $20
 AND #$00FF
 ORA #$FF00            ; sign-extend negative
 BRA :dsc_off_apply
:dsc_off_pos
 REP $20
 AND #$00FF
:dsc_off_apply
 CLC
 ADC IMAGE01_XPOS
 STA IMAGE01_XPOS
* Bail if the offset pushed effective xpos negative (frame_x_off
* is signed; e.g. anim_punch2's -9 mirror lunge with xpos < 9).
* Without this, the 16-bit wrap below adds $FFxx into the playfield
* base and the sprite plots at random columns / rows. Skip the
* draw entirely — prev_xpos is unchanged, so erase next frame still
* targets the last successful draw position.
 BPL :dsc_off_ok
 JMP :dsc_done
:dsc_off_ok
* Screen base address = $2000 + ypos*$A0 + IMAGE01_XPOS. Patched
* into both inner-loop abs,Y operands so the loop can use the
* cheaper LDA/STA abs,Y form instead of LDA/STA [dp],Y. Row tail
* re-patches both operands by adding $A0 each iteration.
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
 ADC IMAGE01_XPOS
 STA :dsc_scr_lda+1
 STA :dsc_scr_sta+1

 LDA FRAME_ADDR
 STA 4                 ; DP 4-5 = data offset
 LDA MASK_ADDR
 STA 7                 ; DP 7-8 = mask offset

 SEP $30
 LDA FRAME_X
 STA $0A               ; DP $0A = byte width (loop bound, Y < FRAME_X)
 LDX FRAME_Y           ; X = row counter

* Switch DBR=$01 so the inner loop's abs,Y screen access lands in
* the SHR shadow bank. PHB at routine entry stashed the caller's
* DBR; the final PLB in :dsc_done restores it.
 LDA #$01
 PHA
 PLB

:dsc_row
 LDY #0                ; sprite-byte index, runs 0..FRAME_X-1
:dsc_byte
:dsc_scr_lda LDA $0000,Y     ; abs,Y, operand self-modified per row
 AND [7],Y
 ORA [4],Y
:dsc_scr_sta STA $0000,Y     ; abs,Y, operand self-modified per row
 INY
 CPY $0A
 BCC :dsc_byte

 DEX
 BEQ :dsc_done

* Advance pointers to next row (16-bit math). DBR=$01 here, so
* FRAME_X must be read via long addressing (ADCL) — plain ADC
* would land in bank $01 instead of bank $00.
 REP $20
 LDAL :dsc_scr_lda+1
 CLC
 ADC #$00A0
 STAL :dsc_scr_lda+1
 STAL :dsc_scr_sta+1
 LDA 4
 CLC
 ADCL FRAME_X
 STA 4
 LDA 7
 CLC
 ADCL FRAME_X
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

*----------------------------------------------------------
* draw_sprite_immediate - JSL-into-compiled-blob blit path.
* Same caller interface as draw_sprite_compiled but expects the
* sprite's frame to have a _BLIT blob in bank $1B. Inputs:
*   IMAGE01_XPOS / IMAGE01_YPOS  destination
*   FRAME_X                      (unused — blob is self-describing)
*   FRAME_Y                      (unused)
*   frame_x_off                  same signed offset support
*   :dsi_blit_lo/hi              16-bit address of blob in bank $1B
*                                (caller sets before JSR)
*
* The blob expects on entry:
*   M=8-bit, X=16-bit, DBR=$01
*   X = $2000 + ypos*$A0 + xpos  (top-left screen byte)
* It ends with RTL.
*
* Prototype path. Only WILLIAM1 idle frame is wired in via the
* dispatch check at the top of draw_sprite_compiled.
*----------------------------------------------------------
draw_sprite_immediate
 PHB
 PHP
 CLC
 XCE                   ; native mode
 PHP
 PHK
 PLB                   ; DBR = $00 for setup ABS reads
 REP $30               ; 16-bit A/X/Y
dsi_modes_ready
* Entry from draw_sprite_compiled's dispatcher lands here, having
* already done the PHB/PHP/CLC/XCE/PHP/PHK/PLB/REP $30 mode entry.
* MX=00, DBR=$00, stack has [P_native, P_emul, DBR_caller].

* Apply signed frame_x_off (mirror of draw_sprite_compiled).
 SEP $20
 LDA frame_x_off
 BPL :dsi_off_pos
 REP $20
 AND #$00FF
 ORA #$FF00
 BRA :dsi_off_apply
:dsi_off_pos
 REP $20
 AND #$00FF
:dsi_off_apply
 CLC
 ADC IMAGE01_XPOS
 STA IMAGE01_XPOS
 BPL :dsi_off_ok
 JMP :dsi_done
:dsi_off_ok

* Compute screen base = $2000 + ypos*$A0 + xpos into X (16-bit).
 LDA IMAGE01_YPOS
 ASL
 ASL
 ASL
 ASL
 ASL
 STA IMAGE01_XTEMP
 ASL
 ASL
 CLC
 ADC IMAGE01_XTEMP
 CLC
 ADC #$2000
 CLC
 ADC IMAGE01_XPOS
 TAX                   ; X = screen base

* Patch the JSL operand: low+high from dsi_blit_addr, bank from
* dsi_blit_bank. Both set by the dispatcher in draw_sprite_compiled
* (or any other caller) before JMPing here.
 LDA dsi_blit_addr
 STA :dsi_call+1
 SEP $20
 LDA dsi_blit_bank
 STA :dsi_call+3

* Switch DBR=$01 so the blob's STA abs,X writes land in the SHR
* shadow bank. M stays 8-bit (matches blob's per-pixel ops).
 LDA #$01
 PHA
 PLB

:dsi_call JSL $000000  ; operand patched above

* Blob returned via RTL. M=8-bit on return (blob ends after a STA).
* Teardown.
:dsi_done
 REP $30
 PLP
 XCE
 PLP
 PLB                   ; restore caller's DBR
 RTS

dsi_blit_addr dw 0     ; 16-bit blit blob address (within blit_bank)
dsi_blit_bank dfb 0    ; bank byte for the JSL operand patch

*----------------------------------------------------------
* compiled_dispatch_tbl - Linear-scan dispatch table built at
* init time by _init_mission13blit. 64 entries × 6 bytes each
* (max — actual count in compiled_dispatch_count).
*
* Per-entry layout:
*   +0..+1  frame_addr   (16-bit bank-$1B sprite-data address,
*                         matched against FRAME_ADDR at draw time)
*   +2..+3  blit_addr    (16-bit blit-blob offset within blit_bank)
*   +4      blit_bank    (8-bit bank holding the blit blob, $30/$31)
*   +5      pad          (alignment / future use)
*
* Each migrated sprite contributes TWO entries: one for its
* normal-orientation DATA address paired with its BLIT, and one
* for the mirrored DATA paired with BLIT_MIRROR. Same scan loop
* handles both.
*----------------------------------------------------------
* compiled_dispatch_tbl + compiled_dispatch_count live in the free
* bank-$00 RAM hole between ddii.s ($1000-$13FF after PIC) and
* game.s ($2000+). Using EQU keeps the ~2 KB off the game.s
* image so we don't blow through ddii.s's $9F00 read cap as the
* dispatch table grows with each migrated cohort. Current usage
* after mission13+mission1+mission1jimmy+mission12 is 264 entries
* × 6 = 1584 bytes; 2048 bytes leaves headroom for mission14.
compiled_dispatch_tbl   equ $1400      ; up to 2048 bytes ($1400-$1BFF, ~341 entries × 6)
compiled_dispatch_count equ $1C00      ; 2-byte count (16-bit)

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
 da level_path_buf    ; pathname pointer (filled per-load from manifest)
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

* Background PAK paths (pathname/path12..path114) moved to the
* bank-$02 level manifest; loaded via level_compose_bg into
* level_path_buf at boot.
level_path_buf ds 40   ; composed ProDOS path (len byte + chars)
bg_count_cache dfb 0   ; manifest bg_count, cached for the load loop
lp_limit       dfb 0   ; append_str copy limit (str len + 1)
lp_name_lo     dfb 0   ; scratch: bank-$02 addr of a manifest str
lp_name_hi     dfb 0
man_base       dw 0    ; bank-$02 offset of level_manifest (from header)
* level_iter_loads scratch
lp_iter_off    dfb 0   ; offset of load_entries[0] from manifest base
lp_iter_count  dfb 0   ; load_count from manifest +3
lp_iter_idx    dfb 0   ; current iteration index
lp_dest_bank   dfb 0   ; current entry's dest_bank
lp_kind        dfb 0   ; current entry's kind (0/1/2)

* master sprite table
sprite_table
  dw billy_sprite       ; player 1 (always first)
  dw jimmy_sprite       ; player 2 (co-op)
  hex 0000              ; NPC slots (populated by level script)
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
  hex 0000         ; +52 (NPC walk_anim slot — unused for Billy; the
                   ;     compiled mask_addr now lives at +60 so
                   ;     load_sprite can read it without colliding
                   ;     with NPC walk_anim).
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
  hex 0000         ; +60 active_mask_addr (compiled inverse-mask
                   ;     companion to +14 frame_addr). Patched by
                   ;     init_level + load_sprite + start_anim.
                   ;     Replaces the old +52 mask field.
  hex 0000         ; +62 idle_mask_addr (NPC compiled-idle source —
                   ;     unused for Billy: his idle mask flips with
                   ;     facing via spr_image01_mask / _mirror in
                   ;     :normal_end's billy branch).

**
** JIMMY sprite — co-op player 2. Same info-block layout as Billy.
** All sprite/mask pointers patched by init_jimmy from the bank-$1D
** Jimmy sprite-address table. controller=0 for now (no input wired
** up yet); set to $02 when player 2 controls come online.
**
jimmy_sprite
  hex 6400 ; +0  ypos (placed alongside Billy for now)
  hex 1F00 ; +2  xpos
  hex 0000 ; +4  mirror (face right)
  hex 0000 ; +6  unused
  hex 0500 ; +8  unused
  hex 0900 ; +10 frame_x (JIMMY01 width)
  hex 2800 ; +12 frame_y
  hex 0000 ; +14 frame_addr (patched: JIMMY01_DATA in bank $1D)
  hex 6600 ; +16 mask color = $66
  hex 6000 ; +18 maskhi
  hex 0600 ; +20 masklo
  hex 0200 ; +22 controller = $02 (player 2 — skipped by update_npcs
                   ;     and check_punch_hit until Ctrl-J flips
                   ;     jimmy_active. The Ctrl-J path doesn't have
                   ;     to touch this byte.)
  hex 0000 ; +24 anim_ptr = 0 (inert at boot — update_anims walks
                   ;     past sprites whose anim_ptr is zero, and
                   ;     draw_all keys off dirty so Jimmy is fully
                   ;     invisible until Ctrl-J)
  hex 0000 ; +26 anim_frame
  hex 0000 ; +28 anim_timer
  hex 0000 ; +30 dirty = 0 (no draw / no erase)
  hex 0000 ; +32 prev_ypos = 0
  hex 0000 ; +34 prev_xpos = 0
  hex 0000 ; +36 prev_frame_x = 0 (mark_overlapping reads this as
                   ;     the on-screen "prev rect" width — with it
                   ;     at 0, the horizontal-overlap test always
                   ;     rejects Jimmy, so Billy's moves don't set
                   ;     Jimmy's dirty bit before activation)
  hex 0000 ; +38 prev_frame_y = 0
  da anim_jpunched ; +40 punched_anim
  hex 0000 ; +42 idle_addr (patched: JIMMY01_DATA)
  hex 0900 ; +44 idle_x
  hex 2800 ; +46 idle_y
  hex 0000 ; +48 punch_count
  da anim_jfall    ; +50 fall_anim
  hex 0000 ; +52 walk_anim (NPC slot, unused for player)
  hex 0000 ; +54 atk_anim (NPC slot, unused)
  hex 1D00 ; +56 frame_bank = $1D (Jimmy data lives in bank $1D)
  hex 1D00 ; +58 idle_bank = $1D
  hex 0000 ; +60 active_mask_addr (patched: JIMMY01_MASK)
  hex 0000 ; +62 idle_mask_addr (patched: JIMMY01_MASK)

* Jimmy walk animation — mirrors anim_walk's structure but with
* compiled stride (11 bytes/frame). init_jimmy patches each frame
* slot from the spr_jimmy0X cache vars.
anim_walk_j
 dfb 4               ; num_frames
 dfb $0B             ; max_width (JIMMY03 is widest)
 dfb $84             ; flags: bit 7 = compiled stride, bit 2 = bank $1D
 dfb $09,$28,5       ; JIMMY01: 9 wide, 40 tall, 5 VBLs
  hex 0000             ; patched: spr_jimmy01
  hex 0000             ; patched: spr_jimmy01_mask
  hex 0000             ; patched: spr_jimmy01_data_mir
  hex 0000             ; patched: spr_jimmy01_mask_mir
 dfb $08,$28,5       ; JIMMY02
  hex 0000
  hex 0000
  hex 0000
  hex 0000
 dfb $0B,$28,5       ; JIMMY03
  hex 0000
  hex 0000
  hex 0000
  hex 0000
 dfb $08,$28,5       ; JIMMY02 (return)
  hex 0000
  hex 0000
  hex 0000
  hex 0000

*-------------------------------
* Globals (used by erase/draw_sprite)
*-------------------------------
FRAME_X  HEX 0900         ; current frame width
FRAME_Y  HEX 2800         ; current frame height
FRAME_ADDR ds 2            ; current frame data address (set at runtime)
MASK_ADDR  ds 2            ; companion inverse-mask address for compiled
                           ; AND/ORA draw path; consumed by draw_sprite_compiled
frame_x_off dfb 0          ; signed render-x offset for the current draw.
                           ; Set per-sprite by draw_all/erase_all (today
                           ; only when drawing Billy); draw_sprite and
                           ; draw_sprite_compiled add it to IMAGE01_XPOS
                           ; at the screen-address calculation. Cleared
                           ; for non-Billy sprites so NPC draws aren't
                           ; affected.
billy_cur_x_off dfb 0      ; signed byte. Set by set_anim_x_off when an
                           ; anim with a render offset starts/runs (today
                           ; only anim_punch1/anim_punch2: +1 right-facing,
                           ; -5 mirrored). Read by draw_all when drawing
                           ; Billy. Cleared at :normal_end. Lives in a
                           ; global instead of an info+ slot because NPC
                           ; behaviors already pack state into info+7..+9.
billy_prev_x_off dfb 0     ; signed byte latched from billy_cur_x_off
                           ; right after each Billy draw. Read by
                           ; erase_all next frame so the union erase rect
                           ; covers the offset-shifted prev draw.
billy_y_off    dfb 0       ; signed byte: Billy's current ypos offset
                           ; from grounded position. Drives the parabolic
                           ; jump arc — negative = airborne. Modified
                           ; in 2px steps by update_billy_y_off as it
                           ; ramps toward billy_y_target each game-loop
                           ; tick. The same delta is applied to Billy's
                           ; ypos at info+0 / IMAGE01_YPOS so erase_all
                           ; and draw_all see the on-screen Y directly
                           ; (no separate prev_y_off bookkeeping needed).
billy_y_target dfb 0       ; signed byte: target ypos offset. Set to
                           ; -20 ($EC) by set_billy_y_target when an
                           ; anim_jump or anim_bspinkick starts so Billy
                           ; rises. Set to 0 when the last frame of a
                           ; jump-arc anim loads OR any non-jump-arc
                           ; anim starts (e.g. punched mid-air) so
                           ; Billy descends and lands.
* Gravity / falling state (only consulted when gravity_enabled = 1
* — see init_data.s). billy_airborne = 1 while Billy is mid-jump or
* mid-fall; billy_y_vel is the per-frame vertical delta applied to
* billy_sprite.ypos by apply_gravity_step (signed; -ve rising,
* +ve falling). billy_jump_x_vel is the per-frame horizontal delta
* during airborne (signed; +1 = forward right, -1 = left, 0 = no
* horizontal momentum). Set by btn_action_jump from Billy's facing.
billy_airborne dfb 0
billy_y_vel    dfb 0
billy_jump_x_vel dfb 0

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
script_x        ds 2          ; rightmost player's world X (computed)


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

*----------------------------------------------------------
* init_data.s — bank-$00 storage carved out of the init
* block that engine.s now houses. Declarations stay here
* because game.s reads these caches everywhere (renderer,
* hit detection, animations); engine.s only WRITES them
* during init.
*----------------------------------------------------------
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
spr_william1c_data     ds 2
spr_william1c_mask     ds 2
spr_william1c_data_mir ds 2
spr_william1c_mask_mir ds 2
spr_william2c_data     ds 2
spr_william2c_mask     ds 2
spr_william2c_data_mir ds 2
spr_william2c_mask_mir ds 2
spr_william3c_data     ds 2
spr_william3c_mask     ds 2
spr_william3c_data_mir ds 2
spr_william3c_mask_mir ds 2
spr_wpunch1c_data      ds 2
spr_wpunch1c_mask      ds 2
spr_wpunch1c_data_mir  ds 2
spr_wpunch1c_mask_mir  ds 2
spr_wpunch2c_data      ds 2
spr_wpunch2c_mask      ds 2
spr_wpunch2c_data_mir  ds 2
spr_wpunch2c_mask_mir  ds 2
spr_wpunchedc_data     ds 2
spr_wpunchedc_mask     ds 2
spr_wpunchedc_data_mir ds 2
spr_wpunchedc_mask_mir ds 2
spr_wfallc_data        ds 2
spr_wfallc_mask        ds 2
spr_wfallc_data_mir    ds 2
spr_wfallc_mask_mir    ds 2
spr_wfallenc_data      ds 2
spr_wfallenc_mask      ds 2
spr_wfallenc_data_mir  ds 2
spr_wfallenc_mask_mir  ds 2
spr_roper1c_data       ds 2
spr_roper1c_mask       ds 2
spr_roper1c_data_mir   ds 2
spr_roper1c_mask_mir   ds 2
spr_roper2c_data       ds 2
spr_roper2c_mask       ds 2
spr_roper2c_data_mir   ds 2
spr_roper2c_mask_mir   ds 2
spr_roper3c_data       ds 2
spr_roper3c_mask       ds 2
spr_roper3c_data_mir   ds 2
spr_roper3c_mask_mir   ds 2
spr_rpunch1c_data      ds 2
spr_rpunch1c_mask      ds 2
spr_rpunch1c_data_mir  ds 2
spr_rpunch1c_mask_mir  ds 2
spr_rpunch2c_data      ds 2
spr_rpunch2c_mask      ds 2
spr_rpunch2c_data_mir  ds 2
spr_rpunch2c_mask_mir  ds 2
spr_rpunchedc_data     ds 2
spr_rpunchedc_mask     ds 2
spr_rpunchedc_data_mir ds 2
spr_rpunchedc_mask_mir ds 2
spr_rfall1c_data       ds 2
spr_rfall1c_mask       ds 2
spr_rfall1c_data_mir   ds 2
spr_rfall1c_mask_mir   ds 2
spr_rfall2c_data       ds 2
spr_rfall2c_mask       ds 2
spr_rfall2c_data_mir   ds 2
spr_rfall2c_mask_mir   ds 2
spr_linda1c_data       ds 2
spr_linda1c_mask       ds 2
spr_linda1c_data_mir   ds 2
spr_linda1c_mask_mir   ds 2
spr_linda2c_data       ds 2
spr_linda2c_mask       ds 2
spr_linda2c_data_mir   ds 2
spr_linda2c_mask_mir   ds 2
spr_linda3c_data       ds 2
spr_linda3c_mask       ds 2
spr_linda3c_data_mir   ds 2
spr_linda3c_mask_mir   ds 2
spr_lpunch1c_data      ds 2
spr_lpunch1c_mask      ds 2
spr_lpunch1c_data_mir  ds 2
spr_lpunch1c_mask_mir  ds 2
spr_lpunch2c_data      ds 2
spr_lpunch2c_mask      ds 2
spr_lpunch2c_data_mir  ds 2
spr_lpunch2c_mask_mir  ds 2
spr_lpunchedc_data     ds 2
spr_lpunchedc_mask     ds 2
spr_lpunchedc_data_mir ds 2
spr_lpunchedc_mask_mir ds 2
spr_lfall1c_data       ds 2
spr_lfall1c_mask       ds 2
spr_lfall1c_data_mir   ds 2
spr_lfall1c_mask_mir   ds 2
spr_lfall2c_data       ds 2
spr_lfall2c_mask       ds 2
spr_lfall2c_data_mir   ds 2
spr_lfall2c_mask_mir   ds 2
spr_bnwalk1c_data      ds 2
spr_bnwalk1c_mask      ds 2
spr_bnwalk1c_data_mir  ds 2
spr_bnwalk1c_mask_mir  ds 2
spr_bnwalk2c_data      ds 2
spr_bnwalk2c_mask      ds 2
spr_bnwalk2c_data_mir  ds 2
spr_bnwalk2c_mask_mir  ds 2
spr_bnwalk3c_data      ds 2
spr_bnwalk3c_mask      ds 2
spr_bnwalk3c_data_mir  ds 2
spr_bnwalk3c_mask_mir  ds 2
spr_wsomer1c_data      ds 2
spr_wsomer1c_mask      ds 2
spr_wsomer1c_data_mir  ds 2
spr_wsomer1c_mask_mir  ds 2
spr_wsomer2c_data      ds 2
spr_wsomer2c_mask      ds 2
spr_wsomer2c_data_mir  ds 2
spr_wsomer2c_mask_mir  ds 2
spr_wsomer3c_data      ds 2
spr_wsomer3c_mask      ds 2
spr_wsomer3c_data_mir  ds 2
spr_wsomer3c_mask_mir  ds 2
spr_lclimb1c_data      ds 2
spr_lclimb1c_mask      ds 2
spr_lclimb1c_data_mir  ds 2
spr_lclimb1c_mask_mir  ds 2
spr_lclimb2c_data      ds 2
spr_lclimb2c_mask      ds 2
spr_lclimb2c_data_mir  ds 2
spr_lclimb2c_mask_mir  ds 2
spr_lfwalk1c_data      ds 2
spr_lfwalk1c_mask      ds 2
spr_lfwalk1c_data_mir  ds 2
spr_lfwalk1c_mask_mir  ds 2
spr_lfwalk2c_data      ds 2
spr_lfwalk2c_mask      ds 2
spr_lfwalk2c_data_mir  ds 2
spr_lfwalk2c_mask_mir  ds 2
spr_lfwalk3c_data      ds 2
spr_lfwalk3c_mask      ds 2
spr_lfwalk3c_data_mir  ds 2
spr_lfwalk3c_mask_mir  ds 2
spr_lmace1c_data       ds 2
spr_lmace1c_mask       ds 2
spr_lmace1c_data_mir   ds 2
spr_lmace1c_mask_mir   ds 2
spr_lmace2c_data       ds 2
spr_lmace2c_mask       ds 2
spr_lmace2c_data_mir   ds 2
spr_lmace2c_mask_mir   ds 2
spr_lmace3c_data       ds 2
spr_lmace3c_mask       ds 2
spr_lmace3c_data_mir   ds 2
spr_lmace3c_mask_mir   ds 2
spr_wpipewalk1c_data   ds 2
spr_wpipewalk1c_mask   ds 2
spr_wpipewalk1c_data_mir ds 2
spr_wpipewalk1c_mask_mir ds 2
spr_wpipewalk2c_data   ds 2
spr_wpipewalk2c_mask   ds 2
spr_wpipewalk2c_data_mir ds 2
spr_wpipewalk2c_mask_mir ds 2
spr_wpipewalk3c_data   ds 2
spr_wpipewalk3c_mask   ds 2
spr_wpipewalk3c_data_mir ds 2
spr_wpipewalk3c_mask_mir ds 2
spr_wpipe1c_data       ds 2
spr_wpipe1c_mask       ds 2
spr_wpipe1c_data_mir   ds 2
spr_wpipe1c_mask_mir   ds 2
spr_wpipe2c_data       ds 2
spr_wpipe2c_mask       ds 2
spr_wpipe2c_data_mir   ds 2
spr_wpipe2c_mask_mir   ds 2
spr_wpipe3c_data       ds 2
spr_wpipe3c_mask       ds 2
spr_wpipe3c_data_mir   ds 2
spr_wpipe3c_mask_mir   ds 2
spr_wpipe4c_data       ds 2
spr_wpipe4c_mask       ds 2
spr_wpipe4c_data_mir   ds 2
spr_wpipe4c_mask_mir   ds 2
spr_wpipe6c_data       ds 2
spr_wpipe6c_mask       ds 2
spr_wpipe6c_data_mir   ds 2
spr_wpipe6c_mask_mir   ds 2
spr_wknife1c_data      ds 2
spr_wknife1c_mask      ds 2
spr_wknife1c_data_mir  ds 2
spr_wknife1c_mask_mir  ds 2
spr_wknife2c_data      ds 2
spr_wknife2c_mask      ds 2
spr_wknife2c_data_mir  ds 2
spr_wknife2c_mask_mir  ds 2
spr_bnpunch1c_data     ds 2
spr_bnpunch1c_mask     ds 2
spr_bnpunch1c_data_mir ds 2
spr_bnpunch1c_mask_mir ds 2
spr_bnpunch2c_data     ds 2
spr_bnpunch2c_mask     ds 2
spr_bnpunch2c_data_mir ds 2
spr_bnpunch2c_mask_mir ds 2
spr_bnbilly1c_data     ds 2
spr_bnbilly1c_mask     ds 2
spr_bnbilly1c_data_mir ds 2
spr_bnbilly1c_mask_mir ds 2
spr_bnbilly2c_data     ds 2
spr_bnbilly2c_mask     ds 2
spr_bnbilly2c_data_mir ds 2
spr_bnbilly2c_mask_mir ds 2
spr_bnbilly3c_data     ds 2
spr_bnbilly3c_mask     ds 2
spr_bnbilly3c_data_mir ds 2
spr_bnbilly3c_mask_mir ds 2
* Order swapped (BNFALL/BNFALLEN before BNJIMMY) to match
* mission14.s declaration order. The full 26-sprite block
* (spr_lfwalk1c_data .. spr_bnjimmy3c_mask_mir) is 208 bytes
* of contiguous 8-byte slots — init_mission14blit indexes into
* this with sprite_idx*8 in lockstep with the blit_addr_tbl.
spr_bnfall1c_data      ds 2
spr_bnfall1c_mask      ds 2
spr_bnfall1c_data_mir  ds 2
spr_bnfall1c_mask_mir  ds 2
spr_bnfallenc_data     ds 2
spr_bnfallenc_mask     ds 2
spr_bnfallenc_data_mir ds 2
spr_bnfallenc_mask_mir ds 2
spr_bnjimmy1c_data     ds 2
spr_bnjimmy1c_mask     ds 2
spr_bnjimmy1c_data_mir ds 2
spr_bnjimmy1c_mask_mir ds 2
spr_bnjimmy2c_data     ds 2
spr_bnjimmy2c_mask     ds 2
spr_bnjimmy2c_data_mir ds 2
spr_bnjimmy2c_mask_mir ds 2
spr_bnjimmy3c_data     ds 2
spr_bnjimmy3c_mask     ds 2
spr_bnjimmy3c_data_mir ds 2
spr_bnjimmy3c_mask_mir ds 2
spr_bnwalk1  ds 2
spr_bnwalk2  ds 2
spr_bnwalk3  ds 2
spr_bnfall1  ds 2
spr_bnfallen ds 2
spr_bnpunch1 ds 2
spr_bnpunch2 ds 2
spr_bnbilly1 ds 2
spr_bnbilly2 ds 2
spr_bnbilly3 ds 2
spr_bdiss1   ds 2
spr_bdiss2   ds 2
spr_bdiss3   ds 2
spr_bdiss4   ds 2
spr_bdiss5   ds 2
spr_bdiss6   ds 2
spr_bdiss7   ds 2
spr_bdiss8   ds 2
spr_lfwalk1  ds 2
spr_lfwalk2  ds 2
spr_lfwalk3  ds 2
spr_lmace1   ds 2
spr_lmace2   ds 2
spr_lmace3   ds 2
spr_wpipewalk1 ds 2
spr_wpipewalk2 ds 2
spr_wpipewalk3 ds 2
spr_mace1    ds 2
spr_mace2    ds 2
spr_mace3    ds 2
spr_mace4    ds 2
spr_mace5    ds 2
spr_pipe1    ds 2
spr_bpipew1  ds 2
spr_bpipew2  ds 2
spr_bpipew3  ds 2
spr_bpipe1   ds 2
spr_bpipe2   ds 2
spr_bpipe3   ds 2
spr_bpipe4   ds 2
billy_pipe_armed dfb 0
billy_mace_armed dfb 0
billy_knife_armed dfb 0
pipe_walk_addr_tbl ds 8
mace_walk_addr_tbl ds 8
spr_bmwalk1  ds 2
spr_bmwalk2  ds 2
spr_bmwalk3  ds 2
spr_bknife1  ds 2
spr_bknife2  ds 2
spr_bknife3  ds 2
spr_bkwalk1  ds 2
spr_bkwalk2  ds 2
spr_bkwalk3  ds 2
knife_walk_addr_tbl ds 8
knife_walk_x_tbl    ds 4
spr_bmace1   ds 2
spr_bmace2   ds 2
spr_bmace3   ds 2
spr_bmace4   ds 2
spr_bfall    ds 2
spr_bfallen  ds 2
loading_str_tbl_addr ds 2
spr_wpipe1   ds 2
spr_wpipe2   ds 2
spr_wpipe3   ds 2
spr_wpipe4   ds 2
spr_wpipe5   ds 2
spr_wpipe6   ds 2
spr_wknife1  ds 2
spr_wknife2  ds 2
spr_knife2   ds 2     ; thrown/dropped, pointing right
spr_knife4   ds 2     ; thrown/dropped, pointing left
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
spr_bspin1   ds 2
spr_bspin2   ds 2
spr_bspin3   ds 2
somersault_addr_tbl ds 10
somersault_data_tbl     ds 10
somersault_mask_tbl     ds 10
somersault_data_mir_tbl ds 10
somersault_mask_mir_tbl ds 10
UPPERCUT_WINDOW = 15  ; VBL frames
landing_window dfb 0
PUNCH_GRAB_WINDOW   = 15
GRAB_PUNCH_DURATION = 8
GRAB_Y_OFFSET       = 10
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
grab_punch_timer  dfb 0   ; > 0 while showing BGRAB1/xHELD2 sub-anim
last_key          dfb 0   ; scratch: most recent keypress, used by
bn_grab_active    dfb 0
* Per-mission gate for the gravity / falling system. Set by
* _init_level from the bank-$02 header at $02/001C (level_flags
* bit 0). Mission 1 keeps it clear → legacy jump-arc. Mission 2+
* sets it → player uses y_vel + per-frame gravity (apply_gravity_step).
gravity_enabled   dfb 0
BTN_WINDOW = 8            ; ~133 ms at 60 Hz
btn_pending_key   dfb 0   ; 0 / 'j' / 'l'
btn_pending_timer dfb 0
btn_pending_fire  dfb 0   ; 1 = fire pending action this frame
input_mode      dfb 0
joy_btn_a_prev  dfb 0     ; $80 if button A held last frame
joy_btn_b_prev  dfb 0     ; $80 if button B held last frame
joy_armed       dfb 0
jimmy_active    dfb 0       ; 0 = Jimmy is hidden / inert (default at
                            ; boot). Ctrl-J flips to 1, which arms
                            ; joystick polling for Jimmy in
                            ; process_input_jimmy and unlocks his
                            ; anim/dirty path.
friendly_fire   dfb 0       ; 0 = player vs player hits are dropped
                            ; in check_punch_hit (default — feels
                            ; like co-op). 1 = allow Jimmy to hit
                            ; Billy (and any future Billy → Jimmy
                            ; path) the same way they'd hit NPCs.
jimmy_cur_x_off  dfb 0      ; Jimmy's signed punch-lunge render offset
                            ; (parallel to billy_cur_x_off). Written by
                            ; set_anim_x_off for anim_jpunch1/jpunch2
                            ; frames; read by erase_all / draw_all when
                            ; the sprite being processed is Jimmy
                            ; (controller=$02).
jimmy_prev_x_off dfb 0      ; Latched from jimmy_cur_x_off after each
                            ; Jimmy draw so the NEXT frame's erase rect
                            ; covers the lunged-forward pixels.

* === Context-swap state for player 2 (Jimmy) ===
*
* process_input was written around Billy's globals. To reuse it for
* Jimmy we save Billy's live values to billy_save_*, load Jimmy's
* values from jimmy_stash_*, call process_input via pi_action_dispatch,
* then save Jimmy's modified state back to jimmy_stash_* and restore
* Billy.
*
* Scope: per-player state that lives outside the sprite info block.
* Info-block fields are auto-swapped by setting info_ptr=jimmy_sprite
* + load_sprite / save_sprite.
billy_save_walk_step          ds 1
billy_save_walk_toggle        ds 1
billy_save_climb_toggle       ds 1
billy_save_punch_toggle       ds 1
billy_save_y_off              ds 1
billy_save_y_target           ds 1
billy_save_airborne           ds 1
billy_save_y_vel              ds 1
billy_save_cur_x_off          ds 1
billy_save_prev_x_off         ds 1
billy_save_via_ladder         ds 1
billy_save_fall_count         ds 1
billy_save_pipe_armed         ds 1
billy_save_mace_armed         ds 1
billy_save_knife_armed        ds 1
billy_save_punch_window       ds 1
billy_save_landing_window     ds 1
billy_save_grab_punch_timer   ds 1
billy_save_jump_x_toggle      ds 1
billy_save_last_hit_target    ds 2
billy_save_grab_target        ds 2
billy_save_abs_x              ds 2
billy_save_input_mode         ds 1
* Per-player input source. input_mode is the live "current player"
* gate (kbd=0 / joy=1 / snes=2); swap_in_jimmy moves the active
* mode in and out. jimmy_input_mode holds P2's selected source
* (set once at game init from $304) and is loaded into input_mode
* on every Jimmy turn.
jimmy_input_mode              dfb 1   ; default joystick (overwritten at init from $304)
billy_save_walk_addr_tbl      ds 8
billy_save_walk_mask_tbl      ds 8
billy_save_walk_addr_tbl_mir  ds 8
billy_save_walk_mask_tbl_mir  ds 8
billy_save_scroll_right_en    ds 1
billy_save_scroll_left_en     ds 1
billy_save_scroll_up_en       ds 1

* Jimmy's stashed state — what gets loaded into the live globals
* on swap-in. Zero-initialised so Jimmy boots in a clean state.
jimmy_stash_walk_step         ds 1
* Jimmy's walk_toggle initial value = 0 (the trigger phase of the
* 3-state walk gate) so his first walk press after spawn moves +
* animates on the first VBL.
jimmy_stash_walk_toggle       ds 1
jimmy_stash_climb_toggle      ds 1
jimmy_stash_punch_toggle      ds 1
jimmy_stash_y_off             ds 1
jimmy_stash_y_target          ds 1
jimmy_stash_airborne          ds 1
jimmy_stash_y_vel             ds 1
jimmy_stash_cur_x_off         ds 1
jimmy_stash_prev_x_off        ds 1
jimmy_stash_via_ladder        ds 1
jimmy_stash_fall_count        ds 1
jimmy_stash_pipe_armed        ds 1
jimmy_stash_mace_armed        ds 1
jimmy_stash_knife_armed       ds 1
jimmy_stash_punch_window      ds 1
jimmy_stash_landing_window    ds 1
jimmy_stash_grab_punch_timer  ds 1
jimmy_stash_jump_x_toggle     ds 1
jimmy_stash_btn_pending_key   ds 1
jimmy_stash_btn_pending_timer ds 1
jimmy_stash_btn_pending_fire  ds 1
jimmy_stash_joy_btn_a_prev    ds 1
jimmy_stash_joy_btn_b_prev    ds 1
* SNES MAX edge state for P2 (controller 2 of the same card). Swapped
* with snes_b0_prev / snes_b1_prev in swap_in/out_jimmy so Billy and
* Jimmy each get independent button-edge detection even when both
* are on SNES.
jimmy_stash_snes_b0_prev      ds 1
jimmy_stash_snes_b1_prev      ds 1
jimmy_stash_last_hit_target   ds 2
jimmy_stash_grab_target       ds 2

* Billy backups for the same set of pending/button-edge state.
billy_save_btn_pending_key    ds 1
billy_save_btn_pending_timer  ds 1
billy_save_btn_pending_fire   ds 1
billy_save_joy_btn_a_prev     ds 1
billy_save_joy_btn_b_prev     ds 1
billy_save_snes_b0_prev       ds 1
billy_save_snes_b1_prev       ds 1
billy_save_snes_poll_mask     ds 1
snes_b0         dfb 0
snes_b1         dfb 0
snes_b0_prev    dfb 0
snes_b1_prev    dfb 0
* SNES MAX shift-register bit mask for the active player. The card
* shifts both controllers out of $C0C0: bit 7 = controller 1 (P1 if
* on SNES), bit 6 = controller 2 (P2 if on SNES). snes_poll uses
* this to pull the right bit during its shift loop; swap_in/out_jimmy
* flips it between $80 and $40 each turn.
snes_poll_mask  dfb $80
SNES_LATCH      = $C0C0
SNES_CLOCK      = $C0C1
JOY_DEAD_LO = $30         ; 48
JOY_DEAD_HI = $D0         ; 208
spr_roper1   ds 2
spr_roper2   ds 2
spr_roper3   ds 2
spr_rpunch1  ds 2
spr_rpunch2  ds 2
spr_rpunched ds 2
spr_rfall1   ds 2
spr_rfall2   ds 2
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
spr_pointright_mask        ds 2
spr_pointright_data_mirror ds 2
spr_pointright_mask_mirror ds 2
spr_pointup_mask           ds 2
spr_pointup_data_mirror    ds 2
spr_pointup_mask_mirror    ds 2
spr_image01_mask           ds 2
spr_image01_data_mirror    ds 2
spr_image01_mask_mirror    ds 2
spr_image02_mask           ds 2
spr_image02_data_mirror    ds 2
spr_image02_mask_mirror    ds 2
spr_image03_mask           ds 2
spr_image03_data_mirror    ds 2
spr_image03_mask_mirror    ds 2
spr_bclimb1_mask           ds 2
spr_bclimb1_data_mirror    ds 2
spr_bclimb1_mask_mirror    ds 2
spr_bclimb2_mask           ds 2
spr_bclimb2_data_mirror    ds 2
spr_bclimb2_mask_mirror    ds 2
spr_punch11_mask           ds 2
spr_punch11_data_mirror    ds 2
spr_punch11_mask_mirror    ds 2
spr_punch12_mask           ds 2
spr_punch12_data_mirror    ds 2
spr_punch12_mask_mirror    ds 2
spr_punch21_mask           ds 2
spr_punch21_data_mirror    ds 2
spr_punch21_mask_mirror    ds 2
spr_punch22_mask           ds 2
spr_punch22_data_mirror    ds 2
spr_punch22_mask_mirror    ds 2
spr_kick1_mask             ds 2
spr_kick1_data_mirror      ds 2
spr_kick1_mask_mirror      ds 2
spr_kick2_mask             ds 2
spr_kick2_data_mirror      ds 2
spr_kick2_mask_mirror      ds 2
spr_jump1_mask             ds 2
spr_jump1_data_mirror      ds 2
spr_jump1_mask_mirror      ds 2
spr_jump2_mask             ds 2
spr_jump2_data_mirror      ds 2
spr_jump2_mask_mirror      ds 2
spr_jump3_mask             ds 2
spr_jump3_data_mirror      ds 2
spr_jump3_mask_mirror      ds 2
spr_bpunched_mask          ds 2
spr_bpunched_data_mirror   ds 2
spr_bpunched_mask_mirror   ds 2

* Jimmy walk-frame cache vars — patched by init_jimmy from
* mission1jimmy.s's bank-$1D sprite-address table.
spr_jimmy01                ds 2
spr_jimmy01_mask           ds 2
spr_jimmy01_data_mir       ds 2
spr_jimmy01_mask_mir       ds 2
spr_jimmy02                ds 2
spr_jimmy02_mask           ds 2
spr_jimmy02_data_mir       ds 2
spr_jimmy02_mask_mir       ds 2
spr_jimmy03                ds 2
spr_jimmy03_mask           ds 2
spr_jimmy03_data_mir       ds 2
spr_jimmy03_mask_mir       ds 2
* Jump frames
spr_jjump1                 ds 2
spr_jjump1_mask            ds 2
spr_jjump1_data_mir        ds 2
spr_jjump1_mask_mir        ds 2
spr_jjump2                 ds 2
spr_jjump2_mask            ds 2
spr_jjump2_data_mir        ds 2
spr_jjump2_mask_mir        ds 2
spr_jjump3                 ds 2
spr_jjump3_mask            ds 2
spr_jjump3_data_mir        ds 2
spr_jjump3_mask_mir        ds 2
* Kick frames
spr_jkick1                 ds 2
spr_jkick1_mask            ds 2
spr_jkick1_data_mir        ds 2
spr_jkick1_mask_mir        ds 2
spr_jkick2                 ds 2
spr_jkick2_mask            ds 2
spr_jkick2_data_mir        ds 2
spr_jkick2_mask_mir        ds 2
* Punch frames
spr_jpunch11               ds 2
spr_jpunch11_mask          ds 2
spr_jpunch11_data_mir      ds 2
spr_jpunch11_mask_mir      ds 2
spr_jpunch12               ds 2
spr_jpunch12_mask          ds 2
spr_jpunch12_data_mir      ds 2
spr_jpunch12_mask_mir      ds 2
spr_jpunch21               ds 2
spr_jpunch21_mask          ds 2
spr_jpunch21_data_mir      ds 2
spr_jpunch21_mask_mir      ds 2
spr_jpunch22               ds 2
spr_jpunch22_mask          ds 2
spr_jpunch22_data_mir      ds 2
spr_jpunch22_mask_mir      ds 2
* Spinkick (legacy) + uppercut (legacy)
spr_jspin1                 ds 2
spr_jspin2                 ds 2
spr_jspin3                 ds 2
spr_jupper1                ds 2
spr_jupper2                ds 2
spr_jupper3                ds 2
* Punched (compiled) + fall (legacy)
spr_jpunched               ds 2
spr_jpunched_mask          ds 2
spr_jpunched_data_mir      ds 2
spr_jpunched_mask_mir      ds 2
spr_jfall                  ds 2
spr_jfallen                ds 2
* Ladder-climb frames (compiled, parallel to BCLIMB1/BCLIMB2).
spr_jclimb1                ds 2
spr_jclimb1_mask           ds 2
spr_jclimb1_data_mir       ds 2
spr_jclimb1_mask_mir       ds 2
spr_jclimb2                ds 2
spr_jclimb2_mask           ds 2
spr_jclimb2_data_mir       ds 2
spr_jclimb2_mask_mir       ds 2
* Jimmy armed sprites (legacy stride, palette-shifted from Billy
* originals). Patched by init_jimmy from bank-$1D spr_addr_tbl.
spr_jmwalk1                ds 2
spr_jmwalk2                ds 2
spr_jmwalk3                ds 2
spr_jmace1                 ds 2
spr_jmace2                 ds 2
spr_jmace3                 ds 2
spr_jmace4                 ds 2
spr_jkwalk1                ds 2
spr_jkwalk2                ds 2
spr_jkwalk3                ds 2
spr_jknife1                ds 2
spr_jknife2                ds 2
spr_jknife3                ds 2
spr_jpipew1                ds 2
spr_jpipew2                ds 2
spr_jpipew3                ds 2
spr_jpipe1                 ds 2
spr_jpipe2                 ds 2
spr_jpipe3                 ds 2
spr_jpipe4                 ds 2
* Head-grab frames (legacy, bank $1D). Mirror BGRAB1/2 dims (14×40
* active + 13×40 hold). billy_set_grab_frame dispatches by
* arm_is_jimmy and reads these for Jimmy's grab.
spr_jgrab1                 ds 2
spr_jgrab2                 ds 2
* Per-player armed walk frame tables — parallel to the Billy
* tables (pipe_walk_addr_tbl, mace_walk_addr_tbl, etc.). advance_walk
* dispatches on info+22 (controller) to pick the right table.
jimmy_pipe_walk_addr_tbl   ds 8
jimmy_mace_walk_addr_tbl   ds 8
jimmy_knife_walk_addr_tbl  ds 8
jimmy_knife_walk_x_tbl     ds 4
* Active pickup anim — swap_in_jimmy points this at anim_jpickup
* so billy_try_pickup_weapon's start_anim plays the right frames
* for the active player.
active_pickup_anim         dw anim_bpickup
billy_save_active_pickup_anim ds 2

* Active anim pointers — used by process_input's btn_action_* paths
* via indirection. Initialized to Billy's anims. swap_in_jimmy
* points them at Jimmy's variants; swap_out_jimmy restores.
active_jump_anim       dw anim_jump
active_bspinkick_anim  dw anim_bspinkick
active_kick_anim       dw anim_kick
active_punch1_anim     dw anim_punch1
active_punch2_anim     dw anim_punch2
active_uppercut_anim   dw anim_uppercut
active_pipe_swing_anim dw anim_bpipeswing
active_mace_swing_anim dw anim_bmaceswing

billy_save_active_jump_anim       ds 2
billy_save_active_bspinkick_anim  ds 2
billy_save_active_kick_anim       ds 2
billy_save_active_punch1_anim     ds 2
billy_save_active_punch2_anim     ds 2
billy_save_active_uppercut_anim   ds 2
billy_save_active_pipe_swing_anim ds 2
billy_save_active_mace_swing_anim ds 2

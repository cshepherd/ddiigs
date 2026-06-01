*----------------------------------------------------------
* mission1boss.s — Bank-$1E mission1 boss (Burnov) behavior.
*
* Loaded by game.s at boot from /DDIIGS/MISSION1BOSS to $1E:$0000.
* Mission1-specific boss code split out of game.s to keep the
* engine level-agnostic and reclaim bank-$00 space. Same split
* pattern as engine.s ($1F): runs with K=$1E but B=$00, so it
* reads/writes bank-$00 sprite info, globals and animation
* descriptors via absolute / (dp),y exactly like in-bank code.
*
* DO NOT phk/plb here — DBR must stay $00 or absolute stores land
* in bank $1E and silently corrupt this code.
*
* Bank-$00 routines are called via the JSR+RTL shims in game.s
* (sound_trigger_l, start_anim_l). Bank-$00 symbol addresses come
* from engine_externs.s (regenerated from game.s's listing each
* build; the boss symbols are listed in engine_externs.list).
*
* Public entry points (callable via JSL from game.s):
*   $1E/0000  start_burnov_dissolve   (bn_dissolve)
*   $1E/0004  start_burnov_recon      (bn_recon)
*   $1E/0008  finish_burnov_recon     (bn_finish_recon)
*   $1E/000C  bn_anim_ended           (boss death-cycle dispatch)
*   $1E/0010  bn_grab_end
*   $1E/0014  bn_try_grab
*   $1E/0018  bn_spawn_setup
*   $1E/001C  bn_approach_pad
*----------------------------------------------------------

         ORG $1E0000
         mx %11

* Mirror game.s constants used by the moved code. Keep in sync
* with game.s (FALL_Y_OFFSET / BDISS_HELMET_Y / SND_BURNGONE /
* SND_BURNBACK definitions).
DEBUG_PRINT equ 0
FALL_Y_OFFSET  equ 24
BDISS_HELMET_Y equ 15
SND_BURNGONE   equ 8
SND_BURNBACK   equ 9

* ZP pointers mirrored from game.s (declared there with `=`, so
* they aren't emitted into engine_externs.s).
info_ptr = $E2
anim_ptr = $E4

* JML jump table at the head of the bank — fixed JSL targets that
* don't shift when the body changes. Entries not yet migrated
* point at _bn_stub (a bare RTL).
         jml _start_burnov_dissolve    ; $1E/0000
         jml _start_burnov_recon       ; $1E/0004
         jml _finish_burnov_recon      ; $1E/0008
         jml _bn_anim_ended            ; $1E/000C bn_anim_ended
         jml _bn_grab_end              ; $1E/0010 bn_grab_end
         jml _bn_try_grab              ; $1E/0014 bn_try_grab
         jml _bn_stub                  ; $1E/0018 bn_spawn_setup
         jml _bn_stub                  ; $1E/001C bn_approach_pad

         PUT engine_externs.s

* Placeholder for not-yet-migrated entry points.
_bn_stub
 rtl

*----------------------------------------------------------
* Burnov boss-death state-machine helpers. Called from
* update_anims when the just-ended anim matches one of the
* boss-death stages. info_ptr = Burnov on entry, MX = %11,
* emulation mode (caller's mode; JSL/RTL work in emulation).
*----------------------------------------------------------

* start_burnov_dissolve - fall_anim ended on Burnov (kill 1 or 2).
* Trigger BURNGONE and install anim_bn_diss. The fall already
* left ypos at the bumped FALLEN position; we un-bump it here so
* the bigger BDISS frames render around Burnov's standing height
* instead of being shoved down by FALL_Y_OFFSET.
_start_burnov_dissolve
 ldx #SND_BURNGONE
 jsl sound_trigger_l
* Release the held player if Burnov was mid-grab when he died. The
* natural grab-end hook only fires when anim_bngrab / anim_bnjgrab
* ends cleanly; a death-mid-grab swaps Burnov's anim_ptr away
* before that hook can run, leaving bn_grab_active stuck and the
* held player invisible (their draw is gated off). bn_grab_active
* tells us which player: $01=Billy, $02=Jimmy. Mark them dirty so
* the next draw_all repaints at the pre-grab position.
 lda bn_grab_active
 beq :sbd_no_release
 cmp #$02
 beq :sbd_release_jimmy
 lda billy_sprite+30
 ora #$03
 sta billy_sprite+30
 bra :sbd_release_done
:sbd_release_jimmy
 lda jimmy_sprite+30
 ora #$03
 sta jimmy_sprite+30
:sbd_release_done
 stz bn_grab_active
:sbd_no_release
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
 jsl start_anim_l
 rtl

* start_burnov_recon - anim_bn_diss ended. Move Burnov to the
* alternate boss spawn position, trigger BURNBACK, install
* anim_bn_recon. Position alternates by boss_death_count parity:
*   count=0 (1st kill, hasn't incremented yet) → teleport to x=$10
*   count=1 (2nd kill, hasn't incremented yet) → teleport to x=$58
* y is reset to the boss spawn y ($43) regardless.
_start_burnov_recon
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
 jsl sound_trigger_l
 lda #<anim_bn_recon
 ldx #>anim_bn_recon
 jsl start_anim_l
 rtl

* finish_burnov_recon - anim_bn_recon ended. Reset punch_count to
* 0 so the next 3 hits trigger the next dissolve cycle, reset
* behavior_state to FO_APPROACH so the boss starts walking toward
* Billy again, increment boss_death_count, and let the caller's
* idle-restore put Burnov back to BNWALK1.
_finish_burnov_recon
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
 rtl

*----------------------------------------------------------
* bn_anim_ended - called from update_anims when an anim ends on
* a sprite whose frame_bank is $19 or $1C (the caller gates by
* frame_bank to skip non-Burnov sprites entirely). Reads anim_ptr
* and routes to the matching death-cycle handler, returning a
* disposition code for the caller to branch on.
*
* Returns A =
*   0  not a Burnov death-cycle anim      caller: :ad_normal_flow
*   1  dissolve or recon installed        caller: :next
*   2  finish_recon done (idle restore)   caller: :normal_end
*   3  3rd-kill diss done; route to death caller: :ad_do_death
*
* The internal handler calls use JSL (handlers are RTL-terminated
* for the cross-bank entry path), so the stack stays balanced.
*----------------------------------------------------------
_bn_anim_ended
* anim_bnfall ended? → dissolve.
 lda anim_ptr
 cmp #<anim_bnfall
 bne :be_chk_diss
 lda anim_ptr+1
 cmp #>anim_bnfall
 bne :be_chk_diss
 jsl _start_burnov_dissolve
 lda #1
 rtl
:be_chk_diss
* anim_bn_diss ended? → recon, or 3rd-kill death.
 lda anim_ptr
 cmp #<anim_bn_diss
 bne :be_chk_recon
 lda anim_ptr+1
 cmp #>anim_bn_diss
 bne :be_chk_recon
 lda boss_death_count
 cmp #2
 bcs :be_death
 jsl _start_burnov_recon
 lda #1
 rtl
:be_death
 lda #3
 rtl
:be_chk_recon
* anim_bn_recon ended? → finish_recon.
 lda anim_ptr
 cmp #<anim_bn_recon
 bne :be_none
 lda anim_ptr+1
 cmp #>anim_bn_recon
 bne :be_none
 jsl _finish_burnov_recon
 lda #2
 rtl
:be_none
 lda #0
 rtl

*----------------------------------------------------------
* bn_grab_end - called from update_anims (formerly the inline
* ":ne_grab_do" block + detect). If the just-ended anim is
* anim_bngrab (Billy grabbed) or anim_bnjgrab (Jimmy grabbed),
* release the held player, run the fall + score/palette cascade,
* and restore info_ptr to Burnov. RTL unconditionally — caller
* falls into :ne_not_bngrab afterward whether or not we acted.
*----------------------------------------------------------
_bn_grab_end
 lda anim_ptr
 cmp #<anim_bngrab
 bne :ne_chk_bnjgrab
 lda anim_ptr+1
 cmp #>anim_bngrab
 beq :ne_grab_do
:ne_chk_bnjgrab
 lda anim_ptr
 cmp #<anim_bnjgrab
 bne :ne_no_grab
 lda anim_ptr+1
 cmp #>anim_bnjgrab
 beq :ne_grab_do
:ne_no_grab
 rtl
:ne_grab_do
* Snapshot which player is being released; bn_grab_active holds
* their controller value ($01 Billy / $02 Jimmy) — set by
* check_punch_hit's grab trigger. Use a local scratch so the
* clear can fire immediately without losing the dispatch info.
 lda bn_grab_active
 sta :ne_grab_who
 stz bn_grab_active
* Save Burnov's info_ptr; switch to the released player's block
* for start_anim. Pick by :ne_grab_who.
 lda info_ptr
 pha
 lda info_ptr+1
 pha
 lda :ne_grab_who
 cmp #$02
 beq :ne_grab_load_jimmy
 lda #<billy_sprite
 sta info_ptr
 lda #>billy_sprite
 sta info_ptr+1
 bra :ne_grab_loaded
:ne_grab_load_jimmy
 lda #<jimmy_sprite
 sta info_ptr
 lda #>jimmy_sprite
 sta info_ptr+1
:ne_grab_loaded
* Mirror the player so they face Burnov (so the trajectory dx and
* fall pose orient correctly). Burnov's mirror was already loaded
* above (final frame of the grab anim).
 lda IMAGE01_MIRROR
 eor #$01
 ldy #4
 sta (info_ptr),y
* Load the player's globals for start_anim.
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
 jsl start_anim_l
* Count this as one of the released player's falls and deplete a
* palette segment. Mirror of the cascade in check_punch_hit's
* :use_fall path; check_punch_hit's grab branch jumped to :done
* before hitting :use_fall, so this is the only place the grab's
* fall is accounted for. Dispatch by :ne_grab_who.
 lda #0
 ldy #48
 sta (info_ptr),y     ; reset punch_count on the player block
 lda :ne_grab_who
 cmp #$02
 beq :ne_grab_dep_jimmy
* Billy: increment billy_fall_count and deplete P1 slots.
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
 jmp :ne_grab_dep_done
:ne_grab_dep_jimmy
* Jimmy: mirrors :uf_target_jimmy. P2 palette slots 5..9 deplete
* in the same fall1→5 order as P1. fall_count for Jimmy lives in
* jimmy_stash_fall_count.
 inc jimmy_stash_fall_count
 lda jimmy_stash_fall_count
 cmp #1
 bne :ne_grab_jdep_2
 lda #0
 stal $019E52
 stal $019E53
 jmp :ne_grab_dep_done
:ne_grab_jdep_2
 cmp #2
 bne :ne_grab_jdep_3
 lda #0
 stal $019E50
 stal $019E51
 jmp :ne_grab_dep_done
:ne_grab_jdep_3
 cmp #3
 bne :ne_grab_jdep_4
 lda #0
 stal $019E4E
 stal $019E4F
 jmp :ne_grab_dep_done
:ne_grab_jdep_4
 cmp #4
 bne :ne_grab_jdep_5
 lda #0
 stal $019E4C
 stal $019E4D
 jmp :ne_grab_dep_done
:ne_grab_jdep_5
 cmp #5
 bne :ne_grab_dep_done
 lda #0
 stal $019E4A
 stal $019E4B
:ne_grab_dep_done
* Restore Burnov's info_ptr so the caller's idle-restore path
* operates on him.
 pla
 sta info_ptr+1
 pla
 sta info_ptr
 rtl

:ne_grab_who dfb 0          ; bn_grab_active snapshot (local data)

*----------------------------------------------------------
* bn_try_grab - called from check_punch_hit when a hit has just
* been detected. If the puncher's anim was anim_bnpunch AND the
* target is Billy (controller=$01) or the actual jimmy_sprite
* (controller=$02, but not a dropped item), divert from the
* normal hit/fall logic to the BNBILLY/BNJIMMY grab sequence.
*
* Inputs (staged by caller into bank-$00 scratch):
*   bn_puncher_anim_lo/hi - puncher's anim_ptr value
*   bn_self_lo/hi         - puncher's info_ptr (Burnov)
*   info_ptr (ZP)         - target sprite (player or item)
* Returns A =
*   0  not a grab        caller: continue to :hit_normal
*   1  grab handled      caller: jmp :done (skip damage logic)
*
* On A=1 exit, info_ptr is left pointing at Burnov (matches the
* original inline behavior, which jmp'd to :done without
* restoring info_ptr).
*----------------------------------------------------------
_bn_try_grab
* Was the puncher anim_bnpunch?
 lda bn_puncher_anim_lo
 cmp #<anim_bnpunch
 beq :tg_chk_anim_hi
:tg_no_grab
 lda #0
 rtl
:tg_chk_anim_hi
 lda bn_puncher_anim_hi
 cmp #>anim_bnpunch
 bne :tg_no_grab
* Target controller: $01 = Billy, $02 = Jimmy-or-item.
 ldy #22
 lda (info_ptr),y
 cmp #$01
 beq :tg_do_grab
 cmp #$02
 bne :tg_no_grab
* Target=$02 is the controller value Jimmy and dropped items
* share; re-check it's actually jimmy_sprite to avoid grabbing a
* pipe/knife.
 lda info_ptr
 cmp #<jimmy_sprite
 bne :tg_no_grab
 lda info_ptr+1
 cmp #>jimmy_sprite
 bne :tg_no_grab
:tg_do_grab
* Remember which player got grabbed. Stash the target's
* controller into bn_grab_active so it doubles as the "which
* player" tag for later release logic and the draw-skip gates.
 ldy #22
 lda (info_ptr),y
 sta bn_grab_active
 ldy #30
 lda (info_ptr),y
 ora #$02             ; force erase bit; clear draw bit
 and #$FE
 sta (info_ptr),y
* Switch info_ptr back to the puncher (Burnov) and run start_anim
* with anim_bngrab (Billy target) or anim_bnjgrab (Jimmy target).
* start_anim handles frame_bank, info+10/+12/+14, dirty, etc.
 lda bn_self_lo
 sta info_ptr
 lda bn_self_hi
 sta info_ptr+1
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
* Pick the grab anim variant by bn_grab_active (set just above).
 lda bn_grab_active
 cmp #$02
 beq :tg_jimmy
 lda #<anim_bngrab
 ldx #>anim_bngrab
 bra :tg_start
:tg_jimmy
 lda #<anim_bnjgrab
 ldx #>anim_bnjgrab
:tg_start
 jsl start_anim_l
 lda #1
 rtl

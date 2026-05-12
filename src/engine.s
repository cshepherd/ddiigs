*----------------------------------------------------------
* engine.s — Bank-$1F engine code: scroll/blit pipeline.
*
* Loaded by game.s at boot from /DDIIGS/ENGINE to $1F:$0000.
* Bank $00 is too full to hold the engine plus all the scroll
* code, so we split the heavy memcpy-style routines off into
* their own bank. They still touch bank-$00 globals (DBR=$00 on
* entry — caller preserves it), so the code reads like normal
* in-bank assembly; only the program counter lives at $1F.
*
* Public entry points (callable via JSL from game.s):
*   $1F/0000  scroll_right
*   $1F/0004  scroll_left
*   $1F/0008  scroll_up
*
* Internal helpers (push_band, fast_blit_18_01, compute_up_align)
* are called intra-bank via JSR and not exposed.
*
* All bank-$00 symbol addresses come from engine_externs.s, which
* tools/extract_externs.py regenerates from game.s's listing on
* every build.
*----------------------------------------------------------

         ORG $1F0000
         mx %11

* Mirror game.s's DEBUG_PRINT switch so `do DEBUG_PRINT/fin` blocks
* in the moved scroll code assemble identically here. Keep in sync
* with the game.s definition.
DEBUG_PRINT equ 0

* ZP-pointer addresses that game.s declares as `=` equates — those
* don't appear in the listing as bindings the extractor can read,
* so we mirror them here. Keep in sync with game.s.
info_ptr = $E2

* JML jump table at the head of the bank — gives game.s fixed
* JSL targets that don't shift when engine.s body changes.
         jml _scroll_right             ; $1F/0000
         jml _scroll_left              ; $1F/0004
         jml _scroll_up                ; $1F/0008

         PUT engine_externs.s

*----------------------------------------------------------
* Moved verbatim from game.s with the following transforms:
*   - scroll_right/_left/_up renamed with leading underscore
*     to match the jump-table targets.
*   - each entry point's RTS exits converted to RTL.
*   - JSRs to bank-$00 helpers (shadow_off, shadow_on,
*     draw_active_sprite, draw_overlay, inc_border,
*     load_screen_bounds) become JSL to their _l trampolines.
*   - everything else (variables, internal helpers, locals)
*     migrates unchanged.
*----------------------------------------------------------

*----------------------------------------------------------
* scroll_right - Scroll playfield 1 byte (2 pixels) right.
* 1) Shift bytes 1-110 left by one in bank $18 for 183 lines
* 2) Fill right edge from bank $51 (x_scroll_idx bytes)
* 3) Blit 110-byte wide playfield from $18 to $E1
* 4) Redraw sprite
*----------------------------------------------------------
_scroll_right
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
 jsl shadow_off_l

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
 sta fsg_off
 lda #110
 sec
 sbc fsg_off
 sta fsg_count1       ; count_curr (1 or 3)
 lda #4
 sec
 sbc fsg_count1
 sta fsg_count2       ; count_next (3 or 1)
* --- Phase 1 setup ---
 rep $20
 mx %00
 lda fsg_off
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
 lda fsg_count1
 sta fsg_curr
 ldy #0
:fsg_p1_byte
 lda [$F0],y
 sta [$F3],y
 iny
 dec fsg_curr
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
 adc fsg_count1
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
 lda fsg_count2
 sta fsg_curr
 ldy #0
:fsg_p2_byte
 lda [$F0],y
 sta [$F3],y
 iny
 dec fsg_curr
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
 lda fsg_count2
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
 jsl draw_active_sprite_l
 jsl draw_overlay_l

* Step 5: Re-enable shadow and propagate the staged $01 to $E1
* via push_band over the full playfield (rows 0..182). Shadow
* stays ON after we return so game_loop's erase/draw operations
* propagate to $E1 in the normal way.
 clc
 xce                   ; native mode
 rep $30
 jsl shadow_on_l
 lda #0
 sep $20
 sta push_ymin
 lda #182
 sta push_ymax
 rep $20
 jsr push_band

 sec
 xce                   ; back to emulation mode
 rtl


*----------------------------------------------------------
* scroll_left - Mirror of scroll_right.
* Shift each scanline 4 bytes RIGHT in bank $18, then fill
* the leftmost 4 bytes (offsets 0-3) from the previous
* screen's source bank.
*----------------------------------------------------------
_scroll_left
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
 rtl
:sl_reset_off
 lda #50
 sta scroll_lsrc_off
:sl_proceed
* Phase 2 pipeline: shadow off while we stage on $01, then
* shadow on + push_band to atomically propagate to $E1. No
* flicker-cover needed because $E1 keeps showing the previous
* frame's content throughout the staging window.
 jsl shadow_off_l

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
 sta old_lo
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
 sbc old_lo
 sta nfp
 lda #1
 clc
 adc old_lo
 sta nfc
 lda #110
 sec
 sbc nfp
 sta prev_start

* --- Split pass 1: copy nfp bytes from (lsrc_bank-1) ---
 rep $20
 mx %00
 lda prev_start
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
 cpy nfp
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
 lda nfp
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
 cpy nfc
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
 lda old_lo
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
 jsl draw_active_sprite_l
 jsl draw_overlay_l
 clc
 xce
 rep $30
 jsl shadow_on_l
 lda #0
 sep $20
 sta push_ymin
 lda #182
 sta push_ymax
 rep $20
 jsr push_band
 sec
 xce
 rtl

* scroll_left scratch

*----------------------------------------------------------
* scroll_up - Vertical scroll: shift all rows DOWN by 4 in
* bank $18, then fill the top 4 rows from scroll_up_bank
* (the screen ABOVE) at scroll_up_off (counts down from 182).
* When scroll_up_off would go below 3, snap-transition: copy
* the entire source bank to $18 and update current_screen.
*----------------------------------------------------------
_scroll_up
* Phase 2 pipeline: shadow off while we stage on $01. Both the
* incremental (:su_normal) and :snap_transition paths end with
* shadow_on + push_band to atomically propagate to $E1.
 jsl shadow_off_l

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
 jsl load_screen_bounds_l
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
 sta rg1_count
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
 cpy rg1_count
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
 sta rg2_count
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
 cpy rg2_count
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
 sta ffs_s9_count      ; count = 330 - wo (= scr9 visible bytes)
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
 cpy ffs_s9_count
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
 sta ffs_count         ; count = wo - 220 (= scr8 visible bytes)
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
 cpy ffs_count
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
 sta ufill_top
 rep $20
 mx %00

* Compute src addr = $2000 + ufill_top * $A0
 lda ufill_top
 and #$00FF
 sta utmp
 asl
 asl                    ; *4
 clc
 adc utmp              ; *5
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
 sta snap_wo_delta
 lda scroll_up_anchor
 sta world_offset
 jsr compute_up_align
 lda snap_wo_delta
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
 lda ufill_top
 and #$00FF
 sta utmp
 asl
 asl
 clc
 adc utmp
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
 sta rgap_start        ; first unfilled byte on right
 cmp #110
 bcs :rgap_done         ; no gap (filled to edge)
 lda #110
 sec
 sbc rgap_start
 sta rgap_count        ; bytes to fill from right neighbor
* Source: rbank/(2000 + (off-3)*$A0 + 0) — leftmost bytes
 lda ufill_top
 and #$00FF
 sta utmp
 asl
 asl
 clc
 adc utmp
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
 adc rgap_start
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
 cpy rgap_count
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
 jsl draw_active_sprite_l
 jsl draw_overlay_l
 clc
 xce
 rep $30
 jsl shadow_on_l
 lda #0
 sep $20
 sta push_ymin
 lda #182
 sta push_ymax
 rep $20
 jsr push_band
 sec
 xce
 rtl

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
 do DEBUG_PRINT
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
 fin
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
 sta snap_wo_delta
 lda scroll_up_anchor
 sta world_offset
 jsr compute_up_align
 lda snap_wo_delta
 sta world_offset
 bra :snap_compute_done
:snap_no_pin
 jsr compute_up_align
:snap_compute_done
* DEBUG: one-line dump of world_offset / anchor / up_dst_start at
* snap time so we can see whether the post-snap position drifts
* run-to-run. Switch to emulation to use ROM COUT, then restore
* native 16-bit mode for the rest of snap_transition. Whole
* block is conditional on DEBUG_PRINT — including the mode
* swaps, since they're only here for the print.
 do DEBUG_PRINT
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
 fin
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
 sta rgap_start
 cmp #110
 bcs :snap_rgap_done
 lda #110
 sec
 sbc rgap_start
 sta rgap_count
 lda #$2000
 sta $F0                ; src = rbank/(2000) — leftmost bytes
 lda #$2000
 clc
 adc rgap_start
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
 cpy rgap_count
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
 sta snap_lo_s9_count ; count = 330 - wo
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
 cpy snap_lo_s9_count
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
 sta lower_rgap_count ; count = wo - 220
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
 cpy lower_rgap_count
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
 lda lower_rgap_count
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
 jsl load_screen_bounds_l     ; needs A = screen index — call before inc_border
 jsl inc_border_l             ; new screen scrolled in (vertical)
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
 sta billy_sprite+60
 lda spr_image01_mask+1
 sta MASK_ADDR+1
 sta billy_sprite+61
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
 sta billy_sprite+60
 lda spr_image01_mask_mirror+1
 sta MASK_ADDR+1
 sta billy_sprite+61
:st_mask_done
 stz climb_toggle       ; next climb starts on BCLIMB1
* Disable the ladder Billy just climbed by locating it from his
* current world_x and setting y_top=255 so check_ladder fails
* for any proposed y. Prevents re-climbing "invisible" after snap.
 lda ladder_count
 bne :dl_have
 jmp :dl_done          ; no ladders — skip scan; far branch
:dl_have
 sta dl_cnt
 clc
 lda IMAGE01_XPOS
 adc world_offset
 sta dl_wx
 lda #0
 adc world_offset+1
 sta dl_wx+1
 ldx #0
:dl_scan
 lda dl_wx+1
 cmp ladder_buf+1,x    ; x_left high
 bcc :dl_next
 bne :dl_ge_lf
 lda dl_wx
 cmp ladder_buf,x      ; x_left low
 bcc :dl_next
:dl_ge_lf
 lda ladder_buf+3,x    ; x_right high
 cmp dl_wx+1
 bcc :dl_next
 bne :dl_le_rt
 lda ladder_buf+2,x    ; x_right low
 cmp dl_wx
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
 sta ldr_ctr
 lda ladder_buf+1,x     ; x_left high
 adc ladder_buf+3,x     ; x_right high
 sta ldr_ctr+1
 lsr ldr_ctr+1
 ror ldr_ctr
* world_offset := scroll_up_anchor
 lda scroll_up_anchor
 sta world_offset
 lda scroll_up_anchor+1
 sta world_offset+1
* IMAGE01_XPOS := ladder_center - anchor - 4 (sprite half-width
* compensation so Billy's visual center sits on scr12_center,
* matching the mid-climb formula).
 sec
 lda ldr_ctr
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
 lda ldr_ctr
 sbc #4
 sta abs_x
 lda ldr_ctr+1
 sbc #0
 sta abs_x+1
 bra :dl_done
:dl_next
 txa
 clc
 adc #6
 tax
 dec dl_cnt
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
 jsl draw_active_sprite_l
 jsl draw_overlay_l
 clc
 xce
 rep $30
 jsl shadow_on_l
 lda #0
 sep $20
 sta push_ymin
 lda #182
 sta push_ymax
 rep $20
 jsr push_band
 sec
 xce
 rtl

* scroll_up scratch — must be 2 bytes since 16-bit stores
* land here.


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
 sta pb_save_s

* Compute X = push_ymin * $A0 and Y = row count BEFORE enabling
* WrCardRAM. Once $C005 is set, ANY bank-$00 store in $0200-$BFFF
* gets redirected to bank $01 — so pb_tmp would corrupt the SHR
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
 sta pb_tmp
 asl
 asl                   ; *128
 clc
 adc pb_tmp           ; *160
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

 lda pb_save_s
 tcs
 cli
 rts


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

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

* push_band's mid-row SP save slot. Must live OUTSIDE the
* WrCardRAM redirect range ($0200-$BFFF) — push_band has
* WrCardRAM ON so any `sta abs` to $0200-$BFFF goes to bank $01
* instead of bank $00, but `lda abs` still reads from bank $00.
* That mismatch made the original $1C54 address unusable: the
* save vanished into SHR display memory and the restore loaded
* stale data. Address $00E0 is in zero page (untouched by
* WrCardRAM); $E0-$E1 currently hold `spr_ptr` in game.s but
* that's only used between game-loop iterations, not during
* push_band, so we can borrow it as scratch here.
*
* Actually safer: use bank-$00 page $01 (the stack area), which
* is also outside WrCardRAM redirect. Pick $0150 — well clear
* of any plausible runtime SP encroachment.
pb_sp_mid equ $000150

* ZP-pointer addresses that game.s declares as `=` equates — those
* don't appear in the listing as bindings the extractor can read,
* so we mirror them here. Keep in sync with game.s.
info_ptr = $E2

* JML jump table at the head of the bank — gives game.s fixed
* JSL targets that don't shift when engine.s body changes.
         jml _scroll_right             ; $1F/0000
         jml _scroll_left              ; $1F/0004
         jml _scroll_up                ; $1F/0008
         jml _init_level               ; $1F/000C
         jml _init_mission12           ; $1F/0010
         jml _init_mission13           ; $1F/0014
         jml _init_mission14           ; $1F/0018
         jml _init_jimmy               ; $1F/001C
         jml _init_mission12blit       ; $1F/0020
         jml _init_mission14blit       ; $1F/0024
         jml _init_mission13blit       ; $1F/0028
         jml _init_mission1blit        ; $1F/002C
         jml _init_mission1jimmyblit   ; $1F/0030
         jml _scroll_down              ; $1F/0034
         jml _scroll_up_split          ; $1F/0038

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

* Step 1 (unrolled long-absolute,X shift): Shift each scanline
* 4 bytes left in bank $18. Using absolute-long indexed
* (`ldal $182004,x / stal $182000,x`, 6+6=12 cycles per word,
* M=16) plus a fully unrolled 53-word body cuts per-row work
* roughly in half vs the old long-indirect `lda [$F0],y /
* sta [$F3],y` (8+8 = 16 cycles per word PLUS iny/cpy/bcc =
* 26 cycles per word).
*
* Earlier attempt used direct-page addressing (`lda <$04`,
* 10 cycles/word) but that required setting DBR=$18 + DP=$2000
* across the entire shift loop. Any IRQ firing in that window
* (NTPstreamsound runs every few hundred cycles) inherited the
* changed DBR/DP and mis-addressed its state — observed as
* a crash with PC landing in draw_overlay's `lda #$02 / sta
* sprite_bank` after scroll_right returned.
*
* long-absolute,X is IRQ-safe: each instruction carries its
* full 24-bit base address, no DBR/DP dependence.
*
 ldx #0                ; X = row byte offset (row * $A0)
:shift_line
]src = $182004
]dst = $182000
 LUP 53
 ldal ]src,x
 stal ]dst,x
]src = ]src+2
]dst = ]dst+2
 --^
* After LUP expansion ]src=$18206E, ]dst=$18206A — covered
* offsets $04..$6C read into $00..$68 write = 53 words = 106
* bytes shifted left by 4 per row. The LUP assembles ONCE;
* the 53 hardcoded (ldal,x / stal,x) pairs re-execute for
* every row in the runtime loop below. X is the per-row byte
* stride ($A0 per row); each LDAL/STAL pair adds the literal
* base, so we don't need to update any pointer state per row.

 txa
 clc
 adc #$00A0
 tax                   ; X += $A0 (next row)
 cpx #$7260            ; 183 * $A0 = $7260 — stop after processing row 182
 bcs :shift_done
 jmp :shift_line       ; inverted — LUP body (~424 bytes for 53
                       ; unrolled BF/9F instructions of 4 bytes
                       ; each) pushes :shift_line well outside
                       ; BCC's +/-128 range.
:shift_done

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
* On entry: M=8 (from earlier sep $20 before the dispatch branch).
* We want M=16 throughout this routine except for the 1-byte bank
* stores into $F2/$F5. Each mode transition needs both the CPU
* (sep/rep) AND Merlin's tracker (mx %xx) updated — Merlin doesn't
* follow sep/rep on its own, and a missing mx leaves operand sizes
* out of sync with runtime M, producing 16-bit immediates the CPU
* truncates to 8-bit + executes the high byte as the next opcode
* (= $00 → BRK landing in the middle of the fill code).
 rep $20
 mx %00
 lda #$206A            ; dst = $18/(2000 + 106) = row 0 byte 106
 sta $F3
 sep $20
 mx %10
 lda #$18
 sta $F5
* Vertical-split decision: split_row != 0 → upper bank for the
* first split_row rows, then lower bank for the rest. split_row==0
* keeps the legacy single-bank behavior (= scroll_src_bank for all
* 183 rows).
 lda scroll_src_split_row
 bne :fn_split_jmp
 jmp :fn_no_split
:fn_split_jmp
* Pass A setup. Switch to M=16 for the 16-bit arithmetic.
 rep $20
 mx %00
 lda scroll_src_upper_row_offset
 and #$00FF
 sta utmp
 asl
 asl                          ; *4
 clc
 adc utmp                     ; *5
 asl
 asl
 asl
 asl
 asl                          ; *160 = $A0
 clc
 adc #$2000
 sta utmp                     ; utmp = $2000 + row_offset*$A0
 lda scroll_src_off
 and #$00FF
 clc
 adc utmp
 sta $F0                      ; F0 = $2000 + row_offset*$A0 + scroll_src_off
 sep $20
 mx %10
 lda scroll_src_upper_bank
 sta $F2
 rep $20
 mx %00
* Pass A: rows 0..(split_row-1) from upper bank.
 ldy #0
 lda scroll_src_split_row
 and #$00FF
 tax
:fn_upper
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
 bne :fn_upper
* Pass B setup. $F3 has advanced to playfield row split_row byte 106;
* $F0 needs to be reset to lower_bank's row 0 byte scroll_src_off.
 lda scroll_src_off
 and #$00FF
 clc
 adc #$2000
 sta $F0
 sep $20
 mx %10
 lda scroll_src_bank
 sta $F2
 rep $20
 mx %00
* Pass B: rows split_row..182 from lower bank. count = 183 - split_row.
 lda #183
 sec
 sbc scroll_src_split_row
 and #$00FF
 tax
 beq :fn_split_done
:fn_lower
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
 bne :fn_lower
:fn_split_done
 bra :fn_fill_done

:fn_no_split
* Legacy single-bank fill. On entry M=8 (from the dispatch branch's
* sep). Switch to M=16 for the arithmetic and the indirect loop.
 rep $20
 mx %00
 lda scroll_src_off
 and #$00FF
 clc
 adc #$2000
 sta $F0
 sep $20
 mx %10
 lda scroll_src_bank
 sta $F2
 rep $20
 mx %00
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
:fn_fill_done

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

* Step 4: Composite sprite + overlay directly on $01 (shadow off,
* no per-write tax). The draw_*_l wrappers switch to e-mode
* internally in bank $00 — this bank must stay NATIVE (e-mode IRQ
* while PBR=$1F loses the program bank).
 jsl draw_active_sprite_l
 jsl draw_other_sprite_l       ; 2-player: also draw non-active sprite
 jsl draw_overlay_l

* Step 5: Re-enable shadow and propagate the staged $01 to $E1
* via push_band over the full playfield (rows 0..182). Shadow
* stays ON after we return so game_loop's erase/draw operations
* propagate to $E1 in the normal way.
 rep $30
 jsl shadow_on_l
 lda #0
 sep $20
 sta push_ymin
 lda #182
 sta push_ymax
 rep $20
 jsr push_band

 rtl                   ; native — bank-$00 caller restores e-mode
 mx %11


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

* Step 1 (unrolled long-absolute,X shift, mirror of scroll_right):
* Shift each scanline 4 bytes right in bank $18 using LDAL/STAL,X.
* Same speedup story as _scroll_right's step 1 — ~140K cycles
* saved per call. See that routine for the rationale (and the
* DBR/DP-hazard discussion explaining why we don't use DP mode).
*
* Direction: bytes at offset 0..105 land at offset 4..109. To
* avoid the source-overwrite trap, the unrolled body emits its
* word moves in DECREASING offset order — read offset 104,
* write offset 108; read offset 102, write 106; ... read 0,
* write 4. Each write lands at a higher offset than any
* subsequent read, so the source stays intact.
 ldx #0                 ; X = row byte offset (row * $A0)
:lshift_line
]src = $182068          ; offset 104 in bank $18 row 0
]dst = $18206C          ; offset 108 in bank $18 row 0
 LUP 53
 ldal ]src,x
 stal ]dst,x
]src = ]src-2
]dst = ]dst-2
 --^
* After 53 iterations: ]src = $181FFE, ]dst = $182002. Covered
* offsets $68..$00 read into $6C..$04 write — 53 words = 106
* bytes shifted right by 4 per row.

 txa
 clc
 adc #$00A0
 tax
 cpx #$7260             ; 183 * $A0 = $7260 — stop after processing row 182
 bcs :lshift_done
 jmp :lshift_line       ; inverted — LUP body too large for BCC
:lshift_done

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

* Steps 3-5: Phase 2 pipeline — same as scroll_right. Stays native
* (draw_*_l wrappers handle the e-mode switch in bank $00).
 jsr fast_blit_18_01
 jsl draw_active_sprite_l
 jsl draw_other_sprite_l       ; 2-player: also draw non-active sprite
 jsl draw_overlay_l
 rep $30
 jsl shadow_on_l
 lda #0
 sep $20
 sta push_ymin
 lda #182
 sta push_ymax
 rep $20
 jsr push_band
 rtl                   ; native — bank-$00 caller restores e-mode
 mx %11

* scroll_left scratch

*----------------------------------------------------------
* scroll_up - Vertical scroll: shift all rows DOWN by 4 in
* bank $18, then fill the top 4 rows from scroll_up_bank
* (the screen ABOVE) at scroll_up_off (counts down from 182).
* When scroll_up_off would go below 3, snap-transition: copy
* the entire source bank to $18 and update current_screen.
*----------------------------------------------------------
SNAP_ALIGN_TOL = $10        ; co-op snap auto-aligns the non-climber to
                            ; the canonical ladder column if they're
                            ; already within this many bytes of it.
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
 clc
 xce
 rep $30
 mx %00

* First-call setup: paint the lower band (two source screens that
* the source stratum overlays the playfield with at climb start)
* across all 183 rows, BEFORE Step 1's shift. Mirrors snap_-
* transition's lower-fill but for all rows so the climb animation
* shows the post-snap layout throughout. Cost ~100ms one-time at
* climb start.
*
* Per-target setup populates ffs_left_bank/left_origin (= the
* source-stratum screen whose world range starts to the LEFT of
* the right neighbor) and ffs_right_bank/right_origin (= the
* screen whose world range starts at right_origin and extends
* rightward). The split happens at right_origin: source bytes
* in [wo, right_origin) come from left; bytes in [right_origin,
* wo+110) come from right. This generalizes the old scr12-only
* hardcoding to all three mission-1 climbs.
 lda climb_started
 and #$00FF
 beq :ffs_check_screen
 jmp :ffs_done
:ffs_check_screen
 lda scroll_up_screen
 and #$00FF
 cmp #5
 beq :ffs_setup_scr5
 cmp #10
 beq :ffs_setup_scr10
 cmp #12
 beq :ffs_setup_scr12
 jmp :ffs_done
:ffs_setup_scr5
* Ladder 1: scr3 → scr5. Source stratum (ground) overlays scr2 +
* scr3 at the climb-start wo. scr2 origin=220, scr3 origin=330.
 sep $20
 lda #$05               ; scr2 bank
 sta ffs_left_bank
 lda #$06               ; scr3 bank
 sta ffs_right_bank
 rep $20
 lda #220
 sta ffs_left_origin
 lda #330
 sta ffs_right_origin
 bra :ffs_paint
:ffs_setup_scr10
* Ladder 2: scr7 → scr10. Source stratum (mid) overlays scr5 +
* scr7. NOTE the origins here are the ART-relative origins
* (scr5=330, scr7=440), NOT the strata-bounds origins (296/406).
* The strata origins were shifted for bounds reasons; the art
* files still expect the older origins. With wo=372 the formula
* (wo - scr5_origin) gives scr5 byte 42 — matching the original
* OP_SNAPSTATE_DEFER repaint that this code replaces.
 sep $20
 lda #$08               ; scr5 bank
 sta ffs_left_bank
 lda #$0A               ; scr7 bank
 sta ffs_right_bank
 rep $20
 lda #330
 sta ffs_left_origin
 lda #440
 sta ffs_right_origin
 bra :ffs_paint
:ffs_setup_scr12
* Ladder 3: scr9 → scr12. Source stratum (skywalk) overlays scr9
* + scr8. scr9 origin=220, scr8 origin=330. (Note: scr8's origin
* is to the RIGHT of scr9's in world coords, so scr8 is the
* "right" screen in this pair even though its bank number is
* lower than scr9's.)
 sep $20
 lda #$0C               ; scr9 bank
 sta ffs_left_bank
 lda #$0B               ; scr8 bank
 sta ffs_right_bank
 rep $20
 lda #220
 sta ffs_left_origin
 lda #330
 sta ffs_right_origin
:ffs_paint
 sep $20
 lda #1
 sta climb_started
 rep $20
* compute_up_align populates up_src_start, up_count, up_dst_start
* from world_offset and scroll_up_anchor. Step 2 will call it
* again with the same inputs.
 jsr compute_up_align
 lda up_count
 bne :ffs_paint_left
 jmp :ffs_done
:ffs_paint_left
* --- Left screen fill: covers world [left_origin, right_origin).
* For wo, left byte (wo - left_origin) sits at playfield col 0,
* count = right_origin - wo (= bytes from wo to right_origin
* exclusive, the left-screen-visible portion).
 lda world_offset
 sec
 sbc ffs_left_origin
 clc
 adc #$2000
 sta $F0                ; src = left byte (wo - left_origin)
 lda #$2000
 sta $F3                ; dst = col 0
 lda ffs_right_origin
 sec
 sbc world_offset
 sta ffs_s9_count       ; count = right_origin - wo
 sep $20
 lda ffs_left_bank
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
* --- Right screen fill: covers world [right_origin, ...). For wo,
* right byte 0 sits at playfield col (right_origin - wo),
* count = wo + 110 - right_origin (= visible right bytes).
 lda world_offset
 sec
 sbc ffs_left_origin
 sta ffs_count          ; count = wo - left_origin
 beq :ffs_s8_jmp_done
 lda #$2000
 sta $F0                ; src = right byte 0
 lda ffs_right_origin
 sec
 sbc world_offset
 clc
 adc #$2000
 sta $F3                ; dst = col (right_origin - wo)
 sep $20
 lda ffs_right_bank
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

* Step 1 (unrolled long-absolute,X shift, vertical direction):
* Shift all rows down by 4 in $18, processing from row 178 down
* to row 0 (179 rows total). Each row gets COPIED to row+4 —
* destination offset is always source + $0280 ($A0 × 4 rows).
*
* X is the source row's byte offset within bank $18 (row*$A0).
* X starts at 178*$A0 = $B280 (row 178) and counts down by $A0
* per iteration; the body iterates X exactly down to 0 (row 0).
* Each LDAL/STAL pair uses X for both — source base $182000,
* dest base $182280 ($182000 + 4 rows). Going high→low row order
* avoids the source-overwrite trap (each row's dest is 4 rows
* below, so a row's source data stays intact while we process
* rows above it).
*
* 55 word moves per row × 179 rows = 9845 moves. At 12 cycles
* per word, ~118K cycles vs the old ~273K cycles for the
* long-indirect version. Same DBR/DP-safety properties as the
* horizontal scrolls — no register state leaks past the loop.
 ldx #$6F40             ; row 178 source byte offset (178 * $A0)
:ushift_row
]src = $182000
]dst = $182280          ; src + 4 rows ($A0 × 4)
 LUP 55
 ldal ]src,x
 stal ]dst,x
]src = ]src+2
]dst = ]dst+2
 --^
* After 55 iterations: ]src = $18206E, ]dst = $1822EE. Covered
* row offsets 0..108 (55 words = 110 bytes — the full row).

 txa
 beq :ushift_done       ; just processed row 0 — exit
 sec
 sbc #$00A0
 tax                    ; X = next source row (-$A0)
 jmp :ushift_row        ; inverted — LUP body (~440 bytes) is
                        ; far outside any short branch's range.
:ushift_done

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
 bne :rg_proceed
 jmp :rgap_done
:rg_proceed
 lda up_dst_start
 clc
 adc up_count
 sta rgap_start        ; first unfilled byte on right
 cmp #110
 bcc :rg_have_gap       ; gap exists, continue
 jmp :rgap_done         ; no gap (filled to edge)
:rg_have_gap
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
 cpy rgap_count
 bcs :rgap_row_done
 iny
 cpy rgap_count
 dey
 bcs :rgap_tail
* Word fits (Y+1 < count).
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 bra :rgap_word
:rgap_tail
* 1-byte tail for odd rgap_count — see snap_transition's
* matching :snap_rg_tail comment. Same hazard at PLAYFIELD_EDGE+1.
 sep $20
 lda [$F0],y
 sta [$F3],y
 rep $20
 iny
 bra :rgap_word
:rgap_row_done
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

* Phase 2 pipeline: blit, composite on $01, push to $E1. Stays
* native (draw_*_l wrappers handle the e-mode switch in bank $00).
 jsr fast_blit_18_01
 jsl draw_active_sprite_l
 jsl draw_other_sprite_l       ; 2-player: also draw non-active sprite
 jsl draw_overlay_l
 rep $30
 jsl shadow_on_l
 lda #0
 sep $20
 sta push_ymin
 lda #182
 sta push_ymax
 rep $20
 jsr push_band
 rtl                   ; native — bank-$00 caller restores e-mode
 mx %11

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
:snap_rgwrd cpy rgap_count
 bcs :snap_rg_row_done   ; Y >= count → done with this row
 iny
 cpy rgap_count          ; Y was pre-incremented to Y+1
 dey                      ; restore Y for the upcoming store
 bcs :snap_rg_tail       ; only 1 byte left (Y+1 == count) → 1-byte tail
* Full word fits: 16-bit store of 2 bytes.
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 bra :snap_rgwrd
:snap_rg_tail
* Odd count's last byte. 8-bit STA so it doesn't overrun into
* byte 110 (one past PLAYFIELD_EDGE). The default 16-bit cpy/bcc
* loop overshoots by 1 byte for odd counts — for scr12 climbs
* (rgap_count=75) that splatters scr11 byte 75 across $18's
* right margin for all 113 snap_copy_rows, and any later erase
* whose union rect spans byte 110 propagates it to $01/$E1.
 sep $20
 lda [$F0],y
 sta [$F3],y
 rep $20
 iny
 bra :snap_rgwrd          ; Y == count → loop guard exits cleanly
:snap_rg_row_done
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
* fill the remaining 70 playfield rows (113..182) from the source
* stratum's two overlapping screens, using GEOMETRIC per-screen
* world origins (mirrors :ffs_do during-climb). Uses the ffs_*
* descriptor cells populated by :ffs_setup_scrN at climb start —
* enables this paint for ALL three ladders (was scr12-only).
 lda scroll_up_screen
 and #$00FF
 cmp #12
 beq :snap_lower_go
* :snap_lower_go is ONLY for narrow targets whose bank has fewer
* than 183 rows of content. scr12 has rows 0..112 of art and
* rows 113..199 empty, so it needs the bottom 70 playfield rows
* filled from the source stratum (scr9+scr8). scr5 (ladder 1)
* and scr10 (ladder 2) are full-height: their banks have art at
* rows 113+ too (scr10 has an empty middle at rows 100..112 but
* content resumes at 113). For those, the main snap_copy paints
* all 183 rows of target art and :snap_lower_go would overpaint
* the target's bottom with source-stratum art — wrong.
 jmp :snap_lower_done
:snap_lower_go
* Left fill — src = left byte (wo - left_origin), dst = col 0,
* count = right_origin - wo (visible left bytes).
 lda world_offset
 sec
 sbc ffs_left_origin
 clc
 adc #$2000
 sta $F0
 lda #$66A0
 sta $F3                ; dst = $18/(row 113, col 0)
 lda ffs_right_origin
 sec
 sbc world_offset
 sta snap_lo_s9_count   ; count = right_origin - wo
 beq :snap_lo_s9_done
 sep $20
 lda ffs_left_bank
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
* Right fill — src = right byte 0, dst = col (right_origin - wo),
* count = wo - left_origin (visible right bytes).
 lda world_offset
 sec
 sbc ffs_left_origin
 sta lower_rgap_count   ; count = wo - left_origin
 beq :no_scr8_fill
 lda #$2000
 sta $F0
 lda ffs_right_origin
 sec
 sbc world_offset
 clc
 adc #$66A0
 sta $F3                ; dst = $18/(row 113, col right_origin-wo)
 sep $20
 lda ffs_right_bank
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
* scr8_src_off init is currently scr12-specific (tracks scr8 byte
* position for subsequent scroll_right lower-fill). For other
* ladders we don't yet have an equivalent — leave the field at
* whatever it was. Gate on scroll_up_screen == 12 explicitly.
 lda scroll_up_screen
 and #$00FF
 cmp #12
 bne :snap_lower_done
 lda lower_rgap_count
 sta scr8_src_off
 stz scr8_src_off+1
 bra :snap_lower_done
:no_scr8_fill
* Same gate as above — only scr12 climb resets scr8_src_off.
 lda scroll_up_screen
 and #$00FF
 cmp #12
 bne :snap_lower_done
 stz scr8_src_off
 stz scr8_src_off+1
:snap_lower_done

 sep $30                ; 8-bit A/X — but stay NATIVE: e-mode in
                        ; bank $1F + IRQ loses the program bank
 mx %11
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
* Co-op climb hide: snap_transition is where the hidden OTHER
* reappears. Place them at the climber's exit (X, Y), force
* erase+draw bits so the next frame renders them, and clear
* climb_hide_other so input/draw gates re-engage.
 mx %11
 lda climb_hide_other
 beq :sl_no_other_y
 stz climb_hide_other
 lda info_ptr
 cmp #<billy_sprite
 bne :sl_other_is_billy
 lda info_ptr+1
 cmp #>billy_sprite
 bne :sl_other_is_billy
* Climber = Billy → OTHER = Jimmy.
 lda billy_sprite+0
 sta jimmy_sprite+0
 sta jimmy_sprite+32
 lda billy_sprite+2
 sta jimmy_sprite+2
 sta jimmy_sprite+34
 lda jimmy_sprite+30
 ora #$03
 sta jimmy_sprite+30
 bra :sl_no_other_y
:sl_other_is_billy
* Climber = Jimmy → OTHER = Billy.
 lda jimmy_sprite+0
 sta billy_sprite+0
 sta billy_sprite+32
 lda jimmy_sprite+2
 sta billy_sprite+2
 sta billy_sprite+34
 lda billy_sprite+30
 ora #$03
 sta billy_sprite+30
:sl_no_other_y
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
* variant if the climber is facing left. Without this, FRAME_ADDR is
* the compiled IMAGE01_DATA but MASK_ADDR was cleared by
* advance_climb, so dispatch routes to legacy and the $00
* transparency slots in the compiled data render as opaque black
* ("box around the climber" at the top of the ladder).
*
* Climber-aware: dispatch by info_ptr so we install Jimmy's
* spr_jimmy01_mask (bank-$1D) when Jimmy is the climber. The old
* code hardcoded spr_image01_mask + billy_sprite+60 regardless of
* which player climbed — when Jimmy was the climber his info+60
* stayed at whatever the pre-climb state held (e.g.
* JPUNCHED_MASK_MIRROR from a hit), and his compiled draw then
* paired JIMMY01_DATA (9 wide) with an 11-wide JPUNCHED mask →
* per-row stride mismatch → diagonal stripes through the bg.
 lda info_ptr
 cmp #<jimmy_sprite
 bne :st_climber_billy
 lda info_ptr+1
 cmp #>jimmy_sprite
 bne :st_climber_billy
* Climber = Jimmy.
 lda IMAGE01_MIRROR
 bne :st_jclimber_mirror
 lda spr_jimmy01_mask
 sta MASK_ADDR
 sta jimmy_sprite+60
 lda spr_jimmy01_mask+1
 sta MASK_ADDR+1
 sta jimmy_sprite+61
 bra :st_mask_done
:st_jclimber_mirror
 lda spr_jimmy01_data_mir
 sta FRAME_ADDR
 sta jimmy_sprite+14
 lda spr_jimmy01_data_mir+1
 sta FRAME_ADDR+1
 sta jimmy_sprite+15
 lda spr_jimmy01_mask_mir
 sta MASK_ADDR
 sta jimmy_sprite+60
 lda spr_jimmy01_mask_mir+1
 sta MASK_ADDR+1
 sta jimmy_sprite+61
 bra :st_mask_done
:st_climber_billy
* Climber = Billy.
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
* 2-player: also reset OTHER (the non-climber) out of climb-anim.
* The block above used (info_ptr),y to reset the climber and the
* hardcoded billy_sprite+14/+60 writes used IMAGE01_MIRROR (the
* climber's mirror) — neither resets OTHER's anim using OTHER's
* own mirror. When Jimmy is the climber and Billy was walking up
* the ladder column with via_ladder=1, Billy's frame_addr stays
* at BCLIMB and his frame_x/y at the climb dimensions → Billy is
* rendered with the climb sprite on the flat exit platform
* ("sprite corrupted" report). Reset OTHER explicitly.
 lda jimmy_active
 bne :st_have_jimmy
 jmp :st_other_reset_done
:st_have_jimmy
 lda info_ptr
 cmp #<billy_sprite
 bne :st_other_is_billy
 lda info_ptr+1
 cmp #>billy_sprite
 bne :st_other_is_billy
* Climber = Billy → reset Jimmy. Restore canonical idle state:
* idle_addr, idle_x/y, mask_addr, frame_bank all anchored on the
* spr_jimmy01* cache vars (patched by init_jimmy from bank-$1D
* spr_addr_tbl).
 lda spr_jimmy01            ; frame_addr ← JIMMY01_DATA offset
 sta jimmy_sprite+14
 sta jimmy_sprite+42
 lda spr_jimmy01+1
 sta jimmy_sprite+15
 sta jimmy_sprite+43
 lda spr_jimmy01_mask       ; mask_addr ← JIMMY01_MASK offset
 sta jimmy_sprite+60
 sta jimmy_sprite+62
 lda spr_jimmy01_mask+1
 sta jimmy_sprite+61
 sta jimmy_sprite+63
 lda #$09                   ; frame_x = idle_x = 9
 sta jimmy_sprite+10
 sta jimmy_sprite+44
 lda #$28                   ; frame_y = idle_y = 40
 sta jimmy_sprite+12
 sta jimmy_sprite+46
 lda #$1D                   ; frame_bank ← $1D
 sta jimmy_sprite+56
 sta jimmy_sprite+58
 lda #$00
 sta jimmy_sprite+57
 sta jimmy_sprite+59
 sta jimmy_sprite+24        ; clear anim_ptr/frame/timer
 sta jimmy_sprite+25
 sta jimmy_sprite+26
 sta jimmy_sprite+28
 bra :st_other_reset_done
:st_other_is_billy
* Climber = Jimmy → reset Billy using Billy's idle data and
* Billy's mirror state.
 lda billy_sprite+44        ; idle_x
 sta billy_sprite+10
 lda billy_sprite+46        ; idle_y
 sta billy_sprite+12
 lda #$02                   ; frame_bank low ← $02 (IMAGE01's bank)
 sta billy_sprite+56
 lda #$00
 sta billy_sprite+57
 lda billy_sprite+4         ; Billy's mirror state
 bne :st_billy_mirror_other
 lda billy_sprite+42        ; non-mirror idle_addr
 sta billy_sprite+14
 lda billy_sprite+43
 sta billy_sprite+15
 lda spr_image01_mask
 sta billy_sprite+60
 lda spr_image01_mask+1
 sta billy_sprite+61
 bra :st_other_reset_done
:st_billy_mirror_other
 lda spr_image01_data_mirror
 sta billy_sprite+14
 lda spr_image01_data_mirror+1
 sta billy_sprite+15
 lda spr_image01_mask_mirror
 sta billy_sprite+60
 lda spr_image01_mask_mirror+1
 sta billy_sprite+61
:st_other_reset_done
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

* Phase 2 pipeline: blit, composite on $01, push to $E1. Stays
* native (draw_*_l wrappers handle the e-mode switch in bank $00).
 clc
 xce                    ; no-op when already native
 rep $30
 mx %00
 jsr fast_blit_18_01
 jsl draw_active_sprite_l
 jsl draw_other_sprite_l       ; 2-player: also draw non-active sprite
 jsl draw_overlay_l
 rep $30
 jsl shadow_on_l
 lda #0
 sep $20
 sta push_ymin
 lda #182
 sta push_ymax
 rep $20
 jsr push_band
 rtl                   ; native — bank-$00 caller restores e-mode
 mx %11

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
* compute_down_align — mirror of compute_up_align for OP_DOWN.
* Same math: derive (down_src_start, down_dst_start, down_count)
* from world_offset and scroll_down_anchor. For full-width below
* targets (mission2's mission25+26 split, twidth=110), this
* typically produces src_start=0, dst_start=0, count=110.
*----------------------------------------------------------
compute_down_align
 mx %00
 lda world_offset
 sec
 sbc scroll_down_anchor
 sta down_src_start
 bpl :cda_pos
 eor #$FFFF
 inc
 sta down_dst_start
 cmp #110
 bcs :cda_no_overlap
 stz down_src_start
 lda #110
 sec
 sbc down_dst_start
 cmp scroll_down_twidth
 bcc :cda_neg_set
 lda scroll_down_twidth
:cda_neg_set
 sta down_count
 rts
:cda_pos
 cmp scroll_down_twidth
 bcs :cda_no_overlap
 stz down_dst_start
 lda scroll_down_twidth
 sec
 sbc down_src_start
 sta down_count
 rts
:cda_no_overlap
 stz down_count
 rts
 mx %11

*----------------------------------------------------------
* _scroll_down — Phase 2 skeleton. Per-frame downward scroll.
* Shifts all rows UP by 4 in bank $18, fills the BOTTOM 4 rows
* (rows 179..182) with new content from scroll_down_bank starting
* at row scroll_down_off, then increments scroll_down_off by 4.
* When scroll_down_off reaches ~152, performs :snap_transition_down
* to atomically finalize the descent and clear scroll_down_enabled.
*
* Phase 2 is single-bank only (scroll_down_bank); Phase 3 adds
* split-bank composition using scroll_down_lbank/rbank with the
* split column at scroll_down_split. Phase 4 wires :ai_do_down to
* call jsl scroll_down each frame Billy is descending on a ladder.
*
* Driven for Phase 2 by :check_waitdown calling jsl scroll_down
* (see game.s).
*----------------------------------------------------------
_scroll_down
 jsl shadow_off_l

 lda scroll_down_off
 cmp scroll_down_snap_at
 bcc :sd_normal
* Snap fired: source rows 0..(snap_at-1) of current banks have
* been consumed (snap_at is per-layer = floor(art_rows/4)*4 so
* the last fill block held no blank padding tail). If a chain
* target is queued (next_lbank != 0), swap banks and reset off
* so this frame's scroll continues with the new layer. Otherwise
* hand off to :snap_transition_down to clear scroll_down_enabled
* and end the descent.
 lda scroll_down_next_lbank
 beq :sd_no_chain
 sta scroll_down_lbank
 lda scroll_down_next_rbank
 sta scroll_down_rbank
 lda scroll_down_next_snap_at
 sta scroll_down_snap_at
 stz scroll_down_next_lbank
 stz scroll_down_next_rbank
 stz scroll_down_next_snap_at
 stz scroll_down_off
 bra :sd_normal               ; fall through to scroll with new banks
:sd_no_chain
 jmp :snap_transition_down

:sd_normal
 clc
 xce                    ; native mode
 rep $30
 mx %00

* Step 1: shift all rows UP by 4 in bank $18. Source row N maps to
* dest row N-4 for N=4..182. Going LOW→HIGH row order (X increases
* from 0 to $6F40) avoids the overwrite trap — each row's dest is
* 4 rows ABOVE, so a row's source data is read before any later
* iteration could clobber it.
*
* 55 word moves per row × 179 rows = 9845 moves. Same DBR/DP-safe
* long-absolute,X pattern as the OP_UP and horizontal-scroll
* shifts.
 ldx #$0000             ; row 0 byte offset (target after subtracting $280)
:dshift_row
]src = $182280          ; row 4 = src + 4*$A0
]dst = $182000          ; row 0
 LUP 55
 ldal ]src,x
 stal ]dst,x
]src = ]src+2
]dst = ]dst+2
 --^
 txa
 clc
 adc #$00A0             ; advance one row
 tax
 cpx #$6FE0             ; 179*$A0 = $6FE0 — stop after row 178
 bcs :dshift_done
 jmp :dshift_row        ; inverted — LUP body (~440 bytes) is far
                        ; outside any short-branch range.
:dshift_done

* Step 2: fill rows 179..182 from the descent target. dfill_top is
* the source-bank row that will sit at playfield row 179 this
* frame. Two-pass split-bank fill, world-aware:
*   playfield_split = scroll_down_split - scroll_down_anchor
*                     (clamped to [0..110]).
*   Pass A (left half): playfield bytes [0..playfield_split-1] ←
*                       lbank bytes [anchor..anchor+playfield_split-1].
*   Pass B (right half): playfield bytes [playfield_split..109] ←
*                        rbank bytes [max(0, anchor-split)..].
* scroll_down_anchor was frozen at OP_DOWN fire time (= world_offset
* at that moment), so the descent target stays stable even if the
* horizontal camera shifts during descent.
* If scroll_down_rbank == 0 → single-bank mode: Pass A fills the
* entire 110-byte row from lbank starting at byte (anchor).
 sep $20
 mx %10
 lda scroll_down_off
 sta dfill_top
 rep $20
 mx %00

* Compute base src offset = $2000 + dfill_top * $A0. Stored in utmp
* so each pass can re-use it without recomputing.
 lda dfill_top
 and #$00FF
 sta down_src_start     ; temp scratch (overwritten by next pass)
 asl
 asl                    ; *4
 clc
 adc down_src_start     ; *5
 asl
 asl
 asl
 asl
 asl                    ; *160 = $A0
 clc
 adc #$2000
 sta utmp               ; utmp = $2000 + dfill_top*$A0 (row base)

* scroll_down_split = WORLD byte where lbank's content ends and
* rbank's begins. mission25 is world-aligned (byte K = world K),
* mission26 is content-origin-aligned (byte 0 = world byte split).
* So the playfield seam is at byte (split - world_offset), and
* mission26 always reads from byte 0 onward.
 lda scroll_down_split
 sec
 sbc world_offset
 bpl :sd_split_pos
 lda #0                 ; camera past split → no left half
 bra :sd_split_done
:sd_split_pos
 cmp #110
 bcc :sd_split_done
 lda #110               ; split past playfield right edge → all left
:sd_split_done
 sta down_dst_start     ; playfield_split (0..110)

* Single-bank override: if rbank == 0, ignore split and fill the
* whole 110-byte row from lbank.
 lda scroll_down_rbank
 and #$00FF
 bne :sd_rbank_set
 lda #110
 sta down_dst_start
:sd_rbank_set

* ----- Pass A: LEFT HALF (lbank, playfield 0..split-1) -----
 lda down_dst_start
 sta down_count
 beq :dfill_passA_skip

 lda utmp
 clc
 adc world_offset       ; src = lbank/(row base + world_offset)
 sta $F0                ;       — tracks horizontal camera each frame
 lda #$8FE0             ; dst = $18/$8FE0 (row 179 byte 0)
 sta $F3
 sep $20
 lda scroll_down_lbank
 sta $F2
 lda #$18
 sta $F5
 rep $20

 ldx #4
:dfill_rowA
 ldy #0
:dfill_wordA
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy down_count
 bcc :dfill_wordA
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :dfill_rowA
:dfill_passA_skip

* ----- Pass B: RIGHT HALF (rbank, playfield split..109) -----
* Skipped when rbank == 0 (single-bank path) or when playfield_split
* already == 110 (entire row taken by lbank).
 lda scroll_down_rbank
 and #$00FF
 beq :dfill_passB_skip

 lda #110
 sec
 sbc down_dst_start
 sta down_count         ; right-half count = 110 - playfield_split
 beq :dfill_passB_skip

* rbank is content-origin-aligned: byte 0 = world byte split.
* Pass B always reads from byte 0 onward; the dynamic playfield
* seam (in down_dst_start) puts that byte 0 at the right column.
 lda utmp
 sta $F0                ; src = rbank/(row base + 0)
 lda #$8FE0
 clc
 adc down_dst_start
 sta $F3                ; dst = $18/($8FE0 + playfield_split)
 sep $20
 lda scroll_down_rbank
 sta $F2
 lda #$18
 sta $F5
 rep $20

 ldx #4
:dfill_rowB
 ldy #0
:dfill_wordB
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy down_count
 bcc :dfill_wordB
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :dfill_rowB
:dfill_passB_skip
:dfill_skip

* Step 3: increment scroll_down_off by 4
 sep $20
 mx %10
 lda scroll_down_off
 clc
 adc #4
 sta scroll_down_off
 rep $30
 mx %00

* Step 4: standard Phase 2 tail — fast_blit_18_01, draw sprites,
* shadow on, push_band, RTL. Identical to scroll_up's tail. Stays
* native (draw_*_l wrappers handle the e-mode switch in bank $00).
 jsr fast_blit_18_01
 jsl draw_active_sprite_l
 jsl draw_other_sprite_l
 jsl draw_overlay_l
 rep $30
 mx %00
 jsl shadow_on_l
 sep $20
 lda #0
 sta push_ymin
 lda #182
 sta push_ymax
 rep $20
 mx %00
 jsr push_band
 rtl                    ; native — bank-$00 caller restores e-mode
 mx %11

:snap_transition_down
* End-of-descent cleanup (no chain queued). Beyond clearing
* scroll_down_enabled (so SCRIPT_WAITDOWN advances), terminate
* the ladder state so the level script's follow-up opcodes start
* from a clean "Billy is standing" state — not stuck on a ladder
* whose source rows have all scrolled past.
 stz scroll_down_enabled
 stz descent_started
 stz is_climbing                ; Billy is on solid ground now
 stz ladder_count               ; remove ladder so it can't re-engage
* Reset horizontal scroll source so the next OP_RIGHT can install
* a fresh target bank. Without this, OP_RIGHT's mid-scroll
* preservation keeps the OLD scroll_src_bank (e.g. mission22 from
* the pre-descent OP_RIGHT,1), and right-scroll after the descent
* reveals upper-world art instead of the descent target's rbank.
 stz scroll_src_off
 stz scroll_src_off+1
 jsl shadow_on_l        ; restore shadow state (we turned it off at entry)
 mx %11
 rtl

*----------------------------------------------------------
* _scroll_up_split — vertical mirror of _scroll_down. Per-frame
* upward scroll: shift all rows DOWN by 4 in bank $18, then fill
* the TOP 4 rows (0..3) from the split-bank up-target. Reveals
* progressively HIGHER source rows as the climb proceeds.
*
* Source-row mapping: ufill_top = snap_at - off. At off=0 (start)
* the top band shows source row snap_at; as off climbs toward
* snap_at the band walks up to source row 0 (top of the target).
* So the first content revealed at the top is the source's BOTTOM
* (adjacent to where Billy climbs from) and the last is its top.
*
* Split-bank composition is identical to _scroll_down:
*   playfield_split = scroll_us_split - world_offset (clamp 0..110)
*   Pass A (left):  playfield[0..split-1] ← lbank[world_offset..]
*   Pass B (right): playfield[split..109] ← rbank[0..]   (origin-aligned)
* Single-bank when scroll_us_rbank == 0.
*
* Driven by the climb handler in game.s (jsl scroll_up_split when
* Billy climbs an OP_UPSPLIT ladder past UP_SCROLL_THRESH).
*----------------------------------------------------------
_scroll_up_split
 jsl shadow_off_l

 lda scroll_us_off
 cmp scroll_us_snap_at
 bcc :sus_normal
* Reached the top of the current layer. If a chain layer is queued
* (next_lbank != 0), swap to it and reset off so this frame keeps
* scrolling into the new art (e.g. mission25/26 done → mission21/22).
* Otherwise end the climb.
 lda scroll_us_next_lbank
 bne :sus_chain
 jmp :snap_transition_up_split
:sus_chain
 sta scroll_us_lbank
 lda scroll_us_next_rbank
 sta scroll_us_rbank
 lda scroll_us_next_snap_at
 sta scroll_us_snap_at
 lda scroll_us_next_split
 sta scroll_us_split
 lda scroll_us_next_split+1
 sta scroll_us_split+1
 lda scroll_us_next_hoff
 sta scroll_us_hoff
 stz scroll_us_next_lbank
 stz scroll_us_next_rbank
 stz scroll_us_next_snap_at
 stz scroll_us_off

:sus_normal
 clc
 xce                    ; native mode
 rep $30
 mx %00

* Step 1: shift all rows DOWN by 4 in bank $18. Source row N maps
* to dest row N+4 for N=0..178. Going HIGH→LOW row order (X from
* row 178 down to 0) avoids the overwrite trap — each row's dest
* is 4 rows BELOW, so the row is read before any earlier-indexed
* iteration could clobber it.
 ldx #$6F40             ; 178*$A0 = row 178
:ushift_row
]src = $182000          ; row N
]dst = $182280          ; row N+4 = src + 4*$A0
 LUP 55
 ldal ]src,x
 stal ]dst,x
]src = ]src+2
]dst = ]dst+2
 --^
 txa
 sec
 sbc #$00A0             ; back up one row
 bcc :ushift_done       ; passed row 0 → done
 tax
 jmp :ushift_row        ; inverted — LUP body is far out of branch range
:ushift_done

* Step 2: fill rows 0..3 from the up-target. ufill_top = snap_at
* - off is the source-bank row that sits at playfield row 0.
 sep $20
 mx %10
 lda scroll_us_snap_at
 sec
 sbc scroll_us_off
 sta dfill_top          ; reuse down scratch (up/down never co-run)
 rep $20
 mx %00

* row base = $2000 + ufill_top * $A0
 lda dfill_top
 and #$00FF
 sta down_src_start
 asl
 asl                    ; *4
 clc
 adc down_src_start     ; *5
 asl
 asl
 asl
 asl
 asl                    ; *160 = $A0
 clc
 adc #$2000
 sta utmp               ; utmp = $2000 + ufill_top*$A0 (row base)

* us_wo_eff = world_offset + sign-extended scroll_us_hoff. Per-layer
* horizontal calibration: layer-1 (mission25/26) and layer-2
* (mission21/22) need different shifts because their art isn't
* world-aligned to the same origin. Used in place of world_offset
* for both the lbank read AND the seam, so the whole layer shifts
* consistently (halves + seam) without splitting the content.
 lda scroll_us_hoff
 and #$00FF
 cmp #$0080
 bcc :sus_hoff_pos
 ora #$FF00             ; sign-extend negative hoff
:sus_hoff_pos
 clc
 adc world_offset
 sta us_wo_eff

* playfield_split = scroll_us_split - us_wo_eff (clamp 0..110)
 lda scroll_us_split
 sec
 sbc us_wo_eff
 bpl :sus_split_pos
 lda #0
 bra :sus_split_done
:sus_split_pos
 cmp #110
 bcc :sus_split_done
 lda #110
:sus_split_done
 sta down_dst_start     ; playfield_split (0..110)

* single-bank override: rbank == 0 → whole row from lbank
 lda scroll_us_rbank
 and #$00FF
 bne :sus_rbank_set
 lda #110
 sta down_dst_start
:sus_rbank_set

* ----- Pass A: LEFT HALF (lbank, playfield 0..split-1) -----
 lda down_dst_start
 sta down_count
 beq :ufill_passA_skip

 lda utmp
 clc
 adc us_wo_eff          ; src = lbank/(row base + us_wo_eff)
 sta $F0
 lda #$2000             ; dst = $18/$2000 (row 0 byte 0)
 sta $F3
 sep $20
 lda scroll_us_lbank
 sta $F2
 lda #$18
 sta $F5
 rep $20

 ldx #4
:ufill_rowA
 ldy #0
:ufill_wordA
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy down_count
 bcc :ufill_wordA
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :ufill_rowA
:ufill_passA_skip

* ----- Pass B: RIGHT HALF (rbank, playfield split..109) -----
 lda scroll_us_rbank
 and #$00FF
 beq :ufill_passB_skip

 lda #110
 sec
 sbc down_dst_start
 sta down_count
 beq :ufill_passB_skip

* rbank content-origin: byte 0 = world byte `split`. Pass B's
* leftmost visible world byte is max(us_wo_eff, split), so the
* source offset = max(0, us_wo_eff - split). When the seam is on
* screen (us_wo_eff < split) this is 0 (byte 0 = world split at the
* seam). When hoff/scroll pushes the seam off the left edge
* (us_wo_eff >= split, playfield_split clamped to 0), Pass B must
* read deeper into rbank so its left columns aren't duplicated where
* the (skipped) lbank half belonged — that duplication was the
* "doubled left-hand-side art".
 lda us_wo_eff
 sec
 sbc scroll_us_split
 bpl :sus_pb_off_pos
 lda #0
:sus_pb_off_pos
 clc
 adc utmp
 sta $F0                ; src = rbank/(row base + max(0, us_wo_eff-split))
 lda #$2000
 clc
 adc down_dst_start
 sta $F3                ; dst = $18/($2000 + playfield_split)
 sep $20
 lda scroll_us_rbank
 sta $F2
 lda #$18
 sta $F5
 rep $20

 ldx #4
:ufill_rowB
 ldy #0
:ufill_wordB
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy down_count
 bcc :ufill_wordB
 lda $F0
 clc
 adc #$00A0
 sta $F0
 lda $F3
 clc
 adc #$00A0
 sta $F3
 dex
 bne :ufill_rowB
:ufill_passB_skip

* Step 3: increment scroll_us_off by 4
 sep $20
 mx %10
 lda scroll_us_off
 clc
 adc #4
 sta scroll_us_off
 rep $30
 mx %00

* Step 4: standard tail — fast_blit, draw sprites, push_band, RTL.
* Stays native (draw_*_l wrappers handle the e-mode switch in $00).
 jsr fast_blit_18_01
 jsl draw_active_sprite_l
 jsl draw_other_sprite_l
 jsl draw_overlay_l
 rep $30
 mx %00
 jsl shadow_on_l
 sep $20
 lda #0
 sta push_ymin
 lda #182
 sta push_ymax
 rep $20
 mx %00
 jsr push_band
 rtl                    ; native — bank-$00 caller restores e-mode
 mx %11

:snap_transition_up_split
* End-of-climb cleanup (mirror of :snap_transition_down). Clears
* scroll_us_enabled so the climb driver stops firing, drops the
* ladder + climb state, and leaves the destination platform to the
* level script's OP_BOUNDS/OP_PLATFORM. Does NOT reload bounds.
 stz scroll_us_enabled
 stz is_climbing
 stz ladder_count
 stz scroll_src_off
 stz scroll_src_off+1
 jsl shadow_on_l
 mx %11
 rtl

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

* Chunk 1 of 5: 11 PHAs (row offsets 108..88).
]idx = 108
 LUP 11
 LDAL $012000+]idx,x
 pha
]idx = ]idx-2
 --^

* Mid-row IRQ gap #1. TSC saves SP mid-PHA-chain; PHX/PHY
* preserve X and Y because NTP's interrupt_handler does
* PHB/PHD/PHP but NOT PHA/PHX/PHY — clobbering X (row byte
* offset) or Y (row count) would corrupt the loop state.
 tsc
 sta pb_sp_mid
 lda pb_save_s
 tcs
 phx
 phy
 php
 cli
 nop
 nop
 sei
 plp
 ply
 plx
 lda pb_sp_mid
 tcs

* Chunk 2 of 5: 11 PHAs (offsets 86..66).
]idx = 86
 LUP 11
 LDAL $012000+]idx,x
 pha
]idx = ]idx-2
 --^

* Mid-row IRQ gap #2.
 tsc
 sta pb_sp_mid
 lda pb_save_s
 tcs
 phx
 phy
 php
 cli
 nop
 nop
 sei
 plp
 ply
 plx
 lda pb_sp_mid
 tcs

* Chunk 3 of 5: 11 PHAs (offsets 64..44).
]idx = 64
 LUP 11
 LDAL $012000+]idx,x
 pha
]idx = ]idx-2
 --^

* Mid-row IRQ gap #3.
 tsc
 sta pb_sp_mid
 lda pb_save_s
 tcs
 phx
 phy
 php
 cli
 nop
 nop
 sei
 plp
 ply
 plx
 lda pb_sp_mid
 tcs

* Chunk 4 of 5: 11 PHAs (offsets 42..22).
]idx = 42
 LUP 11
 LDAL $012000+]idx,x
 pha
]idx = ]idx-2
 --^

* Mid-row IRQ gap #4.
 tsc
 sta pb_sp_mid
 lda pb_save_s
 tcs
 phx
 phy
 php
 cli
 nop
 nop
 sei
 plp
 ply
 plx
 lda pb_sp_mid
 tcs

* Chunk 5 of 5: 11 PHAs (offsets 20..0).
]idx = 20
 LUP 11
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

* End-of-row IRQ gap. PHX/PHY around CLI for the same reason
* the mid-row gaps need it — NTP's handler doesn't preserve X
* or Y. X here holds the NEXT row's byte offset, Y is the row
* counter (already decremented by `dey` above, will be used by
* the next iter's `dey; beq`). SP doesn't need preservation
* because :pb_line's TCS resets it.
 lda pb_save_s
 tcs
 phx
 phy
 php
 cli
 nop
 nop
 sei
 plp
 ply
 plx

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

*----------------------------------------------------------
* Init/patcher cluster — runs once at boot via JSL. Code only;
* the data declarations and `=` equates that interleaved
* with this block live in src/init_data.s (PUT-included from
* game.s) so both bank-$00 readers and engine.s see them.
*----------------------------------------------------------
*----------------------------------------------------------
* init_level - Read level data header from bank $02 and
* patch engine structures with bank $02 sprite addresses.
* Call after loading mission1 binary to bank $02.
*----------------------------------------------------------
 mx %11
_init_level
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

* Read strata index offset from header field at $02/0018
 lda #$0018
 sta $F0
 sep $20
 lda #$02
 sta $F2
 rep $20
 ldy #0
 lda [$F0],y
 sta strata_base       ; bank $02 address of strata_index

* Read screen→stratum table offset from header field at $02/001A
 lda #$001A
 sta $F0
 sep $20
 lda #$02
 sta $F2
 rep $20
 ldy #0
 lda [$F0],y
 sta s2s_base          ; bank $02 address of screen_to_stratum

* Read engine-mode flags from header field at $02/001C and extract
* gravity bit (bit 0) into the bank-0 gravity_enabled gate.
 lda #$001C
 sta $F0
 sep $20
 mx %10
 ldy #0
 lda [$F0],y
 and #$01
 sta gravity_enabled
 rep $20
 mx %00

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

* POINT_DOWN (offsets +256..+262). Vertically-flipped POINT_UP for
* the OP_DOWN descent overlay. Missions without OP_DOWN keep these
* at $0000 (the overlay setup gates on the address being non-zero).
 ldy #256
 lda [$F0],y
 sta spr_pointdown
 ldy #258
 lda [$F0],y
 sta spr_pointdown_mask
 ldy #260
 lda [$F0],y
 sta spr_pointdown_data_mirror
 ldy #262
 lda [$F0],y
 sta spr_pointdown_mask_mirror

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

* anim_wpunched, anim_wfall, anim_wwalk, anim_wpunch are now
* compiled (bank $1B). They are patched in init_williams_compiled
* (called from init_mission13) since the compiled cache vars
* aren't populated until init_mission13 has run. The legacy
* spr_wpunched / spr_wfall / spr_wfallen / spr_william*/spr_wpunch*
* cache vars below stay because mission1.s spawn templates'
* idle_addr fields still point at bank-$02 WILLIAM1 (the
* spawn-template detector in script_spawn_npc keys on that).

* Patch anim_bfall: 2 legacy frames in bank $19. Frame 0 BFALL
* (in-air arc pose), frame 1 BFALLEN (grounded). Patched here
* would set the compiled-form fields, but anim_bfall is now
* legacy — the bank-$19 init below patches the actual addrs.

* anim_rwalk, anim_rpunch, anim_rpunched, anim_rfall are now
* compiled (bank $1B). Patched in init_roper_compiled (called
* from init_mission13). The legacy spr_roper*/spr_rpunch*/
* spr_rpunched/spr_rfall* cache vars below stay because mission1.s
* spawn templates' idle_addr fields still point at bank-$02
* ROPER1 (the spawn-template detector in script_spawn_npc keys
* on that).

* anim_lwalk, anim_lpunch, anim_lpunched, anim_lfall are now
* compiled (bank $1B). Patched in init_linda_compiled (called
* from init_mission13). The legacy spr_linda*/spr_lpunch*/
* spr_lpunched/spr_lfall* cache vars below stay because mission1.s
* spawn templates' idle_addr fields point at bank-$02 LINDA1
* (the spawn-template detector keys on that) and ld_set_frame
* still uses spr_lclimb1/2 for ladder climbing (not migrated —
* legacy bank-$02 frames).

* Patch billy_sprite frame_addr (+14), idle_addr (+42), and the
* compiled inverse-mask address (+60 — moved from +52 since the
* compiled-NPC migration). Also seed MASK_ADDR so the very first
* draw_all (before any advance_walk) renders correctly.
 lda spr_img01
 sta billy_sprite+14
 sta billy_sprite+42
 lda spr_image01_mask
 sta billy_sprite+60
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
* Release any OP_BOUNDS lock from a prior run so a level restart
* reloads the level-data stratum table normally.
 sep $20
 stz bounds_locked
 rep $20

 sec
 xce                   ; back to emulation mode

* Load initial screen's bounds table. Read initial_screen from
* the bank-$02 level header ($02/0001) rather than hardcoding 0.
 lda #$01
 sta $F0
 stz $F1
 lda #$02
 sta $F2              ; $F0 -> $02/0001
 ldy #0
 lda [$F0],y          ; A = initial_screen
 jsl load_screen_bounds_l
* Load global ladder list (once)
 jsl load_ladders_l
* Reset world scroll offset
 stz world_offset
 stz world_offset+1
* Reset script scroll clamps to no-limit sentinels.
 stz scroll_min_wo
 stz scroll_min_wo+1
 lda #$FF
 sta scroll_max_wo
 sta scroll_max_wo+1
 rtl

*-------------------------------
* Sprite address cache (bank $02 addresses, set by init_level)
*-------------------------------

* Compiled Williams sprites — bank-$1B addresses populated by
* init_mission13 from mission13's spr_addr_tbl. Used to render
* Williams' frames through draw_sprite_compiled (AND/ORA
* pipeline) instead of the slower legacy mask-checking path.
* Each frame is 4 entries: DATA, MASK, DATA_MIRROR, MASK_MIRROR.

* Burnov (boss) — bank-$06 sprite addresses, populated by
* init_mission12 from mission12's spr_addr_tbl.

* Burnov holds-and-pummels-Billy frames. Used by anim_bngrab,
* triggered when Burnov's punch lands on Billy. Replaces both
* sprites with BNBILLY1↔2 alternations + a final BNBILLY3 release.

* Burnov "dissolving" animation frames (8 frames, body → helmet).
* Played after each non-final fall as part of his teleport-and-
* respawn boss death cycle. Played in reverse for the recon back.

* Linda-with-flail walk frames (LFWALK1/2/3) and her mace-swing
* attack frames (LMACE1/2/3). Loaded from mission12 by
* init_mission12.

* Williams-with-pipe walk frames (WPIPEWALK1/2/3). Same dimensions
* as regular William.

* Standalone mace weapon (5 orientations). Used for dropped-mace
* sprites (e.g. when linda_flail falls and her weapon hits the
* ground as a static MACE2).

* Standalone pipe (recoverable item — dropped by williams_pipe).

* Billy with pipe — walking frames (BPIPEW1-3) and swing frames
* (BPIPE1-4). Used when billy_pipe_armed != 0. Same dimensions as
* WPIPEW (9-11 wide × 40 tall), Billy mask = $66.

* Set non-zero when Billy has picked up a pipe. Cleared by
* OP_KILLOBJ. Drives advance_walk's frame-table choice and L-key
* attack dispatch (anim_bpipeswing vs anim_punch1).

* Same idea, but for a recovered mace (MACE2 dropped by
* linda_flail). Either flag set means Billy is "armed"; only
* one is set at a time. OP_KILLOBJ clears both.

* Set non-zero when Billy has picked up a knife (KNIFE2/KNIFE4
* dropped by williams_knife). Unlike pipe/mace there's no armed
* idle pose — Billy keeps the regular IMAGE01 compiled idle and
* walk. L throws the knife as a controller=$03 projectile and
* clears the flag.

* Walk-frame address tables for armed Billy. Patched by
* init_mission12. advance_walk reads pipe_walk_addr_tbl when
* billy_pipe_armed != 0 and mace_walk_addr_tbl when
* billy_mace_armed != 0; otherwise uses walk_addr_tbl (the
* compiled IMAGE01-03 table).

* Billy with mace — walking (3 frames) and swing (4 frames).

* Billy-with-knife walk frames (BKWALK1/2/3). Heights are uniform
* (40 lines), but widths differ — BKWALK1/3 are 11, BKWALK2 is 9.
* advance_walk reads knife_walk_x_tbl for the per-frame width and
* uses a hardcoded 40 for height. BKNIFE1/2/3 are reserved for
* the throw animation (loaded but not yet used by the walk path).

* Billy fall pose (BFALL during arc) and fallen pose (BFALLEN
* on the ground). Bank $19 (mission12). Loaded by init_mission12.

* Bank-$19 address of mission12's loading_string_table. Read
* from the mission12 header (+$14) by init_mission12. Used by
* draw_loading_string to look up status strings shown during
* the loading screen.

* Williams-with-pipe swing frames (WPIPE1-6). His attack uses
* a 5-frame sequence: WPIPE1, WPIPE4, WPIPE2, WPIPE6, WPIPE3.
* WPIPE5 isn't used by the swing but is loaded for completeness.

* Williams-with-knife throw frames (WKNIFE1, WKNIFE2) and the
* knife projectile/dropped-item sprites (KNIFE2 right, KNIFE4 left).
* Loaded from mission12 by init_mission12.

* Burnov "death counter" — how many times he's gone through the
* dissolve/teleport/reconstitute cycle. Reset at level init.
*   0 → on next fall, dissolve + teleport (1st kill)
*   1 → on next fall, dissolve + teleport (2nd kill)
*   2 → on next fall, permadeath (3rd kill, level ends)

* Billy spin-kick frames (legacy data, mask=$66). Loaded by
* init_level. Played as anim_bspinkick when J+L is pressed
* during anim_jump.

* Sub-frame -> WSOMER frame address (legacy bank-$02 addrs).
* Kept populated by init_level for backwards compat / fallback;
* fo_somersault reads the compiled tables below.

* Compiled WSOMER lookup tables (5 sub-frames × 2 bytes each).
* Filled by init_williams_compiled. Sub-frame map:
*   0: WSOMER1   1: WSOMER3   2: WSOMER2   3: WSOMER3   4: WSOMER1
* fo_somersault picks data+mask vs data_mir+mask_mir based on
* info+4 (mirror flag) — the compiled draw doesn't mirror at
* draw time, so the caller selects pre-rotated arrays.

* Uppercut input window. Counts down from UPPERCUT_WINDOW after
* anim_jump ends (i.e., Billy lands). While > 0, a Punch press
* triggers anim_uppercut instead of anim_punch1/2.

* --- Grab system ---
* After a punch connects, punch_window counts down. While > 0,
* pressing direction-toward-the-just-hit enemy enters grab state:
* Billy holds the enemy (BGRAB2 / xHELD1) until Billy walks away
* (release) or presses Punch (grab-punch sub-anim showing BGRAB1
* / xHELD2 for GRAB_PUNCH_DURATION frames, registers a normal hit).

* Grabbed enemies render lower on screen than their standing pose:
* when try_enter_grab succeeds, the enemy's ypos is bumped down by
* GRAB_Y_OFFSET. exit_grab and the gp_fall path unbump it back to
* standing height before behavior or fall_anim takes over.

* Per-frame held sprite sizes (low byte of *_X / *_Y from the
* sprite data in mission1.s). Hardcoded so input handling stays
* in 8-bit emulation; if the user redraws a held sprite, update
* the matching constant here.

                          ;   (0 = not grabbing)
                          ;   the grab-state interceptor

* Burnov-grabs-Billy state. Set by check_punch_hit when Burnov's
* anim_bnpunch lands on Billy; cleared by :normal_end when the
* anim_bngrab sequence completes. While set:
*   - draw_all skips Billy (his sprite is hidden — Burnov's
*     BNBILLY1/2/3 frames are the "combined" pose).
*   - process_input is a no-op (Billy can't defend the grab).

* NES-style A/B button input: J = button A, L = button B.
* When either is strobed we record it in btn_pending_key with a
* BTN_WINDOW-frame timer. If the OTHER button strobes before the
* timer expires, it counts as "both pressed" → jump and we cancel
* the pending single action. If the timer expires alone, the
* single action fires (mirror-aware: the button toward Billy's
* facing direction is punch, the other is back-kick).

* Input source: 0 = keyboard (default), 1 = joystick.
* Toggle with Ctrl-J (joystick) / Ctrl-K (keyboard) at any time.
* In joystick mode, GetJoyXY drives WASD-equivalent walking and
* $C061 bit 7 / $C062 bit 7 stand in for J / L through the same
* btn_action_fire pipeline — so the NES same-window logic for
* jump still applies (press both buttons within BTN_WINDOW).
* Input source: 0 = keyboard, 1 = joystick, 2 = SNES MAX.
* 0 until both axes have read centered once after entering joy mode.
* Re-zeroed on Ctrl-J so the user can rearm if the stick goes stale.
* SNES MAX controller 1 state. snes_poll fills these from the slot
* card every frame (active-HIGH after poll: bit set = button pressed).
* Byte 0: bit 0=Right, 1=Left, 2=Down, 3=Up, 4=Start, 5=Select, 6=Y, 7=B
* Byte 1: bits 0-3 unused, 4=R shoulder, 5=L shoulder, 6=X, 7=A
* SNES MAX slot configuration. Latch/data at $C0X0, clock at
* $C0X1, where X = slot+8 (slot 1=$C090, slot 4=$C0C0,
* slot 7=$C0F0). Change to a different slot by editing the two
* address constants below. Slot 4 matches the manufacturer's
* default. Merlin32 won't parse arithmetic in `stal` operands,
* hence the precomputed hex.
* Joystick deadzone — values inside [DEADZONE_LO, DEADZONE_HI]
* count as "centered" for that axis. 8-bit unsigned per GetJoyXY.
* Widened from the original $40/$C0 to absorb stick drift / cheap
* IIgs paddles whose center reads well off $80.

; Roper
; Linda Lash
* Compiled-sprite extras for AND/ORA pipeline overlay path
* Billy walk frames — compiled
* Billy climb frames — compiled
* Billy punch1 frames — compiled
* Billy punch2 frames — compiled
* Billy kick frames — compiled
* Billy jump frames — compiled
* Billy hit-reaction frame — compiled

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
_init_mission12
 clc
 xce                   ; native mode
 rep $30
 mx %00

* Read header.loading_str_off (+$14) and stash the resulting
* bank-$19 address — draw_loading_string uses it later. Done
* first so we can re-use $F0/$F2 for the spr_addr_tbl lookup
* below without juggling two pointers.
 lda #$0014
 sta $F0
 sep $20
 lda #$19
 sta $F2
 rep $20
 ldy #0
 lda [$F0],y
 sta loading_str_tbl_addr

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

* Billy-throws-knife frames (BKNIFE1/2/3) at indices 27-29
* ($36-$3A). Reserved for the throw animation (cached but
* unused by the walk path; the walk uses BKWALK1/2/3 below).
 ldy #$36
 lda [$F0],y
 sta spr_bknife1
 ldy #$38
 lda [$F0],y
 sta spr_bknife2
 ldy #$3A
 lda [$F0],y
 sta spr_bknife3

* Billy-with-knife walk frames (BKWALK1/2/3) at the tail of
* spr_addr_tbl ($88/$8A/$8C). Used by advance_walk when
* billy_knife_armed is set.
 ldy #$88
 lda [$F0],y
 sta spr_bkwalk1
 ldy #$8A
 lda [$F0],y
 sta spr_bkwalk2
 ldy #$8C
 lda [$F0],y
 sta spr_bkwalk3

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
*
* anim_bnwalk is now compiled (bank $1B) — patched in
* init_burnov_compiled (called from init_mission13). The legacy
* spr_bnwalk1/2/3 cache vars below stay because the spawn
* detector :is_burnov writes spr_bnwalk1 to info+14 and the
* post-:do_patch compiled-Burnov detector keys on that match
* before repointing to compiled.

* anim_bnpunch is now compiled (bank $1C) — patched in
* init_burnov_combat_compiled (called from init_mission14).
* spr_bnpunch1/2 cache vars stay because init_mission12 still
* populates them; they're just unread.

* anim_bngrab is now compiled (bank $1C) — patched in
* init_burnov_combat_compiled.

* anim_bnpunched and anim_bnfall are now compiled (bank $1C) —
* patched in init_burnov_combat_compiled.

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

* anim_lfwalk, anim_lmace, anim_wpipewalk, anim_wpipeswing,
* anim_wkthrow are now compiled (bank $1B). Patched in
* init_armed_compiled (called from init_mission13). The legacy
* spr_lfwalk*/spr_lmace*/spr_wpipewalk*/spr_wpipe*/spr_wknife*
* cache vars below stay because mission1.s armed-NPC spawn
* templates' idle_addr fields point at bank-$19 LFWALK1 /
* WPIPEWALK1 / WKNIFE1 (the spawn-template detector keys on
* those values).
*
* anim_lffall and anim_wpfall placeholders (bank-$19 LFWALK1 /
* WPIPEWALK1 reuse) are still patched here — they're not yet
* migrated to compiled form.
 lda spr_lfwalk1
 sta anim_lffall+3+3
 sta anim_lffall+3+8
 lda spr_wpipewalk1
 sta anim_wpfall+3+3
 sta anim_wpfall+3+8

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

* Patch knife_walk_addr_tbl with BKWALK1, 2, 3, 2 and the
* per-frame widths (11 / 9 / 11 / 9). Heights are uniform 40
* across all three frames so we don't need a Y table — the
* knife branch in advance_walk hardcodes the FRAME_Y store.
 lda spr_bkwalk1
 sta knife_walk_addr_tbl
 lda spr_bkwalk2
 sta knife_walk_addr_tbl+2
 lda spr_bkwalk3
 sta knife_walk_addr_tbl+4
 lda spr_bkwalk2
 sta knife_walk_addr_tbl+6
 sep $20
 mx %10
 lda #$0B               ; BKWALK1 width
 sta knife_walk_x_tbl
 lda #$09               ; BKWALK2 width
 sta knife_walk_x_tbl+1
 lda #$0B               ; BKWALK3 width
 sta knife_walk_x_tbl+2
 lda #$09               ; BKWALK2 width (cycle frame)
 sta knife_walk_x_tbl+3
 rep $20
 mx %00

 sec
 xce                   ; back to emulation
 mx %11
* DEBUG: dump key Burnov addresses to the text screen so we
* can verify the address-table read worked. Format:
*   "BN <bnwalk1> <bnpunch1> <bnfall1>"
* Each is 4 hex digits (high then low).
 do DEBUG_PRINT
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
 fin
 rtl

*----------------------------------------------------------
* init_mission13 - Read mission13's spr_addr_tbl (bank $1A) and
* populate the spr_w*c_data / _mask / _mirror cache vars in
* game.s. Mirror of init_mission12's lookup but for the
* compiled mission1 sprite bank. Each frame contributes 4
* table entries (DATA, MASK, DATA_MIRROR, MASK_MIRROR), so
* the table indexes step by $08 between frames.
* Caller: init flow after init_mission12. Native mode + 16-bit
* A/X/Y on entry.
*----------------------------------------------------------
_init_mission13
 clc
 xce
 rep $30
 mx %00
* Set $F0/$F1/$F2 = $1B/0012 (header.spr_addr_off field).
 lda #$0012
 sta $F0
 sep $20
 lda #$1B
 sta $F2
 rep $20
* Dereference: $F0 ← *($1B/0012) = bank-$1B offset of spr_addr_tbl.
 ldy #0
 lda [$F0],y
 sta $F0
* spr_addr_tbl is a contiguous array of 2-byte bank-$1B offsets,
* 4 entries per sprite (DATA, MASK, DATA_MIRROR, MASK_MIRROR).
* Order matches the cache var declarations: WILLIAM1, WILLIAM2,
* WILLIAM3, WPUNCH1, WPUNCH2, WPUNCHED, WFALL, WFALLEN.
 ldy #0
 lda [$F0],y
 sta spr_william1c_data
 ldy #2
 lda [$F0],y
 sta spr_william1c_mask
 ldy #4
 lda [$F0],y
 sta spr_william1c_data_mir
 ldy #6
 lda [$F0],y
 sta spr_william1c_mask_mir
 ldy #8
 lda [$F0],y
 sta spr_william2c_data
 ldy #10
 lda [$F0],y
 sta spr_william2c_mask
 ldy #12
 lda [$F0],y
 sta spr_william2c_data_mir
 ldy #14
 lda [$F0],y
 sta spr_william2c_mask_mir
 ldy #16
 lda [$F0],y
 sta spr_william3c_data
 ldy #18
 lda [$F0],y
 sta spr_william3c_mask
 ldy #20
 lda [$F0],y
 sta spr_william3c_data_mir
 ldy #22
 lda [$F0],y
 sta spr_william3c_mask_mir
 ldy #24
 lda [$F0],y
 sta spr_wpunch1c_data
 ldy #26
 lda [$F0],y
 sta spr_wpunch1c_mask
 ldy #28
 lda [$F0],y
 sta spr_wpunch1c_data_mir
 ldy #30
 lda [$F0],y
 sta spr_wpunch1c_mask_mir
 ldy #32
 lda [$F0],y
 sta spr_wpunch2c_data
 ldy #34
 lda [$F0],y
 sta spr_wpunch2c_mask
 ldy #36
 lda [$F0],y
 sta spr_wpunch2c_data_mir
 ldy #38
 lda [$F0],y
 sta spr_wpunch2c_mask_mir
 ldy #40
 lda [$F0],y
 sta spr_wpunchedc_data
 ldy #42
 lda [$F0],y
 sta spr_wpunchedc_mask
 ldy #44
 lda [$F0],y
 sta spr_wpunchedc_data_mir
 ldy #46
 lda [$F0],y
 sta spr_wpunchedc_mask_mir
 ldy #48
 lda [$F0],y
 sta spr_wfallc_data
 ldy #50
 lda [$F0],y
 sta spr_wfallc_mask
 ldy #52
 lda [$F0],y
 sta spr_wfallc_data_mir
 ldy #54
 lda [$F0],y
 sta spr_wfallc_mask_mir
 ldy #56
 lda [$F0],y
 sta spr_wfallenc_data
 ldy #58
 lda [$F0],y
 sta spr_wfallenc_mask
 ldy #60
 lda [$F0],y
 sta spr_wfallenc_data_mir
 ldy #62
 lda [$F0],y
 sta spr_wfallenc_mask_mir
 ldy #64
 lda [$F0],y
 sta spr_roper1c_data
 ldy #66
 lda [$F0],y
 sta spr_roper1c_mask
 ldy #68
 lda [$F0],y
 sta spr_roper1c_data_mir
 ldy #70
 lda [$F0],y
 sta spr_roper1c_mask_mir
 ldy #72
 lda [$F0],y
 sta spr_roper2c_data
 ldy #74
 lda [$F0],y
 sta spr_roper2c_mask
 ldy #76
 lda [$F0],y
 sta spr_roper2c_data_mir
 ldy #78
 lda [$F0],y
 sta spr_roper2c_mask_mir
 ldy #80
 lda [$F0],y
 sta spr_roper3c_data
 ldy #82
 lda [$F0],y
 sta spr_roper3c_mask
 ldy #84
 lda [$F0],y
 sta spr_roper3c_data_mir
 ldy #86
 lda [$F0],y
 sta spr_roper3c_mask_mir
 ldy #88
 lda [$F0],y
 sta spr_rpunch1c_data
 ldy #90
 lda [$F0],y
 sta spr_rpunch1c_mask
 ldy #92
 lda [$F0],y
 sta spr_rpunch1c_data_mir
 ldy #94
 lda [$F0],y
 sta spr_rpunch1c_mask_mir
 ldy #96
 lda [$F0],y
 sta spr_rpunch2c_data
 ldy #98
 lda [$F0],y
 sta spr_rpunch2c_mask
 ldy #100
 lda [$F0],y
 sta spr_rpunch2c_data_mir
 ldy #102
 lda [$F0],y
 sta spr_rpunch2c_mask_mir
 ldy #104
 lda [$F0],y
 sta spr_rpunchedc_data
 ldy #106
 lda [$F0],y
 sta spr_rpunchedc_mask
 ldy #108
 lda [$F0],y
 sta spr_rpunchedc_data_mir
 ldy #110
 lda [$F0],y
 sta spr_rpunchedc_mask_mir
 ldy #112
 lda [$F0],y
 sta spr_rfall1c_data
 ldy #114
 lda [$F0],y
 sta spr_rfall1c_mask
 ldy #116
 lda [$F0],y
 sta spr_rfall1c_data_mir
 ldy #118
 lda [$F0],y
 sta spr_rfall1c_mask_mir
 ldy #120
 lda [$F0],y
 sta spr_rfall2c_data
 ldy #122
 lda [$F0],y
 sta spr_rfall2c_mask
 ldy #124
 lda [$F0],y
 sta spr_rfall2c_data_mir
 ldy #126
 lda [$F0],y
 sta spr_rfall2c_mask_mir
 ldy #128
 lda [$F0],y
 sta spr_linda1c_data
 ldy #130
 lda [$F0],y
 sta spr_linda1c_mask
 ldy #132
 lda [$F0],y
 sta spr_linda1c_data_mir
 ldy #134
 lda [$F0],y
 sta spr_linda1c_mask_mir
 ldy #136
 lda [$F0],y
 sta spr_linda2c_data
 ldy #138
 lda [$F0],y
 sta spr_linda2c_mask
 ldy #140
 lda [$F0],y
 sta spr_linda2c_data_mir
 ldy #142
 lda [$F0],y
 sta spr_linda2c_mask_mir
 ldy #144
 lda [$F0],y
 sta spr_linda3c_data
 ldy #146
 lda [$F0],y
 sta spr_linda3c_mask
 ldy #148
 lda [$F0],y
 sta spr_linda3c_data_mir
 ldy #150
 lda [$F0],y
 sta spr_linda3c_mask_mir
 ldy #152
 lda [$F0],y
 sta spr_lpunch1c_data
 ldy #154
 lda [$F0],y
 sta spr_lpunch1c_mask
 ldy #156
 lda [$F0],y
 sta spr_lpunch1c_data_mir
 ldy #158
 lda [$F0],y
 sta spr_lpunch1c_mask_mir
 ldy #160
 lda [$F0],y
 sta spr_lpunch2c_data
 ldy #162
 lda [$F0],y
 sta spr_lpunch2c_mask
 ldy #164
 lda [$F0],y
 sta spr_lpunch2c_data_mir
 ldy #166
 lda [$F0],y
 sta spr_lpunch2c_mask_mir
 ldy #168
 lda [$F0],y
 sta spr_lpunchedc_data
 ldy #170
 lda [$F0],y
 sta spr_lpunchedc_mask
 ldy #172
 lda [$F0],y
 sta spr_lpunchedc_data_mir
 ldy #174
 lda [$F0],y
 sta spr_lpunchedc_mask_mir
 ldy #176
 lda [$F0],y
 sta spr_lfall1c_data
 ldy #178
 lda [$F0],y
 sta spr_lfall1c_mask
 ldy #180
 lda [$F0],y
 sta spr_lfall1c_data_mir
 ldy #182
 lda [$F0],y
 sta spr_lfall1c_mask_mir
 ldy #184
 lda [$F0],y
 sta spr_lfall2c_data
 ldy #186
 lda [$F0],y
 sta spr_lfall2c_mask
 ldy #188
 lda [$F0],y
 sta spr_lfall2c_data_mir
 ldy #190
 lda [$F0],y
 sta spr_lfall2c_mask_mir
 ldy #192
 lda [$F0],y
 sta spr_bnwalk1c_data
 ldy #194
 lda [$F0],y
 sta spr_bnwalk1c_mask
 ldy #196
 lda [$F0],y
 sta spr_bnwalk1c_data_mir
 ldy #198
 lda [$F0],y
 sta spr_bnwalk1c_mask_mir
 ldy #200
 lda [$F0],y
 sta spr_bnwalk2c_data
 ldy #202
 lda [$F0],y
 sta spr_bnwalk2c_mask
 ldy #204
 lda [$F0],y
 sta spr_bnwalk2c_data_mir
 ldy #206
 lda [$F0],y
 sta spr_bnwalk2c_mask_mir
 ldy #208
 lda [$F0],y
 sta spr_bnwalk3c_data
 ldy #210
 lda [$F0],y
 sta spr_bnwalk3c_mask
 ldy #212
 lda [$F0],y
 sta spr_bnwalk3c_data_mir
 ldy #214
 lda [$F0],y
 sta spr_bnwalk3c_mask_mir
* WSOMER1/2/3 (offsets 216-238) — Williams cartwheel frames.
 ldy #216
 lda [$F0],y
 sta spr_wsomer1c_data
 ldy #218
 lda [$F0],y
 sta spr_wsomer1c_mask
 ldy #220
 lda [$F0],y
 sta spr_wsomer1c_data_mir
 ldy #222
 lda [$F0],y
 sta spr_wsomer1c_mask_mir
 ldy #224
 lda [$F0],y
 sta spr_wsomer2c_data
 ldy #226
 lda [$F0],y
 sta spr_wsomer2c_mask
 ldy #228
 lda [$F0],y
 sta spr_wsomer2c_data_mir
 ldy #230
 lda [$F0],y
 sta spr_wsomer2c_mask_mir
 ldy #232
 lda [$F0],y
 sta spr_wsomer3c_data
 ldy #234
 lda [$F0],y
 sta spr_wsomer3c_mask
 ldy #236
 lda [$F0],y
 sta spr_wsomer3c_data_mir
 ldy #238
 lda [$F0],y
 sta spr_wsomer3c_mask_mir
* LCLIMB1/2 (offsets 240-270) — Linda's ladder-climb frames.
 ldy #240
 lda [$F0],y
 sta spr_lclimb1c_data
 ldy #242
 lda [$F0],y
 sta spr_lclimb1c_mask
 ldy #244
 lda [$F0],y
 sta spr_lclimb1c_data_mir
 ldy #246
 lda [$F0],y
 sta spr_lclimb1c_mask_mir
 ldy #248
 lda [$F0],y
 sta spr_lclimb2c_data
 ldy #250
 lda [$F0],y
 sta spr_lclimb2c_mask
 ldy #252
 lda [$F0],y
 sta spr_lclimb2c_data_mir
 ldy #254
 lda [$F0],y
 sta spr_lclimb2c_mask_mir

 sec
 xce
 mx %11
* DEBUG: dump compiled WILLIAM1 cache values + first bytes of
* WILLIAM1_DATA at bank $1B:$0020. Format:
*   "M13 D<dh><dl> M<mh><ml> R<b29><b2A><b2D><b2E>"
* The "R" line samples bytes at offsets that should differ in
* row 1 of WILLIAM1_DATA. Per the compile output:
*   $1B:$0029 = $00 (row 1 byte 0 — transparent prefix)
*   $1B:$002A = $00 (row 1 byte 1 — transparent prefix)
*   $1B:$002D = $F0 (row 1 byte 4 — first opaque pixel pair)
*   $1B:$002E = $F0 (row 1 byte 5)
* If we see anything other than 00 00 F0 F0 the bank-$1B image
* is corrupted (data wasn't loaded, or got overwritten).
 do DEBUG_PRINT
 lda #$CD              ; 'M'
 jsr dbg_print_char
 lda #$B1              ; '1'
 jsr dbg_print_char
 lda #$B3              ; '3'
 jsr dbg_print_char
 lda #$A0
 jsr dbg_print_char
 lda #$C4              ; 'D'
 jsr dbg_print_char
 lda spr_william1c_data+1
 jsr dbg_print_hex8
 lda spr_william1c_data
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$CD              ; 'M'
 jsr dbg_print_char
 lda spr_william1c_mask+1
 jsr dbg_print_hex8
 lda spr_william1c_mask
 jsr dbg_print_hex8
 lda #$A0
 jsr dbg_print_char
 lda #$D2              ; 'R'
 jsr dbg_print_char
 ldal $1B0029
 jsr dbg_print_hex8
 ldal $1B002A
 jsr dbg_print_hex8
 ldal $1B002D
 jsr dbg_print_hex8
 ldal $1B002E
 jsr dbg_print_hex8
 jsr dbg_print_nl
 fin
 jsr init_williams_compiled
 jsr init_roper_compiled
 jsr init_linda_compiled
 jsr init_burnov_compiled
 rtl

*----------------------------------------------------------
* init_williams_compiled - Patch the compiled-form Williams
* anim descriptors (anim_wwalk, anim_wpunch, anim_wpunched,
* anim_wfall) with the bank-$1B WILLIAM*_DATA / _MASK / _MIRROR
* addresses populated by init_mission13. Each compiled frame
* slot is 11 bytes: 3-byte header (frame_x, frame_y, duration)
* + 8 bytes of patched fields (data_lo/hi, mask_lo/hi,
* dmir_lo/hi, mmir_lo/hi). Frame N starts at descriptor + 3 +
* N*11; data field at +6+N*11, mask at +8+N*11, dmir at
* +10+N*11, mmir at +12+N*11. Native mode, MX %00 entry.
*----------------------------------------------------------
 mx %11
init_williams_compiled
 clc
 xce
 rep $30
 mx %00

* anim_wwalk frame 0 = WILLIAM1
 lda spr_william1c_data
 sta anim_wwalk+6
 lda spr_william1c_mask
 sta anim_wwalk+8
 lda spr_william1c_data_mir
 sta anim_wwalk+10
 lda spr_william1c_mask_mir
 sta anim_wwalk+12
* anim_wwalk frame 1 = WILLIAM2
 lda spr_william2c_data
 sta anim_wwalk+17
 lda spr_william2c_mask
 sta anim_wwalk+19
 lda spr_william2c_data_mir
 sta anim_wwalk+21
 lda spr_william2c_mask_mir
 sta anim_wwalk+23
* anim_wwalk frame 2 = WILLIAM3
 lda spr_william3c_data
 sta anim_wwalk+28
 lda spr_william3c_mask
 sta anim_wwalk+30
 lda spr_william3c_data_mir
 sta anim_wwalk+32
 lda spr_william3c_mask_mir
 sta anim_wwalk+34
* anim_wwalk frame 3 = WILLIAM2
 lda spr_william2c_data
 sta anim_wwalk+39
 lda spr_william2c_mask
 sta anim_wwalk+41
 lda spr_william2c_data_mir
 sta anim_wwalk+43
 lda spr_william2c_mask_mir
 sta anim_wwalk+45

* anim_wpunch frame 0 = WPUNCH1
 lda spr_wpunch1c_data
 sta anim_wpunch+6
 lda spr_wpunch1c_mask
 sta anim_wpunch+8
 lda spr_wpunch1c_data_mir
 sta anim_wpunch+10
 lda spr_wpunch1c_mask_mir
 sta anim_wpunch+12
* anim_wpunch frame 1 = WPUNCH2
 lda spr_wpunch2c_data
 sta anim_wpunch+17
 lda spr_wpunch2c_mask
 sta anim_wpunch+19
 lda spr_wpunch2c_data_mir
 sta anim_wpunch+21
 lda spr_wpunch2c_mask_mir
 sta anim_wpunch+23

* anim_wpunched frame 0 = WPUNCHED
 lda spr_wpunchedc_data
 sta anim_wpunched+6
 lda spr_wpunchedc_mask
 sta anim_wpunched+8
 lda spr_wpunchedc_data_mir
 sta anim_wpunched+10
 lda spr_wpunchedc_mask_mir
 sta anim_wpunched+12

* anim_wfall frame 0 = WFALL
 lda spr_wfallc_data
 sta anim_wfall+6
 lda spr_wfallc_mask
 sta anim_wfall+8
 lda spr_wfallc_data_mir
 sta anim_wfall+10
 lda spr_wfallc_mask_mir
 sta anim_wfall+12
* anim_wfall frame 1 = WFALLEN
 lda spr_wfallenc_data
 sta anim_wfall+17
 lda spr_wfallenc_mask
 sta anim_wfall+19
 lda spr_wfallenc_data_mir
 sta anim_wfall+21
 lda spr_wfallenc_mask_mir
 sta anim_wfall+23

* Populate the 4 WSOMER sub-frame tables. fo_somersault reads
* one of these per sub-frame (data+mask for mirror=0, _mir
* variants for mirror=1). Sub-frame → sprite map:
*   0,4 → WSOMER1  (offsets 0, 8)
*   1,3 → WSOMER3  (offsets 2, 6)
*   2   → WSOMER2  (offset  4)
 lda spr_wsomer1c_data
 sta somersault_data_tbl
 sta somersault_data_tbl+8
 lda spr_wsomer3c_data
 sta somersault_data_tbl+2
 sta somersault_data_tbl+6
 lda spr_wsomer2c_data
 sta somersault_data_tbl+4
 lda spr_wsomer1c_mask
 sta somersault_mask_tbl
 sta somersault_mask_tbl+8
 lda spr_wsomer3c_mask
 sta somersault_mask_tbl+2
 sta somersault_mask_tbl+6
 lda spr_wsomer2c_mask
 sta somersault_mask_tbl+4
 lda spr_wsomer1c_data_mir
 sta somersault_data_mir_tbl
 sta somersault_data_mir_tbl+8
 lda spr_wsomer3c_data_mir
 sta somersault_data_mir_tbl+2
 sta somersault_data_mir_tbl+6
 lda spr_wsomer2c_data_mir
 sta somersault_data_mir_tbl+4
 lda spr_wsomer1c_mask_mir
 sta somersault_mask_mir_tbl
 sta somersault_mask_mir_tbl+8
 lda spr_wsomer3c_mask_mir
 sta somersault_mask_mir_tbl+2
 sta somersault_mask_mir_tbl+6
 lda spr_wsomer2c_mask_mir
 sta somersault_mask_mir_tbl+4

 sec
 xce
 mx %11
 rts

*----------------------------------------------------------
* init_roper_compiled - Patch the compiled-form Roper anim
* descriptors (anim_rwalk, anim_rpunch, anim_rpunched,
* anim_rfall) with the bank-$1B ROPER*_DATA / _MASK / _MIRROR
* addresses populated by init_mission13. Stride layout matches
* init_williams_compiled.
*----------------------------------------------------------
 mx %11
init_roper_compiled
 clc
 xce
 rep $30
 mx %00

* anim_rwalk frame 0 = ROPER1
 lda spr_roper1c_data
 sta anim_rwalk+6
 lda spr_roper1c_mask
 sta anim_rwalk+8
 lda spr_roper1c_data_mir
 sta anim_rwalk+10
 lda spr_roper1c_mask_mir
 sta anim_rwalk+12
* anim_rwalk frame 1 = ROPER2
 lda spr_roper2c_data
 sta anim_rwalk+17
 lda spr_roper2c_mask
 sta anim_rwalk+19
 lda spr_roper2c_data_mir
 sta anim_rwalk+21
 lda spr_roper2c_mask_mir
 sta anim_rwalk+23
* anim_rwalk frame 2 = ROPER3
 lda spr_roper3c_data
 sta anim_rwalk+28
 lda spr_roper3c_mask
 sta anim_rwalk+30
 lda spr_roper3c_data_mir
 sta anim_rwalk+32
 lda spr_roper3c_mask_mir
 sta anim_rwalk+34
* anim_rwalk frame 3 = ROPER2
 lda spr_roper2c_data
 sta anim_rwalk+39
 lda spr_roper2c_mask
 sta anim_rwalk+41
 lda spr_roper2c_data_mir
 sta anim_rwalk+43
 lda spr_roper2c_mask_mir
 sta anim_rwalk+45

* anim_rpunch frame 0 = RPUNCH1
 lda spr_rpunch1c_data
 sta anim_rpunch+6
 lda spr_rpunch1c_mask
 sta anim_rpunch+8
 lda spr_rpunch1c_data_mir
 sta anim_rpunch+10
 lda spr_rpunch1c_mask_mir
 sta anim_rpunch+12
* anim_rpunch frame 1 = RPUNCH2
 lda spr_rpunch2c_data
 sta anim_rpunch+17
 lda spr_rpunch2c_mask
 sta anim_rpunch+19
 lda spr_rpunch2c_data_mir
 sta anim_rpunch+21
 lda spr_rpunch2c_mask_mir
 sta anim_rpunch+23

* anim_rpunched frame 0 = RPUNCHED
 lda spr_rpunchedc_data
 sta anim_rpunched+6
 lda spr_rpunchedc_mask
 sta anim_rpunched+8
 lda spr_rpunchedc_data_mir
 sta anim_rpunched+10
 lda spr_rpunchedc_mask_mir
 sta anim_rpunched+12

* anim_rfall frame 0 = RFALL1
 lda spr_rfall1c_data
 sta anim_rfall+6
 lda spr_rfall1c_mask
 sta anim_rfall+8
 lda spr_rfall1c_data_mir
 sta anim_rfall+10
 lda spr_rfall1c_mask_mir
 sta anim_rfall+12
* anim_rfall frame 1 = RFALL2
 lda spr_rfall2c_data
 sta anim_rfall+17
 lda spr_rfall2c_mask
 sta anim_rfall+19
 lda spr_rfall2c_data_mir
 sta anim_rfall+21
 lda spr_rfall2c_mask_mir
 sta anim_rfall+23

 sec
 xce
 mx %11
 rts

*----------------------------------------------------------
* init_linda_compiled - Patch the compiled-form Linda anim
* descriptors (anim_lwalk, anim_lpunch, anim_lpunched,
* anim_lfall) with the bank-$1B LINDA*_DATA / _MASK / _MIRROR
* addresses populated by init_mission13. Stride layout matches
* init_williams_compiled / init_roper_compiled.
*----------------------------------------------------------
 mx %11
init_linda_compiled
 clc
 xce
 rep $30
 mx %00

* anim_lwalk frame 0 = LINDA1
 lda spr_linda1c_data
 sta anim_lwalk+6
 lda spr_linda1c_mask
 sta anim_lwalk+8
 lda spr_linda1c_data_mir
 sta anim_lwalk+10
 lda spr_linda1c_mask_mir
 sta anim_lwalk+12
* anim_lwalk frame 1 = LINDA2
 lda spr_linda2c_data
 sta anim_lwalk+17
 lda spr_linda2c_mask
 sta anim_lwalk+19
 lda spr_linda2c_data_mir
 sta anim_lwalk+21
 lda spr_linda2c_mask_mir
 sta anim_lwalk+23
* anim_lwalk frame 2 = LINDA3
 lda spr_linda3c_data
 sta anim_lwalk+28
 lda spr_linda3c_mask
 sta anim_lwalk+30
 lda spr_linda3c_data_mir
 sta anim_lwalk+32
 lda spr_linda3c_mask_mir
 sta anim_lwalk+34
* anim_lwalk frame 3 = LINDA2
 lda spr_linda2c_data
 sta anim_lwalk+39
 lda spr_linda2c_mask
 sta anim_lwalk+41
 lda spr_linda2c_data_mir
 sta anim_lwalk+43
 lda spr_linda2c_mask_mir
 sta anim_lwalk+45

* anim_lpunch frame 0 = LPUNCH1
 lda spr_lpunch1c_data
 sta anim_lpunch+6
 lda spr_lpunch1c_mask
 sta anim_lpunch+8
 lda spr_lpunch1c_data_mir
 sta anim_lpunch+10
 lda spr_lpunch1c_mask_mir
 sta anim_lpunch+12
* anim_lpunch frame 1 = LPUNCH2
 lda spr_lpunch2c_data
 sta anim_lpunch+17
 lda spr_lpunch2c_mask
 sta anim_lpunch+19
 lda spr_lpunch2c_data_mir
 sta anim_lpunch+21
 lda spr_lpunch2c_mask_mir
 sta anim_lpunch+23

* anim_lpunched frame 0 = LPUNCHED
 lda spr_lpunchedc_data
 sta anim_lpunched+6
 lda spr_lpunchedc_mask
 sta anim_lpunched+8
 lda spr_lpunchedc_data_mir
 sta anim_lpunched+10
 lda spr_lpunchedc_mask_mir
 sta anim_lpunched+12

* anim_lfall frame 0 = LFALL1
 lda spr_lfall1c_data
 sta anim_lfall+6
 lda spr_lfall1c_mask
 sta anim_lfall+8
 lda spr_lfall1c_data_mir
 sta anim_lfall+10
 lda spr_lfall1c_mask_mir
 sta anim_lfall+12
* anim_lfall frame 1 = LFALL2
 lda spr_lfall2c_data
 sta anim_lfall+17
 lda spr_lfall2c_mask
 sta anim_lfall+19
 lda spr_lfall2c_data_mir
 sta anim_lfall+21
 lda spr_lfall2c_mask_mir
 sta anim_lfall+23

 sec
 xce
 mx %11
 rts

*----------------------------------------------------------
* init_burnov_compiled - Patch the compiled-form anim_bnwalk
* with bank-$1B BNWALK*_DATA / _MASK / _MIRROR addresses
* populated by init_mission13. Burnov's other anims (punch,
* grab, fall, dissolve, recon) remain legacy bank-$19.
*----------------------------------------------------------
 mx %11
init_burnov_compiled
 clc
 xce
 rep $30
 mx %00

* anim_bnwalk frame 0 = BNWALK1
 lda spr_bnwalk1c_data
 sta anim_bnwalk+6
 lda spr_bnwalk1c_mask
 sta anim_bnwalk+8
 lda spr_bnwalk1c_data_mir
 sta anim_bnwalk+10
 lda spr_bnwalk1c_mask_mir
 sta anim_bnwalk+12
* anim_bnwalk frame 1 = BNWALK2
 lda spr_bnwalk2c_data
 sta anim_bnwalk+17
 lda spr_bnwalk2c_mask
 sta anim_bnwalk+19
 lda spr_bnwalk2c_data_mir
 sta anim_bnwalk+21
 lda spr_bnwalk2c_mask_mir
 sta anim_bnwalk+23
* anim_bnwalk frame 2 = BNWALK3
 lda spr_bnwalk3c_data
 sta anim_bnwalk+28
 lda spr_bnwalk3c_mask
 sta anim_bnwalk+30
 lda spr_bnwalk3c_data_mir
 sta anim_bnwalk+32
 lda spr_bnwalk3c_mask_mir
 sta anim_bnwalk+34
* anim_bnwalk frame 3 = BNWALK2
 lda spr_bnwalk2c_data
 sta anim_bnwalk+39
 lda spr_bnwalk2c_mask
 sta anim_bnwalk+41
 lda spr_bnwalk2c_data_mir
 sta anim_bnwalk+43
 lda spr_bnwalk2c_mask_mir
 sta anim_bnwalk+45

 sec
 xce
 mx %11
 rts

*----------------------------------------------------------
* init_mission14 - Read mission14's spr_addr_tbl from bank $1C
* and populate the spr_*c_* cache vars for armed Linda / armed
* Williams sprites. Mirrors init_mission13's structure but uses
* bank $1C and reads only the 16 armed sprites (offsets 0-126).
* Calls init_armed_compiled at the end to patch the descriptors.
*----------------------------------------------------------
 mx %11
_init_mission14
 clc
 xce
 rep $30
 mx %00
* Set $F0/$F1/$F2 = $1C/0012 (header.spr_addr_off field).
 lda #$0012
 sta $F0
 sep $20
 lda #$1C
 sta $F2
 rep $20
* Dereference: $F0 ← *($1C/0012) = bank-$1C offset of spr_addr_tbl.
 ldy #0
 lda [$F0],y
 sta $F0
* spr_addr_tbl is 16 sprites × 4 entries × 2 bytes = 128 bytes.
* Order matches init_armed_compiled's expectations: LFWALK1/2/3,
* LMACE1/2/3, WPIPEWALK1/2/3, WPIPE1/2/3/4/6, WKNIFE1/2.
 ldy #0
 lda [$F0],y
 sta spr_lfwalk1c_data
 ldy #2
 lda [$F0],y
 sta spr_lfwalk1c_mask
 ldy #4
 lda [$F0],y
 sta spr_lfwalk1c_data_mir
 ldy #6
 lda [$F0],y
 sta spr_lfwalk1c_mask_mir
 ldy #8
 lda [$F0],y
 sta spr_lfwalk2c_data
 ldy #10
 lda [$F0],y
 sta spr_lfwalk2c_mask
 ldy #12
 lda [$F0],y
 sta spr_lfwalk2c_data_mir
 ldy #14
 lda [$F0],y
 sta spr_lfwalk2c_mask_mir
 ldy #16
 lda [$F0],y
 sta spr_lfwalk3c_data
 ldy #18
 lda [$F0],y
 sta spr_lfwalk3c_mask
 ldy #20
 lda [$F0],y
 sta spr_lfwalk3c_data_mir
 ldy #22
 lda [$F0],y
 sta spr_lfwalk3c_mask_mir
 ldy #24
 lda [$F0],y
 sta spr_lmace1c_data
 ldy #26
 lda [$F0],y
 sta spr_lmace1c_mask
 ldy #28
 lda [$F0],y
 sta spr_lmace1c_data_mir
 ldy #30
 lda [$F0],y
 sta spr_lmace1c_mask_mir
 ldy #32
 lda [$F0],y
 sta spr_lmace2c_data
 ldy #34
 lda [$F0],y
 sta spr_lmace2c_mask
 ldy #36
 lda [$F0],y
 sta spr_lmace2c_data_mir
 ldy #38
 lda [$F0],y
 sta spr_lmace2c_mask_mir
 ldy #40
 lda [$F0],y
 sta spr_lmace3c_data
 ldy #42
 lda [$F0],y
 sta spr_lmace3c_mask
 ldy #44
 lda [$F0],y
 sta spr_lmace3c_data_mir
 ldy #46
 lda [$F0],y
 sta spr_lmace3c_mask_mir
 ldy #48
 lda [$F0],y
 sta spr_wpipewalk1c_data
 ldy #50
 lda [$F0],y
 sta spr_wpipewalk1c_mask
 ldy #52
 lda [$F0],y
 sta spr_wpipewalk1c_data_mir
 ldy #54
 lda [$F0],y
 sta spr_wpipewalk1c_mask_mir
 ldy #56
 lda [$F0],y
 sta spr_wpipewalk2c_data
 ldy #58
 lda [$F0],y
 sta spr_wpipewalk2c_mask
 ldy #60
 lda [$F0],y
 sta spr_wpipewalk2c_data_mir
 ldy #62
 lda [$F0],y
 sta spr_wpipewalk2c_mask_mir
 ldy #64
 lda [$F0],y
 sta spr_wpipewalk3c_data
 ldy #66
 lda [$F0],y
 sta spr_wpipewalk3c_mask
 ldy #68
 lda [$F0],y
 sta spr_wpipewalk3c_data_mir
 ldy #70
 lda [$F0],y
 sta spr_wpipewalk3c_mask_mir
 ldy #72
 lda [$F0],y
 sta spr_wpipe1c_data
 ldy #74
 lda [$F0],y
 sta spr_wpipe1c_mask
 ldy #76
 lda [$F0],y
 sta spr_wpipe1c_data_mir
 ldy #78
 lda [$F0],y
 sta spr_wpipe1c_mask_mir
 ldy #80
 lda [$F0],y
 sta spr_wpipe2c_data
 ldy #82
 lda [$F0],y
 sta spr_wpipe2c_mask
 ldy #84
 lda [$F0],y
 sta spr_wpipe2c_data_mir
 ldy #86
 lda [$F0],y
 sta spr_wpipe2c_mask_mir
 ldy #88
 lda [$F0],y
 sta spr_wpipe3c_data
 ldy #90
 lda [$F0],y
 sta spr_wpipe3c_mask
 ldy #92
 lda [$F0],y
 sta spr_wpipe3c_data_mir
 ldy #94
 lda [$F0],y
 sta spr_wpipe3c_mask_mir
 ldy #96
 lda [$F0],y
 sta spr_wpipe4c_data
 ldy #98
 lda [$F0],y
 sta spr_wpipe4c_mask
 ldy #100
 lda [$F0],y
 sta spr_wpipe4c_data_mir
 ldy #102
 lda [$F0],y
 sta spr_wpipe4c_mask_mir
 ldy #104
 lda [$F0],y
 sta spr_wpipe6c_data
 ldy #106
 lda [$F0],y
 sta spr_wpipe6c_mask
 ldy #108
 lda [$F0],y
 sta spr_wpipe6c_data_mir
 ldy #110
 lda [$F0],y
 sta spr_wpipe6c_mask_mir
 ldy #112
 lda [$F0],y
 sta spr_wknife1c_data
 ldy #114
 lda [$F0],y
 sta spr_wknife1c_mask
 ldy #116
 lda [$F0],y
 sta spr_wknife1c_data_mir
 ldy #118
 lda [$F0],y
 sta spr_wknife1c_mask_mir
 ldy #120
 lda [$F0],y
 sta spr_wknife2c_data
 ldy #122
 lda [$F0],y
 sta spr_wknife2c_mask
 ldy #124
 lda [$F0],y
 sta spr_wknife2c_data_mir
 ldy #126
 lda [$F0],y
 sta spr_wknife2c_mask_mir
* Burnov combat sprites (BNPUNCH1/2, BNBILLY1/2/3, BNFALL1,
* BNFALLEN) — offsets 128-182. Order matches mission14.s
* spr_addr_tbl after WKNIFE2.
 ldy #128
 lda [$F0],y
 sta spr_bnpunch1c_data
 ldy #130
 lda [$F0],y
 sta spr_bnpunch1c_mask
 ldy #132
 lda [$F0],y
 sta spr_bnpunch1c_data_mir
 ldy #134
 lda [$F0],y
 sta spr_bnpunch1c_mask_mir
 ldy #136
 lda [$F0],y
 sta spr_bnpunch2c_data
 ldy #138
 lda [$F0],y
 sta spr_bnpunch2c_mask
 ldy #140
 lda [$F0],y
 sta spr_bnpunch2c_data_mir
 ldy #142
 lda [$F0],y
 sta spr_bnpunch2c_mask_mir
 ldy #144
 lda [$F0],y
 sta spr_bnbilly1c_data
 ldy #146
 lda [$F0],y
 sta spr_bnbilly1c_mask
 ldy #148
 lda [$F0],y
 sta spr_bnbilly1c_data_mir
 ldy #150
 lda [$F0],y
 sta spr_bnbilly1c_mask_mir
 ldy #152
 lda [$F0],y
 sta spr_bnbilly2c_data
 ldy #154
 lda [$F0],y
 sta spr_bnbilly2c_mask
 ldy #156
 lda [$F0],y
 sta spr_bnbilly2c_data_mir
 ldy #158
 lda [$F0],y
 sta spr_bnbilly2c_mask_mir
 ldy #160
 lda [$F0],y
 sta spr_bnbilly3c_data
 ldy #162
 lda [$F0],y
 sta spr_bnbilly3c_mask
 ldy #164
 lda [$F0],y
 sta spr_bnbilly3c_data_mir
 ldy #166
 lda [$F0],y
 sta spr_bnbilly3c_mask_mir
 ldy #168
 lda [$F0],y
 sta spr_bnfall1c_data
 ldy #170
 lda [$F0],y
 sta spr_bnfall1c_mask
 ldy #172
 lda [$F0],y
 sta spr_bnfall1c_data_mir
 ldy #174
 lda [$F0],y
 sta spr_bnfall1c_mask_mir
 ldy #176
 lda [$F0],y
 sta spr_bnfallenc_data
 ldy #178
 lda [$F0],y
 sta spr_bnfallenc_mask
 ldy #180
 lda [$F0],y
 sta spr_bnfallenc_data_mir
 ldy #182
 lda [$F0],y
 sta spr_bnfallenc_mask_mir
* BNJIMMY1/2/3 — appended to spr_addr_tbl after BNFALLEN. Offsets
* 184-206. Patched into anim_bnjgrab by init_burnov_combat_compiled
* (alongside the BNBILLY → anim_bngrab patching).
 ldy #184
 lda [$F0],y
 sta spr_bnjimmy1c_data
 ldy #186
 lda [$F0],y
 sta spr_bnjimmy1c_mask
 ldy #188
 lda [$F0],y
 sta spr_bnjimmy1c_data_mir
 ldy #190
 lda [$F0],y
 sta spr_bnjimmy1c_mask_mir
 ldy #192
 lda [$F0],y
 sta spr_bnjimmy2c_data
 ldy #194
 lda [$F0],y
 sta spr_bnjimmy2c_mask
 ldy #196
 lda [$F0],y
 sta spr_bnjimmy2c_data_mir
 ldy #198
 lda [$F0],y
 sta spr_bnjimmy2c_mask_mir
 ldy #200
 lda [$F0],y
 sta spr_bnjimmy3c_data
 ldy #202
 lda [$F0],y
 sta spr_bnjimmy3c_mask
 ldy #204
 lda [$F0],y
 sta spr_bnjimmy3c_data_mir
 ldy #206
 lda [$F0],y
 sta spr_bnjimmy3c_mask_mir
 sec
 xce
 mx %11
 jsr init_armed_compiled
 jsr init_burnov_combat_compiled
 rtl

*----------------------------------------------------------
* init_burnov_combat_compiled - Patch the compiled-form Burnov
* combat anim descriptors (anim_bnpunch, anim_bngrab,
* anim_bnpunched, anim_bnfall) with the bank-$1C BN*_DATA /
* _MASK / _MIRROR addresses populated by init_mission14.
* anim_bnwalk is patched separately by init_burnov_compiled
* (in mission13 / bank $1B).
*----------------------------------------------------------
 mx %11
init_burnov_combat_compiled
 clc
 xce
 rep $30
 mx %00

* anim_bnpunch frame 0 = BNPUNCH1
 lda spr_bnpunch1c_data
 sta anim_bnpunch+6
 lda spr_bnpunch1c_mask
 sta anim_bnpunch+8
 lda spr_bnpunch1c_data_mir
 sta anim_bnpunch+10
 lda spr_bnpunch1c_mask_mir
 sta anim_bnpunch+12
* anim_bnpunch frame 1 = BNPUNCH2
 lda spr_bnpunch2c_data
 sta anim_bnpunch+17
 lda spr_bnpunch2c_mask
 sta anim_bnpunch+19
 lda spr_bnpunch2c_data_mir
 sta anim_bnpunch+21
 lda spr_bnpunch2c_mask_mir
 sta anim_bnpunch+23

* anim_bngrab: BNBILLY1, 2, 1, 2, 1, 2, 3 (7 frames).
* Frame N data offset = 6 + N*11; same +2/+4/+6 for mask/dmir/mmir.
 lda spr_bnbilly1c_data
 sta anim_bngrab+6
 sta anim_bngrab+28      ; frame 2 = BNBILLY1
 sta anim_bngrab+50      ; frame 4 = BNBILLY1
 lda spr_bnbilly1c_mask
 sta anim_bngrab+8
 sta anim_bngrab+30
 sta anim_bngrab+52
 lda spr_bnbilly1c_data_mir
 sta anim_bngrab+10
 sta anim_bngrab+32
 sta anim_bngrab+54
 lda spr_bnbilly1c_mask_mir
 sta anim_bngrab+12
 sta anim_bngrab+34
 sta anim_bngrab+56
 lda spr_bnbilly2c_data
 sta anim_bngrab+17      ; frame 1
 sta anim_bngrab+39      ; frame 3
 sta anim_bngrab+61      ; frame 5
 lda spr_bnbilly2c_mask
 sta anim_bngrab+19
 sta anim_bngrab+41
 sta anim_bngrab+63
 lda spr_bnbilly2c_data_mir
 sta anim_bngrab+21
 sta anim_bngrab+43
 sta anim_bngrab+65
 lda spr_bnbilly2c_mask_mir
 sta anim_bngrab+23
 sta anim_bngrab+45
 sta anim_bngrab+67
 lda spr_bnbilly3c_data
 sta anim_bngrab+72      ; frame 6 = BNBILLY3
 lda spr_bnbilly3c_mask
 sta anim_bngrab+74
 lda spr_bnbilly3c_data_mir
 sta anim_bngrab+76
 lda spr_bnbilly3c_mask_mir
 sta anim_bngrab+78

* anim_bnjgrab: same 7-frame BNJIMMY1/2/1/2/1/2/3 layout as
* anim_bngrab. Offsets in the descriptor are identical because the
* Jimmy frames have the same dims/duration as the Billy ones.
 lda spr_bnjimmy1c_data
 sta anim_bnjgrab+6
 sta anim_bnjgrab+28
 sta anim_bnjgrab+50
 lda spr_bnjimmy1c_mask
 sta anim_bnjgrab+8
 sta anim_bnjgrab+30
 sta anim_bnjgrab+52
 lda spr_bnjimmy1c_data_mir
 sta anim_bnjgrab+10
 sta anim_bnjgrab+32
 sta anim_bnjgrab+54
 lda spr_bnjimmy1c_mask_mir
 sta anim_bnjgrab+12
 sta anim_bnjgrab+34
 sta anim_bnjgrab+56
 lda spr_bnjimmy2c_data
 sta anim_bnjgrab+17
 sta anim_bnjgrab+39
 sta anim_bnjgrab+61
 lda spr_bnjimmy2c_mask
 sta anim_bnjgrab+19
 sta anim_bnjgrab+41
 sta anim_bnjgrab+63
 lda spr_bnjimmy2c_data_mir
 sta anim_bnjgrab+21
 sta anim_bnjgrab+43
 sta anim_bnjgrab+65
 lda spr_bnjimmy2c_mask_mir
 sta anim_bnjgrab+23
 sta anim_bnjgrab+45
 sta anim_bnjgrab+67
 lda spr_bnjimmy3c_data
 sta anim_bnjgrab+72      ; frame 6 = BNJIMMY3
 lda spr_bnjimmy3c_mask
 sta anim_bnjgrab+74
 lda spr_bnjimmy3c_data_mir
 sta anim_bnjgrab+76
 lda spr_bnjimmy3c_mask_mir
 sta anim_bnjgrab+78

* anim_bnpunched: 1 frame BNFALL1 (placeholder reaction).
 lda spr_bnfall1c_data
 sta anim_bnpunched+6
 lda spr_bnfall1c_mask
 sta anim_bnpunched+8
 lda spr_bnfall1c_data_mir
 sta anim_bnpunched+10
 lda spr_bnfall1c_mask_mir
 sta anim_bnpunched+12

* anim_bnfall frame 0 = BNFALL1 (arc), frame 1 = BNFALLEN.
 lda spr_bnfall1c_data
 sta anim_bnfall+6
 lda spr_bnfall1c_mask
 sta anim_bnfall+8
 lda spr_bnfall1c_data_mir
 sta anim_bnfall+10
 lda spr_bnfall1c_mask_mir
 sta anim_bnfall+12
 lda spr_bnfallenc_data
 sta anim_bnfall+17
 lda spr_bnfallenc_mask
 sta anim_bnfall+19
 lda spr_bnfallenc_data_mir
 sta anim_bnfall+21
 lda spr_bnfallenc_mask_mir
 sta anim_bnfall+23

 sec
 xce
 mx %11
 rts

*----------------------------------------------------------
* init_armed_compiled - Patch the compiled-form armed-Linda /
* armed-Williams anim descriptors with the bank-$1C addresses
* populated by init_mission14. Stride layout matches the other
* init_*_compiled patchers.
*----------------------------------------------------------
 mx %11
init_armed_compiled
 clc
 xce
 rep $30
 mx %00

* anim_lfwalk frame 0 = LFWALK1
 lda spr_lfwalk1c_data
 sta anim_lfwalk+6
 lda spr_lfwalk1c_mask
 sta anim_lfwalk+8
 lda spr_lfwalk1c_data_mir
 sta anim_lfwalk+10
 lda spr_lfwalk1c_mask_mir
 sta anim_lfwalk+12
* anim_lfwalk frame 1 = LFWALK2
 lda spr_lfwalk2c_data
 sta anim_lfwalk+17
 lda spr_lfwalk2c_mask
 sta anim_lfwalk+19
 lda spr_lfwalk2c_data_mir
 sta anim_lfwalk+21
 lda spr_lfwalk2c_mask_mir
 sta anim_lfwalk+23
* anim_lfwalk frame 2 = LFWALK3
 lda spr_lfwalk3c_data
 sta anim_lfwalk+28
 lda spr_lfwalk3c_mask
 sta anim_lfwalk+30
 lda spr_lfwalk3c_data_mir
 sta anim_lfwalk+32
 lda spr_lfwalk3c_mask_mir
 sta anim_lfwalk+34
* anim_lfwalk frame 3 = LFWALK2
 lda spr_lfwalk2c_data
 sta anim_lfwalk+39
 lda spr_lfwalk2c_mask
 sta anim_lfwalk+41
 lda spr_lfwalk2c_data_mir
 sta anim_lfwalk+43
 lda spr_lfwalk2c_mask_mir
 sta anim_lfwalk+45

* anim_lmace frame 0 = LMACE1
 lda spr_lmace1c_data
 sta anim_lmace+6
 lda spr_lmace1c_mask
 sta anim_lmace+8
 lda spr_lmace1c_data_mir
 sta anim_lmace+10
 lda spr_lmace1c_mask_mir
 sta anim_lmace+12
* anim_lmace frame 1 = LMACE2
 lda spr_lmace2c_data
 sta anim_lmace+17
 lda spr_lmace2c_mask
 sta anim_lmace+19
 lda spr_lmace2c_data_mir
 sta anim_lmace+21
 lda spr_lmace2c_mask_mir
 sta anim_lmace+23
* anim_lmace frame 2 = LMACE3
 lda spr_lmace3c_data
 sta anim_lmace+28
 lda spr_lmace3c_mask
 sta anim_lmace+30
 lda spr_lmace3c_data_mir
 sta anim_lmace+32
 lda spr_lmace3c_mask_mir
 sta anim_lmace+34

* anim_wpipewalk frame 0 = WPIPEWALK1
 lda spr_wpipewalk1c_data
 sta anim_wpipewalk+6
 lda spr_wpipewalk1c_mask
 sta anim_wpipewalk+8
 lda spr_wpipewalk1c_data_mir
 sta anim_wpipewalk+10
 lda spr_wpipewalk1c_mask_mir
 sta anim_wpipewalk+12
* anim_wpipewalk frame 1 = WPIPEWALK2
 lda spr_wpipewalk2c_data
 sta anim_wpipewalk+17
 lda spr_wpipewalk2c_mask
 sta anim_wpipewalk+19
 lda spr_wpipewalk2c_data_mir
 sta anim_wpipewalk+21
 lda spr_wpipewalk2c_mask_mir
 sta anim_wpipewalk+23
* anim_wpipewalk frame 2 = WPIPEWALK3
 lda spr_wpipewalk3c_data
 sta anim_wpipewalk+28
 lda spr_wpipewalk3c_mask
 sta anim_wpipewalk+30
 lda spr_wpipewalk3c_data_mir
 sta anim_wpipewalk+32
 lda spr_wpipewalk3c_mask_mir
 sta anim_wpipewalk+34
* anim_wpipewalk frame 3 = WPIPEWALK2
 lda spr_wpipewalk2c_data
 sta anim_wpipewalk+39
 lda spr_wpipewalk2c_mask
 sta anim_wpipewalk+41
 lda spr_wpipewalk2c_data_mir
 sta anim_wpipewalk+43
 lda spr_wpipewalk2c_mask_mir
 sta anim_wpipewalk+45

* anim_wpipeswing: WPIPE1, WPIPE4, WPIPE2, WPIPE6, WPIPE3
* (5 frames; offsets +6/+17/+28/+39/+50, etc.)
 lda spr_wpipe1c_data
 sta anim_wpipeswing+6
 lda spr_wpipe1c_mask
 sta anim_wpipeswing+8
 lda spr_wpipe1c_data_mir
 sta anim_wpipeswing+10
 lda spr_wpipe1c_mask_mir
 sta anim_wpipeswing+12
 lda spr_wpipe4c_data
 sta anim_wpipeswing+17
 lda spr_wpipe4c_mask
 sta anim_wpipeswing+19
 lda spr_wpipe4c_data_mir
 sta anim_wpipeswing+21
 lda spr_wpipe4c_mask_mir
 sta anim_wpipeswing+23
 lda spr_wpipe2c_data
 sta anim_wpipeswing+28
 lda spr_wpipe2c_mask
 sta anim_wpipeswing+30
 lda spr_wpipe2c_data_mir
 sta anim_wpipeswing+32
 lda spr_wpipe2c_mask_mir
 sta anim_wpipeswing+34
 lda spr_wpipe6c_data
 sta anim_wpipeswing+39
 lda spr_wpipe6c_mask
 sta anim_wpipeswing+41
 lda spr_wpipe6c_data_mir
 sta anim_wpipeswing+43
 lda spr_wpipe6c_mask_mir
 sta anim_wpipeswing+45
 lda spr_wpipe3c_data
 sta anim_wpipeswing+50
 lda spr_wpipe3c_mask
 sta anim_wpipeswing+52
 lda spr_wpipe3c_data_mir
 sta anim_wpipeswing+54
 lda spr_wpipe3c_mask_mir
 sta anim_wpipeswing+56

* anim_wkthrow: WKNIFE1, WKNIFE2 (2 frames)
 lda spr_wknife1c_data
 sta anim_wkthrow+6
 lda spr_wknife1c_mask
 sta anim_wkthrow+8
 lda spr_wknife1c_data_mir
 sta anim_wkthrow+10
 lda spr_wknife1c_mask_mir
 sta anim_wkthrow+12
 lda spr_wknife2c_data
 sta anim_wkthrow+17
 lda spr_wknife2c_mask
 sta anim_wkthrow+19
 lda spr_wknife2c_data_mir
 sta anim_wkthrow+21
 lda spr_wknife2c_mask_mir
 sta anim_wkthrow+23

 sec
 xce
 mx %11
 rts

*----------------------------------------------------------
* init_jimmy - Patch the bank-$00 Jimmy cache vars + info-block
* fields + anim_walk_j descriptor from the sprite-address table
* in mission1jimmy.s at $1D:$0000.
*
* The header at $1D:$0000 is a 2-byte spr_addr_off. The table
* it points at is 12 sequential `dw <label>` entries (4 per
* compiled sprite: DATA / MASK / DATA_MIRROR / MASK_MIRROR).
*----------------------------------------------------------
 mx %11
_init_jimmy
 clc
 xce                   ; native mode
 rep $30
 mx %00

* Read spr_addr_off (the header word at $1D:$0000).
 lda #$0000
 sta $F0
 sep $20
 lda #$1D
 sta $F2
 rep $20
 ldy #0
 lda [$F0],y
 sta $F0               ; $F0/F1 now points at spr_addr_tbl ($1D:nnnn)

* Walk the 12-entry table and write each 2-byte address into
* its corresponding cache var. Order matches mission1jimmy.s.
 ldy #0
 lda [$F0],y
 sta spr_jimmy01
 ldy #2
 lda [$F0],y
 sta spr_jimmy01_mask
 ldy #4
 lda [$F0],y
 sta spr_jimmy01_data_mir
 ldy #6
 lda [$F0],y
 sta spr_jimmy01_mask_mir
 ldy #8
 lda [$F0],y
 sta spr_jimmy02
 ldy #10
 lda [$F0],y
 sta spr_jimmy02_mask
 ldy #12
 lda [$F0],y
 sta spr_jimmy02_data_mir
 ldy #14
 lda [$F0],y
 sta spr_jimmy02_mask_mir
 ldy #16
 lda [$F0],y
 sta spr_jimmy03
 ldy #18
 lda [$F0],y
 sta spr_jimmy03_mask
 ldy #20
 lda [$F0],y
 sta spr_jimmy03_data_mir
 ldy #22
 lda [$F0],y
 sta spr_jimmy03_mask_mir

* Patch jimmy_sprite info block: frame_addr (+14) and
* idle_addr (+42) from spr_jimmy01; active_mask_addr (+60)
* and idle_mask_addr (+62) from spr_jimmy01_mask.
 lda spr_jimmy01
 sta jimmy_sprite+14
 sta jimmy_sprite+42
 lda spr_jimmy01_mask
 sta jimmy_sprite+60
 sta jimmy_sprite+62

* Patch anim_walk_j: 11-byte stride per frame, 4 frames in
* order JIMMY01, JIMMY02, JIMMY03, JIMMY02. Frame slot offsets
* relative to descriptor start:
*   header is 3 bytes; frame 0 starts at +3 with x/y/dur (3B)
*   then DATA / MASK / DATA_MIRROR / MASK_MIRROR (8B), total 11.
*
*   Frame 0 DATA at +6, MASK at +8, DATA_MIRROR +10, MASK_MIRROR +12
*   Frame 1 DATA at +17, MASK at +19, DATA_MIRROR +21, MASK_MIRROR +23
*   Frame 2 DATA at +28, MASK at +30, DATA_MIRROR +32, MASK_MIRROR +34
*   Frame 3 DATA at +39, MASK at +41, DATA_MIRROR +43, MASK_MIRROR +45
 lda spr_jimmy01
 sta anim_walk_j+6
 lda spr_jimmy01_mask
 sta anim_walk_j+8
 lda spr_jimmy01_data_mir
 sta anim_walk_j+10
 lda spr_jimmy01_mask_mir
 sta anim_walk_j+12
 lda spr_jimmy02
 sta anim_walk_j+17
 lda spr_jimmy02_mask
 sta anim_walk_j+19
 lda spr_jimmy02_data_mir
 sta anim_walk_j+21
 lda spr_jimmy02_mask_mir
 sta anim_walk_j+23
 lda spr_jimmy03
 sta anim_walk_j+28
 lda spr_jimmy03_mask
 sta anim_walk_j+30
 lda spr_jimmy03_data_mir
 sta anim_walk_j+32
 lda spr_jimmy03_mask_mir
 sta anim_walk_j+34
 lda spr_jimmy02
 sta anim_walk_j+39
 lda spr_jimmy02_mask
 sta anim_walk_j+41
 lda spr_jimmy02_data_mir
 sta anim_walk_j+43
 lda spr_jimmy02_mask_mir
 sta anim_walk_j+45

* Populate jimmy_walk_addr_tbl / _mask_tbl (+ mirrored pair) for
* advance_jimmy_walk. Step cycle: 0→JIMMY01, 1→JIMMY02,
* 2→JIMMY03, 3→JIMMY02. Same step→sprite mapping Billy uses in
* walk_addr_tbl.
 lda spr_jimmy01
 sta jimmy_walk_addr_tbl
 lda spr_jimmy01_mask
 sta jimmy_walk_mask_tbl
 lda spr_jimmy01_data_mir
 sta jimmy_walk_addr_tbl_mirror
 lda spr_jimmy01_mask_mir
 sta jimmy_walk_mask_tbl_mirror
 lda spr_jimmy02
 sta jimmy_walk_addr_tbl+2
 lda spr_jimmy02_mask
 sta jimmy_walk_mask_tbl+2
 lda spr_jimmy02_data_mir
 sta jimmy_walk_addr_tbl_mirror+2
 lda spr_jimmy02_mask_mir
 sta jimmy_walk_mask_tbl_mirror+2
 lda spr_jimmy03
 sta jimmy_walk_addr_tbl+4
 lda spr_jimmy03_mask
 sta jimmy_walk_mask_tbl+4
 lda spr_jimmy03_data_mir
 sta jimmy_walk_addr_tbl_mirror+4
 lda spr_jimmy03_mask_mir
 sta jimmy_walk_mask_tbl_mirror+4
 lda spr_jimmy02
 sta jimmy_walk_addr_tbl+6
 lda spr_jimmy02_mask
 sta jimmy_walk_mask_tbl+6
 lda spr_jimmy02_data_mir
 sta jimmy_walk_addr_tbl_mirror+6
 lda spr_jimmy02_mask_mir
 sta jimmy_walk_mask_tbl_mirror+6

* Continue reading the bank-$1D sprite-address table past the
* walk entries. Layout: 24 bytes walk, then 24 bytes jjump
* (3 compiled sprites x 4 entries x 2 bytes), then 16 bytes
* jkick, 32 bytes jpunch, 6 bytes legacy spin, 6 bytes legacy
* upper, 8 bytes jpunched (compiled), 2 bytes jfall, 2 bytes
* jfallen. Y-offsets below assume that order.
*
* JJUMP1 entries at +24
 ldy #24
 lda [$F0],y
 sta spr_jjump1
 ldy #26
 lda [$F0],y
 sta spr_jjump1_mask
 ldy #28
 lda [$F0],y
 sta spr_jjump1_data_mir
 ldy #30
 lda [$F0],y
 sta spr_jjump1_mask_mir
 ldy #32
 lda [$F0],y
 sta spr_jjump2
 ldy #34
 lda [$F0],y
 sta spr_jjump2_mask
 ldy #36
 lda [$F0],y
 sta spr_jjump2_data_mir
 ldy #38
 lda [$F0],y
 sta spr_jjump2_mask_mir
 ldy #40
 lda [$F0],y
 sta spr_jjump3
 ldy #42
 lda [$F0],y
 sta spr_jjump3_mask
 ldy #44
 lda [$F0],y
 sta spr_jjump3_data_mir
 ldy #46
 lda [$F0],y
 sta spr_jjump3_mask_mir
* JKICK1/2 entries at +48
 ldy #48
 lda [$F0],y
 sta spr_jkick1
 ldy #50
 lda [$F0],y
 sta spr_jkick1_mask
 ldy #52
 lda [$F0],y
 sta spr_jkick1_data_mir
 ldy #54
 lda [$F0],y
 sta spr_jkick1_mask_mir
 ldy #56
 lda [$F0],y
 sta spr_jkick2
 ldy #58
 lda [$F0],y
 sta spr_jkick2_mask
 ldy #60
 lda [$F0],y
 sta spr_jkick2_data_mir
 ldy #62
 lda [$F0],y
 sta spr_jkick2_mask_mir
* JPUNCH11/12/21/22 entries at +64
 ldy #64
 lda [$F0],y
 sta spr_jpunch11
 ldy #66
 lda [$F0],y
 sta spr_jpunch11_mask
 ldy #68
 lda [$F0],y
 sta spr_jpunch11_data_mir
 ldy #70
 lda [$F0],y
 sta spr_jpunch11_mask_mir
 ldy #72
 lda [$F0],y
 sta spr_jpunch12
 ldy #74
 lda [$F0],y
 sta spr_jpunch12_mask
 ldy #76
 lda [$F0],y
 sta spr_jpunch12_data_mir
 ldy #78
 lda [$F0],y
 sta spr_jpunch12_mask_mir
 ldy #80
 lda [$F0],y
 sta spr_jpunch21
 ldy #82
 lda [$F0],y
 sta spr_jpunch21_mask
 ldy #84
 lda [$F0],y
 sta spr_jpunch21_data_mir
 ldy #86
 lda [$F0],y
 sta spr_jpunch21_mask_mir
 ldy #88
 lda [$F0],y
 sta spr_jpunch22
 ldy #90
 lda [$F0],y
 sta spr_jpunch22_mask
 ldy #92
 lda [$F0],y
 sta spr_jpunch22_data_mir
 ldy #94
 lda [$F0],y
 sta spr_jpunch22_mask_mir
* Legacy: JSPIN1/2/3 at +96, JUPPER1/2/3 at +102.
 ldy #96
 lda [$F0],y
 sta spr_jspin1
 ldy #98
 lda [$F0],y
 sta spr_jspin2
 ldy #100
 lda [$F0],y
 sta spr_jspin3
 ldy #102
 lda [$F0],y
 sta spr_jupper1
 ldy #104
 lda [$F0],y
 sta spr_jupper2
 ldy #106
 lda [$F0],y
 sta spr_jupper3
* JPUNCHED at +108 (compiled), JFALL at +116, JFALLEN at +118.
 ldy #108
 lda [$F0],y
 sta spr_jpunched
 ldy #110
 lda [$F0],y
 sta spr_jpunched_mask
 ldy #112
 lda [$F0],y
 sta spr_jpunched_data_mir
 ldy #114
 lda [$F0],y
 sta spr_jpunched_mask_mir
 ldy #116
 lda [$F0],y
 sta spr_jfall
 ldy #118
 lda [$F0],y
 sta spr_jfallen
* JCLIMB1/2 at +120 (4 entries each, compiled stride).
 ldy #120
 lda [$F0],y
 sta spr_jclimb1
 ldy #122
 lda [$F0],y
 sta spr_jclimb1_mask
 ldy #124
 lda [$F0],y
 sta spr_jclimb1_data_mir
 ldy #126
 lda [$F0],y
 sta spr_jclimb1_mask_mir
 ldy #128
 lda [$F0],y
 sta spr_jclimb2
 ldy #130
 lda [$F0],y
 sta spr_jclimb2_mask
 ldy #132
 lda [$F0],y
 sta spr_jclimb2_data_mir
 ldy #134
 lda [$F0],y
 sta spr_jclimb2_mask_mir

* Jimmy armed sprite caches (legacy stride, one address per
* frame). Indices 136..174 in spr_addr_tbl. Order must match
* mission1jimmy.s additions: JMWALK1-3, JMACE1-4, JKWALK1-3,
* JKNIFE1-3, JPIPEW1-3, JPIPE1-4.
 ldy #136
 lda [$F0],y
 sta spr_jmwalk1
 ldy #138
 lda [$F0],y
 sta spr_jmwalk2
 ldy #140
 lda [$F0],y
 sta spr_jmwalk3
 ldy #142
 lda [$F0],y
 sta spr_jmace1
 ldy #144
 lda [$F0],y
 sta spr_jmace2
 ldy #146
 lda [$F0],y
 sta spr_jmace3
 ldy #148
 lda [$F0],y
 sta spr_jmace4
 ldy #150
 lda [$F0],y
 sta spr_jkwalk1
 ldy #152
 lda [$F0],y
 sta spr_jkwalk2
 ldy #154
 lda [$F0],y
 sta spr_jkwalk3
 ldy #156
 lda [$F0],y
 sta spr_jknife1
 ldy #158
 lda [$F0],y
 sta spr_jknife2
 ldy #160
 lda [$F0],y
 sta spr_jknife3
 ldy #162
 lda [$F0],y
 sta spr_jpipew1
 ldy #164
 lda [$F0],y
 sta spr_jpipew2
 ldy #166
 lda [$F0],y
 sta spr_jpipew3
 ldy #168
 lda [$F0],y
 sta spr_jpipe1
 ldy #170
 lda [$F0],y
 sta spr_jpipe2
 ldy #172
 lda [$F0],y
 sta spr_jpipe3
 ldy #174
 lda [$F0],y
 sta spr_jpipe4
 ldy #176
 lda [$F0],y
 sta spr_jgrab1
 ldy #178
 lda [$F0],y
 sta spr_jgrab2

* Populate Jimmy's armed walk tables — parallel to the Billy
* tables that init_billy fills. advance_walk dispatches on the
* active player's controller (info+22) and reads the matching
* set. Layout per Billy: 4 entries × 2 bytes per direction step.
* For pipe/mace: 9×40 frames at indices 0/2/4/6 of the table
* (frames 1,2,3,2 in walk_step order). For knife: same shape
* using the BKWALK / JKWALK frames; jimmy_knife_walk_x_tbl
* mirrors knife_walk_x_tbl (BKWALK1/3=11, BKWALK2=9).
 lda spr_jpipew1
 sta jimmy_pipe_walk_addr_tbl
 lda spr_jpipew2
 sta jimmy_pipe_walk_addr_tbl+2
 lda spr_jpipew3
 sta jimmy_pipe_walk_addr_tbl+4
 lda spr_jpipew2
 sta jimmy_pipe_walk_addr_tbl+6
 lda spr_jmwalk1
 sta jimmy_mace_walk_addr_tbl
 lda spr_jmwalk2
 sta jimmy_mace_walk_addr_tbl+2
 lda spr_jmwalk3
 sta jimmy_mace_walk_addr_tbl+4
 lda spr_jmwalk2
 sta jimmy_mace_walk_addr_tbl+6
 lda spr_jkwalk1
 sta jimmy_knife_walk_addr_tbl
 lda spr_jkwalk2
 sta jimmy_knife_walk_addr_tbl+2
 lda spr_jkwalk3
 sta jimmy_knife_walk_addr_tbl+4
 lda spr_jkwalk2
 sta jimmy_knife_walk_addr_tbl+6
* Per-frame X for the knife walk (frames 1/3 are 11 bytes,
* frame 2 is 9). Stride 1 byte/frame.
 sep $20
 mx %11
 lda #$0B
 sta jimmy_knife_walk_x_tbl
 lda #$09
 sta jimmy_knife_walk_x_tbl+1
 lda #$0B
 sta jimmy_knife_walk_x_tbl+2
 lda #$09
 sta jimmy_knife_walk_x_tbl+3
 rep $20
 mx %00

* Patch anim_jpickup: 1 compiled frame (JJUMP3 hold, 11-byte
* stride). Mirrors engine.s init_billy's anim_bpickup patch but
* targets Jimmy's bank-$1D JJUMP3 caches.
 lda spr_jjump3
 sta anim_jpickup+6
 lda spr_jjump3_mask
 sta anim_jpickup+8
 lda spr_jjump3_data_mir
 sta anim_jpickup+10
 lda spr_jjump3_mask_mir
 sta anim_jpickup+12

* Patch Jimmy's action anims. Each compiled-stride frame slot
* is 11 bytes: x/y/dur (3) + DATA / MASK / DATA_MIR / MASK_MIR
* (8). Header is 3 bytes (num_frames / max_width / flags), so
* frame 0 starts at +3 (with DATA at +6), frame 1 at +14 (DATA
* at +17), frame 2 at +25 (DATA at +28), frame 3 at +36 (DATA
* at +39). Legacy stride is 5 bytes: x/y/dur (3) + DATA (2);
* frame 0 DATA at +6, frame 1 at +11, frame 2 at +16, etc.

* anim_jjump (compiled, 3 frames: JJUMP1/2/3)
 lda spr_jjump1
 sta anim_jjump+6
 lda spr_jjump1_mask
 sta anim_jjump+8
 lda spr_jjump1_data_mir
 sta anim_jjump+10
 lda spr_jjump1_mask_mir
 sta anim_jjump+12
 lda spr_jjump2
 sta anim_jjump+17
 lda spr_jjump2_mask
 sta anim_jjump+19
 lda spr_jjump2_data_mir
 sta anim_jjump+21
 lda spr_jjump2_mask_mir
 sta anim_jjump+23
 lda spr_jjump3
 sta anim_jjump+28
 lda spr_jjump3_mask
 sta anim_jjump+30
 lda spr_jjump3_data_mir
 sta anim_jjump+32
 lda spr_jjump3_mask_mir
 sta anim_jjump+34

* anim_jkick (compiled, 2 frames: JKICK1/2)
 lda spr_jkick1
 sta anim_jkick+6
 lda spr_jkick1_mask
 sta anim_jkick+8
 lda spr_jkick1_data_mir
 sta anim_jkick+10
 lda spr_jkick1_mask_mir
 sta anim_jkick+12
 lda spr_jkick2
 sta anim_jkick+17
 lda spr_jkick2_mask
 sta anim_jkick+19
 lda spr_jkick2_data_mir
 sta anim_jkick+21
 lda spr_jkick2_mask_mir
 sta anim_jkick+23

* anim_jpunch1 (compiled, 2 frames: JPUNCH11/12)
 lda spr_jpunch11
 sta anim_jpunch1+6
 lda spr_jpunch11_mask
 sta anim_jpunch1+8
 lda spr_jpunch11_data_mir
 sta anim_jpunch1+10
 lda spr_jpunch11_mask_mir
 sta anim_jpunch1+12
 lda spr_jpunch12
 sta anim_jpunch1+17
 lda spr_jpunch12_mask
 sta anim_jpunch1+19
 lda spr_jpunch12_data_mir
 sta anim_jpunch1+21
 lda spr_jpunch12_mask_mir
 sta anim_jpunch1+23

* anim_jpunch2 (compiled, 2 frames: JPUNCH21/22)
 lda spr_jpunch21
 sta anim_jpunch2+6
 lda spr_jpunch21_mask
 sta anim_jpunch2+8
 lda spr_jpunch21_data_mir
 sta anim_jpunch2+10
 lda spr_jpunch21_mask_mir
 sta anim_jpunch2+12
 lda spr_jpunch22
 sta anim_jpunch2+17
 lda spr_jpunch22_mask
 sta anim_jpunch2+19
 lda spr_jpunch22_data_mir
 sta anim_jpunch2+21
 lda spr_jpunch22_mask_mir
 sta anim_jpunch2+23

* anim_jbspinkick (legacy, 8 frames). Layout: 3-byte header +
* 5-byte frames (x/y/dur + DATA at +3). Frame N DATA = anim+6+5*N.
 lda spr_jspin1
 sta anim_jbspinkick+6
 lda spr_jspin2
 sta anim_jbspinkick+11
 lda spr_jspin3
 sta anim_jbspinkick+16
 lda spr_jspin2
 sta anim_jbspinkick+21
 lda spr_jspin1
 sta anim_jbspinkick+26
 lda spr_jspin2
 sta anim_jbspinkick+31
 lda spr_jspin3
 sta anim_jbspinkick+36
 lda spr_jspin2
 sta anim_jbspinkick+41

* anim_juppercut (legacy, 3 frames: JUPPER1/2/3)
 lda spr_jupper1
 sta anim_juppercut+6
 lda spr_jupper2
 sta anim_juppercut+11
 lda spr_jupper3
 sta anim_juppercut+16

* anim_jpunched (compiled, 1 frame: JPUNCHED)
 lda spr_jpunched
 sta anim_jpunched+6
 lda spr_jpunched_mask
 sta anim_jpunched+8
 lda spr_jpunched_data_mir
 sta anim_jpunched+10
 lda spr_jpunched_mask_mir
 sta anim_jpunched+12

* anim_jfall (legacy, 2 frames: JFALL + JFALLEN)
 lda spr_jfall
 sta anim_jfall+6
 lda spr_jfallen
 sta anim_jfall+11

* anim_jpipeswing (legacy, 4 frames: JPIPE1-4). 5-byte stride.
* Frame 0 DATA at +6, frame 1 at +11, frame 2 at +16, frame 3 at +21.
 lda spr_jpipe1
 sta anim_jpipeswing+6
 lda spr_jpipe2
 sta anim_jpipeswing+11
 lda spr_jpipe3
 sta anim_jpipeswing+16
 lda spr_jpipe4
 sta anim_jpipeswing+21

* anim_jmaceswing (legacy, 4 frames: JMACE1-4). 5-byte stride.
 lda spr_jmace1
 sta anim_jmaceswing+6
 lda spr_jmace2
 sta anim_jmaceswing+11
 lda spr_jmace3
 sta anim_jmaceswing+16
 lda spr_jmace4
 sta anim_jmaceswing+21

 sec
 xce
 mx %11
 rtl

*----------------------------------------------------------
* _init_mission12blit - Migrated from game.s to free bank-$00
* space. Builds compiled_dispatch_tbl entries for the legacy
* mission12 sprites compiled to immediate-mode blits in banks
* $34-$38. Same logic as the in-game.s version was; only
* difference is RTL at the end and a leading underscore on
* the global label so it matches the JML jump-table target.
*
* Frame addresses come from mission12.s's spr_addr_tbl (bank
* $19, starting at $19/$0016). spr_flail at offset +0 is
* skipped; spr_lmace1 (first migrated sprite) is at +2.
*
* Each sprite contributes 2 dispatch entries: (data, orient=0)
* and (mirror, orient=1). Sharing the FRAME_ADDR as the key
* between the two relies on try_immediate_dispatch's orient
* byte check at entry+5.
*
* Native + MX %00 on entry/exit. Caller wraps with JSL.
*----------------------------------------------------------
_init_mission12blit
 phb                   ; save caller's DBR
 clc
 xce
 rep $30
 mx %00
* Don't `phk / plb` here — engine.s lives in bank $1F, so that
* would set DBR=$1F and route every `sta compiled_dispatch_tbl,x`
* below to bank-$1F engine code instead of bank-$00 dispatch
* memory. Caller (game.s) has DBR=$00, which is what we want.

 lda #$0018
 sta :im12_m12_off

 lda #$34
 jsr :im12_process_file
 lda #$35
 jsr :im12_process_file
 lda #$36
 jsr :im12_process_file
 lda #$37
 jsr :im12_process_file
 lda #$38
 jsr :im12_process_file

 sec
 xce
 plb
 mx %11
 rtl

:im12_process_file
 mx %00
 sta :im12_bank

 stz $F0
 sep $20
 lda :im12_bank
 sta $F2
 rep $20

 ldy #0
 lda [$F0],y
 sta :im12_tbl_off
 ldy #2
 lda [$F0],y
 sta :im12_remain

 lda :im12_tbl_off
 sta $F0

 ldy #0
:im12_loop
 mx %00
 lda :im12_remain
 bne :im12_in_range
 jmp :im12_file_done
:im12_in_range

 lda [$F0],y
 sta :im12_blit_data_addr
 iny
 iny
 sep $20
 lda [$F0],y
 sta :im12_blit_data_bank
 rep $20
 iny

 lda [$F0],y
 sta :im12_blit_mir_addr
 iny
 iny
 sep $20
 lda [$F0],y
 sta :im12_blit_mir_bank
 rep $20
 iny

 phy

 stz $F0
 sep $20
 lda #$19
 sta $F2
 rep $20
 ldy :im12_m12_off
 lda [$F0],y
 sta :im12_frame_addr

* Entry 1: key = FRAME_ADDR, orient = 0, blit = data.
 ldx compiled_dispatch_count
 lda :im12_frame_addr
 sta compiled_dispatch_tbl,x
 lda :im12_blit_data_addr
 sta compiled_dispatch_tbl+2,x
 sep $20
 lda :im12_blit_data_bank
 sta compiled_dispatch_tbl+4,x
 stz compiled_dispatch_tbl+5,x
 rep $20
 txa
 clc
 adc #6
 tax
* Entry 2: key = FRAME_ADDR, orient = 1, blit = mir.
 lda :im12_frame_addr
 sta compiled_dispatch_tbl,x
 lda :im12_blit_mir_addr
 sta compiled_dispatch_tbl+2,x
 sep $20
 lda :im12_blit_mir_bank
 sta compiled_dispatch_tbl+4,x
 lda #$01
 sta compiled_dispatch_tbl+5,x
 rep $20
 txa
 clc
 adc #6
 sta compiled_dispatch_count

 lda :im12_m12_off
 clc
 adc #2
 sta :im12_m12_off

 stz $F0
 sep $20
 lda :im12_bank
 sta $F2
 rep $20
 lda :im12_tbl_off
 sta $F0

 ply

 lda :im12_remain
 dec
 sta :im12_remain
 jmp :im12_loop

:im12_file_done
 rts

* Scratch locals moved to bank-$00 RAM hole — see imb_* comment.
:im12_bank             equ $001C30
:im12_remain           equ $001C32
:im12_tbl_off          equ $001C34
:im12_m12_off          equ $001C36
:im12_blit_data_addr   equ $001C38
:im12_blit_data_bank   equ $001C3A
:im12_blit_mir_addr    equ $001C3C
:im12_blit_mir_bank    equ $001C3E
:im12_frame_addr       equ $001C40

*----------------------------------------------------------
* _init_mission14blit - Same shape as init_mission13blit but
* walks mission14blit_39 / mission14blit_3a (banks $39 and $3A)
* and reads frame addrs from the mission14 cache var base
* (spr_lfwalk1c_data + 25 consecutive 8-byte slots, matching
* mission14.s declaration order: LFWALK1/2/3, LMACE1/2/3,
* WPIPEWALK1/2/3, WPIPE1-4/6, WKNIFE1/2, BNPUNCH1/2,
* BNBILLY1/2/3, BNFALL1, BNFALLEN, BNJIMMY1/2/3).
*
* Each migrated frame contributes two dispatch entries (data +
* mirror, 6 bytes each). Compiled FRAME_ADDRs for data vs mirror
* are already distinct (different bank-$1C labels), so both
* entries use orient = 0.
*
* Native + MX %00 on entry/exit.
*----------------------------------------------------------
_init_mission14blit
 phb                   ; save caller's DBR
 clc
 xce
 rep $30
 mx %00
* No phk/plb — see _init_mission12blit comment.

 ldx #$0000                   ; first sprite index = 0
 lda #$39
 jsr :im14_process_file

 lda #$3A
 jsr :im14_process_file

 sec
 xce
 plb
 mx %11
 rtl

:im14_process_file
 mx %00
 sta :im14_bank

 stz $F0
 sep $20
 lda :im14_bank
 sta $F2
 rep $20

 ldy #0
 lda [$F0],y
 sta :im14_tbl_off
 ldy #2
 lda [$F0],y
 sta :im14_remain

 lda :im14_tbl_off
 sta $F0

 ldy #0
:im14_loop
 mx %00
 lda [$F0],y
 sta :im14_blit_data_addr
 iny
 iny
 sep $20
 lda [$F0],y
 sta :im14_blit_data_bank
 rep $20
 iny

 lda [$F0],y
 sta :im14_blit_mir_addr
 iny
 iny
 sep $20
 lda [$F0],y
 sta :im14_blit_mir_bank
 rep $20
 iny

 phy

* Cache-var base for mission14 is spr_lfwalk1c_data; each
* sprite slot is 8 bytes. sprite_idx * 8 -> A.
 txa
 asl
 asl
 asl
 tay
 lda spr_lfwalk1c_data,y
 sta :im14_frame_data_addr
 lda spr_lfwalk1c_data_mir,y
 sta :im14_frame_mir_addr

 phx
 ldx compiled_dispatch_count
 lda :im14_frame_data_addr
 sta compiled_dispatch_tbl,x
 lda :im14_blit_data_addr
 sta compiled_dispatch_tbl+2,x
 sep $20
 lda :im14_blit_data_bank
 sta compiled_dispatch_tbl+4,x
 stz compiled_dispatch_tbl+5,x
 rep $20
 lda :im14_frame_mir_addr
 sta compiled_dispatch_tbl+6,x
 lda :im14_blit_mir_addr
 sta compiled_dispatch_tbl+8,x
 sep $20
 lda :im14_blit_mir_bank
 sta compiled_dispatch_tbl+10,x
 stz compiled_dispatch_tbl+11,x
 rep $20
 txa
 clc
 adc #12
 sta compiled_dispatch_count
 plx
 inx

 ply

 lda :im14_remain
 dec
 sta :im14_remain
 bne :im14_loop

 rts

* Scratch locals moved to bank-$00 RAM hole — see imb_* comment.
:im14_bank             equ $001C42
:im14_remain           equ $001C44
:im14_tbl_off          equ $001C46
:im14_blit_data_addr   equ $001C48
:im14_blit_data_bank   equ $001C4A
:im14_blit_mir_addr    equ $001C4C
:im14_blit_mir_bank    equ $001C4E
:im14_frame_data_addr  equ $001C50
:im14_frame_mir_addr   equ $001C52

*----------------------------------------------------------
* _init_mission13blit - Migrated from game.s. Builds the first
* batch of compiled_dispatch_tbl entries from mission13blit_30
* + mission13blit_31 headers and mission13's DATA cache vars
* (spr_william1c_data + 31 consecutive 8-byte slots, populated
* earlier by _init_mission13). 32 sprites × 2 entries = 64.
*
* Each frame contributes 2 dispatch entries (data + mirror,
* 6 bytes each). Compiled sprites have distinct DATA vs
* DATA_MIRROR addresses, so both entries get orient = 0 and
* are disambiguated by their keys alone.
*
* This is the FIRST init to run, so it zeros compiled_dispatch_count.
* The other init_*blit routines append.
*
* Native + MX %00 on entry/exit. Caller wraps with JSL.
*----------------------------------------------------------
_init_mission13blit
 phb                   ; save caller's DBR
 clc
 xce
 rep $30
 mx %00
* No phk/plb — see _init_mission12blit comment.

 stz compiled_dispatch_count

 ldx #$0000
 lda #$30
 jsr :imb_process_file

 lda #$31
 jsr :imb_process_file

 sec
 xce
 plb
 mx %11
 rtl

:imb_process_file
 mx %00
 sta :imb_bank

 stz $F0
 sep $20
 lda :imb_bank
 sta $F2
 rep $20

 ldy #0
 lda [$F0],y
 sta :imb_tbl_off
 ldy #2
 lda [$F0],y
 sta :imb_remain

 lda :imb_tbl_off
 sta $F0

 ldy #0

:imb_loop
 lda [$F0],y
 sta :imb_blit_data_addr
 iny
 iny
 sep $20
 lda [$F0],y
 sta :imb_blit_data_bank
 rep $20
 iny

 lda [$F0],y
 sta :imb_blit_mir_addr
 iny
 iny
 sep $20
 lda [$F0],y
 sta :imb_blit_mir_bank
 rep $20
 iny

 phy

 txa
 asl
 asl
 asl
 tay
 lda spr_william1c_data,y
 sta :imb_frame_data_addr
 lda spr_william1c_data_mir,y
 sta :imb_frame_mir_addr

 phx
 ldx compiled_dispatch_count
 lda :imb_frame_data_addr
 sta compiled_dispatch_tbl,x
 lda :imb_blit_data_addr
 sta compiled_dispatch_tbl+2,x
 sep $20
 lda :imb_blit_data_bank
 sta compiled_dispatch_tbl+4,x
 stz compiled_dispatch_tbl+5,x
 rep $20
 lda :imb_frame_mir_addr
 sta compiled_dispatch_tbl+6,x
 lda :imb_blit_mir_addr
 sta compiled_dispatch_tbl+8,x
 sep $20
 lda :imb_blit_mir_bank
 sta compiled_dispatch_tbl+10,x
 stz compiled_dispatch_tbl+11,x
 rep $20
 txa
 clc
 adc #12
 sta compiled_dispatch_count
 plx
 inx

 ply

 lda :imb_remain
 dec
 sta :imb_remain
 bne :imb_loop

 rts

* Scratch locals MOVED from bank $1F (engine.s) to bank-$00 RAM
* hole at $1C02+. Original engine.s addresses collided with
* game.s code at the same offsets when DBR=$00 (which we set
* via "no phk/plb" to keep `sta compiled_dispatch_tbl,x` writing
* to bank $00). Symptom: $00/37D3-$37DE got 12 bytes overwritten
* per init_mission1jimmyblit call, clobbering check_x_bounds_world.
:imb_bank             equ $001C02
:imb_remain           equ $001C04
:imb_tbl_off          equ $001C06
:imb_blit_data_addr   equ $001C08
:imb_blit_data_bank   equ $001C0A
:imb_blit_mir_addr    equ $001C0C
:imb_blit_mir_bank    equ $001C0E
:imb_frame_data_addr  equ $001C10
:imb_frame_mir_addr   equ $001C12

*----------------------------------------------------------
* _init_mission1blit - Migrated from game.s. Walks
* mission1blit_32 in lockstep with the :im1b_offsets table
* below (which maps each Billy sprite to its DATA / DATA_MIRROR
* offsets in mission1's bank-$02 spr_addr_tbl). Mission1's
* layout is "scattered" — no clean 8-byte stride — so the
* offsets are hardcoded per sprite. Order must match the
* names list in tools/generate_mission1blit.py.
*
* Native + MX %00 on entry/exit. Caller wraps with JSL.
*----------------------------------------------------------
_init_mission1blit
 phb                   ; save caller's DBR
 clc
 xce
 rep $30
 mx %00
* No phk/plb — see _init_mission12blit comment.

 stz $F0
 sep $20
 lda #$32
 sta $F2
 rep $20
 ldy #0
 lda [$F0],y
 sta $F0

 ldy #0
 ldx #0
:im1b_loop
 mx %00
 cpx #:im1b_offsets_end-:im1b_offsets
 bcc :im1b_in_range
 jmp :im1b_done
:im1b_in_range

 lda [$F0],y
 sta :im1b_blit_data_addr
 iny
 iny
 sep $20
 lda [$F0],y
 sta :im1b_blit_data_bank
 rep $20
 iny

 lda [$F0],y
 sta :im1b_blit_mir_addr
 iny
 iny
 sep $20
 lda [$F0],y
 sta :im1b_blit_mir_bank
 rep $20
 iny

 phy
 phx

 stz $F0
 sep $20
 lda #$02
 sta $F2
 rep $20

* LDAL (long absolute) is required here: :im1b_offsets lives in bank $1F
* (engine.s) but DBR=$00 at init time (per [[engine_dbr_trap]] memory we
* don't phk;plb in engine.s). `lda :im1b_offsets,x` assembles as `lda abs,X`
* which reads $00/<offset>+X — that's game.s code bytes, not the offsets
* table. Symptom: dispatch table gets garbage frame_addr values; sprites
* miss immediate-mode dispatch and fall back to AND/ORA (which renders
* correctly via FRAME_X, so the bug was invisible for Billy). Jimmy had
* a 4-pixel residue on direction-change because one happenstance match
* routed a 9-wide frame to a wider blit blob. Same fix for :im1j_offsets
* below.
 sep $20
 ldal :im1b_offsets,x
 sta :im1b_tmp_off
 stz :im1b_tmp_off+1
 rep $20
 lda :im1b_tmp_off
 tay
 lda [$F0],y
 sta :im1b_frame_data_addr

 sep $20
 ldal :im1b_offsets+1,x
 sta :im1b_tmp_off
 stz :im1b_tmp_off+1
 rep $20
 lda :im1b_tmp_off
 tay
 lda [$F0],y
 sta :im1b_frame_mir_addr

 ldx compiled_dispatch_count
 lda :im1b_frame_data_addr
 sta compiled_dispatch_tbl,x
 lda :im1b_blit_data_addr
 sta compiled_dispatch_tbl+2,x
 sep $20
 lda :im1b_blit_data_bank
 sta compiled_dispatch_tbl+4,x
 stz compiled_dispatch_tbl+5,x
 rep $20
 lda :im1b_frame_mir_addr
 sta compiled_dispatch_tbl+6,x
 lda :im1b_blit_mir_addr
 sta compiled_dispatch_tbl+8,x
 sep $20
 lda :im1b_blit_mir_bank
 sta compiled_dispatch_tbl+10,x
 stz compiled_dispatch_tbl+11,x
 rep $20
 txa
 clc
 adc #12
 sta compiled_dispatch_count

 stz $F0
 sep $20
 lda #$32
 sta $F2
 rep $20
 ldy #0
 lda [$F0],y
 sta $F0

 plx
 ply

 inx
 inx
 jmp :im1b_loop

:im1b_done
 sec
 xce
 plb
 mx %11
 rtl

:im1b_offsets
 dfb $1C,$80      ; IMAGE01
 dfb $1E,$86      ; IMAGE02
 dfb $20,$8C      ; IMAGE03
 dfb $22,$C2      ; JUMP1
 dfb $24,$C8      ; JUMP2
 dfb $26,$CE      ; JUMP3
 dfb $28,$B6      ; KICK1
 dfb $2A,$BC      ; KICK2
 dfb $2C,$9E      ; PUNCH11
 dfb $2E,$A4      ; PUNCH12
 dfb $30,$AA      ; PUNCH21
 dfb $32,$B0      ; PUNCH22
 dfb $34,$D4      ; BPUNCHED
 dfb $6A,$92      ; BCLIMB1
 dfb $6C,$98      ; BCLIMB2
:im1b_offsets_end

* Scratch locals moved to bank-$00 RAM hole — see imb_* comment.
:im1b_tmp_off          equ $001C14
:im1b_blit_data_addr   equ $001C16
:im1b_blit_data_bank   equ $001C18
:im1b_blit_mir_addr    equ $001C1A
:im1b_blit_mir_bank    equ $001C1C
:im1b_frame_data_addr  equ $001C1E
:im1b_frame_mir_addr   equ $001C20

*----------------------------------------------------------
* _init_mission1jimmyblit - Migrated from game.s. Walks
* mission1jimmyblit_33 (bank $33) in lockstep with :im1j_offsets,
* which maps each Jimmy sprite to its DATA / DATA_MIRROR offsets
* in mission1jimmy.s's bank-$1D spr_addr_tbl. Order matches
* tools/generate_mission1jimmyblit.py.
*
* Native + MX %00 on entry/exit. Caller wraps with JSL.
*----------------------------------------------------------
_init_mission1jimmyblit
 phb                   ; save caller's DBR
 clc
 xce
 rep $30
 mx %00
* No phk/plb — see _init_mission12blit comment.

 stz $F0
 sep $20
 lda #$33
 sta $F2
 rep $20
 ldy #0
 lda [$F0],y
 sta $F0

 ldy #0
 ldx #0
:im1j_loop
 mx %00
 cpx #:im1j_offsets_end-:im1j_offsets
 bcc :im1j_in_range
 jmp :im1j_done
:im1j_in_range

 lda [$F0],y
 sta :im1j_blit_data_addr
 iny
 iny
 sep $20
 lda [$F0],y
 sta :im1j_blit_data_bank
 rep $20
 iny

 lda [$F0],y
 sta :im1j_blit_mir_addr
 iny
 iny
 sep $20
 lda [$F0],y
 sta :im1j_blit_mir_bank
 rep $20
 iny

 phy
 phx

 stz $F0
 sep $20
 lda #$1D
 sta $F2
 rep $20

* LDAL required — same DBR=$00 / engine.s-bank-$1F mismatch as :im1b_offsets
* above. Reading via `lda abs,X` gave dispatch entries with garbage
* frame_addrs, causing Jimmy's 4-pixel "non-mirrored residue" trail.
 sep $20
 ldal :im1j_offsets,x
 sta :im1j_tmp_off
 stz :im1j_tmp_off+1
 rep $20
 lda :im1j_tmp_off
 tay
 lda [$F0],y
 sta :im1j_frame_data_addr

 sep $20
 ldal :im1j_offsets+1,x
 sta :im1j_tmp_off
 stz :im1j_tmp_off+1
 rep $20
 lda :im1j_tmp_off
 tay
 lda [$F0],y
 sta :im1j_frame_mir_addr

 ldx compiled_dispatch_count
 lda :im1j_frame_data_addr
 sta compiled_dispatch_tbl,x
 lda :im1j_blit_data_addr
 sta compiled_dispatch_tbl+2,x
 sep $20
 lda :im1j_blit_data_bank
 sta compiled_dispatch_tbl+4,x
 stz compiled_dispatch_tbl+5,x
 rep $20
 lda :im1j_frame_mir_addr
 sta compiled_dispatch_tbl+6,x
 lda :im1j_blit_mir_addr
 sta compiled_dispatch_tbl+8,x
 sep $20
 lda :im1j_blit_mir_bank
 sta compiled_dispatch_tbl+10,x
 stz compiled_dispatch_tbl+11,x
 rep $20
 txa
 clc
 adc #12
 sta compiled_dispatch_count

 stz $F0
 sep $20
 lda #$33
 sta $F2
 rep $20
 ldy #0
 lda [$F0],y
 sta $F0

 plx
 ply

 inx
 inx
 jmp :im1j_loop

:im1j_done
 sec
 xce
 plb
 mx %11
 rtl

:im1j_offsets
 dfb $02,$06      ; JIMMY01
 dfb $0A,$0E      ; JIMMY02
 dfb $12,$16      ; JIMMY03
 dfb $1A,$1E      ; JJUMP1
 dfb $22,$26      ; JJUMP2
 dfb $2A,$2E      ; JJUMP3
 dfb $32,$36      ; JKICK1
 dfb $3A,$3E      ; JKICK2
 dfb $42,$46      ; JPUNCH11
 dfb $4A,$4E      ; JPUNCH12
 dfb $52,$56      ; JPUNCH21
 dfb $5A,$5E      ; JPUNCH22
 dfb $6E,$72      ; JPUNCHED
 dfb $7A,$7E      ; JCLIMB1
 dfb $82,$86      ; JCLIMB2
:im1j_offsets_end

* Scratch locals moved to bank-$00 RAM hole — see imb_* comment.
:im1j_tmp_off          equ $001C22
:im1j_blit_data_addr   equ $001C24
:im1j_blit_data_bank   equ $001C26
:im1j_blit_mir_addr    equ $001C28
:im1j_blit_mir_bank    equ $001C2A
:im1j_frame_data_addr  equ $001C2C
:im1j_frame_mir_addr   equ $001C2E

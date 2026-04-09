*----------------------------------------------------------
* DDIIGS
* Mission 1, toolbox init, sprite display
*----------------------------------------------------------
    org $2000

]IOBUF = $6C00        ; 1024-byte ProDOS I/O buffer (page-aligned)
]RDBUF = $7000         ; 4KB read buffer

* Initialize IIgs Toolbox
 jsr toolbox_init

* Enable SHR shadowing (bank $01 -> $E1) before loading
 clc
 xce
 sep $20
 ldal $C035
 and #$F7             ; clear bit 3
 stal $C035
 sec
 xce                   ; back to emulation for ProDOS calls

* Load MISSION11.PAK -> $4F, unpack to $50, copy $50 -> $01
 lda #$50
 sta unpack_bank
 jsr load_and_unpack
 jsr copy_50_to_01

* Load MISSION12.PAK -> $4F, unpack to $51
 lda #<path12
 sta p_open+1
 lda #>path12
 sta p_open+2
 lda #$51
 sta unpack_bank
 jsr load_and_unpack

* Load MISSION13.PAK -> $4F, unpack to $52
 lda #<path13
 sta p_open+1
 lda #>path13
 sta p_open+2
 lda #$52
 sta unpack_bank
 jsr load_and_unpack

* Load MISSION14.PAK -> $4F, unpack to $53
 lda #<path14
 sta p_open+1
 lda #>path14
 sta p_open+2
 lda #$53
 sta unpack_bank
 jsr load_and_unpack

* Load MISSION15.PAK -> $4F, unpack to $54
 lda #<path15
 sta p_open+1
 lda #>path15
 sta p_open+2
 lda #$54
 sta unpack_bank
 jsr load_and_unpack

* Enable SHR mode
 lda #$c1
 sta $e0c029

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

 lda #1
 pha
 lda #193
 pha
 ldx #$3a04         ; MoveTo
 jsl $E10000

 pea ^string5
 pea string5
 ldx #$A604
 jsl $E10000        ; DrawCString

 sec
 xce
 sep #$30

 bra over1

string1 ASC 'Player 1 x0',00
string2 ASC 'Score: 00000',00
string3 ASC 'Player 2 x0',00
string4 ASC 'Score: 00000',00
string5 ASC 'DD2 Tech Demo [cCc] 2026 -- Press 8,4,6,2',00

over1
* Initial draw of all sprites
 jsr draw_all

*==========================================================
* Main game loop
*==========================================================
game_loop
 jsr wait_for_vbl
 jsr erase_all
 jsr process_input
; jsr update_npcs
 jsr update_anims
 jsr draw_all
 bra game_loop

*----------------------------------------------------------
* update_npcs - Iterate sprite_table, call npc_seek_player
* for each NPC (controller = $00, not the terminator).
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
 bne :skip            ; non-zero = player or other, skip
 jsr npc_seek_player
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
* Death: erase at prev position, then remove from table
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
 jsr remove_from_sprite_table
 bra :loop            ; don't advance spr_ptr — entries shifted down
:not_dead
* Erase if bit 1 set (needs_erase)
 ldy #30
 lda (info_ptr),y
 and #$02
 beq :skip_erase
* Load previous position/size for erase
 ldy #32
 lda (info_ptr),y     ; prev_ypos
 sta IMAGE01_YPOS
 ldy #34
 lda (info_ptr),y     ; prev_xpos
 sta IMAGE01_XPOS
 ldy #36
 lda (info_ptr),y     ; prev_frame_x
 sta FRAME_X
 ldy #38
 lda (info_ptr),y     ; prev_frame_y
 sta FRAME_Y
* If animation active, use max_width for erase
 ldy #24
 lda (info_ptr),y     ; anim_ptr low
 iny
 ora (info_ptr),y     ; anim_ptr high
 beq :no_anim
 ldy #24
 lda (info_ptr),y
 sta anim_ptr
 ldy #25
 lda (info_ptr),y
 sta anim_ptr+1
 ldy #1
 lda (anim_ptr),y     ; max_width from descriptor
 sta FRAME_X
:no_anim
 jsr erase
* Check if erased area overlaps other sprites
 jsr mark_overlapping
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

spr_ptr = $E0         ; ZP pointer into sprite_table
info_ptr = $E2        ; ZP pointer to current sprite info block
anim_ptr = $E4        ; ZP pointer to animation descriptor

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
 rts
:not_scroll
 cmp #'8'
 bne :not_up
 dec IMAGE01_YPOS
 jsr save_sprite
 jsr resort_sprite_table
 rts
:not_up cmp #'2'
 bne :not_down
 inc IMAGE01_YPOS
 jsr save_sprite
 jsr resort_sprite_table
 rts
:not_down cmp #'4'
 bne :not_left
 lda IMAGE01_XPOS
 cmp #2
 bcc :skip_left        ; already at minimum (1)
 dec IMAGE01_XPOS
:skip_left
 lda #$01
 sta IMAGE01_MIRROR
 jsr advance_walk
 jsr save_sprite
 rts
:not_left cmp #'6'
 bne :not_jump
 lda IMAGE01_XPOS
 cmp #100
 bcs :skip_right       ; already at maximum (100)
 inc IMAGE01_XPOS
:skip_right
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
 bne :not_punch1
 lda #<anim_kick
 ldx #>anim_kick
 jsr start_anim
 rts
:not_punch1 cmp #'p'
 bne :not_punch2
 lda #<anim_punch1
 ldx #>anim_punch1
 jsr start_anim
 rts
:not_punch2 cmp #'P'
 bne :no_key2
 lda #<anim_punch2
 ldx #>anim_punch2
 jsr start_anim
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
walk_x_tbl dfb $09,$08,$0B,$08
walk_y_tbl dfb $28,$28,$28,$28
walk_addr_tbl da IMAGE01,IMAGE02,IMAGE03,IMAGE02

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
 jsr save_sprite
 rts

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
 bcc :load_frame      ; frame < num_frames, load it
* Animation complete — check for loop
 ldy #2
 lda (anim_ptr),y     ; flags
 and #$02             ; bit 1 = loop
 beq :anim_done       ; not looping, terminate
* Loop: reset to frame 0
 ldy #26
 lda #0
 sta (info_ptr),y     ; anim_frame = 0
 bra :load_frame
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
* Death: set $FFFF sentinel, mark dirty for erase+removal
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
 jsr save_sprite
 bra :next

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
* Check for punch hit (if this is frame 1 of punch1 or punch2)
 ldy #26
 lda (info_ptr),y     ; anim_frame
 cmp #1
 bne :no_punch_hit
 lda anim_ptr
 cmp #<anim_punch1
 beq :do_hit
 cmp #<anim_punch2
 bne :no_punch_hit
 lda anim_ptr+1
 cmp #>anim_punch2
 bne :no_punch_hit
 bra :do_hit2
:do_hit
 lda anim_ptr+1
 cmp #>anim_punch1
 bne :no_punch_hit
:do_hit2
 jsr check_punch_hit
:no_punch_hit
 jsr save_sprite

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
* scroll_right - Scroll playfield 1 byte (2 pixels) right.
* 1) Shift bytes 1-110 left by one in bank $50 for 183 lines
* 2) Fill right edge from bank $51 (x_scroll_idx bytes)
* 3) Blit 110-byte wide playfield from $50 to $E1
* 4) Redraw sprite
*----------------------------------------------------------
scroll_right
 inc x_scroll_idx      ; 8-bit inc, fine for values < 256

 clc
 xce                   ; native mode
 rep $30               ; 16-bit A, X, Y

* Step 1: Shift bytes 1-110 left by one in bank $50
 lda #$2001
 sta $F0               ; src = line_start + 1
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
 cpy #110
 bcc :shift_word

 lda $F0
 clc
 adc #$A0
 sta $F0
 lda $F3
 clc
 adc #$A0
 sta $F3
 dex
 bne :shift_line

* Step 2: Fill byte 109 (rightmost visible) from scroll source
 lda scroll_src_off
 clc
 adc #$2000
 sta $F0               ; src = scroll_src_bank/(2000 + scroll_src_off)
 lda #$206D            ; dst = $50/(2000 + 109)
 sta $F3
 sep $20
 lda scroll_src_bank
 sta $F2               ; src bank
 lda #$50
 sta $F5               ; dst bank

 rep $20
 ldx #183
:fill_line
 sep $20
 lda [$F0]             ; read 1 byte from source
 sta [$F3]             ; write to byte 109 in $50
 rep $20
 lda $F0
 clc
 adc #$A0
 sta $F0
 lda $F3
 clc
 adc #$A0
 sta $F3
 dex
 bne :fill_line

* Advance scroll source for next scroll
 inc scroll_src_off
 lda scroll_src_off
 cmp #110
 bcc :no_bank_wrap
 stz scroll_src_off    ; reset offset
 sep $20
 inc scroll_src_bank   ; advance to next bank
 rep $20
:no_bank_wrap

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
 rts

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
 da IMAGE01
 dfb $08,$28,5       ; IMAGE02
 da IMAGE02
 dfb $0B,$28,5       ; IMAGE03
 da IMAGE03
 dfb $08,$28,5       ; IMAGE02
 da IMAGE02

anim_jump
 dfb 3               ; num_frames
 dfb $0F             ; max_width (JUMP2 is widest)
 dfb $01             ; flags: advance position
 dfb $0A,$28,3       ; JUMP1
 da JUMP1
 dfb $0F,$2A,12      ; JUMP2
 da JUMP2
 dfb $0D,$20,3       ; JUMP3
 da JUMP3

anim_kick
 dfb 2               ; num_frames
 dfb $14             ; max_width (KICK2 is widest)
 dfb $00             ; flags: none
 dfb $09,$28,12      ; KICK1
 da KICK1
 dfb $14,$28,12      ; KICK2
 da KICK2

anim_punch1
 dfb 2               ; num_frames
 dfb $10             ; max_width (PUNCH12 is widest)
 dfb $00             ; flags: none
 dfb $0B,$28,6       ; PUNCH11
 da PUNCH11
 dfb $10,$28,6       ; PUNCH12
 da PUNCH12

anim_punch2
 dfb 2               ; num_frames
 dfb $10             ; max_width (PUNCH22 is widest)
 dfb $00             ; flags: none
 dfb $0A,$28,6       ; PUNCH21
 da PUNCH21
 dfb $10,$28,6       ; PUNCH22
 da PUNCH22

anim_bpunched
 dfb 1               ; num_frames
 dfb $0B             ; max_width
 dfb $00             ; flags: none (one-shot)
 dfb $0B,$28,5       ; BPUNCHED: 11 wide, 40 tall, 5 VBLs
 da BPUNCHED

anim_wpunched
 dfb 1               ; num_frames
 dfb $09             ; max_width
 dfb $00             ; flags: none (one-shot)
 dfb $09,$28,5       ; WPUNCHED: 9 wide, 40 tall, 5 VBLs
 da WPUNCHED

anim_wfall
 dfb 2               ; num_frames
 dfb $14             ; max_width (WFALL is widest at $14)
 dfb $00             ; flags: none (one-shot)
 dfb $14,$23,3       ; WFALL: 20 wide, 35 tall, 3 VBLs
 da WFALL
 dfb $12,$17,60      ; WFALLEN: 18 wide, 15 tall, 60 VBLs
 da WFALLEN

anim_bfall
 dfb 1               ; num_frames
 dfb $09             ; max_width (IMAGE01)
 dfb $00             ; flags: none (one-shot, placeholder)
 dfb $09,$28,33      ; IMAGE01: 9 wide, 40 tall, 33 VBLs
 da IMAGE01

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
* Save caller's spr_ptr and info_ptr
 lda spr_ptr
 pha
 lda spr_ptr+1
 pha
 lda info_ptr
 pha
 lda info_ptr+1
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
 ldal $E0C034
 clc
 adc #1
 and #$0F
 sta :tmp
 ldal $E0C034
 and #$F0
 ora :tmp
 stal $E0C034
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
* Restore caller's info_ptr and spr_ptr
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
 LDA #^IMAGE01
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

* master sprite table
sprite_table
  dw billy_sprite
  dw william_sprite
  dw william2_sprite
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
  da IMAGE01 ; +14 frame data address (init to IMAGE01)
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
  da IMAGE01       ; +42 idle_addr
  hex 0900         ; +44 idle_x
  hex 2800         ; +46 idle_y
  hex 0000         ; +48 punch_count
  da anim_bfall    ; +50 fall_anim pointer

*-------------------------------
* Globals (used by erase/draw_sprite)
*-------------------------------
FRAME_X  HEX 0900         ; current frame width
FRAME_Y  HEX 2800         ; current frame height
FRAME_ADDR DA IMAGE01     ; current frame data address

*-------------------------------
* Sprite state
*-------------------------------
IMAGE01_XTEMP HEX 0000
IMAGE01_XPOS HEX 0100
IMAGE01_YPOS HEX 6400
IMAGE01_MIRROR HEX 0000
x_scroll_idx HEX 0000
scroll_src_bank dfb $51    ; current source bank for scroll fill
draw_bank da $0001         ; bank for draw_sprite destination (default $01, shadowed to $E1)
scroll_src_off HEX 0000   ; byte offset within source bank scanline
MASKHI HEX 60
MASKLO HEX 06
MASK HEX 66

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
IMLEN01 EQU *-IMAGE01

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
IMLEN02 EQU *-IMAGE02

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
IMLEN03 EQU *-IMAGE03

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
JUMPLEN01 EQU *-JUMP1

JUMP2_Y HEX 2A00
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
 HEX 666666666666666666666666666666
 HEX 666666666666666666666666666666
 HEX 666666666666666666666666666666
 HEX 666666666666666666666666666666
 HEX 666666666666666666666666666666
 HEX 666666666666666666666666666666
 HEX 666666666666666666666666666666
 HEX 666666666666666666666666666666
 HEX 666666666666666666666666666666
 HEX 666666666666666666666666666666
 HEX 666666666666666666666666666666
 HEX 666666666666666666666666666666
JUMPLEN02 EQU *-JUMP2

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
JUMPLEN03 EQU *-JUMP3

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
KICK1LEN EQU *-KICK1

KICK2_Y HEX 2800
KICK2_X HEX 1400
KICK2
 HEX 6666666666666666666666666666666666666666
 HEX 6666666666666666666666666666666666666666
 HEX 6666666666666666666666666666666666666666
 HEX 6666666666666666666666666666666666666666
 HEX 6666666666666666666666666666666666666666
 HEX 6666666666666666666666666666666666666666
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
KICK2LEN EQU *-KICK2

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
PUNCH11LEN EQU *-PUNCH11

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
PUNCH12LEN EQU *-PUNCH12

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
PUNCH22LEN EQU *-PUNCH22

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
BPUNCHEDLEN EQU *-BPUNCHED

**
** WILLIAM sprites (note William's mask color is E not 6)
**

william_sprite
  hex 5F00 ; +0  ypos
  hex 5800 ; +2  xpos
  hex 0100 ; +4  mirror (0 or 1)
  hex 0000 ; +6  anim_step (unused)
  hex 0500 ; +8  anim_count (unused)
  hex 0900 ; +10 frame width (init to WILLIAM1)
  hex 2800 ; +12 frame height (init to WILLIAM1)
  da WILLIAM1 ; +14 frame data address
  hex EE00 ; +16 mask
  hex E000 ; +18 maskhi
  hex 0E00 ; +20 masklo
  hex 0000 ; +22 controller (00 = none)
  hex 0000 ; +24 anim_ptr
  hex 0000 ; +26 anim_frame
  hex 0000 ; +28 anim_timer
  hex 0100 ; +30 dirty (bit0=needs_draw, bit1=needs_erase)
  hex 5F00 ; +32 prev_ypos
  hex 5800 ; +34 prev_xpos
  hex 0900 ; +36 prev_frame_x
  hex 2800 ; +38 prev_frame_y
  da anim_wpunched ; +40 punched_anim pointer
  da WILLIAM1      ; +42 idle_addr
  hex 0900         ; +44 idle_x
  hex 2800         ; +46 idle_y
  hex 0000         ; +48 punch_count
  da anim_wfall    ; +50 fall_anim pointer

william2_sprite
  hex 8400 ; +0  ypos
  hex 5800 ; +2  xpos
  hex 0100 ; +4  mirror (0 or 1)
  hex 0000 ; +6  anim_step (unused)
  hex 0500 ; +8  anim_count (unused)
  hex 0900 ; +10 frame width (init to WILLIAM1)
  hex 2800 ; +12 frame height (init to WILLIAM1)
  da WILLIAM1 ; +14 frame data address
  hex EE00 ; +16 mask
  hex E000 ; +18 maskhi
  hex 0E00 ; +20 masklo
  hex 0000 ; +22 controller (00 = none)
  hex 0000 ; +24 anim_ptr
  hex 0000 ; +26 anim_frame
  hex 0000 ; +28 anim_timer
  hex 0100 ; +30 dirty (bit0=needs_draw, bit1=needs_erase)
  hex 8400 ; +32 prev_ypos
  hex 5800 ; +34 prev_xpos
  hex 0900 ; +36 prev_frame_x
  hex 2800 ; +38 prev_frame_y
  da anim_wpunched ; +40 punched_anim pointer
  da WILLIAM1      ; +42 idle_addr
  hex 0900         ; +44 idle_x
  hex 2800         ; +46 idle_y
  hex 0000         ; +48 punch_count
  da anim_wfall    ; +50 fall_anim pointer

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
WILLIAM1LEN EQU *-WILLIAM1

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
WILLIAM2LEN EQU *-WILLIAM2

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
WILLIAM3LEN EQU *-WILLIAM3

WPUNCHED_Y HEX 2800
WPUNCHED_X HEX 0900
WPUNCHED
 HEX EEEEEE0E0000EEEEEE
 HEX EE0040F0FFFF0EEEEE
 HEX EE0F0FFFF0FFF0EEEE
 HEX EEE0FFFF000FF0EEEE
 HEX EEE0FFFF0F20FF0EEE
 HEX EEEE00F0F2220F0EEE
 HEX EEEEE00F22FFF00EEE
 HEX EEEEE0FFF0022020EE
 HEX EEEEEE000F444040EE
 HEX EEEEEE00F0004F00EE
 HEX EEEE00000F00040EEE
 HEX EEE0FFF000400F00EE
 HEX EE04444F000F40F0EE
 HEX EE0444440F000040EE
 HEX E0F444440FF44040EE
 HEX E044444F00FF00F0EE
 HEX E044444FF000000000
 HEX E044F00F0000004F40
 HEX E0F44F00000000FF40
 HEX E0F44040F4F0004440
 HEX E0F4F0044440000000
 HEX EE0F04044440000440
 HEX EEE0000F44F000000E
 HEX EEEEE0400000000EEE
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

WFALL_Y HEX 2300
WFALL_X HEX 1400
WFALL HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EEEE00E0000EEEEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX E0000F0FFFF0EEEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX E0F0FFFF0FFF0EEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX E00FFFF000FF0EEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EE0FFFF0F20FF0EEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EE000F0F2220F0EEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EEE000F22FFF000EEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EEEE0FFF0022020EEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EEEEEE0FF444040EE0000EEEEEEEEEEEEEEEEEEE
 HEX EEEEEE0F0004F000004040EEEEEEEEEEEEEEEEEE
 HEX EEEEEEE0F0004000F0F0F0EEEEEEEEEEEEEEEEEE
 HEX EEEEEEE00400F00040FFF0EEEEEEEEEEEEEEEEEE
 HEX EEEEEEEE00F400F04F4440EEEEEEEEEEEEEEEEEE
 HEX EEEEEEEEE0000F400F4400EEEEEEEEEEEEEEEEEE
 HEX EEEEEEEEE00000F0000000EEEEEEEEEEEEEEEEEE
 HEX EEEEEEEE00FFF0004040F0EEEEEEEEEEEEEEEEEE
 HEX EEEEEEEE0F444F00000000EEEEEEEEEEEEEEEEEE
 HEX EEEEEEEE04444400F44F000000000E0EEEEE00EE
 HEX EEEEEEEE0F44440F444F000669996090EEE090EE
 HEX EEEEEEEEE0FF4404444F0000000060990009A0EE
 HEX EEEEEEEEEE000FF4444F0069999600A99A990EEE
 HEX EEEEEEEEEEEEE00F44F00099999990AAAA990EEE
 HEX EEEEEEEEEEEEEEE0000000999669900000AA0EEE
 HEX EEEEEEEEEEEEEEEEEE000066609960EEEE000EEE
 HEX EEEEEEEEEEEEEEEEEEEEEE00006660EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEE000000EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEE0A990EEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEE0A990EEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEE0A90EEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEE0AA0EEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEE09900EEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEE099990EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEE000000EEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
WFALLLEN EQU *-WFALL

WFALLEN_Y HEX 1700
WFALLEN_X HEX 1200
WFALLEN HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
 HEX EE00000000EEEEEEEEEEEE0000EEEEEEEEEE
 HEX EEFFFFFFF00000EEEEEEE066600EEEEEEEEE
 HEX EE0FFFF000000000EEEE06000000EEEEEEEE
 HEX EEFFF000000FF0000EE00069999A0EEEEEEE
 HEX EE0FF00F20044F000000069996A00EEEEEEE
 HEX EEFFF0044F00F000000069966600A0EEEEEE
 HEX EE0000F40000000000069996600A9A0000EE
 HEX EE0FF000000FFF000066996600A99900A9EE
 HEX EEF44000FF0044F000699966000A99AA9AEE
 HEX EE444040444F44F0006996600000AA99A0EE
 HEX EE444000444444F0006666000000099A00EE
 HEX EEF4F0F0FF444F00000660E0000000A00EEE
 HEX EE0000000000000000000EEEEEE00000EEEE
 HEX EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
WFALLENLEN EQU *-WFALLEN

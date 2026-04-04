*----------------------------------------------------------
* DDIIGS
* Mission 1, toolbox init, sprite display
*----------------------------------------------------------
    org $2000

]MASK = $AA ;Background color to mask off
]MASKHI = $A0 ; upper nibble needs maskin
]MASKLO = $0A ; lower nibble needs maskin

]IOBUF = $6C00        ; 1024-byte ProDOS I/O buffer (page-aligned)
]RDBUF = $7000         ; 4KB read buffer

* Initialize IIgs Toolbox
 jsr toolbox_init

* Load background from MISSION11.SHR -> $E1/2000 and $50/2000
 jsr load_background

* Load MISSION12.SHR -> $51/2000
 lda #<path12
 sta p_open+1
 lda #>path12
 sta p_open+2
 lda #$51
 sta load_bank
 jsr load_to_bank

* Load MISSION13.SHR -> $52/2000
 lda #<path13
 sta p_open+1
 lda #>path13
 sta p_open+2
 lda #$52
 sta load_bank
 jsr load_to_bank

* Load MISSION14.SHR -> $53/2000
 lda #<path14
 sta p_open+1
 lda #>path14
 sta p_open+2
 lda #$53
 sta load_bank
 jsr load_to_bank

* Load MISSION15.SHR -> $54/2000
 lda #<path15
 sta p_open+1
 lda #>path15
 sta p_open+2
 lda #$54
 sta load_bank
 jsr load_to_bank

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
 jsr DUMP01
nokey bit $c000
 bpl nokey
 lda $c010
 and #$7f
 cmp #'r'
 bne not_scroll
 jsr wait_for_vbl
 jsr scroll_right    ; composites onto back buffer, no erase needed
 bra nokey
not_scroll
 pha                 ; save keypress
 jsr wait_for_vbl
 jsr erase           ; erase at OLD position with OLD frame dims
 pla                 ; restore keypress
 cmp #'8'
 bne not_up
 dec IMAGE01_YPOS
 bra keyend
not_up cmp #'2'
 bne not_down
 inc IMAGE01_YPOS
 bra keyend
not_down cmp #'4'
 bne not_left
 dec IMAGE01_XPOS
 lda #$01
 sta IMAGE01_MIRROR
 jsr advance_frame   ; animate on horizontal movement
 bra keyend
not_left cmp #'6'
 bne not_jump
 inc IMAGE01_XPOS
 stz IMAGE01_MIRROR
 jsr advance_frame   ; animate on horizontal movement
 bra keyend
not_jump cmp #'j'
 bne not_kick
 jsr do_jump         ; blocking jump animation
 bra nokey           ; do_jump handles all drawing
not_kick cmp #'k'
 bne not_punch1
 jsr do_kick         ; blocking kick animation
 bra nokey
not_punch1 cmp #'p'
 bne not_punch2
 jsr do_punch1       ; blocking punch1 animation
 bra nokey
not_punch2 cmp #'P'
 bne keyend
 jsr do_punch2       ; blocking punch2 animation
 bra nokey
keyend jsr DUMP01       ; draw at NEW position with NEW frame
 bra nokey

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
* load_background - Open MISSION11.SHR via ProDOS 8,
* read 32KB in 4KB chunks into ]RDBUF, and copy each
* chunk to SHR screen ($E1/2000) and shadow ($50/2000).
* Returns with carry clear on success, set on error.
*----------------------------------------------------------
load_background
 jsr $BF00
 dfb $C8              ; OPEN
 da p_open
 bcs :err
 lda o_refnum
 sta r_refnum
 sta c_refnum

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

 jsr copy_chunk

* Advance destination by $1000
 lda dest+1
 clc
 adc #$10
 sta dest+1

 dec :count
 bne :readlp

:close
 php                   ; save carry (error status)
 jsr $BF00
 dfb $CC              ; CLOSE
 da p_close
 plp                   ; restore original carry
:err rts

:count dfb 0

*----------------------------------------------------------
* copy_chunk - Copy 4KB from ]RDBUF to $E1/dest and $50/dest
* Uses ZP $F0-$F5 for indirect long pointers.
*----------------------------------------------------------
copy_chunk
 clc
 xce                   ; switch to native mode
 rep $30               ; 16-bit A and index

 lda dest
 sta $F0               ; $E1 destination low/high
 sta $F3               ; $50 destination low/high
 sep $20
 lda #$E1
 sta $F2               ; $E1 bank byte
 lda #$50
 sta $F5               ; $50 bank byte

 rep $30
 ldy #$0000
 ldx #$0800            ; $1000/2 = $0800 word copies

:loop lda ]RDBUF,y
 sta [$F0],y
 sta [$F3],y
 iny
 iny
 dex
 bne :loop

 sec
 xce                   ; back to emulation mode
 rts

*----------------------------------------------------------
* load_to_bank - Load a SHR file into a single bank.
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
 jsr DUMP01

* Step 5: Stack-blit $55 -> $E1 (screen) for flicker-free update
 clc
 xce                   ; native mode
 rep $30
 jsr stack_blit_55_e1

 sec
 xce                   ; back to emulation mode

* Restore draw_bank for normal (non-scroll) DUMP01 calls
 lda #$E1
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
* stack_blit_55_e1 - Stack-based blit from $55 to screen $E1
* Maps stack to bank $01, enables SHR shadow ($01->$E1),
* then uses PHA to write each word. 110 bytes wide, 183 lines.
* Entry: native mode, REP $30. Trashes A/X/Y/S (S restored).
*----------------------------------------------------------
stack_blit_55_e1
 rep $30               ; assert 16-bit A/X/Y for assembler MX tracking
 tsc
 sta :save_s           ; save stack pointer

 sei                   ; no interrupts while stack is remapped
 sep $20
 sta $C005             ; WrCardRAM: writes to bank $00 -> bank $01
 lda $C035
 and #$F7
 sta $C035             ; clear bit 3: enable SHR shadow ($01->$E1)
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
 lda $C035
 ora #$08
 sta $C035             ; set bit 3: disable SHR shadow
 rep $20

 lda :save_s
 tcs                   ; restore stack pointer
 cli                   ; re-enable interrupts
 rts

:save_s ds 2

 mx %11                ; following routines run in emulation mode (8-bit)
*----------------------------------------------------------
* do_jump - Play 3-frame jump animation (blocking).
* Frame 1 (JUMP1): 3 VBLs, frame 2 (JUMP2): 6 VBLs,
* frame 3 (JUMP3): 3 VBLs. Advances XPOS by 1 byte per VBL
* in the current facing direction. No input accepted.
*----------------------------------------------------------
do_jump
 ldx #0               ; jump step index (0, 1, 2)

:next_frame
 lda JUMP_X_TBL,x
 sta FRAME_X
 lda JUMP_Y_TBL,x
 sta FRAME_Y
 txa
 pha                   ; save step index
 asl                   ; *2 for 16-bit addr table
 tax
 lda JUMP_ADDR_TBL,x
 sta FRAME_ADDR
 lda JUMP_ADDR_TBL+1,x
 sta FRAME_ADDR+1
 pla
 tax                   ; restore step index
 lda JUMP_DUR_TBL,x   ; duration for this frame
 sta :dur
 stx :step             ; save step index (erase/DUMP01 clobber X)

:vbl_loop
 jsr wait_for_vbl
* Erase with widest jump frame width to avoid trails
 lda FRAME_X
 pha                   ; save current frame width
 lda #$11             ; JUMP2_X = widest jump sprite (17 bytes)
 sta FRAME_X
 jsr erase
 pla
 sta FRAME_X           ; restore actual frame width for draw
* Advance position in facing direction
 lda IMAGE01_MIRROR
 bne :go_left
 inc IMAGE01_XPOS
 bra :draw
:go_left
 dec IMAGE01_XPOS
:draw
 jsr DUMP01

 dec :dur
 bne :vbl_loop

* Next jump frame
 ldx :step             ; restore step index
 inx
 cpx #3
 bcc :next_frame

* Restore to IMAGE01 standing frame after jump
 stz ANIM_STEP         ; reset walk animation to frame 0
 lda #5
 sta ANIM_COUNT        ; reset VBL countdown
 lda FRAME_X_TBL
 sta FRAME_X
 lda FRAME_Y_TBL
 sta FRAME_Y
 lda FRAME_ADDR_TBL
 sta FRAME_ADDR
 lda FRAME_ADDR_TBL+1
 sta FRAME_ADDR+1
* Erase JUMP3 footprint (wide) and draw IMAGE01
 jsr wait_for_vbl
 lda FRAME_X
 pha
 lda #$11             ; widest jump sprite
 sta FRAME_X
 jsr erase
 pla
 sta FRAME_X
 jsr DUMP01
 rts

:dur dfb 0
:step dfb 0

*-------------------------------
* Jump animation tables
*-------------------------------
JUMP_X_TBL   dfb $0B,$11,$0E         ; JUMP1_X, JUMP2_X, JUMP3_X
JUMP_Y_TBL   dfb $28,$2A,$20         ; JUMP1_Y, JUMP2_Y, JUMP3_Y
JUMP_DUR_TBL dfb 3,12,3              ; VBLs per frame
JUMP_ADDR_TBL DA JUMP1,JUMP2,JUMP3

*----------------------------------------------------------
* do_kick - Play 2-frame kick animation (blocking).
* KICK1 for 2 VBLs, KICK2 for 2 VBLs, then restore IMAGE01.
* Sprite stays in place (no movement).
*----------------------------------------------------------
do_kick
 ldx #0               ; kick step index (0, 1)

:next_frame
 lda KICK_X_TBL,x
 sta FRAME_X
 lda KICK_Y_TBL,x
 sta FRAME_Y
 stx :step
 txa
 asl
 tax
 lda KICK_ADDR_TBL,x
 sta FRAME_ADDR
 lda KICK_ADDR_TBL+1,x
 sta FRAME_ADDR+1
 ldx :step
 lda KICK_DUR_TBL,x
 sta :dur

:vbl_loop
 jsr wait_for_vbl
 lda FRAME_X
 pha
 lda #$15             ; KICK2_X = widest kick sprite (21 bytes)
 sta FRAME_X
 jsr erase
 pla
 sta FRAME_X
 jsr DUMP01

 dec :dur
 bne :vbl_loop

 ldx :step
 inx
 cpx #2
 bcc :next_frame

* Restore to IMAGE01 standing frame
 stz ANIM_STEP
 lda #5
 sta ANIM_COUNT
 lda FRAME_X_TBL
 sta FRAME_X
 lda FRAME_Y_TBL
 sta FRAME_Y
 lda FRAME_ADDR_TBL
 sta FRAME_ADDR
 lda FRAME_ADDR_TBL+1
 sta FRAME_ADDR+1
 jsr wait_for_vbl
 lda FRAME_X
 pha
 lda #$15             ; widest kick sprite
 sta FRAME_X
 jsr erase
 pla
 sta FRAME_X
 jsr DUMP01
 rts

:dur dfb 0
:step dfb 0

*-------------------------------
* Kick animation tables
*-------------------------------
KICK_X_TBL   dfb $0A,$15             ; KICK1_X, KICK2_X
KICK_Y_TBL   dfb $28,$28             ; KICK1_Y, KICK2_Y
KICK_DUR_TBL dfb 12,12                 ; VBLs per frame
KICK_ADDR_TBL DA KICK1,KICK2

*----------------------------------------------------------
* do_punch1 - Play 2-frame punch animation (blocking).
* PUNCH11 for 6 VBLs, PUNCH12 for 6 VBLs, then IMAGE01.
*----------------------------------------------------------
do_punch1
 ldx #0

:next_frame
 lda PUNCH1_X_TBL,x
 sta FRAME_X
 lda PUNCH1_Y_TBL,x
 sta FRAME_Y
 stx :step
 txa
 asl
 tax
 lda PUNCH1_ADDR_TBL,x
 sta FRAME_ADDR
 lda PUNCH1_ADDR_TBL+1,x
 sta FRAME_ADDR+1
 ldx :step
 lda PUNCH1_DUR_TBL,x
 sta :dur

:vbl_loop
 jsr wait_for_vbl
 lda FRAME_X
 pha
 lda #$12             ; widest punch sprite (PUNCH22 = $12)
 sta FRAME_X
 jsr erase
 pla
 sta FRAME_X
 jsr DUMP01

 dec :dur
 bne :vbl_loop

 ldx :step
 inx
 cpx #2
 bcc :next_frame

* Restore to IMAGE01 standing frame
 stz ANIM_STEP
 lda #5
 sta ANIM_COUNT
 lda FRAME_X_TBL
 sta FRAME_X
 lda FRAME_Y_TBL
 sta FRAME_Y
 lda FRAME_ADDR_TBL
 sta FRAME_ADDR
 lda FRAME_ADDR_TBL+1
 sta FRAME_ADDR+1
 jsr wait_for_vbl
 lda FRAME_X
 pha
 lda #$12
 sta FRAME_X
 jsr erase
 pla
 sta FRAME_X
 jsr DUMP01
 rts

:dur dfb 0
:step dfb 0

PUNCH1_X_TBL   dfb $0C,$11
PUNCH1_Y_TBL   dfb $28,$28
PUNCH1_DUR_TBL dfb 6,6
PUNCH1_ADDR_TBL DA PUNCH11,PUNCH12

*----------------------------------------------------------
* do_punch2 - Play 2-frame punch animation (blocking).
* PUNCH21 for 6 VBLs, PUNCH22 for 6 VBLs, then IMAGE01.
*----------------------------------------------------------
do_punch2
 ldx #0

:next_frame
 lda PUNCH2_X_TBL,x
 sta FRAME_X
 lda PUNCH2_Y_TBL,x
 sta FRAME_Y
 stx :step
 txa
 asl
 tax
 lda PUNCH2_ADDR_TBL,x
 sta FRAME_ADDR
 lda PUNCH2_ADDR_TBL+1,x
 sta FRAME_ADDR+1
 ldx :step
 lda PUNCH2_DUR_TBL,x
 sta :dur

:vbl_loop
 jsr wait_for_vbl
 lda FRAME_X
 pha
 lda #$12             ; widest punch sprite (PUNCH22 = $12)
 sta FRAME_X
 jsr erase
 pla
 sta FRAME_X
 jsr DUMP01

 dec :dur
 bne :vbl_loop

 ldx :step
 inx
 cpx #2
 bcc :next_frame

* Restore to IMAGE01 standing frame
 stz ANIM_STEP
 lda #5
 sta ANIM_COUNT
 lda FRAME_X_TBL
 sta FRAME_X
 lda FRAME_Y_TBL
 sta FRAME_Y
 lda FRAME_ADDR_TBL
 sta FRAME_ADDR
 lda FRAME_ADDR_TBL+1
 sta FRAME_ADDR+1
 jsr wait_for_vbl
 lda FRAME_X
 pha
 lda #$12
 sta FRAME_X
 jsr erase
 pla
 sta FRAME_X
 jsr DUMP01
 rts

:dur dfb 0
:step dfb 0

PUNCH2_X_TBL   dfb $0B,$12
PUNCH2_Y_TBL   dfb $28,$28
PUNCH2_DUR_TBL dfb 6,6
PUNCH2_ADDR_TBL DA PUNCH21,PUNCH22

*----------------------------------------------------------
* advance_frame - count VBLs and cycle animation frame
* Sequence: IMAGE01 -> IMAGE02 -> IMAGE03 -> IMAGE02 -> repeat
*----------------------------------------------------------
advance_frame
 dec ANIM_COUNT
 bne :done
 lda #5
 sta ANIM_COUNT      ; reset counter
 inc ANIM_STEP
 lda ANIM_STEP
 cmp #4
 bne :nowrap
 stz ANIM_STEP
:nowrap ldx ANIM_STEP
 lda FRAME_X_TBL,x
 sta FRAME_X
 lda FRAME_Y_TBL,x
 sta FRAME_Y
 txa
 asl                 ; *2 for 16-bit table index
 tax
 lda FRAME_ADDR_TBL,x
 sta FRAME_ADDR
 lda FRAME_ADDR_TBL+1,x
 sta FRAME_ADDR+1
:done rts

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
* Set up destination pointer (screen at $E1/2000) in DP 0-2
 LDA #$E1
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
* DUMP01 - Plot the current frame to screen
* Uses FRAME_X, FRAME_Y, FRAME_ADDR for the active frame.
*----------------------------------------------------------
DUMP01 PHB
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
 CMP #]MASK
 BEQ MSKIP
 AND #$F0
 CMP #]MASKHI
 BEQ MDOMASKHI
 LDA 9
 AND #$0F
 CMP #]MASKLO
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
  CMP #]MASK
  BEQ SKIP
  AND #$F0
  CMP #]MASKHI
  BEQ DOMASKHI
  LDA [4]
  AND #$0F
  CMP #]MASKLO
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

pathname dfb 21
 asc '/DDIIGS/MISSION11.SHR'

path12 dfb 21
 asc '/DDIIGS/MISSION12.SHR'

path13 dfb 21
 asc '/DDIIGS/MISSION13.SHR'

path14 dfb 21
 asc '/DDIIGS/MISSION14.SHR'

path15 dfb 21
 asc '/DDIIGS/MISSION15.SHR'

**
** BILLY sprites
**

*-------------------------------
* Animation state
*-------------------------------
ANIM_STEP HEX 0000        ; current step in sequence (0-3)
ANIM_COUNT HEX 0500       ; VBL countdown (starts at 5)
FRAME_X  HEX 0B00         ; current frame width (init to IMAGE01)
FRAME_Y  HEX 2800         ; current frame height (init to IMAGE01)
FRAME_ADDR DA IMAGE01     ; current frame data address (init to IMAGE01)

*-------------------------------
* Animation lookup tables
* Sequence: IMAGE01, IMAGE02, IMAGE03, IMAGE02
*-------------------------------
FRAME_X_TBL HEX 0B090C09
FRAME_Y_TBL HEX 28282828
FRAME_ADDR_TBL DA IMAGE01,IMAGE02,IMAGE03,IMAGE02

*-------------------------------
* Sprite state
*-------------------------------
IMAGE01_XTEMP HEX 0000
IMAGE01_XPOS HEX 0100
IMAGE01_YPOS HEX 6400
IMAGE01_MIRROR HEX 0000
x_scroll_idx HEX 0000
scroll_src_bank dfb $51    ; current source bank for scroll fill
draw_bank da $00E1         ; bank for DUMP01 destination (default $E1 = screen)
scroll_src_off HEX 0000   ; byte offset within source bank scanline

IMAGE01_X HEX 0B00
IMAGE01_Y HEX 2800
IMAGE01
 HEX AAAAAAAAAAA0FFFFFFAAAA
 HEX AAAAAAAAAA0FFFF2F2FFAA
 HEX AAAAAAAAAAFF0F0FFF2FAA
 HEX AAAAAAAAA0FF000F0FFFAA
 HEX AAAAAAAAA0FF0F000FFAAA
 HEX AAAAAAAAA0FF0F2F000AAA
 HEX AAAAAAAAA0F00F00F0AAAA
 HEX AAAAAAAAA0F0F22F20AAAA
 HEX AAAAAAA00000F22F00AAAA
 HEX AAAAAA0F2F000FFF0AAAAA
 HEX AAAAA0F222F000000AAAAA
 HEX AAAAA02222F000F220AAAA
 HEX AAAAA02222F00F22220AAA
 HEX AAAAA0F222000F22220AAA
 HEX AAAAA0F22F00FFF2220AAA
 HEX AAAAA00F202222FFF0AAAA
 HEX AAAAAA0022222200AAAAAA
 HEX AAAAAA0022222F00AAAAAA
 HEX AAAAAA00F22220C0AAAAAA
 HEX AAAAAA0C0FFF0C0AAAAAAA
 HEX AAAAAAA00000CC0AAAAAAA
 HEX AAAAAAA0CCBBBC0AAAAAAA
 HEX AAAAAA0CCC0CC000AAAAAA
 HEX AAAAAA0CCCC00000AAAAAA
 HEX AAAAAA0CCBBCC00AAAAAAA
 HEX AAAAAA0CCCBBC00AAAAAAA
 HEX AAAAAA00CCCBBC0AAAAAAA
 HEX AAAAAA000CCCBC0AAAAAAA
 HEX AAAAA00000CCCCC0AAAAAA
 HEX AAAAA0C0000CCBC0AAAAAA
 HEX AAAA00CC00A0BBC0AAAAAA
 HEX AAAA000000A00C00AAAAAA
 HEX AAAA022220A022F0AAAAAA
 HEX AAAA02220AA02220AAAAAA
 HEX AAA0F220AAA0F220AAAAAA
 HEX AAA0F20AAAAA0220AAAAAA
 HEX AA0F2F0AAAAA0FF0AAAAAA
 HEX AA0F2220AAAA022200AAAA
 HEX AAA0F2220AAA02F2220AAA
 HEX AAAA00000AAA0000000AAA
IMLEN01 EQU *-IMAGE01

IMAGE02_X HEX 0900
IMAGE02_Y HEX 2800
IMAGE02
 HEX AAAAAAA0FFFFFFAAAA
 HEX AAAAAA0FFFF2F2FFAA
 HEX AAAAAAFF0F0FFF2FAA
 HEX AAAAA0FF000F0FFFAA
 HEX AAAAA0FF0F000FFAAA
 HEX AAAAA0FF0F2F000AAA
 HEX AAAAA0F00F00F0AAAA
 HEX AAAAA0F0F22F20AAAA
 HEX AAA00000F22F00AAAA
 HEX AA0F2F000FFF0AAAAA
 HEX A0F222F000000AAAAA
 HEX A02222F000F220AAAA
 HEX A02222F00F22220AAA
 HEX A0F222000F22220AAA
 HEX A0F22F00FFF2220AAA
 HEX A00F202222FFF0AAAA
 HEX AA00222222000AAAAA
 HEX AA0022222F00AAAAAA
 HEX AA00F22220C0AAAAAA
 HEX AA0C0FFF0C0AAAAAAA
 HEX AAA00000CC0AAAAAAA
 HEX AAA0CCBBBC0AAAAAAA
 HEX AA0CCC0CC00AAAAAAA
 HEX AA0CCCC00C0AAAAAAA
 HEX AA0CBBC00C0AAAAAAA
 HEX AA0CCBB00C0AAAAAAA
 HEX AA0CCBBC0C0AAAAAAA
 HEX AA00CCBC000AAAAAAA
 HEX AAA0CCCCC00AAAAAAA
 HEX AAA000CBC00AAAAAAA
 HEX AAAA0CBBC00AAAAAAA
 HEX AAAA0000000AAAAAAA
 HEX AAA0222F00AAAAAAAA
 HEX AAA022F00AAAAAAAAA
 HEX AA022F00AAAAAAAAAA
 HEX A0FF20F0AAAAAAAAAA
 HEX A022F0F0AAAAAAAAAA
 HEX AA022F020AAAAAAAAA
 HEX AAA022F020AAAAAAAA
 HEX AAAA000000AAAAAAAA
IMLEN02 EQU *-IMAGE02

IMAGE03_X HEX 0C00
IMAGE03_Y HEX 2800
IMAGE03
 HEX AAAAAAAAAAA0FFFFFFAAAAAA
 HEX AAAAAAAAAA0FFFF2F2FFAAAA
 HEX AAAAAAAAAAFF0F0FFF2FAAAA
 HEX AAAAAAAAA0FF000F0FFFAAAA
 HEX AAAAAAAAA0FF0F000FFAAAAA
 HEX AAAAAAAAA0FF0F2F000AAAAA
 HEX AAAAAAAAA0F00F00F0AAAAAA
 HEX AAAAAAAAA0F0F22F20AAAAAA
 HEX AAAAAAA00000F22F00AAAAAA
 HEX AAAAAA0F2F000FFF0AAAAAAA
 HEX AAAAA0F222F000000AAAAAAA
 HEX AAAAA02222F000F220AAAAAA
 HEX AAAAA02222F00F22220AAAAA
 HEX AAAAA0F222000F22220AAAAA
 HEX AAAAA0F22F00FFF2220AAAAA
 HEX AAAAA00F202222FFF0AAAAAA
 HEX AAAAAA0022222200AAAAAAAA
 HEX AAAAAA0022222F00AAAAAAAA
 HEX AAAAAA00F22220C0AAAAAAAA
 HEX AAAAAA0C0FFF0C0AAAAAAAAA
 HEX AAAAAAA00000CC0AAAAAAAAA
 HEX AAAAAAA0CCBBBC0AAAAAAAAA
 HEX AAAAAA0CCC0CC000AAAAAAAA
 HEX AAAAAA0CCCC00000AAAAAAAA
 HEX AAAAA00CBBC00CBC0AAAAAAA
 HEX AAAAA0CCBBC0CCBB0AAAAAAA
 HEX AAAAA0CBBC000CCBC0AAAAAA
 HEX AAAAA0CBBC0A00CCB0AAAAAA
 HEX AAAA00CCC0AAA0CCCC0AAAAA
 HEX AAAA0CBBC0AAAA0CBB0AAAAA
 HEX AAAA0CBC0AAAAA0CCC0AAAAA
 HEX AAAA00000AAAAA00C00AAAAA
 HEX AAA022220AAAAA022F0AAAAA
 HEX AAA02220AAAAAA02220AAAAA
 HEX AA0F220AAAAAAA0F220AAAAA
 HEX AA0F20AAAAAAAAA0220AAAAA
 HEX A0F2F0AAAAAAAAA0FF0AAAAA
 HEX A0F2220AAAAAAAA022200AAA
 HEX AA0F2220AAAAAAA02F2220AA
 HEX AAA00000AAAAAAA0000000AA
IMLEN03 EQU *-IMAGE03

JUMP1_Y HEX 2800
JUMP1_X HEX 0B00
JUMP1
 HEX AAAAAAAAAAAA0FFFFFFAAA
 HEX AAAAAAAAAAA0FFFF2F2FFA
 HEX AAAAAAAAAAAFF0F0FFF2FA
 HEX AAAAAAAAAA0FF000F0FFFA
 HEX AAAAAAAAAA0FF0F000FFAA
 HEX AAAAAAAAAA0FF0F2F000AA
 HEX AAAAAAAAAA0F00F00F0AAA
 HEX AAAAAAAAAA0F0F22F20AAA
 HEX AAAAAAAA00000F22F00AAA
 HEX AAAAAAA0F2F000FFF0AAAA
 HEX AAAAAA0F222F000000AAAA
 HEX AAAAAA02222F000F220AAA
 HEX AAAAAA02222F00F22220AA
 HEX AAAAAA0F222000F22220AA
 HEX AAAAAA0F22F00FFF2220AA
 HEX AAAAAA00F202222FFF0AAA
 HEX AAAAAAA0022222200AAAAA
 HEX AAAAAAA0022222F00AAAAA
 HEX AAAAAAA00F2222000AAAAA
 HEX AAAAAAA000FFF00000AAAA
 HEX AAAAAAA0CC0000CCB00AAA
 HEX AAAAAAA0CCCBBC0BBC00AA
 HEX AAAAAA00CC0000CCCBC0AA
 HEX AAAAAA0CBBCC00CCCBBC0A
 HEX AAAAAA0CBBBC000CCCBC0A
 HEX AAAAAA0CBBCC0000CCCC0A
 HEX AAAAAA0CBBC000000CC00A
 HEX AAAAAA0CCCC000000000AA
 HEX AAAAA00CBBC0000AAAAAAA
 HEX AAAAA0CCBC00BB0AAAAAAA
 HEX AAAAA0CCC0000B0AAAAAAA
 HEX AAAAA000000AA00AAAAAAA
 HEX AAAA022220AAAAAAAAAAAA
 HEX AAAA02220AAAAAAAAAAAAA
 HEX AAA0F220AAAAAAAAAAAAAA
 HEX AAA0F20AAAAAAAAAAAAAAA
 HEX AA0F2F0AAAAAAAAAAAAAAA
 HEX AA0F2220AAAAAAAAAAAAAA
 HEX AAA0F2220AAAAAAAAAAAAA
 HEX AAAA00000AAAAAAAAAAAAA
JUMPLEN01 EQU *-JUMP1

JUMP2_Y HEX 2A00
JUMP2_X HEX 1100
JUMP2
 HEX AAAA0FFFFFFAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAA0FFFF2F2FFAAAAAAAAAAAAAAAAAAAAA
 HEX AAAFF0F0FFF2FAAAAAAAAAAAAAAAAAAAAA
 HEX AA0FF000F0FFFAAAAAAAAAAAAAAAAAAAAA
 HEX AA0FF0F000FFAAAAAAAAAAAAAAAAAAAAAA
 HEX AA0FF0F2F000AAAAAAAAAAAAAAAAAAAAAA
 HEX AA0F00F00F0AAAAAAAAAAAAAAAAAAAAAAA
 HEX AA0F0F22F20AAAAAAAAAAAAAAAAAAAAAAA
 HEX AAA00F22F00000AAAAAAAAAAAAAAAAAAAA
 HEX AAAA0FFF000F2F0AAAAAAAAAAAAAAAAAAA
 HEX AAAA000000F222F0AAAAAAAAAAAAAAAAAA
 HEX AAA022F000F22220AAAAAAAAAAAAAAAAAA
 HEX AA02222F00F22220AAAAAAAAAAAAAAAAAA
 HEX AA02222F000222F0AAAAAAAAAAAAAAAAAA
 HEX AA0222FFF00F22F0AAAAAAAAAAAAAAAAAA
 HEX AAA0FFF222202F00AAAAAAAAAAAAAAAAAA
 HEX AAAA00022222200AAAAAAAAAAAAAAAAAAA
 HEX AAAAA00F22222000AAAAAAAAAAAAAAAAAA
 HEX AAAA00002222F0C000AAAAAAAAAAAAAAAA
 HEX AAA020200FFF0CCCCC0000AAAAAAAAAAAA
 HEX AAA0F020C000CC00BBBCC000AAAAAAAAAA
 HEX AAA020000CCCC00CCBBBCCCC00000000AA
 HEX AAA0FF00CC00000CCCCCCBC022F0F020AA
 HEX AAAA000FCCCC0000CCC0CCC0220FF020AA
 HEX AAAA00CC0000000000000CC02F0FF0F0AA
 HEX AAA00BCC022F0F020AAA0000000FF00AAA
 HEX AAA0CBCC0220FF020AAAAAAAAA000AAAAA
 HEX AAA0CCCC02F0FF0F0AAAAAAAAAAAAAAAAA
 HEX AAA00CCC0000FF00AAAAAAAAAAAAAAAAAA
 HEX AAAA00000AA000AAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
JUMPLEN02 EQU *-JUMP2

JUMP3_Y HEX 2000
JUMP3_X HEX 0E00
JUMP3
 HEX AAAAAAAAAAAAAAAAAA0FFFFFFAAA
 HEX AAAAAAAAAAAAAAAAA0FFFF2F2FFA
 HEX AAAAAAAAAAAAAAAAAFF0F0FFF2FA
 HEX AAAAAAAAAAAAAAAA0FF000F0FFFA
 HEX AAAAAAAAAAAAAAAA0FF0F000FFAA
 HEX AAAAAAAAAAAAAAAA0FF0F2F000AA
 HEX AAAAAAAAAAAAAAAA0F00F00F0AAA
 HEX AAAAAAAAAAAAAAAA0F0F22F20AAA
 HEX AAAAAAAAAAAAA000000022F00AAA
 HEX AAAAAAAAAAAA0F2200F0F2F0AAAA
 HEX AAAAAAAAAAA0F22220000FF0AAAA
 HEX AAAAAAAAAA0F222220F0000AAAAA
 HEX AAAAAAAAA0F22222202F0AAAAAAA
 HEX AAAAAAAAA02FF22F00220AAAAAAA
 HEX AAAAAAAAA0F22F000F2F0AAAAAAA
 HEX AAAAAAAAA0222F000220AAAAAAAA
 HEX AAAAAAAAA022220F000AAAAAAAAA
 HEX AAAAAAAAA0F22F0FF00AAAAAAAAA
 HEX AAAAAAAAA0FFF0000000000AAAAA
 HEX AAAAAAAAA0F2222000BBCCC0AAAA
 HEX AAAAAAAAA0F202020CCCCCBC0AAA
 HEX AAAAAAAAA00202020CC0CCBB0AAA
 HEX AAAAAAAAA00F0F0F00C0CCBC0AAA
 HEX AAAAAAAAA00000000000CCC00AAA
 HEX AAAAAAAAA0CCC00000000000AAAA
 HEX AAAA000AA0CBC000A002220AAAAA
 HEX AAA0F20000CBCC0AA0F220AAAAAA
 HEX AAA022F20CCBCC0AA0F2F0AAAAAA
 HEX AA0F22220CCCC0AAA0FF00AAAAAA
 HEX A0F2F0F20CCCC0AAA022200AAAAA
 HEX A02F000000CC00AAA02F2220AAAA
 HEX A000AAAA00000AAAA0000000AAAA
JUMPLEN03 EQU *-JUMP3

KICK1_Y HEX 2800
KICK1_X HEX 0A00
KICK1
 HEX AAAAAAAAAAFFFFFF0AAA
 HEX AAAAAAAAFF2F2FFFF0AA
 HEX AAAAAAAAF2FFF0F0FFAA
 HEX AAAAAAAAFFF0F000FF0A
 HEX AAAAAAAAAFF000F0FF0A
 HEX AAAAAAAAA000F2F0FF0A
 HEX AAAAAAAAAA0F00F00F0A
 HEX AAAAAAAAAA02F22F0F0A
 HEX AAAAAA00000F22F00AAA
 HEX AAAAA0F2F000FFF0AAAA
 HEX AAAA0F222F000000AAAA
 HEX AAAA02222F000F220AAA
 HEX AAAA02222F00F22220AA
 HEX AAAA0F222000F22220AA
 HEX AAAA0F22F00FFF2220AA
 HEX AAAA00F202222FFF0AAA
 HEX AAAA00022222200AAAAA
 HEX AAAA00022222F0AAAAAA
 HEX AAAA0C0F222200AAAAAA
 HEX AAAA0C00FFF00AAAAAAA
 HEX AAAAA000000C0AAAAAAA
 HEX AAAAA0CCBBBC0AAAAAAA
 HEX AAAA0CCC0CC00AAAAAAA
 HEX AAAA0CCCC00C0AAAAAAA
 HEX AAAAA0CBBC00C0AAAAAA
 HEX A000000CBB00C0AAAAAA
 HEX A022FF0CBBC0C0AAAAAA
 HEX A0F2220CCBC000AAAAAA
 HEX A022F20CCCCC00AAAAAA
 HEX A02F00000CBC00AAAAAA
 HEX A0108800CBBC00AAAAAA
 HEX A020AAA0000000AAAAAA
 HEX A00AAAA022220AAAAAAA
 HEX AAAAAAA02220AAAAAAAA
 HEX AAAAAA0F220AAAAAAAAA
 HEX AAAAAA0F20AAAAAAAAAA
 HEX AAAAA0F2F0AAAAAAAAAA
 HEX AAAAA0F2220AAAAAAAAA
 HEX AAAAAA0F2220AAAAAAAA
 HEX AAAAAAA00000AAAAAAAA
KICK1LEN EQU *-KICK1

KICK2_Y HEX 2800
KICK2_X HEX 1500
KICK2
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA0FFFFAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA0FFF2FFAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA00F2FFF0AA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA000F02F0AA
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAAAA00000F000FFF0A
 HEX AAAAAAAAAAAAAAAAAAAAAAAAAA00F220FFF000FF0A
 HEX AAAAAAAAAAAAAAAAAAAAAAAAA00F22220F2F00FF0A
 HEX AAAAAAAAAAAAAAAAAAAAAAAA0C022222022F00FF0A
 HEX AAAAAAAAAAAAAAAAAAAA0000CC0222220FFF0F000A
 HEX AA000000000000AAAAA0C000CC02FF2F00000000AA
 HEX AA020F0F220CC0000000CB0CCC00222F00FF000AAA
 HEX AA020FF0220CCC0CCC000CCCC00F2222FF22F0AAAA
 HEX AA0F0FF0F20CBCCCCCCC0000000F22222F2220AAAA
 HEX AAA00FF000CCCCBBBCCCC000000F22222F2220AAAA
 HEX AAAAA000AA000CCBBBC0CBCC0000F222FFF0F0AAAA
 HEX AAAAAAAAAAAA0000CCCC0CBCC000000000000AAAAA
 HEX AAAAAAAAAAAAAAAA000C00CBC0AAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAA0CC0CCC0AAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAA0CBBC00AAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAA0CBBCC0AAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAA00CBBC0AAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAA0CBBC0AAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAA0CCC00AAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAA0CBBC0AAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAA0CBC0AAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAA00000AAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAA022F0AAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAA02220AAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAA0F220AAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAA0220AAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAA0FF0AAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAA022200AAAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAA02F2220AAAAAAAAAAAA
 HEX AAAAAAAAAAAAAAAAAAAAAAA0000000AAAAAAAAAAAA
KICK2LEN EQU *-KICK2

PUNCH11_Y HEX 2800
PUNCH11_X HEX 0C00
PUNCH11
 HEX AAAAAAAAA0FFFFFFAAAAAAAA
 HEX AAAAAAAA0FFFF2F2FFAAAAAA
 HEX AAAAAAAAFF0F0FFF2FAAAAAA
 HEX AAAAAAA0FF000F0FFFAAAAAA
 HEX AAAAAAA0FF0F000FFAAAAAAA
 HEX AAAAAAA0FF0F2F000AAAAAAA
 HEX AAAAAAA0F00F00F0AAAAAAAA
 HEX AAAAAAA0F0F22F20AAAAAAAA
 HEX AAAAAA0000F22F00000AAAAA
 HEX AAAAA0CC000FF00002220AAA
 HEX AAAA0CCCF0000FF2F22220AA
 HEX AAAA0CBC1F0F2222F22220AA
 HEX AAA0CBBC0F222222F20F20AA
 HEX AAA0CBCC0222222F00F20AAA
 HEX AAA0CBCC022222F0A000AAAA
 HEX AA00CCCC0F222F0AAAAAAAAA
 HEX AA0000CCC0FFF0AAAAAAAAAA
 HEX AA00C000CCC000AAAAAAAAAA
 HEX A0CCBCCCCCC00AAAAAAAAAAA
 HEX A00CCBBCCC00AAAAAAAAAAAA
 HEX AA0000000000AAAAAAAAAAAA
 HEX AAA00000CC00AAAAAAAAAAAA
 HEX AAA00CCCCCC0AAAAAAAAAAAA
 HEX AAA00CCCCCC0AAAAAAAAAAAA
 HEX AAAAA0CCBBCC00AAAAAAAAAA
 HEX AAAAA0CCCBBC00AAAAAAAAAA
 HEX AAAAA00CCCBBC0AAAAAAAAAA
 HEX AAAAA000CCCBC0AAAAAAAAAA
 HEX AAAA00000CCCCC0AAAAAAAAA
 HEX AAAA0C0000CCBC0AAAAAAAAA
 HEX AAA00CC00A0BBC0AAAAAAAAA
 HEX AAA000000A00C00AAAAAAAAA
 HEX AAA022220A022F0AAAAAAAAA
 HEX AAA02220AA02220AAAAAAAAA
 HEX AA0F220AAA0F220AAAAAAAAA
 HEX AA0F20AAAAA0220AAAAAAAAA
 HEX A0F2F0AAAAA0FF0AAAAAAAAA
 HEX A0F2220AAAA022200AAAAAAA
 HEX AA0F2220AAA02F2220AAAAAA
 HEX AAA00000AAA0000000AAAAAA
PUNCH11LEN EQU *-PUNCH11

PUNCH12_Y HEX 2800
PUNCH12_X HEX 1100
PUNCH12
 HEX AAAAAAAAAAA0FFFFFFAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAA0FFFF2F2FFAAAAAAAAAAAAAA
 HEX AAAAAAAAAAFF0F0FFF2FAAAAAAAAAAAAAA
 HEX AAAAAAAAA0FF000F0FFFAAAAAAAAAAAAAA
 HEX AAAAAAAAA0FF0F000FFAAAAAAAAAAAAAAA
 HEX AAAAAAAAA0FF0F2F000AAAAAAAAAAAAAAA
 HEX AAAAAAAAA0F00F00F0AAAAAAAAAAAAAAAA
 HEX AAAAAAAAA0F0F22F0000000000000AAAAA
 HEX AAAAAAAA000000000FFFFFF22F02220AAA
 HEX AAAAAAA000CCCCC0F2222F2222F22220AA
 HEX AAAAA0FF0CCCCBC02222222222F22220AA
 HEX AAAA02200CCCBBC02222222222F20F20AA
 HEX AAA022F0CCC0BBC0222222F2F000F20AAA
 HEX AAA02200CCC0CBC0F22FF000AAA000AAAA
 HEX AAAA0F00CCC0CCC000000AAAAAAAAAAAAA
 HEX AAAA0000CCC000CCAAAAAAAAAAAAAAAAAA
 HEX AAAA0000CCCCCCC0AAAAAAAAAAAAAAAAAA
 HEX AAAA00C000CCC000AAAAAAAAAAAAAAAAAA
 HEX AAA0CCBCCCCCC00AAAAAAAAAAAAAAAAAAA
 HEX AAA00CCBBCCC00AAAAAAAAAAAAAAAAAAAA
 HEX AAAA0000000000AAAAAAAAAAAAAAAAAAAA
 HEX AAAAA00000CC00AAAAAAAAAAAAAAAAAAAA
 HEX AAAAA00CCCCCC0AAAAAAAAAAAAAAAAAAAA
 HEX AAAAA00CCCCCC0AAAAAAAAAAAAAAAAAAAA
 HEX AAAAA0CCBBCC00AAAAAAAAAAAAAAAAAAAA
 HEX AAAAA0CCCBBC00AAAAAAAAAAAAAAAAAAAA
 HEX AAAAA00CCCBBC0AAAAAAAAAAAAAAAAAAAA
 HEX AAAAA000CCCBC0AAAAAAAAAAAAAAAAAAAA
 HEX AAAA00000CCCCC0AAAAAAAAAAAAAAAAAAA
 HEX AAAA0C0000CCBC0AAAAAAAAAAAAAAAAAAA
 HEX AAA00CC00A0BBC0AAAAAAAAAAAAAAAAAAA
 HEX AAA000000A00C00AAAAAAAAAAAAAAAAAAA
 HEX AAA022220A022F0AAAAAAAAAAAAAAAAAAA
 HEX AAA02220AA02220AAAAAAAAAAAAAAAAAAA
 HEX AA0F220AAA0F220AAAAAAAAAAAAAAAAAAA
 HEX AA0F20AAAAA0220AAAAAAAAAAAAAAAAAAA
 HEX A0F2F0AAAAA0FF0AAAAAAAAAAAAAAAAAAA
 HEX A0F2220AAAA022200AAAAAAAAAAAAAAAAA
 HEX AA0F2220AAA02F2220AAAAAAAAAAAAAAAA
 HEX AAA00000AAA0000000AAAAAAAAAAAAAAAA
PUNCH12LEN EQU *-PUNCH12

PUNCH21_Y HEX 2800
PUNCH21_X HEX 0B00
PUNCH21
 HEX AAAAAAAAA0FFFFFFAAAAAA
 HEX AAAAAAAA0FFFF2F2FFAAAA
 HEX AAAAAAAAFF0F0FFF2FAAAA
 HEX AAAAAAA0FF000F0FFFAAAA
 HEX AAAAAAA0FF0F000FF0AAAA
 HEX AAAAAAA0FF0F2F000220AA
 HEX AAAAAAA0F00F00F022220A
 HEX AAAAAAA0F0F22F202F220A
 HEX AAAAA00000F22F002FF20A
 HEX AAAA0F2F000FFF0F22F0AA
 HEX AAA0F222F000000A000AAA
 HEX AAA02222F000F220AAAAAA
 HEX AAA02222F00F22220AAAAA
 HEX AAA0F222000F22220AAAAA
 HEX AAA0F22F00FFF2220AAAAA
 HEX AAA00F202222FFF0AAAAAA
 HEX AAAA0002222220C0AAAAAA
 HEX AAAA00022222F0C0AAAAAA
 HEX AAAA0C0F222200C0AAAAAA
 HEX AAAA0C00FFF00000AAAAAA
 HEX AAAAA00000000A00AAAAAA
 HEX AAAAA0CCBCC00AAAAAAAAA
 HEX AAAA0CCC0CC0AAAAAAAAAA
 HEX AAAA0CCCCCC0AAAAAAAAAA
 HEX AAAAA0CCBBCC00AAAAAAAA
 HEX AAAAA0CCCBBC00AAAAAAAA
 HEX AAAAA00CCCBBC0AAAAAAAA
 HEX AAAAA000CCCBC0AAAAAAAA
 HEX AAAA00000CCCCC0AAAAAAA
 HEX AAAA0C0000CCBC0AAAAAAA
 HEX AAA00CC00A0BBC0AAAAAAA
 HEX AAA000000A00C00AAAAAAA
 HEX AAA022220A022F0AAAAAAA
 HEX AAA02220AA02220AAAAAAA
 HEX AA0F220AAA0F220AAAAAAA
 HEX AA0F20AAAAA0220AAAAAAA
 HEX A0F2F0AAAAA0FF0AAAAAAA
 HEX A0F2220AAAA022200AAAAA
 HEX AA0F2220AAA02F2220AAAA
 HEX AAA00000AAA0000000AAAA
PUNCH21LEN EQU *-PUNCH21

PUNCH22_Y HEX 2800
PUNCH22_X HEX 1200
PUNCH22
 HEX AAAAAAAAAAAA0FFFFFFAAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAA0FFFF2F2FFAAAAAAAAAAAAAAA
 HEX AAAAAAAAAAAFF0F0FFF2FAAAAAAAAAAAAAAA
 HEX AAAAAAAAAA0FF000F0FFFAAAAAAAAAAAAAAA
 HEX AAAAAAAAAA0FF0F000FFAAAAAAAAAAAAAAAA
 HEX AAAAAAAAAA0FF0F2F0000AAAAA00000AAAAA
 HEX AAAAAAAAAA0F00F00F002000F22202220AAA
 HEX AAAAAAAAAA0F0F22F202222F2220222220AA
 HEX AAAAAAAA00000F22F0022222222022F220AA
 HEX AAAAAAA0F2F000FFF0F22222222022FF20AA
 HEX AAAAAA0F222F000000FF222022F0022F0AAA
 HEX AAAAAA02222F000F220FFFFF00AAA000AAAA
 HEX AAAAAA02222F00F222200000AAAAAAAAAAAA
 HEX AAAAAA0F222000F22220AAAAAAAAAAAAAAAA
 HEX AAAAAA0F22F00FFF2220AAAAAAAAAAAAAAAA
 HEX AAAAAA00F202222FFF00AAAAAAAAAAAAAAAA
 HEX AAAAAA0002222220C0AAAAAAAAAAAAAAAAAA
 HEX AAAAAA00022222F0C0AAAAAAAAAAAAAAAAAA
 HEX AAAAAA0C0F222200C0AAAAAAAAAAAAAAAAAA
 HEX AAAAAA0C00FFF00000AAAAAAAAAAAAAAAAAA
 HEX AAAAAAA00000000A00AAAAAAAAAAAAAAAAAA
 HEX AAAAAAA0CCBCC00AAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAA0CCC0CC0AAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAA0CCCCCC0AAAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAA0CCBBCC00AAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAA0CCCBBC00AAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAA00CCCBBC0AAAAAAAAAAAAAAAAAAAAA
 HEX AAAAAA000CCCBC0AAAAAAAAAAAAAAAAAAAAA
 HEX AAAAA00000CCCCC0AAAAAAAAAAAAAAAAAAAA
 HEX AAAAA0C0000CCBC0AAAAAAAAAAAAAAAAAAAA
 HEX AAAA00CC00A0BBC0AAAAAAAAAAAAAAAAAAAA
 HEX AAAA000000A00C00AAAAAAAAAAAAAAAAAAAA
 HEX AAAA022220A022F0AAAAAAAAAAAAAAAAAAAA
 HEX AAAA02220AA02220AAAAAAAAAAAAAAAAAAAA
 HEX AAA0F220AAA0F220AAAAAAAAAAAAAAAAAAAA
 HEX AAA0F20AAAAA0220AAAAAAAAAAAAAAAAAAAA
 HEX AA0F2F0AAAAA0FF0AAAAAAAAAAAAAAAAAAAA
 HEX AA0F2220AAAA022200AAAAAAAAAAAAAAAAAA
 HEX AAA0F2220AAA02F2220AAAAAAAAAAAAAAAAA
 HEX AAAA00000AAA0000000AAAAAAAAAAAAAAAAA
PUNCH22LEN EQU *-PUNCH22

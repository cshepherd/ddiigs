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

* Load background from MISSION11.SHR -> $01/2000 (shadowed to $E1) and $50/2000
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
* Plot WILLIAM1 mirrored at $80,$64
 lda #$EE
 sta MASK
 lda #$E0
 sta MASKHI
 lda #$0E
 sta MASKLO
 lda #$64
 sta IMAGE01_YPOS
 lda #$60
 sta IMAGE01_XPOS
 lda #$01
 sta IMAGE01_MIRROR
 lda WILLIAM1_X
 sta FRAME_X
 lda WILLIAM1_Y
 sta FRAME_Y
 lda #<WILLIAM1
 sta FRAME_ADDR
 lda #>WILLIAM1
 sta FRAME_ADDR+1
 jsr DUMP01

* Restore Billy's mask and position for main loop
 lda #$66
 sta MASK
 lda #$60
 sta MASKHI
 lda #$06
 sta MASKLO
 lda #$64
 sta IMAGE01_YPOS
 lda #$01
 sta IMAGE01_XPOS
 stz IMAGE01_MIRROR
 lda FRAME_X_TBL
 sta FRAME_X
 lda FRAME_Y_TBL
 sta FRAME_Y
 lda FRAME_ADDR_TBL
 sta FRAME_ADDR
 lda FRAME_ADDR_TBL+1
 sta FRAME_ADDR+1
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
* copy_chunk - Copy 4KB from ]RDBUF to $01/dest and $50/dest
* Uses ZP $F0-$F5 for indirect long pointers.
*----------------------------------------------------------
copy_chunk
 clc
 xce                   ; switch to native mode
 rep $30               ; 16-bit A and index

 lda dest
 sta $F0               ; $01 destination low/high
 sta $F3               ; $50 destination low/high
 sep $20
 lda #$01
 sta $F2               ; $01 bank byte (shadowed to $E1)
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
 lda #$10             ; JUMP2_X = widest jump sprite (16 bytes)
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
 lda #$10             ; widest jump sprite
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
JUMP_X_TBL   dfb $0B,$10,$0E         ; JUMP1_X, JUMP2_X, JUMP3_X
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
 lda #$11             ; widest punch sprite (PUNCH22 = $11)
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

PUNCH1_X_TBL   dfb $0B,$10
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
 lda #$11             ; widest punch sprite (PUNCH22 = $11)
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

PUNCH2_X_TBL   dfb $0B,$11
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
FRAME_X  HEX 0A00         ; current frame width (init to IMAGE01)
FRAME_Y  HEX 2800         ; current frame height (init to IMAGE01)
FRAME_ADDR DA IMAGE01     ; current frame data address (init to IMAGE01)

*-------------------------------
* Animation lookup tables
* Sequence: IMAGE01, IMAGE02, IMAGE03, IMAGE02
*-------------------------------
FRAME_X_TBL HEX 0A080B08
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
draw_bank da $0001         ; bank for DUMP01 destination (default $01, shadowed to $E1)
scroll_src_off HEX 0000   ; byte offset within source bank scanline
MASKHI HEX 60
MASKLO HEX 06
MASK HEX 66

**
** BILLY sprites (note mask color is 6)
**

IMAGE01_X HEX 0A00
IMAGE01_Y HEX 2800
IMAGE01
 HEX 666666666660FFFFFF66
 HEX 66666666660FFFF2F2FF
 HEX 6666666666FF0F0FFF2F
 HEX 6666666660FF000F0FFF
 HEX 6666666660FF0F000FF6
 HEX 6666666660FF0F2F0006
 HEX 6666666660F00F00F066
 HEX 6666666660F0F22F2066
 HEX 666666600000F22F0066
 HEX 6666660F2F000FFF0666
 HEX 666660F222F000000666
 HEX 6666602222F000F22066
 HEX 6666602222F00F222206
 HEX 666660F222000F222206
 HEX 666660F22F00FFF22206
 HEX 6666600F202222FFF066
 HEX 66666600222222006666
 HEX 6666660022222F006666
 HEX 66666600F22220A06666
 HEX 6666660A0FFF0A066666
 HEX 666666600000AA066666
 HEX 66666660AA999A066666
 HEX 6666660AAA0AA0006666
 HEX 6666660AAAA000006666
 HEX 6666660AA99AA0066666
 HEX 6666660AAA99A0066666
 HEX 66666600AAA99A066666
 HEX 666666000AAA9A066666
 HEX 6666600000AAAAA06666
 HEX 666660A0000AA9A06666
 HEX 666600AA006099A06666
 HEX 6666000000600A006666
 HEX 66660222206022F06666
 HEX 66660222066022206666
 HEX 6660F2206660F2206666
 HEX 6660F206666602206666
 HEX 660F2F0666660FF06666
 HEX 660F2220666602220066
 HEX 6660F222066602F22206
 HEX 66660000066600000006
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
JUMP1_X HEX 0B00
JUMP1
 HEX 6666666666660FFFFFF666
 HEX 666666666660FFFF2F2FF6
 HEX 66666666666FF0F0FFF2F6
 HEX 66666666660FF000F0FFF6
 HEX 66666666660FF0F000FF66
 HEX 66666666660FF0F2F00066
 HEX 66666666660F00F00F0666
 HEX 66666666660F0F22F20666
 HEX 6666666600000F22F00666
 HEX 66666660F2F000FFF06666
 HEX 6666660F222F0000006666
 HEX 66666602222F000F220666
 HEX 66666602222F00F2222066
 HEX 6666660F222000F2222066
 HEX 6666660F22F00FFF222066
 HEX 66666600F202222FFF0666
 HEX 6666666002222220066666
 HEX 66666660022222F0066666
 HEX 666666600F222200066666
 HEX 6666666000FFF000006666
 HEX 66666660AA0000AA900666
 HEX 66666660AAA99A099A0066
 HEX 66666600AA0000AAA9A066
 HEX 6666660A99AA00AAA99A06
 HEX 6666660A999A000AAA9A06
 HEX 6666660A99AA0000AAAA06
 HEX 6666660A99A000000AA006
 HEX 6666660AAAA00000000066
 HEX 6666600A99A00006666666
 HEX 666660AA9A009906666666
 HEX 666660AAA0000906666666
 HEX 6666600000066006666666
 HEX 6666022220666666666666
 HEX 6666022206666666666666
 HEX 6660F22066666666666666
 HEX 6660F20666666666666666
 HEX 660F2F0666666666666666
 HEX 660F222066666666666666
 HEX 6660F22206666666666666
 HEX 6666000006666666666666
JUMPLEN01 EQU *-JUMP1

JUMP2_Y HEX 2A00
JUMP2_X HEX 1000
JUMP2
 HEX 66660FFFFFF666666666666666666666
 HEX 6660FFFF2F2FF6666666666666666666
 HEX 666FF0F0FFF2F6666666666666666666
 HEX 660FF000F0FFF6666666666666666666
 HEX 660FF0F000FF66666666666666666666
 HEX 660FF0F2F00066666666666666666666
 HEX 660F00F00F0666666666666666666666
 HEX 660F0F22F20666666666666666666666
 HEX 66600F22F00000666666666666666666
 HEX 66660FFF000F2F066666666666666666
 HEX 6666000000F222F06666666666666666
 HEX 666022F000F222206666666666666666
 HEX 6602222F00F222206666666666666666
 HEX 6602222F000222F06666666666666666
 HEX 660222FFF00F22F06666666666666666
 HEX 6660FFF222202F006666666666666666
 HEX 66660002222220066666666666666666
 HEX 6666600F222220006666666666666666
 HEX 666600002222F0A00066666666666666
 HEX 666020200FFF0AAAAA00006666666666
 HEX 6660F020A000AA00999AA00066666666
 HEX 666020000AAAA00AA999AAAA00000000
 HEX 6660FF00AA00000AAAAAA9A022F0F020
 HEX 6666000FAAAA0000AAA0AAA0220FF020
 HEX 666600AA0000000000000AA02F0FF0F0
 HEX 666009AA022F0F0206660000000FF006
 HEX 6660A9AA0220FF020666666666000666
 HEX 6660AAAA02F0FF0F0666666666666666
 HEX 66600AAA0000FF006666666666666666
 HEX 66660000066000666666666666666666
 HEX 66666666666666666666666666666666
 HEX 66666666666666666666666666666666
 HEX 66666666666666666666666666666666
 HEX 66666666666666666666666666666666
 HEX 66666666666666666666666666666666
 HEX 66666666666666666666666666666666
 HEX 66666666666666666666666666666666
 HEX 66666666666666666666666666666666
 HEX 66666666666666666666666666666666
 HEX 66666666666666666666666666666666
 HEX 66666666666666666666666666666666
 HEX 66666666666666666666666666666666
JUMPLEN02 EQU *-JUMP2

JUMP3_Y HEX 2000
JUMP3_X HEX 0E00
JUMP3
 HEX 6666666666666666660FFFFFF666
 HEX 666666666666666660FFFF2F2FF6
 HEX 66666666666666666FF0F0FFF2F6
 HEX 66666666666666660FF000F0FFF6
 HEX 66666666666666660FF0F000FF66
 HEX 66666666666666660FF0F2F00066
 HEX 66666666666666660F00F00F0666
 HEX 66666666666666660F0F22F20666
 HEX 6666666666666000000022F00666
 HEX 6666666666660F2200F0F2F06666
 HEX 666666666660F22220000FF06666
 HEX 66666666660F222220F000066666
 HEX 6666666660F22222202F06666666
 HEX 66666666602FF22F002206666666
 HEX 6666666660F22F000F2F06666666
 HEX 6666666660222F00022066666666
 HEX 666666666022220F000666666666
 HEX 6666666660F22F0FF00666666666
 HEX 6666666660FFF000000000066666
 HEX 6666666660F222200099AAA06666
 HEX 6666666660F202020AAAAA9A0666
 HEX 66666666600202020AA0AA990666
 HEX 66666666600F0F0F00A0AA9A0666
 HEX 66666666600000000000AAA00666
 HEX 6666666660AAA000000000006666
 HEX 6666000660A9A000600222066666
 HEX 6660F20000A9AA0660F220666666
 HEX 666022F20AA9AA0660F2F0666666
 HEX 660F22220AAAA06660FF00666666
 HEX 60F2F0F20AAAA066602220066666
 HEX 602F000000AA0066602F22206666
 HEX 6000666600000666600000006666
JUMPLEN03 EQU *-JUMP3

KICK1_Y HEX 2800
KICK1_X HEX 0A00
KICK1
 HEX 6666666666FFFFFF0666
 HEX 66666666FF2F2FFFF066
 HEX 66666666F2FFF0F0FF66
 HEX 66666666FFF0F000FF06
 HEX 666666666FF000F0FF06
 HEX 666666666000F2F0FF06
 HEX 66666666660F00F00F06
 HEX 666666666602F22F0F06
 HEX 66666600000F22F00666
 HEX 666660F2F000FFF06666
 HEX 66660F222F0000006666
 HEX 666602222F000F220666
 HEX 666602222F00F2222066
 HEX 66660F222000F2222066
 HEX 66660F22F00FFF222066
 HEX 666600F202222FFF0666
 HEX 66660002222220066666
 HEX 666600022222F0666666
 HEX 66660A0F222200666666
 HEX 66660A00FFF006666666
 HEX 66666000000A06666666
 HEX 666660AA999A06666666
 HEX 66660AAA0AA006666666
 HEX 66660AAAA00A06666666
 HEX 666660A99A00A0666666
 HEX 6000000A9900A0666666
 HEX 6022FF0A99A0A0666666
 HEX 60F2220AA9A000666666
 HEX 6022F20AAAAA00666666
 HEX 602F00000A9A00666666
 HEX 60108800A99A00666666
 HEX 60206660000000666666
 HEX 60066660222206666666
 HEX 66666660222066666666
 HEX 6666660F220666666666
 HEX 6666660F206666666666
 HEX 666660F2F06666666666
 HEX 666660F2220666666666
 HEX 6666660F222066666666
 HEX 66666660000066666666
KICK1LEN EQU *-KICK1

KICK2_Y HEX 2800
KICK2_X HEX 1500
KICK2
 HEX 666666666666666666666666666666666666666666
 HEX 666666666666666666666666666666666666666666
 HEX 666666666666666666666666666666666666666666
 HEX 666666666666666666666666666666666666666666
 HEX 666666666666666666666666666666666666666666
 HEX 666666666666666666666666666666666666666666
 HEX 6666666666666666666666666666666660FFFF6666
 HEX 666666666666666666666666666666660FFF2FF666
 HEX 6666666666666666666666666666666600F2FFF066
 HEX 66666666666666666666666666666666000F02F066
 HEX 666666666666666666666666666600000F000FFF06
 HEX 6666666666666666666666666600F220FFF000FF06
 HEX 666666666666666666666666600F22220F2F00FF06
 HEX 6666666666666666666666660A022222022F00FF06
 HEX 666666666666666666660000AA0222220FFF0F0006
 HEX 66000000000000666660A000AA02FF2F0000000066
 HEX 66020F0F220AA0000000A90AAA00222F00FF000666
 HEX 66020FF0220AAA0AAA000AAAA00F2222FF22F06666
 HEX 660F0FF0F20A9AAAAAAA0000000F22222F22206666
 HEX 66600FF000AAAA999AAAA000000F22222F22206666
 HEX 6666600066000AA999A0A9AA0000F222FFF0F06666
 HEX 6666666666660000AAAA0A9AA00000000000066666
 HEX 6666666666666666000A00A9A06666666666666666
 HEX 6666666666666666660AA0AAA06666666666666666
 HEX 66666666666666666660A99A006666666666666666
 HEX 66666666666666666660A99AA06666666666666666
 HEX 666666666666666666600A99A06666666666666666
 HEX 666666666666666666660A99A06666666666666666
 HEX 6666666666666666666660AAA00666666666666666
 HEX 6666666666666666666660A99A0666666666666666
 HEX 66666666666666666666660A9A0666666666666666
 HEX 666666666666666666666600000666666666666666
 HEX 6666666666666666666666022F0666666666666666
 HEX 666666666666666666666602220666666666666666
 HEX 66666666666666666666660F220666666666666666
 HEX 666666666666666666666660220666666666666666
 HEX 666666666666666666666660FF0666666666666666
 HEX 666666666666666666666660222006666666666666
 HEX 6666666666666666666666602F2220666666666666
 HEX 666666666666666666666660000000666666666666
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
PUNCH21_X HEX 0B00
PUNCH21
 HEX 6666666660FFFFFF666666
 HEX 666666660FFFF2F2FF6666
 HEX 66666666FF0F0FFF2F6666
 HEX 66666660FF000F0FFF6666
 HEX 66666660FF0F000FF06666
 HEX 66666660FF0F2F00022066
 HEX 66666660F00F00F0222206
 HEX 66666660F0F22F202F2206
 HEX 6666600000F22F002FF206
 HEX 66660F2F000FFF0F22F066
 HEX 6660F222F0000006000666
 HEX 66602222F000F220666666
 HEX 66602222F00F2222066666
 HEX 6660F222000F2222066666
 HEX 6660F22F00FFF222066666
 HEX 66600F202222FFF0666666
 HEX 66660002222220A0666666
 HEX 666600022222F0A0666666
 HEX 66660A0F222200A0666666
 HEX 66660A00FFF00000666666
 HEX 6666600000000600666666
 HEX 666660AA9AA00666666666
 HEX 66660AAA0AA06666666666
 HEX 66660AAAAAA06666666666
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
PUNCH21LEN EQU *-PUNCH21

PUNCH22_Y HEX 2800
PUNCH22_X HEX 1100
PUNCH22
 HEX 6666666666660FFFFFF666666666666666
 HEX 666666666660FFFF2F2FF6666666666666
 HEX 66666666666FF0F0FFF2F6666666666666
 HEX 66666666660FF000F0FFF6666666666666
 HEX 66666666660FF0F000FF66666666666666
 HEX 66666666660FF0F2F00006666600000666
 HEX 66666666660F00F00F002000F222022206
 HEX 66666666660F0F22F202222F2220222220
 HEX 6666666600000F22F0022222222022F220
 HEX 66666660F2F000FFF0F22222222022FF20
 HEX 6666660F222F000000FF222022F0022F06
 HEX 66666602222F000F220FFFFF0066600066
 HEX 66666602222F00F2222000006666666666
 HEX 6666660F222000F2222066666666666666
 HEX 6666660F22F00FFF222066666666666666
 HEX 66666600F202222FFF0066666666666666
 HEX 6666660002222220A06666666666666666
 HEX 66666600022222F0A06666666666666666
 HEX 6666660A0F222200A06666666666666666
 HEX 6666660A00FFF000006666666666666666
 HEX 6666666000000006006666666666666666
 HEX 66666660AA9AA006666666666666666666
 HEX 6666660AAA0AA066666666666666666666
 HEX 6666660AAAAAA066666666666666666666
 HEX 6666660AA99AA006666666666666666666
 HEX 6666660AAA99A006666666666666666666
 HEX 66666600AAA99A06666666666666666666
 HEX 666666000AAA9A06666666666666666666
 HEX 6666600000AAAAA0666666666666666666
 HEX 666660A0000AA9A0666666666666666666
 HEX 666600AA006099A0666666666666666666
 HEX 6666000000600A00666666666666666666
 HEX 66660222206022F0666666666666666666
 HEX 6666022206602220666666666666666666
 HEX 6660F2206660F220666666666666666666
 HEX 6660F20666660220666666666666666666
 HEX 660F2F0666660FF0666666666666666666
 HEX 660F222066660222006666666666666666
 HEX 6660F222066602F2220666666666666666
 HEX 6666000006660000000666666666666666
PUNCH22LEN EQU *-PUNCH22

**
** WILLIAM sprites (note William's mask color is E not 6)
**

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
WILLIAM2_X HEX 0A00
WILLIAM2
 HEX 44444444000404040444
 HEX 44444440F0F0F0F0F044
 HEX 44444440FFFFFFFFF044
 HEX 44444440FF00FFFF0044
 HEX 44444440FF0F00F00044
 HEX 44444440FF022F000444
 HEX 44444440F00222220444
 HEX 4444444000FF22F20444
 HEX 44444440000000F04444
 HEX 444444400FF44F404444
 HEX 4444400000F44F004444
 HEX 44440FFF00F400004444
 HEX 44404444F00F440F0444
 HEX 4440444440F000040444
 HEX 444F444440FF44040444
 HEX 44044444F00FF00F0444
 HEX 404444FF000000000444
 HEX 404F00F0000004F40444
 HEX 4F44F00000000FF40444
 HEX 4F44040F4F0004440444
 HEX 4F4F0044440000000444
 HEX 40F04044440000440444
 HEX 440000F44F0000004444
 HEX 44440400000000444444
 HEX 44444066660060444444
 HEX 44444069990060444444
 HEX 44444069996060444444
 HEX 44444006999000444444
 HEX 44444406699600444444
 HEX 44444400069900444444
 HEX 44444440669900444444
 HEX 44444440066600444444
 HEX 4444440A900004444444
 HEX 44444409990044444444
 HEX 444440A9900444444444
 HEX 44440AAA000444444444
 HEX 44440A99000444444444
 HEX 44440A99A00044444444
 HEX 444440099A0004444444
 HEX 44444440000004444444
WILLIAM2LEN EQU *-WILLIAM2

WILLIAM3_Y HEX 2800
WILLIAM3_X HEX 0A00
WILLIAM3
 HEX 44444444400040404044
 HEX 444444440F0F0F0F0F04
 HEX 444444440FFFFFFFFF04
 HEX 444444440FF00FFFF004
 HEX 444444440FF0F00F0044
 HEX 444444440FF022F00044
 HEX 444444440F0022222044
 HEX 44444444000FF22F2044
 HEX 444444440000000F0444
 HEX 4444444400FF44F40444
 HEX 44444400000F44F00444
 HEX 444440FFF00F40000444
 HEX 444404444F00F440F044
 HEX 44440444440F00004044
 HEX 4444F444440FF4404044
 HEX 444044444F00FF00F044
 HEX 4404444FF00000000044
 HEX 4404F00F0000004F4044
 HEX 44F44F00000000FF4044
 HEX 44F44040F4F000444044
 HEX 44F4F004444000000044
 HEX 440F0404444000044044
 HEX 4440000F44F000000444
 HEX 44444040000000044444
 HEX 44444400066666044444
 HEX 44444400066996044444
 HEX 44444000006999604444
 HEX 44444060000699604444
 HEX 44440060000699604444
 HEX 44440666004069960444
 HEX 44440666004009960444
 HEX 44406660044066660444
 HEX 44000000444000000444
 HEX 440A99904440A9904444
 HEX 440A99044440A9904444
 HEX 440A99044440A9044444
 HEX 440AA0044440AA044444
 HEX 440A9900444099004444
 HEX 440A9999044099990444
 HEX 44000000044000000444
WILLIAM3LEN EQU *-WILLIAM3

*----------------------------------------------------------
* Subroutine to dump image to screen
* Requires at least 14 bytes ($0E) stack space
* Change the RTL at the bottom for calls other than JSL
* Change the XPOS,YPOS equates if you wish to move the image around
* This routine and it's associated bit image was produced using :-
* [ UNSHR v1.5 - by Richard Bennett ]
*
* This version loads MISSION11.SHR via ProDOS 8 into SHR
* screen memory ($E1/2000) and shadow copy ($50/2000),
* then animates a walking sprite with 3 frames.
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
 bne not_right
 inc IMAGE01_XPOS
 stz IMAGE01_MIRROR
 jsr advance_frame   ; animate on horizontal movement
 bra keyend
not_right cmp #'r'
 bne keyend
 jsr scroll_right    ; shift, fill, blit, and redraw sprite
 bra nokey           ; skip DUMP01, scroll_right already drew
keyend jsr DUMP01       ; draw at NEW position with NEW frame
 bra nokey

*----------------------------------------------------------
* toolbox_init - Start IIgs Toolbox tools
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

* Step 3: Blit 110-byte wide playfield from $50 to $E1
 lda #$2000
 sta $F0
 sta $F3
 sep $20
 lda #$50
 sta $F2               ; src bank
 lda #$E1
 sta $F5               ; dst bank
 rep $20

 ldx #183
:blit_line
 ldy #0
:blit_word
 lda [$F0],y
 sta [$F3],y
 iny
 iny
 cpy #110
 bcc :blit_word

 lda $F0
 clc
 adc #$A0
 sta $F0
 lda $F3
 clc
 adc #$A0
 sta $F3
 dex
 bne :blit_line

 sec
 xce                   ; back to emulation mode

* Step 4: Redraw sprite at current position
 jsr DUMP01
 rts

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
 LDA #$E1
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
scroll_src_off HEX 0000   ; byte offset within source bank scanline

*-------------------------------
* $0B bytes (b4 pack), from X - $01 to $0B, Y - $10 to $3A.
*-------------------------------
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

*-------------------------------
* $09 bytes (b4 pack), from X - $0C to $14, Y - $10 to $3A.
*-------------------------------
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

*-------------------------------
* $0C bytes (b4 pack), from X - $15 to $20, Y - $10 to $3A.
*-------------------------------
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

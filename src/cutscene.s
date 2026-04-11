; DD II cutscene render engine

  ORG $2000

  jsr toolbox_init

  clc
  xce
  rep $30

  pea #$0006
  ldx #$A004
  jsl $E10000        ; SetForeColor

  pea #$0000
  ldx #$A204
  jsl $E10000        ; SetBackColor

  pea #$0001         ; bit 1 = bold
  ldx #$9A04
  jsl $E10000        ; SetTextFace

  sep $20
  ldal $e0C035
  and #$F7             ; clear bit 3: enable SHR shadow ($01->$E1)
  stal $e0C035
  ldal $e0c034
  and #$F0
  stal $e0c034
  rep $20

* Load cutscene1 data to bank $02
  sec
  xce                   ; emulation mode for ProDOS
  jsr load_cutscene1
  clc
  xce                   ; back to native
  rep $30

* Execute cutscene script from bank $02
  jsr run_cutscene

  sec
  xce
  rts                   ; return to caller (BASIC.SYSTEM etc.)

*----------------------------------------------------------
* Cutscene bytecode interpreter
*----------------------------------------------------------
script_ptr = $E0       ; 3-byte ZP pointer into bank $02 script data
text_ptr   = $E4       ; 3-byte ZP pointer for text display lists

OP_NONE     EQU 0
OP_CLS      EQU 1
OP_FADEIN   EQU 2
OP_FADEOUT  EQU 3
OP_TEXT     EQU 4
OP_GFX      EQU 5
OP_WAIT     EQU 6
OP_PALETTE  EQU 7

 mx %00
run_cutscene
* Set up script_ptr to playlist at $02/0000
 lda #$0000
 sta script_ptr
 sep $20
 lda #$02
 sta script_ptr+2      ; bank byte
 rep $20

* Iterate screens playlist
:next_screen
 ldy #0
 lda [script_ptr],y    ; read screen pointer (2 bytes)
 bne :has_screen
 jmp :cutscene_done    ; $0000 = end of playlist
:has_screen
 sta :screen_addr       ; save screen address

* Advance playlist pointer by 2 and save it
 lda script_ptr
 clc
 adc #2
 sta script_ptr
 sta :save_playlist     ; save for after screen completes

* Set up screen execution pointer
 lda :screen_addr
 sta :exec_ptr

* Execute opcodes for this screen
:next_op
 lda :exec_ptr
 sta script_ptr         ; point script_ptr to current opcode
 ldy #0
 lda [script_ptr],y    ; read opcode (16-bit read, but opcode is 1 byte)
 and #$00FF            ; mask to 8 bits
 cmp #$00FF            ; check for $FFFF terminator (low byte = $FF)
 bne :not_term
 jmp :screen_done
:not_term

 cmp #OP_CLS
 bne :n1
 jmp :do_cls
:n1 cmp #OP_FADEIN
 bne :n2
 jmp :do_fadein
:n2 cmp #OP_FADEOUT
 bne :n3
 jmp :do_fadeout
:n3 cmp #OP_TEXT
 bne :n4
 jmp :do_text
:n4 cmp #OP_GFX
 bne :n5
 jmp :do_gfx
:n5 cmp #OP_WAIT
 bne :n6
 jmp :do_wait
:n6 cmp #OP_PALETTE
 bne :n7
 jmp :do_palette
:n7

* Unknown opcode or OP_NONE — skip 1 byte
 inc :exec_ptr
 jmp :next_op

:do_cls
 jsr cls
 inc :exec_ptr          ; advance past opcode (1 byte)
 jmp :next_op

:do_fadein
 jsr fadeIn
 inc :exec_ptr
 jmp :next_op

:do_fadeout
 jsr fadeOut
 inc :exec_ptr
 jmp :next_op

:do_wait
 inc :exec_ptr          ; skip opcode
* Read 2-byte frame count parameter
 lda :exec_ptr
 sta script_ptr
 ldy #0
 lda [script_ptr],y    ; frame count
 sta :wait_count
 lda :exec_ptr
 clc
 adc #2
 sta :exec_ptr          ; advance past parameter
:wait_loop
 jsr wait_for_vbl
 lda :wait_count
 sec
 sbc #1
 sta :wait_count
 bne :wait_loop
 jmp :next_op

:do_palette
 inc :exec_ptr          ; skip opcode
* Read 2-byte palette data pointer
 lda :exec_ptr
 sta script_ptr
 ldy #0
 lda [script_ptr],y    ; palette address in bank $02
 sta :pal_addr
 lda :exec_ptr
 clc
 adc #2
 sta :exec_ptr          ; advance past parameter
* Copy 32 bytes of palette data from bank $02 to targetPal buffer
* (fadeIn will use targetPal to fade from black to these colors)
 lda :pal_addr
 sta script_ptr         ; reuse script_ptr to read palette
 ldy #0
:pal_loop
 lda [script_ptr],y
 sta targetPal,y
 iny
 iny
 cpy #$0020             ; 32 bytes = 16 words = 1 palette
 bcc :pal_loop
 jmp :next_op

:do_gfx
 inc :exec_ptr          ; skip opcode
* Read graphics address (2 bytes), x pos (2 bytes), y pos (2 bytes)
 lda :exec_ptr
 sta script_ptr
 ldy #0
 lda [script_ptr],y    ; graphics data address in bank $02
 sta :gfx_addr
 iny
 iny
 lda [script_ptr],y    ; x position
 sta IMAGE01_XPOS
 iny
 iny
 lda [script_ptr],y    ; y position
 sta IMAGE01_YPOS
 lda :exec_ptr
 clc
 adc #6
 sta :exec_ptr          ; advance past 6 bytes of parameters
* Set up plot parameters — read width/height from before pixel data
* Height (_Y) is at gfx_addr-4, width (_X) is at gfx_addr-2
 lda :gfx_addr
 sec
 sbc #4
 sta script_ptr
 ldy #0
 lda [script_ptr],y    ; height (Y) at gfx_addr-4
 and #$00FF
 sta FRAME_Y
 ldy #2
 lda [script_ptr],y    ; width (X) at gfx_addr-2
 and #$00FF
 sta FRAME_X
* Frame address = gfx_addr (pixel data starts at the label)
 lda :gfx_addr
 sta FRAME_ADDR
 sep $20
 lda #$02
 sta FRAME_ADDR+2      ; bank $02
 rep $20
 lda #$0001
 sta draw_bank          ; draw to screen bank $01
 jsr plot
 jmp :next_op

:do_text
 inc :exec_ptr          ; skip opcode
* Read text display list pointer (2 bytes)
 lda :exec_ptr
 sta script_ptr
 ldy #0
 lda [script_ptr],y    ; text list address in bank $02
 sta :text_list
 lda :exec_ptr
 clc
 adc #2
 sta :exec_ptr          ; advance past parameter
* Iterate text display list
 lda :text_list
 sta text_ptr
 sep $20
 lda #$02
 sta text_ptr+2
 rep $20
:text_loop
 ldy #0
 lda [text_ptr],y      ; text entry pointer
 beq :text_done         ; $0000 = end of list
 sta :text_entry
* Advance text_ptr by 2
 lda text_ptr
 clc
 adc #2
 sta text_ptr
* Read text entry: xpos (2), ypos (2), then null-terminated string
 lda :text_entry
 sta script_ptr         ; point to text entry in bank $02
 ldy #0
 lda [script_ptr],y    ; xpos
 pha                    ; push for MoveTo
 iny
 iny
 lda [script_ptr],y    ; ypos
 pha                    ; push for MoveTo
 ldx #$3A04            ; _MoveTo
 jsl $E10000
* String starts at offset +4 in the text entry
 pea $0002              ; push string bank ($02) — high word first
 lda :text_entry
 clc
 adc #4
 pha                    ; push string addr (low word)
 ldx #$A604            ; _DrawCString
 jsl $E10000
 bra :text_loop
:text_done
 jmp :next_op

:screen_done
* Restore playlist pointer and continue
 lda :save_playlist
 sta script_ptr
 jmp :next_screen

:cutscene_done
 rts

:screen_addr dw 0
:exec_ptr dw 0
:save_playlist dw 0
:wait_count dw 0
:pal_addr dw 0
:gfx_addr dw 0
:text_list dw 0
:text_entry dw 0

*----------------------------------------------------------
* draw_text - Draw a C string using QuickDraw II
* (standalone helper, not used by interpreter directly)
*----------------------------------------------------------
  mx %00
draw_text
  lda #80
  pha
  lda #184
  pha
  ldx #$3a04         ; MoveTo
  jsl $E10000

  pea #$0006
  ldx #$A004
  jsl $E10000        ; SetForeColor

  pea #$0000
  ldx #$A204
  jsl $E10000        ; SetBackColor

  pea ^s_pressany
  pea s_pressany
  ldx #$A604
  jsl $E10000        ; DrawCString
  rts

s_pressany asc 'Press any key',00

  mx %00
cls
* Clear screen pixels
  lda #$0000
  ldx #$0000
:cls  stal $012000,x
  inx
  inx
  cpx #$7d00
  bne :cls

* Clear palette RAM
  ldx #$01FE
:clspal  stal $019E00,x
  dex
  dex
  bpl :clspal

* Clear targetPal buffer
  ldx #$01FE
:clstgt  sta targetPal,x
  dex
  dex
  bpl :clstgt

  rts

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
* half_sec - Delay for 30 VBLs (~0.5 seconds at 60Hz)
* Assumes native mode with 16-bit X/Y.
*----------------------------------------------------------
quarter_sec
  rep $30               ; assert 16-bit for assembler MX tracking
  ldx #15
:loop phx
  jsr wait_for_vbl
  plx
  dex
  bne :loop
  rts

half_sec
  rep $30               ; assert 16-bit for assembler MX tracking
  ldx #30
:loop phx
  jsr wait_for_vbl
  plx
  dex
  bne :loop
  rts

IMAGE01_YPOS HEX 0000
IMAGE01_XPOS HEX 0000
IMAGE01_XTEMP HEX 0000
FRAME_X HEX 0000
FRAME_Y HEX 0000
FRAME_ADDR HEX 00000000
draw_bank HEX 0000

*----------------------------------------------------------
* Normal (non-mirrored) draw path
*----------------------------------------------------------
plot PHB
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
 LDA #$02              ; sprite data bank
 STA 6
 LDA FRAME_ADDR
 STA 4
 SEP $30
 LDA FRAME_X
 CLC
 ADC IMAGE01_XPOS
 STA IMAGE01_XTEMP
 LDX FRAME_Y       ;Number of lines

]LOOP1 LDY IMAGE01_XPOS
]LOOP LDA [4]
 STA [0],Y
 REP $20
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
 sep $20            ; 8-bit A for BIT test on bit 7
:lp1 bit $c019
 bmi :lp1 ; wait for current VBL to end
:lp2 bit $c019
 bpl :lp2 ; wait for next VBL to start
 rep $20            ; restore 16-bit A
 rts

*----------------------------------------------------------
* fadeOut - Fade all 16 palettes (256 words at $019E00) to
* black over 16 steps using the fadeBlack lookup table.
* Each palette word is $0RGB. Each nibble is faded
* individually: fadeBlack[nibble*16 + step].
* Must be called in native mode with REP $30.
*----------------------------------------------------------
 mx %00
fadeOut
* First, save the original palette to a buffer
 ldx #$01FE           ; 256 words = 512 bytes, index last word
:save
 ldal $019E00,x
 sta origPal,x
 dex
 dex
 bpl :save

 lda #0
 sta :step             ; fade step counter (0-15)

:stepLoop
* For each palette word, fade R, G, B nibbles
 ldx #0               ; palette byte index (0-$1FE, step 2)

:wordLoop
* Read original palette word
 lda origPal,x
 sta :origWord

* Fade Blue (bits 0-3)
 and #$000F            ; isolate B nibble
 asl
 asl
 asl
 asl                   ; * 16 = row offset in fadeBlack
 clc
 adc :step             ; + step = table index
 tay
 sep $20
 lda fadeBlack,y       ; faded B value
 sta :fadedB
 rep $20

* Fade Green (bits 4-7)
 lda :origWord
 and #$00F0
                       ; already *16 relative to nibble value
                       ; but we need (nibble_value * 16) + step
                       ; nibble_value = bits 4-7 >> 4
 lsr
 lsr
 lsr
 lsr                   ; now have green nibble in low 4 bits
 asl
 asl
 asl
 asl                   ; * 16
 clc
 adc :step
 tay
 sep $20
 lda fadeBlack,y       ; faded G value
 asl
 asl
 asl
 asl                   ; shift back to bits 4-7
 ora :fadedB
 sta :fadedGB
 rep $20

* Fade Red (bits 8-11)
 lda :origWord
 and #$0F00
 xba                   ; swap bytes: red nibble now in low byte
 asl
 asl
 asl
 asl                   ; * 16
 clc
 adc :step
 tay
 sep $20
 lda fadeBlack,y       ; faded R value (8-bit, 0-F)
 sta :fadedR
 rep $20
* Combine $0RGB from :fadedR (R), :fadedGB (G+B)
 lda :fadedR
 and #$000F            ; $000R
 xba                   ; $0R00
 sta :fadedRGB         ; save R in high byte position
 lda :fadedGB
 and #$00FF            ; $00GB
 ora :fadedRGB         ; $0RGB
 stal $019E00,x        ; write to palette RAM

 inx
 inx
 cpx #$0200
 bcc :wordLoop

* Wait for VBL
 sep $20
:vbl1 bit $C019
 bmi :vbl1
:vbl2 bit $C019
 bpl :vbl2
 rep $20

* Next step
 lda :step
 clc
 adc #1
 sta :step
 cmp #16
 bcs :fadeDone
 jmp :stepLoop
:fadeDone

 rts

:step dw 0
:origWord dw 0
:fadedB dfb 0
:fadedGB dfb 0
:fadedR dfb 0
:fadedRGB dw 0

*----------------------------------------------------------
* fadeIn - Fade all 16 palettes from black to the target
* palette stored at $02/9E00 over 16 steps.
* Works backwards through the fadeBlack table (step 15→0).
* Must be called in native mode with REP $30.
*----------------------------------------------------------
 mx %00
fadeIn
* targetPal must be populated before calling (by OP_PALETTE or caller)
 lda #15
 sta :istep            ; start at step 15 (fully black)

:istepLoop
 ldx #0               ; palette byte index

:iwordLoop
* Read target palette word
 lda targetPal,x
 sta :iorigWord

* Fade Blue (bits 0-3)
 and #$000F
 asl
 asl
 asl
 asl                   ; * 16
 clc
 adc :istep
 tay
 sep $20
 lda fadeBlack,y
 sta :ifadedB
 rep $20

* Fade Green (bits 4-7)
 lda :iorigWord
 and #$00F0
 lsr
 lsr
 lsr
 lsr                   ; green nibble in low bits
 asl
 asl
 asl
 asl                   ; * 16
 clc
 adc :istep
 tay
 sep $20
 lda fadeBlack,y
 asl
 asl
 asl
 asl                   ; shift to bits 4-7
 ora :ifadedB
 sta :ifadedGB
 rep $20

* Fade Red (bits 8-11)
 lda :iorigWord
 and #$0F00
 xba                   ; red nibble in low byte
 asl
 asl
 asl
 asl                   ; * 16
 clc
 adc :istep
 tay
 sep $20
 lda fadeBlack,y       ; faded R value (8-bit, 0-F)
 sta :ifadedR
 rep $20
* Combine $0RGB from :ifadedR (R), :ifadedGB (G+B)
 lda :ifadedR
 and #$000F            ; $000R
 xba                   ; $0R00
 sta :ifadedRGB
 lda :ifadedGB
 and #$00FF            ; $00GB
 ora :ifadedRGB        ; $0RGB
 stal $019E00,x

 inx
 inx
 cpx #$0200
 bcc :iwordLoop

* Wait for VBL
 sep $20
:ivbl1 bit $C019
 bmi :ivbl1
:ivbl2 bit $C019
 bpl :ivbl2
 rep $20

* Decrement step (15→14→...→0)
 lda :istep
 sec
 sbc #1
 sta :istep
 bpl :jstep
 rts                   ; done when step goes negative
:jstep jmp :istepLoop

:istep dw 0
:iorigWord dw 0
:ifadedB dfb 0
:ifadedGB dfb 0
:ifadedR dfb 0
:ifadedRGB dw 0

targetPal ds 512       ; target palette from bank $02

origPal ds 512          ; saved copy of original palette (used by fadeOut)

; fade table for title screen fade-in/out effect, indexed by frame (0-15) and color index (0-15)
; use fadeBlack[orig*16]+step to get faded color index for a given original color nibble and fade step
; NOTE this is for gamma value 1.6
fadeBlack
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $01, $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $02, $02, $02, $01, $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00
    db $03, $03, $02, $02, $02, $02, $01, $01, $01, $01, $01, $00, $00, $00, $00, $00
    db $04, $04, $03, $03, $02, $02, $02, $01, $01, $01, $01, $00, $00, $00, $00, $00
    db $05, $04, $04, $03, $03, $03, $02, $02, $01, $01, $01, $01, $00, $00, $00, $00
    db $06, $05, $05, $04, $04, $03, $03, $02, $02, $01, $01, $01, $00, $00, $00, $00
    db $07, $06, $06, $05, $04, $04, $03, $03, $02, $02, $01, $01, $01, $00, $00, $00
    db $08, $07, $06, $06, $05, $04, $04, $03, $02, $02, $01, $01, $01, $00, $00, $00
    db $09, $08, $07, $06, $05, $05, $04, $03, $03, $02, $02, $01, $01, $00, $00, $00
    db $0A, $09, $08, $07, $06, $05, $04, $04, $03, $02, $02, $01, $01, $00, $00, $00
    db $0B, $0A, $09, $08, $07, $06, $05, $04, $03, $03, $02, $01, $01, $00, $00, $00
    db $0C, $0B, $0A, $08, $07, $06, $05, $04, $04, $03, $02, $01, $01, $00, $00, $00
    db $0D, $0C, $0A, $09, $08, $07, $06, $05, $04, $03, $02, $02, $01, $01, $00, $00
    db $0E, $0D, $0B, $0A, $09, $07, $06, $05, $04, $03, $02, $02, $01, $01, $00, $00
    db $0F, $0D, $0C, $0A, $09, $08, $07, $05, $04, $03, $03, $02, $01, $01, $00, $00

*----------------------------------------------------------
* ProDOS 8 file loader
*----------------------------------------------------------

]IOBUF = $6C00         ; 1024-byte ProDOS I/O buffer (page-aligned)
]RDBUF = $7000         ; 4KB read buffer

*----------------------------------------------------------
* load_cutscene1 - Load CUTSCENE1 to bank $02 via ProDOS 8
* in 4KB chunks. Handles multi-bank wrapping.
* Must be called in emulation mode.
*----------------------------------------------------------
 mx %11
load_cutscene1
 jsr $BF00
 dfb $C8              ; OPEN
 da cs_open
 bcs :err
 lda cs_oref
 sta cs_rref
 sta cs_cref

 lda #$00
 sta cs_dest
 sta cs_dest+1         ; destination starts at $xx/0000
 lda #$02
 sta cs_bank

:readlp
 jsr $BF00
 dfb $CA              ; READ
 da cs_read
 bcs :close

 jsr cs_copy_chunk

* Advance destination by $1000
 lda cs_dest+1
 clc
 adc #$10
 sta cs_dest+1
 bcc :readlp
* Address wrapped — next bank
 lda #$00
 sta cs_dest+1
 inc cs_bank
 bra :readlp

:close
 php
 jsr $BF00
 dfb $CC              ; CLOSE
 da cs_close
 plp
:err rts

*----------------------------------------------------------
* cs_copy_chunk - Copy 4KB from ]RDBUF to cs_bank/cs_dest
*----------------------------------------------------------
cs_copy_chunk
 clc
 xce                   ; native mode
 rep $30
 mx %00

 lda cs_dest
 sta $F0
 sep $20
 lda cs_bank
 sta $F2
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
* ProDOS 8 parameter blocks
*----------------------------------------------------------
cs_dest ds 2
cs_bank dfb $02

cs_open dfb 3
 da cs_path
 da ]IOBUF
cs_oref dfb 0

cs_read dfb 4
cs_rref dfb 0
 da ]RDBUF
 da $1000
 ds 2                  ; transfer count

cs_close dfb 1
cs_cref dfb 0

cs_path dfb 17
 asc '/DDIIGS/CUTSCENE1'

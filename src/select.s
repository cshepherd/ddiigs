; Controller Selection Screen Concept

  ORG $2000

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

game_type = $300
ctl_type_p1 = $302
ctl_type_p2 = $304

game_type_selected = $0b93
game_type_unselected = $0000

palette_1p = $e19e26
palette_2p_coop = $e19e38
palette_2p_pvp = $e19e36

;
; init: set defaults
;

; game type default: 1P
  lda #GT_1P
  sta game_type
  stz game_type+1

; P1 controller default: joystick
  lda #CTL_JOYSTICK
  sta ctl_type_p1
  stz ctl_type_p1+1


; P2 controller default: keyboard
  lda #CTL_KEYBOARD
  sta ctl_type_p2
  stz ctl_type_p2+1

; set 1P palette color to selected, black out the other two
  lda #<game_type_selected
  stal palette_1p
  lda #>game_type_selected
  stal palette_1p+1

  lda #00
  stal palette_2p_coop
  stal palette_2p_coop+1
  stal palette_2p_pvp
  stal palette_2p_pvp+1

  jsr toolbox_init

  jsr load_concept3

  clc
  xce
  rep $30

; blit default controller for P1 (joystick)
  lda #JOYSTICK
  sta FRAME_ADDR
  lda JOYSTICK_X
  sta FRAME_X
  lda JOYSTICK_Y
  sta FRAME_Y
  lda #$47
  sta DRAW_YPOS
  lda #$14
  sta DRAW_XPOS
  jsr plot

; blit default controller for P2 (keyboard)
  lda #KEYBOARD
  sta FRAME_ADDR
  lda KEYBOARD_X
  sta FRAME_X
  lda KEYBOARD_Y
  sta FRAME_Y
  lda #$47
  sta DRAW_YPOS
  lda #$65
  sta DRAW_XPOS
  jsr plot

  ldx #$CA04            ; _InitCursor
  jsl $E10000

;  pea $0000
;  pea #cursor
;  ldx #$8e04
;  jsl $E10000           ; _SetCursor

eventLoop
  pea $0000             ; space for result
  pea #$0002            ; event type (bit 1 = mouse down)
  pea $0000             ; event record high
  pea #eventRecord      ; event record low
  ldx #$0a06
  jsl $E10000           ; _GetNextEvent

  pla                   ; boolean: event should be handled by app

  lda eventRecord
  beq eventLoop         ; if event code is 0, it's a null event → loop again

* Print the mouse coordinates at the right edge of the SHR
* screen. Modeled on game.s's draw_debug_xy (toggled by 'x' in
* the main game). 16-bit because ermouseLocation is two words.
;  jsr draw_mouse_xy

* Hit-test the click against every entry in the buttons table.
* Each table slot is a 16-bit pointer to a 5-word rect record:
*   +0  top-left X      +2  top-left Y
*   +4  bottom-right X  +6  bottom-right Y
*   +8  handler address (intra-bank; handler JMPs back to eventLoop)
* Walk the null-terminated table; on the first containing rect we
* JMP to its handler. If nothing matches, fall through to the BRA
* below and wait for the next event.
*
* ermouseLocation point layout (QD II Point): V word at +0, H word
* at +2. Snapshot into click_x/click_y so we're not re-reading the
* OS event record on every comparison.
  lda ermouseLocation+2     ; H (X)
  sta click_x
  lda ermouseLocation       ; V (Y)
  sta click_y
  ldx #0
:btn_loop
  lda buttons,x
  beq :btn_none             ; null terminator → no hit
  sta $00                   ; DP $00..$01 = pointer to current rect
  ldy #0
  lda ($00),y               ; top-left X
  cmp click_x
  beq :btn_tlx_ok
  bcs :btn_next             ; top-left X > click_x → outside on the left
:btn_tlx_ok
  ldy #2
  lda ($00),y               ; top-left Y
  cmp click_y
  beq :btn_tly_ok
  bcs :btn_next             ; top-left Y > click_y → outside above
:btn_tly_ok
  ldy #4
  lda ($00),y               ; bottom-right X
  cmp click_x
  bcc :btn_next             ; bottom-right X < click_x → outside on the right
  ldy #6
  lda ($00),y               ; bottom-right Y
  cmp click_y
  bcc :btn_next             ; bottom-right Y < click_y → outside below
* Hit! Load the handler address and JMP through it. JMP not JSR
* because the handler owns its own return path (they all branch
* back to eventLoop themselves).
  ldy #8
  lda ($00),y
  sta $02
  jmp ($02)
:btn_next
  inx
  inx                       ; advance one word in the buttons table
  bra :btn_loop
:btn_none

  bra eventLoop

;
; click handlers
;
1p_clicked
  lda #game_type_selected
  stal palette_1p

  lda #game_type_unselected
  stal palette_2p_coop
  stal palette_2p_pvp

  lda #GT_1P
  sta game_type

  jmp eventLoop

2p_coop_clicked
  lda #game_type_selected
  stal palette_2p_coop

  lda #game_type_unselected
  stal palette_1p
  stal palette_2p_pvp

  lda #GT_2P_COOP
  sta game_type

  jmp eventLoop

2p_pvp_clicked
  lda #game_type_selected
  stal palette_2p_pvp

  lda #game_type_unselected
  stal palette_1p
  stal palette_2p_coop

  lda #GT_2P_PVP
  sta game_type

  jmp eventLoop

p1_left_clicked
p1_right_clicked
p2_left_clicked
p2_right_clicked
  lda ctl_type_p1
  cmp #CTL_KEYBOARD
  bne :p1_left_not_keyboard
  lda #CTL_JOYSTICK
  sta ctl_type_p1
  lda #JOYSTICK
  sta FRAME_ADDR
  lda JOYSTICK_X
  sta FRAME_X
  lda JOYSTICK_Y
  sta FRAME_Y
  lda #$47
  sta DRAW_YPOS
  lda #$14
  sta DRAW_XPOS
  jsr plot
; now for P2 to keyboard since P1 has joystick
  lda #CTL_KEYBOARD
  sta ctl_type_p2
; blit keyboard for P2
  lda #KEYBOARD
  sta FRAME_ADDR
  lda KEYBOARD_X
  sta FRAME_X
  lda KEYBOARD_Y
  sta FRAME_Y
  lda #$48
  sta DRAW_YPOS
  lda #$65
  sta DRAW_XPOS
  jmp :p1_left_done
:p1_left_not_keyboard
  lda #CTL_KEYBOARD
  sta ctl_type_p1
; blit keyboard for P1
  lda #KEYBOARD
  sta FRAME_ADDR
  lda KEYBOARD_X
  sta FRAME_X
  lda KEYBOARD_Y
  sta FRAME_Y
  lda #$48
  sta DRAW_YPOS
  lda #$13
  sta DRAW_XPOS
  jsr plot
; now for P2 to joystick since P1 has keyboard
  lda #CTL_JOYSTICK
  sta ctl_type_p2
; blit joystick for P2
  lda #JOYSTICK
  sta FRAME_ADDR
  lda JOYSTICK_X
  sta FRAME_X
  lda JOYSTICK_Y
  sta FRAME_Y
  lda #$47
  sta DRAW_YPOS
  lda #$66
  sta DRAW_XPOS
:p1_left_done
  jsr plot

  jmp eventLoop

start_clicked
  sec
  xce
  sep $20
  lda #$41
  sta $c029
  rts

p1_keyboard_clicked
  jmp eventLoop
p1_joystick_clicked
  jmp eventLoop
p1_snes_clicked
  jmp eventLoop
p2_keyboard_clicked
  jmp eventLoop
p2_joystick_clicked
  jmp eventLoop 
p2_snes_clicked
  jmp eventLoop

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
 pea $1d00             ; dpAddress — 3 pages ($1D00-$1FFF) sit just
                       ; below RDBUF at $B700. Anything in game.s
                       ; below $B400 is safe from QD II's DP scribbles.
 pea $0000             ; master SCB (320 mode)
 pea $00A0             ; max width (160 bytes)
 lda myID
 pha                   ; userID
 ldx #$0204            ; _QDStartup
 jsl $E10000
 bcs errorspot2

 ldx #$0205            ; _DeskStartUp
 jsl $E10000

 pea $8100             ; EM DP (1 page)
 pea $0000             ; queue size (0 = default of 20)
 pea $0000             ; X Min Clamp
 pea #320            ; X Max Clamp
 pea $0000             ; Y Min Clamp
 pea #200            ; Y Max Clamp
 lda myID
 pha                   ; userID
 ldx #$0206            ; _EMStartUp
 jsl $E10000

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
  ldx #5
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


wait_for_vbl
 sep $20            ; 8-bit A for BIT test on bit 7
:lp1 bit $c019
 bmi :lp1 ; wait for current VBL to end
:lp2 bit $c019
 bpl :lp2 ; wait for next VBL to start
 rep $20            ; restore 16-bit A
 rts

*----------------------------------------------------------
* ProDOS 8 file loading and relocation
*----------------------------------------------------------

]IOBUF = $6C00         ; 1024-byte ProDOS I/O buffer (page-aligned)
]RDBUF = $7000         ; 4KB read buffer

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
* Save target palette from bank $02 to buffer
 sep $20
 lda #$02
 sta $F2               ; bank byte for indirect long
 rep $20
 lda #$9E00
 sta $F0               ; $F0 = $02/9E00
 ldy #0
:loadTgt
 lda [$F0],y
 sta targetPal,y
 iny
 iny
 cpy #$0200
 bcc :loadTgt

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

;
; Clickable Regions
;
buttons
  dw 1p
  dw 2p_coop
  dw 2p_pvp
  dw p1_left
  dw p1_right
  dw p2_left
  dw p2_right
  dw start
  dw p1_keyboard
  dw p1_joystick
  dw p1_snes
  dw p2_keyboard
  dw p2_joystick
  dw p2_snes
  dw 0000              ; the end my friend

1p
  dw $34, $0a            ; top left x,y
  dw $6f, $22            ; bottom right x,y
  dw 1p_clicked        ; handler

2p_coop
  dw $76, $0a
  dw $cc, $22
  dw 2p_coop_clicked

2p_pvp
  dw $d1, $0a
  dw $10c, $22
  dw 2p_pvp_clicked

p1_left
  dw $1a, $55
  dw $22, $68
  dw p1_left_clicked

p1_right
  dw $78, $55
  dw $81, $68
  dw p1_right_clicked

p2_left
  dw $C0, $55
  dw $C8, $68
  dw p2_left_clicked

p2_right
  dw $11E, $55
  dw $128, $68
  dw p2_right_clicked

start
  dw $FC, $80
  dw $137, $C1
  dw start_clicked

p1_keyboard
  dw $20, $89
  dw $38, $9C
  dw p1_keyboard_clicked

p1_joystick
  dw $44, $89
  dw $57, $9C
  dw p1_joystick_clicked

p1_snes
  dw $62, $89
  dw $7D, $9C
  dw p1_snes_clicked

p2_keyboard
  dw $C3, $89
  dw $DC, $9C
  dw p2_keyboard_clicked

p2_joystick
  dw $E9, $89
  dw $FC, $9C
  dw p2_joystick_clicked

p2_snes
  dw $108, $89
  dw $121, $9C
  dw p2_snes_clicked

;
; QD II cursor Record (currently unused but could be useful later)
;
cursor
  hex 0b000400 ; 11 rows of 4 words (16 bit LE)
; pixels
  hex 1111111111111111
  hex 1311111111111111
  hex 1331111111111111
  hex 1333111111111111
  hex 1333311111111111
  hex 1333331111111111
  hex 1333333111111111
  hex 1333333311111111
  hex 1331331111111111
  hex 1111133111111111
  hex 1111111111111111

; mask
  hex ff00000000000000
  hex fff0000000000000
  hex ffff000000000000
  hex fffff00000000000
  hex ffffff0000000000
  hex fffffff000000000
  hex ffffffff00000000
  hex fffffffff0000000
  hex ffffffff00000000
  hex fff0ffff00000000
  hex 00000fff00000000

; hotspot
  hex 01000100 ; hotspot at (1,1) (16 bit LE)

;
; EventManager Event Record
;
eventRecord
  hex 0000     ; what: event code (word, 0 = null event)
  hex 00000000 ; message: event message (long)
  hex 00000000 ; when: event tick count (long)
ermouseLocation
  hex 00000000 ; where: mouse location (point — QD II Point order:
               ;        V word at +0, H word at +2)
  hex 00000000 ; modifier flags (long)

; Snapshot of mouse coords taken at the top of every hit-test pass
; so the per-button (0),y reads compare against a stable value.
click_x dw 0
click_y dw 0

*----------------------------------------------------------
* draw_mouse_xy - Format ermouseLocation as two 4-digit hex
* strings ("X=hhhh" / "Y=hhhh") and draw via _DrawCString at
* the right edge of the SHR screen. Modeled on game.s's
* draw_debug_xy but widened from 8-bit to 16-bit per axis
* (mouse can reach 320/640 wide, 200 tall).
*
* Caller must be in native mode with REP $30. Mode is preserved.
*----------------------------------------------------------
DBG_MX_X     = 225        ; column for both readouts
DBG_MX_Y_X   = 40         ; row for X label
DBG_MX_Y_Y   = 50         ; row for Y label

 mx %00
draw_mouse_xy
* X readout — ermouseLocation+2 is the H (horizontal) word.
 lda ermouseLocation+2
 jsr fmt_hex16_to_mxy_buf
 pea #DBG_MX_X
 pea #DBG_MX_Y_X
 ldx #$3a04               ; MoveTo
 jsl $E10000
 pea #$0000
 pea #mxy_buf
 ldx #$A604               ; DrawCString
 jsl $E10000

* Y readout — ermouseLocation+0 is the V (vertical) word.
 lda ermouseLocation
 jsr fmt_hex16_to_mxy_buf
 pea #DBG_MX_X
 pea #DBG_MX_Y_Y
 ldx #$3a04
 jsl $E10000
 pea #$0000
 pea #mxy_buf
 ldx #$A604
 jsl $E10000
 rts

*----------------------------------------------------------
* fmt_hex16_to_mxy_buf - 16-bit A → 4 hex chars at mxy_buf
* (high byte's hex first). Caller in 16-bit M, returns in
* 16-bit M.
*----------------------------------------------------------
fmt_hex16_to_mxy_buf
 pha                      ; stash the 16-bit value
 sep $20
* mem[SP+2] = high byte, mem[SP+1] = low byte after PHA in 16-bit.
 lda 2,s
 jsr fmt_hex_byte_pair
 sta mxy_buf+0
 lda :lo_char
 sta mxy_buf+1
 lda 1,s
 jsr fmt_hex_byte_pair
 sta mxy_buf+2
 lda :lo_char
 sta mxy_buf+3
 rep $20
 pla                      ; discard the saved value
 rts

*----------------------------------------------------------
* fmt_hex_byte_pair - 8-bit A → A = char for high nibble,
* :lo_char (data byte below) = char for low nibble.
* Caller in 8-bit M. The mx %11 directive matters: without
* it Merlin (still tracking the surrounding draw_mouse_xy
* mx %00 block) would assemble `cmp #10` / `adc #N` as
* 16-bit immediates, and at runtime with M=1 the CPU would
* read only 1 immediate byte and treat the trailing $00 as
* the next opcode → BRK $00 crash.
*----------------------------------------------------------
 mx %11
fmt_hex_byte_pair
 pha
 and #$0F                 ; low nibble first
 jsr :nib_to_char
 sta :lo_char             ; stash low-nibble char
 pla
 lsr
 lsr
 lsr
 lsr
 jsr :nib_to_char         ; high nibble char in A
 rts                      ; caller reads A then :lo_char
:nib_to_char
 cmp #10
 bcc :digit
 clc
 adc #'A'-10
 rts
:digit
 clc
 adc #'0'
 rts
:lo_char dfb 0
 mx %00                   ; restore for any later 16-bit code

* Output buffer — 4 hex digits + null terminator for DrawCString.
mxy_buf
 dfb 0,0,0,0,0

*----------------------------------------------------------
* load_concept3 - Load /MENU/CONCEPT3 (uncompressed 32 KB SHR
* PIC) into bank $E1 starting at $E1/2000. The PIC layout
* matches the natural SHR display: pixel data $2000-$9D7F,
* SCBs $9D00-$9DFF, palettes $9E00-$9FFF. Writing directly to
* bank $E1 bypasses the shadow path entirely, so the picture
* appears as the load progresses.
* Caller must be in emulation mode with 8-bit A/X/Y.
*----------------------------------------------------------
 mx %11
load_concept3
 jsr $BF00
 dfb $C8              ; OPEN
 da c3_open
 bcc :ok
 rts
:ok
 lda c3_oref
 sta c3_rref
 sta c3_cref

 lda #$00
 sta t_dest
 lda #$20
 sta t_dest+1          ; destination starts at $E1/2000
 lda #$E1
 sta t_bank

:readlp
 jsr $BF00
 dfb $CA              ; READ
 da c3_read
 bcs :close           ; carry set on EOF

 jsr copy_chunk_e1

 lda t_dest+1
 clc
 adc #$10              ; advance 4 KB ($1000) within bank
 sta t_dest+1
 bra :readlp           ; CONCEPT3 is 32 KB → fits in bank $E1

:close
 jsr $BF00
 dfb $CC              ; CLOSE
 da c3_close
 rts

*----------------------------------------------------------
* copy_chunk_e1 - Copy 4 KB from ]RDBUF to t_bank/t_dest using
* the [$F0],y indirect-long pointer. Mirrors title.s's
* copy_chunk_bank.
*----------------------------------------------------------
copy_chunk_e1
 clc
 xce                   ; native mode
 rep $30
 mx %00

 lda t_dest
 sta $F0
 sep $20
 lda t_bank
 sta $F2
 rep $30

 ldy #$0000
 ldx #$0800            ; $1000/2 word copies
:loop
 lda ]RDBUF,y
 sta [$F0],y
 iny
 iny
 dex
 bne :loop

 sec
 xce                   ; back to emulation mode
 mx %11
 rts

*----------------------------------------------------------
* ProDOS 8 parameter blocks + scratch for load_concept3
*----------------------------------------------------------
t_dest ds 2            ; current dest offset within t_bank
t_bank dfb 0           ; current dest bank

c3_open  dfb 3
 da c3_path
 da ]IOBUF
c3_oref  dfb 0

c3_read  dfb 4
c3_rref  dfb 0
 da ]RDBUF
 da $1000              ; request 4 KB per read
 ds 2                  ; transfer count (returned)

c3_close dfb 1
c3_cref  dfb 0

c3_path  dfb 14
 asc '/MENU/CONCEPT3'

 mx %00
plot
 ldx #$9004
 jsl $E10000    ; _HideCursor to prevent corruption
 PHB
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
 lda DRAW_YPOS  ; do our own multiplication by $a0 because address won't always be hardcoded
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
 LDA #^JOYSTICK
 STA 6
 LDA FRAME_ADDR
 STA 4
 SEP $30
 LDA FRAME_X
 CLC
 ADC DRAW_XPOS
 STA IMAGE_XTEMP
 LDX FRAME_Y       ;Number of lines

]LOOP1 LDY DRAW_XPOS
]LOOP LDA [4]
 STA [0],Y
 REP $20
 INC 4
 SEP $20
 INY
 CPY IMAGE_XTEMP
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
 ldx #$9104
 jsl $E10000    ; _ShowCursor
 RTS

DRAW_XPOS hex 0000
DRAW_YPOS hex 0000
IMAGE_XTEMP HEX 0000
FRAME_X HEX 0000
FRAME_Y HEX 0000
FRAME_ADDR HEX 00000000
draw_bank HEX E100

JOYSTICK_XPOS hex 6900
JOYSTICK_YPOS hex 4600
JOYSTICK_Y hex 3500
JOYSTICK_X hex 2400
JOYSTICK
 HEX 111111111111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111111111111111111111111111444491111111111111111111111111111111
 HEX 11111111111111111111111111111111194C333334411111111111111111111111111111
 HEX 111111111111111111111111111111111333333333341111111111111111111111111111
 HEX 11111111111111111111111111111111C333333333334111111111111111111111111111
 HEX 1111111111111111111111111111111C3333333333333911111111111111111111111111
 HEX 111111111111111111111111111111133333333333333411111111111111111111111111
 HEX 111111111111111111111111111111C33333333333333C91111111111111111111111111
 HEX 111111111111111111111111111111333333333333333341111111111111111111111111
 HEX 111111111111111111111111111111333333333333333341111111111111111111111111
 HEX 111111111111111111111111111111333333333333333341111111111111111111111111
 HEX 111111111111111111111111111111333333333333333341111111111111111111111111
 HEX 111111111111111111111111111111C33333333333333C11111111111111111111111111
 HEX 111111111111111111111111111111133333333333333411111111111111111111111111
 HEX 11111111111111111111111111111114333333333333C111111111111111111111111111
 HEX 11111111111111111111111111111111C3333333333C1111111111111111111111111111
 HEX 111111111111111111111111111111111C33333333C11111111111111111111111111111
 HEX 11111111111111111111111111111111111C3333C1111111111111111111111111111111
 HEX 111111111111111111111111111111111E11111111111111111111111111111111111111
 HEX 111111111111111111111111111111111114CCCCC1111111111111111111111111111111
 HEX 11111111111111111111111111111111111C333331111111111111111111111111111111
 HEX 11111111111111111111111111111111111C333331111111111111111111111111111111
 HEX 11111111111111111111111111111111111C333331111111111111111111111111111111
 HEX 11111111111111111111111111111111111C333331111111111111111111111111111111
 HEX 11111111111111111111111111111111111C333331111111111111111111111111111111
 HEX 11111111111111111111111111111111111C333331111111111111111111111111111111
 HEX 11111111111111111111111111111111111C333331111111111111111111111111111111
 HEX 111111111111111111111119CCCCCCCCCC1C3333314CCCCCCCCCC4111111111111111111
 HEX 1111111111111111111111C333333333331C333331333333333333C41111111111111111
 HEX 111111111111111111111C33C4444444441C3333314444444444C3334111111111111111
 HEX 11111111111111111111C33411111111C31C333331C34111111114333411111111111111
 HEX 1111111111111111111933411111111C3C1C333331433911111111433C11111111111111
 HEX 1111111111111111111C3C11111111933111C333411C3C1111991E1C3391111111111111
 HEX 1111111111111111111334111111111C33341111143334111C3334193341111111111111
 HEX 11111111111111111933C11111111E11C333333333334111C3333341C339111111111111
 HEX 11111111111111111C33111111111111114333333C111111C33333C11C3C111111111111
 HEX 1111111111111111133C11111111111111111111111111111C333C191C33911111111111
 HEX 1111111111111111C3341111111111111111111111111111111111111133C11111111111
 HEX 111111111111111C33334CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC4C333C1111111111
 HEX 111111111111111C333333333333333333333333333333333333333333333C1111111111
 HEX 111111111111111433333333333333333333333333333333333333333333341111111111
 HEX 11111111111111919CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC911111111111
 HEX 1111111111111114C1111111111111111111111111111111111111111111C41111111111
 HEX 111111111111111C3CCC33333333333333333333333333333333333333CC3C1111111111
 HEX 111111111111111C333333333333333333333333333333333333333333333C1111111111
 HEX 111111111111111C33333333333333333333333333333333333333333333341111111111
 HEX 1111111111111111C3333333333333333333333333333333333333333333C11111111111
 HEX 111111111111111143333333333333333333333333333333333333333333411111111111
 HEX 11111111111111111C33333333333333333333333333333333333333333C111111111111
 HEX 1111111111111111114CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC41111111111111
 HEX 111111111111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111111111111111111111111111111111111111111111111111111111111111

KEYBOARD_XPOS hex 1300
KEYBOARD_YPOS hex 5800
KEYBOARD_Y hex 3100
KEYBOARD_X hex 2600
KEYBOARD
 HEX 1111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111
 HEX 1111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111
 HEX 1111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111
 HEX 1111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111
 HEX 1111119999999999999999999999999999999999999999999999999999999999
 HEX 999999911111
 HEX 1111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111
 HEX 111119CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
 HEX CCCCCCC11111
 HEX 1111933333333333333333333333333333333333333333333333333333333333
 HEX 3333333C1111
 HEX 1119333333333333333333333333333333333333333333333333333333333333
 HEX 33333333C111
 HEX 11143333CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
 HEX CCCCC3333111
 HEX 1114333411111111111111111111111111111111111111111111111111111111
 HEX 11111C333111
 HEX 111433C191111199111119111119911111911111998111199111119111119911
 HEX 111911333111
 HEX 111433C119444911444491944441194449114444819444911944491944441194
 HEX 449119333111
 HEX 111433C11C333C19333341C3333113333C14333381C333C19333341C333391C3
 HEX 33C119333111
 HEX 111433C11C3333193333C1C3333113333C14333391C333C19333341C33339133
 HEX 33C119333111
 HEX 111433C11C333C19333341C3333113333C14333391C333C19333341C333391C3
 HEX 33C119333111
 HEX 111433C11C333C19333341C3333113333C14333391C333C19333341C33339133
 HEX 33C119333111
 HEX 111433C114CCCC19CCCC414CCCC11CCCC414CCCC91CCCCC11CCCC414CCCC11CC
 HEX CCC119333111
 HEX 111433C111111191111119111111911111911111991111191111119111119911
 HEX 111119333111
 HEX 111433C111111111199111119111111911111911111191111191111119111111
 HEX 111119333111
 HEX 111433C114CCCCCCC11CCCC414CCCC91CCCCC19CCCC91CCCCC11CCCC414CCCCC
 HEX CCC119333111
 HEX 111433C11C333333311C333C14333391C333C14333341C3333193333C1C33333
 HEX 33C119333111
 HEX 111433C11C333333311C333C14333391C333C14333341C3333193333C1C33333
 HEX 33C119333111
 HEX 111433C11C333333311C333C14333391C333C14333341C3333193333C1C33333
 HEX 33C119333111
 HEX 111433C11C333333311C333C14333391C333C14333341C333C19333341C33333
 HEX 33C118333111
 HEX 111433C119444444911944491144491194449114444119444911444411144444
 HEX 449119333111
 HEX 111433C111111111111111111E11111111111181111811111111111111111111
 HEX 111119333111
 HEX 111433C111111111911111111111111111111111111111111111991111191111
 HEX 111119333111
 HEX 111433C11C3333341C333333333333333333333333333333333C11C333C19C33
 HEX 33C119333111
 HEX 111433C11C33333C1C333333333333333333333333333333333C113333319333
 HEX 333119333111
 HEX 111433C11C3333341C333333333333333333333333333333333C113333319333
 HEX 33C119333111
 HEX 111433C11C33333C1C333333333333333333333333333333333C113333319333
 HEX 33C119333111
 HEX 111433C11C33333414333333333333333333333333333333333C11C333C19333
 HEX 33C118333111
 HEX 111433C191111111111111111111111111111111111111111111111111111111
 HEX 111114333111
 HEX 111433C199999999999999999999999999999999999999999999999999999999
 HEX 999911333111
 HEX 1114333411111111111111111111111111111111111111111111111111111111
 HEX 11111C333111
 HEX 11143333CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
 HEX CCCCC3333111
 HEX 1114333333333333333333333333333333333333333333333333333333333333
 HEX 33333333C111
 HEX 1111133333333333333333333333333333333333333333333333333333333333
 HEX 3333333C1111
 HEX 111914CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
 HEX CCCCCCC19111
 HEX 1111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111
 HEX 1111181111111111111111111111111111111111111111111111111111111111
 HEX 111111111111
 HEX 1111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111
 HEX 1111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111
 HEX 1111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111
 HEX 1111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111
 HEX 1111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111
 HEX 1111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111
 HEX 1111111111111111111111111111111111111111111111111111111111111111
 HEX 111111111111

SNES_XPOS hex 6900
SNES_YPOS hex 5800
SNES_Y hex 0F00
SNES_X hex 1000
SNES
 HEX 1111111111111111111111111111111111
 HEX 1111189999991111111119999991111111
 HEX 1111999999999999999999999999911111
 HEX 1119911111111111111111111111991111
 HEX 1199889999911111111111999991199111
 HEX 1191198191191111111119119119119111
 HEX 1191991191199111111199119119919111
 HEX 1191999999999111111199991999919111
 HEX 1198999999999199199199991999919111
 HEX 1191991191199199199199119119919111
 HEX 1191191191191111111119119119119111
 HEX 1199119999911111111111999991199111
 HEX 1119911111119999999991111111991111
 HEX 11E1999999999999999999999999911111
 HEX 1111119999911111111111999991111111
 HEX 1111111111111111111111111111111111

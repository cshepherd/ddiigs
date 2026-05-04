*----------------------------------------------------------
* Subroutine to dump image to screen
* Requires at least 14 bytes ($0E) stack space
* Change the RTL at the bottom for calls other than JSL
* Change the XPOS,YPOS equates if you wish to move the image around
* This routine and it's associated bit image was produced using :- 
* [ UNSHR v1.5 - by Richard Bennett ]
*----------------------------------------------------------
]X1 = $00 ;Change this to XPOS on screen
]Y1 = $00 ;Change this to YPOS on screen
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
 SBC #8
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
 LDA #]Y1*$A0+$2000 ;Line address
 STA 0
 LDA #^IMAGE01
 STA 6
 LDA #IMAGE01
 STA 4
 SEP $30
 LDX #$07 ;Number of lines
]LOOP1 LDY #]X1
]LOOP LDA [4]
 STA [0],Y
 REP $20
 INC 4
 SEP $20
 INY
 CPY #]X1+$02
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
 ADC #8
 TCS
 PLP
 XCE
 PLP
 PLB
 RTL
*-------------------------------
* $02 bytes (b4 pack), from X - $00 to $01, Y - $00 to $06.
*-------------------------------
IMAGE01 HEX 9999
 HEX 9B99
 HEX 9F99
 HEX FBFB
 HEX 9F99
 HEX 9B99
 HEX 9999
IMLEN01 EQU *-IMAGE01

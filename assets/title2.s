*----------------------------------------------------------
* Subroutine to dump image to screen
* Requires at least 14 bytes ($0E) stack space
* Change the RTL at the bottom for calls other than JSL
* Change the XPOS,YPOS equates if you wish to move the image around
* This routine and it's associated bit image was produced using :- 
* [ UNSHR v1.5 - by Richard Bennett ]
*----------------------------------------------------------
]X1 = $02 ;Change this to XPOS on screen
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
 LDX #$09 ;Number of lines
]LOOP1 LDY #]X1
]LOOP LDA [4]
 STA [0],Y
 REP $20
 INC 4
 SEP $20
 INY
 CPY #]X1+$04
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
* $04 bytes (b4 pack), from X - $02 to $05, Y - $00 to $08.
*-------------------------------
IMAGE01 HEX 99999999
 HEX 97999997
 HEX 99879789
 HEX 99786879
 HEX 99966699
 HEX 99786879
 HEX 99879789
 HEX 97999997
 HEX 99999999
IMLEN01 EQU *-IMAGE01

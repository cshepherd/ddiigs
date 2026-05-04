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
 LDX #$10 ;Number of lines
]LOOP1 LDY #]X1
]LOOP LDA [4]
 STA [0],Y
 REP $20
 INC 4
 SEP $20
 INY
 CPY #]X1+$0C
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
* $0C bytes (b4 pack), from X - $00 to $0B, Y - $00 to $0F.
*-------------------------------
IMAGE01 HEX 77777700CCC0CCCCCCCCC070
 HEX 55567C09BBBC9BBBBBBB9000
 HEX 55570AB1111BC1111BB11900
 HEX 5558AB11B111CB111BB11900
 HEX 77709B11B11179BBBBBBBC00
 HEX 800AB11B9B118CACAAAAC070
 HEX C9C911B9CBB17A99C0808770
 HEX 0B691B9AC9BB0B1BA66C7770
 HEX 0159BBC00899911BC6607770
 HEX 0159BB59C00099A006607770
 HEX 81BA9B11BAC0C55AC6607780
 HEX 0BBA99B1B906B11BA6607880
 HEX 791BAABBB971111157608870
 HEX 6091BA0A998BB1BA06608770
 HEX 7709B90CCC0CC7C055787770
 HEX 5446C8064555555445787770
IMLEN01 EQU *-IMAGE01

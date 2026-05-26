*----------------------------------------------------------
* DDII.SYSTEM - DD II launcher.
*
* Loaded by ProDOS at $2000. Self-relocates to $1000, then
* loads /DDIIGS/TITLE at $2000 and runs it. Public jump table
* at the top of the relocated launcher:
*
*   $1000  load TITLE     (also the boot/post-relocation entry)
*   $1002  load CUTSCENE
*   $1004  load GAME
*
* Each entry is a 2-byte BRA into its loader stub. After the
* loaded part finishes, it JMPs to $1002 or $1004 to chain to
* the next part. Re-entering $1000 reloads TITLE.
*----------------------------------------------------------

  ORG $1000

* Public jump table.
br_title     bra load_title             ; $1000
br_cutscene  bra load_cutscene          ; $1002
br_game      bra load_game              ; $1004

*----------------------------------------------------------
* load_title - Boot OR reload-TITLE entry. On the very first
* call the file is still at $2000 (ProDOS hasn't moved us
* yet); detect that case by sampling the BRA opcode at $1002
* and $1004 (both should be $80 once the file is at $1000),
* and run a PIC bootstrap to copy the file down before
* falling through to the path-set / load_and_run path.
*----------------------------------------------------------
load_title
 lda $1002
 cmp #$80
 bne :do_bootstrap
 lda $1004
 cmp #$80
 bne :do_bootstrap
 jmp :set_title_path

:do_bootstrap
* Copy 4 pages ($2000-$23FF) down to $1000-$13FF. Uses only
* fixed source/dest addresses + a relative BNE, so it runs
* correctly while still executing from $2xxx (its absolute
* labels resolve to $1xxx, but they're not used here).
 ldx #$00
:cp_loop
 lda $2000,x
 sta $1000,x
 lda $2100,x
 sta $1100,x
 lda $2200,x
 sta $1200,x
 lda $2300,x
 sta $1300,x
 inx
 bne :cp_loop
 stz $1100

:set_title_path
 ldx #>title_path
 lda #<title_path
 jmp load_and_run

load_cutscene
 ldx #>cutscene_path
 lda #<cutscene_path
 jmp load_and_run

load_game
 ldx #>game_path
 lda #<game_path
 jmp load_and_run

*----------------------------------------------------------
* load_and_run - Open the file at <path>, READ into $2000,
* CLOSE, and JMP $2000.
* Inputs: A = path low byte, X = path high byte.
*----------------------------------------------------------
load_and_run
 sta path_ptr
 stx path_ptr+1
 lda path_ptr
 sta open_path
 lda path_ptr+1
 sta open_path+1

 jsr $BF00
 dfb $C8                    ; OPEN
 da open_pblock
 lda open_ref
 sta read_ref
 sta close_ref

 jsr $BF00
 dfb $CA                    ; READ
 da read_pblock

 jsr $BF00
 dfb $CC                    ; CLOSE
 da close_pblock

 jmp $2000

*----------------------------------------------------------
* ProDOS MLI parameter blocks.
*----------------------------------------------------------
path_ptr     dw 0

open_pblock  dfb 3
open_path    dw 0           ; pathname pointer (set per call)
open_iobuf   dw $0C00         ; ProDOS I/O buffer (1KB, page-aligned)
open_ref     dfb 0

read_pblock  dfb 4
read_ref     dfb 0
read_buf     dw $2000        ; load address for the SYS file
read_count   dw $9F00        ; max bytes ($2000-$BF00 ≈ 54 KB) —
                              ; $BF00 = ProDOS Global Page (top of
                              ; available bank-$00 user RAM). ]IOBUF
                              ; moved to $0C00 (and ]RDBUF to $0800)
                              ; so game.s can grow through $BEFF.
                              ; Bump in lockstep with IOBUF/RDBUF moves.
read_xfer    dw 0            ; bytes actually read

close_pblock dfb 1
close_ref    dfb 0

*----------------------------------------------------------
* Pathnames (ProDOS 8 format: length byte, then chars).
*----------------------------------------------------------
title_path    str 'TITLE'

cutscene_path str 'CUTSCENE'

game_path     str 'GAME'

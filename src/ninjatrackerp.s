*****************************
* NinjaTracker+ Player
*
* by Jesse Blue
*
* thanks to:
* Huibert Aalbers, Olivier Goguel, Jon Christopher Co, John Valdezco, John Brooks
* Brutal Deluxe, Digarok, Saga Musix, yzi, djh0ffman, fatdogprojects, Prince Slime
* Brian C. Bening, Tim Meekins
*
*
* Sep   9, 2018 - Initial release
* Sep  16, 2019 - Bug fix:
*                 - The player now uses the system volume
* Feb   8, 2020 > Version 1.0
*                 - Bug fixes:
*                 - portamento effects 1 and 2 no longer start at first tick
* Aug   2, 2020 > Version 1.1
*               - Added call NTPgetsongpos to retrieve information during playing
*               - Bug fixes:
*                 - Speed=0 now ends the current song
*                 - Speed=1 no longer behaves like Speed=2
*                 - Stopping a song did not work properly
* Apr   3, 2021 > Version 1.2
*               - Added call NTPsetplayvolume to set volume during playing
*               - Bug fixes:
*                 - Some notes where not stopped resulting in "skipped" notes
*                 - Octaves 0 and 4 had wrong values
* Jan  02, 2022 > Version 1.3
*               - Added support to stream samples, allowing to play modules with large samples
*               - Added effect [9] sample offset (for streamed samples only)
*               - Added effect [14][15] invert loop
*               - Added option for channel doubling
*               - Bug fixes:
*                 - Instruments where not played correctly when there was only one pattern
*                 - Effect [11]: Position jump did not reset position in the pattern when jumping
*                 - Effect did not work: [14][9]: Retrigger sample
*                 - Effect did not work: [14][12]: Cut sample
*                 - Effect did not work: [14][13]: Delay sample
*                 - NTPsetplayvolume did not calculate volumes correct
* Jan  16, 2022 > Version 1.4
*               - Added option to make use of more oscillators
*               - Song name and instrument names are now included in NTP files
*               - Added call NTPstreamsound for streaming SFX
*****************************

                        dsk ntpplayer
                        org $0f0000
                        mx  %00


; all calls to the player must be JSLs with 16 bit registers
; copy this into your program in order to call the player:

NinjaTrackerPlus        =   *
NTPprepare              =   NinjaTrackerPlus
NTPplay                 =   NinjaTrackerPlus+3
NTPstop                 =   NinjaTrackerPlus+6
NTPgetvuptr             =   NinjaTrackerPlus+9
NTPgete8ptr             =   NinjaTrackerPlus+12
NTPforcesongpos         =   NinjaTrackerPlus+15
NTPgetsongpos           =   NinjaTrackerPlus+18
NTPsetplayvolume        =   NinjaTrackerPlus+21
NTPstreamsound          =   NinjaTrackerPlus+24


; prepare
; Prepares music, copies all instruments into sound ram and inits the sound interrupt.
; Sets the play volume to maximum.
; input:  call with X=address low, Y=address high of pointer to the ntp file in memory
;         A=0 play normally (two oscillators per track), else use double channels (four oscillators per track)
;             channel doubling will play each voice with half the volume on the opposite output channel
; output: X=address low, Y=address high of pointer to instruments (main program can reuse memory from here)
;         when carry bit is set, an error occurred. The A register holds the error code:
;         A=1 The header information did not match (the player did not find a NTP module at the given location).
;         A=2 The version of the NTP module is not supported.
;         A=3 When the NTP has more than 7 tracks and channel doubling should be used.
;             Note that since channel doubling uses 4 oscillators, only NTPs with up to 7 tracks can be played.
                        jmp prepare

; play
; Starts previously prepared music.
; input:  call with A=0 loop song, else play song only once
;         please note that if the song has position jumps (effect B), the song might never stop
; output: -
                        jmp play

; stop
; Stops a currently playing music, turns off all oscillators used by the player and restores the sound interrupt.
; input:  -
; outout: -
                        jmp stop

; getvuptr
; Returns a pointer to vu data (1 word number of tracks, then one word for every track with its volume).
; input:  -
; output: X=address low, Y=address high of pointer
                        jmp getvuptr

; gete8ptr
; Returns a pointer to where the player stores information about the last 8xx command found. Can be used for timing purposes.
; input:  -
; output: X=address low, Y=address high of pointer
                        jmp gete8ptr

; forcesongpos
; Forces the player to jump to a certain pattern (like command B).
; input:  A=songpos
; output: carry bit is set when the song position does not exist (error)
                        jmp forcesongpos

; getsongpos
; Returns data about the current pattern and position
; input:  -
; output: X=pattern, Y=pos
                        jmp getsongpos

; setplayvolume
; Sets the maximum volume, may be used during play.
; input: A=volume (00-FF)
; output: -
                        jmp setplayvolume

; streamsound
; Streams a sound from memory through DOC ram. Can be used to play sound effects alongside music.
; input: X=address low, Y=address high of pointer to data structure (see below)
; output: -
;
; data structure
; 4 bytes pointer to sample in ram
; 4 bytes length of sample in ram
; 2 bytes freq to play
; 1 byte page of a 512 byte buffer in sound ram (the page has to be aligned on a 512 byte boundary, like $00 or $02 or $04 etc.)
; 1 byte first oscillator to use (0-29) (the first one is used for streaming purposes, the next play the sound)
; 1 byte number of playing oscillators (1-30)
; for each playing osc:
; 1 byte volume (0-255)
; 1 byte channel (0-7 placed in the upper 4 bits, example: $00 for left, $10 for right)
                        jmp streamsound

*-------------------------------

; to stay out of the way, do not use the direct page at all
; use DP only for faster access to sound registers
; the assembled code should not be bank relative (meaning: not compiled to a fixed bank)

sound_control           =   $3c                     ;really at $e1c03c
sound_data              =   $3d                     ;really at $e1c03d
sound_address           =   $3e                     ;really at $e1c03e

sound_interrupt_ptr     =   $e1002c
irq_volume              =   $e100ca
osc_interrupt           =   $e100cc

max_tracks_available    =   31                      ;the GS has 32 voices, but we need 1 for interrupt

max_pattern_line        =   64                      ;there are 64 lines in a pattern

max_instruments         =   255                     ;NTP supports up to 255 instruments

dbl_osc_offset          =   14                      ;when channel doubling is used, each oscillator gets a twin, 14 oscillators appart

;-------------------------- helper functions

read_head               ldal 0,x
                        rts

read_pattern            ldal 0,x
                        rts

read_instrument         ldal 0,x
                        rts

read_streamstructure    ldal 0,x
                        rts

                        mx %10

access_doc_registers    = *
                        ldal irq_volume
                        sta sound_control
                        rts

access_doc_ram          = *
                        ldal irq_volume
                        ora #%0110_0000
                        sta sound_control
                        rts

access_doc_ram_no_inc   = *
                        ldal irq_volume
                        ora #%0100_0000
                        sta sound_control
                        rts

                        mx  %00

;-----------------------------------------------------------------------------------------
; prepare
;-----------------------------------------------------------------------------------------

prepare                 =     *
                        sei
                        phb
                        phd
                        phk
                        plb

                        clc
                        xce
                        rep #$30
                        mx  %00

                        pea $c000
                        pld

                        jsr clear_memory

                        stx ptr_header
                        sty ptr_header+2
                        sta channel_doubling

                        jsr check_header
                        bcs prepare_1

                        jsr extract_header_info
                        jsr setup_channel_doubling
                        bcs prepare_1

                        jsr setup_register_tables
                        jsr copy_instruments_to_doc
                        jsr setup_instrument_ptrs
                        jsr setup_music
                        jsr setup_interrupt
                        jsr setup_master_volume

                        ldx ptr_instruments
                        ldy ptr_instruments+2

                        pld
                        plb
                        cli
                        clc
                        rtl

prepare_1               pld
                        plb
                        cli
                        sec
                        rtl

;--------------------------

clear_memory            = *
                        phx
                        ldx #zero_out_end-zero_out_begin-2
]loop                   stz zero_out_begin,x
                        dex
                        dex
                        bpl ]loop
                        plx
                        rts 

;--------------------------

header_str              asc 'nfc!'

check_header            = *
; patch ptr into header
                        lda ptr_header
                        sta read_head+1
                        lda ptr_header+1
                        sta read_head+2

; check header string
                        ldx #0
                        jsr read_head
                        cmp header_str
                        bne check_header_1

                        inx
                        inx
                        jsr read_head
                        cmp header_str+2
                        bne check_header_1

; check version
                        inx
                        inx
                        jsr read_head
                        and #$ff
                        cmp #3
                        bge check_header_2

                        sta ntp_file_version

                        clc
                        rts

check_header_1          = *
                        lda #1                  ;header did not match
                        sec
                        rts

check_header_2          = *
                        lda #2                  ;version did not match
                        sec
                        rts

;--------------------------

extract_header_info     = *

; get basic settings
                        ldx #5
                        jsr read_head
                        inx
                        inx
                        pha
                        and #$ff
                        sta number_of_tracks
                        sta vu_number_of_tracks
                        asl
                        sta number_of_tracks2
                        asl
                        sta number_of_tracks4
                        pla
                        xba
                        and #$ff
                        sta number_of_instruments
                        asl
                        sta number_of_instruments2

                        jsr read_head
                        inx
                        and #$ff
                        sta number_of_patterns

                        jsr read_head
                        inx
                        and #$ff
                        sta pattern_order_length

                        lda ntp_file_version
                        cmp #2
                        blt extract_header_info_1

                        jsr read_head                       ;skip over song name
                        inx
                        and #$ff
                        pha
                        txa
                        clc
                        adc 1,s
                        tax
                        pla
extract_header_info_1   = *

; get track configuration
                        ldy #0
]loop                   jsr read_head
                        inx
                        and #%111
                        asl
                        asl
                        asl
                        asl
                        sta track_channels,y
                        eor #%0001_0000
                        sta track_channels_inverse,y
                        
                        lda ntp_file_version                ;version 0 has no information on streambuffers
                        beq extract_header_info_2
                        
                        jsr read_head
                        inx
                        and #$ff
                        sta track_streambuffers,y
                        
                        lda ntp_file_version                ;version 1 has no information on which track uses which oscillator
                        cmp #2
                        blt extract_header_info_2

                        jsr read_head
                        inx
                        and #$ff
                        pha
                        and #%00011111                      ;the lowest 5 bits are the 1st oscillator the track uses
                        sta track_oscillators,y
                        pla
                        and #%10000000                      ;the upper bits is how many oscillators the track uses 0=1, 1=2
                        asl
                        asl
                        xba
                        sta track_oscillator_count,y

extract_header_info_2   = *
                        iny
                        iny
                        cpy number_of_tracks2
                        blt ]loop

; get instrument data
                        ldy #0

]loop                   jsr read_head
                        inx
                        and #%1111
                        sta instrument_types,y

                        jsr extract_instr_lengths           ;get instrument length/repeat pointer/repeat length

                        jsr read_head
                        inx
                        and #$ff
                        sta instrument_volumes,y

                        jsr read_head
                        inx
                        and #$f
                        asl
                        phy
                        tay
                        lda note_freq_ptrs_offset,y
                        ply
                        sta instrument_finetune,y

                        jsr read_head
                        inx
                        and #$ff
                        sta instrument_osc_a_ptr,y
                        sta instrument_osc_b_ptr,y

                        jsr read_head
                        inx
                        and #$ff
                        sta instrument_osc_a_siz,y
                        sta instrument_osc_b_siz,y
                        
                        lda ntp_file_version
                        cmp #2
                        blt extract_header_info_3

                        jsr read_head                       ;skip over instrument name
                        inx
                        and #$ff
                        pha
                        txa
                        clc
                        adc 1,s
                        tax
                        pla
extract_header_info_3   = *

                        iny
                        iny
                        cpy number_of_instruments2
                        blt ]loop

                        jsr generate_osc_settings

; get pattern order
                        ldy #0
]loop                   jsr read_head
                        inx
                        and #$ff
                        sta pattern_order,y
                        iny
                        cpy pattern_order_length
                        blt ]loop

; calc pointer to notes
                        txa
                        clc
                        adc ptr_header
                        sta ptr_notes
                        lda ptr_header+2
                        adc #0
                        sta ptr_notes+2

; patch note ptr
                        lda ptr_notes
                        sta read_pattern+1
                        lda ptr_notes+1
                        sta read_pattern+2

; calculate pattern length (= number of tracks x 4 x 64)
                        lda number_of_tracks
                        xba
                        sta pattern_length

; calculate pattern pointers
                        phx
                        lda ptr_notes
                        sta pattern_pointers
                        lda ptr_notes+2
                        sta pattern_pointers+2
                        ldy #0
                        ldx #1
                        cpx number_of_patterns
                        beq extract_header_info_4           ;edge case: skip further calculation if there is only 1 pattern
]loop                   lda pattern_pointers,y
                        clc
                        adc pattern_length
                        sta pattern_pointers+4,y
                        lda pattern_pointers+2,y
                        adc #0
                        sta pattern_pointers+6,y
                        iny
                        iny
                        iny
                        iny
                        inx
                        cpx number_of_patterns
                        blt ]loop
extract_header_info_4   = *
                        plx

; get ptr to instruments: it's the last calculated pattern pointer plus one pattern length
                        lda pattern_pointers,y
                        clc
                        adc pattern_length
                        sta ptr_instruments
                        lda pattern_pointers+2,y
                        adc #0
                        sta ptr_instruments+2

; patch instrument ptr
                        lda ptr_instruments
                        sta read_instrument+1
                        lda ptr_instruments+1
                        sta read_instrument+2

; for ntp files < version 2: always 2 oscillators per track
                        lda ntp_file_version
                        cmp #2
                        bge extract_header_info_5

                        ldy #0                          ;
]loop                   tya
                        sta track_oscillators,y
                        lda #2
                        sta track_oscillator_count,y
                        iny
                        iny
                        cpy number_of_tracks2
                        blt ]loop
extract_header_info_5   = *

                        rts

;--------------------------

extract_instr_lengths   = *
                        jsr read_head
                        inx
                        inx
                        sta instrument_lengths,y

                        lda ntp_file_version                ;version 0 has only 2 bytes for sample length
                        beq extract_instr_lengths_1

                        jsr read_head
                        inx                                 ;version >0 has 3 bytes for sample length
                        and #$ff
                        sta instrument_lengths_hi,y

                        jsr read_head                       ;store repeat pointer (used for streamed samples)
                        inx
                        inx
                        sta instrument_rep_ptr,y
                        jsr read_head
                        inx
                        and #$ff
                        sta instrument_rep_ptr_hi,y

                        jsr read_head                       ;store repeat length (used for streamed samples)
                        inx
                        inx
                        sta instrument_rep_len,y
                        jsr read_head
                        inx
                        and #$ff
                        sta instrument_rep_len_hi,y

extract_instr_lengths_1 = *
                        rts

;--------------------------

generate_osc_settings   = *                             ;from instruments, generate control bytes for osc A and B

                        phx
                        ldy #0

]loop                   lda instrument_types+2,y        ;see if the next instrument has an optimal length
                        and #%0100
                        sta generate_osc_opti_next

                        lda instrument_types,y
                        and #%0111
                        asl
                        tax

                        jsr (generate_osc_sett_tbl,x)

                        iny
                        iny
                        cpy number_of_instruments2
                        blt ]loop

                        plx
                        rts

generate_osc_sett_tbl   dw  generate_osc_0,generate_osc_1a,generate_osc_2,generate_osc_3 ;normal samples
                        dw  generate_osc_0,generate_osc_1b,generate_osc_2,generate_osc_3 ;sample has an optimal size

generate_osc_0          = *
                        lda #%010                       ;type 0: normal sample, use one-shot for osc A
                        sta instrument_osc_a_ctl,y
                        lda #%001                       ;stop osc B
                        sta instrument_osc_b_ctl,y
                        rts

generate_osc_1a         = *
                        lda #%110                       ;type 1a: simple looped sample, use swap mode for osc A
                        sta instrument_osc_a_ctl,y
                        lda #%111                       ;use swap mode for osc B
                        sta instrument_osc_b_ctl,y
                        rts

generate_osc_1b          = *
                        lda #%000                       ;type 1b: simple looped sample with optimal length, use free run mode for osc A
                        sta instrument_osc_a_ctl,y
                        lda #%001                       ;stop osc B
                        sta instrument_osc_b_ctl,y
                        rts

generate_osc_2          = *
                        lda generate_osc_opti_next      ;type 2: this is the header for the next instrument which is looped
                        bne generate_osc_2_1

                        lda #%1110                      ;loop has no optimal length: use swap mode for osc A with interrupt
                        sta instrument_osc_a_ctl,y
                        lda #%0111                      ;swap mode for osc B when A is done
                        sta instrument_osc_b_ctl,y

                        bra generate_osc_2_2

generate_osc_2_1        = *
                        lda #%110                       ;loop has optimal length: use swap mode for osc A
                        sta instrument_osc_a_ctl,y
                        lda #%001                       ;use free run mode for osc B when A is done
                        sta instrument_osc_b_ctl,y

generate_osc_2_2        = *
                        lda instrument_osc_a_ptr+2,y    ;since osc B plays the loop instrument, copy its ptr and siz parameters
                        sta instrument_osc_b_ptr,y

                        lda instrument_osc_a_siz+2,y
                        sta instrument_osc_b_siz,y
                        
generate_osc_3          = *
                        rts                             ;type 3: do nothing; it is played via loop header instrument (type 2)

;--------------------------

setup_channel_doubling  = *
                        ldx #talk_to_doc_play

                        lda channel_doubling
                        beq setup_channel_double_1

                        jsr get_highest_osc
                        cmp #16                         ;if there are too many oscillators needed, channel doubling is not possible
                        bge setup_channel_double_2

                        ldx #0                          ;double the oscillators
]loop                   asl track_oscillators,x
                        inc track_oscillator_count,x
                        inc track_oscillator_count,x
                        inx
                        inx
                        cpx number_of_tracks2
                        blt ]loop

                        ldx #talk_to_doc_play_dbl

setup_channel_double_1  = *
                        stx talk_to_doc_play_call+1

                        clc
                        rts

setup_channel_double_2  = *
                        lda #3                          ;error code
                        sec
                        rts

;--------------------------

get_highest_osc         = *
                        ldy #0                          ;find out if there are enough oscillators to make double channeling possible
                        tya                             ;a holds the highest oscillator number found
                        tyx
]loop                   cmp track_oscillators,y
                        bge get_highest_osc_1
                        lda track_oscillators,y
                        tyx                             ;x holds the pointer to the track with the last oscillator used
get_highest_osc_1       = *
                        iny
                        iny
                        cpy number_of_tracks2
                        blt ]loop

                        lda track_oscillator_count,x    ;get the number of oscillators needed for that track
                        lsr                             ;0=1, 2=2 oscillators
                        sec
                        adc track_oscillators,x
                        rts

;--------------------------

setup_register_tables   = *
                        ldy #0                          ;setup tables for doc registers

]loop                   lda track_oscillators,y
                        sta reg_tbl_freqlo,y

                        lda #32
                        clc
                        adc track_oscillators,y
                        sta reg_tbl_freqhi,y

                        lda #64
                        clc
                        adc track_oscillators,y
                        sta reg_tbl_vol,y

                        lda #128
                        clc
                        adc track_oscillators,y
                        sta reg_tbl_ptr,y

                        lda #160
                        clc
                        adc track_oscillators,y
                        sta reg_tbl_ctl,y

                        lda #192
                        clc
                        adc track_oscillators,y
                        sta reg_tbl_siz,y

                        iny
                        iny
                        cpy number_of_tracks2
                        blt ]loop

                        ldy #0                          ;setup mapping: which oscillator is which track?
]loop                   ldx track_oscillators,y
                        tya
                        sta oscillator_trk_tbl,x
                        iny
                        iny
                        cpy number_of_tracks2
                        blt ]loop

                        rts

;--------------------------

copy_instruments_to_doc = *
                        jsr setup_docram

                        ldy #0

]loop                   lda read_instrument+1           ;for streamed instruments, save the pointer to the sample data
                        sta instrument_ptr,y
                        lda read_instrument+3
                        and #$ff
                        sta instrument_ptr_hi,y

                        lda instrument_types,y          ;if it's a streamed sample, do not copy it into doc ram
                        and #%1000
                        bne copy_instruments_1

                        lda instrument_lengths,y        ;else copy into doc ram
                        sta copy_instrument_length
                        jsr copy_instrument

copy_instruments_1      = *
                        lda read_instrument+1
                        clc
                        adc instrument_lengths,y
                        sta read_instrument+1
                        lda read_instrument+3
                        and #$ff
                        adc instrument_lengths_hi,y

                        sep #$20
                        sta read_instrument+3
                        rep #$20

                        iny
                        iny
                        cpy number_of_instruments2

                        blt ]loop
                        rts

copy_instrument         = *
                        sep #$20
                        mx  %10

                        jsr access_doc_ram

                        stz sound_address
                        lda instrument_osc_a_ptr,y
                        sta sound_address+1
                        
                        ldx #0
]loop                   jsr read_instrument
                        inx
                        sta sound_data
                        cpx copy_instrument_length
                        blt ]loop

                        rep #$20
                        mx  %00

                        rts

;--------------------------

setup_docram            = *
                        sep #$20
                        mx  %10

                        jsr access_doc_ram

                        stz sound_address

                        lda #$80                    ;edge case: if there are only streamed instruments,
                        ldx #256                    ;make sure that page 00 has nonzero data for interrupt
]loop                   sta sound_data
                        dex
                        bne ]loop

                        rep #$20
                        mx  %00

                        rts

;--------------------------

setup_instrument_ptrs   = *
                        ldy #0

]loop                   = *
                        lda instrument_ptr,y                ;calculcate memory pointer for repeat pointer
                        clc
                        adc instrument_rep_ptr,y
                        sta instrument_rep_ptr,y
                        
                        lda instrument_ptr_hi,y
                        adc instrument_rep_ptr_hi,y
                        sta instrument_rep_ptr_hi,y

                        lda instrument_types,y
                        and #%0011
                        beq setup_instrument_ptrs_1

                        lda instrument_rep_ptr,y            ;instrument is looped
                        clc
                        adc instrument_rep_len,y
                        sta instrument_end_ptr,y
                        lda instrument_rep_ptr_hi,y
                        adc instrument_rep_len_hi,y
                        sta instrument_end_ptr_hi,y
                        bra setup_instrument_ptrs_2

setup_instrument_ptrs_1 = *
                        lda instrument_ptr,y                ;instrument is not looped
                        clc
                        adc instrument_lengths,y
                        sta instrument_end_ptr,y
                        lda instrument_ptr_hi,y
                        adc instrument_lengths_hi,y
                        sta instrument_end_ptr_hi,y

setup_instrument_ptrs_2 = *
                        iny
                        iny
                        cpy number_of_instruments2

                        blt ]loop
                        rts

;--------------------------

setup_music             = *

; reset pointers
                        stz timer
                        
                        lda #6
                        sta tempo

                        stz ptr_within_pattern
                        stz pattern_order_ptr

; get pointer to first pattern to play
                        ldx pattern_order_ptr
                        lda pattern_order,x
                        and #$ff
                        asl
                        asl
                        tax
                        lda pattern_pointers,x
                        sta read_pattern+1
                        lda pattern_pointers+1,x
                        sta read_pattern+2
                        
                        rts

;--------------------------

setup_interrupt         = *
                        ldal  sound_interrupt_ptr
                        sta   backup_interrupt_ptr
                        ldal  sound_interrupt_ptr+2
                        sta   backup_interrupt_ptr+2

                        lda   #$5c
                        stal  sound_interrupt_ptr
                        phk
                        phk
                        pla
                        stal  sound_interrupt_ptr+2
                        lda   #interrupt_handler
                        stal  sound_interrupt_ptr+1

                        sep   #$20
                        mx    %10

                        jsr   access_doc_registers

                        ldy   #0
]loop                   lda   timer_sound_settings,y
                        sta   sound_address
                        iny
                        lda   timer_sound_settings,y
                        sta   sound_data
                        iny
                        cpy   #7*2
                        bne   ]loop

                        lda   #2
                        sta   oscillator_job_tbl+interrupt_oscillator

                        rep #$20
                        mx  %00

                        lda   #reference_freq
                        sta   osc_interrupt_freq
                        sta   new_osc_interrupt_freq

                        rts

interrupt_oscillator    =     31
reference_freq          =     249                   ; interrupt frequence
timer_sound_settings    =     *                     ; set up oscillator 30 for interrupts
                        dfb   $00+interrupt_oscillator,reference_freq    ; frequency low register
                        dfb   $20+interrupt_oscillator,0                 ; frequency high register
                        dfb   $40+interrupt_oscillator,0                 ; volume register, volume = 0
                        dfb   $80+interrupt_oscillator,0                 ; wavetable pointer register, point to 0
                        dfb   $c0+interrupt_oscillator,0                 ; wavetable size register, 256 byte length
                        dfb   $e1,$3e                                    ; oscillator enable register
                        dfb   $a0+interrupt_oscillator,$08               ; mode register, set to free run

;--------------------------

setup_master_volume     = *
                        lda #255                    ; setup play volume
                        sta setplayvolume_value
                        rts

;-----------------------------------------------------------------------------------------
; play
;-----------------------------------------------------------------------------------------

play                    = *
                        phb
                        phk
                        plb

                        sta play_song_once

                        lda #1
                        sta playing

                        plb
                        clc
                        rtl

;-----------------------------------------------------------------------------------------
; stop
;-----------------------------------------------------------------------------------------

stop                    = *
                        sei
                        phb
                        phd
                        phk
                        plb

                        lda   #$c000
                        tcd

                        jsr   stop_playing

                        lda   backup_interrupt_ptr      ; restore old interrupt ptr
                        stal  sound_interrupt_ptr
                        lda   backup_interrupt_ptr+2
                        stal  sound_interrupt_ptr+2

                        cli
                        pld
                        plb
                        clc
                        rtl

;-----------------------------------------------------------------------------------------
; getvuptr
;-----------------------------------------------------------------------------------------

getvuptr                = *
                        phk
                        phk
                        pla

                        and #$ff
                        tay
                        ldx #vu_number_of_tracks

                        clc
                        rtl

;-----------------------------------------------------------------------------------------
; gete8ptr
;-----------------------------------------------------------------------------------------

gete8ptr                = *
                        phk
                        phk
                        pla

                        and #$ff
                        tay
                        ldx #last_effect_8_param

                        clc
                        rtl

;-----------------------------------------------------------------------------------------
; forcesongpos
;-----------------------------------------------------------------------------------------

forcesongpos            = *
                        sei
                        phb

                        phk
                        plb

                        cmp pattern_order_length
                        bge forcesongpos_1

                        sta force_pattern_jump_p
                        lda #1
                        sta force_pattern_jump

                        plb
                        cli
                        clc
                        rtl

forcesongpos_1          = *
                        plb
                        cli
                        sec
                        rtl

;-----------------------------------------------------------------------------------------
; getsongpos
;-----------------------------------------------------------------------------------------

getsongpos              = *
                        phb

                        phk
                        plb

                        sei

                        lda   playing                   ;get playing
                        sta   songinfo
                        
                        ldx   pattern_order_ptr         ;get pattern number
                        lda   pattern_order,x
                        and   #$ff
                        sta   songinfo+2
                        stx   songinfo+4                ;get song position
                        
                        ldy   #0               
                        lda   ptr_within_pattern
                        sta   songinfo+6                ;get ptr within pattern
                        beq   getsongpos_1
]loop                   iny                             ;get line
                        sec
                        sbc   number_of_tracks4
                        bne   ]loop
getsongpos_1            = *
                        sty   songinfo+8

                        lda   read_pattern+1            ;get ptr to pattern data
                        sta   songinfo+10
                        lda   read_pattern+2
                        sta   songinfo+11

                        lda   number_of_tracks          ;number of tracks
                        sta   songinfo+14

                        cli
                        
                        phk
                        phk
                        pla

                        and   #$ff
                        tay
                        ldx   #songinfo

                        plb
                        clc
                        rtl


;-----------------------------------------------------------------------------------------
; setplayvolume
;-----------------------------------------------------------------------------------------

setplayvolume           = *
                        phb
                        phd
                        phk
                        plb

                        pea $c000
                        pld

                        and #$ff
                        sta setplayvolume_value

                        asl
                        asl
                        sta setplayvolume_add
                        
                        stz setplayvolume_sum

                        ldx #0
]loop                   lda setplayvolume_sum+1
                        and #$ff
                        sta volume_lookup,x
                        
                        lda setplayvolume_sum
                        clc
                        adc setplayvolume_add
                        sta setplayvolume_sum

                        inx
                        inx
                        cpx #128
                        blt ]loop

                        lda setplayvolume_sum+1
                        and #$ff
                        sta volume_lookup+128
                        sta volume_lookup+130

                        lda playing
                        beq setplayvolume_2

                        sep #$20                        ;if music is playing, turn down oscillator volumes
                        mx  %10

                        jsr access_doc_registers

                        ldy #0
]loop                   lda reg_tbl_vol,y
                        sta sound_address
                        lda sound_data
                        lda sound_data
                        cmp setplayvolume_value
                        blt setplayvolume_1
                        beq setplayvolume_1
                        lda setplayvolume_value
                        sta sound_data
                        inc sound_address
                        sta sound_data
setplayvolume_1         = *
                        iny
                        iny
                        cpy number_of_tracks2
                        blt ]loop

                        rep #$20
                        mx  %00

setplayvolume_2         = *
                        pld
                        plb
                        clc
                        rtl


;-----------------------------------------------------------------------------------------
; stream sample from ram
;-----------------------------------------------------------------------------------------

streamsound             = *
                        phb
                        phd

                        phk
                        plb

                        tya
                        xba
                        sta read_streamstructure+2
                        stx read_streamstructure+1

                        lda #$c000
                        tcd

                        ldx #11
                        jsr read_streamstructure
                        inx
                        and #$ff
                        sta streamsound_osc
                        asl
                        sta streamsound_osc2

                        jsr read_streamstructure
                        and #$ff
                        sta streamsound_osc_count

                        ldy streamsound_osc2

                        ldx #0                          ;set pointer
                        jsr read_streamstructure
                        inx
                        inx
                        sta stream_instr_ptr,y
                        jsr read_streamstructure
                        inx
                        inx
                        sta stream_instr_ptr_hi,y

                        jsr read_streamstructure        ;calc end pointer
                        inx
                        inx
                        clc
                        adc stream_instr_ptr,y
                        sta stream_end_ptr,y
                        jsr read_streamstructure
                        adc stream_instr_ptr_hi,y
                        sta stream_end_ptr_hi,y

                        ldx #10                         ;setup doc ram page
                        jsr read_streamstructure
                        and #$ff
                        sta track_streambuffers,y
                        lda #0                          ;we're filling both stream pages, so the next time we stream, we copy data to the first page
                        sta stream_doc_page_offset,y
                        jsr calc_stream_doc_page

                        sei
                        sep #$20
                        mx %10
                        jsr access_doc_registers

                        lda streamsound_osc             ;stop oscillators
                        clc
                        adc #$a0
                        sta sound_address
                        lda #%11
                        ldy streamsound_osc_count
                        jsr streamsound_set_reg

                        ldy streamsound_osc2
                        jsr stream_copy                 ;fill buffer with 512 bytes for first play
                        jsr stream_copy_no_init

                        mx %00                          ;we're in 16bit mode on return

                        sep #$20
                        mx %10
                        jsr access_doc_registers

                        lda #0                          ;set freq lo
                        ldx #8
                        jsr streamsound_copy

                        lda #$20                        ;set freq hi
                        inx
                        jsr streamsound_copy

                        lda #$40                        ;set volume for interrupt osc
                        ora streamsound_osc
                        sta sound_address
                        lda #0
                        sta sound_data

                        ldx #13                         ;set volumes for other oscs
                        lda #$40
                        jsr streamsound_copy_indiv

                        lda #$80                        ;set wavetable ptr for interrupt osc
                        ora streamsound_osc
                        sta sound_address
                        lda #0
                        sta sound_data

                        ldx #10                         ;set wavetable ptr for other oscs
                        lda #$81
                        ldy streamsound_osc_count
                        dey
                        jsr streamsound_copy_no_y

                        lda #$c0                        ;set wavetable siz for interrupt osc
                        ora streamsound_osc
                        sta sound_address
                        lda #0                          ;256 bytes
                        sta sound_data

                        inc sound_address               ;set wavetable siz for other oscs
                        ldy streamsound_osc_count
                        dey
                        lda #%001001                    ;512 bytes
                        jsr streamsound_set_reg

                        ldx streamsound_osc             ;flag that we have a streaming sample on this oscillator
                        lda #10
                        sta oscillator_job_tbl,x

                        lda streamsound_osc_count       ;record how many oscillators this stream requires to stop them later
                        ldy streamsound_osc2
                        sta stream_osc_count,y

                        lda streamsound_osc2            ;set that this osc=track so that we know which instrument to stream
                        ldy streamsound_osc
                        sta oscillator_trk_tbl,y

                        lda #$a0                        ;start interrupt osc
                        ora streamsound_osc
                        sta sound_address
                        lda #%1000
                        sta sound_data

                        ldx #14                         ;start other oscs
                        lda #$a0
                        jsr streamsound_copy_indiv

debug_skip = *
                        rep #$20
                        mx %00
                        cli

                        pld
                        plb
                        clc
                        rtl

                        mx %10
streamsound_copy        = *                             ;copy a byte from stream structure to multiple doc registers
                        ldy streamsound_osc_count
streamsound_copy_no_y   = *
                        clc
                        adc streamsound_osc
                        sta sound_address
                        jsr read_streamstructure
streamsound_set_reg     = *
]loop                   sta sound_data
                        inc sound_address
                        dey
                        bpl ]loop
                        rts

streamsound_copy_indiv  = *                             ;copy bytes from stream structure to doc registers
                        sec
                        adc streamsound_osc
                        sta sound_address
                        ldy streamsound_osc_count
]loop                   jsr read_streamstructure
                        inx
                        inx
                        sta sound_data
                        inc sound_address
                        dey
                        bne ]loop
                        rts
                        mx %00

;-----------------------------------------------------------------------------------------
; interupt handler (=the player)
;-----------------------------------------------------------------------------------------

interrupt_handler       = *
                        phb
                        phd
                        php                                 ; DDIIGS: explicitly preserve caller P
                                                            ; (including E flag implication via MX);
                                                            ; the IIgs ROM IRQ dispatcher saves
                                                            ; outer state, but a caller running in
                                                            ; native MX=11 emulation gets MX leaked
                                                            ; to MX=00 unless we PLP just before RTL.

                        phk
                        plb

                        clc
                        xce
                        rep #$30
                        mx  %00

                        lda #$c000
                        tcd

                        sep #$20
                        mx  %10

                        jsr   access_doc_registers

                        ldal  osc_interrupt             ; which oscillator generated the interrupt?

interrupt_handler_loop  = *
                        and   #%00111110
                        lsr
                        sta   interrupt_handler_osc
                        ldy   interrupt_handler_osc

                        lda   oscillator_trk_tbl,y      ;which track is it?
                        sta   interrupt_track

                        lda   oscillator_job_tbl,y      ;what is the job of the oscillator?
                        sta   interrupt_job

                        ldx   interrupt_job
                        jsr   (interrupt_jump_tbl,x)

]loop                   lda   sound_control
                        bmi   ]loop

                        lda   #$e0
                        sta   sound_address
                        lda   sound_data
                        lda	  #0                        ;dummy wait?
                        sta   sound_address
                        lda   sound_data
                        bpl   interrupt_handler_loop

                        sep   #$30
                        plp                                 ; DDIIGS: restore caller P
                                                            ; (matches PHP at entry — see comment
                                                            ; there). PLP runs before PLD/PLB so
                                                            ; the stack order matches push order
                                                            ; (PHB→PHD→PHP). The CLC below forces
                                                            ; C=0 (= IRQ handled per IIgs
                                                            ; convention) regardless of what PLP
                                                            ; just restored.
                        pld
                        plb
                        clc
                        rtl

interrupt_jump_tbl      = *
                        dw    interrupt_handler_rts     ;0=do nothing
                        dw    tracker_interrupt         ;2=tracker interrupt
                        dw    interrupt_handler_rts     ;4=do nothing
                        dw    interrupt_stream          ;6=stream instrument
                        dw    interrupt_handler_instr   ;8=instrument with left osc triggering interrupt
                        dw    interrupt_streamsound     ;10=stream sample

;--------------------------

interrupt_handler_instr = *
                        mx    %10
                        ldy   interrupt_track           ; y = track*2
                        ldx   osc_instrument,y

                        lda   reg_tbl_ptr,y
                        sta   sound_address
                        lda   instrument_osc_b_ptr,x
                        sta   sound_data

                        lda   reg_tbl_siz,y
                        sta   sound_address
                        lda   instrument_osc_b_siz,x
                        sta   sound_data

                        lda   reg_tbl_ctl,y
                        sta   sound_address
                        lda   instrument_osc_b_ctl,x
                        ora   track_channels,y
                        ora   #1
                        sta   sound_data

                        lda   channel_doubling
                        beq   interrupt_handler_ins_1

                        lda   reg_tbl_ptr,y
                        inc
                        inc
                        sta   sound_address
                        lda   instrument_osc_b_ptr,x
                        sta   sound_data

                        lda   reg_tbl_siz,y
                        inc
                        inc
                        sta   sound_address
                        lda   instrument_osc_b_siz,x
                        sta   sound_data

                        lda   reg_tbl_ctl,y
                        inc
                        inc
                        sta   sound_address
                        lda   instrument_osc_b_ctl,x
                        ora   track_channels,y
                        ora   #1
                        sta   sound_data

interrupt_handler_ins_1 = *
                        ldx   track_oscillators,y
                        lda   #0
                        sta   oscillator_job_tbl,x      ;nothing more to do here

interrupt_handler_rts   = *
                        rts

;--------------------------

tracker_interrupt       = *                             ; it's the 50Hz interrupt
                        mx    %10
                        lda   playing
                        beq   interrupt_handler_rts

                        rep   #$30
                        mx    %00

                        lda   timer
                        beq   parse_tracks              ;fetch track information only when timer=0

                        inc
                        cmp   tempo
                        blt   tracker_interrupt_1
                        lda   #0
tracker_interrupt_1     sta   timer

                        lda   tempo                     ;edge case: when tempo=1 do only parse tracks
                        cmp   #1
                        beq   parse_tracks

                        jsr   handle_effects
                        jmp   talk_to_doc

;--------------------------

parse_tracks_2          = *
                        dec   delay_pattern             ;do pattern delay
                        jsr   handle_effects
                        jmp   talk_to_doc

parse_tracks             = *                            ;fetch track information
                        inc   timer

                        lda   delay_pattern
                        bne   parse_tracks_2

                        jsr   check_pattern_jump        ;if we reached the end of the pattern or there was a pattern jump, handle it

                        ldy   #0
                        ldx   ptr_within_pattern
                        lda   #$ffff
                        sta   loop_position_jump

parse_tracks_loop       = *
                        jsr   read_pattern
                        pha
                        and   #$ff
                        asl
                        sta   note
                        pla
                        xba
                        and   #$ff
                        asl
                        sta   sample
                        inx
                        inx

                        jsr   read_pattern
                        pha
                        and   #$f
                        asl
                        sta   effect
                        pla
                        xba
                        and   #$ff
                        sta   effect_param
                        inx
                        inx

                        phx
                        jsr   setup_effect
                        plx

                        iny
                        iny
                        
                        cpy   number_of_tracks2
                        blt   parse_tracks_loop

                        lda   loop_position_jump        ;if there is an active loop, jump
                        bmi   parse_tracks_1
                        tax
parse_tracks_1          = *
                        stx   ptr_within_pattern


talk_to_doc             = *                             ;for each track: talk to ensoniq doc

; stop all oscillators that will be retriggered
                        sep #$20
                        mx  %10

                        jsr   access_doc_registers

                        ldy   #0
]loop                   lda   what_to_do,y              ;check if we need to start an instrument
                        bpl   talk_to_doc_stoploop

                        ldx   track_oscillator_count,y
                        jsr   (talk_to_doc_stop_tbl,x)

talk_to_doc_stoploop    iny
                        iny

                        cpy   number_of_tracks2
                        blt   ]loop

; prepare streamed instruments (if any)
                        rep   #$20
                        mx    %00

                        ldy   #0
]loop                   lda   what_to_do,y              ;check if we need to start an instrument
                        and   #%1000_0000
                        beq   talk_to_doc_streamloop

                        lda   osc_instrument_type,y     ;check if we're dealing with a streamed instrument
                        and   #%10000
                        beq   talk_to_doc_streamloop

                        jsr   talk_to_doc_prepstream

talk_to_doc_streamloop  iny
                        iny

                        cpy   number_of_tracks2
                        blt   ]loop

; set registers
                        sep #$20
                        mx  %10

                        jsr   access_doc_registers

                        ldy   #0
]loop                   lda   what_to_do,y              ;check if we need to start an instrument
                        beq   talk_to_doc_loop

                        ldx   osc_instrument_type,y
talk_to_doc_play_call   jsr   (talk_to_doc_play,x)

talk_to_doc_loop        iny
                        iny

                        cpy   number_of_tracks2
                        blt   ]loop
                        
; change timer frequency (if needed)
                        ldy   new_osc_interrupt_freq
                        cpy   osc_interrupt_freq
                        bne   talk_to_doc_timer
                        rts

talk_to_doc_timer       = *
                        sty   osc_interrupt_freq        ;set new interrupt frequency

                        lda   #$00+interrupt_oscillator
                        sta   sound_address
                        lda   osc_interrupt_freq
                        sta   sound_data
                        lda   #$20+interrupt_oscillator
                        sta   sound_address
                        lda   osc_interrupt_freq+1
                        sta   sound_data
                        rts


; stop oscillator(s) for a track

                        mx  %10

talk_to_doc_stop_1osc   = *
                        lda reg_tbl_ctl,y
                        sta sound_address
                        lda #%0000_0011
                        sta sound_data
                        rts
talk_to_doc_stop_2osc   = *
                        lda reg_tbl_ctl,y
                        sta sound_address
                        lda #%0000_0011
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        rts
talk_to_doc_stop_4osc   = *
                        lda reg_tbl_ctl,y
                        sta sound_address
                        lda #%0000_0011
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        rts

; set registers for a track

; values can be combined by setting bits in what_to_do
; %10000000 = set control (and turn oscillators off before)
; %00000010 = set freq
; %00000001 = set volume
; %00000000 = do nothing

; There are 6 combinations:
; case 1: doc ram based instrument using 1 oscillator
; case 2: doc ram based instrument using 2 oscillators
; case 3: streamed sample
; case 4: doc ram based sample using 1 oscillator with channel doubling
; case 5: doc ram based sample using 2 oscillators with channel doubling
; case 6: streamed sample with channel doubling

; y = track number
; a = what_to_do

                        mx  %10

; case 1: doc ram based instrument using 1 oscillator

talk_to_doc_1osc        = *
                        bit #%00000001
                        beq talk_to_doc_1osc_1

                        lda reg_tbl_vol,y               ;set volume
                        sta sound_address
                        lda osc_volume,y
                        sta sound_data
                        
                        lda what_to_do,y
talk_to_doc_1osc_1      = *
                        bit #%00000010
                        beq talk_to_doc_1osc_2

                        lda reg_tbl_freqlo,y            ;set freq
                        sta sound_address
                        lda osc_freq,y
                        sta sound_data

                        lda reg_tbl_freqhi,y
                        sta sound_address
                        lda osc_freq+1,y
                        sta sound_data
                        
talk_to_doc_1osc_2      = *
                        lda what_to_do,y
                        bpl talk_to_doc_1osc_3

                        ldx osc_instrument,y
                        
                        lda reg_tbl_ptr,y               ;set wave ptr via instrument
                        sta sound_address
                        lda instrument_osc_a_ptr,x
                        sta sound_data

                        lda reg_tbl_siz,y               ;set wave size via instrument
                        sta sound_address
                        lda instrument_osc_a_siz,x
                        sta sound_data

                        lda reg_tbl_ctl,y               ;set control via instrument
                        sta sound_address
                        lda instrument_osc_a_ctl,x
                        ora track_channels,y
                        sta sound_data

                        ldx track_oscillators,y
                        lda #0
                        sta oscillator_job_tbl,x        ;flag that we await no interrupt for this instrument

                        lda osc_volume,y                ;update vu meter
                        sta vu_data,y
talk_to_doc_1osc_3      = *
                        rts

; case 2: doc ram based instrument using 2 oscillators

talk_to_doc_2osc        = *
                        bit #%00000001
                        beq talk_to_doc_2osc_1

                        lda reg_tbl_vol,y               ;set volume
                        sta sound_address
                        lda osc_volume,y
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        
                        lda what_to_do,y
talk_to_doc_2osc_1      = *
                        bit #%00000010
                        beq talk_to_doc_2osc_2

                        lda reg_tbl_freqlo,y            ;set freq
                        sta sound_address
                        lda osc_freq,y
                        sta sound_data
                        inc sound_address
                        sta sound_data

                        lda reg_tbl_freqhi,y
                        sta sound_address
                        lda osc_freq+1,y
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        
talk_to_doc_2osc_2      = *
                        lda what_to_do,y
                        bpl talk_to_doc_2osc_3

                        ldx osc_instrument,y
                        
                        lda reg_tbl_ptr,y               ;set wave ptr via instrument
                        sta sound_address
                        lda instrument_osc_a_ptr,x
                        sta sound_data
                        inc sound_address
                        lda instrument_osc_b_ptr,x
                        sta sound_data

                        lda reg_tbl_siz,y               ;set wave size via instrument
                        sta sound_address
                        lda instrument_osc_a_siz,x
                        sta sound_data
                        inc sound_address
                        lda instrument_osc_b_siz,x
                        sta sound_data

                        lda reg_tbl_ctl,y               ;set control via instrument
                        sta sound_address
                        lda instrument_osc_a_ctl,x
                        ora track_channels,y
                        sta sound_data
                        inc sound_address
                        lda instrument_osc_b_ctl,x
                        ora track_channels,y
                        sta sound_data

                        lda instrument_osc_a_ctl,x
                        ldx track_oscillators,y
                        and #%1000
                        sta oscillator_job_tbl,x        ;flag that we might await an interrupt for this instrument

                        lda osc_volume,y                ;update vu meter
                        sta vu_data,y
talk_to_doc_2osc_3      = *
                        rts

; case 3: streamed sample

talk_to_doc_str         = *
                        lda reg_tbl_vol,y
                        sta sound_address
                        lda #0                          ;always set volume to zero for 1st oscillator
                        sta sound_data                  ;can't use stz because we must write 1 byte!

                        lda what_to_do,y
                        bit #%00000001
                        beq talk_to_doc_str_1

                        inc sound_address
                        lda osc_volume,y                ;set volume for 2nd oscillator
                        sta sound_data
                        
                        lda what_to_do,y
talk_to_doc_str_1       = *
                        bit #%00000010
                        beq talk_to_doc_str_2

                        lda reg_tbl_freqlo,y            ;set freq
                        sta sound_address
                        lda osc_freq,y
                        sta sound_data
                        inc sound_address
                        sta sound_data

                        lda reg_tbl_freqhi,y
                        sta sound_address
                        lda osc_freq+1,y
                        sta sound_data
                        inc sound_address
                        sta sound_data
talk_to_doc_str_2       = *
                        lda what_to_do,y
                        bpl talk_to_doc_str_3

                        lda reg_tbl_ptr,y               ;set pointer to stream buffer for this track
                        sta sound_address
                        lda #0                          ;pointer to interrupt wave
                        sta sound_data      
                        inc sound_address            
                        lda stream_doc_page,y
                        sta sound_data

                        lda reg_tbl_siz,y               ;set table size to match stream buffer for this track
                        sta sound_address
                        lda #%000_000                   ;000 => 256 bytes
                        sta sound_data
                        inc sound_address
                        lda #%001_001                   ;001 => 512 bytes
                        sta sound_data

                        lda reg_tbl_ctl,y               ;turn on oscillators!
                        sta sound_address
                        lda #%0000_1000                 ;free run for osc A with interrupt
                        sta sound_data
                        inc sound_address
                        lda track_channels,y            ;free run for osc B
                        sta sound_data

                        ldx track_oscillators,y
                        lda #6
                        sta oscillator_job_tbl,x        ;flag that streaming should happen on this track

                        lda osc_volume,y                ;update vu meter
                        sta vu_data,y

talk_to_doc_str_3       = *
                        rts

; case 4: doc ram based sample using 1 oscillator with channel doubling

talk_to_doc_1osc_dbl    = *
                        lda what_to_do,y
                        bit #%00000001
                        beq talk_to_doc_1osc_dbl_1

                        lda reg_tbl_vol,y               ;set volume
                        sta sound_address
                        lda osc_volume,y
                        sta sound_data
                        inc sound_address
                        lsr                             ;only half the volume
                        sta sound_data
                        
                        lda what_to_do,y
talk_to_doc_1osc_dbl_1  = *
                        bit #%00000010
                        beq talk_to_doc_1osc_dbl_2
                        
                        lda reg_tbl_freqlo,y            ;set freq
                        sta sound_address
                        lda osc_freq,y
                        sta sound_data
                        inc sound_address
                        sta sound_data

                        lda reg_tbl_freqhi,y
                        sta sound_address
                        lda osc_freq+1,y
                        sta sound_data
                        inc sound_address
                        sta sound_data

talk_to_doc_1osc_dbl_2  = *
                        lda what_to_do,y
                        bpl talk_to_doc_1osc_dbl_3

                        ldx osc_instrument,y

                        lda reg_tbl_ptr,y                   ;set wave ptr via instrument
                        sta sound_address
                        lda instrument_osc_a_ptr,x
                        sta sound_data
                        inc sound_address
                        sta sound_data

                        lda reg_tbl_siz,y                   ;set wave size via instrument
                        sta sound_address
                        lda instrument_osc_a_siz,x
                        sta sound_data
                        inc sound_address
                        sta sound_data

                        lda reg_tbl_ctl,y                   ;set control via instrument
                        sta sound_address
                        lda instrument_osc_a_ctl,x
                        ora track_channels,y
                        sta sound_data
                        inc sound_address
                        lda instrument_osc_a_ctl,x
                        ora track_channels_inverse,y        ;use opposite channel than normally
                        sta sound_data

                        ldx track_oscillators,y
                        lda #0
                        sta oscillator_job_tbl,x            ;flag that we await no interrupt for this instrument

                        lda osc_volume,y                    ;update vu meter
                        sta vu_data,y

talk_to_doc_1osc_dbl_3  = *
                        rts

; case 5: doc ram based sample using 2 oscillators with channel doubling

talk_to_doc_2osc_dbl    = *
                        lda what_to_do,y
                        bit #%00000001
                        beq talk_to_doc_2osc_dbl_1

                        lda reg_tbl_vol,y                   ;set volume
                        sta sound_address
                        lda osc_volume,y
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        inc sound_address
                        lsr                                 ;only half the volume
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        
                        lda what_to_do,y
talk_to_doc_2osc_dbl_1  = *
                        bit #%00000010
                        beq talk_to_doc_2osc_dbl_2
                        
                        lda reg_tbl_freqlo,y                ;set freq
                        sta sound_address
                        lda osc_freq,y
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        inc sound_address
                        sta sound_data

                        lda reg_tbl_freqhi,y
                        sta sound_address
                        lda osc_freq+1,y
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        inc sound_address
                        sta sound_data
talk_to_doc_2osc_dbl_2  = *
                        lda what_to_do,y
                        bpl talk_to_doc_1osc_dbl_3          ;nearest rts

                        ldx osc_instrument,y

                        lda reg_tbl_ptr,y                   ;set wave ptr via instrument
                        sta sound_address
                        lda instrument_osc_a_ptr,x
                        sta sound_data
                        inc sound_address
                        lda instrument_osc_b_ptr,x
                        sta sound_data
                        inc sound_address
                        lda instrument_osc_a_ptr,x
                        sta sound_data
                        inc sound_address
                        lda instrument_osc_b_ptr,x
                        sta sound_data

                        lda reg_tbl_siz,y                   ;set wave size via instrument
                        sta sound_address
                        lda instrument_osc_a_siz,x
                        sta sound_data
                        inc sound_address
                        lda instrument_osc_b_siz,x
                        sta sound_data
                        inc sound_address
                        lda instrument_osc_a_siz,x
                        sta sound_data
                        inc sound_address
                        lda instrument_osc_b_siz,x
                        sta sound_data

                        lda reg_tbl_ctl,y                   ;set control via instrument
                        sta sound_address
                        lda instrument_osc_a_ctl,x
                        ora track_channels,y
                        sta sound_data
                        inc sound_address
                        lda instrument_osc_b_ctl,x
                        ora track_channels,y
                        sta sound_data
                        inc sound_address
                        lda instrument_osc_a_ctl,x
                        and #%0111                          ;no interrupts!
                        ora track_channels_inverse,y        ;use opposite channel than normally
                        sta sound_data
                        inc sound_address
                        lda instrument_osc_b_ctl,x
                        and #%0111                          ;no interrupts!
                        ora track_channels_inverse,y        ;use opposite channel than normally
                        sta sound_data

                        lda instrument_osc_a_ctl,x
                        ldx track_oscillators,y
                        and #%1000
                        sta oscillator_job_tbl,x            ;flag that we await an interrupt for this instrument

                        lda osc_volume,y                    ;update vu meter
                        sta vu_data,y

                        rts

; case 6: streamed sample with channel doubling

talk_to_doc_str_dbl     = *
                        lda reg_tbl_vol,y
                        sta sound_address
                        lda #0                              ;always set volume to zero for 1st oscillator
                        sta sound_data                      ;can't use stz because we must write 1 byte!
                        
                        inc sound_address
                        inc sound_address
                        lda #0                              ;always set volume to zero for 1st oscillator
                        sta sound_data                      ;can't use stz because we must write 1 byte!

                        lda what_to_do,y
                        bit #%00000001
                        beq talk_to_doc_str_dbl_1

                        lda reg_tbl_vol,y
                        inc
                        sta sound_address
                        lda osc_volume,y                    ;set volume for 2nd oscillator
                        sta sound_data

                        inc sound_address
                        inc sound_address
                        lsr                                 ;only half the volume
                        sta sound_data
                        
                        lda what_to_do,y
talk_to_doc_str_dbl_1   = *
                        bit #%00000010
                        beq talk_to_doc_str_dbl_2
                        
                        lda reg_tbl_freqlo,y                ;set freq
                        sta sound_address
                        lda osc_freq,y
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        inc sound_address
                        sta sound_data

                        lda reg_tbl_freqhi,y
                        sta sound_address
                        lda osc_freq+1,y
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        inc sound_address
                        sta sound_data
                        inc sound_address
                        sta sound_data

talk_to_doc_str_dbl_2   = *
                        lda what_to_do,y
                        bpl talk_to_doc_str_dbl_3
                        
                        lda reg_tbl_ptr,y                   ;set pointer to stream buffer for this track
                        sta sound_address
                        lda #0                              ;pointer to interrupt wave
                        sta sound_data      
                        inc sound_address            
                        lda stream_doc_page,y
                        sta sound_data
                        inc sound_address
                        lda #0                              ;pointer to interrupt wave
                        sta sound_data      
                        inc sound_address            
                        lda stream_doc_page,y
                        sta sound_data

                        lda reg_tbl_siz,y                   ;set table size to match stream buffer for this track
                        sta sound_address
                        lda #%000_000                       ;000 => 256 bytes
                        sta sound_data
                        inc sound_address
                        lda #%001_001                       ;001 => 512 bytes
                        sta sound_data
                        inc sound_address
                        lda #%000_000                       ;000 => 256 bytes
                        sta sound_data
                        inc sound_address
                        lda #%001_001                       ;001 => 512 bytes
                        sta sound_data

                        lda reg_tbl_ctl,y                   ;turn on oscillators!
                        sta sound_address
                        lda #%0000_1000                     ;free run for osc A with interrupt
                        sta sound_data
                        inc sound_address
                        lda track_channels,y                ;free run for osc B
                        sta sound_data
                        inc sound_address
                        lda #%0000_0011                     ;turn off osc A
                        sta sound_data
                        inc sound_address
                        lda track_channels_inverse,y        ;free run for osc B on opposite channel
                        sta sound_data

                        ldx track_oscillators,y
                        lda #6
                        sta oscillator_job_tbl,x            ;flag that streaming should happen on this track

                        lda osc_volume,y                    ;update vu meter
                        sta vu_data,y

talk_to_doc_str_dbl_3   = *
                        rts

;--------------------------

                        mx %00
talk_to_doc_prepstream  = *                             ;prepare stream buffer for the start of an instrument
                        ldx osc_instrument,y
                        lda instrument_ptr,x            ;prepare pointer into instrument in ram
                        clc
                        adc sample_offset,y             ;add sample offset if present
                        sta stream_instr_ptr,y
                        lda instrument_ptr_hi,x
                        adc #0
                        sta stream_instr_ptr_hi,y

                        lda #0                          ;we're filling both stream pages, so the next time we stream, we copy data to the first page
                        sta stream_doc_page_offset,y

                        jsr calc_stream_doc_page

                        jsr stream_copy                 ;fill buffer with 512 bytes for first play
                        jmp stream_copy_no_init

;--------------------------

calc_stream_doc_page    = *                             ;determine page in sound ram to stream to
                        lda track_streambuffers,y
                        clc
                        adc stream_doc_page_offset,y
                        sta stream_doc_page,y
                        rts

;--------------------------

check_pattern_jump      = *
                        ldx   pattern_jump
                        jmp   (check_pattern_jump_tbl,x)

check_pattern_jump_tbl  = *
                        dw    check_pattern_end
                        dw    handle_pattern_jump
                        dw    handle_pattern_break
                        dw    stop_playing

;--------------------------

check_pattern_end       = *
    	                lda   force_pattern_jump
                        beq   check_pattern_end_0
                        
                        lda   force_pattern_jump_p
                        sta   pattern_jump_param
                        stz   force_pattern_jump
                        bra   handle_pattern_jump

check_pattern_end_0     = *
                        lda   ptr_within_pattern        ;check if we're at the end of the pattern
                        cmp   pattern_length
                        blt   check_pattern_end_4

                        stz   ptr_within_pattern        ;reset pointer within pattern
                        stz   loop_position             ;reset loop in pattern
                        stz   loop_position_active

check_pattern_end_1     = *
                        ldx   pattern_order_ptr         ;end of pattern; set next pattern
                        inx

check_pattern_end_2     = *
                        cpx   pattern_order_length
                        blt   check_pattern_end_3

                        lda   play_song_once
                        beq   check_pattern_end_2_1

                        jmp   stop_playing              ;stop playing after this song

check_pattern_end_2_1   = *
                        ldx   #0

check_pattern_end_3     = *
                        stx   pattern_order_ptr

                        lda   pattern_order,x           ;set new offset position to new pattern
                        and   #$ff
                        asl
                        asl
                        tax
                        lda   pattern_pointers,x
                        sta   read_pattern+1
                        lda   pattern_pointers+1,x
                        sta   read_pattern+2

check_pattern_end_4     = *
                        rts

;--------------------------

handle_pattern_jump     = *                             ;jump to a specific pattern order position
                        stz pattern_jump

                        stz loop_position               ;reset loop in pattern
                        stz loop_position_active
                        
                        stz ptr_within_pattern          ;reset pointer within pattern

                        ldx pattern_jump_param
                        jmp check_pattern_end_2

;--------------------------

handle_pattern_break    = *                             ;stop pattern here and go to next pattern but start at specific line
                        stz pattern_jump

                        ldx pattern_jump_param
                        lda pattern_break_ptrs,x
                        and #$ff
                        beq handle_pattern_break_1
                        
                        tax
                        lda #0
                        clc

]loop                   adc number_of_tracks4           ;poor man's multiply
                        dex
                        bne ]loop

handle_pattern_break_1  = *
                        sta ptr_within_pattern

                        stz loop_position               ;reset loop in pattern
                        stz loop_position_active

                        jmp check_pattern_end_1

;--------------------------

stop_playing            = *
                        
                        stz   playing                   ; stop player

                        jsr   get_highest_osc
                        inc
                        tay

                        sep   #$20
                        mx    %10

                        jsr   access_doc_registers

                        ldx   number_of_tracks2
                        beq   stop_playing_1

                        lda   reg_tbl_ctl               ; stop all oscillators in use
                        sta   sound_address
                        lda   #%11
]loop                   sta   sound_data
                        inc   sound_address
                        dey
                        bne   ]loop

stop_playing_1          = *
                        lda   #$a0+interrupt_oscillator ; stop interrupt oscillator
                        sta   sound_address
                        lda   #3
                        sta   sound_data

                        rep   #$20
                        mx    %00
                        rts

;--------------------------

setup_effect_jump_rts   rts
setup_effect_jump_tbl   = *
                        dw    setup_arpeggio
                        dw    setup_slide_up
                        dw    setup_slide_down
                        dw    setup_slide_to_note
                        dw    setup_vibrato
                        dw    setup_volslide            ;Continue 'Slide to note', but also do Volume slide
                        dw    setup_volslide            ;Continue 'Vibrato', but also do Volume slide
                        dw    setup_tremolo
                        dw    setup_gs_panning          ;IIGS panning
                        dw    setup_sample_offset
                        dw    setup_volslide
                        dw    setup_positionjump
                        dw    setup_setvolume
                        dw    setup_patternbreak
                        dw    setup_e_effects
                        dw    setup_setspeed

setup_e_effect_jump_tbl = *
                        dw    setup_effect_jump_rts     ;Not supported: Set filter on/off
                        dw    fineslide_up
                        dw    fineslide_down
                        dw    set_glissando
                        dw    set_vibrato_waveform
                        dw    set_sample_finetune
                        dw    set_loop_pattern
                        dw    set_tremolo_waveform
                        dw    setup_effect_jump_rts     ;unused
                        dw    setup_retrigger
                        dw    volslide_up
                        dw    volslide_down
                        dw    setup_note_cut
                        dw    setup_note_delay
                        dw    setup_delay_pattern
                        dw    setup_invertloop

setup_effect            = *
                        lda   #0                        ;by default, do nothing
                        sta   what_to_do,y
                        sta   vu_data,y                 ;reset vu meter

; if sample is defined, set it
; and set volume according to instrument

                        lda   sample
                        beq   setup_effect_2

                        sta   curr_sample,y             ;store current sample if nonzero

; if sample is defined, always set the volume from the instrument
                        tax
                        dex
                        dex

                        lda   instrument_volumes,x      ;use default volume from sample
                        sta   curr_volume,y             ;backup volume setting in track
                        asl
                        tax
                        lda   volume_lookup,x
                        sta   osc_volume,y              ;store volume for osc

                        lda   #%00000001                ;mark that we want to set the volume
                        sta   what_to_do,y

                        lda   #0                        ;clear sample offset
                        sta   sample_offset,y

                        sta   invertloop_offset,y       ;reset sample position for invert loop
                        sta   invertloop_offset_hi,y

                        lda   note                      ;if there is a note, skip
                        bne   setup_effect_2

                        ldx   osc_instrument,y          ;if the current instrument is a non-ideal-sized non-streamed looped sample, retrigger note
                        lda   instrument_types,x        ;this is an edge case to avoid clicking sounds
                        cmp   #%0001
                        beq   setup_effect_1
                        cmp   #%0010
                        bne   setup_effect_2

setup_effect_1          = *
                        lda   curr_note,y               ;no prev note, skip
                        beq   setup_effect_2
                        sta   note                      ;else retrigger note

setup_effect_2          = *

                        lda   effect
                        sta   curr_effect,y
                        tax
                        jsr   (setup_effect_jump_tbl,x)

check_play_note  = *

; if note is defined, play it

                        lda   note
                        beq   check_play_note_1         ;no note, don't play

                        sta   curr_note,y               ;backup note

                        lda   curr_sample,y
                        beq   check_play_note_1         ;no last sample defined, do not play the note
                        
                        dec
                        dec
                        sta   osc_instrument,y          ;we have to play this instrument
                        tax

                        lda   instrument_types,x        ;copy type for quicker access later
                        asl
                        sta   osc_instrument_type,y

                        lda   instrument_finetune,x
                        clc
                        adc   note
                        tax
                        lda   note_freq_ptrs,x          ;use note and sample's finetune and look up a frequency
                        sta   curr_ptrfinetune,y
                        tax
                        lda   freq_finetune,x
                        sta   osc_freq,y                ;store freq for osc

                        lda   what_to_do,y
                        ora   #%10000010                ;store that we want to set frequency and start the sample
                        sta   what_to_do,y

check_play_note_1       = *
                        rts

;--------------------------

setup_arpeggio          = *
                        lda effect_param
                        beq setup_arpeggio_2            ;no arpeggio, turn off if it was running before

                        lda note                        ;if we have a new note, use it
                        bne setup_arpeggio_1
                        lda arpeggio_note1,y            ;else use last played
                        beq setup_arpeggio_2            ;no last note - do nothing

                        sta note                        ;make sure we play the last note again

setup_arpeggio_1        = *
                        sta arpeggio_note1,y

                        lda effect_param
                        and #$f0
                        lsr
                        lsr
                        lsr
                        clc
                        adc note
                        sta arpeggio_note2,y

                        lda effect_param
                        and #$f
                        asl
                        clc
                        adc note
                        sta arpeggio_note3,y

                        lda #$8000
setup_arpeggio_2        = *
                        sta arpeggio_ptr,y

                        rts

;--------------------------

setup_slide_up          = *
                        lda effect_param                ;do not slide on first tick
                        asl
                        sta slide_delta,y
                        rts

;--------------------------

setup_slide_down        = *
                        lda effect_param                ;do not slide on first tick
                        asl
                        sta slide_delta,y
                        rts

;--------------------------

setup_slide_to_note     = *
                        lda effect_param
                        beq setup_slide_to_note_1       ;if there is a speed set, use this, else keep whatever is there
                        asl
                        sta slide_delta,y
setup_slide_to_note_1   = *

                        lda note                        ;if there is a note set, use this as target, else keep whatever is there
                        beq setup_slide_to_note_2

                        sta slide_target_note,y         ;if a note is set, this is our target to slide to
                        ldx curr_sample,y
                        lda instrument_finetune-2,x
                        clc
                        adc note
                        tax
                        lda note_freq_ptrs,x            ;find the target in the freq table to slide to
                        sta slide_target,y

                        stz note                        ;with this command, the note is a parameter and is not played
                        lda what_to_do,y
                        and #%00000101
                        sta what_to_do,y
setup_slide_to_note_2   = *
                        rts

;--------------------------

setup_vibrato           = *
                        lda effect_param
                        and #$f0                        ;If either x or y are 0, then the old vibrato values will be used.
                        beq setup_vibrato_1
                        lsr
                        lsr
                        lsr
                        sta vibrato_rate,y
setup_vibrato_1         = *

                        lda effect_param
                        and #$f
                        beq setup_vibrato_2
                        xba
                        lsr                             ;*128
                        clc
                        adc vibrato_tableoffset,y
                        sta vibrato_table,y
setup_vibrato_2         = *

                        lda #0                          ;reset position in vibrato table
                        sta vibrato_pos,y
                        rts

;--------------------------

setup_tremolo           = *
                        lda effect_param
                        and #$f0
                        beq setup_tremolo_1
                        lsr
                        lsr
                        lsr
                        sta tremolo_rate,y
setup_tremolo_1         = *

                        lda effect_param
                        and #$f
                        beq setup_tremolo_2
                        xba
                        lsr                             ;*128
                        clc
                        adc tremolo_tableoffset,y
                        sta tremolo_table,y
setup_tremolo_2         = *

                        lda #0                          ;reset position in tremolo table: this is actually a bug in protracker
                        sta tremolo_pos,y

                        rts

;--------------------------

setup_gs_panning        = *
                        lda effect_param
                        cmp #8
                        bge setup_gs_panning_1          ;GS panning: if < 8, then we set the channel for this track
                        asl
                        asl
                        asl
                        asl
                        sta track_channels,y
                        eor #%0001_0000
                        sta track_channels_inverse,y
                        rts
setup_gs_panning_1      sta last_effect_8_param         ;if it is not a panning effect, store in shared register for timing purposes
                        rts

;--------------------------

setup_volslide          = *
                        lda effect_param
                        beq setup_volslide_1

                        cmp #$10
                        bge setup_volslide_1

                        lda #0
                        sec
                        sbc effect_param
                        sta volslide_delta,y

                        rts

setup_volslide_1        = *
                        and #$f0                        ;If both x and y are non-zero, the y value is ignored (assumed to be 0).
                        lsr
                        lsr
                        lsr
                        lsr
                        sta volslide_delta,y

                        rts

;--------------------------

setup_setvolume         = *
                        lda effect_param
                        cmp #64
                        blt setup_setvolume_1
                        lda #64
setup_setvolume_1       sta curr_volume,y
                        asl
                        tax
                        lda volume_lookup,x
                        sta osc_volume,y

                        lda   what_to_do,y
                        ora   #%00000001                ;store that we want to set the volume immediately
                        sta   what_to_do,y
                        rts

;--------------------------

setup_positionjump      = *
                        lda effect_param                ;Legal values are from 0 to 127
                        and #$7f
                        sta pattern_jump_param

                        lda #2
                        sta pattern_jump

                        rts

;--------------------------

setup_patternbreak      = *
                        lda effect_param
                        sta pattern_jump_param

                        lda #4
                        sta pattern_jump

                        rts

;--------------------------

setup_e_effects         = *
                        lda effect_param
                        and #$f0
                        lsr
                        lsr
                        lsr
                        sta curr_e_effect,y
                        tax
                        lda effect_param
                        and #$f
                        sta effect_param
                        jmp (setup_e_effect_jump_tbl,x)

;--------------------------

setup_setspeed          = *
                        lda effect_param
                        bne setup_setspeed_2

                        lda #6                          ;when 0, stop music
                        sta pattern_jump
                        rts

setup_setspeed_1        = *
                        sta tempo
                        rts

setup_setspeed_2        = *
                        cmp #$20                        ;when < 32, assume set tempo
                        blt setup_setspeed_1

                        sec                             ;else interrupt timer
                        sbc #$20
                        asl
                        tax
                        lda bpm_to_freq,x
                        sta new_osc_interrupt_freq
                        rts

;--------------------------

setup_sample_offset     = *                             ;this effect only works with streamed samples
                        ldx sample
                        bne setup_sample_offset_1       ;there is a new sample with this command

                        ldx curr_sample,y               ;use the same sample again
                        beq setup_sample_offset_3       ;no previous sample, do nothing

setup_sample_offset_1   = *
                        dex
                        dex
                        lda instrument_types,x
                        and #%1000
                        beq setup_sample_offset_3       ;if it is not a streamed sample, do nothing

                        lda effect_param
                        beq setup_sample_offset_2       ;if 0, reuse the previous value

                        xba                             ;According to the doc, "The offset is measured in words."
                        sta sample_offset,y             ;but it's really only bytes
                        sta sample_offset_backup,y

                        lda instrument_lengths_hi,x     ;check if the offset would exceed the sample size
                        bne setup_sample_offset_3

                        lda instrument_lengths,x
                        cmp sample_offset,y
                        bge setup_sample_offset_3

;edge case: if the desired sample offset is greater than the length of the sample, place the offset at the end of the sample
;if the sample is not looped, go back 8 stopper bytes
;if the sample is looped, go back 1 byte
                        dec
                        sta sample_offset,y

                        lda instrument_types,x          ;is it a looped instrument?
                        and #%0001
                        bne setup_sample_offset_3

                        lda instrument_lengths,x        ;no, go back 8 stopper bytes
                        sec
                        sbc #8
                        sta sample_offset,y
                        sta sample_offset_backup,y
                        rts

setup_sample_offset_2   = *
                        lda sample_offset_backup,y
                        sta sample_offset,y
setup_sample_offset_3   = *
                        rts

;--------------------------

fineslide_up            = *
                        asl effect_param

                        lda curr_ptrfinetune,y
                        clc
                        adc effect_param
                        cmp #max_finetune_ptr
                        blt fineslide_up_1
                        lda #max_finetune_ptr

fineslide_up_1          sta curr_ptrfinetune,y

                        tax
                        lda freq_finetune,x
                        sta osc_freq,y

                        lda   what_to_do,y
                        ora   #%00000010                ;store that we want to set the freq for this track
                        sta   what_to_do,y
                        rts

;--------------------------

fineslide_down          = *
                        asl effect_param
                        
                        lda curr_ptrfinetune,y
                        sec
                        sbc effect_param
                        bpl fineslide_down_1
                        lda #0

fineslide_down_1        sta curr_ptrfinetune,y

                        tax
                        lda freq_finetune,x
                        sta osc_freq,y

                        lda   what_to_do,y
                        ora   #%00000010                ;store that we want to set the freq for this track
                        sta   what_to_do,y
                        rts

;--------------------------

set_glissando           = *
                        lda effect_param               ;only 0 and 1 are valid, but PT doesn't check that
                        sta glissando,y
                        rts

;--------------------------

set_vibrato_waveform    = *
                        lda effect_param
                        cmp #8
                        bge set_vibrato_waveform_1

                        and #%11
                        asl
                        tax

                        lda waveforms,x
                        sta vibrato_tableoffset,y

                        lda effect_param
                        and #%100
                        sta vibrato_retrig,y

set_vibrato_waveform_1  = *
                        rts

;--------------------------

set_sample_finetune     = *
                        ldx sample
                        bne set_sample_finetune_1
                        ldx curr_sample,y
                        beq set_sample_finetune_2
 
set_sample_finetune_1   = *
                        phx
                        lda effect_param
                        asl
                        tax
                        lda note_freq_ptrs_offset,x
                        plx
                        sta instrument_finetune-2,x

set_sample_finetune_2   = *
                        rts

;--------------------------

set_loop_pattern        = *
                        lda effect_param            ;0=record position, else loop
                        bne set_loop_pattern_1

                        lda ptr_within_pattern      ;record pattern position
                        sta loop_position
                        rts

set_loop_pattern_1      = *                         ;start or continue loop
                        lda loop_position_active
                        bne set_loop_pattern_2

                        lda #1                      ;start loop
                        sta loop_position_active
                        lda effect_param
                        sta loop_repeat_count
                        lda loop_position
                        sta loop_position_jump
                        rts

set_loop_pattern_2      = *                         ;continue loop, enough repetitions?
                        dec loop_repeat_count
                        beq set_loop_pattern_3

                        lda loop_position
                        sta loop_position_jump
                        rts

set_loop_pattern_3      = *                         ;loop has ended
                        stz loop_position_active
                        rts

;--------------------------

set_tremolo_waveform    = *
                        lda effect_param
                        cmp #8
                        bge set_tremolo_waveform_1

                        and #%11
                        asl
                        tax

                        lda waveforms,x
                        sta tremolo_tableoffset,y

                        lda effect_param
                        and #%100
                        sta tremolo_retrig,y

set_tremolo_waveform_1  = *
                        rts

;--------------------------

setup_retrigger         = *
                        lda effect_param
                        sta retrigger_steps,y
                        lda #0
                        sta retrigger_count,y
                        rts

;--------------------------

volslide_up             = *
                        lda curr_volume,y
                        clc
                        adc effect_param
                        cmp #64
                        blt volslide_up_1
                        lda #64

volslide_up_1           = *
                        sta curr_volume,y

                        asl
                        tax
                        lda   volume_lookup,x
                        sta   osc_volume,y              ;store volume for osc

                        lda   what_to_do,y
                        ora   #%00000001                ;store that we want to set the volume for this track
                        sta   what_to_do,y

                        rts

;--------------------------

volslide_down           = *
                        lda curr_volume,y
                        sec
                        sbc effect_param
                        bpl volslide_up_1
                        lda #0
                        bra volslide_up_1

;--------------------------

setup_note_cut          = *
                        lda effect_param
                        sta note_cut,y
                        rts

;--------------------------

setup_note_delay        = *
                        lda note
                        beq setup_note_delay_1

                        sta note_delay_note,y

                        lda effect_param
                        sta note_delay_count,y

                        stz note

setup_note_delay_1      = *
                        rts

;--------------------------

setup_delay_pattern     = *
                        lda effect_param
                        sta delay_pattern
                        rts

;--------------------------

setup_invertloop        = *
                        lda effect_param
                        sta invertloop_tbl_speed,y
                        jmp handle_invertloop

;--------------------------

handle_effect_jump_tbl  = *
                        dw    handle_arpeggio
                        dw    handle_slide_up
                        dw    handle_slide_down
                        dw    handle_slide_to_note
                        dw    handle_vibrato
                        dw    handle_effect_5
                        dw    handle_effect_6
                        dw    handle_tremolo
                        dw    handle_effect_nothing
                        dw    handle_effect_nothing
                        dw    handle_volslide
                        dw    handle_effect_nothing
                        dw    handle_effect_nothing
                        dw    handle_effect_nothing
                        dw    handle_e_effects
                        dw    handle_effect_nothing

handle_e_eff_jump_tbl   dw    handle_effect_nothing
                        dw    handle_effect_nothing
                        dw    handle_effect_nothing
                        dw    handle_effect_nothing
                        dw    handle_effect_nothing
                        dw    handle_effect_nothing
                        dw    handle_effect_nothing
                        dw    handle_effect_nothing
                        dw    handle_effect_nothing
                        dw    handle_retrigger
                        dw    handle_effect_nothing
                        dw    handle_effect_nothing
                        dw    handle_note_cut
                        dw    handle_note_delay
                        dw    handle_effect_nothing
                        dw    handle_invertloop

handle_effects          = *             ;when a non-tracker line is encountered, do what the last effect needs to do
                        ldy #0

]loop                   lda #0
                        sta what_to_do,y

                        ldx curr_effect,y
                        jsr (handle_effect_jump_tbl,x)

                        iny
                        iny
                        cpy number_of_tracks2
                        blt ]loop

handle_effect_nothing   rts

;--------------------------

handle_arpeggio         = *
                        lda arpeggio_ptr,y
                        beq handle_arpeggio_5

                        inc
                        cmp #$8003
                        blt handle_arpeggio_1
                        lda #$8000
handle_arpeggio_1       = *
                        sta arpeggio_ptr,y

                        cmp #$8000
                        bne handle_arpeggio_2
                        lda arpeggio_note1,y
                        bra handle_arpeggio_4

handle_arpeggio_2       = *
                        cmp #$8001
                        bne handle_arpeggio_3
                        lda arpeggio_note2,y
                        bra handle_arpeggio_4

handle_arpeggio_3       = *
                        lda arpeggio_note3,y

handle_arpeggio_4       = *
                        sta note
                        sta curr_note,y

                        lda curr_sample,y
                        sta sample

                        jmp check_play_note

handle_arpeggio_5       = *
                        rts

;--------------------------

handle_slide_up         = *
                        lda curr_ptrfinetune,y
                        clc
                        adc slide_delta,y
                        cmp #max_finetune_ptr
                        blt handle_slide_up_1
                        lda #max_finetune_ptr

handle_slide_up_1       sta curr_ptrfinetune,y

                        tax
                        lda freq_finetune,x
                        sta osc_freq,y

                        lda   what_to_do,y
                        ora   #%00000010                ;store that we want to set the freq for this track
                        sta   what_to_do,y
                        rts

;--------------------------

handle_slide_down       = *
                        lda curr_ptrfinetune,y
                        sec
                        sbc slide_delta,y
                        cmp #max_finetune_ptr
                        blt handle_slide_down_1
                        lda #0

handle_slide_down_1     sta curr_ptrfinetune,y

                        tax
                        lda freq_finetune,x
                        sta osc_freq,y

                        lda   what_to_do,y
                        ora   #%00000010                ;store that we want to set the freq for this track
                        sta   what_to_do,y
                        rts

;--------------------------

handle_slide_to_note    = *
                        lda glissando,y
                        beq handle_slide_to_note_0

;when glissando is on, we have to slide in semitones
                        lda curr_note,y
                        cmp slide_target_note,y
                        beq handle_slide_to_note_3
                        bge handle_slide_to_note_g1

                        inc
                        inc
                        bra handle_slide_to_note_g2

handle_slide_to_note_g1 = *
                        dec
                        dec

handle_slide_to_note_g2 = *
                        sta curr_note,y

                        ldx curr_sample,y
                        lda instrument_finetune-2,x
                        clc
                        adc curr_note,y
                        tax
                        lda note_freq_ptrs,x
                        bra handle_slide_to_note_2

;no glissando

handle_slide_to_note_0  = *
                        lda curr_ptrfinetune,y
                        cmp slide_target,y
                        beq handle_slide_to_note_3
                        bge handle_slide_to_note_4

                        clc
                        adc slide_delta,y
                        cmp slide_target,y
                        blt handle_slide_to_note_2
handle_slide_to_note_1  = *
                        lda slide_target,y
handle_slide_to_note_2  = *
                        sta curr_ptrfinetune,y
                        tax
                        lda freq_finetune,x
                        sta osc_freq,y

                        lda   what_to_do,y
                        ora   #%00000010                ;store that we want to set the freq for this track
                        sta   what_to_do,y
handle_slide_to_note_3  = *
                        rts

handle_slide_to_note_4  = *
                        sec
                        sbc slide_delta,y
                        cmp slide_target,y
                        bge handle_slide_to_note_2
                        bra handle_slide_to_note_1

;--------------------------

handle_vibrato          = *
                        lda vibrato_table,y
                        clc
                        adc vibrato_pos,y
                        tax
                        lda sine_tbl,x
                        clc
                        adc curr_ptrfinetune,y
                        tax
                        lda freq_finetune,x
                        sta osc_freq,y

                        lda   what_to_do,y
                        ora   #%00000010                ;store that we want to set the freq for this track
                        sta   what_to_do,y

                        lda vibrato_pos,y
                        clc
                        adc vibrato_rate,y
                        cmp #128
                        blt handle_vibrato_1

                        ldx vibrato_retrig,y
                        bne handle_vibrato_2

                        and #127
handle_vibrato_1        sta vibrato_pos,y
handle_vibrato_2        rts

;--------------------------

handle_effect_5         = *
                        jsr handle_slide_to_note        ;Continue 'Slide to note', but also do Volume slide
                        jmp handle_volslide

;--------------------------

handle_effect_6         = *
                        jsr handle_vibrato              ;Continue 'Vibrato', but also do Volume slide
                        jmp handle_volslide

;--------------------------

handle_tremolo          = *
                        lda tremolo_table,y
                        clc
                        adc tremolo_pos,y
                        tax
                        lda sine_tbl,x
                        lsr                             ;divide by 2 because sine table is factors of 2
                        clc
                        adc curr_volume,y
                        asl
                        tax
                        lda volume_lookup,x
                        sta osc_volume,y

                        lda   what_to_do,y
                        ora   #%00000001                ;store that we want to set the vol for this track
                        sta   what_to_do,y

                        lda tremolo_pos,y
                        clc
                        adc tremolo_rate,y
                        cmp #128
                        blt handle_tremolo_1

                        ldx tremolo_retrig,y
                        bne handle_tremolo_2

                        and #127
handle_tremolo_1        sta tremolo_pos,y
handle_tremolo_2        rts


;--------------------------

handle_volslide         = *
                        ldx #0
                        lda curr_volume,y
                        clc
                        adc volslide_delta,y
                        bmi handle_volslide_1           ;when < 0 then 0

                        ldx #64
                        cmp #64
                        bge handle_volslide_1           ;when > 64 then 64

                        tax

handle_volslide_1       = *
                        txa
                        sta   curr_volume,y             ;backup volume setting in track
                        asl
                        tax
                        lda   volume_lookup,x
                        sta   osc_volume,y              ;store volume for osc

                        lda   what_to_do,y
                        ora   #%00000001                ;store that we want to set the volume for this track
                        sta   what_to_do,y

                        rts

;--------------------------

handle_e_effects        = *
                        ldx curr_e_effect,y
                        jmp (handle_e_eff_jump_tbl,x)

;--------------------------

handle_retrigger        = *
                        lda retrigger_count,y
                        inc
                        cmp retrigger_steps,y
                        blt handle_retrigger_2

                        lda curr_sample,y
                        beq handle_retrigger_1

                        lda what_to_do,y            ;do retrigger
                        ora #%10000000
                        sta what_to_do,y

handle_retrigger_1      = *
                        lda #0
handle_retrigger_2      = *
                        sta retrigger_count,y

                        rts

;--------------------------

handle_note_cut         = *
                        lda note_cut,y
                        beq handle_note_cut_1
                        dec
                        sta note_cut,y
                        bne handle_note_cut_1

                        lda #0
                        sta curr_volume,y
                        sta osc_volume,y

                        lda what_to_do,y            ;store that we want to set the volume
                        ora #%00000001
                        sta what_to_do,y

handle_note_cut_1       = *
                        rts

;--------------------------

handle_note_delay       = *
                        lda note_delay_count,y
                        dec
                        sta note_delay_count,y
                        bne handle_note_delay_1

                        lda note_delay_note,y
                        sta note

                        jmp check_play_note

handle_note_delay_1     = *
                        rts

;--------------------------

handle_invertloop       = *
                        ldx invertloop_tbl_speed,y
                        beq handle_invertloop_1         ;when 0, then nothing to do

                        lda invertloop_add_tbl,x        ;add the value from the table
                        and #$ff
                        clc
                        adc invertloop_tbl_value,y
                        cmp #128
                        bge handle_invertloop_2         ;invert bytes when >= 128

                        sta invertloop_tbl_value,y      ;not yet
handle_invertloop_1     = *
                        rts

handle_invertloop_2     = *
                        lda #0
                        sta invertloop_tbl_value,y      ;reset value

                        ldx curr_sample,y
                        beq handle_invertloop_1         ;no current sample, do nothing
                        dex
                        dex                             ;x=ptr into instrument table
                        lda instrument_types,x
                        bit #%1000
                        bne handle_invertloop_str       ;branch if it's a streamed instrument

                        and #%11                        ;no streamed instrument
                        beq handle_invertloop_1         ;if it's not looped, do nothing
                        cmp #%01
                        beq handle_invertloop_doc_1     ;the current instrument is the loop

                        inx                             ;the next instrument is the loop
                        inx

handle_invertloop_doc_1 = *
                        lda instrument_osc_a_ptr,x      ;get page of instrument in doc ram
                        xba
                        sta sound_address

                        lda invertloop_offset,y         ;increase/wrap pointer into sample
                        inc
                        cmp instrument_lengths,x
                        blt handle_invertloop_doc_2
                        lda #0

handle_invertloop_doc_2 = *
                        sta invertloop_offset,y         ;calc pointer into doc memory
                        clc
                        adc sound_address
                        sta sound_address

                        sep #$20
                        mx  %10

                        jsr access_doc_ram_no_inc

                        lda sound_data                  ;read once and discard
                        lda #0                          ;do negate
                        sec
                        sbc sound_data
                        sta sound_data

                        rep #$20
                        mx  %00

                        rts


handle_invertloop_str   = *                             ;streamed sample
                        and #%1
                        beq handle_invertloop_1         ;if it's not looped, do nothing

                        tyx                             ;increase pointer into sample byte
                        inc invertloop_offset,x
                        bne handle_invertloop_str_1
                        inc invertloop_offset_hi,x
handle_invertloop_str_1 = *

;streamed looped sample
                        lda invertloop_offset,y         ;check if pointer outside of instrument loop
                        cmp instrument_rep_len,x
                        bne handle_invertloop_str_2
                        lda invertloop_offset_hi,y
                        cmp instrument_rep_len_hi,x
                        bne handle_invertloop_str_2

                        lda #0                          ;reset pointer
                        sta invertloop_offset,y
                        sta invertloop_offset_hi,y
handle_invertloop_str_2 = *

                        lda instrument_rep_ptr,x        ;prepare pointers
                        clc
                        adc invertloop_offset,y
                        sta handle_invertloop_inv_1+1
                        sta handle_invertloop_inv_2+1
                        
                        sep #$20
                        mx %10

                        lda instrument_rep_ptr_hi,x
                        adc invertloop_offset_hi,y
                        sta handle_invertloop_inv_1+3
                        sta handle_invertloop_inv_2+3

                        mx %10
                        lda #0                          ;do negate
                        sec
handle_invertloop_inv_1 = *
                        sbcl 0
handle_invertloop_inv_2 = *
                        stal 0

                        rep #$20
                        mx %00
                        rts

;--------------------------

interrupt_stream        = *
                        mx    %10
                        ldy   interrupt_track           ; y = track*2

                        jsr   stream_copy               ;access to doc ram, set pointer in doc ram; always copy 256 bytes straight
                        mx    %00

                        ldx   osc_instrument,y          ; x = ptr into instrument tables

                        lda   stream_instr_ptr_hi,y     ;have we reached the end of the instrument?
                        cmp   instrument_end_ptr_hi,x
                        blt   interrupt_stream_nowrap
                        lda   stream_instr_ptr,y
                        cmp   instrument_end_ptr,x
                        blt   interrupt_stream_nowrap

                        lda   instrument_types,x        ;is it a looped instrument?
                        and   #%0001
                        beq   interrupt_stream_noloop

                        lda   stream_instr_ptr,y        ;instrument is looped, move pointer back
                        sec
                        sbc   instrument_rep_len,x
                        sta   stream_instr_ptr,y
                        lda   stream_instr_ptr_hi,y
                        sbc   instrument_rep_len_hi,x
                        sta   stream_instr_ptr_hi,y

interrupt_stream_nowrap = *
                        lda   stream_doc_page_offset,y ;prepare next stream buffer offset
                        eor   #1
                        sta   stream_doc_page_offset,y

                        jsr   calc_stream_doc_page
                        sep   #$20
                        mx    %10
                        jmp   access_doc_registers

interrupt_stream_noloop = *                             ;the streamed instrument is not looped, turn off 1st oscillator
                        sep   #$20
                        mx    %10

                        jsr   access_doc_registers

                        lda   reg_tbl_ctl,y
                        sta   sound_address
                        lda   #3
                        sta   sound_data                ;turn off interrupting oscillator

                        ldx   track_oscillators,y
                        lda   #0
                        sta   oscillator_job_tbl,x      ;flag that no streaming should happen on this track

                        rts
                        mx    %00

                        
;--------------------------

interrupt_streamsound   = *
                        mx    %10
                        ldy   interrupt_track           ; y = track*2

                        jsr   stream_copy               ;access to doc ram, set pointer in doc ram; always copy 256 bytes straight
                        mx    %00

                        lda   stream_instr_ptr_hi,y     ;have we reached the end of the sample?
                        cmp   stream_end_ptr_hi,y
                        blt   interrupt_streamsound_1
                        lda   stream_instr_ptr,y
                        cmp   stream_end_ptr,y
                        blt   interrupt_streamsound_1

                        sep   #$20
                        mx    %10

                        jsr   access_doc_registers

                        lda   #$a0
                        ora   interrupt_handler_osc
                        sta   sound_address
                        lda   #3
                        sta   sound_data                ;turn off interrupting oscillator

                        ldx stream_osc_count,y          ;turn off other oscs
]loop                   inc sound_address
                        sta sound_data
                        dex
                        bne ]loop

                        ldx   interrupt_handler_osc
                        lda   #0
                        sta   oscillator_job_tbl,x      ;nothing more to do here

                        rts
                        mx    %00

interrupt_streamsound_1 = *
                        lda   stream_doc_page_offset,y  ;prepare next stream buffer offset
                        eor   #1
                        sta   stream_doc_page_offset,y

                        jsr   calc_stream_doc_page
                        sep   #$20
                        mx    %10
                        jmp   access_doc_registers
                        mx    %00

;--------------------------

stream_copy             = *
                        sep   #$20
                        jsr   access_doc_ram
                        rep   #$20

                        lda   stream_doc_page,y         ;set pointer where to copy instrument data to
                        xba
                        sta   sound_address

stream_copy_no_init     = *
                        ldx   stream_instr_ptr,y        ;x = ptr to copy from

                        sep   #$20
                        mx    %10

                        lda   stream_instr_ptr_hi,y     ;set bank to where the sample is
                        pha
                        plb

; to be as fast as possible, unroll copy code
; each copy instruction is 5 bytes per byte copied
;
;                       lda $0000,x                     ;3 bytes
;                       sta sound_data                  ;2 bytes
;                       lda $0001,x
;                       sta sound_data
;                       ...
]offset                 = 0
                        lup   256
                        lda:  ]offset,x
                        sta   sound_data
]offset                 = ]offset+1
                        --^

                        phk                             ;restore bank
                        plb

                        rep   #$20
                        mx    %00

                        lda   stream_instr_ptr,y        ;advance pointer
                        clc
                        adc   #256
                        sta   stream_instr_ptr,y
                        lda   stream_instr_ptr_hi,y
                        adc   #0
                        sta   stream_instr_ptr_hi,y

                        rts


;--------------------------

; instrument types
; 0000 = not looped    doc ram based    any size      1 osc
; 0001 = looped        doc ram based    any size      2 osc
; 0010 = loop head     doc ram based    any size      2 osc
; 0011 = loop          doc ram based    any size      2 osc
; 0100 = not looped    doc ram based    ideal size    1 osc
; 0101 = looped        doc ram based    ideal size    1 osc
; 0110 = loop head     doc ram based    ideal size    2 osc
; 0111 = loop          doc ram based    ideal size    2 osc
; 1000 = not looped    streamed         any size      2 osc
; 1001 = looped        streamed         any size      2 osc

talk_to_doc_stop_tbl    = *
                        dw talk_to_doc_stop_1osc
                        dw talk_to_doc_stop_2osc
                        dw talk_to_doc_stop_4osc

talk_to_doc_play        = *
                        dw talk_to_doc_1osc             ; 0000 = not looped    doc ram based    any size      1 osc
                        dw talk_to_doc_2osc             ; 0001 = looped        doc ram based    any size      2 osc
                        dw talk_to_doc_2osc             ; 0010 = loop head     doc ram based    any size      2 osc
                        dw talk_to_doc_2osc             ; 0011 = loop          doc ram based    any size      2 osc
                        dw talk_to_doc_1osc             ; 0100 = not looped    doc ram based    ideal size    1 osc
                        dw talk_to_doc_1osc             ; 0101 = looped        doc ram based    ideal size    1 osc
                        dw talk_to_doc_2osc             ; 0110 = loop head     doc ram based    ideal size    2 osc
                        dw talk_to_doc_2osc             ; 0111 = loop          doc ram based    ideal size    2 osc
                        dw talk_to_doc_str              ; 1000 = not looped    streamed         any size      2 osc
                        dw talk_to_doc_str              ; 1001 = looped        streamed         any size      2 osc

talk_to_doc_play_dbl    = *
                        dw talk_to_doc_1osc_dbl
                        dw talk_to_doc_2osc_dbl
                        dw talk_to_doc_2osc_dbl
                        dw talk_to_doc_2osc_dbl
                        dw talk_to_doc_1osc_dbl
                        dw talk_to_doc_1osc_dbl
                        dw talk_to_doc_2osc_dbl
                        dw talk_to_doc_2osc_dbl
                        dw talk_to_doc_str_dbl
                        dw talk_to_doc_str_dbl

;--------------------------

volume_lookup           = *
                        dw 0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60
                        dw 64,68,72,76,80,84,88,92,96,100,104,108,112,116,120,124
                        dw 128,132,136,140,144,148,152,156,160,164,168,172,176,180,184,188
                        dw 192,196,200,204,208,212,216,220,224,228,232,236,240,244,248,252
                        dw 255,255

max_finetune_ptr        = 3574
freq_finetune           = *
                        dw 38,38,38,38,38,38,38,38,38,38,38,38,38,38,38,38
                        dw 38,38,38,38,38,38,39,39,39,39,39,39,39,39,39,39
                        dw 39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39
                        dw 39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39
                        dw 39,39,39,39,40,40,40,40,40,40,40,40,40,40,40,40
                        dw 40,40,40,40,40,40,40,40,40,40,40,40,40,40,40,40
                        dw 40,40,40,40,40,40,40,40,40,40,40,40,40,40,40,41
                        dw 41,41,41,41,41,41,41,41,41,41,41,41,41,41,41,41
                        dw 41,41,41,41,41,41,41,41,41,41,41,41,41,41,41,41
                        dw 41,41,41,41,41,41,41,41,42,42,42,42,42,42,42,42
                        dw 42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42
                        dw 42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,43
                        dw 43,43,43,43,43,43,43,43,43,43,43,43,43,43,43,43
                        dw 43,43,43,43,43,43,43,43,43,43,43,43,43,43,43,43
                        dw 43,43,43,43,44,44,44,44,44,44,44,44,44,44,44,44
                        dw 44,44,44,44,44,44,44,44,44,44,44,44,44,44,44,44
                        dw 44,44,44,44,44,44,44,44,45,45,45,45,45,45,45,45
                        dw 45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45
                        dw 45,45,45,45,45,45,45,45,45,45,46,46,46,46,46,46
                        dw 46,46,46,46,46,46,46,46,46,46,46,46,46,46,46,46
                        dw 46,46,46,46,46,46,46,46,46,46,46,47,47,47,47,47
                        dw 47,47,47,47,47,47,47,47,47,47,47,47,47,47,47,47
                        dw 47,47,47,47,47,47,47,47,47,47,48,48,48,48,48,48
                        dw 48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48
                        dw 48,48,48,48,48,48,48,48,49,49,49,49,49,49,49,49
                        dw 49,49,49,49,49,49,49,49,49,49,49,49,49,49,49,49
                        dw 49,49,49,49,49,50,50,50,50,50,50,50,50,50,50,50
                        dw 50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50
                        dw 51,51,51,51,51,51,51,51,51,51,51,51,51,51,51,51
                        dw 51,51,51,51,51,51,51,51,51,51,51,52,52,52,52,52
                        dw 52,52,52,52,52,52,52,52,52,52,52,52,52,52,52,52
                        dw 52,52,52,52,53,53,53,53,53,53,53,53,53,53,53,53
                        dw 53,53,53,53,53,53,53,53,53,53,53,53,53,54,54,54
                        dw 54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54
                        dw 54,54,54,54,55,55,55,55,55,55,55,55,55,55,55,55
                        dw 55,55,55,55,55,55,55,55,55,55,55,56,56,56,56,56
                        dw 56,56,56,56,56,56,56,56,56,56,56,56,56,56,56,56
                        dw 56,57,57,57,57,57,57,57,57,57,57,57,57,57,57,57
                        dw 57,57,57,57,57,57,57,58,58,58,58,58,58,58,58,58
                        dw 58,58,58,58,58,58,58,58,58,58,58,59,59,59,59,59
                        dw 59,59,59,59,59,59,59,59,59,59,59,59,59,59,59,60
                        dw 60,60,60,60,60,60,60,60,60,60,60,60,60,60,60,60
                        dw 60,60,61,61,61,61,61,61,61,61,61,61,61,61,61,61
                        dw 61,61,61,61,61,62,62,62,62,62,62,62,62,62,62,62
                        dw 62,62,62,62,62,62,62,63,63,63,63,63,63,63,63,63
                        dw 63,63,63,63,63,63,63,63,64,64,64,64,64,64,64,64
                        dw 64,64,64,64,64,64,64,64,64,65,65,65,65,65,65,65
                        dw 65,65,65,65,65,65,65,65,65,66,66,66,66,66,66,66
                        dw 66,66,66,66,66,66,66,66,66,67,67,67,67,67,67,67
                        dw 67,67,67,67,67,67,67,67,68,68,68,68,68,68,68,68
                        dw 68,68,68,68,68,68,68,69,69,69,69,69,69,69,69,69
                        dw 69,69,69,69,69,69,70,70,70,70,70,70,70,70,70,70
                        dw 70,70,70,70,71,71,71,71,71,71,71,71,71,71,71,71
                        dw 71,71,72,72,72,72,72,72,72,72,72,72,72,72,72,73
                        dw 73,73,73,73,73,73,73,73,73,73,73,73,74,74,74,74
                        dw 74,74,74,74,74,74,74,74,75,75,75,75,75,75,75,75
                        dw 75,75,75,75,75,76,76,76,76,76,76,76,76,76,76,76
                        dw 76,77,77,77,77,77,77,77,77,77,77,77,78,78,78,78
                        dw 78,78,78,78,78,78,78,78,79,79,79,79,79,79,79,79
                        dw 79,79,79,80,80,80,80,80,80,80,80,80,80,81,81,81
                        dw 81,81,81,81,81,81,81,81,82,82,82,82,82,82,82,82
                        dw 82,82,83,83,83,83,83,83,83,83,83,83,84,84,84,84
                        dw 84,84,84,84,84,84,85,85,85,85,85,85,85,85,85,85
                        dw 86,86,86,86,86,86,86,86,86,87,87,87,87,87,87,87
                        dw 87,87,88,88,88,88,88,88,88,88,88,89,89,89,89,89
                        dw 89,89,89,89,90,90,90,90,90,90,90,90,91,91,91,91
                        dw 91,91,91,91,92,92,92,92,92,92,92,92,92,93,93,93
                        dw 93,93,93,93,93,94,94,94,94,94,94,94,95,95,95,95
                        dw 95,95,95,95,96,96,96,96,96,96,96,96,97,97,97,97
                        dw 97,97,97,98,98,98,98,98,98,98,99,99,99,99,99,99
                        dw 99,100,100,100,100,100,100,100,101,101,101,101,101,101,101,102
                        dw 102,102,102,102,102,103,103,103,103,103,103,103,104,104,104,104
                        dw 104,104,105,105,105,105,105,105,106,106,106,106,106,106,106,107
                        dw 107,107,107,107,107,108,108,108,108,108,108,109,109,109,109,109
                        dw 110,110,110,110,110,110,111,111,111,111,111,111,112,112,112,112
                        dw 112,113,113,113,113,113,113,114,114,114,114,114,115,115,115,115
                        dw 115,116,116,116,116,116,117,117,117,117,117,118,118,118,118,118
                        dw 119,119,119,119,119,120,120,120,120,120,121,121,121,121,121,122
                        dw 122,122,122,123,123,123,123,123,124,124,124,124,125,125,125,125
                        dw 125,126,126,126,126,127,127,127,127,128,128,128,128,128,129,129
                        dw 129,129,130,130,130,130,131,131,131,131,132,132,132,132,133,133
                        dw 133,133,134,134,134,134,135,135,135,136,136,136,136,137,137,137
                        dw 137,138,138,138,139,139,139,139,140,140,140,141,141,141,141,142
                        dw 142,142,143,143,143,143,144,144,144,145,145,145,146,146,146,146
                        dw 147,147,147,148,148,148,149,149,149,150,150,150,151,151,151,152
                        dw 152,152,153,153,153,154,154,154,155,155,155,156,156,156,157,157
                        dw 158,158,158,159,159,159,160,160,160,161,161,162,162,162,163,163
                        dw 164,164,164,165,165,165,166,166,167,167,167,168,168,169,169,170
                        dw 170,170,171,171,172,172,172,173,173,174,174,175,175,176,176,176
                        dw 177,177,178,178,179,179,180,180,181,181,182,182,183,183,184,184
                        dw 184,185,185,186,186,187,187,188,189,189,190,190,191,191,192,192
                        dw 193,193,194,194,195,195,196,197,197,198,198,199,199,200,201,201
                        dw 202,202,203,204,204,205,205,206,207,207,208,208,209,210,210,211
                        dw 212,212,213,214,214,215,216,216,217,218,218,219,220,220,221,222
                        dw 223,223,224,225,225,226,227,228,228,229,230,231,232,232,233,234
                        dw 235,235,236,237,238,239,240,240,241,242,243,244,245,246,246,247
                        dw 248,249,250,251,252,253,254,255,256,256,257,258,259,260,261,262
                        dw 263,264,265,266,267,268,270,271,272,273,274,275,276,277,278,279
                        dw 280,282,283,284,285,286,287,289,290,291,292,294,295,296,297,299
                        dw 300,301,303,304,305,307,308,309,311,312,314,315,317,318,319,321
                        dw 322,324,325,327,329,330,332,333,335,337,338,340,342,343,345,347
                        dw 348,350,352,354,356,357,359,361,363,365,367,369,371,373,375,377
                        dw 379,381,383,385,388,390,392,394,397,399,401,403,406,408,411,413
                        dw 416,418,421,423,426,429,431,434,437,439,442,445,448,451,454,457
                        dw 460,463,466,469,473,476,479,482,486,489,493,496,500,504,507,511
                        dw 515,519,523,527,531,535,539,543,548,552,556,561,566,570,575,580
                        dw 585,590,595,600,605,611,616,622,627,633,639,645,651,657,663,670
                        dw 676,683,690,697,704,711,719,726,734,742,750,758,767,775,784,793
                        dw 802,812,821,831,841,852,862,873,885,896,908,920,932,945,958,972
                        dw 986,1000,1015,1030,1045,1061,1078,1095,1113,1131,1150,1169,1190,1210,1232,1254
                        dw 1278,1302,1327,1353,1380,1408,1437,1468,1500,1533,1568,1605,1643,1683,1725,1769
                        dw 1816,1865,1917,1971,2029,2091,2156,2226,2300,2379,2464,2555

note_freq_ptrs          = *
note_freq_ptrs_0        = *
                        dw 0,204,396,580,748,916,1068,1212,1348,1476,1596,1708,1816,1916,2012,2104
                        dw 2188,2272,2348,2420,2488,2552,2612,2668,2722,2772,2820,2866,2908,2950,2988,3024
                        dw 3058,3090,3120,3148,3176,3200,3224,3248,3268,3288,3308,3326,3342,3358,3374,3388
                        dw 3402,3414,3426,3438,3448,3458,3468,3478,3486,3494,3502,3508,3516,3522,3528,3534
                        dw 3538,3544,3548,3554,3558,3562,3566,3568,3572
note_freq_ptrs_1        = *
                        dw 0,228,420,600,770,930,1082,1224,1360,1488,1608,1720,1828,1928,2024,2114
                        dw 2198,2280,2354,2426,2494,2558,2618,2674,2728,2778,2826,2870,2914,2954,2992,3028
                        dw 3060,3092,3122,3150,3178,3202,3226,3250,3270,3290,3310,3328,3344,3360,3376,3390
                        dw 3402,3416,3428,3440,3450,3460,3470,3478,3488,3496,3502,3510,3516,3522,3528,3534
                        dw 3540,3544,3550,3554,3558,3562,3566,3570,3572,3572
note_freq_ptrs_2        = *
                        dw 0,252,442,622,790,950,1100,1242,1376,1502,1622,1734,1840,1940,2036,2124
                        dw 2210,2288,2364,2434,2502,2564,2624,2680,2734,2784,2832,2876,2918,2958,2996,3032
                        dw 3064,3096,3126,3154,3180,3206,3230,3252,3274,3294,3312,3330,3346,3362,3378,3392
                        dw 3404,3416,3428,3440,3452,3462,3470,3480,3488,3496,3504,3510,3518,3522,3528,3534
                        dw 3540,3546,3550,3554,3558,3562,3566,3570,3572,3572
note_freq_ptrs_3        = *
                        dw 0,276,464,642,810,968,1118,1258,1392,1518,1636,1748,1854,1952,2046,2136
                        dw 2220,2298,2372,2444,2510,2572,2632,2688,2740,2790,2838,2882,2924,2964,3000,3036
                        dw 3068,3100,3130,3158,3184,3210,3232,3254,3276,3296,3314,3332,3348,3364,3378,3392
                        dw 3406,3418,3430,3442,3452,3462,3472,3480,3488,3496,3504,3510,3518,3524,3530,3536
                        dw 3540,3546,3550,3554,3560,3564,3566,3570,3574,3574
note_freq_ptrs_4        = *
                        dw 0,300,488,664,830,988,1136,1276,1408,1532,1650,1762,1866,1964,2058,2146
                        dw 2230,2308,2382,2452,2518,2580,2638,2694,2746,2796,2844,2888,2928,2968,3004,3040
                        dw 3072,3104,3134,3162,3188,3212,3236,3258,3278,3298,3316,3334,3350,3366,3380,3394
                        dw 3408,3420,3432,3444,3454,3464,3472,3482,3490,3498,3504,3512,3518,3524,3530,3536
                        dw 3542,3546,3550,3556,3560,3564,3566,3570,3574,3574
note_freq_ptrs_5        = *
                        dw 0,324,510,686,850,1006,1154,1292,1424,1548,1664,1774,1878,1976,2070,2156
                        dw 2240,2318,2390,2460,2526,2588,2646,2702,2754,2802,2848,2892,2934,2972,3010,3044
                        dw 3076,3108,3138,3164,3190,3216,3238,3260,3280,3300,3318,3336,3352,3368,3382,3396
                        dw 3410,3422,3434,3444,3454,3464,3474,3482,3490,3498,3506,3512,3520,3526,3532,3536
                        dw 3542,3546,3552,3556,3560,3564,3568,3570,3574,3574
note_freq_ptrs_6        = *
                        dw 0,348,532,706,870,1026,1172,1310,1440,1562,1678,1788,1892,1988,2080,2168
                        dw 2250,2326,2400,2468,2534,2596,2654,2708,2760,2808,2854,2898,2938,2978,3014,3048
                        dw 3080,3112,3140,3168,3194,3218,3242,3262,3284,3302,3320,3338,3354,3370,3384,3398
                        dw 3410,3424,3436,3446,3456,3466,3474,3484,3492,3500,3506,3514,3520,3526,3532,3538
                        dw 3542,3548,3552,3556,3560,3564,3568,3572,3574,3574
note_freq_ptrs_7        = *
                        dw 0,372,556,728,892,1044,1190,1326,1456,1578,1692,1802,1904,2000,2092,2178
                        dw 2260,2336,2408,2478,2542,2602,2660,2714,2766,2814,2860,2902,2944,2982,3018,3052
                        dw 3084,3116,3144,3172,3196,3220,3244,3266,3286,3306,3324,3340,3356,3372,3386,3400
                        dw 3412,3424,3436,3448,3458,3468,3476,3484,3492,3500,3508,3514,3520,3526,3532,3538
                        dw 3544,3548,3552,3556,3560,3564,3568,3572,3574,3574
note_freq_ptrs_8        = *
                        dw 0,0,204,396,578,750,912,1064,1208,1344,1472,1592,1708,1814,1916,2012
                        dw 2104,2188,2272,2348,2420,2488,2552,2612,2668,2722,2772,2820,2866,2908,2950,2988
                        dw 3024,3058,3090,3120,3148,3176,3200,3224,3248,3268,3288,3308,3326,3342,3358,3374
                        dw 3388,3402,3416,3428,3438,3448,3458,3468,3478,3486,3494,3502,3508,3516,3522,3528
                        dw 3534,3540,3544,3548,3554,3558,3562,3566,3568,3568
note_freq_ptrs_9        = *
                        dw 0,28,230,422,602,772,932,1084,1226,1362,1488,1608,1722,1828,1928,2024
                        dw 2114,2198,2278,2356,2426,2494,2558,2618,2674,2728,2778,2826,2870,2914,2954,2992
                        dw 3028,3060,3092,3122,3152,3178,3204,3228,3250,3270,3290,3310,3328,3344,3360,3376
                        dw 3390,3404,3416,3428,3440,3450,3460,3470,3478,3486,3494,3502,3510,3516,3522,3528
                        dw 3534,3540,3544,3550,3554,3558,3562,3566,3568,3568
note_freq_ptrs_a        = *
                        dw 0,52,254,444,622,810,950,1100,1242,1376,1502,1622,1734,1840,1940,2036
                        dw 2124,2210,2288,2364,2434,2502,2564,2624,2680,2734,2784,2832,2876,2918,2958,2996
                        dw 3032,3064,3096,3126,3154,3182,3206,3230,3252,3274,3294,3312,3330,3346,3362,3378
                        dw 3392,3406,3418,3430,3442,3452,3462,3472,3480,3488,3496,3504,3510,3516,3524,3530
                        dw 3536,3540,3546,3550,3554,3558,3562,3566,3570,3570
note_freq_ptrs_b        = *
                        dw 0,80,280,468,646,812,972,1120,1260,1394,1520,1638,1750,1854,1952,2046
                        dw 2136,2220,2298,2372,2444,2510,2572,2632,2688,2740,2790,2838,2882,2924,2964,3000
                        dw 3036,3068,3100,3130,3158,3184,3210,3232,3254,3276,3296,3314,3332,3348,3364,3378
                        dw 3392,3406,3420,3432,3442,3452,3462,3472,3480,3490,3496,3504,3512,3516,3524,3530
                        dw 3536,3540,3546,3550,3554,3560,3562,3566,3570,3570
note_freq_ptrs_c        = *
                        dw 0,104,302,490,666,832,988,1138,1278,1410,1534,1652,1762,1866,1964,2058
                        dw 2146,2230,2308,2382,2452,2518,2580,2640,2694,2746,2796,2844,2888,2928,2968,3004
                        dw 3040,3072,3104,3134,3162,3188,3212,3236,3258,3278,3298,3316,3334,3350,3366,3382
                        dw 3394,3408,3420,3432,3444,3454,3464,3474,3482,3490,3498,3506,3512,3518,3524,3530
                        dw 3536,3542,3546,3552,3556,3560,3564,3568,3570,3570
note_freq_ptrs_d        = *
                        dw 0,128,326,510,686,852,1006,1154,1294,1424,1548,1664,1774,1878,1976,2070
                        dw 2156,2240,2318,2390,2460,2526,2588,2646,2702,2754,2802,2848,2892,2934,2972,3010
                        dw 3044,3076,3108,3138,3164,3190,3216,3238,3260,3280,3300,3318,3336,3352,3368,3382
                        dw 3396,3410,3422,3434,3444,3454,3464,3474,3482,3490,3498,3506,3512,3518,3526,3532
                        dw 3536,3542,3546,3552,3556,3560,3564,3568,3570,3570
note_freq_ptrs_e        = *
                        dw 0,156,352,536,710,874,1028,1174,1312,1442,1564,1680,1790,1892,1988,2080
                        dw 2168,2250,2326,2400,2468,2534,2596,2654,2708,2760,2808,2854,2898,2938,2978,3014
                        dw 3048,3080,3112,3140,3168,3194,3218,3242,3262,3284,3302,3320,3338,3354,3370,3384
                        dw 3398,3412,3424,3436,3444,3456,3464,3474,3484,3492,3500,3506,3514,3520,3526,3532
                        dw 3536,3542,3548,3552,3556,3560,3564,3568,3572,3572
note_freq_ptrs_f        = *
                        dw 0,180,374,558,730,892,1046,1190,1328,1456,1578,1694,1802,1904,2000,2092
                        dw 2178,2260,2336,2408,2478,2542,2602,2660,2714,2766,2814,2860,2902,2944,2982,3018
                        dw 3052,3084,3116,3144,3172,3196,3222,3244,3266,3286,3306,3324,3340,3356,3372,3386
                        dw 3400,3412,3424,3436,3446,3458,3466,3476,3484,3492,3500,3508,3514,3520,3526,3532
                        dw 3538,3544,3548,3552,3556,3560,3564,3568,3572,3572
max_freq_ptr            = 146
note_freq_ptrs_offset   = *
                        dw note_freq_ptrs_0-note_freq_ptrs
                        dw note_freq_ptrs_1-note_freq_ptrs
                        dw note_freq_ptrs_2-note_freq_ptrs
                        dw note_freq_ptrs_3-note_freq_ptrs
                        dw note_freq_ptrs_4-note_freq_ptrs
                        dw note_freq_ptrs_5-note_freq_ptrs
                        dw note_freq_ptrs_6-note_freq_ptrs
                        dw note_freq_ptrs_7-note_freq_ptrs
                        dw note_freq_ptrs_8-note_freq_ptrs
                        dw note_freq_ptrs_9-note_freq_ptrs
                        dw note_freq_ptrs_a-note_freq_ptrs
                        dw note_freq_ptrs_b-note_freq_ptrs
                        dw note_freq_ptrs_c-note_freq_ptrs
                        dw note_freq_ptrs_d-note_freq_ptrs
                        dw note_freq_ptrs_e-note_freq_ptrs
                        dw note_freq_ptrs_f-note_freq_ptrs

waveforms               dw 0,2048,4096,4096 ;random=square in protracker!

sine_tbl                = *
                        dw 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        dw 0,0,0,0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,0,0,0,0,0
                        dw 0,0,0,2,2,2,2,2,2,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,2,2,2,2,2,2,0,0,0,0,0,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,0,0
                        dw 0,0,2,2,2,2,4,4,4,4,4,6,6,6,6,6,6,6,6,6,6,6,4,4,4,4,4,2,2,2,2,0,0,0,$fffe,$fffe,$fffe,$fffe,$fffc,$fffc,$fffc,$fffc,$fffc,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffc,$fffc,$fffc,$fffc,$fffc,$fffe,$fffe,$fffe,$fffe,0
                        dw 0,0,2,2,4,4,4,6,6,6,6,8,8,8,8,8,8,8,8,8,8,8,6,6,6,6,4,4,4,2,2,0,0,0,$fffe,$fffe,$fffc,$fffc,$fffc,$fffa,$fffa,$fffa,$fffa,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fffa,$fffa,$fffa,$fffa,$fffc,$fffc,$fffc,$fffe,$fffe,0
                        dw 0,0,2,2,4,4,6,6,8,8,8,8,$a,$a,$a,$a,$a,$a,$a,$a,$a,8,8,8,8,6,6,4,4,2,2,0,0,0,$fffe,$fffe,$fffc,$fffc,$fffa,$fffa,$fff8,$fff8,$fff8,$fff8,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff8,$fff8,$fff8,$fff8,$fffa,$fffa,$fffc,$fffc,$fffe,$fffe,0
                        dw 0,2,2,4,4,6,6,8,8,$a,$a,$a,$c,$c,$c,$c,$c,$c,$c,$c,$c,$a,$a,$a,8,8,6,6,4,4,2,2,0,$fffe,$fffe,$fffc,$fffc,$fffa,$fffa,$fff8,$fff8,$fff6,$fff6,$fff6,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff6,$fff6,$fff6,$fff8,$fff8,$fffa,$fffa,$fffc,$fffc,$fffe,$fffe
                        dw 0,2,2,4,6,6,8,8,$a,$a,$c,$c,$c,$e,$e,$e,$e,$e,$e,$e,$c,$c,$c,$a,$a,8,8,6,6,4,2,2,0,$fffe,$fffe,$fffc,$fffa,$fffa,$fff8,$fff8,$fff6,$fff6,$fff4,$fff4,$fff4,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff4,$fff4,$fff4,$fff6,$fff6,$fff8,$fff8,$fffa,$fffa,$fffc,$fffe,$fffe
                        dw 0,2,4,4,6,8,8,$a,$c,$c,$e,$e,$e,$10,$10,$10,$10,$10,$10,$10,$e,$e,$e,$c,$c,$a,8,8,6,4,4,2,0,$fffe,$fffc,$fffc,$fffa,$fff8,$fff8,$fff6,$fff4,$fff4,$fff2,$fff2,$fff2,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff2,$fff2,$fff2,$fff4,$fff4,$fff6,$fff8,$fff8,$fffa,$fffc,$fffc,$fffe
                        dw 0,2,4,6,6,8,$a,$c,$c,$e,$e,$10,$10,$12,$12,$12,$12,$12,$12,$12,$10,$10,$e,$e,$c,$c,$a,8,6,6,4,2,0,$fffe,$fffc,$fffa,$fffa,$fff8,$fff6,$fff4,$fff4,$fff2,$fff2,$fff0,$fff0,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$fff0,$fff0,$fff2,$fff2,$fff4,$fff4,$fff6,$fff8,$fffa,$fffa,$fffc,$fffe
                        dw 0,2,4,6,8,$a,$c,$c,$e,$10,$10,$12,$12,$14,$14,$14,$14,$14,$14,$14,$12,$12,$10,$10,$e,$c,$c,$a,8,6,4,2,0,$fffe,$fffc,$fffa,$fff8,$fff6,$fff4,$fff4,$fff2,$fff0,$fff0,$ffee,$ffee,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffee,$ffee,$fff0,$fff0,$fff2,$fff4,$fff4,$fff6,$fff8,$fffa,$fffc,$fffe
                        dw 0,2,4,6,8,$a,$c,$e,$10,$12,$12,$14,$14,$16,$16,$16,$16,$16,$16,$16,$14,$14,$12,$12,$10,$e,$c,$a,8,6,4,2,0,$fffe,$fffc,$fffa,$fff8,$fff6,$fff4,$fff2,$fff0,$ffee,$ffee,$ffec,$ffec,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffec,$ffec,$ffee,$ffee,$fff0,$fff2,$fff4,$fff6,$fff8,$fffa,$fffc,$fffe
                        dw 0,2,4,6,$a,$c,$e,$10,$10,$12,$14,$16,$16,$16,$18,$18,$18,$18,$18,$16,$16,$16,$14,$12,$10,$10,$e,$c,$a,6,4,2,0,$fffe,$fffc,$fffa,$fff6,$fff4,$fff2,$fff0,$fff0,$ffee,$ffec,$ffea,$ffea,$ffea,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffea,$ffea,$ffea,$ffec,$ffee,$fff0,$fff0,$fff2,$fff4,$fff6,$fffa,$fffc,$fffe
                        dw 0,2,6,8,$a,$c,$e,$10,$12,$14,$16,$16,$18,$18,$1a,$1a,$1a,$1a,$1a,$18,$18,$16,$16,$14,$12,$10,$e,$c,$a,8,6,2,0,$fffe,$fffa,$fff8,$fff6,$fff4,$fff2,$fff0,$ffee,$ffec,$ffea,$ffea,$ffe8,$ffe8,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe8,$ffe8,$ffea,$ffea,$ffec,$ffee,$fff0,$fff2,$fff4,$fff6,$fff8,$fffa,$fffe
                        dw 0,2,6,8,$a,$e,$10,$12,$14,$16,$18,$18,$1a,$1a,$1c,$1c,$1c,$1c,$1c,$1a,$1a,$18,$18,$16,$14,$12,$10,$e,$a,8,6,2,0,$fffe,$fffa,$fff8,$fff6,$fff2,$fff0,$ffee,$ffec,$ffea,$ffe8,$ffe8,$ffe6,$ffe6,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe6,$ffe6,$ffe8,$ffe8,$ffea,$ffec,$ffee,$fff0,$fff2,$fff6,$fff8,$fffa,$fffe
                        dw 0,2,6,8,$c,$e,$10,$14,$16,$18,$18,$1a,$1c,$1c,$1e,$1e,$1e,$1e,$1e,$1c,$1c,$1a,$18,$18,$16,$14,$10,$e,$c,8,6,2,0,$fffe,$fffa,$fff8,$fff4,$fff2,$fff0,$ffec,$ffea,$ffe8,$ffe8,$ffe6,$ffe4,$ffe4,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe4,$ffe4,$ffe6,$ffe8,$ffe8,$ffea,$ffec,$fff0,$fff2,$fff4,$fff8,$fffa,$fffe

ramp_tbl                = *
                        dw 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        dw 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe
                        dw 4,4,4,4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc
                        dw 6,6,6,6,6,6,4,4,4,4,4,4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffa,$fffa,$fffa,$fffa,$fffa
                        dw 8,8,8,8,8,6,6,6,6,6,6,6,6,4,4,4,4,4,4,4,4,2,2,2,2,2,2,2,2,0,0,0,0,0,0,0,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fff8,$fff8,$fff8,$fff8
                        dw $a,$a,$a,$a,8,8,8,8,8,8,6,6,6,6,6,6,6,4,4,4,4,4,4,2,2,2,2,2,2,0,0,0,0,0,0,0,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff6,$fff6,$fff6
                        dw $c,$c,$c,$a,$a,$a,$a,$a,$a,8,8,8,8,8,6,6,6,6,6,4,4,4,4,4,4,2,2,2,2,2,0,0,0,0,0,$fffe,$fffe,$fffe,$fffe,$fffe,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffa,$fffa,$fffa,$fffa,$fffa,$fff8,$fff8,$fff8,$fff8,$fff8,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff4,$fff4
                        dw $e,$e,$e,$c,$c,$c,$c,$a,$a,$a,$a,$a,8,8,8,8,8,6,6,6,6,4,4,4,4,4,2,2,2,2,0,0,0,0,0,$fffe,$fffe,$fffe,$fffe,$fffc,$fffc,$fffc,$fffc,$fffc,$fffa,$fffa,$fffa,$fffa,$fff8,$fff8,$fff8,$fff8,$fff8,$fff6,$fff6,$fff6,$fff6,$fff6,$fff4,$fff4,$fff4,$fff4,$fff2,$fff2
                        dw $10,$10,$10,$e,$e,$e,$e,$c,$c,$c,$c,$a,$a,$a,$a,8,8,8,8,6,6,6,6,4,4,4,4,2,2,2,2,0,0,0,$fffe,$fffe,$fffe,$fffe,$fffc,$fffc,$fffc,$fffc,$fffa,$fffa,$fffa,$fffa,$fff8,$fff8,$fff8,$fff8,$fff6,$fff6,$fff6,$fff6,$fff4,$fff4,$fff4,$fff4,$fff2,$fff2,$fff2,$fff2,$fff0,$fff0
                        dw $12,$12,$10,$10,$10,$10,$e,$e,$e,$c,$c,$c,$c,$a,$a,$a,$a,8,8,8,6,6,6,6,4,4,4,2,2,2,2,0,0,0,$fffe,$fffe,$fffe,$fffe,$fffc,$fffc,$fffc,$fffa,$fffa,$fffa,$fffa,$fff8,$fff8,$fff8,$fff6,$fff6,$fff6,$fff6,$fff4,$fff4,$fff4,$fff4,$fff2,$fff2,$fff2,$fff0,$fff0,$fff0,$fff0,$ffee
                        dw $14,$14,$12,$12,$12,$10,$10,$10,$10,$e,$e,$e,$c,$c,$c,$a,$a,$a,8,8,8,6,6,6,6,4,4,4,2,2,2,0,0,0,$fffe,$fffe,$fffe,$fffc,$fffc,$fffc,$fffa,$fffa,$fffa,$fffa,$fff8,$fff8,$fff8,$fff6,$fff6,$fff6,$fff4,$fff4,$fff4,$fff2,$fff2,$fff2,$fff0,$fff0,$fff0,$fff0,$ffee,$ffee,$ffee,$ffec
                        dw $16,$16,$14,$14,$14,$12,$12,$12,$10,$10,$10,$e,$e,$e,$c,$c,$c,$a,$a,8,8,8,6,6,6,4,4,4,2,2,2,0,0,0,$fffe,$fffe,$fffe,$fffc,$fffc,$fffc,$fffa,$fffa,$fffa,$fff8,$fff8,$fff8,$fff6,$fff6,$fff4,$fff4,$fff4,$fff2,$fff2,$fff2,$fff0,$fff0,$fff0,$ffee,$ffee,$ffee,$ffec,$ffec,$ffec,$ffea
                        dw $18,$18,$16,$16,$16,$14,$14,$12,$12,$12,$10,$10,$10,$e,$e,$c,$c,$c,$a,$a,$a,8,8,6,6,6,4,4,4,2,2,0,0,0,$fffe,$fffe,$fffc,$fffc,$fffc,$fffa,$fffa,$fffa,$fff8,$fff8,$fff6,$fff6,$fff6,$fff4,$fff4,$fff4,$fff2,$fff2,$fff0,$fff0,$fff0,$ffee,$ffee,$ffee,$ffec,$ffec,$ffea,$ffea,$ffea,$ffe8
                        dw $1a,$1a,$18,$18,$16,$16,$16,$14,$14,$12,$12,$12,$10,$10,$e,$e,$e,$c,$c,$a,$a,8,8,8,6,6,4,4,4,2,2,0,0,0,$fffe,$fffe,$fffc,$fffc,$fffc,$fffa,$fffa,$fff8,$fff8,$fff8,$fff6,$fff6,$fff4,$fff4,$fff2,$fff2,$fff2,$fff0,$fff0,$ffee,$ffee,$ffee,$ffec,$ffec,$ffea,$ffea,$ffea,$ffe8,$ffe8,$ffe6
                        dw $1c,$1c,$1a,$1a,$18,$18,$16,$16,$16,$14,$14,$12,$12,$10,$10,$e,$e,$e,$c,$c,$a,$a,8,8,8,6,6,4,4,2,2,0,0,0,$fffe,$fffe,$fffc,$fffc,$fffa,$fffa,$fff8,$fff8,$fff8,$fff6,$fff6,$fff4,$fff4,$fff2,$fff2,$fff2,$fff0,$fff0,$ffee,$ffee,$ffec,$ffec,$ffea,$ffea,$ffea,$ffe8,$ffe8,$ffe6,$ffe6,$ffe4
                        dw $1e,$1e,$1c,$1c,$1a,$1a,$18,$18,$16,$16,$14,$14,$12,$12,$10,$10,$10,$e,$e,$c,$c,$a,$a,8,8,6,6,4,4,2,2,0,0,0,$fffe,$fffe,$fffc,$fffc,$fffa,$fffa,$fff8,$fff8,$fff6,$fff6,$fff4,$fff4,$fff2,$fff2,$fff0,$fff0,$fff0,$ffee,$ffee,$ffec,$ffec,$ffea,$ffea,$ffe8,$ffe8,$ffe6,$ffe6,$ffe4,$ffe4,$ffe2

square_tbl              = *
                        dw 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        dw 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe
                        dw 4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc
                        dw 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa
                        dw 8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8
                        dw $a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$a,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6
                        dw $c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$c,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4
                        dw $e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$e,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2
                        dw $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0
                        dw $12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee
                        dw $14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec
                        dw $16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea
                        dw $18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8
                        dw $1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6
                        dw $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4
                        dw $1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$1e,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2

pattern_break_ptrs      = *
                        dfb 0,1,2,3,4,5,6,7,8,9,0,0,0,0,0,0
                        dfb 10,11,12,13,14,15,16,17,18,19,0,0,0,0,0,0
                        dfb 20,21,22,23,24,25,26,27,28,29,0,0,0,0,0,0
                        dfb 30,31,32,33,34,35,36,37,38,39,0,0,0,0,0,0
                        dfb 40,41,42,43,44,45,46,47,48,49,0,0,0,0,0,0
                        dfb 50,51,52,53,54,55,56,57,58,59,0,0,0,0,0,0
                        dfb 60,61,62,63,0,0,0,0,0,0,0,0,0,0,0,0
                        dfb 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        dfb 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        dfb 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        dfb 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        dfb 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        dfb 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        dfb 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        dfb 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        dfb 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

bpm_to_freq             = *
                        dw 64,66,68,70,72,74,76,78,80,82,84,86,88,90,92,94
                        dw 96,98,100,102,104,106,108,110,112,114,116,118,120,122,124,125
                        dw 127,129,131,133,135,137,139,141,143,145,147,149,151,153,155,157
                        dw 159,161,163,165,167,169,171,173,175,177,179,181,183,185,187,189
                        dw 191,193,195,197,199,201,203,205,207,209,211,213,215,217,219,221
                        dw 223,225,227,229,231,233,235,237,239,241,243,245,247,249,251,253
                        dw 255,257,259,261,263,265,267,269,271,273,275,277,279,281,283,285
                        dw 287,289,291,293,295,297,299,301,303,305,307,309,311,313,315,317
                        dw 319,321,323,325,327,329,331,333,335,337,339,341,343,345,347,349
                        dw 351,353,355,357,359,361,363,365,367,369,371,372,374,376,378,380
                        dw 382,384,386,388,390,392,394,396,398,400,402,404,406,408,410,412
                        dw 414,416,418,420,422,424,426,428,430,432,434,436,438,440,442,444
                        dw 446,448,450,452,454,456,458,460,462,464,466,468,470,472,474,476
                        dw 478,480,482,484,486,488,490,492,494,496,498,500,502,504,506,508

invertloop_add_tbl      = *
                        dfb $00,$05,$06,$07,$08,$0A,$0B,$0D
                        dfb $10,$13,$16,$1A,$20,$2B,$40,$80

;--------------------------

zero_out_begin          = *                             ;for init, we're writing zeros from here

ntp_file_version        dw  0                           ;version of the ntp file

generate_osc_opti       dw  0
generate_osc_opti_next  dw  0

ptr_header              ds  4                           ;pointer to file start
ptr_notes               ds  4                           ;pointer to music notes
ptr_instruments         ds  4                           ;pointer to instrument start

play_song_once          dw  0                           ;0=loop song, else do stop song after one play
channel_doubling        dw  0                           ;0=no doubling, 1=double channels

number_of_tracks        dw  0                           ;1-15
number_of_instruments   dw  0                           ;1-255
number_of_patterns      dw  0                           ;1-255
pattern_length          dw  0                           ;pattern length in bytes (=4 bytes x number_of_tracks x 64, can be 3584 bytes max.)
track_channels          ds  max_tracks_available*2      ;1 word of stereo setting for each track
track_channels_inverse  ds  max_tracks_available*2      ;1 word of stereo setting for each track, inversed from track_channels
track_streambuffers     ds  max_tracks_available*2      ;1 word beginning page of stream buffer in DOC RAM
track_oscillators       ds  max_tracks_available*2      ;1 word that configures the oscillator(s) to use for each track
track_oscillator_count  ds  max_tracks_available*2      ;1 word for each track set to 0/2/4 if track uses 1/2/4 oscillators
pattern_order_length    dw  0                           ;how many entries there are in pattern_order
pattern_order           ds  256                         ;in which order the patterns should be played

reg_tbl_freqlo          ds  max_tracks_available*2
reg_tbl_freqhi          ds  max_tracks_available*2
reg_tbl_vol             ds  max_tracks_available*2
reg_tbl_ptr             ds  max_tracks_available*2
reg_tbl_ctl             ds  max_tracks_available*2
reg_tbl_siz             ds  max_tracks_available*2

instrument_types        ds  max_instruments*2           ;1 word per instrument
instrument_lengths      ds  max_instruments*2
instrument_lengths_hi   ds  max_instruments*2           ;2nd word for length
instrument_ptr          ds  max_instruments*2
instrument_ptr_hi       ds  max_instruments*2
instrument_rep_ptr      ds  max_instruments*2
instrument_rep_ptr_hi   ds  max_instruments*2
instrument_rep_len      ds  max_instruments*2
instrument_rep_len_hi   ds  max_instruments*2
instrument_end_ptr      ds  max_instruments*2
instrument_end_ptr_hi   ds  max_instruments*2
instrument_volumes      ds  max_instruments*2
instrument_finetune     ds  max_instruments*2           ;instrument finetune value * 2
instrument_osc_a_ptr    ds  max_instruments*2
instrument_osc_b_ptr    ds  max_instruments*2
instrument_osc_a_siz    ds  max_instruments*2
instrument_osc_b_siz    ds  max_instruments*2
instrument_osc_a_ctl    ds  max_instruments*2
instrument_osc_b_ctl    ds  max_instruments*2

copy_instrument_length  dw  0

pattern_pointers        ds  1024                        ;for every pattern, calculate the offset into memory

number_of_tracks2       dw  0                           ;number of tracks x 2
number_of_instruments2  dw  0                           ;number_of_instruments x 2
number_of_tracks4       dw  0                           ;number of tracks x 4 = number of bytes in a pattern line

backup_interrupt_ptr    ds  4

playing                 dw  0                           ;0=not playing, 1=playing
tempo                   dw  0
timer                   dw  0

pattern_jump            dw  0                           ;0=no jump, 2=pattern_jump_param has next songpos, 4=pattern_jump_param has next pointer in pattern, 6=end song
pattern_jump_param      dw  0
force_pattern_jump      dw  0                           ;0=no jump, else force jump on next occasion
force_pattern_jump_p    dw  0                           ;jump to this songpos

loop_position           dw  0                           ;position where to jump to in the current frame
loop_repeat_count       dw  0                           ;number of times the loop should be repeated
loop_position_active    dw  0                           ;0=loop not running, else=loop running
loop_position_jump      dw  0                           ;$ffff=no position jump, else=jump to this position

pattern_order_ptr       dw  0                           ;current position in the pattern order
ptr_within_pattern      dw  0                           ;offset in bytes to current line in the pattern

note                    dw  0                           ;read note*2
sample                  dw  0                           ;read sample*2
effect                  dw  0                           ;read effect*2
effect_param            dw  0                           ;just the effect parameter

interrupt_track         dw  0
interrupt_handler_osc   dw  0
interrupt_job           dw  0
oscillator_job_tbl      ds  32
oscillator_trk_tbl      ds  32

osc_interrupt_freq      dw  0
new_osc_interrupt_freq  dw  0

delay_pattern           dw  0                           ;after the current line, do a delay of X rows

what_to_do              ds  max_tracks_available*2      ;what to send to the shound chip (bit field)

;the last line that we got from the pattern
curr_note               ds  max_tracks_available*2      ;note number * 2
curr_sample             ds  max_tracks_available*2      ;sample number * 2
curr_effect             ds  max_tracks_available*2      ;effect number * 2
curr_e_effect           ds  max_tracks_available*2      ;e-effect number * 2
curr_ptrfinetune        ds  max_tracks_available*2      ;ptr into the big finetune table
curr_volume             ds  max_tracks_available*2      ;the volume for this track (0-64)

arpeggio_ptr            ds  max_tracks_available*2      ;when 0, arpeggio is off, $8000=note 1, $8001=note 2, $8003=note 3
arpeggio_note1          ds  max_tracks_available*2
arpeggio_note2          ds  max_tracks_available*2
arpeggio_note3          ds  max_tracks_available*2

slide_delta             ds  max_tracks_available*2
slide_target            ds  max_tracks_available*2
slide_target_note       ds  max_tracks_available*2

vibrato_tableoffset     ds  max_tracks_available*2
vibrato_table           ds  max_tracks_available*2
vibrato_rate            ds  max_tracks_available*2
vibrato_pos             ds  max_tracks_available*2
vibrato_retrig          ds  max_tracks_available*2

tremolo_tableoffset     ds  max_tracks_available*2
tremolo_table           ds  max_tracks_available*2
tremolo_rate            ds  max_tracks_available*2
tremolo_pos             ds  max_tracks_available*2
tremolo_retrig          ds  max_tracks_available*2

volslide_delta          ds  max_tracks_available*2

retrigger_steps         ds  max_tracks_available*2
retrigger_count         ds  max_tracks_available*2

note_cut                ds  max_tracks_available*2

note_delay_count        ds  max_tracks_available*2
note_delay_note         ds  max_tracks_available*2

osc_freq                ds  max_tracks_available*2
osc_volume              ds  max_tracks_available*2
osc_instrument          ds  max_tracks_available*2
osc_instrument_type     ds  max_tracks_available*2

glissando               ds  max_tracks_available*2      ;0=no glissando, 1=glissando

sample_offset           ds  max_tracks_available*2
sample_offset_backup    ds  max_tracks_available*2

invertloop_tbl_speed    ds  max_tracks_available*2      ;how much to add
invertloop_tbl_value    ds  max_tracks_available*2      ;the current value in the range 0..127
invertloop_offset       ds  max_tracks_available*2      ;pointer into the wave to negate bytes
invertloop_offset_hi    ds  max_tracks_available*2

stream_instr_ptr        ds  max_tracks_available*2      ;pointer into the current instrument buffer in memory
stream_instr_ptr_hi     ds  max_tracks_available*2
stream_doc_page_offset  ds  max_tracks_available*2      ;offset page to add to track_streambuffers (0 or 1) - used during streaming
stream_doc_page         ds  max_tracks_available*2      ;doc ram page where to copy instrument data to

stream_end_ptr          ds  max_tracks_available*2
stream_end_ptr_hi       ds  max_tracks_available*2
stream_osc_count        ds  max_tracks_available*2

streamsound_osc         dw 0
streamsound_osc2        dw 0
streamsound_osc_count   dw 0

setplayvolume_value     dw  0
setplayvolume_add       dw  0
setplayvolume_sum       dw  0

last_effect_8_param     dw  0

vu_number_of_tracks     dw  0
vu_data                 ds  max_tracks_available*2

songinfo                = *
                        dw 0                            ;playing
                        dw 0                            ;pattern number
                        dw 0                            ;song position
                        dw 0                            ;ptr within pattern
                        dw 0                            ;line number
                        ds 4                            ;ptr to pattern
                        dw 0                            ;number of tracks

zero_out_end            = *                             ;for init, we're writing zeros until here

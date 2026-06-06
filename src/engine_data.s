*----------------------------------------------------------
* engine_data.s — bank-$00 scratch storage for engine.s.
*
* engine.s lives in bank $1F but runs with DBR=$00, so its
* private scratch cells must live in bank $00 too. They're
* declared here, PUT into game.s, and re-equ'd into engine.s
* by engine_externs.s (via tools/extract_externs.py).
*----------------------------------------------------------
fsg_off                  ds 1
fsg_count1               ds 1
fsg_count2               ds 1
fsg_curr                 ds 1
old_lo                   dfb 0
nfp                      dfb 0
nfc                      dfb 0
prev_start               dfb 0
ufill_top                ds 2
utmp                     ds 2
rgap_start               ds 2
rgap_count               ds 2
lgap_base                ds 2
dl_wx                    ds 2
dl_cnt                   ds 1
ldr_ctr                  ds 2
lower_rgap_count         ds 2
snap_lo_s9_count         ds 2
ffs_count                ds 2
ffs_dst                  ds 2
ffs_s9_count             ds 2
snap_wo_delta            ds 2
pb_save_s                ds 2
pb_tmp                   ds 2
up_src_start             ds 2
up_dst_start             ds 2
up_count                 ds 2
* OP_DOWN scratch (mirror of up_* above). compute_down_align
* populates these from world_offset + scroll_down_anchor.
down_src_start           ds 2
down_dst_start           ds 2
down_count               ds 2
dfill_top                ds 1
push_ymin                dfb 0
push_ymax                dfb 0

* Ladder-refactor: per-target lower-band fill descriptors. Set by
* engine.s :ffs_setup before each climb's first paint. The pair
* (left_bank, left_origin) and (right_bank, right_origin) tells
* :ffs_paint and :snap_lower_paint which banks to read and what
* world byte sits at playfield col 0 for each side. Generalizes
* the old scr12-only scr9/scr8 hardcoding.
ffs_left_bank            ds 1
ffs_left_origin          ds 2
ffs_right_bank           ds 1
ffs_right_origin         ds 2

* Bounds-refactor (Option A): bank-$02 addresses of the strata tables.
* Read from the level header at init_level via $02/0018 (strata_index)
* and $02/001A (screen_to_stratum). strata_base holds the address of
* the strata_index array (4 × 2 bytes), s2s_base holds the address of
* the screen_to_stratum byte table.
strata_base              ds 2
s2s_base                 ds 2

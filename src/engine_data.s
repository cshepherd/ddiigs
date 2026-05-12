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
rg1_count                dw 0
rg2_count                dw 0
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
push_ymin                dfb 0
push_ymax                dfb 0

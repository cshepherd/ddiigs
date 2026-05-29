
VOLNAME = ddiigs
IMGFILE = out/$(VOLNAME).po

# Cadius wrapper that exits non-zero on "Error : ..." output. Plain
# cadius reports e.g. "No enough space in the image" and exits 0,
# letting make silently produce a disk image with missing files.
CADIUS = tools/cadius_strict.sh

.PHONY: package clean

package: $(IMGFILE)

out/game: src/game.s
	mkdir -p out
	cd src && merlin32 -V game.s
	mv src/game out/game

# engine.s (scroll/blit pipeline) lives in bank $1F. It references
# bank-$00 symbols via absolute mode, so we re-extract their post-
# build addresses from game.s's Merlin32 listing each time game.s
# is reassembled. engine.s depends on out/game (which produces
# src/game_Output.txt as a side effect of the -V flag).
src/engine_externs.s: out/game src/engine_externs.list tools/extract_externs.py
	python3 tools/extract_externs.py src/game_Output.txt src/engine_externs.list src/engine_externs.s

out/engine: src/engine.s src/engine_externs.s
	mkdir -p out
	cd src && merlin32 engine.s
	mv src/engine out/engine

# mission1boss.s (Burnov boss behavior) lives in bank $1E. Like
# engine.s it references bank-$00 symbols via absolute mode, so it
# depends on the shared engine_externs.s (regenerated from game.s).
out/mission1boss: src/mission1boss.s src/engine_externs.s
	mkdir -p out
	cd src && merlin32 mission1boss.s
	mv src/mission1boss out/mission1boss

out/title: src/title.s
	mkdir -p out
	cd src && merlin32 title.s
	mv src/title out/title

src/mission1_strata.s: tools/mission1_strata.txt tools/gen_strata.py src/mission1.s
	python3 tools/gen_strata.py --strata tools/mission1_strata.txt --mission src/mission1.s --out src/mission1_strata.s

out/mission1: src/mission1.s src/mission1_strata.s
	mkdir -p out
	cd src && merlin32 mission1.s
	mv src/mission1 out/mission1

out/mission12: src/mission12.s
	mkdir -p out
	cd src && merlin32 mission12.s
	mv src/mission12 out/mission12

out/mission13: src/mission13.s
	mkdir -p out
	cd src && merlin32 mission13.s
	mv src/mission13 out/mission13

out/mission14: src/mission14.s
	mkdir -p out
	cd src && merlin32 mission14.s
	mv src/mission14 out/mission14

# Bank $30/$31 immediate-mode blit blobs for mission13's compiled
# NPC frames. Regenerated from src/mission13.s by
# tools/generate_mission13blit.py whenever mission13's DATA/MASK
# rows change. Output files are loaded by game.s startup and
# JSL'd into per-frame by draw_sprite_immediate.
src/mission13blit_30.s src/mission13blit_31.s: src/mission13.s tools/generate_mission13blit.py tools/compile_sprite.py
	python3 tools/generate_mission13blit.py

out/mission13blit_30: src/mission13blit_30.s
	mkdir -p out
	cd src && merlin32 mission13blit_30.s
	mv src/mission13blit_30 out/mission13blit_30

out/mission13blit_31: src/mission13blit_31.s
	mkdir -p out
	cd src && merlin32 mission13blit_31.s
	mv src/mission13blit_31 out/mission13blit_31

# Bank $32 immediate-mode blit blobs for Billy's compiled poses
# (walk, jump, kick, punch, climb, hit-reaction). Regenerated from
# src/mission1.s by tools/generate_mission1blit.py.
src/mission1blit_32.s: src/mission1.s tools/generate_mission1blit.py tools/compile_sprite.py
	python3 tools/generate_mission1blit.py

out/mission1blit_32: src/mission1blit_32.s
	mkdir -p out
	cd src && merlin32 mission1blit_32.s
	mv src/mission1blit_32 out/mission1blit_32

# Bank $33 immediate-mode blit blobs for Jimmy's compiled poses.
# Same shape as mission1blit_32 (Billy), regenerated from
# src/mission1jimmy.s by tools/generate_mission1jimmyblit.py.
src/mission1jimmyblit_33.s: src/mission1jimmy.s tools/generate_mission1jimmyblit.py tools/compile_sprite.py
	python3 tools/generate_mission1jimmyblit.py

out/mission1jimmyblit_33: src/mission1jimmyblit_33.s
	mkdir -p out
	cd src && merlin32 mission1jimmyblit_33.s
	mv src/mission1jimmyblit_33 out/mission1jimmyblit_33

# Banks $34-$38 immediate-mode blit blobs for mission12 legacy
# sprites (Linda mace, Williams pipe/knife, Billy armed, Burnov,
# Burnov dissolve, thrown weapons). The source sprites live in
# raw-HEX form in src/mission12.s; tools/generate_mission12blit.py
# compiles them on the fly via tools/compile_mission12.py and emits
# the per-bank blit files.
src/mission12blit_34.s src/mission12blit_35.s src/mission12blit_36.s src/mission12blit_37.s src/mission12blit_38.s: src/mission12.s tools/generate_mission12blit.py tools/compile_mission12.py tools/compile_sprite.py
	python3 tools/generate_mission12blit.py

out/mission12blit_34: src/mission12blit_34.s
	mkdir -p out
	cd src && merlin32 mission12blit_34.s
	mv src/mission12blit_34 out/mission12blit_34

out/mission12blit_35: src/mission12blit_35.s
	mkdir -p out
	cd src && merlin32 mission12blit_35.s
	mv src/mission12blit_35 out/mission12blit_35

out/mission12blit_36: src/mission12blit_36.s
	mkdir -p out
	cd src && merlin32 mission12blit_36.s
	mv src/mission12blit_36 out/mission12blit_36

out/mission12blit_37: src/mission12blit_37.s
	mkdir -p out
	cd src && merlin32 mission12blit_37.s
	mv src/mission12blit_37 out/mission12blit_37

out/mission12blit_38: src/mission12blit_38.s
	mkdir -p out
	cd src && merlin32 mission12blit_38.s
	mv src/mission12blit_38 out/mission12blit_38

# Banks $39/$3A immediate-mode blit blobs for mission14 armed-NPC
# compiled sprites (Linda flail, Williams pipe/knife, Burnov combat).
# generate_mission14blit.py reads src/mission14.s's DATA/MASK blocks
# directly and packs them per-bank.
src/mission14blit_39.s src/mission14blit_3a.s: src/mission14.s tools/generate_mission14blit.py tools/compile_sprite.py
	python3 tools/generate_mission14blit.py

out/mission14blit_39: src/mission14blit_39.s
	mkdir -p out
	cd src && merlin32 mission14blit_39.s
	mv src/mission14blit_39 out/mission14blit_39

out/mission14blit_3a: src/mission14blit_3a.s
	mkdir -p out
	cd src && merlin32 mission14blit_3a.s
	mv src/mission14blit_3a out/mission14blit_3a

out/mission1jimmy: src/mission1jimmy.s
	mkdir -p out
	cd src && merlin32 mission1jimmy.s
	mv src/mission1jimmy out/mission1jimmy

out/cutscene: src/cutscene.s
	mkdir -p out
	cd src && merlin32 cutscene.s
	mv src/cutscene out/cutscene

out/cutscene1: src/cutscene1.s
	mkdir -p out
	cd src && merlin32 cutscene1.s
	mv src/cutscene1 out/cutscene1

out/cutscene2: src/cutscene2.s
	mkdir -p out
	cd src && merlin32 cutscene2.s
	mv src/cutscene2 out/cutscene2

out/ddii: src/ddii.s
	mkdir -p out
	cd src && merlin32 ddii.s
	mv src/ddii out/ddii

$(IMGFILE): res/PRODOS res/BASIC.SYSTEM assets/mission11.shr assets/mission12.shr assets/mission13.shr assets/mission14.shr assets/mission15.shr assets/mission16.shr assets/mission17.shr assets/mission18.shr assets/mission19.shr assets/mission110.shr assets/mission111.shr assets/mission112.shr assets/mission113.shr assets/mission114.shr assets/mission21.shr assets/mission22.shr assets/mission23.shr assets/mission24.shr assets/mission25.shr assets/mission26.shr assets/mission27.shr assets/mission28.shr assets/mission29.shr assets/mission210.shr assets/CONCEPT3\#C10000 assets/INTRO\#C10000 assets/keycontrols\#C10000 assets/joycontrols\#C10000 assets/snescontrols\#C10000 assets/moves\#C10000 out/game out/title out/mission1 out/mission12 out/mission13 out/cutscene out/cutscene1 out/cutscene2 out/ddii out/mission14 out/engine out/mission1boss out/mission1jimmy out/mission13blit_30 out/mission13blit_31 out/mission1blit_32 out/mission1jimmyblit_33 out/mission12blit_34 out/mission12blit_35 out/mission12blit_36 out/mission12blit_37 out/mission12blit_38 out/mission14blit_39 out/mission14blit_3a
	mkdir -p out
	rm -f $(IMGFILE)
	$(CADIUS) CREATEVOLUME $(IMGFILE) $(VOLNAME) 2880KB --quiet
	$(CADIUS) CREATEFOLDER $(IMGFILE) /$(VOLNAME)/MISSION1 --quiet
	$(CADIUS) CREATEFOLDER $(IMGFILE) /$(VOLNAME)/MISSION2 --quiet
	$(CADIUS) CREATEFOLDER $(IMGFILE) /$(VOLNAME)/MISSION3 --quiet
	$(CADIUS) CREATEFOLDER $(IMGFILE) /$(VOLNAME)/SFX --quiet
	$(CADIUS) CREATEFOLDER $(IMGFILE) /$(VOLNAME)/GUIDE --quiet
	cp res/PRODOS out/PRODOS\#FF0000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/PRODOS\#FF0000 --quiet
	rm out/PRODOS\#FF0000
	python3 tools/packbytes.py pack assets/mission11.shr out/MISSION11.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION11.PAK\#C00000 --quiet
	rm out/MISSION11.PAK\#C00000
	# Use --length 32000 on subsequent bg art because we don't need the palettes and SCBs
	python3 tools/packbytes.py pack --length 32000 assets/mission12.shr out/MISSION12.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION12.PAK\#C00000 --quiet
	rm out/MISSION12.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission13.shr out/MISSION13.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION13.PAK\#C00000 --quiet
	rm out/MISSION13.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission14.shr out/MISSION14.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION14.PAK\#C00000 --quiet
	rm out/MISSION14.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission15.shr out/MISSION15.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION15.PAK\#C00000 --quiet
	rm out/MISSION15.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission16.shr out/MISSION16.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION16.PAK\#C00000 --quiet
	rm out/MISSION16.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission17.shr out/MISSION17.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION17.PAK\#C00000 --quiet
	rm out/MISSION17.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission18.shr out/MISSION18.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION18.PAK\#C00000 --quiet
	rm out/MISSION18.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission19.shr out/MISSION19.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION19.PAK\#C00000 --quiet
	rm out/MISSION19.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission110.shr out/MISSION110.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION110.PAK\#C00000 --quiet
	rm out/MISSION110.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission111.shr out/MISSION111.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION111.PAK\#C00000 --quiet
	rm out/MISSION111.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission112.shr out/MISSION112.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION112.PAK\#C00000 --quiet
	rm out/MISSION112.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission113.shr out/MISSION113.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION113.PAK\#C00000 --quiet
	rm out/MISSION113.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission114.shr out/MISSION114.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION114.PAK\#C00000 --quiet
	rm out/MISSION114.PAK\#C00000

	# Mission 2 backgrounds. MISSION21 carries the palette/SCB (full
	# file); MISSION22..MISSION210 are pixel-data-only (32000 B), same
	# convention as MISSION12..MISSION114.
	python3 tools/packbytes.py pack assets/mission21.shr out/MISSION21\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION2/ out/MISSION21\#C00000 --quiet
	rm out/MISSION21\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission22.shr out/MISSION22\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION2/ out/MISSION22\#C00000 --quiet
	rm out/MISSION22\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission23.shr out/MISSION23\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION2/ out/MISSION23\#C00000 --quiet
	rm out/MISSION23\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission24.shr out/MISSION24\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION2/ out/MISSION24\#C00000 --quiet
	rm out/MISSION24\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission25.shr out/MISSION25\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION2/ out/MISSION25\#C00000 --quiet
	rm out/MISSION25\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission26.shr out/MISSION26\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION2/ out/MISSION26\#C00000 --quiet
	rm out/MISSION26\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission27.shr out/MISSION27\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION2/ out/MISSION27\#C00000 --quiet
	rm out/MISSION27\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission28.shr out/MISSION28\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION2/ out/MISSION28\#C00000 --quiet
	rm out/MISSION28\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission29.shr out/MISSION29\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION2/ out/MISSION29\#C00000 --quiet
	rm out/MISSION29\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission210.shr out/MISSION210\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION2/ out/MISSION210\#C00000 --quiet
	rm out/MISSION210\#C00000
	cp out/mission1 out/MISSION1\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION1\#060000 --quiet
	rm out/MISSION1\#060000
	cp out/mission12 out/MISSION12\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION12\#060000 --quiet
	rm out/MISSION12\#060000
	# Compiled mission1 sprites (bank $1B) — added to disk and loaded
	# at startup alongside mission12. ProDOS file name is MISSION13.
	cp out/mission13 out/MISSION13\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION13\#060000 --quiet
	rm out/MISSION13\#060000
	# Compiled armed-NPC sprites (bank $1C) — split out from mission13
	# because the regular + armed sprite set together exceeded 64 KB.
	cp out/mission14 out/MISSION14\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION14\#060000 --quiet
	rm out/MISSION14\#060000
	# Immediate-mode blit blobs for mission13's compiled NPCs (banks
	# $30/$31). Each frame has a JSL-callable blob that paints the
	# sprite via inline LDA #imm; STA off,X instead of the AND/ORA
	# data-table loop. ProDOS file names MISSION13BLIT30 / 31.
	# NOTE: adding these pushes the disk past the 1600-block (800KB)
	# floppy capacity, so the image must be mounted as a hard-drive
	# image (e.g. via KEGS' HDD slot) rather than as a 3.5" floppy.
	# Mounting it as a floppy with overflowing content corrupts
	# ProDOS reads partway through sound_install_all.
	cp out/mission13blit_30 out/MISSION13BLIT30\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION13BLIT30\#060000 --quiet
	rm out/MISSION13BLIT30\#060000
	cp out/mission13blit_31 out/MISSION13BLIT31\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION13BLIT31\#060000 --quiet
	rm out/MISSION13BLIT31\#060000
	# Immediate-mode blit blobs for Billy's compiled poses (bank $32).
	# IMAGE01-03 walk, JUMP1-3, KICK1-2, PUNCH11/12/21/22, BPUNCHED,
	# BCLIMB1-2. ProDOS file name MISSION1BLIT32.
	cp out/mission1blit_32 out/MISSION1BLIT32\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION1BLIT32\#060000 --quiet
	rm out/MISSION1BLIT32\#060000
	# Immediate-mode blit blobs for Jimmy's compiled poses (bank $33).
	# Mirrors Billy's set 1:1 (JIMMY01-03 walk, JJUMP/JKICK/JPUNCH/
	# JPUNCHED/JCLIMB equivalents). ProDOS file name M1JIMMYBLIT33
	# (15-char ProDOS limit; longer MISSION1JIMMYBLIT33 doesn't fit).
	cp out/mission1jimmyblit_33 out/M1JIMMYBLIT33\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/M1JIMMYBLIT33\#060000 --quiet
	rm out/M1JIMMYBLIT33\#060000
	# Immediate-mode blit blobs for mission12's legacy sprites
	# (banks $34-$38). 70 sprites total: Linda mace, Williams pipe/
	# knife, thrown weapons, Billy armed (mace/pipe/knife/walk),
	# Burnov (boss), Burnov dissolve, Linda flame walk.
	cp out/mission12blit_34 out/M12BLIT34\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/M12BLIT34\#060000 --quiet
	rm out/M12BLIT34\#060000
	cp out/mission12blit_35 out/M12BLIT35\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/M12BLIT35\#060000 --quiet
	rm out/M12BLIT35\#060000
	cp out/mission12blit_36 out/M12BLIT36\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/M12BLIT36\#060000 --quiet
	rm out/M12BLIT36\#060000
	cp out/mission12blit_37 out/M12BLIT37\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/M12BLIT37\#060000 --quiet
	rm out/M12BLIT37\#060000
	cp out/mission12blit_38 out/M12BLIT38\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/M12BLIT38\#060000 --quiet
	rm out/M12BLIT38\#060000
	cp out/mission14blit_39 out/M14BLIT39\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/M14BLIT39\#060000 --quiet
	rm out/M14BLIT39\#060000
	cp out/mission14blit_3a out/M14BLIT3A\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/M14BLIT3A\#060000 --quiet
	rm out/M14BLIT3A\#060000
	# Jimmy color-shifted sprites (bank $1D) — generated by
	# tools/generate_jimmy_blocks.py from the Billy originals in
	# mission1.s + mission12.s.
	cp out/mission1jimmy out/MISSION1JIMMY\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION1JIMMY\#060000 --quiet
	rm out/MISSION1JIMMY\#060000
	cp out/game out/GAME\#FF2000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/GAME\#FF2000 --quiet
	rm out/GAME\#FF2000
	# Bank-$1F engine code (scroll/blit pipeline). Loaded by game.s
	# at startup to $1F:$0000. Stored at the disk root (not under
	# /MISSION1/) because it's level-independent.
	cp out/engine out/ENGINE\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/ENGINE\#060000 --quiet
	rm out/ENGINE\#060000
	# Bank-$1E mission1 boss (Burnov) behavior. Loaded by game.s at
	# startup to $1E:$0000. Under /MISSION1/ because it's level-
	# specific (the engine in /ENGINE stays level-independent).
	cp out/mission1boss out/BOSS\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/BOSS\#060000 --quiet
	rm out/BOSS\#060000
	cp out/cutscene out/CUTSCENE\#FF2000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/CUTSCENE\#FF2000 --quiet
	rm out/CUTSCENE\#FF2000
	cp out/cutscene1 out/CUTSCENE1\#040000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/CUTSCENE1\#040000 --quiet
	rm out/CUTSCENE1\#040000
	cp out/cutscene2 out/CUTSCENE2\#040000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/CUTSCENE2\#040000 --quiet
	rm out/CUTSCENE2\#040000
	cp out/title out/TITLE\#FF0000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/TITLE\#FF0000 --quiet
	rm out/TITLE\#FF0000
	cp out/ddii out/DDII.SYSTEM\#FF2000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/DDII.SYSTEM\#FF2000 --quiet
	rm out/DDII.SYSTEM\#FF2000
	cp assets/ccc.shr out/CCC.SHR\#C10000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/CCC.SHR\#C10000 --quiet
	rm out/CCC.SHR\#C10000
	# Pack drugs.shr → DRUGS.PAK (RLE compresses the updated
	# lower-entropy art well; raw was 32KB, packed is much
	# smaller). title.s load_drugs stages the PAK in bank $17
	# and _UnPackBytes-decompresses to $02/2000.
	python3 tools/packbytes.py pack assets/drugs.shr out/DRUGS.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/DRUGS.PAK\#C00000 --quiet
	rm out/DRUGS.PAK\#C00000
	# Packed full-screen LOADING image (palettes + SCBs included
	# so it's standalone — no companion palette load needed).
	python3 tools/packbytes.py pack assets/loading.shr out/LOADING.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/LOADING.PAK\#C00000 --quiet
	rm out/LOADING.PAK\#C00000
	# Packed CONCEPT3 SHR — backdrop for the controller-select screen
	# integrated into title.s. Full standalone PIC (palettes + SCBs).
	python3 tools/packbytes.py pack assets/CONCEPT3\#C10000 out/SELECT.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/SELECT.PAK\#C00000 --quiet
	rm out/SELECT.PAK\#C00000
	# /GUIDE pages — each is a full standalone SHR PIC packed with
	# PackBytes (palettes + SCBs included). Loaded by the in-game
	# user guide one page at a time.
	python3 tools/packbytes.py pack assets/INTRO\#C10000 out/PAGE1.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/GUIDE/ out/PAGE1.PAK\#C00000 --quiet
	rm out/PAGE1.PAK\#C00000
	python3 tools/packbytes.py pack assets/keycontrols\#C10000 out/PAGE2.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/GUIDE/ out/PAGE2.PAK\#C00000 --quiet
	rm out/PAGE2.PAK\#C00000
	python3 tools/packbytes.py pack assets/joycontrols\#C10000 out/PAGE3.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/GUIDE/ out/PAGE3.PAK\#C00000 --quiet
	rm out/PAGE3.PAK\#C00000
	python3 tools/packbytes.py pack assets/snescontrols\#C10000 out/PAGE4.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/GUIDE/ out/PAGE4.PAK\#C00000 --quiet
	rm out/PAGE4.PAK\#C00000
	python3 tools/packbytes.py pack assets/moves\#C10000 out/PAGE5.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/GUIDE/ out/PAGE5.PAK\#C00000 --quiet
	rm out/PAGE5.PAK\#C00000
	# Add NTP music assets. ntpplayer compresses ~58% (34672 → 14667
	# bytes) so we ship it PackBytes-compressed and have title.s
	# unpack it to bank $12 at boot via load_titlentp_pak.
	python3 tools/packbytes.py pack res/ntpplayer\#060000 out/NTPPLAYER.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/NTPPLAYER.PAK\#C00000 --quiet
	rm out/NTPPLAYER.PAK\#C00000
	python3 tools/packbytes.py pack assets/audio/TITLE.NTP\#000000 out/TITLE.NTP.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/TITLE.NTP.PAK\#C00000 --quiet
	rm out/TITLE.NTP.PAK\#C00000
	python3 tools/packbytes.py pack assets/audio/CUTSCENE.NTP\#000000 out/CUTSCENENTP.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/CUTSCENENTP.PAK\#C00000 --quiet
	rm out/CUTSCENENTP.PAK\#C00000
	python3 tools/packbytes.py pack assets/audio/COMPLETE.NTP\#000000 out/COMPLETENTP.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/COMPLETENTP.PAK\#C00000 --quiet
	rm out/COMPLETENTP.PAK\#C00000
	# In-game music: pre-pack with PackBytes — the engine loads
	# them through load_and_unpack the same way it does SHR
	# backgrounds. (Filenames trimmed to fit the ProDOS 15-char
	# limit: MISSION1NTP.PAK instead of MISSION1.NTP.PAK.)
	python3 tools/packbytes.py pack assets/audio/MISSION1.NTP\#000000 out/MISSION1NTP.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION1NTP.PAK\#C00000 --quiet
	rm out/MISSION1NTP.PAK\#C00000
	python3 tools/packbytes.py pack assets/mission2.ntp out/MISSION2NTP.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION2/ out/MISSION2NTP.PAK\#C00000 --quiet
	rm out/MISSION2NTP.PAK\#C00000
	python3 tools/packbytes.py pack assets/mission3.ntp out/MISSION3NTP.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION3/ out/MISSION3NTP.PAK\#C00000 --quiet
	rm out/MISSION3NTP.PAK\#C00000
	python3 tools/packbytes.py pack assets/audio/BOSS.NTP\#000000 out/BOSS.NTP.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/BOSS.NTP.PAK\#C00000 --quiet
	rm out/BOSS.NTP.PAK\#C00000
	# Game-over jingle. Trimmed to GAMEOVERNTP.PAK (15-char ProDOS
	# limit, same convention as MISSION1NTP.PAK / CUTSCENENTP.PAK).
	python3 tools/packbytes.py pack assets/audio/clean-mid/gameover.ntp out/GAMEOVERNTP.PAK\#C00000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/ out/GAMEOVERNTP.PAK\#C00000 --quiet
	rm out/GAMEOVERNTP.PAK\#C00000
	# Add sound effect RAW files (in /SFX/ subfolder)
	cp assets/audio/punch.raw out/PUNCH.RAW\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/PUNCH.RAW\#060000 --quiet
	rm out/PUNCH.RAW\#060000
	cp assets/audio/finger.raw out/FINGER.RAW\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/FINGER.RAW\#060000 --quiet
	rm out/FINGER.RAW\#060000
	cp assets/audio/fall.raw out/FALL.RAW\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/FALL.RAW\#060000 --quiet
	rm out/FALL.RAW\#060000
	cp assets/audio/punchlanded.raw out/PUNCHLANDED.RAW\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/PUNCHLANDED.RAW\#060000 --quiet
	rm out/PUNCHLANDED.RAW\#060000
	cp assets/audio/pow.raw out/POW.RAW\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/POW.RAW\#060000 --quiet
	rm out/POW.RAW\#060000
	cp assets/audio/fallen.raw out/FALLEN.RAW\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/FALLEN.RAW\#060000 --quiet
	rm out/FALLEN.RAW\#060000
	cp assets/audio/spinkick.raw out/SPINKICK.RAW\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/SPINKICK.RAW\#060000 --quiet
	rm out/SPINKICK.RAW\#060000
	cp assets/audio/jump.raw out/JUMP.RAW\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/JUMP.RAW\#060000 --quiet
	rm out/JUMP.RAW\#060000
	cp assets/audio/door.raw out/DOOR.RAW\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/DOOR.RAW\#060000 --quiet
	rm out/DOOR.RAW\#060000
	cp assets/audio/burngone.raw out/BURNGONE.RAW\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/BURNGONE.RAW\#060000 --quiet
	rm out/BURNGONE.RAW\#060000
	cp assets/audio/burnback.raw out/BURNBACK.RAW\#060000
	$(CADIUS) ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/BURNBACK.RAW\#060000 --quiet
	rm out/BURNBACK.RAW\#060000
	$(CADIUS) CATALOG $(IMGFILE)

clean:
	rm -rf out

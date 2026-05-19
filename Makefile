
VOLNAME = ddiigs
IMGFILE = out/$(VOLNAME).po

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

out/title: src/title.s
	mkdir -p out
	cd src && merlin32 title.s
	mv src/title out/title

out/mission1: src/mission1.s
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

out/ddii: src/ddii.s
	mkdir -p out
	cd src && merlin32 ddii.s
	mv src/ddii out/ddii

$(IMGFILE): res/PRODOS res/BASIC.SYSTEM assets/mission11.shr assets/mission12.shr assets/mission13.shr assets/mission14.shr assets/mission15.shr assets/mission16.shr assets/mission17.shr assets/mission18.shr assets/mission19.shr assets/mission110.shr assets/mission111.shr assets/mission112.shr assets/mission113.shr assets/mission114.shr assets/CONCEPT3\#C10000 assets/INTRO\#C10000 assets/keycontrols\#C10000 assets/joycontrols\#C10000 assets/snescontrols\#C10000 assets/moves\#C10000 out/game out/title out/mission1 out/mission12 out/mission13 out/cutscene out/cutscene1 out/ddii out/mission14 out/engine out/mission1jimmy
	mkdir -p out
	rm -f $(IMGFILE)
	cadius CREATEVOLUME $(IMGFILE) $(VOLNAME) 800KB --quiet
	cadius CREATEFOLDER $(IMGFILE) /$(VOLNAME)/MISSION1 --quiet
	cadius CREATEFOLDER $(IMGFILE) /$(VOLNAME)/SFX --quiet
	cadius CREATEFOLDER $(IMGFILE) /$(VOLNAME)/GUIDE --quiet
	cp res/PRODOS out/PRODOS\#FF0000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/PRODOS\#FF0000 --quiet
	rm out/PRODOS\#FF0000
	python3 tools/packbytes.py pack assets/mission11.shr out/MISSION11.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION11.PAK\#C00000 --quiet
	rm out/MISSION11.PAK\#C00000
	# Use --length 32000 on subsequent bg art because we don't need the palettes and SCBs
	python3 tools/packbytes.py pack --length 32000 assets/mission12.shr out/MISSION12.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION12.PAK\#C00000 --quiet
	rm out/MISSION12.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission13.shr out/MISSION13.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION13.PAK\#C00000 --quiet
	rm out/MISSION13.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission14.shr out/MISSION14.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION14.PAK\#C00000 --quiet
	rm out/MISSION14.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission15.shr out/MISSION15.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION15.PAK\#C00000 --quiet
	rm out/MISSION15.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission16.shr out/MISSION16.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION16.PAK\#C00000 --quiet
	rm out/MISSION16.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission17.shr out/MISSION17.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION17.PAK\#C00000 --quiet
	rm out/MISSION17.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission18.shr out/MISSION18.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION18.PAK\#C00000 --quiet
	rm out/MISSION18.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission19.shr out/MISSION19.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION19.PAK\#C00000 --quiet
	rm out/MISSION19.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission110.shr out/MISSION110.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION110.PAK\#C00000 --quiet
	rm out/MISSION110.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission111.shr out/MISSION111.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION111.PAK\#C00000 --quiet
	rm out/MISSION111.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission112.shr out/MISSION112.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION112.PAK\#C00000 --quiet
	rm out/MISSION112.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission113.shr out/MISSION113.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION113.PAK\#C00000 --quiet
	rm out/MISSION113.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission114.shr out/MISSION114.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION114.PAK\#C00000 --quiet
	rm out/MISSION114.PAK\#C00000
	cp out/mission1 out/MISSION1\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION1\#060000 --quiet
	rm out/MISSION1\#060000
	cp out/mission12 out/MISSION12\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION12\#060000 --quiet
	rm out/MISSION12\#060000
	# Compiled mission1 sprites (bank $1B) — added to disk and loaded
	# at startup alongside mission12. ProDOS file name is MISSION13.
	cp out/mission13 out/MISSION13\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION13\#060000 --quiet
	rm out/MISSION13\#060000
	# Compiled armed-NPC sprites (bank $1C) — split out from mission13
	# because the regular + armed sprite set together exceeded 64 KB.
	cp out/mission14 out/MISSION14\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION14\#060000 --quiet
	rm out/MISSION14\#060000
	# Jimmy color-shifted sprites (bank $1D) — generated by
	# tools/generate_jimmy_blocks.py from the Billy originals in
	# mission1.s + mission12.s.
	cp out/mission1jimmy out/MISSION1JIMMY\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION1JIMMY\#060000 --quiet
	rm out/MISSION1JIMMY\#060000
	cp out/game out/GAME\#FF2000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/GAME\#FF2000 --quiet
	rm out/GAME\#FF2000
	# Bank-$1F engine code (scroll/blit pipeline). Loaded by game.s
	# at startup to $1F:$0000. Stored at the disk root (not under
	# /MISSION1/) because it's level-independent.
	cp out/engine out/ENGINE\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/ENGINE\#060000 --quiet
	rm out/ENGINE\#060000
	cp out/cutscene out/CUTSCENE\#FF2000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/CUTSCENE\#FF2000 --quiet
	rm out/CUTSCENE\#FF2000
	cp out/cutscene1 out/CUTSCENE1\#040000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/CUTSCENE1\#040000 --quiet
	rm out/CUTSCENE1\#040000
	cp out/title out/TITLE\#FF0000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/TITLE\#FF0000 --quiet
	rm out/TITLE\#FF0000
	cp out/ddii out/DDII.SYSTEM\#FF2000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/DDII.SYSTEM\#FF2000 --quiet
	rm out/DDII.SYSTEM\#FF2000
	cp assets/ccc.shr out/CCC.SHR\#C10000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/CCC.SHR\#C10000 --quiet
	rm out/CCC.SHR\#C10000
	cp assets/drugs.shr out/DRUGS.SHR\#C10000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/DRUGS.SHR\#C10000 --quiet
	rm out/DRUGS.SHR\#C10000
	# Packed full-screen LOADING image (palettes + SCBs included
	# so it's standalone — no companion palette load needed).
	python3 tools/packbytes.py pack assets/loading.shr out/LOADING.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/LOADING.PAK\#C00000 --quiet
	rm out/LOADING.PAK\#C00000
	# Packed CONCEPT3 SHR — backdrop for the controller-select screen
	# integrated into title.s. Full standalone PIC (palettes + SCBs).
	python3 tools/packbytes.py pack assets/CONCEPT3\#C10000 out/SELECT.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/SELECT.PAK\#C00000 --quiet
	rm out/SELECT.PAK\#C00000
	# /GUIDE pages — each is a full standalone SHR PIC packed with
	# PackBytes (palettes + SCBs included). Loaded by the in-game
	# user guide one page at a time.
	python3 tools/packbytes.py pack assets/INTRO\#C10000 out/PAGE1.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/GUIDE/ out/PAGE1.PAK\#C00000 --quiet
	rm out/PAGE1.PAK\#C00000
	python3 tools/packbytes.py pack assets/keycontrols\#C10000 out/PAGE2.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/GUIDE/ out/PAGE2.PAK\#C00000 --quiet
	rm out/PAGE2.PAK\#C00000
	python3 tools/packbytes.py pack assets/joycontrols\#C10000 out/PAGE3.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/GUIDE/ out/PAGE3.PAK\#C00000 --quiet
	rm out/PAGE3.PAK\#C00000
	python3 tools/packbytes.py pack assets/snescontrols\#C10000 out/PAGE4.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/GUIDE/ out/PAGE4.PAK\#C00000 --quiet
	rm out/PAGE4.PAK\#C00000
	python3 tools/packbytes.py pack assets/moves\#C10000 out/PAGE5.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/GUIDE/ out/PAGE5.PAK\#C00000 --quiet
	rm out/PAGE5.PAK\#C00000
	# Add NTP music assets. ntpplayer compresses ~58% (34672 → 14667
	# bytes) so we ship it PackBytes-compressed and have title.s
	# unpack it to bank $12 at boot via load_titlentp_pak.
	python3 tools/packbytes.py pack res/ntpplayer\#060000 out/NTPPLAYER.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/NTPPLAYER.PAK\#C00000 --quiet
	rm out/NTPPLAYER.PAK\#C00000
	python3 tools/packbytes.py pack assets/audio/TITLE.NTP\#000000 out/TITLE.NTP.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/TITLE.NTP.PAK\#C00000 --quiet
	rm out/TITLE.NTP.PAK\#C00000
	python3 tools/packbytes.py pack assets/audio/CUTSCENE.NTP\#000000 out/CUTSCENENTP.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/CUTSCENENTP.PAK\#C00000 --quiet
	rm out/CUTSCENENTP.PAK\#C00000
	python3 tools/packbytes.py pack assets/audio/COMPLETE.NTP\#000000 out/COMPLETENTP.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/COMPLETENTP.PAK\#C00000 --quiet
	rm out/COMPLETENTP.PAK\#C00000
	# In-game music: pre-pack with PackBytes — the engine loads
	# them through load_and_unpack the same way it does SHR
	# backgrounds. (Filenames trimmed to fit the ProDOS 15-char
	# limit: MISSION1NTP.PAK instead of MISSION1.NTP.PAK.)
	python3 tools/packbytes.py pack assets/audio/MISSION1.NTP\#000000 out/MISSION1NTP.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/MISSION1/ out/MISSION1NTP.PAK\#C00000 --quiet
	rm out/MISSION1NTP.PAK\#C00000
	python3 tools/packbytes.py pack assets/audio/BOSS.NTP\#000000 out/BOSS.NTP.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/BOSS.NTP.PAK\#C00000 --quiet
	rm out/BOSS.NTP.PAK\#C00000
	# Game-over jingle. Trimmed to GAMEOVERNTP.PAK (15-char ProDOS
	# limit, same convention as MISSION1NTP.PAK / CUTSCENENTP.PAK).
	python3 tools/packbytes.py pack assets/audio/clean-mid/gameover.ntp out/GAMEOVERNTP.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/GAMEOVERNTP.PAK\#C00000 --quiet
	rm out/GAMEOVERNTP.PAK\#C00000
	# Add sound effect RAW files (in /SFX/ subfolder)
	cp assets/audio/punch.raw out/PUNCH.RAW\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/PUNCH.RAW\#060000 --quiet
	rm out/PUNCH.RAW\#060000
	cp assets/audio/finger.raw out/FINGER.RAW\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/FINGER.RAW\#060000 --quiet
	rm out/FINGER.RAW\#060000
	cp assets/audio/fall.raw out/FALL.RAW\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/FALL.RAW\#060000 --quiet
	rm out/FALL.RAW\#060000
	cp assets/audio/punchlanded.raw out/PUNCHLANDED.RAW\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/PUNCHLANDED.RAW\#060000 --quiet
	rm out/PUNCHLANDED.RAW\#060000
	cp assets/audio/pow.raw out/POW.RAW\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/POW.RAW\#060000 --quiet
	rm out/POW.RAW\#060000
	cp assets/audio/fallen.raw out/FALLEN.RAW\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/FALLEN.RAW\#060000 --quiet
	rm out/FALLEN.RAW\#060000
	cp assets/audio/spinkick.raw out/SPINKICK.RAW\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/SPINKICK.RAW\#060000 --quiet
	rm out/SPINKICK.RAW\#060000
	cp assets/audio/jump.raw out/JUMP.RAW\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/JUMP.RAW\#060000 --quiet
	rm out/JUMP.RAW\#060000
	cp assets/audio/door.raw out/DOOR.RAW\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/DOOR.RAW\#060000 --quiet
	rm out/DOOR.RAW\#060000
	cp assets/audio/burngone.raw out/BURNGONE.RAW\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/BURNGONE.RAW\#060000 --quiet
	rm out/BURNGONE.RAW\#060000
	cp assets/audio/burnback.raw out/BURNBACK.RAW\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/SFX/ out/BURNBACK.RAW\#060000 --quiet
	rm out/BURNBACK.RAW\#060000
	cadius CATALOG $(IMGFILE)

clean:
	rm -rf out

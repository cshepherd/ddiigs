
VOLNAME = ddiigs
IMGFILE = out/$(VOLNAME).po

.PHONY: package clean

package: $(IMGFILE)

out/game: src/game.s
	mkdir -p out
	cd src && merlin32 game.s
	mv src/game out/game

out/title: src/title.s
	mkdir -p out
	cd src && merlin32 title.s
	mv src/title out/title

out/mission1: src/mission1.s
	mkdir -p out
	cd src && merlin32 mission1.s
	mv src/mission1 out/mission1

out/cutscene: src/cutscene.s
	mkdir -p out
	cd src && merlin32 cutscene.s
	mv src/cutscene out/cutscene

out/cutscene1: src/cutscene1.s
	mkdir -p out
	cd src && merlin32 cutscene1.s
	mv src/cutscene1 out/cutscene1

$(IMGFILE): res/PRODOS res/BASIC.SYSTEM assets/mission11.shr assets/mission12.shr assets/mission13.shr assets/mission14.shr assets/mission15.shr assets/mission16.shr assets/mission17.shr assets/mission18.shr assets/mission19.shr assets/mission110.shr assets/mission111.shr assets/mission112.shr assets/mission113.shr assets/mission114.shr out/game out/title out/mission1 out/cutscene out/cutscene1
	mkdir -p out
	rm -f $(IMGFILE)
	cadius CREATEVOLUME $(IMGFILE) $(VOLNAME) 800KB --quiet
	cadius CREATEFOLDER $(IMGFILE) /$(VOLNAME)/MISSION1 --quiet
	cadius CREATEFOLDER $(IMGFILE) /$(VOLNAME)/SFX --quiet
	cp res/PRODOS out/PRODOS\#FF0000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/PRODOS\#FF0000 --quiet
	rm out/PRODOS\#FF0000
	cp res/BASIC.SYSTEM out/BASIC.SYSTEM\#FF2000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/BASIC.SYSTEM\#FF2000 --quiet
	rm out/BASIC.SYSTEM\#FF2000
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
	cp out/game out/GAME\#FF2000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/GAME\#FF2000 --quiet
	rm out/GAME\#FF2000
	cp out/cutscene out/CUTSCENE\#FF2000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/CUTSCENE\#FF2000 --quiet
	rm out/CUTSCENE\#FF2000
	cp out/cutscene1 out/CUTSCENE1\#040000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/CUTSCENE1\#040000 --quiet
	rm out/CUTSCENE1\#040000
	cp out/title out/TITLE\#FF0000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/TITLE\#FF0000 --quiet
	rm out/TITLE\#FF0000
	cp assets/ccc.shr out/CCC.SHR\#C10000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/CCC.SHR\#C10000 --quiet
	rm out/CCC.SHR\#C10000
	# Add NTP music assets
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ res/ntpplayer\#060000 --quiet
	python3 tools/packbytes.py pack assets/audio/TITLE.NTP\#000000 out/TITLE.NTP.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/TITLE.NTP.PAK\#C00000 --quiet
	rm out/TITLE.NTP.PAK\#C00000
	python3 tools/packbytes.py pack assets/audio/CUTSCENE.NTP\#000000 out/CUTSCENENTP.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/CUTSCENENTP.PAK\#C00000 --quiet
	rm out/CUTSCENENTP.PAK\#C00000
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
	cadius CATALOG $(IMGFILE)

clean:
	rm -rf out

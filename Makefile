
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

$(IMGFILE): res/PRODOS res/BASIC.SYSTEM assets/mission11.shr assets/mission12.shr assets/mission13.shr assets/mission14.shr assets/mission15.shr out/game out/title out/mission1
	mkdir -p out
	rm -f $(IMGFILE)
	cadius CREATEVOLUME $(IMGFILE) $(VOLNAME) 800KB --quiet
	cp res/PRODOS out/PRODOS\#FF0000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/PRODOS\#FF0000 --quiet
	rm out/PRODOS\#FF0000
	cp res/BASIC.SYSTEM out/BASIC.SYSTEM\#FF2000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/BASIC.SYSTEM\#FF2000 --quiet
	rm out/BASIC.SYSTEM\#FF2000
	python3 tools/packbytes.py pack assets/mission11.shr out/MISSION11.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/MISSION11.PAK\#C00000 --quiet
	rm out/MISSION11.PAK\#C00000
	# Use --length 32000 on subsequent bg art because we don't need the palettes and SCBs
	python3 tools/packbytes.py pack --length 32000 assets/mission12.shr out/MISSION12.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/MISSION12.PAK\#C00000 --quiet
	rm out/MISSION12.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission13.shr out/MISSION13.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/MISSION13.PAK\#C00000 --quiet
	rm out/MISSION13.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission14.shr out/MISSION14.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/MISSION14.PAK\#C00000 --quiet
	rm out/MISSION14.PAK\#C00000
	python3 tools/packbytes.py pack --length 32000 assets/mission15.shr out/MISSION15.PAK\#C00000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/MISSION15.PAK\#C00000 --quiet
	rm out/MISSION15.PAK\#C00000
	cp out/mission1 out/MISSION1\#060000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/MISSION1\#060000 --quiet
	rm out/MISSION1\#060000
	cp out/game out/GAME\#FF2000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/GAME\#FF2000 --quiet
	rm out/GAME\#FF2000
	cp out/title out/TITLE\#FF0000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/TITLE\#FF0000 --quiet
	rm out/TITLE\#FF0000
	cp assets/ccc.shr out/CCC.SHR\#C10000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/CCC.SHR\#C10000 --quiet
	rm out/CCC.SHR\#C10000
	# Add NTP music assets
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ res/ntpplayer\#060000 --quiet
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ assets/audio/TITLE.NTP#000000 --quiet
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ assets/audio/MISSION1.NTP\#000000 --quiet
	cadius CATALOG $(IMGFILE)

clean:
	rm -rf out

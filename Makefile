
VOLNAME = ddiigs
IMGFILE = out/$(VOLNAME).po

.PHONY: package clean

package: $(IMGFILE)

out/mission1: src/mission1.s
	mkdir -p out
	cd src && merlin32 mission1.s
	mv src/mission1 out/mission1

out/title: src/title.s
	mkdir -p out
	cd src && merlin32 title.s
	mv src/title out/title

$(IMGFILE): res/PRODOS res/BASIC.SYSTEM assets/mission11.shr assets/mission12.shr assets/mission13.shr assets/mission14.shr assets/mission15.shr assets/billy1.shr out/mission1 out/title
	mkdir -p out
	rm -f $(IMGFILE)
	cadius CREATEVOLUME $(IMGFILE) $(VOLNAME) 800KB --quiet
	cp res/PRODOS out/PRODOS\#FF0000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/PRODOS\#FF0000 --quiet
	rm out/PRODOS\#FF0000
	cp res/BASIC.SYSTEM out/BASIC.SYSTEM\#FF2000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/BASIC.SYSTEM\#FF2000 --quiet
	rm out/BASIC.SYSTEM\#FF2000
	cp assets/mission11.shr out/MISSION11.SHR\#C10000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/MISSION11.SHR\#C10000 --quiet
	rm out/MISSION11.SHR\#C10000
	cp assets/mission12.shr out/MISSION12.SHR\#C10000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/MISSION12.SHR\#C10000 --quiet
	rm out/MISSION12.SHR\#C10000
	cp assets/mission13.shr out/MISSION13.SHR\#C10000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/MISSION13.SHR\#C10000 --quiet
	rm out/MISSION13.SHR\#C10000
	cp assets/mission14.shr out/MISSION14.SHR\#C10000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/MISSION14.SHR\#C10000 --quiet
	rm out/MISSION14.SHR\#C10000
	cp assets/mission15.shr out/MISSION15.SHR\#C10000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/MISSION15.SHR\#C10000 --quiet
	rm out/MISSION15.SHR\#C10000
	cp assets/billy1.shr out/BILLY1.SHR\#C10000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/BILLY1.SHR\#C10000 --quiet
	rm out/BILLY1.SHR\#C10000
	cp out/mission1 out/MISSION1\#FF2000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/MISSION1\#FF2000 --quiet
	rm out/MISSION1\#FF2000
	cp out/title out/TITLE\#FF0000
	cadius ADDFILE $(IMGFILE) /$(VOLNAME)/ out/TITLE\#FF0000 --quiet
	rm out/TITLE\#FF0000
	cadius CATALOG $(IMGFILE)

clean:
	rm -rf out

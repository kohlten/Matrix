DC=ldc2
OUT=bin/matrix

$(OUT):
	-git clone https://github.com/Jebbs/DSFMLC.git
	-cd DSFMLC && cmake . && make
	cp -rf DSFMLC/extlibs/libs-osx/Frameworks .
	cp DSFMLC/lib/* Frameworks
	dub build --compiler=$(DC)

clean:
	dub clean
	-rm dub.selections.json
	-rm -rf bin
	-rm -rf .dub
	-rm -rf DSFMLC
	-rm -rf Frameworks
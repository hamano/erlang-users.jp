MAN1=$(wildcard *.1)
MAN2=$(wildcard *.2)
HTML=$(MAN1:%.1=%.html) $(MAN2:%.2=%.html)
SED=$(MAN1:%.1=%.html) $(MAN2:%.2=%.html)

.SUFFIXES: .1 .html

all: $(HTML)

clean: $(HTML)
	rm -rf $^

.1.html:
	sed -f sed/template.sed $< > $<.tmp
	man2html -c < $<.tmp > $@
	rm -rf $<.tmp


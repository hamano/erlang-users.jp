MAN1=$(wildcard *.1)
MAN2=$(wildcard *.2)
HTML=$(MAN1:%.1=%.html) $(MAN2:%.2=%.html)
SED=$(MAN1:%.1=%.html) $(MAN2:%.2=%.html)

.SUFFIXES: .1 .html

all: index.html

clean: $(HTML) index.html
	rm -rf $^

.1.html:
	sed -f sed/template.sed $< > $<.tmp
	man2html -c < $<.tmp > $@
	rm -rf $<.tmp

index.html: $(HTML) header.html footer.html
	cat header.html > index.html
	for f in $(MAN1); do \
		echo "<li>$${f%.*}" >> $@; \
		echo "(<a href=\"$${f%.*}.html\">html</a>)" >> $@; \
		echo "(<a href=\"$${f}\">nroff</a>)" >> $@; \
		echo "</li>" >> $@; \
	done
	cat footer.html >> index.html

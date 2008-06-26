HTML=erl.html erlc.html

.SUFFIXES: .1 .html

all: $(HTML)
clean: $(HTML)
	rm -rf $^

.1.html:
	man2html -p < $< > $@


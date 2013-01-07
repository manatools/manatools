.PHONY: clean

curl_download:
	test -e Makefile_c || perl Makefile.PL
	$(MAKE) -f Makefile_c

install:
	test -e Makefile_c || perl Makefile.PL
	$(MAKE) -f Makefile_c install

clean:
	test ! -e Makefile_c || $(MAKE) -f Makefile_c clean
	rm -f *~ *.o

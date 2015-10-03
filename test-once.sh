#!/bin/sh
set -e
if [ ! -f test-in ]
then	printf 1>&2 "generating..."
	./test-gen.pl "$@" >test-in
	printf 1>&2 "done\n"
fi
time ./test.pl <test-in >test-out-pl
time ./test-qp <test-in >test-out-qp
time ./test-cb <test-in >test-out-cb
cmp test-out-pl test-out-qp
cmp test-out-pl test-out-cb
rm -f test-in test-out-??
#!/usr/local/bin/perl

BEGIN { push(@INC, './t') }
use W;
print W->new()->test('test2', "examples/every.pl", *DATA);

__END__
INTEGER	1
ADDOP	+
INTEGER	2
ADDOP	+
INTEGER	3
ADDOP	+
INTEGER	4
ADDOP	+
INTEGER	5
ADDOP	+
INTEGER	6
ADDOP	+
INTEGER	6
ADDOP	+
INTEGER	7
ADDOP	+
INTEGER	7
ADDOP	+
INTEGER	7
ADDOP	-
INTEGER	76
NEWLINE	

INTEGER	0
ADDOP	+
INTEGER	0
ADDOP	+
INTEGER	0
ADDOP	+
INTEGER	0
ADDOP	+
INTEGER	0
ADDOP	+
INTEGER	0
ADDOP	+
INTEGER	0
ADDOP	+
INTEGER	0
ADDOP	+
INTEGER	0
ADDOP	+
INTEGER	0
ADDOP	+
INTEGER	0
ADDOP	+
NEWLINE	

INTEGER	1
ADDOP	+
INTEGER	2
ADDOP	+
INTEGER	3
ADDOP	+
INTEGER	4
ADDOP	+
INTEGER	5
ADDOP	+
INTEGER	6
ADDOP	+
INTEGER	6
ADDOP	+
INTEGER	7
ADDOP	+
INTEGER	7
ADDOP	+
INTEGER	7
ADDOP	-
INTEGER	76
NEWLINE	

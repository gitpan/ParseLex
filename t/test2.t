#!/usr/local/bin/perl

BEGIN {  push(@INC, './t') }
use W;

require 5.004; 

$test = W->new('1..1');
$test->result("examples/every.pl");
$test->expected(\*DATA);
$test->assert('\n\n$');
print $test->report(1, sub { 
		      my $result = $test->result;
#		      print $result;
		      $test->expected eq $result;
		    });

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


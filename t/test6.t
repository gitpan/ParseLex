#!/usr/local/bin/perl

BEGIN { push(@INC, './t') }
use W;
$test = W->new('1..1');
$test->result("examples/from_string.pl");
$test->expected(\*DATA);
print $test->report(1, sub { 
		      my $expectation =  $test->expected;
		      my $result =  $test->result;
		      $expectation =~ s/\s+$//;
		      $result =~ s/\s+$//;
		      $expectation eq $result;
		    });

__END__
INTEGER 1 ADDOP + INTEGER 2 EOI 
INTEGER	1
ADDOP	+
INTEGER	2

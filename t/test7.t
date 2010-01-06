#!/usr/local/bin/perl

BEGIN { push(@INC, './t') }
use W;
$test = W->new('1..1');
$test->result("examples/sexpcond.pl");
$test->expected(\*DATA);
print $test->report(1, sub { 
		      my $expectation =  $test->expected;
		      my $result =  $test->result;
		      $expectation =~ s/\s+$//;
		      $result =~ s/\s+$//;
		      unless ($expectation eq $result) {
			print "$result\n" if $ENV{TEST_VERBOSE};
			0;
		      } else {
			1;
		      }
		    });

__END__
result of (* 2 (+ 3 3)): 12
Trace is ON in class Parse::Lex
[Parse::SExpressions] Token read (LEFTP, [\(]): (
[Parse::SExpressions] Token read (OPERATOR, [-+\/*]): *
[Parse::SExpressions] Token read (NUMBER, \d+): 2
[Parse::SExpressions] Token read (LEFTP, [\(]): (
[Parse::SExpressions] Token read (OPERATOR, [-+\/*]): +
[Parse::SExpressions] Token read (NUMBER, \d+): 3
[Parse::SExpressions] Token read (NUMBER, \d+): 3
[Parse::SExpressions] Token read (RIGHTP, [\)]): )
[Parse::SExpressions] Token read (RIGHTP, [\)]): )




#!/usr/local/bin/perl

BEGIN { push(@INC, './t') }
use W;
$test = W->new('1..1');
$test->result("examples/evparser.pl");
$test->expected(\*DATA);
print $test->report(1, sub { 
		      my $expectation =  $test->expected;
		      my $result =  $test->result;
		      $expectation =~ s/\s+$//;
		      $result =~ s/\s+$//;
		      $expectation eq $result;
		    });

__END__
comment: /*
  A C comment 
*/
remainder: 

ccomment: // A C++ comment

remainder: var d = 
dquotes: "string in \"double\" quotes"
remainder: ;
var s = 
squotes: 'string in ''single'' quotes'
remainder: ;
var x = 1;
var y = 2;

Version 1.00

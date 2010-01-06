#!/usr/local/bin/perl

BEGIN {  push(@INC, './t') }
use W;

$test = W->new('1..1');
$test->result("examples/ctokens.pl");
$test->expected(\*DATA);
print $test->report(1, sub { 
		      my $expectation =  $test->expected;
		      my $result =  $test->result;
		      $expectation =~ s/\s+$//;
#		      print STDERR "\nResult:\n$result\n";
#		      print STDERR "Expectation: $expectation\n";
		      $result =~ s/\s+$//;
		      $expectation eq $result;
		    });

__END__
1
+
2


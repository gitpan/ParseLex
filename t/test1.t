#!/usr/local/bin/perl

BEGIN {  push(@INC, './t') }
use W;

$test = W->new('1..1');
$test->result("examples/tokenizer.pl");
$test->expected(\*DATA);
print $test->report(1, sub { 
		      my $expectation =  $test->expected;
		      my $result =  $test->result;
		      $expectation =~ s/\s+$//;
#		      print STDERR "Result: $result\n";
#		      print STDERR "Expectation: $expectation\n";
		      $result =~ s/\s+$//;
		      $expectation eq $result;
		    });

__END__
Tokenization of DATA:
Line 1	Type: main::INTEGER	Content:->1<-
Line 1	Type: main::ADDOP	Content:->+<-
Line 1	Type: main::INTEGER	Content:->2<-
Line 1	Type: main::ADDOP	Content:->-<-
Line 1	Type: main::INTEGER	Content:->5<-
Line 1	Type: main::NEWLINE	Content:->
<-
Line 3	Type: main::STRING	Content:->"This is a multiline
string with an embedded "" in it"<-
Line 3	Type: main::NEWLINE	Content:->
<-
Version 1.15
Trace is ON in class Parse::Lex
[main::lexer|Parse::Lex] Token read (main::INTEGER, [1-9][0-9]*): 1
[main::lexer|Parse::Lex] Token read (main::ADDOP, [-+]): +
[main::lexer|Parse::Lex] Token read (main::INTEGER, [1-9][0-9]*): 2
[main::lexer|Parse::Lex] Token read (main::ADDOP, [-+]): -
[main::lexer|Parse::Lex] Token read (main::INTEGER, [1-9][0-9]*): 5
[main::lexer|Parse::Lex] Token read (main::NEWLINE, 
): 

[main::lexer|Parse::Lex] Token read (main::STRING, "(?:[^"]+|"")*"): "This is a multiline
string with an embedded "" in it"
[main::lexer|Parse::Lex] Token read (main::NEWLINE, 
): 

[main::lexer|Parse::Lex] Token read (main::ERROR, .*): this is an invalid string with a "" in it"
can't analyze: "this is an invalid string with a "" in it"" at examples/tokenizer.pl line 22, <DATA> chunk 4.


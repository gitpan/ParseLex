#!/usr/local/bin/perl

BEGIN {  push(@INC, './t') }
use W;

require 5.004; 

$test = W->new('1..1');
$test->result("examples/tokenizer.pl");
$test->expected(\*DATA);
print $test->report(1, sub { 
		      my $expectation =  $test->expected;
		      my $result =  $test->result;
		      $expectation =~ s/\s+$//;
		      #print STDERR "Result:\n$result\n";
		      #print STDERR "Expectation:\n$expectation\n";
		      $result =~ s/\s+$//;
		      $expectation eq $result;
		    });

__END__
Tokenization of DATA:
Record number: 1
Type: INTEGER	Content:->1<-
Record number: 1
Type: ADDOP	Content:->+<-
Record number: 1
Type: INTEGER	Content:->2<-
Record number: 1
Type: ADDOP	Content:->-<-
Record number: 1
Type: INTEGER	Content:->5<-
Record number: 1
Type: NEWLINE	Content:->
<-
Record number: 3
Type: STRING	Content:->"This is a multiline
string with an embedded "" in it"<-
Record number: 3
Type: NEWLINE	Content:->
<-
Version 2.15
Trace is ON in class Parse::Lex
[main::lexer|Parse::Lex] Token read (INTEGER, [1-9][0-9]*): 1
[main::lexer|Parse::Lex] Token read (ADDOP, [-+]): +
[main::lexer|Parse::Lex] Token read (INTEGER, [1-9][0-9]*): 2
[main::lexer|Parse::Lex] Token read (ADDOP, [-+]): -
[main::lexer|Parse::Lex] Token read (INTEGER, [1-9][0-9]*): 5
[main::lexer|Parse::Lex] Token read (NEWLINE, \n): 

[main::lexer|Parse::Lex] Token read (STRING, \"(?:[^\"]+|\"\")*\"): "This is a multiline
string with an embedded "" in it"
[main::lexer|Parse::Lex] Token read (NEWLINE, \n): 

[main::lexer|Parse::Lex] Token read (ERROR, .*): this is an invalid string with a "" in it"
can't analyze: "this is an invalid string with a "" in it""

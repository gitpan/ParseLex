#!/usr/local/bin/perl -w

require 5.000;

BEGIN {		
  push(@INC,  ("$ENV{'HOME'}/lib/perl5")); # or PERL5LIB
}

use Parse::Lex;
print STDERR "Version $Parse::Lex::VERSION\n";

@token = (
	  qw(
	     ADDOP    [-+]
	     LEFTP    [\(]
	     RIGHTP   [\)]
	     INTEGER  [1-9][0-9]*
	     NEWLINE  \n
	    ),
	  qw(STRING),   [qw(" (?:[^"]+|"")* ")],
	  qw(ERROR  .*), sub {
	    die qq!can\'t analyze: "$_[1]"!;
	  }
	 );

Parse::Lex->trace;
$lexer = Parse::Lex->new(@token);

$lexer->from(\*DATA);
print "Tokenization of DATA:\n";

TOKEN:while (1) {
  $token = $lexer->next;
  if (not $lexer->eoi) {
    print "Line $.\t";
    print "Type: ", $token->name, "\t";
    print "Content:->", $token->getstring, "<-\n";
  } else {
    last TOKEN;
  }
}

__END__
1+2-5
"This is a multiline
string with an embedded "" in it"
this is an invalid string with a "" in it"



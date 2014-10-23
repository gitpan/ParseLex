# Copyright (c) Philippe Verdret, 1995-1997

require 5.003;
use strict qw(vars);
use strict qw(refs);
use strict qw(subs);

package Parse::Lex;
use vars qw($VERSION);
$VERSION = '1.15';
use Parse::Trace;
@Parse::Lex::ISA = qw(Parse::Trace);
use Parse::Token;
use Carp;
use Parse::Preprocess;
use vars qw($trace);
$trace = 0;			# control trace mode

				# Default values
my $DEFAULT_FH = \*STDIN;	# Input Filehandle 
my $eoi = 0;			# 1 if end of imput 
my $DEFAULT_TOKEN = Parse::Token->new('default token', '.*'); # default token
my $pendingToken = 0;		# if 1 there is a pending token
				# You can access to these variables from outside!

my $skip = '[ \t]+';		# strings to skip
my $hold = 0;			# if true enable data saving

my $lexer = bless [];		# Prototype object
my($FH, $STRING, $SUB, $BUFFER, $PENDING_TOKEN, 
   $EOI, $SKIP, $HOLD, $HOLD_CONTENT, $COMPLEX_RE, 
   $NAME, $IN_PKG,
   $CODE_HEAD, $CODE_BODY, $CODE_FOOT, $TRACE, $INIT, 
   $TOKEN_LIST
  ) = (0..17);
$lexer->[$FH] = $DEFAULT_FH;
$lexer->[$STRING] = 0; # if 1 data come from string
$lexer->[$SUB] = sub {
  $_[0]->[$FH] = $DEFAULT_FH;	# read on default Filehandle
  $_[0]->genlex;		# autogeneration
  &{$_[0]->[$SUB]};		# execution
};
$lexer->[$BUFFER] = '';		# string to tokenize
$lexer->[$PENDING_TOKEN] = $DEFAULT_TOKEN;
$lexer->[$EOI] = $eoi;
$lexer->[$SKIP] = $skip;
$lexer->[$HOLD] = $hold;	# save or not what is consumed
$lexer->[$HOLD_CONTENT] = '';	# saved string
$lexer->[$COMPLEX_RE] = 0;	# if 1 three part regexp
$lexer->[$CODE_HEAD] = '';	# lexer code
$lexer->[$CODE_BODY] = '';	# lexer code
$lexer->[$CODE_FOOT] = '';	# lexer code
$lexer->[$TRACE] = $trace;
$lexer->[$INIT] = 1;		# for the first generation
$lexer->[$TOKEN_LIST] = undef;
$Lex::PEND_TOKEN = $PENDING_TOKEN;

sub next { &{$_[0]->[$SUB]} }
sub eoi { 
  my $self = shift;
  $self->[$EOI];
} 
sub token {			# always return a Token object
  my $self = shift;
  $self->[$PENDING_TOKEN] or
    $DEFAULT_TOKEN 
} 
sub tokenis {			# force the token
  my $self = shift;
  $self->[$PENDING_TOKEN] = $_[0];
}
sub setbuffer {			# set the buffer content
  my $self = shift;
  $self->[$BUFFER] = $_[0];
} 
sub getbuffer {			# get the buffer content
  my $self = shift;
  $self->[$BUFFER]; 
} 
sub buffer { 
  my $self = shift;
  if (defined $_[0]) {
    $self->[$BUFFER] = $_[0] 
  } else {
    $self->[$BUFFER];
  }
} 
sub flush {
  my $self = shift;
  my $tmp = $self->[$HOLD_CONTENT];
  $self->[$HOLD_CONTENT] = '';
  $tmp;
}
sub less { 
  my $self = shift;
  if (defined $_[0]) {
    $self->[$BUFFER] = $_[0] . 
      $self->[$BUFFER];
  }
}
sub name {			# not documented
  my $self = shift;
  if (defined $_[0]) {
    $self->[$NAME] = $_[0] 
  } else {
    $self->[$NAME];
  }
}
sub inpkg {			# not documented
  my $self = shift;
  if (defined $_[0]) {
    $self->[$IN_PKG] = $_[0] 
  } else {
    $self->[$IN_PKG];
  }
}
# Purpose: execute some action on each token
# Arguments: an anonymous sub to call on each token
# Returns: undef

sub every {			
  my $self = shift;
  my $ref = ref($_[0]);
  if (not $ref or $ref ne 'CODE') { 
    croak "every must have an anonymous routine as argument";
  }
  my $token = &{$self->[$SUB]}($self);
  while (not $self->[$EOI]) {
    &{$_[0]}($token);
    $token = &{$self->[$SUB]}($self);
  }
  undef;
}
sub reset { 
  my $self = shift;
  $self->[$EOI] = 0; 
  $self->[$BUFFER] = ''; 
  if ($self->[$PENDING_TOKEN]) { 
    $self->[$PENDING_TOKEN]->setstring();
    $self->[$PENDING_TOKEN] = 0;
  }
}
sub tokenlist {
  my $self = shift;
  @{$self}[$TOKEN_LIST..$#{$self}]; 
}
# where data come from
sub from {
  my $self = shift;
				# Read data from a filehandle
  if (ref($_[0]) eq 'GLOB' and defined fileno($_[0])) {	
    if ($self->[$FH] ne $_[0]) { # FH not defined or has changed
      $self->[$FH] = $_[0];
      $self->[$STRING] = 0;
      $self->genbody($self->tokenlist) if $self->[$COMPLEX_RE];
      $self->genlex();
    }
    $self->reset;
  } elsif (defined $_[0]) {		# Data from a variable or a list
    unless ($self->[$STRING]) {
      $self->genbody($self->tokenlist) if $self->[$COMPLEX_RE];
      $self->genlex();
    }
    $self->reset;
    $self->[$BUFFER] = join($", @_); # Data from a list
  } elsif ($self->[$FH]) {
    $self->[$FH];
  } else {
    undef;
  }
}

#Structure of the next routine:
#  $header_ST | $header_FH
#  (($rowHeader_SIMPLE|$rowHeader_COMPLEX_FH|$rowHeader_COMPLEX_ST)
#   ($rowFooter|$rowFooterSub))+
#  $footer

my $header_ST = q!
  {		
   my $buffer = $_[0]->[<<$_BUFFER>>];
   if ($buffer ne '') {
     $buffer =~ s/^(<<$_skip_>>)//;
     <<$Lex::holdSkip>>
   }
   if ($buffer eq '') {
     $_[0]->[<<$_EOI>>] = 1;
     $_[0]->[<<$Lex::_PENDING_TOKEN>>] = $Token::EOI;
     return $Token::EOI;
   }
   my $content = '';
   my $token = undef;
 CASE:{
!;

my $header_FH = q!
  {
   my $buffer = $_[0]->[<<$_BUFFER>>];
   if ($buffer ne '') {
     $buffer =~ s/^(<<$_skip_>>)//;
     <<$Lex::holdSkip>>
   }
   if ($buffer eq '') {
     if ($_[0]->[<<$_EOI>>]) # if EOI
       { 
         $_[0]->[<<$Lex::_PENDING_TOKEN>>] = $Token::EOI;
         return $Token::EOI;
       } 
     else 
       {
        my $fh = $_[0]->[<<$_FH>>];
        do {
           $buffer = <$fh>; 
           if (defined($buffer)) {
             $buffer =~ s/^(<<$_skip_>>)//;
             <<$Lex::holdSkip>>
           } else {
             $_[0]->[<<$_EOI>>] = 1;
             $_[0]->[<<$Lex::_PENDING_TOKEN>>] = $Token::EOI;
             return $Token::EOI;
           }
         } while ($buffer eq '');
       }
   }
   my $content = '';
   my $token = undef;
 CASE:{
!;
my $rowHeader_SIMPLE = q!  
   $buffer =~ s/^(<<$Lex::begin>>)// and do {
   $content = $1;
!;
my $rowHeader_SIMPLE_TRACE = q!
   if ($_[0]->[<<$Lex::_TRACE>>]) {
     my $trace = "Token read (" . $<<$Lex::id>>->name .
       ", <<$Lex::begin>>\E): $content"; 
     $_[0]->context($trace);
   }!;
my $rowHeader_COMPLEX_ST = q!
   $buffer =~ s/^(<<$Lex::begin>><<$Lex::between>><<$Lex::end>>)// and do {
   $content = $1;
!;
my $rowHeader_COMPLEX_FH = q!
    $buffer =~ s/^(<<$Lex::begin>>)// and do {
    my $string = $buffer;
    $content = $1;
    my $fh = $_[0]->[<<$_FH>>];
    do {
      while (not $string =~ /<<$Lex::end>>/) {
        $string = <$fh>;
        if (not defined($string)) {
           $_[0]->[<<$_EOI>>] = 1;
           $_[0]->[<<$Lex::_PENDING_TOKEN>>] = $Token::EOI;
           return $Token::EOI;
        }
        $buffer .= $string;
      }
      $string = '';
      $buffer =~ s/^(<<$Lex::between>>)//;
      $content .= $1;
    } until ($buffer =~ s/^(<<$Lex::end>>)//);
    $content .= $1;
!;
my $rowHeader_COMPLEX_TRACE = q!
  if ($_[0]->[<<$Lex::_TRACE>>]) { # Trace
     my $trace = "Token read (" . $<<$Lex::id>>->name .
       ", <<$Lex::begin>><<$Lex::between>><<$Lex::end>>\E): $content"; 
     $_[0]->context($trace);
  }!;
my $rowFooterSub = q!
    $_[0]->[<<$_BUFFER>>] = $buffer;
    $<<$Lex::id>>->setstring($content);
    $_[0]->[<<$Lex::_PENDING_TOKEN>>] = $token = $<<$Lex::id>>;
    $content = &{$<<$Lex::id>>->mean}($token, $content);
    $<<$Lex::id>>->setstring($content);
    $token = $_[0]->[<<$Lex::_PENDING_TOKEN>>]; # if tokenis in sub
    last CASE;
  };
!;
my $rowFooter = q!
    $_[0]->[<<$_BUFFER>>] = $buffer;
    #$content = "$content$1";
    $<<$Lex::id>>->setstring($content);
    $_[0]->[<<$Lex::_PENDING_TOKEN>>] = $token = $<<$Lex::id>>;
    last CASE;
   };
!;
my $footer = q!
  }#CASE
  <<$Lex::holdToken>>
  return $token;
}!;
$Lex::holdToken = qq!\$_[0]->[$HOLD_CONTENT] .= \$content; # hold consumed strings!;
$Lex::holdSkip = qq!\$_[0]->[$HOLD_CONTENT] .= \$1; # hold consumed strings!;

# hold(EXPR)
# hold
# Purpose: hold or not consumed string, else return the current value
# Arguments: nothing or EXPR true/false
# Returns: the current value of the hold attribute

sub hold {			
  my $self = shift;
  if (ref $self) {
      $self->[$HOLD] = not $self->[$HOLD];
      $self->genbody($self->tokenlist);
      $self->genlex();
  } else {			# for the class attribute
				# or perhaps change the default object
    $hold = not $hold;
  }
}

# skip(EXPR)
# skip
# Purpose: return or set the value of the regexp used for consuming
#  inter-token strings. 
# Arguments: with EXPR changed the regexp and regenerate the
#  lexical analyzer 
# Returns: see Purpose

sub skip {			
  my $self = shift;
  if (ref $self) {
    if (defined($_[0])) {
      if ($_[0] ne $self->[$SKIP]) {
	$self->[$SKIP] = $_[0];
	$self->genlex();
      }
    } else {
      $self->[$SKIP];
    }
  } else {			# for the class attribute
				# or perhaps change the default object
    defined $_[0] ? $skip = $_[0] : $skip;
  }
}


# Purpose: create the lexical analyzer, with the associated tokens
# Arguments: list of token specifications
# Returns: a lex object

sub new {
  my $receiver = shift;
  my $class = (ref $receiver or $receiver);
  if (not defined($_[0])) {
    croak "arguments of the new method must be a list of token specifications";
  }

  $lexer->reset;
  my $self = bless[@{$lexer}], $class; # the default 

  $self->[$INIT] = 1;
  $self->[$HOLD] = $hold;	# perhaps put this in the default object
  $self->[$TRACE] = $trace; 
  $self->[$SKIP] = $skip; 
  $self->[$IN_PKG] = (caller(0))[0]; # From which package?

  my @token = $self->newset(@_);
  splice(@{$self}, $TOKEN_LIST, 1, @token);	

  $self->genbody(@token);
}

# Purpose: create the lexical analyzer
# Arguments: list of tokens
# Returns: a Lex object

sub genbody {
  my $self = shift;
  my $sub;
  $self->[$COMPLEX_RE] = 0;
  local $Lex::id;	
  local $Lex::_TRACE = $TRACE;
  if ($self->[$INIT]) {	# object creation
    $self->[$TRACE] = $trace; # class current value
    $self->[$INIT] = 0;
  }
  local $Lex::_PENDING_TOKEN = $PENDING_TOKEN;
  local $Lex::_BUFFER = $BUFFER;
  local $Lex::_EOI = $EOI;
  local $Lex::_FH = $FH;
  local $Lex::holdToken = '' unless $self->[$HOLD];
  local($Lex::regexp, $Lex::begin, $Lex::between, $Lex::end);
  my $fh = $self->[$FH]; 
  no strict 'refs';		# => ${$Lex::id}
  my $token;
  my $body = '';
  while (@_) {
    $token = shift;
    $Lex::regexp = $token->regexp;
    $Lex::id = $token->name;

    if (ref($Lex::regexp) eq 'ARRAY') {
      $self->[$COMPLEX_RE] = 1;
      if ($#{$Lex::regexp} >= 3) {
	carp join  " " , "Warning!", $#{$Lex::regexp} + 1, 
	"arguments in your token definition";
      }
      $Lex::begin = ppregexp(${$Lex::regexp}[0]);
      $Lex::between = ${$Lex::regexp}[1] ? 
	ppregexp(${$Lex::regexp}[1]) : '(?:.*?)';
      $Lex::end = ppregexp(${$Lex::regexp}[2] or ${$Lex::regexp}[0]);

      if ($fh) {
	$body .= ppcode($rowHeader_COMPLEX_FH, 'Lex');
      } else {
	$body .= ppcode($rowHeader_COMPLEX_ST, 'Lex');
      }
      if ($self->[$TRACE]) {
	$body .= ppcode($rowHeader_COMPLEX_TRACE, 'Lex');
      } 
      $Lex::between = '';
    } else {
      $Lex::begin = ppregexp($Lex::regexp);
      $body .= ppcode($rowHeader_SIMPLE, 'Lex');
      if ($self->[$TRACE]) {
	$body .= ppcode($rowHeader_SIMPLE_TRACE, 'Lex');
      } 
    }

    $sub = $token->mean;
    if ($sub) {			# Token with an associated sub
      $body .= ppcode($rowFooterSub, 'Lex');
      $sub = undef;		# 
    } else {
      $body .= ppcode($rowFooter, 'Lex');
    }
  }

  $self->[$CODE_BODY] = $body;
  $self;
}

# Purpose: Generate the lexical analyzer
# Arguments: 
# Returns: 

sub genlex {
  my $self = shift;
				# save all what is consumed or not 
  local $Lex::holdToken = '' unless $self->[$HOLD];
  local $Lex::holdSkip = ''  unless $self->[$HOLD];
  local $Lex::_skip_ = $self->[$SKIP];
  local $Lex::_FH = $FH;
  local $Lex::_BUFFER = $BUFFER;
  local $Lex::_EOI = $EOI;
  local $Lex::_PENDING_TOKEN = $PENDING_TOKEN;
  my $fh = $self->[$FH];	# 
  my $head;			# sub genhead
  if ($fh) {
    $head = $self->[$CODE_HEAD] = ppcode($header_FH, 'Lex');
  } else {
    $head = $self->[$CODE_HEAD] = ppcode($header_ST, 'Lex');
  }
				# sub genfoot
  my $foot = $self->[$CODE_FOOT] = ppcode($footer, 'Lex');

  my $analyser = $head . $self->[$CODE_BODY] . $foot;
  eval qq!\$self->[$SUB] = sub $analyser!; # Create the lexer

  if ($@) {	# can be usefull ;-)
    my $line = 0;
    $analyser =~ s/^/sprintf("%3d", $line++)/meg if $@;	# line numbers
    print STDERR "$analyser\n";
    print STDERR "$@\n";
    die "\n";
  }
}

# Purpose: Returns code of the lexical analyzer
# Arguments: nothing
# Returns: code of the lexical analyzer
# Remarks: not documented

sub getcode {
  my $self = shift;
  $self->[$CODE_HEAD] . $self->[$CODE_BODY]. $self->[$CODE_FOOT];
}

# Purpose: returns the lexical analyzer like an anonymous sub
# Arguments: nothing
# Returns: an anonymous sub implementing the lexical analyzer
# Remarks: not documented

sub getsub {
  my $self = shift;
  my $sub = "$self->[$CODE_HEAD] $self->[$CODE_BODY] $self->[$CODE_FOOT]";
  eval "sub $sub";
}

# Purpose: Generate a set of tokens and define these tokens
#          in the package of the caller
# Arguments: list of token specification
# Returns: list of token objects
# Remarks: define a new class (container)

sub newset {		
  my $self = shift;
  my $inpkg = $self->inpkg;
  if (not defined $inpkg) {
    $inpkg = (caller(0))[0];
  }
  if (not defined($_[0])) {
    croak "arguments of the newset method must be a list of token specifications";
  }
  my $sub;
  my $ref;
  my $tokenid;
  my $regexp;
  my $tmp;
  my @token;
  no strict 'refs';		# => ${$tokenid}
  while (@_) {
    ($tokenid, $regexp) = (shift, shift);
    $tokenid = "$inpkg" . "::" . "$tokenid";
    if (@_) {
      $ref = ref($_[0]);
      if ($ref and $ref eq 'CODE') { # if next arg is a sub reference
	$sub = shift;
      } else {
	$sub = undef;
      }
    }
    # Creation of a new Token object
    ${$tokenid} = $tmp = Parse::Token->new($tokenid, $regexp, $sub, $self);
    push(@token, $tmp);				    
  }
  @token;
}
sub readline {
  my $fh = $_[0]->[$FH];
  $_ = <$fh>;
  if (not defined($_)) {
    $_[0]->[$EOI] = 1;
  } else {
    $_;
  }
}
# Purpose: Toggle the trace mode
# todo: regenerate the analyser's body
sub trace { 
  my $self = shift;
  my $class = ref($self);
  if ($class) {			# for an object
    if ($self->[$TRACE]) {
      $self->[$TRACE] = 0;
      print STDERR qq!trace OFF for a "$class" object\n!;
    } else {
      $self->[$TRACE] = 1;
      print STDERR qq!trace ON for a "$class" object\n!;
    }
  } else {			# for the class attribute
    $self->SUPER::trace(@_);
  }
}
1;
__END__

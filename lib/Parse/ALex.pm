# Copyright (c) Philippe Verdret, 1995-1998

# Architecture:
# Parse::Template + Parse::ALex - Abstract Lexer
#              /  |  \
#             /   |   \
#          Lex  CLex  ...       - Concrete lexer from an instanciated template

# Todo:
# Parse::Lex->configure(-from => TT, -xxx => yyy)

require 5.003;
use integer;
use strict qw(vars);
use strict qw(refs);
use strict qw(subs);

package Parse::ALex;
$Parse::ALex::VERSION = '2.01';
use Parse::Trace;
@Parse::ALex::ISA = qw(Parse::Trace);
use Parse::Token;
use Parse::Template;
use Carp;

my $thisClass = &{sub { caller }};

				# Default values
my $trace = 0;			# if true enable the trace mode
my $hold = 0;			# if true enable data saving
my $skip = '[ \t]+';		# strings to skip
my $DEFAULT_STREAM = \*STDIN;	# Input Filehandle 
my $eoi = 0;			# 1 if end of imput 
my $DEFAULT_TOKEN = Parse::Token->new('DEFAULT', '.*'); # default token
my $pendingToken = 0;		# 1 if there is a pending token
				# You can access to these variables from outside!


my $lexer = bless [];		# Prototypical instance
sub prototype { $lexer }

my $index = -1;
my %_map;			# Define a mapping between element names and numbers
my($STREAM, $FROM_STRING, $SUB, $BUFFER, $PENDING_TOKEN, 
   $LINE, $RECORD_LENGTH, $OFFSET, $POS,
   $EOI, $SKIP, $HOLD, $HOLD_TEXT, $THREE_PART_RE, 
   $NAME, $IN_PKG,
   $TEMPLATE, 
   $STRING_SUB, $STREAM_SUB, $HANDLES,
   $STRING_CODE, $STREAM_CODE, $CODE,
   $CODE_STATE_MACHINE, 
   $STATES, $STACK_STATES,
   $EXCLUSIVE_COND, $INCLUSIVE_COND,
   $TRACE, $INIT, 
   $TOKEN_LIST
  ) = map {
    $_map{$_} = ++$index;
  } qw(STREAM FROM_STRING SUB BUFFER PENDING_TOKEN 
       LINE RECORD_LENGTH OFFSET POS
       EOI SKIP HOLD HOLD_TEXT THREE_PART_RE 
       NAME IN_PKG
       TEMPLATE
       STRING_SUB STREAM_SUB HANDLES
       STRING_CODE STREAM_CODE CODE
       CODE_STATE_MACHINE 
       STATES STACK_STATES
       EXCLUSIVE_COND INCLUSIVE_COND
       TRACE INIT 
       TOKEN_LIST);
sub _map { $_map{($_[1])} }	

my $somevar = '';
$lexer->[$STREAM] = $DEFAULT_STREAM;
$lexer->[$FROM_STRING] = 0; # 1 if you must analyze a string
$lexer->[$BUFFER] = \$somevar;		# string to tokenize
$lexer->[$PENDING_TOKEN] = $DEFAULT_TOKEN;
$lexer->[$LINE] = \$somevar;	# number of the current record
$lexer->[$RECORD_LENGTH] = \$somevar;	# length of the current record
$lexer->[$OFFSET] = \$somevar;		# offset from the beginning of the analysed stream
$lexer->[$POS] = \$somevar;		# position in the current record
$lexer->[$EOI] = $eoi;
$lexer->[$SKIP] = $skip;	# a pattern to skip
$lexer->[$HOLD] = $hold;	# save or not what is consumed
$lexer->[$HOLD_TEXT] = '';	# saved string
$lexer->[$THREE_PART_RE] = 0;	# 1 if three part regexp
$lexer->[$TEMPLATE] = new Parse::Template; # code template

				# Lexer code: [HEADER, BODY, FOOTER]
$lexer->[$STREAM_CODE] = [];	# cached version
$lexer->[$STRING_CODE] = [];	# cached version
$lexer->[$CODE] = [];		# current lexer
				# Anonymous routines

$lexer->[$HANDLES] = [];	# lexer closure environnement
$lexer->[$SUB] = sub {
  $_[0]->genLex;		# lexer autogeneration
  &{$_[0]->[$SUB]};		# lexer execution
};
$lexer->[$STREAM_SUB] = sub {};	# cache for the stream lexer
$lexer->[$STRING_SUB] = sub {};	# cache for the string lexer
				# State machine
$lexer->[$EXCLUSIVE_COND] = {};
$lexer->[$INCLUSIVE_COND] = {};
$lexer->[$CODE_STATE_MACHINE] = ''; # definition of the state machine
$lexer->[$STATES] = { 'INITIAL' => \$somevar };	# state machine
$lexer->[$STACK_STATES] = [];	# stack of states, not used
$lexer->[$TRACE] = $trace;
$lexer->[$INIT] = 1;		# true at object creation
$lexer->[$TOKEN_LIST] = [];	# Tokens

my $tokenClass = 'Parse::Token'; # Default token class
sub tokenClass { 
  if (defined $_[1]) {
    no strict qw/refs/;
    ${"$tokenClass" . "::PENDING_TOKEN"} = $PENDING_TOKEN; 
    $tokenClass = $_[1];
  } else {
    $_[1] 
  }
}
$lexer->tokenClass($tokenClass);

sub reset {			# reset all lexer's state values
  my $self = shift;
  ${$self->[$LINE]} = 0;
  ${$self->[$RECORD_LENGTH]} = 0;
  ${$self->[$OFFSET]} = 0;
  ${$self->[$POS]} = 0;
  ${$self->[$BUFFER]} = ''; 
  $self->[$HOLD_TEXT] = '';
  $self->[$EOI] = 0; 
  $self->state('INITIAL');	# initialize the state machine
  if ($self->[$PENDING_TOKEN]) { 
    $self->[$PENDING_TOKEN]->setText();
    $self->[$PENDING_TOKEN] = 0;
  }
  $self;
}

sub eoi { 
  my $self = shift;
  $self->[$EOI];
} 
sub token {			# always return a Token object
  my $self = shift;
  $self->[$PENDING_TOKEN] or $DEFAULT_TOKEN 
} 
*getToken = \&token;
sub setToken {			# force the token
  my $self = shift;
  $self->[$PENDING_TOKEN] = $_[0];
}
sub setBuffer {			# not documented
  my $self = shift;
  ${$self->[$BUFFER]} = $_[0];
} 
sub getBuffer {			# not documented
  my $self = shift;
  ${$self->[$BUFFER]}; 
} 
sub buffer { 
  my $self = shift;
  if (defined $_[0]) {
    ${$self->[$BUFFER]} = $_[0] 
  } else {
    ${$self->[$BUFFER]};
  }
} 
sub flush {
  my $self = shift;
  my $tmp = $self->[$HOLD_TEXT];
  $self->[$HOLD_TEXT] = '';
  $tmp;
}
# returns or sets the number of the current record
sub line {	
  my $self = shift;
  if (@_) {
    ${$self->[$LINE]} = shift;
  } else {
    ${$self->[$LINE]};
  }
}
# return the length of the current record
# not documented
sub length {	
  my $self = shift;
  ${$self->[$RECORD_LENGTH]};
}
# return the end position of last token from the stream beginning
sub offset {			
  my $self = shift;
  ${$self->[$OFFSET]};
}
# return the end position of the last token 
# in the current record
sub pos {		
  my $self = shift;
  if (defined $_[0]) {
    ${$self->[$POS]} = $_[0] 
  } else {
    ${$self->[$POS]};
  }
}
sub name {		      
  my $self = shift;
  if (defined $_[0]) {
    $self->[$NAME] = $_[0] 
  } else {
    $self->[$NAME];
  }
}
# not documented
sub inpkg {		
  my $self = shift;
#  if (ref $self) {
    if (defined $_[0]) {
      $self->[$IN_PKG] = $_[0] 
    } else {
      $self->[$IN_PKG];
    }
#  } else {
#    if (defined $_[0]) {
#      $inpkg = $_[0] 
#    } else {
#      $inpkg;
#    }
#  }
}
sub tokenList {
  my $self = shift;
  @{$self->[$TOKEN_LIST]}; 
}
				# Call of the lexer routine
sub next { &{$_[0]->[$SUB]} }

# Purpose: Analyze data in one call
# Arguments: string or stream to analyze
# Returns: a list of token name and text
# Todo: generate a specific lexer
sub analyze {			
  my $self = shift;
  my $from = shift;
  $self->from($from);
  my $sub = $self->[$SUB];
  my $token = &{$sub}($self);
  my @token = ($token->name, $token->text);
  while (not $self->[$EOI]) {
    $token = &{$sub}($self);
    push (@token, $token->name, $token->text);
  }
  @token;
}

# Purpose: execute some action on each token
# Arguments: an anonymous sub to call on each token
# Returns: undef
sub every {			
  my $self = shift;
  my $ref = ref($_[0]);
  if (not $ref or $ref ne 'CODE') { 
    croak "argument of the 'every' method must be an anonymous routine";
  }
  my $token = &{$self->[$SUB]}($self);
  while (not $self->[$EOI]) {
    &{$_[0]}($token);
    $token = &{$self->[$SUB]}($self);
  }
  undef;
}
# Purpose: define the data input
# Parameters: 
# 1. reference to a filehandle 
# 2. a string list
# 3. <none> 
# Returns:  1. returns the lexer
#           2. returns the lexer
#           3. returns the lexer's filehandle if defined
#              or undef if not 
sub from {
  my $self = shift;
  my $debug = 0;
				# From STREAM
  if (ref($_[0]) eq 'GLOB' and defined fileno($_[0])) {	
    $self->[$STREAM] = $_[0];

    print STDERR "From stream\n" if $debug;

    if (@{$self->[$STREAM_CODE]}) { # Code already exists
      if ($self->[$FROM_STRING]) { # if STREAM definition isn't the current
	print STDERR "code already exists\n" if $debug;
	$self->[$CODE] = [@{$self->[$STREAM_CODE]}];
	$self->[$SUB] = $self->[$STREAM_SUB];
	$self->_switchHandles();
	$self->[$FROM_STRING] = 0;
      }
    } else {
      print STDERR "STREAM code generation\n" if $debug;
      # genCode()
      $self->[$FROM_STRING] = 0;
      $self->genBody($self->tokenList); # if $self->[$THREE_PART_RE];
      $self->genHeader();
      $self->genFooter();
      #
      $self->_saveHandles();
      $self->genLex();
				# $self->getCode()
      $self->[$STREAM_CODE] = [@{$self->[$CODE]}]; # cache
      $self->[$STREAM_SUB] = $self->[$SUB];
    }

    $self->reset;
    $self;
  } elsif (defined $_[0]) {	# From STRING
    unless ($self->[$FROM_STRING]) {
      print STDERR "From string\n" if $debug;

      $self->[$FROM_STRING] = 1;
    
      if (@{$self->[$STRING_CODE]}) { # code already exists
	print STDERR "code already exists\n" if $debug;
	$self->[$CODE] = [@{$self->[$STRING_CODE]}];
	$self->[$SUB] = $self->[$STRING_SUB];
	$self->_switchHandles();
      } else {
	print STDERR "code generation\n" if $debug;
	# genCode()
	$self->genBody($self->tokenList); # if $self->[$THREE_PART_RE];
	$self->genHeader();
	$self->genFooter();
	#
	$self->_saveHandles();
	$self->genLex();
				# $self->getCode()
	$self->[$STRING_CODE] = [@{$self->[$CODE]}];	# cache
	$self->[$STRING_SUB] = $self->[$SUB];
      }
    }
    $self->reset;
    my $buffer = join($", @_); # Data from a list
    ${$self->[$BUFFER]} = $buffer;
    ${$self->[$RECORD_LENGTH]} = length($buffer);
    $self;
  } elsif ($self->[$STREAM]) {
    $self->[$STREAM];
  } else {
    undef;
  }
}
# Not documented
# Purpose: direct access to some internal variables of a lexer object
# Arguments: nil
# Returns: references to some internal object fields
sub handles {
  my $self = shift;
  ($self->[$BUFFER], 
   $self->[$RECORD_LENGTH],
   $self->[$LINE], 
   $self->[$POS], 
   $self->[$OFFSET],
   $self->[$STATES],
  )
}
sub _saveHandles {
  my $self = shift;
  $self->[$HANDLES] = [$self->handles];
}
sub _switchHandles {
  my $self = shift;
  my @tmp = $self->handles();
  ($self->[$BUFFER], 
   $self->[$RECORD_LENGTH],
   $self->[$LINE], 
   $self->[$POS], 
   $self->[$OFFSET],
   $self->[$STATES],
  ) = @{$self->[$HANDLES]};
  @{$self->[$HANDLES]} = @tmp;
}

sub readline {
  my $fh = $_[0]->[$STREAM];
  my $record = '';
  if (not defined($record = <$fh>)) {
    $_[0]->[$EOI] = 1;
  } else {
    ${$_[0]->[$LINE]}++;
  }
  $record;
}

sub isTrace { $_[0]->[$TRACE] }
# Purpose: Toggle the trace mode
				# regenerate the lexer if needed!!!
sub trace { 
  my $self = shift;
  my $class = ref($self);
  if ($class) {			# Object atrtibute
    if ($self->[$TRACE]) {
      $self->[$TRACE] = 0;
      print STDERR qq!trace OFF for a "$class" object\n!;
    } else {
      $self->[$TRACE] = 1;
      print STDERR qq!trace ON for a "$class" object\n!;
    }
  } else {			# The class attribute
    $self->prototype()->[$TRACE] = not $self->prototype->[$TRACE];
    $self->SUPER::trace(@_);
  }
}
sub isHold { $_[0]->[$HOLD] }
# hold(EXPR)
# hold
# Purpose: Toggle method, hold or not consumed strings
# Arguments: nothing or EXPR true/false
# Returns: value of the hold attribute

sub hold {			
  my $self = shift;
  if (ref $self) {		# Instance method
      $self->[$HOLD] = not $self->[$HOLD];
      $self->genHeader();
      $self->genFooter();
      $self->genLex();
  } else {			# Class method
    $self->prototype()->[$HOLD] = not $self->prototype()->[$HOLD];
  }
}

# skip(EXPR)
# skip
# Purpose: return or set the value of the regexp used for consuming
#          inter-token strings. 
# Arguments: with EXPR change the regexp and regenerate the
#            lexical analyzer 
# Returns: see Purpose
sub skip {			
  my $self = shift;

  my $debug = 0;
  if (ref $self) {		# Instance method
    if (defined($_[0]) and $_[0] ne $self->[$SKIP]) {
      print STDERR "skip value: '$_[0]'\n" if $debug;

      $self->[$SKIP] = $_[0];
      $self->genHeader();
      $self->genLex();
    } else {
      $self->[$SKIP];
    }
  } else {			# Used as a Class method
    print STDERR "skip value: '$_[0]'\n" if $debug;

    defined $_[0] ?
      $self->prototype()->[$SKIP] = $_[0] : $self->prototype()->[$SKIP];
  }
}

# Purpose: create the lexical analyzer, with the associated tokens
# - the new lexer is a copy of the prototypical lexer if used as a class method
# - the new lexer is a copy of the message receiver if used as an instance method
# Arguments: list of token specifications
# Returns: a lex object
sub _clone {
  my $receiver = shift;
  my $class = (ref $receiver or $receiver);

  if ($class eq $thisClass) {
    croak "'$class' is an abstract class, can't create an instance"

  }
  my $prototype;
  my $self;
  
  if (ref $receiver) {		# Instance method: create from the current instance
    $self = bless [@{$receiver}], $class; 
  } else {			# Class method: create from the Prototype
    $self = bless [@{$class->prototype->reset}], $class; 
  }

  $self->template->partOf($self); # now the template is part of self

  $self->[$INIT] = 1;
  $self->[$IN_PKG] = (caller(1))[0]; # From which package?
  $self;
}
# Purpose: create the lexical analyzer
# Arguments: list of tokens or token specifications
# Returns: a lex object
sub new {
  my $self = shift;
  $self = $self->_clone;
  if (@_) {
    my @token = $tokenClass->factory(@_);
    my $token;
    foreach $token (@token) {	
      $token->lexer($self);	# Attach each token to its lexer
      $token->inpkg($self->inpkg); # Define the package in which the token is defined
      $token->exportTo();	# export to the calling package
    }
    $self->[$TOKEN_LIST] = [@token];
  }
  $self;
}

# Put or fetch a template object
sub template {
  my $self = shift;
  if (defined $_[0]) {
    $self->[$TEMPLATE] = $_[0];
  } else {
    $self->[$TEMPLATE];
  }
}
sub getTemplate {
  my $self = shift;
  my $part = shift;
  $self->[$TEMPLATE]->{$part};
}
sub setTemplate {
  my $self = shift;
  my $part = shift;
  $self->[$TEMPLATE]->{$part} = shift;
}

sub genCode {
  my $self = shift;
  $self->genHeader();
  $self->genBody($self->tokenList); 
  $self->genFooter();
}
# Remark: not documented
sub genHeader {
  my $self = shift;
  if ($self->[$FROM_STRING]) {
    $self->[$CODE]->[0] = $self->template->eval('HEADER_STRING');
  } else {
    $self->[$CODE]->[0] = $self->template->eval('HEADER_STREAM');
  }
}
# Purpose: create the lexical analyzer
# Arguments: list of tokens
# Returns: a Lex object
# Remark: not documented
sub genBody {
  my $self = shift;
				# 
  $self->[$THREE_PART_RE] = 0;
  if ($self->[$INIT]) {		# object creation
    $self->[$INIT] = 0;		# useless
  }
  my $fromString = $self->[$FROM_STRING]; 
  my $template = $self->template;
  my $sub;
  my $token;
  my $body = '';
  my $tokenid = '';
  my $regexp = '';
  my $ppregexp = '';
  my $tmpregexp = '';
  my $condition = '';
  while (@_) {			# list of Token instances
    $token = shift;
    $regexp = $token->regexp();
    $tokenid = $self->inpkg() . '::' . $token->name();
    $template->env('tokenid', $tokenid);
    $condition = $self->genCondition($token->condition);
    $template->env('condition', $condition);

    if (ref($regexp) eq 'ARRAY') {
      $self->[$THREE_PART_RE] = 1;
      if ($#{$regexp} >= 3) {
	carp join  " " , "Warning!", $#{$regexp} + 1, 
	"arguments in token definition";
      }
      $ppregexp = $tmpregexp = $template->ppregexp(${$regexp}[0]);
      $template->env('start', $ppregexp);

      $ppregexp = ${$regexp}[1] ? $template->ppregexp(${$regexp}[1]) : '(?:.*?)';
      $tmpregexp .= $ppregexp;
      $template->env('middle', $ppregexp);

      $ppregexp = $template->ppregexp(${$regexp}[2] or ${$regexp}[0]);
      $template->env('end', $ppregexp);
      $template->env('regexp', "$tmpregexp$ppregexp");

				# source of data
      if ($fromString) {
	$body .= $template->eval('ROW_HEADER_THREE_PART_RE_STRING');
      } else {
	$body .= $template->eval('ROW_HEADER_THREE_PART_RE_STREAM');
      }
    } else {
      $ppregexp = $template->ppregexp($regexp);
      $template->env('regexp', $ppregexp);
      $body .= $template->eval('ROW_HEADER_SIMPLE_RE');
    }

    $sub = $token->action;
    if ($sub) {			# Token with an associated sub
      $body .= $template->eval('ROW_FOOTER_SUB');
      $sub = undef;		# 
    } else {
      $body .= $template->eval('ROW_FOOTER');
    }
  }
  $self->[$CODE]->[1] = $body;
}
# Remark: not documented
sub genFooter {
  my $self = shift;
  $self->[$CODE]->[2] = $self->template->eval('FOOTER');
}

# Purpose: Returns code of the current lexer
# Arguments: nothing
# Returns: code of the lexical analyzer
# Remark: not documented, doesn't return the state machine definition
sub getCode { 
  my $self = shift;
  join '', @{$self->[$CODE]} 
}

# Purpose: Generate the lexical analyzer
# Arguments: 
#A Returns: the anonymous subroutine implementing the lexical analyzer
# Remark: not documented
sub genLex {
  my $self = shift;
  $self->genCode unless $self->getCode;	

				# closure environnement
  my $buffer = '';
  my $length = 0;		# length of the current record
  my $line = 0;
  my $pos = 0;
  my $offset = 0;
  my $token = '';

  $self->[$BUFFER] = \$buffer;
  $self->[$RECORD_LENGTH] = \$length;
  $self->[$LINE] = \$line;
  $self->[$POS] = \$pos;	# current position 
  $self->[$OFFSET] = \$offset;	# offset from the beginning

  my $fhr = \$self->[$STREAM];

				# The state machine
  my %state = ();
  $self->[$STATES] = \%state;
  my $stateMachine = $self->genStateMachine();

  my $analyzer = $self->getCode();
  eval qq!$stateMachine; \$self->[$SUB] = sub $analyzer!;

  my $debug = 0;
  if ($@ or $debug) {	# can be useful ;-)
    my $line = 0;
    $stateMachine =~ s/^/sprintf("%3d", $line++)/meg; # line numbers
    $analyzer =~ s/^/sprintf("%3d", $line++)/meg;
    print STDERR "$stateMachine$analyzer\n";
    print STDERR "$@\n";
    die "\n" if $@;
  }
  $self->[$SUB];
}

# Purpose: returns the lexical analyzer routine
# Arguments: nothing
# Returns: the anonymous sub implementing the lexical analyzer
sub getSub {
  my $self = shift;
  if (ref($self->[$SUB]) eq 'CODE') {
    $self->[$SUB];
  } else {
    $self->genLex();
  }
}
				# 
				# The State Machine
				# 
sub inclusive {
  my $self = shift;
  if (ref $self) {
    if (@_)  {
      $self->[$INCLUSIVE_COND]  = {@_};
    } else {
      $self->[$INCLUSIVE_COND];
    }
  } else {			# class method
    $self->prototype->inclusive(map { $_ => 1 } @_);
  }
}
sub exclusive {
  my $self = shift;
  if (ref $self) {
    if (@_) {
      $self->[$EXCLUSIVE_COND]  = {@_};
    } else {
      $self->[$EXCLUSIVE_COND];
    }
  } else {			# class method
    $self->prototype->exclusive(map { $_ => 1 } @_);
  }
}
sub genCondition {
  my $self = shift;
  my $specif = shift;
  my $prefix = '';		# genCondition
  my $condition = '';
  my $tmp = '';
  my %exclusion = %{$self->exclusive};
  my %inclusion = %{$self->inclusive};
  my $stateName = '';
  while ($specif =~ /^(.+):/g) {	# Ex. A:B:C: or A,C:
    ($prefix) = ($1);
    while ($prefix =~ /(\w+)/g) {
      delete $exclusion{$1};
      delete $inclusion{$1};
      if ($condition)  {
	$condition .= q! or $! . "$1";
      } else {
	$condition = qq!\(\$! . "$1";	# beginning
      }
    }
    $condition = "$condition)";	# end
  }
  my @tmp = ();
  if (@tmp = map { "\$$_" } keys(%exclusion)) {
    if ($condition) {
      $condition = "not (" . join(" or ", @tmp) . ") and $condition";
    } else {
      $condition = "not (" . join(" or ", @tmp) . ")";
    }
  } 
  if (@tmp = map { "\$$_" } keys(%inclusion) and $condition) {
    $condition = "not (" . join(" or ", @tmp) . ") and $condition";
  } 
  $condition ne '' ? "$condition and" : '';
}
sub genStateMachine { 
  my $self = shift;
  my $stateDeclaration = ' my $INITIAL = 1; ' .
      q!$state{'INITIAL'} = \\$INITIAL;! . "\n";
  my $stateName = '';
  my %exclusion = %{$self->exclusive};
  my %inclusion = %{$self->inclusive};
  foreach $stateName (keys (%inclusion), keys(%exclusion)) {
    $stateDeclaration .=
      q!my $! . "$stateName" . q! = 0; ! . 
	q!$state{'! . "$stateName" . q!'} = \\$! . "$stateName" . q!;!  . "\n";
  }
  $self->setStateMachine($stateDeclaration);
}
# not documented
sub setStateMachine {
  my $self = shift;
  $self->[$CODE_STATE_MACHINE] = shift;
}
# not documented
sub getStateMachine {
  my $self = shift;
  $self->[$CODE_STATE_MACHINE];
}
# not documented
sub getState {
  my $self = shift;
  my $state = shift;
  ${$self->[$STATES]->{$state}};
}
# not documented
sub setState {
  my $self = shift;
  my $state = shift;
  ${$self->[$STATES]->{$state}} = shift;
}
sub state {
  my $self = shift;
  my $state = shift;
  if (@_)  {
    ${$self->[$STATES]->{$state}} = shift;
  } else {
    ${$self->[$STATES]->{$state}};
  }
}
sub start {
  my $self = shift;
  my $state = shift;
  if ($state eq 'INITIAL') {
    $self->_restart() 
  } else {
    if (exists $self->[$EXCLUSIVE_COND]->{$state}) {
      $self->_restart;
    }
    $DB::single = 1;
    print STDERR "start: $state $self->[$STATES]\n";
    ${$self->[$STATES]->{$state}} = 1;
  }
}
sub _restart {
  my $self = shift;
  my $state = shift;
  my $hashref = $self->[$STATES];
  foreach $state (keys %$hashref) {
    ${$hashref->{$state}} = 0;
  }
  ${$hashref->{'INITIAL'}} = 1;
}
sub end {
  my $self = shift;
  my $state = shift;
  ${$self->[$STATES]->{$state}} = 0;
}
1;
__END__
sub pushState {}
sub popState {}
sub topState {}

1;
__END__

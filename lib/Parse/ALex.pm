# Copyright (c) Philippe Verdret, 1995-1999

# Architecture:
# Parse::Template + Parse::ALex - Abstract Lexer
#              /  |  \
#             /   |   \
#          Lex  CLex  ...       - Concrete lexer 

# Todo:
# Parse::Lex->configure(From => TT, Xxx => yyy)
# implement a lexer instance as a pseudo-hash
# use of constant is another possibility (see The Perl Journal Spring 99)
#   and replace [$ATT_NAME] by {ATT_NAME}

require 5.004;
use integer;
use strict qw(vars);
use strict qw(refs);
use strict qw(subs);

package Parse::ALex;
$Parse::ALex::VERSION = '2.09';
use Parse::Trace;
@Parse::ALex::ISA = qw(Parse::Trace); 

use Parse::Token;	
use Parse::Template;

				# Default values
my $trace = 0;			# if true enable the trace mode
my $hold = 0;			# if true enable data saving
my $skip = '[ \t]+';		# strings to skip
my $DEFAULT_STREAM = \*STDIN;	# Input Filehandle 
my $eoi = 0;			# 1 if end of imput 
my $pendingToken = 0;		# 1 if there is a pending token
my $index = -1;

#use constant STREAM => 0;
#use constant EOI => 9;

my %_map;			# Define a mapping between element names and numbers
my($STREAM, $FROM_STRING, $SUB, $BUFFER, $PENDING_TOKEN, 
   $LINE, $RECORD_LENGTH, $OFFSET, $POS,
   $EOI, $SKIP, $HOLD, $HOLD_TEXT, 
   $NAME, $IN_PKG,
   $TEMPLATE, 
   $STRING_SUB, $STREAM_SUB, $HANDLES,
   $STRING_CODE, $STREAM_CODE, $CODE,
   $STATE_MACHINE_CODE, 
   $STATES, $STACK_STATES,
   $EXCLUSIVE_COND, $INCLUSIVE_COND,
   $TRACE, $INIT, 
   $TOKEN_LIST
  ) = map {
    $_map{$_} = ++$index;
  } qw(STREAM FROM_STRING SUB BUFFER PENDING_TOKEN 
       LINE RECORD_LENGTH OFFSET POS
       EOI SKIP HOLD HOLD_TEXT 
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

my $somevar = '';		# use gensym instead???
				# Create and instanciate a prototypical instance
my $lexer = __PACKAGE__->clone;	
sub prototype { $lexer or [] }

my $TOKEN_CLASS = 'Parse::Token'; # Root class
sub tokenClass { 
  if (defined $_[1]) {
    no strict qw/refs/;
    ${"$TOKEN_CLASS" . "::PENDING_TOKEN"} = $PENDING_TOKEN; 
    $TOKEN_CLASS = $_[1];
  } else {
    $_[1] 
  }
}
my $DEFAULT_TOKEN = $TOKEN_CLASS->new('DEFAULT', '.*'); # default token
$lexer->tokenClass($TOKEN_CLASS);

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
$lexer->[$TEMPLATE] = new Parse::Template; # code template

				# Lexer code: [HEADER, BODY, FOOTER]
$lexer->[$STREAM_CODE] = [];	# cached subroutine definition
$lexer->[$STRING_CODE] = [];	# cached subroutine definition
$lexer->[$CODE] = [];		# current lexer
$lexer->[$HANDLES] = [];	# lexer closure environnement
$lexer->[$SUB] = my $DEFAULT_SUB = sub {
  $_[0]->genLex;		# lexer autogeneration
  &{$_[0]->[$SUB]};		# lexer execution
};
$lexer->[$STREAM_SUB] = sub {};	# cache for the stream lexer
$lexer->[$STRING_SUB] = sub {};	# cache for the string lexer
				# State machine
$lexer->[$EXCLUSIVE_COND] = {};	# exclusive conditions
$lexer->[$INCLUSIVE_COND] = {};	# inclusive conditions
$lexer->[$STATE_MACHINE_CODE] = ''; # definition of the state machine
$lexer->[$STATES] = { 'INITIAL' => \$somevar };	# state machine, define a class will be better
$lexer->[$STACK_STATES] = [];	# stack of states, not used
$lexer->[$TRACE] = $trace;
$lexer->[$INIT] = 1;		# true at object creation (useful???)
$lexer->[$TOKEN_LIST] = [];	# Tokens

				# 
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

				# 
				# next() wrappers
				# 
# Purpose: Analyze data in one call
# Arguments: string or stream to analyze
# Returns: self
# Todo: generate a specific lexer sub
sub parse {
  my $self = shift;
  unless (defined $_[0]) {
    require Carp;
    Carp::carp "no data to analyze";
  }
  $self->from($_[0]);
  my $next = $self->[$SUB];
  &{$next}($self) until $self->[$EOI]; 
  $self;
}
# Purpose: Analyze data in one call
# Arguments: string or stream to analyze
# Returns: a list of token name and text
# Todo: generate a specific lexer sub
sub analyze {			
  my $self = shift;
  unless (defined $_[0]) {
    require Carp;
    Carp::carp "no data to analyze";
  }
  $self->from($_[0]);
  my $next = $self->[$SUB];
  my $token = &{$next}($self);
  my @token = ($token->name, $token->text);
  while (not $self->[$EOI]) {
    $token = &{$next}($self);
    push (@token, $token->name, $token->text);
  }
  @token;
}
# Remark: not documented
# Purpose: put the next token in a scalar reference
# Arguments: a scalar reference
# Returns: 1 if token isn't equal to the EOI token
sub nextis {			
  my $self = shift;
  unless (@_ == 1) {
    require Carp;
    Carp::croak "bad argument number";
  }
  if (ref $_[0]) {
    my $token = &{$self->[$SUB]}($self);
    ${$_[0]} = $token;
    $token == $Parse::Token::EOI ? return 0 : return 1;
  } else {
    require Carp;
    Carp::croak "bad argument $_[0]";
  }
}
# Purpose: execute some action on each token
# Arguments: an anonymous sub to call on each token
# Returns: undef
sub every {			
  my $self = shift;
  my $do_on = shift;
  my $ref = ref($do_on);
  if (not $ref or $ref ne 'CODE') { 
    require Carp;
    Carp::croak "argument of the 'every' method must be an anonymous routine";
  }
  my $token = &{$self->[$SUB]}($self);
  $DB::single = 1;
  while (not $self->[$EOI]) {
    &{$do_on}($token);
    $token = &{$self->[$SUB]}($self);
  }
  undef;
}

####
# Purpose: define the data input
# Parameters: possibilities
# 1. filehandle (\*FH, *FH or IO::File instance)
# 2. list of strings
# 3. <none> 
# Returns:  1. returns the lexer
#           2. returns the lexer
#           3. returns the lexer's filehandle if defined
#              or undef if not 
sub from {
  my $self = shift;
  my $debug = 0;
				# From STREAM
  local *X = $_[0];		
  print STDERR "arg: $_[0] ", fileno(X) , "\n" if $debug;
  if (defined(fileno(X))) {		
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
    } else {			# code doesn't exist
      print STDERR "STREAM code generation\n" if $debug;
      # genCode()
      $self->[$FROM_STRING] = 0;
      $self->genHeader();
      $self->genBody($self->tokenList); 
      $self->genFooter();
      $self->_saveHandles();
      $self->genLex();
				# $self->getCode()
      $self->[$STREAM_CODE] = [@{$self->[$CODE]}]; # cache
      $self->[$STREAM_SUB] = $self->[$SUB];
    }

    $self->reset;
    $self;
  } elsif (defined $_[0]) {	# From STRING
    print STDERR "From string\n" if $debug;
    if (@{$self->[$STRING_CODE]}) { # code already exists
      unless ($self->[$FROM_STRING]) {
	print STDERR "code already exists\n" if $debug;
	$self->[$CODE] = [@{$self->[$STRING_CODE]}];
	$self->[$SUB] = $self->[$STRING_SUB];
	$self->_switchHandles();
	$self->[$FROM_STRING] = 1;
      }
    } else {
      print STDERR "STRING code generation\n" if $debug;
      $self->[$FROM_STRING] = 1;

      # genCode()
      $self->genHeader();
      $self->genBody($self->tokenList); 
      $self->genFooter();
      #
      $self->_saveHandles();
      $self->genLex();
				# $self->getCode()
      $self->[$STRING_CODE] = [@{$self->[$CODE]}]; # cache
      $self->[$STRING_SUB] = $self->[$SUB];
    }
    $self->reset;
    my $buffer = join($", @_); # Data from a list
    ${$self->[$BUFFER]} = $buffer;
    ${$self->[$RECORD_LENGTH]} = CORE::length($buffer);
    $self;
  } elsif ($self->[$STREAM]) {
    $self->[$STREAM];
  } else {
    undef;
  }
}
# Not documented
# Purpose: set/get environnement of the lexer closure
# Arguments: see definition
# Returns: references to some internal object fields
# todo: test type and number of arguments
# name closureEnv ???
sub handles {
  my $self = shift;
  if (@_) {
    ($self->[$BUFFER], 
     $self->[$RECORD_LENGTH],
     $self->[$LINE], 
     $self->[$POS], 
     $self->[$OFFSET],
     $self->[$STATES],
    ) = @_;
  } else {
    ($self->[$BUFFER], 
     $self->[$RECORD_LENGTH],
     $self->[$LINE], 
     $self->[$POS], 
     $self->[$OFFSET],
     $self->[$STATES],
    )
  }
}
sub _saveHandles {
  my $self = shift;
  @{$self->[$HANDLES]} = $self->handles();
}
#($self->[$BUFFER], $self->[$RECORD_LENGTH], $self->[$LINE], $self->[$POS], 
#$self->[$OFFSET], $self->[$STATES]) = @{$self->[$HANDLES]};
sub _switchHandles {
  my $self = shift;
  my @tmp = $self->handles();
  $self->handles(@{$self->[$HANDLES]});
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

# could be improved
# Purpose: Toggle the trace mode
# todo: regenerate the lexer if needed
sub trace { 
  my $self = shift;
  my $class = ref($self);
  if ($class) {			# Object method
    if ($self->[$TRACE]) {
      $self->[$TRACE] = 0;
      print STDERR qq!trace OFF for a "$class" object\n!;
    } else {
      $self->[$TRACE] = 1;
      print STDERR qq!trace ON for a "$class" object\n!;
    }
  } else {			# Class method
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

      # delete the code already generated
      @{$lexer->[$STREAM_CODE]} = ();
      @{$lexer->[$STRING_CODE]} = ();
      @{$lexer->[$CODE]} = ();		
      $lexer->[$SUB] = $DEFAULT_SUB;

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

      # delete the code already generated
      @{$self->[$STREAM_CODE]} = ();
      @{$self->[$STRING_CODE]} = ();
      @{$self->[$CODE]} = ();		
      $self->[$SUB] = $DEFAULT_SUB;

    } else {
      $self->[$SKIP];
    }
  } else {			# Used as a Class method
    print STDERR "skip value: '$_[0]'\n" if $debug;

    defined $_[0] ?
      $self->prototype()->[$SKIP] = $_[0] : $self->prototype()->[$SKIP];
  }
}
# not documented
# Purpose: returns a 
# - a copy of the prototypical lexer if used as a class method
# - a copy of the message receiver if used as an instance method
# naive implementation
sub clone {
  my $receiver = shift;
  my $class;
  if ($class = ref $receiver) {		# Instance method: clone the current instance
    bless [@{$receiver}], $class; 
  } else {			# Class method: clone the Prototype
    bless [@{$receiver->prototype}], $receiver; 
  }
}
# Purpose: create the lexical analyzer
# Arguments: list of tokens or token specifications
# Returns: a lex object
sub new {
  my $receiver = shift;
  my $class = (ref $receiver or $receiver);

  if ($class eq __PACKAGE__) {
    require Carp;
    Carp::croak "can't create an instance of '$class' abstract class"
  }

  my $self = $receiver->clone;
  $self->reset;
  $self->[$INIT] = 1;
  $self->[$IN_PKG] = (caller(0))[0]; # From which package?

  if (@_) {
    my @token = $TOKEN_CLASS->factory(@_);
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

# not documented, used in Parse::Token::
sub lexerType {
  my $self = shift;
  if ($self->isa('Parse::Lex')) {
    return 'Parse::Lex';
  } elsif ($self->isa('Parse::CLex')) {
    return 'Parse::CLex';
  } else {
    return ref $self || $self;
  }
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
my $TRACE_GEN = 0;
sub genCode {
  my $self = shift;
  print STDERR "genCode()\n" if $TRACE_GEN;
  $self->genHeader();
  $self->genBody($self->tokenList); 
  $self->genFooter();
}
# Remark: not documented
sub genHeader {
  my $self = shift;
  my $template = $self->template;
  print STDERR "genHeader()\n" if $TRACE_GEN;
				# build the template env
  $template->env(
		 'SKIP' => $self->[$SKIP],
		 'IS_HOLD' => $self->[$HOLD],
		 'HOLD_TEXT' => $HOLD_TEXT,
		 'EOI' => $EOI,
		 'TRACE' => $TRACE,
		 'IS_TRACE' => $self->[$TRACE],
		 'PENDING_TOKEN' => $PENDING_TOKEN,
		); 

  if ($self->[$FROM_STRING]) {
    $self->[$CODE]->[0] = $self->template->eval('HEADER_STRING_PART');
  } else {
    $self->[$CODE]->[0] = $self->template->eval('HEADER_STREAM_PART');
  }
}
# Purpose: create the lexical analyzer
# Arguments: list of tokens
# Returns: a Lex object
# Remark: not documented
sub genBody {
  my $self = shift;
  print STDERR "genBody()\n"  if $TRACE_GEN;
				# 
  if ($self->[$INIT]) {		# object creation
    $self->[$INIT] = 0;		# useless
  }

  my $token;
  my $body = '';
  my $debug = 0;
  while (@_) {			# list of Token instances
    $body .= shift->genCode();
  }
  $self->[$CODE]->[1] = $body;
}
# Remark: not documented
sub genFooter {
  my $self = shift;
  print STDERR "genFooter()\n" if $TRACE_GEN;
  $self->[$CODE]->[2] = $self->template->eval('FOOTER_PART');
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
# A Returns: the anonymous subroutine implementing the lexical analyzer
# Remark: not documented
sub genLex {
  my $self = shift;
  $self->genCode unless @{$self->[$CODE]};	
  print STDERR "Lexer generation...\n"  if $TRACE_GEN;

				# Closure environnement
  my $LEX_BUFFER = '';		# buffer to analyze
  my $LEX_LENGTH = 0;		# buffer length
  my $LEX_RECORD = 0;		# current record number
  my $LEX_POS = 0;		# current position in buffer
  my $LEX_OFFSET = 0;		# offset from the beginning
  my $LEX_TOKEN = '';		# token instance
  my %state = ();		# states

  $self->handles(\(
		 $LEX_BUFFER,	
		 $LEX_LENGTH,	
		 $LEX_RECORD,		
		 $LEX_POS,	
		 $LEX_OFFSET,
		 %state,
		));		

  my $LEX_FHR = \$self->[$STREAM];
  my $stateMachine = $self->genStateMachine();
  my $analyzer = $self->getCode();
  eval qq!$stateMachine; \$self->[$SUB] = sub $analyzer!;

  my $debug = 0;
  if ($@ or $debug) {	# can be useful ;-)
    my $line = 0;
    $stateMachine =~ s/^/sprintf("%3d ", $line++)/meg; # line numbers
    $analyzer =~ s/^/sprintf("%3d ", $line++)/meg;
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
#package Parse::State;
# todo: create a Parse::State  class
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
use constant GEN_CONDITION => 0;
sub genCondition {
  my $self = shift;
  my $specif = shift;
  return '' if $specif =~ /^ALL:/; # special condition

  my %exclusion = %{$self->exclusive};
  my %inclusion = %{$self->inclusive};
  return '' unless $specif or keys %exclusion;

  my $condition;
  my @condition;
  my $cond_group;
  my $cond_item;
  my @cond_group;
  if ($specif =~ /^(.+):/g) {	# Ex. A:B:C: or A,C: 
    my ($prefix) = ($1);
    foreach $cond_group (split /:/, $prefix) {
      foreach $cond_item (@cond_group = split /,/, $cond_group) {
	unless ($cond_item eq 'INITIAL' or 
		defined $exclusion{$cond_item} or 
		defined $inclusion{$cond_item}) {
	  require Carp;
	  Carp::croak "'$cond_item' condition not defined";
	}
	delete $exclusion{$cond_item};
	delete $inclusion{$cond_item};
      }
      push @condition, "(" . join(" or ", map { "\$$_" } @cond_group) . ")";
    }
    if (@condition == 1) {
      $condition = shift @condition;
    } else {
      $condition = "(" . join(" and ", @condition) . ")";
    }
  }
  my @tmp = ();
  if (@tmp = map { "\$$_" } keys(%exclusion)) {
    if ($condition) {
      $condition = "not (" . join(" or ", @tmp) . ") and $condition";
    } else {
      $condition = "not (" . join(" or ", @tmp) . ")";
    }
  } 
  print STDERR "genCondition(): $specif -> $condition\n" if GEN_CONDITION;
  $condition ne '' ? "$condition and" : '';
}
sub genStateMachine { 
  my $self = shift;
  my $somevar;

  my $stateDeclaration = 'my $INITIAL = 1;' .
    "\n" .
      q!$state{'INITIAL'} = \\$INITIAL;! . "\n";
  my $stateName = '';
  foreach $stateName (keys (%{$self->exclusive}), keys(%{$self->inclusive})) {
    $stateDeclaration .=
      q!my $! . "$stateName" . q! = 0; ! . 
	q!$state{'! . "$stateName" . q!'} = \\$! . "$stateName" . q!;!  . "\n";
  }
  $self->setStateMachine($stateDeclaration);
}
# not documented
sub setStateMachine {
  my $self = shift;
  $self->[$STATE_MACHINE_CODE] = shift;
}
# not documented
sub getStateMachine {
  my $self = shift;
  $self->[$STATE_MACHINE_CODE];
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
sub state {			# get/set state
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

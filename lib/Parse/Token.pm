# Copyright (c)  Philippe Verdret, 1995-1998

require 5.000;
use strict qw(vars);
use strict qw(refs);
use strict qw(subs);

package Parse::Token;
use Parse::Trace;
@Parse::Token::ISA = qw(Parse::Trace);

use Carp;
use vars qw($AUTOLOAD);

use vars qw($trace $PENDING_TOKEN $EOI);
$trace = 0;
my(
   $STATUS, $TEXT, $NAME, $CONDITION, 
   $REGEXP, $SUB, $DECORATION, $LEXER, 
   $TRACE, $IN_PKG
   ) = (0..9);
$EOI = Parse::Token->new('EOI');

#  new()
# Purpose: token constructor
# Arguments: see definition
# Returns: Return a token object
sub new {
  my $receiver = shift;
  my $class = (ref $receiver or $receiver);
  my $self = bless [], $class;

  $self->[$STATUS] = 0;		# object status
  $self->[$TEXT] = '';		# recognized text

  ($self->[$CONDITION], 	# associated conditions		
   $self->[$NAME]		# symbolic name
  ) = $self->_parseName($_[0]);

  $self->[$REGEXP] = $_[1];	# regexp, can be an array reference
  $self->[$SUB] = $_[2];	# associated sub
  $self->[$LEXER] = $_[3];	# lexer object
  $self->[$IN_PKG] = '';	# defined in which package
  $self->[$DECORATION] = {};	# token decoration
  $self->[$TRACE] = $trace;	# trace
  $self;
}
# Purpose: export a token objet to the caller package or 
#          in the package returns by inpkg()
# Arguments: 
# Returns: the token object 
# Remarks: what to do if called as a class method?
sub exportTo {
  my $self = shift;
  my $inpkg = $self->inpkg;
  if (not defined $inpkg) {
    $inpkg = (caller(0))[0];
    $self->inpkg($inpkg);
  }
  my $name = $self->name;
  no strict 'refs';	
  if ($^W and defined ${"$inpkg" . "::" . "$name"}) {
    warn "the '${inpkg}::$name' token is already defined";
  }
  ${"$inpkg" . "::" . "$name"} = $self;
  $self;
}

sub isToken { 1 }
# Purpose: create a list of token objects
# Arguments: a list of token specification or token objects
sub factory { 
  my $self = shift;

  if (not defined($_[0])) {
    croak "arguments must be a list of token specifications";
  }

  my $sub;
  my $ref;
  my @token;
  my $token;
  my $nextArg;
  while (@_) {
    $nextArg = shift;
    if (ref $nextArg and $nextArg->can('isToken')) {	# it's already a token object...
      push @token, $nextArg;
    } else {			# parse the specification
      my($name, $regexp) = ($nextArg, shift);
      if (@_) {
	$ref = ref($_[0]);
	if ($ref and $ref eq 'CODE') { # if next arg is a sub reference
	  $sub = shift;
	} else {
	  $sub = undef;
	}
      } else {
	$sub = '';
      }
      push @token, $self->new($name, $regexp, $sub);
    }
  }
  @token;
}
sub _parseName {
  my $self = shift;
  my $name = shift;
  my $condition = '';
  if ($name =~ /^(.+:)(.+)/) { # Ex. A:B:C:SYMBOL, A,C:SYMBOL
    ($condition, $name) = ($1, $2);
  }
  ($condition, $name);
}
sub condition {
  my $self = shift;
  if (@_) {
    $self->[$CONDITION] = shift;
  } else {
    $self->[$CONDITION];
  }
}
sub AUTOLOAD {		    
  my $self = shift;
  return unless ref($self);
  my $name = $AUTOLOAD;
  $name =~ s/.*://;
  my $value = shift;
  if (defined $value) { 
    ${$self->[$DECORATION]}{$name} = $value;
  } else {
    ${$self->[$DECORATION]}{$name};
  }
}
# set(ATTRIBUTE, VALUE)
# Purpose: set an attribute value
sub set {  ${$_[0]->[$DECORATION]}{$_[1]} = $_[2];}
# get(ATT)
# Purpose: return an attribute value
sub get {  ${$_[0]->[$DECORATION]}{$_[1]};}

sub inpkg {			# not documented
  my $self = shift;
  if (defined $_[0]) {
    $self->[$IN_PKG] = $_[0] 
  } else {
    $self->[$IN_PKG];
  }
}
# status()
# Purpose: Indicate is the last token search has succeeded or not
# Arguments:
# Returns:
sub status { 
  defined($_[1]) ? 
    $_[0]->[$STATUS] = $_[1] : 
      $_[0]->[$STATUS];
} 
# setText()
# Purpose: Return the symbolic name of the object
# Arguments:
# Returns: see purpose
# Extension: save $1, $2... in a list
sub setText    { $_[0]->[$TEXT] = $_[1] } # set token string

# getText()
# Purpose:
# Arguments:
# Returns:
sub getText    { $_[0]->[$TEXT] }	# get token string 

sub text { 
  defined($_[1]) ? 
    $_[0]->[$TEXT] = $_[1] : 
      $_[0]->[$TEXT];
} 

#  name()
# Purpose:
# Arguments:
# Returns:
sub name { $_[0]->[$NAME] }	# name of the token
*type = \&name;			# synonym of the name method

#  
# Purpose:
# Arguments:
# Returns:
sub regexp { $_[0]->[$REGEXP] }	# regexp

# action()
# Purpose:
# Arguments:
# Returns:
sub action   { $_[0]->[$SUB] }	# anonymous function

# lexer(EXP)
# lexer
# Purpose: Defines or returns the associated lexer
# Arguments:
# Returns:
sub lexer {		
  if (defined $_[1]) {
    $_[0]->[$LEXER] = $_[1];
  } else {
    $_[0]->[$LEXER];
  }
}	
sub do { 
  my $self = shift;
  &{(shift)}($self, @_)
}

# next()
# Purpose: Return the string token if token is the pending one
# Arguments: no argument
# Returns: a token string if token is found, else undef
# Remark: $PENDING_TOKEN  is set by the Parse::ALex class
sub next {			# return the token string 
  my $self = shift;
  my $lexer = $self->[$LEXER];
  my $pendingToken = $lexer->[$PENDING_TOKEN];
  if ($pendingToken == $EOI) {
    $self->[$STATUS] = $self == $EOI ? 1 : 0;
    return undef;		
  }
  $lexer->next() unless $pendingToken;
  if ($self == $lexer->[$PENDING_TOKEN]) {
    $lexer->[$PENDING_TOKEN] = 0; # now no pending token
    my $text = $self->[$TEXT];
    $self->[$TEXT] = '';
    $self->[$STATUS] = 1;
    $text;			# return token string
  } else {
    $self->[$STATUS] = 0;
    undef;
  }
}
# isnext()
# Purpose: Return the status of the token object, and the recognized string
# Arguments: scalar reference
# Returns: 
#  1. the object status
#  2. the recognized string is put in the scalar reference
sub isnext {
  my $self = shift;
  my $lexer = $self->[$LEXER];
  my $pendingToken = $lexer->[$PENDING_TOKEN];
  if ($pendingToken == $EOI) {
    ${$_[0]} = undef;
    return $self->[$STATUS] = $self == $EOI ? 1 : 0;
  }
  $lexer->next() unless $pendingToken;
  if ($self == $lexer->[$PENDING_TOKEN]) {
    $lexer->[$PENDING_TOKEN] = 0; # now no pending token
    ${$_[0]} = $self->[$TEXT];
    $self->[$TEXT] = '';
    $self->[$STATUS] = 1;
    1;
  } else {
    $self->[$STATUS] = 0;
    ${$_[0]} = undef;
    0;
  }
}
1;
__END__


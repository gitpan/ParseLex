# Copyright (c)  Philippe Verdret, 1995-1997

require 5.000;
use strict qw(vars);
use strict qw(refs);
use strict qw(subs);

package Parse::Token;
use Parse::Trace;
@Parse::Token::ISA = qw(Parse::Trace);

use Carp;
use vars qw($AUTOLOAD);

if ((caller(0))[0] ne 'Parse::Lex') {
  carp "The Parse::Token class must be called only via the Parse::Lex class";
}

use vars qw($trace);
$trace = 0;
my(
   $STATUS, $STRING, $NAME, $REGEXP, $SUB,
   $ATTRIBUTES, $READER, $TRACE 
   ) = (0..7);
$Token::EOI = Parse::Token->new('EOI');

#  new()
# Purpose: token constructor
# Arguments: see definition
# Returns: Return a token object
sub new {
  my $receiver = shift;
  my $class = (ref $receiver or $receiver);
  my $self = bless [], $class;
  $self->[$STATUS] = 0;		# object status
  $self->[$STRING] = '';	# recognized string 
  $self->[$NAME] = $_[0];	# symbolic name
  $self->[$REGEXP] = $_[1];	# regexp
  $self->[$SUB] = $_[2];	# associated sub
  $self->[$READER] = $_[3];	# reader object
  $self->[$ATTRIBUTES] = {};	# token decoration
  $self->[$TRACE] = $trace;	# trace
  $self;
}

sub AUTOLOAD {			# Thanks Tom
  my $self = shift;
  return unless ref($self);
  my $name = $AUTOLOAD;
  $name =~ s/.*://;
  my $value = shift;
  if (defined $value) { 
    ${$self->[$ATTRIBUTES]}{$name} = $value;
  } else {
    ${$self->[$ATTRIBUTES]}{$name};
  }
}
# set(ATTRIBUTE, VALUE)
# Purpose: set an attribute value
sub set {  ${$_[0]->[$ATTRIBUTES]}{$_[1]} = $_[2];}
# get(ATT)
# Purpose: return an attribute value
sub get {  ${$_[0]->[$ATTRIBUTES]}{$_[1]};}

# status()
# Purpose: Indicate is the last token search has succeeded or not
# Arguments:
# Returns:
sub status { 
  defined($_[1]) ? 
    $_[0]->[$STATUS] = $_[1] : 
      $_[0]->[$STATUS];
} 
# setstring()
# Purpose: Return the symbolic name of the object
# Arguments:
# Returns: see purpose
# Extension: save $1, $2... in a list
sub setstring    { $_[0]->[$STRING] = $_[1] } # set token string

# getstring()
# Purpose:
# Arguments:
# Returns:
sub getstring    { $_[0]->[$STRING] }	# get token string 

sub text { 
  defined($_[1]) ? 
    $_[0]->[$STRING] = $_[1] : 
      $_[0]->[$STRING];
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

#  mean()
# Purpose:
# Arguments:
# Returns:
sub mean   { $_[0]->[$SUB] }	# anonymous fonction

# reader(EXP)
# reader
# Purpose: Defines or returns the associated lexer
# Arguments:
# Returns:
sub reader {		
  if (defined $_[1]) {
    if (ref($_[1]) eq 'Parse::Lex') {
      $_[0]->[$READER] = $_[1];
    } else {
      my $mesg = "$_[1] must be a Parse::Lex object";
      croak $mesg;
    }
  } else {
    $_[0]->[$READER];
  }
}	
sub do     { &{$_[1]}($_[0]) }	# why not? 

# next()
# Purpose: Return the string token if token is the pending one
# Arguments: no argument

# Returns: a token string if token is found, else undef
sub next {			# return the token string 
  my $self = shift;
  my $reader = $self->[$READER];
  my $pendingToken = $reader->[$Lex::PEND_TOKEN];
  if ($pendingToken == $Token::EOI) {
    $self->[$STATUS] = $self == $Token::EOI ? 1 : 0;
    return undef;		
  }
  $reader->next() unless $pendingToken;
  if ($self == $reader->[$Lex::PEND_TOKEN]) {
    $reader->[$Lex::PEND_TOKEN] = 0; # now no pending token
    my $string = $self->[$STRING];
    $self->[$STRING] = '';
    $self->[$STATUS] = 1;
    $string;			# return token string
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
  my $reader = $self->[$READER];
  my $pendingToken = $reader->[$Lex::PEND_TOKEN];
  if ($pendingToken == $Token::EOI) {
    ${$_[0]} = undef;
    return $self->[$STATUS] = $self == $Token::EOI ? 1 : 0;
  }
  $reader->next() unless $pendingToken;
  if ($self == $reader->[$Lex::PEND_TOKEN]) {
    $reader->[$Lex::PEND_TOKEN] = 0; # now no pending token
    ${$_[0]} = $self->[$STRING];
    $self->[$STRING] = '';
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


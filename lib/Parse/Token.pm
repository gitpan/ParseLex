# Copyright (c)  Philippe Verdret, 1995-1999

require 5.004;
use strict qw(vars);
use strict qw(refs);
use strict qw(subs);

package Parse::Token;		# or perhaps: Parse::AToken
use Parse::Trace;
@Parse::Token::ISA = qw(Parse::Trace);

use vars qw($AUTOLOAD $trace $PENDING_TOKEN $EOI);
$trace = 0;

# other possibilities: dynamic variables, pseudo-hash, constants (see The Perl Journal Spring 99)
my %_map;
my @attributes = qw(STATUS TEXT NAME CONDITION 
		    REGEXP SUB DECORATION LEXER EXPRESSION
		    TEMPLATE TRACE IN_PKG);
my($STATUS, $TEXT, $NAME, $CONDITION, 
   $REGEXP, $ACTION, $DECORATION, $LEXER, $EXPRESSION,
   $TEMPLATE, $TRACE, $IN_PKG) = @_map{@attributes} = (0..$#attributes);
sub _map { 
  shift;
  if (@_) {
    wantarray ? @_map{@_} : $_map{$_[0]}
  } else {
    @attributes;
  }
}

$EOI = Parse::Token->new('EOI');

#  new()
# Purpose: token constructor
# Arguments: see definition
# Returns: Return a token object
sub new {
  my $receiver = shift;
  my $class = (ref $receiver or $receiver);
  my $self = bless [], $class;

				# initialize...
  $self->[$STATUS] = 0;		# object status
  $self->[$TEXT] = '';		# recognized text

  (
   $self->[$CONDITION], 	# associated conditions		
   $self->[$NAME]		# symbolic name
  ) = $self->_parseName($_[0]);

  $self->[$REGEXP] = $_[1];	# regexp, can be an array reference
  $self->[$ACTION] = $_[2];	# associated sub
  $self->[$LEXER] = $_[3];	# lexer instance
  $self->[$EXPRESSION] = $_[4];	# for an action token
  $self->[$IN_PKG] = '';	# defined in this package
  $self->[$DECORATION] = {};	# token decoration
  $self->[$TEMPLATE] = {};	# associated template
  $self->[$TRACE] = $trace;	# trace
  $self;
}
# Purpose: export a token objet to the caller package or 
#          in the package returned by inpkg()
# Arguments: 
# Returns: the token object 
sub exportTo {
  my $self = shift;
  my $inpkg = $self->inpkg;
  unless (defined $inpkg) {
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

#sub isToken { 1 }		# use isa() instead

# Purpose: create a list of token objects
# Arguments: a list of token specification or token objects
sub factory { 
  my $self = shift;

  unless (defined($_[0])) {
    require Carp;
    Carp::croak "arguments of the factory() method must be a list of token specifications";
  }

  my $sub;
  my $ref;
  my @token;
  my $token;
  my $next_arg;
  my $token_class = 'Parse::Token::Simple';
  while (@_) {
    $next_arg = shift;
				# it's already an instance
    if (ref $next_arg and $next_arg->isa(__PACKAGE__)) { # isa()
      push @token, $next_arg;
    } else {			# parse the specification
      my($name, $regexp) = ($next_arg, shift);
      if (@_) {
	$ref = ref($_[0]);
	if ($ref and $ref eq 'CODE') { # if next arg is a sub reference
	  $sub = shift;
	} else {
	  $sub = undef;
	}
      } else {
	$sub = undef;
      }
      unless (ref($regexp) eq 'ARRAY') {
	$token_class = 'Parse::Token::Simple';
      } else {
	$token_class = 'Parse::Token::Multiline';
      }
      push @token, $token_class->new($name, $regexp, $sub);
    }
  }
  #print STDERR "@token\n";
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
  $self->[$TEMPLATE];
}
sub setTemplate {
  my $self = shift;
  $self->[$TEMPLATE] = shift;
}
sub condition {
  my $self = shift;
  if (@_) {
    $self->[$CONDITION] = shift;
  } else {
    $self->[$CONDITION];
  }
}
sub expression {
  my $self = shift;
  if (@_) {
    $self->[$EXPRESSION] = shift;
  } else {
    $self->[$EXPRESSION];
  }
}
sub AUTOLOAD {		    
  my $self = shift;
  return unless ref($self);
  return if $AUTOLOAD =~ /\bDESTROY$/;
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
*type = \&name;			# synonym of the name() method

#  
# Purpose:
# Arguments:
# Returns:
sub regexp { $_[0]->[$REGEXP] }	# regexp

# action()
# Purpose:
# Arguments:
# Returns:
sub action   { $_[0]->[$ACTION] } # anonymous function

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
# not documented
sub do { 
  my $self = shift;
  &{(shift)}($self, @_)
}

# next()
# Purpose: Return the string token if token is the pending token
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

package Parse::Token::Action;	# experimental feature - not documented
use Parse::Template;
@Parse::Token::Action::ISA = qw(Parse::Token Parse::Trace);

use vars qw(%TEMPLATE $template);
%TEMPLATE = 
(EXPRESSION_PART => q!
 %%$CONDITION%%
 %%$EXPRESSION%%
 !
);
$template = new Parse::Template(%TEMPLATE);
sub new {
  my $receiver = shift;
  my ($name, $expression) = $receiver->_parse(@_);
  my $token = $receiver->SUPER::new($name, '', '', '', $expression);
  $token->template($template);	
  $token;
}
sub _parse {
  my $self = shift;
  unless (@_ >= 2) {
    require  Carp;
    Carp::croak "bad argument number (@_)";
  }
  my ($key, $value);
  my ($name, $expression);
  my $escape = '';
  while (@_ >= 2) {
    ($key, $value) = (shift, shift);
    if ($key =~ /-?[Nn]ame/) {
      $name = $value;
    } elsif ($key =~ /^-?[Ee]xpr$/) {
      $expression = $value;
    } else {
      last;
    }
  }
  ($name, $expression);
}
sub genCode {
  my $self = shift;

  my $lexer = $self->lexer;
  my $tokenid = $lexer->inpkg() . '::' . $self->name();
  my $template = $self->template;
  my $condition = $lexer->genCondition($self->condition);
  my $expression = $self->expression;

  $template->env(
		 CONDITION => $condition,
		 EXPRESSION => $expression,
		); 
  my $code;
  eval {
    $code = $template->eval('EXPRESSION_PART');
  };
  if ($@) {
    require Carp;
    Carp::croak "$@";
  }
  $code;
}
package Parse::Token::Simple;
use Parse::Trace;
use Parse::Template;
@Parse::Token::Simple::ISA = qw(Parse::Token Parse::Trace);

use vars qw(%TEMPLATE $template);
%TEMPLATE = ();
				# for the Lex class
$TEMPLATE{'LEX_HEADER_PART'} = q!
   %%$CONDITION%%
   $LEX_BUFFER =~ /\G(?:%%$REGEXP%%)/cg and do {
     $textLength = pos($LEX_BUFFER) - $LEX_POS;
     $content = substr($LEX_BUFFER, $LEX_POS, $textLength); # $&
     $LEX_OFFSET += $textLength;
     $LEX_POS += $textLength;
     %%$WITH_TRACE ? LEX_TRACE_PART() : '' %%
     %%$WITH_SUB ? LEX_FOOTER_WITH_SUB_PART() : LEX_FOOTER_PART() %%
!;
$TEMPLATE{'LEX_TRACE_PART'} = q!
     if ($self->[%%$TRACE%%]) {
       my $tmp = '%%$REGEXP%%';
       my $trace = "Token read (" . $%%$TOKEN_ID%%->name . ", $tmp): $content"; 
       $self->context($trace);
     }
!;
$TEMPLATE{'LEX_FOOTER_WITH_SUB_PART'} = q!
    $%%$TOKEN_ID%%->setText($content);
    $self->[%%$PENDING_TOKEN%%] = $LEX_TOKEN = $%%$TOKEN_ID%%;
    $content = &{$%%$TOKEN_ID%%->action}($LEX_TOKEN, $content);
    $%%$TOKEN_ID%%->setText($content);
    $LEX_TOKEN = $self->[%%$PENDING_TOKEN%%]; # if tokenis in sub
    %%$WITH_TRACE ? LEX_FOOTER_WITH_SUB_TRACE_PART() : ''%%
    last CASE;
  };
!;
$TEMPLATE{'LEX_FOOTER_WITH_SUB_TRACE_PART'} = q!
    if ($self->[%%$PENDING_TOKEN%%] ne $LEX_TOKEN) {
     if ($self->[%%$TRACE%%]) { # Trace
	    $self->context("Token type has changed - " .
			   "Type: " . $LEX_TOKEN->name .
			   " - Content: $content\n");
	  }
	}
!;
$TEMPLATE{'LEX_FOOTER_PART'} = q!
    $%%$TOKEN_ID%%->setText($content);
    $LEX_TOKEN = $%%$TOKEN_ID%%;
    last CASE;
   };
!;
				# For the CLex class
$TEMPLATE{'CLEX_HEADER_PART'} = q!
   %%$CONDITION%%
   $LEX_BUFFER =~ s/^(?:%%$REGEXP%%)// and do {
     $content = $&;
     $textLength = CORE::length($content);
     $LEX_OFFSET += $textLength;
     $LEX_POS += $textLength;
     %%$WITH_TRACE ? CLEX_TRACE_PART() : '' %%
     %%$WITH_SUB ? CLEX_FOOTER_WITH_SUB_PART() : CLEX_FOOTER_PART() %%
!;
$TEMPLATE{'CLEX_TRACE_PART'} = q!
     if ($self->[%%$TRACE%%]) {
       my $tmp = '%%$REGEXP%%';
       my $trace = "Token read (" . $%%$TOKEN_ID%%->name . ", $tmp): $content"; 
       $self->context($trace);
     }
!;

$TEMPLATE{'CLEX_FOOTER_WITH_SUB_PART'} = q!
     $%%$TOKEN_ID%%->setText($content);
     $self->[%%$PENDING_TOKEN%%] = $LEX_TOKEN 
       = $%%$TOKEN_ID%%;
     $content = &{$%%$TOKEN_ID%%->action}($LEX_TOKEN, $content);
     ($LEX_TOKEN = $self->getToken)->setText($content);
     %%$WITH_TRACE ? CLEX_FOOTER_WITH_SUB_TRACE_PART() : ''%%
     last CASE;
  };
!;
$TEMPLATE{'CLEX_FOOTER_WITH_SUB_TRACE_PART'} = q!
        if ($self->[%%$PENDING_TOKEN%%] ne $LEX_TOKEN) {
	  if ($self->isTrace) {
	    $self->context("token type has changed - " .
			   "Type: " . $LEX_TOKEN->name .
			   " - Content: $content\n");
	  }
	}
!;
$TEMPLATE{'CLEX_FOOTER_PART'} = q!
     $%%$TOKEN_ID%%->setText($content);
     $LEX_TOKEN = $%%$TOKEN_ID%%;
     last CASE;
   };
!;
#########################################################################################################
$template = new Parse::Template(%TEMPLATE);
sub new {
  my $receiver = shift;
  my $token = $receiver->SUPER::new(@_);
  $token->template($template);	
  $token;
}

sub genCode {
  my $self = shift;

  my $lexer = $self->lexer;
  my $tokenid = $lexer->inpkg() . '::' . $self->name();
  my $template = $self->template;
  my $condition = $lexer->genCondition($self->condition);
  my $with_sub = defined $self->action ? 1 : 0;

  my($SKIP, $HOLD, $TRACE, $EOI, $HOLD_TEXT,  $PENDING_TOKEN) =
    $lexer->_map('SKIP', 'HOLD', 'TRACE', 'EOI', 'HOLD_TEXT', 'PENDING_TOKEN');

  $template->env(
		 #'template' => \$template,
		 'CONDITION' => $condition,
		 'TOKEN_ID'=> $tokenid,
		 'SKIP' => $lexer->[$SKIP],
		 'IS_HOLD' => $lexer->[$HOLD],
		 'WITH_TRACE' => $lexer->[$TRACE],
		 'WITH_SUB' => $with_sub,
		 'HOLD_TEXT' => $HOLD_TEXT,
		 'EOI' => $EOI,
		 'TRACE' => $TRACE,
		 'PENDING_TOKEN' => $PENDING_TOKEN,
		); 

  my $ppregexp = $template->ppregexp($self->regexp);
  my $debug = 0;
  if ($debug) {
    print STDERR "REGEXP[$tokenid]->\t\t$ppregexp\n";
  }
  $template->env('REGEXP', $ppregexp);
  my $code;
  my $lexer_type = $lexer->lexerType;
  $lexer_type =~ s/.+::(.+)$/\U$1_/g;
  eval {
    $code = $template->eval($lexer_type . 'HEADER_PART');
  };
  if ($@) {
    require Carp;
    Carp::croak "$@";
  }
  $code;
}

package Parse::Token::Multiline; # Parse::Token::Complex ???
use Parse::Trace;
@Parse::Token::Multiline::ISA = qw(Parse::Token Parse::Trace);

use vars qw(%TEMPLATE $template);
%TEMPLATE = ();
				# For the Lex class
$TEMPLATE{'LEX_HEADER_PART'} = q!
  %%$FROM_STRING ? LEX_HEADER_STRING_PART() : LEX_HEADER_STREAM_PART() %%
!;

$TEMPLATE{'LEX_HEADER_STRING_PART'} = q!
   %%$CONDITION%%
   $LEX_BUFFER =~ /\G(?:%%$REGEXP%%)/cg and do {
     $textLength = pos($LEX_BUFFER) - $LEX_POS; # length $&
     $content = substr($LEX_BUFFER, $LEX_POS, $textLength); # $&
     $LEX_OFFSET += $textLength;
     $LEX_POS += $textLength;
     %%$WITH_TRACE ? LEX_TOKEN_TRACE_PART() : '' %%
     %%$FROM_STRING ? LEX_TOKEN_STRING_PART() : LEX_TOKEN_STREAM_PART() %%
     %%$WITH_SUB ? LEX_FOOTER_WITH_SUB_PART() : LEX_FOOTER_PART() %%
!;
$TEMPLATE{'LEX_HEADER_STREAM_PART'} = q@
    %%$CONDITION%%
    $LEX_BUFFER =~ /\G(?:%%"$REGEXP_START"%%)/cg and do {
      my $before_pos = $LEX_POS;
      my $start_pos = pos($LEX_BUFFER);
      my $tmp = substr($LEX_BUFFER, $start_pos); 
      my $line_read = 0;
      # don't use \G 
      #print STDERR "before: $LEX_POS - initpos: $start_pos - tmp: $tmp\n";
      unless ($tmp =~ /^(?:%%"$REGEXP_MIDDLE$REGEXP_END"%%)/g) {
	my $line = '';
	do {
	  while (1) {
	    $line = <$LEX_FH>;
	    $line_read = 1;
	    unless (defined($line)) { # 
	      $self->[%%$EOI%%] = 1;
	      $LEX_TOKEN = $Parse::Token::EOI;
	      require Carp;
	      Carp::croak "unable to find end of token ", $%%$TOKEN_ID%%->name, "";
	    }
	    $LEX_RECORD++;
	    $tmp .= $line;
	    last if $line =~ /%%$REGEXP_END%%/;
	  }
	} until ($tmp =~ /^(?:%%"$REGEXP_MIDDLE$REGEXP_END"%%)/g); # don't forget /g
      }
      $LEX_POS = $start_pos + pos($tmp);
      $LEX_OFFSET += $LEX_POS;
      if ($line_read) {
	$LEX_BUFFER = substr($LEX_BUFFER, 0, $start_pos) . $tmp;
	$LEX_LENGTH = CORE::length($LEX_BUFFER); 
      } 
      $content = substr($LEX_BUFFER, $before_pos, $LEX_POS - $before_pos);
      pos($LEX_BUFFER) = $LEX_POS;
      #print STDERR "LEX_BUFFER: $LEX_BUFFER\n";
      #print STDERR "pos: $before_pos - length: ", $LEX_POS -$before_pos, " - content->$content<-\n";
      %%$WITH_TRACE ? LEX_TOKEN_TRACE_PART() : '' %%
      %%$WITH_SUB ? LEX_FOOTER_WITH_SUB_PART() : LEX_FOOTER_PART() %%
@;
$TEMPLATE{'LEX_TOKEN_TRACE_PART'} = q!
     if ($self->[%%$TRACE%%]) { # Trace
       my $tmp = '%%$REGEXP%%';
       my $trace = "Token read (" . $%%$TOKEN_ID%%->name . ", $tmp): $content"; 
        $self->context($trace);
     }
!;
$TEMPLATE{'LEX_FOOTER_WITH_SUB_PART'} = q!
    $%%$TOKEN_ID%%->setText($content);
    $self->[%%$PENDING_TOKEN%%] = $LEX_TOKEN = $%%$TOKEN_ID%%;
    $content = &{$%%$TOKEN_ID%%->action}($LEX_TOKEN, $content);
    $%%$TOKEN_ID%%->setText($content);
    $LEX_TOKEN = $self->[%%$PENDING_TOKEN%%]; # if tokenis in sub
     %%$WITH_TRACE ? LEX_FOOTER_WITH_SUB_TRACE_PART() : ''%%
    last CASE;
  };
!;
$TEMPLATE{'LEX_FOOTER_WITH_SUB_TRACE_PART'} = q!
    if ($self->[%%$PENDING_TOKEN%%] ne $LEX_TOKEN) {
     if ($self->[%%$TRACE%%]) { # Trace
	    $self->context("Token type has changed - " .
			   "Type: " . $LEX_TOKEN->name .
			   " - Content: $content\n");
	  }
	}
!;
$TEMPLATE{'LEX_FOOTER_PART'} = q!
    $%%$TOKEN_ID%%->setText($content);
    $LEX_TOKEN = $%%$TOKEN_ID%%;
    last CASE;
   };
!;

				# For the CLex class
$TEMPLATE{'CLEX_HEADER_PART'} = q!
  %%$FROM_STRING ? CLEX_HEADER_STRING_PART() : CLEX_HEADER_STREAM_PART() %%
!;
$TEMPLATE{'CLEX_HEADER_STRING_PART'} = q!
   %%$CONDITION%%
   $LEX_BUFFER =~ s/^(?:%%$REGEXP%%)// and do {
     $content = $&;
     $textLength = CORE::length($content);
     $LEX_OFFSET += $textLength;
     $LEX_POS += $textLength;
     %%$WITH_TRACE ? CLEX_TOKEN_TRACE_PART() : '' %%
     %%$FROM_STRING ? CLEX_TOKEN_STRING_PART() : CLEX_TOKEN_STREAM_PART() %%
     %%$WITH_SUB ? CLEX_FOOTER_WITH_SUB_PART() : CLEX_FOOTER_PART() %%
!;
$TEMPLATE{'CLEX_HEADER_STREAM_PART'} = q!
    %%$CONDITION%%
    $LEX_BUFFER =~ s/^(?:%%$REGEXP_START%%)// and do {
      my $string = $LEX_BUFFER;
      $content = $&;
      my $length = CORE::length($content) + CORE::length($LEX_BUFFER);
     do {
       until ($string =~ /%%$REGEXP_END%%/) {
	 $string = <$LEX_FH>;
	 unless (defined($string)) { # 
           $self->[%%$EOI%%] = 1;
           $LEX_TOKEN = $Parse::Token::EOI;
	   require Carp;
	   Carp::croak "unable to find end of token ", $%%$TOKEN_ID%%->name, "";
	 }
	 $length = CORE::length($string);
	 $LEX_RECORD++;
	 $LEX_BUFFER .= $string;
       }
       $string = '';
     } until ($LEX_BUFFER =~ s/^(?:%%"$REGEXP_MIDDLE$REGEXP_END"%%)//);
     $content .= $&;
     $textLength = CORE::length($content);
     $LEX_OFFSET += $textLength;
     $LEX_POS += $length - CORE::length($LEX_BUFFER);	
     %%$WITH_TRACE ? CLEX_TOKEN_TRACE_PART() : '' %%
     %%$WITH_SUB ? LEX_FOOTER_WITH_SUB_PART() : LEX_FOOTER_PART() %%
!;
$TEMPLATE{'CLEX_TOKEN_TRACE_PART'} = q!
     if ($self->[%%$TRACE%%]) { # Trace
       my $tmp = '%%$REGEXP%%';
       my $trace = "Token read (" . $%%$TOKEN_ID%%->name . ", $tmp): $content"; 
        $self->context($trace);
     }
!;
$TEMPLATE{'CLEX_FOOTER_WITH_SUB_PART'} = q!
     $%%$TOKEN_ID%%->setText($content);
     $self->[%%$PENDING_TOKEN%%] = $LEX_TOKEN 
       = $%%$TOKEN_ID%%;
     $content = &{$%%$TOKEN_ID%%->action}($LEX_TOKEN, $content);
     ($LEX_TOKEN = $self->getToken)->setText($content);
     %%$WITH_TRACE ? CLEX_FOOTER_WITH_SUB_TRACE_PART() : ''%%
     last CASE;
  };
!;
$TEMPLATE{'CLEX_FOOTER_WITH_SUB_TRACE_PART'} = q!
        if ($self->[%%$PENDING_TOKEN%%] ne $LEX_TOKEN) {
	  if ($self->isTrace) {
	    $self->context("token type has changed - " .
			   "Type: " . $LEX_TOKEN->name .
			   " - Content: $content\n");
	  }
	}
!;
$TEMPLATE{'CLEX_FOOTER_PART'} = q!
     $%%$TOKEN_ID%%->setText($content);
     $LEX_TOKEN = $%%$TOKEN_ID%%;
     last CASE;
   };
!;

#########################################################################################################
$template = new Parse::Template(%TEMPLATE);
sub new {
  my $receiver = shift;
  my $token = $receiver->SUPER::new(@_);
  $token->template($template);	
  $token;
}

sub genCode {
  my $self = shift;

  my $lexer = $self->lexer;
  my $tokenid = $lexer->inpkg() . '::' . $self->name();
  my $template = $self->template;
  my $condition = $lexer->genCondition($self->condition);
  
  my($FROM_STRING, $SKIP, $HOLD, $TRACE, $EOI, $HOLD_TEXT,  $PENDING_TOKEN) =
    $lexer->_map('FROM_STRING', 'SKIP', 'HOLD', 'TRACE', 'EOI', 'HOLD_TEXT', 'PENDING_TOKEN');

  my $with_sub = defined $self->action ? 1 : 0;
  $template->env(
		 #'template' => \$template,
		 'CONDITION', $condition,
		 'TOKEN_ID', $tokenid,
		 'SKIP' => $lexer->[$SKIP],
		 'FROM_STRING' => $lexer->[$FROM_STRING],
		 'IS_HOLD' => $lexer->[$HOLD],
		 'WITH_TRACE' => $lexer->[$TRACE],
		 'WITH_SUB' => $with_sub,
		 'HOLD_TEXT' => $HOLD_TEXT,
		 'EOI' => $EOI,
		 'TRACE' => $TRACE,
		 'PENDING_TOKEN' => $PENDING_TOKEN,
		); 

  my $ppregexp;
  my $tmpregexp;
  my $regexp = $self->regexp;
  if ($#{$regexp} >= 3) {
    require Carp;
    Carp::carp join  " " , "Warning!", $#{$regexp} + 1, 
    "arguments in token definition";
  }
  $ppregexp = $tmpregexp = $template->ppregexp(${$regexp}[0]);
  $template->env('REGEXP_START', $ppregexp);

  $ppregexp = ${$regexp}[1] ? $template->ppregexp(${$regexp}[1]) : '(?:.*?)';
  $tmpregexp .= $ppregexp;
  $template->env('REGEXP_MIDDLE', $ppregexp);

  $ppregexp = $template->ppregexp(${$regexp}[2] or ${$regexp}[0]);
  $template->env('REGEXP_END', $ppregexp);
  $ppregexp = "$tmpregexp$ppregexp";
  my $debug = 0;
  if ($debug) {
    print STDERR "REGEXP[$tokenid]->\t\t$ppregexp\n";
  }
  $template->env('REGEXP', $ppregexp);

  my $code;
  my $lexer_type = $lexer->lexerType;
  $lexer_type =~ s/.+::(.+)$/\U$1_/g;
  $code = $template->eval($lexer_type . 'HEADER_PART');
  $code;
}

package Parse::Token::Quoted;
use Parse::Trace;
@Parse::Token::Quoted::ISA = qw(Parse::Token::Multiline Parse::Trace);

sub new {
  my $receiver = shift;
  my ($name, $regexp, @remain) = $receiver->_parse(@_);
  my $token = $receiver->SUPER::new($name, $regexp, @remain);
  $token;
}

sub _parse {
  my $self = shift;
  unless (@_ >= 2) {
    require  Carp;
    Carp::croak "bad argument number (@_)";
  }
  my ($key, $value);
  my ($name, $start, $end, $regexp, $action);
  my $escape = '';
  while (@_ >= 2) {
    ($key, $value) = (shift, shift);
    if ($key =~ /-?[Nn]ame/) {
      $name = $value;
    } elsif ($key =~ /^-?[Qq]uote$/) {
      $start = $value unless defined $start;
      $end = $value unless defined $end;
    } elsif ($key =~ /^-?[Ss]tart$/) {
      $start = $value;
      $end = $value unless defined $end;
    } elsif ($key =~ /^-?[Ee]nd$/) {
      $end = $value;
      $start = $value unless defined $start;
    } elsif ($key =~ /^-?[Ee]scape$/) {
      $escape = $value;
    } elsif ($key =~ /^-?[Aa]ction$/) {
      $action = $value;
    } else {
      last;
    }
  }
  unless (defined $start) {
    require Carp;
    Carp::croak "'Start' char not defined";
  }
  unless (defined $end) {
    require Carp;
    Carp::croak "'end' char not defined";
  }
  $regexp = $self->_buildRegexp($start, $end, $escape);
  #print STDERR "regexp: @$regexp\n";
  ($name, $regexp, $action, @_);
}
# Examples:
# [qw(" [^"]+(?:""[^"]*)* ")]
# [qw(" [^\\"]+(?:\\.[^\\"]*)* ")]
sub _buildRegexp {
  my $self = shift;
  my ($start, $end, $escape) = @_;
  my $content;
  $start = quotemeta $start;
  $end = quotemeta $end;
  if ($escape ne '') {
    $escape = quotemeta $escape;
    $content = qq![^$end$escape]*(?:$escape.! . qq![^$end$escape]*)*!;
  } else {
    $content = qq![^$end]*(?:$end$end! . qq![^$end]*)*!;
  } 
  [$start, $content, $end];
}

package Parse::Token::Delimited;
use Parse::Trace;
@Parse::Token::Delimited::ISA = qw(Parse::Token::Multiline Parse::Trace);

# Examples:
# [qw(/* (?:.*?) */)]
# [qw(<!-- (?:.*?) -->)]
# [qw(<? (?:.*?) ?>)]
sub new {
  die "Sorry! Not yet implemented";
}

package Parse::Token::Nested;
use Parse::Trace;
@Parse::Token::Nested::ISA = qw(Parse::Token::Nested Parse::Trace);

# Examples:
# (+ (* 3 4) 4)
# 
sub new {
  die "Sorry! Not yet implemented";
}

1;
__END__

=head1 NAME

C<Parse::Token> - Definition of tokens used by C<Parse::Lex>

=head1 SYNOPSIS

	require 5.005;

	use Parse::Lex;
	@token = qw(
	    ADDOP    [-+]
	    INTEGER  [1-9][0-9]*
	   );

	$lexer = Parse::Lex->new(@token);
	$lexer->from(\*DATA);

	$content = $INTEGER->next;
	if ($INTEGER->status) {
	  print "$content\n";
	}
	$content = $ADDOP->next;
	if ($ADDOP->status) {
	  print "$content\n";
	}
	if ($INTEGER->isnext(\$content)) {
	  print "$content\n";
	}
	__END__
	1+2

=head1 DESCRIPTION

The C<Token> package defines the lexemes used by C<Parse::Lex> or
C<Parse::CLex>. The C<Lex::new()> method of the C<Parse::Lex> package
indirectly creates a C<Parse::Token> instance for each recognized lexeme.
The methods C<next> and C<isnext> of the C<Token> package permit easily
interfacing the lexical analyzer with a recursive-descent syntactic analyzer
(parser).  For interfacing with C<byacc>, see the C<Parse::YYLex> package.

This package is included indirectly via C<use Parse::Lex>.

=head1 Methods

=over 4

=item action

Returns the anonymous subroutine defined within the C<Parse::Token> object.

=item factory LIST

Creates a list of C<Parse::Token> objects from a list of token
specifications.  The list can also include objects of class
C<Parse::Token> or of a class derived from it.  Can be used
as a class method or instance method.

The C<factory(LIST)> method can be used to create a set
of tokens which are not within the analysis automaton.
This method carries out two operations: 1) it creates the
objects based on the specifications given in LIST (see the
C<new()> method), and 2) it imports the created objects into
the calling package.

You could for example write:

	%keywords = 
	  qw (
	      PROC  undef
	      FUNC  undef
	      RETURN undef
	      IF    undef
	      ELSE  undef
	      WHILE undef
	      PRINT undef
	      READ  undef
	     );
	Parse::Token->factory(%keywords);

and install these tokens in a symbol table in the following manner:

	foreach $name (keys %keywords) {
	  $symbol{"\L$name"} = [${$name}, ''];
	}

C<${$name}> is the C<Parse::Token> object.

During the lexical analysis phase, you can use the tokens in the
following manner:

	qw(IDENT [a-zA-Z][a-zA-Z0-9]*),  sub {		      
	   $symbol{$_[1]} = [] unless defined $symbol{$_[1]};
	   my $type = $symbol{$_[1]}[0];
	   $lexer->setToken((not defined $type) ? $VAR : $type);
	   $_[1];  # THE TOKEN TEXT
	 }

This permits indicating that any symbol of unknown type is a variable.

In this example we have used  C<$_[1]> which corresponds to the text
recognized by the regular expression.  This text is what is returned
by the anonymous subroutine.

=item get EXPR

C<get> obtains the value of the attribute named by the result of
evaluating EXPR.  You can also use the name of the attribute as a method name.

=item getText

Returns the character string that was recognized by means of this
C<Parse::Token> object.

Same as the text() method.

=item isnext EXPR

=item isnext

Returns the status of the token. The consumed string is put into
EXPR if it is a reference to a scalar.

=item name

Returns the symbolic name of the C<Parse::Token> object.

=item next

Activate searching for the lexeme defined by the regular expression
contained in the object. If this lexeme is recognized on the character
stream to analyze, C<next> returns the string found and sets the
status of the object to true.

=item new SYMBOL_NAME, REGEXP, SUB

Creates an object of the C<Parse::Token> type. The arguments of the C<new>
method are: a symbolic name, a regular expression, and an anonymous
subroutine.

REGEXP is either a simple regular expression, or a reference to an
array containing from one to three regular expressions. In the latter
case the lexeme can span several lines. For example, it
can be a character string delimited by quotation marks, comments in a
C program, etc. The regular expressions are used to recognize:

1. The beginning of the lexeme,

2. The "body" of the lexeme; if this second expression is missing,
C<Parse::Lex> uses "(?:.*?)",

3. the end of the lexeme; if this last expression is missing then the
first one is used. (Note! The end of the lexeme cannot span
several lines).

Example:

	  qw(STRING), [qw(" (?:[^"\\\\]+|\\\\(?:.|\n))* ")],

These regular expressions can recognize multi-line strings
delimited by quotation marks, where the backslash is used to quote the
quotation marks appearing within the string. Notice the quadrupling of
the backslash.

Here is a variation of the previous example which uses the C<s>
option to include newline in the characters recognized by "C<.>":

	  qw(STRING), [qw(" (?s:[^"\\\\]+|\\\\.)* ")],

(Note: it is possible to write regular expressions which are
more efficient in terms of execution time, but this is not our
objective with this example.)

The anonymous subroutine is called when the lexeme is recognized by the
lexical analyzer. This subroutine takes two arguments: C<$_[0]> contains
the C<Parse::Token> object, and C<$_[1]> contains the string recognized
by the regular expression. The scalar returned by the anonymous
subroutine defines the character string memorized in the C<Parse::Token>
object.

In the anonymous subroutine you can use the positional variables
C<$1>, C<$2>, etc. which correspond to the groups of parentheses
in the regular expression.

=item regexp

Returns the regular expression of the C<Token> object.

=item set LIST

Allows marking a Token object with a list of attribute-value
pairs.

An attribute name can be used as a method name.

=item setText EXPR

The value of C<EXPR> defines the character string associated with the
lexeme.

Same as the C<text(EXPR)> method.

=item status EXPR

=item status

Indicates if the last search of the lexeme succeeded or failed.
C<status EXPR> overrides the existing value and sets it to the value of EXPR.

=item text EXPR

=item text

C<text()> Returns the character string recognized by means of the
C<Token> object. The value of C<EXPR> sets the character string
associated with the lexeme.

=item trace OUTPUT 

=item trace 

Class method which activates/deactivates a trace of the lexical
analysis.

C<OUTPUT> can be a file name or a reference to a filehandle to which
the trace will be directed.

=back

=head1 ERROR HANDLING

To handle the cases of nonrecognition of lexemes you can define a
special C<Token> object at the end of the list of tokens which
defines the lexical analyzer. If the search for this token succeeds it is
then possible to call a subroutine reserved for error handling.

=head1 FUTURE CHANGES

Subclasses of the C<Parse::Token> class are being defined.
They will permit recognizing specific structures such as,
for example, strings within double-quotes, C comments, etc.
Here are the subclasses which I plan to create:

C<Parse::Token::Simple> : for defining 'ordinary' tokens.

C<Parse::Token::Multiline> : for defining tokens which
may necessitate reading additional data.

C<Parse::Token::Nested> : for recognizing nested structures
such as parenthesized expressions.

C<Parse::Token::Delimited> : for recognizing, for example,
strings within double-quotes.

The names of these classes as proposed above may be changed
if you wish to suggest alternatives.

=head1 AUTHOR

Philippe Verdret. Documentation translated to English by Vladimir
Alexiev and Ocrat.

=head1 ACKNOWLEDGMENTS

Version 2.0 owes much to suggestions made by Vladimir Alexiev.
Ocrat has significantly contributed to improving this documentation.

=head1 REFERENCES

Friedl, J.E.F. Mastering Regular Expressions. O'Reilly & Associates
1996.

Mason, T. & Brown, D. - Lex & Yacc. O'Reilly & Associates, Inc. 1990.

=head1 COPYRIGHT

Copyright (c) 1995-1999 Philippe Verdret. All rights reserved. This
module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

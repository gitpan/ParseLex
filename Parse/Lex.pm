# Copyright (c) Philippe Verdret, 1995-1997

# todo:
# - unless(defined $skip)

require 5.003;
use integer;
use strict qw(vars);
use strict qw(refs);
use strict qw(subs);

package Parse::Lex;
$Parse::Lex::VERSION = '1.18';
use Parse::Trace;
@Parse::Lex::ISA = qw(Parse::Trace);
use Parse::Token;
use Carp;
				# Default values
my $trace = 0;			# control trace mode
my $hold = 0;			# if true enable data saving
my $skip = '[ \t]+';		# strings to skip
my $DEFAULT_FH = \*STDIN;	# Input Filehandle 
my $eoi = 0;			# 1 if end of imput 
my $DEFAULT_TOKEN = Parse::Token->new('DEFAULT', '.*'); # default token
my $pendingToken = 0;		# 1 if a pending token
				# You can access to these variables from outside!


my $lexer = bless [];		# Prototype object
sub prototype { $lexer }

use vars qw(%_map);
my $i = -1;
%_map = map {
  ($_, ++$i)
} qw(FH STRING SUB BUFFER PENDING_TOKEN 
  RECORD_NO RECORD_LENGTH OFFSET POS
  EOI SKIP HOLD HOLD_CONTENT THREE_PART_RE 
  NAME IN_PKG
  TEMPLATE CODE_HEAD CODE_BODY CODE_FOOT 
  TRACE INIT 
  TOKEN_LIST);
sub _map { $_map{($_[1])} }
my($FH, $STRING, $SUB, $BUFFER, $PENDING_TOKEN, 
   $RECORD_NO, $RECORD_LENGTH, $OFFSET, $POS,
   $EOI, $SKIP, $HOLD, $HOLD_CONTENT, $THREE_PART_RE, 
   $NAME, $IN_PKG,
   $TEMPLATE, $CODE_HEAD, $CODE_BODY, $CODE_FOOT, 
   $TRACE, $INIT, 
   $TOKEN_LIST
  ) = (0..$i);

####################################################################
#Structure of the next routine:
#  HEADER_ST | HEADER_FH
#  ((ROW_HEADER_SIMPLE|ROW_HEADER_THREE_PART_FH|ROW_HEADER_THREE_PART_ST)
#   (ROW_FOOTER|ROW_FOOTER_SUB))+
#  FOOTER
# hold consumed strings
use vars qw($HOLDTOKEN $HOLDSKIP);
$HOLDTOKEN = q!$_[0]->[! . Parse::Lex->_map('HOLD_CONTENT') . q!] .= $content;!;
$HOLDSKIP = q!$_[0]->[! . Parse::Lex->_map('HOLD_CONTENT') . q!] .= $1;!; 

my %CODE = ();
$CODE{'HEADER_ST'} = q@
  {		
   pos($buffer) = $pos;
   my $tokenLength = 0;
   if ($pos < $length) { 
     if ($buffer =~ /\G(<<$self->skip()>>)/cg) {
       $tokenLength = length($1);
       $offset += $tokenLength;
       $pos += $tokenLength;
       <<$HOLDSKIP>>
     } 
   }
   if ($pos == $length) { 
     $self->[<<$self->_map('EOI')>>] = 1;
     $token = $Token::EOI;
     return $Token::EOI;
   }
   my $content = '';
   $token = undef;
 CASE:{
@;
$CODE{'HEADER_FH'} = q@
  {
   pos($buffer) = $pos;
   my $tokenLength = 0;
   if ($pos != $length) { 
     if ($buffer =~ /\G(<<$self->skip()>>)/cg) {
       $tokenLength = length($1);
       $offset += $tokenLength;
       $pos += $tokenLength;
       <<$HOLDSKIP>>
     } 
   }
   if ($pos == $length) { 
     if ($self->[<<$self->_map('EOI')>>]) # if EOI
       { 
         $token = $Token::EOI;
         return $Token::EOI;
       } 
     else 
       {
	local *FH = $self->[<<$self->_map('FH')>>];
	READ:{
	    do {
	      $buffer = <FH>; 
	      if (defined($buffer)) {
		pos($buffer) = $pos = 0;
		$length = length($buffer);
		$recordno++;
		if ($buffer =~ /\G(<<$self->skip()>>)/cg) {
		  $tokenLength = length($1);
		  $offset += $tokenLength;
		  $pos = $tokenLength;
		  <<$HOLDSKIP>>
		} else {
		  last READ;
		}
	      } else {
		$self->[<<$self->_map('EOI')>>] = 1;
		$token = $Token::EOI;
		return $Token::EOI;
	      }
	    } while ($pos == $length);
	  }# READ
      }
   }
   my $content = '';
   $token = undef;
 CASE:{
@;
$CODE{'ROW_HEADER_SIMPLE'} = q!
   $buffer =~ /\G(<<$Lex::begin>>)/cg and do {
     $content = $1;
     $tokenLength = length($content);
     $offset += $tokenLength;
     $pos += $tokenLength;
!;
$CODE{'ROW_HEADER_SIMPLE_TRACE'} = q!
     if ($self->[<<$self->_map('TRACE')>>]) {
       my $trace = "Token read (" . $<<$Lex::tokenid>>->name . ", <<$Lex::begin>>\E ): $content"; 
      $self->context($trace);
     }
!;
$CODE{'ROW_HEADER_THREE_PART_ST'} = q!
   $buffer =~ /\G(<<$Lex::begin>><<$Lex::between>><<$Lex::end>>)/cg and do {
     $content = $1;
     $tokenLength = length($content);
     $offset += $tokenLength;
     $pos += $tokenLength;
!;
$CODE{'ROW_HEADER_THREE_PART_FH'} = q@
    $buffer =~ /\G(<<$Lex::begin>>)/cg and do {
      my $beforepos = $pos;
      my $initpos = pos($buffer);
      my($tmp) = substr($buffer, $initpos);
				# don't use \G 
      unless ($tmp =~ /^<<$Lex::between>><<$Lex::end>>/) {
	my $string = '';
	local *FH = $self->[<<$self->_map('FH')>>];
	do {
	  while (1) {
	    $string = <FH>;
	    if (not defined($string)) { # 
	      $self->[<<$self->_map('EOI')>>] = 1;
	      $token = $Token::EOI;
	      croak "unable to find end of token ", $<<$Lex::tokenid>>->name, "";
	    }
	    $recordno++;
	    $tmp .= $string;
	    last if $string =~ /<<$Lex::end>>/;
	  }
	} until ($tmp =~ /^<<$Lex::between>><<$Lex::end>>/g);
      }
      $pos = pos($tmp) + $initpos; # "g" is mandatory in the previous regexp
      $buffer = substr($buffer, $beforepos, $initpos) . $tmp;
      $length = length($buffer);
      $offset += $pos - $beforepos; # or length($content);
      $content = substr($buffer, $beforepos, $pos);
@;
$CODE{'ROW_HEADER_THREE_PART_TRACE'} = q!
     if ($self->[<<$self->_map('TRACE')>>]) { # Trace
       my $trace = "Token read (" . $<<$Lex::tokenid>>->name .
          ", <<$Lex::begin>><<$Lex::between>><<$Lex::end>>\E ): $content"; 
        $self->context($trace);
     }
!;
$CODE{'ROW_FOOTER_SUB'} = q!
    $<<$Lex::tokenid>>->setstring($content);
    $self->[<<$self->_map('PENDING_TOKEN')>>] = $token = $<<$Lex::tokenid>>;
    $content = &{$<<$Lex::tokenid>>->mean}($token, $content);
    $<<$Lex::tokenid>>->setstring($content);
    $token = $self->[<<$self->_map('PENDING_TOKEN')>>]; # if tokenis in sub
    last CASE;
  };
!;
$CODE{'ROW_FOOTER'} = q!
    $<<$Lex::tokenid>>->setstring($content);
    $token = $<<$Lex::tokenid>>;
    last CASE;
   };
!;
$CODE{'FOOTER'} = q!
  }#CASE
  <<$HOLDTOKEN>>
  $self->[<<$self->_map('PENDING_TOKEN')>>] = $token;
  $token;
}
!;
####################################################################
$lexer->[$FH] = $DEFAULT_FH;
$lexer->[$STRING] = 0; # if 1 data come from string
$lexer->[$SUB] = sub {
  $_[0]->genlex;		# autogeneration
  &{$_[0]->[$SUB]};		# execution
};
my $somevar = '';
$lexer->[$BUFFER] = \$somevar;		# string to tokenize
$lexer->[$PENDING_TOKEN] = $DEFAULT_TOKEN;
$lexer->[$RECORD_NO] = \$somevar;	# number of the current record
$lexer->[$RECORD_LENGTH] = \$somevar;	# length of the current record
$lexer->[$OFFSET] = \$somevar;		# offset from the beginning of the analysed stream
$lexer->[$POS] = \$somevar;		# position in the current record
$lexer->[$EOI] = $eoi;
$lexer->[$SKIP] = $skip;
$lexer->[$HOLD] = $hold;	# save or not what is consumed
$lexer->[$HOLD_CONTENT] = '';	# saved string
$lexer->[$THREE_PART_RE] = 0;	# 1 if three part regexp
$lexer->[$TEMPLATE] = \%CODE;	# code template
$lexer->[$CODE_HEAD] = '';	# lexer code
$lexer->[$CODE_BODY] = '';	# lexer code
$lexer->[$CODE_FOOT] = '';	# lexer code
$lexer->[$TRACE] = $trace;
$lexer->[$INIT] = 1;		# true at the object creation
$lexer->[$TOKEN_LIST] = undef;
$Lex::PEND_TOKEN = $PENDING_TOKEN; # used by the Token class

				
sub reset {			# reset all lexer's state values
  my $self = shift;
  $self->[$EOI] = 0; 
  ${$self->[$RECORD_NO]} = 0;
  ${$self->[$RECORD_LENGTH]} = 0;
  ${$self->[$OFFSET]} = 0;
  ${$self->[$POS]} = 0;
  $self->[$HOLD_CONTENT] = '';
  ${$self->[$BUFFER]} = ''; 
  if ($self->[$PENDING_TOKEN]) { 
    $self->[$PENDING_TOKEN]->setstring();
    $self->[$PENDING_TOKEN] = 0;
  }
}

sub next { &{$_[0]->[$SUB]} }
sub eoi { 
  my $self = shift;
  $self->[$EOI];
} 
sub token {			# always return a Token object
  my $self = shift;
  $self->[$PENDING_TOKEN] or $DEFAULT_TOKEN 
} 
sub settoken {			# force the token
  my $self = shift;
  $self->[$PENDING_TOKEN] = $_[0];
}
*tokenis = \&settoken;

sub setbuffer {			# not documented
  my $self = shift;
  ${$self->[$BUFFER]} = $_[0];
} 
sub getbuffer {			# not documented
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
  my $tmp = $self->[$HOLD_CONTENT];
  $self->[$HOLD_CONTENT] = '';
  $tmp;
}
sub less {			# hum... doesn't seem really useful
  my $self = shift;
  if (defined $_[0]) {
    ${$self->[$BUFFER]} = $_[0] . 
      ${$self->[$BUFFER]};
  }
}
sub recordno {			# return the number of the current record
  my $self = shift;
  ${$self->[$RECORD_NO]};
}
sub recordlength {		# return the length of the current record
				# not documented
  my $self = shift;
  ${$self->[$RECORD_LENGTH]};
}

sub offset {			# return the end position from the stream beginning
				# of the last token	
  my $self = shift;
  ${$self->[$OFFSET]};
}
sub pos {			# return the end position of the last token 
				# in the current record
  my $self = shift;
  if (defined $_[0]) {
    ${$self->[$POS]} = $_[0] 
  } else {
    ${$self->[$POS]};
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
    croak "argument of the 'every' method must be an anonymous routine";
  }
  my $token = &{$self->[$SUB]}($self);
  while (not $self->[$EOI]) {
    &{$_[0]}($token);
    $token = &{$self->[$SUB]}($self);
  }
  undef;
}
sub tokenlist {
  my $self = shift;
  @{$self}[$TOKEN_LIST..$#{$self}]; 
}
# where data come from
sub from {
  my $self = shift;
				# Data from a filehandle
  if (ref($_[0]) eq 'GLOB' and defined fileno($_[0])) {	
    if ($self->[$FH] ne $_[0]) { # FH not defined or has changed
      $self->[$FH] = $_[0];
      $self->[$STRING] = 0;
      $self->genbody($self->tokenlist) if $self->[$THREE_PART_RE];
      $self->genhead();
      $self->genlex();
    }
    $self->reset;
  } elsif (defined $_[0]) {	# Data from a variable or a list
    unless ($self->[$STRING]) {
      $self->[$FH] = '';
      $self->[$STRING] = 1;
      $self->genbody($self->tokenlist) if $self->[$THREE_PART_RE];
      $self->genhead();
      $self->genlex();
    }
    $self->reset;
    my $buffer = join($", @_); # Data from a list
    ${$self->[$BUFFER]} = $buffer;
    ${$self->[$RECORD_LENGTH]} = length($buffer);
  } elsif ($self->[$FH]) {
    $self->[$FH];
  } else {
    undef;
  }
}
sub readline {
  my $fh = $_[0]->[$FH];
  if (not defined($_ = <$fh>)) {
    $_[0]->[$EOI] = 1;
  } else {
    ${$_[0]->[$RECORD_NO]}++;
  }
  $_;
}
# Purpose: Toggle the trace mode
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
    $self->prototype()->[$TRACE] = not $self->prototype->[$TRACE];
    $self->SUPER::trace(@_);
  }
}

# hold(EXPR)
# hold
# Purpose: hold or not consumed strings, return the current value
# Arguments: nothing or EXPR true/false
# Returns: the current value of the hold attribute

sub hold {			
  my $self = shift;
  if (ref $self) {
#    print "object method\n";
      $self->[$HOLD] = not $self->[$HOLD];
      $self->genhead();
      $self->genfoot();
      $self->genlex();
  } else {			# for the class attribute
				# or perhaps change the default object
    $self->prototype()->[$HOLD] = not $self->prototype()->[$HOLD];
#    $hold = not $hold;
#    print "class method $hold $self\n";
  }
}

# skip(EXPR)
# skip
# Purpose: return or set the value of the regexp used for consuming
# inter-token strings. 
# Arguments: with EXPR changed the regexp and regenerate the
# lexical analyzer 
# Returns: see Purpose

sub skip {			
  my $self = shift;
  if (ref $self) {
    if (defined($_[0])) {
      if ($_[0] ne $self->[$SKIP]) {
	$self->[$SKIP] = $_[0];
	$self->genhead();
	$self->genlex();
      }
    } else {
      $self->[$SKIP];
    }
  } else {			# for the class attribute
				# or perhaps change the default object
    defined $_[0] ?
      $self->prototype()->[$SKIP] = $_[0] : $self->prototype()->[$SKIP];
#    defined $_[0] ? $skip = $_[0] : $skip;
  }
}

# Purpose: create the lexical analyzer, with the associated tokens
# Arguments: list of token specifications
# Returns: a lex object

sub new {
  my $receiver = shift;
  my $class = (ref $receiver or $receiver);

  # Parse::Lex doesn't work if $[ < 5.004
  #if ($class eq 'Parse::Lex' and $[ < 5.004);
  # warn "doesn\'t work with Perl $[";

  my $prototype = $class->prototype;
  $prototype->reset;
  my $self = bless [@{$prototype}], $class; 

  $self->[$INIT] = 1;
  $self->[$IN_PKG] = (caller(0))[0]; # From which package?

  my @token = ();
  if (@_) {
    @token = $self->newset(@_);
    splice(@{$self}, $TOKEN_LIST, 1, @token);	
    $self->gencode(@token);
  }
  $self;
}
sub ppregexp { # pre-process regexp: ! or / (delimiters) -> \! \/
  shift;
  my $regexp = $_[0];
  $regexp =~ s{
    ((?:\G|[^\\])(?:\\{2,2})*)	# Context before
    ([/!\"])			# Delimiters used
  }{$1\\$2}xg;
  $regexp;
}
sub ppcode {
  my $self = shift;
  my $code = shift;
  $code =~ s/<<([^<].*?)>>/"$1"/eeg;
  $code;
}
sub template {
  my $self = shift;
  my $part = shift;
  $self->[$TEMPLATE]->{$part};
}
sub processTemplate {
  my $self = shift;
  my $part = shift;
  my $code = $self->[$TEMPLATE]->{$part};
  $code =~ s/<<([^<].*?)>>/"$1"/eeg;
  $code;
}
# Purpose: create the lexical analyzer
# Arguments: list of tokens
# Returns: a Lex object
# Remark: not documented
sub genbody {
  my $self = shift;

  local $HOLDTOKEN = '' unless $self->[$HOLD];
  local $Lex::tokenid;	
  my $regexp = '';
  local($Lex::begin, $Lex::between, $Lex::end);
				# 
  $self->[$THREE_PART_RE] = 0;
  if ($self->[$INIT]) {		# object creation
    $self->[$INIT] = 0;		# useless
  }
  my $fromFH = $self->[$FH]; 
  my $sub;
  my $token;
  my $body = '';
  no strict 'refs';		# => ${$Lex::tokenid}
  while (@_) {			# list of Token instances
    $token = shift;
    $regexp = $token->regexp;
    $Lex::tokenid = $self->inpkg . '::' . $token->name;

    if (ref($regexp) eq 'ARRAY') {
      $self->[$THREE_PART_RE] = 1;
      if ($#{$regexp} >= 3) {
	carp join  " " , "Warning!", $#{$regexp} + 1, 
	"arguments in token definition";
      }
      $Lex::begin = $self->ppregexp(${$regexp}[0]);
      $Lex::between = ${$regexp}[1] ? 
	$self->ppregexp(${$regexp}[1]) : '(?:.*?)';
      $Lex::end = $self->ppregexp(${$regexp}[2] or ${$regexp}[0]);

      if ($fromFH) {
	$body .= $self->processTemplate('ROW_HEADER_THREE_PART_FH');
      } else {
	$body .= $self->processTemplate('ROW_HEADER_THREE_PART_ST');
      }
      if ($self->[$TRACE]) {
	$body .= $self->processTemplate('ROW_HEADER_THREE_PART_TRACE');
      } 
      $Lex::between = '';
    } else {
      $Lex::begin = $self->ppregexp($regexp);
      $body .= $self->processTemplate('ROW_HEADER_SIMPLE');
      if ($self->[$TRACE]) {
	$body .= $self->processTemplate('ROW_HEADER_SIMPLE_TRACE');
      } 
    }
    $sub = $token->mean;
    if ($sub) {			# Token with an associated sub
      $body .= $self->processTemplate('ROW_FOOTER_SUB');
      $sub = undef;		# 
    } else {
      $body .= $self->processTemplate('ROW_FOOTER');
    }
  }
  $self->[$CODE_BODY] = $body;
}
# Remark: not documented
sub genhead {
  my $self = shift;
  my $class = ref $self;
				# save all what is consumed or not 
  local $HOLDTOKEN = '' unless $self->[$HOLD];
  local $HOLDSKIP = ''  unless $self->[$HOLD];
				# 
  if ($self->[$FH]) {
    $self->[$CODE_HEAD] = $self->processTemplate('HEADER_FH');
  } else {
    $self->[$CODE_HEAD] = $self->processTemplate('HEADER_ST');
  }

}
# Remark: not documented
sub genfoot {
  my $self = shift;
  local $HOLDTOKEN = '' unless $self->[$HOLD];
  $self->[$CODE_FOOT] = $self->processTemplate('FOOTER');
}
# Remark: not documented
sub gencode {
  my $self = shift;
  $self->genbody(@_);
  $self->genhead();
  $self->genfoot();
}

# Purpose: Returns code of the lexical analyzer
# Arguments: nothing
# Returns: code of the lexical analyzer
# Remark: not documented
sub getcode {
  my $self = shift;
  $self->[$CODE_HEAD] . $self->[$CODE_BODY]. $self->[$CODE_FOOT];
}

# Purpose: Generate the lexical analyzer
# Arguments: 
# Returns: the anonymous subroutine implementing the lexical analyzer
# Remark: not documented
sub genlex {
  my $self = shift;
  my $analyzer = $self->getcode();
  my $buffer = '';
  $self->[$BUFFER] = \$buffer;
  my $length = 0;		# length of the current record
  $self->[$RECORD_LENGTH] = \$length;
  my $recordno = 0;
  $self->[$RECORD_NO] = \$recordno;
  my $pos = 0;
  $self->[$POS] = \$pos;	# current position 
  my $offset = 0;
  $self->[$OFFSET] = \$offset;	# offset from the beginning
  my $token = '';

  eval qq!\$self->[$SUB] = sub $analyzer!;

  my $debug = 0;
  if ($@ or $debug) {	# can be useful ;-)
    my $line = 0;
    print STDERR "adf\n";
    $analyzer =~ s/^/sprintf("%3d", $line++)/meg; # line numbers
    print STDERR "$analyzer\n";
    print STDERR "$@\n";
    die "\n" if $@;
  }
  $self->[$SUB];
}

# Purpose: returns the lexical analyzer routine
# Arguments: nothing
# Returns: the anonymous sub implementing the lexical analyzer
sub getsub {
  my $self = shift;
  if (ref($self->[$SUB]) eq 'CODE') {
    $self->[$SUB];
  } else {
    $self->genlex();
  }
}

# Purpose: Generate a set of tokens and define these tokens
#          in the package of the caller
# Arguments: list of token specifications
# Returns: list of token objects
# Remark: define a new class (container)

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
  my $name;
  my $regexp;
  my $tmp;
  my @token;
  no strict 'refs';		# => ${$name}
  while (@_) {
    ($name, $regexp) = (shift, shift);
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
    # Creation of a new Token object
    ${"$inpkg" . "::$name"} = $tmp = Parse::Token->new($name, $regexp, $sub, $self);
    push(@token, $tmp);				    
  }
  @token;
}
1;
__END__

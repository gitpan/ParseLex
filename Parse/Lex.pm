# Copyright (c) Philippe Verdret, 1995-1997

require 5.004;
use strict qw(vars);
use strict qw(refs);
use strict qw(subs);

package Parse::Lex;
use Parse::ALex;
use Carp;
@Parse::Lex::ISA = qw(Parse::ALex);

my $lexer = bless [@{Parse::Lex->SUPER::prototype()}];
sub prototype { $lexer }

my($FH, $STRING, $SUB, $BUFFER, $PENDING_TOKEN, 
   $RECORD_NO, $RECORD_LENGTH, $OFFSET, $POS,
   $EOI, $SKIP, $HOLD, $HOLD_CONTENT, $THREE_PART_RE, 
   $NAME, $IN_PKG,
   $TEMPLATE, $CODE_HEAD, $CODE_BODY, $CODE_FOOT, 
   $TRACE, $INIT, 
   $TOKEN_LIST
  ) = (0..30);

####################################################################
#Structure of the next routine:
#  HEADER_ST | HEADER_FH
#  ((ROW_HEADER_SIMPLE|ROW_HEADER_THREE_PART_FH|ROW_HEADER_THREE_PART_ST)
#   (ROW_FOOTER|ROW_FOOTER_SUB))+
#  FOOTER

my %CODE = ();
$CODE{'HOLDSKIP'} = q@$self->[<<$self->_map('HOLD_CONTENT')>>] .= $1;@;
$CODE{'HOLDTOKEN'} = q@$self->[<<$self->_map('HOLD_CONTENT')>>] .= $content;@;
$CODE{'HEADER_ST'} = q@
  {		
   pos($buffer) = $pos;
   my $tokenLength = 0;
   if ($pos < $length) { 
     if ($buffer =~ /\G(<<$self->skip()>>)/cg) {
       $tokenLength = length($1);
       $offset += $tokenLength;
       $pos += $tokenLength;
       <<$self->ishold ? $self->processTemplate('HOLDSKIP') : ''>>
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
       <<$self->ishold ? $self->processTemplate('HOLDSKIP') : ''>>
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
                  <<$self->ishold ? $self->processTemplate('HOLDSKIP') : ''>>
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
  <<$self->ishold ? $self->processTemplate('HOLDTOKEN') : ''>>
  $self->[<<$self->_map('PENDING_TOKEN')>>] = $token;
  $token;
}
!;
####################################################################
$lexer->[$TEMPLATE] = \%CODE;	# code template

1;
__END__


# Copyright (c) Philippe Verdret, 1995-1997

require 5.003;
use strict qw(vars);
use strict qw(refs);
use strict qw(subs);

package Parse::CLex;
use Parse::Lex;
use Carp;
@Parse::CLex::ISA = qw(Parse::Lex);

my $lexer = Parse::CLex->SUPER::proto();
sub proto { $lexer }

my($FH, $STRING, $SUB, $BUFFER, $PENDING_TOKEN, 
   $RECORD_NO, $RECORD_LENGTH, $OFFSET, $POS,
   $EOI, $SKIP, $HOLD, $HOLD_CONTENT, $THREE_PART_RE, 
   $NAME, $IN_PKG,
   $TEMPLATE, $CODE_HEAD, $CODE_BODY, $CODE_FOOT, 
   $TRACE, $INIT, 
   $TOKEN_LIST
  ) = (0..30);

sub pos {			
  my $self = shift;
  if (defined $_[0]) {    
    carp "can't change position";
    #my $buffer = $self->buffer;
    #$buffer =~ s/.{$_[0]}//s;
    #$self->buffer($buffer);
  } else {
    ${$self->[$POS]};
  }
}

####################################################################
#Structure of the next routine:
#  HEADER_ST | HEADER_FH
#  ((ROW_HEADER_SIMPLE|ROW_HEADER_THREE_PART_FH|ROW_HEADER_THREE_PART_ST)
#   (ROW_FOOTER|ROW_FOOTER_SUB))+
#  FOOTER
# hold consumed strings
use vars qw($HOLDTOKEN $HOLDSKIP);
$HOLDTOKEN = q!$self->[! . Parse::Lex->_map('HOLD_CONTENT') . q!] .= $content;!;
$HOLDSKIP = q!$self->[! . Parse::Lex->_map('HOLD_CONTENT') . q!] .= $1;!; 

my %CODE = ();
$CODE{'HEADER_ST'} = q!
  {		
   my $tokenLength = 0;
   if ($buffer ne '') {
     if ($buffer =~ s/^(<<$self->skip()>>)//) {
       $tokenLength = length($1);
       $offset += $tokenLength;
       $pos += $tokenLength;
       <<$HOLDSKIP>>
     }
   }
   if ($buffer eq '') {
     $self->[<<$self->_map('EOI')>>] = 1;
     $token = $Token::EOI;
     return $Token::EOI;
   }
   my $content = '';
   $token = undef;
 CASE:{
!;
$CODE{'HEADER_FH'} = q!
  {
   my $tokenLength = 0;
   if ($buffer ne '') {
     if ($buffer =~ s/^(<<$self->skip()>>)//) {
       $tokenLength = length($1);
       $offset += $tokenLength;
       $pos += $tokenLength;
       <<$HOLDSKIP>>
     }
   }
   if ($buffer eq '') {
     if ($self->[<<$self->_map('EOI')>>]) # if EOI
       { 
         $self->[<<$self->_map('PENDING_TOKEN')>>] = $Token::EOI;
         return $Token::EOI;
       } 
     else 
       {
	local *FH = $self->[<<$self->_map('FH')>>];
      READ: {
	  do {
	    $buffer = <FH>; 
	    if (defined($buffer)) {
	      $recordno++;
	      if ($buffer =~ s/^(<<$self->skip()>>)//) {
		$tokenLength = length($1);
		$offset+= $tokenLength;
		$pos = $tokenLength;
		<<$HOLDSKIP>>
	      } else {
		$pos = 0; 
		last READ;
	      }
	    } else {
	      $self->[<<$self->_map('EOI')>>] = 1;
	      $token = $Token::EOI;
	      return $Token::EOI;
	    }
	  } while ($buffer eq '');
	}
      }
   }
   my $content = '';
   $token = undef;
 CASE:{
!;
$CODE{'ROW_HEADER_SIMPLE'} = q!
   $buffer =~ s/^(<<$Lex::begin>>)// and do {
     $content = $1;
     $tokenLength = length($content);
     $offset += $tokenLength;
     $pos += $tokenLength;
!;
$CODE{'ROW_HEADER_SIMPLE_TRACE'} = q!
     if ($self->[<<$self->_map('TRACE')>>]) {
       my $trace = "Token read (" . $<<$Lex::id>>->name . ", <<$Lex::begin>>\E): $content"; 
       $self->context($trace);
     }
!;
$CODE{'ROW_HEADER_THREE_PART_ST'} = q!
   $buffer =~ s/^(<<$Lex::begin>><<$Lex::between>><<$Lex::end>>)// and do {
     $content = $1;
     $tokenLength = length($content);
     $offset += $tokenLength;
     $pos += $tokenLength;
!;
$CODE{'ROW_HEADER_THREE_PART_FH'} = q!
    $buffer =~ s/^(<<$Lex::begin>>)// and do {
      my $string = $buffer;
      $content = $1;
      my $length = length($content) + length($buffer);
      local *FH = $self->[<<$self->_map('FH')>>];
     do {
       while (not $string =~ /<<$Lex::end>>/) {
	 $string = <FH>;
	 if (not defined($string)) { # 
           $self->[<<$self->_map('EOI')>>] = 1;
           $token = $Token::EOI;
	   croak "unable to find end of token ", $<<$Lex::id>>->name, "";
	 }
	 $length = length($string);
	 $recordno++;
	 $buffer .= $string;
       }
       $string = '';
       $buffer =~ s/^(<<$Lex::between>>)//;
       $content .= $1;
     } until ($buffer =~ s/^(<<$Lex::end>>)//);
     $content .= $1;
     $tokenLength = length($content);
     $offset += $tokenLength;
     $pos += $length - length($buffer);	
!;
$CODE{'ROW_HEADER_THREE_PART_TRACE'} = q!
     if ($self->[<<$self->_map('TRACE')>>]) { # Trace
       my $trace = "Token read (" . $<<$Lex::id>>->name .
          ", <<$Lex::begin>><<$Lex::between>><<$Lex::end>>\E): $content"; 
        $self->context($trace);
     }
!;
$CODE{'ROW_FOOTER_SUB'} = q!
     $<<$Lex::id>>->setstring($content);
     $token = $<<$Lex::id>>;
     $content = &{$<<$Lex::id>>->mean}($token, $content);
     $<<$Lex::id>>->setstring($content);
     last CASE;
  };
!;
$CODE{'ROW_FOOTER'} = q!
     $<<$Lex::id>>->setstring($content);
     $token = $<<$Lex::id>>;
     last CASE;
   };
!;
$CODE{'FOOTER'} = q!
  }#CASE
  <<$HOLDTOKEN>>
  $token;
}
!;
####################################################################
$lexer->[$TEMPLATE] = \%CODE;	# code template

1;
__END__


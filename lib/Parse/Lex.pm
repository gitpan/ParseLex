# Copyright (c) Philippe Verdret, 1995-1998

require 5.004;
use strict qw(vars);
use strict qw(refs);
use strict qw(subs);

package Parse::Lex;
use Parse::ALex;
use Carp;
@Parse::Lex::ISA = qw(Parse::ALex);

my $thisClass = __PACKAGE__; #&{sub { caller }};
my $lexer = $thisClass->clone;
sub prototype { $lexer or $thisClass->SUPER::prototype }

####################################################################
#Structure of the next routine:
#  HEADER_STRING | HEADER_STREAM
#  ((SIMPLE_TOKEN|THREE_PART_TOKEN_STREAM|THREE_PART_TOKEN_STRING)
#   (ROW_FOOTER|ROW_FOOTER_SUB))+
#  FOOTER

# <<...>> are processed by the Parse::Template class
# In <<>> $template and $self are the same Parse::Template instance
# RegExp must be delimited by // or m!!
# <<>> can't be imbricated

my %TEMPLATE = ();
$lexer->template(new Parse::Template (\%TEMPLATE));	# code template

$TEMPLATE{'WITH_SKIP'} = q@
   if ($LEX_POS < $LEX_LENGTH and $LEX_BUFFER =~ /\G<<$SKIP>>/cg) {
     $textLength = pos($LEX_BUFFER) - $LEX_POS; # length $&
     $LEX_OFFSET += $textLength;
     $LEX_POS += $textLength;
     <<$IS_HOLD ? $template->eval('HOLD_SKIP') : ''>>
   }
@;
$TEMPLATE{'WITH_SKIP_LAST_READ'} = q@
		if ($LEX_BUFFER =~ /\G<<$SKIP>>/cg) {
		  $textLength = pos($LEX_BUFFER) - $LEX_POS; # length $&
		  $LEX_OFFSET += $textLength;
		  $LEX_POS += $textLength;
                  <<$IS_HOLD ? $template->eval('HOLD_SKIP') : ''>>
		} else {
		  last READ;
		}
@;
$TEMPLATE{'HOLD_SKIP'} = q@$self->[<<$HOLD_TEXT>>] .= $1;@;
$TEMPLATE{'HEADER_STRING'} = q@
  {		
   pos($LEX_BUFFER) = $LEX_POS;
   my $textLength = 0;
   <<$SKIP ne '' ? $template->eval('WITH_SKIP') : '' >>
   if ($LEX_POS == $LEX_LENGTH) { 
     $self->[<<$EOI>>] = 1;
     $LEX_TOKEN = $Parse::Token::EOI;
     return $Parse::Token::EOI;
   }
   my $content = '';
   $LEX_TOKEN = undef;
 CASE:{
@;
$TEMPLATE{'HEADER_STREAM'} = q@
  {
   pos($LEX_BUFFER) = $LEX_POS;
   my $textLength = 0;
   my $LEX_FH = $$LEX_FHR;
   <<$SKIP ne '' ? $template->eval('WITH_SKIP') : '' >>
   if ($LEX_POS == $LEX_LENGTH) { 
     if ($self->[<<$EOI>>]) # if EOI
       { 
         $LEX_TOKEN = $Parse::Token::EOI;
         return $Parse::Token::EOI;
       } 
     else 
       {
	READ:{
	    do {
	      $LEX_BUFFER = <$LEX_FH>; 
	      if (defined($LEX_BUFFER)) {
		pos($LEX_BUFFER) = $LEX_POS = 0;
		$LEX_LENGTH = CORE::length($LEX_BUFFER);
		$LEX_RECORD++;
		<<$SKIP ne '' ? $template->eval('WITH_SKIP_LAST_READ') : '' >>
	      } else {
		$self->[<<$EOI>>] = 1;
		$LEX_TOKEN = $Parse::Token::EOI;
		return $Parse::Token::EOI;
	      }
	    } while ($LEX_POS == $LEX_LENGTH);
	  }# READ
      }
   }
   my $content = '';
   $LEX_TOKEN = undef;
 CASE:{
@;
$TEMPLATE{'SIMPLE_TOKEN'} = q!
   <<$CONDITION>>
   $LEX_BUFFER =~ /\G<<$REGEXP>>/cg and do {
     $textLength = pos($LEX_BUFFER) - $LEX_POS;
     $content = substr($LEX_BUFFER, $LEX_POS, $textLength); # $&
     $LEX_OFFSET += $textLength;
     $LEX_POS += $textLength;
     <<$IS_TRACE ? $template->eval('SIMPLE_TOKEN_TRACE') : '' >>
!;
$TEMPLATE{'SIMPLE_TOKEN_TRACE'} = q!
     if ($self->[<<$TRACE>>]) {
       my $trace = "Token read (" . $<<"$TOKEN_ID">>->name . 
	 ", '<<$REGEXP>>\E'): $content"; 
      $self->context($trace);
     }
!;
$TEMPLATE{'THREE_PART_TOKEN_STRING'} = q!
   <<$CONDITION>>
   $LEX_BUFFER =~ /\G<<$REGEXP>>/cg and do {
     $textLength = pos($LEX_BUFFER) - $LEX_POS; # length $&
     $content = substr($LEX_BUFFER, $LEX_POS, $textLength); # $&
     $LEX_OFFSET += $textLength;
     $LEX_POS += $textLength;
     <<$IS_TRACE ? $template->eval('THREE_PART_TOKEN_TRACE') : '' >>
!;
$TEMPLATE{'THREE_PART_TOKEN_STREAM'} = q@
    <<$CONDITION>>
    $LEX_BUFFER =~ /\G<<"$REGEXP_START">>/cg and do {
      my $beforepos = $LEX_POS;
      my $initpos = pos($LEX_BUFFER);
      my($tmp) = substr($LEX_BUFFER, $initpos); 
      # don't use \G 
      unless ($tmp =~ /^<<"$REGEXP_MIDDLE$REGEXP_END">>/g) {
	my $text = '';
	do {
	  while (1) {
	    $text = <$LEX_FH>;
	    if (not defined($text)) { # 
	      $self->[<<$EOI>>] = 1;
	      $LEX_TOKEN = $Parse::Token::EOI;
	      croak "unable to find end of token ", $<<"$TOKEN_ID">>->name, "";
	    }
	    $LEX_RECORD++;
	    $tmp .= $text;
	    last if $text =~ /<<$REGEXP_END>>/;
	  }
	} until ($tmp =~ /^<<"$REGEXP_MIDDLE$REGEXP_END">>/g);
      }
      $LEX_POS = pos($tmp) + $initpos; # "g" is mandatory in the previous regexp
      $LEX_BUFFER = substr($LEX_BUFFER, $beforepos, $initpos) . $tmp;
      $LEX_LENGTH = CORE::length($LEX_BUFFER);
      $LEX_OFFSET += $LEX_POS - $beforepos; # or length($content);
      $content = substr($LEX_BUFFER, $beforepos, $LEX_POS);
      <<$IS_TRACE ? $template->eval('THREE_PART_TOKEN_TRACE') : '' >>
@;
$TEMPLATE{'THREE_PART_TOKEN_TRACE'} = q!
     if ($self->[<<$TRACE>>]) { # Trace
       my $trace = "Token read (" . $<<"$TOKEN_ID">>->name .
          ", '<<$REGEXP>>\E'): $content"; 
        $self->context($trace);
     }
!;
$TEMPLATE{'ROW_FOOTER_SUB'} = q!
    $<<"$TOKEN_ID">>->setText($content);
    $self->[<<$PENDING_TOKEN>>] = $LEX_TOKEN = $<<"$TOKEN_ID">>;
    $content = &{$<<"$TOKEN_ID">>->action}($LEX_TOKEN, $content);
    $<<"$TOKEN_ID">>->setText($content);
     <<$IS_TRACE ? $template->eval('ROW_FOOTER_SUB_TRACE') : ''>>
    $LEX_TOKEN = $self->[<<$PENDING_TOKEN>>]; # if tokenis in sub
    last CASE;
  };
!;
$TEMPLATE{'ROW_FOOTER_SUB_TRACE'} = q!
    if ($self->[<<$PENDING_TOKEN>>] ne $LEX_TOKEN) {
     if ($self->[<<$TRACE>>]) { # Trace
	    $self->context("Token type has changed - " .
			   "Type: " . $LEX_TOKEN->name .
			   " - Content: $content\n");
	  }
	}
!;
$TEMPLATE{'ROW_FOOTER'} = q!
    $<<"$TOKEN_ID">>->setText($content);
    $LEX_TOKEN = $<<"$TOKEN_ID">>;
    last CASE;
   };
!;
$TEMPLATE{'HOLD_TOKEN'} = q@$self->[<<$HOLD_TEXT>>] .= $content;@;
$TEMPLATE{'FOOTER'} = q!
  }#CASE
  <<$IS_HOLD ? $template->eval('HOLD_TOKEN') : ''>>
  $self->[<<$PENDING_TOKEN>>] = $LEX_TOKEN;
  $LEX_TOKEN;
}
!;

1;
__END__


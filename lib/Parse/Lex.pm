# Copyright (c) Philippe Verdret, 1995-1998

require 5.004;
use strict qw(vars);
use strict qw(refs);
use strict qw(subs);

package Parse::Lex;
use Parse::ALex;
use Carp;
@Parse::Lex::ISA = qw(Parse::ALex);

my $thisClass = &{sub { caller }};
my $lexer = $thisClass->clone;
sub prototype { $lexer or $thisClass->SUPER::prototype }

####################################################################
#Structure of the next routine:
#  HEADER_STRING | HEADER_STREAM
#  ((ROW_HEADER_SIMPLE_RE|ROW_HEADER_THREE_PART_RE_STREAM|ROW_HEADER_THREE_PART_RE_STRING)
#   (ROW_FOOTER|ROW_FOOTER_SUB))+
#  FOOTER

# <<...>> are processed by the Parse::Template class
# <<>> can't be imbricated
# RegExp must be delimited by // or m!!
# $self is the tokenizer object
# $template is the Parse::Template object

my %TEMPLATE = ();
$lexer->template(new Parse::Template (\%TEMPLATE));	# code template

$TEMPLATE{'WITH_SKIP'} = q@
   if ($pos < $length and $buffer =~ /\G<<$self->skip()>>/cg) {
     $textLength = pos($buffer) - $pos; # length $&
     $offset += $textLength;
     $pos += $textLength;
     <<$self->isHold ? $template->eval('HOLD_SKIP') : ''>>
   }
@;
$TEMPLATE{'WITH_SKIP_LAST_READ'} = q@
		if ($buffer =~ /\G<<$self->skip()>>/cg) {
		  $textLength = pos($buffer) - $pos; # length $&
		  $offset += $textLength;
		  $pos += $textLength;
                  <<$self->isHold ? $template->eval('HOLD_SKIP') : ''>>
		} else {
		  last READ;
		}
@;
$TEMPLATE{'HOLD_SKIP'} = q@$self->[<<$self->_map('HOLD_TEXT')>>] .= $1;@;
$TEMPLATE{'HEADER_STRING'} = q@
  {		
   pos($buffer) = $pos;
   my $textLength = 0;
   <<$self->skip ne '' ? $template->eval('WITH_SKIP') : '' >>
   if ($pos == $length) { 
     $self->[<<$self->_map('EOI')>>] = 1;
     $token = $Parse::Token::EOI;
     return $Parse::Token::EOI;
   }
   my $content = '';
   $token = undef;
 CASE:{
@;
$TEMPLATE{'HEADER_STREAM'} = q@
  {
   pos($buffer) = $pos;
   my $textLength = 0;
   my $fh = $$fhr;
   <<$self->skip ne '' ? $template->eval('WITH_SKIP') : '' >>
   if ($pos == $length) { 
     if ($self->[<<$self->_map('EOI')>>]) # if EOI
       { 
         $token = $Parse::Token::EOI;
         return $Parse::Token::EOI;
       } 
     else 
       {
	READ:{
	    do {
	      $buffer = <$fh>; 
	      if (defined($buffer)) {
		pos($buffer) = $pos = 0;
		$length = length($buffer);
		$line++;
		<<$self->skip ne '' ? $template->eval('WITH_SKIP_LAST_READ') : '' >>
	      } else {
		$self->[<<$self->_map('EOI')>>] = 1;
		$token = $Parse::Token::EOI;
		return $Parse::Token::EOI;
	      }
	    } while ($pos == $length);
	  }# READ
      }
   }
   my $content = '';
   $token = undef;
 CASE:{
@;
$TEMPLATE{'ROW_HEADER_SIMPLE_RE'} = q!
   <<$template->env('condition')>>
   $buffer =~ /\G<<$template->env('regexp')>>/cg and do {
     $textLength = pos($buffer) - $pos;
     $content = substr($buffer, $pos, $textLength); # $&
     $offset += $textLength;
     $pos += $textLength;
     <<$self->isTrace ? $template->eval('ROW_HEADER_SIMPLE_RE_TRACE') : '' >>
!;
$TEMPLATE{'ROW_HEADER_SIMPLE_RE_TRACE'} = q!
     if ($self->[<<$self->_map('TRACE')>>]) {
       my $trace = "Token read (" . $<<$template->env('tokenid')>>->name . 
	 ", '<<$template->env('regexp')>>\E'): $content"; 
      $self->context($trace);
     }
!;
$TEMPLATE{'ROW_HEADER_THREE_PART_RE_STRING'} = q!
   <<$template->env('condition')>>
   $buffer =~ /\G<<$template->env('regexp')>>/cg and do {
     $textLength = pos($buffer) - $pos; # length $&
     $content = substr($buffer, $pos, $textLength); # $&
     $offset += $textLength;
     $pos += $textLength;
     <<$self->isTrace ? $template->eval('ROW_HEADER_THREE_PART_RE_TRACE') : '' >>
!;
$TEMPLATE{'ROW_HEADER_THREE_PART_RE_STREAM'} = q@
    <<$template->env('condition')>>
    $buffer =~ /\G<<$template->env('start')>>/cg and do {
      my $beforepos = $pos;
      my $initpos = pos($buffer);
      my($tmp) = substr($buffer, $initpos); 
				# don't use \G 
      unless ($tmp =~ /^<<$template->env('middle')>><<$template->env('end')>>/g) {
	my $text = '';
	do {
	  while (1) {
	    $text = <$fh>;
	    if (not defined($text)) { # 
	      $self->[<<$self->_map('EOI')>>] = 1;
	      $token = $Parse::Token::EOI;
	      croak "unable to find end of token ", $<<$template->env('tokenid')>>->name, "";
	    }
	    $line++;
	    $tmp .= $text;
	    last if $text =~ /<<$template->env('end')>>/;
	  }
	} until ($tmp =~ /^<<$template->env('middle')>><<$template->env('end')>>/g);
      }
      $pos = pos($tmp) + $initpos; # "g" is mandatory in the previous regexp
      $buffer = substr($buffer, $beforepos, $initpos) . $tmp;
      $length = length($buffer);
      $offset += $pos - $beforepos; # or length($content);
      $content = substr($buffer, $beforepos, $pos);
      <<$self->isTrace ? $template->eval('ROW_HEADER_THREE_PART_RE_TRACE') : '' >>
@;
$TEMPLATE{'ROW_HEADER_THREE_PART_RE_TRACE'} = q!
     if ($self->[<<$self->_map('TRACE')>>]) { # Trace
       my $trace = "Token read (" . $<<$template->env('tokenid')>>->name .
          ", '<<$template->env('regexp')>>\E'): $content"; 
        $self->context($trace);
     }
!;
$TEMPLATE{'ROW_FOOTER_SUB'} = q!
    $<<$template->env('tokenid')>>->setText($content);
    $self->[<<$self->_map('PENDING_TOKEN')>>] = $token = $<<$template->env('tokenid')>>;
    $content = &{$<<$template->env('tokenid')>>->action}($token, $content);
    $<<$template->env('tokenid')>>->setText($content);
     <<$self->isTrace ? $template->eval('ROW_HEADER_SUB_TRACE') : ''>>
    $token = $self->[<<$self->_map('PENDING_TOKEN')>>]; # if tokenis in sub
    last CASE;
  };
!;
$TEMPLATE{'ROW_HEADER_SUB_TRACE'} = q!
    if ($self->[<<$self->_map('PENDING_TOKEN')>>] ne $token) {
     if ($self->[<<$self->_map('TRACE')>>]) { # Trace
	    $self->context("Token type has changed - " .
			   "Type: " . $token->name .
			   " - Content: $content\n");
	  }
	}
!;
$TEMPLATE{'ROW_FOOTER'} = q!
    $<<$template->env('tokenid')>>->setText($content);
    $token = $<<$template->env('tokenid')>>;
    last CASE;
   };
!;
$TEMPLATE{'HOLD_TOKEN'} = q@$self->[<<$self->_map('HOLD_TEXT')>>] .= $content;@;
$TEMPLATE{'FOOTER'} = q!
  }#CASE
  <<$self->isHold ? $template->eval('HOLD_TOKEN') : ''>>
  $self->[<<$self->_map('PENDING_TOKEN')>>] = $token;
  $token;
}
!;
####################################################################

1;
__END__


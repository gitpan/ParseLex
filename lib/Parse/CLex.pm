# Copyright (c) Philippe Verdret, 1995-1998

require 5.003;
use strict qw(vars);
use strict qw(refs);
use strict qw(subs);

package Parse::CLex;
use Parse::ALex;
use Carp;
@Parse::CLex::ISA = qw(Parse::ALex);

my $lexer = bless [@{Parse::CLex->SUPER::prototype()}];
sub prototype { $lexer }

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
   if ($buffer ne '' and $buffer =~ s/^<<$self->skip()>>//) {
     $textLength = length($&);
     $offset += $textLength;
     $pos += $textLength;
     <<$self->isHold ? $template->eval('HOLD_SKIP') : ''>>
   }
@;
$TEMPLATE{'WITH_SKIP_LAST_READ'} = q@
	      if ($buffer =~ s/^<<$self->skip()>>//) {
		$textLength = length($&);
		$offset+= $textLength;
		$pos = $textLength;
                <<$self->isHold ? $template->eval('HOLD_SKIP') : ''>>
	      } else {
		$pos = 0; 
		last READ;
	      }
@;
$TEMPLATE{'HOLD_SKIP'} = q@$self->[<<$self->_map('HOLD_TEXT')>>] .= $&;@;
$TEMPLATE{'HEADER_STRING'} = q!
  {		
   my $textLength = 0;
   <<$self->skip ne '' ? $template->eval('WITH_SKIP') : '' >>
   if ($buffer eq '') {
     $self->[<<$self->_map('EOI')>>] = 1;
     $token = $Parse::Token::EOI;
     return $Parse::Token::EOI;
   }
   my $content = '';
   $token = undef;
 CASE:{
!;
$TEMPLATE{'HEADER_STREAM'} = q!
  {
   my $textLength = 0;
   <<$self->skip ne '' ? $template->eval('WITH_SKIP') : '' >>
   my $fh = $$fhr;
   if ($buffer eq '') {
     if ($self->[<<$self->_map('EOI')>>]) # if EOI
       { 
         $self->[<<$self->_map('PENDING_TOKEN')>>] = $Parse::Token::EOI;
         return $Parse::Token::EOI;
       } 
     else 
       {
      READ: {
	  do {
	    $buffer = <$fh>; 
	    if (defined($buffer)) {
	      $line++;
	      <<$self->skip ne '' ? $template->eval('WITH_SKIP_LAST_READ') : '' >>
	    } else {
	      $self->[<<$self->_map('EOI')>>] = 1;
	      $token = $Parse::Token::EOI;
	      return $Parse::Token::EOI;
	    }
	  } while ($buffer eq '');
	}
      }
   }
   my $content = '';
   $token = undef;
 CASE:{
!;
$TEMPLATE{'ROW_HEADER_SIMPLE_RE'} = q!
   <<$template->env('condition')>>
   $buffer =~ s/^<<$template->env('regexp')>>// and do {
     $content = $&;
     $textLength = length($content);
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
   $buffer =~ s/^<<$template->env('regexp')>>// and do {
     $content = $&;
     $textLength = length($content);
     $offset += $textLength;
     $pos += $textLength;
     <<$self->isTrace ? $template->eval('ROW_HEADER_THREE_PART_RE_TRACE') : '' >>
!;
$TEMPLATE{'ROW_HEADER_THREE_PART_RE_STREAM'} = q!
    <<$template->env('condition')>>
    $buffer =~ s/^<<$template->env('start')>>// and do {
      my $string = $buffer;
      $content = $&;
      my $length = length($content) + length($buffer);
     do {
       while (not $string =~ /<<$template->env('end')>>/) {
	 $string = <$fh>;
	 if (not defined($string)) { # 
           $self->[<<$self->_map('EOI')>>] = 1;
           $token = $Parse::Token::EOI;
	   croak "unable to find end of token ", $<<$template->env('tokenid')>>->name, "";
	 }
	 $length = length($string);
	 $line++;
	 $buffer .= $string;
       }
       $string = '';
       $buffer =~ s/^<<$template->env('middle')>>//;
       $content .= $&;
     } until ($buffer =~ s/^<<$template->env('end')>>//);
     $content .= $&;
     $textLength = length($content);
     $offset += $textLength;
     $pos += $length - length($buffer);	
     <<$self->isTrace ? $template->eval('ROW_HEADER_THREE_PART_RE_TRACE') : '' >>
!;
$TEMPLATE{'ROW_HEADER_THREE_PART_RE_TRACE'} = q!
     if ($self->[<<$self->_map('TRACE')>>]) { # Trace
       my $trace = "Token read (" . $<<$template->env('tokenid')>>->name .
          ", '<<$template->env('regexp')>>\E'): $content"; 
        $self->context($trace);
     }
!;
$TEMPLATE{'ROW_FOOTER_SUB'} = q!
     $<<$template->env('tokenid')>>->setText($content);
     $self->[<<$self->_map('PENDING_TOKEN')>>] = $token 
       = $<<$template->env('tokenid')>>;
     $content = &{$<<$template->env('tokenid')>>->action}($token, $content);
     ($token = $self->getToken)->setText($content);
     <<$self->isTrace ? $template->eval('ROW_HEADER_SUB_TRACE') : ''>>
     last CASE;
  };
!;
$TEMPLATE{'ROW_HEADER_SUB_TRACE'} = q!
        if ($self->[<<$self->_map('PENDING_TOKEN')>>] ne $token) {
	  if ($self->isTrace) {
	    $self->context("token type has changed\n" .
			   "Type is: " . $token->name .
			   " and content is: $content\n");
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

my $POS = $lexer->_map('POS');
sub pos {			
  my $self = shift;
  if (defined $_[0]) {    
    carp "can't change position";
  } else {
    ${$self->[$POS]};
  }
}

1;
__END__


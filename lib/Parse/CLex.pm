 # Copyright (c) Philippe Verdret, 1995-1998

require 5.003;
use strict qw(vars);
use strict qw(refs);
use strict qw(subs);

package Parse::CLex;
use Parse::ALex;
use Carp;
@Parse::CLex::ISA = qw(Parse::ALex);

my $thisClass = &{sub { caller }};
my $lexer = $thisClass->clone;
sub prototype { $lexer or $thisClass->SUPER::prototype }

####################################################################
#Structure of the next routine:
#  HEADER_STRING | HEADER_STREAM
#  ((SIMPLE_TOKEN|THREE_PART_TOKEN_STREAM|THREE_PART_TOKEN_STRING)
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
   if ($LEX_BUFFER ne '' and $LEX_BUFFER =~ s/^<<$SKIP>>//) {
     $textLength = length($&);
     $LEX_OFFSET += $textLength;
     $LEX_POS += $textLength;
     <<$IS_HOLD ? $template->eval('HOLD_SKIP') : ''>>
   }
@;
$TEMPLATE{'WITH_SKIP_LAST_READ'} = q@
	      if ($LEX_BUFFER =~ s/^<<$SKIP>>//) {
		$textLength = length($&);
		$LEX_OFFSET+= $textLength;
		$LEX_POS = $textLength;
                <<$IS_HOLD ? $template->eval('HOLD_SKIP') : ''>>
	      } else {
		$LEX_POS = 0; 
		last READ;
	      }
@;
$TEMPLATE{'HOLD_SKIP'} = q@$self->[<<$HOLD_TEXT>>] .= $&;@;
$TEMPLATE{'HEADER_STRING'} = q!
  {		
   my $textLength = 0;
   <<$SKIP ne '' ? $template->eval('WITH_SKIP') : '' >>
   if ($LEX_BUFFER eq '') {
     $self->[<<$EOI>>] = 1;
     $LEX_TOKEN = $Parse::Token::EOI;
     return $Parse::Token::EOI;
   }
   my $content = '';
   $LEX_TOKEN = undef;
 CASE:{
!;
$TEMPLATE{'HEADER_STREAM'} = q!
  {
   my $textLength = 0;
   <<$SKIP ne '' ? $template->eval('WITH_SKIP') : '' >>
   my $LEX_FH = $$LEX_FHR;
   if ($LEX_BUFFER eq '') {
     if ($self->[<<$EOI>>]) # if EOI
       { 
         $self->[<<$PENDING_TOKEN>>] = $Parse::Token::EOI;
         return $Parse::Token::EOI;
       } 
     else 
       {
      READ: {
	  do {
	    $LEX_BUFFER = <$LEX_FH>; 
	    if (defined($LEX_BUFFER)) {
	      $LEX_RECORD++;
	      <<$SKIP ne '' ? $template->eval('WITH_SKIP_LAST_READ') : '' >>
	    } else {
	      $self->[<<$EOI>>] = 1;
	      $LEX_TOKEN = $Parse::Token::EOI;
	      return $Parse::Token::EOI;
	    }
	  } while ($LEX_BUFFER eq '');
	}
      }
   }
   my $content = '';
   $LEX_TOKEN = undef;
 CASE:{
!;
$TEMPLATE{'SIMPLE_TOKEN'} = q!
   <<$CONDITION>>
   $LEX_BUFFER =~ s/^<<$REGEXP>>// and do {
     $content = $&;
     $textLength = length($content);
     $LEX_OFFSET += $textLength;
     $LEX_POS += $textLength;
     <<$IS_TRACE ? $template->eval('SIMPLE_TOKEN_TRACE') : '' >>
!;
$TEMPLATE{'SIMPLE_TOKEN_TRACE'} = q!
     if ($self->[<<$TRACE>>]) {
       my $trace = "Token read (" . $<<$TOKEN_ID>>->name . 
	 ", '<<$REGEXP>>\E'): $content"; 
       $self->context($trace);
     }
!;
$TEMPLATE{'THREE_PART_TOKEN_STRING'} = q!
   <<$CONDITION>>
   $LEX_BUFFER =~ s/^<<$REGEXP>>// and do {
     $content = $&;
     $textLength = length($content);
     $LEX_OFFSET += $textLength;
     $LEX_POS += $textLength;
     <<$IS_TRACE ? $template->eval('THREE_PART_TOKEN_TRACE') : '' >>
!;
$TEMPLATE{'THREE_PART_TOKEN_STREAM'} = q!
    <<$CONDITION>>
    $LEX_BUFFER =~ s/^<<$REGEXP_START>>// and do {
      my $string = $LEX_BUFFER;
      $content = $&;
      my $length = length($content) + length($LEX_BUFFER);
     do {
       while (not $string =~ /<<$REGEXP_END>>/) {
	 $string = <$LEX_FH>;
	 if (not defined($string)) { # 
           $self->[<<$EOI>>] = 1;
           $LEX_TOKEN = $Parse::Token::EOI;
	   croak "unable to find end of token ", $<<$TOKEN_ID>>->name, "";
	 }
	 $length = length($string);
	 $LEX_RECORD++;
	 $LEX_BUFFER .= $string;
       }
       $string = '';
       $LEX_BUFFER =~ s/^<<$REGEXP_MIDDLE>>//;
       $content .= $&;
     } until ($LEX_BUFFER =~ s/^<<$REGEXP_END>>//);
     $content .= $&;
     $textLength = length($content);
     $LEX_OFFSET += $textLength;
     $LEX_POS += $length - length($LEX_BUFFER);	
     <<$IS_TRACE ? $template->eval('THREE_PART_TOKEN_TRACE') : '' >>
!;
$TEMPLATE{'THREE_PART_TOKEN_TRACE'} = q!
     if ($self->[<<$TRACE>>]) { # Trace
       my $trace = "Token read (" . $<<$TOKEN_ID>>->name .
          ", '<<$REGEXP>>\E'): $content"; 
        $self->context($trace);
     }
!;
$TEMPLATE{'ROW_FOOTER_SUB'} = q!
     $<<$TOKEN_ID>>->setText($content);
     $self->[<<$PENDING_TOKEN>>] = $LEX_TOKEN 
       = $<<$TOKEN_ID>>;
     $content = &{$<<$TOKEN_ID>>->action}($LEX_TOKEN, $content);
     ($LEX_TOKEN = $self->getToken)->setText($content);
     <<$IS_TRACE ? $template->eval('ROW_FOOTER_SUB_TRACE') : ''>>
     last CASE;
  };
!;
$TEMPLATE{'ROW_FOOTER_SUB_TRACE'} = q!
        if ($self->[<<$PENDING_TOKEN>>] ne $LEX_TOKEN) {
	  if ($self->isTrace) {
	    $self->context("token type has changed - " .
			   "Type: " . $LEX_TOKEN->name .
			   " - Content: $content\n");
	  }
	}
!;
$TEMPLATE{'ROW_FOOTER'} = q!
     $<<$TOKEN_ID>>->setText($content);
     $LEX_TOKEN = $<<$TOKEN_ID>>;
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


# Copyright (c) Philippe Verdret, 1998
# A very simple template processor 

use strict
require 5.004;
package Parse::Template;
$Parse::Template::VERSION = '0.02';

use constant DEBUG => 0;	

my $sym = 'sym00';
sub genSymbol { $sym++ }	# generate: sym00, sym01, sym02, etc.

sub new {
  my $receiver = shift;
  my $class = genSymbol();
  my $self; 
  if (@_) {
    if (ref $_[0] eq 'HASH') {
      $self = bless $_[0], $class;
    } else {
      $self = bless {@_}, $class;
    }
  } else {
    $self = bless {}, $class;
  }
  no strict;
  @{"${class}::ISA"} = ref $receiver || $receiver;
  $self->initialize();	
  $self;
}
sub initialize {
  my $self = shift;
  my $class = ref $self;
  no strict;
  #local($^W) = 0;		
  ${"${class}::self"} = $self;
  ${"${class}::self"} = $self;
  $self;
}
sub undef {
  my $self = shift;
  my $class = ref $self;
  unless (@_) {
    undef %{"${class}::"};
  } else {}
}
use constant TRACE_ENV => 0;
sub env {
  my $self = shift;
  my $class = ref $self;
  my $symbol = shift;
  no strict;
  if (@_) {
    while (@_) {
      my $value = shift;
      print STDERR "${class}::$symbol\t$value\n" if TRACE_ENV;
      if (ref $value) {
	*{"${class}::$symbol"} = $value;
      } else {			# scalar value
      	*{"${class}::$symbol"} = \$value;
      }
      $symbol = shift if @_;
    }
  } elsif (defined *{"${class}::$symbol"}) { # borrowed from Exporter.pm
    return \&{"${class}::$symbol"} unless $symbol =~ s/^(\W)//;
    my $type = $1;
    return 
      $type eq '&' ? \&{"${class}::$symbol"} :
	$type eq '$' ? \${"${class}::$symbol"} :
	    $type eq '@' ? \@{"${class}::$symbol"} :
	    $type eq '%' ? \%{"${class}::$symbol"} :
	    $type eq '*' ?  *{"${class}::$symbol"} :
	    do { require Carp; Carp::croak("$type$symbol not defined") };
  } else {
    undef;
  }
}
# Purpose:  validate the regexp and replace "!" or "/" by "\!" or "\/"
# Arguments: a regexp
# Returns: the preprocessed regexp
sub ppregexp {
  #  my $self = $_[0]; # useless
  my $regexp = $_[1];
  eval { '' =~ /$regexp/ };
  if ($@) {			
    die "$@";			
  }
  $regexp =~ s{
    ((?:\G|[^\\])(?:\\{2,2})*)	# Context before
    ([/!\"])			# Delimiters used
  }{$1\\$2}xg;
  $regexp;
}
sub getPart {		
  my $self = shift;
  my $part = shift;
  $self->{$part};
}
sub setPart {		
  my $self = shift;
  my $part = shift;
  $self->{$part} = shift;
}
sub eval {
  my $self = shift;
  my $class = ref $self;
  my $part = shift;
  my $code = $self->{$part};
  unless (defined $code) {
    die "'$part' template part not defined";
  }
  local $^W = 0 if $^W;
  $code =~ s{<<(.*?)>>}{
    if (DEBUG) {
      print STDERR "expression to eval {package $class; $1}\n";
    } 
    qq!package $class; $1!;
  }eegsx;
  die "$@" if $@;
  $code;
}
1;
__END__

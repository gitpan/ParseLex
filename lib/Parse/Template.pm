# Copyright (c) Philippe Verdret, 1995-1998
# A very simple template processor 

use strict;
package Parse::Template;

my $DEBUG = 0;			# define a constant!!!
sub new {
  my $receiver = shift;
  my $class = (ref $receiver or $receiver);
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
  $self;
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
sub partOf {
  my $self = shift;
  if (@_) {
    $self->{'_partOf'} = shift;
  } else {
    $self->{'_partOf'};
  }
}
sub env {
  my $self = shift;
  my $symbol = shift;
  if (@_) {
    $self->{'_env'}->{$symbol} = shift;
  } elsif (exists $self->{'_env'}->{$symbol}) {
    my $value = $self->{'_env'}->{$symbol};
    #print STDERR "$symbol -> $value\n" if $DEBUG;
    $value;
  } else {
    print STDERR "'$symbol' not defined in the template environment\n" if $^W;
    '';
  }
}
# Purpose:  
# - validate the regexp
# - replace "!" or "/" by "\!" or "\/"
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
sub eval {
  my $template = shift;		# WARNING! template is the object Template
  my $self = $template->partOf;
  my $part = shift;
  my $code = $template->{$part};
  unless (defined $code) {
    die "'$part' template part not defined";
  }
  $code =~ s{<<([^<].*?)>>}{
    #print STDERR "expression to evaluate-->$1<--\n" if $DEBUG;
    $1
  }eegsx;
  $code;
}
1;
__END__

# Copyright (c) Philippe Verdret, 1995-1997
require 5.003;
use strict;

package Parse::Trace;
use Carp;
#use vars qw($indent);
$Trace::indent = 0;

use FileHandle;
my $TRACE = \*STDERR;		# Default

my %cache = ();
sub name { $cache{$_[0]} or ($cache{$_[0]} = $_[0]->findName) }
sub inpkg { 'main' }		# no better definition at time
sub findName {			# Try to find the "name"
  my $self = shift;
  my $pkg = $self->inpkg;
  my $symbol;
  my $value;
  $^W = 0;
  no strict qw(refs);
  map {
    ($symbol = ${"${pkg}::"}{$_}) =~ s/[*]//;
    $value = ${$symbol};
    if (defined $value and $value eq $self) {
      return $symbol;
    } 
  } keys %{"${$pkg}::"};
  use strict qw(refs);
  $^W = 1;
  return 'no name';
}
sub context {
  my $self = shift;
  my $ref = ref($self);
  my $name = '';
  $name = $self->name;	
  if (not $name) {
    $name = $self->Parse::Trace::name;
  }
  my $sign = "[$name|$ref]";
  print $TRACE "  " x $Trace::indent, "$sign @_\n";
}
sub trace {	
  my $self = shift;
  my $class = (ref $self or $self);
				# state switch
  no strict qw(refs);
  ${"${class}::trace"} = not ${"${class}::trace"};
  if (${"${class}::trace"}) {
    push @INC, '.';
    my $file = $class;
    $file =~ s!::!/!g;
    # specialized methods for the trace mode
    eval {
      require "${file}-t.pm";
    };
    print STDERR "Trace is ON in class $class\n";
  } else {
    print STDERR "Trace is OFF in class $class\n";
  }
  use strict qw(refs);
				# output
  if (@_) {
    if (ref $_[0]) {
      $TRACE = $_[0];
    } else {
      $TRACE = new FileHandle("> $_[0]");
      unless ($TRACE) {
	croak qq^unable to open "$_[0]"^;
      } else {
	print STDERR "Trace put in $_[0]\n";
      }
    }
  }
}

1;
__END__


# Copyright (c) Philippe Verdret, 1995-1997
require 5.000;
use strict;

package Parse::Trace;
use Carp;
#use vars qw($indent);
$Trace::indent = 0;

# doesn't work with my Perl current version
#use FileHandle;
my $TRACE = \*STDERR;		# Default

my %cache = ();
# todo: 
# - have the choice to use or not the cache
# - reinitialize the cache
sub name { $cache{$_[0]} or ($cache{$_[0]} = $_[0]->findName) }
sub inpkg { 'main' }		# no better definition at the present time

sub findName {			# Try to find the "name" of self
				# assume $self is put in a scalar variable
  my $self = shift;
  my $pkg = $self->inpkg;
  my $symbol;
  my $value;
  no strict qw(refs);
  my $CW = $^W;
  $^W = 0;
  map {
    ($symbol = ${"${pkg}::"}{$_}) =~ s/[*]//;
    if (defined($value = ${$symbol})) {
      return $symbol if ($value eq $self);
    } 
  } keys %{"${$pkg}::"};
  $^W = $CW;
  use strict qw(refs);
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
    eval {			# Load specialized methods
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
#      $TRACE = new FileHandle("> $_[0]");
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


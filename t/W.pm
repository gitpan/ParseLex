# todo:
# - use levels of verbosity
package W;			# Test::Wrapper
my $verbose = $ENV{TEST_VERBOSE};
my $log = $ENV{TEST_LOG} ? 'testlog' : 0;

if ($log) {
  open(LOG, ">>$log") or die qq^unable to open "$log"^;
  print STDERR "see informations in the '$log' file\n";
} 
sub new {
  my $self = shift;
  $class = (ref $self or $self);
  my $range = defined $_[0] ? shift : '1..1';
  print "$range\n";
  bless { 'range' => $range }, $class;
}
sub result {		
  my $self = shift; 
  my $cmd = shift;
  my @result;
  my @err;
  my $result;
  if ($cmd) {
    print "Execution of $^X $cmd\n" if $verbose;
    die qq^unable to find "$cmd"^ unless (-f $cmd);

    # the following line doesn't work on Win95 (ActiveState's Perl, build 516):
    # open( CMD, "$^X $cmd 2>err |" ) or warn "$0: Can't run. $!\n";
    # corrected by Stefan Becker:
    local *SAVE_STDERR;
    open(SAVE_STDERR, ">&STDERR");
    open STDERR, "> err";
    open( CMD, "$^X $cmd |" ) or warn "$0: Can't run. $!\n";
    @result = <CMD>;
    close CMD;
    close STDERR;
    open(STDERR, ">&SAVE_STDERR");

    open( CMD, "< err" ) or warn "$0: Can't open: $!\n";
    @err = <CMD>;
    close CMD;

    push @result, @err if @err;

    $self->{result} = join('', @result);
    if ($log) {
      print LOG "=" x 80, "\n";
      print LOG "Execution of $^X $cmd 2>err\n";
      print LOG "=" x 80, "\n";
      print LOG "* Result:\n";
      print LOG "-" x 80, "\n";
      print LOG $self->{result};
    }
  } else {
    $self->{result};
  }
}
sub expected {			# ad hoc method
  my $self = shift;
  my $FH = shift;
  if ($FH) {
    $self->{'expected'} = join('', <$FH>);
    if ($log) {
      print LOG "-" x 80, "\n";
      print LOG "* Expected:\n";
      print LOG "-" x 80, "\n";
      print LOG $self->{expected};
    }
  } else {
    $self->{'expected'};
  }
}
sub assert {
  my $self = shift;
  my $regexp = shift;
  if ($self->{'expected'} !~ /$regexp/) {
    die "$regexp doesn't match expected string";
  }
}
sub report {			# borrowed to the DProf.pm package
  my $self = shift;
  my $num = shift;
  my $sub = shift;
  my $x;

  $x = &$sub;
  $x ? "ok $num\n" : "not ok $num\n";
}
sub all_in_one {		# not used, not tested
  my $self = shift;
  my $prog_to_test = shift;
  my $reference = shift;	# filehandle
  $self->result("$prog_to_test");
  $self->expected($reference);
  $self->report(1, sub { 
		      my $expectation = $test->expected;
		      my $result =  $test->result;
		      $expectation =~ s/\s+$//;
		      $result =~ s/\s+$//;
		      unless ($expectation eq $result) {
			print "$result\n" if $VERBOSE;
			0;
		      } else {
			1;
		      }
		    });

}
sub debug {}
1;

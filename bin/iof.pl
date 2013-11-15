#!/usr/bin/env perl

BEGIN { $ENV{GONZLOG_SILENT} = 1 }

use 5.010;

use Bio::Gonzales::Project;
use Bio::Gonzales::Util::Cerial;
use Pod::Usage;
use String::ShellQuote;
use Getopt::Long qw(:config auto_help);

my %opt = ( quote => 1 );
GetOptions( \%opt, 'flat|f', 'quote|q!', 'json|j' ) or pod2usage(2);

gonzlog->tee_stderr(0);
gonzlog->namespace("gonzconf");
my @args = @ARGV;
my $res  = gonzconf shift @args;
for my $a (@args) {
  $res = $res->{$a};
}

if ( $opt{json} ) {
  print jfreeze $res;
} elsif ( $opt{flat} && ref $res eq 'ARRAY' ) {
  my $args;
  if ( $opt{quote} ) {
    $args = shell_quote(@$res);
  } else {
    $args = join " ", @$res;
  }
  print $args;
} elsif ( ref $res ) {
  print jfreeze $res;
} else {
  chomp $res;
  print $res;
}

use warnings;
use Test::More;
use Data::Dumper;
use File::Slurp qw/slurp/;
use File::Spec::Functions qw/catfile/;
use File::Temp qw/tempfile tmpnam tempdir/;
use File::Which;
use Bio::Gonzales::Util::Cerial;


BEGIN { use_ok( 'Bio::Gonzales::Util::File', 'slurpc' ); }

my $tmpdir = tempdir( CLEANUP => 1 );


{
  my $linesa = slurpc_old("t/data/mini.fasta");
  my $linesb = slurpc("t/data/mini.fasta");
  is_deeply( $linesa, $linesb );
}

{
  my $tempfn = catfile($tmpdir, '1.gz');

  my $gzip = which('gzip');
  diag $gzip;
  my $ofh = Bio::Gonzales::Util::File::_pipe_z($gzip, $tempfn, '>' );


  open my $ifh, '<', 't/data/mini.fasta' or die "Can't open filehandle: $!"; # check
  my @lines = <$ifh>;
  close $ifh;

  for my $l (@lines) {
    print $ofh $l;
  }
  close $ofh;

  my $linesa = slurpc("t/data/mini.fasta");
  open my $fh, '-|', 'gunzip', '-c', $tempfn or die "Can't open filehandle: $!"; #check
  my @linesb = map { chomp; $_ } <$fh>;
  close $fh;
  is_deeply(\@linesb, $linesa );
  unlink $tempfn;
}

{
  my $tempfn = catfile($tmpdir, '2.gz');

  $Bio::Gonzales::Util::File::EXTERNAL_GZ = which('gzip');
  my $ofh = Bio::Gonzales::Util::File::open_on_demand($tempfn, '>' );
  isnt(ref $ofh, 'IO::Zlib');

  open my $ifh, '<', 't/data/mini.fasta' or die "Can't open filehandle: $!"; # check
  my @lines = <$ifh>;
  close $ifh;

  for my $l (@lines) {
    print $ofh $l;
  }
  close $ofh;

  my $linesa = slurpc("t/data/mini.fasta");
  open my $fh, '-|', 'gunzip', '-c', $tempfn or die "Can't open filehandle: $!"; #check
  my @linesb = map { chomp; $_ } <$fh>;
  is_deeply( $linesa, \@linesb );
  close $fh;
  unlink $tempfn;
}

{
  my $tempfn = catfile($tmpdir, '3.gz');

  undef $Bio::Gonzales::Util::File::EXTERNAL_GZ;
  my $ofh = Bio::Gonzales::Util::File::open_on_demand($tempfn, '>' );
  is(ref $ofh, 'IO::Zlib');

  open my $ifh, '<', 't/data/mini.fasta' or die "Can't open filehandle: $!"; #check
  my @lines = <$ifh>;
  close $ifh;

  for my $l (@lines) {
    print $ofh $l;
  }
  close $ofh;

  my $linesa = slurpc("t/data/mini.fasta");
  open my $fh, '-|', 'gunzip', '-c', $tempfn or die "Can't open filehandle: $!"; #check
  my @linesb = map { chomp; $_ } <$fh>;
  close $fh;
  is_deeply( $linesa, \@linesb );
  unlink $tempfn;
}
{
  my $tempfn = catfile($tmpdir, '4.gz');

  undef $Bio::Gonzales::Util::File::EXTERNAL_GZ;
  my $ofh = Bio::Gonzales::Util::File::open_on_demand($tempfn, '>' ); #check
  is(ref $ofh, 'IO::Zlib');

  open my $ifh, '<', 't/data/mini.fasta' or die "Can't open filehandle: $!"; #check
  my @lines = map { chomp; $_ } <$ifh>;
  close $ifh;

  jspew($ofh, \@lines);

  close $ofh;

  my $linesa = slurpc("t/data/mini.fasta");
  open my $fh, '-|', 'gunzip', '-c', $tempfn or die "Can't open filehandle: $!"; #check
  my $linesb = do { local $/; <$fh> };
  close $fh;
  $linesb = jthaw($linesb);
  is_deeply( $linesb,$linesa );
  unlink $tempfn;
}

sub slurpc_old {
  my @lines;
  open my $fh, '<', $_[0] or die "Can't open filehandle: $!"; #check
  while (<$fh>) {
    chomp;
    push @lines, $_;
  }
  close $fh;

  return wantarray ? @lines : \@lines;
}

done_testing();

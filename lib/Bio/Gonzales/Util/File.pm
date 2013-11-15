package Bio::Gonzales::Util::File;

use warnings;
use strict;
use Carp;
use File::Spec;

use Scalar::Util;

use IO::Handle;
use IO::Zlib;
use IO::Uncompress::Bunzip2 qw($Bunzip2Error);
use File::Which qw/which/;

our %ZMODES = (
  '>'  => 'wb',
  '>>' => 'ab',
  '<', => 'rb',
);

use base 'Exporter';
our ( @EXPORT, @EXPORT_OK, %EXPORT_TAGS );
our $VERSION  = 0.01_01;
our $EXTERNAL_GZ = which('pigz') // which('gzip');
our $EXTERNAL_BZIP2 = which('bzip2');

@EXPORT      = qw(rexglob epath bname openod spath);
%EXPORT_TAGS = ();
@EXPORT_OK
  = qw(regex_glob expand_path slurpc basename open_on_demand is_newer splitpath %ZMODES is_archive expand_home);

sub epath { expand_path(@_) }

sub expand_path {
  my @files = @_;

  my @expanded;
  for my $file (@files) {
    push @expanded, File::Spec->rel2abs( expand_home($file) );
  }
  return wantarray ? @expanded : ( shift @expanded );
}

sub expand_home {
  my $file = shift;
  $file =~ s{ ^ ~ ( [^/]* ) }
            { $1
                ? (getpwnam($1))[7]
                : ( $ENV{HOME} || $ENV{LOGDIR} || (getpwuid($>))[7] )
            }ex;

  return $file;
}

sub regex_glob { return reglob(@_) }

sub rexglob {
  my ( $dir, $re ) = @_;

  $dir = expand_path($dir);

  opendir( my $dh, $dir ) || die "can't opendir >$dir< $!";
  my @res;
  for ( readdir($dh) ) {
    push @res, File::Spec->catfile( $dir, $_ ) if ( /$re/ && $_ !~ /^\.\.?$/ );
  }
  closedir $dh;
  return wantarray ? @res : \@res;
}

sub slurpc {

  my ( $fh, $was_open ) = open_on_demand( $_[0], '<' );
  my @lines = map { s/\r\n/\n/; chomp; $_ } <$fh>;
  close $fh if ( !$was_open );

  return wantarray ? @lines : \@lines;
}

sub bname { return basename(@_) }

sub basename {
  my $f = shift;
  my ( $dir, $base ) = ( File::Spec->splitpath($f) )[ 1, 2 ];
  $base =~ s/\.([^.]*?)$//;
  my $suffix = $1;

  return wantarray ? ( $dir, $base, $suffix ) : $base;
}

sub spath { return splitpath(@_) }

sub splitpath {
  my $f = shift;
  my ( $dir, $filename ) = ( File::Spec->splitpath($f) )[ 1, 2 ];
  $dir =~ s![\/\\]$!!;
  return ( $dir, $filename );
}

sub openod { return open_on_demand(@_) }

sub open_on_demand {
  my ( $src, $mode ) = @_;

  confess "no file or filehandle given" unless ($src);
  confess "no file open mode given or mode not known: $mode" unless ( $mode && exists( $ZMODES{$mode} ) );

  my $fh;
  my $fh_was_open;
  if ( is_fh($src) ) {
    $fh          = $src;
    $fh_was_open = 1;
  } elsif ( !ref($src) ) {
    $src = expand_home($src);
    if ( $src =~ /.+?\.gz$/i) {
      if($EXTERNAL_GZ) {
        $fh = _pipe_z( $EXTERNAL_GZ, $src, $mode );
      } else {
        $fh = IO::Zlib->new( $src, $ZMODES{$mode} ) or die "IO::Zlib failed\n";
      }
    } elsif ( $src =~ /.+?\.bz2$/i) {
      if($EXTERNAL_BZIP2) {
        $fh = _pipe_z( $EXTERNAL_BZIP2, $src, $mode );
      } else {
        $fh = IO::Uncompress::Bunzip2->new($src) or die "IO::Uncompress::Bunzip2 failed: $Bunzip2Error\n";
      }
    } else {
      open $fh, $mode, $src or confess "Can't open filehandle $src: $!";
    }
  } else {
    # try to open it anyway, let's see what happens
    # could be a reference to a scalar, supported since perl 5.10
    open $fh, $mode, $src or confess "Can't open filehandle $src: $!";
  }

  if (wantarray) {
    return ( $fh, $fh_was_open );
  } elsif ($fh_was_open) {
    confess "it is not possible to use open_on_demand\n in scalar context with previously opened filehandle";
  }
  return $fh;
}

sub _pipe_z {
  my ($gz, $f, $mode ) = @_;
  return unless( $gz && -x $gz);
  if ( $mode eq '<' ) {
    open my $fh, '-|', $gz, '-c', '-d', $f or die "Can't open filehandle $f: $!";
    return $fh;
  } elsif ( $mode eq '>' ) {
    my ( $r, $w );
    pipe( $r, $w ) || die "pigz pipe failed: $!";
    my $pid = fork();
    $SIG{PIPE} = sub { die "whoops, pigz pipe broke" };
    defined($pid) || die "pigz fork failed: $!";
    if ($pid) {
      close $r;
      return $w;
    } else {
      open( STDIN, "<&", $r ) || die "can't reopen pigz STDIN: $!";
      close($w) || die "can't close pigz WRITER: $!";
      open STDOUT, '>', $f or die "Can't open filehandle: $!";
      exec( $gz, '-c' );
      exit(0);
    }
  }

  return;
}

sub is_archive {
  my $f = shift;

  if ( $f =~ /.+?\.gz$/i ) {
    return 'gz';
  } elsif ( $f =~ /.+?\.bz2$/i ) {
    return 'bz2';
  } else {
    return;
  }
}

sub is_newer {
  my ( $a, $b ) = @_;

  confess "$a doesn't exist"
    unless ( -f $a );
  return 1
    if ( !-e $b || ( -e $b && ( stat $a )[9] > ( stat $b )[9] ) );
  return;
}

sub is_fh {
  my $fh = shift;

  my $reftype = Scalar::Util::reftype($fh);

  return 1 if ( $reftype && ( $reftype eq 'IO' or $reftype eq 'GLOB' && *{$fh}{IO} ) );

  return;
}

1;
__END__

=head1 NAME

Bio::Gonzales::Util::File - Utility functions for file stuff

=head1 SYNOPSIS

    use Bio::Gonzales::Util::File qw(regex_glob expand_path slurpc basename open_on_demand is_newer);

=head1 DESCRIPTION

=head1 SUBROUTINES

=over 4

=item B<< my ($fh, $was_already_open) = open_on_demand($filename_or_fh, $mode) >>

=item B<< my ($fh, $was_already_open) = openod($filename_or_fh, $mode) >>

Opens the file if C<$filename_or_fh> is a filename or returns
C<$filename_or_fh> if it is already a filehandle, that is opened.

=item B<< my $fh = open_on_demand($filename, $mode) >>

=item B<< my $fh = openod($filename, $mode) >>

Opens the file C<$filename> and returns an handle to it.

=item B<< $true_if_a_is_newer = is_newer($a, $b) >>

Return true if C<$b> does not exist or C<$a> is newer than C<$b>. Dies if C<$a> does not exist.

=item B<< ($dir, $basename, $suffix) = basename($file) >>

=item B<< $basename = basename($file) >>

Returns the basename of C<$file> in scalar context and the ( C<$dir>,
C<$basename>, C<$suffix> ) in list context. Filename example:

  /path/to/file.txt
  scalar basename: 'file'
  list basename: ('path/to', 'file', 'txt')

=item B<< @lines = slurpc($file) >>

=item B<< @expanded = expand_path(@files) >>

=item B<< $expanded_ref = expand_path(@files) >>

Expands F<~> in all supplied files and returns the crap.

=item B<< @files = regex_glob($dir, $file_regex) >>

Selects files from C<$dir> based on the supplied C<$file_regex>.

=item B<< ($dirname, $filename) = splitpath($path) >>

Splits a $path into directory and filename.

=back

=head1 SEE ALSO

=head1 AUTHOR

jw bargsten, C<< <joachim.bargsten at wur.nl> >>

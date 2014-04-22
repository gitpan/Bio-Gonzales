package Bio::Gonzales::Project;

use warnings;
use strict;
use Carp;

use 5.010;

use POSIX;
use File::Spec::Functions qw/catfile/;
use File::Spec;
use FindBin;
use Bio::Gonzales::Util::File qw/slurpc/;
use Bio::Gonzales::Util::Cerial;
use Bio::Gonzales::Util::Development::File;
use Data::Visitor::Callback;
use Bio::Gonzales::Util::Log;
use Data::Printer;
use Carp;

use base 'Exporter';
our ( @EXPORT, @EXPORT_OK, %EXPORT_TAGS );
our $VERSION = '0.0545'; # VERSION

@EXPORT
  = qw(catfile nfi $ANALYSIS_VERSION path_to analysis_path msg error debug gonzlog env_add gonzconf iof $GONZLOG);
%EXPORT_TAGS = ();
@EXPORT_OK   = qw();

our $ANALYSIS_VERSION;
if ( $ENV{ANALYSIS_VERSION} ) {
  $ANALYSIS_VERSION = $ENV{ANALYSIS_VERSION};
} elsif ( -f 'av' ) {
  $ANALYSIS_VERSION = ( slurpc('av') )[0];
}

unless ( $ANALYSIS_VERSION && $ANALYSIS_VERSION =~ /^[-A-Za-z_.0-9]+$/ ) {
  carp "analysis version not or not correctly specified, variable contains: " . ($ANALYSIS_VERSION // 'nothing');
  carp "using current dir as output dir";
  $ANALYSIS_VERSION = '.';
} else {
  mkdir $ANALYSIS_VERSION unless ( -d $ANALYSIS_VERSION );
}

my $SUBSTITUTE_GONZCONF;
{
  my %subs = (
    av      => sub { return $ANALYSIS_VERSION },
    path_to => \&path_to,
    data    => sub { return path_to('data') },
  );

  $SUBSTITUTE_GONZCONF = Data::Visitor::Callback->new(
    plain_value => sub {
      return unless defined $_;
      $_ =~ s{ ^ ~ ( [^/]* ) }
            { $1
                ? (getpwnam($1))[7]
                : ( $ENV{HOME} || (getpwuid($>))[7] )
            }ex;

      my $subsre = join "|", keys %subs;
      s{__($subsre)(?:\((.+?)\))?__}{ $subs{ $1 }->( $2 ? split( /,/, $2 ) : () ) }eg;
    }
  );
}

our $GONZLOG = Bio::Gonzales::Util::Log->new( path => _nfi('gonz.log'), level => 'info', namespace => $FindBin::Script );
$GONZLOG->info("invoked")    # if a script is run, log it
  if(!$ENV{GONZLOG_SILENT});

sub gonzlog {
  return $GONZLOG;
}

sub nfi {
  my $f = _nfi(@_);
  $GONZLOG->info("(nfi) > $f <");
  return $f;
}

sub env_add {
  my $e = shift;

  while ( my ( $k, $v ) = each %$e ) {
    $ENV{$k} = join ":", $v, $ENV{$k};
  }
}

sub _nfi { return File::Spec->catfile( $ANALYSIS_VERSION, @_ ) }

sub iof { return gonzconf(@_) }

sub gonzconf {
  my ($key) = @_;

  my $data;
  if ( -f 'gonzconf.yml' ) {
    $data = yslurp('gonzconf.yml');
  } elsif ( -f 'gonz.conf.yml' ) {
    $data = yslurp('gonz.conf.yml');
  } elsif ( -f 'iof.yml' ) {
    $data = yslurp('iof.yml');
  } elsif ( -f 'io_files.yml' ) {
    $data = thaw_file('io_files.yml');
  } elsif ( -f 'iof.json' ) {
    $data = jslurp('iof.json');
  } else {
    confess "io file not found";
  }
  $SUBSTITUTE_GONZCONF->visit($data);

  if ( $key && exists( $data->{$key} ) ) {
    $GONZLOG->info( "(gonzconf) > $key <", p( $data->{$key} ) );
    return $data->{$key};
  } elsif ($key) {
    confess "$key not found in gonzconf";
  } else {
    $GONZLOG->info( "(gonzconf) dump", p($data) );
    return $data;
  }
}

sub path_to {
  my $home = Bio::Gonzales::Util::Development::File::find_root(
    {
      location => '.',
      dirs     => [ '.git', 'analysis', 'doc', ],
      files    => ['Makefile']
    }
  );

  confess "Could not find project home"
    unless ($home);
  return File::Spec->catfile( $home, @_ );
}

sub analysis_path {

  return path_to( "analysis", @_ );
}

1;

__END__

=head1 NAME

Bio::Gonzales::AV - analysis project utils

=head1 SYNOPSIS

    use Bio::Gonzales::AV qw(catfile nfi $ANALYSIS_VERSION iof path_to analysis_path msg error debug);

=head1 SUBROUTINES

=over 4

=item B<< msg(@stuff) >>

say C<@stuff> to C<STDERR>.

=item B<< path_to($filename) >>

Locate the root of the project and prepend it to the C<$filename>.

=item B<< iof() >>

get access to the IO files config file. Use like

    my $protein_files = iof()->{protein_files}

=item B<< nfi($filename) >>

Prepend the current analysis version diretory to the filename.


=item B<< catfile($path, $file) >>

make them whole again...

=back

=head1 SEE ALSO

=head1 AUTHOR

jw bargsten, C<< <joachim.bargsten at wur.nl> >>

=cut

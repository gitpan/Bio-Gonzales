#!/usr/bin/env perl

use warnings;
use strict;

use Data::Dumper;
use Carp;

use 5.010;

use File::Path qw/make_path/;
use DateTime;
use File::Spec::Functions qw/catfile/;
use Bio::Gonzales::Util::File qw/slurpc/;
use Cwd qw/fastcwd/;
use File::Touch;
use Getopt::Long::Descriptive;
use Bio::Gonzales::Util::Development::File;

our $ANALYSIS_DIR     = 'analysis';
our @STD_PROJECT_DIRS = qw(
  lib
  doc
  data
  analysis
);

our @REQUIRED_PROJECT_DIRS = qw(
  .git
  doc
  analysis
);

my ( $opt, $usage ) = describe_options(
  '%c %o <cmd> <name>', [ 'help', "print usage message and exit", ],
  [], ['<cmd> can be "init, analysis, ls, tag'],
);

print( $usage->text ), exit if $opt->help;

@ARGV = ('ls') unless ( @ARGV >= 1 );

my ( $cmd, @args ) = @ARGV;

my $date = DateTime->today->strftime("%F");

given ($cmd) {
  when (/^i(nit)?/) {
    my $name = shift @args;

    confess 'you have to supply a name' unless ($name);
    confess "name already exists" if ( -e $name );

    my @dirs = ($name);
    push @dirs, map { catfile( $name, $_ ) } @STD_PROJECT_DIRS;

    for my $d (@dirs) {
      say STDERR "Creating $d";
      make_path($d);
    }

    chdir $name;

    say STDERR "Creating Makefile";
    open my $make_fh, '>', "Makefile" or confess "Can't open filehandle: $!";
    say $make_fh ".PHONY: all clean test\n";
    $make_fh->close;

    create_readme( '.', $name, $date );
    say STDERR "creating git repo";

    open my $gi_fh, '>', '.gitignore' or confess "Can't open filehandle: $!";
    say $gi_fh "analysis";
    $gi_fh->close;

    system qw/git init/;
    system qw/git add Makefile README .gitignore/;
    system qw/git commit -m/, "initial commit";

    say STDERR "Finished";

  }
  when (/^a(nalysis)?/) {
    my $name = shift @args;

    my $project_dir = find_project_root();
    my $rel_dir;
    my $dir;
    if ($project_dir) {
      $project_dir = File::Spec->rel2abs($project_dir);
      $rel_dir     = catfile( $ANALYSIS_DIR, $name );
      $dir         = catfile( $project_dir, $rel_dir );

    } else {
      $rel_dir = $name;
      $dir = catfile( File::Spec->rel2abs('.'), $rel_dir );
    }
    say STDERR "Creating $dir";
    confess "name already exists" if ( -e $dir );
    make_path($dir);

    say STDERR "Creating $dir/bin";
    make_path( catfile( $dir, 'bin' ) );

    say STDERR "Creating $dir/data";
    make_path( catfile( $dir, 'data' ) );

    say STDERR "Creating $dir/test";
    make_path( catfile( $dir, 'test' ) );

    chdir $dir;
    say STDERR "Creating Makefile";
    open my $make_fh, '>', "Makefile" or confess "Can't open filehandle: $!";
    say $make_fh ".PHONY: all\n";
    say $make_fh "";
    #say $make_fh 'date=$(shell date +%F)';
    say $make_fh 'ANALYSIS_VERSION=$(shell cat av)';
    say $make_fh "\nexport ANALYSIS_VERSION\n";
    say $make_fh 'AV=$(ANALYSIS_VERSION)' . "\n";
    say $make_fh "all: dir\n";
    say $make_fh "dir:";
    say $make_fh "\t" . '@[ -d $(AV) ] || mkdir $(AV)';

    $make_fh->close;

    open my $av_fh, '>', 'av' or confess "Can't open filehandle: $!";
    say $av_fh $date;
    $av_fh->close;

    say STDERR "Creating IO files dictionary";
    touch("gonzconf.yml");
    #touch("INDEX");

    ( my $pretty_name = $name );    # =~ s/^\d+_//;
    create_readme( '.', $pretty_name, $date );

    system qw/git init/;
    system qw/git add Makefile README av gonzconf.yml/;
    system qw/git commit -m/, "initial commit";

    if ($project_dir) {
      say STDERR 'updating project makefile';
      open my $main_mkf_fh, '>>', catfile( $project_dir, 'Makefile' ) or confess "Can't open filehandle: $!";
      say $main_mkf_fh "";
      say $main_mkf_fh "# created on $date";
      say $main_mkf_fh "$name:";
      say $main_mkf_fh "\tcd $rel_dir && \$(MAKE)";
      $main_mkf_fh->close;
    } else {
      say STDERR 'NOT updating project makefile';
    }
    say STDERR "Finished";
  }
  when ('ls') {
    my $dir = catfile( find_project_root(), $ANALYSIS_DIR );

    my @all_analysis_runs;
    confess "could not find $dir" unless ( -d $dir );

    opendir( my $dh, $dir ) || confess "could not open dir $dir";
    my @analysis_dirs = readdir($dh);
    @analysis_dirs = grep { !/^\./ && -d catfile( $dir, $_ ) } @analysis_dirs;
    closedir($dh);

    for my $ad (@analysis_dirs) {
      my $abs_ad = catfile( $dir, $ad );
      opendir( my $adh, $abs_ad ) || confess "could not open $abs_ad";
      my @runs = grep { /^\d{4}-\d\d-\d\d$/ && -d catfile( $abs_ad, $_ ) } readdir($adh);
      closedir($adh);
      push @all_analysis_runs, map { [ $ad, $_ ] } @runs;
    }
    @all_analysis_runs = sort { $a->[1] cmp $b->[1] } @all_analysis_runs;

    for my $ar (@all_analysis_runs) {
      say $ar->[1] . "    " . catfile(@$ar);
    }
  }
  when ('tag') {
    confess "no analysis version file found" unless ( -f 'av' );

    my $analysis_version = ( slurpc('av') )[0];
    my $curdir           = ( File::Spec->splitpath(fastcwd) )[2];
    say $curdir . "_" . $analysis_version;
  }
  default {
    print( $usage->text ), exit;
  }
}

sub create_readme {
  my ( $path, $name, $date ) = @_;

  say STDERR "Creating README file";
  open my $readme_fh, '>', catfile( $path, 'README' ) or confess "Can't open filehandle: $!";
  say $readme_fh uc($name);
  say $readme_fh "=" x length($name);
  say $readme_fh "";
  say $readme_fh "Joachim Bargsten <jw\@bargsten.org> ($date)";
  say $readme_fh "$name erstellt am $date.";
  say $readme_fh "\n";
  $readme_fh->close;
}

sub find_project_root {
  my $home = Bio::Gonzales::Util::Development::File::find_root(
    { location => '.', dirs => [@REQUIRED_PROJECT_DIRS], files => ['Makefile'] } );

  unless ( defined($home) ) {
    carp("Could not find project home, using current dir");
    return;
  }

  return $home;
}

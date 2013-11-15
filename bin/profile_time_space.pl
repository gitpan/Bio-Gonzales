#!/usr/bin/env perl

use warnings;
use strict;
use Time::HiRes;
use Proc::ProcessTable;
use Scalar::Util::Numeric qw/isnan isinf/;

print STDERR "$0 [poll intervall sec] [utilization log file] [end stats log file] [command] [arguments]\n"
  and exit
  unless ( @ARGV && @ARGV > 3 );

my ( $poll_intervall, $mem_log_f, $time_log_f, @cmd ) = @ARGV;
$poll_intervall *= 1000 * 1000;

my $start_time = [ Time::HiRes::gettimeofday() ];

$SIG{CHLD} = 'IGNORE';

my $pid = fork;
die "cannot fork" unless defined $pid;

if ( $pid == 0 ) {
  #child
  system(@cmd);

} else {
  #main

  local $| = 1;
  my $ppt = Proc::ProcessTable->new;

  open my $mem_log_fh, '>', $mem_log_f or die "Can't open filehandle: $!";
  print $mem_log_fh join( "\t", qw/tp time pid ppid rss vsz pcpu cmd/ ), "\n";
  my $time_point = 1;
  while ( kill( 0, $pid ) ) {
    my $t = Time::HiRes::tv_interval($start_time);
    #my $pt     = parse_ps($ENV{USER});
    my $pt = parse_ppt( $ppt->table );

    my %childs = map { $_ => 1 } subproc_ids( $pid, $pt );
    for my $p (@$pt) {
      if ( $childs{ $p->[0] } ) {
        #say STDERR "timepoint" unless(defined($time_point));
        #say STDERR "time" unless(defined($t));
        #say STDERR "process" unless((grep { defined $_ } @$p ) != @$p);
        print $mem_log_fh join( "\t", $time_point, $t, @$p ), "\n";
      }
    }
    Time::HiRes::usleep($poll_intervall);
    $time_point++;
  }
  close $mem_log_fh;

  my ( $user, $system, $child_user, $child_system ) = times;
  my $t = Time::HiRes::tv_interval($start_time);

  open my $time_log_fh, '>', $time_log_f or die "Can't open filehandle: $!";

  print $time_log_fh "wall clock time was ", Time::HiRes::tv_interval($start_time), "\n",
    "user time for $$ was $user\n",
    "system time for $$ was $system\n",
    "user time for all children was $child_user\n",
    "system time for all children was $child_system\n";

  close $time_log_fh;
}

sub parse_ps {
  my $u = shift;
  my @table = map { chomp; [ split /\s+/, $_, 6 ] } `ps --no-headers -u $u -o pid,ppid,rsz,vsz,pcpu,cmd`;
  return \@table;
}

sub parse_ppt {
  my $ppt_table = shift;
  my @table     = map {
    my $z = $_->pctcpu;
    [ $_->pid, $_->ppid, $_->rss, $_->size, ( isnan($z) || isinf($z) ? 0 : $z ), $_->exec ]
  } @$ppt_table;
  return \@table;
}

sub subproc_ids {
  my ( $pid, $procs ) = @_;
  #[ pid, parentid ]
  my @childs;
  for my $c ( grep { $_->[1] == $pid } @$procs ) {
    push @childs, $c->[0];
    push @childs, subproc_ids( $c->[0], $procs );
  }
  return @childs;
}

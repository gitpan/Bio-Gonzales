#!/usr/bin/env perl

use warnings;
use strict;

use Carp;
use Pod::Usage;
use Getopt::Long;

my %a;    # commandline %a rguments

GetOptions( \%a, 'help|h|?', 'switch-query-reference|switch|s' ) or pod2usage( -verbose => 2 );

pod2usage( -verbose => 2 ) if ( $a{help} );

my ( $coords_file, $gff_file ) = @ARGV;
pod2usage(
  -msg       => "ERROR: Coordinate file not supplied or non-existent\n",
  -verbose   => 1,
  -noperldoc => 1
) unless ( $coords_file && -f $coords_file );

use Bio::Gonzales::Feat::IO::GFF3;

my $fout = Bio::Gonzales::Feat::IO::GFF3->new( file => $gff_file, mode => '>' );

open my $coords_fh, '<', $coords_file or confess "Can't open filehandle: $!";

#fast forward to NUCMER tag
while ( <$coords_fh> !~ /^NUCMER/ ) { }

my @header;
my $i = 0;
while ( my $c = <$coords_fh> ) {
  $c =~ s/\r\n/\n/;
  chomp $c;

  #skip empty lines
  next if ( $c =~ /^\s*$/ );

  #we found the header line
  if ( $c =~ /^\[/ ) {
    $c =~ y/[]//d;
    @header = split /\t/, $c;
    next;
  }

  #skip lines that don't start with coordinates(numbers)
  next unless ( $c =~ /^\d/ );

  #split line into columns
  my @contents = split /\t/, $c;

  if ( $a{'switch-query-reference'} ) {
    #FIXME quick and dirty, reorder fields, so that seq1 => seq2 and seq2 => seq1
    @contents = @contents[ 2, 3, 0, 1, 5, 4, 6, 8, 7 ];
  }

  my %coords;
  #figure out correct orientation
  if ( $contents[0] > $contents[1] && $contents[2] > $contents[3] ) {
    %coords = ( r_range => [ 1, 0 ], strand => 1, q_range => [ 3, 2 ] );
  } elsif ( $contents[0] < $contents[1] && $contents[2] > $contents[3] ) {
    %coords = ( r_range => [ 0, 1 ], strand => -1, q_range => [ 3, 2 ] );
  } elsif ( $contents[0] < $contents[1] && $contents[2] < $contents[3] ) {
    %coords = ( r_range => [ 0, 1 ], strand => 1, q_range => [ 2, 3 ] );
  } elsif ( $contents[0] > $contents[1] && $contents[2] < $contents[3] ) {
    %coords = ( r_range => [ 1, 0 ], strand => -1, q_range => [ 2, 3 ] );
  } else {
    die "error in coordinate parsing";
  }

  my $b = create_feat( \@contents, \%coords );
  $b->id( sprintf( "align%09d", $i++ ) );
  $fout->write_feat($b);
}
$fout->close;

sub create_feat {
  my ( $c, $ranges ) = @_;

  my $qid   = $c->[8];
  my $rid   = $c->[7];
  my $score = $c->[6];

  my $strand = $ranges->{'strand'};

  my ( $qstart, $qend ) = @{$c}[ @{ $ranges->{'q_range'} } ];
  my ( $rstart, $rend ) = @{$c}[ @{ $ranges->{'r_range'} } ];

  my $f = Bio::Gonzales::Feat->new(
    seq_id     => $rid,
    source     => 'coords2gff',
    type       => 'match',
    start      => $rstart,
    end        => $rend,
    strand     => $strand,
    attributes => { Target => ["\"$qid\" $qstart $qend"], Ontology_term => ['SO:0000343'], },
  );

  return $f;
}
__END__

=head1 NAME

coords2gff.pl - convert mummer coords files to gff3 format

=head1 SYNOPSIS
    
    # store results in OUTPUT.gff3
    perl coords2gff.pl [OPTIONS] <MUMMER_ALIGNMENT.coords> <OUTPUT.gff3>

    # print results to standard output
    perl coords2gff.pl [OPTIONS] <MUMMER_ALIGNMENT.coords>
    # or
    perl coords2gff.pl [OPTIONS] <MUMMER_ALIGNMENT.coords> -

=head1 DESCRIPTION

This script converts mummer output in coords files to gff3 formatted output.

=head1 OPTIONS

Alternative option names are separated by "|".

=over 4

=item B<< --switch-query-reference|switch|s >>

Take the query (2nd sequence in the alignment) as reference and
the reference (1st sequence in the alignment) as query. Adjust coordinates
accordingly.

=item B<< --help|h|? >>

Complete help.

=back

=cut
 

=head1 SEE ALSO

L<Bio::FeatureIO>, L<Bio::SeqFeature::Generic>

=head1 AUTHOR

jw bargsten, C<< <joachim.bargsten at wur.nl> >>

=cut

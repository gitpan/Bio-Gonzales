package Bio::Gonzales::Matrix::IO;

use warnings;
use strict;
use Carp;
use Data::Dumper;
use File::Slurp qw/slurp/;
use List::MoreUtils qw/uniq/;
use Bio::Gonzales::Util qw/flatten/;

use Bio::Gonzales::Matrix::Util qw/uniq_rows/;

use 5.010;

use List::Util qw/max/;
use Bio::Gonzales::Util::File qw/open_on_demand slurpc/;

use base 'Exporter';
our ( @EXPORT, @EXPORT_OK, %EXPORT_TAGS );
our $VERSION = 0.01_01;

@EXPORT      = qw(mslurp mspew lslurp miterate hslurp lspew dict_slurp dict_spew);
%EXPORT_TAGS = ();
@EXPORT_OK   = qw(lspew xlsx_slurp xlsx_spew hspew);

sub dict_slurp {
  my ( $src, $cc ) = @_;
  carp "you have not specified key_idx and val_idx, using 0 and 1"
    unless ( $cc && exists( $cc->{key_idx} ) && exists( $cc->{val_idx} ) );

  $cc //= {};
  my %c = (
    sep     => qr/\t/,
    header  => 0,
    skip    => -1,
    comment => qr/^#/,
    key_idx => 0,
    val_idx => 1,
    %$cc
  );

  my $kidx = $cc->{key_idx};
  my $vidx = $cc->{val_idx};
  # make an array from it

  my $uniq = $cc->{uniq} // $cc->{uniq_vals} // 0;

  my ( $fh, $fh_was_open ) = open_on_demand( $src, '<' );

  my @header;
  if ( $c{header} ) {
    while ( my $raw_row = <$fh> ) {
      next if ( $c{comment} && $raw_row =~ /$c{comment}/ );

      $raw_row =~ s/\r\n/\n/;
      chomp $raw_row;
      $raw_row =~ s/$c{pre}// if ( $c{pre} );
      @header = split /$c{sep}/, $raw_row;
      last;
    }
  }

  my %map;
  my $lnum = 0;
  while (<$fh>) {
    next if ( $lnum++ <= $c{skip} );
    next if ( $c{comment} && /$c{comment}/ );
    s/\r\n/\n/;
    chomp;
    next if (/^\s*$/);

    my @r = split /$c{sep}/;

    if ($uniq) {
      $map{ $r[$kidx] } = ( ref $vidx ? [ @r[@$vidx] ] : $r[$vidx] );
    } else {
      $map{ $r[$kidx] } //= [];
      push @{ $map{ $r[$kidx] } }, ( ref $vidx ? [ @r[@$vidx] ] : $r[$vidx] );
    }
  }

  close $fh unless ($fh_was_open);
  return wantarray ? ( \%map, \@header ) : \%map;
}

sub dict_spew {
  my ( $dest, $m, $c ) = @_;

  my $uniq = $c->{uniq} // $c->{uniq_vals} // 0;

  my @flat;
  while ( my ( $k, $vv ) = each %$m ) {
    # $v => [ a, b, c] or $v => a or $v => [ [ a, b ], [c, d], ...]
    $vv = [$vv] unless ( ref $vv );
    my $vals = [ map { ref $_ ? $_ : [$_] } @$vv ];
    $vals = uniq_rows($vals) if ($uniq);
    for my $v (@$vals) {
      push @flat, [ $k, @$v ];
    }
  }
  return mspew( $dest, \@flat, $c );
}

sub mslurp {
  my ( $src, $cc ) = @_;
  my @m;

  my ( $fh, $fh_was_open ) = open_on_demand( $src, '<' );

  $cc //= {};
  my %c = (
    sep       => qr/\t/,
    header    => 0,
    skip      => -1,
    row_names => 0,
    comment   => qr/^#/,
    %$cc
  );

  my @header;
  my @row_names;

  if ( $c{header} ) {
    while ( my $raw_row = <$fh> ) {
      next if ( $c{comment} && $raw_row =~ /$c{comment}/ );

      $raw_row =~ s/\r\n/\n/;
      chomp $raw_row;
      $raw_row =~ s/$c{pre}// if ( $c{pre} );
      @header = split /$c{sep}/, $raw_row;
      last;
    }
  }

  my $lnum = 0;
  while (<$fh>) {
    next if ( $lnum++ <= $c{skip} );
    next if ( $c{comment} && /$c{comment}/ );
    s/\r\n/\n/;
    chomp;
    next if (/^\s*$/);

    my @row = split /$c{sep}/;
    push @row_names, shift @row if ( $c{row_names} );

    push @m, \@row;
  }
  close $fh unless ($fh_was_open);

  #remove first empty element of a header if same number of elements as first matrix element.
  shift @header if ( $c{header} && @m > 0 && @{ $m[0] } == @header && !$header[0] );

  if (wantarray) {
    return ( \@m, ( @header ? \@header : undef ), ( @row_names ? \@row_names : undef ) );
  } else {
    return \@m;
  }
}

sub miterate {
  my ( $src, $cc ) = @_;
  my ( $fh, $fh_was_open ) = open_on_demand( $src, '<' );

  $cc //= {};
  my %c = (
    sep     => qr/\t/,
    skip    => 0,
    comment => qr/^#/,
    %$cc
  );

  return sub {
    while (<$fh>) {

      next if ( --$c{skip} >= 0 );

      next if ( $c{comment} && /$c{comment}/ );
      s/\r\n/\n/;
      chomp;
      s/$c{pre}// if ( $c{pre} );
      next if (/^\s*$/);
      my @row = split /$c{sep}/;
      return \@row;

    }
    close $fh unless ($fh_was_open);
    return;
  };
}

sub lspew {
  my ( $dest, $l, $c ) = @_;
  my $delim = $c->{sep} // $c->{delim} // "\t";
  my ( $fh, $fh_was_open ) = open_on_demand( $dest, '>' );

  if ( ref $l eq 'HASH' ) {
    while ( my ( $k, $v ) = each %$l ) {
      if ( ref $v eq 'ARRAY' ) {
        say $fh join $delim, ( $k, @$v );
      } else {
        say $fh join $delim, ( $k, $v );
      }
    }
  } elsif ( ref $l eq 'ARRAY' ) {
    for my $v (@$l) {
      if ( ref $v eq 'ARRAY' ) {
        say $fh join $delim, @$v;
      } else {
        say $fh $v;
      }
    }

  } else {
    confess "need a reference for the list argument";
  }
  close $fh unless ($fh_was_open);

  return;
}

sub lslurp {
  my ($file) = @_;

  my @lines = slurpc($file);
  return \@lines;
}

sub hspew { return lspew(@_) }

sub hslurp {
  my ( $file, $c ) = @_;

  my $idx_col          = $c->{idx_col}    // 0;
  my $allow_duplicates = $c->{duplicates} // 0;

  my $lines = mslurp( $file, $c );
  my %data;
  for my $l (@$lines) {
    my $key = splice @$l, $idx_col, 1;
    if ($allow_duplicates) {
      $data{$key} //= [];
      push @{ $data{$key} }, $l;
    } else {
      confess if ( exists( $data{$key} ) );
      $data{$key} = $l;
    }
  }
  return \%data;
}

sub mspew {
  my ( $dest, $m, $c ) = @_;

  confess "no matrix, you need to supply a matrix of the form [ [ 1,2,3 ], [ 4,5,6 ], ... ]"
    unless ($m);

  my $header    = $c->{header}    // $c->{ids};
  my $rownames  = $c->{row_names} // $c->{rownames};
  my $square    = $c->{square};
  my $fill_rows = $c->{fill_rows} // 1;
  my $sep       = $c->{sep}       // "\t";
  my $na_value  = $c->{missing}   // $c->{na_value} // 'NA';
  my $quote_is_on = $c->{quote};

  # get the number of rows
  my $num_rows = scalar @$m;
  # find the longest column
  my $num_cols = max map { defined $_ ? scalar @$_ : -1 } @$m;

  # if the header is longer, it defines the number of cols
  $num_cols = max $num_cols, scalar @$header if ( $header && @$header > 0 );

  $rownames = $header
    if ( $header && @$header > 0 && $rownames && !ref $rownames && @$header >= @$m );

  # adjust num rows if rownames are longer than the
  $num_rows = scalar @$rownames if ( ref $rownames eq 'ARRAY' && @$rownames > $num_rows );

  if ($square) {
    $num_rows = $num_cols if ( $num_cols > $num_rows );
    $num_cols = $num_rows if ( $num_rows > $num_cols );
    #add one for the id in the first row
    $num_cols++ if ($rownames);
  }

  confess "error with rownames: not an array"
    if ( $rownames && !( ref $rownames eq 'ARRAY' && @$rownames >= @$m ) );
  confess "no matrix" unless ( defined $m );

  my ( $fh, $fh_was_open ) = open_on_demand( $dest, '>' );

  #print header if we have header
  say $fh join $sep, @{ _quote( $header, $quote_is_on, $na_value ) } if ($header);

  #iterate through rows
  for ( my $i = 0; $i < $num_rows; $i++ ) {
    my @r;
    #add rowname as first column if desired
    push @r, ( $rownames->[$i] // "no_name" ) if ($rownames);
    #add the values
    push @r, @{ $m->[$i] // [] } if ( $i < @$m );
    #fill the square if desired
    if ($square) {
      my $missing = $square - @r;
      push @r, (undef) x $missing;
    }
    #print row
    say $fh join $sep, @{ _quote( \@r, $quote_is_on, $na_value ) };
  }
  close $fh unless ($fh_was_open);
  return;
}

sub _quote {
  my ( $f, $q, $na ) = @_;
  $na = "$na" if ( $q && defined $na );
  my @fields = map {
    if ( !defined )
    {
      $na;
    } elsif ( !$q || /^\d+$/ ) {
      $_;
    } else {
      ( my $str = $_ ) =~ s/"/""/g;
      qq{"$str"};
    }
  } @{ $_[0] };
  return \@fields;
}

sub xlsx_spew {
  my ( $dest, $m, $c ) = @_;
  #eval "use Excel::Writer::XLSX";
  #die "could not load Excel::Writer::XLSX $@" if ($@);
  eval "use Excel::Writer::XLSX; 1" or confess "could not load Excel::Writer::XLSX";

  my $header   = $c->{header}    // $c->{ids};
  my $rownames = $c->{row_names} // $c->{rownames};
  my $sep      = $c->{sep}       // "\t";
  my $na_value = $c->{missing}   // $c->{na_value} // 'NA';

  $rownames = $header
    if ( $header && @$header > 0 && $rownames && !ref $rownames && @$header == @$m );

  my @table;
  #print header if we have header
  push @table, $header if ($header);

  #iterate through rows
  for ( my $i = 0; $i < @$m; $i++ ) {
    my @r;
    #add rowname as first column if desired
    push @r, $rownames->[$i] if ($rownames);
    #add the values
    push @r, @{ $m->[$i] };
    #fill the square if desired

    #print row
    push @table, [ map { $_ // $na_value } @r ];
  }

  my ( $fh, $fh_was_open ) = open_on_demand( $dest, '>' );

  my $workbook  = Excel::Writer::XLSX->new($fh);
  my $worksheet = $workbook->add_worksheet();
  $worksheet->write_col( 'A1', \@table );
  $workbook->close;
  close $fh unless ($fh_was_open);
  return;
}

sub xlsx_slurp {
  my ( $src, $cc ) = @_;
  my @m;
  #my ( $fh, $fh_was_open ) = open_on_demand( $src, '<' );

  eval "use Spreadsheet::XLSX; 1" or confess "could not load Spreadsheet::XLSX";

  my $excel = Spreadsheet::XLSX->new($src);

  my %ms;

  for my $sheet ( @{ $excel->{Worksheet} } ) {

    my $sname = $sheet->{Name};

    my @m;
    my $cells = $sheet->{Cells};
    for my $r (@$cells) {
      push @m, [ map { $_->{Val} } @$r ];
    }
    $ms{$sname} = \@m;
  }
  return \%ms;
}

1;

__END__

=head1 NAME

Bio::Gonzales::Matrix::IO - Library for simple matrix IO


=head1 SYNOPSIS

    use Bio::Gonzales::Matrix::IO qw(lspew mslurp lslurp mspew);

=head1 DESCRIPTION

Provides functions for common matrix/list IO.

=head1 SUBROUTINES

=over 4

=item B<< mspew($filename, \@matrix, \%options) >>

=item B<< mspew($filehandle, \@matrix, \%options) >>

Save the values in C<@matrix> to a C<$filename> or C<$filehandle>. C<@matrix>
is an array of arrayrefs:

    @matrix = (
        [ l11, l12, l13 ],
        [ l21, l22, l23 ],
        [ l31, l32, l33 ]
    );

Options:

=over 4

=item header / ids

Supply a header. Same as 

     mspew($file, [ \@header, @matrix ])

=item row_names

Supply row names or if not an array but true, use the header as row names

    mspew( $file, $matrix, { row_names => 1 } );                            #use header
    mspew( $file, $matrix, { row_names => [ 'row1', '...', 'rown' ] } );    #use supplied row names


=item fill_missing_cols

If a row has less columns than the longest row of the matrix, fill it up with empty strings.

=item na_value

Use this value in case undefined values are found. Default is 'NA'.

=item sep

Set a separator for the output file

=item square (default 1)

Add empty columns to fill up to a square.

=back

=item B<< $matrix_ref = mslurp($file, \%config) >>

=item B<< ($matrix_ref, $header_ref, $row_names_ref) = mslurp($file, \%config) >>

Reads in the contents of C<$file> and puts it in a array of arrayrefs.

You can set the delimiter via the configuration by supplying C<< { sep => qr/\t/ } >> as config hash.

Further options with defaults:

    %config = (
        sep => qr/\t/, # set column separator
        header => 0, # parse header
        skip => 0, # skip the first N lines (without header)
        row_names => 0, # parse row names
        comment => qr/^#/ # the comment character
    );
    
=item B<< lspew($fh_or_filename, $list, $config_options) >>

spews out a list of values to a file. It can handle filenames and filehandles,
but if you supply a handle, you have to close it on your own. The C<$list> can
be a 

=over 4

=item hash ref of array refs

results in
    keya    avalue0 avalue1
    keyb    bvalue0 bvalue1
    ...

=item hash ref

results in
    keya    valuea
    keyb    valueb
    ...

=item array ref

results in
    value0
    value1
    ...

=back

C<$config_options> is a hash ref. It can take the options:

    $config_options = {
        delim => "\t",
    };


=item B<< \%data = hslurp($file, \%config) >>

Reads the context of a file, splits the input lines acording to mslurp rules
and takes the first element as hash reference. The remaining part of the line
is stored as array reference under the key (first element). The configuration
options are the same as in mslurp.

The default behaviour can be influenced by 

  %config = (
    idx_col => 0, # set a different index column as hash key, 0-based
    has_duplicates => 0, # allow duplicate entries in the index column.
    ...
  );

If duplicates are allowed, the result data structure has the form

  %data = (
    "key1" => [
      [ elem_x, elem_y, elem_z ], 
      [ elem_x, elem_y, elem_z ], 
      ...
    ],
    "key2" => [
      [ elem_x, elem_y, elem_z ], 
      [ elem_x, elem_y, elem_z ], 
      ...
    ],
  );

If no duplicates are allowed, C<%data> has the structure

  %data = (
    "key1" => [ elem_x, elem_y, elem_z ], 
    "key2" => [ elem_x, elem_y, elem_z ], 
  );

C<hslurp> dies with stacktrace if it hits a duplicate key in the index column.

=back

=head1 SEE ALSO

=head1 AUTHOR

jw bargsten, C<< <joachim.bargsten at wur.nl> >>

=cut

package Bio::Gonzales::Align;

use Mouse;

use warnings;
use strict;

use 5.010;

our $VERSION = '0.0545'; # VERSION


has seqs => (is => 'rw', default => sub { [] });
has info => (is => 'rw', default => sub { {} });
has score => (is => 'rw', default => -1);


__PACKAGE__->meta->make_immutable;

1;

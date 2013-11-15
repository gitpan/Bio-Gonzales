use warnings;
use Test::More;
use Data::Dumper;
use IO::Scalar;

BEGIN {
  eval "use 5.010";
  plan skip_all => "perl 5.10 required for testing" if $@;

  use_ok( "Bio::Gonzales::Matrix::IO", 'miterate' );
}

my $data = <<EOD;
a\tb\tc
#d\te\tf

nix
EOD

{
  my $sh = new IO::Scalar \$data;

  my $mit = miterate($sh);
  is_deeply( $mit->(), [ 'a', 'b', 'c' ], 'first line' );
  is( $mit->()->[0], 'nix', 'second line' );
  is( $mit->(),      undef, 'last line' );

  $sh->close;
}
{
  my $sh = new IO::Scalar \$data;

  my $mit = miterate( $sh, { skip => 1 } );
  is_deeply( $mit->(), ['nix'], 'first line' );
  is( $mit->(), undef, 'second line' );

  $sh->close;
}

done_testing();


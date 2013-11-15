
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Speedy functions to manipulate biological data",
  "AUTHOR" => "Joachim Bargsten <jwb\@cpan.org>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Bio-Gonzales",
  "EXE_FILES" => [
    "bin/iof.pl",
    "bin/profile_time_space.pl",
    "bin/fachar",
    "bin/fa2sto.pl",
    "bin/fapair-identity",
    "bin/gonzlog",
    "bin/newick2phyloxml.pl",
    "bin/gonzconf",
    "bin/show-align2clustalw.pl",
    "bin/project.pl",
    "bin/favalidate",
    "bin/faformat",
    "bin/faeq-seq",
    "bin/consense_tree.pl",
    "bin/faln2phylip.pl",
    "bin/merge_fa-qual.pl",
    "bin/gffcds2seq.pl",
    "bin/farmgaps",
    "bin/faextract_by_treeleaves",
    "bin/aln2aln.pl",
    "bin/facompare",
    "bin/faextract",
    "bin/self_dot_plot.pl",
    "bin/coords2gff.pl",
    "bin/agp2fasta.pl",
    "bin/gff_to_bed.pl",
    "bin/profile_time_space.plot.R",
    "bin/headeridx.pl",
    "bin/blast2gff3.pl",
    "bin/fadiff",
    "bin/instantblast.pl",
    "bin/fagrep"
  ],
  "LICENSE" => "perl",
  "NAME" => "Bio::Gonzales",
  "PREREQ_PM" => {},
  "TEST_REQUIRES" => {
    "Test::More" => 0
  },
  "VERSION" => "0.04",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Test::More" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);




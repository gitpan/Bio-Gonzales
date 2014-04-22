
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "Speedy functions to manipulate biological data",
  "dist_author" => [
    "Joachim Bargsten <jwb\@cpan.org>"
  ],
  "dist_name" => "Bio-Gonzales",
  "dist_version" => "0.0545",
  "license" => "perl",
  "module_name" => "Bio::Gonzales",
  "recommends" => {
    "Bio::Root::Version" => 0,
    "Excel::Writer::XLSX" => 0,
    "Net::DNS" => 0,
    "Net::Domain" => 0,
    "SVG" => 0,
    "Term::ReadKey" => 0
  },
  "recursive_test_files" => 1,
  "requires" => {
    "Capture::Tiny" => 0,
    "Config::General" => 0,
    "Cwd" => 0,
    "Data::Dumper" => 0,
    "Data::Printer" => 0,
    "Data::Visitor::Callback" => 0,
    "DateTime" => 0,
    "Digest::MD5" => 0,
    "Digest::SHA1" => 0,
    "File::Copy" => 0,
    "File::Find" => 0,
    "File::Path" => 0,
    "File::Slurp" => 0,
    "File::Spec" => 0,
    "File::Temp" => 0,
    "File::Touch" => 0,
    "File::Which" => 0,
    "Getopt::Long::Descriptive" => 0,
    "HTTP::Date" => 0,
    "IO::Prompt::Tiny" => 0,
    "IO::Scalar" => 0,
    "JSON::XS" => 0,
    "List::MoreUtils" => 0,
    "Math::Combinatorics" => 0,
    "Moo" => 0,
    "Mouse" => 0,
    "MouseX::Foreign" => 0,
    "Number::Format" => 0,
    "Params::Util" => 0,
    "Path::Class" => 0,
    "Scalar::Util::Numeric" => 0,
    "Set::IntervalTree" => 0,
    "Storable" => 0,
    "String::ShellQuote" => 0,
    "Try::Tiny" => 0,
    "URI" => 0,
    "YAML::XS" => 0,
    "constant" => 0,
    "perl" => "5.010"
  },
  "script_files" => [
    "bin/iof.pl",
    "bin/fachar",
    "bin/ppt_profile_cmd_plot.R",
    "bin/gonzp",
    "bin/fa2sto.pl",
    "bin/gonz_overlap.pl",
    "bin/fapair-identity",
    "bin/gonzlog",
    "bin/newick2phyloxml.pl",
    "bin/gonzconf",
    "bin/show-align2clustalw.pl",
    "bin/ppt_profile_cmd.pl",
    "bin/favalidate",
    "bin/faformat",
    "bin/faeq-seq",
    "bin/consense_tree.pl",
    "bin/faln2phylip.pl",
    "bin/gonz_obo2dict.pl",
    "bin/gitv_tex",
    "bin/merge_fa-qual.pl",
    "bin/gonz_unmap.pl",
    "bin/gonzc",
    "bin/gffcds2seq.pl",
    "bin/farmgaps",
    "bin/faextract_by_treeleaves",
    "bin/ppt_watch_process.pl",
    "bin/aln2aln.pl",
    "bin/facompare",
    "bin/faextract",
    "bin/uniq_nodes.pl",
    "bin/self_dot_plot.pl",
    "bin/coords2gff.pl",
    "bin/agp2fasta.pl",
    "bin/gff_to_bed.pl",
    "bin/gonz_compcol.pl",
    "bin/headeridx.pl",
    "bin/blast2gff3.pl",
    "bin/fadiff",
    "bin/instantblast.pl",
    "bin/fagrep"
  ],
  "test_requires" => {
    "Test::More" => 0
  }
);


my %fallback_build_requires = (
  "Module::Build" => "0.3601",
  "Test::More" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;

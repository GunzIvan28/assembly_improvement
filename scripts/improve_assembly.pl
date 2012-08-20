#!/usr/bin/env perl

=head1 NAME

improve_assembly 

=head1 SYNOPSIS

improve_assembly - Given an assembly, some reads and optionally a reference, reduce the number of contigs and fill gaps.

=head1 DESCRIPTION

Given an assembly, some reads and optionally a reference, reduce the number of contigs and fill gaps.

=head1 CONTACT

path-help@sanger.ac.uk

=head1 METHODS

=cut

package ImproveAssembly::Main;

BEGIN { unshift( @INC, '../modules' ) }
use lib "/software/pathogen/internal/prod/lib";
use Moose;
use Getopt::Long;
use Cwd;
use Cwd 'abs_path';
use Pathogen::Scaffold::SSpace::PreprocessInputFiles;
use Pathogen::Scaffold::SSpace::Iterative;
use Pathogen::Abacas::Main;

my ( $assembly_file, $forward_reads_file, $reverse_reads_file, $insert_size, $scaffolder_exec, $abacas_exec,$gapfiller_exec, $debug,$reference, $help );

GetOptions(
    'a|assembly=s'        => \$assembly_file,
    'f|forward_fastq=s'   => \$forward_reads_file,
    'r|reverse_fastq=s'   => \$reverse_reads_file,
    'f|reference=s'       => \$reference,
    'i|insert_size=i'     => \$insert_size,
    's|scaffolder_exec=s' => \$scaffolder_exec,
    'b|abacas_exec=s'     => \$abacas_exec,
    'g|gapfiller_exec=s'  => \$gapfiller_exec,
    'd|debug'             => \$debug,
    'h|help'              => \$help,
);

( defined($assembly_file) && defined($forward_reads_file) && defined($reverse_reads_file) && ( -e $assembly_file ) && ( -e $forward_reads_file ) && ( -e $reverse_reads_file ) && !$help ) or die <<USAGE;
Usage: improve_assembly [options]
Take in an assembly in FASTA format,reads in FASTQ format, and optionally a reference and produce a a better reference using Abacas/SSpace and GapFiller.

# Improve the assembly without a reference
improve_assembly -a contigs.fa -f 123_1.fastq -r 123_2.fastq 

# Provide a reference
improve_assembly -a contigs.fa -f 123_1.fastq -r 123_2.fastq  -f my_reference.fa

# Gzipped input files are accepted
improve_assembly -a contigs.fa.gz -f 123_1.fastq.gz -r 123_2.fastq.gz

# Insert size defaults to 250 if not specified
improve_assembly -a contigs.fa -f 123_1.fastq -r 123_2.fastq -i 3000

# This help message
improve_assembly -h

USAGE

$debug           ||= 0;
$insert_size     ||= 250;
$scaffolder_exec ||= '/software/pathogen/external/apps/usr/local/SSPACE-BASIC-2.0_linux-x86_64/SSPACE_Basic_v2.0.pl';
$gapfiller_exec  ||= '/software/pathogen/external/apps/usr/local/GapFiller_v1-10_linux-x86_64/GapFiller.pl';
$abacas_exec     ||= 'abacas.pl';

my @input_files = ( $forward_reads_file, $reverse_reads_file );

my $preprocess_input_files = Pathogen::Scaffold::SSpace::PreprocessInputFiles->new(
    input_files    => \@input_files,
    input_assembly => $assembly_file,
    reference      => $reference,
);
my $process_input_files_tmp_dir_obj = $preprocess_input_files->_temp_directory_obj();

# scaffold
my $scaffolding_obj;
if(defined($reference))
{
  $scaffolding_obj = Pathogen::Abacas::Main->new(
    reference      => $preprocess_input_files->processed_reference,
    input_assembly => $preprocess_input_files->processed_input_assembly,
    abacas_exec    => $abacas_exec,
    debug          => $debug
  )->run;
}
else
{
  $scaffolding_obj = Pathogen::Scaffold::SSpace::Iterative->new(
      input_files     => $preprocess_input_files->processed_input_files,
      input_assembly  => $preprocess_input_files->processed_input_assembly,
      insert_size     => $insert_size,
      scaffolder_exec => $scaffolder_exec,
      debug           => $debug
  )->run();
}

# fill gaps
my $fill_gaps_obj = Pathogen::FillGaps::GapFiller::Iterative->new(
    input_files     => $preprocess_input_files->processed_input_files,
    input_assembly  => $scaffolding_obj->final_output_filename,
    insert_size     => $insert_size,
    gap_filler_exec => $gapfiller_exec,
    debug           => $debug,
    _output_prefix  => 'gapfilled'
)->run();

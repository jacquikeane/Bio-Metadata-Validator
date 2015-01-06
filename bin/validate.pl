#!/usr/bin/env perl

# PODNAME:  validate.pl
# ABSTRACT: validate an input file against the checklist

use strict;
use warnings;

use Carp qw( croak );
use Getopt::Long::Descriptive;
use Bio::Metadata::Validator;
use Term::ANSIColor;
use Pod::Usage;

my ( $opt, $usage ) = describe_options(
  'validate.pl %o <filename>',
  [ 'config|c=s',       'path to the configuration file that defines the checklist [required]', ],
  [ 'output|o=s',       'write the validated CSV file to this file' ],
  [ 'write-invalid|i',  'write invalid rows only' ],
  [ 'verbose-errors|v', 'show full field descriptions in validation error messages' ],
  [],
  [ 'help|h',           'print usage message' ],
);

pod2usage( { -verbose => 2, -exitval => 0 } )
  if $opt->help;

unless ( $opt->config ) {
  print STDERR "ERROR: you must supply a configuration file\n";
  exit 1;
}

my $v = Bio::Metadata::Validator->new( config_file => $opt->config );

$v->write_invalid(  $opt->write_invalid );
$v->verbose_errors( $opt->verbose_errors );

my $file = shift;
$v->validate( $file );
$v->validation_report( $file );

if ( $opt->output ) {
  $v->write_validated_file( $opt->output );
  if ( $opt->write_invalid ) {
    print "wrote only invalid rows from validated file to '" . $opt->output . "'.\n";
  }
  else {
    print "wrote validated file to '" . $opt->output . "'.\n";
  }
}

exit;

__END__

=head1 USAGE

 validate.pl [--write-invalid|-i] [--output|-o <output file] -c <configuration file> <input file>

=head1 SYNOPSIS

 bash% validate.pl -c hicf.conf manifest.csv
 'manifest.csv' is valid

=head1 DESCRIPTION

This script reads a configuration file that defines a manifest checklist.
The supplied input file is validated against that checklist and rows with
errors can be dumped to an output file

=head1 OPTIONS

=over 8

=item <input file>

Input file to be validated.

=item --config | -c

Validate the input file against this configuration file.

=item --output | -o

Write the validated rows to the specifed output file. Default is to write
all rows, both valid and invalid.

=item --write-invalid | -i

Write only invalid rows, with error messages appended, to the specified
output file.

=back

=head1 SEE ALSO

See L<Bio::Metadata::Validator> for the guts of the script

=head1 CONTACT

path-help@sanger.ac.uk

=cut


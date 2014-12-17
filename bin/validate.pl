#!/usr/bin/env perl

# PODNAME:  validate.pl
# ABSTRACT: validate an input file against the checklist

use strict;
use warnings;

use Getopt::Long::Descriptive;
use Bio::Metadata::Validator;
use Term::ANSIColor;
use Pod::Usage;

my ( $opt, $usage ) = describe_options(
  'validate.pl %o <filename>',
  [ 'config|c=s',  'path to the configuration file that defines the checklist [required]', ],
  [ 'output|o=s',  'write the validated CSV file to this file' ],
  [ 'invalid|i',   'write invalid rows only' ],
  [],
  [ 'help|h',      'print usage message' ],
);

pod2usage( { -verbose => 2, -exitval => 0 } )
  if $opt->help;

my $v = Bio::Metadata::Validator->new( config_file => $opt->config || '' );

my $file = shift;
$v->validate( $file );
$v->validation_report( $file );

if ( $opt->output ) {
  $v->write_validated_file( $opt->output, $opt->invalid );
}

exit;

__END__

=head1 NAME

validate.pl - validate a manifest against a checklist

=head1 USAGE

 validate.pl [--invalid|-i] [--output|-o <output file] -c <configuration file> <input file>

=head1 SYNOPSIS

 validate.pl -c hicf.conf manifest.csv
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
all rows, valid or invalid.

=item --invalid | -i

Write only invalid rows, with error messages appended, to the specified
output file.

=back

=head1 SEE ALSO

See L<Bio::Metadata::Validator> for the guts of the script

=head1 AUTHOR

John Tate <jt6@sanger.ac.uk>

=cut


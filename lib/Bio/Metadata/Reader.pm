
package Bio::Metadata::Reader;

# ABSTRACT: class for reading manifests

use Moose;
use namespace::autoclean;

use Text::CSV;

use Bio::Metadata::Config;
use Bio::Metadata::Manifest;

=head1 NAME

Bio::Metadata::Reader

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------

# public attributes

has 'config' => (
  is       => 'ro',
  isa      => 'Bio::Metadata::Config',
  required => 1,
);

=attr config

configuration object (L<Bio::Metadata::Config>); B<Read-only>; supply at
instantiation

=cut

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=cut

sub read_csv {
  my ( $self, $file ) = @_;

  die "ERROR: no input file given"          unless defined $file;
  die "ERROR: no such input file ('$file')" unless -e $file;

  # get the header row from the config
  my $header = substr( $self->config->{header_row} || '', 0, 20 );

  my $csv = Text::CSV->new;
  open my $fh, '<:encoding(utf8)', $file
    or die "ERROR: problems reading input CSV file: $!";

  my $manifest = Bio::Metadata::Manifest->new( config => $self->config );

  my $row_num = 0;

  ROW: while ( my $row_string = <$fh> ) {
    $row_num++;

    # try to skip the header row, if present, and blank rows
    if ( $row_num == 1 and ( $row_string =~ m/^$header/ or $row_string =~ m/^\,+$/ ) ) {
      next ROW;
    }

    # skip the empty rows that excel likes to include in CSVs
    next ROW if $row_string =~ m/^,+[\r\n]*$/;

    # the current row should now be a data row, so try parsing it
    $csv->parse($row_string)
      or die "ERROR: could not parse row $row_num\n";

    my @raw_values = $csv->fields;
    $manifest->add_row( \@raw_values );
  }

  return $manifest;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# private method

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;


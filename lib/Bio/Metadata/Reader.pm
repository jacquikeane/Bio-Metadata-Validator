
package Bio::Metadata::Reader;

# ABSTRACT: class for reading manifests

use Moose;
use namespace::autoclean;

use Text::CSV_XS;
use Digest::MD5;

use Bio::Metadata::Checklist;
use Bio::Metadata::Manifest;

=head1 NAME

Bio::Metadata::Reader

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------

# public attributes

has 'checklist' => (
  is       => 'rw',
  isa      => 'Bio::Metadata::Checklist',
  required => 1,
);

=attr checklist

A reference to a L<Bio::Metadata::Checklist> object. This checklist object will
be passed to all L<Bio::Metadata::Manifest> objects created by this reader.

Setting a new checklist after instantiation will only affect manifests created
after that point; previously generated manifests will retain their reference to
the original checklist object.

=cut

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 read_csv($file)

Reads a manifest from the given file and returns a L<Bio::Metadata::Manifest>.
As the file is read an MD5 checksum is generated and set on the
L<Bio::Metadata::Manifest|Manifest>. We rely on the
L<Bio::Metadata::Manifest|Manifest> itself to create a UUID.

=cut

sub read_csv {
  my ( $self, $file ) = @_;

  die "ERROR: no input file given"          unless defined $file;
  die "ERROR: no such input file ('$file')" unless -e $file;

  my $file_type = `file $file`;
  die 'ERROR: not a CSV file' if ( $file_type and $file_type !~ m/ASCII [\w ]*text/ );

  # get the header row from the checklist
  my $header = substr( $self->checklist->{header_row} || '', 0, 20 );

  # add a flag to Text::CSV_XS to tell it to parse blank fields in the CSV
  # as undef, rather than "". This is important because when we come to load
  # the row into a DB, DBIC needs empty fields to be undef so that they get
  # correctly translated as NULL in the SQL.
  # NOTE: this switch doesn't seem to work with Text::CSV, only with the
  # XS version.
  my $csv = Text::CSV_XS->new( { blank_is_undef => 1 } );
  open my $fh, '<:encoding(utf8)', $file
    or die "ERROR: problems reading input CSV file: $!";

  my $manifest = Bio::Metadata::Manifest->new( checklist => $self->checklist );

  # calculate an MD5 digest for the file
  my $digest = Digest::MD5->new;
  $digest->addfile($fh);
  $manifest->md5( $digest->hexdigest );

  # rewind the file after calculating the digest, so that we can read its
  # contents
  seek $fh, 0, 0
    or die "ERROR: couldn't rewind input file for reading";

  my $file_contents = join '', <$fh>;
  $file_contents =~ s/\r\n/\r/g;
  $file_contents =~ s/\r/\n/g;

  my @file_rows = split m/\n/, $file_contents;

  my $row_num = 0;

  ROW: foreach my $row_string ( @file_rows ) {
    chomp $row_string;

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


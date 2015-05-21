
package Bio::Metadata::Manifest;

# ABSTRACT: class for working with manifest metadata

use Moose;
use namespace::autoclean;

use File::Slurp qw( write_file );
use Data::UUID;
use FileHandle;
use Carp qw( croak );
use Text::CSV_XS;
use Bio::Metadata::Types qw( MD5 UUID );
use MooseX::Types::Moose qw( ArrayRef Str );

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------

# public attributes

has 'checklist' => (
  is       => 'ro',
  isa      => 'Bio::Metadata::Checklist',
  required => 1,
  handles  => [ 'field_names', 'fields' ],
);

has 'rows' => (
  traits  => ['Array'],
  is      => 'rw',
  isa     => ArrayRef[ArrayRef],
  default => sub { [] },
  handles => {
    add_rows   => 'push',
    add_row    => 'push',
    next_row   => 'shift',
    all_rows   => 'elements',
    get_row    => 'get',
    row_count  => 'count',
  },
);

has 'row_errors' => (
  traits  => ['Array'],
  is      => 'rw',
  isa     => ArrayRef[Str],
  default => sub { [] },
  handles => {
    all_row_errors => 'elements',
    get_row_error  => 'get',
    set_row_error  => 'set',
    reset          => 'clear',
  },
);

has 'md5' => ( is => 'rw', isa => MD5 );
has 'uuid' => ( is => 'rw', isa => UUID );
has 'filename' => ( is => 'ro', isa => Str );

=attr checklist

checklist object (L<Bio::Metadata::Checklist>); B<Read-only>; specify at
instantiation

=attr rows

reference to an array containing the rows in this manifest

=attr row_errors

reference to an array containing the error messages for the invalid rows in
this manifest. The rows errors are inserted at the same position as the
corresponding invalid row, meaning that this array will have C<undef> at
positions where the original row is valid.

=attr md5

MD5 checksum value for the file from which the manifest was loaded.

=attr uuid

a UUID, as generated using L<Data::UUID>, for this manifest.

=attr filename

name of the file from which the manifest was loaded; B<Read-only>; specify
at instantiation.

B<Note> that the filename is only stored on the object. Use L<add_row> to add
rows to the manifest.

=cut

# private attributes

has '_csv' => (
  is      => 'ro',
  isa     => 'Text::CSV_XS',
  writer  => '_set_csv', # for testing
  default => sub {
    my $csv = Text::CSV_XS->new;
    $csv->eol("\n");
    return $csv;
  },
);

has '_fh' => (
  is      => 'ro',
  isa     => 'FileHandle',
  writer  => '_set_fh', # for testing
  default => sub { FileHandle->new },
);

#-------------------------------------------------------------------------------
#- construction ----------------------------------------------------------------
#-------------------------------------------------------------------------------

sub BUILD {
  my $self = shift;

  # if a UUID wasn't passed in when the object was created, generate one now
  $self->uuid( Data::UUID->new->create_str ) unless defined $self->uuid;
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 add_rows($row1, $row2, ...)

Add one or more rows to the manifest. C<$row> should be a reference to a list
of field values.

=head2 add_row($row)

Add a single row to the manifest.

=head2 all_rows

Returns all of the rows in the manifest as an array (as opposed to an array
ref).

=head2 get_row

Returns a reference to the specified row array.

=head2 next_row

Shifts off the next row in the list of rows. Reduces the number of rows in
the manifest by 1.

=head2 row_count

Returns the number of rows in the manifest.

=head2 all_row_errors

Returns all of the error messages for invalid rows in the manifest as an array
(as opposed to an array ref).

=head2 get_row_error($index)

Returns the error message for the specified row, or C<undef> if there is no
error for the specified row. Note that the row index is zero-based when calling
this method, i.e. the first row in the manifest is 0, not 1.

=head2 set_row_error($index, $err_msg)

Adds the given error message for the specified row. Note that the row index is
zero-based when calling this method, i.e. the first row in the manifest is 0,
not 1.

=head2 reset

Resets the manifest by deleting the error messages for invalid rows.

=head2 invalid_row_count

Returns the number of invalid rows in the manifest. Note that this is different
to the number of rows in the array containing the invalid rows, since there will
be empty slots corresponding to the valid rows in the original array.

=cut

sub invalid_row_count {
  my $self = shift;

  my $count = 0;
  foreach my $row ( @{$self->row_errors} ) {
    $count++ if defined $row;
  }
  return $count;
}

=head2 has_invalid_rows

Returns 1 if the manifest contains invalid rows, 0 otherwise

=cut

sub has_invalid_rows {
  return shift->invalid_row_count ? 1 : 0;
}

=head2 is_invalid

Alias for L<has_invalid_rows>.

=cut

sub is_invalid { shift->has_invalid_rows }

#-------------------------------------------------------------------------------

=head2 get_csv($invalid_only)

Returns the current manifest in CSV format as a string. If C<$invalid_only> is
set to true, only invalid rows will be included. The header row will always be
included as the first line of the CSV string.

=cut

sub get_csv {
  my ( $self, $invalid_only ) = @_;

  my $csv_string = '';

  my $rows = $self->_get_csv_rows($invalid_only);
  foreach my $row ( @$rows ) {
    $self->_csv->combine(@$row);
    $csv_string .= $self->_csv->string;
  }

  return $csv_string;
}

#-------------------------------------------------------------------------------

=head2 write_csv($filename, $invalid_only)

Writes the current manifest as a CSV file with the specified filename. If
C<$invalid_only> is set to true, only invalid rows will be written to the
file.

=cut

sub write_csv {
  my ( $self, $filename, $invalid_only ) = @_;

  $self->_fh->open($filename, '>')
    or croak "ERROR: couldn't open output file for write: $!";

  my $rows = $self->_get_csv_rows($invalid_only);
  $self->_csv->print( $self->_fh, $_ ) for @$rows;

  $self->_fh->close;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# Returns a references to an array containing the rows in the manifest. Each
# row is given as a reference to an array containing the column values. If
# C<$invalid_only> is set to true, only invalid rows will be included. The
# header row will always be included as the first row of the array.

sub _get_csv_rows {
  my ( $self, $invalid_only ) = @_;

  # put the header line into the output CSV first
  my @rows = ();

  my @header_row = split ',', $self->checklist->get('header_row');
  push @rows, \@header_row if defined scalar @header_row;

  my $n = 0;
  foreach my $original_row ( $self->all_rows ) {

    # take a copy of the row array, so that we're not altering it if we push
    # in error messages
    my @row = @$original_row;

    # append any error messages to the row
    my $row_error = $self->get_row_error($n);
    push @row, $row_error if $row_error;

    if ( $invalid_only ) {
      push @rows, \@row if $row_error;
    }
    else {
      push @rows, \@row;
    }

    $n++;
  }

  return \@rows;
}

# sub get_csv_rows {
#   my ( $self, $invalid_only ) = @_;
#
#   # put the header line into the output CSV first
#   my @rows = ();
#
#   push @rows, $self->checklist->get('header_row')
#     if defined $self->checklist->get('header_row');
#
#   my $n = 0;
#   foreach my $row ( $self->all_rows ) {
#     my $row_string;
#     # turn off warnings before trying to join an array with undefs
#     {
#       no warnings;
#       $row_string = join ',', @$row;
#     }
#
#     # append any error messages to the row
#     my $invalid_row = $self->get_row_error($n);
#     $row_string .= ",$invalid_row" if $invalid_row;
#
#     if ( $invalid_only ) {
#       push @rows, $row_string if $invalid_row;
#     }
#     else {
#       push @rows, $row_string;
#     }
#
#     $n++;
#   }
#
#   return @rows;
# }

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

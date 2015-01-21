
package Bio::Metadata::Manifest;

# ABSTRACT: class for working with manifest metadata

use Moose;
use namespace::autoclean;

use File::Slurp qw( write_file );

=head1 NAME

Bio::Metadata::Manifest

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------

# public attributes

=attr config

configuration object (L<Bio::Metadata::Config>); B<Read-only>; specify at
instantiation

=cut

has 'config' => (
  is       => 'ro',
  isa      => 'Bio::Metadata::Config',
  required => 1,
  handles  => [ 'field_names', 'fields' ],
);

=attr rows

reference to an array containing the rows in this manifest

=cut

has 'rows' => (
  traits  => ['Array'],
  is      => 'rw',
  isa     => 'ArrayRef[ArrayRef]',
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

=attr invalid_rows

reference to an array containing the invalid rows in this manifest. The invalid
rows are inserted at the same position in the original array, meaning that this
array will have C<undef> at positions where the original row is valid.

=cut

has 'invalid_rows' => (
  traits  => ['Array'],
  is      => 'rw',
  isa     => 'ArrayRef[ArrayRef]',
  default => sub { [] },
  handles => {
    all_invalid_rows => 'elements',
    get_invalid_row  => 'get',
    set_invalid_row  => 'set',
    reset            => 'clear',
  },
);

=attr filename

name of the file from which the manifest was loaded; B<Read-only>; specify
at instantiation.

B<Note> that the filename is only stored on the object. Use L<add_row> to add
rows to the manifest.

=cut

has 'filename' => ( is => 'ro', isa => 'Str' );

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

=head2 add_invalid_row($row)

Adds an invalid row to the manifest. The C<$row> should be a reference to a
list of field values.

=head2 all_invalid_rows

Returns all of the invalid rows in the manifest as an array (as opposed to
an array ref).

=head2 get_invalid_row($index)

Returns a reference to the specified invalid row array. Note that the row index
is zero-based when calling this method, i.e. the first row in the manifest is
0, not 1.

=head2 set_invalid_row($index, $row)

Sets the specified row in the list of invalid rows in this manifest. Note that
the row index is zero-based when calling this method, i.e. the first row in the
manifest is 0, not 1.

=head2 reset

Deletes the validated and invalid rows from the manifest.

=head2 invalid_row_count

Returns the number of invalid rows in the manifest. Note that this is different
to the number of rows in the array containing the invalid rows, since there will
be empty slots corresponding to the valid rows in the original array.

=cut

sub invalid_row_count {
  my $self = shift;

  my $count = 0;
  foreach my $row ( @{$self->invalid_rows} ) {
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

=head2 write_csv($filename, $invalid_only)

Writes the current manifest as a CSV file with the specified filename. If
C<$invalid_only> is set to true, only invalid rows will be written to the
file.

=cut

sub write_csv {
  my ( $self, $filename, $invalid_only ) = @_;

  my @rows = ( $self->config->get('header_row') . "\n" );

  if ( $invalid_only ) {
    foreach my $row ( $self->all_invalid_rows ) {
      next unless defined $row;
      push @rows, join(',', @$row) . "\n";
    }
  }
  else {
    my $n = 0;
    foreach my $row ( $self->all_rows ) {
      my $row_string = join ',', @$row;

      # interleave the invalid rows
      if ( my $invalid_row = $self->get_invalid_row($n) ) {
        # append the error message to the CSV row string
        $row_string .= ',' . $invalid_row->[-1];
      }

      push @rows, "$row_string\n";
      $n++;
    }
  }

  write_file( $filename, @rows );
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

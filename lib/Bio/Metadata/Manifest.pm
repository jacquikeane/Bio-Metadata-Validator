
package Bio::Metadata::Manifest;

# ABSTRACT: class for working with manifest metadata

use Moose;
use namespace::autoclean;

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
);

=attr rows

reference to the list of the rows in this manifest

=cut

has 'rows' => (
  traits  => ['Array'],
  is      => 'rw',
  isa     => 'ArrayRef[ArrayRef]',
  default => sub { [] },
  handles => {
    add_row    => 'push',
    next_row   => 'shift',
    all_rows   => 'elements',
    get_row    => 'get',
    row_count  => 'count',
  },
);

=attr invalid_rows

reference to the list of the invalid rows in this manifest

=cut

has 'invalid_rows' => (
  traits  => ['Array'],
  is      => 'rw',
  isa     => 'ArrayRef[ArrayRef]',
  default => sub { [] },
  handles => {
    add_invalid_row    => 'push',
    next_invalid_row   => 'shift',
    all_invalid_rows   => 'elements',
    get_invalid_row    => 'get',
    invalid_row_count  => 'count',
    has_invalid_rows   => 'count',
    reset              => 'clear',
    is_invalid         => 'count',
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

=head2 add_row

Add a row to the manifest. The C<$row> should be a reference to a list of
field values.

=head2 all_rows

Returns a list of all rows in the manifest.

=head2 get_row

Returns a reference to the specified row array.

=head2 next_row

Shifts off the next row in the list of rows. Reduces the number of rows in
the manifest by 1.

=head2 row_count

Returns the number of rows in the manifest.

=head2 add_invalid_row

Adds an invalid row to the manifest. The C<$row> should be a reference to a
list of field values.

=head2 all_invalid_rows

Returns a list of all invalid rows in the manifest.

=head2 get_invalid_row

Returns a reference to the specified invalid row array.

=head2 next_invalid_row

Shifts off the next invalid row in the list of invalid rows. Reduces the number
of rows in the manifest by 1.

=head2 invalid_row_count

Returns the number of invalid rows in the manifest.

=head2 has_invalid_rows

Returns 1 if the manifest contains invalid rows, 0 otherwise

=head2 reset

Deletes the validated and invalid rows from the manifest.

=cut

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

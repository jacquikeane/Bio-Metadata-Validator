
package Bio::Metadata::TaxonomyLoader;

# ABSTRACT: class for reading and loading NCBI taxonomy tree dumps

use Moose;
use namespace::autoclean;
use Moose::Util::TypeConstraints;

use Carp qw( croak );
use Tree::Simple;

use Bio::Metadata::Types;

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------

# public attributes

=attr names

scalar containing a path to the "names.dmp" file from the NCBI taxdump, or an
open L<FileHandle> for it.

=cut

has 'names' => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

# has '_names' => (
#   is       => 'rw',
#   isa      => 'ArrayRef[Maybe[HashRef]]',
# );

#---------------------------------------

=attr nodes

scalar containing a path to the "nodes.dmp" file from the NCBI taxdump, or an
open L<FileHandle> for it.

=cut

has 'nodes' => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has '_nodes' => (
  is       => 'rw',
  isa      => 'ArrayRef[Maybe[Tree::Simple]]',
);

#---------------------------------------

has 'tree' => (
  is     => 'ro',
  isa    => 'Tree::Simple',
  writer => '_set_tree',
);

#-------------------------------------------------------------------------------
#- construction ----------------------------------------------------------------
#-------------------------------------------------------------------------------

sub BUILD {
  my $self = shift;

  # fail fast; we're done here if we can't open the files...
  open ( NAMES, $self->names )
    or croak 'ERROR: failed to open names file (' . $self->names . "): $!";
  open ( NODES, $self->nodes )
    or croak 'ERROR: failed to open nodes file (' . $self->nodes . "): $!";

  # parse the names into a simple array of hashe
  my $names = [];
  while ( <NAMES> ) {
    s/\t\|\n$//; # tidy up the line terminator (<tab>|)
    my @fields = split m/\t\|\t/;
    next unless $fields[3] eq 'scientific name';
    $names->[$fields[0]] = {
      name        => $fields[1],
      unique_name => $fields[2],
    };
  }

  # parse each of the nodes into a Tree::Simple object, mapping the names in as
  # we go
  my $nodes;
  while ( <NODES> ) {
    s/\t\|\n$//; # tidy up the line terminator (<tab>|)
    my @fields = split m/\t\|\t/;
    my $tax_id = $fields[0];
    $nodes->[$tax_id] = Tree::Simple->new( {
      tax_id        => $tax_id,
      parent_tax_id => $fields[1],
      rank          => $fields[2],
      name          => $names->[$tax_id]->{name},
    } );
  }
  $self->_nodes( $nodes );
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub build_tree {
  my $self = shift;

  # walk the list of nodes and append each one to its parent node
  my $root;
  NODE: for ( my $tax_id = 1; $tax_id < scalar @{ $self->_nodes }; $tax_id++ ) {
    my $node = $self->_nodes->[$tax_id];

    next unless defined $node;

    my $parent_tax_id = $node->getNodeValue->{parent_tax_id};

    if ( $parent_tax_id eq $tax_id ) {
      $root = $node;
      next NODE;
    }

    $self->_nodes->[$parent_tax_id]->addChild( $node );
  }

  $self->_set_tree( $root );
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

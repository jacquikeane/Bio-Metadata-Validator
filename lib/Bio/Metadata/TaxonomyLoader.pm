
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

=attr names_file

scalar containing a path to the "names.dmp" file from the NCBI taxdump, or an
open L<FileHandle> for it. B<Read-only>; supply at instantiation.

=cut

has 'names_file' => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

#---------------------------------------

=attr nodes_file

scalar containing a path to the "nodes.dmp" file from the NCBI taxdump, or an
open L<FileHandle> for it. B<Read-only>; supply at instantiation.

=cut

has 'nodes_file' => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

#---------------------------------------

=attr nodes

reference to an array containing the nodes of the tree, indexed by tax ID. Each
node is a L<Tree::Simple> object. B<Note> that because there is (or shouldn't
be) a node in the taxonomy tree with tax ID zero, the first slot of the array
returned by C<$tree->nodes> will be empty. B<Read-only>.

=cut

has 'nodes' => (
  is       => 'ro',
  isa      => 'ArrayRef[Maybe[Tree::Simple]]',
  writer   => '_set_nodes',
);

#---------------------------------------

=attr tree

reference to the L<Tree::Simple> object that represents the root node of the
tree.

=cut

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
  open ( NAMES, $self->names_file )
    or croak 'ERROR: failed to open names file (' . $self->names_file . "): $!";
  open ( NODES, $self->nodes_file )
    or croak 'ERROR: failed to open nodes file (' . $self->nodes_file . "): $!";

  # parse the names into a simple array of hashes, indexed on tax ID
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

  # parse each of the rows in the nodes file into a Tree::Simple object,
  # mapping the names in as we go. Store them in an array, indexed on tax ID
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

  $self->_set_nodes( $nodes );
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 build_tree

Constructs a L<Tree::Simple>-based tree from the nodes loaded from the names
and nodes files. Returns a reference to the object representing the root node.

Each node of the tree is a L<Tree::Simple> object. The "value" of the node is
a hash containing the following keys:

=over 2

=item name

the name of the node in the taxonomic tree represented by this L<Tree::Simple>
object

=item tax_id / parent_tax_id

the taxonomy ID for the node and its parent node. If the node is the root node,
C<tax_id> == C<parent_tax_id>.

=item rank

the taxonomic rank for the node

=item lft / rgt

"left" and "right" values for the node. These can be used for modified
pre-order tree traversal (see
L<http://www.sitepoint.com/hierarchical-data-database-2/>).

=over

=cut

sub build_tree {
  my $self = shift;

  # walk the list of nodes and append each one to its parent node
  my $root;
  NODE: for ( my $tax_id = 1; $tax_id < scalar @{ $self->nodes }; $tax_id++ ) {
    my $node = $self->nodes->[$tax_id];

    next unless defined $node;

    my $parent_tax_id = $node->getNodeValue->{parent_tax_id};

    if ( $parent_tax_id eq $tax_id ) {
      $root = $node;
      next NODE;
    }

    $self->nodes->[$parent_tax_id]->addChild( $node );
  }

  # the root node that we have in $root is the root node of the taxonomic tree,
  # but we need to append it to a new Tree::Simple root, otherwise the tree
  # walking steps later will miss it out
  my $tree = Tree::Simple->new($root);
  $tree->addChild( $root );

  # walk down each branch and number lefts and rights
  my $count = 1;
  $tree->traverse(
    sub { shift->getNodeValue->{lft} = $count++ },
    sub { shift->getNodeValue->{rgt} = $count++ },
  );

  # store the root node and return it
  $self->_set_tree( $tree );

  return $tree;
}

#-------------------------------------------------------------------------------

sub get_node_values {
  my ( $self, $in_tree_order ) = @_;

  my @rows = [];

  if ( $in_tree_order ) {
    # return the nodes in tree traversal-order
    $self->tree->traverse( sub {
      my $node = shift;
      my $v = $node->getNodeValue;
      push @rows, [
        $v->{tax_id},
        $v->{name},
        $v->{lft},
        $v->{rgt},
        $v->{parent_tax_id},
      ];
    } );
  }
  else {
    # return the nodes in the order in which they were read from the names.dmp
    # file
    foreach my $node ( @{ $self->nodes } ) {
      next unless defined $node; # skip empty first slot in list of nodes
      my $v = $node->getNodeValue;
      push @rows, [
        $v->{tax_id},
        $v->{name},
        $v->{lft},
        $v->{rgt},
        $v->{parent_tax_id},
      ];
    }
  }

  return \@rows;
}

#-------------------------------------------------------------------------------

sub load_tree {
  my $self = shift;

  $self->tree->traverse( sub {
    my $node = shift;
    my $v = $node->getNodeValue;
    print join( " | ",
      $v->{tax_id},
      $v->{name},
      $v->{lft},
      $v->{rgt},
      $v->{parent_tax_id} ), "\n";
  } );

}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------

=head1 SEE ALSO

L<Tree::Simple>

=cut

__PACKAGE__->meta->make_immutable;

1;

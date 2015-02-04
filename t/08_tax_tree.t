#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Bio::Metadata::TaxTree

use_ok('Bio::Metadata::TaxTree');

my $tl;

throws_ok { $tl = Bio::Metadata::TaxTree->new }
  qr/Attribute \(names_file\) is required/, 'error when instantiating with no arguments';
throws_ok { $tl = Bio::Metadata::TaxTree->new( names_file => 'nonexistent', nodes_file => 't/data/08_nodes.dmp' ) }
  qr/failed to open names file/, 'error when instantiating with non-existent names file';
throws_ok { $tl = Bio::Metadata::TaxTree->new( names_file => 't/data/08_names.dmp', nodes_file => 'nonexistent' ) }
  qr/failed to open nodes file/, 'error when instantiating with non-existent nodes file';

lives_ok { $tl = Bio::Metadata::TaxTree->new( names_file => 't/data/08_names.dmp', nodes_file => 't/data/08_nodes.dmp' ) } 'no error when instantiating with valid params';

is( scalar @{ $tl->nodes }, 13, 'correct number of nodes in _nodes' );
is( $tl->nodes->[0], undef, 'first slot in _nodes list is empty' );

isa_ok( $tl->nodes->[1], 'Tree::Simple', 'first node' );
is( $tl->nodes->[1]->getNodeValue->{name}, 'root node', 'found root node' );
is( $tl->nodes->[12]->getNodeValue->{name}, 'leaf 5', 'found last leaf node' );

ok( $tl->build_tree, 'tree builds ok' );

isa_ok( $tl->tree, 'Tree::Simple', 'tree' );

my $root = $tl->tree->getChild(0);
my $node;
lives_ok { $node = $root->getChild(2)->getChild(1)->getChild(0) }
  'got a Tree::Simple object at the expected node';
is( $node->getNodeValue->{name}, 'leaf 2', 'found leaf 2 at expected node' );

my $node_two = {
  name          => 'node two',
  lft           => 2,
  rgt           => 5,
  tax_id        => 2,
  parent_tax_id => 1,
  rank          => 'kingdom',
};

is_deeply( $root->getChild(0)->getNodeValue, $node_two, 'test node has expected data' );

is( $root->getNodeValue->{lft},  1, 'root node has lft == 1' );
is( $root->getNodeValue->{rgt}, 24, 'root node has rgt == 24' );

my $nodes = $tl->get_node_values;
is_deeply( $nodes->[0], [ 1, 'root node', 1, 24, 1 ], '"get_node_values" returns root node as expected' );
is_deeply( $nodes->[11], [ 12, 'leaf 5', 3, 4, 2 ], '"get_node_values" returns last node as expected' );

$nodes = $tl->get_node_values(1);
is_deeply( $nodes->[0], [ 1, 'root node', 1, 24, 1 ], '"get_node_values(1)" returns root node as expected' );
is_deeply( $nodes->[11], [ 10, 'leaf 3', 21, 22, 5 ], '"get_node_values(1)" returns last node as expected' );

$DB::single = 1;

done_testing;

__END__

# loaded tree should look like:
tree
└── one
    ├── five
    │   └── leaf_3
    ├── four
    │   ├── seven
    │   │   └── leaf_2
    │   └── six
    │       └── leaf_1
    ├── three
    │   └── leaf_4
    └── two
        └── leaf_5

# print the tree with:
$tl->tree->traverse(sub{my $t=shift;print ( ("\t" x $t->getDepth ) ,$t->getNodeValue->{name},"\n")})

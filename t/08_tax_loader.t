#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use File::Temp;
use File::Slurp qw( read_file );

use Bio::Metadata::TaxonomyLoader

use_ok('Bio::Metadata::TaxonomyLoader');

my $tl;

throws_ok { $tl = Bio::Metadata::TaxonomyLoader->new }
  qr/Attribute \(names\) is required/, 'error when instantiating with no arguments';
throws_ok { $tl = Bio::Metadata::TaxonomyLoader->new( names => 'nonexistent', nodes => 't/data/08_nodes.dmp' ) }
  qr/failed to open names file/, 'error when instantiating with non-existent names file';
throws_ok { $tl = Bio::Metadata::TaxonomyLoader->new( names => 't/data/08_names.dmp', nodes => 'nonexistent' ) }
  qr/failed to open nodes file/, 'error when instantiating with non-existent nodes file';

lives_ok { $tl = Bio::Metadata::TaxonomyLoader->new( names => 't/data/08_names.dmp', nodes => 't/data/08_nodes.dmp' ) } 'no error when instantiating with valid params';

is( scalar @{ $tl->_nodes }, 13, 'correct number of nodes in _nodes' );
is( $tl->_nodes->[0], undef, 'first slot in _nodes list is empty' );

isa_ok( $tl->_nodes->[1], 'Tree::Simple', '_nodes contains Tree::Simple objects' );
is( $tl->_nodes->[1]->getNodeValue->{name}, 'root node', 'found root node' );
is( $tl->_nodes->[12]->getNodeValue->{name}, 'leaf 5', 'found last leaf node' );

ok( $tl->build_tree, 'tree builds ok' );

isa_ok( $tl->tree, 'Tree::Simple', '"tree" methods returns Tree::Simple object' );

my $node;
lives_ok { $node = $tl->tree->getChild(2)->getChild(1)->getChild(0) }
  'got a Tree::Simple object at the expected node';
is( $node->getNodeValue->{name}, 'leaf 2', 'node is leaf 2, as expected' );


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

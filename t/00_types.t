
use strict;
use warnings;

use Test::More;
use Test::Exception;

use_ok('Bio::Metadata::Types');

package Test::TypeTester;

use Moose;
use Bio::Metadata::Types;
use namespace::autoclean;

has md5  => ( is => 'rw', isa => 'Bio::Metadata::Types::MD5' );
has uuid => ( is => 'rw', isa => 'Bio::Metadata::Types::UUID' );
has amr  => ( is => 'rw', isa => 'Bio::Metadata::Types::AntimicrobialName' );
has sir  => ( is => 'rw', isa => 'Bio::Metadata::Types::SIRTerm' );

package main;

use_ok( 'Test::TypeTester', 'test module works' );

my $tt;
ok( $tt = Test::TypeTester->new, 'got a new test module ok' );

lives_ok { $tt->md5('8fb372b3d14392b8a21dd296dc7d9f5a') } 'can set valid MD5';
throws_ok { $tt->md5('x') } qr/Not a valid MD5/, 'exception with invalid MD5';

lives_ok { $tt->uuid('4162F712-1DD2-11B2-B17E-C09EFE1DC403') } 'can set valid UUID';
throws_ok { $tt->uuid('x') } qr/Not a valid UUID/, 'exception with invalid UUID';

lives_ok { $tt->amr('am1') } 'can set valid antimicrobial name';
throws_ok { $tt->amr('am#') } qr/Not a valid anti/, 'exception with invalid amr';

lives_ok { $tt->sir('S') } 'can set valid SIR term';
throws_ok { $tt->sir('X') } qr/Not a valid susc/, 'exception with invalid sir';

done_testing();


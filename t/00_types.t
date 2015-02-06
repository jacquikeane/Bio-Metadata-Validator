
use strict;
use warnings;

use Test::More;
use Test::Exception;

use_ok('Bio::Metadata::Types');

package Test::TypeTester;

use Moose;
use namespace::autoclean;

use Bio::Metadata::Types;

has md5  => ( is => 'rw', isa => 'Bio::Metadata::Types::MD5' );
has uuid => ( is => 'rw', isa => 'Bio::Metadata::Types::UUID' );
has sir  => ( is => 'rw', isa => 'Bio::Metadata::Types::SIRTerm' );
has am   => ( is => 'rw', isa => 'Bio::Metadata::Types::AntimicrobialName' );
has amr  => ( is => 'rw', isa => 'Bio::Metadata::Types::AMRString' );

package main;

use_ok( 'Test::TypeTester', 'test module works' );

my $tt;
ok( $tt = Test::TypeTester->new, 'got a new test module ok' );

lives_ok { $tt->md5('8fb372b3d14392b8a21dd296dc7d9f5a') } 'can set valid MD5';
throws_ok { $tt->md5('x') } qr/Not a valid MD5/, 'exception with invalid MD5';

lives_ok { $tt->uuid('4162F712-1DD2-11B2-B17E-C09EFE1DC403') } 'can set valid UUID';
throws_ok { $tt->uuid('x') } qr/Not a valid UUID/, 'exception with invalid UUID';

lives_ok { $tt->sir('S') } 'can set valid SIR term';
throws_ok { $tt->sir('X') } qr/Not a valid susc/, 'exception with invalid sir';

lives_ok { $tt->am('am1') } 'can set valid antimicrobial name';
throws_ok { $tt->am('am#') } qr/Not a valid anti/, 'exception with invalid amr';

lives_ok { $tt->amr('am1;S;10') } 'can set valid antimicrobial resistance result';
lives_ok { $tt->amr('am1;S;10;WTSI,am2;I;20,am3;R;30') } 'can set valid multi-term amr';
throws_ok { $tt->amr('am#') } qr/Not a valid antimicrobial resistance/, 'exception with invalid amr';
throws_ok { $tt->amr('am1;X;20') } qr/Not a valid antimicrobial resistance/, 'exception with invalid amr';
throws_ok { $tt->amr('am1;S;a') } qr/Not a valid antimicrobial resistance/, 'exception with invalid amr';

TODO: {
  todo_skip 'amr regex needs to catch invalid amr strings after a comma', 1;
  throws_ok { $tt->amr('am1;S;10,am2;') } qr/Not a valid antimicrobial resistance/, 'exception with invalid amr';
}

done_testing();

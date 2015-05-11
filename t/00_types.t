
use strict;
use warnings;

use Test::More tests => 22;
use Test::Exception;

BEGIN { use_ok('Bio::Metadata::Types', qw(MD5 UUID SIRTerm AntimicrobialName AMRString OntologyTerm) ); }

package Test::TypeTester;

use Moose;
use namespace::autoclean;

BEGIN { use Bio::Metadata::Types qw(MD5 UUID SIRTerm AntimicrobialName AMRString OntologyTerm); }

has md5  => ( is => 'rw', isa => MD5 );
has uuid => ( is => 'rw', isa => UUID );
has sir  => ( is => 'rw', isa => SIRTerm );
has am   => ( is => 'rw', isa => AntimicrobialName );
has amr  => ( is => 'rw', isa => AMRString );
has ot   => ( is => 'rw', isa => OntologyTerm );

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
lives_ok { $tt->amr('am1;I;ge20') } 'can set single amr with equality';
lives_ok { $tt->amr('am1;S;10;WTSI,am2;I;lt20,am3;R;30') } 'can set valid multi-term amr with equality';
throws_ok { $tt->amr('am#') } qr/Not a valid antimicrobial resistance/, 'exception with invalid amr';
throws_ok { $tt->amr('am1;X;20') } qr/Not a valid antimicrobial resistance/, 'exception with invalid amr';
throws_ok { $tt->amr('am1;S;a') } qr/Not a valid antimicrobial resistance/, 'exception with invalid amr';
throws_ok { $tt->amr('am1;S;xx20') } qr/Not a valid antimicrobial resistance/, 'exception with invalid amr';

TODO: {
  todo_skip 'amr regex needs to catch invalid amr strings after a comma', 1;
  throws_ok { $tt->amr('am1;S;10,am2;') } qr/Not a valid antimicrobial resistance/, 'exception with invalid amr';
}

lives_ok { $tt->ot('ABC:123456') } 'can set valid ontology term';
throws_ok { $tt->ot('ABC') } qr/Not a valid ontology term/, 'exception with invalid ontology term';

done_testing;


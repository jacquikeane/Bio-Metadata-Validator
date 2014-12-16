#!env perl

# PODNAME:  validate.pl
# ABSTRACT: validate an input file against the checklist

use strict;
use warnings;

use Bio::Metadata::Validator;

my $v = Bio::Metadata::Validator->new_with_options;

my $file = shift;
print $file;

$v->validate($file);


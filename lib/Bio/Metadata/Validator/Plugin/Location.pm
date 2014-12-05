package Bio::Metadata::Validator::Plugin::Location;

use Moose;
use namespace::autoclean;

with 'MooseX::Role::Pluggable::Plugin';

sub validate {
  my ( $self, $value, $field_definition ) = @_;

  die 'ERROR: the Location validator requires an ontology'
    unless defined $field_definition->{ontology};

  my $ontology_file = $field_definition->{ontology};
  die "ERROR: couldn't find ontology file '$ontology_file': $!"
    unless -e $ontology_file;

  open ( GREP, "grep -c '^id: $value' $ontology_file |" )
    or die "ERROR: couldn't grep value in ontology_file: $!";
  my $rv = join '', <GREP>;
  close GREP;

  chomp $rv;

  return ( $rv eq 1 ) ? 1 : 0;
}

__PACKAGE__->meta->make_immutable;

1;



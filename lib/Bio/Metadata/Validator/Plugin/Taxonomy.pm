
package Bio::Metadata::Validator::Plugin::Taxonomy;

# ABSTRACT: validation plugin for validating tax IDs

use Moose;
use namespace::autoclean;

use Carp qw( croak );

with 'MooseX::Role::Pluggable::Plugin',
     'Bio::Metadata::Validator::PluginRole';

# store the ontology terms in a set of hashes
has '_ids'   => ( is => 'rw', isa => 'HashRef[Str]', default => sub { {} } );
has '_names' => ( is => 'rw', isa => 'HashRef[Int]', default => sub { {} } );

#-------------------------------------------------------------------------------

sub validate {
  my ( $self, $value, $field_definition ) = @_;

  my $names_file = $field_definition->{path};

  croak 'ERROR: the Taxonomy validator requires a file path for the names.dmp file'
    unless defined $names_file;

  croak "ERROR: couldn't find names.dmp file at '$names_file': $!"
    unless -e $names_file;

  $self->_load_taxonomy($names_file)
    if not scalar keys %{$self->_ids};

  return $self->_ids->{$value} || $self->_names->{$value} || 0;
}

#-------------------------------------------------------------------------------

sub _load_taxonomy {
  my ( $self, $file ) = @_;

  open ( TAX, '<', $file )
    or croak "ERROR: couldn't read taxonomy names.dmp file ($file): $!";
  while ( <TAX> ) {
    next unless m/^(\d+)\t\|\t(.*?)\t\|.*?\t\|\tscientific name\t/;
    $self->_ids->{$1}   = $2;
    $self->_names->{$2} = $1;
  }
  close TAX;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;



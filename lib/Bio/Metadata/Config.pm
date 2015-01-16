
package Bio::Metadata::Config;

# ABSTRACT: a class for handling config

use Moose;
use namespace::autoclean;

use Config::General;
use TryCatch;

=head1 NAME

Bio::Metadata::Config

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------

# public attributes
has 'config_file'  => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  trigger  => \&_set_config_file,
);

has 'config_name' => (
  is       => 'rw',
  isa      => 'Str',
  trigger  => \&_set_config_name,
);

has 'config' => (
  is     => 'ro',
  isa    => 'HashRef',
  writer => '_set_config',
);

=attr config_name

the name of the configuration to use; mainly intended for testing.

=attr config_file

a configuration file that specifies the checklist. B<Read-only>; specify at
instantiation

=attr config

the current active configuration. B<Read-only>; set internally

=cut

# private attributes
has '_full_config' => ( is => 'rw', isa => 'HashRef' );

#---------------------------------------

# triggers

sub _set_config_file {
  my $self = shift;

  # make sure the config file exists
  die 'ERROR: could not find the specified configuration file (' . $self->config_file . ")\n"
    unless -e $self->config_file;

  # load the config
  my $cg;
  try {
    $cg = Config::General->new( -ConfigFile => $self->config_file );
  }
  catch ( $e ) {
    die 'ERROR: could not load configuration file (' . $self->config_file . "): $e";
  }

  my %config = $cg->getall;

  # store the full config from the file or string
  $self->_full_config( \%config );

  if ( defined $self->config_name and
       exists $self->_full_config->{checklist}->{$self->config_name} ) {
    # we're looking for a configuration section with a specific name
    $self->_set_config( $self->_full_config->{checklist}->{$self->config_name} );
  }
  else {
    # load any config from the file
    my ( $name, $config ) = each %{ $self->_full_config->{checklist} };
    $self->_set_config($config);
  }
}

#---------------------------------------

sub _set_config_name {
  my $self = shift;

  die "ERROR: there is no config named '" . $self->config_name . "'\n"
    unless exists $self->_full_config->{checklist}->{$self->config_name};

  $self->_set_config( $self->_full_config->{checklist}->{$self->config_name} );

  die "ERROR: failed to load specified config'\n"
    unless defined $self->config;
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 fields

Returns a reference to an array containing the field definitions in the
current config.

=cut

sub fields {
  my $self = shift;

  return unless $self->config;
  return $self->config->{field};
}

#-------------------------------------------------------------------------------

=head2 field_names

Returns a reference to an array containing the field names in the current
config.

=cut

sub field_names {
  my $self = shift;

  return unless $self->config;
  my @names;
  foreach my $field ( @{ $self->config->{field} } ) {
    push @names, $field->{name};
  }
  return \@names;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# none

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;


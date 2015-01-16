
package Bio::Metadata::ConfigRole;

# ABSTRACT: a role for handling config loading

use Moose::Role;

use Config::General;
use TryCatch;

=head1 NAME

Bio::Metadata::ConfigRole

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
  required => 1,
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
    die 'ERROR: could not load configuration file (' . $self->config_file . '): $!';
  }

  my %config = $cg->getall;

  # store the full config from the file or string
  $self->_full_config( \%config );

  # we're looking for a configuration section with a specific name
  die "ERROR: there is no config named '" . $self->config_name . "'\n"
    unless exists $self->_full_config->{checklist}->{$self->config_name};

  $self->_set_config( $self->_full_config->{checklist}->{$self->config_name} );
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

=cut

# none

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# none

#-------------------------------------------------------------------------------

1;


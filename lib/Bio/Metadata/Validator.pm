
package Bio::Metadata::Validator;

# ABSTRACT: validate sample metadata according to a configurable checklist

use Moose;
use namespace::autoclean;
use TryCatch;
use Text::CSV;
use File::Slurp;
use Digest::MD5 qw( md5_hex );
use Term::ANSIColor;
use Carp qw( croak );

with 'MooseX::Role::Pluggable';

use Bio::Metadata::Reader;
use Bio::Metadata::Config;
use Bio::Metadata::Manifest;
use Bio::Metadata::Validator::Exception;

=head1 NAME

Bio::Metadata::Validator

=head1 SYNOPSIS

 # create a config object
 my $config = Bio::Metadata::Config->new( config_file => 'hicf.conf', config_name => 'hicf' );

 # create a reader
 my $reader= Bio::Metadata::Reader->new( config => $config );

 # create a validator
 my $validator = Bio::Metadata::Validator->new( config => $config );

 # read a CSV file and get a Bio::Metadata::Manifest
 my $manifest = $reader->read_csv( 'hicf.csv' );

 # validate the manifest; returns 1 if valid, 0 otherwise
 my $valid = $validator->validate_csv( $manifest );

 # or validate the manifest and display the validation report
 $validator->print_validation_report( $manifest );

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------

# public attributes

=attr verbose_errors

flag showing whether error messages in the output file should include field
descriptions from the checklist configuration

=cut

has 'verbose_errors' => (
  is      => 'rw',
  isa     => 'Bool',
  default => 0,
);

=attr config

configuration object (L<Bio::Metadata::Config>); B<Read-only>; specify
at instantiation

=cut

has 'config' => (
  is       => 'rw',
  isa      => 'Bio::Metadata::Config',
  required => 1,
);

#---------------------------------------

# private attributes
has '_field_defs'        => ( is => 'rw', isa => 'HashRef' );
has '_field_values'      => ( is => 'rw', isa => 'HashRef' );
has '_valid_fields'      => ( is => 'rw', isa => 'HashRef' );
has '_checked_if_config' => ( is => 'rw', isa => 'Bool', default => 0 );
has '_checked_eo_config' => ( is => 'rw', isa => 'Bool', default => 0 );

# field-validation plugins
has 'plugins' => (
  is  => 'ro',
  default => sub { [ qw( Str Int Enum DateTime Ontology Bool ) ] },
);

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 validate

Takes a single argument, the L<Bio::Metadata::Manifest|Manifest> to be
validated. Returns 1 if the manifest is valid, 0 otherwise.

=cut

sub validate {
  my ( $self, $manifest ) = @_;

  croak 'ERROR: must supply a Bio::Metadata::Manifest to validate'
    unless ( defined $manifest and ref $manifest eq 'Bio::Metadata::Manifest' );

  # reset the manifest before validating, otherwise, if the manifest has been
  # validated previously, we'll have duplicate invalid rows
  $manifest->reset;

  my $row_num = 0;
  ROW: foreach my $row ( @{ $manifest->rows } ) {
    $row_num++;

    # validate the fields in the row
    my $row_errors = '';
    try {
      $self->_validate_row( $row, \$row_errors );
    }
    catch ( Bio::Metadata::Validator::Exception::NoValidatorPluginForColumnType $e ) {
      # add the row number (which we don't have in the _validate_row method) to
      # the error message and re-throw
      croak "ERROR: row $row_num; " . $e->error;
    }

    if ( $row_errors ) {
      # since we're pushing the error message onto the invalid rows, we need to
      # clone the row values, otherwise, if we just stored the reference to the
      # row in list of invalid rows, we'd have the error message on rows in both
      # "invalid_rows" and "validated_rows"
      my @invalid_row = @$row;

      # add the row number to the error message
      $row_errors =~ s/^\s+|\s+$//g;
      $row_errors = "[errors found on row $row_num] $row_errors";
      push @invalid_row, $row_errors;
      $manifest->add_invalid_row( \@invalid_row );
    }
    $manifest->add_validated_row( $row );
  }

  return $manifest->has_invalid_rows ? 0 : 1;
}

#-------------------------------------------------------------------------------

=head2 print_validation_report

Validates the supplied manifest and prints a human-readable validation report
to STDOUT. Returns 1 if the manifest is valid, 0 otherwise.

=cut

sub print_validation_report {
  my ( $self, $manifest ) = @_;

  my $valid = $self->validate( $manifest );

  my $validated_file = $manifest->filename
                     ? "'" . $manifest->filename . "' is "
                     : 'input data are ';
  if ( $valid ) {
    print $validated_file, colored( "valid\n", 'green' );
  }
  else {
    my $num_invalid_rows = $manifest->invalid_row_count;
    print $validated_file, colored( "invalid", "bold red" )
          . ". Found $num_invalid_rows invalid row"
          . ( $num_invalid_rows > 1 ? 's' : '' ) . ".\n";
  }
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# takes a reference to an array containing the field values to be validated.
# Walks the fields in the row and validates the values
#
# arguments: ref; list of raw field values
#            ref; scalar to hold errors for this row

sub _validate_row {
  my ( $self, $raw_values, $row_errors_ref ) = @_;

  # validate all of the fields but keep track of errors in the scalar that
  # was handed in

  # keep track of the valid fields (valid in terms of their type only) and the
  # contents of the fields, valid or otherwise
  my $valid_fields = {};

  my $field_values = {};

  # keep track of the field definitions, hashed by field name
  my $field_definitions = {};

  my $num_fields = scalar @{ $self->config->config->{field} };

  FIELD: for ( my $i = 0; $i < $num_fields; $i++ ) {
    # retrieve the definition for this particular field, and add in its column
    # number for later
    my $field_definition = $self->config->config->{field}->[$i];
    $field_definition->{col_num} = $i;

    my $field_name  = $field_definition->{name};
    my $field_type  = $field_definition->{type};
    my $field_value = $raw_values->[$i];

    $field_values->{$field_name} = $field_value;

    $field_definitions->{$field_name} = $field_definition;

    # check for required/optional and skip empty fields
    if ( not defined $field_value or $field_value =~ m/^\s*$/ ) {
      if ( defined $field_definition->{required} and
           $field_definition->{required} ) {
        $$row_errors_ref .= "[field '$field_name' is a required field] ";
      }
      next FIELD;
    }

    # look up the expected type for this field in the configuration
    # and get the appropriate plugin
    my $plugin = $self->plugin_hash->{$field_type};

    if ( not defined $plugin ) {
      Bio::Metadata::Validator::Exception::NoValidatorPluginForColumnType->throw(
        error => "There is no validation plugin for this column type ($field_type) (column $i)\n"
      );
    }

    # use the plugin to validate the field
    my $valid = $plugin->validate($field_value, $field_definition);

    if ( $valid ) {
      $valid_fields->{$field_name} = 1;
    }
    else {
      if ( $self->verbose_errors ) {
        my $desc = $field_definition->{description} || $field_type;
        $$row_errors_ref .= "[value in field '$field_name' is not valid; field description: '$desc'] ";
      }
      else {
        $$row_errors_ref .= "[value in field '$field_name' is not valid] ";
      }
      my $x = 0;
    }
  }

  $self->_field_defs( $field_definitions );
  $self->_field_values( $field_values );
  $self->_valid_fields( $valid_fields );

  $self->_validate_if_dependencies( $raw_values, $row_errors_ref );
  $self->_validate_one_of_dependencies( $raw_values, $row_errors_ref );
  $self->_validate_some_of_dependencies( $raw_values, $row_errors_ref );
}

#-------------------------------------------------------------------------------

# checks that the row meets any specified "if" dependencies
#
# arguments: ref;    array containing fields for a given row
#            ref;    scalar with the raw row string
# returns:   no return value

sub _validate_if_dependencies {
  my ( $self, $row, $row_errors_ref ) = @_;

  return unless defined $self->config->config->{dependencies}->{if};

  IF: foreach my $if_col_name ( keys %{ $self->config->config->{dependencies}->{if} } ) {
    my $dependency = $self->config->config->{dependencies}->{if}->{$if_col_name};

    my $field_definition = $self->_field_defs->{$if_col_name};
    unless ( defined $field_definition ) {
      Bio::Metadata::Validator::Exception::BadConfig->throw(
        error => "ERROR: can't find field definition for '$if_col_name' (required by 'if' dependency)\n"
      );
    }

    # make sure that the column which is supposed to be true or false, the
    # "if" column on which the dependency hangs, is itself valid
    if ( not $self->_valid_fields->{$if_col_name} ) {
      $$row_errors_ref .= " [field '$if_col_name' must be valid in order to statisfy a dependency]";
      next IF;
    }

    # before checking the fields themselves, a quick check on the configuration
    # that we've been given...
    if ( not $self->_checked_if_config ) {
      unless ( $field_definition->{type} eq 'Bool' ) {
        Bio::Metadata::Validator::Exception::BadConfig->throw(
          error => "ERROR: fields with an 'if' dependency must have type Bool ('$if_col_name' field)\n"
        );
      }
      $self->_checked_if_config(1);
    }

    # if the value of the field named $if_dependency is true, we need to check
    # the values in the "then" fields. If it's false, we need to check the
    # "else" columns. We also need to make sure that if $if_dependency is true,
    # there are no valid fields in the "else" columns.

    # look up the column number for the field
    my $if_col_num = $field_definition->{col_num};

    # work around the Config::General behaviour of single element arrays vs
    # scalars
    my $thens = ref $dependency->{then}
              ? $dependency->{then}
              : [ $dependency->{then} ];
    my $elses = ref $dependency->{else}
              ? $dependency->{else}
              : [ $dependency->{else} ];

    if ( $row->[$if_col_num] ) {

      # true; check that the "then" columns are valid
      foreach my $then_col_name ( @$thens ) {
        if ( not $self->_valid_fields->{$then_col_name} ) {
          $$row_errors_ref .= " [field '$then_col_name' must be valid if field '$if_col_name' is set to true]";
        }
      }

      # shouldn't have any "else" dependencies completed. Here we're checking
      # for a value, not a *valid* value
      foreach my $else_col_name ( @$elses ) {
        if ( $self->_field_values->{$else_col_name} ) {
          $$row_errors_ref .= " [field '$else_col_name' should not be completed if field '$if_col_name' is set to true]";
        }
      }

    }
    else {

      # false; check that the "else" columns are valid
      foreach my $else_col_name ( @$elses ) {
        if ( not $self->_valid_fields->{$else_col_name} ) {
          $$row_errors_ref .= " [field '$else_col_name' must be valid if field '$if_col_name' is set to false]";
        }
      }

      # shouldn't have any "then" dependencies completed
      foreach my $then_col_name ( @$thens ) {
        if ( $self->_field_values->{$then_col_name} ) {
          $$row_errors_ref .= " [field '$then_col_name' should not be completed if field '$if_col_name' is set to false]";
        }
      }

    }
  } # end of "foreach if dependency"
}

#-------------------------------------------------------------------------------

# checks that the row meets any specified "one_of" dependencies
#
# arguments: ref;    array containing fields for a given row
#            ref;    scalar with the raw row string
# returns:   no return value

sub _validate_one_of_dependencies {
  my ( $self, $row, $row_errors_ref ) = @_;

  return unless defined $self->config->config->{dependencies}->{one_of};

  GROUP: while ( my ( $group_name, $group ) = each %{ $self->config->config->{dependencies}->{one_of} } ) {
    my $num_completed_fields = 0;

    my $group_list = ref $group ? $group : [ $group ];
    FIELD: foreach my $field_name ( @$group_list ) {
      $num_completed_fields++ if $self->_field_values->{$field_name};
    }

    if ( $num_completed_fields != 1 ) {
      my $group_fields = join ', ', map { qq('$_') } @$group_list;
      $$row_errors_ref .= " [exactly one field out of $group_fields should be completed (found $num_completed_fields)]";
    }
  }
}

#-------------------------------------------------------------------------------

# checks that the row meets any specified "some_of" dependencies
#
# arguments: ref;    array containing fields for a given row
#            ref;    scalar with the raw row string
# returns:   no return value

sub _validate_some_of_dependencies {
  my ( $self, $row, $row_errors_ref ) = @_;

  return unless defined $self->config->config->{dependencies}->{some_of};

  GROUP: while ( my ( $group_name, $group ) = each %{ $self->config->config->{dependencies}->{some_of} } ) {
    my $num_completed_fields = 0;

    my $group_list = ref $group ? $group : [ $group ];
    FIELD: foreach my $field_name ( @$group_list ) {
      $num_completed_fields++ if $self->_field_values->{$field_name};
    }
    if ( $num_completed_fields < 1 ) {
      my $group_fields = join ', ', map { qq('$_') } @$group_list;
      $$row_errors_ref .= " [at least one field out of $group_fields should be completed]";
    }
  }
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

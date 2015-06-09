
package Bio::Metadata::Validator;

# ABSTRACT: validate sample metadata according to a configurable checklist

use Moose;
use namespace::autoclean;
use Try::Tiny;
use Text::CSV;
use File::Slurp;
use Digest::MD5 qw( md5_hex );
use Term::ANSIColor;
use Carp qw( croak );
use MooseX::Types::Moose qw ( Bool HashRef Str );

with 'MooseX::Role::Pluggable';

use Bio::Metadata::Reader;
use Bio::Metadata::Manifest;
use Bio::Metadata::Validator::Exception;

=head1 SYNOPSIS

 # create a checklist object
 my $checklist = Bio::Metadata::Checklist->new( config_file => 'hicf.conf', config_name => 'hicf' );

 # create a reader
 my $reader= Bio::Metadata::Reader->new( checklist => $checklist );

 # read a CSV file and get a Bio::Metadata::Manifest
 my $manifest = $reader->read_csv( 'hicf.csv' );

 # create a validator
 my $validator = Bio::Metadata::Validator->new;

 # validate the manifest; returns 1 if valid, 0 otherwise
 my $valid = $validator->validate_csv( $manifest );

 # or validate the manifest and display the validation report
 $valid = $validator->print_validation_report( $manifest );

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------

# public attributes

=attr verbose_errors

flag showing whether error messages in the output file should include field
descriptions from the checklist

=cut

has 'verbose_errors' => (
  is      => 'rw',
  isa     => Bool,
  default => 0,
);

#---------------------------------------

# private attributes

has '_field_defs'        => ( is => 'rw', isa => HashRef );
has '_field_values'      => ( is => 'rw', isa => HashRef );
has '_valid_fields'      => ( is => 'rw', isa => HashRef );
has '_checked_if_config' => ( is => 'rw', isa => Bool, default => 0 );
has '_checked_eo_config' => ( is => 'rw', isa => Bool, default => 0 );
has '_unknown_terms'     => ( is => 'rw', isa => HashRef[Str] );
has '_checklist'         => ( is => 'rw', isa => 'Bio::Metadata::Checklist', trigger => \&_set_unknowns );

sub _set_unknowns {
  my ( $self, $checklist ) = @_;

  # all of this is to avoid creating a ref to an empty array in the checklist.
  # Using the "map" on an undefined slot appears to auto-vivify the array ref
  # in the checklist, which makes one of the tests fail...
  my %unknown_terms = defined $checklist->config->{unknown_term}
                    ? map { $_ => 1 } @{ $checklist->config->{unknown_term} }
                    : ();

  $self->_unknown_terms( \%unknown_terms );
}

# field-validation plugins
has 'plugins' => (
  is  => 'ro',
  default => sub { [ qw( Str Int Enum DateTime Ontology Bool Taxonomy ) ] },
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

  # store the configuration object for convenience
  $self->_checklist( $manifest->checklist );

  my $row_num = 0;
  ROW: foreach my $row ( @{ $manifest->rows } ) {
    $row_num++;

    # validate the fields in the row
    my $row_errors = '';
    try {
      $self->_validate_row( $row, \$row_errors );
    } catch {
      # add the row number (which we don't have in the _validate_row method) to
      # the error message and re-throw
      croak "ERROR: row $row_num; $_";
    };

    if ( $row_errors ) {

      # add the row number to the error message
      $row_errors =~ s/^\s+|\s+$//g; # strip leading and trailing space
      $row_errors = "[errors found on row $row_num] $row_errors";

      # push the row into the array. The row number is 1-based though, to make
      # it easier to read the error messages. Make the count zero-based...
      $manifest->set_row_error( $row_num - 1, $row_errors );
    }
  }

  # clean up the book-keeping hash keys that we put into the checklist config
  # as we do the validation
  foreach my $field ( @{ $manifest->checklist->fields } ) {
    delete $field->{__col_num};
    delete $field->{__unknown_terms};
  }

  return $manifest->has_invalid_rows ? 0 : 1;
}

#-------------------------------------------------------------------------------

=head2 print_validation_report

Validates the supplied manifest and prints a human-readable validation report
to STDOUT. Returns 1 if the manifest is valid, 0 otherwise.

=cut

# TODO this could (and probably should) be extended to display the row-by-row
# TODO error messages in a friendly format

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

  return $valid;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# takes a reference to an array containing the field values to be validated.
# Walks the fields in the row and validates the values
#
# arguments: ref; list of raw field values
#            ref; scalar to hold errors for this row; this will be modified to
#                 add the error messages (if any) for the row

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

  my $num_fields = scalar @{ $self->_checklist->get('field') };

  FIELD: for ( my $i = 0; $i < $num_fields; $i++ ) {
    # retrieve the definition for this particular field, and add in its column
    # number for later. We also add a reference to the various "unknown" terms,
    # for use by the plugin role
    my $field_definition = $self->_checklist->get('field')->[$i];
    $field_definition->{__col_num} = $i;
    $field_definition->{__unknown_terms} = $self->_unknown_terms;

    my $field_name  = $field_definition->{name};
    my $field_type  = $field_definition->{type};
    my $field_value = $raw_values->[$i];

    $field_values->{$field_name} = $field_value;

    $field_definitions->{$field_name} = $field_definition;

    # check for required/optional and skip empty fields. We only need to
    # perform this check for fields that are empty, since fields that have
    # values will be validated by the normal mechanism anyway.
    if ( not defined $field_value or $field_value =~ m/^\s*$/ ) {
      if ( defined $field_definition->{required} and
           $field_definition->{required}         and
           ! $field_definition->{unknown} ) {
        $$row_errors_ref .= "['$field_name' is a required field] ";
      }
      next FIELD;
    }

    # look up the expected type for this field in the checklist configuration
    # and get the appropriate plugin
    my $plugin = $self->plugin_hash->{$field_type};

    if ( not defined $plugin ) {
      Bio::Metadata::Validator::Exception::NoValidatorPluginForColumnType->throw(
        error => "There is no validation plugin for this column type ($field_type) (column $i)\n"
      );
    }

    # use the plugin to validate the field. Returns 1 for valid, 0 for invalid,
    # -1 for unknown
    $valid_fields->{$field_name} = $plugin->validate($field_value, $field_definition);

    # if the field is invalid, add an error message
    if ( $valid_fields->{$field_name} == 0 ) {
      if ( $self->verbose_errors ) {
        my $desc = $field_definition->{description} || $field_type;
        $$row_errors_ref .= "[value in field '$field_name' is not valid; field description: '$desc'] ";
      }
      else {
        $$row_errors_ref .= "[value in field '$field_name' is not valid] ";
      }
    }
  }

  $self->_field_defs( $field_definitions );
  $self->_field_values( $field_values );
  $self->_valid_fields( $valid_fields );

  # we've checked that the individual fields are valid. Now check that the
  # dependencies on the individual fields hold
  $self->_validate_dependencies( $raw_values, $row_errors_ref );

  # TODO there's nothing currently stopping the author of the checklist putting
  # TODO the same column in two dependencies, i.e. making a column subject to
  # TODO both an "if" and a "one_of". What happens in that case is undefined,
  # TODO so it would be sensible to set a flag on each column when it's first
  # TODO used in a dependency, checking for it before using the column in any
  # TODO other dependencies.
}

#-------------------------------------------------------------------------------

# checks that the row meets any specified "one_of" dependencies
#
# arguments: ref;    array containing fields for a given row
#            ref;    scalar with the raw row string
# returns:   no return value

sub _validate_dependencies {
  my ( $self, $row, $row_errors_ref ) = @_;

  $self->_validate_if_dependencies( $row, $row_errors_ref );

  DEP_TYPE: foreach my $dep_type ( qw( one_of some_of ) ) {

    # we're immediately done here if there are no "one of" dependencies to check
    next DEP_TYPE unless ( defined $self->_checklist->get('dependencies') and
                           exists $self->_checklist->get('dependencies')->{$dep_type} );

    GROUP: while ( my ( $group_name, $group ) =
                     each %{ $self->_checklist->get('dependencies')->{$dep_type} } ) {
      my $counts = $self->_count_fields($group);

      # we don't consider it an error if all of the fields are unknowns
      next GROUP if $counts->{num_unknown} == $counts->{num_total};

      # nor if all of the fields are optional
      next GROUP if ( $counts->{num_completed} == 0 and
                      $counts->{num_optional} == $counts->{num_total} );

      if ( $dep_type eq 'one_of' and $counts->{num_completed} != 1 ) {
        $$row_errors_ref .= ' [exactly one field out of ' . $counts->{group_fields}
                            . ' should be completed (found ' . $counts->{num_completed}
                            . ") and not 'unknown']";
      }
      elsif ( $dep_type eq 'some_of' and $counts->{num_completed} < 1 ) {
        $$row_errors_ref .= ' [at least one field out of ' . $counts->{group_fields}
                            . "should be completed and not 'unknown']";
      }
    }
  }

}

#-------------------------------------------------------------------------------

# walks the fields in the given dependency group and checks for fields with
# "unknown". Returns a hash ref containing:
#   num_completed: number of completed fields in the group
#   num_unknown:   number of fields in the group with "unknown"
#   num_optional   number of fields in the group which are optional (required != 1)
#   num_total:     total number of fields in the group
#   group_fields:  string giving the names of all fields in the group
#
# arguments: scalar; name of the group to check
# returns:   ref; hash with counts

sub _count_fields {
  my ( $self, $group ) = @_;

  my $num_completed_fields = 0;
  my $num_unknown_fields   = 0;
  my $num_optional_fields  = 0;
  my $num_fields_in_group  = 0;

  my $group_list = ref $group ? $group : [ $group ];
  FIELD: foreach my $field_name ( @$group_list ) {
    $num_fields_in_group++;
    $num_optional_fields++ unless $self->_field_defs->{$field_name}->{required};

    my $field_value = $self->_field_values->{$field_name};

    next FIELD if not defined $field_value;

    # if the field accepts "unknown" and the value actually IS "unknown"
    # don't count it as a completed field
    if ( $self->_field_defs->{$field_name}->{accepts_unknown} and
         $self->_field_defs->{$field_name}->{__unknown_terms}->{$field_value} ) {
      $num_unknown_fields++;
      next FIELD;
    }

    # field is defined and not one of the allowed "unknown" terms; count it
    # as completed
    $num_completed_fields++;
  }

  my $group_fields = join ', ', map { qq('$_') } @$group_list;

  return {
    num_completed => $num_completed_fields,
    num_unknown   => $num_unknown_fields,
    num_optional  => $num_optional_fields,
    num_total     => $num_fields_in_group,
    group_fields  => $group_fields,
  };
}

#-------------------------------------------------------------------------------

# checks that the row meets any specified "if" dependencies
#
# arguments: ref;    array containing fields for a given row
#            ref;    scalar with the raw row string
# returns:   no return value

sub _validate_if_dependencies {
  my ( $self, $row, $row_errors_ref ) = @_;

  return unless ( defined $self->_checklist->get('dependencies') and
                  exists $self->_checklist->get('dependencies')->{if} );

  IF: foreach my $if_col_name ( keys %{ $self->_checklist->get('dependencies')->{if} } ) {

    my $field_definition = $self->_field_defs->{$if_col_name};
    unless ( defined $field_definition ) {
      Bio::Metadata::Validator::Exception::BadConfig->throw(
        error => "ERROR: can't find field definition for '$if_col_name' (required by 'if' dependency)\n"
      );
    }

    # if the field that defines the "if" dependencies is flagged as "unknown",
    # all bets are off. We can't work out which set of other fields (given by
    # the "then" or "else" blocks) should be required and valid
    next IF if ( $field_definition->{accepts_unknown} and
                 defined $self->_valid_fields->{$if_col_name} and
                 $self->_valid_fields->{$if_col_name} < 0 );

    # make sure that the column which is supposed to be true or false, the
    # "if" column on which the dependency hangs, is itself valid
    if ( not $self->_valid_fields->{$if_col_name} ) {
      $$row_errors_ref .= " [field '$if_col_name' must be valid in order to statisfy a dependency]";
      next IF;
    }

    # before checking the fields themselves, a quick check on the checklist
    # configuration that we've been given...
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
    my $if_col_num = $field_definition->{__col_num};

    my $dependency = $self->_checklist->get('dependencies')->{if}->{$if_col_name};

    my $thens = ref $dependency->{then}  # (work around the Config::General
              ? $dependency->{then}      # behaviour of single element arrays
              : [ $dependency->{then} ]; # vs # scalars)
    my $elses = ref $dependency->{else}
              ? $dependency->{else}
              : [ $dependency->{else} ];

    # check for the allowed "true" values. These must match up with those permitted
    # by the Bool validator plugin (Bio::Metadata::Validator::Plugin::Bool)
    if ( $row->[$if_col_num] eq 'true' or
         $row->[$if_col_num] eq 'yes'  or
         $row->[$if_col_num] eq '1' ) {

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

__PACKAGE__->meta->make_immutable;

1;

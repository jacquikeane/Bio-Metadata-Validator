
package Bio::Metadata::DataFinder;

# ABSTRACT: class for finding sample metadata from tracking databases

use Moose;
use namespace::autoclean;

use Carp qw( croak carp );
use MooseX::Types::Moose qw( ArrayRef Str Int );
use File::Slurp;

use Path::Find;
use Path::Find::Lanes;

use Bio::Metadata::Types qw( IDType );

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------

# public attributes

has 'input_type' => (
  is       => 'ro',
  isa      => IDType,
  required => 1,
);

has 'input' => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has 'file_id_type' => (
  is  => 'ro',
  isa => IDType,
);

# private attributes

has '_vrtrack' => (
  is  => 'rw',
  isa => 'VRTrack::VRTrack'
);

#-------------------------------------------------------------------------------
#- construction ----------------------------------------------------------------
#-------------------------------------------------------------------------------

sub BUILD {
  my $self = shift;

  croak 'ERROR: must specify "file_id_type" if input type is "file"'
    if ( $self->input_type eq 'file' and not defined $self->file_id_type );

  croak 'ERROR: "file_id_type" cannot be "file"'
    if ( defined $self->file_id_type and $self->file_id_type eq 'file' );

  croak q(ERROR: can't find input file ") . $self->input . q(")
    if ( $self->input_type eq 'file' and ! -f $self->input );
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 find

=cut

sub find {
  my $self = shift;

  # use Path::Find to retrieve a list of lanes for the specified IDs
  my $lanes = $self->_get_lanes_from_db;

  my $output = {
    key_order => [],
  };

  return $output unless scalar @$lanes;

  if ( $self->input_type eq 'lane' or
       $self->input_type eq 'sample' ) {
    $output = {
      key_order    => [ $self->input ],
      $self->input => $lanes->[0],
    };
  }
  elsif ( $self->input_type eq 'study' ) {
    foreach my $lane ( @$lanes ) {
      push @{ $output->{key_order} }, $lane->name;
      $output->{ $lane->name } = $lane;
    }
  }
  elsif ( $self->input_type eq 'file' ) {
    # given a file of IDs as input, the Path::Find module will return lane
    # objects in an order that's determined by the database, but that order
    # won't necessarily match the order of the IDs in the input file.
    #
    # This chunk of code, cloned directly from
    # Bio::ENA::DataSubmission::CommandLine::GenerateManifest, takes care of
    # ordering the lanes, grepping the list of IDs that were found by
    # "_get_lanes_from_db" and generating a list of found IDs in the order that
    # they appeared in the input file
    my $input_ids = $self->_read_file;
    my $found_ids = $self->_get_found_ids($lanes);

    foreach my $input_id ( @$input_ids ) {
      # the "grep" below will throw warnings when it hits an empty slot in the
      # list of found IDs
      no warnings 'uninitialized';

      my ( $index ) = grep { $found_ids->[$_] eq $input_id } 0 .. $#$found_ids;
      # (ugly; see http://www.perlmonks.org/?node_id=624502 about ^^^^^^^^^^^^)

      push @{ $output->{key_order} }, $input_id;
      $output->{$input_id} = defined $index
                           ? $lanes->[$index]
                           : undef;
    }
  }

  return $output;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

sub _get_found_ids {
  my ( $self, $lanes ) = @_;

  my @found_ids;

  LANE: foreach my $lane ( @$lanes ) {
    if ( $self->file_id_type eq 'lane' ) {
      push @found_ids, $lane->{name};
    }
    else {
      my $library = VRTrack::Library->new( $self->_vrtrack, $lane->library_id );
      unless ( defined $library ) {
        carp 'WARNING: no sample for library "' . $lane->library_id . '"';
        next LANE;
      }
      my $sample = VRTrack::Sample->new( $self->_vrtrack, $library->sample_id );
      push @found_ids, $sample->individual->acc;
    }
  }

  return \@found_ids;
}

#-------------------------------------------------------------------------------

sub _read_file {
  my $self = shift;

  open ( FILE, $self->input )
    or croak "ERROR: can't open input file for read: $!";

  my @ids;
  while ( <FILE> ) {
    chomp;
    next if m/^$/;
    push @ids, $_;
  }

  close FILE;

  return \@ids;
}

#-------------------------------------------------------------------------------

sub _get_lanes_from_db {
  my $self = shift;

  my @pathfind_args = ();

  if ( $ENV{TEST_PATHFIND} ) {
    @pathfind_args = (
      # environment => 'test',
      db_root     => 't/data/10_pathfind_root_dirs',
    );
  }

  my $pathfind = Path::Find->new(@pathfind_args);

  my ( $pathtrack, $dbh, $lanes );
  DB: foreach my $db ( $pathfind->pathogen_databases ) {
    ( $pathtrack, $dbh ) = $pathfind->get_db_info($db);

    # set the processed flag
    # (1024 for assemblies, 2048 for annotations, 0 otherwise)
    my $processed_flag = $self->input_type eq 'assembly'   ? 1024
                       : $self->input_type eq 'annotation' ? 2048
                       : 0;

    my %params = (
      search_type    => $self->input_type,
      search_id      => $self->input,
      file_id_type   => $self->file_id_type || $self->input_type,
      pathtrack      => $pathtrack,
      dbh            => $dbh,
      processed_flag => $processed_flag,
    );

    my $lanes_finder = Path::Find::Lanes->new( %params );
    $lanes = $lanes_finder->lanes;

    last DB if scalar @$lanes;
  }

  $self->_vrtrack($pathtrack);

  return $lanes;
}







# sub find {
#   my $self = shift;
#
#   my $lanes = $self->_get_lanes_from_db;
#
#   my %data = ( key_order => [] );
#   return \%data unless @$lanes;
#
#   if ( $self->type eq 'lane' || $self->type eq 'sample' ) {
#     push( $data{key_order}, $self->id );
#     $data{ $self->id } = $lanes->[0];
#   }
#   elsif ( $self->type eq 'study' ) {
#     for my $l (@$lanes) {
#       push( $data{key_order}, $l->name );
#       $data{ $l->name } = $l;
#     }
#   }
#   elsif ( $self->type eq 'file' ) {
#
#     # set key order as per file
#     open( my $fh, '<', $self->id );
#     my @ids = <$fh>;
#     chomp @ids;
#     $data{key_order} = \@ids;
#
#     # match returned lane objects to their ID
#     my @found_ids = $self->_found_ids($lanes);
#
#     for my $id (@ids) {
#       $data{$id} = undef;
#       my ($index) = grep { $found_ids[$_] eq $id } 0 .. $#found_ids;
#       $data{$id} = $lanes->[$index] if ( defined $index );
#     }
#   }
#
#   return \%data;
# }

# sub _get_lanes_from_db {
#   my $self = shift;
#   my $lanes;
#   my $find               = Path::Find->new();
#   my @pathogen_databases = $find->pathogen_databases;
#   my ( $pathtrack, $dbh, $root );
#   for my $database (@pathogen_databases) {
#     ( $pathtrack, $dbh, $root ) = $find->get_db_info($database);
#
#     my $processed_flag = 0;
#     if ( $self->file_type eq 'assembly' ) {
#       $processed_flag = 1024;
#     }
#     elsif ( $self->file_type eq 'annotation' ) {
#       $processed_flag = 2048;
#     }
#
#     my $find_lanes = Path::Find::Lanes->new(
#       search_type    => $self->type,
#       search_id      => $self->id,
#       file_id_type   => $self->file_id_type,
#       pathtrack      => $pathtrack,
#       dbh            => $dbh,
#       processed_flag => $processed_flag
#     );
#     $lanes = $find_lanes->lanes;
#
#     if (@$lanes) {
#       $dbh->disconnect();
#       last;
#     }
#   }
#
#   $self->_vrtrack($pathtrack);
#   $self->_root($root);
#
#   return $lanes;
# }

#-------------------------------------------------------------------------------

# sub _found_ids {
#   my ( $self, $lanes ) = @_;
#   my $vrtrack = $self->_vrtrack;
#
#   open( my $fh, '<', $self->id );
#   my @ids = <$fh>;
#
#   # extract IDs from lane objects
#   my @got_ids;
#
#   # detect whether lane names or sample accessions
#   foreach my $lane (@$lanes) {
#     if ( $self->file_id_type eq 'lane' ) {
#       push @got_ids, $lane->{name};
#     }
#     else {
#       my $library = VRTrack::Library->new( $self->_vrtrack, $lane->library_id );
#       if ( not defined $library ) {
#         warn q(WARNING: no sample for library ') . $lane->library_id . q(');
#         next ID;
#       }
#       my $sample = VRTrack::Sample->new( $self->_vrtrack, $library->sample_id );
#       push @got_ids, $sample->individual->acc;
#     }
#   }
#
#   return @got_ids;
# }

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

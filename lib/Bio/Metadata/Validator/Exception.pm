package Bio::Metadata::Validator::Exception;
# ABSTRACT: Builds exceptions for input data

=head1 SYNOPSIS

Builds exceptions for input data

=cut

use Exception::Class (
  Bio::Metadata::Validator::Exception::UnknownError                   => { description => 'General, uncaught, unforeseen error' },
  Bio::Metadata::Validator::Exception::NoConfigSpecified              => { description => 'No configuration given' },
  Bio::Metadata::Validator::Exception::NoInputSpecified               => { description => 'No input file given' },
  Bio::Metadata::Validator::Exception::ConfigFileNotFound             => { description => 'No such config file' },
  Bio::Metadata::Validator::Exception::ConfigNotValid                 => { description => 'Invalid configuration' },
  Bio::Metadata::Validator::Exception::BadConfig                      => { description => 'There is a problem with the configuration file' },
  Bio::Metadata::Validator::Exception::InputFileNotFound              => { description => 'No such input file' },
  Bio::Metadata::Validator::Exception::NoValidatorPluginForColumnType => { description => 'No plugin found to validate the specified column type' },
  Bio::Metadata::Validator::Exception::InputFileValidationError       => { description => 'Encountered parsing errors when reading CSV file' },
  Bio::Metadata::Validator::Exception::NotValidated                   => { description => 'We have not validated any file yet' },
);

1;


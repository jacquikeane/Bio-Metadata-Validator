# Bio-Metadata-Validator
Validate a genome metadata manifest against a checklist

[![Build Status](https://travis-ci.org/sanger-pathogens/Bio-Metadata-Validator.svg)](https://travis-ci.org/sanger-pathogens/Bio-Metadata-Validator)   
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-brightgreen.svg)](https://github.com/sanger-pathogens/Bio-Metadata-Validator/blob/master/software-license)   

## Contents
  * [Introduction](#introduction)
  * [Installation](#installation)
    * [From Source](#from-source)
    * [Running the tests](#running-the-tests)
  * [Usage](#usage)
  * [License](#license)
  * [Feedback/Issues](#feedbackissues)

## Introduction
Bio-Metadata-Validator is used to validate an input file against the checklist.

## Installation
Details for installing Bio-Metadata-Validator are provided below. If you encounter an issue when installing Bio-Metadata-Validator please contact your local system administrator. If you encounter a bug please log it [here](https://github.com/sanger-pathogens/Bio-Metadata-Validator/issues) or email us at path-help@sanger.ac.uk.

### From Source
Clone the repository:   
   
`git clone https://github.com/sanger-pathogens/Bio-Metadata-Validator.git`   
   
Move into the directory and install all dependencies using [DistZilla](http://dzil.org/):   
  
```
cd Bio-Metadata-Validator
dzil authordeps --missing | cpanm
dzil listdeps --missing | cpanm
```
  
Run the tests:   
  
`dzil test`   
If the tests pass, install Bio-Metadata-Validator:   
  
`dzil install`   

### Running the tests
The test can be run with dzil from the top level directory:  
  
`dzil test`  

## Usage
Validate a manifest:
```
shell% validate_manifest -c hicf.conf valid_manifest.csv
'valid_manifest.csv' is valid
```
Check an invalid file and write the invalid rows to an output file:
```
shell% validate_manifest -c hicf.conf -o validated.csv -i invalid_manifest.csv
'invalid_manifest.csv' is invalid. Found 6 invalid rows
wrote only invalid rows from validated file to 'validated.csv'.
```
Specify the configuration file in an environment variable. For bash:
```
bash% export CHECKLIST_CONFIG=hicf.conf
```
or for C-shell:
```
csh% setenv CHECKLIST_CONFIG hicf.conf
```
then
```
shell% validate_manifest valid_manifest.csv
'valid_manifest.csv' is valid
```
This script validates a sample manifest against a checklist and displays a report. The checklist must be defined in a configuration file, which should be supplied either using the `--config` option or by setting the `CHECKLIST_CONFIG` environment variable.

When the `--output` option is supplied, the validated file will be written to the specified output file. If the input file was not valid, invalid rows in the output file will have error messages appended to them. Adding the `--write-invalid` option will cause the script to write only invalid rows to the output file. The default behaviour is to write both valid and invalid rows to the output file.

The script exits with status 0 if the input file was valid. The exit status will be 1 if the input file was invalid, or if there was a problem with the options or an error was encountered while running.

```
-h --help
   display help text
-c --config
   configuration file defining the checklist that should be used to validate the input file
-o --output
   write the validated input to the specifed output file. Default is to write all rows, both valid and invalid.
-i --write-invalid
   write only invalid rows, with error messages appended, to the specified output file.
<input file>
   Input file to be validated.
```
## License
Bio-Metadata-Validator is free software, licensed under [GPLv3](https://github.com/sanger-pathogens/Bio-Metadata-Validator/blob/master/software-license).

## Feedback/Issues
Please report any issues to the [issues page](https://github.com/sanger-pathogens/Bio-Metadata-Validator/issues) or email path-help@sanger.ac.uk.


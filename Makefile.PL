#!/usr/bin/perl -w

use ExtUtils::MakeMaker;

WriteMakefile(
	      'NAME'         => 'cmms',
	      'VERSION_FROM' => 'lib/CMMS/Ripper.pm', # finds $VERSION
	      'PREREQ_PM'    => {
				 'TAER'             => 0.08,
				 'Install'          => 0.14,
				 'FrameworkBuilder' => 0.04,
				 'RS::Util'         => 0.01,
				 # CGI can't be > 3.00 due to upload() bug in
				 # Embperl 1.X
				 CGI                => 3.00
	      }, # e.g., Module::Name => 1.1
	      'clean' => { FILES => '*~ lib/*~ lib/CDist/*~' },
);

use ExtUtils::MakeMaker;	# See the Camel, page 409-
require 5.000;

WriteMakefile(
	      'NAME'			=> 'Parse::Lex',
	      'DISTNAME'        => "ParseLex",
	      'VERSION_FROM'	=> 'lib/Parse/ALex.pm',
		  'PREREQ_PM' 		=> { 'Test::More' => 0 },
	      'clean'			=> {'FILES' => ['err', 'testlog']},
	      'dist'            => { COMPRESS => 'gzip', SUFFIX => 'gz' },
		  'PREREQ_PM'		=> { 'Parse::Template'		=> 3.01 },
);


use ExtUtils::MakeMaker;	# See the Camel, page 409-
require 5.000;

WriteMakefile(
	      'NAME'		=> 'Parse::Lex',
	      'DISTNAME'        => "ParseLex",
	      'VERSION_FROM'	=> 'lib/Parse/ALex.pm',
	      'clean'		=> {'FILES' => 'err'},
	      'dist'            => { COMPRESS => 'gzip', SUFFIX => 'gz' },
);


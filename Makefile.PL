use ExtUtils::MakeMaker;	# See the Camel, page 409-
require 5.002;
$Verbose = 1;
WriteMakefile(
	      'NAME'		=> 'Parse::Lex',
	      'DISTNAME'        => "ParseLex",
	      'VERSION_FROM'	=> 'Parse/Lex.pm',
	      'clean'		=> {'FILES' => 'err'},
	      'dist'            => { COMPRESS => 'gzip', SUFFIX => 'gz' },
);


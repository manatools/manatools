use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'curl_download',
    'INSTALLDIRS'  => 'vendor',
    'VERSION_FROM' => 'curl_download.pm', # finds VERSION
    'INC'          => '-I.',
    'MAKEFILE'     => 'Makefile_c',
);

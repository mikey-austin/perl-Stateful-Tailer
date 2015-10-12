use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Stateful::Tailer',
    AUTHOR           => q{Mikey Austin <mikey@jackiemclean.net>},
    VERSION_FROM     => 'lib/Stateful/Tailer.pm',
    ABSTRACT_FROM    => 'lib/Stateful/Tailer.pm',
    LICENSE          => 'artistic_2',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'YAML' => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Stateful-Tailer-*' },
);

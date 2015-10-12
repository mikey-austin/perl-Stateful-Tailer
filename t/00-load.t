#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 3;

BEGIN {
    use_ok( 'Stateful::Tailer' ) || print "Bail out!\n";
    use_ok( 'Stateful::Tailer::File' ) || print "Bail out!\n";
    use_ok( 'Stateful::Tailer::Exception' ) || print "Bail out!\n";
}

diag( "Testing Stateful::Tailer $Stateful::Tailer::VERSION, Perl $], $^X" );

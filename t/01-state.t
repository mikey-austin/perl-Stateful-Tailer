#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;
use Stateful::Tailer;

plan tests => 3;

my $now = time;
my $state_path = "/tmp/st_$now.state";
my $file1 = "/tmp/st_test1_$now.txt";
my $file2 = "/tmp/st_test2_$now.txt";

open(my $fh1, '>>', $file1);
open(my $fh2, '>>', $file2);
$fh1->autoflush(1);
$fh2->autoflush(1);

my $tailer = Stateful::Tailer->new(
    files            => [ $file1, $file2 ],
    state_file       => $state_path,
    include_patterns => [ '^include_me' ],
    exclude_patterns => [ 'exclude_me$' ],
    read_callback    => (
        sub {
            my $lines = shift;

            # Each matched line equates to one test.
            ok($_ =~ /^include_me/) for @{$lines};
        }
    )
);

$fh1->print("include_me 123\n");
$fh2->print("include_me 1234568888\n");
$fh1->print("include_me 123456\n");
$fh1->print("123 exclude_me\n");
$fh2->print("123456 exclude_me\n");

$tailer->read;

unlink($_) for qw/$file1 $file2 $state_path/;

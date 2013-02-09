#!/usr/bin/perl
use 5.012;
use lib 'blib/lib', 'blib/arch', 't';
use Benchmark qw/timethis timethese/;
use Panda::Export { abc => 1};
use Time::HiRes;

BEGIN {
    require MyTest;
    my @list = (map {"CONST$_"} 1..1);
    my $now = Time::HiRes::time;
    MyTest->import();
    say "MAIN took ".((Time::HiRes::time - $now)*1000)." ms";
}

say "START";

1;

package Panda::Export;
use 5.012;

our $VERSION = '1.1';

=head1 NAME

Panda::Export - Replacement for Exporter.pm + const.pm written in pure C.

It's very fast not only in runtime but at compile time as well. That means you can create and export/import a
lot of constants/functions without slowing down the startup.

=cut

require XSLoader;
XSLoader::load('Panda::Export', $VERSION);

=head1 SYNOPSIS

=head2 Exporting functions

    package MyModule;
    use parent 'Panda::Export';
    
    sub mysub { ... }
    sub mysub2 { ... }
    
    1;
    
    package Somewhere;
    use MyModule qw/mysub mysub2/;
    
    mysub();
    
=head2 Creating and using constants (without export)

    package MyModule;
    
    use Panda::Export {
        CONST1 => 1,
        CONST2 => 'string',
    };
    
    say CONST1;
    say CONST2;

=head2 Creating and using constants with export

    package MyModule;
    use parent 'Panda::Export';
    
    use Panda::Export {
        CONST1 => 1,
        CONST2 => 'string',
    };
    
    say CONST1;
    say CONST2;
    
    package Somewhere;
    
    use MyModule;
    
    say CONST1;
    say CONST2;    

=head1 DESCRIPTION

You can create constants by saying

    use Panda::Export {CONST_NAME1 => VALUE1, ...}

If you want your class to able to export constants or functions you need to derive from Panda::Export.

Exports specified constants and functions to caller's package.

    use MyModule qw/subs list/;

Exports nothing

    use MyModule();
    

Exports all constants only (no functions)

    use MyModule;

Exports functions sub1 and sub2 and all constants

    use MyModule qw/sub1 sub2 :const/;


If Panda::Export discovers name collision while creating or exporting functions or constants it raises an exception.
If you specify wrong sub or const name in import list an exception will also be raisen.

=head1 PERFOMANCE

Panda::Export is up to 10x faster than const.pm and 5x faster than Exporter.pm at compile-time.
The runtime perfomance is the same as it doesn't depend on this module.

=head1 AUTHOR

Pronin Oleg <syber@cpan.org>, Crazy Panda, CP Decision LTD

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

1;

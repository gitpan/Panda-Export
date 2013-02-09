use inc::Module::Install;

name     'Panda-Export';
all_from 'lib/Panda/Export.pm';

makemaker_args(
    CC    => 'g++',
    LD    => '$(CC)',
    XSOPT => '-C++',
);

auto_install;
WriteAll;

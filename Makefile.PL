use inc::Module::Install;

name     'Panda-Export';
all_from 'lib/Panda/Export.pm';

makemaker_args(
    CC    => 'c++',
    LD    => '$(CC)',
    XSOPT => '-C++',
);

auto_install;
WriteAll;

use strict;
use Panda::Install;

write_makefile(
    NAME     => 'Panda::Export',
    BIN_DEPS => 'Panda::XS',
);

use inc::Module::Install;

name 'RPG';
all_from 'lib/RPG.pm';

requires Catalyst => '5.64';

catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;

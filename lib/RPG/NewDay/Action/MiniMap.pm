package RPG::NewDay::Action::MiniMap;

use Moose;

extends 'RPG::NewDay::Base';

use RPG::Template;
use File::Slurp;

sub cron_string {
    my $self = shift;
     
    return '*/5 * * * *';
}

sub run {
    my $self = shift;
    
    my $c = $self->context;
    
    my $land_rs = $c->schema->resultset('Land')->search(
        {},
        {
            prefetch => 'kingdom',
            order_by => ['y','x'],
        }
    );
    
    $Template::Directive::WHILE_MAX = 100000;
        
    $land_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    
    my $map = RPG::Template->process(
        $c->config,
        'map/kingdom_map.html',
        {
            land_rs => $land_rs,
        },
    );
    
    write_file($c->config->{home} . '/root/minimap/kingdoms.html', $map);
}

1;
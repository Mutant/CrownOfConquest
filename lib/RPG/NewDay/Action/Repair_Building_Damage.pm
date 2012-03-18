package RPG::NewDay::Action::Repair_Building_Damage;

use Moose;

extends 'RPG::NewDay::Base';

use DateTime;

sub cron_string {
    my $self = shift;
     
    return $self->context->config->{repair_building_damage_cron_string};
}

sub run {
    my $self = shift;
    
    my @upgrades = $self->context->schema->resultset('Building_Upgrade')->search(
        {
            damage_last_done => {'<=', DateTime->now->subtract( days => 1 )},
        }
    );
        
    foreach my $upgrade (@upgrades) {
        $upgrade->damage(0);
        $upgrade->damage_last_done(undef);
        $upgrade->update;   
    }
}

1;

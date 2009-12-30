package RPG::Schema::Party_Town;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Party_Town');

__PACKAGE__->add_columns(qw/party_id town_id tax_amount_paid_today raids_today/);

__PACKAGE__->add_columns( prestige => { accessor => '_prestige' } );

__PACKAGE__->belongs_to( 'party', 'RPG::Schema::Party', { 'foreign.party_id' => 'self.party_id' } );

__PACKAGE__->set_primary_key(qw/party_id town_id/);

sub prestige {
    my $self = shift;
    my $new_prestige = shift;
    
    return $self->_prestige unless defined $new_prestige;
    
    if ($new_prestige > 100) {
        $new_prestige = 100;
    }
    if ($new_prestige < -100) {
        $new_prestige = -100;   
    }
    
    $self->_prestige($new_prestige);
}

1;
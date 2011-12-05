package RPG::Schema::Skill::Fletching;

use Moose::Role;

use Games::Dice::Advanced;
use Data::Dumper;

sub execute {
    my $self = shift;
    my $event = shift;
    
    return unless $event eq 'new_day';
    
    my $character = $self->char_with_skill;
    
    my ($item) = $character->get_equipped_item('Weapon');
    
    return unless $item;
    
    return unless $item->item_type->category->item_category eq 'Ranged Weapon';
    
    my $chance = $self->level * 9;
    
    if (Games::Dice::Advanced->roll('1d100') <= $chance) {
        my @ammo = $character->ammunition_for_item($item);

        my $ammo_item;
        my $current_quantity = 0;
                    
        if (@ammo) {
            $ammo_item = $self->result_source->schema->resultset('Items')->find( { item_id => $ammo[0]->{id}, }, );
            $current_quantity = $ammo[0]->{quantity};
        }
        else {
            my $ammunition_item_type_id = $item->item_type->attribute('Ammunition')->value;   

            $ammo_item = $self->result_source->schema->resultset('Items')->create(
                {
                    item_type_id => $ammunition_item_type_id,
                    character_id => $character->id,
                }
            );
        }
        
        my $extra = $character->intelligence + ( Games::Dice::Advanced->roll('1d40') - 20);
        $extra = 10 if $extra < 10;
        
        my $quant_rec = $ammo_item->variable_row('Quantity');        
        $quant_rec->item_variable_value($current_quantity+$extra);
        $quant_rec->update;
        
        my $message = RPG::Template->process(
            RPG::Schema->config,
            'skills/fletching.html',
            {
                character => $character,
                ammo_type => $ammo_item->item_type->item_type,
                made => $extra,
                weapon_type => $item->display_name,
            }
        );
        
        my $today = $self->result_source->schema->resultset('Day')->find_today();
        
        $character->party->add_to_day_logs(
            {
                day_id => $today->id,
                log => $message,
            }
        );         
    }
        
    
    
}

1;
package RPG::Schema::Role::Item_Type::Blank_Scroll;

use strict;
use warnings;

use Moose::Role;
use Try::Tiny;

with 'RPG::Schema::Role::Item_Type::Usable';

sub display_name {
    my $self = shift;
        
    return "Blank Scroll";
}

sub label {
    my $self = shift;
    
    return "Inscribe Spell on Scroll";   
}

sub is_usable {
    my $self = shift;
    my $combat = shift // 0;
    my $character = shift;
    
    return 0 if $combat;
        
    return 0 unless $character;
    
    return 0 if $character->level < RPG::Schema->config->{min_scroll_enscribe_level};
        
    return $character->is_spell_caster;
}

sub use {
    my $self = shift;
    my $target = shift;
    
    return unless $self->is_usable(0);
    
    my $character = $self->belongs_to_character;
    
    return unless $character;
    
    my $mem_spell = $character->find_related(
        'memorised_spells',
        {
            'spell.spell_id' => $target,
        },
        {
            prefetch => 'spell',
        }
    );

    return unless $mem_spell && $mem_spell->casts_left_today > 0;
   
    my $scroll_item_type = $self->result_source->schema->resultset('Item_Type')->find(
        {
            item_type => 'Scroll',
        }
    );
    
    my $new_item = $self->result_source->schema->resultset('Items')->create(
        {
            item_type_id => $scroll_item_type->id,
        }
    );
    
    my $no_room = 0;
    try {
        $new_item->add_to_characters_inventory($character);
    }
    catch {
        if ($_ =~ /Couldn't find room for item/) {
            $new_item->delete;
            
            $no_room = 1;             
        }
        else {
            die $_;
        }
    };
    
    if ($no_room) {
        return RPG::Combat::SpellActionResult->new(
            spell_name => $mem_spell->spell->spell_name,
            attacker   => $character,
            defender   => $self,
            type       => 'inscribe',
            custom     => {
                inventory_full => 1,
            },
        );
    }
    
    $mem_spell->number_cast_today( $mem_spell->number_cast_today + 1 );
    $mem_spell->update;    
    
    $new_item->variable('Spell', $mem_spell->spell->spell_name);
    $new_item->update;
        
    return RPG::Combat::SpellActionResult->new(
        spell_name => $mem_spell->spell->spell_name,
        attacker   => $character,
        defender   => $self,
        type       => 'inscribe',
    );       
}

sub target_list {
    my $self = shift;
    
    my $character = $self->belongs_to_character;
    
    my @spells = $character->castable_spells;
    
    my @targets;
    foreach my $mem_spell (@spells) {
        my $spell = $mem_spell->spell;
        push @targets, {
            name => $spell->spell_name,
            id => $spell->id,
        }   
    }
    
    return @targets;
}

sub target {'special'}

1;
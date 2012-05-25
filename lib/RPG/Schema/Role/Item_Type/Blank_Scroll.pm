package RPG::Schema::Role::Item_Type::Blank_Scroll;

use strict;
use warnings;

use Moose::Role;

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
    
    return 0 if $combat;
    
    my $character = $self->belongs_to_character;
    
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
    
    $mem_spell->number_cast_today( $mem_spell->number_cast_today + 1 );
    $mem_spell->update;
    
    my $scroll_item_type = $self->result_source->schema->resultset('Item_Type')->find(
        {
            item_type => 'Scroll',
        }
    );
    
    my $new_item = $self->result_source->schema->resultset('Items')->create(
        {
            item_type_id => $scroll_item_type->id,
            character_id => $character->id,
        }
    );
    
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
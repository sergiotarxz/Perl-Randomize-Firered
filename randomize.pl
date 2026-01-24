#!/usr/bin/env perl

use v5.42.0;
use strict;
use warnings;

use Data::Dumper;
use JSON   qw/decode_json to_json/;
use Encode qw/decode encode/;
use List::Util qw/any/;

sub get_moves {
    state $result;
    if ( !defined $result ) {
        my $moves_file = 'include/constants/moves.h';

        open my $fh, '<', $moves_file;

        $result = {};
        while ( my $line = <$fh> ) {
            next if $line !~ /#define MOVE_/;
            my ( $move, $number ) = $line =~ /^#define MOVE_(.*?)\s+(.*)$/;
            $result->{$move}{number} = $number;
        }
        fill_descriptions($result);
    }
    return $result;
}

sub fill_descriptions {
    my $result                 = shift;
    my $move_descriptions_file = 'src/move_descriptions.c';
    open my $fh, '<', $move_descriptions_file;
    while ( my $line = <$fh> ) {
        next if $line !~ /^const u8 gMoveDescription_/;
        my ( $move_camel_case, $description ) =
          $line =~ /^const u8 gMoveDescription_(.*?)\[\] = _\("(.*)"\);$/;
        my ($move) = snake_camel($move_camel_case);
        if ( !defined $result->{$move} ) {
            die "$move not found, programming error.";
        }
        $result->{$move}{description} = $description;
    }
}

sub snake_camel {
    return uc( shift =~ s/(?<=\w)([A-Z0-9])/_$1/gr );
}

sub camel_snake {
    my $word = shift;
    $word = lc $word;
    $word =~ s/^(.)/uc($1)/e;
    $word =~ s/_(.)/uc($1)/eg;
    return $word;
}

sub mix_tms_and_change_rare_candy_price {
    my $unique_non_repeated_moves = get_unique_moves_with_description();
    my $tm_file                   = 'src/data/items.json';
    my @moves;
    open my $fh, '<', $tm_file;
    my $data  = decode_json( join '', <$fh> );
    my $items = $data->{items};
    for my $item (@$items) {
        if ( $item->{itemId} eq 'ITEM_RARE_CANDY' ) {
            $item->{price} = 10;
            next;
        }
        next if $item->{itemId} !~ /^ITEM_TM[0-9]{2}$/;
        my $item_id         = $item->{itemId};
        for my $move (keys %$unique_non_repeated_moves) {
            if (any { $move eq $_ } hms()) {
                delete $unique_non_repeated_moves->{$move};
            }
        }
        my @candidate_moves = keys %$unique_non_repeated_moves;
        my $selected_move =
          $candidate_moves[ rand_int( scalar @candidate_moves ) ];
        delete $unique_non_repeated_moves->{$selected_move};
        $item->{moveId}              = camel_snake($selected_move);
        $item->{description_english} = decode 'utf-8',
          get_moves()->{$selected_move}{description};
        push @moves, $selected_move;
    }
    close $fh;
    open $fh, '>', $tm_file;
    binmode $fh, ':utf8';
    print $fh to_json($data);
    modify_tm_move_list( \@moves );
}

sub hms {
    return (qw/CUT FLY SURF STRENGTH FLASH ROCK_SMASH WATERFALL DIVE/ );
}

sub modify_tm_move_list {
    my @moves = @{ $_[0] };
    @moves =
      ( @moves, hms() );

    my $file = 'src/data/party_menu.h';
    open my $fh, '<', $file;
    binmode $fh, ':utf8';
    my $file_content = join '', <$fh>;
    close $fh;
    $file_content =~
s/(static const u16 sTMHMMoves_Duplicate\[\] =\s+\{).*?(\})/${1}@{[join ",\n", map { 'MOVE_' . $_ } @moves]}${2}/s;
    $file_content =~
s/(static const u16 sTMHMMoves\[\] =\s+\{).*?(\})/${1}@{[join ",\n", map { 'MOVE_' . $_ } @moves]}${2}/s;
    open $fh, '>', $file;
    print $fh $file_content;
}

sub allow_every_evolution {
    my $file = 'src/evolution_scene.c';
    open my $fh, '<', $file;
    my $file_contents = '';
    while (my $line = <$fh>) {
        if ($line =~ /IsNationalPokedexEnabled/) {
            $line = (' ' x 4 ) . "if (FALSE";
        }
        $file_contents .= $line; 
    }
    open $fh, '>', $file;
    print $fh $file_contents;
}

sub get_unique_moves_with_description {
    my $moves                     = get_moves;
    my $unique_non_repeated_moves = { map { $_ => 1 } keys %$moves };
    for my $move ( keys %$unique_non_repeated_moves ) {
        delete $unique_non_repeated_moves->{$move}
          if !defined $moves->{$move}{description};
    }
    return $unique_non_repeated_moves;
}

sub randomize_givemons {
    my $file = 'data/maps/SilphCo_7F/scripts.inc';
    my $file_contents = '';
    open my $fh, '<', $file;
    my %species = %{ get_species() };
    my @species = keys %species;
    my $lapras  = splice @species, rand_int( scalar @species ), 1;
    while (my $line = <$fh>) {
        $line =~ s/SPECIES_LAPRAS/SPECIES_$lapras/gm;
        $file_contents .= $line;
    } 
    open $fh, '>', $file;
    print $fh $file_contents;
    $file = 'data/maps/CeladonCity_Condominiums_RoofRoom/scripts.inc';
    $file_contents = '';
    open $fh, '<', $file;
    my $eevee  = splice @species, rand_int( scalar @species ), 1;
    while (my $line = <$fh>) {
        $line =~ s/SPECIES_EEVEE/SPECIES_$eevee/gm;
        $file_contents .= $line;
    }
    open $fh, '>', $file;
    print $fh $file_contents;
    $file = 'data/maps/Route4_PokemonCenter_1F/scripts.inc';
    $file_contents = '';
    open $fh, '<', $file;
    my $magikarp  = splice @species, rand_int( scalar @species ), 1;
    while (my $line = <$fh>) {
        $line =~ s/SPECIES_MAGIKARP/SPECIES_$magikarp/gm;
        $file_contents .= $line;
    }
    open $fh, '>', $file;
    print $fh $file_contents;
    $file = 'data/maps/CinnabarIsland_PokemonLab_ExperimentRoom/scripts.inc';
    $file_contents = '';
    open $fh, '<', $file;
    my $kabuto  = splice @species, rand_int( scalar @species ), 1;
    my $omanyte  = splice @species, rand_int( scalar @species ), 1;
    my $aerodactyl  = splice @species, rand_int( scalar @species ), 1;
    while (my $line = <$fh>) {
        $line =~ s/SPECIES_KABUTO/SPECIES_$kabuto/gm;
        $line =~ s/SPECIES_OMANYTE/SPECIES_$omanyte/gm;
        $line =~ s/SPECIES_AERODACTYL/SPECIES_$aerodactyl/gm;
        $file_contents .= $line;
    }
    open $fh, '>', $file;
    print $fh $file_contents;
    my $file = 'data/maps/SaffronCity_Dojo/scripts.inc';
    open $fh, '<', $file;
    my $hitmonlee  = splice @species, rand_int( scalar @species ), 1;
    my $hitmonchan  = splice @species, rand_int( scalar @species ), 1;
    my $file_contents = '';
    while (my $line = <$fh>) {
        $line =~ s/SPECIES_HITMONLEE/SPECIES_$hitmonlee/gm;
        $line =~ s/SPECIES_HITMONCHAN/SPECIES_$hitmonchan/gm;
        $file_contents .= $line;
    }
    open $fh, '>', $file;
    print $fh $file_contents;
}

sub get_seed {
    state $seed;
    if ( !defined $seed ) {
        $seed = srand;
    }
    return $seed;
}

sub rand_int {
    get_seed;
    my $number_of_values = shift;
    if ( !defined $number_of_values ) {
        die 'rand_int requires number of values';
    }
    return int( rand($number_of_values) );
}

sub get_species {
    state %species;
    if ( !%species ) {
        my $file = 'include/constants/species.h';
        open my $fh, '<', $file;
        while ( my $line = <$fh> ) {
            next if $line !~ /^#define SPECIES_/;
            next if $line =~ /NUM_SPECIES/;
            next if $line =~ /OLD_UNOWN/;
            my ($mon) = $line =~ /SPECIES_(.*?)\b/;
            next if $mon eq 'EGG';
            next if $mon eq 'NONE';
            $species{$mon} = 1;
        }
    }
    return \%species;
}

sub mix_wild_encounters {
    my %species = %{ get_species() };
    my $file    = 'src/data/wild_encounters.json';
    open my $fh, '<', $file;
    my $data = decode_json( join '', <$fh> );
    close $fh;
    my $fields      = $data->{wild_encounter_groups}[0]{fields};
    my $encounters  = $data->{wild_encounter_groups}[0]{encounters};
    my @field_types = map { $_->{type} } @$fields;
    my @species     = keys %species;

    for my $encounter (@$encounters) {
        for my $field (@field_types) {
            next if !defined $encounter->{$field};
            my $mons = $encounter->{$field}{mons};
            $mons = [
                map {
                    $_->{species} =
                      'SPECIES_' . $species[ rand_int( scalar @species ) ];
                    $_
                } @$mons
            ];
            $encounter->{$field}{mons} = $mons;
        }
    }
    open $fh, '>', $file;
    binmode $fh, ':utf8';
    print $fh to_json($data);
}

sub change_starter {
    my $file    = 'data/maps/PalletTown_ProfessorOaksLab/scripts.inc';
    my %species = %{ get_species() };
    my @species = keys %species;
    my ( $bulbasaur, $charmander, $squirtle );

    $bulbasaur  = splice @species, rand_int( scalar @species ), 1;
    $charmander = splice @species, rand_int( scalar @species ), 1;
    $squirtle   = splice @species, rand_int( scalar @species ), 1;

    open my $fh, '<', $file;
    my $file_contents = join '', <$fh>;
    close $fh;
    $file_contents =~ s/SPECIES_BULBASAUR/SPECIES_$bulbasaur/gs;
    $file_contents =~ s/SPECIES_CHARMANDER/SPECIES_$charmander/gs;
    $file_contents =~ s/SPECIES_SQUIRTLE/SPECIES_$squirtle/gs;
    open $fh, '>', $file;
    print $fh $file_contents;
}

sub add_items_to_shops {
    my @files = qw{./data/maps/FuchsiaCity_Mart
      ./data/maps/ViridianCity_Mart
      ./data/maps/SevenIsland_Mart
      ./data/maps/SaffronCity_Mart
      ./data/maps/SixIsland_Mart
      ./data/maps/PewterCity_Mart
      ./data/maps/LavenderTown_Mart
      ./data/maps/ThreeIsland_Mart
      ./data/maps/CinnabarIsland_Mart
      ./data/maps/VermilionCity_Mart
      ./data/maps/CeruleanCity_Mart
      ./data/maps/FourIsland_Mart
    };

    for my $file (@files) {
        $file .= '/scripts.inc';
        open my $fh, '<', $file;
        my $file_contents = '';
        while ( my $line = <$fh> ) {
            $file_contents .= $line;
            if ( $line =~ /\.2byte ITEM_/ ) {
                $file_contents .= "\t.2byte ITEM_RARE_CANDY\n";
                last;
            }
        }
        $file_contents .= join '', <$fh>;
        close $fh;
        open $fh, '>', $file or die "$!";
        print $fh $file_contents;
    }
}

sub mix_level_moves {
    my $file = 'src/data/pokemon/level_up_learnsets.h';
    open my $fh, '<', $file;
    my $file_contents = '';
    my %moves         = %{ get_moves() };
    my @moves         = keys %moves;
    while ( my $line = <$fh> ) {
        if ( $line !~ /#define/ ) {
            if ( $line =~ /LEVEL_UP_MOVE/ ) {
                my ($level) = $line =~ /LEVEL_UP_MOVE\((\d+), MOVE_/;
                die $line if !defined $level;
                my $new_move = splice @moves, rand_int( scalar @moves ), 1;
                $line =
                  ( ' ' x 4 ) . "LEVEL_UP_MOVE($level, MOVE_$new_move),\n";
            }
            if ( $line =~ /LEVEL_UP_END/ ) {
                @moves = keys %moves;
            }
        }
        $file_contents .= $line;
    }
    open $fh, '>', $file;
    print $fh $file_contents;
}

sub get_four_random_moves {
    my %moves         = %{ get_moves() };
    my @moves         = keys %moves;
    my @selected_moves = map { splice @moves, rand_int( scalar @moves ), 1 } (0..3);
    return @selected_moves;
}

sub mix_trainers {
    my $file = './src/data/trainer_parties.h';
    open my $fh, '<', $file;
    my $file_contents = '';
    my $first_real_trainer = 0;
    my $current_party;
    my %species = %{ get_species() };
    while (my $line = <$fh>) {
        if ($line =~ /const/) {
            ($current_party) = $line =~ /sParty_(\w+)/;
            if ($line !~ /DUMMY/) {
                $first_real_trainer = 1;
            }
            $file_contents .= $line;
            next;
        }
        if (!$first_real_trainer) {
            $file_contents .= $line;
            next;
        }
        if ($line =~ /\.species/) {
            my @species = keys %species;
            my $species = splice @species, rand_int( scalar @species ), 1;
            # TODO: If important trainer do it better with full evolved/legendaries
            $line = (' ' x 8) . ".species = SPECIES_$species,\n";
        }
        if ($line =~ /\.moves/) {
            $line = (' ' x 8) . ".moves={@{[join ', ', map { 'MOVE_' . $_ } get_four_random_moves()]}}\n";
        }
        $file_contents .= $line;
    }
    open $fh, '>', $file;
    print $fh $file_contents;
}

sub allow_forget_hm {
    my $file = 'src/pokemon_summary_screen.c';
    open my $fh, '<', $file;
    my $file_contents = '';
    while (my $line = <$fh>) {
        if ($line =~ /IsMoveHm/) {
            $line = (' ' x 4) . "if (FALSE)\n"

        }
        $file_contents .= $line;
    }
    close $fh;
    open $fh, '>', $file;
    print $fh $file_contents;
    $file = 'src/battle_script_commands.c';
    $file_contents = '';
    open $fh, '<', $file;
    while (my $line = <$fh>) {
        if ($line =~ /IsHMMove2/) {
            $line = (' ' x 16) . "if (FALSE)\n"
        }
        $file_contents .= $line;
    }
    open $fh, '>', $file;
    print $fh $file_contents;
}

sub tm_never_spent {
    my $file = 'src/party_menu.c';
    open my $fh, '<', $file;
    my $file_contents = '';
    while (my $line = <$fh>) {
        if ($line =~ /item.*<.*ITEM_HM01/i) {
            $line = (' ' x 4) . "if (FALSE)\n"
        }
        $file_contents .= $line;
    }
    close $fh;
    open $fh, '>', $file;
    print $fh $file_contents;

}

sub get_abilities {
    my $file = 'include/constants/abilities.h';
    state %abilities;
    if (!%abilities) {
        open my $fh, '<', $file;
        while (my $line = <$fh>) {
            my ($ability) = $line =~ /define ABILITY_(.*?)\s/;
            if (!defined $ability) {
                next;
            }
            if ($ability eq 'NONE') {
                next;
            }
            $abilities{$ability} = 1;
        }
    }

    return \%abilities;
}
sub mix_abilities {
    my $file = 'src/data/pokemon/species_info.h';
    my $file_contents;
    open my $fh, '<', $file;
    while (my $line = <$fh>) {
        if ($line =~ /\.abilities/ && $line !~ /\\/) {
            my @abilities = keys %{get_abilities()};
            my $move1 = splice @abilities, rand_int( scalar @abilities ), 1;
            my $move2 = splice @abilities, rand_int( scalar @abilities ), 1;
            $line = (' ' x 8) . ".abilities = { ABILITY_$move1, ABILITY_$move2 },\n"
        }
        $file_contents.=$line;
    }
    close $fh;
    open $fh, '>', $file;
    print $fh $file_contents;
}

sub obey {
    my $file = 'src/battle_util.c';
    my $file_contents = '';
    open my $fh, '<', $file;
    while (my $line = <$fh>) {
        if ($line =~ /SPECIES_DEOXYS/) {
            $line = (' ' x 4) . "if (TRUE\n"
        }
        if ($line =~ /SPECIES_MEW/) {
            $line = (' ' x 8) . "&& TRUE)\n"
        }
        $file_contents .= $line;
    }
    open $fh, '>', $file;
    print $fh $file_contents;
}

my $seed = get_seed;
say 'RANDOM SEED: ' . $seed;
mix_tms_and_change_rare_candy_price;
mix_wild_encounters;
change_starter;
add_items_to_shops;
mix_level_moves;
mix_trainers;
allow_forget_hm;
tm_never_spent;
mix_abilities;
allow_every_evolution;
randomize_givemons;
obey;

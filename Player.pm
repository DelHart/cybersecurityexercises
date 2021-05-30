package Player;
use local::lib '/home/del/repos/2021s/csc452/webrisk';
use Company;
use Carp;
use Data::Dumper;
use Math::GSL::RNG;
use Math::GSL::Randist qw/:all/;

our $ACTION_ID = 1000;
our $RNG = Math::GSL::RNG->new();

our $DIFFICULTIES = {
    '0' => 'very easy',
    '1' => 'easy',
    '2' => 'easy',
    '3' => 'average',
    '4' => 'average',
    '5' => 'average',
    '6' => 'difficult',
    '7' => 'difficult',
    '8' => 'very difficult',
    '9' => 'very difficult'
};

our $DIFF_MAP = {
    'very easy' => {'cost' => 100,
                    'diff_mod' => -18,
                    'time' => 3, },
    'easy' => {'cost' => 300,
                    'diff_mod' => -12,
                    'time' => 5, },
    'average' => {'cost' => 500,
                    'diff_mod' => -6,
                    'time' => 7, },
    'difficult' => {'cost' => 700,
                    'diff_mod' => 0,
                    'time' => 8, },
    'very difficult' => {'cost' => 900,
                    'diff_mod' => 6,
                    'time' => 9, },
};

our $MAX_AREAS = 4;

our @FIELDS = qw (
    identify 
    detection 
    protection 
    response 
    recovery 
    );
our @ASSETS = qw (
    development
    operations
    sales
    );

our @AREAS;
push @AREAS, @FIELDS, @ASSETS;

our @ATTRIBS = qw (id name budget score nexttime);

our $FIELD_INDEX = {};
for (my $i=0; $i < $#AREAS; $i++ ) {
    $FIELD_INDEX->{$AREAS[$i]} = $i;
}

sub new {
    my ($class, $args) = @_;
    my $ref = {'id' => -1,
                'name' => 'default name',
                'budget' => 0,
                'score' => 0,
                'new_action_index' => 0,
                'nexttime' => -1};

    $ref->{'skills'} = [];
    $ref->{'offset'} = [];
    $ref->{'percepts'} = [];
    $ref->{'areas'} = [];
    $ref->{'area_idx'} = [];
    $ref->{'actions'} = { };
    foreach my $f (@AREAS) {
        push @{$ref->{'skills'}}, 0;
        push @{$ref->{'offset'}}, 0;
        push @{$ref->{'percepts'}}, 0;
        push @{$ref->{'areas'}}, 0;
    }
    my $self = bless $ref, $class;
}

sub init {
    my $self = shift;
    my $data = shift;

    foreach my $key (keys %$data) {
        if ($key eq 'skills') {
            for (my $i=0; $i<=$#{$data->{$key}}; $i++  ) {
                ${$self->{$key}}[$i] = ${$data->{$key}}[$i];
            }
        } elsif ($key eq 'offset') {
            for (my $i=0; $i<=$#{$data->{$key}}; $i++  ) {
                ${$self->{$key}}[$i] = ${$data->{$key}}[$i];
            }
        } elsif ($key eq 'areas') {
            for (my $i=0; $i<=$#{$data->{$key}}; $i++  ) {
                ${$self->{$key}}[$i] = ${$data->{$key}}[$i];
            }
        } else {
            $self->{$key} = $data->{$key};
        }
    }

    for (my $i=0; $i<=$#{$self->{'percepts'}}; $i++  ) {
        $self->update_percept($i);
    }
    $self->count_areas();

} # init

sub update_percept {
    my $self = shift;
    my $i = shift;

    # the player perception of their skill is normally distributed 
    # mean - based on their skill plus their offset
    # sigma - lack of skill = ( 100 - skill ) / 4
    my $base = ${$self->{'skills'}}[$i] + ${$self->{'offset'}}[$i];
    my $los = 100 - ${$self->{'skills'}}[$i];
    my $sigma = $los / 4;
    my $percept = gsl_ran_gaussian ($RNG->raw(), $sigma) + $base;
    $percept = 1 if ($percept < 1);
    ${$self->{'percepts'}}[$i] = int ($percept);

} # update_percept

sub count_areas {
    my $self = shift;
    my $num_areas = 0;
    $self->{'area_idx'} = [];

    for (my $i=0; $i<=$#{$self->{'percepts'}}; $i++  ) {
        if (${$self->{'areas'}}[$i] > 0) {
            $num_areas++;
            push @{$self->{'area_idx'}}, $i;
        }
    }

    $self->{'num_areas'} = $num_areas;

} # count_areas

sub user_info {
    my $self = shift;
    my $data = {};

    foreach my $a (@ATTRIBS) {
        $data->{$a} = $self->{$a};
    }
    my $skills = {};
    my $areas = {};
    for (my $i=0; $i<=$#{$self->{'percepts'}}; $i++  ) {
        $skills->{$AREAS[$i]} = ${$self->{'percepts'}}[$i];
        $areas->{$AREAS[$i]} = ${$self->{'areas'}}[$i];
    }
    $data->{'skills'} = $skills;
    $data->{'areas'} = $areas;
    $data->{'num_areas'} = $self->{'num_areas'};

    # figure out available actions
    # personal actions
    # company actions
    $data->{'actions'} = {};
    my @keys = sort keys %{$self->{'actions'}};
    while ($#keys < 3) {
        $self->refreshActions();
        @keys = sort keys %{$self->{'actions'}};
    }
    for (my $i=0; $i<=$#keys; $i++  ) {
        my $k = $keys[$i];
        $data->{'actions'}->{$k} = $self->{'actions'}->{$k};
        $data->{'actions'}->{$k}->{'an'} = $i;
    }

    return $data;

} # user_info

sub enable {
    my $self = shift;
    my $area = shift;
    my $time = shift;

    if ($time < $self->{'nexttime'}) {
        return 'player is still busy will be done at: ' . $self->{'nexttime'} . ' current ' . $time;
    }

    my $ai = $FIELD_INDEX->{$area};

    if ($self->{'num_areas'} >= $MAX_AREAS) {
        return 'already at maximum number of enabled areas (' . $MAX_AREAS . ')';
    }

    ${$self->{'areas'}}[$ai] = 1;
    $self->count_areas();

    $self->{'nexttime'} = $time + 3;

    return "$area enabled";

} # enable

sub disable {
    my $self = shift;
    my $area = shift;
    my $time = shift;

    if ($time < $self->{'nexttime'}) {
        return 'player is still busy will be done at: ' . $self->{'nexttime'} . ' current ' . $time;
    }

    my $ai = $FIELD_INDEX->{$area};

    ${$self->{'areas'}}[$ai] = 0;
    $self->count_areas();

    $self->{'nexttime'} = $time + 3;

    return "$area disabled";

} # disable

sub do_action {
    my $self = shift;
    my $action = shift;
    my $doit = shift;
    my $time = shift;

    if ($time < $self->{'nexttime'}) {
        return 'player is still busy will be done at: ' . $self->{'nexttime'} . ' current ' . $time;
    }

    if ($doit == 0) {
        $self->{'nexttime'} = $time + 1;
        # having trouble getting delete to work
        my $data = {};
        my @keys = keys %{$self->{'actions'}};
        foreach my $k (@keys) {
            next if ($k == $action);
            $data->{$k} = $self->{'actions'}->{$k};
        }
        $self->{'actions'} = $data;
        return "action dismissed";
    } # if dismissed

    my $a = $self->{'actions'}->{$action};
    # which type of action
    # improve skill compare action level versus skill level to see amount of success
    # asset actions improve asset - compare player skill level versus asset level and action difficulty for success
    # security function actions
    #   improve function compare player skill level versus function level and difficulty 
    #   operate temporarily raise level - not implemented for now
    $self->{'nexttime'} = $time + $a->{'time'};
    if ($a->{'cost'} > $self->{'budget'}) {
        return 'player has insufficient budget';
    }

    my $msg = '';

    if ($a->{'type'} eq 'skill') {
        ${$self->{'skills'}}[$a->{'data'}] += 3;
        $self->update_percept($a->{'data'});
        $msg = 'skill ' . $Player::AREAS[$a->{'data'}] . ' improved.';
    }
    elsif ($a->{'type'} eq 'security' ) {
        my $skill = int (${$self->{'skills'}}[$a->{'data'}] / 10) + 1;
        my $comp = $self->{'company'};
        ${$comp->{'sfns'}}[$a->{'data'}] += $skill;
        $msg = 'security fn ' . $Player::AREAS[$a->{'data'}] . 'improved.';
    }
    elsif ($a->{'type'} eq 'asset' ) {
    }

    my $data = {};
    my @keys = keys %{$self->{'actions'}};
    foreach my $k (@keys) {
       next if ($k == $action);
       $data->{$k} = $self->{'actions'}->{$k};
    }
    $self->{'actions'} = $data;

    return $msg;

} # do_action


sub add_budget {
    my $self = shift;
    my $money = shift;

    $self->{'budget'} += $money;

} # add_budget

sub set_company {
    my $self = shift;
    my $company = shift;
    $self->{'company'} = $company;
} # set_company

sub refreshActions {
    my $self = shift;
    my $id = $ACTION_ID++;

    my $r = int (rand() * 10);
    my $r2 = int (rand() * 10);
    my $diff = $DIFFICULTIES->{$r};

    my $data = { 'id' => $id, 
                 'cost' => $DIFF_MAP->{$diff}->{'cost'},
                 'difficulty' => $diff,
                 'time' => $DIFF_MAP->{$diff}->{'time'}
    };

    my $area;
    # choose an area
    my $na = $self->{'num_areas'};
    if ($na > 0) {
        $area = $id % $na;
        $area = ${$self->{'area_idx'}}[$area];

        # is this an asset or a security function
        if ($area < 5) {
            # security function
            if ($r2 < 7) {
                $data->{'name'} = 'improve security ' . $AREAS[$area]; 
                $data->{'description'} = 'improve security ' . $AREAS[$area]; 
                $data->{'data'} = $area;
                $data->{'type'} = 'security';
            }
            else {
                $data->{'name'} = 'improve skill ' . $AREAS[$area]; 
                $data->{'description'} = 'improve skill ' . $AREAS[$area]; 
                $data->{'data'} = $area;
                $data->{'type'} = 'skill';
            }

        }
        else {
            # asset
            if ($r2 < 7) {
                $data->{'name'} = 'improve asset ' . $AREAS[$area]; 
                $data->{'description'} = 'improve asset ' . $AREAS[$area]; 
                $data->{'data'} = $area;
                $data->{'type'} = 'asset';
            }
            else {
                $data->{'name'} = 'improve skill ' . $AREAS[$area]; 
                $data->{'description'} = 'improve skill ' . $AREAS[$area]; 
                $data->{'data'} = $area;
                $data->{'type'} = 'skill';
            }
        }

    }
    else {
        $area = $id % $#AREAS;
        $data->{'name'} = 'improve skill ' . $AREAS[$area]; 
        $data->{'description'} = 'improve skill ' . $AREAS[$area]; 
        $data->{'data'} = $area;
        $data->{'type'} = 'skill';
    }

    $self->{'actions'}->{$id} = $data;

} # refreshActions




sub TO_JSON {
    my $self = shift;

    my $data = {};

    foreach my $key (keys %$self) {
        if ($key eq 'skills') {
            my @copy_array = @{$self->{$key}};
            $data->{$key} = \@copy_array;
        } elsif ($key eq 'company') {
            $data->{'company'} = $self->{'company'}->{'id'};
        } elsif ($key eq 'offset') {
            my @copy_array = @{$self->{$key}};
            $data->{$key} = \@copy_array;
        } elsif ($key eq 'areas') {
            my @copy_array = @{$self->{$key}};
            $data->{$key} = \@copy_array;
        } elsif ($key eq 'percepts') {
        } else {
            $data->{$key} = $self->{$key};
        }
    }

    return $data;
    #return '{ "id" : "' . $self->{'id'} . '"}';
} # TO_JSON

1;
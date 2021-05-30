package Company;
use local::lib '/home/del/repos/2021s/csc452/webrisk';
use Player;
use Carp;
use Data::Dumper;

our $ASSET_PERIOD = 10;
our $THREAT_PERIOD = 10;
our $THREAT_CLOCK = 0;
our $THREAT_TIME = 0;
our $THREAT_ID = 0;
our @THREATS = ();

sub new {

    my ($class, $args) = @_;
    my $ref = {'id' => -1,
                'name' => 'default name',
                'messages' => [],
                'asset_clock'  => 0,
                'cur_threat' => 0,
                'known_threats' => {},
                'basetime' => -1,
                'curtime' => -1};

    $ref->{'assets'} = [];
    $ref->{'players'} = {};
    $ref->{'sfns'} = [];

    foreach my $f (@Player::FIELDS) {
        push @{$ref->{'sfns'}}, 0;
    }

    my $self = bless $ref, $class;
}

sub add_asset {
    my $self = shift;
    my $a = shift;
    #$self->{'assets'}->{$a->{'id'}} = $a;
}


sub update {
    my $self = shift;
    my $time = shift;

    # compare times

    # look at time and compare to the previous current time
    # simulate all events during that time frame
    # create new events as necessary
    my $threat_time = $time - $THREAT_TIME + $THREAT_CLOCK;
    while ($threat_time >= $THREAT_PERIOD) {
        # generate new threat
        # have a slow start to the number of threats
        $THREAT_ID++;
        $threat_time = $threat_time - $THREAT_PERIOD;

        my $ramp = 6 - int ($THREAT_ID / 10);
        if ($ramp > 1) {
            my $m = $THREAT_ID % $ramp;
            next unless ($m == 0);
        }
        push @THREATS, { 'id' => $THREAT_ID, 'time' => $time + 20, 'strength' => $THREAT_ID };
        $THREAT_TIME = $time if ($time > $THREAT_TIME);
    }
    $THREAT_CLOCK = $threat_time;

    # check to see what attacks have occurred during this time frame
    my $ct = $self->{'cur_threat'};
    foreach my $ti ($ct .. $#THREATS) {
        my $t = $THREATS[$ti];
        my $diff = $t->{'time'} - $self->{'curtime'};
        if ($diff < 5) {
            # resolve this attack
            $self->{'cur_threat'} += 1;
            push @{$self->{'messages'}}, {'time' => $t->{'time'}, 'message' => $t->{'id'} . ' attack occurred'};
        }

    }

    my $dt = $time - $self->{'curtime'};
    foreach my $pi (keys %{$self->{'players'}}) {
        my $p = $self->{'players'}->{$pi};
        $p->add_budget ($dt * 100);
    }

    foreach my $ai (@{$self->{'assets'}}) {
        $ai->{'value'} += $dt * 3;
        #$self->{'assets'}->{$ai}->{'value'} += $dt * 3;
    }

    $self->{'curtime'} = $time;

} # update

sub init {
    my $self = shift;
    my $players = shift;
    my $craw = shift;
    my $time = shift;

    # init global info
    $THREAT_TIME = $time;
    $THREAT_CLOCK = 0;
    $THREAT_ID = 20;
    @THREATS = ();

    foreach my $pi (@{$craw->{'p'}}) {
        $self->{'players'}->{$pi} = $players->{$pi};
        $players->{$pi}->set_company ($self);
    }

    $self->{'assets'} = [];

    foreach my $ci (@{$craw->{'assets'}}) {
        push @{$self->{'assets'}}, $ci;
        #$self->{'assets'}->{$ci} = $craw->{'assets'}->{$ci};

    #    $self->{'assets'}->{$ci}->{'sfns'} = [];
    #    foreach my $f (@Player::FIELDS) {
    #        push @{$self->{'assets'}->{$ci}->{'sfns'}}, 0;
    #    }
    }

    $self->{'sfns'} = [];
    foreach my $si (@{$craw->{'sfns'}}) {
        push @{$self->{'sfns'}}, $si;
    }


    $self->{'id'} = $craw->{'id'};
    $self->{'basetime'} = $time;
    $self->{'curtime'} = $time;

} # init

sub company_info {
    my $self = shift;
    my $data = { 'sfns' => {}, 'threats' => [], 'messages' => [], 'assets' => [] };

    my $i = 0;
    foreach my $f (@Player::FIELDS) {
        $data->{'sfns'}->{$f} = ${$self->{'sfns'}}[$i];
        $i++;
    }

    foreach my $ai (@{$self->{'assets'}}) {
        #$data->{'assets'}->{$ai} = $self->{'assets'}->{$ai};

        my $i = 0;
        $ai->{'fns'} = {};
        foreach my $f (@Player::FIELDS) {
            $ai->{'fns'}->{$f} = $ai->{'sfns'}[$i];
            $i++;
        }

        push @{$data->{'assets'}}, $ai;

    }

    my @nearness = (0, 0, 0);
    foreach my $t (@THREATS) {
        my $dist = $t->{'time'} - $self->{'curtime'};
        next if ($dist < 0);

        my $range = int ( $dist / 15);
        my $pos = $nearness[$range]++;
        my $ti = { 'id' => $t->{'id'},
                   'strength' => $t->{'strength'},
                   'range' => $range,
                   'time'  => $t->{'time'},
                   'pos' => $pos};
        push @{$data->{'threats'}}, $ti;
    }

    my $msgs = $self->{'messages'};
    while ($#$msgs > 8) {
        shift @{$msgs};
    }

    foreach my $m (@{$msgs}) {
        push @{$data->{'messages'}}, $m;
    }


    return $data;
}

sub TO_JSON {
    my $self = shift;

    my $data = { 'id' => $self->{'id'},
                 'assets' => [],
                 'sfns'   => [],
                 'p' => [] };

    foreach my $pi (keys %{$self->{'players'}}) {
        push @{$data->{'p'}}, $pi;
    }

    foreach my $si (@{$self->{'sfns'}}) {
        push @{$data->{'sfns'}}, $si;
    }

    foreach my $ai (@{$self->{'assets'}}) {
        push @{$data->{'assets'}}, $ai;
    }

    return $data;
} # TO_JSON


1;
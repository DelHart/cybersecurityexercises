#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use Carp;
use Data::Dumper;
use local::lib '/home/del/repos/2021s/csc452/webrisk';
use File::Slurp;
use Player;
use Company;
use JSON;

my $config = {'example' => 'data'};
my $players = {};
my $companies = {};

# /ww/user/action/object
# /ww/user 

get '/ww/:user' => 
   sub ($c) {
      my $id = $c->param('user');
      $c->stash(id => $id);
      $c->stash(fields => [@Player::FIELDS]);
      $c->stash(assets => [@Player::ASSETS]);
      $c->render (template => 'player');
      };

get '/ww/:user/setup' => 
   sub ($c) {
      my $id = $c->param('user');
      my $time = time();
      my $p = $players->{$id}->user_info ();
      my $cd = $players->{$id}->{'company'}->company_info ();
      $c->render (json => {'time' => $time, 'p' => $p, 'c' => $cd});
      };

get '/ww/:user/enable/:area' => 
   sub ($c) {
      my $id   = $c->param('user');
      my $area = $c->param('area');
      my $time = time();
      my $p = $players->{$id};
      my $msg = $p->enable($area, $time);
      $p->{'company'}->update($time);
      my $pd = $p->user_info ();
      my $cd = $p->{'company'}->company_info ();
      $c->render (json => {'time' => $time, 'p' => $pd, 'c' => $cd, 'msg' => $msg});
      };

get '/ww/:user/disable/:area' => 
   sub ($c) {
      my $id   = $c->param('user');
      my $area = $c->param('area');
      my $time = time();
      my $p = $players->{$id};
      my $msg = $p->disable($area, $time);
      $p->{'company'}->update($time);
      my $pd = $p->user_info ();
      my $cd = $p->{'company'}->company_info ();
      $c->render (json => {'time' => $time, 'p' => $pd, 'c' => $cd, 'msg' => $msg});
      };

get '/ww/:user/action/:doit/:an' => 
   sub ($c) {
      my $id   = $c->param('user');
      my $doit = $c->param('doit');
      my $action = $c->param('an');
      my $time = time();
      my $p = $players->{$id};
      my $msg = $p->do_action($action, $doit, $time);
      $p->{'company'}->update($time);
      my $pd = $p->user_info ();
      my $cd = $p->{'company'}->company_info ();
      $c->render (json => {'time' => $time, 'p' => $pd, 'c' => $cd, 'msg' => $msg});
      };


# admin user
get '/ww/:user/save/:file' =>
   sub ($c) {
      my $id = $c->param('user');
      my $file = $c->param('file');
      my $time = time();

      if ($id == 222) {
         # load config
         $config->{"p"} = [ values %$players ];
         $config->{"c"} = [ values %$companies ];
         #carp Dumper $players;

         my $json = JSON->new->convert_blessed;
         my $fileh;
         open $fileh, ">", $file;
         print $fileh $json->pretty->encode ($config);
         close $fileh;
      }
      $c->render (json => {'time' => $time});

   };

get '/ww/:user/load/:file' =>
   sub ($c) {
      my $id = $c->param('user');
      my $file = $c->param('file');
      my $time = time();
      if ($id == 222) {

         my $json = JSON->new;
         my $data = read_file ($file);
         $config = $json->decode ($data);

         # interpret config
         carp Dumper $config;
         my $ps = $config->{'p'};
         foreach my $p (@$ps) {
            my $pid = $p->{'id'};
            $players->{$pid} = new Player if (!(defined $players->{$pid}));
            $players->{$pid}->init ($p);
         }

         my $cs = $config->{'c'};
         foreach my $c (@$cs) {
            my $cid = $c->{'id'};
            $companies->{$cid} = new Company if (!(defined $companies->{$cid}));
            $companies->{$cid}->init ($players, $c, $time);
         }
      }
      $c->render (json => {'time' => $time});

   };

app->start;

# <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.5.1/jquery.min.js"></script>

__DATA__

@@ main.html.ep

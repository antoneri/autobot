
       ###    ##     ## ########  #######  ########   #######  ########
      ## ##   ##     ##    ##    ##     ## ##     ## ##     ##    ##
     ##   ##  ##     ##    ##    ##     ## ##     ## ##     ##    ##
    ##     ## ##     ##    ##    ##     ## ########  ##     ##    ##
    ######### ##     ##    ##    ##     ## ##     ## ##     ##    ##
    ##     ## ##     ##    ##    ##     ## ##     ## ##     ##    ##
    ##     ##  #######     ##     #######  ########   #######     ##

use strict;
use warnings;

use Irssi;
use LWP::UserAgent;
use XML::Simple 'XMLin';
use Text::Levenshtein 'distance';
use JSON qw(decode_json);
use DateTime;

use lib "/home/tfy12/tfy12aen/.autobot/scripts/autobot/TitleMangler/lib";
use TitleMangler;

use vars qw($VERSION %IRSSI);

$VERSION = "0.2";
%IRSSI = (authors     => "Anton Eriksson",
          contact     => "anton\@rizon",
          name        => "autobot",
          date        => "2014-01-23",
          updated     => "2014-11-27",
          description => "Auto reply IRC-bot/Race of shapeshifting robots.",
          license     => "BSD 2-clause",
          url         => "http://www.github.com/antoneri/autobot/");

use constant API_TIMEOUT => 2*60*1000;  #miliseconds
use constant GITHUB_USER => 'antoneri';
use constant GITHUB_REPO => 'autobot';

sub auto_op {
  my ($srv, $msg, $nick, $addr, $target) = @_;

  my @opers = qw(Ades anton Angan hunky\\ Tomas);
  my %hashop = map { $_ => 1 } @opers;

  if ($msg eq "op plz") {
    if (exists($hashop{$nick})) {
      $srv->command("OP $target $nick");
    } else {
      $srv->command("MSG $target Nope.");
    }
  }
}

sub dice {
  my ($srv, $msg, $nick, $addr, $target) = @_;

  if ($msg =~ /^!dice ([^;]+(?:;[^;]+)+)$/i) {

    my @choices = split(';', $1);
    my $i = int(rand(scalar @choices));

    $choices[$i] =~ s/^\s+|\s+$//g;  # trim whitespace

    $srv->command("MSG $target Tärningen bestämmer: $choices[$i]")
  }
}

### We don't want 'spotify' and 'TitleMangler' to
### both react to spotify http uri:s
sub uri_handler{
  my ($srv, $msg, $nick, $addr, $target) = @_;

  if ($msg =~ /(?!https?:\/\/open\.spotify\.com\/|spotify:)
               (album|artist|track)[:\/]
               ([a-zA-Z0-9]+)\/?/ix) {

    my $spotify = spotify($1, $2);
    $srv->command("MSG $target $spotify") if $spotify;

  } else {

    my $title = TitleMangler::get($msg);
    $srv->command("MSG $target $title") if $title;

  }
}


### The below code is based on code copyrighted by
### Simon Lundstöm (http://soy.se/code/)
sub spotify {
  my ($kind, $id) = @_;

  my $url = "http://ws.spotify.com/lookup/1/?uri=spotify:$kind:$id";
  my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>5);
  $ua->agent($IRSSI{name}.".pl/$VERSION ".$ua->_agent);
  my $res = $ua->get($url);

  if ($res->is_success) {
    my ($xml, $info) = (XMLin($res->content), undef);

    if ($xml->{'artist'}->{'name'}) {
      $info .= $xml->{'artist'}->{'name'};
    } else {
      for (keys %{$xml->{'artist'}}) {
        $info .= $_.", ";
      }

      # Trim off the last ", "
      $info =~ s/, $//;
    }

    $info .= " - ";

    if ($xml->{'name'}) {
      $info .= $xml->{'name'};
    }

    if ($xml->{'album'}->{'name'}) {
      $info .= " (" . $xml->{'album'}->{'name'} . ")";
    }

    return "[Spotify] $info";
  }

  return 0;
}

sub get_recent_commits {
  my %args = @_;

  my $dt = DateTime->now->set_time_zone("GMT");
  $dt->subtract(minutes => $args{minutes});

  my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>5);
  $ua->agent($IRSSI{name}.".pl/$VERSION ".$ua->_agent);
  my $url = "https://api.github.com/repos/$args{user}/$args{repo}/commits?since=$dt";
  my $res = $ua->get($url);

  if ($res->is_success) {
    my $json = decode_json($res->decoded_content);
    return @{$json} if $json;
  }

  return [];
}

sub show_commits {
  my @commits = get_recent_commits(user => GITHUB_USER, repo => GITHUB_REPO, minutes => API_TIMEOUT);
  my $srv = Irssi::active_server();

  foreach my $c (@commits) {
    $srv->command("MSG #alvsbyn [autobot] Commit: $c->{commit}->{message}");
  }
}

Irssi::timeout_add(API_TIMEOUT, show_commit);
Irssi::signal_add("message public", "auto_op");
Irssi::signal_add("message public", "dice");
Irssi::signal_add("message public", "uri_handler");


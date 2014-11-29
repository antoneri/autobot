
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
use DateTime;
use LWP::UserAgent;
use JSON qw(decode_json);
use XML::Simple qw(XMLin);

use File::Basename;
use lib dirname (__FILE__) . "/lib";
use TitleMangler;
#use Helpers qw(command message);

our $VERSION = "0.2";
our %IRSSI   = (authors     => "Anton Eriksson",
                contact     => "anton\@rizon",
                name        => "autobot",
                date        => "2014-01-23",
                updated     => "2014-11-29",
                description => "IRC-bot",
                license     => "BSD 2-clause",
                url         => "http://www.github.com/antoneri/autobot/");

use constant {
  API_TIMEOUT => 2,  #minutes
  GITHUB_USER => 'antoneri',
  GITHUB_REPO => 'autobot',

  CHANNEL     => "#alvsbyn",
  MISSION     => "Kill all humans.",
};

our $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>5);
$ua->agent($IRSSI{name}.".pl/$VERSION ".$ua->_agent);

sub command {
  my ($type, $message) = @_;
  my $server = Irssi::active_server();
  $server->command("$type @{[CHANNEL]} $message");
}

sub message {
  my $message = shift;
  command("MSG", $message;
}

sub sig_auto_op {
  my (undef, $msg, $nick, undef, undef) = @_;

  my @opers = qw(Ades anton Angan hunky\\ Tomas);
  my %hashop = map { $_ => 1 } @opers;

  if ($msg eq "op plz") {

    if (exists($hashop{$nick})) {
      command("OP", $nick);
    } else {
      message("Nope.");
    }

  }
}

sub sig_dice {
  my (undef, $msg, $nick, undef, undef) = @_;

  if ($msg =~ /^!dice ([^;]+(?:;[^;]+)+)$/i) {

    my @choices = split(';', $1);
    my $i = int(rand(scalar @choices));

    $choices[$i] =~ s/^\s+|\s+$//g;  # trim whitespace

    message("Tärningen bestämmer: $choices[$i]");
  }
}

### We don't want 'spotify' and 'TitleMangler' to
### both react to spotify http uri:s
sub sig_uri_handler{
  my (undef, $msg, $nick, undef, undef) = @_;

  if ($msg =~ /(?!https?:\/\/open\.spotify\.com\/|spotify:)
               (album|artist|track)[:\/]
               ([a-zA-Z0-9]+)\/?/ix) {

    my $spotify = spotify($1, $2);
    message($spotify) if $spotify;

  } else {

    my $title = TitleMangler::get($msg);
    message($title) if $title;

  }
}


### The below code is based on code copyrighted by
### Simon Lundstöm (http://soy.se/code/)
sub spotify {
  my ($kind, $id) = @_;

  my $url = "http://ws.spotify.com/lookup/1/?uri=spotify:$kind:$id";
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

sub show_commits {
  my $dt = DateTime->now->set_time_zone("GMT");
  $dt->subtract(minutes => API_TIMEOUT);

  my $url = "https://api.github.com/repos/${[GITHUB_USER]}/${[GITHUB_REPO]}/commits?since=${dt}Z";
  my $res = $ua->get($url);

  if ($res->is_success) {
    my $commits = decode_json($res->decoded_content);

    foreach my $c (@{$commits}) {
      message("[autobot] Commit: $c->{commit}->{message}");
    }
  }
}

Irssi::timeout_add(API_TIMEOUT*60*1000, "show_commits", undef);
Irssi::signal_add("message public", "sig_auto_op");
Irssi::signal_add("message public", "sig_dice");
Irssi::signal_add("message public", "sig_uri_handler");


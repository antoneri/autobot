use strict;
use warnings;

use Irssi;
use DateTime;
use LWP::UserAgent;
use JSON qw(decode_json);

use File::Basename;
use lib dirname (__FILE__) . "/lib";
use Spotify;
use Helpers qw(command message);
use TitleMangler;

our $VERSION = "0.2";
our %IRSSI   = (authors     => "Anton Eriksson",
                contact     => "anton\@rizon",
                name        => "autobot",
                date        => "2014-01-23",
                updated     => "2014-11-29",
                description => "IRC-bot",
                license     => "BSD 2-clause",
                url         => "http://www.github.com/antoneri/autobot/");

our $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>5);

use constant {
  API_TIMEOUT => 2,  #minutes
  GITHUB_USER => 'antoneri',
  GITHUB_REPO => 'autobot',

  USER_AGENT  => "autobot.pl/0.2 $ua->_agent",
};

$ua->agent(USER_AGENT);

sub sig_auto_op {
  my (undef, $msg, $nick, undef, $target) = @_;

  my @opers = qw(Ades anton Angan hunky\\ Tomas);
  my %hashop = map { $_ => 1 } @opers;

  if ($msg eq "op plz") {

    if (exists($hashop{$nick})) {
      command("OP", $target, $nick);
    } else {
      message($target, "Nope.");
    }

  }
}

sub sig_dice {
  my (undef, $msg, $nick, undef, $target) = @_;

  if ($msg =~ /^!dice ([^;]+(?:;[^;]+)+)$/i) {

    my @choices = split(';', $1);
    my $i = int(rand(scalar @choices));

    $choices[$i] =~ s/^\s+|\s+$//g;  # trim whitespace

    message($target, "Tärningen bestämmer: $choices[$i]");
  }
}

### We don't want 'Spotify' and 'TitleMangler' to
### both react to spotify http uri:s
sub sig_uri_handler{
  my (undef, $msg, $nick, undef, $target) = @_;

  if ($msg =~ /(?!https?:\/\/open\.spotify\.com\/|spotify:)
               (album|artist|track)[:\/]
               ([a-zA-Z0-9]+)\/?/ix) {

    Spotify::set_user_agent(USER_AGENT);
    my $spotify = Spotify::spotify($1, $2);
    message($target, $spotify) if $spotify;

  } else {

    my $title = TitleMangler::get($msg);
    message($target, $title) if $title;

  }
}

sub show_commits {
  my $dt = DateTime->now->set_time_zone("GMT");
  $dt->subtract(minutes => API_TIMEOUT);

  my $url = "https://api.github.com/repos/${[GITHUB_USER]}/${[GITHUB_REPO]}/commits?since=${dt}Z";
  my $res = $ua->get($url);

  if ($res->is_success) {
    my $commits = decode_json($res->decoded_content);

    foreach my $c (@{$commits}) {
      message("#testautobot", "[autobot] Commit: $c->{commit}->{message}");
    }
  }
}

Irssi::timeout_add(API_TIMEOUT*60*1000, "show_commits", undef);
Irssi::signal_add("message public", "sig_auto_op");
Irssi::signal_add("message public", "sig_dice");
Irssi::signal_add("message public", "sig_uri_handler");


use strict;
use warnings;

use DateTime;
use Irssi;
use JSON;

use File::Basename;
use lib dirname (__FILE__) . "/lib";
use Helpers qw(command message get_url);
use Spotify;
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

our $API_TIMEOUT = 2;  #minutes

Helpers::set_user_agent("$IRSSI{name}.pl/$VERSION");

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
  my (undef, $msg, undef, undef, $target) = @_;

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
  my (undef, $msg, undef, undef, $target) = @_;

  if ($msg =~ /(?!https?:\/\/open\.spotify\.com\/|spotify:)
               (album|artist|track)[:\/]
               ([a-zA-Z0-9]+)\/?/ix) {

    my $res = get_url(Spotify::lookup($1, $2));
    my $spotify = Spotify::parse($res);
    message($target, $spotify) if $spotify;

  } elsif ($msg =~ /((?:https?:\/\/)?
                     (?:[\w\d-]+\.)*
                     ([\w\d-]+)
                     \.([a-z]{2,20})
                     (?:\/.*)?)
                     \b/ix) {

    my $res = get_url($1);
    my $title = TitleMangler::formatted($res, $1, $2, $3);
    message($target, $title) if $title;

  }
}

sub show_commits {
  my $dt = DateTime->now->set_time_zone("GMT");
  $dt->subtract(minutes => $API_TIMEOUT);

  my $res = get_url("https://api.github.com/repos/antoneri/autobot/commits?since=${dt}Z");

  if ($res->is_success) {
    my $commits = decode_json($res->decoded_content);

    foreach my $c (@{$commits}) {
      message("#testautobot", "[autobot] Commit: $c->{commit}->{message}");
    }
  }
}

Irssi::timeout_add($API_TIMEOUT*60*1000, "show_commits", undef);
Irssi::signal_add("message public", "sig_auto_op");
Irssi::signal_add("message public", "sig_dice");
Irssi::signal_add("message public", "sig_uri_handler");


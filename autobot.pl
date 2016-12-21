use strict;
use warnings;
use 5.014;

use Irssi;
use LWP::UserAgent;
use Text::Levenshtein qw(distance);
use JSON qw(decode_json);

our $VERSION = "0.3";
our %IRSSI = (authors     => "Anton Eriksson",
              contact     => "anton\@rizon",
              name        => "autobot",
              date        => "2014-01-23",
              updated     => "2014-12-01",
              description => "IRC-bot",
              license     => "BSD 2-clause",
              url         => "http://www.github.com/antoneri/autobot/");

our $USER_AGENT = "$IRSSI{name}.pl/$VERSION ";  # Must end with space
our $DEBUG = 0;
our $CHANNEL = ($DEBUG) ? "#testautobot" : "#alvsbyn";

sub command {
  my ($type, $target, $message) = @_;

  my $server = Irssi::active_server();

  $server->command("$type $target $message");
}

sub message {
  my ($target, $message) = @_;

  command("MSG", $target, $message);
}

sub get_url {
  my ($url) = @_;

  my $ua = LWP::UserAgent->new(agent => $USER_AGENT, env_proxy => 1, keep_alive => 1, timeout => 5);

  return $ua->get($url);
}

sub sig_auto_op {
  my (undef, $msg, $nick, undef, $target) = @_;

  my @opers = qw(Ades anton Tomas-);
  my %hashop = map { $_ => 1 } @opers;

  if ($msg eq "op plz") {
    if (exists $hashop{$nick}) {
      command("OP", $target, $nick);
    }
  }
}

sub sig_dice {
  my (undef, $msg, undef, undef, $target) = @_;

  if ($msg =~ /^!dice ([^;]+(?:;[^;]+)+)$/i) {

    my @choices = split(';', $1);
    my $i = int(rand(scalar @choices));

    $choices[$i] =~ s/^\s+|\s+$//g;  # Trim whitespace

    message($target, "Tärningen bestämmer: $choices[$i]");
  }
}

### We don't want 'spotify_*' and 'formatted_title' to
### both react to spotify http uri:s
sub sig_uri_handler{
  my (undef, $msg, $nick, undef, $target) = @_;

  if ($msg =~ /(?!https?:\/\/open\.spotify\.com\/|spotify:)
               (album|artist|track)[:\/]
               ([a-zA-Z0-9]+)\/?/ix) {

    my $res = get_url(spotify_api_url($1, $2));
    my $spotify = spotify_parse_res($res);

    if ($spotify) {
      message($target, $spotify);
    }

  } elsif ($msg =~ /((?:https?:\/\/)?
                     (?:[\w\d-]+\.)*
                     ([\w\d-]+)
                     \.([a-z]{2,20})
                     (?:\/.*)?)
                     \b/ix) {

    my $res = get_url($1);
    my $title = formatted_title($res, $1, $2, $3);

    if ($title) {
      message($target, $title);
    }
  }
}

sub formatted_title {
  my ($res, $url, $domain, $tld) = @_;

  return 0 unless $res->is_success;

  my $edit_distance = 2;

  if ($res->title) {
    my ($title, $pos) = ($res->title, undef);
    my @words = split(' ', $title);

    ## Try to find one-word domain.tld in title.
    for my $i (0 .. $#words) {
      if (distance(lc($words[$i]), lc("$domain.$tld")) < $edit_distance) {
        $pos = $i;
        last;
      }
    }

    ## Try to find one-word domain in title.
    unless (defined $pos) {
      for my $i (0 .. $#words) {
        if (distance(lc($words[$i]), lc($domain)) < $edit_distance) {
          $pos = $i;
          last;
        }
      }
    }

    ## Try to find two-word domain names in title.
    unless (defined $pos) {
      for my $i (0 .. $#words-1) {
        if (distance(lc(join(' ', @words[$i .. $i+1])), lc($domain))        < $edit_distance ||
            distance(lc(join(' ', @words[$i .. $i+1])), lc("$domain.$tld")) < $edit_distance) {

          splice(@words, $i, 2, join(' ', @words[$i .. $i+1]));
          $pos = $i;
          last;
        }
      }
    }

    ## We found the domain in the title, remove it.
    if (defined $pos) {
      $words[$pos] =~ s/^[,\.]|[,\.:]$//; # FIXME: is this needed?

      ## Look for delimiters before and after the domain name in the title.
      if ($words[$pos-1] && $words[$pos-1] =~ "[-\|]") {
        $title = join(' ', @words[0 .. $pos-2]);
      } elsif ($words[$pos+1] && $words[$pos+1] =~ "[-\|]") {
        $title = join(' ', @words[$pos+2 .. $#words]);
      }

      ## Domain name not separated from title by common delimiters.
      ## Here we choose to build our title on every word but the domain.
      ## This will fail.
      elsif ($pos == 0) {
        $title = join(' ', @words[$pos+1 .. $#words]);
      } elsif ($pos == $#words) {
        $title  = join(' ', @words[0 .. $pos-1]);
      }

      return "[$words[$pos]] $title";
    }

    ## Couldn't find domain in title
    return "[".ucfirst($domain)."] $title";
  }

  ## Can we at least show some content type information?
  elsif ($res->content_type && $res->filename) {
    my $info = "(".$res->content_type.") ".$res->filename;

    ## Special cases
    if ($domain eq "akamihd") {
      $domain = "Facebook";
    } elsif ($domain eq "deviantart") {
      $domain = "DeviantArt";
    } else {
      $domain = ucfirst $domain;
    }

    return "[$domain] $info";
  }

  return 0; # Fall-through
}

### The below code is based on code copyrighted by
### Simon Lundstöm (http://soy.se/code/)

sub spotify_api_url {
  my ($kind, $id) = @_;

  return "https://api.spotify.com/v1/${kind}s/$id";
}

sub spotify_parse_res {
  my $res = shift;

  if ($res->is_success) {
    my ($json, $info) = (decode_json($res->content), undef);

    if (scalar @{$json->{'artists'}} == 1) {
	$info .= $json->{'artists'}[0]->{'name'};
    } else {
	foreach my $artist (@{$json->{'artists'}}) {
	    $info .= $artist->{'name'}.", ";
	}

	$info =~ s/, $//;
    }

    $info .= " - ";

    if ($json->{'name'}) {
	$info .= $json->{'name'};
    }

    if ($json->{'album'}->{'name'}) {
	$info .= " (" . $json->{'album'}->{'name'} . ")";
    }

    return "[Spotify] $info";
  }

  return 0;
}

Irssi::signal_add("message public", "sig_auto_op");
Irssi::signal_add("message public", "sig_dice");
Irssi::signal_add("message public", "sig_uri_handler");


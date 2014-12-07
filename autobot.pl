use strict;
use warnings;
use 5.014;

use DateTime;
use Irssi;
use JSON;
use LWP::UserAgent;
use Text::Levenshtein qw(distance);
use XML::Simple qw(XMLin);

our $VERSION = "0.2";
our %IRSSI = (authors     => "Anton Eriksson",
              contact     => "anton\@rizon",
              name        => "autobot",
              date        => "2014-01-23",
              updated     => "2014-12-01",
              description => "IRC-bot",
              license     => "BSD 2-clause",
              url         => "http://www.github.com/antoneri/autobot/");

our $API_TIMEOUT = 2;  # Minutes
our $USER_AGENT = "$IRSSI{name}.pl/$VERSION ";  # Must end with space
our $DEBUG = 0;
our $CHANNEL = ($DEBUG) ? "#testautobot" : "#alvsbyn";
our $MAX_QUEUE = 6;

our %data;
our @queue;

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

sub add_to_queue {
  my ($nick, $url, $title) = @_;

  if (exists $data{$url}) {
    push $data{$url}{nicks}, $nick;
    return;
  }

  push @queue, $url;

  if (scalar @queue > $MAX_QUEUE) {
    my $expired = shift @queue;
    delete $data{$expired};
  }

  $data{$url} = {
    url => $url,
    title => $title,
    nicks => [$nick]
  };

}

sub find_by_nick {
  my $nick = shift;

  my %submitted;

  foreach my $key (keys %data) {
    for my $n (@{$data{$key}{nicks}}) {

      if ($n eq $nick) {
        $submitted{$key} = $data{$key};
      }

    }
  }

  return %submitted;
}

sub sig_auto_op {
  my (undef, $msg, $nick, undef, $target) = @_;

  my @opers = qw(Ades anton Angan hunky\\ Tomas-);
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

    message($target, $spotify) if $spotify;

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
      add_to_queue($nick, $1, $title);
    }
  }
}

sub sig_links {
  my (undef, $msg, undef, undef, $target) = @_;

  my $message;

  if ($msg eq "!links") {

    for my $key (@queue) {
      $message = "Postad av ";
      $message .= join(', ', @{$data{$key}{nicks}});
      $message .= ": ";
      $message .= $data{$key}{title};
      $message .= " (" . $data{$key}{url} . ")";

      message($target, $message);
    }

  } elsif ($msg =~ /^!links\s+([\w{}[\]\\\^`_\-]+)/ix) {
    my %submitted = find_by_nick($1);

    if (keys %submitted) {
      message($target, "Länkar postade av $1:");
    }

    foreach my $key (keys %submitted) {
      $message = $submitted{$key}{url};
      $message .= " - ";
      $message .= $submitted{$key}{title};

      message($target, $message);
    }

  }
}

sub show_commits {
  my $dt = DateTime->now->set_time_zone("GMT");
  $dt->subtract(minutes => $API_TIMEOUT);

  my $res = get_url("https://api.github.com/repos/antoneri/autobot/commits?since=${dt}Z");

  if ($res->is_success) {
    my $commits = decode_json($res->decoded_content);

    foreach my $c (@{$commits}) {
      message($CHANNEL, "[autobot] Commit: $c->{commit}->{message}");
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
      $domain = "Facebook CDN";
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

  return "http://ws.spotify.com/lookup/1/?uri=spotify:$kind:$id";
}

sub spotify_parse_res {
  my $res = shift;

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

Irssi::timeout_add($API_TIMEOUT*60*1000, "show_commits", undef);
Irssi::signal_add("message public", "sig_auto_op");
Irssi::signal_add("message public", "sig_dice");
Irssi::signal_add("message public", "sig_uri_handler");
Irssi::signal_add("message public", "sig_links");


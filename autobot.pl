use strict;
use warnings;
use 5.014;

use Irssi;
use LWP::UserAgent;
use Text::Levenshtein qw(distance);
use JSON qw(decode_json);

our $VERSION = "0.4";
our %IRSSI = (authors     => "Anton Eriksson",
              contact     => "anton\@rizon",
              name        => "autobot",
              date        => "2014-01-23",
              updated     => "2016-12-22",
              description => "IRC-bot",
              license     => "BSD 2-clause",
              url         => "http://www.github.com/antoneri/autobot/");

our $USER_AGENT = LWP::UserAgent->new(agent => "$IRSSI{name}.pl/$VERSION ", # Must end with space
                                      env_proxy => 1,
                                      keep_alive => 1,
                                      timeout => 5);

our $VALID_SPOTIFY_URL = qr{
  (?!https?://open\.spotify\.com/|spotify:)
  (album|artist|track)[:/]
  ([a-zA-Z0-9]+)/?
}ix;

our $VALID_URL = qr{
  ((?:https?://)?
  (?:[\w\d-]+\.)*
  ([\w\d-]+)
  \.([a-z]{2,20})
  (?:/.*)?)
  \b
}ix;

sub command {
  my ($type, $target, $message) = @_;

  my $server = Irssi::active_server();

  return $server->command("$type $target $message");
}

sub message {
  my ($target, $message) = @_;

  return command("MSG", $target, $message);
}

sub get_url {
  my ($url) = @_;

  return $USER_AGENT->get($url);
}

sub sig_auto_op {
  my (undef, $msg, $nick, undef, $target) = @_;

  my %opers = map { $_ => 1 } qw(Ades anton Tomas-);

  if ($msg eq "op plz" and exists $opers{$nick}) {
    command("OP", $target, $nick);
  }
  
  return;
}

sub sig_dice {
  my (undef, $msg, undef, undef, $target) = @_;

  if ($msg =~ /^!dice ([^;]+(?:;[^;]+)+)$/ix) {

    my @choices = split(/;/, $1);
    my $i = int(rand(scalar @choices));

    $choices[$i] =~ s/^\s+|\s+$//gxms;  # Trim whitespace

    message($target, "Tärningen bestämmer: $choices[$i]");
  }
  
  return;
}

### We don't want 'spotify_*' and 'formatted_title' to
### both react to spotify http uri:s
sub sig_uri_handler{
  my (undef, $msg, undef, undef, $target) = @_;

  my $response = undef;

  if ($msg =~ $VALID_SPOTIFY_URL) {
    my $content = spotify_get_json($1, $2);
    $response = spotify_parse_json($content) if $content;
  }
  
  elsif ($msg =~ $VALID_URL) {
    $response = formatted_title($1, $2, $3);
  }
  
  if ($response) {
    message($target, $response);
  }
  
  return;
}

sub formatted_title {
  my ($url, $domain, $tld) = @_;

  my $res = get_url($url);

  return unless $res->is_success;

  my $edit_distance = 2;

  if ($res->title) {
    my $title = $res->title;
    my $pos = undef;
    my @words = split(' ', $title);

    ## Try to find one-word domain.tld in title.
    for my $i (0 .. $#words) {
      if (distance(lc($words[$i]), lc("$domain.$tld")) < $edit_distance) {
        $pos = $i;
        last;
      }
    }

    ## Try to find one-word domain in title.
    if (!$pos) {
      for my $i (0 .. $#words) {
        if (distance(lc($words[$i]), lc($domain)) < $edit_distance) {
          $pos = $i;
          last;
        }
      }
    }

    ## Try to find two-word domain names in title.
    if (!$pos) {
      for my $i (0 .. $#words-1) {
        my $two_words = lc(join(' ', @words[$i .. $i+1]));
        if (distance($two_words, lc($domain)) < $edit_distance or
            distance($two_words, lc("$domain.$tld")) < $edit_distance) {
          splice(@words, $i, 2, join(' ', @words[$i .. $i+1]));
          $pos = $i;
          last;
        }
      }
    }

    ## We found the domain in the title, remove it.
    if ($pos) {
      $words[$pos] =~ s/^[,\.]|[,\.:]$//x; # FIXME: is this needed?

      ## Look for delimiters before and after the domain name in the title.
      my $delim = "[-\|]";
      if ($words[$pos-1] and $words[$pos-1] =~ $delim) {
        $title = join(' ', @words[0 .. $pos-2]);
      } elsif ($words[$pos+1] and $words[$pos+1] =~ $delim) {
        $title = join(' ', @words[$pos+2 .. $#words]);
      }
      
      ## Domain name not separated from title by common delimiters.
      ## Here we choose to build our title on every word but the domain.
      elsif ($pos == 0) {
        $title = join(' ', @words[$pos+1 .. $#words]);
      } elsif ($pos == $#words) {
        $title  = join(' ', @words[0 .. $pos-1]);
      } else {
        # Use all of the title
      }

      return "[$words[$pos]] $title";
    }
    
    else {
      ## Couldn't find domain in title
      return "[".ucfirst($domain)."] $title";      
    }
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

  return; # Fall-through
}

sub spotify_get_json {
  my ($kind, $id) = @_;

  my $content;
  
  my $spotify_api_url = "https://api.spotify.com/v1/${kind}s/$id";
  my $res = get_url($spotify_api_url);

  if ($res->is_success) {
    $content = decode_json($res->content);  
  }

  return $content;
}

sub spotify_parse_json {
  my $content = shift;
  my $info = undef;

  if (scalar @{$content->{'artists'}} == 1) {
    $info .= $content->{'artists'}[0]->{'name'};
  } else {
    foreach my $artist (@{$content->{'artists'}}) {
      $info .= $artist->{'name'}.", ";
    }

    $info =~ s/, $//xms;
  }

  $info .= " - " if $info;

  if ($content->{'name'}) {
    $info .= $content->{'name'};
  }

  if ($content->{'album'}->{'name'}) {
    $info .= " (" . $content->{'album'}->{'name'} . ")";
  }

  return "[Spotify] $info";
}

Irssi::signal_add("message public", "sig_auto_op");
Irssi::signal_add("message public", "sig_dice");
Irssi::signal_add("message public", "sig_uri_handler");


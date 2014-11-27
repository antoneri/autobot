
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

use vars qw($VERSION %IRSSI);

$VERSION = "0.2";
%IRSSI = (authors     => "Anton Eriksson",
          contact     => "anton\@rizon",
          name        => "autobot",
          date        => "2014-01-23",
          updated     => "2014-11-26",
          description => "Auto reply IRC-bot/Race of shapeshifting robots.",
          license     => "BSD 2-clause",
          url         => "http://www.github.com/antoneri/autobot/");

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

### We don't want 'spotify' and 'get_page_title' to
### both react to spotify http uri:s
sub uri_handler{
  my ($srv, $msg, $nick, $addr, $target) = @_;

  if ($msg =~ /(?!https?:\/\/open\.spotify\.com\/|spotify:)
               (album|artist|track)[:\/]
               ([a-zA-Z0-9]+)\/?/ix) {

    my $spotify = spotify($1, $2);
    $srv->command("MSG $target $spotify") if $spotify;

  } elsif ($msg =~ /((?:https?:\/\/)?
                    (?:[\w\d-]+\.)*
                    ([\w\d-]+)
                    \.([a-z]{2,20})
                    (?:\/.*)?)
                    \b/ix) {

    my $title = get_page_title($1, $2, $3);
    $srv->command("MSG $target $title") if $title;

  }
}

sub get_page_title {
  my ($url, $domain, $tld) = @_;

  use constant EDIT_DISTANCE => 2;

  my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>5);
  $ua->agent($IRSSI{name}.".pl/$VERSION ".$ua->_agent);
  my $res = $ua->get($url);

  return 0 unless $res->is_success;

  if ($res->title) {
    my $title = $res->title;
    my @words = split(' ', $title);
    my $pos = undef;

    ## Try to find one-word domain in title.
    for my $i (0 .. $#words) {
      if (distance(lc($words[$i]), lc($domain))        < EDIT_DISTANCE ||
          distance(lc($words[$i]), lc("$domain.$tld")) < EDIT_DISTANCE) {
        $pos = $i;
        last;
      }
    }

    ## Try to find two-word domain names in title.
    unless (defined $pos) {
      for my $i (0 .. $#words-1) {
        if (distance(lc(join(' ', @words[$i .. $i+1])), lc($domain))        < EDIT_DISTANCE ||
            distance(lc(join(' ', @words[$i .. $i+1])), lc("$domain.$tld")) < EDIT_DISTANCE) {
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
    }

    return defined $pos
           ? "[$words[$pos]] $title"
           : "[".ucfirst($domain)."] $title";

  ## Can we at least show some content type information?
  } elsif ($res->content_type && $res->filename) {
    return "[".ucfirst($domain)."] (".$res->content_type.") ".$res->filename."\n";
  }

  return 0; # Fall-through
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

Irssi::signal_add("message public", "auto_op");
Irssi::signal_add("message public", "dice");
Irssi::signal_add("message public", "uri_handler");


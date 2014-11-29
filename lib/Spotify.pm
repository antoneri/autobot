package Spotify;
our @ISA       = qw(Exporter);
our @EXPORT    = qw(spotify set_user_agent);
our @EXPORT_OK = qw(spotify set_user_agent);

use strict;
use warnings;

use LWP::UserAgent;
use XML::Simple qw(XMLin);

our $user_agent;

sub set_user_agent {
  $user_agent = shift;
}

### The below code is based on code copyrighted by
### Simon Lundstöm (http://soy.se/code/)
sub spotify {
  my ($kind, $id) = @_;

  my $url = "http://ws.spotify.com/lookup/1/?uri=spotify:$kind:$id";
  my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>5);
  $ua->agent($user_agent);
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

1;


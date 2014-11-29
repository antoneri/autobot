package Spotify;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(lookup parse);

use strict;
use warnings;

use XML::Simple qw(XMLin);

sub lookup {
  my ($kind, $id) = @_;
  return "http://ws.spotify.com/lookup/1/?uri=spotify:$kind:$id";
}

### The below code is based on code copyrighted by
### Simon Lundstöm (http://soy.se/code/)
sub parse {
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

1;


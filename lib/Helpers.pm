package Helpers;
our @ISA    = qw(Exporter);
our @EXPORT = qw(command message get_url);

use strict;
use warnings;

use Irssi;
use LWP::UserAgent;

sub command {
  my ($type, $target, $message) = @_;
  my $server = Irssi::active_server();
  $server->command("$type $target $message");
}

sub message {
  my ($target, $message) = @_;
  command("MSG", $target, $message);
}

our $USER_AGENT;
sub set_user_agent {
  $USER_AGENT = shift;
}

sub get_url {
  my ($url) = @_;

  my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>5);
  $ua->agent($USER_AGENT);
  my $res = $ua->get($url);

  return $res;
}

1;


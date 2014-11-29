package Helpers;
our @ISA       = qw(Exporter);
our @EXPORT    = qw(command message);
our @EXPORT_OK = qw(command message);

use Irssi;

sub command {
  my ($type, $target, $message) = @_;
  my $server = Irssi::active_server();
  $server->command("$type $target $message");
}

sub message {
  my ($target, $message) = @_;
  command("MSG", $target, $message);
}

1;


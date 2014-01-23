use strict;

require LWP::UserAgent;
use vars qw($VERSION %IRSSI);

$VERSION = "0.1";
%IRSSI = (
    authors     => "Anton Eriksson",
    contact     => "anton\@rizon",
    name        => "autobot",
    date        => "2014-01-23",
    description => "Auto reply bot",
    license     => "BSD 2-clause",
    url         => "http://www.github.com/antoneri/irssi-scripts/"
);

sub bot {
    my ($server, $msg, $nick, $address, $target) = @_;

    # -- Fråga Håkan --
    if ($msg =~ /^varför/i) {
        $server->command("MSG $target $nick: Fråga Håkan.");
    ## -- Pseudovetenskap --
    } elsif ($msg =~
            /(
            astrolog(i|y)|
            creation(ism|\Wscience)|
            crop\W?circles|
            homoepat(i|hy)|
            vortex\W?ma(th(.*\b)?|tte|tematik)|
            torsion\W?field(\Wphysics)?|
            kinesiolog(i|y)|
            alternativ(e?)\W?medicin(e?)
            )/ix) {
        my $match = $1;
        $server->command("MSG $target ". ucfirst($match) ." är skitsnack.");
    # -- Rulla tärning --
    } elsif ($msg =~ /^\!dice$/) {
        my $rand = sprintf "%d", int(rand(6)) + 1;
        $server->command("MSG $target Tärningen visar: $rand");
    # -- Visa YouTube-titel --
    } elsif ($msg =~ /((https?:\/\/)?(www\.)?youtu.?be\.?[a-z]{0,3}\/(watch\?v=)?[-_a-z0-9]+[^#\&\?])/i) {
        my $match = $1;
        my $title = youtube($match) or return;
        $server->command("MSG $target $title");
    } elsif ($nick == "Trivia" && $msg =~ /author/i) {
        $server->command("MSG $target john steinbeck");
    }
    return;
}

sub youtube {
    my ($url) = @_;

    my $useragent = LWP::UserAgent->new;
    $useragent->timeout(3);
    $useragent->env_proxy;

    my $response = $useragent->get($url);

    if ($response->is_success) {
        my $title = $response->title();
        if ($title =~ /(.+)-.youtube$/i) {
            return "[YouTube] $1";
        }
    } else {
        return 0;
    }
}

Irssi::signal_add('message public', 'bot');

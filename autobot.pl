use strict;
require LWP::UserAgent;
use vars qw($VERSION %IRSSI);

$VERSION = "0.1";
%IRSSI = (
    authors     => "Anton Eriksson",
    contact     => "anton\@rizon",
    name        => "autobot",
    date        => "2014-01-23",
    description => "Auto reply IRC-bot/Race of shapeshifting robots.",
    license     => "BSD 2-clause",
    url         => "http://www.github.com/antoneri/autobot/"
);

sub autobot {
    my ($server, $msg, $nick, $address, $target) = @_;

    my $response = 0;

    if ($msg =~ /^varför/i) {
        $response = "$nick: Fråga Håkan.";
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
        $response = ucfirst(lc($1)) . " är skitsnack.";
    } elsif ($msg =~ /^\!dice$/) {
        $response = sprintf "Tärningen visar: %d", int(rand(6)) + 1;
    } elsif ($msg =~
            /(
            (https?:\/\/)?
            (www\.)?
            youtu.?be\.?
            [a-z]{0,3}
            \/(watch\?v=)?
            [-_a-z0-9]+
            [^#\&\?]
            )/ix) {
        $response = youtube($1);
    } elsif ($nick eq "Trivia" && $msg =~ /author/i) {
        $response = "john steinbeck";
    }

    $server->command("MSG $target $response") if $response;
    return;
}

sub youtube {
    my ($url) = @_;

    my $useragent = LWP::UserAgent->new;
    $useragent->timeout(3);
    $useragent->env_proxy;

    my $response = $useragent->get($url);
    if ($response->is_success && $response->title() =~ /(.+)-.youtube$/i) {
        return "[YouTube] $1";
    }

    return 0;
}

Irssi::signal_add('message public', 'autobot');

use strict;
use warnings;
use Irssi;
use LWP::UserAgent;
use Text::Levenshtein qw(distance);
use XML::Simple 'XMLin';

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

    if ($msg =~ /
            (?!https?:\/\/open.spotify.com\/|spotify:)
            (album|artist|track)
            [:\/]
            ([a-zA-Z0-9]+)\/?
            /ix) {
        $response = spotify($1, $2);
    } elsif ($msg =~ /((?:https?:\/\/)?(?:[\w\d-]+\.)*([\w\d-]+)\.[a-z]{2,6}.*)\b/i) {
        my $title = get_page_title($1);

        if ($title) {
            my $domain = $2;
            my @words = split(' ', $title);
            my $pos = 0;
            my $titlepos = undef;

            foreach (@words) {
                if (distance(lc($_), lc($domain)) < 3) {
                    $titlepos = $pos;
                }
                $pos += 1;
            }

            if ($titlepos) {
                $words[$titlepos] =~ s/^[,\.]|[,\.]$//;

                if ($words[$titlepos-1] && $words[$titlepos-1] =~ "[-\|]") {
                    $title = join(' ', @words[0..$titlepos-2]);
                } elsif ($words[$titlepos+1] && $words[$titlepos+1] =~ "[-\|]") {
                    $title = join(' ', @words[$titlepos+2..-1]);
                }

                $title = "[".$words[$titlepos]."] ".$title;
            } else {
                $title = "[".ucfirst($domain)."] ".$title;
            }

            $response = $title;
        }
    } elsif ($msg =~ /^!nt (.*)$/) {
        $response = nisetango($1);
    } elsif ($msg =~ /^\!dice$/) {
        $response = sprintf "Tärningen visar: %d", int(rand(6)) + 1;
    } elsif ($msg =~ /^!dice ([^;]+(?:;[^;]+)+)$/i) {
        my @choices = split(';', $1);
        my $num = scalar @choices;
        my $choice = int(rand($num));
        $choices[$choice] =~ s/^\s+|\s+$//g;
        $response = "Tärningen bestämmer: ".$choices[$choice];
    } elsif ($msg =~ /(
            astrolog(?:i|y)|
            creation(?:ism|\Wscience)|
            crop\W?circles|
            hom[oe]+pat(?:i|hy)|
            vortex\W?ma(?:th(?:.*\b)?|tte|tematik)|
            torsion\W?field(?:\Wphysics)?|
            kinesiolog(?:i|y)|
            alternative?\W?medicine?
            )/ix) {
        $response = ucfirst(lc($1)) . " är skitsnack.";
    } elsif ($msg =~ /^varför/i) {
        $response = "$nick: Fråga Håkan.";
    } elsif ($nick eq "Trivia" && $msg =~ /author/i) {
        $response = "john steinbeck";
    }

    $server->command("MSG $target $response") if $response;
    return;
}

sub get_page_title {
    my ($url) = @_;

    my $useragent = LWP::UserAgent->new;
    $useragent->timeout(3);
    $useragent->env_proxy;

    my $response = $useragent->get($url);
    if ($response->is_success && $response->title()) {
        return $response->title();
    }

    return 0;
}

sub nisetango {
    my ($input) = @_;

    $input =~ s/(
        [bfjkmqvwxz]+(?!\b) # any 'consonants'
        |
        c+(?![hk]|\b) # ch, ck
        |
        d+(?![j]) # dj
        |
        g+(?![js]) # gj, gs
        |
        l+(?![j]|\b) # lj
        |
        n+(?![gd]|\b) # ng, nd
        |
        p+(?![h]) # ph, word boundary
        |
        r+ # word boundary
        |
        (?<!s)s(?![chjk]) # sc, sh, sj, sk
        |
        t+(?![hij]|\b) # th, ti, tj
        )
        (?! # not followed by
        \1 # the same as captured above
        |
        [aeiouyåäö] # a vowel
        )/$1u/gix;

    $input =~ s/(?<!l)l(?!l|\b)/r/gi;
    $input =~ s/(?<!u)e\b/u/gi;
    $input =~ s/ou\b/oo/gi;

    return uc $input;
}

# The below code is taken from and copyrighted by
# Simon Lundstöm (http://soy.se/code/)
sub spotify {
    my ($kind, $id) = @_;

    my $url = "http://ws.spotify.com/lookup/1/?uri=spotify:$kind:$id";
    my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>5);
    $ua->agent($IRSSI{name}.".pl/$VERSION ".$ua->agent());
    my $res = $ua->get($url);

    if ($res->is_success()) {
        my ($xml, $info) = (XMLin($res->content()), undef);

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


Irssi::signal_add('message public', 'autobot');

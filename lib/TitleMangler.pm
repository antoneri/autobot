package TitleMangler;

use 5.014;
use strict;
use warnings;

use LWP::UserAgent;
use Text::Levenshtein qw(distance);

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get);
our $VERSION = '0.01';

use constant DEBUG => 0;

sub get {
  my ($url) = @_;

  if ($url =~ /((?:https?:\/\/)?
                (?:[\w\d-]+\.)*
                ([\w\d-]+)
                \.([a-z]{2,20})
                (?:\/.*)?)
                \b/ix) {

    my $title = page_title($1, $2, $3);
    return $title if $title;
  }
}

sub page_title {
  my ($url, $domain, $tld) = @_;

  use constant EDIT_DISTANCE => 2;

  my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>5);
  $ua->agent("TitleMangler/$VERSION ".$ua->_agent);
  my $res = $ua->get($url);

  return 0 unless $res->is_success;

  if ($res->title) {
    my $title = $res->title;
    my @words = split(' ', $title);
    my $pos = undef;

    if (DEBUG) {
      print "URL: $url\n";
      print "Title: $title\n";
      print "Domain: $domain.$tld\n";
    }

    ## Try to find one-word domain.tld in title.
    for my $i (0 .. $#words) {
        if (distance(lc($words[$i]), lc("$domain.$tld")) < EDIT_DISTANCE) {
        $pos = $i;
        print "Match: One-word domain.tld found at position $i: $words[$i]\n" if DEBUG;
        last;
      }
    }

    ## Try to find one-word domain in title.
    unless (defined $pos) {
      for my $i (0 .. $#words) {
        if (distance(lc($words[$i]), lc($domain)) < EDIT_DISTANCE) {
          $pos = $i;
          print "Match: One-word domain found at position $i: $words[$i]\n" if DEBUG;
          last;
        }
      }
    }

    ## Try to find two-word domain names in title.
    unless (defined $pos) {
      for my $i (0 .. $#words-1) {
        if (distance(lc(join(' ', @words[$i .. $i+1])), lc($domain))        < EDIT_DISTANCE ||
            distance(lc(join(' ', @words[$i .. $i+1])), lc("$domain.$tld")) < EDIT_DISTANCE) {
          splice(@words, $i, 2, join(' ', @words[$i .. $i+1]));
          $pos = $i;
          print "Match: Two-word domain found at position $i: $words[$i]\n" if DEBUG;
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

1;

__END__
=head1 NAME

TitleMangler - Perl extension for blah blah blah

=head1 SYNOPSIS

  use TitleMangler;

=head1 DESCRIPTION

Get formatted page title or at least content type from URL.

  $formatted = TitleMangler->get("http://example.com/")

=head1 AUTHOR

Anton Eriksson, E<lt>anton@apple.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Anton Eriksson

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
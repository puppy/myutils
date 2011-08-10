#!/usr/bin/perl -w
use strict;
$|++;

## config

my @FEEDS = map [split], split /\n/, <<'THE_FEEDS';
useperl|journal 90 http://use.perl.org/search.pl?op=journals&content_type=rss
slashdot|journal 90 http://slashdot.org/search.pl?op=journals&content_type=rss
del.icio.us 180 http://merlyn@del.icio.us/rss/
THE_FEEDS

my ($DB) = glob("~/.newsee");    # save database here

sub LAUNCH {
  system "open", shift;          # open $_[0] as a URL in favorite browser
}

## end config

## globals

my $READER = "reader";           # alias for reader session
dbmopen(my %SEEN, $DB, 0600) or die;

## end globals

delete @SEEN{grep $SEEN{$_} < time - 86400 * 3, keys %SEEN};    # quick cleanup

use Tk;
use POE;

POE::Session->create(
  inline_states => {
    _start => sub {
      my ($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];
      require POE::Component::RSSAggregator;

      ## start the reader
      POE::Component::RSSAggregator->new(
        alias    => $READER,
        callback => $session->postback('handle_feed'),
      );

      ## set up the NoteBook
      require Tk::NoteBook;
      $heap->{nb} =
        $poe_main_window->NoteBook(-font => [-size => 10])
        ->pack(-expand => 1, -fill => 'both');

      ## add the initial subscriptions
      $kernel->yield(add_feed => @$_) for @FEEDS;
    },
    add_feed => sub {
      my ($kernel, $session, $heap, $name, $delay, $url) =
        @_[KERNEL, SESSION, HEAP, ARG0, ARG1, ARG2];

      ## add a notebook page
      require Tk::ROText;
      (my $label_name = $name) =~ tr/|/\n/;
      my $scrolled =
        $heap->{nb}->add($name, -label => "$label_name: ?")->Scrolled(
        ROText    => -scrollbars => 'oe',
        -spacing3 => '5',
        )->pack(-expand => 1, -fill => 'both');
      ## set up bindings on $scrolled here
      $scrolled->tagConfigure('link', -font => [-weight => 'bold']);
      $scrolled->tagConfigure('seen');
      for my $tag (qw(link seen)) {
        $scrolled->tagBind($tag, '<1>',
          [$session->postback(handle_click => $name, 1), Ev('@')]);
        $scrolled->tagBind($tag, '<Double-1>',
          [$session->postback(handle_click => $name, 2), Ev('@')]);
      }

      ## start the feed, getting callbacks
      $kernel->post(
        $READER => add_feed => {url => $url, name => $name, delay => $delay});

    },
    handle_click => sub {
      my ($kernel, $session, $heap, $postback_args, $callback_args) =
        @_[KERNEL, SESSION, HEAP, ARG0, ARG1];

      my $name  = $postback_args->[0];
      my $count = $postback_args->[1];    # 1 = single click, 2 = double click

      my $text = $callback_args->[0];
      my $at   = $callback_args->[1];

      my ($line) = $text->index($at) =~ /^(\d+)\.\d+$/ or die;

      if (my $headline = $heap->{feed}{$name}->headlines->[$line - 1]) {
        $SEEN{$headline->id} = time;
        $kernel->yield(feed_changed => $name);

        if ($count == 2) {                # double click: open URL
          LAUNCH($headline->url);
        }
      }
    },
    handle_feed => sub {
      my ($kernel, $session, $heap, $callback_args) =
        @_[KERNEL, SESSION, HEAP, ARG1];
      my $feed = $callback_args->[0];

      my $name = $feed->name;
      $heap->{feed}{$name} = $feed;
      $kernel->yield(feed_changed => $name);
    },
    feed_changed => sub {
      my ($kernel, $session, $heap, $name) = @_[KERNEL, SESSION, HEAP, ARG0];

      my $feed     = $heap->{feed}{$name};
      my $nb       = $heap->{nb};
      my $widget   = $nb->page_widget($name);
      my $scrolled = $widget->children->[0];

      ## update the text
      my ($pct) = $scrolled->yview;
      $scrolled->delete("1.0", "end");

      my $new_count = 0;
      for my $headline (@{$feed->headlines}) {
        my $tag = 'link';
        if ($SEEN{$headline->id}) {
          $tag = 'seen';
        }
        else {
          $new_count++;
        }
        $scrolled->insert('end', $headline->headline, $tag);
        $scrolled->insert('end', "\n");
      }
      $scrolled->yviewMoveto($pct);

      (my $label_name = $name) =~ tr/|/\n/;
      $nb->pageconfigure($name, -label => "$label_name: $new_count");
    },
  }
);

$poe_kernel->run();

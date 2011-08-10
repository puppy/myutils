#!/usr/bin/perl

# http://poe.perl.org/?POE_Cookbook/Tk_Interfaces
#
# This sample program creates a very simple Tk counter.  Its interface
# consists of three widgets: A rapidly increasing counter, and a
# button to reset that counter.

use warnings;
use strict;

use Tk;    # Tk support is enabled if the Tk module is used before POE itself.

# except when it isn't...
#
# ActiveState does something funky such that if you don't include
# Loop::TkActiveState here Loop::Tk won't be detected.  The good news
# is that it does not appear to be necessary to special case this for
# other platforms.
use POE qw( Loop::TkActiveState );

#
# when compiling with ActiveState perlapp a bunch of --add arguments
# will also be needed.  Saner platforms don't need this kick in the
# pants.

# Create the session that will drive the user interface.

POE::Session->create(
  inline_states => {
    _start   => \&ui_start,
    ev_count => \&ui_count,
    ev_clear => \&ui_clear,
  }
);

# Run the program until it is exited.

$poe_kernel->run();
exit 0;

# Create the user interface when the session starts.  This assumes
# some familiarity with Tk.  ui_start() illustrates four important
# points.
#
# 1. Tk events require a main window.  POE creates one for internal
# use and exports it as $poe_main_window.  ui_start() uses that as the
# basis for its user interface.
#
# 2. Widgets we need to work with later, such as the counter display,
# must be stored somewhere.  The heap is a convenient place for them.
#
# 3. Tk widgets expect callbacks in the form of coderefs.  The
# session's postback() method provides coderefs that post events when
# called.  The Button created in ui_start() fires an "ev_clear" event
# when it is pressed.
#
# 4. POE::Kernel methods such as yield(), post(), delay(), signal(),
# and select() (among others) work the same as they would without Tk.
# This feature makes it possible to write back end sessions that
# support multiple GUIs with a single code base.

sub ui_start {
  my ($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];

  $poe_main_window->Label(-text => "Counter")->pack;

  $heap->{counter_widget} =
    $poe_main_window->Label(-textvariable => \$heap->{counter})->pack;

  $poe_main_window->Button(
    -text    => "Clear",
    -command => $session->postback("ev_clear")
  )->pack;

  $kernel->yield("ev_count");
}

# Handle the "ev_count" event by increasing a counter and displaying
# its new value.

sub ui_count {
  $_[HEAP]->{counter}++;
  $poe_main_window->update;    # Needed on SunOS & MacOS-X
  $_[KERNEL]->yield("ev_count");
}

# Handle the "ev_clear" event by clearing and redisplaying the
# counter.

sub ui_clear {
  $_[HEAP]->{counter} = 0;
}

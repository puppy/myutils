#!/usr/bin/perl
# $Id$
# http://poe.perl.org/?POE_Cookbook/Watching_Logs
use warnings;
use strict;
use POE qw( Wheel::FollowTail );

=for cookbook
  haruspex, n. a member of a class of minor priests or soothsayers in
  ancient Rome who predicted the future by looking at the entrails of
  animals killed in sacrifice, by observing lighting, etc.
  [< Latin haruspex < haru- (perhaps entrails; origin uncertain) +
  -spex < spectre inspect]
System logs are a relentless stream of information, most of which
indicates that things are running fine.  Occasionally something
exceptional will happen that must be attended to immediately.  The log
records for those events can easily be overlooked amidst the normal
status messages.
This program uses POE::Wheel::FollowTail to watch a few different logs
on my system.  The paths and record formats are for FreeBSD, and
mileage tends to vary.
This is just a sample program.  As such it ignores the things it does
not understand.  A serious log watcher would not discard unexpected
surprises.
=cut

# This sets up a list of things to watch.  Each log file's key is used
# to determine how the file's records are filtered.
my %logs_to_watch = (
  cron  => "/var/log/cron",
  mail  => "/var/log/maillog",
  ppp   => "/var/log/ppp.log",
  httpd => "/var/log/httpd-access.log",
  msg   => "/var/log/messages",
);

# Start a session to watch the logs.
POE::Session->create(
  inline_states => {
    _start => \&begin_watchers,

    # Handle records from each log differently.
    cron_record  => \&cron_got_record,
    mail_record  => \&mail_got_record,
    ppp_record   => \&ppp_got_record,
    httpd_record => \&httpd_got_record,
    msg_record   => \&msg_got_record,

    # Handle log resets and errors the same way for each file.
    log_reset => \&generic_log_reset,
    log_error => \&generic_log_error,
  }
);

=for cookbook
Start log watchers.  Scans the hash of %logs_to_watch, creating a new
FollowTail wheel to watch each.
Each watcher emits an event based on its key in %logs_to_watch.  Those
events are handled by functions that will parse, filter, and if
necessary display information about the records.
For example, cron is the key for "/var/log/cron".  The cron log
watcher will emit a "cron_record" event whenever that file extends.
The POE::Session->create() call above associates the "cron_record"
event with the cron_got_record() function later on.
=cut

sub begin_watchers {
  my $heap = $_[HEAP];
  while (my ($service, $log_file) = each %logs_to_watch) {
    my $log_watcher = POE::Wheel::FollowTail->new(
      Filename   => $log_file,
      InputEvent => $service . "_record",
      ResetEvent => "log_reset",
      ErrorEvent => "log_error",
    );
    $heap->{services}->{$log_watcher->ID} = $service;
    $heap->{watchers}->{$log_watcher->ID} = $log_watcher;
  }
}

# Handle log resets the same way for each file.  Simply recognize that
# the log file was reset.
sub generic_log_reset {
  my ($heap, $wheel_id) = @_[HEAP, ARG0];
  my $service = $heap->{services}->{$wheel_id};
  print "--- $service log reset at ", scalar(gmtime), " GMT\n";
}

# Handle log errors the same way for each file.  Recognize that an
# error occurred while watching the file, and shut the watcher down.
# If this were a real log watcher, it would periodically try to resume
# watching the log file.
sub generic_log_error {
  my ($heap, $operation, $errno, $error_string, $wheel_id) =
    @_[HEAP, ARG0, ARG1, ARG2, ARG3];
  my $service = $heap->{services}->{$wheel_id};
  print "--- $service log $operation error $errno: $error_string\n";
  print "--- Shutting down $service log watcher.\n";
  delete $heap->{services}->{$wheel_id};
  delete $heap->{watchers}->{$wheel_id};
}

# Find and display interesting things in crond's logs.
sub cron_got_record {
  my $log_record = $_[ARG0];
  my @commands_to_ignore =
    ("/usr/libexec/atrun", "newsyslog", "/usr/local/sbin/faxqclean -v",);
  if ($log_record =~ /CMD \(\s*(.*?)\s*\)$/) {
    my $command = $1;
    foreach my $ignored (@commands_to_ignore) {
      return if $command eq $ignored;
    }
    print "cron: unknown command: $command\n";
    return;
  }
  if ($log_record =~ /RELOAD \((.*?)\)$/) {
    print "cron: reloaded $1\n";
    return;
  }
}

# Find and display interesting things related to mail delivery.
sub mail_got_record {
  my $log_record = $_[ARG0];
  if ($log_record =~ /stat=(.+?)\s*$/) {
    print "mail: Odd delivery status: $1\n" unless $1 eq 'Sent';
    return;
  }
  if ($log_record =~ /relay=(.*?) \[([\d\.]+)\]/) {
    return if $2 eq "127.0.0.1";
    print "mail: Relaying mail for strange host: $1 [$2]\n";
    return;
  }
}

# Watch what's happening regarding the ppp dialer.
sub ppp_got_record {
  my $log_record = $_[ARG0];
  if ($log_record =~ /CONNECT (\d+\S+?)^M/) {
    print "ppp : Reconnected with $1\n";
    return;
  }
  if ($log_record =~
    /deflink: Connect time: (\d+) secs: (\d+) octets in, (\d+) octets out/) {
    print "ppp : Disconnected.\n";
    print "ppp : Online $1 seconds.  Received $2 octets.  Sent $3 octets.\n";
    return;
  }
  if ($log_record =~ /Phase:  total (\d+) bytes\S+ peak (\d+) bytes/) {
    print "ppp : Average bytes/sec: $1.  Peak bytes/sec: $2\n";
    return;
  }
}

# Watch for interesting web access.
sub httpd_got_record {
  my $log_record = $_[ARG0];

  # The requests are coming from INSIDE THE NETWORK!
  return if $log_record =~ /^127\.0\.0\.1/;
  return if $log_record =~ /^10\.0\.0\./;
  if ($log_record =~ /^(\S+).*?\"GET \/scripts\/root\.exe\?/) {
    print "http: NIMDA or alike from $1\n";
    return;
  }
  if ($log_record =~ /^(\S+).*?\"(\S+ \/~troc.*?)\" (\d+)/) {
    print "http: $1 got $3 from $2\n";
    return;
  }
}

# Display some interesting things from the catch-all log.
sub msg_got_record {
  my $log_record = $_[ARG0];
  if ($log_record =~ /Connection attempt to (\S+) (\S+) from (\S+)/) {
    my ($protocol, $dst, $src) = ($1, $2, $3);

    # Don't bother with failed connections from the local network.
    return if $src =~ /^127\.0\.0/;
    return if $src =~ /^10\.0\.0/;
    return if $src =~ /^::0001:/;
    print "msg : vain $protocol connection from $src to $dst\n";
    return;
  }
  if ($log_record =~ /su: (\S+) to (\S+) on (\S+)/) {
    print "msg : $1 has su'd to $2 on $3\n";
    return;
  }
  if ($log_record =~ /su: BAD SU (\S+) to (\S+) on (\S+)/) {
    print "msg : $1 tried (BUT FAILED) to su to $2 on $3\n";
    return;
  }
  if ($log_record =~ /(pid \d+ .*? exited on signal \d+.*?\s*)$/) {
    print "msg : $1\n";
    return;
  }
  if ($log_record =~ /(proc: table is full)/) {
    print "msg : $1\n";
    return;
  }
}

# Run the watchers.  The run() method will return after all the
# watchers end.
$poe_kernel->run();

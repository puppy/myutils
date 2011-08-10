#!/usr/bin/perl
# Create CGI requests from HTTP::Requests, specifically the sort of
# requests that come from POE::Component::Server::HTTP.
use warnings;
use strict;
use POE;
use POE::Component::Server::HTTP;
use CGI ":standard";

# Start an HTTP server.  Run it until it's done, typically forever,
# and then exit the program.
POE::Component::Server::HTTP->new(
  Port           => 32090,
  ContentHandler => {
    '/'      => \&root_handler,
    '/post/' => \&post_handler,
  }
);
POE::Kernel->run();
exit 0;

# Handle root-level requests.  Populate the HTTP response with a CGI
# form.
sub root_handler {
  my ($request, $response) = @_;
  $response->code(RC_OK);
  $response->content(
    start_html("Sample Form")
      . start_form(
      -method  => "post",
      -action  => "/post/",
      -enctype => "application/x-www-form-urlencoded",
      )
      . "Foo: "
      . textfield("foo")
      . br() . "Bar: "
      . popup_menu(
      -name   => "bar",
      -values => [1, 2, 3, 4, 5],
      -labels => {
        1 => 'one',
        2 => 'two',
        3 => 'three',
        4 => 'four',
        5 => 'five'
      }
      )
      . br()
      . submit("submit", "submit")
      . end_form()
      . end_html()
  );
  return RC_OK;
}

# Handle simple CGI parameters.
#
# This code was contributed by Andrew Chen.  It handles GET and POST,
# but it does not handle %ENV-based CGI things.  It does not handle
# cookies, for instance.  Neither does it handle file uploads.
sub post_handler {
  my ($request, $response) = @_;

  # This code creates a CGI query.
  my $q;
  if ($request->method() eq 'POST') {
    $q = new CGI($request->content);
  }
  else {
    $request->uri() =~ /\?(.+$)/;
    if (defined($1)) {
      $q = new CGI($1);
    }
    else {
      $q = new CGI;
    }
  }

  # The rest of this handler displays the values encapsulated by the
  # object.
  $response->code(RC_OK);
  $response->content(start_html("Posted Values") 
      . "Foo = "
      . $q->param("foo")
      . br()
      . "Bar = "
      . $q->param("bar")
      . end_html());
  return RC_OK;
}

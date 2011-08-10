#!perl

use warnings;
use strict;

use POE qw(Component::Server::TCP Filter::SSL Filter::HTTPD);
use HTTP::Response;

# Spawn a web server on port 4433 of all interfaces.

POE::Component::Server::TCP->new(
  Alias => "web_server",
  Port  => 4433,

  # You need to have created (self) signed certificates
  # and a corresponding key file to encrypt the data with
  # SSL.

  ClientFilter => POE::Filter::Stackable->new(
    Filters => [
      POE::Filter::SSL->new(crt => 'server.crt', key => 'server.key'),
      POE::Filter::HTTPD->new(),
    ]
  ),

  # The ClientInput function is called to deal with client input.
  # Because this server uses POE::Filter::SSL to encrypt the connection,
  # POE::Filter::HTTPD must be added after this to parse input.
  # ClientInput will receive first the SSL data and then the
  # add POE::Filter::HTTPD to handle the decrytped HTTP requests.

  ClientInput => sub {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    # Filter::HTTPD sometimes generates HTTP::Response objects.
    # They indicate (and contain the response for) errors that occur
    # while parsing the client's HTTP request.  It's easiest to send
    # the responses as they are and finish up.

    if ($request->isa("HTTP::Response")) {
      $heap->{client}->put($request);
      $kernel->yield("shutdown");
      return;
    }

    # The request is real and fully formed.  Build content based on
    # it.  Insert your favorite template module here, or write your
    # own. :)

    my $request_fields = '';
    $request->headers()->scan(
      sub {
        my ($header, $value) = @_;
        $request_fields .= "<tr><td>$header</td><td>$value</td></tr>";
      }
    );

    my $response = HTTP::Response->new(200);
    $response->push_header('Content-type', 'text/html');
    $response->content(

      # Break the HTML tag for the wiki.
      "<"
        . "html><head><title>Your Request</title></head>"
        . "<body>Details about your request:"
        . "<table border='1'>$request_fields</table>"
        . "</body></html>"
    );

    # Once the content has been built, send it back to the client
    # and schedule a shutdown.

    $heap->{client}->put($response);
    $kernel->yield("shutdown");
  }
);

# Start POE.  This will run the server until it exits.

$poe_kernel->run();
exit 0;

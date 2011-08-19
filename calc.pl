#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  simplest calculator
#
#        USAGE:  ./calc.pl
#
#  DESCRIPTION:  store sub in a hash
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  anderslee (Anders Lee), anderslee@yeah.net
#      COMPANY:  just for fun
#      VERSION:  1.0
#      CREATED:  06/29/2011 03:18:18 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use diagnostics;
use Modern::Perl;

use Smart::Comments;

our $Operators = {
        '+' => sub { $_[0] + $_[1] },
        '-' => sub { $_[0] - $_[1] },
        '*' => sub { $_[0] * $_[1] },
        '**' => sub { $_[0] ** $_[1] },
        '/' => sub { $_[1] ? eval { $_[0] / $_[1] } : 'NaN' },
        '%' => sub { $_[1] ? eval { $_[0] % $_[1] } : 'NaN' },
};

while (1) {
        my ($operator, @operands) = get_line();
        ### $operator
        ### @operands
        ### $Operators


        my $some_sub = $Operators->{$operator};

        unless (defined $some_sub) {
                say "Unknown operator [$operator]";
                next;
        }

        say $Operators->{$operator}->(@operands);
}

say "Done, Exit....";

sub get_line {
        print "prompt(q to quit) jus like 1 + 2>";

        my $line = <STDIN>;
        chomp $line;

        exit if $line =~ /^q$/;

        $line =~ s/^\s+|\s+$//g;
        #$line =~ s/\d+()\S+()\d+/ /g;
        ### $line

        (split /\s+/, $line)[1, 0, 2]; # 加括号是list context
}


sub readConfig {
        my $file = shift;
        my %config = ();

        open (CF, "<", $file) or die "Error: open file: $file error!/n $!/n"; 
        print "<-> readConfig Reading config file: $file./n";
        while (<CF>) {
            chomp();
            next if (/^/s*#/);
            next if (/^/s*$/);
            next unless (/^[^;]+;[^;]+$/);
            $_ =~ s/^/s*//;
            $_ =~ s/#.*$//;
            my ($key, $value) = split //s*;/s*/;
            $config{$key} = $value;
        }
        close (CF);

        return /%config;
}

sub sendHtmlMail {
    my ( $to, $subject, $body, $attach, $from ) = @_;

    my $CRLF     = "/r/n";
    my $Raw_Bond = "=======Boundary=======";
    my $Bond     = "--=======Boundary=======";

    my @receivor = split /[,;]/, $to;
    my $smtp = Net::SMTP->new( Host => 'smtp.yeah.net', Debug => 1 );
    $from = 'anderslee@yeah.net' unless $from;
    $smtp->mail($from);
    $smtp->recipient(@receivor);
    $smtp->data();
    $smtp->datasend("Subject: $subject/n");

    my $head =
        "MIME-Version: 1.0" 
        . $CRLF
        . "Content-Type: multipart/mixed; boundary=/"$Raw_Bond / ""
        . $CRLF;
        
    $head .= "Content-Transfer-Encoding: base64" . $CRLF . $CRLF;
    $smtp->datasend($head);

    if ($body) {
        my $content_head =
                "Content-Type: text/html;" 
                . $CRLF
                . "Content-Transfer-Encoding: base64"
                . $CRLF
                . $CRLF;
        
        $smtp->datasend( "$Bond" . $CRLF );
        $smtp->datasend($content_head);
        $smtp->datasend( encode_base64( $body, $CRLF ) );
    }

    if ($attach) {
            
        $smtp->datasend( $CRLF . $CRLF . $Bond . $CRLF );
        $smtp->datasend( 'Content-Type: application/octet-stream; name='
              . "/"$attach / ""
              . $CRLF );
              
        $smtp->datasend( 'Content-Transfer-Encoding: base64' . $CRLF );
        $smtp->datasend( 'Content-Disposition: attachment; filename='
              . "/"$attach / ""
              . $CRLF
              . $CRLF );

        open( ATTA, "< $attach" ) or die "Open file: $attach error, $!/n";
        
        my $buffer;
        
        while ( read( ATTA, $buffer, 10 * 57 ) ) {
            $smtp->datasend( encode_base64( $buffer, $CRLF ) );
        }
        close(ATTA);
    }

    $smtp->dataend();
    $smtp->quit();
}
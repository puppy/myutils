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










#================================================================================



#!/usr/local/bin/perl 
use strict;
use warnings;
use Data::Dumper;


use WWW::Mechanize;
use HTTP::Cookies;
use LWP::Debug qw(+);
use HTTP::Request;
use LWP::UserAgent;
use HTTP::Request::Common;
use POSIX qw(strftime);


# 配置信息
my $topic = 'YourLink';
my $domain= 'twiki.test.com';
my $url   = "http://$domain/twiki/bin/view.pl/Tech/$topic";
my $un    = 'xx'; ##用户名 
my $pw    = 'xx'; ##密码
my @datas = qw(data1  data2);  ## test data


# 构建agent
my $agent = WWW::Mechanize->new(cookie_jar => {}, autocheck => 0);
$agent->{onerror}=/&WWW::Mechanize::_warn;
$agent->agent('Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.2.3) Gecko/20100407 Ubuntu/9.10 (karmic) Firefox/3.6.3');
$agent->get($url);

# 用户名/密码 登录
$agent->submit_form(
        form_number => 1,
        fields      => { password => $pw, username => $un },
);
die unless ($agent->success); 


##页面上所有link
my @links = $agent->links();

my $write_url;  ##  编辑twiki内容的url
my $attach_url; ## 上传附件的url

for my $wlink (@links) {
        
	my $url_str = $wlink->url;
	
	if ($url_str =~ /$domain//twiki//bin//edit.pl//Tech//$topic/?t/ ) {
	  	$write_url = $url_str;
	}
	if ($url_str =~ ///twiki//bin//attach.pl//Tech//$topic/ ) {
		$attach_url = $url_str;
	}
}

if ($write_url) {
	#print "Write Twiki/n";
	write_twiki();
}
if ($attach_url ) {
	#print "Attache File/n";
	attach_file();
}



##############
	  		
sub write_twiki {
		$agent->credentials($un, $pw); ###  HTTP Basic authentication for all sites and realms until further notice
		$agent->get($write_url);
		if ($agent->success ) {  
	  		#print $agent->content;
	  		my $text_inputs = ($agent->find_all_inputs(  ## 第一个textare
        			type       => 'textarea',
        			name_regex => qr/^text$/,
    				))[0];
	  		
## 编辑twiki的数据
			my $orig    = $text_inputs->value; ## 原来的内容
			my $att_img ="";
			
## 上传的图片放到twiki最后(或者其他位置)
			if ($orig =~ /(<img/ssrc.*?ATTACHURLPATH[^>]+//>).*/) {  
				$att_img = $1;
			}
			$orig =~ s//*/s*test/.gif: <br //>//ig;
			$orig =~ s/$att_img//g;
			$orig =~ s//s+$//g;

			my $today   = strftime("%Y.%m.%d", localtime( time() ) );
			my $content = $orig."/n---++ $today/n";  ## twiki语法
			for my $data (@datas) {
		  		$content .= "   1 $data  OK. /n";
		    }
			$content .= "$att_img /n";
			#print $content;  		
	  	
	  	$agent->submit_form(
        form_number => 1,
        fields      => { text => $content},
			);
			die unless ($agent->success); 
	  	
	  }
	  else {
	  	  #print $agent->content;
	  		print $agent->status();
	  		my $res= $agent->response();
	      print $res->as_string
	  } 
}

sub attach_file {
		$agent->credentials($un, $pw); ###  HTTP Basic authentication for all sites and realms until further notice
		$agent->get($attach_url);
		if ($agent->success ) {  
			#print $agent->content;
			$agent->form_number(1);
			$agent->field('filepath' =>'image/test.gif');
			$agent->field('createlink' => 1);
			$agent->submit();
			die unless ($agent->success); 
		}

}
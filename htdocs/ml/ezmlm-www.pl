#!/usr/bin/perl
# ===========================================================================
# ezmlm-www
# 
# Author: Alessandro Ranellucci <aar@cpan.org>
# Copyright (c) 2003-07.
# 
# see http://ezmlm-www.sourceforge.net
#-----------------------------------------------------------------------
#

use strict;
use vars qw/$VERSION $MOD_PERL $BASE_PATH *Config $lang $lists $STRINGS *WebRequest/;

use CGI::Carp qw(fatalsToBrowser);
use Encode;
use Mail::Ezmlm::Archive;
use Mail::Box::Manager;
use Encode::Guess;
#use encoding 'utf-8';

$VERSION = '1.4.5';

BEGIN {
	if ($MOD_PERL = $ENV{MOD_PERL} =~ /mod_perl/) {
		# if you're running under mod_perl, you must write
		# here your directory path to this script (just the
		# directory name, without the trailing slash):
		# 
		$BASE_PATH = '';
		# 
	} else {
		use FindBin;
		$FindBin::Bin =~ m/^(.*)$/;
		$BASE_PATH = $1;
	}
		
	# init configuration
	$lists = [];
	eval { require "$BASE_PATH/config.pm" }
	   || die("Failed to load configuration ($@)");
	
	# require language file
	$Config{Lang} ||= $lang;
	eval { require "$BASE_PATH/../lang/$Config{Lang}.pm" }
	   || die("Failed to load language file for '$Config{Lang}' language.");
	   
	# set default English strings
	eval { package EzmlmWww::Lang::En; use vars '$STRINGS'; do "$main::BASE_PATH/lang/en.pm"; };
	$STRINGS->{$_} ||= $EzmlmWww::Lang::En::STRINGS->{$_} for keys %$EzmlmWww::Lang::En::STRINGS;
	
	# set other default options
	$Config{CSSPath} ||= 'style.css';
	$Config{URL} ||= "http://$ENV{HTTP_HOST}$ENV{SCRIPT_NAME}";
}

#-----------------------------------------------------------------------

%WebRequest = ParseRequest();
show_lists( %WebRequest ) if $WebRequest{Action} eq 'show_lists';
show_list( %WebRequest ) if $WebRequest{Action} eq 'show_list';
show_month( %WebRequest ) if $WebRequest{Action} eq 'show_month';
show_message( %WebRequest ) if $WebRequest{Action} eq 'show_message';
show_attachment( %WebRequest ) if $WebRequest{Action} eq 'show_attachment';
search( %WebRequest ) if $WebRequest{Action} eq 'search';

#-----------------------------------------------------------------------

sub show_lists {
	header( title => (defined $Config{ListServerName} ? $Config{ListServerName} : 'List Server') );
	print "<ul class=\"ez_lists\">\n";
	for (0..$#$lists) {
		CheckListArchive($lists->[$_], 1);
		print "<li><h4><a href=\"?$_\">$lists->[$_]->{name}</a></b><br />\n";
		print "$lists->[$_]->{description} (" . ($lists->[$_]->{archive}->getcount || '0') . ")</h4></li>\n";
	}
	print "</ul>\n";
	footer();
}

sub show_list {
	my %WebRequest = @_;
	my (@months);
	
	# Handle RSS request, otherwise prepare feed link
	RSSFeed(%WebRequest) if $WebRequest{RSS};
	my $RSSLink = "$Config{URL}?$WebRequest{ListID}:::rss";
	
	my $order = $WebRequest{Order};
	$order = ($WebRequest{List}->{descending_by_default} ? 'd' : 'a') 
		unless ($order eq 'a' || $order eq 'd');
	
	header( title => $WebRequest{List}->{name}, RSS => $RSSLink );
	print "<h4 class=\"ez_pagetitle\">$STRINGS->{available_months}</h4>\n";
	print "<ul>\n";
	@months = $WebRequest{List}->{archive}->getmonths;
	@months = reverse(@months) if ($order eq 'd');
	foreach my $month (@months) {
		$month =~ m/^(\d{4})(\d{2})$/;
		print "<li><a href=\"?$WebRequest{ListID}:$month\">" . $STRINGS->{MONTHS}->[$2-1] . " $1</a></li>\n"
			 if defined $1;
	}
	print "</ul>\n";
	if ($WebRequest{List}->{subscription_info}) {
		print "<h4 class=\"ez_pagetitle\">$STRINGS->{subscriptions}</h4>\n";
		print "<p class=\"ez_medium\">$STRINGS->{to_subscribe}<br />\n";
		print "<a href=\"mailto:$WebRequest{List}->{local_part}-subscribe\@$WebRequest{List}->{host_part}\">";
		print "$WebRequest{List}->{local_part}-subscribe\@$WebRequest{List}->{host_part}</a></p>\n";
	}
	if ($WebRequest{List}->{search}) {
		print "<h4 class=\"ez_pagetitle\">$STRINGS->{search}:</h4>\n";
		print "<form class=\"ez_medium ez_searchForm\" action=\"?$WebRequest{ListID}:::search\" method=\"post\">";
		print '<div><input type="text" name="query" value="" /> ';
		printf '<input type="submit" value="%s" /></div>', $STRINGS->{search};
		print "</form>\n";
	}
	footer(RSS => $RSSLink);
}

sub show_month {
	my %WebRequest = @_;
	
	my $month = $WebRequest{Month};
	
	my $by = $WebRequest{SortBy};
	$by ||= { qw[date d subject s thread t] }->{$WebRequest{List}->{default_sorting}};
	$by ||= $WebRequest{List}->{bydate_by_default} ? 'd' : 't';
	
	my $order = $WebRequest{Order};
	$order = ($WebRequest{List}->{descending_by_default} ? 'd' : 'a')
		unless ($order eq 'a' || $order eq 'd');
	
	$month =~ m/^(\d{4})(\d{2})$/;
	my $MonthName = $STRINGS->{MONTHS}->[$2-1] . " $1";
	#header( title => $WebRequest{List}->{name} . ': ' . $MonthName ); ### Waiting until a better template system is created...
	header( title => $WebRequest{List}->{name}, url => $WebRequest{List}->{indexpage} );
	print "      <div id=\"ez_menubar\">\n";
	print "        <span class=\"menulabel\">$STRINGS->{month}</span>: ";
	print "<a href=\"?$WebRequest{ListID}:" . calc_month($month, 'prev') . "::$order\:$by\">$STRINGS->{previous}</a> - ";
	print "<a href=\"?$WebRequest{ListID}:" . calc_month($month, 'next') . "::$order\:$by\">$STRINGS->{next}</a><br />\n";
	print "        <span class=\"menulabel\">$STRINGS->{order}</span>: <a href=\"?$WebRequest{ListID}:$month\::$order:t\">$STRINGS->{bythread}</a> - ";
	print "<a href=\"?$WebRequest{ListID}:$month\::$order:d\">$STRINGS->{bydate}</a> - ";
	print "<a href=\"?$WebRequest{ListID}:$month\::a:s\">$STRINGS->{bysubject}</a>";
	print " (<a href=\"?$WebRequest{ListID}:$month\::a:$by\">$STRINGS->{ascending}</a> - ";
	print "<a href=\"?$WebRequest{ListID}:$month\::d:$by\">$STRINGS->{descending}</a>)\n";
	print "      </div>\n";
	print "      <h4 class=\"ez_pagetitle\">$MonthName</h4>\n";
	
	my $threads = $WebRequest{List}->{archive}->getthreads($month);
	if (!$threads->[0]) {
		print "$STRINGS->{no_messages_this_month}\n";
	}
	
	print "      <ul class=\"ez_threadlist\">\n";
	if ($by eq 'd' || $by eq 's') {
	
		my ($start, $end, %Messages) = threads2messages($threads);
		my @MessageIDs;
		if ($by eq 'd') {
			# let's sort by date
			@MessageIDs = $start..$end;
		} elsif ($by eq 's') {
			# let's sort by subject
			@MessageIDs = sort { $Messages{$a}->{subject} cmp $Messages{$b}->{subject} } keys %Messages;
		}
		@MessageIDs = reverse(@MessageIDs) if ($order eq 'd');
		
		for (@MessageIDs) {
            my $enc = guess_encoding($Messages{$_}->{subject}, qw/euc-jp shiftjis 7bit-jis utf8/);
			print "<li>";
			printf '<a href="?%s::%d">%s</a>', $WebRequest{ListID}, $_, Encode::decode( $enc, $Messages{$_}->{subject} );
			print " ($Messages{$_}->{author})";
			print "</li>\n";
		}
				
	} else {
		# Order messages by thread
	
		@$threads = reverse(@$threads) if ($order eq 'd');
		
		foreach my $thread (@$threads) {
			my $thread_info = $WebRequest{List}->{archive}->getthread( $thread->{id} );
            my $enc = guess_encoding( $thread_info->{subject}, qw/euc-jp shiftjis 7bit-jis utf8/ );
			$thread->{date} =~ s/\s-\d{4}$//;
			print "        <li>\n";
			printf "          <b>%s</b> (%s)<br />\n", Encode::decode( $enc, $thread_info->{subject} ), $thread->{date};
			print "          <ul class=\"messagelist\">\n";
			foreach my $message ( @{$thread_info->{messages}} ) {
				next if $message->{month} ne $month;
				printf "<li><a href=\"?%s::%s\">%s</a></li>\n", $WebRequest{ListID}, $message->{id}, $message->{author};
			}
			print "          </ul>\n";
			print "        </li>\n";
		}
		
	}
	print "      </ul>\n";
	
	footer();
}

sub show_message {
	my %WebRequest = @_;
	
	my $msg;
	while (!($msg && $msg->{text}) && $WebRequest{MessageID} >= 1) {
		$msg = $WebRequest{List}->{archive}->getmessage( $WebRequest{MessageID} );
		$WebRequest{MessageID}-- unless $msg->{text};
	}
	if (!$msg || !$msg->{text}) {
		fatal_error("Message $WebRequest{MessageID} does not exist.");
	}
	my $message = Mail::Message->read($msg->{text});
	
	header( title => $WebRequest{List}->{name}, url => $WebRequest{List}->{indexpage} );
	print "<div id=\"ez_menubar\">\n";
	print "$STRINGS->{message}: <a href=\"?$WebRequest{ListID}\::" . ($WebRequest{MessageID}-1) . "\">$STRINGS->{previous}</a> - ";
	print "<a href=\"?$WebRequest{ListID}\::" . ($WebRequest{MessageID}+1) . "\">$STRINGS->{next}</a><br />";
	$msg->{month} =~ m/^(\d{4})(\d{2})$/;
	print "$STRINGS->{month}: <a href=\"?$WebRequest{ListID}:" . $msg->{month} . "\">" . $STRINGS->{MONTHS}->[$2-1] . " $1</a>";
	print "</div>\n";
	print "<h4 class=\"ez_pagetitle\">" . htmlencode( $message->study('subject') ) . "</h4>\n";
	
	print "<div id=\"ez_msg\">\n";
	print "<div id=\"ez_header\">\n";
	print "<span class=\"ez_label\">$STRINGS->{from}:</span> " . htmlencode(conceal( $message->study('from'), $WebRequest{List} )) . "<br />\n";
	print "<span class=\"ez_label\">$STRINGS->{date}:</span> " . htmlencode($message->head->get('Date')) . "<br />\n";
	print "</div>\n";
	
 	my ($iframe, $rawhtml, $plaintext, %attachments, $charset);
 	eval { $charset = $message->head->study('Content-Type')->attribute('charset')->value };
 	$charset ||= 'iso-8859-1';
 	my $parts = get_parts($message);
 	for (my $i=0; $i<=$#$parts; $i++) {
 		my $part = $parts->[$i];
 		if ($part->{type} eq 'text/plain') {
 			#$plaintext .= '<pre>' . Encode::decode( $charset, htmlencode(conceal($part->{body}, $WebRequest{List})) ) . '</pre>';
 			$plaintext .= '<pre>' . htmlencode( conceal( Encode::decode( $charset, $part->{body}), $WebRequest{List})) . '</pre>';
 		} elsif ($part->{type} eq 'text/html') {
 			if ($WebRequest{List}->{show_html}) {
 				my $url = "?$WebRequest{ListID}::$WebRequest{MessageID}:get:$i";
 				$iframe .= '<iframe id="msghtml" src="' . $url . '" scrolling="no" marginwidth="0" ';
 				$iframe .= 'marginheight="0" frameborder="0" vspace="0" hspace="0" ';
 				$iframe .= 'style="overflow:visible;width:100%;display:none"></iframe>';
 			} else {
 				$rawhtml .= '<pre>' . Encode::decode( $charset, htmlencode(conceal($part->{body}, $WebRequest{List})) ) . '</pre>';
 			}
 		} elsif ($part->{type} !~ m,^(?:text/(?:plain|html|enriched)|application/applefile)$,) {
 			$attachments{$i} = $part;
 		}
 	}
 	
 	my $msg_output = $iframe || $plaintext || $rawhtml;
	$msg_output ||= '<pre>' . conceal($message->decoded, $WebRequest{List}) . '</pre>';
	if ($WebRequest{List}->{highlight}) {
		$msg_output =~ s/^( ?\&gt;.*)/<span class="ez_quot">$1<\/span>/gmo;
		$msg_output =~ s/\n(-{5} ?[^-]+-{5} ?\n.*)$/\n<span class="ez_quot">$1<\/span>/gos;
		$msg_output =~ s/\n(-- ?\n.*)$/\n<span class="ez_sign">$1<\/span>/os;
		$msg_output =~ s,(((http)+(s)?:(//)|(www\.))((\w|\.|\-|_)+)(/)?(\S+)?),<a href="http$4://$6$7$9$10">$1</a>,gio;
		if (!$WebRequest{List}->{conceal_senders}) {
			$msg_output =~ s/([0-9a-z]+([-_.]?[0-9a-z])*\@[0-9a-z]+([-.]?[0-9a-z])*\.[a-z]{2,5})/<a href="mailto:$1">$1<\/a>/gio;
		}
	}
	print $msg_output;
 	
 	if (%attachments) {
 		print "<br /><h4>$STRINGS->{attachments}:</h4>\n";
 		print "<ul class=\"ez_attachmentsList\">\n";
 		foreach my $att (keys %attachments) {
 			my $link = "?$WebRequest{ListID}::$WebRequest{MessageID}:get:$att";
 			if (($WebRequest{List}->{show_inline_images} || !defined($WebRequest{List}->{show_inline_images}))
 				&& $attachments{$att}->{type} =~ m,^image/(p?jpeg|gif|png)$,) {
 				printf '<li><small>%s</small><br /><img src="%s" alt="%s" /></li>' . "\n", 
 						$attachments{$att}->{name}, $link, $attachments{$att}->{name};
 			} else {
 				my $att_name = $attachments{$att}->{name};
 				my $att_info = sprintf "%s, %skb", $attachments{$att}->{type}, kb($attachments{$att}->{size});
 				unless ($att_name) {
 					$att_name = $attachments{$att}->{type};
 					$att_info = kb($attachments{$att}->{size}) . "kb";
 				}
 				print "<li><a href=\"$link\">$att_name</a> ($att_info)</li>\n";
 			}
 		}
 		print "</ul>\n";
 	}
	print "</div>\n";
	
	footer();
}

sub show_attachment {
	my %WebRequest = @_;
	
	my $message = $WebRequest{List}->{archive}->getmessage( $WebRequest{MessageID} )->{text};
 	my $parts = get_parts( Mail::Message->read($message) );
	my $attachment = $parts->[ $WebRequest{AttachmentID} ];
	print "Content-Type: $attachment->{type}; name=$attachment->{name}\n";
	print "Content-Length: " . length($attachment->{body}) . "\n";
	if ($attachment->{type} !~ m,(?:text/html|text/plain|image/),) {
		print "Content-disposition: attachment; filename=$attachment->{name}\n";
	}
	print "Content-Transfer-Encoding: binary\n\n";
	if ($attachment->{type} =~ m,(?:text/html|text/plain),) {
		# it would be nice to do some other filtering here
		# (for example all <script> tags and other js things).
		print conceal($attachment->{body}, $WebRequest{List});
	} else {
		print $attachment->{body};
	}
}

sub search {
	my %WebRequest = @_;
	
	if (!$WebRequest{List}->{search}) {
		fatal_error("Search is not enabled.");
	}

	my @docs;
	if ($WebRequest{Search}->{query}) {
		
		if ($WebRequest{List}->{search} eq 'kinosearch' 
			&& -e "$WebRequest{List}->{search_dir}/kinostats") {
			# old Search::Kinosearch
			eval q{
				use Search::Kinosearch::KSearch;
				use Search::Kinosearch::Query;
				1;
			} or fatal_error("Failed to load Search::Kinosearch (upgrading to KinoSearch is recommended).");
			my $ksearch = Search::Kinosearch::KSearch->new(
				-mainpath      => $WebRequest{List}->{search_dir},
				-num_results   => 50
			);
			my $query = Search::Kinosearch::Query->new(
				-string    => $WebRequest{Search}->{query},
				-lowercase => 1,
				-tokenize  => 1
			);
			$ksearch->add_query($query);
			$ksearch->process;
			while (my $hit = $ksearch->fetch_hit_hashref) {
				push @docs, {
					score => $hit->{score},
					id => $hit->{doc_id},
					subject => $hit->{subject},
					author => $hit->{author},
					date => $hit->{date}
				};
			}
		} elsif ($WebRequest{List}->{search} eq 'kinosearch') {
			# new KinoSearch suite
			eval q{
				use KinoSearch::Searcher;
				use KinoSearch::Analysis::PolyAnalyzer;
				1;
			} or fatal_error("Failed to load KinoSearch modules.");
			my $analyzer = KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' );
			my $searcher = KinoSearch::Searcher->new(
				invindex => $WebRequest{List}->{search_dir},
				analyzer => $analyzer
			);
			my $hits = $searcher->search( query => $WebRequest{Search}->{query} );
			while ( my $hit = $hits->fetch_hit_hashref ) {
				push @docs, {
					score => $hit->{score},
					id => $hit->{msg_id},
					subject => $hit->{subject},
					author => $hit->{author},
					date => $hit->{date}
				};
			};
		} elsif ($WebRequest{List}->{search} eq 'plucene') {
			eval q{
				use Plucene::QueryParser;
				use Plucene::Analysis::SimpleAnalyzer;
				use Plucene::Document::DateSerializer;
				use Plucene::Search::IndexSearcher;
				1;
			} or fatal_error("Failed to load Plucene.");
			my $parser = Plucene::QueryParser->new({
				analyzer => Plucene::Analysis::SimpleAnalyzer->new(),
				default  => "message"
			});
			my $query = $parser->parse($WebRequest{Search}->{query});
			my $searcher = Plucene::Search::IndexSearcher->new($WebRequest{List}->{search_dir});
			my $hc = Plucene::Search::HitCollector->new(collect => sub {
				my ($self, $doc, $score) = @_;
				my $d = $searcher->doc($doc);
				my $t = $d->[0]->get('date')->string;
				push @docs, {
					score => $score,
					id => $d->[0]->get('id')->string,
					subject => $d->[0]->get('subject')->string,
					author => $d->[0]->get('author')->string,
					date => Plucene::Document::DateSerializer::thaw_date($t)->cdate
				};
				push @docs, [ $searcher->doc($doc), $score ];
			});
			
			$searcher->search_hc($query => $hc);
		}
	}
	
	header( title => $WebRequest{List}->{name}, url => $WebRequest{List}->{indexpage} );
	my $qr = htmlencode($WebRequest{Search}->{query});
	print <<EOF;
		<form action="?$WebRequest{ListID}:::search" method="post">
		$STRINGS->{search}: <input type="text" name="query" value="$qr" /> <input type="submit" value="$STRINGS->{search}" />
		</form>
EOF
	if (@docs) {
		print "      <ul class=\"ez_threadlist\">\n";
		foreach my $doc (@docs) {
			print "        <li>";
			printf('<a href="?%s::%s">', $WebRequest{ListID}, $doc->{id});
			printf('%s</a>', $doc->{subject});
			printf(" (%s)", $doc->{author});
			printf("<br /><i>%s</i>\n", $doc->{date}) if ($doc->{date});
			print "</li>\n";
		}
		print "      </ul>\n";
	}
	
	footer();
}

sub RSSFeed {
	my %WebRequest = @_;
	
	print <<EOF
Content-Type: text/xml

<?xml version="1.0" encoding='UTF-8'?>
<rss version="2.0">
  <channel>
    <title>$WebRequest{List}->{name}</title>
    <link>$Config{URL}</link>
EOF
;
	my $curmonth = (reverse $WebRequest{List}->{archive}->getmonths)[0];
	my $threads = $WebRequest{List}->{archive}->getthreads($curmonth);
	my ($start, $end, %Messages) = threads2messages($threads);

	for ($start .. $end) {
		my $msg = $WebRequest{List}->{archive}->getmessage($_);
		my $msgdate = htmlencode( Mail::Message->read($msg->{text})->head->get('Date') );
        my $enc = guess_encoding($Messages{$_}->{subject}, qw/euc-jp shiftjis 7bit-jis utf8/);
        my $subject = Encode::decode( $enc, $Messages{$_}->{subject} );
		print <<EOF
    <item>
      <title>$subject</title>
      <link>$Config{URL}?$WebRequest{ListID}::$_</link>
      <pubDate>$msgdate</pubDate>
    </item>
EOF
	}
	
	print <<EOF
  </channel>
</rss>
EOF
;
	exit;
}


#-----------------------------------------------------------------------

sub ParseRequest {
	my @Params = split ':', $ENV{QUERY_STRING};
	my %WebRequest = ();
	if ( $Params[0] eq '' && $#{$lists} > 0 ) {
		$WebRequest{Action} = 'show_lists';
	} else {
		if (defined $vpopmail::VERSION) {
			$Params[0] =~ s/:.+$//;
			fatal_error("Invalid mailing list name.") unless $Params[0] =~ /^([\w\-\_\.]+)\@([\w\-\.]+)$/;
			$WebRequest{ListID} = $Params[0];
			$WebRequest{List} = {
				name => $Params[0],
				local_part => $1,
				host_part => $2,
				description => $Params[0],
				archive => Mail::Ezmlm::Archive->new( vgetdomaindir($2) . "/$1" ),
				indexpage => '?' . $Params[0],
				map { $_ => $Config{DefaultVpopmailSettings}->{$_} } 
					qw/conceal_senders subscription_info descending_by_default 
					default_sorting show_html highlight/
			};
			my $Allow = $Config{VpopmailAccess}->{default_policy} eq 'allow';
			$Allow = 1 if { map { $_ => 1 } @{$Config{VpopmailAccess}->{allow_lists}} }->{$Params[0]};
			$Allow = 1 if { map { $_ => 1 } @{$Config{VpopmailAccess}->{allow_domains}} }->{$2};
			$Allow = 0 if { map { $_ => 1 } @{$Config{VpopmailAccess}->{deny_lists}} }->{$Params[0]};
			$Allow = 0 if { map { $_ => 1 } @{$Config{VpopmailAccess}->{deny_domains}} }->{$2};
			fatal_error("Service unavailable.") unless $Allow;
		} else {
			$WebRequest{ListID} = $#{$lists} == 0 ? 0 : $Params[0];
			$WebRequest{List} = $lists->[ $WebRequest{ListID} ];
			$WebRequest{List}->{indexpage} = '?' . $Params[0];
		}
		$WebRequest{List}->{archive}->nocache if $MOD_PERL;
		$WebRequest{Action} = 'show_list';
		$WebRequest{Order} = $Params[3];
		if ($Params[2] ne '') {
			## We got a message ID
			$WebRequest{MessageID} = $Params[2];
			if ($Params[3] eq 'get') {
				$WebRequest{Action} = 'show_attachment';
				$WebRequest{AttachmentID} = $Params[4];
			} else {
				$WebRequest{Action} = 'show_message';
			}
		} elsif ($Params[1] ne '') {
			## We got month
			$WebRequest{Action} = 'show_month';
			$WebRequest{Month} = $Params[1];
			$WebRequest{SortBy} = $Params[4];
		} elsif ($Params[3] ne '') {
			## We got a third parameter
			if ($Params[3] eq 'rss') {
				$WebRequest{RSS} = 1;
			} elsif ($Params[3] eq 'search') {
				$WebRequest{Action} = 'search';
				my %args = read_post();
				$WebRequest{Search} = { query => $args{query} };
			}
		}
		CheckListArchive($WebRequest{List}, 0);
	}
	return %WebRequest;
}

sub CheckListArchive {
	my ($List, $dont_send_header) = @_;
	
	if (!defined $List->{archive}) {
		fatal_error(<<"EOF",
Unable to access mailing list <i>$lists->[$_]->{name}</i>. <br />
<small>Its directory may not exist, or the webserver may not have
appropriate permissions to read archives, or the mailing list may
not be both archived and indexed (as required).</small>
EOF
		$dont_send_header);
	}
	
}

sub header {
	my %params = @_;
	
	my $rsslink = $params{RSS} ? "\n    <link rel=\"alternate\" type=\"application/rss+xml\" title=\"RSS 2.0\" 
									href=\"$params{RSS}\" />" : "";
	
	my $toplink = $params{url} ? "<a href=\"$params{url}\">$params{title}</a>" : $params{title};
	binmode STDOUT, ':utf8';
	print <<EOF
Content-Type: text/html; charset=utf-8

<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
      "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html>
  <head>
    <title>$params{title}</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <link rel="stylesheet" href="$Config{CSSPath}" />$rsslink
    <script type="text/javascript">
<!--
/*IFrame SSI script II- (c) Dynamic Drive DHTML code library (http://www.dynamicdrive.com)
* Visit DynamicDrive.com for hundreds of original DHTML scripts
* This notice must stay intact for legal use*/
var iframeids=["msghtml"]
var iframehide="no"
var getFFVersion=navigator.userAgent.substring(navigator.userAgent.indexOf("Firefox")).split("/")[1]
var FFextraHeight=parseFloat(getFFVersion)>=0.1? 16 : 0 //extra height in px to add to iframe in FireFox 1.0+ browsers
function resizeCaller() {
var dyniframe=new Array()
for (i=0; i<iframeids.length; i++){
if (document.getElementById)
resizeIframe(iframeids[i])
//reveal iframe for lower end browsers? (see var above):
if ((document.all || document.getElementById) && iframehide=="no"){
var tempobj=document.all? document.all[iframeids[i]] : document.getElementById(iframeids[i])
tempobj.style.display="block"
}}}
function resizeIframe(frameid){
var currentfr=document.getElementById(frameid)
if (currentfr && !window.opera){
currentfr.style.display="block"
if (currentfr.contentDocument && currentfr.contentDocument.body.offsetHeight) //ns6 syntax
currentfr.height = currentfr.contentDocument.body.offsetHeight+FFextraHeight; 
else if (currentfr.Document && currentfr.Document.body.scrollHeight) //ie5+ syntax
currentfr.height = currentfr.Document.body.scrollHeight;
if (currentfr.addEventListener)
currentfr.addEventListener("load", readjustIframe, false)
else if (currentfr.attachEvent){
currentfr.detachEvent("onload", readjustIframe) // Bug fix line
currentfr.attachEvent("onload", readjustIframe)
}}}
function readjustIframe(loadevt) {
var crossevt=(window.event)? event : loadevt
var iframeroot=(crossevt.currentTarget)? crossevt.currentTarget : crossevt.srcElement
if (iframeroot)
resizeIframe(iframeroot.id);
}
function loadintoIframe(iframeid, url){
if (document.getElementById)
document.getElementById(iframeid).src=url
}
if (window.addEventListener)
window.addEventListener("load", resizeCaller, false)
else if (window.attachEvent)
window.attachEvent("onload", resizeCaller)
else
window.onload=resizeCaller
-->
</script>
  </head>
  <body>
    <div id="ez_container">
      <h2 class="ez_header">$toplink</h2>
EOF
}

sub footer {
	my %Params = @_;
	
	my $rsslink = $Params{RSS} ? " - <a href=\"$Params{RSS}\">RSS feed</a>" : "";
	print <<EOF
      <h4 class="ez_footer">powered by <a href="http://ezmlm-www.sourceforge.net">ezmlm-www</a> (v$VERSION)$rsslink</h4>
    </div>
  </body>
</html>
EOF
}

sub fatal_error {
	my ($error, $dont_send_header) = @_;
	header() unless $dont_send_header;
	print "<b>Error: $error</b>";
	footer();
	exit;
}

sub htmlencode {
	$_[0] =~ s/&/\&amp;/g;
	$_[0] =~ s/"/\&quot;/g;
	$_[0] =~ s/</\&lt;/g;
	$_[0] =~ s/>/\&gt;/g;
	return $_[0];
}

sub get_parts {
	my $message = shift;
	my @parts;
	if ($message->isMultipart) {
		foreach ($message->parts) {
			push @parts, @{get_parts($_)};
		}
	} else {
		my $partname;
		eval { $partname = $message->head->study('Content-Type')->attribute('name') };
		$partname = $@ ? $message->head->study('Content-Type') : ($partname && $partname->value);
		push @parts, {
			type => lc($message->body->mimeType),
			name => $partname,
			size => $message->body->size,
			body => $message->decoded
		};
	}
	return [@parts];
}

sub threads2messages {
	my ($threads) = @_;
	
	my $start = $threads->[0]->{offset};
	my $end = $threads->[$#$threads]->{offset};
		
	#my %Messages = map { $_ => 1 } ($start .. $end);
	my %Messages;
	foreach my $thread ( @$threads ) {
		my $thread_info = $WebRequest{List}->{archive}->getthread( $thread->{id} );
		foreach my $message ( @{ $thread_info->{messages} } ) {
			$Messages{$message->{id}} = {
				subject => $thread_info->{subject},
				author => $message->{author}
			#} if exists $Messages{$message->{id}};
			} if ($message->{id} >= $start && $message->{id} <= $end);
		}
	}
	return ($start, $end, %Messages);
}

sub kb {
	return sprintf( "%0.1f", (shift)/1024 );
}

sub conceal {
	my ($addr, $List) = @_;
	if ( $List->{conceal_senders} ) {
		$addr =~ s/([_a-z0-9-]+(\.[_a-z0-9-]+)*)\@[a-z0-9-]+(\.[a-z0-9-]+)+/\1\@.../gio;
	}
	return $addr;
}

sub calc_month {
	my ($month, $op) = @_;
	$month =~ m/^(\d{4})(\d{2})$/o;
	my $t = $1*12 + $2 - 1;
	$t++ if ($op eq 'next');
	$t-- if ($op eq 'prev');
	return sprintf("%04u%02u", int($t/12), $t%12 + 1);
}

sub read_post {
	if ($ENV{REQUEST_METHOD} eq 'POST') {
		my ($in, %args);
		read(STDIN, $in, $ENV{CONTENT_LENGTH});
		foreach (split /&/, $in) {
			my ($name, $value) = split(/=/, $_);
			$value =~ tr/+/ /;
			$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
			$args{$name} = $value;
		}
		return %args;
	}
	return undef;
}

1;

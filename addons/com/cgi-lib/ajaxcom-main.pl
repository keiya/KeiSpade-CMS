# ------------------------------------------------------------------------
#   ajaxcom.cgi ---- Ajax comment component (CGI)
#   Copyright 2005-2006 Kawasaki Yusuke <u-suke [at] kawa.net>
#   http://www.kawa.net/works/ajax/ajaxcom/ajaxcom.html
# ------------------------------------------------------------------------
    use strict;
    use CGI;
    use XML::FeedPP;
    require "misclib.pl";
# ------------------------------------------------------------------------
    my $AJAXCOM_DATA = "./ajaxcom-data";
    my $URL_ROOT     = "http://www.keiyac.org";
    my $DOC_ROOT     = "./";
# ------------------------------------------------------------------------
    &ajaxcom_main();
# ------------------------------------------------------------------------
sub ajaxcom_main {
    my $cgi = new CGI();

	#if ( $cgi->param("__mode") eq "rss" ) {
	#    &ajaxcom_mode_rss();
	#    return;
	#};

    my $name = $cgi->param("name");
    my $content = $cgi->param("content");
    &misclib::tb_err_response( "name is null" ) if ( $name eq "" );
    &misclib::tb_err_response( "content is null" ) if ( $content eq "" );

    my $file = &misclib::get_log_filename( $AJAXCOM_DATA );
    &misclib::tb_err_response( "invalid service url" ) unless defined $file;

    my $date = &misclib::get_w3cdtf_date();
	#my $iphash = &misclib::get_ipaddr_hash();
    my $ipaddr = $ENV{REMOTE_ADDR} or 'undef';
    my $line = [ $date, $$, $ipaddr, $name, $content ];
    my $werror = &misclib::write_tab_line( $file, $line );
    &misclib::tb_err_response( $werror ) if defined $werror;

	#&ajaxcom_update_rss();

    &misclib::tb_ok_response();
}
# ----------------------------------------------------------------
sub ajaxcom_mode_rss {
    my $rssfile = &ajaxcom_update_rss();
    &misclib::tb_err_response( "rss update failed." ) unless $rssfile;
    open( RSS, $rssfile ) or &misclib::tb_err_response( "$! - $rssfile" );
    print "Content-Type: text/xml; charset=UTF-8\n\n";
    print <RSS>;
    close( RSS );
}
# ----------------------------------------------------------------
sub ajaxcom_update_rss {
    my $max_total = shift || 50;
    my $max_page  = shift || 10;
    my $max_json  = shift || 10;

    my $bufline = &misclib::find_recent_lines( $AJAXCOM_DATA, $max_total, $max_page );
    my $feed = XML::FeedPP::RSS->new();

    $feed->link( $URL_ROOT );
    $feed->title( "Comments $URL_ROOT" );
    my $alias = &misclib::read_url_alias( $AJAXCOM_DATA ) || {};
	$alias = { reverse %$alias };

    foreach my $pair ( @$bufline ) {
        my $url = ( $pair->[0] =~ m#([^/]+)\.txt$# )[0];
        my $path;
        if ( $alias->{$url} ) {
            $path = $alias->{$url};
        } else {
            $path = $url;
            $path =~ s#_#/#g;           # if aliases is not exist
        }
        my $file = "$DOC_ROOT/$path";
        next unless ( -r $file );
        my( $pubdate, $pid, $ip, $name, $content ) = split( /\t/, $pair->[1] );
        chomp $content;
        my $url = "$URL_ROOT/$path#com-$pubdate";
        my $item = $feed->add_item( $url );
        $item->title( $content );
        $item->pubDate( $pubdate );
        $item->author( $name );
    }

    my $rssfile = "$AJAXCOM_DATA/recent.xml";
    &misclib::output_feed_rss( $feed, $rssfile );

    my $jsonfile = "$AJAXCOM_DATA/recent.json";
    $feed->limit_item( $max_json );
    &misclib::output_feed_json( $feed, $jsonfile );

    $rssfile;
}
# ------------------------------------------------------------------------
;1;
# ------------------------------------------------------------------------

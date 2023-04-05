# Title:	MT-Blacklist MT::App::Trackback::ping
# Summary:	MT-Blacklist's redefinition of MT::App::Trackback::ping
# Author:	Jay Allen (http://www.jayallen.org/)
# Version:	1.6.4
# Date:		May 20, 2004
#
# Information about this plugin can be found at
# http://www.jayallen.org/projects/mt-blacklist
#
# Until I get some sleep and can think about licenses:
# Copyright 2003 Jay Allen
# This code cannot be redistributed without
# permission from the author. 

package jayallen::MTBlPing;

use vars qw($VERSION);

$VERSION = '1.0';

# In order to include the link in the comment notification
# email, I have to use the entire 'post' method, because
# Ben has never abstracted the emails as templates.  Grrrrr.
#
sub ping_post_hdlr {

	require jayallen::Blacklist;

    my $app = shift;
    my $q = $app->{query};
    my($tb_id, $pass) = $app->_get_params;
    return $app->_response(Error =>
           $app->translate("Need a TrackBack ID (tb_id)."))
        unless $tb_id;

    use MT::Util qw( first_n_words encode_xml is_valid_url );
    use File::Spec;
    require MT::App::Trackback;
    #print STDERR "In ".__PACKAGE__." at ".__LINE__."\n";
    #warn "In ".__PACKAGE__." at ".__LINE__."\n";

    my($title, $excerpt, $url, $blog_name) = map scalar $q->param($_),
                                             qw( title excerpt url blog_name);

    MT::App::Trackback::no_utf8($tb_id, $title, $excerpt, $url, $blog_name);

    return $app->_response(Error => $app->translate("Need a Source URL (url)."))
        unless $url;

    if (my $fixed = MT::Util::is_valid_url($url)) {
        $url = $fixed; 
    } else {
        return $app->_response(Error =>
            $app->translate("Invalid URL '[_1]'", $url));
    }

    require MT::TBPing;

    my $tb = jayallen::Blacklist::_getTrackback($tb_id)
        or return $app->_response(Error =>
            $app->translate("Invalid TrackBack ID '[_1]'", $tb_id));

    return $app->_response(Error =>
        $app->translate("This TrackBack item is disabled."))
        if $tb->is_disabled;

    if ($tb->passphrase && (!$pass || $pass ne $tb->passphrase)) {
        return $app->_response(Error =>
          $app->translate("This TrackBack item is protected by a passphrase."));
    }

    ## Check if this user has been banned from sending TrackBack pings.
    require MT::IPBanList;
    my $iter = MT::IPBanList->load_iter({ blog_id => $tb->blog_id });
    my $user_ip = $app->remote_ip;
    while (my $ban = $iter->()) {
        my $banned_ip = $ban->ip;
        if ($user_ip =~ /$banned_ip/) {
            return $app->_response(Error =>
              $app->translate("You are not allowed to send TrackBack pings."));
        }
    }

    ## Check if user has pinged recently
    #my @past = MT::TBPing->load({ tb_id => $tb_id, ip => $host_ip });
    #if (@past) {
    #    @past = sort { $b->created_on cmp $a->created_on } @past;
    #}

### INSERTED CODE STARTS HERE ###
    if (my ($blRc,$blStr,$textStr,$blResponse) = jayallen::Blacklist::_matchBlacklist($tb->blog_id,$title,$excerpt,$url)) { 
	    my $blog = jayallen::Blacklist::_getBlog($tb->blog_id);

		$app->log('MT-Blacklist trackback denial on '.$blog->name.": $blStr") if defined($blStr);
		$blResponse =~ s/__TYPE__/ping/g;
		$blResponse =~ s/__BLACKLIST__/$blStr/g if defined($blStr);
		$blResponse =~ s/__TEXT__/$textStr/g if defined($textStr);
		return $app->_response(Error => $blResponse);
    }
### INSERTED CODE ENDS HERE ###

    my $ping = MT::TBPing->new;
    $ping->blog_id($tb->blog_id);
    $ping->tb_id($tb_id);
    $ping->source_url($url);
    $ping->ip($app->remote_ip || '');
    if ($excerpt) {
        if (length($excerpt) > 255) {
            $excerpt = substr($excerpt, 0, 252) . '...';
        }
        $title = first_n_words($excerpt, 5)
            unless defined $title;
        $ping->excerpt($excerpt);
    }
    $ping->title(defined $title && $title ne '' ? $title : $url);
    $ping->blog_name($blog_name);
    $ping->save;

    ## If this is a trackback item for a particular entry, we need to
    ## rebuild the indexes in case the <$MTEntryTrackbackCount$> tag
    ## is being used. We also want to place the RSS files inside of the
    ## Local Site Path.
    my($blog_id, $entry, $cat);
    if ($tb->entry_id) {
        $entry = jayallen::Blacklist::_getEntry($tb->entry_id);
        $blog_id = $entry->blog_id;
    } elsif ($tb->category_id) {
        require MT::Category;
        $cat = MT::Category->load($tb->category_id);
        $blog_id = $cat->blog_id;
    }
    my $blog = jayallen::Blacklist::_getBlog($blog_id);
    $app->rebuild_indexes( Blog => $blog )
        or return $app->_response(Error =>
            $app->translate("Rebuild failed: [_1]", $app->errstr));

    if ($app->{cfg}->GenerateTrackBackRSS) {
        ## Now generate RSS feed for this trackback item.
        my $rss = MT::App::Trackback::_generate_rss($tb, 10);
        my $base = $blog->archive_path;
        my $feed = File::Spec->catfile($base, $tb->rss_file || $tb->id . '.xml');
        my $fmgr = $blog->file_mgr;
        $fmgr->put_data($rss, $feed)
            or return $app->_response(Error =>
                $app->translate("Can't create RSS feed '[_1]': ", $feed,
                $fmgr->errstr));
    }

    if ($blog->email_new_pings) {
        require MT::Mail;
        my($author, $subj, $body);
        if ($entry) {
            $author = $entry->author;
            $app->set_language($author->preferred_language)
                if $author && $author->preferred_language;
            $subj = $app->translate('New TrackBack Ping to Entry [_1] ([_2])',
                $entry->id, $entry->title);
            $body = $app->translate('A new TrackBack ping has been sent to your weblog, on the entry [_1] ([_2]).', $entry->id, $entry->title);
        } elsif ($cat) {
            require MT::Author;
            $author = MT::Author->load($cat->created_by);
            $app->set_language($author->preferred_language)
                if $author && $author->preferred_language;
            $subj = $app->translate('New TrackBack Ping to Category [_1] ([_2])',
                $cat->id, $cat->label);
            $body = $app->translate('A new TrackBack ping has been sent to your weblog, on the category [_1] ([_2]).', $cat->id, $cat->label);
        }
        if ($author && $author->email) {
            my %head = ( To => $author->email,
                         From => $author->email,
                         Subject => '[' . $blog->name . '] ' . $subj );
            my $charset = $app->{cfg}->PublishCharset || 'iso-8859-1';
            $head{'Content-Type'} = qq(text/plain; charset="$charset");
            require Text::Wrap;
            $Text::Wrap::cols = 72;
            $body = Text::Wrap::wrap('', '', $body) . "\n\n" .
                 $app->translate('IP Address:') . ' ' . $ping->ip . "\n" .
                 $app->translate('URL:') . ' ' . $ping->source_url . "\n" .
                 $app->translate('Title:') . ' ' . $ping->title . "\n" .
                 $app->translate('Weblog:') . ' ' . $ping->blog_name . "\n\n" .
                 $app->translate('Excerpt:') . "\n" . $ping->excerpt . "\n";

### INSERTED CODE STARTS HERE ###
 	             my $ping_view_url = $app->base.$app->path.
					'mt-blacklist.cgi?__mode=despam&_type=ping&id='.
						$ping->id;
 	             $body .= "\n\n".('-'x22).
 	             	"\nDe-spam using MT-Blacklist:\n". 
 	             		$ping_view_url. "\n\n";
### INSERTED CODE ENDS HERE ###

            MT::Mail->send(\%head, $body);
        }
    }

    return $app->_response;
}

1;







# Title:	MT-Blacklist MT::App::Trackback::ping
# Summary:	MT-Blacklist's redefinition of MT::App::Comments::post
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


####################################################
#
#  NOTE TO SOURCE CODE HACKERS
#
#  There are TWO comment post handling routines in 
#  but ONLY ONE is called.  Which one depends on the
#  version of your Movable Type install. 
#
#  If you want to hack this file as you would  
#  MT/App/Comments.pm, hack only the subroutine 
#  shown below:
#
#  Movable Type 2.65 and older: comment_post_hdlr_26
#  Movable Type 2.66 and newer: comment_post_hdlr_266
#
####################################################




package jayallen::MTBlPost;

use vars qw($VERSION);

# Upgraded for compatibility with MT 2.661
$VERSION = '1.1';


# In order to include the link in the comment notification
# email, I have to use the entire 'post' method, because
# Ben has never abstracted the emails as templates.  Grrrrr.
#
sub comment_post_hdlr {
    my $app = shift;
	require MT;
    if ($MT::VERSION lt '2.66') {
        comment_post_hdlr_26($app);
    } else {
        comment_post_hdlr_266($app);
    }
}

sub comment_post_hdlr_26 { 

	require jayallen::Blacklist;

	use MT::Util qw( remove_html );
    my $app = shift;
    my $q = $app->{query};
    if (my $state = $q->param('comment_state')) {
        require MT::Serialize;
        my $ser = MT::Serialize->new($app->{cfg}->Serializer);
        $state = $ser->unserialize(pack 'H*', $state);
        $state = $$state;
        for my $f (keys %$state) {
            $q->param($f, $state->{$f});
        }
    }

    my $entry_id = $q->param('entry_id')
        or return $app->error("No entry_id");
    my $entry = jayallen::Blacklist::_getEntry($entry_id)
        or return $app->error($app->translate(
            "Invalid entry ID '[_1]'.", scalar $q->param('entry_id')));
    unless ($entry->allow_comments eq '1') {
        return $app->handle_error($app->translate(
            "Comments are not allowed on this entry."));
    }
    require MT::IPBanList;
    my $iter = MT::IPBanList->load_iter({ blog_id => $entry->blog_id });
    my $user_ip = $app->remote_ip;
    while (my $ban = $iter->()) {
        my $banned_ip = $ban->ip;
        if ($user_ip =~ /$banned_ip/) {
            return $app->handle_error($app->translate(
                "You are not allowed to post comments."));
        }
    }
    my $blog = jayallen::Blacklist::_getBlog($entry->blog_id);
    if (!$blog->allow_anon_comments &&
        (!$q->param('author') || !$q->param('email'))) {
        return $app->handle_error($app->translate(
            "Name and email address are required."));
    }
    if (!$q->param('text')) {
        return $app->handle_error($app->translate("Comment text is required."));
    }
### INSERTED CODE STARTS HERE ###
    if (my ($blRc,$blStr,$textStr,$blResponse) = jayallen::Blacklist::_matchBlacklist($entry->blog_id,
    					$q->param('text'), 
    					$q->param('url'), 
    					$q->param('email'), 
    					$q->param('author'))) { 
		$app->log('MT-Blacklist comment denial on '.$blog->name.": $blStr") if defined($blStr);
		if (defined($blResponse)) {
            $blResponse =~ s/__TYPE__/comment/g;
            $blResponse =~ s/__BLACKLIST__/$blStr/g if defined($blStr);
            $blResponse =~ s/__TEXT__/$textStr/g if defined($textStr);
		}
		return $app->handle_error($blResponse);
    }
### INSERTED CODE ENDS HERE ###

    my $comment = MT::Comment->new;
    $comment->ip($app->remote_ip);
    $comment->blog_id($entry->blog_id);
    $comment->entry_id($q->param('entry_id'));
    $comment->author(remove_html(scalar $q->param('author')));
    my $email = $q->param('email') || '';
    if ($email) {
        require MT::Util;
        if (my $fixed = MT::Util::is_valid_email($email)) {
            $email = $fixed;
        } else {
            return $app->handle_error($app->translate(
                "Invalid email address '[_1]'", $email));
        }
    }
    $comment->email(remove_html($email));
    my $url = $q->param('url') || '';
    if ($url) {
        require MT::Util;
        if (my $fixed = MT::Util::is_valid_url($url)) {
            $url = $fixed;
        } else {
            return $app->handle_error($app->translate(
                "Invalid URL '[_1]'", $url));
        }
    }
    $comment->url(remove_html($url));
    $comment->text($q->param('text'));
    $comment->save;
    $app->rebuild_indexes( Blog => $blog )
        or return $app->error($app->translate(
            "Rebuild failed: [_1]", $app->errstr));
    $app->rebuild_entry( Entry => $entry )
        or return $app->error($app->translate(
            "Rebuild failed: [_1]", $app->errstr));
    my $link_url;
    if (!$q->param('static')) {
        my $url = $app->base . $app->uri;
        $url .= '?entry_id=' . $q->param('entry_id');
        $link_url = $url;
    } else {
        my $static = $q->param('static');
        if ($static == 1) {
            $link_url = $entry->permalink;
        } else {
            $link_url = $static . '#' . $comment->id;
        }
    }
    if ($blog->email_new_comments) {
        require MT::Mail;
        my $author = $entry->author;
        $app->set_language($author->preferred_language)
            if $author && $author->preferred_language;
        if ($author && $author->email) {
            my %head = ( To => $author->email,
                         From => $comment->email || $author->email,
                         Subject =>
                             '[' . $blog->name . '] ' .
                             $app->translate('New Comment Posted to \'[_1]\'',
                                 $entry->title)
                       );
            my $charset = $app->{cfg}->PublishCharset || 'iso-8859-1';
            $head{'Content-Type'} = qq(text/plain; charset="$charset");
            my $body = $app->translate(
                'A new comment has been posted on your blog [_1], on entry #[_2] ([_3]).',
                $blog->name, $entry->id, $entry->title);
            require Text::Wrap;
            $Text::Wrap::cols = 72;
            $body = Text::Wrap::wrap('', '', $body) . "\n$link_url\n\n" .
              $app->translate('IP Address:') . ' ' . $comment->ip . "\n" .
              $app->translate('Name:') . ' ' . $comment->author . "\n" .
              $app->translate('Email Address:') . ' ' . $comment->email . "\n" .
              $app->translate('URL:') . ' ' . $comment->url . "\n\n" .
              $app->translate('Comments:') . "\n\n" . $comment->text . "\n";

### INSERTED CODE STARTS HERE ###
              my $comment_view_url = $app->base.$app->path.'mt-blacklist.cgi?__mode=despam&_type=comment&id='.$comment->id;
              $body .= "\n\n----------------------\nDe-spam using MT-Blacklist:\n". $comment_view_url. "\n\n";
### INSERTED CODE ENDS HERE ###

            MT::Mail->send(\%head, $body);
        }
    }
    return $app->redirect($link_url);
}




sub comment_post_hdlr_266 {

	require jayallen::Blacklist;

    use MT::Util qw( remove_html encode_html );
    my $app = shift;
    my $q = $app->{query};

    my $entry_id = $q->param('entry_id')
        or return $app->error("No entry_id");
    my $entry = jayallen::Blacklist::_getEntry($entry_id)
        or return $app->error($app->translate(
            "Invalid entry ID '[_1]'.", scalar $q->param('entry_id')));

    my $user_ip = $app->remote_ip;
    require MT::Util;
    my @ts = MT::Util::offset_time_list(time - $app->{cfg}->ThrottleSeconds,
			      $entry->blog_id);
    my $from = sprintf("%04d%02d%02d%02d%02d%02d",
		       $ts[5]+1900, $ts[4]+1, @ts[3,2,1,0]);
    require MT::Comment;

    if (MT::Comment->count({ ip => $user_ip,
			     created_on => [$from] },
			   {range => {created_on => 1} }))
    {
	$app->log("Throttled comment attempt from $user_ip");
	return $app->handle_error($app->translate("In an effort to curb malicious comment posting by abusive users, I've enabled a feature that requires a weblog commenter to wait a short amount of time before being able to post again. Please try to post your comment again in a short while. Thanks for your patience."), "403 Throttled");
    }
    require MT::IPBanList;
    my $iter = MT::IPBanList->load_iter({ blog_id => $entry->blog_id });
    while (my $ban = $iter->()) {
        my $banned_ip = $ban->ip;
        if ($user_ip =~ /$banned_ip/) {
            return $app->handle_error($app->translate(
                "You are not allowed to post comments."));
        }
    }
    @ts = MT::Util::offset_time_list(time - $app->{cfg}->ThrottleSeconds*10-1,
				     $entry->blog_id);
    $from = sprintf("%04d%02d%02d%02d%02d%02d",
		       $ts[5]+1900, $ts[4]+1, @ts[3,2,1,0]);
    my $count =  MT::Comment->count({ ip => $user_ip,
				      created_on => [$from] },
				    { range => {created_on => 1}});
    if ($count >= 8)
    {
	require MT::IPBanList;
	my $ipban = MT::IPBanList->new();
	$ipban->blog_id($entry->blog_id);
	$ipban->ip($user_ip);
	$ipban->save();
	$ipban->commit();
	$app->log("IP $user_ip banned because comment rate " .
		  "exceeded 8 comments in " .
		  10 * $app->{cfg}->ThrottleSeconds . " seconds.");
        require MT::Mail;
        my $author = $entry->author;
        $app->set_language($author->preferred_language)
            if $author && $author->preferred_language;

	my $blog = MT::Blog->load($entry->blog_id);
        if ($author && $author->email) {
            my %head = ( To => $author->email,
                         From => $author->email,
                         Subject =>
			 '[' . $blog->name . '] ' .
			 $app->translate("IP Banned Due to Excessive Comments"));
            my $charset = $app->{cfg}->PublishCharset || 'iso-8859-1';
            $head{'Content-Type'} = qq(text/plain; charset="$charset");
            my $body = $app->translate(
'A visitor to your weblog [_1] has automatically been banned by posting more than the allowed number of comments in the last [_2] seconds. This has been done to prevent a malicious script from overwhelming your weblog with comments. The banned IP address is

    [_3]

If this was a mistake, you can unblock the IP address and allow the visitor to post again by logging in to your Movable Type installation, going to Weblog Config - IP Banning, and deleting the IP address [_4] from the list of banned addresses.', $blog->name, 10 * $app->{cfg}->ThrottleSeconds, $user_ip, $user_ip);
            require Text::Wrap;
            $Text::Wrap::cols = 72;
            $body = Text::Wrap::wrap('', '', $body);
            MT::Mail->send(\%head, $body);
	}
	return $app->handle_error($app->translate("In an effort to curb malicious comment posting by abusive users, I've enabled a feature that requires a weblog commenter to wait a short amount of time before being able to post again. Please try to post your comment again in a short while. Thanks for your patience."), "403 Throttled");
    }

    if (my $state = $q->param('comment_state')) {
        require MT::Serialize;
        my $ser = MT::Serialize->new($app->{cfg}->Serializer);
        $state = $ser->unserialize(pack 'H*', $state);
        $state = $$state;
        for my $f (keys %$state) {
            $q->param($f, $state->{$f});
        }
    }
    unless ($entry->allow_comments eq '1') {
        return $app->handle_error($app->translate(
            "Comments are not allowed on this entry."));
    }
    my $blog = jayallen::Blacklist::_getBlog($entry->blog_id);
    if (!$blog->allow_anon_comments &&
        (!$q->param('author') || !$q->param('email'))) {
        return $app->handle_error($app->translate(
            "Name and email address are required."));
    }
    if (!$q->param('text')) {
        return $app->handle_error($app->translate("Comment text is required."));
    }

### INSERTED CODE STARTS HERE ###
    if (my ($blRc,$blStr,$textStr,$blResponse) = jayallen::Blacklist::_matchBlacklist($entry->blog_id,
    					$q->param('text'), 
    					$q->param('url'), 
    					$q->param('email'), 
    					$q->param('author'))) { 
		$app->log('MT-Blacklist comment denial on '.$blog->name.": $blStr") if defined($blStr);
		if (defined($blResponse)) {
            $blResponse =~ s/__TYPE__/comment/g;
            $blResponse =~ s/__BLACKLIST__/$blStr/g if defined($blStr);
            $blResponse =~ s/__TEXT__/$textStr/g if defined($textStr);
		}
		return $app->handle_error($blResponse);
    }
### INSERTED CODE ENDS HERE ###

    my $comment = MT::Comment->new;
    $comment->ip($app->remote_ip);
    $comment->blog_id($entry->blog_id);
    $comment->entry_id($q->param('entry_id'));
    $comment->author(remove_html(scalar $q->param('author')));
    my $email = $q->param('email') || '';
    if ($email) {
        require MT::Util;
        if (my $fixed = MT::Util::is_valid_email($email)) {
            $email = $fixed;
        } else {
            return $app->handle_error($app->translate(
                "Invalid email address '[_1]'", $email));
        }
    }
    $comment->email(remove_html($email));
    my $url = $q->param('url') || '';
    if ($url) {
        require MT::Util;
        if (my $fixed = MT::Util::is_valid_url($url)) {
            $url = $fixed;
        } else {
            return $app->handle_error($app->translate(
                "Invalid URL '[_1]'", $url));
        }
    }
    $comment->url(remove_html($url));
    $comment->text($q->param('text'));
    $comment->save;
    $app->rebuild_indexes( Blog => $blog )
        or return $app->error($app->translate(
            "Rebuild failed: [_1]", $app->errstr));
    $app->rebuild_entry( Entry => $entry )
        or return $app->error($app->translate(
            "Rebuild failed: [_1]", $app->errstr));
    my $link_url;
    if (!$q->param('static')) {
        $url = $app->base . $app->uri;
        $url .= '?entry_id=' . $q->param('entry_id');
        $link_url = $url;
    } else {
        my $static = $q->param('static');
        if ($static == 1) {
            $link_url = $entry->permalink;
        } else {
            $link_url = $static . '#' . $comment->id;
        }
    }
    if ($blog->email_new_comments) {
        require MT::Mail;
        my $author = $entry->author;
        $app->set_language($author->preferred_language)
            if $author && $author->preferred_language;
        if ($author && $author->email) {
            my %head = ( To => $author->email,
                         From => $comment->email || $author->email,
                         Subject =>
                             '[' . $blog->name . '] ' .
                             $app->translate('New Comment Posted to \'[_1]\'',
                                 $entry->title)
                       );
            my $charset = $app->{cfg}->PublishCharset || 'iso-8859-1';
            $head{'Content-Type'} = qq(text/plain; charset="$charset");
            my $body = $app->translate(
                'A new comment has been posted on your blog [_1], on entry #[_2] ([_3]).',
                $blog->name, $entry->id, $entry->title);
            require Text::Wrap;
            $Text::Wrap::cols = 72;
            $body = Text::Wrap::wrap('', '', $body) . "\n$link_url\n\n" .
              $app->translate('IP Address:') . ' ' . $comment->ip . "\n" .
              $app->translate('Name:') . ' ' . $comment->author . "\n" .
              $app->translate('Email Address:') . ' ' . $comment->email . "\n" .
              $app->translate('URL:') . ' ' . $comment->url . "\n\n" .
              $app->translate('Comments:') . "\n\n" . $comment->text . "\n";

### INSERTED CODE STARTS HERE ###
              my $comment_view_url = $app->base.$app->path.'mt-blacklist.cgi?__mode=despam&_type=comment&id='.$comment->id;
              $body .= "\n\n----------------------\nDe-spam using MT-Blacklist:\n". $comment_view_url. "\n\n";
### INSERTED CODE ENDS HERE ###

            MT::Mail->send(\%head, $body);
        }
    }
    return $app->redirect($link_url);
}




1;















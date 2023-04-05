# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: Comments.pm,v 1.23.2.3.2.1 2004/01/15 20:36:13 btrott Exp $

package MT::App::Comments;
use strict;

use MT::Comment;
use MT::Util qw( remove_html encode_html );
use MT::App;
@MT::App::Comments::ISA = qw( MT::App );

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(
        preview => \&preview,
        post => \&post,
        view => \&view,
	red => \&do_red,
    );
    $app->{default_mode} = 'view';
    $app->{charset} = $app->{cfg}->PublishCharset;
    my $q = $app->{query};

    ## We don't really have a __mode parameter, because we have to
    ## use named submit buttons for Preview and Post. So we hack it.
    if ($q->param('post')) {
        $q->param('__mode', 'post');
    } elsif ($q->param('preview')) {
        $q->param('__mode', 'preview');
    }
    $app;
}

sub do_red {
    my $app = shift;
    my $q = $app->{query};
    my $id = $q->param('id') or return $app->error("No id");
    my $comment = MT::Comment->load($id)
        or return $app->error("No such comment");
    my $uri = encode_html($comment->url);
    return <<HTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html><head><title>Redirecting...</title>
<meta name="robots" content="noindex, nofollow">
<script type="text/javascript">
window.onload = function() { document.location = document.links[0].href; };
</script></head>
<body>
<p><a href="$uri">Click here</a> if you are not redirected</p>
</body>
</html>
HTML
}

sub post {
    my $app = shift;
    my $q = $app->{query};

    my $entry_id = $q->param('entry_id')
        or return $app->error("No entry_id");
    require MT::Entry;
    my $entry = MT::Entry->load($entry_id)
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
    require MT::Blog;
    my $blog = MT::Blog->load($entry->blog_id);
    if (!$blog->allow_anon_comments &&
        (!$q->param('author') || !$q->param('email'))) {
        return $app->handle_error($app->translate(
            "Name and email address are required."));
    }
    if (!$q->param('text')) {
        return $app->handle_error($app->translate("Comment text is required."));
    }
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
            MT::Mail->send(\%head, $body);
        }
    }
    return $app->redirect($link_url);
}

sub preview { do_preview($_[0], $_[0]->{query}) }

sub view {
    my $app = shift;
    my $q = $app->{query};
    require MT::Template;
    require MT::Template::Context;
    require MT::Entry;
    my $entry_id = $q->param('entry_id')
        or return $app->error("No entry_id");
    my $entry = MT::Entry->load($entry_id)
        or return $app->error($app->translate(
            "Invalid entry ID '[_1]'", $entry_id));
    my $ctx = MT::Template::Context->new;
    $ctx->stash('entry', $entry);
    $ctx->{current_timestamp} = $entry->created_on;
    my %cond = (
        EntryIfExtended => $entry->text_more ? 1 : 0,
        EntryIfAllowComments => $entry->allow_comments,
        EntryIfCommentsOpen => $entry->allow_comments eq '1',
        EntryIfAllowPings => $entry->allow_pings,
    );
    my $tmpl = MT::Template->load({ type => 'comments',
                                    blog_id => $entry->blog_id })
        or return $app->error($app->translate(
            "You must define a Comment Listing template in order to " .
            "display dynamic comments."));
    my $html = $tmpl->build($ctx, \%cond);
    $html = MT::Util::encode_html($tmpl->errstr) unless defined $html;
    $html;
}

sub handle_error {
    my $app = shift;
    my($err, $status_line) = @_;
    my $html = do_preview($app, $app->{query}, $err);
    $app->{status_line} = $status_line;
    $html;
}

sub do_preview {
    my($app, $q, $err) = @_;
    require MT::Template;
    require MT::Template::Context;
    require MT::Entry;
    require MT::Util;
    require MT::Comment;
    my $entry_id = $q->param('entry_id');
    my $entry = MT::Entry->load($entry_id);
    my $ctx = MT::Template::Context->new;
    my $comment = MT::Comment->new;
    $comment->blog_id($entry->blog_id);
    for my $f (qw( entry_id author email url text )) {
        $comment->$f(scalar $q->param($f));
    }
    $comment->ip($app->remote_ip);
    ## Set timestamp as we would usually do in ObjectDriver.
    my @ts = MT::Util::offset_time_list(time, $entry->blog_id);
    my $ts = sprintf "%04d%02d%02d%02d%02d%02d",
        $ts[5]+1900, $ts[4]+1, @ts[3,2,1,0];
    $comment->created_on($ts);
    $ctx->stash('comment_preview', $comment);
    unless ($err) {
        ## Serialize comment state, then hex-encode it.
        require MT::Serialize;
        my $ser = MT::Serialize->new($app->{cfg}->Serializer);
        my $state = $comment->column_values;
        $state->{static} = $q->param('static');
        $ctx->stash('comment_state', unpack 'H*', $ser->serialize(\$state));
    }
    $ctx->stash('comment_is_static', $q->param('static'));
    $ctx->stash('entry', $entry);
    $ctx->{current_timestamp} = $ts;
    my($tmpl);
    if ($err) {
        $ctx->stash('error_message', $err);
        $tmpl = MT::Template->load({ type => 'comment_error',
                                     blog_id => $entry->blog_id })
        or return $app->error($app->translate(
            "You must define a Comment Error template."));
    } else {
        $tmpl = MT::Template->load({ type => 'comment_preview',
                                     blog_id => $entry->blog_id })
        or return $app->error($app->translate(
            "You must define a Comment Preview template."));
    }
    my $html = $tmpl->build($ctx);
    $html = $tmpl->errstr unless defined $html;
    $html;
}

1;

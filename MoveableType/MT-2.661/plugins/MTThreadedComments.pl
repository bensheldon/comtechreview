# MTThreadedComments 0.1.1 ($Date: 2003/02/19 17:18:16 $)
# by Alexei Kosut <akosut@cs.stanford.edu>

use MT 2.6;
use MT::Template::Context;
use MT::Comment;

use strict;
use warnings;

sub comment_subject ($) {
    my $ctx = shift;
    my $comment = $ctx->stash('comment')
	or return $ctx->error("Tag called without a comment in context");

    return $comment->subject;
}

MT::Template::Context->add_conditional_tag(IfCommentSubject => sub {
    return comment_subject(shift);
});

MT::Template::Context->add_conditional_tag(UnlessCommentSubject => sub {
    return not comment_subject(shift);
});

MT::Template::Context->add_tag(CommentSubject => sub {
    MT::Template::Context::sanitize_on($_[1]);
    return comment_subject(shift) || "";
});

MT::Template::Context->add_tag(CommentResponseSubject => sub {
    MT::Template::Context::sanitize_on($_[1]);
    my $comment = $_[0]->stash('comment')
	or return $_[0]->_no_comment_error('MTCommentResponseSubject');
    
    if (my $subject = $comment->subject) {
	return ($subject =~ /^re\W/i) ? $subject : "Re: $subject";
    }

    return "Re: " . MT::Entry->load($comment->entry_id)->title;
});

MT::Template::Context->add_tag(CommentPreviewSubject => sub {
    MT::Template::Context::sanitize_on($_[1]);

    my $ctx = shift;
    my $comment = $ctx->stash('comment_preview')
	or return $ctx->error("Tag called without a comment preview in context");

    return $comment->subject || "";
});


sub comment_parent_id ($) {
    my $ctx = shift;
    if ($ctx->stash('tag') =~ /Preview/) {
	return $ctx->stash('comment_preview')
	    ? $ctx->stash('comment_preview')->parent_id
	    : $ctx->stash('comment_parent_id');
    } else {
	return $ctx->stash('comment')
	    ? $ctx->stash('comment')->parent_id : undef;
    }    
}

sub comment_parent_handler {
    my $ctx = shift;
    my $id = comment_parent_id($ctx)
	or return $ctx->error('Tag called with no comment parent in context');
    my $comment = MT::Comment->load($id);
    
    my $builder = $ctx->stash('builder');

    local $ctx->{__stash}{comment} = $comment;
    local $ctx->{current_timestamp} = $comment->created_on;
    my $out = $builder->build($ctx, $ctx->stash('tokens'));
    return $ctx->error($builder->errstr) unless defined $out;

    $out;
}

MT::Template::Context->add_container_tag(CommentPreviewParent
					 => \&comment_parent_handler);
MT::Template::Context->add_container_tag(CommentParent
					 => \&comment_parent_handler);

MT::Template::Context->add_conditional_tag(CommentPreviewIfParent => sub {
    return comment_parent_id(shift);
});

MT::Template::Context->add_conditional_tag(CommentPreviewUnlessParent => sub {
    return not comment_parent_id(shift);
});

MT::Template::Context->add_tag(CommentPreviewParentID => sub {
    return comment_parent_id(shift) || 0;
});

MT::Template::Context->add_conditional_tag(CommentUnlessParent => sub {
    return not comment_parent_id(shift);
});

MT::Template::Context->add_conditional_tag(CommentIfParent => sub {
    return comment_parent_id(shift);
});

MT::Template::Context->add_tag(CommentParentID => sub {
    return comment_parent_id(shift) || 0;
});

sub get_comments($$$) { 
    my ($ctx, $entry, $parent_id) = @_;
  
    # Load comments that do not have a parent.  Note that we
    # scan through the comments rather than querying the database
    # directly.  This is because the comemnts are already cached in
    # memory, and we will probably have to do this a lot, and DB
    # access is slow and there aren't that many comments, etc...
    #
    # (Also because root comments could have an id of either
    # undef or 0, so we'd have to query twice).
    my @comments = sort { $a->created_on <=> $b->created_on }
                        grep { $parent_id
				   ? ($_->parent_id
				      && $_->parent_id == $parent_id)
				   : not $_->parent_id } @{$entry->comments};

    # Note that we do not set comment_order_num, because it is not
    # often used, and it is hard to keep track of with nested
    # comments.

    my $res = '';
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    for my $c (@comments) {
	local $ctx->{__stash}{comment} = $c;

	local $ctx->{current_timestamp} = $c->created_on;
        my $out = $builder->build($ctx, $tokens);
        return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $out;
    }

    $res;
}

MT::Template::Context->add_container_tag(RootComments => sub {	
    my $ctx = shift;
    my $entry = $ctx->stash('entry')
	or return $ctx->_no_entry_error('MTRootComments');

    return get_comments($ctx, $entry, undef);
});

MT::Template::Context->add_container_tag(CommentChildren => sub {	
    my $ctx = shift;
    my $comment = $ctx->stash('comment')
	or return $ctx->_no_comment_error('MTCommentChildren');

    return get_comments($ctx, $ctx->stash('entry')
			|| MT::Entry->load($comment->entry_id), $comment->id);
});

MT::Template::Context->add_conditional_tag(CommentIfChildren => sub {
    my $ctx = shift;
    my $comment = $ctx->stash('comment')
	or return $ctx->_no_comment_error('MTCommentIfChildren');
   
    return MT::Comment->count({ parent_id => $comment->id });
});

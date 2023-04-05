#!/usr/bin/perl -w

# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: mt-send-entry.cgi,v 1.3.2.1.4.1 2004/01/14 22:02:54 btrott Exp $
use strict;

my($MT_DIR);
BEGIN {
    if ($0 =~ m!(.*[/\\])!) {
        $MT_DIR = $1;
    } else {
        $MT_DIR = './';
    }
    unshift @INC, $MT_DIR . 'lib';
    unshift @INC, $MT_DIR . 'extlib';
}

eval {
    require CGI;
    require MT::Mail;
    require MT::Entry;
    require MT::Blog;
    require MT;
    require MT::Util;

    my $mt = MT->new( Config => $MT_DIR . 'mt.cfg', Directory => $MT_DIR )
        or die MT->errstr;
    my $q = CGI->new;

    my $to = $q->param('to');
    my $from = $q->param('from');
    my $entry_id = $q->param('entry_id');
    my $redirect = $q->param('_redirect');
    my $msg = $q->param('message') || '';

    unless ($to && $from && $entry_id && $redirect) {
        die "Missing required parameters\n";
    }

    for ($to, $from) {
        unless ($_ = MT::Util::is_valid_email($_)) {
            die "Invalid email address";
        }
        my $cnt = $_ =~ tr/@/@/;
        die "Invalid email address" if $cnt != 1;
        die "Invalid email address" if /[\r\n,]/;
    }
    die "Message is too long"
        if length($msg) > 250;

    my $entry = MT::Entry->load($entry_id)
        or die "Invalid entry ID '$entry_id'";
    my $blog = MT::Blog->load($entry->blog_id);

    my $link = $blog->archive_url;
    $link .= '/' unless $link =~ m!/$!;
    $link .= $entry->archive_file;

    my $body = <<BODY;
$from has sent you a link!

$msg

Title: @{[ $entry->title ]}
Link: $link
BODY
    my %head = ( To => $to, From => $from,
                 Subject => '[' . $blog->name . '] Recommendation: ' .
                            $entry->title );

    MT::Mail->send(\%head, $body)
        or die "Error sending mail: ", MT::Mail->errstr;

    print $q->redirect($redirect);
};
if ($@) {
    print "Content-Type: text/html\n\n";
    print "Got an error: $@";
}

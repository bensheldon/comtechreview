#!/usr/bin/perl -w
#
# mt-rebuild
#
# Copyright 2003 Timothy Appnel. (tima@mplode.com)
# This code is released under the Artistic License.

use strict;
use Getopt::Long;

use vars qw( $VERSION );
$VERSION = '0.2';

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

use MT;

my $mt = MT->new(Config => $MT_DIR . 'mt.cfg',
                Directory => $MT_DIR) || die MT->errstr;

my $help_msg = <<HELP_MSG
mt-rebuild Usage: 

mt-rebuild.pl -mode="(all|archive|entry|index)" -blog_id=0 
[-archive_type="(Individual|Daily|Weekly|Monthly|Category)" -no_indexes 
 -entry_id=0 -build_dependencies
 -template="your template name" -force ]
 
OR 

mt-rebuild.pl -all [-no_indexes]
 
See the POD documentation embedded in this script for more detail.
HELP_MSG
;

my ($all, $mode, $blog_id, $archive_type, $entry_id, $template_name); #text and integer arguements
my ($help, $no_indexes, $build_dependencies, $force)=(0,0,0,0); # flag/boolean switches

# assign command line arguements to variables.
GetOptions ('all' => \$all,
			'help' => \$help,
			'mode=s' => \$mode,
			'blog_id=i' => \$blog_id, 
			'archive_type=s' => \$archive_type, 
			'no_indexes' => \$no_indexes,
			'entry_id=i' => \$entry_id,
			'build_dependencies' => \$build_dependencies,
			'template=s' => \$template_name,
			'force' => \$force
			);
if ( defined($all) ) {
	require MT::Blog;
    my $iter = MT::Blog->load_iter;
    while (my $blog = $iter->()) {
		$mt->rebuild( BlogID => $blog->id, NoIndexes => $no_indexes ) || 
			die "Blog ID: ".$blog->id."\nRebuild error: ", $mt->errstr; 
    }
} elsif ($help || ! ( defined( $mode ) && defined( $blog_id ) ) ) {
	print "$help_msg\n";
} elsif ($mode eq 'all') {
	$mt->rebuild( BlogID => $blog_id, NoIndexes => $no_indexes ) || 
		die "Rebuild error: ", $mt->errstr; 
} elsif ($mode eq 'archive') {
	if (! defined( $archive_type ) ) {
		die "Rebuild Error: -archive_type is required in '$mode' mode."
	} elsif ( ! $archive_type=~m/(Individual|Daily|Weekly|Monthly|Category)/ ) { 
		die "Rebuild Error: $archive_type is an illegal value for -archive_type. Use one of the following 
			case-sensitive values: Individual, Daily, Weekly, Monthly, or Category."; 
	}
	$mt->rebuild( BlogID => $blog_id, ArchiveType => $archive_type, NoIndexes => $no_indexes ) || 
		die "Rebuild error: ", $mt->errstr; 
} elsif ($mode eq 'entry') {
	if (! defined($entry_id)) { die "Rebuild error: -entry_id is required in '$mode' mode."; }
	require MT::Entry;
	my $entry = MT::Entry->load($entry_id)
		|| die "Rebuild Error: Can't load entry ".$entry_id;
	if ($entry->blog_id != $blog_id) { 
		die "Rebuild Error: Entry ".$entry_id." is not in the specified weblog.";
	}
	$mt->rebuild_entry( Entry => $entry, BuildDependencies => $build_dependencies)
		|| die "Rebuild error: ". $mt->errstr; 
} elsif ($mode eq 'index') {
	if (! defined($template_name)) { die "Rebuild error: -template is required in '$mode' mode."; }
	require MT::Template;
	my $template = MT::Template->load({ name => $template_name, blog_id => $blog_id })
		|| die "Rebuild Error: Can't load template ".$template_name." in blog_id of ".$blog_id;
	$mt->rebuild_indexes( BlogID => $blog_id, Template => $template, Force => 1 )
		|| die "Rebuild error: ", $mt->errstr; 
} else { print "Rebuild error: '$mode' is not a valid mode.\n"; }

1;

__END__

=head1 NAME

mt-rebuild - A utility script for rebuilding a MovableType weblogs from the command-line or F<cron>.

=head1 SYNOPSIS

	# To rebuild all weblogs in the system.
	mt-rebuild -all

	# To rebuild an entire weblog:
	mt-rebuild -mode="all" -blog_id=0

	# To rebuild all archives, but not index templates:
	mt-rebuild -mode="all" -blog_id=0 -no_indexes

	# To rebuild a weblog archive type:
	mt-rebuild -mode="archive" -blog_id=0 -archive_type="(Individual|Daily|Weekly|Monthly|Category)"

	# To rebuild a specific weblog entry:
	mt-rebuild -mode="entry" -blog_id="0" -entry_id=0

	# To rebuild a specific weblog index template:
	mt-rebuild -mode="index" -blog_id="0" -template="your template name"

=head1 DESCRIPTION

mt-rebuild.pl is a utility script for rebuilding a MovableType template from the command-line
as opposed to the standard MT browser interface. This is particularly helpful when combined 
with F<cron> to automatically update a part of your site on a regular basis. An example would 
be the updating of syndicated content feeds using the mt-rssfeed plugin.

This script depreciates its more limited predecessor mt-rebuild-index.

=head1 INSTALLATION

To install mt-rebuild, place the script on in the main directory where MovableType
has been installed. Read, Write and Execute permissions should only be assigned to the 
owner (you) with C<chmod mt-rebuild-index.pl 700>. 

=head1 LICENSE

The software is released under the Artistic License. The terms of the Artistic License are 
described at http://www.perl.com/language/misc/Artistic.html.

=cut
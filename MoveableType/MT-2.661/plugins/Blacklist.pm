# Title:	MT-Blacklist
# Summary:	A plugin for preventing comment and Trackback spam 
# Author:	Jay Allen (http://www.jayallen.org/)
# Version:	1.6.5
# Date:		Aug 4, 2004
#
# Information about this plugin can be found at
# http://www.jayallen.org/projects/mt-blacklist
#
# Until I get some sleep and can think about licenses:
# Copyright 2003 Jay Allen
# This code cannot be redistributed without
# permission from the author. 

package jayallen::Blacklist;
use vars qw($VERSION $_cache @_warnings $blacklist_config_directory);
$VERSION = '1.6.5';

require 5.005;
 
####################################################################
#
# PATH TO FILESYSTEM-BASED BLACKLIST CONFIGURATION
#
# The following configuration option should only be uncommented 
# if you want to use a filesystem-based configuration and
# blacklist instead of one stored in your database.
#
# This is particularly useful for those who do not have the
# Storable perl module installed or anyone who seems to be having 
# problems storing data in a database.
#
# Below, please input the full path to the directory where you 
# would like to store your data.  The directory should be world-
# writeable and world-readable (Permissions: 777 or -rwxrwxrwx) 
# UNLESS you know you can use more strict permissions (due to suexec 
# or cgi-wrap).  The directory should NOT be located within your 
# public website directory hierarchy.
# 
# SUGGESTED LOCATION: mt/extlib/jayallen/Blacklist_Config
#
# $blacklist_config_directory = '/path/to/extlib/jayallen/Blacklist_Config/';
#
####################################################################




# CACHE OBJECT REFERENCE
#
# $_cache->{blacklist} - reference to an array of objects
# $_cache->{blog}} - reference to a hash of blog_id -> blog object
# $_cache->{blogs_loaded} - scalar boolean indicating a full load of blogs
# $_cache->{config} - reference to a hash of config_key = config_value
# $_cache->{entry} - reference to a hash of entry_id -> entry object
# $_cache->{pattern} -  scalar string containing all blacklisted terms
# $_cache->{perms}->{blog} - reference to hash of blog permission objects
# $_cache->{perms}->{blog}{$b_id} - reference to specific blog permission object
# $_cache->{perms}->{canEditAllEntries}{$b_id} - scalar boolean indicating blog/user permission
# $_cache->{perms}->{canEditEntry}{$e->id} 
# $_cache->{plugindataobject}


# CHANGES SINCE LAST PUBLIC VERSION
#
#	Added arbitrary text/regexp to despam search
#	Added NO FILTER to despam search to get LastN comments/trackbacks


use MT::App;
@ISA = qw( MT::App );
use strict;

sub init {
    my $app = shift;
    $app->SUPER::init (@_) or return;
    $app->add_methods (
        'default'	=> \&default,
        'restore'	=> \&restore,
        'add'	=> \&add,
        'remove'	=> \&remove,
        'remove_all'	=> \&remove_all,
        'view'	=> \&view,
        'editentry'	=> \&editentry,
        'quickadd'	=> \&quickadd,
        'quickdelete'	=> \&quickdelete,
        'add'	=> \&add,
        'add_confirm'	=> \&add_confirm,
        'publish'	=> \&publish,
        'config'	=> \&config,
        'search'	=> \&search,
        'despam'	=> \&despam,
        'despam_multi'	=> \&despam_multi,
        'despam_confirm'	=> \&despam_confirm,
        'debug'	=> \&debug_app,
        'permdebug'	=> \&debug_perms,
    );
    $app->{default_mode} = 'default';
    $app->{requires_login} = 1;
    $app->{user_class} = 'MT::Author';
    $app->{template_dir} = 'cms';

	if ($_cache->{config} = _getConfig()) {
		$app->_versionCheck();
	} else {
		#First use -- INSTALL
		$app->restore(1);
	}
	
	$_cache->{blacklist} = _getBlacklist();
	
	
	$app->_debug_status($app->{'query'}->param('debug') || 0);
	$app->{dumpwarnings} = ($app->{'query'}->param('db') || 0);

	# Uncomment the following line to enable 
	# persistent debugging.  Alternatively, 
	# for page by page debugging, you can add 
	# debug=1 parameter to the URL of any page.
	#
	# $app->_debug_status(1);

      $app;
}

sub default {

	my $app = shift;
	my $q = $app->{query};

	my ($sort_col,$custom_sort_field);
	if ($sort_col = $q->param('sort')) {
		$custom_sort_field++;
	} else {
		$sort_col ||= 'string';
	}
	
	
    my $html = $app->_navigation_html('Killing Blog Spam Dead','listpage');

	# QUICK ADD FORM
    $html .= $q->start_form('get',$app->uri);
    $html .= $q->p($q->hidden('__mode', 'quickadd'),"Quick Add: ".$q->textfield(-class=>'text', -name => 'string', -size => 30). $q->submit(-name => '', -value => 'Add').$q->br.'<span class="description">NOTE: Comments are not allowed using quick add</span>');
    $html .= $q->end_form;


    my %messages = (
        'added' => sub { local $_ = shift;
                        $q->p({-class=>'msg_success'},
                            'Your entry was sucessfully entered and is highlighted below.')
                        },
        'dupe' => sub { local $_ = shift;
                        $q->p({-class=>'msg_warning'},
                            'Your entry was not added because it was either a duplicate of or masked by the highlighted entry below.')
                        },
        'notadded' => sub { local $_ = shift;
                        $q->p({-class=>'msg_failure'},
                            'Your entry could not be added because of an unknown error.')
                        },
        'removed' => sub { local $_ = shift;
                        $q->p({-class=>'msg_success'},
                            'The entry "'.$q->param('rmstring').'" was removed from the blacklist.')
                        },
        'notremoved' => sub { local $_ = shift;
                        $q->p({-class=>'msg_failure'},
                            'The entry "'.$q->param('rmstring').'" could not be removed because of an unknown error.')
                        },
        'quickdeleted' => sub { local $_ = shift;
                        $q->p({-class=>'msg_success'},
                            'You successfully deleted '.$q->param('num').' entries.')
                        },
        'notquickdeleted' => sub { local $_ = shift;
                        $q->p({-class=>'msg_warning'},
                            'No entries were deleted.')
                        },
        'DEFAULT' => sub { }
    );

	$html .= &{$messages{($q->param('msg') || 'DEFAULT')}}($q) || '';

    #
    # BLACKLIST FRAGMENT OVERVIEW TABLE
    #
    shift(@{$_cache->{blacklist}});
	unless (@{ $_cache->{blacklist} }) {
		$html .= $q->p($q->strong('No entries in blacklist.'));
		$html .= $q->p({-style => 'text-align:left'}, 'Make sure to grab the latest <a href="http://www.jayallen.org/comment_spam/blacklist.txt">banned spam list</a> from the <a href="http://www.jayallen.org/comment_spam/">MT-Blacklist Comment Spam Clearinghouse</a>.').
			$q->p({-style => 'text-align:left'}, 'Simply copy and paste the entire file into your text box on the <a href="'.$app->uri.'?__mode=add" title="MT-Blacklist Add screen">Add screen</a> and you will be fully protected against all currently known spammers.').
			$q->p({-style => 'text-align:left'}, 'Until MT-Blacklist\'s peer-to-peer distributed blacklist functionality is released, the best way to keep updated is to subscribe to the <a href="http://www.jayallen.org/comment_spam/">Clearinghouse RSS feeds</a>.');
 		return $html;
	}		


	my $i = 0;
	my $sort_dir = $q->param('dir') || 'default';
	my @blacklist = map { $_->{'index'} = $i++; $_ } @{ $_cache->{blacklist} };
	if ($sort_col ne 'string') {
		$sort_col = $q->param('sort') || 'string'; # what about bad input?
		@blacklist = sort { $a->{$sort_col} cmp $b->{$sort_col} } @blacklist;
		@blacklist = reverse @blacklist 
			if $sort_dir eq 'reverse';
	} 


    $html .= $q->start_form('get',$app->uri);

    my @sortbar = (
        {
            'display' => 'URL',
            'link' => $app->uri
        },
        {
            'display' => 'Comments',
            'link' => $app->uri.'?sort=comment'
        },
        {
            'display' => 'Date Added',
            'link' => $app->uri.'?sort=dateAdded'
        },
        {
            'display' => 'Date modified',
            'link' => $app->uri.'?sort=dateModified'
        },
        {
            'display' => 'Added by',
            'link' => $app->uri.'?sort=addedBy'
        },
        {
            'display' => 'Modified by',
            'link' => $app->uri.'?sort=lastModifiedBy'
        }
	);


	my $sort_by .= 'Sort by: '. 
		join(' | ', 
			map { '<a href="'.$_->{'link'}.'">'.$_->{'display'}.'</a>' } 
			@sortbar);


    $html .= $q->p($q->hidden('__mode'),
        'There are '.scalar(@blacklist).' entries in your blacklist.'.$q->br.
        $sort_by );

	if ($sort_dir eq 'reverse') {
		$q->delete('dir');
	} else {
		$q->param('dir', 'reverse');
	}
    my @headings = ('URL Fragment','','',
    		'<a href="'.$q->self_url.'">'.
    		($custom_sort_field ? ucfirst($sort_col) : 'Comment').
    		'</a>','Delete');

    $q->param('__mode', 'quickdelete');
    my @rows = $q->th(\@headings);
    $i = 0;
    my $highlight = defined($q->param('highlight')) ? $q->param('highlight')-1 : -1;
    use MT::Util;
    for ($i=0;$i<scalar(@blacklist);$i++) {

        local $_ = $blacklist[$i];
        my @data = [
            $app->_stringBreak($_->{'string'},45),
#            '<a href="?__mode=view&amp;id='.($i+1).'">info</a>',
            '<a href="?__mode=view&amp;string='.MT::Util::encode_url($_->{'string'}).'">info</a>',
            $q->a({-href=>'?__mode=remove&string='.
                MT::Util::encode_url($_->{'string'})},'remove'),
            ($custom_sort_field ? $_->{$sort_col} : $_->{'comment'}),
            $q->checkbox(-name=>'deleteEntry',
                       -value=>$_->{'string'},
                       -label=>'') ];
            
        if ($highlight == ($i+1)) {
            unshift(@data, {-class=>'highlight'});
        } 
        push(@rows,$q->td(@data));
    }


    push(@rows, $q->td({-colspan=>5,-class=>'right noline'},$q->hidden('__mode'),$q->submit(-name=>'',-value=>'Delete checked entries')));
    $html .= $q->table($q->Tr(\@rows) ); 
    
    $html .= $q->end_form;
	

	if (@blacklist > 20) {	
        # Quick add form
        $html .= $q->start_form('get',$app->uri);
        $q->param('__mode', 'quickadd');
        $html .= $q->p($q->hidden('__mode'),
        	"Quick Add: ".$q->textfield(-class=>'text', -name => 'string', -size => 30). $q->submit(-name => '', -value => 'Add').$q->br.'<span class="description">NOTE: Comments are not allowed using quick add</span>');
        $html .= $q->end_form;
	}

	$html .= $app->_debug(@blacklist);

	$html;

}


sub quickadd {  

	my $app = shift;
	my $q = $app->{query};

	if ($q->param('string') ne '') {
        my $struct = $app->_prepareBlacklistEntry({'string' => $q->param('string')});
        my ($rc,$pos) = $app->_masterAdd($struct);
 
        if ($rc) {
            $app->redirect ($app->uri.'?msg=added&highlight='.$pos);
        } elsif ($pos) {
            $app->redirect ($app->uri.'?msg=dupe&highlight='.($pos+1));
        } elsif ($app->errstr ne '') {
        	# JAYBO - should return proper error string by url encoding error
            die $app->errstr;
        } else {
            $app->redirect ($app->uri.'?msg=notadded&string='.$struct->{'string'});
        }
	} else {
		$app->redirect ($app->uri);
	}
	

}


sub quickdelete {  

# get the blacklist
# make sure the entry isnt on the blacklist
# eval  the entry
#add the entry to the blacklist array
# save the blacklist
# send the user back to view (with entry highlighted)

	my $app = shift;
	my $q = $app->{query};
	my @delete_strings = $q->param('deleteEntry');

	my $rc = $app->_rmFromBlacklist(@delete_strings);

	return $rc ? 
	$app->redirect($app->uri.'?msg=quickdeleted&num='.$rc) :
		$app->redirect($app->uri.'?msg=notquickdeleted');
	
	my @pared_blacklist;
	foreach my $entry (@{ $_cache->{blacklist} }) {
		my $found = 0;
		foreach my $delete (@delete_strings) {
			next unless $delete eq $entry->{'string'};
			$found++;
			last;
		}
		push(@pared_blacklist,$entry) unless $found;
	}

	if ($app->_saveBlacklist(\@pared_blacklist)) {
		$app->redirect($app->uri.'?msg=quickdeleted&num='.
			(scalar(@{ $_cache->{blacklist} })-scalar(@pared_blacklist)).
				'&tot='.scalar(@delete_strings));
	} else {
		$app->redirect($app->uri.'?msg=notquickdeleted');
	}

			
}


sub remove { 

	my $app = shift;
	my $q = $app->{query};
	
	my $str = $q->param('string');
	
	$app->redirect($app->uri) unless $str ne '';
	
	my $rc = $app->_rmFromBlacklist($str);
	
	if ($rc) {
		$app->redirect($app->uri.'?msg=removed&rmstring='.$str);
	} else {
		$app->redirect($app->uri.'?msg=notremoved&rmstring='.$str);
	}
}


sub view { 

	my $app = shift;
	my $q = $app->{query};
	my ($string,$id) = '';
	$string = $q->param('string');
	if ($string and $string ne '') {
		$id = $app->_findBlacklistIndex($string);
	} else {
		$id = $q->param('id') unless $string;
	}

	my ($blEntry,$numEntries) = $app->_getBlacklistEntry($id);

    my $html = $app->_navigation_html('Killing Blog Spam Dead','viewpage');
	my $prev = $id > 1 ?
		'<a href="?__mode=view&id='.($id-1).'">&laquo; previous</a>' :
		''; 
	my $next = ($id < ($numEntries-1)) ? 
		'<a href="?__mode=view&id='.($id+1).'">next &raquo;</a>' :
		'';

    $html .= $q->table(
            $q->Tr({-align=>'left',-valign=>'top'},
            [
     			$q->th({-class=>'prevlink'},$prev).
     			$q->th({-class=>'nextlink'},$next),          $q->th({-colspan=>2,-class=>'entryString'},$blEntry->{'string'}),
               $q->th('Comment').$q->td($blEntry->{'comment'}),
               $q->th('Added by').$q->td($blEntry->{'addedBy'}.' at '.MT::Util::format_ts("%Y/%m/%d %H:%M:%S",$blEntry->{'dateAdded'})),
               $q->th('Last modified by').$q->td($blEntry->{'lastModifiedBy'}.' at '.MT::Util::format_ts("%Y/%m/%d %H:%M:%S",$blEntry->{'dateModified'})),
            ]
          )
    )."\n\n"; 

	# Comment editing form
    $html .= $q->start_form('post',$app->uri);
	$q->param('__mode','editentry');
    $html .= $q->p(
		$q->hidden(-name=>'__mode'),
		$q->hidden(-name=>'id'),
		$q->hidden('string',$blEntry->{'string'}),
		$q->strong("Edit comment: ").$q->br.
		'<textarea name="comment" rows="5" cols="40" class="text">'.$blEntry->{'comment'}.'</textarea>'.
		$q->submit(-name => '', -value => 'Submit')
	);
    $html .= $q->end_form;

	$html .= $app->_debug($blEntry);
	$html;
}


sub editentry {

	my $app = shift;
	my $q = $app->{query};

	my $id = $app->_findBlacklistIndex($q->param('string'));
	
	if (defined($id)) {

		$_cache->{blacklist}->[$id]->{'comment'} = $q->param('comment');
		$_cache->{blacklist}->[$id]->{'comment'} =~ s#[\n\r]+# #g;
		$_cache->{blacklist}->[$id]->{'dateModified'} = _getTimestamp();
		$_cache->{blacklist}->[$id]->{'lastModifiedBy'} = $app->{user}->name.' (ID: '.$app->{user}->id.')';
        $app->_saveBlacklist();
		$app->redirect($app->uri.'?__mode=view&id='.$id);

	} else {
		return $q->div({-class=>'msg_failure'}.
			$q->p("There was an error saving your information: Blacklist entry ID not found"));
	}
}


sub add {

	my $app = shift;
	my $q = $app->{query};
	my @urls = $q->param('url');
	
	
    my $html = $app->_navigation_html('Add Entries to Blacklist', 'addpage');

    $html .= $q->p('Using the form below, you can import one or many entries into the system. ',
    			$q->a({-href=>$q->self_url.'#format', -class=>'helplink'},'[?]'),
    			'Be sure to check the <a href="http://www.jayallen.org/comment_spam/blacklist.txt">updated list</a> at the <a href="http://www.jayallen.org/comment_spam/">Centralized MT-Blacklist Clearinghouse</a> for the best protection.'
    			);


	# Blacklist importing textarea
	$q->param('__mode','add_confirm');
    $html .= $q->start_form('post',$app->uri);
    $html .= $q->p(
		$q->hidden(-name=>'__mode'),
		$q->strong("Import blacklist: ").$q->br.
		'<textarea name="entryimport" rows="20" cols="80" class="text">'.
		(@urls ? join("\n", @urls) : '').
		'</textarea>'.$q->br. 
		$q->submit(-name => '', -value => 'Import entries')
	);
    $html .= $q->end_form;
	
	my @rules = (
        'One entry per line. ',
        'Whitespace will be trimmed.',
        'Everything on a line after a # is saved in the comment field for that entry.',
        'Blank lines and those with only comments are ignored.',
        'All "http://" and leading "www." strings will be stripped from the entries.',
		'Also, it\'s best to omit anything after the domain name (i.e. directory path) unless it is important.',
        'String matching is case-insensitive',
        'Perl regular expressions are allowed but optional (as always)'
	);
	$html .= $q->h2({-id=>'format'},'Entry format:').$q->ul($q->li(\@rules));
	

	my $example_entry =<<'EOD';
# This line will be ignored.
    # So will this one
commentspammer.com		# This text will be the comment for the URL to the left
testdomain1.com  testdomain2.com # This ENTIRE LINE will be ignored

# Both this line and the blank lines above and below it are ignored

# The entry below will block all trackbacks/comments 
# with the <strong>word</strong> viagra in any of 
# the input fields (hint: that's probably not what 
# you want...)
viagra

# So will this one but it will be slower
.+viagra.+

# The super-regex below will block any domain name with
# lolita, phentermine, viagra, virgx, or vig-rx located
# anywhere in it.
# If you find that you are blocking many entries with the
# same unique string, you should consider adding to this 
# entry.
(lolita|phentermine|viagra|vig-?rx)[\w\-_.]*\.[a-z]{2,} 

# The regex below is similar to the one above, except that
# it looks for <strong>two words</strong>: nostril and enlargement.  
(nostril)[_.\-]?enlargement([\w\-_.]+)?\.[a-z]{2,} 
EOD

	$html .= $q->h2('Example:').$q->pre($example_entry);
	$html .= $q->p('You get the idea... ');
	$html .= $app->_debug($_cache->{blacklist});

# Is applyToAllWeblogs set?
#	Yes: 
#		ENTRY 	settings	deletecheckbox
#								deletesubmitbutton
#
#	No:
#		ENTRY	settings	deletecjheckbox
#		O weblog1 O weblog2 O weblog3 O weblog4 
#								deletesubmitbutton

	$html;


}




sub add_confirm {

	my $app = shift;
	my $q = $app->{query};

    my $html = $app->_navigation_html('Import Results','addpage');

	my @new_entries;
    my $import = $q->param('entryimport');
    unless (@new_entries = $app->_diceImportFileData($import)) {

        $html .= $q->div({-class=>'msg_failure'},
            $q->p("No data could be extracted from your submission.  Please go back and check your format again."));
        return $html;
    }
    
    if (@new_entries == 1) {
		$app->{query}->param('string',$new_entries[0]{'string'});
		$app->quickadd();
	}

	# Add the unique entries to the database
	my %strings = (
					'saved' => 0,
					'dupes' => [],
					'unique' => []
				);
	($strings{'saved'}, $strings{'dupes'}, $strings{'unique'}, $strings{'invalid'},) = $app->_masterAdd(@new_entries);

	if ($strings{'dupes'} && @{$strings{'dupes'}}) {
		$html .= $q->div({-class=>'msg_warning'},
			$q->p("The following entries are either duplicates or longer versions of already existing substrings and will not be added:"),
			$q->ul($q->li($strings{'dupes'})));
	}

	if ($strings{'dupes'} && @{$strings{'dupes'}}) {
		$html .= $q->div({-class=>'msg_warning'},
			$q->p("The following entries used invalid regular expression syntax and could not be added:"),
			$q->ul($q->li($strings{'invalid'})));
	}


	return $html unless @{$strings{'unique'}};
	

	if ($strings{'saved'}) {
	
        $html .= $q->div({-class=>'msg_success'},
            $q->p("The following entries were successfully added to the blacklist:"),
            $q->ul($q->li($strings{'unique'})));
	
	} else {
	
		$html .= $q->div({-class=>'msg_failure'},
			$q->p("There was an error adding your unique entries. Please hit the BACK button and try again"));
			return $html;
	}


	$html;
}


sub publish {

	my $app = shift;
	my $q = $app->{query};
	
    for (values %{_getBlogs()}) {
		my $perms = $app->_getBlogPermissions($_->id);

		if ($perms && 
			($perms->can_create_blog || $perms->can_edit_config || 
				$perms->can_edit_templates)) { 
    		    $app->{user}->can_edit_publishloc(1);
    		    last;
		}
	}
    return $app->error("You are not authorized to publish the blacklist.") 
    	unless $app->{user}->can_edit_publishloc;


    my $html = $app->_navigation_html('Publish Blacklist','publishpage');

    $html .= $q->p('If you like, you can publish your blacklist for others to use on their systems.'.$q->br.'If you would like this to happen automatically when changes are made, you can set it up in the <a href="?__mode=config">configuration section</a>.');


	# If the form has bee submitted, process and display results
	my $blPath;
	if ($blPath = $q->param('publishLoc')) {

        $blPath =~ s!\\!/!g;   ## Change backslashes to forward slashes

		# Check for security holes and stupidity
        if (($blPath =~ m!\.\.|\0|\|!) ||
        	($blPath =~ m!\S+\s+\S+!)) {
            return $app->error($app->translate("Invalid path or filename '[_1]'", $blPath));
        }
    
        ## Untaint. We already checked for security holes in $blPath.
        ($blPath) = $blPath =~ /(.+)/s;
    
        # Write out Blacklist file    
		my ($rc,$result) = $app->_writeBlacklistFile($blPath);
        if ($rc) { 
 
            # Update MT-Blacklist config with default publishLoc
            if ($blPath ne $_cache->{config}->{'publishLoc'}) {
                $_cache->{config}->{'publishLoc'} = $blPath;
                $app->_saveConfig();
            }
        	$html .= $q->p({-class=>'msg_success'},"Your blacklist file was successfully published.");
        } else {
        	$html .= $q->p({-class=>'msg_failure'},"The was an error in publishing your blacklist file:".$q->br.($result || ''));
        }
	}	

	my $docroot = $ENV{'DOCUMENT_ROOT'} ? $ENV{'DOCUMENT_ROOT'} : '/FULL/FILE/PATH/TO';
	$docroot =~ s#/?$#/#;
	my $suggested_path = $docroot.'blacklist.txt';
	
	# Set up blacklist file path for form
    unless ($_cache->{config}->{'publishLoc'}) {
		$_cache->{config}->{'publishLoc'} = $suggested_path;
    }


    $html .= $q->start_form('post',$app->uri);
    $html .= $q->p(
        $q->hidden(-name=>'__mode'),
        $q->strong("Full blacklist file publish path: ").$q->br.
        $q->textfield(-class=>'text', -name => 'publishLoc', -size=>50, -value => $_cache->{config}->{'publishLoc'}).
        $q->submit(-name => '', -value => 'Publish')
    );
    $html .= $q->end_form;

	if ($ENV{'DOCUMENT_ROOT'} && 
			($_cache->{config}->{'publishLoc'} ne $suggested_path)) { 
				
		$html .= $q->p($q->strong('Suggested path: '). $q->br. $suggested_path);
	}
	
	$html;
}


sub config {

	my $app = shift;
	my $q = $app->{query};

	# Check for user permissions.  A user must be able 
	# to configure at least one blog to be allowed to 
	# view this page
    my $blogs = _getBlogs(); 
    my %bloglabels;
    for (values %{$blogs}) {
		my $perms = $app->_getBlogPermissions($_->id);

		if ($perms) { 
			if ($perms->can_create_blog) {
				$app->{user}->can_create_blog(1);
			}
			if ($perms->can_edit_config || $perms->can_edit_templates) {
				$bloglabels{$_->id} = $_->name;
    		    $app->{user}->can_edit_publishloc(1);
			}
		}
	}
    return $app->error("You are not authorized to configure any blogs.") unless %bloglabels;

	my $msg = '';
	my %orig_config;
	if ($q->param('formSubmitted')) {

		%orig_config = %{$_cache->{config}};
		
		#
		# EASY SCALAR CONFIG VARIABLES
		# If variable is defined in submitted paramters, we update the config
		# If not, the original config value stays
		#
        foreach ('blacklistActive',
				'logDenials',
				'despamAction',
				'spamSearchDepth',
				'denyResponse') {
			next if (! $app->{user}->can_create_blog or ($q->param($_) eq ''));
            $_cache->{config}->{$_} = $q->param($_);
		}
		if ($app->{user}->can_edit_publishloc && 
				defined($q->param('autoPublish')) && ($q->param('autoPublish') ne '')) {
            $_cache->{config}->{autoPublish} = $q->param('autoPublish');
		}


		#
		# DIFFICULT FILTERED USER ARRAY REFERENCE CONFIG VARIABLES
		#
		# The user can only update his or her own blogs configuration for
		# overrideCommentPosting and overridePingPosting.  Since the user 
		# cannot submit values for other blogs, the other blogs
		# get excised from the array reference if we did it as above.
		#
		# The idea below is to create a hash of original config vars:
		#
		#   $hash{VARIABLE}{BLOG_ID} = 0 or 1
		#
		# Then we update the hash with ONLY values which changed 
		# for ONLY blogs configurable by the user.
		# 
        my %all_blog_ids;
        %all_blog_ids = map {$_,''} keys %{$blogs};
        
        my (%original_override_status,%new_override_status);
        foreach my $key ('overrideCommentPosting','overridePingPosting') {
        
            # Get status for all blogs 
            my %hash; 
            @hash{@{$_cache->{config}->{$key}}} = (); 
            foreach my $blog_id (keys %all_blog_ids) {
                if (exists($hash{$blog_id})) {
                    $original_override_status{$key}{$blog_id} = 1;
                } else {
                    $original_override_status{$key}{$blog_id} = 0;
                }
            } 
        #$test .= "Original config for $key: ".$app->_debug(\%original_override_status); #JAYBO
        
            # Initialize new hash with original status 
            $new_override_status{$key} = $original_override_status{$key};
        
        #$test .= "Incoming param status for $key: ".$app->_debug($q->param($key)) if $q->param($key);
        
            my %request; 
            foreach ($q->param($key)) {
                $request{$_} = (); 
            }
        #$test .= "Request Dump: ". $app->_debug(\%request);
            foreach my $userblog (keys %bloglabels) {
        #$test .= $app->_debug("Exists RequestUserblog $userblog: ". exists($request{$userblog})."<br />\n".
        #	"Orig status $key userblog $userblog: ".$original_override_status{$key}{$userblog});
                if (exists($request{$userblog}) && ! $original_override_status{$key}{$userblog}) {
                    $new_override_status{$key}{$userblog} = 1;
                } elsif (! exists($request{$userblog}) && $original_override_status{$key}{$userblog}) {
                    $new_override_status{$key}{$userblog} = 0;
                } 
            }
        
        #$test .= "Final config for $key: ".$app->_debug(\%new_override_status); #JAYBO
	        $_cache->{config}->{$key} = [];
	        foreach (keys %{$new_override_status{$key}}) {
				next unless $new_override_status{$key}{$_};
		        push(@{$_cache->{config}->{$key}}, $_);
	         } 
        }
		
        
        if ($q->param('publishLoc') && $app->{user}->can_edit_publishloc) {
			my $blPath = $q->param('publishLoc');
            $blPath =~ s!\\!/!g;   ## Change backslashes to forward slashes
    
            # Check for security holes and stupidity
            if (($blPath =~ m!\.\.|\0|\|!) ||
                ($blPath =~ m!\S+\s+\S+!)) {
                return $app->error($app->translate("Invalid path or filename '[_1]'", $blPath));
            }
        
            ## Untaint. We already checked for security holes in $blPath.
            ($blPath) = $blPath =~ /(.+)/s;
            $_cache->{config}->{'publishLoc'} = $blPath;
	 	}           

	 	if ($app->_saveConfig()) {
			$app->log('User \''.$app->{user}->name.'\' changed the MT-Blacklist configuration');
			$msg =$q->p({-class=>'msg_success'},'Your configuration was saved.');
# 			my $subject = "Blacklist configuration change";
# 			my $body = 'User '.$app->{user}->name.' (UserID: '.$app->{user}->id.
# 				') just changed the configuration for MT-Blacklist.  '."\n\n".
# 				'Listed below is each configuration setting that was changed '."\n\n";
# 
#             my %englishizer = (
#                 0 => 'off',
#                 1 => 'on',
#                 'blacklistActive' => 'MT-Blacklist status',
#                 'autoPublish' => 'blacklist auto-publishing status',
#                 'logDenials' => 'activity log usage status',
#                 'despamAction' => 'default despam action',
#                 'publishLoc' => 'blacklist auto-publish location',
#                 'overrideCommentPosting' => 'comment blocking',
# 				'overridePingPosting' =>  'ping blocking',
# 				'overrideCommentTags' =>  'comment filtering',
#                 'overridePingTags' =>  'ping filtering'
#                 );
# my $html = 'HI';
#  
# 			foreach ('blacklistActive','autoPublish','publishLoc','logDenials','despamAction') {
#                 if ($app->{Blacklist_config}->{$_} ne $orig_config{$_}) {
#                     $html .= $q->p("Old $englishizer{$_}: $englishizer{$orig_config{$_}}\n",$q->br,
#                     	"New $englishizer{$_}: $englishizer{$app->{Blacklist_config}->{$_}}\n");
#                 }
# 			}
#  return $html;          
#             foreach ('overrideCommentPosting','overridePingPosting',
#                         'overrideCommentTags','overridePingTags') {
#                 next if $q->param($_) eq '';
#                 $app->{Blacklist_config}->{$_} = [ $q->param($_) ];
#             }
# 
# 'Blacklist_config' => {
#                                          'logDenials' => 1,
#                                          'overrideCommentPosting' => [
#                                                                        '3',
#                                                                        '4'
#                                                                      ],
#                                          'overrideCommentTags' => [
#                                                                     '3',
#                                                                     '4'
#                                                                   ],
#                                          'publishLoc' => '/home/j/other_sites/plugindev/www/blacklist.txt',
#                                          'autoPublish' => 1,
#                                          'blacklistActive' => 1,
#                                          'pluginVersion' => '1.1-dev',
#                                          'overridePingPosting' => [
#                                                                     '3',
#                                                                     '4'
#                                                                   ],
#                                          'overridePingTags' => [
#                                                                  '3',
#                                                                  '4'
#                                                                ], 
                                                               			

        } else {
			$msg =$q->p({-class=>'msg_failure'},'There was an error in saving your configuration.');
        }
	}
	
    my $html = $app->_navigation_html('Configuration','configpage') . $msg;

    $html .= $q->start_form('post',$app->uri);
	$q->param('__mode','config');

	# Only users who can create blogs can flip the master switch
    if ($app->{user}->can_create_blog) {

        $html .= $q->h3('MT-Blacklist Master Switch');
        $html .= $q->p({-class=>'question'},
                        'Would you like to activate MT-Blacklist?  ',
                        $q->radio_group(-name => 'blacklistActive',
                                '-values' => [1,0],
                                '-default' => $_cache->{config}->{'blacklistActive'},
                                -labels => {1=>'Yes', 0=>'No'})
                   ).
                $q->p({-class=>'description'},'If you select Yes, MT-Blacklist will use the settings below in its operations.  If you select No, your MT installation will continue as if MT-Blacklist did not exist.');
    
 	}



	

	$html .= $q->h3('Spam Blocking');

    $html .= $q->p({-class=>'question'},'What actions would you like MT-Blacklist to take for each weblog?');
	$html .= $q->p({-class=>'description'},'When MT-Blacklist protection is active, the plugin will only block the submission types you specify for the weblogs you specify.  Unchecking <strong>all</strong> boxes has the same effect as deactivating the plugin in the option above (except that your expend more energy doing so).',$q->br,
			'<strong>Note:</strong> If you uncheck any of the following, MT-Blacklist will not override Movable Type\'s native methods for that specific combination.  This means that you will not receive the de-spam link in your notification email for that combination.');

    my (%override);
    foreach my $cfgkey ('overrideCommentPosting','overridePingPosting') { 
        %{$override{$cfgkey}} = map { $_,1} @{$_cache->{config}->{$cfgkey}};
    
    }
    
    my @topheadingrow = $q->th('') . 
                        $q->th({-colspan=>2},'Blocking spam');

    my @secondheadingrow = $q->th(['','Comments','Trackbacks']);

    my @datarows = ();
    foreach (keys %bloglabels) {

        my @data = (
            $q->checkbox(-name=>'overrideCommentPosting',
                       -checked=> $override{overrideCommentPosting}{$_} ? 'checked' : 0,
                       -value=>$_,
                       -label=>''),
           $q->checkbox(-name=>'overridePingPosting',
                       -checked=> $override{overridePingPosting}{$_} ? 'checked' : 0,
                       -value=>$_,
                       -label=>'')
            );
            
        push(@datarows,$q->th({-class=>'blognames'},$bloglabels{$_}).$q->td([@data]));
    }



    $html .= $q->table({-id=>'actiontable'},
                        $q->Tr({-class=>'topheader'},\@topheadingrow),
                        $q->Tr({-class=>'bottomheader'},\@secondheadingrow),
                        $q->Tr(\@datarows) ); 
   
	
    if ($app->{user}->can_create_blog) {
	
        $html .= $q->p({-class=>'question'},'What response would you like to return for denied comments/pings?');
        $html .= $q->p({-class=>'description'},'Below you can customize your response to a user who has had their submission denied.  ');
        $html .= $q->p(
            $q->textfield(-class=>'text', -name => 'denyResponse', -size=>70, -value => $_cache->{config}->{'denyResponse'})
        );
        $html .= $q->p({-class=>'description'},'<strong>Variables</strong>'.$q->br.
        '__TYPE__ = the submission type (either "comment" or "ping")'.$q->br.
        '__BLACKLIST__ = the first entry on the blacklist that was matched'.$q->br.
        '__TEXT__ = the specific text fragment that was matched in the submission ');


        $html .= $q->p({-class=>'question'},'Would you like logging of blocked posts?',
                        $q->radio_group(-name => 'logDenials',
                                    '-values' => [1,0],
                                    '-default' =>$_cache->{config}->{'logDenials'},
                                    -labels => {1=>'Yes', 0=>'No'})
                ).
                $q->p({-class=>'description'},'MT-blacklist can log blocked attempts of comment and trackback spam in your Movable Type activity log.  The first blacklisted string matched, the IP address of the probable spammer and time of denial will be logged.  This is not only a great way too see how effective the plugin is, but it could also be the only way you will know if you mistakenly entered something that is blocking every submission.');


        $html .= $q->h3('Search &amp; De-spam');
        
        my @despamAction_labels = (
                {value => 0, label => "Don't delete the comment/ping or rebuild"},
                {value => 'delete', label => "Delete the comment/ping"},
                {value => 'deleteRebuildEntry', label => "Delete the comment/ping and rebuild the entry"},
                {value => 'deleteRebuildEntryIndexes', label => "Delete the comment/ping and rebuild the entry/indexes"});
        my $despamAction_default = $_cache->{config}->{'despamAction'} || 0;
    
        $html .= $q->p({-class=>'question'},'What is your preferred de-spamming action?');
		$html .= $q->p({-class=>'description'},'Below you can set the default action to be taken when using de-spam mode from the link in your comment notification email.  This configuration setting is only the default and can be changed on a case-by-case basis on the de-spam page.');
        $html .= '<p><select name="despamAction">';
        foreach (@despamAction_labels) {
            my $selected = ($_->{'value'} eq $despamAction_default) ? 'selected="selected" ' : '';
            $html .= '<option '.$selected.'value="'.$_->{'value'}.'">'.$_->{'label'}.'</option>'; 
        }
        $html .= '</select></p>';


        $html .= $q->p({-class=>'question'},
        	'How deep should search go? (# of comments/pings) &nbsp; &nbsp; ',
            $q->textfield(-class=>'text', 
            				-name => 'spamSearchDepth', 
            				-size=>4, 
            				-value => $_cache->{config}->{'spamSearchDepth'})
        );
		$html .= $q->p({-class=>'description'},'Spam search mode (accessed by clicking the de-spam button on the toolbar or from the de-spam results page) will search back  through your most recent comments/pings for those which match your blacklist.  Here you can set your default number of comments/pings to search back through.  The higher the number of comments/pings, the longer it takes so setting this low is a good choice.  Plus, you can specify a higher value on the results page in case of a major spam attack.');
    
	}
	
	
	
	# Only users who can create blogs can fiddle with file writing
    if ($app->{user}->can_edit_publishloc) {

        $html .= $q->h3('Automatic Blacklist Publishing');
        $html .= $q->p({-class=>'question'},'Would you like to publish your blacklist on your site after each change?',
                        $q->radio_group(-name => 'autoPublish',
                                    '-values' => [1,0],
                                    '-default' =>$_cache->{config}->{'autoPublish'},
                                    -labels => {1=>'Yes', 0=>'No'})
                ).
                $q->p({-class=>'description'},'If you so choose (and we encourage this choice), you can publish your blacklist to your website automatically upon change. This offers others near-real-time protection against spammers you have discovered.   For the sake of standards, it is recommended that the file be named <em>blacklist.txt</em> and reside in the root directory of your website.  The possible network effect here is certainly delicious. ');
    
        $html .= $q->p(
            $q->strong('If yes, enter the full path and filename of the file:').
            $q->br.
            $q->textfield(-class=>'text', -name => 'publishLoc', -size=>50, -value => $_cache->{config}->{'publishLoc'})
        );
    



 	}
 	
 	
	$html .= $q->p(
					$q->hidden('__mode'),
                    $q->hidden(-name=>'formSubmitted', -value=>1),
					$q->submit(-name => '', -value => 'Save Configuration')
	);
    $html .= $q->end_form;



	# Only users who can create blogs may do a restore
    if ($app->{user}->can_create_blog) {
            $q->param('__mode','restore');
        $html .= $q->div({-id=>'restoreform'},
            $q->h4("Restore default settings"),
            $q->p('If for any reason you need to restore the default installation settings, you can do so below.  This will delete your entire blacklist and restore your configuration settings to their defaults.'),   
            $q->start_form('post',$app->uri),
            $q->p(
                $q->hidden('__mode'),
                $q->checkbox(-name=>'yesImSure',
                                   -value=>'1',
                                   -label=>'I don\'t really want my blacklist and configuration data.')
            ),
            $q->p(
                $q->submit(-name => '', -value => 'Restore default configuration and blacklist')
            ),
            $q->end_form);
	}


	$html .= $app->_debug($_cache->{config});
#	$html .= $test;

	$html;
}


sub remove_all {

    my $app = shift;
	my $q = $app->{query};

	$app->_saveBlacklist([{string => ''}]);											

    $app->redirect($app->uri);
}


sub restore {

    my $app = shift;
	my $q = $app->{query};
	my $newInstall = shift || '';

	unless ($newInstall) {
	    $app->{user}->can_create_blog 
	    	or return $app->error("You are not authorized to perform this action.");
    }
	
	my $idiotCheck = $q->param('yesImSure') || $newInstall;
	unless ($idiotCheck == 1) {
	    return $app->redirect($app->uri); 
	} 
		
	$app->_saveBlacklist([{string => ''}]);											

	my $docroot = $ENV{'DOCUMENT_ROOT'} ? $ENV{'DOCUMENT_ROOT'} : '/FULL/FILE/PATH/TO';
	$docroot =~ s#/?$#/#;

	my $config_data = {
				pluginVersion => $VERSION,
				blacklistActive => 0,
                publishLoc => $docroot.'blacklist.txt',
                autoPublish => (-d $docroot ? 1 : 0),
                updateNotifyURLs => [],
				logDenials => 1,
				despamAction => 'deleteRebuildEntryIndexes',
				spamSearchDepth => 25,
				denyResponse => 'Your __TYPE__ could not be submitted due to questionable content: __TEXT__'
             };


    my $blogs = _getBlogs(); 
	my @blog_ids = map { $_ } keys %{$blogs};
	foreach ('overrideCommentPosting','overridePingPosting') {
					
		$config_data->{$_} = [ @blog_ids ];
    }
    
	$app->_saveConfig($config_data);
 
    return $newInstall ? 
    	$app->redirect($app->uri.'?__mode=config') :
    	$app->redirect($app->uri);
}





sub despam {
    my $app = shift;
	my $q = $app->{query};

    my $html = $app->_navigation_html('De-spamming your blog','despampage');

	my $type = $q->param('_type') || '';

	my (@extract_strings,$comment,$tb,$entry,$comment_mt_url,$raw_source);
	if ($type eq 'comment') {
        require MT::Comment;
        $comment = MT::Comment->load($q->param('id')) or
	        return $app->error("The $type could not be loaded for de-spamming. (".
	         ucfirst($type) .': '. $q->param('id') .')');
        
        $comment_mt_url = $app->{cfg}->CGIPath.
                            'mt.cgi?__mode=view&_type=comment&id='.
                            $comment->id.
                            '&blog_id='.
                            $comment->blog_id;
                            
		@extract_strings = ($comment->text,$comment->url,$comment->author);
		$raw_source = ($comment->author || '') ."\n".($comment->url || '')."\n\n".($comment->text || '');
		
	} elsif ($type eq 'ping') {
		require MT::TBPing;
        my $ping = MT::TBPing->load($q->param('id')) or
            return $app->error("The $type could not be loaded for de-spamming. (".
             ucfirst($type) .': '. $q->param('id') .')');

		@extract_strings = ($ping->title,$ping->excerpt,$ping->source_url);
		$raw_source = ($ping->title || '')."\n".($ping->source_url || '')."\n\n".($ping->excerpt || '');

	} else {
		return $app->error("Improper object type: ".$type);
	} 


	$html.= $q->h2("De-spamming Movable Type");
	$html .= $q->p('Below you will find the extracted URLs from ',
                $type eq 'comment' ?
					$q->a({-href=>$comment_mt_url},'the comment') :
                	'the ping',
			' in question.  On this page, you can add those URLs to
			 your blacklist, delete the comment and rebuild.  All 
			 in one step!'
	);

	my @unique = $app->_extractURLs(@extract_strings);

	$html .= $q->start_form('post',$app->uri);
	
	$html .=  $q->h3('Found URLs');

	if (@unique) {
        $html .=  $q->p({-class=>'description'},"The following unique URL fragments were found in the $type.").
        	$q->p({-class=>'description'},
        	"Please select the ones you would like to ban and edit them as you would on the ",
            $q->a({-href=>$app->uri.'?__mode=add'},'Add page'),'(e.g. adding comments).  If there are strings that you want to ban that were not extracted, you can copy and paste them from the raw source of the '.$type.' submission '.$q->a({-href=>'#rawsource'},'below').': ');
 
        my $rows = scalar(@unique) > 20 ? 20 : scalar(@unique);
        $rows = $rows < 5 ? 5 : $rows;   
		$html .= '<p><textarea name="foundURLs" rows="'.$rows.'" cols="80" class="text">'.join("\n",@unique).'</textarea></p>';
	} else {
        $html .=  $q->p('No URL fragments were found.');
	}



	$html .=  $q->h3('Taking out the trash').
			$q->p({-class=>'description'},"You have the option to delete the $type ",
			'and rebuild the entry if you like.',$q->hidden('id'));

	my @despamAction_labels = (
			{value => 0, label => "Don't delete the $type or rebuild"},
			{value => 'delete', label => "Delete the $type"},
			{value => 'deleteRebuildEntry', label => "Delete the $type and rebuild the entry"},
			{value => 'deleteRebuildEntryIndexes', label => "Delete the $type and rebuild the entry/indexes"});
	my $despamAction_default = $_cache->{config}->{'despamAction'} || 0;

	$html .= '<p><select name="despamAction">';
	foreach (@despamAction_labels) {
		my $selected = ($_->{'value'} eq $despamAction_default) ? 'selected="selected" ' : '';
		$html .= '<option '.$selected.'value="'.$_->{'value'}.'">'.$_->{'label'}.'</option>'; 
	}
	$html .= '</select></p>';


	$q->param('__mode','despam_confirm');	
    $html .= $q->p({-class=>'right'}, $q->hidden('__mode'),$q->hidden('_type'),
$q->submit(-name => '', -value => 'Go forth now and do my bidding!')).$q->hr;




    $html.= $q->h3({-id=>'rawsource'},"The original $type content:");
    my $rows = () = $raw_source =~ /\n/g; ;
    $rows = $rows > 20 ? 20 : $rows;
    $rows = $rows < 5 ? 5 : $rows;   
	$html .= $q->p('<textarea readonly="readonly" rows="'.$rows.'" cols="80" name="rawsource" class="text">'.$raw_source.'</textarea>');
    $html .= $q->end_form;

    $html;






}



sub despam_confirm {

	# This could use some cleaning up and abstraction 
	# of common actions with add_confirm
	
    my $app = shift;
	my $q = $app->{query};
	my $type = $q->param('_type');

    my $html = $app->_navigation_html('De-spamming Results','despampage');
	$html .= $q->h2('De-spamming results');

	# ADD ENTRIES TO BLACKLIST
	my @new_entries;
	my %results = (
					'success' => [],
					'dupes' => []
				);

	# ADD ENTRIES TO BLACKLIST IF PRESENT
    if (my $import = $q->param('foundURLs')) { 
        foreach (@new_entries = $app->_diceImportFileData($import)) {
            if (defined($app->_fuzzyFindBlacklistIndex($_->{'string'}))) {
                push(@{$results{'dupes'}}, $_->{'string'});
                next;
            }
            push(@{ $_cache->{blacklist} }, $_);
            push(@{$results{'success'}}, $_->{'string'});
        }
    
        if (@{$results{'success'}}) {
            $results{'blacklist_saved'} = $app->_saveBlacklist();

            my $logstring = 'User \''.$app->{user}->name.'\' added '.
                (@{$results{'success'}} == 1 ? '\''.${$results{'success'}}[0].'\'' :
                    (@{$results{'success'}}).' entries').
                    ' to the MT-Blacklist';
            $app->log($logstring);

        }
    }


    # DELETE THE COMMENT/PING IF REQUESTED
    my ($object,$findMoreLink);
	if (my $action = $q->param('despamAction')) {

        # Load up the ping/comment
        my $id = $q->param('id');
        if ($type eq 'comment') {
            use MT::Comment;
            $object = MT::Comment->load($id);
        } elsif ($type eq 'ping') {
            use MT::TBPing;
            $object = MT::TBPing->load($id);
        }
        return $app->error("Could not load $type for deletion (ID: $id):") unless $object ;


        $findMoreLink = $q->p('Find other '.$type.'s that match <a href="'.
                $app->uri.'?__mode=search&amp;_type='.$type.'">your blacklist</a> or <a href="'.
                $app->uri.'?__mode=search&amp;_type='.$type.'&amp;ip='.
                $object->ip.'&amp;matchType=ip">this user\'s IP address</a>.');

        if ($app->_deleteObject($object)) {
            $results{'obj_removal'} = $q->strong({-class=>'msg_success'},'SUCCEEDED');
			if ($action eq 'deleteRebuildEntry') {
                $results{'entry_rebuild'} = 
                        $app->_rebuildObjectEntry($object);
			} elsif ($action eq 'deleteRebuildEntryIndexes') {
                $results{'entry_rebuild'} = 
                        $app->_rebuildObjectAll($object);
			}
			
			if ($results{'entry_rebuild'}) { 
                $results{'entry_rebuild'} =
                    $q->strong({-class=>'msg_success'},'SUCCEEDED');
            } elsif (exists($results{'entry_rebuild'})) { 
                $results{'entry_rebuild'} =
                    $q->strong({-class=>'msg_failure'},'FAILED - '.
                    	($app->errstr || 'Unknown error'));
			} else { 
                     $results{'entry_rebuild'} = $q->strong({-class=>'msg_info'},'Not requested');
            }
        } else {
            $results{'obj_removal'} = $q->strong({-class=>'msg_error'},'FAILED'.
            	($app->errstr || 'Unknown error'));
            $results{'entry_rebuild'} = $q->strong({-class=>'msg_info'},'NOT DONE');
        }		
    } else {
        $results{'entry_rebuild'} = $results{'obj_removal'} = 
        	$q->strong({-class=>'msg_info'},'Not requested');
    }


	$html .= $findMoreLink || '';

	# If we didn't do anything, tell the user.
	unless (@new_entries || $q->param('despamAction')) {
        $html .= $q->div({-class=>'msg_info'},
			$q->ul($q->li(["No action was taken."]))
		);
		return $html;
	}


	$html .= $q->div({-class=>'msg_info'},
		$q->ul($q->li([ucfirst($type).' removal: '.$results{'obj_removal'},
			'Entry rebuild: '.$results{'entry_rebuild'} ]))
	);


	if (@{$results{'dupes'}}) {
		$html .= $q->div({-class=>'msg_warning'},
			$q->p("The following entries are duplicates or longer versions of already existing substrings and will not be added:"),
			$q->ul($q->li($results{'dupes'})));
	}

	return $html unless @{$results{'success'}};
	

	if ($results{'blacklist_saved'}) {
        $html .= $q->div({-class=>'msg_success'},
            $q->p("The following entries were successfully added to the blacklist:"),
            $q->ul($q->li($results{'success'})));
	} else {
		$html .= $q->div({-class=>'msg_failure'},
			$q->p("There was an error adding your entries. Please hit the BACK button, uncheck the 'delete $type' checkbox and try again"));
	}
	$html .= $findMoreLink || '';
	$html;

}



sub despam_multi {

	
    my $app = shift;
	my $q = $app->{query};
	my $type = $q->param('_type');

    my $html = $app->_navigation_html('De-spamming Results','despampage');
	$html .= $q->h2('De-spamming results');

    my @objects = $q->param('deleteObject');
    my $rebuild = $q->param('rebuildEntries');

    unless (@objects) {
        my $html = $app->_navigation_html('De-spamming Results','despampage');
        $html .= $q->h2('De-spamming results');
        $html .= $q->div({-class=>'msg_info'},
            $q->ul($q->li([ 'No action taken.' ]))
        );
        return $html;
    }


    # Define anonymous subroutine to grab entry
    my ($entry_grab,$extract_strings);
	if ($type eq 'comment') {
		$extract_strings =sub {
			my $obj = shift;
			return ($obj->text,$obj->url,$obj->author);
		};
	} else {
		$extract_strings = sub {
			my $obj = shift;
			return ($obj->blog_name,$obj->title,$obj->excerpt,$obj->source_url);
		};
	}

	my (%entries_modified,@errors,@deleted,@extracted_urls) = ();
	my (%editAllPosts, %blogPerms, %editPost);
	foreach my $id (@objects) {
        # Load up the ping/comment
        my $object;
        if ($type eq 'comment') {
            use MT::Comment;
            $object = MT::Comment->load($id);
        } elsif ($type eq 'ping') {
            use MT::TBPing;
            $object = MT::TBPing->load($id);
        }

        my $e;
        if ($object) {

			unless ($app->_canEditObject($type,$object)) {
				push(@errors, 'You have no permission to edit '.$object->id);
				next;
            }

	        if ($app->_deleteObject($object)) {
	        	push(@deleted, $object);
	        	$entries_modified{$object->id} = _getObjectEntry($type,$object);
	        	push(@extracted_urls, $app->_extractURLs($extract_strings->($object)));
	        } else {
    	    	push(@errors, "Could not delete $type (ID: $id):". 
    	    		($object->errstr || 'Unknown error'));
	        }
        } else {
    	    push(@errors, "Could not load $type for deletion (ID: $id).")  ;
        }
	}
	
	if (%entries_modified && $rebuild) {
		my %seen = ();
		foreach my $entry (values %entries_modified) {	
			next if $seen{$entry->id};
             if ($app->_rebuildEntry($entry,1)) {
	             $seen{$entry->id}++;
             } else {
             	push(@errors, 'Error rebuilding entry ID '.$entry->id);
             }
        }
	}
	
	
	$html .= $q->div({-class=>'msg_info'}, $q->ul($q->li([scalar(@deleted).' of '. scalar(@objects).' '.$type.'s were successfully deleted.'])));

	if (@extracted_urls) {
	    $q->param('__mode', 'add');
	    $html .= $q->start_form('post',$app->uri);
		$html .= $q->div({-class=>'msg_info'}, 
				$q->p('URLs were found in the deleted comments.  ',
				$q->hidden('__mode'),
				(map { $q->hidden('url',$_) } @extracted_urls),
				$q->submit(-name=>'',-value=>'Click to inspect and add')));
	    $html .= $q->end_form;
	}
	if (@errors) {
		$html .= $q->div({-class=>'msg_failure'}, 
				$q->p('The following errors were encountered:'),
				$q->ul($q->li([@errors])));
	}
	$html;
}





sub search {

    my $app = shift;
	my $q = $app->{query};

	# Set search type
	my $type = $q->param('_type') || 'comment';
	my $matchType = $q->param('matchType') || 'blacklist';

	# Set extra search criteria if applicable
	my $ip = $q->param('ip') if ($matchType eq 'ip');
	my $text = $q->param('text') if ($matchType eq 'text');


	# Set miscellaneous search options
	my $searchDepth = $q->param('n') || $_cache->{config}->{spamSearchDepth};
	my $showSpamText = defined($q->param('showSpamText')) ? $q->param('showSpamText') : '';
	if ($showSpamText ne '') {
	
		$_cache->{config}->{showSpamText} = $showSpamText ? 1 : 0;
		$app->_saveConfig();
	}

	# Get objects the user has edit priviliges for
	my (%blognames,@filtered_objects);
	my $objects = $app->_getUserObjects($type,$searchDepth); 
    foreach my $obj (@{$objects}) {
        my $string;
        if ($type eq 'comment') {
        		foreach ($obj->author, 
        				$obj->url, 
        				$obj->email, 
        				$obj->text) {
					$string .= $_ if $_ && ($_ ne '');
				}        		
        } else {
        		foreach ($obj->blog_name, 
        				$obj->title, 
        				$obj->excerpt, 
        				$obj->source_url) {
					$string .= $_ if $_ && ($_ ne '');
				}        		
        }		

		my $e = _getObjectEntry($type,$obj);

        unless ($blognames{$obj->blog_id}) {
            my $blog = _getBlog($obj->blog_id) or return $app->error('Could not load blog ID '.$obj->blog_id);
            $blognames{$obj->blog_id} = $blog->name;
        }

        my ($rc,$blacklist_string,$matched_string);
    
		# IP address matching  
		if (($matchType eq 'ip') && $ip && $obj->ip && ($obj->ip eq $ip)) {
		
			push(@filtered_objects, {class => 'ip_address',
									blog => $blognames{$obj->blog_id},
									entry => $e,
									object => $obj,
									matched => $ip});

		# Blacklist matching
		} elsif (($matchType eq 'blacklist') && (($rc,$blacklist_string,$matched_string) = _matchBlacklist($obj->blog_id, $string))) { 

            push(@filtered_objects, {class => 'blacklist',
                                        blog => $blognames{$obj->blog_id},
                                        entry => $e,
                                        object => $obj,
                                        blacklist_string => $blacklist_string,
                                        matched_string => $matched_string});

		# Text/Regexp matching
		} elsif (($matchType eq 'text') && $text && ($matched_string = _matchArbitraryText($text, $string))) { 
            push(@filtered_objects, {class => 'text',
                                        blog => $blognames{$obj->blog_id},
                                        entry => $e,
                                        object => $obj,
                                        blacklist_string => $blacklist_string,
                                        matched_string => $matched_string});
                                        
		# LastN comments/trackbacks (no filtering, match all)
		} elsif ($matchType eq 'all') { 
             push(@filtered_objects, {class => 'matchall',
                                        blog => $blognames{$obj->blog_id},
                                        entry => $e,
                                        object => $obj,
                                        blacklist_string => $blacklist_string,
                                        matched_string => $matched_string});
       }
    }


    my $html = $app->_navigation_html('Comment/Trackback Search','searchpage');
    my %defaults = (all => '', blacklist => '', ip => '', text => '', comment => '', ping => '');
    $defaults{$matchType} = 'checked="checked" ';
    $defaults{$type} = ' selected="selected" ';
    $html .= $q->start_form('get',$app->uri);
    $html .= $q->div({-class => 'searchbox'},
		$q->p("Search the last ",
		'<input type="hidden" name="__mode" value="search" /> ',
		'<input type="text" name="n" value="'.$searchDepth.'" size="4" /> ',
		'<select name="_type"><option value="comment"'.$defaults{'comment'}.'>comments</option>'.
		'<option value="ping"'.$defaults{'ping'}.'>pings</option></select> for'),
    	$q->p({-style => 'margin: 0px auto; text-align: left;width:300px'},
		'<input type="radio" name="matchType" value="blacklist" '.$defaults{'blacklist'}.'/> Blacklist matches<br />'.
	    '<input type="radio" name="matchType" value="text" '.$defaults{'text'}.'/> Text/regexp'.
		'<input type="text" name="text" value="'.($text || '').'" size="25" /><br />',
	    '<input type="radio" name="matchType" value="ip" '.$defaults{'ip'}.'/> IP Address '.
	    '<input type="text" name="ip" value="'.($ip || '').'" size="25" /><br />',
 	   '<input type="radio" name="matchType" value="all" '.$defaults{'all'}.'/> All (i.e. no filter)<br />'),
	$q->p('<input type="submit" name="re-search" value="Search" />')
    );
    $html .= $q->end_form;
    				
    				
    				
	$html .= $q->h2(ucfirst($type).' spam search');

# 	my $type_toggle = $type eq 'comment' ? 'ping' : 'comment';
# 	(my $toggle_type_link = $q->self_url) =~ 
# 			s/;?_type=(?:comment|ping)//;
# 	$toggle_type_link = $q->p('Search for <a href="'.$toggle_type_link.';_type='.$type_toggle.'">'.$type_toggle. 's</a>');


	if (! @filtered_objects) {
		$html .= $q->p('Out of the last '.$searchDepth.' '.$type.'s, there are none on entries for which you have editing privileges that match your search criteria.');
#		return $html.$toggle_type_link;
		return $html;
	}

#	$html .= $toggle_type_link;
	my $spamTextToggle = $_cache->{config}->{showSpamText} ? 0 : 1;
	(my $spamTextToggleURL = $q->self_url) =~ s/(.+?)(?:;showSpamText=[01])?$/$1;showSpamText=$spamTextToggle/;

    $html .= $q->start_form('post',$app->uri);
    $q->param('__mode', 'despam_multi');
    $q->param('_type', $type);
    $html .= $q->p({-class=>'description'},$q->hidden('__mode'), $q->hidden('_type'), 
    		'Out of the last ',$searchDepth,' ',$type.'s, there are '.scalar(@filtered_objects).
        ' '.$type.'s on entries for which you have editing '.
        "privileges that match your search criteria. ".
        'Select the ones below which you would like to delete.  You may '.
        '<a href="'.$spamTextToggleURL.'">toggle</a> the '.$type.' text if you like.');
    $html .= '<table width="95%">';

	my @headings;
    if ($type eq 'comment') {
	    @headings = ('Spam','Author','IP Address','Email','URL');
    } else {
	    @headings = ('Spam','Blog','Title','Source URL');
    }		
    $html .= '<tr><td>'.join('</td><td>', @headings).'</td></tr>';

    require MT::Util; 
    
    my $count = 0;
    foreach (@filtered_objects) {
    	my $obj = $_->{object};
		my $alternate = ($count++ % 2 == 1) ? 'odd' : 'even'; 
        if ($type eq 'comment') {
            $html .= '<tr class="'.$alternate.
                    '"><td class="noline">'.
                    '<input type="checkbox" name="deleteObject" checked="checked" value="'.
                    $obj->id.
                    '" /></td><td class="noline">'.
                    $obj->author.'</td><td class="noline">'.
                    $obj->ip.'</td><td class="noline">'.
                    $obj->email.'</td><td class="noline">'.
                    $obj->url.'</td></tr>';
        } else {
            $html .= '<tr class="'.$alternate.
                    '"><td class="noline">'.
                    '<input type="checkbox" name="deleteObject" checked="checked" value="'.
                    $obj->id.
                    '" /></td><td class="noline">'.
                    $obj->blog_name.'</td><td class="noline">'.
                    $obj->title.'</td><td class="noline">'.
                    $obj->source_url.'</td></tr>';
        }		
		if ($matchType eq 'blacklist') {
            $html .= '<tr class="'.$alternate.
                    '"><td colspan="'.scalar(@headings).
                    '" class="noline" align="center">Blacklist entry matched: '.
                    $_->{blacklist_string}.'</td></tr>';
        }
		if ($_cache->{config}->{showSpamText}) {
			my $text = $type eq 'comment' ? MT::Util::first_n_words(MT::Util::encode_html($obj->text),10) : $obj->excerpt;
            $html .= '<tr class="'.$alternate.
                    '"><td colspan="'.scalar(@headings).'" class="noline">'.
                    $text.'</td></tr>';
        }

		my $comment_mt_url;
        if ($type eq 'comment') {
           $comment_mt_url = $app->{cfg}->CGIPath.
                                'mt.cgi?__mode=view&_type=comment&id='.
                                $obj->id.
                                '&blog_id='.
                                $obj->blog_id;
        } 	
    	$html .= '<tr class="'.$alternate.
    			'"><td colspan="5" align="center"><strong>'. ($comment_mt_url ? '<a href="'.$comment_mt_url.
    			'">' : '').'Posted to '.$_->{blog}.' entry "'.
    			$_->{entry}->title.'"'. ($comment_mt_url ? '</a>' : '').'</strong></td></tr>';
    }
    $html .= '</table>';

    $html .= $q->p('<input type="checkbox" name="rebuildEntries" value="1" checked="checked" />'.
    		'Rebuild the relevant entries after '.$type.' deletion');
    $html .= $q->p($q->submit(-name => '', -value => 'Delete checked '.$type.'s'));
    $html .= $q->end_form;
    $html;




}

sub debug_app {
	my $app = shift;

    $app->{user}->can_create_blog or return $app->error("You are not authorized to view this page");
    my $html = $app->_navigation_html('Debug Mode','debugpage');
	$app->_debug_status(1);
	$html .= '<h1>ENV OBJECT</h1>'.$app->_debug(\%ENV);
	$html .= '<h1>APP OBJECT</h1>'.$app->_debug($app);
	$html .= '<h1>CACHE OBJECT</h1>'.$app->_debug($_cache);
	$html;

}


sub debug_perms {
	my $app = shift;

    my $blogs = _getBlogs(); 
	my $html;
    require Data::Dumper;
$app->_debug_status(1);
    for (values %{$blogs}) {
		my $perms = $app->_getBlogPermissions($_->id);
		$html .= '<h1>'.$_->id .' and '.$app->{user}->id.'</h1>';
		$html .= $app->_debug($perms);
	}

	$html;

}


sub _versionCheck {
	my $app = shift;

	#
	# If the config is current, then do nothing
	#
	return 1 if $_cache->{config}->{pluginVersion} eq $VERSION;
	
	
	#
	# Get rid of old configuration directives
	#
    foreach ('despamShowRawContent',
    		'applyToAllWeblogs',
    		'protectedBlogs',
    		'overridePingTags',
    		'overrideCommentTags') {
        if (exists($_cache->{config}->{$_})) {
            delete $_cache->{config}->{$_};
        }
    }
    
    
    #
    # Add new configuration directives
    #
    my $blogs = _getBlogs(); 
	my @blog_ids = map { $_ } keys %{$blogs};
	foreach ('overrideCommentPosting','overridePingPosting') {
		next if exists($_cache->{config}->{$_});
		$_cache->{config}->{$_} = [ @blog_ids ];
    }
	$_cache->{config}->{denyResponse} ||= 
		'Your __TYPE__ could not be submitted due to questionable content: __TEXT__';
	$_cache->{config}->{denyResponse} =~ s/__STRING__/__TEXT__/g; 
	$_cache->{config}->{despamAction} ||= 'deleteRebuildEntryIndexes';
	$_cache->{config}->{spamSearchDepth} ||= '25';


	#
	# Save updated configuration
	#    
	$_cache->{config}->{pluginVersion} = $VERSION;
	$app->_saveConfig();

}


sub _checkRegexp {
	my $app = shift;
	my $reg = shift;
	my $line = 'jay_rocks';
	eval { $line =~ m#$reg#; 1; };
	return $@ ? $app->error($@) : 1;
	
}

sub _masterAdd {

	my $app = shift;
	my @entries = @_;
	my $q = $app->{query};

	return unless @entries;


	my $last_dupe = '';
	my %results = (
					'blacklist_saved' => 0,
					'unique' => [],
					'dupes' => [],
					'invalid' => []
				);
	foreach (@entries) {

		if (! $app->_checkRegexp($_->{string})) {
			push(@{$results{'invalid'}}, $app->errstr);
			next;
 		} elsif ($last_dupe = $app->_fuzzyFindBlacklistIndex($_->{'string'})) {
			push(@{$results{'dupes'}}, $_->{'string'});
			next;
		}

		push(@{ $_cache->{blacklist} }, $_);
		push(@{$results{'unique'}}, $_->{'string'});
	}

	# If we had at least one new entry, save the blacklist
	if (@{$results{'unique'}}) {
        $results{'blacklist_saved'} = $app->_saveBlacklist();
		my $logstring = 'User \''.$app->{user}->name.'\' added '.
			(@{$results{'unique'}} == 1 ? '\''.${$results{'unique'}}[0].'\'' :
				(@{$results{'unique'}}).' entries').
				' to the MT-Blacklist';
		$app->log($logstring);

	}

	# Return results to caller with multiple items since it's easy.  
	if (@entries > 1) {
		return ($results{'blacklist_saved'}, $results{'dupes'}, $results{'unique'}, $results{'invalid'});
	}	


	# Now handle callers with only one item
    my $str = ${$results{'unique'}}[0];
    
	# A dupe gets back (0,dupe_id)
    if ($last_dupe ne "") {
        return ($results{'blacklist_saved'},$last_dupe);
    } 

	# An invalid regex gets back just 0 with $app->errstr
    return 0 if $app->errstr;
    
    return $results{'blacklist_saved'} ?
        # A unique and successful save gets (1,new_id)
        ($results{'blacklist_saved'}, $app->_findBlacklistIndex($str)+1) :  # It is a mystery why I have to add 1
        # A unique and failed save (0)
        $results{'blacklist_saved'};				
}		



sub _findBlacklistIndex {

	my $app = shift;
	my ($str,$fuzzy) = @_;

	my @strings = map { $_->{'string'}} @{ $_cache->{blacklist} }; 

	my $i;
    for ($i = 0; $i < @strings; $i++) {
		next if $strings[$i] eq '';
        if ($strings[$i] eq $str) {
            return $i;
        }
    } 

	if ($fuzzy) {
        for ($i = 0; $i < @strings; $i++) {
			next if $strings[$i] eq '';
            # Case-insentive substring match
            if ( index(lc($str),lc($strings[$i])) != -1) {
                return $i;
            }
        } 
    }
    return;
}

sub _fuzzyFindBlacklistIndex {
	my $app = shift;
	my $str = shift;
	return $app->_findBlacklistIndex($str,1);
}

sub _prepareBlacklistEntry {

	my $app = shift;
	my $struct = shift;

	my $user;
	if (! $app->{user}) {
		$user = '';
	} elsif (! defined($_cache->{blacklist}) && 
				! defined($_cache->{config})) { 
	
		$user = 'MT-Blacklist $VERSION Install';
	} else {
	
		$user = $app->{user}->name.' (ID: '.$app->{user}->id.')';
	}

	# Maybe this is a mistake, but I am protecting users
	# from the own ignorance and removing http://www from
	# the blacklist strings.
	$struct->{'string'} =~ s#^http://(www)?##;

    my $ts = _getTimestamp();

	$struct->{'weblogs'} ||= [-1];
	$struct->{'origin'} ||= 'local';
	$struct->{'sent'} ||= [];
	$struct->{'comment'} ||= '';
	$struct->{'comment'} =~ s#[\n\r]+# #g; # Convert newlines
	$struct->{'dateAdded'} ||= $ts;
	$struct->{'addedBy'} ||= $user;
	$struct->{'dateModified'} ||= $ts;
	$struct->{'lastModifiedBy'} ||= $user;

	$struct;
}

sub _rmFromBlacklist { 

	my $app = shift;
	my @delete_strings = @_ or return;

	my @pared_blacklist;
	foreach my $entry (@{$_cache->{blacklist}}) {
		my $found = 0;
		foreach my $delete (@delete_strings) {
			next unless $delete eq $entry->{'string'};
			$found++;
			last;
		}
		push(@pared_blacklist,$entry) unless $found;
	}
	
	my $diff = scalar(@{$_cache->{blacklist}}) - scalar(@pared_blacklist);

	my $logstring = 'User \''.$app->{user}->name.'\' deleted '.
		($diff == 1 ? '\''.$delete_strings[0].'\'' :
			(scalar(@{ $_cache->{blacklist} })-scalar(@pared_blacklist).' entries')).
			' from the MT-Blacklist';

	if ($app->_saveBlacklist(\@pared_blacklist)) {
		 	$app->log($logstring);
		    $diff;
	    } else {
		 	$app->log($logstring);
			0;
        }

}


sub _deleteObject {
	my $app = shift;
	my $object = shift or 
		return $app->error("No object provided for deletion");
	
	$object->remove or 
		$app->error("Could not remove object: ".($object->errstr || 'Unknown error'));
}



sub _saveBlacklist { 

	my $app = shift;
	my $data = shift;

	my $rc = $app->_saveBlacklistData('blacklist',$data);

	$app->_writeBlacklistFile() if $rc && $_cache->{config}->{'autoPublish'};
	
	$rc;
 }
 
 
sub _saveConfig { 
	my $app = shift;
	my $data = shift;

	$app->_saveBlacklistData('config',$data);
}


sub _saveBlacklistData {

	my $app = shift;
    my ($key,$data) = @_;
    
    if (!ref($data)) {
    	$data = $key eq 'blacklist' ?
    		$_cache->{blacklist} :
			$_cache->{config};
	}
   
    # Within the application the blacklist will
    # always have a dummy first entry at index 0.
    # When it is saved, it is stripped from the array.
    # We also sort by string before saving
	if ($key eq 'blacklist') {
    	while (@{$data} && ($data->[0]->{string} eq '')) { shift(@{$data}); }
		@$data = sort { $a->{string} cmp $b->{string} } @$data;
   	} 

	my $rc;
    if ($blacklist_config_directory && ($blacklist_config_directory ne '')) {
    	my $file = $blacklist_config_directory."/$key.yaml";
    	$file =~ s#//#/#g;
		unless (-d $blacklist_config_directory) {
        	die "The Blacklist config directory you specified ($blacklist_config_directory) does not exist.";
        }
		require Yaml; 
		$rc = YAML::DumpFile($file, $data);
		unless ($rc) {
			my $mode = (stat($blacklist_config_directory))[2];
			my $perm = sprintf "%04o", $mode & 07777;
            my $debuginfo = {
            'directory' => $blacklist_config_directory,
            'mode' => $mode,
            'perm' => $perm
            };
			die "<p>Could not save your $key data. This could indicate a problem with your blacklist config directory permissions.</p><p>The error given was: ". ($@ || 'Unknown error') ."</p><p>Some debugging info for you to report:</p><pre>\n".Dumper($debuginfo).'</pre>'; 
		}
    } else {
        my $blObj = _getPluginDataObject($key);
        if (!$blObj) {
			require MT::PluginData;
            $blObj = MT::PluginData->new;
            $blObj->plugin ('Blacklist');
            $blObj->key ($key);
        }
        
        $blObj->data ($data);
        $rc = $blObj->save or die "Could not save your $key data: ". 
        	($blObj->errstr || 'Unknown error');
    }

	# Put the blank string back on
    unshift(@{$_cache->{$key}}, {string => ''}) if $key eq 'blacklist';
	$_cache->{$key} = $data;
	$rc;
}


sub _writeBlacklistFile { 

	my $app = shift;
	my $blPath = shift || $_cache->{config}->{'publishLoc'};

	return (0,"No blacklist publish location set.") unless $blPath;

	# Create blacklist file content
	my $data = _getBlacklistMasthead();	

	my $num_entries = 0;
	if ($_cache->{blacklist}) {
		$num_entries = scalar(@{ $_cache->{blacklist} }); 
		foreach (@{ $_cache->{blacklist} }) {

			my $len = length($_->{'string'}) > 35 ? length($_->{'string'}) : 35;
			$data .= sprintf("%-".$len."s ", $_->{'string'});
			$data .= $_->{'comment'} ? '# '.$_->{'comment'}."\n" : "\n";
		}
	} 
	$data =~ s/\{NUM_ENTRIES\}/$num_entries/;

	my $ts = _getTimestamp();
	$ts =~ s#(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})#$1/$2/$3 $4:$5:$6#;
	$data =~ s/\{TIMESTAMP\}/$ts/;

	# Write file
	require MT::FileMgr;
	my $fmgr;
	$fmgr = MT::FileMgr->new('Local') or return (0,$fmgr->errstr);
	defined($fmgr->put_data($data, $blPath)) or return (0,$fmgr->errstr);
 	1;
}


sub _rebuildObjectAll {
	return _rebuildObjectPage(@_);
}

sub _rebuildObjectEntry {
	return _rebuildObjectPage(@_,'entry');
}

sub _rebuildObjectPage {

	my $app = shift;
	my ($object,$type) = @_;

	$type ||= '';

    my $entry = _getEntry($object->entry_id);
	if ($type eq 'entry') {
        $app->rebuild_entry( Entry => $entry );
	} else {
        $app->rebuild_entry( Entry => $entry, BuildDependencies => 1 );
	}
}


sub _rebuildEntry {

	my $app = shift;
	my ($entry, $dependancies) = @_;

	if ($dependancies) {
        $app->rebuild_entry( Entry => $entry, BuildDependencies => 1 );
	} else {
        $app->rebuild_entry( Entry => $entry );
	}
}


sub _diceImportFileData {
	my $app = shift;
	my $data = shift;
	chomp $data;

	my @banned;	
    my @lines = split /\r?\n/, $data;
    foreach my $line (@lines) {
        my ($banned_url,$comment) = $line =~ 
            m(
            ^					# Beginning of line
            \s*					# Optional whitespace
            ([^\s\#]+)\s*			# The url fragment
            (?:\s+\#\s*(.*))?	# Optional line-ending
                                #  comment (minus the #)
            $					# End of line
            )x;
        next if !$banned_url;
        # Remove whitespace from endings
        $banned_url =~ s/^\s+|\s+$//;
        $comment =~ s/^\s+|\s+$// if $comment;

        push(@banned, $app->_prepareBlacklistEntry({string=>$banned_url,comment=>$comment}));
    }

	@banned;
}


sub _getBlacklistEntry { 

	my $app = shift;
	my $id = shift;
	return (${ $_cache->{blacklist} }[$id],scalar(@{ $_cache->{blacklist} }));
	
}


#
# _matchBlacklist method
#
# Here we match blacklisted strings against the user input.
# Plain strings and regular expressions are allowed.  Nothing
# needs to be escaped as far as I know since our delimiters
# and regular expression metacharaters are mutually exclusive 
# aside from the period which makes no difference.
#
sub _matchArbitraryText {

    my (@strings, @blacklisted_strings, $str, $deny);
	my $needle = shift;
	my $haystack = shift;

    # Sanitize text
    $haystack = _sanitizeInput($haystack);
    return unless $haystack =~ /\S/;

    # Match against pattern in one expression
    return unless $haystack =~ m#$needle#io;
	return $&;

}






sub _canEditObject {
	my $app = shift;
	my ($type,$object) = @_;
	my $rc; 

	_mywarn("In canEditObject with $type ID ".$object->id);

	if ($type eq 'comment') {
		$rc = $app->_canEditComment($object);
	} elsif ($type eq 'ping') {
		$rc = $app->_canEditPing($object);
	} elsif ($type eq 'entry') {
		$rc = $app->_canEditEntry($object);
	} else {
		die "Unknown object type in canEditObject";
	}
	_mywarn("Returning from canEditObject with a $rc for $type ID ".$object->id);

	$rc;
}


sub _canEditComment {
	my $app = shift;
	my $c = shift or return $app->error("No comment specified for permission check.");

	_mywarn("In canEditComment with comment ID ".$c->id);

	my $entry = _getEntry($c->entry_id);

	$app->_canEditEntry($entry);
}


sub _canEditPing {
	my $app = shift;
	my $p = shift or return $app->error("No ping specified for permission check.");

	_mywarn("In canEditPing with ping ID ".$p->id);

	my $tb = _getTrackback($p->tb_id);
	my $entry = _getEntry($tb->entry_id);
	
	$app->_canEditEntry($entry);

}


sub _canEditEntry {
	my $app = shift;
	my $e = shift or return $app->error("No entry specified for permission check.");

	_mywarn("In canEditEntry with entry ID ".$e->id);

	if ($app->_canEditAllEntries($e->blog_id)) {
		_mywarn("Returning from canEditEntry with 1 (CAN_EDIT_ALL_BLOGS)");
		$_cache->{perms}->{canEditEntry}{$e->id} = 1;
		return $_cache->{perms}->{canEditEntry}{$e->id} 

    } elsif (exists($_cache->{perms}->{canEditEntry}{$e->id})) {
		_mywarn("(CACHE) Returning from canEditEntry with ".
				$_cache->{perms}->{canEditEntry}{$e->id});
    	return $_cache->{perms}->{canEditEntry}{$e->id};

    } elsif (! $app->_getBlogPermissions($e->blog_id)) {
		_mywarn("(CACHE) Returning from canEditEntry with 0 (No permissions on blog)");
    	$_cache->{perms}->{canEditEntry}{$e->id} = 0;
    	return $_cache->{perms}->{canEditEntry}{$e->id};
    }

	$_cache->{perms}->{canEditEntry}{$e->id} = 
		$_cache->{perms}->{blog}{$e->blog_id}->can_edit_entry($e, $app->{user});
		
	_mywarn("(DB) Returning from canEditEntry with ".
		$_cache->{perms}->{canEditEntry}{$e->id});

	$_cache->{perms}->{canEditEntry}{$e->id};
		
}


sub _canEditAllEntries {
	my $app = shift;
	my $b_id = shift or return $app->error("No blog ID specified for permission check.");

	_mywarn("In canEdirAllEntries with blog ID ".$b_id);

	if (exists($_cache->{perms}->{canEditAllEntries}{$b_id})) {
	_mywarn("(CACHE) Returning from canEdiAllEntries with ".$_cache->{perms}->{canEditAllEntries}{$b_id});
		return $_cache->{perms}->{canEditAllEntries}{$b_id};
    }
		
	if (defined($_cache->{perms}->{blog}{$b_id})) {
		_mywarn("(CACHE) Returning from _canEditAllEntries with perms for blog ID ".$b_id);
		return $_cache->{perms}->{blog}{$b_id};
	} else {
		_mywarn("(DB) Returning from _canEditAllEntries with perms for blog ID ".$b_id);
	    my $perm = $app->_getBlogPermissions($b_id);
	    if ($perm && ref($perm)) {
	        $_cache->{perms}->{canEditAllEntries}{$b_id} = 
 	           $perm->can_edit_all_posts;
		} elsif (defined($perm)) {
			return $perm;
		} else {
			warn "Warning: Could not retrieve permissions for user ID ".$app->{user}->id." on blog ID $b_id.";	
			0;    
		}
	}
}


sub _getBlogPermissions {
	my $app = shift;
	my $id = shift;

	_mywarn("In getBlogPermissions for blog ID $id");

	if (my $p = $_cache->{perms}->{blog}{$id}) {
		_mywarn("(CACHE) Returning permissions for blog ID $id");
		return $p;
	} else {
		_mywarn("(DB) Loading permissions for blog ID $id");
	    require MT::Permission;
	    $_cache->{perms}->{blog}{$id} = MT::Permission->load(
	            {author_id => $app->{user}->id, 
	            blog_id => $id });
	}
}


sub _getUserObjects {
	    
	my $app = shift;
	my $q = $app->{query};
	my ($type,$searchDepth) = @_;

	my $iter;
	if ($type eq 'comment') {
		require MT::Comment;
		$iter = MT::Comment->load_iter({}, { 'sort' => 'created_on', direction => 'descend', limit => $searchDepth});

	} else {
		require MT::TBPing;
		$iter = MT::TBPing->load_iter({}, { 'sort' => 'created_on', direction => 'descend', limit => $searchDepth});
	}

	my $count = 0;
	my @objects;
	while (my $obj = $iter->()) {
		if ($app->_canEditObject($type,$obj)) {
			_mywarn("(DB) Loaded $type ID ".$obj->id);
			push(@objects, $obj);
		}

		last if $searchDepth && ($searchDepth == ++$count);
	}

	return (\@objects);
}





		
sub _extractURLs {

	my $app = shift;
	my @strings = @_;
	
	my @urls;
	foreach (@strings) {
 		next unless ($_ and $_ ne '');
		local $_ = _sanitizeInput($_);
		while (m#http://(?:www.)?([^\s/'">]+)#gi) {
		
			push(@urls,$1);
		}
	}
	my %seen = ();
	my @unique = grep { ! $seen{lc($_)} ++ } @urls; 	
	@unique = sort { lc($a) cmp lc($b) } @unique;

}


sub _stringBreak {

    my $app = shift;
    my ($string,$length) = @_;
    
    return $string unless $length;
    
    
    my @lines = ();
    if (length($string) > $length) {
    	my @chars = split //, $string;
     	while (@chars) {
	     	push(@lines, join('',splice(@chars,0,$length-1)));
     	}
     	$string = join(' ',@lines,join('',@chars));
    }
    
	return $string;
}



sub _navigation_html {

	my $app = shift;
	my ($tagline,$pageclass) = @_;
	my $q = $app->{query};

	$tagline = "- $tagline" if $tagline;
	
	my $styles = _blacklistAppCSS();
 	my $html = <<EOD;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
<title>MT-Blacklist $tagline</title>
$styles
</head>
<body class="$pageclass">
<div id="header">
EOD


    $html .= $q->h1('MT-Blacklist',($_cache->{config}->{'blacklistActive'} ? '' : 'is '.$q->a({-href => '?__mode=config', -style=>'msg_warning'}, 'inactive')));

    my %menu = (
            'List' => {
                'link' => $app->uri,
                title => 'List all blacklist entries'
            },
            'Add' => {
                'link' => '?__mode=add',
                title => 'Add or import blacklist entries'
            },
            'Publish' => {
                'link' => '?__mode=publish',
                title => 'Publish your blacklist'
            },
            'Configure' => {
                'link' => '?__mode=config',
                title => 'Configure MT-Blacklist'
            },
            'De-spam' => {
                'link' => '?__mode=search',
                title => 'De-spam your Movable Type installation'
            },
            'About' => {
                'link' => 'http://www.jayallen.org/comment_spam/',
                title => 'About MT-Blacklist'
            },
            'RESTORE' => {
                'link' => '?__mode=restore&yesImSure=1',
                title => 'Wipe and restore MT-Blacklist'
            },
            'DEBUG' => {
                'link' => '?__mode=debug',
                title => 'Debug MT-Blacklist'
            }
    );
	delete($menu{'Publish'}) if $_cache->{config}->{'autoPublish'}; 
	delete($menu{'DEBUG'}) unless $app->_debug_status() && $app->{user}->can_create_blog; 
	delete($menu{'RESTORE'}) unless $app->_debug_status() && $app->{user}->can_create_blog; 

	my $menulist;
	foreach ('List','Add','De-spam','Publish','Configure','About','RESTORE','DEBUG') {
		next unless exists($menu{$_});
		push(@$menulist, $q->a({href=>$menu{$_}{'link'},
							title=>$menu{$_}{'title'}},
							$_));
	}
		
	$html .= $q->div({id => $menu{'Publish'} ? 'navcontainer' : 'navcontainer_nopublish'},
		$q->ul({id => 'navlist'},$q->li($menulist)));
	$html .= '</div><div id="content">';
	$html;

}

 
sub _debug {

	my $app = shift;	
	return '' unless $app->_debug_status() && $app->{user}->can_create_blog; #JAYBO
 
	unless (@_) {
		my ($package, $filename, $line) = caller(); 
		@_ = ('No debugging info available at '.$package.', line '.$line);
	}
		
	if ((@_ > 1) || ref($_[0])){
	    require Data::Dumper;
        return '<pre style="background: #eee;border:1px solid #ccc;text-align:left;">'.Data::Dumper::Dumper(@_).'</pre>';
    } else {
		return '<p style="background: #eee;border:1px solid #ccc;text-align:left;">'.(shift).'</p>';
    }
}

sub _debug_status { 

	my $app = shift;
	if (my $status = shift) { 
	
		$app->{debug_status} = $status;
    }
	$app->{debug_status};
}

sub _getTimestamp {
    use MT::Util;
    my @ts = MT::Util::offset_time_list(time);
    my $ts = sprintf '%04d%02d%02d%02d%02d%02d',
    	$ts[5]+1900, $ts[4]+1, @ts[3,2,1,0];
	$ts;
}


sub _getBlacklistMasthead {
 
return <<EOD
#
#	MT-Blacklist Version $VERSION
#
#   Last update:        {TIMESTAMP}
#   Number of entries:  {NUM_ENTRIES}
#
#   You can find out more about this file at:
#    http://www.jayallen.org/comment_spam/
#
#   You can find out more about MT-Blacklist at
#   http://www.jayallen.org/projects/mt-blacklist
#

EOD
}

sub _blacklistAppCSS {
return <<EOD;

<style type="text/css" media="screen">
/* <![CDATA[ */

/* 
	Menu bar with List-o-matic
	http://www.accessify.com/tools-and-wizards/list-o-matic
	
	General styles lovingly stolen 
	from Dean Allen's Refer.
	http://www.textism.com/tools/refer/
*/

body {
	text-align: center;
	background: #fff;
	color: #000;
	}
h1,h2,h3,h4,h5,h6  {
	font-family: Verdana, Trebuchet;
	margin-bottom: 0px;
	}
h1 { margin-top: 10px; }
h1 a { background: inherit; color: #f00;}
td {
	padding: 0 10px 0 0;
	color: black;
	font-family: Verdana;
	font-size: 10px;
	line-height: 20px;
	border-bottom: #dddddd;
	border-width: 0 0 1px 0;
	border-style: none none solid none;
	}
td.noline {
	border: 0;
	}
thead { font-weight: bold; }

p {
	font-family: Verdana, Trebuchet;
	font-size: small;
	line-height: 150%;
	}
code { font-size: medium; }

a {
	color: olive;
	text-decoration: none;
	}
a:hover { text-decoration: underline; }

a.helplink {
	font-size: 90%;
	font-weight: bold;
	}
input.text,textarea.text {
	border-color: gray white white gray;
	padding: 2px;
	}
textarea, select {
	font-family: Verdana;
	font-size: 10px;
	background-color: #eee;
	border-color: white gray gray white;
	border-width: 1px;
	border-style: solid;
	padding: 5px;
	}
input.white {
	background-color: #fff;
	border: 0;
	}
.right { text-align:right; }
.even { background: #ccc; }
.odd { background: #eee; }

/* ***************
 * SPECIFIC STYLES
 * ************* */

div#header {
	text-align: center;
	padding-bottom: 20px;
	}
div#content {
	clear: both;
	text-align: left;
	width: 500px;
	margin: 0 auto;
	}
div#versiontag {
	font-size:11px;
	color: #aaa;
	background: inherit;
	text-align: center;
	}	
/* MSG STYLES */
.msg_success {color: #0a0;}
.msg_failure {color: #f00;}
.msg_warning {color: #f90;}
.msg_info {color: #069;}

/* MSG BOXES */
p.msg_success, div.msg_success {
	border: 1px solid #cfc;
	background: inherit;
	}
p.msg_failure, div.msg_failure {
	border: 1px solid #fcc;
	background: inherit;
	}
p.msg_warning, div.msg_warning {
	border: 1px solid #fc9;
	background: inherit;
	}
p.msg_info, div.msg_info {
	border: 1px solid #369;
	background: inherit;
	}
	
	
/*LIST PAGE - Default view */
body.listpage div#content {
	text-align: center;
	width: 600px;
	}
body.listpage table {
	width: 600px;
	margin: 0px auto;
	text-align:left;
	}
body.listpage table th {
	text-align:left;
	}
body.listpage table td {
	vertical-align: top;
	text-align:left;
	}
body.listpage table td.right  {
	text-align:right;
	}
body.listpage table td.highlight {
	background:#ccf;
	}

/* VIEW PAGE */
body.viewpage div#content {
	text-align: center;
	}
body.viewpage table {
	margin: 20px auto;
	}
body.viewpage th {
	text-align: left;
	font-weight: bold;
	}
body.viewpage th.prevlink {
	text-align: left;
	font-weight: normal;
	}
body.viewpage th.nextlink {
	text-align: right;
	font-weight: normal;
	}
body.viewpage th.entryString {
	text-align: center;
	background: #ccc;
	color: #000;
	}
body.viewpage form {
	text-align: center;
	}

/* CONFIG PAGE */
body.configpage {
	text-align: center;
	}
body.configpage div#restoreform {
	padding: 0 10px;
	border: 1px solid #000;
	background: #c66;
	color: #000;
	}
body.configpage p.question {
	font-weight: bold;
	margin-bottom: 0px;
	}
body.configpage table#actiontable {
	width: 95%;
	}
/*
body.configpage table#actiontable tr.topheader {

	}
body.configpage table#actiontable tr.bottomheader {

	}
*/
body.configpage table#actiontable th.blognames {
	text-align:left;
	}
body.configpage table#actiontable td {
	text-align:center;
	}
.description {
	margin-top: 0px;
	font-size: x-small;
	background: inherit;
	color: #666;
	}

/* DESPAM PAGE */
body.despampage div.msg_info,
body.despampage div.msg_warning,
body.despampage div.msg_success,
body.despampage div.msg_failure {
	text-align: center;
	padding: 0 40px;
	}
body.despampage ul {
    margin: 10px 40px;
    padding: 0;
    border: none;
    text-align:left;
	}
	
/* PUBLISH PAGE */
body.publishpage form {
	text-align: center;
	}
	
body.searchpage div.searchbox {
	margin-top: 20px;
	background: #eee;
	color: inherit;
	border: 1px solid #999;
	padding: 5px;
	text-align: center;
	}	

/* *************
 * NAV MENU
 * *********** */

div#navcontainer {
    width: 395px; 
    margin: 0 auto;
    padding: 0;
    text-align:center;
	}
div#navcontainer_nopublish {
    width: 325px;
    margin: 0 auto;
    padding: 0;
    text-align:center;
	}
ul#navlist {
    list-style: none;
    margin: 0;
    padding: 0;
    border: none;
	}
ul#navlist li {
    display: block;
    margin: 0;
    padding: 0;
    float: left;
    width: auto;
	}
ul#navlist a {
    color: #444;
    display: block;
    width: auto;
    text-decoration: none;
    background: #DDDDDD;
    margin: 0;
    padding: 2px 10px;
    border-left: 1px solid #fff;
    border-top: 1px solid #fff;
    border-right: 1px solid #aaa;
	}

ul#navlist a:hover, ul#navlist a:active { background: #BBBBBB; }

ul#navlist a.active:link, ul#navlist a.active:visited {
    position: relative;
    z-index: 102;
    background: #BBBBBB;
    font-weight: bold;
	}


/* ]]> */
</style>

EOD
}











# #####################################
#
#
#  METHODS USED BY BOTH APP AND PLUGIN
#
#
# #####################################



sub _getBlacklist { 

	# This function is used by both 
	# the plugin and the application

	# Return cached data if exists
	return $_cache->{blacklist} if $_cache->{blacklist} && @{$_cache->{blacklist}};

	my $list = _getBlacklistData('blacklist');

    # Within the application the blacklist will
    # always have a dummy first entry at index 0.
    # When it is saved, it is stripped from the array.
	while (@{$list} && ($list->[0]->{string} eq '')) { shift(@{$list}); }
    unshift(@{$list}, {string => ''});

	# Cache the data
    $_cache->{blacklist} = $list;
    
    $list;
}
 
 
sub _getConfig { 

	# This function is used by both 
	# the plugin and the application

	# Return cached data if exists
	return $_cache->{config} if $_cache->{config};

	my $config = _getBlacklistData('config');

	# Cache the data
    $_cache->{config} = $config;

	$config or return;
}


sub _getBlacklistData {

	# This function is used by both 
	# the plugin and the application

    my $key = shift;

    if ($blacklist_config_directory && ($blacklist_config_directory ne '')) {
    	my $file = $blacklist_config_directory."/$key.yaml";
    	$file =~ s#//#/#g;
		require Yaml; 
		return unless -e $file;
		$_cache->{$key} = YAML::LoadFile($file)
			or return; 
    } else {
        my $data = _getPluginDataObject($key);
        return $data->data if $data;
    }
}


sub _getPluginDataObject {

	# This function is used by both 
	# the plugin and the application

    my $key = shift;
	_mywarn("In getPluginDataObject for $key");
	if ($_cache->{plugindataobject}{$key}) {
		_mywarn("(CACHE) Returning from _getPluginDataObject $key PluginDataObject");
		$_cache->{plugindataobject}{$key};
    } else {
		require MT::PluginData;
		_mywarn("(DB) Returning from _getPluginDataObject $key PluginDataObject");
        $_cache->{plugindataobject}{$key} = MT::PluginData->load ({ plugin => 'Blacklist', 
                                            key => $key });
    }
}



sub _getEntry {
    my $id = shift;
	_mywarn("In _getEntry with entry ID $id");

    if (my $e = $_cache->{entry}->{$id}) {
		_mywarn("(CACHE) Returning from _getEntry entry ID $id\n");
    	return $e ;
    }
		_mywarn("(DB) Loading from _getEntry entry ID $id\n");
	require MT::Entry;
    $_cache->{entry}->{$id} = MT::Entry->load($id);
}

sub _getTrackback {
    my $id = shift;
	_mywarn("In loadTrackback with trackback ID $id from caller");

    if (my $trackback = $_cache->{trackback}->{$id}) {
		_mywarn("(CACHE) Returning trackback ID $id\n");
    	return $trackback ;
    }
	_mywarn("(DB) Loading trackback ID $id\n");
	require MT::Trackback;
    $_cache->{trackback}->{$id} = MT::Trackback->load($id);
}

sub _getObjectEntry {
	my ($type,$object) = @_;
	
	if ($type eq 'comment') {
		_getCommentEntry($object);
	} elsif ($type eq 'ping') {
		_getPingEntry($object);
	} else {
		die "Unknown object type in _getObjectEntry";
	}
}

sub _getCommentEntry {
	my $c = shift;

	my $entry = _getEntry($c->entry_id);

}

sub _getPingEntry {
	my $p = shift;

	my $tb = _getTrackback($p->tb_id);
	my $entry = _getEntry($tb->entry_id);
}

sub _getBlog {
    my $id = shift;
	_mywarn("In loadBlog with Blog ID ".$id);

	if (my $b = $_cache->{blog}->{$id}) {
		_mywarn("(CACHE) Returning blog ID $id");
	    return $b;
	} else {
		_mywarn("(DB) Returning blog ID $id");
		require MT::Blog;
	    $_cache->{blog}->{$id} = MT::Blog->load($id);
    }
}

sub _getBlogs {
	require MT::Blog;

	_mywarn("In loadBlogs");
	if ($_cache->{blogs_loaded}) {
		_mywarn("(CACHE) Returning blogs");
		return $_cache->{blog};
	} else {
		_mywarn("(DB) Returning blogs");
	    my @blogs = MT::Blog->load();
		$_cache->{blogs_loaded}++;
	    %{$_cache->{blog}} = map { $_->id, $_ } @blogs;
    	$_cache->{blog};
	}
}















# #####################################
#
#
#  START OF MT-BLACKLIST PLUGIN METHODS
#
#
# #####################################


#
# _matchBlacklist method
#
# Here we match blacklisted strings against the user input.
# Plain strings and regular expressions are allowed.  Nothing
# needs to be escaped as far as I know since our delimiters
# and regular expression metacharaters are mutually exclusive 
# aside from the period which makes no difference.
#
sub _matchBlacklist {

    my (@strings, @blacklisted_strings, $str, $deny);

    my $blog_id = shift;
    @strings = @_;

    # Read in config
    my $config;
    $config = _getConfig();

	my $query = $ENV{QUERY_STRING} || $ENV{REQUEST_URI} || '';
    unless ($query =~ m/__mode=search/) {
        return unless $config && $config->{'blacklistActive'};
    }

    # Sanitize text
    $str = _sanitizeInput(join(' ', @strings));
    return unless $str =~ /\S/;

    # Build combined pattern
    unless ($_cache->{pattern}) {
        # Read in blacklist
        @blacklisted_strings = _readBlacklist();
        shift(@blacklisted_strings);
        $_cache->{pattern} = join('|', @blacklisted_strings);
    }

    # Match against pattern in one expression
    return unless $str =~ m#$_cache->{pattern}#io;
	my $matched_string = $&;
    
    # We match an entry, find out which one it was
    @blacklisted_strings = _readBlacklist();
    shift(@blacklisted_strings);
    # Match against blacklist
    foreach my $blacklist_string (@blacklisted_strings) {
        if ($str =~ m#$blacklist_string#i) {
            return (1,$blacklist_string,$matched_string,$config->{denyResponse});
        }
    }

    # We should never get here...
	return;
}






#
# Read blacklist
#
# This subroutine doesn't READ the blacklist so 
# much as it transforms it into a simple array 
# of strings/regexps
sub _readBlacklist {
	
    return map { $_->{'string'}} @{ _getBlacklist() }; 
}



#
# Sanitize user input
#
# Here, we sanitize the user input to prevent spammers 
# from trying to circumvent matching.  I'm sure that 
# this will grow over time as spammers attempt to 
# prove that the are smarter than the thousands
# of highly connected people that they are pissing off.
sub _sanitizeInput {

	my $str = shift;
	
	# Remove any HTML comments in the form of <! ... >
	$str =~ s/\x3c\!.+?\x3e//g;

	#
	#THANKS to Stepan Riha for the next three
    # Convert decimal entities (&#112; => p)
    $str =~ s/&#(\d{1,3});/chr($1)/eg;

    # Convert hex entities (&#x70; => p)
    $str =~ s/&#x(\d{2});/chr(hex($1))/eg;

    # Convert URL encodings (%70 => p)
    $str =~ s/\%([0-9A-Z]{2})/chr(hex($1))/eig;

	# Remove any #'s since we will be using it as a delimiter
	# This is safe since it isn't something that would
	# be included in a blacklist.
	$str =~ tr/#//d; 
	
	return $str;
}



sub _mywarn {

    my $warning = shift;
    
    push(@_warnings, $warning);
    
}

sub _dumpwarn {
my $app = shift;
    $app->_debug_status(1);
    return $app->_debug(join("<br />\n", @_warnings)); 
}


1;

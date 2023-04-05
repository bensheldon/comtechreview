#!/usr/bin/perl -w
# Copyright 2003 Stepan Riha. This code cannot be redistributed without
# permission from www.nonplus.net.

package MTMedic;
use strict;

## BEGIN CONFIGURATION

## ADMIN_PASSWORD gives you full access to MT-Medic, including changing the MovableType database, such as resetting passwords
my $ADMIN_PASSWORD = "Nelson";

## INFO_PASSWORD gives you only access to viewing cofiguration and plugin listings
## You can specify the INFO_PASSWORD if some third party is helping you debug your MT installation.
my $INFO_PASSWORD = "";

## END CONFIGURATION

## DO NOT EDIT BELOW THIS LINE

=head1 Version History

	1.34: September 29, 2003

	Added "Add Author".

	1.3.3: June 15, 2003

	Improved plugins listing:
		Catches more plugin warnings (that's right, I've discovered $SIG{__WARN__}).
		Highlights warnings and errors.
		Adds links to plugin sources.

	1.3.2: June 12, 2003

	Fixed plugin error reporting when errors come from another module.
	Fixed parsing and UI when script is installed under a name other than mt-medic.cgi
	Fixed error when using on an installation that doesn't have any blogs with entries with comments.

	1.3.1: June 1, 2003

	Sort configurations (and other stuff) aplhabetically.
	Fixed "Can't use an undefined value as an ARRAY reference" error when not using custom templates

	1.3: May 16, 2003

	Added support for viewing filter effects.
	Added plugin source listing for plugins with errors.

	1.2.2: May 14, 2003

	Fix plugin parsing to ignore text in POD, comments, strings and beyond __END__.
	Added checking of "use" dependencies.

	1.2.1: May 9, 2003

	Removed hardcoded password.

	1.2: May 8, 2003

	Changed plugin listing to display filter and text-filter effects and to display
	tag values, when possible. Plugins are parsed for $VERSION information and "require"
	dependencies are checked.
	Added general authors configuration and blog listings. 
	Added blog authoring permissions configuration.

	1.1: April 28, 2003

	Changed password protection to use $INFO_PASSWORD for config and plugin listings
	and $ADMIN_PASSWORD for admin stuff.

	1.0: April 28, 2003

	Added configuration listing. Changed logged-in warning on bottom of page.

	0.9: April 26, 2003
	
	Original release.

=cut

use vars qw( $VERSION );
my $VERSION = '1.34';

my($MT_DIR, $CAN_EDIT, $CAN_VIEW, $q, $MODE, $URL);

BEGIN {
    if ($0 =~ m!(.*[/\\])!) {
        $MT_DIR = $1;
    } else {
        $MT_DIR = './';
    }
    unshift @INC, $MT_DIR . 'lib';
    unshift @INC, $MT_DIR . 'extlib';
	$CAN_EDIT = $CAN_VIEW = 0;
}

if(@ARGV) {
#	print join("\n", @ARGV) . "\n";
	while(my $v = shift(@ARGV)) {
		if($v eq '-plugin') {
			my $plugin = shift(@ARGV);
			print "$plugin\n";
			eval {
				require "$plugin";
			};

			if($@) {
				print "ERROR\n$@";
			} else {
				foreach my $tag (sort keys %MT::Template::Context::Global_filters) {
					print "filter $tag\n";
				}

				foreach my $tag (sort keys %MT::Template::Context::Global_handlers) {
					print $MT::Template::Context::Global_handlers{$tag}->{is_container}?'container':'tag';
					print " $tag\n";
				}

				foreach my $tag (sort keys %MT::Text_filters) {
					print "text_filter $tag\n";
				}
			}

			exit 1;
		} elsif($v eq '-plugins') {
			my $plugin_dir = $MT_DIR."plugins";
			print_plugins_info($plugin_dir);
			exit 1;
		} else {
			print "Uknown parameter: $v\n";
		}
	}
}

local $| = 1;
my %config =
	(
		'' => {
						title => 'About',
						access => 'clear'
			},
		blank => {
						title => '',
						access => 'clear'
			},
		login => {
						title => 'Login',
						access => 'clear'
			},
		logout => {
						title => 'Logout',
						access => 'clear'
			},
		config => {
						title => 'Configuration',
						access => 'view'
			},
		plugins => {
						title => 'Plugins',
						access => 'view'
			},
		filters => {
						title => 'Filters',
						access => 'view'
			},
		permissions => {
						title => 'Permissions',
						access => 'edit'
			},
		authors => {
						title => 'Authors',
						access => 'edit'
			},
		blogs => {
						title => 'Blogs',
						access => 'edit'
			},
		source => {
						title => 'Plugin Source',
						access => 'view',
						popup => 1
			}
	);
			
$URL = "";

eval {
	require CGI;
	$q = CGI->new;
	$MODE = $q->param('mode') || '';
	$URL = $q->url;
	
	$CAN_EDIT = 0;
	my $cookie = [];
	if($MODE eq 'logout') {
		$cookie = [ expiration_cookie() ];
	} elsif($MODE eq 'login' && $q->param('password') && ($ADMIN_PASSWORD || $INFO_PASSWORD)) {
		my $password = $q->param('password');
		my $crypt_password;
		$CAN_EDIT = $CAN_VIEW = ($password eq $ADMIN_PASSWORD);
		$CAN_VIEW = ($password eq $INFO_PASSWORD) unless $CAN_VIEW;
		if($password && $CAN_VIEW) {
			my @alpha = ('a'..'z', 'A'..'Z', 0..9);
			my $salt = join '', map $alpha[rand @alpha], 1..2;
			$crypt_password = crypt($password, $salt);
			$cookie = [ $q->cookie(
								-name=>'medic_password',
								-value=>$crypt_password) ];
		} else {
			$cookie = [ expiration_cookie() ];
		}
	} elsif(my $crypt_password = $q->cookie('medic_password')) {
		$CAN_EDIT = $CAN_VIEW = (crypt($ADMIN_PASSWORD, $crypt_password) eq $crypt_password);
		$CAN_VIEW = (crypt($INFO_PASSWORD, $crypt_password) eq $crypt_password) unless $CAN_VIEW;
	}

	if($MODE eq 'filters') {
		if($q->param('submit')) {
			push @$cookie, $q->cookie(
				-name=>'medic_filter',
				-value=>$q->param('filter'),
				-expires=>'+100d');

			push @$cookie, $q->cookie(
				-name=>'medic_filter_text',
				-value=>$q->param('text'),
				-expires=>'+100d');
			
			push @$cookie, $q->cookie(
				-name=>'medic_filter_val',
				-value=>$q->param('filter_val'),
				-expires=>'+100d');

			my $render = $q->param('render') ? $q->param('render') : '';
			push @$cookie, $q->cookie(
				-name=> 'medic_filter_render',
				-value=> $render,
				-expires => $render ? '+100d' : '-1d');
		} else {
			$q->param('filter', $q->cookie('medic_filter'));
			$q->param('text', $q->cookie('medic_filter_text'));
			$q->param('filter_val', $q->cookie('medic_filter_val'));
			$q->param('render', $q->cookie('medic_filter_render'));
		}
	}
	
	if($cookie) {
		print $q->header(-cookie=>$cookie, -type=>'text/html');
	} else {
		print $q->header(-type=>'text/html');
	}
};

## Print header
my $_MODE = $q->param('_mode')||$MODE;
my $title = ($config{$_MODE} || $config{''})->{title};
print html_head("MT-Medic: " . $title);

eval {

	if(!$config{$MODE}->{popup}) {
		## Print navigation
		print <<HTML;
<div>
<table width="100%" border="0" cellspacing="0" cellpadding="0">
<tr><td>
<font class="pagetitle">
<a href="$URL">MT-Medic</a>: 
<a href="$URL?mode=config">Configuration</a> |
<a href="$URL?mode=plugins">Plugins</a> |
<a href="$URL?mode=filters">Filters</a> ||
<a href="$URL?mode=authors">Authors</a> |
<a href="$URL?mode=blogs">Blogs</a> |
<a href="$URL?mode=permissions">Permissions</a>
</font>
</td><td align="right">
HTML

		if($CAN_EDIT || $CAN_VIEW) {
			my $title = $CAN_EDIT ? 'ADMINISTRATOR' : 'INFO';
		print <<HTML;
[<a href="$URL?mode=logout">Logout</a> - $title]
HTML
		} else {
		print <<HTML;
[<a href="$URL?mode=login">Login</a>]
HTML
		}

		print <<HTML;
</td></tr></table>
</div>
<hr />
HTML

		print '<div><font class="pagetitle">' . $config{$_MODE}->{title} . '</font></div>';

		if($MODE eq 'login') {
			$MODE = login_handler($q, $_MODE, $config{$_MODE}->{access});
		} elsif($MODE eq 'logout') {
			$MODE = logout_handler($q);
		}
	}
	my $cfg = $config{$MODE} || $config{''};
	if($cfg->{access} eq 'edit' && !$CAN_EDIT
		|| $cfg->{access} eq 'view' && !$CAN_VIEW) {
		die "You must be logged in to view this page" if $config{$MODE}->{popup};
		login_handler($q, $_MODE, $cfg->{access});
	} elsif($MODE eq 'plugins') {
		plugins_handler($q);
	} elsif($MODE eq 'filters') {
		filters_handler($q);
	} elsif($MODE eq 'config') {
		config_handler($q);
	} elsif($MODE eq 'permissions') {
		permissions_handler($q);
	} elsif($MODE eq 'authors') {
		authors_handler($q);
	} elsif($MODE eq 'blogs') {
		blogs_handler($q);
	} elsif($MODE eq 'source') {
		source_handler($q);
	} elsif($MODE eq 'blank') {
	} else {
		default_handler($q);
	}

};

if ($@) {
    print <<HTML;
<pre class="error">
An error occurred:

$@
</pre>
HTML
}

	my $warning = edit_warning();
	print <<HTML unless ($config{$MODE}->{popup});
$warning
<div>
<a href="http://www.nonplus.net/software/mt/MT-Medic.htm">MT-Medic</a> $VERSION - &copy; 2003 Stepan Riha
</div>
HTML
	print <<HTML;
</body>
</html>
HTML


sub expiration_cookie {
	my $cookie = $q->cookie(
		-name=>'medic_password',
		-value=>'',
		-expires=>'-1d');
}

sub print_warning {
	my ($line, $warning) = @_;
	$line ||= 0;
	print "WARNING $line\n$warning\n========\n";
}

sub print_plugins_info {
	my ($plugin_dir) = @_;
	
	local *DH;
	if (opendir DH, $plugin_dir) {
		my @p = readdir DH;
		closedir DH;
		for my $plugin (@p) {
			next if $plugin !~ /\.pl$/;
			my @warnings;
			eval {
				use File::Spec;
				$plugin = File::Spec->catfile($plugin_dir, $plugin);
				if ($plugin =~ /^([-\\\/\@\:\w\.\s]+)$/) {
					$plugin = $1;
				} else {
					die "Bad plugin filename '$plugin'";
				}

				%MT::Template::Context::Global_handlers = ();
				%MT::Template::Context::Global_filters = ();
				%MT::Text_filters = ();
				{
					## Catch warnings
					local $SIG{__WARN__} = sub {
						push @warnings, $_[0];
					};
					require "$plugin";
				}
			};
			## Remember error, if any
			my $plugin_error = $@;

			print "PLUGIN $plugin\n";
			my $errors = parse_errors($plugin, $plugin_error);
			if($plugin_error) {				
				foreach my $line (sort keys %$errors) {
					$plugin_error = $errors->{$line};
					print "ERROR $line\n$plugin_error\n========\n";
				}
			}

			my $warnings = parse_warnings($plugin, \@warnings);
			foreach my $line (sort keys %$warnings) {
				my $warning = $warnings->{$line};
				print "WARNING $line\n$warning\n========\n";
			}

			process_plugin($plugin, \&listing_callback,  $errors, $warnings);
			
			if(!$plugin_error) {
				foreach my $tag (sort keys %MT::Template::Context::Global_filters) {
					print "filter $tag\n";
				}

				foreach my $tag (sort keys %MT::Template::Context::Global_handlers) {
					print $MT::Template::Context::Global_handlers{$tag}->{is_container}?'container':'tag';
					print " $tag\n";
				}

				foreach my $tag (sort keys %MT::Text_filters) {
					print "text_filter $tag\n";
				}
			}
		}
	}			
}

sub login_handler {
	my $q = shift;
	my $_mode = shift;
	my $type = shift || 'edit';
	
	$type = 'edit' if($q->param('admin'));
	
#	print "$_mode $type\n";
	
	if(!$ADMIN_PASSWORD && $type ne 'view') {
		print <<HTML;
<div class="error-message">
You cannot log in to MT-Medic untill you have specified the \$ADMIN_PASSWORD in
the configuration section of the $0 file.
</div>
HTML
		return 'blank';
	}
	if(!($ADMIN_PASSWORD || $INFO_PASSWORD)) {
		print <<HTML;
<div class="error-message">
You cannot log in to MT-Medic untill you have specified the \$ADMIN_PASSWORD or \$INFO_PASSWORD in
the configuration section of the $0 file.
</div>
HTML
		return 'blank';
	}
	
	if($CAN_EDIT || $type eq 'view' && $CAN_VIEW) {
		print <<HTML;
<div class="message">
You have successfully logged in.
</div>
HTML
		return $q->param('_mode');
	} else {
		print <<HTML if $q->param('password');
<div class="error-message">
Incorrect password.  You can change your MT-Medic passwords in the
$0 file.
</div>
HTML
		print <<HTML;
<div class="form">
<form>
<table border="0" cellspacing="0" cellpadding="0">
<tr><td nowrap><font class="title">Please enter your MT-Medic password:
</td><td>
<input type="password" name="password" size="20">
</td></tr>
<tr><td>&nbsp;</td><td>
<input class="button-big" type="submit" value="Login">
<input type="hidden" name="mode" value="login">
<input type="hidden" name="_mode" value="$_mode">
</td></tr>
</table>
</form>
</div>
HTML
	}
	
	'blank';
}

sub logout_handler {
	print <<HTML;
<div class="message">
You have successfully logged out.
</div>
HTML
}

sub permissions_handler {
	my $q = shift;

	## Get MT instance
	my $mt = new_mt();

	use MT::Author;
	use MT::Blog;
	use MT::Permission;

	my $blog;
	my $author;
	my @items;
	my $title;
	my ($type, $id);
	if($q->{blog_id}) {
		$id = shift(@{$q->{blog_id}});
		$blog = MT::Blog->load($id)
			or die "Invalid blog id '$id'";
		my $name = $blog->name;
		$type = 'blog';
		@items = MT::Author->load();
		$title = "Weblog: $name - Author";
	} elsif($q->{author_id}) {
		$id = shift(@{$q->{author_id}});
		$author = MT::Author->load($id)
			or die "Invalid author id '$id'";
		my $name = $author->name;
		$type = 'author';
		@items = MT::Blog->load();
		$title = "Author: $name - Weblog";
	} else {
		print <<HTML;
<div class="form">
<table>
<tr>
<td>
<select class="blog" name="new_author_id"
onchange='window.location =(new_author_id.options[new_author_id.selectedIndex].value)'>
<option value='$URL' selected>[ Select an Author ]</option>
HTML

	my @authors = MT::Author->load();
	foreach my $a (sort { $a->name cmp $b->name } @authors) {
		my ($id, $name) = ($a->id, escapeHTML($a->name));
		print <<HTML;
<option value='$URL?mode=permissions&author_id=$id'>$name</option>
HTML
	}
	print <<HTML;
</select>
</td>
<td>
Select an author from this menu to specify the editing
permissions on all blogs in your installation.
</td>
</tr>

<tr>
<td>
<select class="blog" name="new_blog_id"
onchange='window.location =(new_blog_id.options[new_blog_id.selectedIndex].value)'>
<option value='$URL' selected>[ Select a Blog ]</option>
HTML

	my @blogs = MT::Blog->load();
	foreach my $a (sort { $a->name cmp $b->name } @blogs) {
		my ($id, $name) = ($a->id, escapeHTML($a->name));
		print <<HTML;
<option value='$URL?mode=permissions&blog_id=$id'>$name</option>
HTML
	}

	print <<HTML;
</select>
</td>
<td>
Select a blog from the menu to specify the editing
permissions for all authors in your installation.
</td>
</tr>
</table>
</div>
HTML
		return;
	}

	if($q->{save}) {
		my $count = 0;
		foreach my $item (@items) {
			my ($id, $name) = ($item->id, $item->name);
			my $mask = 0;
			if(my $perms = $q->{"item_$id"}) {
				foreach my $perm (@$perms) {
					$mask |= $perm;
				}
			}
			my $perm = MT::Permission->load( { author_id => $author ? $author->id : $id,
												blog_id => $blog ? $blog->id : $id });
			if(!$perm && $mask) {
				$perm = MT::Permission->new;
				$perm->blog_id($blog ? $blog->id : $id);
				$perm->author_id($author ? $author->id : $id);
			}
			if($perm && $perm->role_mask != $mask) {
				$perm->role_mask($mask);
				$mask ? $perm->save : $perm->remove;
				$count++;
			}
		}

		print <<HTML if $count;
<div class="message">
Permissions have been updated on $count items.
</div>
HTML
		print <<HTML if !$count;
<div class="message">
No permissions changed.
</div>
HTML
	}

	print <<HTML;
<div class="form">
<form method="post" action="$URL">
HTML

	my $row;
	foreach my $item (sort { $a->name cmp $b->name } @items) {
		my ($id, $name) = ($item->id, $item->name);
		my $perm = MT::Permission->load( { author_id => $author ? $author->id : $id,
											blog_id => $blog ? $blog->id : $id })
					|| MT::Permission->new;
		my $color = row_color($row++);
		print <<HTML;
<div style="background: $color">
<font class="pagetitle">$title: $name</font>
<table>
	<tr>
HTML
		my @perms = @{MT::Permission::perms()};
		my $cols = int(scalar(@perms)/2);
		while (@perms) {
			print <<HTML;
<td><table>
HTML
			for(my $col = 0; $col < $cols; $col++) {
				my $perms = shift(@perms);
				my ($val, $attr, $name) = @$perms;
				my $checked = ($perm->role_mask & $val) ? 'checked ' : '';
				print <<HTML;
<tr>
	<td><input type="checkbox" name="item_$id" value="$val" $checked/>&nbsp;<font class="bold-label">$name</font></td></tr>
HTML
				last unless @perms;
			}

			print <<HTML;
	</table>
	</td>
HTML
		}
		print <<HTML;
<td>
<table>
<tr>
<td>
<input type="button" class="button" name="CheckAll" value="Check All" onClick="checkAll(item_$id, true)">
</td>
</tr>
<tr>
<td>
<input type="button" class="button" name="CheckAll" value="Uncheck All" onClick="checkAll(item_$id, false)">
</td>
</tr>
</table>
</td>
	</tr></table>
</div>
HTML
	}

	my $color = row_color($row++);
	print <<HTML;
<div style="background: $color">
<input class="button-big" type="submit" value="Save Changes">
<font class="pagetitle">&nbsp;&nbsp;-&nbsp;&nbsp;or&nbsp;&nbsp;-&nbsp;&nbsp;</font>
<select class="blog" name="new_author_id"
onchange='window.location =(new_author_id.options[new_author_id.selectedIndex].value)'>
<option value='0'>[ Pick another Author ]</option>
HTML

	my @authors = MT::Author->load();
	foreach my $a ( sort { $a->name cmp $b->name } @authors) {
		my ($id, $name) = ($a->id, escapeHTML($a->name));
		print <<HTML;
<option value='$URL?mode=permissions&author_id=$id'>$name</option>
HTML
	}
	print <<HTML;
</select>
<font class="pagetitle">&nbsp;&nbsp;or&nbsp;&nbsp;</font>
<select class="blog" name="new_blog_id"
onchange='window.location =(new_blog_id.options[new_blog_id.selectedIndex].value)'>
<option value='0'>[ Pick another Blog ]</option>
HTML

	my @blogs = MT::Blog->load();
	foreach my $a ( sort { $a->name cmp $b->name } @blogs) {
		my ($id, $name) = ($a->id, escapeHTML($a->name));
		print <<HTML;
<option value='$URL?mode=permissions&blog_id=$id'>$name</option>
HTML
	}

	print <<HTML;
</select>
<input type="hidden" name="mode" value="permissions">
<input type="hidden" name="save" value="1">
<input type="hidden" name="type" value="$type">
<input type="hidden" name="${type}_id" value="$id">
</div>
</form>
</div>
HTML
}

sub authors_handler {
	my $q = shift;

	## Get MT instance
	my $mt = new_mt();

	use MT::Author;
	my $author;
	if($q->{author_id} && $q->{save}) {
		my $author_id = shift(@{$q->{author_id}});
		## Load author
		my $author = MT::Author->load($author_id) or die "Invalid author id '" . $author_id . "'";
		my $err;
		$author = MT::Author->new() if($author->id ne $author_id);

		$author->name(shift @{$q->{name}});
		$author->nickname(shift @{$q->{nickname}});
		$author->email(shift @{$q->{email}});
		$author->url(shift @{$q->{url}});
		$author->hint(shift @{$q->{hint}});
		$author->created_by(shift @{$q->{created_by}});
		$author->can_create_blog($q->{can_create_blog} ? 1 : 0);
		$author->can_view_log($q->{can_view_log} ? 1 : 0);
		if(my ($password, $password_conf) = (@{$q->{password}}, @{$q->{password_conf}})) {
			if($password && $password eq $password_conf) {
				$author->set_password($password);
			} elsif($password) {
				$err = "Passwords do not match!";
				$q->{edit} = 1;
			}
		}

		if($err) {
			print <<HTML;
<div class="error-message">
$err
</div>
HTML
		} else {
			$author->save;
			my ($name) = ($author->name);

			print <<HTML;
<div class="message">
The profile of author $name has been updated.
</div>
HTML
		}
	}
	
	if($q->{author_id} && $q->{edit} || $q->{new}) {
		my $author_id = $q->{new} ? 0 : shift(@{$q->{author_id}});

		## Load author
		if($q->{new}) {
			$author = MT::Author->new();
		} else {
			$author = MT::Author->load($author_id) or die "Invalid author id '" . $author_id . "'" unless $author;
		}
		my ($name, $nickname, $email, $url, $hint, $can_create_blog, $can_view_log)
				= ($author->name, $author->nickname, $author->email, $author->url, $author->hint,
					$author->can_create_blog ? 'CHECKED' : '',
					$author->can_view_log ? 'CHECKED' : '');

		print <<HTML;
<div class="form">
<form method="post" action="$URL">
<table border="0" cellspacing="0" cellpadding="0">
<tr>
<td valign="top">

<table border="0" cellspacing="0" cellpadding="0">

<tr><td nowrap><font class="pagetitle">Author Information</font></td></tr>

<tr><td nowrap>
<font class="title">Username</font><br />
<input class="text-short" name="name" value="$name">
</td></tr>
<tr><td nowrap>
<font class="title">Nickname</font><br />
<input class="text-short" name="nickname" value="$nickname">
</td></tr>
<tr><td nowrap>
<font class="title">Email Address</font><br />
<input class="text-short" name="email" value="$email">
</td></tr>
<tr><td nowrap>
<font class="title">Website URL (optional)</font><br />
<input class="text-short" name="url" value="$url">
</td></tr>

<tr><td nowrap><hr /><font class="pagetitle">Password change</font></td></tr>

<tr><td nowrap>
<font class="title">Password</font><br />
<input class="text-short" name="password" value="">
</td></tr>
<tr><td nowrap>
<font class="title">Password confirm</font><br />
<input class="text-short" name="password_conf" value="">
</td></tr>

<tr><td nowrap><hr /><font class="pagetitle">For Password Recovery</font></td></tr>

<tr><td nowrap>
<font class="title">Birthplace</font><br />
<input class="text-short" name="hint" value="$hint">
</td></tr>
<tr><td>
<hr />
<input class="button-big" type="submit" value="Save">
<input type="hidden" name="mode" value="authors">
<input type="hidden" name="save" value="1">
<input type="hidden" name="author_id" value="$author_id">
</td></tr>
</table>

</td><td valign="top">

<table>
<tr><td nowrap><font class="pagetitle">General Permissions</font></td></tr>

<tr><td nowrap>
<font class="title"><input type="checkbox" name="can_create_blog" $can_create_blog>User can create new weblogs</font><br />
</td></tr>

<tr><td nowrap>
<font class="title"><input type="checkbox" name="can_view_log" $can_view_log>User can view activity log</font><br />
</td></tr>

<tr><td nowrap><font class="pagetitle"><hr />Author was created by:</font></td></tr>
<tr><td nowrap>
<select class="blog" name="created_by">
HTML
	my @authors = MT::Author->load();
	print "<option value='0'". ($author->created_by ? '': ' SELECTED') . "'>[MovableType]\n";
	foreach my $a ( sort { $a->name cmp $b->name } @authors) {
		my ($id, $name, $selected) = ($a->id, escapeHTML($a->name), ($author->created_by==$a->id) ? ' SELECTED' : '');
		print "<option value='$id'$selected>$name</a>\n";
	}
	print <<HTML;
</select>
</td></tr>

HTML
	if($q->{new}) {
	} else {
		require MT::Permission;
		my %blogs = ();
		if(my @blogs = MT::Blog->load( undef,
				{ 'join' =>
					[ 'MT::Permission', 'blog_id', { author_id => $author->id } ]
				})) {
			print <<HTML;
<tr><td nowrap><font class="pagetitle"><hr />Blogs:</font></td></tr>
<tr><td nowrap>

HTML
			foreach my $b ( sort { $a->name cmp $b->name } @blogs) {
				my ($id, $name) = ($b->id, escapeHTML($b->name));
				$blogs{$b->id} = $b;
				print <<HTML;
<tr><td nowrap>
$name
</td></tr>
HTML
			}
		} else {
			print <<HTML;
<tr><td nowrap><font class="pagetitle"><hr />Member of no blogs</font></td></tr>
HTML
		}
		print <<HTML;

<tr><td nowrap><a href="$URL?mode=permissions&author_id=$author_id">Edit Blog Permissions</a></td></tr>


</td></tr>
HTML
		}
		print <<HTML;

</table>

</td>
</tr>
</table>

</form>
</div>
HTML

	} else {

		## List authors
		my @authors = MT::Author->load();
		print <<HTML;
<div class="form">

<table border="0" cellspacing="0" cellpadding="0">
<tr>
	<td bgcolor="#829FAC" nowrap><font class="title-no-padding"><b>Name</b></font></td>
	<td bgcolor="#829FAC" nowrap><font class="title-no-padding"><b>Email</b></font></td>
	<td bgcolor="#829FAC" nowrap><font class="title-no-padding"><b>URL</b></font></td>
	<td bgcolor="#829FAC" nowrap><font class="title-no-padding"><b>Blogs</b></font></td>
	<td bgcolor="#829FAC" nowrap><font class="title-no-padding"><b>Can create blogs?</b></font></td>
	<td bgcolor="#829FAC" nowrap><font class="title-no-padding"><b>Can view log?</b></font></td>
	<td bgcolor="#829FAC" nowrap>&nbsp;</td>
	<td bgcolor="#829FAC" nowrap width="100%">&nbsp;</td>
</tr>
HTML
		my $row;
		foreach my $author ( sort { $a->name cmp $b->name } @authors) {
			my $color = row_color($row++);
			my ($name, $nickname, $email, $url, $hint)
					= ($author->name, $author->nickname, $author->email, $author->url, $author->hint);
			my ($site) = $url =~ m|^http://(.*)|;
			$site ||= '';
			print "<tr bgcolor=\"$color\"><td nowrap>" . escapeHTML($author->name) 
				 . "</td><td nowrap><a href='mailto:$email'>" . escapeHTML($email) ."</a></td><td nowrap><a href='$url' target='_blank'>$site</a>\n";
			
			require MT::Permission;
			my $count = MT::Permission->count( { author_id => $author->id } );
			print "<td align='center'>$count</td>";
			
			my $id = $author->id;
			if($author->can_create_blog) {
				print "<td align='center' class='message'>Yes</td>";
			} else {
				print "<td align='center' class='error-message'>No</td>";
			}
			if($author->can_view_log) {
				print "<td align='center' class='message'>Yes</td>";
			} else {
				print "<td align='center' class='error-message'>No</td>";
			}

			print <<HTML;
<td nowrap><a href="$URL?mode=authors&author_id=$id&edit=1" title="Edit author '$name'">Edit</a></td>
<td nowrap><a href="$URL?mode=permissions&author_id=$id" title="Edit blog permissions for '$name'">Blog Permissions</a></td>
HTML
			print "</tr>\n";
		}

		my $color = row_color($row++);
		print <<HTML;
<tr bgcolor="$color">
<td colspan="8">
<input type="button" value="Add New Author" onclick="javascript:location.href='$URL?mode=authors&new=1'">	
</td>
</tr>
</table>
</div>
HTML
	}

}

sub blogs_handler {
	my $q = shift;

	## Get MT instance
	my $mt = new_mt();

	use MT::Author;
	use MT::Blog;
	my $author;
	if($q->{author_id} && $q->{save}) {
		my $author_id = shift(@{$q->{author_id}});
		## Load author
		my $author = MT::Author->load($author_id) or die "Invalid author id '" . $author_id . "'";
		my $err;

		$author->name(shift @{$q->{name}});
		$author->nickname(shift @{$q->{nickname}});
		$author->email(shift @{$q->{email}});
		$author->url(shift @{$q->{url}});
		$author->hint(shift @{$q->{hint}});
		$author->can_create_blog($q->{can_create_blog} ? 1 : 0);
		$author->can_view_log($q->{can_view_log} ? 1 : 0);
		if(my ($password, $password_conf) = (@{$q->{password}}, @{$q->{password_conf}})) {
			if($password && $password eq $password_conf) {
				$author->set_password($password);
			} elsif($password) {
				$err = "Passwords do not match!";
				$q->{edit} = 1;
			}
		}

		if($err) {
			print <<HTML;
<div class="error-message">
$err
</div>
HTML
		} else {
			$author->save;
			my ($name) = ($author->name);

			print <<HTML;
<div class="message">
The profile of author $name has been updated.
</div>
HTML
		}
	}
	
	if($q->{author_id} && $q->{edit}) {
		my $author_id = shift(@{$q->{author_id}});

		## Load author
		$author = MT::Author->load($author_id) or die "Invalid author id '" . $author_id . "'" unless $author;
		my ($name, $nickname, $email, $url, $hint, $can_create_blog, $can_view_log)
				= ($author->name, $author->nickname, $author->email, $author->url, $author->hint,
					$author->can_create_blog ? 'CHECKED' : '',
					$author->can_view_log ? 'CHECKED' : '');

		print <<HTML;
<div class="form">
<form method="post" action="$URL">
<table border="0" cellspacing="0" cellpadding="0">
<tr>
<td valign="top">

<table border="0" cellspacing="0" cellpadding="0">

<tr><td nowrap><font class="pagetitle">Author Information</font></td></tr>

<tr><td nowrap>
<font class="title">Username</font><br />
<input class="text-short" name="name" value="$name">
</td></tr>
<tr><td nowrap>
<font class="title">Nickname</font><br />
<input class="text-short" name="nickname" value="$nickname">
</td></tr>
<tr><td nowrap>
<font class="title">Email Address</font><br />
<input class="text-short" name="email" value="$email">
</td></tr>
<tr><td nowrap>
<font class="title">Website URL (optional)</font><br />
<input class="text-short" name="url" value="$url">
</td></tr>

<tr><td nowrap><hr /><font class="pagetitle">Password change</font></td></tr>

<tr><td nowrap>
<font class="title">Password</font><br />
<input class="text-short" name="password" value="">
</td></tr>
<tr><td nowrap>
<font class="title">Password confirm</font><br />
<input class="text-short" name="password_conf" value="">
</td></tr>

<tr><td nowrap><hr /><font class="pagetitle">For Password Recovery</font></td></tr>

<tr><td nowrap>
<font class="title">Birthplace</font><br />
<input class="text-short" name="hint" value="$hint">
</td></tr>
<tr><td>
<hr />
<input class="button-big" type="submit" value="Save">
<input type="hidden" name="mode" value="authors">
<input type="hidden" name="save" value="1">
<input type="hidden" name="author_id" value="$author_id">
</td></tr>
</table>

</td><td valign="top">

<table>
<tr><td nowrap><font class="pagetitle">General Permissions</font></td></tr>

<tr><td nowrap>
<font class="title"><input type="checkbox" name="can_create_blog" $can_create_blog>User can create new weblogs</font><br />
</td></tr>

<tr><td nowrap>
<font class="title"><input type="checkbox" name="can_view_log" $can_view_log>User can view activity log</font><br />
</td></tr>
</table>

</td>
</tr>
</table>

</form>
</div>
HTML

	} else {

		## List blogs
		my @blogs = MT::Blog->load();
		print <<HTML;
<div class="form">

<table border="0" cellspacing="0" cellpadding="0">
<tr>
	<td bgcolor="#829FAC" nowrap><font class="title-no-padding"><b>Name</b></font></td>
	<td bgcolor="#829FAC" nowrap><font class="title-no-padding"><b>URL</b></font></td>
	<td bgcolor="#829FAC" nowrap><font class="title-no-padding"><b>Authors</b></font></td>
	<td bgcolor="#829FAC" width="100%">&nbsp;</td>
</tr>
HTML
		my $row;
		foreach my $blog ( sort { $a->name cmp $b->name } @blogs) {
			my $color = row_color($row++);
			my ($name, $url)
					= ($blog->name, $blog->site_url);
			my ($site) = $url =~ m|^http://(.*)|;
			$site ||= '';
			print "<tr bgcolor=\"$color\"><td nowrap>" . escapeHTML($blog->name) 
				 . "<td nowrap><a href='$url' target='_blank'>$site</a>\n";
		
			require MT::Permission;
			my $count = MT::Permission->count( { blog_id => $blog->id } );
			print "<td align='center'>$count</td>";
			
			my $id = $blog->id;
			print <<HTML;
<td nowrap><a href="$URL?mode=permissions&blog_id=$id" title="Edit author permission for '$name'">Author Permissions</a></td>
HTML
			print "</tr>\n";
		}

		print "</table></div>";
	}

}

sub config_handler {
	my $q = shift;
	my $mt = new_mt();
    my $cfg = $mt->{cfg};

	print <<HTML;
<div>
This is the active MovableType configuration
</div>

<div class="form">
<table border="0" cellspacing="0" cellpadding="0">
<tr><td bgcolor="#829FAC"><font class="title-no-padding"><b>Setting</b></font></td>
	<td bgcolor="#829FAC" width="100%"><font class="title-no-padding"><b>Value</b></font></td></tr>
HTML

	my $row;
	foreach my $var (sort keys %{$cfg->{__var}}) {
		my $val = $cfg->{__var}->{$var} || '';
		## List array
		$val = join(", ", @$val) if ref $val eq 'ARRAY';
		## Cleanup
		$val = escapeHTML($val);
		## Hide password unless logged in
		$val = "<a href='$URL?mode=login&_mode=config&admin=1'>Login as ADMINISTRATOR to see value</a>"
			if(!$CAN_EDIT && ($var =~ m/Password/i));
		my $color = row_color($row++);
		print <<HTML;
<tr bgcolor="$color"><td>$var</td><td>$val</td></tr>

HTML
	}

	print "</table></div>";
}

sub plugins_handler {
	my $q = shift;
	my $plugin_dir = $MT_DIR."plugins";
	my $filter_string = qq(Quoting "<b>boldly</b>" &amp; <a href="#" title="Example">linking</a> with '<i>emphasis</i>'.);
	my $escaped_filter = escapeHTML($filter_string);
#	my $max_length = length($filter_string);
	my $max_length = 60;

	## Context used for entries and filters
	my $mt = new_mt();
	my $ctx = new_context();
	my $entry = $ctx->stash('entry');
	my $entry_title = $entry ? escapeHTML($entry->title) : '<tt>[No entries were found]</tt>';
	my $entry_link = $entry ? $entry->permalink : '#';
	my $blog = $ctx->stash('blog');
	my $blog_name = $blog ? $blog->name : '<tt>[No blogs were found]</tt>';
	my $blog_url = $blog ? $blog->site_url : '#';

	print <<HTML;
<div>
The following are the plugins installed in the plugins directory
and the tags they add to MovableType.
<br />
Filters and text filters are evaluated on the string:
<blockquote>
$filter_string
</blockquote>
<blockquote>
<pre class="filter">$escaped_filter</pre>
</blockquote>
Tags are evaluated in the context of entry <a href="$entry_link" target="_blank">$entry_title</a> in blog
<a href="$blog_url" target="_blank">$blog_name</a>.
</div>
HTML

	my ($inError, $err, $plugin, $info);
	my %plugins = ();
	my $cmd = "$^X $0 -plugins";
#	print "<pre>$cmd</pre>";
	open (PIPE, "$cmd |");
	while (<PIPE>) {
#		print "$_<br>\n";
		if($inError) {
			if(/^=====/) {
				chop $err;
				if($inError ne 'ERROR') {
					$info->{warnings}->{$inError}->{message} = $err;
				} else {
					$info->{$inError} = $err;
				}
				$inError = 0;
			} else {
				$err .= $_ unless /$0/;
			}
		} elsif(my ($type, $line) = /^(ERROR|WARNING)\s+(\d+)/) {
			$err = "";
			$inError = $line;
			$info->{warnings}->{$inError} = { type => $type, line => $line };
		} elsif(/^VERSION/) {
			my ($version) = /^VERSION\s+([^\s]+)/;
			$version ||= '';
			$version = "[$version]" if $version;
			$info->{version} = $version;
		} elsif(/^PLUGIN/) {
			# Stash previous info
			$plugins{$plugin} = $info if $plugin;

			# Initialize new plugin info
			($plugin) = /^PLUGIN\s+([^\s]+)/;
			$info = { name=>$plugin, entries=>{}, warnings=>{} };
#			print "PLUGIN $plugin<br>\n";
		} else {
			my ($type, $tag) = /^([^\s]+)\s+([^\s]+)/;
			$info->{entries}->{$tag} = { type=>$type };
		}
	}
	close PIPE;

	# Stash last info
	$plugins{$plugin} = $info if $plugin;


	## Emit
	my $val = escapeHTML($filter_string);
	$val = $filter_string;
	print <<HTML;
<div class='form'>
<table border='0' cellspacing='0' cellpadding='0'>
<tr>
<td bgcolor="#829FAC"><font class="title-no-padding"><b>Type</b></font></td>
<td bgcolor="#829FAC"><font class="title-no-padding"><b>Name</b></font></td>
<td bgcolor="#829FAC" width="100%"><font class="title-no-padding"><b>Tag or Filter value</b></font></td>
</tr>
HTML

	## Iterate over plugins
	for my $plugin (sort {$a cmp $b} keys %plugins) {
		my $row = 0;
		my $info = $plugins{$plugin};
		my $version = $info->{version};
		($plugin) = $plugin =~ /([^\\\/\:]+)$/;
		## Emit
#		print "<tr bgcolor='#cccccc'><td>&nbsp;</td><td><b>$plugin</b></td><td><b>$version</b></td></tr>";
		print <<HTML;
<tr bgcolor="#cccccc">
	<td>&nbsp;</td>
	<td><b>$plugin $version</b></td>
	<td><a
		title="View the source of $plugin"
		style="cursor: hand; font-weight: normal"
		onclick="show_source('$URL?mode=source&plugin=$plugin')"
		>View&nbsp;Source</a>
	</td>
</tr>
HTML
#		print "<tr bgcolor='#ffcccc'><td>ERROR</td><td colspan='2'><pre class='error'>".escapeHTML($info->{ERROR})."</pre></td></tr>\n" if $info->{ERROR};
		foreach my $line (sort keys %{$info->{warnings}}) {
			my $type = $info->{warnings}->{$line}->{type};
			my $warning = escapeHTML($info->{warnings}->{$line}->{message});
			my $color = ($type eq 'ERROR') ? '#ffcccc' : '#ffffcc';
			$warning =~ s/\n/<br \/>\n/g;
			print <<HTML;
<tr bgcolor="$color">
	<td><a
		title="Go to line $line of $plugin"
		style="cursor: hand"
		onclick="show_source('$URL?mode=source&plugin=$plugin#line_$line')"
		>$type</a></td>
	<td colspan='2'><span class='error'>$warning</span></td>
</tr>
HTML
		}
		foreach my $tag (sort keys %{$info->{entries}}) {
			my $entry = $info->{entries}->{$tag};
			if($entry->{type} eq 'filter') {
				my $val;
				eval {
					$val = $MT::Template::Context::Global_filters{$tag}->($filter_string, '1', $ctx);
				};
				print filtered_text_row('filter', $tag, $val, $max_length, $row++);
			} elsif($entry->{type} eq 'text_filter') {
				my $val;
				eval {
					$val = $MT::Text_filters{$tag}{on_format}->($filter_string);
				};
				print filtered_text_row('text filter', $MT::Text_filters{$tag}{label} . " ($tag)", $val, $max_length, $row++);
			} elsif($entry->{type} eq 'tag') {
				my $val;
				eval {
					my $handler = $MT::Template::Context::Global_handlers{$tag};
					$val = $handler->{'code'}->($ctx, {}, {}) if $handler;
					$val = "No handler for $tag" unless $handler;
				};
#					$val = escapeHTML($@) if $@;
				print filtered_text_row('&nbsp;', "MT$tag", $val, $max_length, $row++);
			} elsif($entry->{type} eq 'container') {
				my $color = row_color($row++);
				print <<HTML
<tr bgcolor="$color"><td>container</td><td>MT$tag</td><td>&nbsp;</td></tr>

HTML
			}
		}		
	}

	print "</table></div>\n";

}

sub filters_handler {
	my $q = shift;
	## Get MT instance
	my $mt = new_mt();
	my $default_source = qq(Quoting "<b>boldly</b>" &amp; <a href="#" title="Example">linking</a> with '<i>emphasis</i>'.\n\nThis is another paragraph.);
	my $source = $q->param('text') || $default_source;
	my $val = '';
	my $filtered;
	my $filter_val = defined($q->param('filter_val')) ? $q->param('filter_val') : 1;

	my $filter = $q->param('filter') || '';

	if(my ($tag) = $filter =~ /^tag_(.*)/) {
		if(my $h = $MT::Template::Context::Global_filters{$tag}) {
			eval {
				$val = $h->($source, $filter_val, new_context());
			};
		}
	} elsif(($tag) = $filter =~ /^text_(.*)/) {
		eval {
			if(my $h = $MT::Text_filters{$tag}{on_format}) {
				$val = $h->($source);
			};
		};
	}
	
	if(!$val) {
		eval {
			if(my $h = $MT::Text_filters{'__default__'}{on_format}) {
				$val = $h->($source);
				$filter = 'text___default__';
			};
		};
	}

	print <<HTML;
<div class="form">
<form method='post' name='form' id='form'>
<table>
<tr>
<td nowrap>Text of tag filter:</td>
<td>
<select class="blog" name="filter">
<option value=''># Text Formatting #</option>
<option value=''></option>
HTML
	foreach my $tag (sort { $MT::Text_filters{$a}{label} cmp $MT::Text_filters{$b}{label} } keys %MT::Text_filters) {
		my $label = $MT::Text_filters{$tag}{label};
		my $val = "text_$tag";
		my $selected = ($filter eq $val) ? 'selected' : '';
		print <<HTML;
<option value="$val" $selected>$label</option>
HTML
	}

	print <<HTML;
<option value=''></option>
<option value=''># Tag Attributes #</option>
<option value=''></option>
HTML

	for my $tag (sort keys %MT::Template::Context::Global_filters) {
		my $label = $tag;
		my $val = "tag_$tag";
		my $selected = ($filter eq $val) ? 'selected' : '';
		print <<HTML;
<option value="$val" $selected>$label</option>
HTML
	}

	$source = escapeHTML($source);
	$filtered = escapeHTML($val);
	$filter_val = escapeHTML($filter_val);
	$default_source =~ s|\'|\\\'|g;
	$default_source =~ s|\n|\\n|g;
	$default_source = escapeHTML($default_source);

	my $rendered = $q->param('render') ? $val : '-- not rendered --';
	my $render = $q->param('render') ? 'checked' : '';

	print <<HTML;
</select>
</td>
</tr>

<tr>
<td nowrap>Tag-filter Value:</td>
<td>
<input type="text" name="filter_val" value="$filter_val">
</td>
</tr>

<tr>
<td>&nbsp;</td>
<td>
<input type="checkbox" name="render" $render> Render HTML
</td>
</tr>

<tr>
<td nowrap>Source Text:<br />
(<a href="#" onclick="document.form.text.value='$default_source'">default</a>)
</td>
<td>
<textarea name="text" rows="8" cols="72">$source</textarea>
</td>
</tr>

<tr>
<td>&nbsp;</td>
<td>
<input type="hidden" name="mode" value="filters">
<input class="button-big" type="submit" name="submit" value="Test Filter">
</td>
</tr>

<tr>
<td colspan="2"><hr></td>
</tr>

<tr>
<td nowrap>Filtered:</td>
<td>
<pre class='filter'>$filtered</pre>
</td>
</tr>
HTML

	print <<HTML if $render;

<tr>
<td colspan="2"><hr></td>
</tr>

<tr>
<td nowrap>Rendered:</td>
<td>
$rendered
</td>
</tr>
HTML

	print <<HTML;
</table>
</form>
</div>
HTML
}

sub source_handler {
	my $q = shift;
	my $plugin_dir = $MT_DIR."plugins";
	my $plugin = $q->param('plugin') || '';
	my @warnings;

	print "<font class='pagetitle'>Source for plugin '$plugin'</font><div class='form'>";

	eval {
		use File::Spec;
		$plugin = File::Spec->catfile($plugin_dir, $plugin);
		{
			## Catch warnings
			local $SIG{__WARN__} = sub {
				push @warnings, $_[0];
			};
			require "$plugin";
		}
	};

	## Remember error, if any
	my $plugin_error = $@ || '';
#	print "<div class='error'>" . escapeHTML($plugin_error) . "</div>" if $plugin_error;
	print "<pre class='filter'>";
	process_plugin($plugin, \&source_callback, parse_errors($plugin, $plugin_error), parse_warnings($plugin, \@warnings));
	print "</pre></div>";
}

sub parse_errors {
	my $plugin = shift;
	my @lines = split /[\r\n]+/, ($_[0] || '');
	my $errors = {};
	my $error = '';

	foreach my $line (@lines) {
		if(my($number) = $line =~ /line\s+(\d+)/) {
			next if $line =~ /$0/;
			$line .= "\n";
			if($line =~ /$plugin/) {
				$errors->{$number} = ($errors->{$number}||$error) . $line;
				$error = '';
			} else {
				$error .= $line;
			}
		}
	}
	return $errors;
}

sub parse_warnings {
	my ($plugin, $wa) = @_;
	my $warnings = {};
	my $prev;
	foreach (@$wa) {
		if(my ($line) = /line (\d+)\.$/) {
			$warnings->{$line} = $_;
			$prev = $line;
		} elsif($prev) {
			$warnings->{$prev} .= $_;
		}
	}
	return $warnings;
}

sub source_callback {
	my ($text, $state, $prev_state) = @_;
	my $line = $state->{line};
	my $isError = $state->{errors}->{$line} || $state->{warnings}->{$line} || $state->{warning};
	my $clean = escapeHTML($isError||'');
	$clean =~ s/[\r\n]/<br \/>\r\n/g;
	print qq|<a name='line_$line' onMouseOver="hideshowElement('error_$line', 'show')" onMouseOut="hideshowElement('error_$line', 'hide')"><span class='error' style='background: yellow'>| if $isError;
	printf("%4d: %s", $line, escapeHTML($text));
	print qq|</span></a><div id="error_$line" name="error_$line" class="floater" style="display:none">
<table><tr><td>
<div class="filter">$clean</div>
</td></table>
</div>| if $isError;
}

sub listing_callback {
	my ($text, $state, $prev_state) = @_;

	print "VERSION " . $state->{version} . "\n" if $state->{version};
	if(my $dependency = $state->{dependency}) {
		print_warning($state->{line}, "Loading external module '" . $dependency->{module} . "':\n" . $state->{warning} )
			if $state->{warning} && !$state->{errors}->{$state->{line}};
	}
}

sub process_plugin {
	my ($plugin, $callback, $errors, $warnings) = @_;

	## Get Version information and check required modules			
	open(PLUGIN, $plugin) or die "Can't read file '$plugin'";
	{
		my %prev_state = ();
		my %state = ( line => 0, errors => $errors, warnings => $warnings );
		while(<PLUGIN>) {
			my $text = $_;
			$state{line}++;
			($state{version}, $state{dependency}, $state{warning}) = ();
			if($state{inPod}) {
				## Check for end of documentation
				$state{inPod} = !/^=cut/;
			} elsif($state{inString}) {
				## Check for end of << constant
				$state{inString} = 0 if /^$state{inString}$/;
			} elsif(/^=/) {
				## Check for beginning of documentation
				$state{inPod} = ! /^=cut/;
			} elsif(my ($tok) = /<<\W*(\w+)/) {
				## Check for beginning of << constant
				$state{inString} = $tok;
			} elsif(/^__END__/) {
				last;
			} elsif(my ($version) = /\$VERSION\s*=\s*'?"?([\w\d\.]+)/) {
				# Try parsing the $VERSION assignment
				$state{version} = $version;
#				last if $plugin_error;
			} elsif(my ($type, $module) = /^[^\'\"\#]*(require|use)\s+([\w\d:\.]+)/) {
#				next if $plugin_error;
				eval "$type $module";
				my $warning;
				if($@) {
#					$@ =~ s/[\r\n]*$//;
					## String trailing "( at eval ..."
					$warning = reverse($@);
					$warning =~ s/^[\r\n]*//;
					$warning =~ s/.*lave\( ta \)//;
					$warning = reverse($warning);
#					$warning = $@;
#					print_warning($state{line}, "Loading external module '$module':\n$warning");
				}
				$state{dependency} = { type => $type, module => $module, warning => $warning };
				$state{warning} = $warning;
			}
			$callback->($text,  \%state, \%prev_state);
			%prev_state = %state;
		}
		close PLUGIN;
	}
}


sub row_color {
	my ($row) = @_;
	$row ||= 0;
	return ($row&1) ? "#ffffff" : "#eeeeee";
}

sub filtered_text_row {
	my ($type, $tag, $val, $max_length, $row) = @_;
	my $out = '';
	my $color = row_color($row);
	$val ||= '';
	$max_length = 40 unless $max_length;

	if(length($val) > $max_length) {
		my $clean = escapeHTML($val);
		$val = escapeHTML(substr($val, 0, $max_length - 3));
		return <<HTML;
<tr bgcolor="$color"><td nowrap>
<div id="filter_$tag" name="filter_$tag" class="floater" style="display:none">
<table><tr><td>
<pre class="filter">$clean</pre>
</td><td>
<a href="javascript:hideshowElement('filter_$tag')" title="Close">x</a>
</td></tr></table>
</div>
$type
</td><td>
$tag
</td><td>
<pre class="filter">$val <a href="javascript:hideshowElement('filter_$tag')" title="Show All">...</a></pre>
</td></tr>
HTML
	} else {
		$val = escapeHTML($val);
		return <<HTML;
<tr bgcolor="$color"><td nowrap>$type</td><td>$tag</td><td><pre class="filter">$val</pre></td></tr>
HTML
	}
}

sub default_handler {
	my $q = shift;
		print <<HTML;
<div class='form'>
The MT-Medic application allows you to do global administration tasks on your MovableType installation.
<dl>
<dt><a href="$URL?mode=config">Configuration</a></dt>
<dd>Lists all configuration entries of your MovableType installation.
<br />
Used for general troubleshooting.
</dd>

<dt><a href="$URL?mode=plugins">Plugins</a></dt>
<dd>Lists all the plugins that you have installed as well as the template tags and filters that each
adds to MovableType.  It also shows any errors that the plugins may have.
<br />
Used when you have problems with a plugin or when you want to see which plugins and tags you have available.
</dd>

<dt><a href="$URL?mode=filters">Filters</a></dt>
<dd>Lets you try out the effects of different
<a href="http://www.movabletype.org/docs/mtmanual_tags.html#global tag attributes">global tag attribute</a>
and
<a href="http://www.movabletype.org/docs/mtmanual_entries.html#item_Text_Formatting">text formatting</a>
filters that are installed.
<br />
Used when you need to see how a filter affects the text that it renders.
</dd>

<dt><a href="$URL?mode=authors">Authors</a></dt>
<dd>Allows you to change the contact information (name, nickname, email, etc.)
and blog creation and log viewing privileges,
as well as to reset the password of any MovableType author.
<br />
Used when a user has forgotten (and can't retrieve) their password and for general
user administration.
</dd>

<dt><a href="$URL?mode=blogs">Blogs</a></dt>
<dd>Gives you an overview of blogs and how many authors each has.
</dd>

<dt><a href="$URL?mode=permissions">Permissions</a></dt>
<dd>View and change any author permissions on any blog in the system. 
<br />
Used for changing permissions on blogs that have been created by other users.
</dd>

</dl>

</div>
HTML
}

sub escapeHTML {
    my $text = shift;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/\"/&quot;/g;
    return $text;  
}

sub new_mt {
	## Create MT Object
	require MT;
	return MT->new( Config => $MT_DIR . 'mt.cfg', Directory => $MT_DIR )
		or die MT->errstr;
}

sub new_context {
	## Create Context object
	use MT::Template::Context;
	my $ctx = MT::Template::Context->new;

	use MT::Entry;
	my $entry;
	## Pick a published entry with comments
	$entry = MT::Entry->load( { status => 2} ,
						{ 'join' =>
							[ 'MT::Comment', 'entry_id', undef, { limit => 1 } ]
						});
	## Try a published entry without comments
	$entry = MT::Entry->load( { status => 2}, { limit => 1} ) unless $entry;
	## Try a draft entry
	$entry = MT::Entry->load( undef, { limit => 1} ) unless $entry;

	use MT::Blog;
	my $blog;
	if($entry) {
	    $blog = MT::Blog->load($entry->blog_id) or warn "Load of blog '" . $entry->blog_id . "' failed!";
	} else {
		$blog = MT::Blog->load(undef, { limit => 1 } ) or warn "There appear to be no blogs in this installation";
	}

	if($blog) {
		$ctx->stash('blog', $blog);
		$ctx->stash('blog_id', $blog->id);
	}
	if($entry) {
		$ctx->stash('entry', $entry);
		$ctx->{current_timestamp} = $entry->created_on;
	}
if(0) {
    my(%cond);
	$cond{EntryIfAllowComments} = $entry->allow_comments;
	$cond{EntryIfCommentsOpen} = $entry->allow_comments eq '1';
	$cond{EntryIfAllowPings} = $entry->allow_pings;
	$cond{EntryIfExtended} = $entry->text_more ? 1 : 0;
}
	return $ctx;
}

sub edit_warning {
	return "" unless $CAN_EDIT;
	return <<TEXT;
<div class="error">
You are currently logged in to MT-Medic.  Don't forget to <a href="$URL?mode=logout">log out</a>
when you are finished using MT-Medic.
</div>
TEXT
}

sub html_head {
	my $title = shift || 'MT-Medic';
	return <<TEXT;
<html>
<head>
	<title>$title</title>

<script language="JavaScript" type="text/JavaScript">
function hideshowElement(name, value){
	which = document.getElementById(name);
	if (!which) return;
	if (which.style.display=="none" || value=="show"){
		which.style.display="";
	}else{
		which.style.display="none";
	}
}

function checkAll(field, value)
{
for (i = 0; i < field.length; i++)
	field[i].checked = value ;
}

function show_source(url)
{
	// Open window
	win = window.open('', 'mtmedic_source', 'width=600,height=400,resizable=yes,scrollbars=yes');
	// Clear contens
	win.location = '';
	win.location.reload();
	// Reload with URL
	win.location = url;
}

</script>
<style type="text/css">
<!--
body { 
	background:#fff; 
/*	margin-top: 0px; 
	margin-left: 0px; 
	margin-right: 0px; 
	padding: 0; 
*/
/*	background-image: 
	url(images/bar-back.gif); 
	background-repeat:repeat-x;
*/	font-family:trebuchet MS, trebuchet, verdana, arial, sans-serif; 
	font-size: 11px; 
	color: #666; 
	}

body.pop { 
	background:#fff; 
	margin-top: 0px; 
	margin-left: 0px; 
	margin-right: 0px; 
	padding: 0; 
	background-image: 
	url(images/logo-small.gif); 
	background-repeat:repeat-x;
	}

	A 			{ color: #4A7184; text-decoration: underline; font-weight:bold; font-family:trebuchet MS, trebuchet, verdana, arial, sans-serif; font-size: 12px;} 
	A:link		{ color: #4A7184;  } 
	A:visited	{ color: #4A7184;  } 
	A:active	{ color: #999966;  } 
	A:hover		{ color: #999966;  } 

a.instructional { 
	font-family:verdana, arial, sans-serif; 
	font-size:10px; 
	line-height:13px;
	}

a.list {
	font-family: trebuchet MS, trebuchet, verdana, arial, sans-serif; 
	font-size: 11px;  
	line-height:12px;
	font-weight: normal;	
	}

a.title {
	text-decoration:none;	
	}
			
font { 
	font-family:trebuchet MS, trebuchet, verdana, arial, sans-serif;
	font-weight:normal;
	text-transform:none; 
	}

font.title { 
	font-family:trebuchet MS, trebuchet, verdana, arial, sans-serif; 
	font-size: 12px; 
	color: #666; 
	line-height:15px;
/*	font-weight:bold; */
	}

font.title-list { 
	font-family:trebuchet MS, trebuchet, verdana, arial, sans-serif; 
	font-size: 11px; 
	color: #666; 
	line-height:15px;
	}
	
font.bold-label {
	font-family:trebuchet MS, trebuchet, verdana, arial, sans-serif;
	font-size: 11px;
	color: #666;
	font-weight: bold;
	}
 
font.title-no-padding {
	font-family:trebuchet MS, trebuchet, verdana, arial, sans-serif;
	font-size: 11px;
	color: #FFF;
	}

font.title-padding { 
	font-family:trebuchet MS, trebuchet, verdana, arial, sans-serif; 
	font-size: 11px; 
	color: #FFF; 
	line-height:15px;
	padding:5px;
	}

font.title-padding-grey { 
	font-family:trebuchet MS, trebuchet, verdana, arial, sans-serif; 
	font-size: 11px; 
	color: #333; 
	line-height:15px;
	padding:5px;
	}
	
font.pagetitle { 
	font-family:trebuchet MS, trebuchet, verdana, arial, sans-serif; 
	font-size: 12px; 
	color: #666; 
	line-height:15px;
	font-weight:bold;
	}

font.pagetitlelink { 
	font-family:trebuchet MS, trebuchet, verdana, arial, sans-serif; 
	font-size: 12px; 
	color: #336699; 
	line-height:15px;
	font-weight:bold;
	}

font.plain { 
	font-family:trebuchet MS, trebuchet, verdana, arial, sans-serif; 
	font-size:11px; 
	color: #666; 
	line-height:15px;
	}

font.instructional { 
	font-family:verdana, arial, sans-serif; 
	font-size:10px; 
	color: #666; 
	line-height:13px;
	text-align:justify;
	}

.message { 
	font-family: verdana, arial, sans-serif; 
	font-size:11px; 
	color: #669966; 
	line-height:13px;
	font-weight:bold;
	margin-bottom: 10px;
	}

.message a {
	font-family: verdana, arial, sans-serif;
	font-size: 11px;
	}

.error {
	color: #993333; 
}

.error-message { 
	font-family:verdana, arial, sans-serif; 
	font-size:11px; 
	color: #993333; 
	line-height:13px;
	font-weight:bold;
	margin-bottom: 10px;
	}

.error-message a {
	font-family: verdana, arial, sans-serif;
	font-size: 11px;
	}

font.instructional-just { 
	font-family:verdana, arial, sans-serif; 
	font-size:10px; 
	color: #666; 
	line-height:13px;
	}

font.head1 { 
	font-family: trebuchet MS, trebuchet, verdana, arial, sans-serif; 
	font-size:11px; 
	color: #336699; 
	line-height:15px;
	font-weight:bold;
	}

font.command { 
	font-family: trebuchet MS, trebuchet, verdana, arial, sans-serif; 
	font-size: 12px; 
	line-height:15px;
	text-transform:uppercase;
	font-weight:bold;
	}

font.command-grey { 
	font-family: trebuchet MS, trebuchet, verdana, arial, sans-serif; 
	font-size: 12px; 
	line-height:15px;
	color: #666;
	font-weight:bold;
	valign:middle;
	}

div, pre {
	padding: 5px;
}

pre.filter, pre.error {
	padding: 0px;
	margin: 0px;
}

p, td, dd { 
	color:#666; 
	font-family: trebuchet MS, trebuchet, verdana, geneva, arial, helvetica, sans-serif; 
	font-size: 11px; 
	line-height:14px;
	}

td {
	padding-left: 5px;
	padding-right: 5px;
	padding-top: 2px;
	padding-bottom: 2px;
	vertical-align: top;
}

ul { 
	color:#666; 
	font-family: trebuchet MS, trebuchet, verdana, helvetica, sans-serif; 
	font-size: 11px; 
	line-height:14px;  }

li { 
	font-family: trebuchet MS, trebuchet, verdana, helvetica, sans-serif; 
	font-size: 11px; 
	margin-left: 0px; 
	margin-right: 0px; 
	margin-top: 6px; 
	margin-bottom: 0px;
	line-height:14px;
	}

	.blogbox {
	padding:5px;
	background-color:#FFF;
	margin-bottom:10px;
	border:1px solid #CCC;
	width:260px;
	}


.padded-box {
	border: 1px solid #696;
	padding: 10px;
	margin-top: 50px;
	margin-left: 50px;
	text-align:center;
	}

#copyright {
	background:#FFF;
	font-family:verdana, arial, sans-serif;
	font-size:10px;
	color:#666;
	border-top:1px dotted #CCC;
	border-bottom:1px dotted #CCC;	
	margin-top:50px;
	margin-left:10px;
	margin-right:10px;
	padding-left:50px;
	}

	input {
	font-family:verdana, arial, sans-serif;
	font-size:11px;
	font-weight:bold;
	color:#666;
	} 
	
	input.search {
	font-family:verdana, arial, sans-serif;
	font-size:10px;
	color:#666;
	font-weight:normal;	
	} 
		
	input.text {
	width: 292px;  
	height: 20px;
	} 
	
	input.num {
	width: 16px; 
	height: 20px;
	}

	input.num4 {
	width: 32px;
	height: 20px;
	} 
	
	input.text-short {
	width: 175px;  
	height: 20px;
	}

	input.text-large { 
	width: 250px;  
	height: 20px;
	margin-bottom:5px;
	}
	
	input.button {
	width: 100px;
	font-family: verdana, arial, sans-serif;
	font-size:11px;
	font-weight:bold;
	color:#666;
	text-transform:uppercase;
	}

	input.button-big {
	width: 150px;
	font-family: verdana, arial, sans-serif;
	font-size:11px;

	font-weight:bold;
	color:#666;
	text-transform:uppercase;
	} 

	input.weird-button {
	width:75px;
	font-family: verdana, arial, sans-serif;
	font-size:11px;
	font-weight:bold;
	color:#000;
	background-color:#FFF;
	text-transform:uppercase;	
	} 
	
	input.button-small {
	width: 50px;
	font-family: verdana, arial, sans-serif;
	font-size:11px;
	font-weight:bold;
	color:#666;
	text-transform:uppercase;	
	} 

	input.button-search {
	width: 75px;
	font-family: verdana, arial, sans-serif;
	font-size:10px;
	font-weight:bold;
	color:#666;
	text-transform:lowecase;	
	}
			
	input.button-go {
	width: 100px;
	font-family: verdana, arial, sans-serif;
	font-size:11px;
	font-weight:bold;
	color:#666;
	background-color:#C5D1C7;
	text-transform:uppercase;	
	}	
	
	input.cbox { 
	vertical-align:3px;
	}
	 
	select { 
	font-family: verdana, arial, sans-serif; 
	font-weight:bold; 
	color:#666; 
	font-size:11px;
	} 
	
	select.menu { 
	width: 106px;
	}

	select.menu-long {
	width: 225px;
	}

	select.blog { 
	width: 165px;
	color:#666; 
	font-size:11px;
	}
	
	select.category {
	width: 150px;
	} 
	
	select.menu-short {
	width: 130px;
	} 
	 
	textarea {
	font-family:verdana, arial, sans-serif; 
	color:#333; 
	background-color:#FFF; 
	font-size:11px;	 
	} 

	textarea.width500 {
	font-family:verdana, arial, sans-serif; 
	color:#333; 
	background-color:#FFF; 
	font-size:11px;	
	width:486px; 
	} 
	
	textarea.config {
	font-family:verdana, arial, sans-serif; 
	color:#333;  
	font-size:11px;	
	width: 292px;
	} 
		
	textarea.wide {
	font-family:verdana, arial, sans-serif; 
	color:#333; 
	background-color:#FFF; 
	font-size:11px; 
	} 
	
	textarea.short310 {
	font-family:verdana, arial, sans-serif;
	color:#333;
	background-color:#FFF;
	font-size:11px;
	width: 310px;
	}

	textarea.short340 {
	font-family:verdana, arial, sans-serif;
	color:#333;
	background-color:#FFF;
	font-size:11px;
	width: 340px;
	}

	.form {
	padding:5px;
	background-color:#FFF;
	margin-top:10px;
	border:1px solid #CCC;
	}

  div.floater {
	  position:absolute;
	  z-index:1000;
	  background: #eeeeee;
	  border: solid 1px gray;
	  padding: 2px;
  }

  pre a {
	  font-family: monospace;
	  font-weight: normal;
	  text-decoration: none;
  }

-->
</style>
</head>
<body onload="window.focus()">
TEXT
}

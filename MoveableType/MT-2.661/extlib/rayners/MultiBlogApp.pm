
package rayners::MultiBlogApp;
use MT::App;
@ISA = qw( MT::App );

use strict;

use vars qw( $VERSION );
my $VERSION = "1.0.1";

use MT::Permission;

use rayners::MultiBlogPlugin;
use rayners::MultiBlog;

sub init {
  my $app = shift;
  $app->SUPER::init (@_) or return;
  $app->add_methods (
      default	=> \&default,
      add_dep	=> \&add_dep,
      rem_dep	=> \&rem_dep,
      add_acl 	=> \&add_acl,
      reset_acl => \&reset_acl,
      set_default_access => \&set_default_access,
      );
  $app->{default_mode} = 'default';
  $app->{template_dir} = 'cms';
  $app->{requires_login} = 1;
  $app->{user_class} = 'MT::Author';

  $app;
}

sub uri {
    $_[0]->path .
       ($_[0]->{author} ? MT::ConfigMgr->instance->AdminScript : $_[0]->script);
}

sub success_message {
  my ($app, $success_message) = @_;

  $success_message = "<div class='message'><span class='inner'>$success_message</span></div>";
  $app->default ($success_message);
}

sub error_message {
  my ($app, $error_message) = @_;

  $error_message = "<div class='error-message'><span class='input'>$error_message</span></div>";
  $app->default ($error_message);
}

sub set_default_access {
  my $app = shift;
  my $q = $app->{query};

  my $default_access = $q->param ('default_access');

  return $app->error_message ("Need an access type!") if (!$default_access);
  
  return $app->error_message ("Unknown access type: '$default_access'") if ($default_access !~ /(allow|deny)/);

  my $plugin = rayners::MultiBlogPlugin->plugin;
  $plugin->set_config_value ('default_access', $default_access) 
    or return $app->error_message ("Error saving default access type: '".$plugin->errstr."'.");

  return $app->success_message ("Default Blog Access set to <i>".$default_access."</i>.");
}

sub rem_dep {
  my $app = shift;
  my $q = $app->{query};

  my $pb = $q->param ('post_blog_id');
  my $rb = $q->param ('rebuild_blog_id');

  require MT::Blog;
  my $p_blog = MT::Blog->load ($pb) or 
    return $app->error_message ("Unknown blog_id: $pb");
  my $r_blog = MT::Blog->load ($rb) or
    return $app->error_message ("Unknown blog_id: $rb");

  return $app->error_message ("Blog will already rebuild itself")
    if ($pb == $rb);

  my $plugin = rayners::MultiBlogPlugin->plugin;

  my $rebuilds = $plugin->get_config_value ('rebuilds');

  delete $rebuilds->{$pb}->{$rb};

  if (!scalar keys %{$rebuilds->{$pb}}) {
    delete $rebuilds->{$pb};
  }

  if (!scalar keys %$rebuilds) {
    undef $rebuilds;
  }

  $plugin->set_config_value ('rebuilds', $rebuilds) or
    return $app->error_message ("Error saving rebuild data: '".$plugin->errstr.
	"'.");

  return $app->success_message ("Posts to <i>".$p_blog->name."</i> will no longer rebuild <i>".$r_blog->name."</i>.");
}

sub add_acl {
  my $app = shift;
  my $q = $app->{query};

  my $sb = $q->param ('source_blog_id');
  my $access = $q->param ('access_type');
  my $db = $q->param ('dest_blog_id');

  require MT::Blog;
  my $s_blog = MT::Blog->load ($sb) or
    return $app->error_message ("Unknown blog_id: $sb");
  my $d_blog = MT::Blog->load ($db) or
    return $app->error_message ("Unknown blog_id: $db");

  return $app->error_message ("Unknown access type: $access")
    if ($access ne 'allow' && $access ne 'deny');

  $d_blog = rayners::MultiBlog->copy_blog ($d_blog);

  $d_blog->_set_access ($access, $s_blog);

  return $app->success_message ("Access to <i>".$d_blog->name."</i> from <i>".$s_blog->name."</i> will be <b>".(($access eq 'allow') ? 'allowed' : 'denied')."</b>.");
}

sub reset_acl {
  my $app = shift;
  my $q = $app->{query};

  my $sb = $q->param ('source_blog_id');
  my $db = $q->param ('dest_blog_id');

  require MT::Blog;
  my $s_blog = MT::Blog->load ($sb) or
    return $app->error_message ("Unknown blog_id: $sb");
  my $d_blog = MT::Blog->load ($db) or
    return $app->error_message ("Unknown blog_id: $db");

  $d_blog = rayners::MultiBlog->copy_blog ($d_blog);
  $d_blog->_reset_access ($s_blog);

  return $app->success_message ("Access to <i>".$d_blog->name."</i> from <i>".$s_blog->name."</i> has been reset.");
}

sub add_dep {
  my $app = shift;
  my $q = $app->{query};

  my $pb = $q->param ('post_blog_id');
  my $rb = $q->param ('rebuild_blog_id');
  my $when = $q->param ('rebuild_when');

  require MT::Blog;
  my $p_blog = MT::Blog->load ($pb) or 
    return $app->error_message ("Unknown blog_id: $pb");
  my $r_blog = MT::Blog->load ($rb) or
    return $app->error_message ("Unknown blog_id: $rb");

  return $app->error_message ("Blog will already rebuild itself")
    if ($pb == $rb);

  return $app->error_message ("Unknown rebuild_when: '$when'")
    if ($when !~ /(entry|placement)/);

  my $plugin = rayners::MultiBlogPlugin->plugin;

  my $rebuilds = $plugin->get_config_value ('rebuilds');

  $rebuilds->{$pb}->{$rb} = $when;

  $plugin->set_config_value ('rebuilds', $rebuilds) or
    return $app->error_message ("Error saving rebuild data: '".$plugin->errstr.
	"'.");

  return $app->success_message ("Posts to <i>".$p_blog->name."</i> will now rebuild <i>".$r_blog->name."</i> on <i>".$when."</i> save.");
}

sub default {
  my $app = shift;

  my ($incoming_html) = @_;

  my $plugin = rayners::MultiBlogPlugin->plugin;
  my $rebuilds = $plugin->get_config_value ('rebuilds');
  my $acls = $plugin->get_config_value ('acls');
  my $default_access = $plugin->get_config_value ('default_access') || 'allow';
  
  my $author = $app->{author};
  
  require MT::App::CMS;
  my $header = MT::App::CMS::build_page ($app, "header.tmpl", { author_name => $author->username, no_breadcrumbs => 1 }) || "";
  my $footer = MT::App::CMS::build_page ($app, "footer.tmpl", {}) || "";

  my $html = "";

  require MT::Blog;
  my @blogs = MT::Blog->load ();

  my %blog_names;
  foreach my $blog (@blogs) {
    $blog_names{$blog->id} = $blog->name;
  }

  $html .= $incoming_html if ($incoming_html);

  $html .= "<div class='box'>\n";
  $html .= "<h4>Rebuild Control</h4>\n";
  $html .= "<div class='inner'>\n";
  $html .= "<p></p>\n";
  if ($rebuilds) {
    $html .= "<h4>Current Ruleset</h4>\n";
    $html .= "<div class='list'>\n";
    $html .= "<table>\n";
    $html .= "<tr><th>Posts to:</th><th>Rebuild:</th><th>When:</th><th></th></tr>\n";
    my $even = 0;
    foreach my $p (sort {$blog_names{$a} cmp $blog_names{$b}}
	keys %$rebuilds) {
      $html .= "<tr class='". (($even) ? 'even' : 'odd') . "'>";
      my $num = scalar keys %{$rebuilds->{$p}};
      $html .= "<td rowspan='$num'>$blog_names{$p}</td>\n";
      my @ids = sort {$blog_names{$a} cmp $blog_names{$b}} keys %{$rebuilds->{$p}};
      my $r = shift @ids;
      $html .= "<td>$blog_names{$r}</td>";
      $html .= "<td>On <i>".$rebuilds->{$p}->{$r}."</i> save</td>";
      $html .= "<td>[ <a href='?__mode=rem_dep&post_blog_id=$p&rebuild_blog_id=$r'>remove</a> ]</td>";
      $html .= "</tr>";
      $even = !$even;
      foreach $r (@ids) {
	$html .= "<tr class='".(($even) ? 'even' : 'odd'). "'>";
	$html .= "<td>$blog_names{$r}</td>";
	$html .= "<td>On <i>".$rebuilds->{$p}->{$r}."</i> save</td>";
	$html .= "<td>[ <a href='?__mode=rem_dep&post_blog_id=$p&rebuild_blog_id=$r'>remove</a> ]</td>";
	$html .= "</tr>";
	$even = !$even;
      }
    }
    $html .= "</table>\n";
    $html .= "</div>\n";
  }


  $html .= "<h4>Configuration</h4>\n";
  $html .= "<div class='list'>\n";
  $html .= "<table>\n";

  $html .= "<form method='post'>\n";
  $html .= "<input type='hidden' name='__mode' value='add_dep' />\n";
  $html .= "<table class='list'>\n";
  $html .= "<tr><th>Posts to:</th><th>Will rebuild indexes in:</th><th>On:</th><th></th></tr>\n";
  $html .= "<tr><td><select name='post_blog_id'>\n";
  foreach my $blog (@blogs) {
    $html .= "<option value='".$blog->id."'>".$blog->name."</option>\n";
  }
  $html .= "</td><td>";
  $html .= "<select name='rebuild_blog_id'>\n";
  foreach my $blog (@blogs) {
    $html .= "<option value='".$blog->id."'>".$blog->name."</option>\n";
  }
  $html .= "<td><select name='rebuild_when'><option value='entry'>Entry Save</option><option value='placement'>Placement Save</option></select></td>\n";
  $html .= "</select></td><td><input type='submit' value=' Set ' /></td></tr>\n";
  $html .= "</table></form>\n";
  $html .= "</div></div></div>\n";

  $html .= "<div class='box'>\n";
  $html .= "<h4>Access Control</h4>\n";
  $html .= "<div class='inner'>\n";

  $html .= "<p></p>";
  
  if ($acls) {
    $html .= "<h4>Current Controls</h4>\n";
    $html .= "<div class='list'>\n";
    $html .= "<table>\n";
    $html .= "<tr><th>Source Blog:</th><th>Access Type:</th><th>Requesting Blog:</th><th></th></tr>\n";
    my $even = 0;
    foreach my $d (sort {$blog_names{$a} cmp $blog_names{$b}} keys %$acls) {
      $html .= "<tr class='".(($even) ? 'even' : 'odd')."'>";
      my $num = scalar keys %{$acls->{$d}};
      $html .= "<td rowspan='$num'>$blog_names{$d}</td>";
      my @ids = sort {$blog_names{$a} cmp $blog_names{$b}} keys %{$acls->{$d}};
      my $s = shift @ids;
      $html .= "<td><i>".$acls->{$d}->{$s}."</i> from</td>";
      $html .= "<td>$blog_names{$s}</td>";
      $html .= "<td>[ <a href='?__mode=reset_acl&source_blog_id=$s&dest_blog_id=$d'>reset</a> ]</td>";
      $html .= "</tr>";
      $even = !$even;
      foreach $s (@ids) {
	$html .= "<tr class='".(($even) ? 'even' : 'odd')."'>";
  	$html .= "<td><i>".$acls->{$d}->{$s}."</i> from</td>";
    	$html .= "<td>$blog_names{$s}</td>";
      	$html .= "<td>[ <a href='?__mode=reset_acl&source_blog_id=$s&dest_blog_id=$d'>reset</a> ]</td>";
	$html .= "</tr>";
  	$even = !$even;
      }
    }
    $html .= "</table>\n";
    $html .= "</div>\n";
  }

  $html .= "<h4>Configuration</h4>\n";
  $html .= "<div class='list'>\n";

  $html .= "<form method='post'>\n";
  $html .= "<input type='hidden' name='__mode' value='add_acl' />\n";
  $html .= "<table class='list'>\n";
  $html .= "<tr><th>Source Blog</th><th>Access Type</th><th>Requesting Blog</th><th></th></tr>\n";

  $html .= "<tr><td><select name='dest_blog_id'>\n";
  foreach my $blog (@blogs) {
    $html .= "<option value='".$blog->id."'>".$blog->name."</option>\n";
  }
  $html .= "</select></td>\n";
  $html .= "<td><select name='access_type'><option value='allow'>Allow From</option><option value='deny'>Deny From</option></select></td>\n";
  $html .= "<td><select name='source_blog_id'>\n";
  foreach my $blog (@blogs) {
    $html .= "<option value='".$blog->id."'>".$blog->name."</option>\n";
  }
  $html .= "</select></td><td><input type='submit' value=' Set ' /></td></tr>\n";
  $html .= "</table></form>\n";

  $html .= "<form method='post'>\n";
  $html .= "<input type='hidden' name='__mode' value='set_default_access' />\n";
  $html .= "<table>\n";
  $html .= "<tr><th>Default Access Type:</th><th></th></tr>\n";
  $html .= "<tr><td><select name='default_access'><option value='allow'".(($default_access eq 'allow') ? " selected" : "").">ALLOW</option><option value='deny'".(($default_access eq 'deny') ? " selected" : "") .">DENY</option></select></td>\n";
  $html .= "<td><input type='submit' value=' Set ' /></td></tr>\n";
  $html .= "</table></form>\n";

  $html .= "</div>\n";
  $html .= "</div>\n";
  $html .= "</div>\n";

  $html .= "<br clear='both' />\n";

  return $header.$html.$footer;
}

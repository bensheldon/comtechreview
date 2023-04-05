
package rayners::MultiBlog;

use rayners::MultiBlogPlugin;

use MT::Blog;
@ISA = qw( MT::Blog );

__PACKAGE__->install_properties (MT::Blog->properties);

use strict;

use vars qw( $VERSION );
my $VERSION = "1.0.1";

sub copy_blog {
  my $class = shift;
  my $blog = $class->new;
  my $old_blog = shift;
  $blog->set_values ($old_blog->column_values);
  $blog;
}

# Determine if the blog can access another blog
# Returns 1 if it can
# Returns 0 if it cannot

sub can_access {
  my ($blog, $other_blog) = @_;

# A blog should always be able to access itself
  
  return 1 if ($blog->id == $other_blog->id);

# Grab the settings from the database

  my $plugin = rayners::MultiBlogPlugin->plugin;
  my $default = $plugin->get_config_value ('default_access') || 'allow';
  my $acls = $plugin->get_config_value ('acls');

# If _no_ settings are defined (should never happen), default to allow
  
  return 1 if (!$default && !$acls);
  
  if ($default eq 'allow') {

# If the default access is 'allow'
# Check to make sure the blog is not denied only
    
    return 0 if (defined $acls->{$other_blog->id}->{$blog->id} && 
	$acls->{$other_blog->id}->{$blog->id} eq 'deny');
    return 1;
  } elsif ($default eq 'deny') {

# If the default access is 'deny'
# Check to make sur the blog is allowed only
    
    return 1 if (defined $acls->{$other_blog->id}->{$blog->id} && 
	$acls->{$other_blog->id}->{$blog->id} eq 'allow');
    return 0;
  }
}

sub _set_access {
  my ($blog, $access, $other_blog) = @_;

  my $plugin = rayners::MultiBlogPlugin->plugin;

  my $acls = $plugin->get_config_value ('acls');

  return if (!$access or !$other_blog);
  return if ($access !~ /(allow|deny)/);
  return if ($blog->id == $other_blog->id);

  $acls->{$blog->id}->{$other_blog->id} = $access;

  $plugin->set_config_value ('acls', $acls);
}

sub _reset_access {
  my ($blog, $other_blog) = @_;
  my $plugin = rayners::MultiBlogPlugin->plugin;

  return if (!$other_blog);
  return if ($blog->id == $other_blog->id);

  my $acls = $plugin->get_config_value ('acls');

  delete $acls->{$blog->id}->{$other_blog->id};
  if (!scalar keys %{$acls->{$blog->id}}) {
    delete $acls->{$blog->id};
  }

  if (!scalar keys %$acls) {
    undef $acls;
  }

  $plugin->set_config_value ('acls', $acls);

  return;
}


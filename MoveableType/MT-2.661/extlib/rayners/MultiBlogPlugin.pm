
package rayners::MultiBlogPlugin;

use MT;

use vars qw( $VERSION $plugin );
my $VERSION = "1.1.0";
my $plugin;

if (MT->version_number >= 3) {

  require MT::Plugin;
  $plugin = MT::Plugin->new;
  $plugin->name ("MultiBlog");
  $plugin->description ("MultiBlog allows you to define blog rebuild dependencies. Version $VERSION");
  $plugin->config_link ("../multiblog-config.cgi");
  $plugin->doc_link ("http://wiki.rayners.org/plugins/MultiBlog");

  MT->add_plugin ($plugin);

  require MT::Entry;
  require MT::Placement;
  MT::Entry->add_callback	('post_save', 10, $plugin, \&post_save_entry);
  MT::Placement->add_callback	('post_save', 10, $plugin, \&post_save_place);

  require MT::Blog;
  MT::Blog->add_callback	('pre_remove', 10, $plugin, \&post_rem_blog);
}

sub plugin {
  return $plugin;
}

sub post_rem_blog {
  my ($cb, $b) = @_;

  my $rebuilds = $plugin->get_config_value ('rebuilds');
  delete $rebuilds->{$b->id} if ($rebuilds->{$b->id});
  foreach my $id (keys %$rebuilds) {
    delete $rebuilds->{$id}->{$b->id} if ($rebuilds->{$id}->{$b->id});
  }
  $plugin->set_config_value ('rebuilds', $rebuilds);

  my $acls = $plugin->get_config_value ('acls');
  delete $acls->{$b->id} if ($acls->{$b->id});
  foreach my $id (keys %$acls) {
    delete $acls->{$id}->{$b->id} if ($acls->{$id}->{$b->id});
  }
  $plugin->set_config_value ('acls', $acls);

}

sub post_save_entry {
  my ($cb, $entry) = @_;
  
  require MT::Entry;
  if ($entry->status != MT::Entry::RELEASE()) {
    return;
  }

  require MT;
  my $mt = MT->new or return $cb->error (MT->errstr);

# This method is coming soon
# my $mt = MT->instance;

  my $rebuilds = $plugin->get_config_value ('rebuilds');
  return if (!$rebuilds->{$entry->blog_id});

  foreach my $id (sort keys %{$rebuilds->{$entry->blog_id}}) {
    next if ($rebuilds->{$entry->blog_id}->{$id} ne 'entry');
    $mt->rebuild_indexes ( BlogID => $id ) or
      return $cb->error ($mt->errstr);
  }
}

sub post_save_place {
  my ($cb, $place) = @_;

  require MT::Placement;
  if (!$place->is_primary) {
    return;
  }

  require MT;
  my $mt = MT->new or return $cb->error (MT->errstr);

# This method is coming soon
# my $mt = MT->instance;

  my $rebuilds = $plugin->get_config_value ('rebuilds');

  return if (!$rebuilds->{$place->blog_id});

  foreach my $id (sort keys %{$rebuilds->{$place->blog_id}}) {
    next if ($rebuilds->{$place->blog_id}->{$id} ne 'placement');
    $mt->rebuild_indexes ( BlogID => $id ) or
      return $cb->error ($mt->errstr);
  }
}

1;

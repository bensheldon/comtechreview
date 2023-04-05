#!/usr/bin/perl -w

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
  require rayners::MultiBlogApp;
  my $app = rayners::MultiBlogApp->new ( Config => $MT_DIR . 'mt.cfg',
      					 Directory => $MT_DIR )
    or die rayners::MultiBlogApp->errstr;
  local $SIG{__WARN__} = sub { $app->trace ($_[0]) };
  $app->run;
};

if ($@) {
  print "ContentType: text/html\n\n";
  print "An error orcurred: $@";
}

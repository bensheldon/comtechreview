#!/usr/bin/perl -w

# Title:	MT-Blacklist Plugin Web Interface
# Summary:	A plugin for preventing comment and Trackback spam 
# Author:	Jay Allen (http://www.jayallen.org/)
# Version:	1.6.4
# Date:		May 20, 2004
#
# Information about this plugin can be found at
# http://www.jayallen.org/projects/mt-blacklist
#
# Until I get some sleep and can think about licenses:
# Copyright 2003 Jay Allen
# This code cannot be redistributed without
# permission from the author. 

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
	require jayallen::Blacklist;
	my $app = jayallen::Blacklist->new ( Config => $MT_DIR . 'mt.cfg',
      				     Directory => $MT_DIR )
    or die jayallen::Blacklist->errstr;
  local $SIG{__WARN__} = sub { $app->trace ($_[0]) };
  $app->run;
  print '<div id="versiontag">MT-Blacklist Version '.$app->VERSION.'<br />Script execution time: '.(time - $^T).' seconds</div></div>'. ($app->{dumpwarnings} ? $app->_dumpwarn : '').$app->{query}->end_html;
};

if ($@) {
  print "Content-Type: text/html\n\n";
  print "An error occurred: $@";
}

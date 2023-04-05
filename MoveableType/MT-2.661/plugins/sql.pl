# ---------------------------------------------------------------------------
# SQL
# A Plugin for Movable Type
#
# Release 1.52
# November 5, 2002
#
# From Brad Choate
# http://www.bradchoate.com/
# ---------------------------------------------------------------------------
# This software is provided as-is.
# You may use it for commercial or personal use.
# If you distribute it, please keep this notice intact.
#
# Copyright (c) 2002 Brad Choate
# ---------------------------------------------------------------------------

use strict;
use MT::Template::Context;

MT::Template::Context->add_container_tag(SQL => \&SQL);
MT::Template::Context->add_container_tag(SQLHeader => \&SQLHeader);
MT::Template::Context->add_container_tag(SQLFooter => \&SQLFooter);
MT::Template::Context->add_tag(SQLColumn => \&SQLColumn);
MT::Template::Context->add_container_tag(SQLEntries => \&SQLEntries);
MT::Template::Context->add_container_tag(SQLComments => \&SQLComments);
MT::Template::Context->add_container_tag(SQLCategories => \&SQLCategories);
MT::Template::Context->add_container_tag(SQLPings => \&SQLPings);
MT::Template::Context->add_container_tag(SQLAuthors => \&SQLAuthors);

sub SQL {
    require bradchoate::sql;
    &bradchoate::sql::SQL;
}

sub SQLHeader {
    require bradchoate::sql;
    &bradchoate::sql::SQLHeader;
}

sub SQLFooter {
    require bradchoate::sql;
    &bradchoate::sql::SQLFooter;
}

sub SQLColumn {
    require bradchoate::sql;
    &bradchoate::sql::SQLColumn;
}

sub SQLEntries {
    require bradchoate::sql;
    &bradchoate::sql::SQLEntries;
}

sub SQLComments {
    require bradchoate::sql;
    &bradchoate::sql::SQLComments;
}

sub SQLCategories {
    require bradchoate::sql;
    &bradchoate::sql::SQLCategories;
}

sub SQLPings {
    require bradchoate::sql;
    &bradchoate::sql::SQLPings;
}

sub SQLAuthors {
    require bradchoate::sql;
    &bradchoate::sql::SQLAuthors;
}

1;

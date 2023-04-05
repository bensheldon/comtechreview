
# Compare.pl
# Movable Type plugin tags for displaying conditional output based on 
# comparisons of values and/or MT expressions
# by Kevin Shay
# http://www.staggernation.com/mtplugins/
# last modified July 12, 2004

package MT::Plugin::Compare;
use strict;
use vars qw( $VERSION );
$VERSION = '1.1';

use MT;
use MT::Template::Context;

eval{ require MT::Plugin };
unless ($@) {
    my $plugin = {
        name => "Compare $VERSION",
        description => 'Display a section of template code conditionally, based on various types of comparisons of two or more values.',
        doc_link => 'http://www.staggernation.com/mtplugins/Compare'
    }; 
    MT->add_plugin(new MT::Plugin($plugin));
}

MT::Template::Context->add_conditional_tag('IfEqual' => sub{&_hdlr_equality;});
MT::Template::Context->add_conditional_tag('IfNotEqual' => sub{&_hdlr_equality;});
for (qw( IfGreater IfGreaterOrEqual IfLess IfLessOrEqual IfBetween 
		IfBetweenExclusive IfNotBetween )) {
	MT::Template::Context->add_conditional_tag($_ => sub{&_hdlr_inequality;});
}

sub _hdlr_equality {
# handler for equal/not equal tags
	my ($ctx, $args, $cond) = @_;
	defined(my $test = $args->{'a'})
		|| return $ctx->error('No "a" value passed');
	(my @val_args = grep { m/^b\d*/ } keys %$args)
		|| return $ctx->error('No "b" value passed');
	my $case_sensitive = $args->{'case_sensitive'} ? 1 : 0;
	my $num = $args->{'numeric'} ? 1 : 0;
	my $tag = $ctx->stash('tag');
	my $builder = $ctx->stash('builder');
	my $tok = $ctx->stash('tokens');
	$test = build_value($ctx, $test, $case_sensitive);
		# IfEqual: assume no display until we find a match;
		# IfNotEqual: assume display unless we find a match
	my $display = ($tag eq 'IfEqual') ? 0 : 1;
	for (@val_args) {
		my $value = build_value($ctx, $args->{$_}, $case_sensitive);
		if (($num && ($test == $value)) || (!$num && ($test eq $value))) {
				# we have a match
			$display = !$display;
			last;
		}
	}
	return $display;
}

sub _hdlr_inequality {
# handler for greater/less/between tags
	my ($ctx, $args, $cond) = @_;
	my $tag = $ctx->stash('tag');
	my $builder = $ctx->stash('builder');
	my $tok = $ctx->stash('tokens');
	my $case_sensitive = $args->{'case_sensitive'} ? 1 : 0;
	my $num = $args->{'numeric'} ? 1 : 0;
	defined(my $test = $args->{'a'})
		|| return $ctx->error('No "a" value passed');
	my ($value, $upper, $lower);
	if ($tag =~ /Between/) {
		defined($lower = $args->{'lower'})
			|| return $ctx->error('No lower range value passed');
		defined($upper = $args->{'upper'})
			|| return $ctx->error('No upper range value passed');
		$lower = build_value($ctx, $lower, $case_sensitive);
		$upper = build_value($ctx, $upper, $case_sensitive);
	} else {
		defined($value = $args->{'b'})
			|| return $ctx->error('No "b" value passed');
		$value = build_value($ctx, $value, $case_sensitive);
	}
	$test = build_value($ctx, $test, $case_sensitive);
	my $display;
	if ($tag eq 'IfBetweenExclusive') {
		$display = (
			(($num && ($test > $lower)) || (!$num && ($test gt $lower)))
			&& (($num && ($test < $upper)) || (!$num && ($test lt $upper)))
		);
	} elsif ($tag =~ /Between/) {
		$display = (
			(($num && ($test >= $lower)) || (!$num && ($test ge $lower)))
			&& (($num && ($test <= $upper)) || (!$num && ($test le $upper)))
		);
		$display = !$display if ($tag eq 'IfNotBetween');
	} elsif ($tag eq 'IfGreater') {
		$display = (($num && ($test > $value)) || (!$num && ($test gt $value)));
	} elsif ($tag eq 'IfGreaterOrEqual') {
		$display = (($num && ($test >= $value)) || (!$num && ($test ge $value)));
	} elsif ($tag eq 'IfLess') {
		$display = (($num && ($test < $value)) || (!$num && ($test lt $value)));
	} elsif ($tag eq 'IfLessOrEqual') {
		$display = (($num && ($test <= $value)) || (!$num && ($test le $value)));
	}
	return $display;
}

sub build_value {
# convert and build MT template tags within a passed value.
	my ($ctx, $value, $case_sensitive) = @_;
		# within a value argument, you can use MT tags, but with
		# square brackets instead of angle brackets and single quotes
		# instead of double quotes; literal square brackets and single
		# quotes must be escaped with a backslash
		# convert non-escaped []'
	$value =~ s/(?<!\\)\[/</g;
	$value =~ s/(?<!\\)\]/>/g;
	$value =~ s/(?<!\\)'/"/g;
		# de-escape escaped []'
	$value =~ s/\\([\[\]'])/$1/g;
		# any MT tags?
	if ($value =~ /<MT/) {
		my $builder = $ctx->stash('builder');
		my $tok = $builder->compile($ctx, $value);
		$value = $builder->build($ctx, $tok);
		return $ctx->error($builder->errstr) unless defined($value);
	}
	$value = lc($value) unless ($case_sensitive);
	return $value;
}

1;
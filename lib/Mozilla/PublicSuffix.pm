package Mozilla::PublicSuffix;

use strict;
use warnings FATAL => "all";
use utf8;
use parent "Exporter";
use Carp ();
use Net::LibIDN qw(idn_prep_name idn_to_ascii idn_to_unicode);

our @EXPORT_OK = qw(public_suffix);

# VERSION
# ABSTRACT: Get a domain name's "public suffix" via Mozilla's Public Suffix List

my %rules = qw();
sub public_suffix {
	my ($domain) = @_;

	# Test domain well-formedness:
	eval { $domain = idn_to_unicode idn_to_ascii idn_prep_name $domain }
		or Carp::croak("Argument passed is not a well-formed domain name");

	# Gather matching rules:
	my @labels = split /\./, $domain;
	my @matches = sort { $b->{label} =~ /\./g <=> $a->{label} =~ /\./g }
		map {
			my $label = join ".", @labels[ $_ .. $#labels ];
			exists $rules{$label}
				? { type  => $rules{$label}, label => $label }
					: ();
		} 0 .. $#labels;

	# Choose prevailing rule and return suffix, if one is to be found:
	return do {
		@matches == 0
			? undef
			: do {
				my @exc_rules = grep { $_->{type} eq "e" } @matches;
				@exc_rules > 0
					? do {
						@exc_rules == 1
							? undef
							: do {
								# Recheck with left-mode label chopped off
								@_ = $exc_rules[0]{label} =~ /^[^.]+\.(.*)$/;
								goto &public_suffix; } }
					: do {
						my ($type, $label) = @{$matches[0]}{qw(type label)};
						$type eq "w"
							and ($label) = $domain =~ /((?:[^.]+\.)$label)$/;
						$label ||= undef; } } }; }

1;

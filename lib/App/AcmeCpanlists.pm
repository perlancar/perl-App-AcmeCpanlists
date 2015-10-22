package App::AcmeCpanlists;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'The Acme::CPANLists CLI (backend module)',
};

sub _complete_module {
    require Complete::Module;
    my %args = @_;

    Complete::Module::complete_module(
        %args,
        ns_prefix => 'Acme::CPANLists',
    );
}

my %args_filtering = (
    module => {
        schema => 'str*',
        cmdline_aliases => {m=>{}},
        completion => \&_complete_module,
        tags => ['category:filtering'],
    },
    type => {
        schema => ['str*', in=>[qw/author a module m/]],
        cmdline_aliases => {t=>{}},
        tags => ['category:filtering'],
    },
);

my %arg_detail = (
    detail => {
        name => 'Return detailed records instead of just name/ID',
        schema => 'bool',
        cmdline_aliases => {l=>{}},
    },
);

$SPEC{list_mods} = {
    v => 1.1,
    summary => 'List all installed Acme::CPANLists modules',
    args => {
        # XXX detail
    },
};
sub list_mods {
    require PERLANCAR::Module::List;

    my $res = PERLANCAR::Module::List::list_modules(
        'Acme::CPANLists::', {list_modules=>1});

    my @res;
    for (sort keys %$res) {
        s/^Acme::CPANLists:://;
        push @res, $_;
    }

    [200, "OK", \@res];
}

$SPEC{list_lists} = {
    v => 1.1,
    summary => 'List CPAN lists',
    args => {
        %args_filtering,
        %arg_detail,
    },
};
sub list_lists {
    no strict 'refs';

    my %args = @_;

    my $detail = $args{detail};
    my $type = $args{type};

    my @mods;
    if ($args{module}) {
        @mods = ($args{module});
    } else {
        my $res = list_mods();
        @mods = @{$res->[2]};
    }

    for my $mod (@mods) {
        my $mod_pm = $mod; $mod_pm =~ s!::!/!g; $mod_pm .= ".pm";
        require "Acme/CPANLists/$mod_pm";
    }

    my @cols;
    if ($detail) {
        @cols = (qw/name type summary num_entries/);
    } else {
        @cols = (qw/name/);
    }

    my @rows;
    if (!$type || $type eq 'author' || $type eq 'a') {
        for my $mod (@mods) {
            for my $l (@{ "Acme::CPANLists::$mod\::Author_Lists" }) {
                my $rec = {
                    type => 'author',
                    module => $mod,
                    summary => $l->{summary},
                    num_entries => scalar(@{ $l->{entries} // []}),
                };
                $rec->{_ref} = $l if $args{_with_ref};
                push @rows, $detail ? $rec : $rec->{summary};
            }
        }
    }
    if (!$type || $type eq 'module' || $type eq 'm') {
        for my $mod (@mods) {
            for my $l (@{ "Acme::CPANLists::$mod\::Module_Lists" }) {
                my $rec = {
                    type => 'module',
                    module => $mod,
                    summary => $l->{summary},
                    num_entries => scalar(@{ $l->{entries} // []}),
                };
                $rec->{_ref} = $l if $args{_with_ref};
                push @rows, $detail ? $rec : $rec->{summary};
            }
        }
    }

    [200, "OK", \@rows, {'table.fields'=>\@cols}];
}

$SPEC{get_list} = {
    v => 1.1,
    summary => 'Get a CPAN list',
    args => {
        %args_filtering,
        %arg_detail,
        all => {
            schema => 'bool',
        },
        query => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
    },
};
sub get_list {
    no strict 'refs';

    my %args = @_;

    my $res = list_lists(
        (map {(module=>$args{$_}) x !!defined($args{$_})}
             keys %args_filtering),
        detail => 1,
        _with_ref => 1,
    );

    my @rows;
    for my $row (@{ $res->[2] }) {
        if ($row->{summary} eq $args{query}) {
            my $rec = $row->{_ref};
            if ($args{all}) {
                push @rows, $rec;
            } else {
                return [200, "OK", $rec];
            }
        }
    }

    [200, "OK", \@rows];
}

1;
#ABSTRACT:

=head1 SEE ALSO

Use the included script L<acme-cpanlists>.

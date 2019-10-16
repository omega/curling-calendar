package CurlingCalendar::Model::Data 0.99;

use 5.014;
use DateTime::Format::Strptime;
use DateTime::Format::ISO8601;
use Mojo::Collection;
use Scalar::Util qw();

sub get_season {
    my ($self, $league, $year, $division, $dom) = @_;

    my $season = CurlingCalendar::Model::Data::Season->new(
        league => $league,
        division => $division,
        year => $year,
    );


    if (Scalar::Util::blessed($dom) and $dom->isa('Mojo::DOM')) {
        my $fmt = DateTime::Format::Strptime->new(
            pattern => '%Y/%d/%m %R',
            locale => 'nb_NO',
            time_zone => 'Europe/Oslo',
            on_error => 'croak',
        );
        $dom->find('table tr')->each(sub {
                state $count = 0;
                my $row = shift;
                if ($count) {
                    # this is a proper row
                    my $d = $row->child_nodes->map('all_text')->flatten->compact->to_array;
                    return unless scalar(@$d);
                    my $date = $fmt->parse_datetime(
                        ($d->[0] =~ m|/1\d$| ? $year - 1 : $year) . "/" . shift(@$d)
                        . " " . shift(@$d)
                    );
                    my $location = shift(@$d) . ", " . shift(@$d);
                    my $res;
                    if (scalar(@$d) > 2) {
                        # We have a result
                        $res = join(" ", @$d[2..4]);
                    }

                    $season->add_match(CurlingCalendar::Model::Data::Match->new(
                            home => $d->[0],
                            away => $d->[1],
                            time => $date,
                            location => $location,
                            result => $res,
                        )
                    );
                }
                $count++;
            }
        );
    } else {
        # We have JSON?
        #
        foreach my $m (@$dom) {
            next unless $m->{home} =~ m/^$division/;
            my $t = DateTime::Format::ISO8601->parse_datetime(delete $m->{time});

            $season->add_match(CurlingCalendar::Model::Data::Match->new(%$m, time => $t));
        }
    }
    return $season;

}


package CurlingCalendar::Model::Data::Season {
    use Moo;

    has league => (
        is => 'ro',
        required => 1,
    );
    has division => (
        is => 'ro',
        required => 1,
    );
    has year => (
        is => 'ro',
        required => 1,
    );
    has matches => (
        is => 'ro',
        default => sub { Mojo::Collection->new() },
        handles => [qw/each size/],
    );

    sub add_match {
        my ($self, $match ) = @_;

        push(@{ $self->matches }, $match);
    }

    sub matches_for_team {
        my ($self, $team) = @_;
        return $self->new(
            league => $self->league,
            year => $self->year,
            division => $self->division,
            matches => $self->matches->grep('is_team_playing', $team)
        );
    }

    sub as_table {
        my $self = shift;

        # Re-format the data to a table?
        my %teams = ();
        $self->matches->each(sub {
                my $m = shift;
                for (qw/home away/) {
                    $teams{$m->$_} = {
                        name => $m->$_,
                        points => 0,
                        played => 0,
                        beat => {},
                    } unless exists $teams{$m->$_};
                    $teams{$m->$_}->{played}++ if $m->result;
                }
                if ($m->result) {
                    my $score = eval $m->result;
                    if (eval $m->result > 0) {
                        $teams{$m->home}->{points} += 2;
                        $teams{$m->home}->{beat}->{$m->away} = 1;

                    } elsif (eval $m->result == 0) {
                        $teams{$m->home}->{points} += 1;
                        $teams{$m->away}->{points} += 1;
                    } else {
                        $teams{$m->away}->{points} += 2;
                        $teams{$m->away}->{beat}->{$m->home} = 1;
                    }
                }
            }
        );
        my $table = CurlingCalendar::Model::Data::Table->new();
        foreach my $t (sort {
                $teams{$b}->{points} <=> $teams{$a}->{points}
                || # equal points, need to look at more data somehow..?
                ($teams{$b}->{beat}->{$a} // 0) <=> ($teams{$a}->{beat}->{$b} // 0)
            } keys %teams) {
            push(@{ $table->entries }, $teams{$t});
        }
        return $table;
    }
    sub description {
        my $self = shift;
        return sprintf("%s %d. divisjon %d/%d", $self->league, $self->division, $self->year-1, $self->year);
    }
    sub TO_JSON {
        return shift->matches;
    }
};
package CurlingCalendar::Model::Data::Table {
    use Moo;

    has entries => (
        is => 'ro',
        default => sub { Mojo::Collection->new() },
        handles => [qw/each size TO_JSON/],
    );
};
package CurlingCalendar::Model::Data::Match {
    use Moo;

    has [qw/home away/] => (
        is => 'ro',
        required => 1,
    );
    has location => (
        is => 'ro',
        required => 1,
    );
    has time => (
        is => 'ro',
        required => 1,
    );

    has result => (
        is => 'ro',
        required => 0,
        predicate => 1,
    );
    sub uid {
        my $self = shift;
        my $season = shift;
        return sprintf("%s/%d/%d.division/%s-%s",
            $season->league, $season->year, $season->division,
            $self->home, $self->away
        );
    }
    sub start {
        return shift->time->clone;
    }
    sub end {
        return shift->time->clone->add(hours => 2);
    }
    sub description {
        my $self = shift;
        my $season = shift;
        return sprintf("%s: %s - %s%s", $season->league,
            $self->home, $self->away,
            ($self->result ? " (" . $self->result . ")" : "")
        );
    }

    sub home_points {
        my $self = shift;
        return unless $self->result;
        my ($pts) = ( $self->result =~ m|(\d+) -| );
        return $pts;
    }
    sub away_points {
        my $self = shift;
        return unless $self->result;
        my ($pts) = ( $self->result =~ m|- (\d+)| );
        return $pts;
    }
    sub is_team_playing {
        my ($self, $team) = @_;
        $team = lc($team);
        return (lc($self->home) eq $team or lc($self->away) eq $team);
    }
    sub is_team_victorious {
        my ($self, $team) = @_;
        $team = lc($team);
        return unless $self->result;
        return unless $self->is_team_playing($team);

        if (eval $self->result > 0 and $team eq lc($self->home)) {
            return 1;
        } elsif(eval $self->result < 0  and $team eq lc($self->away)) {
            return 1;
        }
    }

    sub is_team_lost {
        my ($self, $team) = @_;
        $team = lc($team);
        return unless $self->result;
        return unless $self->is_team_playing($team);

        if (eval $self->result < 0 and $team eq lc($self->home)) {
            return 1;
        } elsif (eval $self->result > 0 and $team eq lc($self->away)) {
            return 1;
        }
    }

    sub TO_JSON {
        my $self = shift;
        return { %$self };
    }

};
1;

__END__

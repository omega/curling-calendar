package CurlingCalendar;
use Mojo::Base 'Mojolicious';

use Path::Tiny;
use CurlingCalendar::Model::Data;

use HTTP::Tiny;
use Encode;

# This method will run once at server start
sub startup {
    my $self = shift;

    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');
    $self->plugin('CHI' => {
            default => {
                driver => 'File',
                root_dir => 'cache/',
                depth => 3,
                max_key_length => 128,
            }
        }
    );


    $self->types->type(ical => 'text/calendar');

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->get('/')->to('root#index');

    $r->get('/:league/:year/:division/:team')->to('root#division');


    $self->helper('curling.fetch_league' => sub {
            my ($c, $cb) = @_;
            my $league = $c->stash->{league};
            my $year = $c->stash->{year};
            my $division = $c->stash->{division};
            my $team = $c->stash->{team};
            my $cache_key = join("_", $league, $year, $division);

            my $parser = sub {
                my ($dom, $cb) = @_;
                # We should parse it all, and call the $cb with some sort of
                # structure
                $c->app->log->debug("In the parser");
                my $season = CurlingCalendar::Model::Data->get_season($league, $year, $division, $dom);
                if ($team) {
                    $season = $season->matches_for_team($team);
                }
                $cb->($season);
            };

            if (my $html = $c->chi->get($cache_key)) {
                $c->app->log->debug("found $cache_key in cache");
                my $dom = Mojo::DOM->new( $html );
                $parser->($dom, $cb);
            } else {
                my $url = 'http://www.runewaage.com/oack2/oppsett.php?a=' . ($division + 5);
                $c->app->log->debug("Fetching content from $url");

                my $res = HTTP::Tiny->new->get($url);

                my $content = Encode::decode_utf8( $res->{content} );
                $c->chi->set($cache_key => $content);
                $parser->(Mojo::DOM->new($content), $cb);
            }
        });
}

1;

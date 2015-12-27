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

    $r->get('/:league/:year/:division')->to('root#division');
    $r->get('/:league/:year/:division/:team')->to('root#team');


    $self->helper('curling.fetch_division' => sub {
            my ($c, $cb) = @_;
            $c->curling->fetch_season(sub {
                    $cb->(shift->as_table);
                }
            );

        }
    );


    $self->helper('curling.fetch_team' => sub {
            my ($c, $cb) = @_;
            $c->curling->fetch_season(sub {
                    $cb->(shift->matches_for_team($c->stash->{team}));
                }
            );
        }
    );
    $self->helper('curling.fetch_season' => sub {
            my ($c, $parser) = @_;
            my $division = $c->stash->{division};
            my $cache_key = join("_", $c->stash->{league}, $c->stash->{year}, $division);

            my $html;

            if ($html = $c->chi->get($cache_key)) {
                $c->app->log->debug("found $cache_key in cache");
            } else {
                my $url = 'http://www.runewaage.com/oack2/oppsett.php?a=' . ($division + 5);
                $c->app->log->debug("Fetching content from $url");

                my $res = HTTP::Tiny->new->get($url);

                $html = Encode::decode_utf8( $res->{content} );
                $c->chi->set($cache_key => $html, '1 day');
            }
            my $season = CurlingCalendar::Model::Data->get_season(
                $c->stash->{league}, $c->stash->{year}, $c->stash->{division},
                Mojo::DOM->new( $html ),
            );
            $parser->($season);
        });
}

1;

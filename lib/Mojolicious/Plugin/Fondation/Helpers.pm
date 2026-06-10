package Mojolicious::Plugin::Fondation::Helpers;
# ABSTRACT: All Fondation helpers in one place -- keeps Fondation.pm minimal

use Mojo::Base -base, -signatures;
use Mojo::ByteStream 'b';

sub register ($class, $app, $manager) {

    # ═══════════════════════════════════════════════════════════════════════
    # ── Core identity ──
    # ═══════════════════════════════════════════════════════════════════════
    $app->helper(manager => sub { $manager });

    # Stable public API (recommended over direct manager access)
    $app->helper(fondation => sub { $manager->api });

    # ═══════════════════════════════════════════════════════════════════════
    # ── Fallback helpers -- overridden by specialized plugins ──
    # Must be registered BEFORE load_plugin_recursive so plugins can override.
    # ═══════════════════════════════════════════════════════════════════════

    # Overridden by I18N-like plugins
    $app->helper(l => sub { $_[1] });

    # Fallback i18n_js -- injected by layout before app JS.
    # Identity function when I18N absent; overridden by I18N-like plugins.
    $app->helper(i18n_js => sub ($c) {
        return Mojo::ByteStream->new(
            q{<script>window.l=function(k){return k;};</script>}
        );
    });

    # Overridden by a Notification plugin
    $app->helper(notify_user => sub { Mojo::Promise->resolve() });

    # Overridden by a Authorization plugin -- permissive fallback (allow all)
    $app->helper(check_group => sub { 1 });
    $app->helper(check_perm  => sub { 1 });

    # Overridden by a validation plugin
    $app->helper(valid_input => sub ($c) { $c });


    # ═══════════════════════════════════════════════════════════════════════
    # ── Real helpers (not no-ops) ──
    # ═══════════════════════════════════════════════════════════════════════

    # Check whether a helper exists (Mojo helpers are not visible via $c->can).
    $app->helper(has_helper => sub ($c, $name) {
        return exists $c->app->renderer->helpers->{$name};
    });


    # ═══════════════════════════════════════════════════════════════════════
    # ── Zone system ──
    # ═══════════════════════════════════════════════════════════════════════

    $app->helper(render_zone_type => sub ($c, $type, $zone) {
        my $manager = $c->app->manager;
        my $output  = '';

        for my $long (@{$manager->load_order}) {
            my $entry = $manager->registry->{$long};
            next unless $entry;

            my $files = $entry->{zones}{$type}{$zone} // [];
            next unless @$files;

            if ($type eq 'html') {
                for my $template (@$files) {
                    $output .= $c->render_to_string(
                        template => $template,
                        layout   => undef,
                    );
                }
            }
            else {
                for my $content (@$files) {
                    $output .= $content;
                }
            }
        }

        return $output;
    });

    $app->helper(render_zone => sub ($c, $zone) {
        return $c->render_zone_type('html', $zone);
    });

    $app->helper(render_zone_js => sub ($c, $zone) {
        return $c->render_zone_type('js', $zone);
    });

    return;
}

1;

# CPAN dependencies for Mojolicious-Plugin-Fondation
# This file is used by cpanminus (cpanm) and Carton

# Minimum Perl version required (for Mojolicious signatures feature)
requires 'perl' => '5.026';

# Runtime dependencies
requires 'Mojolicious' => '9.00';  # Mojolicious 9.00+ for -signatures support
requires 'File::ShareDir' => '1.00';  # For finding shared files
requires 'Role::Tiny' => '2.000000';  # For ConfigMerge role functionality

# Optional dependencies (for enhanced functionality)
recommends 'Mojolicious::Plugin::Config' => '2.00';  # For configuration merging

# Testing dependencies
on test => sub {
    requires 'Test::More' => '1.00';
    requires 'File::Temp' => '0.01';
    requires 'File::Spec' => '3.00';
    requires 'FindBin' => '1.00';
    requires 'File::Path' => '2.00';
};

# Development dependencies (for author)
on develop => sub {
    # Dist::Zilla dependencies are managed by dist.ini
    # These are additional tools for development
    recommends 'Perl::Critic' => '1.00';
    recommends 'Perl::Tidy' => '20200000';
    recommends 'Pod::Checker' => '1.00';
};
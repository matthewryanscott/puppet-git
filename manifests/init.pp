# GIT Repository Utils
#
# This is a module from puppetmanaged.org
#

class git {

    class client {

        #
        # Documentation on this class
        #
        # This class causes the client to gain git capabilities. Boo!
        #

        case $lsbdistcodename {
          etch: {
            os::backported_package{"git-core":
              ensure => installed
            }
          }

          default: {
            package { "git-core":
              ensure => installed
            }
          }
        }
    }

    class server inherits client {

        #
        # Documentation on this class
        #
        # Including this class will install git, the git-daemon, ensure the
        # service is running
        #

        package { "git-daemon-run":
            ensure => installed
        }

        #service { "git":
        #    enable => true,
        #    ensure => running,
        #    require => Package["git-daemon-run"],
        #    notify => Service["xinetd"]
        #}

        #service { "xinetd":
        #    enable => true,
        #    ensure => running
        #}

        file { "/srv/git/":
            ensure => directory,
            mode => 755
        }

        file { "/usr/local/bin/git_init_script":
            owner => "root",
            group => "root",
            mode => 750,
            source => [
                #"puppet://$server/private/$domain/git/git_init_script",
                #"puppet://$server/files/git/git_init_script",
                "puppet://$server/git/git_init_script"
            ]
        }
    }

    define repository(  $public = false, $shared = false,
                        $localtree = "/srv/git/", $owner = "root",
                        $group = "root", $symlink_prefix = false,
                        $prefix = false, $recipients = false,
                        $description = false) {
        # FIXME
        # Why does this include server? One can run repositories without a
        # git daemon..!!
        #
        # - The defined File["git_init_script"] resource will need to move to
        # this class
        #
        # Documentation on this resource
        #
        # Set $public to true when calling this resource to make the repository
        # readable to others
        #
        # Set $shared to true to allow the group owner (set with $group) to
        # write to the repository
        #
        # Set $localtree to the base directory of where you would like to have
        # the git repository located.
        #
        # The actual git repository would end up in $localtree/$name, where
        # $name is the title you gave to the resource.
        #
        # Set $owner to the user that is the owner of the entire git repository
        #
        # Set $group to the group that is the owner of the entire git repository
        #
        # Set $init to false to prevent the initial commit to be made
        #

        include server

        file { "git_repository_$name":
            path => $prefix ? {
                false => "$localtree/$name",
                default => "$localtree/$prefix-$name"
            },
            ensure => directory,
            owner => "$owner",
            group => "$group",
            mode => $public ? {
                true => $shared ? {
                    true => 2775,
                    default => 0755
                },
                default => $shared ? {
                    true => 2770,
                    default => 0750
                }
            }
        }

        # Set the hook for this repository
        file { "git_repository_hook_post-commit_$name":
            path => $prefix ? {
                false => "$localtree/$name/hooks/post-commit",
                default => "$localtree/$prefix-$name/hooks/post-commit"
            },
            source => "puppet://$server/git/post-commit",
            mode => 755,
            require => [
                File["git_repository_$name"],
                Exec["git_init_script_$name"]
            ]
        }

        file { "git_repository_hook_update_$name":
            path => $prefix ? {
                false => "$localtree/$name/hooks/update",
                default => "$localtree/$prefix-$name/hooks/update"
            },
            ensure => "$localtree/$name/hooks/post-commit",
            require => [
                File["git_repository_$name"],
                Exec["git_init_script_$name"]
            ]
        }

        file { "git_repository_hook_post-update_$name":
            path => $prefix ? {
                false => "$localtree/$name/hooks/post-update",
                default => "$localtree/$prefix-$name/hooks/post-update"
            },
            mode => 755,
            owner => "$owner",
            group => "$group",
            require => [
                File["git_repository_$name"],
                Exec["git_init_script_$name"]
            ]
        }

        # In case there are recipients defined, get in the commit-list
        case $recipients {
            false: {}
            default: {
                file { "git_repository_commit_list_$name":
                    path => $prefix ? {
                        false => "$localtree/$name/commit-list",
                        default => "$localtree/$prefix-$name/commit-list"
                    },
                    content => template('git/commit-list.erb'),
                    require => [
                        File["git_repository_$name"],
                        Exec["git_init_script_$name"]
                    ]
                }
            }
        }

        case $description {
            false: {}
            default: {
                file { "git_repository_description_$name":
                    path => $prefix ? {
                        false => "$localtree/$name/description",
                        default => "$localtree/$prefix-$name/description"
                    },
                    content => "$description",
                    require => [
                        File["git_repository_$name"],
                        Exec["git_init_script_$name"]
                    ]
                }
            }
        }

        exec { "git_init_script_$name":
            command => $prefix ? {
                false => "git_init_script --localtree $localtree --name $name --shared $shared --public $public --owner $owner --group $group",
                default => "git_init_script --localtree $localtree --name $prefix-$name --shared $shared --public $public --owner $owner --group $group"
            },
            creates => $prefix ? {
                false => "$localtree/$name/info",
                default => "$localtree/$prefix-$name"
            },
            require => [
                File["git_repository_$name"],
                File["/usr/local/bin/git_init_script"]
            ]
        }
    }

    define repository::domain(  $public = false,
                                $shared = false,
                                $localtree = "/srv/git/",
                                $owner = "root",
                                $group = "root",
                                $symlink_prefix = false,
                                $recipients = false,
                                $description = false) {
        repository { "$name":
            public => $public,
            shared => $shared,
            localtree => "$localtree/",
            owner => "$owner",
            group => "git-$name",
            prefix => "domain",
            symlink_prefix => "$symlink_prefix",
            recipients => $recipients,
            description => "$description",
            require => Group["git-$name"]
        }

        group { "git-$name":
            ensure => present
        }

        user { "satellite-$name":
            ensure => present,
            comment => "Satellite user for domain $name",
            groups => "git-$name",
            shell => "/usr/bin/git-shell"
        }
    }

    define clean($localtree = "/srv/git/", $real_name = false) {

        #
        # Resource to clean out a working directory
        # Useful for directories you want to pull from upstream, but might
        # have added files. This resource is applied for all pull resources,
        # by default.
        #

        exec { "git_clean_exec_$name":
            cwd => $real_name ? {
                false => "$localtree/$name",
                default => "$localtree/$real_name"
            },
            command => "git clean -d -f"
        }
    }

    define reset($localtree = "/srv/git/", $real_name = false, $clean = true) {

        #
        # Resource to reset changes in a working directory
        # Useful to undo any changes that might have occured in directories
        # that you want to pull for. This resource is automatically called
        # with every pull by default.
        #
        # You can set $clean to false to prevent a clean (removing untracked
        # files)
        #

        exec { "git_reset_exec_$name":
            cwd => $real_name ? {
                false => "$localtree/$name",
                default => "$localtree/$real_name"
            },
            command => "git reset --hard HEAD"
        }

        if $clean {
            clean { "$name":
                localtree => "$localtree",
                real_name => "$real_name"
            }
        }
    }

    define pull($localtree = "/srv/git/", $real_name = false,
                $reset = true, $clean = true, $branch = false) {

        #
        # This resource enables one to update a working directory
        # from an upstream GIT source repository. Note that by default,
        # the working directory is reset (undo any changes to tracked
        # files), and clean (remove untracked files)
        #
        # Note that to prevent a reset to be executed, you can set $reset to
        # false when calling this resource.
        #
        # Note that to prevent a clean to be executed as part of the reset, you
        # can set $clean to false
        #

        if $reset {
            reset { "$name":
                localtree => "$localtree",
                real_name => "$real_name",
                clean => $clean
            }
        }

        @exec { "git_pull_exec_$name":
            cwd => "$localtree/$real_name",
            command => "git pull",
            onlyif => "test -d $localtree/$real_name/.git/info"
        }

        case $branch {
            false: {}
            default: {
                exec { "git_pull_checkout_$branch_$localtree/$_name":
                    cwd => "$localtree/$_name",
                    command => "git checkout --track -b $branch origin/$branch",
                    creates => "$localtree/$_name/refs/heads/$branch"
                }
            }
        }

        if defined(Git::Reset["$name"]) {
            Exec["git_pull_exec_$name"] {
                require +> Git::Reset["$name"]
            }
        }

        if defined(Git::Clean["$name"]) {
            Exec["git_pull_exec_$name"] {
                require +> Git::Clean["$name"]
            }
        }

        realize(Exec["git_pull_exec_$name"])
    }

    define clone(   $source,
                    $localtree = "/srv/git/",
                    $real_name = false,
                    $branch = false) {
        if $real_name {
            $_name = $real_name
        }
        else {
            $_name = $name
        }

        exec { "git_clone_exec_$localtree/$_name":
            cwd => $localtree,
            command => "git clone $source $_name",
            creates => "$localtree/$_name/.git/"
        }

        case $branch {
            false: {}
            default: {
                exec { "git_clone_checkout_$branch_$localtree/$_name":
                    cwd => "$localtree/$_name",
                    command => "git checkout --track -b $branch origin/$branch",
                    creates => "$localtree/$_name/.git/refs/heads/$branch"
                }
            }
        }
    }
}

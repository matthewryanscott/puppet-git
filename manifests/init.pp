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

        package { "git":
            ensure => installed
        }
    }

    class server inherits client {

        #
        # Documentation on this class
        #
        # Including this class will install git, the git-daemon, ensure the service is running
        #

        package { "git-daemon":
            ensure => installed
        }

        service { "git":
            enable => true,
            ensure => running,
            require => Package["git-daemon"],
            notify => Service["xinetd"]
        }

        service { "xinetd":
            enable => true,
            ensure => running
        }

        file { "/usr/local/bin/git_init_script":
            owner => "root",
            group => "root",
            mode => 750,
            source => "puppet://$server/git/usr/local/bin/git_init_script"
        }
    }

    define repository(  $public = false, $shared = false, $localtree = "/srv/git",
                        $owner = "root", $group = "root", $init = true,
                        $symlink_prefix = "puppet", $recipients = false) {
        # FIXME
        # Why does this include server? One can run repositories without a git daemon..!!
        # - The defined File["git_init_script"] resource will need to move to this class
        #
        # Documentation on this resource
        #
        # Set $public to true when calling this resource to make the repository readable to others
        #
        # Set $shared to true to allow the group owner (set with $group) to write to the repository
        #
        # Set $localtree to the base directory of where you would like to have the git repository located.
        # The actual git repository would end up in $localtree/$name, where $name is the title you gave to
        # the resource.
        #
        # Set $owner to the user that is the owner of the entire git repository
        #
        # Set $group to the group that is the owner of the entire git repository
        #
        # Set $init to false to prevent the initial commit to be made
        #

        include server

        file { "git_repository_$name":
            path => "$localtree/$name",
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
        file { "git_repository_hook_$name":
            path => "$localtree/$name/hooks/post-commit",
            content => template('git/post-commit.erb'),
            mode => 755
        }

        # In case there are recipients defined, get in the commit-list
        case $recipients {
            false: {}
            default: {
                file { "git_repository_commit_list_$name":
                    path => "$localtree/$name/commit-list,
                    content => $recipients
                }

                @file { "/usr/local/bin/send-unicode-email.py":
                    source => [
                        "puppet://$server/private/$domain/git/send-unicode-email.py",
                        "puppet://$server/files/git/send-unicode-email.py",
                        "puppet://$server/git/send-unicode-email.py"
                    ],
                    mode => 755,
                    owner => "root",
                    group => "root"
                }
            }
        }

        file { "git_repository_symlink_$name":
            path => "/git/$symlink_prefix-$name",
            links => manage,
            backup => false,
            ensure => "$localtree/$name"
        }

        exec { "git_init_script_$name":
            command => $init ? {
                true => "git_init_script --localtree $localtree --name $name --shared $shared --public $public --owner $owner --group $group --init-commit",
                default => "git_init_script --localtree $localtree --name $name --shared $shared --public $public --owner $owner --group $group"
            },
            require => [ File["git_repository_$name"], File["/usr/local/bin/git_init_script"] ]
        }
    }

    define clean($localtree = "/srv/git") {

        #
        # Resource to clean out a working directory
        # Useful for directories you want to pull from upstream, but might
        # have added files. This resource is applied for all pull resources,
        # by default.
        #

        exec { "git_clean_exec_$name":
            cwd => "$localtree/$name",
            command => "git clean -d -f"
        }
    }

    define reset($localtree = "/srv/git", $clean = true) {

        #
        # Resource to reset changes in a working directory
        # Useful to undo any changes that might have occured in directories
        # that you want to pull for. This resource is automatically called
        # with every pull by default.
        #
        # You can set $clean to false to prevent a clean (removing untracked files)
        #

        exec { "git_reset_exec_$name":
            cwd => "$localtree/$name",
            command => "git reset --hard HEAD"
        }

        if $clean {
            clean { "$name":
                localtree => "$localtree"
            }
        }
    }

    define pull($source = false, $localtree = "/srv/git", $reset = true, $clean = true, $branch = false) {

        #
        # This resource enables one to update a working directory
        # from an upstream GIT source repository. Note that by default,
        # the working directory is reset (undo any changes to tracked
        # files), and clean (remove untracked files)
        #
        # Note that to prevent a reset to be executed, you can set $reset to false when
        # calling this resource.
        #
        # Note that to prevent a clean to be executed as part of the reset, you can
        # set $clean to false
        #

        if $reset {
            reset { "$name":
                localtree => "$localtree",
                clean => $clean
            }
        }

        case $source {
            false: {
                exec { "git_pull_exec_$name":
                    cwd => "$localtree/$name",
                    command => "git pull",
                    onlyif => "test -d $localtree/$name/.git",
                    require => Reset["$name"]
                }
            }
            default: {
                clone { "$name":
                    localtree => "$localtree",
                    source => "$source"
                }

                exec { "git_pull_exec_$name":
                    cwd => "$localtree/$name",
                    command => $branch ? {
                        false => "git pull $source",
                        default => "git pull $source $branch"
                    },
                    onlyif => "test -d $localtree/$name/.git",
                    require => [ Clone["$name"], Reset["$name"], Clean["$name"] ]
                }
            }
        }
    }

    define clone($source, $localtree = "/srv/git") {
        exec { "git_clone_exec_$name":
            cwd => $localtree,
            command => "git clone $source $name",
            creates => "$localtree/$name/"
        }
    }

    define repository::domain(  $public = false, $shared = false, $localtree = "/srv/git", $owner = "root",
                                $group = "root", $init = true, $recipients = false) {
        repository { "$name":
            public => $public,
            shared => $shared,
            localtree => "$localtree/domains",
            owner => "$owner",
            group => "git-$name",
            init => $init,
            recipients => $recipients,
            require => Group["git-$name"]
        }

        group { "git-$name":
            ensure => present
        }
    }
}
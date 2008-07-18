# GIT Repository Utils
#
# This is a module from puppetmanaged.org
#

class git::client {

    #
    # Documentation on this class
    #
    # This class causes the client to gain git capabilities. Boo!
    #

    package { "git-core":
        ensure => installed
    }
}

class git::server inherits git::client {

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

define git::repository( $public = false, $shared = false, $localtree = "/srv/git",
                        $owner = "root", $group = "root", $init = true,
                        $symlink_prefix = "puppet") {
    # FIXME
    # Why does this include git::server? One can run git::repositories without a git daemon..!!
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

    include git::server

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

define git::clean($localtree = "/srv/git") {

    #
    # Resource to clean out a working directory
    # Useful for directories you want to git::pull from upstream, but might
    # have added files. This resource is applied for all git::pull resources,
    # by default.
    #

    exec { "git_clean_exec_$name":
        cwd => "$localtree/$name",
        command => "git clean -d -f"
    }
}

define git::reset($localtree = "/srv/git", $clean = true) {

    #
    # Resource to reset changes in a working directory
    # Useful to undo any changes that might have occured in directories
    # that you want to git::pull for. This resource is automatically called
    # with every git::pull by default.
    #
    # You can set $clean to false to prevent a git::clean (removing untracked files)
    #

    exec { "git_reset_exec_$name":
        cwd => "$localtree/$name",
        command => "git reset --hard HEAD"
    }

    if $clean {
        git::clean { "$name":
            localtree => "$localtree"
        }
    }
}

define git::pull($source = false, $localtree = "/srv/git", $reset = true, $clean = true) {

    #
    # This resource enables one to update a working directory
    # from an upstream GIT source repository. Note that by default,
    # the working directory is git::reset (undo any changes to tracked
    # files), and git::clean (remove untracked files)
    #
    # Note that to prevent a git::reset to be executed, you can set $reset to false when
    # calling this resource.
    #
    # Note that to prevent a git::clean to be executed as part of the git::reset, you can
    # set $clean to false
    #

    if $reset {
        git::reset { "$name":
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
                require => Git::Reset["$name"]
            }
        }
        default: {
            exec { "git_pull_exec_$name":
                cwd => "$localtree/$name",
                command => "git pull $source",
                onlyif => "test -d $localtree/$name/.git",
                require => Git::Reset["$name"]
            }
        }
    }
}

define git::clone($source, $localtree = "/srv/git") {
    file { "git_clone_file_$name":
        path => "$localtree/$name",
        ensure => absent,
        purge => true,
        recurse => true,
        force => true
    }

    exec { "git_clone_exec_$name":
        cwd => $localtree,
        command => "git clone $source $name",
        require => File["git_clone_file_$name"],
        creates => "$localtree/$name/.git/"
    }
}

define git::repository::domain($public = false, $shared = false, $localtree = "/srv/git", $owner = "root", $group = "root", $init = true) {
    git::repository { "$name":
        public => $public,
        shared => $shared,
        localtree => "$localtree/domains",
        owner => "$owner",
        group => "git-$name",
        init => $init,
        require => Group["git-$name"]
    }

    group { "git-$name":
        ensure => present
    }
}

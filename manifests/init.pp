# GIT Repository Utils

class git::client {
    package { "git-core":
        ensure => installed
    }
}

class git::server inherits git::client {
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

define git::repository($public = false, $shared = false, $localtree = "/srv/git/", $owner = "root", $group = "root") {
    include git::server

    file { "git_repository_$name":
        path => "$localtree/$name",
        ensure => directory,
        owner => $owner,
        group => $group,
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
        path => "/git/$name",
        links => manage,
        backup => false,
        ensure => "$localtree/$name"
    }

    exec { "git_init_script_$name":
        command => "git_init_script --localtree $localtree --name $name --shared $shared --owner $owner --group $group",
        require => [ File["git_repository_$name"], File["/usr/local/bin/git_init_script"] ]
    }
}

define git::reset($localtree = "/srv/git/") {
    exec { "git_reset_exec_$name":
        cwd => "$localtree/$name",
        command => "git reset --hard HEAD",
    }
}

define git::pull($source = False, $localtree = "/srv/git/") {
    git::reset { "$name":
        localtree => $localtree
    }

    case $source {
        false: {
            exec { "git_pull_exec_$name":
                cwd => "$localtree/$name",
                command => "git pull",
                onlyif => "test -d $localtree/$name/.git",
                require => Exec["git_reset_exec_$name"]
            }
        }
        default: {
            exec { "git_pull_exec_$name":
                cwd => "$localtree/$name",
                command => "git pull $source",
                onlyif => "test -d $localtree/$name/.git",
                require => Exec["git_reset_exec_$name"]
            }
        }
    }
}

define git::clone($source, $localtree = "/srv/git/") {
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

PKGNAME		:= puppet-module-git
SPECFILE	:= $(PKGNAME).spec
VERSION		:= $(shell rpm -q --qf "%{VERSION}\n" --specfile $(SPECFILE)| head -1)
RELEASE		:= $(shell rpm -q --qf "%{RELEASE}\n" --specfile $(SPECFILE)| head -1)

clean:
	@rm -rf documentation/tmp
	@rm -rf $(PKGNAME)-$(VERSION)/
	@rm -rf $(PKGNAME)-$(VERSION).tar.gz

test: clean
	@puppet --noop --parseonly manifests/init.pp
	@echo All OK

archive: test
	@rm -rf $(PKGNAME)-$(VERSION).tar.gz
	@rm -rf /tmp/$(PKGNAME)-$(VERSION) /tmp/$(PKGNAME)
	@dir=$$PWD; cd /tmp; cp -a $$dir $(PKGNAME)
	@mv /tmp/$(PKGNAME) /tmp/$(PKGNAME)-$(VERSION)
	@dir=$$PWD; cd /tmp; tar --exclude .git --gzip -cvf $$dir/$(PKGNAME)-$(VERSION).tar.gz $(PKGNAME)-$(VERSION)
	@rm -rf /tmp/$(PKGNAME)-$(VERSION)
	@echo "The archive is in $(PKGNAME)-$(VERSION).tar.gz"

rpm: archive
	@rpmbuild -ta $(PKGNAME)-$(VERSION).tar.gz

install:
	mkdir -p $(DESTDIR)/var/lib/puppet/modules/git
	cp -r files $(DESTDIR)/var/lib/puppet/modules/git/
	cp -r manifests $(DESTDIR)/var/lib/puppet/modules/git/
	cp -r templates $(DESTDIR)/var/lib/puppet/modules/git/

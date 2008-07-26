test:
	@puppet --noop --parseonly manifests/init.pp
	@echo All OK

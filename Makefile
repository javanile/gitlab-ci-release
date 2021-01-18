
.PHONY: test

push:
	git config credential.helper 'cache --timeout=3600'
	date > PUSH
	git add .
	git commit -am "push"
	git push


## -------
## Testing
## -------
test: push
	bash test/release-test.sh

test-simple-release:
	bash test/simple-release-test.sh

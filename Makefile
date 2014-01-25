all: build/octavo.combo.min.js

lib/rangy.js: lib/rangy-core.js lib/rangy-selectionsaverestore.js
	cat lib/rangy-core.js lib/LF lib/rangy-selectionsaverestore.js lib/SEMI > lib/rangy.js

build/octavo.js: src/octavo.coffee
	coffee -o build/ -c src/octavo.coffee
	archive src/octavo.coffee versions/

build/octavo.min.js: build/octavo.js
	uglifyjs build/octavo.js > build/octavo.min.js
	archive build/octavo.js versions/

build/octavo.combo.min.js: lib/jquery.js lib/rangy.js build/octavo.min.js
	cat lib/jquery.js lib/LF lib/rangy.js lib/LF build/octavo.min.js > build/octavo.combo.min.js

commit: ;
	git add -A .
	git commit
	git push

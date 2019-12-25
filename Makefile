# Build binary
#
# Example:
#   make install
install:
	hack/install.sh
.PHONY: install

# Build binary
#
# Example:
#   make uninstall
uninstall:
	hack/uninstall.sh
.PHONY: uninstall

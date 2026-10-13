# run this after `./craft pin all` and verifying SHA256 hashes match

# Set your own registry here:
export REGISTRY=goodieshq
export PLATFORMS=linux/amd64,linux/arm64
export CADDY_VERSION=2.11
export REQUIRE_SHA256=1
./craft update --push
./craft dashboard --push
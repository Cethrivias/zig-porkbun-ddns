run:
	@zig build run --prominent-compile-errors

watch:
	@zig build --watch -fincremental --prominent-compile-errors

build.release:
	@zig build --release=fast

docker.build:
	@docker build . -t cethrivias/zig-porkbun-ddns:latest --platform linux/amd64,linux/arm64/v8

docker.publish: docker.build
	@docker push cethrivias/zig-porkbun-ddns

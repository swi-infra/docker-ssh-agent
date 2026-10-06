ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

IMAGE_NAME:=jenkins4eval/ssh-slave
IMAGE_ALPINE:=${IMAGE_NAME}:alpine
IMAGE_BUSTER:=${IMAGE_NAME}:test
IMAGE_STRETCH=${IMAGE_NAME}:stretch
IMAGE_JDK11:=${IMAGE_NAME}:jdk11
IMAGE_STRETCH_JDK11=${IMAGE_NAME}:jdk11-stretch
IMAGE_BOOKWORM_JDK21:=${IMAGE_NAME}:jdk21-bookworm

build: build-alpine build-buster build-stretch build-jdk11 build-stretch-jdk11 build-bookworm-jdk21

build-alpine:
	cp -f setup-sshd 8/alpine/
	docker build -t ${IMAGE_ALPINE} 8/alpine

build-buster:
	cp -f setup-sshd 8/debian/buster/
	docker build -t ${IMAGE_BUSTER} 8/debian/buster

build-stretch:
	cp -f setup-sshd 8/debian/stretch/
	docker build -t ${IMAGE_STRETCH} 8/debian/stretch

build-jdk11:
	cp -f setup-sshd 11/debian/buster/
	docker build -t ${IMAGE_JDK11} 11/debian/buster

build-stretch-jdk11:
	cp -f setup-sshd 11/debian/stretch/
	docker build -t ${IMAGE_STRETCH_JDK11} 11/debian/stretch

build-bookworm-jdk21:
	cp -f setup-sshd 21/debian/bookworm/
	docker build -t ${IMAGE_BOOKWORM_JDK21} 21/debian/bookworm


bats:
	# The lastest version is v1.1.0
	@if [ ! -d bats-core ]; then git clone https://github.com/bats-core/bats-core.git; fi
	@git -C bats-core reset --hard c706d1470dd1376687776bbe985ac22d09780327

.PHONY: test test-alpine test-jdk11 test-buster test-stretch test-stretch-jdk11 test-bookworm-jdk21
test: bats test-alpine test-jdk11 test-buster test-stretch test-stretch-jdk11 test-bookworm-jdk21

test-alpine:
	@FOLDER="8/alpine" bats-core/bin/bats tests/tests.bats

test-jdk11:
	@FOLDER="11/debian/buster" bats-core/bin/bats tests/tests.bats

test-buster:
	@FOLDER="8/debian/buster" bats-core/bin/bats tests/tests.bats

test-stretch:
	@FOLDER="8/debian/stretch" bats-core/bin/bats tests/tests.bats

test-stretch-jdk11:
	@FOLDER="11/debian/stretch" bats-core/bin/bats tests/tests.bats

test-bookworm-jdk21:
	@FOLDER="21/debian/bookworm" bats-core/bin/bats tests/tests.bats

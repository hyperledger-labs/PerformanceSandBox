# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0

ARG GO_VER=1.14.4
ARG ALPINE_VER=3.12

FROM golang:${GO_VER}-alpine${ALPINE_VER}

# ENV GOPROXY=https://goproxy.cn,direct
WORKDIR /go/src/github.com/msalimbene/hlp-721
COPY . .

RUN go get -d -v ./...
RUN go install -v ./...

EXPOSE 9999
CMD ["hlp-721"]

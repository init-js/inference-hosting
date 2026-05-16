#!/bin/bash

set -exuo pipefail

docker build . -t llmux-static:latest


# Changelog

All notable changes to this project will be documented in this file.

## [2.2.1](https://github.com/terraform-aws-modules/terraform-aws-dms/compare/v2.2.0...v2.2.1) (2024-03-07)


### Bug Fixes

* Update CI workflow versions to remove deprecated runtime warnings ([#61](https://github.com/terraform-aws-modules/terraform-aws-dms/issues/61)) ([b56e19e](https://github.com/terraform-aws-modules/terraform-aws-dms/commit/b56e19e8387a9cb35a043e33f665b6905716c0dd))

## [2.2.0](https://github.com/terraform-aws-modules/terraform-aws-dms/compare/v2.1.0...v2.2.0) (2024-02-02)


### Features

* Add Serverless replication task support ([#56](https://github.com/terraform-aws-modules/terraform-aws-dms/issues/56)) ([c5fcb29](https://github.com/terraform-aws-modules/terraform-aws-dms/commit/c5fcb2968301fa9774c6923507c0389f29db7538))

## [2.1.0](https://github.com/terraform-aws-modules/terraform-aws-dms/compare/v2.0.1...v2.1.0) (2023-12-22)


### Features

* DMS Endpoint `postgres_settings` ([#54](https://github.com/terraform-aws-modules/terraform-aws-dms/issues/54)) ([9dd4bf1](https://github.com/terraform-aws-modules/terraform-aws-dms/commit/9dd4bf16b03d5b811a4ed4843ba1e23855736ce4))

### [2.0.1](https://github.com/terraform-aws-modules/terraform-aws-dms/compare/v2.0.0...v2.0.1) (2023-10-27)


### Bug Fixes

* Add conditional to access IAM role when used as fallback value ([#48](https://github.com/terraform-aws-modules/terraform-aws-dms/issues/48)) ([3695079](https://github.com/terraform-aws-modules/terraform-aws-dms/commit/369507990a61b98947c67654dbbf5d49cc862914))

## [2.0.0](https://github.com/terraform-aws-modules/terraform-aws-dms/compare/v1.6.1...v2.0.0) (2023-08-23)


### ⚠ BREAKING CHANGES

* Update AWS provider to support `v5.0` and increase Terraform MSV to `1.0` (#42)

### Features

* Update AWS provider to support `v5.0` and increase Terraform MSV to `1.0` ([#42](https://github.com/terraform-aws-modules/terraform-aws-dms/issues/42)) ([6fea0da](https://github.com/terraform-aws-modules/terraform-aws-dms/commit/6fea0dab2aa25a91d0d794942a5c184342924b48))


### Bug Fixes

* Fixes small README typos ([#37](https://github.com/terraform-aws-modules/terraform-aws-dms/issues/37)) ([f67f77d](https://github.com/terraform-aws-modules/terraform-aws-dms/commit/f67f77dab595457eb65bb0b9e3b9dc170bbeb354))

### [1.6.1](https://github.com/terraform-aws-modules/terraform-aws-dms/compare/v1.6.0...v1.6.1) (2022-11-07)


### Bug Fixes

* Update CI configuration files to use latest version ([#31](https://github.com/terraform-aws-modules/terraform-aws-dms/issues/31)) ([8d96876](https://github.com/terraform-aws-modules/terraform-aws-dms/commit/8d9687647a0822fa2b777fe07b00d23f45ec7c7b))

## [1.6.0](https://github.com/terraform-aws-modules/terraform-aws-dms/compare/v1.5.3...v1.6.0) (2022-09-25)


### Features

* Added support for secretsmanager secret in endpoints ([#27](https://github.com/terraform-aws-modules/terraform-aws-dms/issues/27)) ([ddb33cb](https://github.com/terraform-aws-modules/terraform-aws-dms/commit/ddb33cbc7a39add9d331cef49206d1aa80d14541))

### [1.5.3](https://github.com/terraform-aws-modules/terraform-aws-dms/compare/v1.5.2...v1.5.3) (2022-07-25)


### Bug Fixes

* Replace local-exec sleep with time_sleep ([#22](https://github.com/terraform-aws-modules/terraform-aws-dms/issues/22)) ([b4ace3b](https://github.com/terraform-aws-modules/terraform-aws-dms/commit/b4ace3bd62dadc269d2a0d3c13f991596055d507))

### [1.5.2](https://github.com/terraform-aws-modules/terraform-aws-dms/compare/v1.5.1...v1.5.2) (2022-06-23)


### Bug Fixes

* Update dynamic lookup logic to support lazy evaluation ([#19](https://github.com/terraform-aws-modules/terraform-aws-dms/issues/19)) ([8fb0daa](https://github.com/terraform-aws-modules/terraform-aws-dms/commit/8fb0daa718b2b346d14c314f0865b8f26bedebe0))

### [1.5.1](https://github.com/terraform-aws-modules/terraform-aws-dms/compare/v1.5.0...v1.5.1) (2022-04-21)


### Bug Fixes

* Update documentation to remove prior notice and deprecated workflow ([#13](https://github.com/terraform-aws-modules/terraform-aws-dms/issues/13)) ([0b928d9](https://github.com/terraform-aws-modules/terraform-aws-dms/commit/0b928d9ee91befa31cb6f796aaf5a97c6959dd7a))

## [1.5.0](https://github.com/clowdhaus/terraform-aws-dms/compare/v1.4.0...v1.5.0) (2022-04-20)


### Features

* Repo has moved to [terraform-aws-modules](https://github.com/terraform-aws-modules/terraform-aws-dms) organization ([d7e1dd5](https://github.com/clowdhaus/terraform-aws-dms/commit/d7e1dd5a635d6b2fe9dc3b41c6e2505239a81f61))

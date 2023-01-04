# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2023-01-04

### Added

- Added this changelog.
- Added Test Helpers to aid in generating valid tokens and mocking requests to Google during automated testing.

### Changed

- Refactored token decoding to its own class to allow decoding tokens outside of middleware (such as tests).
